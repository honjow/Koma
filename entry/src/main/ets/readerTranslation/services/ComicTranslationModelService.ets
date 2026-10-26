// Adapted from NextE59a7a679. Koma owns configuration, credentials and files.
import { common } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { DiagnosticLogger } from '../../diagnostics/DiagnosticLogger'
import { ReaderModelAssetDownload } from '../../model/ReaderModelAssetDownload'
import { validateReaderModelAsset } from '../../model/ReaderModelAssetValidation'

const MODEL_DIRECTORY: string = 'comic-translation-models/ysgyolo-1.2-os1-ncnn-fp32-v1'
const MODEL_RELEASE_TAG: string = 'model-pack-v1.1.6'
const MODEL_ORIGIN_PREFIX: string =
  `https://github.com/erosTeam/NextE-Models/releases/download/${MODEL_RELEASE_TAG}/`
// Same-path mirrors: each prefix is prepended to the origin URL, so the bytes behind it are the same
// artifact. They exist because the release assets are only served from GitHub, which is slow or
// unreachable on many networks. Trust does not move to the mirror — every file is still pinned to the
// SHA-256 below before it is renamed into place, so a mirror that truncates or rewrites a body is
// rejected instead of installed.
const MODEL_MIRROR_PREFIXES: string[] = [
  'https://ghproxy.net/',
  'https://gh-proxy.com/',
  'https://ghfast.top/',
]
const PARAM_FILE_NAME: string = 'ysgyolo_1.2_OS1.0.ncnn.param'
const MODEL_FILE_NAME: string = 'ysgyolo_1.2_OS1.0.ncnn.bin'
const OCR_PARAM_FILE_NAME: string = 'ppocrv5_mobile_rec.ncnn.param'
const OCR_MODEL_FILE_NAME: string = 'ppocrv5_mobile_rec.ncnn.bin'
const OCR_DICTIONARY_FILE_NAME: string = 'ppocrv5_mobile_rec.dict.txt'
const INPAINTER_PARAM_FILE_NAME: string = 'aot-manga-inpainting-256.ncnn.param'
const INPAINTER_MODEL_FILE_NAME: string = 'aot-manga-inpainting-256.ncnn.bin'
const TEXT_MASK_PARAM_FILE_NAME: string = 'comic-text-mask-ctd-1024.ncnn.param'
const TEXT_MASK_MODEL_FILE_NAME: string = 'comic-text-mask-ctd-1024.ncnn.bin'
const PARAM_BYTES: number = 27031
const MODEL_BYTES: number = 10720760
const OCR_PARAM_BYTES: number = 19637
const OCR_MODEL_BYTES: number = 16442228
const OCR_DICTIONARY_BYTES: number = 74012
const INPAINTER_PARAM_BYTES: number = 35150
const INPAINTER_MODEL_BYTES: number = 22711880
const TEXT_MASK_PARAM_BYTES: number = 15552
const TEXT_MASK_MODEL_BYTES: number = 32790420
const PARAM_SHA256: string =
  'f3617c7834bf3f7ae67521db908a53709140aeb1c11a02f8c64b7c091b569987'
const MODEL_SHA256: string =
  '7658e654db1a2e8a77c387607def85d5d297b26f110cc2b334dd52ae17a4fe00'
const OCR_PARAM_SHA256: string =
  '7be8d21064ec730db52c03b144b57f6022ecdd1703e1fe410ca209c2bf0e4d47'
const OCR_MODEL_SHA256: string =
  '1d73b6e2ee6cbd02cabfac6ef9b6a48e62ae76ae02200ea23ac57b121e29697c'
const OCR_DICTIONARY_SHA256: string =
  'd1979e9f794c464c0d2e0b70a7fe14dd978e9dc644c0e71f14158cdf8342af1b'
const INPAINTER_PARAM_SHA256: string =
  'fcaf0b35e6bf19d94f3fe42c98e484bb6e754ede71ffaaa2a48cc9ad5d737b66'
const INPAINTER_MODEL_SHA256: string =
  '356f816992eeb90d50480e96322d6a06dbb8254524180cb951e15975fb60cd7d'
const TEXT_MASK_PARAM_SHA256: string =
  '1f7e14f5c327e0341e775bf23fd61f4ec34a4d3661bf13ff06ea32e3c5c8d072'
const TEXT_MASK_MODEL_SHA256: string =
  'c0bdafdc17e194fa28496532abd860aeb1ee08f60f08b919215abd45191f4deb'
const DOWNLOAD_CONNECT_TIMEOUT_MS: number = 15000
// Allow slow model transfers; the separate stall deadline bounds periods without new bytes.
const DOWNLOAD_READ_TIMEOUT_MS: number = 45 * 60 * 1000
const DOWNLOAD_STALL_TIMEOUT_MS: number = 60 * 1000

export class ComicTranslationModelPaths {
  paramPath: string = ''
  modelPath: string = ''
}

export class ComicTextRecognitionModelPaths {
  paramPath: string = ''
  modelPath: string = ''
  dictionaryPath: string = ''
}

export class ComicSourceInpaintingModelPaths {
  paramPath: string = ''
  modelPath: string = ''
}

export class ComicTextMaskModelPaths {
  paramPath: string = ''
  modelPath: string = ''
}

/** Installs the optional, component-licensed manga model pack outside the HAP. */
export class ComicTranslationModelService {
  private static installTask: Promise<void> | null = null
  // Index of the source that last delivered a file. The nine assets install back to back, so walking
  // the failover list once is enough; later files start from the source that is known to work here.
  private static preferredSource: number = 0
  private static readiness: Map<string, ComicTranslationModelPaths | null> =
    new Map<string, ComicTranslationModelPaths | null>()
  private static ocrReadiness: Map<string, ComicTextRecognitionModelPaths | null> =
    new Map<string, ComicTextRecognitionModelPaths | null>()
  private static inpaintingReadiness: Map<string, ComicSourceInpaintingModelPaths | null> =
    new Map<string, ComicSourceInpaintingModelPaths | null>()
  private static textMaskReadiness: Map<string, ComicTextMaskModelPaths | null> =
    new Map<string, ComicTextMaskModelPaths | null>()

  static displayName(): string {
    return 'YSGYolo + CTD + PP-OCRv5 + AOT'
  }

  static detectorLicense(): string {
    return 'AGPL-3.0-only'
  }

  static textRecognizerLicense(): string {
    return 'Apache-2.0'
  }

  static sourceInpainterLicense(): string {
    return 'GPL-3.0-only'
  }

  static textMaskLicense(): string {
    return 'GPL-3.0-only'
  }

  static downloadBytes(): number {
    return PARAM_BYTES + MODEL_BYTES + OCR_PARAM_BYTES + OCR_MODEL_BYTES +
      OCR_DICTIONARY_BYTES + INPAINTER_PARAM_BYTES + INPAINTER_MODEL_BYTES +
      TEXT_MASK_PARAM_BYTES + TEXT_MASK_MODEL_BYTES
  }

  static async pathsIfReady(context: common.UIAbilityContext): Promise<ComicTranslationModelPaths | null> {
    const directory: string = ComicTranslationModelService.directory(context)
    if (ComicTranslationModelService.readiness.has(directory)) {
      return ComicTranslationModelService.readiness.get(directory) ?? null
    }
    const paths: ComicTranslationModelPaths = ComicTranslationModelService.paths(context)
    const ready: boolean = await validateReaderModelAsset(
      paths.paramPath,
      PARAM_BYTES,
      PARAM_SHA256,
    ) && await validateReaderModelAsset(
      paths.modelPath,
      MODEL_BYTES,
      MODEL_SHA256,
    )
    // A remove/install may publish a newer result while the worker is reading.
    // Never resurrect removed paths or replace a newly installed model with an old miss.
    if (ComicTranslationModelService.readiness.has(directory)) {
      return ComicTranslationModelService.readiness.get(directory) ?? null
    }
    ComicTranslationModelService.readiness.set(directory, ready ? paths : null)
    return ready ? paths : null
  }

  static async ocrPathsIfReady(context: common.UIAbilityContext): Promise<ComicTextRecognitionModelPaths | null> {
    const directory: string = ComicTranslationModelService.directory(context)
    if (ComicTranslationModelService.ocrReadiness.has(directory)) {
      return ComicTranslationModelService.ocrReadiness.get(directory) ?? null
    }
    const paths: ComicTextRecognitionModelPaths = ComicTranslationModelService.ocrPaths(context)
    const ready: boolean = await validateReaderModelAsset(
      paths.paramPath,
      OCR_PARAM_BYTES,
      OCR_PARAM_SHA256,
    ) && await validateReaderModelAsset(
      paths.modelPath,
      OCR_MODEL_BYTES,
      OCR_MODEL_SHA256,
    ) && await validateReaderModelAsset(
      paths.dictionaryPath,
      OCR_DICTIONARY_BYTES,
      OCR_DICTIONARY_SHA256,
    )
    if (ComicTranslationModelService.ocrReadiness.has(directory)) {
      return ComicTranslationModelService.ocrReadiness.get(directory) ?? null
    }
    ComicTranslationModelService.ocrReadiness.set(directory, ready ? paths : null)
    return ready ? paths : null
  }

  static async inpaintingPathsIfReady(
    context: common.UIAbilityContext,
  ): Promise<ComicSourceInpaintingModelPaths | null> {
    const directory: string = ComicTranslationModelService.directory(context)
    if (ComicTranslationModelService.inpaintingReadiness.has(directory)) {
      return ComicTranslationModelService.inpaintingReadiness.get(directory) ?? null
    }
    const paths: ComicSourceInpaintingModelPaths =
      ComicTranslationModelService.inpaintingPaths(context)
    const ready: boolean = await validateReaderModelAsset(
      paths.paramPath,
      INPAINTER_PARAM_BYTES,
      INPAINTER_PARAM_SHA256,
    ) && await validateReaderModelAsset(
      paths.modelPath,
      INPAINTER_MODEL_BYTES,
      INPAINTER_MODEL_SHA256,
    )
    if (ComicTranslationModelService.inpaintingReadiness.has(directory)) {
      return ComicTranslationModelService.inpaintingReadiness.get(directory) ?? null
    }
    ComicTranslationModelService.inpaintingReadiness.set(directory, ready ? paths : null)
    return ready ? paths : null
  }

  static async textMaskPathsIfReady(
    context: common.UIAbilityContext,
  ): Promise<ComicTextMaskModelPaths | null> {
    const directory: string = ComicTranslationModelService.directory(context)
    if (ComicTranslationModelService.textMaskReadiness.has(directory)) {
      return ComicTranslationModelService.textMaskReadiness.get(directory) ?? null
    }
    const paths: ComicTextMaskModelPaths = ComicTranslationModelService.textMaskPaths(context)
    const ready: boolean = await validateReaderModelAsset(
      paths.paramPath,
      TEXT_MASK_PARAM_BYTES,
      TEXT_MASK_PARAM_SHA256,
    ) && await validateReaderModelAsset(
      paths.modelPath,
      TEXT_MASK_MODEL_BYTES,
      TEXT_MASK_MODEL_SHA256,
    )
    if (ComicTranslationModelService.textMaskReadiness.has(directory)) {
      return ComicTranslationModelService.textMaskReadiness.get(directory) ?? null
    }
    ComicTranslationModelService.textMaskReadiness.set(directory, ready ? paths : null)
    return ready ? paths : null
  }

  static async isInstalled(context: common.UIAbilityContext): Promise<boolean> {
    return await ComicTranslationModelService.pathsIfReady(context) !== null &&
      await ComicTranslationModelService.ocrPathsIfReady(context) !== null &&
      await ComicTranslationModelService.inpaintingPathsIfReady(context) !== null &&
      await ComicTranslationModelService.textMaskPathsIfReady(context) !== null
  }

  static async install(context: common.UIAbilityContext): Promise<void> {
    if (await ComicTranslationModelService.isInstalled(context)) {
      return
    }
    if (ComicTranslationModelService.installTask === null) {
      ComicTranslationModelService.installTask =
        ComicTranslationModelService.installNow(context)
    }
    try {
      await ComicTranslationModelService.installTask
    } finally {
      ComicTranslationModelService.installTask = null
    }
  }

  static remove(context: common.UIAbilityContext): void {
    const paths: ComicTranslationModelPaths = ComicTranslationModelService.paths(context)
    const ocrPaths: ComicTextRecognitionModelPaths =
      ComicTranslationModelService.ocrPaths(context)
    const inpaintingPaths: ComicSourceInpaintingModelPaths =
      ComicTranslationModelService.inpaintingPaths(context)
    const textMaskPaths: ComicTextMaskModelPaths =
      ComicTranslationModelService.textMaskPaths(context)
    const values: string[] = [
      paths.paramPath,
      paths.modelPath,
      ocrPaths.paramPath,
      ocrPaths.modelPath,
      ocrPaths.dictionaryPath,
      inpaintingPaths.paramPath,
      inpaintingPaths.modelPath,
      textMaskPaths.paramPath,
      textMaskPaths.modelPath,
    ]
    for (let index: number = 0; index < values.length; index++) {
      ComicTranslationModelService.removeIfExists(values[index])
      ComicTranslationModelService.removeIfExists(`${values[index]}.part`)
    }
    ComicTranslationModelService.readiness.set(
      ComicTranslationModelService.directory(context),
      null,
    )
    ComicTranslationModelService.ocrReadiness.set(
      ComicTranslationModelService.directory(context),
      null,
    )
    ComicTranslationModelService.inpaintingReadiness.set(
      ComicTranslationModelService.directory(context),
      null,
    )
    ComicTranslationModelService.textMaskReadiness.set(
      ComicTranslationModelService.directory(context),
      null,
    )
  }

  private static async installNow(context: common.UIAbilityContext): Promise<void> {
    const directory: string = ComicTranslationModelService.directory(context)
    const paths: ComicTranslationModelPaths = ComicTranslationModelService.paths(context)
    const ocrPaths: ComicTextRecognitionModelPaths =
      ComicTranslationModelService.ocrPaths(context)
    const inpaintingPaths: ComicSourceInpaintingModelPaths =
      ComicTranslationModelService.inpaintingPaths(context)
    const textMaskPaths: ComicTextMaskModelPaths =
      ComicTranslationModelService.textMaskPaths(context)
    ComicTranslationModelService.ensureDir(directory)
    DiagnosticLogger.info('comic-translation-model', 'download_start', 'pack=local-manga')
    try {
      await ComicTranslationModelService.installAssetIfMissing(
        PARAM_FILE_NAME,
        paths.paramPath,
        PARAM_BYTES,
        PARAM_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        MODEL_FILE_NAME,
        paths.modelPath,
        MODEL_BYTES,
        MODEL_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        OCR_PARAM_FILE_NAME,
        ocrPaths.paramPath,
        OCR_PARAM_BYTES,
        OCR_PARAM_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        OCR_MODEL_FILE_NAME,
        ocrPaths.modelPath,
        OCR_MODEL_BYTES,
        OCR_MODEL_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        OCR_DICTIONARY_FILE_NAME,
        ocrPaths.dictionaryPath,
        OCR_DICTIONARY_BYTES,
        OCR_DICTIONARY_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        INPAINTER_PARAM_FILE_NAME,
        inpaintingPaths.paramPath,
        INPAINTER_PARAM_BYTES,
        INPAINTER_PARAM_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        INPAINTER_MODEL_FILE_NAME,
        inpaintingPaths.modelPath,
        INPAINTER_MODEL_BYTES,
        INPAINTER_MODEL_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        TEXT_MASK_PARAM_FILE_NAME,
        textMaskPaths.paramPath,
        TEXT_MASK_PARAM_BYTES,
        TEXT_MASK_PARAM_SHA256,
      )
      await ComicTranslationModelService.installAssetIfMissing(
        TEXT_MASK_MODEL_FILE_NAME,
        textMaskPaths.modelPath,
        TEXT_MASK_MODEL_BYTES,
        TEXT_MASK_MODEL_SHA256,
      )
      ComicTranslationModelService.readiness.set(directory, paths)
      ComicTranslationModelService.ocrReadiness.set(directory, ocrPaths)
      ComicTranslationModelService.inpaintingReadiness.set(directory, inpaintingPaths)
      ComicTranslationModelService.textMaskReadiness.set(directory, textMaskPaths)
      DiagnosticLogger.info(
        'comic-translation-model',
        'download_success',
        `pack=local-manga bytes=${ComicTranslationModelService.downloadBytes()}`,
      )
    } catch (error) {
      ComicTranslationModelService.readiness.delete(directory)
      ComicTranslationModelService.ocrReadiness.delete(directory)
      ComicTranslationModelService.inpaintingReadiness.delete(directory)
      ComicTranslationModelService.textMaskReadiness.delete(directory)
      await ComicTranslationModelService.pathsIfReady(context)
      await ComicTranslationModelService.ocrPathsIfReady(context)
      await ComicTranslationModelService.inpaintingPathsIfReady(context)
      await ComicTranslationModelService.textMaskPathsIfReady(context)
      DiagnosticLogger.warn(
        'comic-translation-model',
        'download_failed',
        (error as Error).message,
      )
      throw error as Error
    }
  }

  private static async installAssetIfMissing(
    fileName: string,
    destination: string,
    expectedBytes: number,
    expectedSha256: string,
  ): Promise<void> {
    if (await validateReaderModelAsset(
      destination,
      expectedBytes,
      expectedSha256,
    )) {
      return
    }
    const partial: string = `${destination}.part`
    ComicTranslationModelService.removeIfExists(partial)
    try {
      await ComicTranslationModelService.download(fileName, partial, expectedBytes, expectedSha256)
      ComicTranslationModelService.removeIfExists(destination)
      fileIo.renameSync(partial, destination)
    } catch (error) {
      ComicTranslationModelService.removeIfExists(partial)
      throw error as Error
    }
  }

  private static async download(
    fileName: string,
    path: string,
    expectedBytes: number,
    expectedSha256: string,
  ): Promise<void> {
    const sources: string[] = ComicTranslationModelService.modelSources(fileName)
    const firstSource: number = ComicTranslationModelService.preferredSource
    let lastError: string = ''
    for (let step: number = 0; step < sources.length; step++) {
      const index: number = (firstSource + step) % sources.length
      try {
        await ComicTranslationModelService.downloadFrom(sources[index], fileName, path)
        if (!await validateReaderModelAsset(path, expectedBytes, expectedSha256)) {
          throw new Error(`${fileName} checksum mismatch`)
        }
        ComicTranslationModelService.preferredSource = index
        return
      } catch (error) {
        lastError = (error as Error).message
        // Each attempt truncates-then-writes, but a source that dies mid-body would still leave a
        // short file behind; clear it so the next source starts from a clean path.
        ComicTranslationModelService.removeIfExists(path)
        DiagnosticLogger.warn(
          'comic-translation-model',
          'download_source_failed',
          `source=${index} attempt=${step} file=${fileName} ${lastError}`,
        )
      }
    }
    throw new Error(`${fileName} unavailable on all ${sources.length} sources: ${lastError}`)
  }

  private static modelSources(fileName: string): string[] {
    const urls: string[] = [`${MODEL_ORIGIN_PREFIX}${fileName}`]
    for (let index: number = 0; index < MODEL_MIRROR_PREFIXES.length; index++) {
      urls.push(`${MODEL_MIRROR_PREFIXES[index]}${MODEL_ORIGIN_PREFIX}${fileName}`)
    }
    return urls
  }

  private static async downloadFrom(url: string, fileName: string, path: string): Promise<void> {
    const bytes: number = await ReaderModelAssetDownload.download(
      url,
      path,
      (_loaded: number, _total: number): void => {},
      DOWNLOAD_CONNECT_TIMEOUT_MS,
      DOWNLOAD_STALL_TIMEOUT_MS,
      'application/octet-stream,text/plain,*/*',
      1,
      DOWNLOAD_READ_TIMEOUT_MS,
    )
    if (bytes <= 0) {
      throw new Error(`${fileName} response is empty`)
    }
  }

  private static ocrPaths(context: common.UIAbilityContext): ComicTextRecognitionModelPaths {
    const directory: string = ComicTranslationModelService.directory(context)
    const paths: ComicTextRecognitionModelPaths = new ComicTextRecognitionModelPaths()
    paths.paramPath = `${directory}/${OCR_PARAM_FILE_NAME}`
    paths.modelPath = `${directory}/${OCR_MODEL_FILE_NAME}`
    paths.dictionaryPath = `${directory}/${OCR_DICTIONARY_FILE_NAME}`
    return paths
  }

  private static paths(context: common.UIAbilityContext): ComicTranslationModelPaths {
    const directory: string = ComicTranslationModelService.directory(context)
    const paths: ComicTranslationModelPaths = new ComicTranslationModelPaths()
    paths.paramPath = `${directory}/${PARAM_FILE_NAME}`
    paths.modelPath = `${directory}/${MODEL_FILE_NAME}`
    return paths
  }

  private static inpaintingPaths(context: common.UIAbilityContext): ComicSourceInpaintingModelPaths {
    const directory: string = ComicTranslationModelService.directory(context)
    const paths: ComicSourceInpaintingModelPaths = new ComicSourceInpaintingModelPaths()
    paths.paramPath = `${directory}/${INPAINTER_PARAM_FILE_NAME}`
    paths.modelPath = `${directory}/${INPAINTER_MODEL_FILE_NAME}`
    return paths
  }

  private static textMaskPaths(context: common.UIAbilityContext): ComicTextMaskModelPaths {
    const directory: string = ComicTranslationModelService.directory(context)
    const paths: ComicTextMaskModelPaths = new ComicTextMaskModelPaths()
    paths.paramPath = `${directory}/${TEXT_MASK_PARAM_FILE_NAME}`
    paths.modelPath = `${directory}/${TEXT_MASK_MODEL_FILE_NAME}`
    return paths
  }

  private static directory(context: common.UIAbilityContext): string {
    return `${context.filesDir}/${MODEL_DIRECTORY}`
  }

  private static ensureDir(path: string): void {
    try {
      fileIo.mkdirSync(path, true)
    } catch (error) {
      if (!fileIo.accessSync(path)) {
        throw error as Error
      }
    }
  }

  private static removeIfExists(path: string): void {
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path)
      }
    } catch (_error) {
      // Best-effort cleanup; validation prevents partial files from becoming active.
    }
  }
}

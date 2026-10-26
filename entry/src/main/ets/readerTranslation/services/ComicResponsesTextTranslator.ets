// Adapted from NextE59a7a679. Koma owns configuration, credentials and files.
import { KomaTranslationSettings } from '../KomaTranslationSettings'
import { common } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../../diagnostics/DiagnosticLogger'
import {
  ComicTextTranslationRequest,
  ComicTextTranslationResult,
  ComicTextTranslator,
} from './ComicVisualTranslationBackend'
import {
  CODEX_RESPONSES_BASE_URL,
  ComicProviderHttpError,
  ComicResponsesCallConfig,
  ComicResponsesHttpTransport,
  ComicResponsesLabeledImage,
  ComicResponsesProviderCore,
  DefaultComicResponsesHttpTransport,
} from './ComicResponsesPageAnalyzer'
import { ComicResponsesImagePayload } from './ComicResponsesImagePayload'
import {
  ComicResponsesRegionImage,
  ComicResponsesRegionImagePayload,
} from './ComicResponsesRegionImagePayload'
import {
  COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL,
  COMIC_TEXT_TRANSLATION_INPUT_TEXT_ONLY,
  ComicResponsesTextTranslationProtocol,
} from './ComicResponsesTextTranslationProtocol'

export const COMIC_RESPONSES_TEXT_TRANSLATION_PROMPT_VERSION: string =
  'comic-text-responses-v8'
export const COMIC_RESPONSES_TEXT_ONLY_TRANSLATION_PROMPT_VERSION: string =
  'comic-text-responses-text-only-v1'

class ComicResponsesTextTranslatorCore {
  private readonly providerCore: ComicResponsesProviderCore
  private readonly inputMode: string

  constructor(
    transport: ComicResponsesHttpTransport,
    inputMode: string,
  ) {
    ComicResponsesTextTranslationProtocol.validateInputMode(inputMode)
    this.providerCore = new ComicResponsesProviderCore(transport)
    this.inputMode = inputMode
  }

  async translate(
    request: ComicTextTranslationRequest,
    config: ComicResponsesCallConfig,
    sourceRevision: number,
  ): Promise<ComicTextTranslationResult> {
    const startedAt: number = Date.now()
    const prompt: string =
      ComicResponsesTextTranslationProtocol.buildPrompt(request, this.inputMode)
    let imageDataUrl: string = ''
    let crops: ComicResponsesRegionImage[] = []
    if (this.inputMode === COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL) {
      imageDataUrl = ComicResponsesImagePayload.dataUrl(
        request.source.imageFilePath,
        request.source.imageHash,
      )
      crops = await ComicResponsesRegionImagePayload.build(request)
    }
    const additionalImages: ComicResponsesLabeledImage[] = []
    for (let index: number = 0; index < crops.length; index++) {
      const input: ComicResponsesLabeledImage = new ComicResponsesLabeledImage()
      input.label = 'Region crop blockId=' + crops[index].blockId
      input.imageDataUrl = crops[index].dataUrl
      additionalImages.push(input)
    }
    let cropDataUrlChars: number = 0
    let cropBytes: number = 0
    let cropPixels: number = 0
    for (let index: number = 0; index < crops.length; index++) {
      cropDataUrlChars += crops[index].dataUrl.length
      cropBytes += crops[index].byteLength
      cropPixels += crops[index].width * crops[index].height
    }
    const payloadPreparedAt: number = Date.now()
    const prepareMs: number = payloadPreparedAt - startedAt
    DiagnosticLogger.info(
      'comic-translation',
      'text_request_payload',
      `page=${request.source.pageIndex} input=${this.inputMode} ` +
        `source=${request.source.imageWidth}x${request.source.imageHeight} ` +
        `blocks=${request.document.blocks.length} promptChars=${prompt.length} ` +
        `fullImageChars=${imageDataUrl.length} crops=${crops.length} ` +
        `cropChars=${cropDataUrlChars} cropBytes=${cropBytes} cropPixels=${cropPixels} ` +
        `prepare=${prepareMs}ms`,
    )
    const providerJson: string = await this.providerCore.requestJson(
      prompt,
      imageDataUrl,
      config,
      additionalImages,
    )
    const providerCompletedAt: number = Date.now()
    const providerMs: number = providerCompletedAt - payloadPreparedAt
    DiagnosticLogger.info(
      'comic-translation',
      'text_request_timing',
      `page=${request.source.pageIndex} input=${this.inputMode} ` +
        `prepare=${prepareMs}ms ` +
        `provider=${providerMs}ms total=${providerCompletedAt - startedAt}ms`,
    )
    try {
      const result: ComicTextTranslationResult = ComicResponsesTextTranslationProtocol.parse(
        request,
        providerJson,
        config.providerId,
        sourceRevision,
        config.model,
        this.promptVersion(),
        this.inputMode,
      )
      const finishedAt: number = Date.now()
      result.diagnostics.inputMode = this.inputMode
      result.diagnostics.promptChars = prompt.length
      result.diagnostics.fullImageDataUrlChars = imageDataUrl.length
      result.diagnostics.regionCropCount = crops.length
      result.diagnostics.regionCropDataUrlChars = cropDataUrlChars
      result.diagnostics.regionCropBytes = cropBytes
      result.diagnostics.regionCropPixels = cropPixels
      result.diagnostics.providerResponseChars = providerJson.length
      result.diagnostics.prepareMs = prepareMs
      result.diagnostics.providerMs = providerMs
      result.diagnostics.parseMs = finishedAt - providerCompletedAt
      result.diagnostics.totalMs = finishedAt - startedAt
      return result
    } catch (error) {
      throw ComicResponsesProviderCore.stageError('output', error as Error)
    }
  }

  promptVersion(): string {
    return this.inputMode === COMIC_TEXT_TRANSLATION_INPUT_TEXT_ONLY
      ? COMIC_RESPONSES_TEXT_ONLY_TRANSLATION_PROMPT_VERSION
      : COMIC_RESPONSES_TEXT_TRANSLATION_PROMPT_VERSION
  }

  contextFingerprint(request: ComicTextTranslationRequest): string {
    return ComicResponsesTextTranslationProtocol.contextFingerprint(request, this.inputMode)
  }
}

export class OpenAiApiComicTextTranslator implements ComicTextTranslator {
  private readonly config: ComicResponsesCallConfig
  private readonly revision: number
  private readonly core: ComicResponsesTextTranslatorCore

  constructor(
    baseUrl: string,
    apiKey: string,
    model: string,
    transport: ComicResponsesHttpTransport = new DefaultComicResponsesHttpTransport(),
    sourceProfileId: string = 'openai-responses-api',
    sourceRevision: number = 1,
    inputMode: string = COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL,
  ) {
    this.config = new ComicResponsesCallConfig()
    this.config.providerId = sourceProfileId
    this.config.baseUrl = baseUrl
    this.config.accessToken = apiKey
    this.config.model = model
    this.revision = sourceRevision
    this.core = new ComicResponsesTextTranslatorCore(transport, inputMode)
  }

  sourceProfileId(): string {
    return this.config.providerId
  }

  sourceRevision(): number {
    return this.revision
  }

  modelId(): string {
    return this.config.model
  }

  promptVersion(): string {
    return this.core.promptVersion()
  }

  contextFingerprint(request: ComicTextTranslationRequest): string {
    return this.core.contextFingerprint(request)
  }

  translate(request: ComicTextTranslationRequest): Promise<ComicTextTranslationResult> {
    return this.core.translate(request, this.config, this.revision)
  }
}

/** Koma's explicit configuration is independent of NextE's accounts and credentials. */
export class ComicTextTranslatorFactory {
  static async create(context: common.UIAbilityContext,
    inputMode: string = COMIC_TEXT_TRANSLATION_INPUT_MULTIMODAL,
    expectedRevision: number = -1,
    transport: ComicResponsesHttpTransport = new DefaultComicResponsesHttpTransport(expectedRevision)): Promise<ComicTextTranslator> {
    const settings = await KomaTranslationSettings.load(context)
    KomaTranslationSettings.assertRevision(expectedRevision, settings.revision)
    if (!settings.textConfigured()) throw new Error('LLM source is not configured')
    return new OpenAiApiComicTextTranslator(settings.apiBaseUrl, settings.apiKey, settings.apiModel,
      transport, 'koma-reader-translation', settings.revision, inputMode)
  }
}

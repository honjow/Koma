// Ported from NextE; Koma owns processing preferences, model files and cache.
import { readerProcessingOwnerHash, readerSuperResolutionFailureCode } from './ReaderProcessingDiagnostics'
import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { fileIo } from '@kit.CoreFileKit'
import { image, sendableImage } from '@kit.ImageKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  connectReaderModeState as connectReadMode,
  READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT,
  ReaderSuperResolutionBackend,
  ReaderSuperResolutionModel,
} from '../state/ReaderModeState'
import { CacheStat } from './CacheStat'
import {
  ReaderMindSporeSuperResolution,
  ReaderMindSporeSuperResolutionPrepareResult,
  ReaderMindSporeSuperResolutionResult,
} from './ReaderMindSporeSuperResolution'
import {
  ReaderNativeBackendPreference,
  ReaderNativeSuperResolution,
  ReaderNativeSuperResolutionCapabilities,
  ReaderNativeSuperResolutionConfig,
  ReaderNativeSuperResolutionPrepareResult,
  ReaderNativeSuperResolutionResult,
} from './ReaderNativeSuperResolution'
import {
  ReaderSuperResolutionModelPaths,
  ReaderSuperResolutionModelService,
} from './ReaderSuperResolutionModelService'
import {
  ReaderSuperResolutionModelDefinition,
  ReaderSuperResolutionModelRegistry,
} from './ReaderSuperResolutionModelRegistry'
import { ReaderSystemSuperResolutionService } from './ReaderSystemSuperResolutionService'
import { readerImageFileSha256 } from './ReaderImageFileIdentity'
import { pruneSuperResolutionCache, readSuperResolutionCache, removeSuperResolutionCacheFile } from './ReaderSuperResolutionCache'

const CACHE_DIR_NAME: string = 'reader-super-resolution-cache'
const OUTPUT_SCALE: number = 2
// Keep the execution budget aligned with the largest height exposed by settings. For ordinary
// portrait reader images, every source at or below that height must be eligible for 2x processing.
const MAX_OUTPUT_EDGE: number = READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT * OUTPUT_SCALE
const MAX_OUTPUT_PIXELS: number = MAX_OUTPUT_EDGE * MAX_OUTPUT_EDGE
const MAX_OUTPUT_PIXEL_BYTES: number = MAX_OUTPUT_PIXELS * 4
const SYSTEM_MAX_OUTPUT_EDGE: number = READER_SUPER_RESOLUTION_MAX_SOURCE_HEIGHT * 4
const SYSTEM_MAX_OUTPUT_PIXELS: number = SYSTEM_MAX_OUTPUT_EDGE * SYSTEM_MAX_OUTPUT_EDGE
const SYSTEM_MAX_OUTPUT_PIXEL_BYTES: number = SYSTEM_MAX_OUTPUT_PIXELS * 4
const SENDABLE_PIXEL_MAP_LIMIT: number = 128 * 1024 * 1024

@Concurrent
function allocateSystemSuperResolutionPixels(bytes: number): ArrayBuffer {
  return new ArrayBuffer(bytes)
}

/** Own the normalized buffer, encoder and their disposal on the same worker. */
@Concurrent
async function packSystemSuperResolution(source: sendableImage.PixelMap | ArrayBuffer, width: number, height: number,
  path: string): Promise<void> {
  let pixels: image.PixelMap | undefined = undefined
  let packer: image.ImagePacker | undefined = undefined
  let file: fileIo.File | undefined = undefined
  try {
    const bytes = source instanceof ArrayBuffer ? source : new ArrayBuffer(width * height * 4)
    if (!(source instanceof ArrayBuffer)) {
      await source.readPixelsToBuffer(bytes)
      await source.release()
    }
    pixels = await image.createPixelMap(bytes, {
      size: { width, height },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: false,
    })
    file = await fileIo.open(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    packer = image.createImagePacker()
    await packer.packToFile(pixels, file.fd, { format: 'image/jpeg', quality: 98 })
    await fileIo.close(file)
    file = undefined
  } finally {
    if (file !== undefined) {
      try { await fileIo.close(file) } catch (_error) {}
    }
    if (packer !== undefined) {
      try { await packer.release() } catch (_error) {}
    }
    if (pixels !== undefined) {
      try { await pixels.release() } catch (_error) {}
    }
  }
}

const MAX_CACHE_FILE_COUNT: number = 64
const MAX_CACHE_BYTES: number = 256 * 1024 * 1024
const SUPER_RESOLUTION_SUPERSEDED_ERROR: string = 'super-resolution request superseded'
const NNRT_VALIDATION_BACKEND: string = 'nnrt'
// VkVersion encoding for Vulkan 1.3. This is a conservative proxy from the tested devices, not a
// Vulkan guarantee about foreground scheduling behavior.
const INTERACTION_SAFE_VULKAN_API_VERSION: number = 0x00403000
const NATIVE_PIPELINE_VERSION: string =
  'nnrt-model-contracts-v4|vulkan-gpu-prepost-tile128-fp16a-yield1-v7'

let readerSuperResolutionInteractionPauseRequested: boolean = false
let readerSuperResolutionInteractionPaused: boolean = false
let readerSuperResolutionInteractionProtectionRequired: boolean = true

function applyReaderSuperResolutionInteractionPause(): void {
  const effectivePaused: boolean = connectReadMode().superResolutionEnabled &&
    readerSuperResolutionInteractionPauseRequested &&
    readerSuperResolutionInteractionProtectionRequired
  if (readerSuperResolutionInteractionPaused === effectivePaused) return
  readerSuperResolutionInteractionPaused = effectivePaused
  ReaderNativeSuperResolution.setInteractionPaused(effectivePaused)
}

function setReaderSuperResolutionInteractionProtectionRequired(required: boolean): void {
  readerSuperResolutionInteractionProtectionRequired = required
  applyReaderSuperResolutionInteractionPause()
}

@Concurrent
function pruneSuperResolutionCacheOnWorker(dir: string, protectedPath: string, maxBytes: number, maxFiles: number): void {
  pruneSuperResolutionCache(dir, protectedPath, maxBytes, maxFiles)
}

export class ReaderSuperResolutionResult {
  filePath: string = ''
  displayUri: string = ''
  applied: boolean = false
  sourceWidth: number = 0
  sourceHeight: number = 0
  outputWidth: number = 0
  outputHeight: number = 0
  elapsedMs: number = 0
  backend: string = ''
  reason: string = ''
}

export enum ReaderSuperResolutionTaskState {
  QUEUED = 'queued',
  PROCESSING = 'processing',
}

export enum ReaderSuperResolutionTaskPriority {
  CURRENT = 0,
  PREFETCH = 1,
}

class ReaderSuperResolutionInFlightTask {
  promise: Promise<ReaderSuperResolutionResult> = Promise.resolve(new ReaderSuperResolutionResult())
  state: ReaderSuperResolutionTaskState = ReaderSuperResolutionTaskState.QUEUED
  requestId: number = 0
  priority: number = ReaderSuperResolutionTaskPriority.CURRENT
  enqueueOrder: number = 0
  sourcePath: string = ''
  owners: Map<string, number> = new Map<string, number>()
  observers: Array<(state: ReaderSuperResolutionTaskState) => void> = []
  unownedPriority: number = Number.POSITIVE_INFINITY
  superseded: boolean = false
  resumeSystemProcessing: (() => void) | null = null
  startAction: () => Promise<ReaderSuperResolutionResult> =
    (): Promise<ReaderSuperResolutionResult> => Promise.resolve(new ReaderSuperResolutionResult())
  resolveTask: (result: ReaderSuperResolutionResult) => void =
    (_result: ReaderSuperResolutionResult): void => {}
  rejectTask: (error: Error) => void = (_error: Error): void => {}
}

class ReaderSuperResolutionEventLoopProbe {
  private active: boolean = false
  private expectedAt: number = 0
  private delays: number[] = []

  start(): void {
    this.active = true
    this.expectedAt = Date.now() + 16
    this.schedule()
  }

  stop(): void {
    this.active = false
  }

  sampleCount(): number {
    return this.delays.length
  }

  maximumDelayMs(): number {
    return this.delays.length === 0 ? 0 : Math.max(...this.delays)
  }

  percentile95DelayMs(): number {
    if (this.delays.length === 0) {
      return 0
    }
    const ordered: number[] = this.delays.slice().sort(
      (left: number, right: number): number => left - right,
    )
    const index: number = Math.min(
      ordered.length - 1,
      Math.floor(ordered.length * 0.95),
    )
    return ordered[index]
  }

  private schedule(): void {
    setTimeout((): void => {
      if (!this.active) {
        return
      }
      const now: number = Date.now()
      this.delays.push(Math.max(0, now - this.expectedAt))
      this.expectedAt = now + 16
      this.schedule()
    }, 16)
  }
}

export class ReaderSuperResolutionCapabilities {
  vulkanAvailable: boolean = false
  nnrtAvailable: boolean = false
  vulkanApiVersion: number = 0
  gpuName: string = ''
  ncnnVersion: string = ''
}

/**
 * On-device reader image enhancement. The original image remains the display fallback and only the
 * current and bounded prefetch demands share this service's priority queue for
 * generating a 2x cached derivative. reader-kit owns the actual demand window.
 */
export class ReaderSuperResolutionService {
  private static inFlight: Map<string, ReaderSuperResolutionInFlightTask> = new Map<
    string,
    ReaderSuperResolutionInFlightTask
  >()
  private static ownerTasks: Map<string, ReaderSuperResolutionInFlightTask> = new Map<
    string,
    ReaderSuperResolutionInFlightTask
  >()
  private static requestSequence: number = 0
  private static enqueueSequence: number = 0
  private static pendingTasks: ReaderSuperResolutionInFlightTask[] = []
  private static activeTask: ReaderSuperResolutionInFlightTask | null = null
  private static pruneChain: Promise<void> = Promise.resolve()
  private static preparationInFlight: Map<string, Promise<void>> = new Map<string, Promise<void>>()
  static capabilities(): ReaderSuperResolutionCapabilities {
    const native: ReaderNativeSuperResolutionCapabilities =
      ReaderNativeSuperResolution.capabilities()
    const result: ReaderSuperResolutionCapabilities = new ReaderSuperResolutionCapabilities()
    result.vulkanAvailable = native.vulkanAvailable
    result.vulkanApiVersion = native.vulkanApiVersion
    try {
      result.nnrtAvailable = ReaderMindSporeSuperResolution.acceleratorAvailable()
    } catch (_error) {
      result.nnrtAvailable = false
    }
    result.gpuName = native.gpuName
    result.ncnnVersion = native.ncnnVersion
    return result
  }

  static async prepareSelectedModel(context: common.UIAbilityContext): Promise<void> {
    const readMode = connectReadMode()
    if (!readMode.superResolutionEnabled) {
      return
    }
    const model: string = readMode.superResolutionModel
    if (model === ReaderSuperResolutionModel.NONE ||
      ReaderSuperResolutionModelRegistry.find(model) === null) {
      return
    }
    const backendPreference: string = readMode.superResolutionBackend
    const preparationKey: string = `${model}|${backendPreference}`
    const existing: Promise<void> | undefined =
      ReaderSuperResolutionService.preparationInFlight.get(preparationKey)
    if (existing !== undefined) {
      await existing
      return
    }
    const preparation: Promise<void> = ReaderSuperResolutionService.prepareSelectedModelNow(
      context,
      model,
      backendPreference,
    )
    ReaderSuperResolutionService.preparationInFlight.set(preparationKey, preparation)
    try {
      await preparation
    } finally {
      if (ReaderSuperResolutionService.preparationInFlight.get(preparationKey) === preparation) {
        ReaderSuperResolutionService.preparationInFlight.delete(preparationKey)
      }
    }
  }

  private static async prepareSelectedModelNow(
    context: common.UIAbilityContext,
    model: string,
    backendPreference: string,
  ): Promise<void> {
    try {
      if (model === ReaderSuperResolutionModel.SYSTEM_CORE_VISION) {
        if (ReaderSuperResolutionModelService.systemSuperResolutionSupported()) {
          setReaderSuperResolutionInteractionProtectionRequired(true)
        }
        return
      }
      const nnrtModelPath: string | null =
        await ReaderSuperResolutionService.nnrtModelPath(context, model, backendPreference)
      const modelPaths: ReaderSuperResolutionModelPaths | null =
        await ReaderSuperResolutionModelService.pathsIfReady(context, model)
      const readMode = connectReadMode()
      if ((modelPaths === null && nnrtModelPath === null) || !readMode.superResolutionEnabled ||
        readMode.superResolutionModel !== model ||
        readMode.superResolutionBackend !== backendPreference) {
        return
      }
      DiagnosticLogger.info(
        'reader-super-resolution',
        'prepare_start',
        `model=${model} backendPreference=${backendPreference}`,
      )
      setReaderSuperResolutionInteractionProtectionRequired(true)
      if (nnrtModelPath !== null) {
        try {
          const nnrtResult: ReaderMindSporeSuperResolutionPrepareResult =
            await ReaderMindSporeSuperResolution.prepareModel(
              nnrtModelPath,
              ReaderSuperResolutionService.nativeConfig(model, backendPreference).modelKind,
            )
          DiagnosticLogger.info(
            'reader-super-resolution',
            'prepare_success',
            `model=${model} backend=${nnrtResult.backend} modelLoadMs=${nnrtResult.modelLoadMs}`,
          )
          ReaderSuperResolutionService.configureInteractionProtection(nnrtResult.backend)
          return
        } catch (error) {
          DiagnosticLogger.warn(
            'reader-super-resolution',
            'prepare_nnrt_failed',
            `model=${model} reason=${readerSuperResolutionFailureCode((error as Error).message)} message=${(error as Error).message}`,
          )
          if (backendPreference === NNRT_VALIDATION_BACKEND) {
            throw error as Error
          }
        }
      }
      if (modelPaths === null) {
        return
      }
      const result: ReaderNativeSuperResolutionPrepareResult =
        await ReaderNativeSuperResolution.prepareModel(
          modelPaths.paramPath,
          modelPaths.modelPath,
          ReaderSuperResolutionService.nativeConfig(model, backendPreference),
        )
      DiagnosticLogger.info(
        'reader-super-resolution',
        'prepare_success',
        `model=${model} backend=${result.backend} modelLoadMs=${result.modelLoadMs}`,
      )
      ReaderSuperResolutionService.configureInteractionProtection(result.backend)
    } catch (error) {
      DiagnosticLogger.warn(
        'reader-super-resolution',
        'prepare_failed',
        `model=${model} reason=${readerSuperResolutionFailureCode((error as Error).message)} message=${(error as Error).message}`,
      )
    }
  }

  static async stat(context: common.UIAbilityContext): Promise<CacheStat> {
    const result: CacheStat = new CacheStat()
    const entries = readSuperResolutionCache(ReaderSuperResolutionService.cacheDir(context), false)
    result.count = entries.length
    for (let i: number = 0; i < entries.length; i++) {
      result.bytes += entries[i].bytes
    }
    return result
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    await ReaderSuperResolutionService.waitForIdle()
    const entries = readSuperResolutionCache(ReaderSuperResolutionService.cacheDir(context), true)
    for (let i: number = 0; i < entries.length; i++) {
      ReaderSuperResolutionService.removeIfExists(entries[i].path)
      ReaderSuperResolutionService.removeIfExists(
        ReaderSuperResolutionService.backendMetadataPath(entries[i].path),
      )
    }
  }

  static async process(
    context: common.UIAbilityContext,
    sourcePath: string,
    sourceKey: string,
    onTaskState: (state: ReaderSuperResolutionTaskState) => void = (_state: ReaderSuperResolutionTaskState) => {},
    ownerKey: string = '',
    priority: () => number = (): number => ReaderSuperResolutionTaskPriority.CURRENT,
    current: () => boolean = (): boolean => true,
  ): Promise<ReaderSuperResolutionResult> {
    if (!current()) return ReaderSuperResolutionService.originalResult(sourcePath, 'cancelled')
    if (!connectReadMode().superResolutionEnabled) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'disabled')
    }
    const model: string = connectReadMode().superResolutionModel
    if (model === ReaderSuperResolutionModel.NONE) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'model_not_selected')
    }
    if (ReaderSuperResolutionModelRegistry.find(model) === null) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'backend_unavailable')
    }
    if (model === ReaderSuperResolutionModel.SYSTEM_CORE_VISION &&
      !ReaderSuperResolutionModelService.systemSuperResolutionSupported()) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'backend_unavailable')
    }
    const backendPreference: string = connectReadMode().superResolutionBackend

    const sourceStat: fileIo.Stat | null = ReaderSuperResolutionService.fileStat(sourcePath)
    if (sourceStat === null || sourceStat.size <= 0) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'source_missing')
    }
    const maxHeight: number = connectReadMode().superResolutionMaxHeight
    let sourceDigest: string = ''
    try {
      sourceDigest = await readerImageFileSha256(sourcePath)
    } catch (error) {
      DiagnosticLogger.warn(
        'reader-super-resolution',
        'source_hash_failed',
        `message=${(error as Error).message} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'source_hash_failed')
    }
    // Hashing now yields to UI input. Retire a cancelled/changed request before
    // claiming an owner, using a cached result or scheduling any native work.
    const latest = connectReadMode()
    if (!current() || !latest.superResolutionEnabled || latest.superResolutionModel !== model ||
      latest.superResolutionBackend !== backendPreference || latest.superResolutionMaxHeight !== maxHeight) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'cancelled')
    }
    const cacheIdentity: string =
      `${ReaderSuperResolutionService.pipelineVersion(model)}|${model}|${sourceKey}|` +
        `${sourceStat.size}|${sourceDigest}|maxHeight=${maxHeight}|backend=${backendPreference}`
    let outputPath: string = ''
    try {
      outputPath = ReaderSuperResolutionService.outputPath(context, cacheIdentity)
    } catch (error) {
      DiagnosticLogger.warn(
        'reader-super-resolution',
        'cache_prepare_failed',
        `message=${(error as Error).message} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      return ReaderSuperResolutionService.originalResult(sourcePath, 'cache_unavailable')
    }
    const cachedBytes: number = ReaderSuperResolutionService.fileSize(outputPath)
    if (cachedBytes > 0) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
      ReaderSuperResolutionService.touch(outputPath)
      DiagnosticLogger.info(
        'reader-super-resolution',
        'cache_hit',
        `bytes=${cachedBytes} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      const cachedResult: ReaderSuperResolutionResult = new ReaderSuperResolutionResult()
      cachedResult.filePath = outputPath
      cachedResult.displayUri = ReaderSuperResolutionService.displayUri(outputPath)
      cachedResult.applied = true
      cachedResult.backend = ReaderSuperResolutionService.readBackendMetadata(outputPath)
      cachedResult.reason = cachedResult.backend.length > 0
        ? `cache_hit:${cachedResult.backend}`
        : 'cache_hit'
      let cachedSource: image.ImageSource | undefined = undefined
      let cachedOutput: image.ImageSource | undefined = undefined
      try {
        cachedSource = image.createImageSource(sourcePath)
        const cachedSourceInfo: image.ImageInfo = await cachedSource.getImageInfo()
        cachedResult.sourceWidth = cachedSourceInfo.size.width
        cachedResult.sourceHeight = cachedSourceInfo.size.height
        if (model === ReaderSuperResolutionModel.SYSTEM_CORE_VISION) {
          cachedOutput = image.createImageSource(outputPath)
          const cachedOutputInfo: image.ImageInfo = await cachedOutput.getImageInfo()
          cachedResult.outputWidth = cachedOutputInfo.size.width
          cachedResult.outputHeight = cachedOutputInfo.size.height
        } else {
          cachedResult.outputWidth = cachedResult.sourceWidth * OUTPUT_SCALE
          cachedResult.outputHeight = cachedResult.sourceHeight * OUTPUT_SCALE
        }
      } catch (error) {
        DiagnosticLogger.warn(
          'reader-super-resolution',
          'cache_dimensions_failed',
          `message=${(error as Error).message} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
        )
      } finally {
        if (cachedSource !== undefined) {
          await cachedSource.release()
        }
        if (cachedOutput !== undefined) {
          await cachedOutput.release()
        }
      }
      return cachedResult
    }

    const existing: ReaderSuperResolutionInFlightTask | undefined =
      ReaderSuperResolutionService.inFlight.get(outputPath)
    if (existing !== undefined && ReaderSuperResolutionService.hasActiveOwner(existing)) {
      ReaderSuperResolutionService.claimOwner(ownerKey, existing, priority(), onTaskState)
      ReaderSuperResolutionService.updateTaskPriority(existing, sourceKey)
      onTaskState(existing.state)
      DiagnosticLogger.info(
        'reader-super-resolution',
        'queue_join',
        `state=${existing.state} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      return await existing.promise
    }
    const inFlight: ReaderSuperResolutionInFlightTask = new ReaderSuperResolutionInFlightTask()
    ReaderSuperResolutionService.requestSequence += 1
    inFlight.requestId = ReaderSuperResolutionService.requestSequence
    ReaderSuperResolutionService.enqueueSequence += 1
    inFlight.enqueueOrder = ReaderSuperResolutionService.enqueueSequence
    inFlight.priority = priority()
    inFlight.sourcePath = sourcePath
    ReaderSuperResolutionService.claimOwner(ownerKey, inFlight, inFlight.priority, onTaskState)
    const task: Promise<ReaderSuperResolutionResult> =
      new Promise<ReaderSuperResolutionResult>(
        (
          resolve: (result: ReaderSuperResolutionResult) => void,
          reject: (error: Error) => void,
        ): void => {
          inFlight.resolveTask = resolve
          inFlight.rejectTask = reject
        },
      )
    inFlight.promise = task
    inFlight.startAction = (): Promise<ReaderSuperResolutionResult> =>
      model === ReaderSuperResolutionModel.SYSTEM_CORE_VISION
        ? ReaderSuperResolutionService.processNowSystem(
          context,
          sourcePath,
          sourceKey,
          outputPath,
          maxHeight,
          inFlight,
        )
        : ReaderSuperResolutionService.processNow(
          context,
          sourcePath,
          sourceKey,
          outputPath,
          maxHeight,
          model,
          backendPreference,
          inFlight,
        )
    ReaderSuperResolutionService.inFlight.set(outputPath, inFlight)
    onTaskState(ReaderSuperResolutionTaskState.QUEUED)
    DiagnosticLogger.info(
      'reader-super-resolution',
      'queue_enqueue',
      `priority=${inFlight.priority} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
    )
    ReaderSuperResolutionService.enqueue(inFlight, sourceKey)
    try {
      return await task
    } finally {
      ReaderSuperResolutionService.cleanupTask(outputPath, inFlight)
    }
  }

  static updateOwnerPriority(ownerKey: string, priority: number): void {
    const task = ReaderSuperResolutionService.ownerTasks.get(ownerKey)
    if (task === undefined) return
    task.owners.set(ownerKey, priority)
    ReaderSuperResolutionService.updateTaskPriority(task, ownerKey)
  }

  static releaseOwner(ownerKey: string): void {
    if (ownerKey.length <= 0) {
      return
    }
    const task: ReaderSuperResolutionInFlightTask | undefined =
      ReaderSuperResolutionService.ownerTasks.get(ownerKey)
    if (task === undefined) {
      return
    }
    ReaderSuperResolutionService.ownerTasks.delete(ownerKey)
    task.owners.delete(ownerKey)
    if (!ReaderSuperResolutionService.hasActiveOwner(task)) {
      ReaderNativeSuperResolution.setRequestActive(task.requestId, false)
      task.resumeSystemProcessing?.()
      DiagnosticLogger.info(
        'reader-super-resolution',
        'queue_release',
        `request=${task.requestId} state=${task.state}`,
      )
    } else {
      ReaderSuperResolutionService.updateTaskPriority(task, ownerKey)
    }
  }

  static setInteractionPaused(paused: boolean): void {
    readerSuperResolutionInteractionPauseRequested = paused
    applyReaderSuperResolutionInteractionPause()
    if (!paused) ReaderSuperResolutionService.activeTask?.resumeSystemProcessing?.()
  }

  private static configureInteractionProtection(backend: string): void {
    let gpuName: string = ''
    let vulkanApiVersion: number = 0
    try {
      const capabilities: ReaderNativeSuperResolutionCapabilities =
        ReaderNativeSuperResolution.capabilities()
      gpuName = capabilities.gpuName.trim()
      vulkanApiVersion = capabilities.vulkanApiVersion
    } catch (_error) {
      gpuName = ''
      vulkanApiVersion = 0
    }
    const supportsConcurrentVulkanInteraction: boolean = backend === 'vulkan' &&
      vulkanApiVersion >= INTERACTION_SAFE_VULKAN_API_VERSION
    setReaderSuperResolutionInteractionProtectionRequired(!supportsConcurrentVulkanInteraction)
    DiagnosticLogger.info(
      'reader-super-resolution',
      'interaction_policy',
      `backend=${backend} gpu=${gpuName.length > 0 ? gpuName : 'unknown'} ` +
        `vulkanApiVersion=${vulkanApiVersion} ` +
        `pauseDuringInteraction=${!supportsConcurrentVulkanInteraction}`,
    )
  }

  private static claimOwner(
    ownerKey: string,
    task: ReaderSuperResolutionInFlightTask,
    priority: number,
    observer: (state: ReaderSuperResolutionTaskState) => void,
  ): void {
    task.observers.push(observer)
    if (ownerKey.length <= 0) {
      task.unownedPriority = Math.min(task.unownedPriority, priority)
      ReaderNativeSuperResolution.setRequestActive(task.requestId, true)
      return
    }
    const previous: ReaderSuperResolutionInFlightTask | undefined =
      ReaderSuperResolutionService.ownerTasks.get(ownerKey)
    if (previous !== undefined && previous !== task) {
      ReaderSuperResolutionService.releaseOwner(ownerKey)
    }
    task.owners.set(ownerKey, priority)
    ReaderSuperResolutionService.ownerTasks.set(ownerKey, task)
    ReaderNativeSuperResolution.setRequestActive(task.requestId, true)
  }

  private static hasActiveOwner(task: ReaderSuperResolutionInFlightTask): boolean {
    return !task.superseded && (Number.isFinite(task.unownedPriority) || task.owners.size > 0)
  }

  private static ensureTaskActive(task: ReaderSuperResolutionInFlightTask): void {
    if (ReaderSuperResolutionService.hasActiveOwner(task)) {
      return
    }
    ReaderNativeSuperResolution.setRequestActive(task.requestId, false)
    throw new Error(SUPER_RESOLUTION_SUPERSEDED_ERROR)
  }

  private static async waitForSystemInteractionIdle(task: ReaderSuperResolutionInFlightTask): Promise<void> {
    // Core Vision and ImageKit run outside our tiled native pause gate.
    // Do not start a large normalization or encode while the reader is moving.
    while (readerSuperResolutionInteractionPauseRequested && ReaderSuperResolutionService.hasActiveOwner(task)) {
      await new Promise<void>((resume: () => void): void => { task.resumeSystemProcessing = resume })
      task.resumeSystemProcessing = null
    }
    ReaderSuperResolutionService.ensureTaskActive(task)
  }

  private static notifyProcessing(task: ReaderSuperResolutionInFlightTask): void {
    task.state = ReaderSuperResolutionTaskState.PROCESSING
    for (let i: number = 0; i < task.observers.length; i++) {
      task.observers[i](ReaderSuperResolutionTaskState.PROCESSING)
    }
  }

  private static cleanupTask(
    outputPath: string,
    task: ReaderSuperResolutionInFlightTask,
  ): void {
    if (ReaderSuperResolutionService.inFlight.get(outputPath) === task) {
      ReaderSuperResolutionService.inFlight.delete(outputPath)
    }
    task.owners.forEach((_priority: number, ownerKey: string): void => {
      if (ReaderSuperResolutionService.ownerTasks.get(ownerKey) === task) {
        ReaderSuperResolutionService.ownerTasks.delete(ownerKey)
      }
    })
    task.owners.clear()
    ReaderNativeSuperResolution.setRequestActive(task.requestId, true)
  }

  private static enqueue(
    inFlight: ReaderSuperResolutionInFlightTask,
    sourceKey: string,
  ): void {
    ReaderSuperResolutionService.pendingTasks.push(inFlight)
    ReaderSuperResolutionService.sortPendingTasks()
    if (inFlight.priority === ReaderSuperResolutionTaskPriority.CURRENT) {
      ReaderSuperResolutionService.preemptActivePrefetch(sourceKey)
    }
    ReaderSuperResolutionService.drainQueue()
  }

  private static updateTaskPriority(task: ReaderSuperResolutionInFlightTask, sourceKey: string): void {
    if (task.superseded) return
    let priority = task.unownedPriority
    task.owners.forEach((value: number): void => { priority = Math.min(priority, value) })
    if (priority === task.priority) return
    task.priority = priority
    ReaderSuperResolutionService.sortPendingTasks()
    // Once the reader leaves a page, its retained work is lookahead again.
    // A pending current page can supersede it at the existing backend boundary.
    if (ReaderSuperResolutionService.pendingTasks.some((pending: ReaderSuperResolutionInFlightTask): boolean =>
      pending.priority === ReaderSuperResolutionTaskPriority.CURRENT && ReaderSuperResolutionService.hasActiveOwner(pending))) {
      ReaderSuperResolutionService.preemptActivePrefetch(sourceKey)
    }
    DiagnosticLogger.info(
      'reader-super-resolution',
      'queue_priority',
      `request=${task.requestId} priority=${priority} state=${task.state} ` +
        `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
    )
  }

  private static sortPendingTasks(): void {
    ReaderSuperResolutionService.pendingTasks.sort(
      (
        left: ReaderSuperResolutionInFlightTask,
        right: ReaderSuperResolutionInFlightTask,
      ): number => {
        if (left.priority !== right.priority) {
          return left.priority - right.priority
        }
        return left.enqueueOrder - right.enqueueOrder
      },
    )
  }

  private static preemptActivePrefetch(sourceKey: string): void {
    const active: ReaderSuperResolutionInFlightTask | null =
      ReaderSuperResolutionService.activeTask
    if (active === null ||
      active.priority === ReaderSuperResolutionTaskPriority.CURRENT || active.superseded) {
      return
    }
    active.superseded = true
    ReaderNativeSuperResolution.setRequestActive(active.requestId, false)
    active.resumeSystemProcessing?.()
    DiagnosticLogger.info(
      'reader-super-resolution',
      'queue_preempt',
      `request=${active.requestId} byKeyHash=${readerProcessingOwnerHash(sourceKey)}`,
    )
  }

  private static drainQueue(): void {
    if (ReaderSuperResolutionService.activeTask !== null) {
      return
    }
    while (ReaderSuperResolutionService.pendingTasks.length > 0) {
      const next: ReaderSuperResolutionInFlightTask | undefined =
        ReaderSuperResolutionService.pendingTasks.shift()
      if (next === undefined) {
        return
      }
      if (!ReaderSuperResolutionService.hasActiveOwner(next)) {
        next.resolveTask(
          ReaderSuperResolutionService.originalResult(next.sourcePath, 'superseded'),
        )
        continue
      }
      ReaderSuperResolutionService.activeTask = next
      ReaderSuperResolutionService.notifyProcessing(next)
      next.startAction()
        .then((result: ReaderSuperResolutionResult): void => {
          next.resolveTask(result)
        })
        .catch((error: Error): void => {
          next.rejectTask(error)
        })
        .finally((): void => {
          if (ReaderSuperResolutionService.activeTask === next) {
            ReaderSuperResolutionService.activeTask = null
          }
          ReaderSuperResolutionService.drainQueue()
        })
      return
    }
  }

  private static async waitForIdle(): Promise<void> {
    while (ReaderSuperResolutionService.activeTask !== null ||
      ReaderSuperResolutionService.pendingTasks.length > 0) {
      await new Promise<void>((resolve: () => void): void => {
        setTimeout((): void => resolve(), 20)
      })
    }
  }

  private static async processNowSystem(
    context: common.UIAbilityContext,
    sourcePath: string,
    sourceKey: string,
    outputPath: string,
    maxHeight: number,
    inFlight: ReaderSuperResolutionInFlightTask,
  ): Promise<ReaderSuperResolutionResult> {
    const startedAt: number = Date.now()
    const eventLoopProbe: ReaderSuperResolutionEventLoopProbe =
      new ReaderSuperResolutionEventLoopProbe()
    let source: image.ImageSource | undefined = undefined
    let outputPixelMap: image.PixelMap | undefined = undefined
    const tmpPath: string = `${outputPath}.part`
    let sourceWidth: number = 0
    let sourceHeight: number = 0
    let processingStage: string = 'system_source'
    try {
      await ReaderSuperResolutionService.waitForSystemInteractionIdle(inFlight)
      eventLoopProbe.start()
      source = image.createImageSource(sourcePath)
      const sourceInfo: image.ImageInfo = await source.getImageInfo()
      sourceWidth = sourceInfo.size.width
      sourceHeight = sourceInfo.size.height
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'invalid_dimensions',
        )
      }
      if (sourceHeight > maxHeight) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'height_limit',
        )
      }
      DiagnosticLogger.info(
        'reader-super-resolution',
        'process_start',
        `model=${ReaderSuperResolutionModel.SYSTEM_CORE_VISION} ` +
          `source=${sourceWidth}x${sourceHeight} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      processingStage = 'system_process'
      await ReaderSuperResolutionService.waitForSystemInteractionIdle(inFlight)
      outputPixelMap = await ReaderSystemSuperResolutionService.process(sourcePath, maxHeight)
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      if (outputPixelMap === undefined) {
        throw new Error('system image super-resolution returned no output')
      }
      const outputInfo: image.ImageInfo = await outputPixelMap.getImageInfo()
      const outputWidth: number = outputInfo.size.width
      const outputHeight: number = outputInfo.size.height
      const outputPixels: number = outputWidth * outputHeight
      if (outputWidth <= 0 || outputHeight <= 0) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'invalid_dimensions',
        )
      }
      if (outputWidth > SYSTEM_MAX_OUTPUT_EDGE || outputHeight > SYSTEM_MAX_OUTPUT_EDGE ||
        outputPixels > SYSTEM_MAX_OUTPUT_PIXELS ||
        outputPixels * 4 > SYSTEM_MAX_OUTPUT_PIXEL_BYTES) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'device_size_limit',
        )
      }
      // Core Vision may return an internal hardware layout that ImagePacker cannot encode.
      processingStage = 'system_normalize'
      await ReaderSuperResolutionService.waitForSystemInteractionIdle(inFlight)
      let shared: sendableImage.PixelMap | undefined = undefined
      if (outputPixels * 4 <= SENDABLE_PIXEL_MAP_LIMIT) {
        try {
          shared = sendableImage.convertFromPixelMap(outputPixelMap)
          outputPixelMap = undefined
        } catch (_conversionError) { /* Keep the original normalization path for unsupported maps. */ }
      }
      if (shared !== undefined) {
        const workerMap = shared
        processingStage = 'system_worker_pack'
        try {
          await taskpool.execute(packSystemSuperResolution, workerMap, outputWidth, outputHeight, tmpPath)
        } catch (error) {
          // If transfer or reading the sendable map failed, try the same
          // pixels through the existing normalization path.
          try {
            outputPixelMap = sendableImage.convertToPixelMap(workerMap)
            shared = undefined
          } catch (_conversionError) {
            try { await workerMap.release() } catch (_releaseError) {}
            throw error as Error
          }
          processingStage = 'system_normalize'
          await ReaderSuperResolutionService.waitForSystemInteractionIdle(inFlight)
        }
      }
      if (outputPixelMap !== undefined) {
        const normalizedBuffer = await taskpool.execute(allocateSystemSuperResolutionPixels, outputPixels * 4) as ArrayBuffer
        await ReaderSuperResolutionService.waitForSystemInteractionIdle(inFlight)
        await outputPixelMap.readPixelsToBuffer(normalizedBuffer)
        try {
          await outputPixelMap.release()
          outputPixelMap = undefined
        } catch (_releaseError) { /* Retry disposal in finally. */ }
        await ReaderSuperResolutionService.waitForSystemInteractionIdle(inFlight)
        // TaskPool transfers this one-use ArrayBuffer. The original native map
        // cannot be serialized above the PixelMap limit, so only its copied
        // pixels go back to a worker for normalization, packing and disposal.
        processingStage = 'system_worker_pack_buffer'
        await taskpool.execute(packSystemSuperResolution, normalizedBuffer, outputWidth, outputHeight, tmpPath)
      }
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      if (ReaderSuperResolutionService.fileSize(tmpPath) <= 0) throw new Error('enhanced image file is empty')
      ReaderSuperResolutionService.removeIfExists(outputPath)
      ReaderSuperResolutionService.removeIfExists(
        ReaderSuperResolutionService.backendMetadataPath(outputPath),
      )
      fileIo.renameSync(tmpPath, outputPath)
      ReaderSuperResolutionService.writeBackendMetadata(outputPath, 'system')
      const outputBytes: number = ReaderSuperResolutionService.fileSize(outputPath)
      if (outputBytes <= 0) {
        throw new Error('enhanced image file is empty')
      }
      ReaderSuperResolutionService.touch(outputPath)
      const elapsedMs: number = Date.now() - startedAt
      DiagnosticLogger.info(
        'reader-super-resolution',
        'process_success',
        `model=${ReaderSuperResolutionModel.SYSTEM_CORE_VISION} ` +
          `source=${sourceWidth}x${sourceHeight} output=${outputWidth}x${outputHeight} ` +
          `backend=system normalize=${shared !== undefined ? 'worker' : 'worker-buffer'} bytes=${outputBytes} elapsedMs=${elapsedMs} ` +
          `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      await ReaderSuperResolutionService.pruneToLimit(context, outputPath)
      const result: ReaderSuperResolutionResult = new ReaderSuperResolutionResult()
      result.filePath = outputPath
      result.displayUri = ReaderSuperResolutionService.displayUri(outputPath)
      result.applied = true
      result.sourceWidth = sourceWidth
      result.sourceHeight = sourceHeight
      result.outputWidth = outputWidth
      result.outputHeight = outputHeight
      result.elapsedMs = elapsedMs
      result.backend = 'system'
      result.reason = 'processed:system'
      return result
    } catch (error) {
      ReaderSuperResolutionService.removeIfExists(tmpPath)
      const message: string = (error as Error).message
      if (message === SUPER_RESOLUTION_SUPERSEDED_ERROR ||
        !ReaderSuperResolutionService.hasActiveOwner(inFlight)) {
        DiagnosticLogger.info(
          'reader-super-resolution',
          'process_superseded',
          `request=${inFlight.requestId} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
        )
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'superseded',
        )
      }
      DiagnosticLogger.warn(
        'reader-super-resolution',
        'process_failed',
        `stage=${processingStage} message=${message} ` +
          `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      return ReaderSuperResolutionService.originalResult(sourcePath, 'processing_failed')
    } finally {
      eventLoopProbe.stop()
      DiagnosticLogger.info(
        'reader-super-resolution',
        'event_loop_probe',
        `samples=${eventLoopProbe.sampleCount()} ` +
          `p95DelayMs=${eventLoopProbe.percentile95DelayMs()} ` +
          `maxDelayMs=${eventLoopProbe.maximumDelayMs()} ` +
          `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      if (outputPixelMap !== undefined) {
        try {
          await outputPixelMap.release()
        } catch (_releaseError) {}
      }
      if (source !== undefined) {
        try {
          await source.release()
        } catch (_releaseError) {}
      }
    }
  }

  private static async processNow(
    context: common.UIAbilityContext,
    sourcePath: string,
    sourceKey: string,
    outputPath: string,
    maxHeight: number,
    model: string,
    backendPreference: string,
    inFlight: ReaderSuperResolutionInFlightTask,
  ): Promise<ReaderSuperResolutionResult> {
    const startedAt: number = Date.now()
    const eventLoopProbe: ReaderSuperResolutionEventLoopProbe =
      new ReaderSuperResolutionEventLoopProbe()
    eventLoopProbe.start()
    let source: image.ImageSource | undefined = undefined
    let sourcePixelMap: image.PixelMap | undefined = undefined
    let outputPixelMap: image.PixelMap | undefined = undefined
    let packer: image.ImagePacker | undefined = undefined
    let outputFile: fileIo.File | null = null
    let actualBackend: string = ''
    const tmpPath: string = `${outputPath}.part`
    let sourceWidth: number = 0
    let sourceHeight: number = 0
    try {
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      source = image.createImageSource(sourcePath)
      const sourceInfo: image.ImageInfo = await source.getImageInfo()
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      sourceWidth = sourceInfo.size.width
      sourceHeight = sourceInfo.size.height
      if (sourceWidth <= 0 || sourceHeight <= 0) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'invalid_dimensions',
        )
      }
      if (sourceHeight > maxHeight) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'height_limit',
        )
      }
      const outputWidth: number = sourceWidth * OUTPUT_SCALE
      const outputHeight: number = sourceHeight * OUTPUT_SCALE
      const outputPixels: number = outputWidth * outputHeight
      if (outputWidth > MAX_OUTPUT_EDGE || outputHeight > MAX_OUTPUT_EDGE ||
        outputPixels > MAX_OUTPUT_PIXELS) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'device_size_limit',
        )
      }
      const outputPixelBytes: number = outputWidth * outputHeight * 4
      if (outputPixelBytes > MAX_OUTPUT_PIXEL_BYTES) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'memory_limit',
        )
      }

      DiagnosticLogger.info(
        'reader-super-resolution',
        'process_start',
        `model=${model} source=${sourceWidth}x${sourceHeight} output=${outputWidth}x${outputHeight} ` +
          `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      const decodingOptions: image.DecodingOptions = {
        editable: false,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      }
      sourcePixelMap = await source.createPixelMap(decodingOptions)
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      DiagnosticLogger.info(
        'reader-super-resolution',
        'source_decoded',
        `source=${sourceWidth}x${sourceHeight} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      const modelPaths: ReaderSuperResolutionModelPaths | null =
        await ReaderSuperResolutionModelService.pathsIfReady(context, model)
      const nnrtModelPath: string | null =
        await ReaderSuperResolutionService.nnrtModelPath(context, model, backendPreference)
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      if (modelPaths === null && nnrtModelPath === null) {
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'model_not_installed',
        )
      }
      const inputBuffer: ArrayBuffer = new ArrayBuffer(sourcePixelMap.getPixelBytesNumber())
      await sourcePixelMap.readPixelsToBuffer(inputBuffer)
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      // PixelMap.readPixelsToBuffer exports tightly packed pixels WITHOUT its
      // allocator's row padding (official ImageKit contract). ImageInfo.stride
      // describes the PixelMap allocation, not this exported RGBA buffer. On
      // 197's 800px pages that mismatch rejected current and prefetch alike as
      // short_rgba_buffer. Keep the original RGBA format and processing path.
      const stride: number = sourceWidth * 4
      let enhancedPixels: ArrayBuffer = new ArrayBuffer(0)
      let modelLoadMs: number = 0
      let inferenceMs: number = 0
      let tileCount: number = 0
      const nativeConfig: ReaderNativeSuperResolutionConfig =
        ReaderSuperResolutionService.nativeConfig(model, backendPreference)
      if (nnrtModelPath !== null) {
        try {
          const nnrtResult: ReaderMindSporeSuperResolutionResult =
            await ReaderMindSporeSuperResolution.upscaleRgba(
              inputBuffer,
              sourceWidth,
              sourceHeight,
              stride,
              nnrtModelPath,
              nativeConfig.modelKind,
              inFlight.requestId,
              nativeConfig.effectStrengthPercent,
            )
          enhancedPixels = nnrtResult.pixels
          actualBackend = nnrtResult.backend
          modelLoadMs = nnrtResult.modelLoadMs
          inferenceMs = nnrtResult.inferenceMs
          tileCount = nnrtResult.tileCount
        } catch (error) {
          ReaderSuperResolutionService.ensureTaskActive(inFlight)
          DiagnosticLogger.warn(
            'reader-super-resolution',
            'nnrt_fallback',
            `model=${model} reason=${readerSuperResolutionFailureCode((error as Error).message)} message=${(error as Error).message}`,
          )
        }
      }
      if (enhancedPixels.byteLength === 0) {
        if (backendPreference === NNRT_VALIDATION_BACKEND) {
          throw new Error('NNRT-only validation failed')
        }
        if (modelPaths === null) {
          throw new Error('NNRT model failed and ncnn fallback is unavailable')
        }
        const nativeResult: ReaderNativeSuperResolutionResult =
          await ReaderNativeSuperResolution.upscaleRgba(
            inputBuffer,
            sourceWidth,
            sourceHeight,
            stride,
            modelPaths.paramPath,
            modelPaths.modelPath,
            nativeConfig,
            inFlight.requestId,
          )
        enhancedPixels = nativeResult.pixels
        actualBackend = nativeResult.backend
        modelLoadMs = nativeResult.modelLoadMs
        inferenceMs = nativeResult.inferenceMs
      }
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      const initializationOptions: image.InitializationOptions = {
        size: { width: outputWidth, height: outputHeight },
        srcPixelFormat: image.PixelMapFormat.RGBA_8888,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: false,
      }
      outputPixelMap = await image.createPixelMap(enhancedPixels, initializationOptions)
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      DiagnosticLogger.info(
        'reader-super-resolution',
        'model_inference_done',
        `model=${model} backend=${actualBackend} output=${outputWidth}x${outputHeight} ` +
          `modelLoadMs=${modelLoadMs} inferenceMs=${inferenceMs} tiles=${tileCount} ` +
          `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )

      ReaderSuperResolutionService.removeIfExists(tmpPath)
      outputFile = fileIo.openSync(
        tmpPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      packer = image.createImagePacker()
      const packOptions: image.PackingOption = { format: 'image/jpeg', quality: 98 }
      await packer.packToFile(outputPixelMap, outputFile.fd, packOptions)
      ReaderSuperResolutionService.ensureTaskActive(inFlight)
      fileIo.closeSync(outputFile)
      outputFile = null
      ReaderSuperResolutionService.removeIfExists(outputPath)
      ReaderSuperResolutionService.removeIfExists(
        ReaderSuperResolutionService.backendMetadataPath(outputPath),
      )
      fileIo.renameSync(tmpPath, outputPath)
      ReaderSuperResolutionService.writeBackendMetadata(outputPath, actualBackend)
      const outputBytes: number = ReaderSuperResolutionService.fileSize(outputPath)
      if (outputBytes <= 0) {
        throw new Error('enhanced image file is empty')
      }
      ReaderSuperResolutionService.touch(outputPath)
      const elapsedMs: number = Date.now() - startedAt
      DiagnosticLogger.info(
        'reader-super-resolution',
        'process_success',
        `model=${model} source=${sourceWidth}x${sourceHeight} output=${outputWidth}x${outputHeight} ` +
          `backend=${actualBackend} bytes=${outputBytes} elapsedMs=${elapsedMs} ` +
            `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      await ReaderSuperResolutionService.pruneToLimit(context, outputPath)
      const result: ReaderSuperResolutionResult = new ReaderSuperResolutionResult()
      result.filePath = outputPath
      result.displayUri = ReaderSuperResolutionService.displayUri(outputPath)
      result.applied = true
      result.sourceWidth = sourceWidth
      result.sourceHeight = sourceHeight
      result.outputWidth = outputWidth
      result.outputHeight = outputHeight
      result.elapsedMs = elapsedMs
      result.backend = actualBackend
      result.reason = `processed:${actualBackend}`
      return result
    } catch (error) {
      ReaderSuperResolutionService.removeIfExists(tmpPath)
      const message: string = (error as Error).message
      if (message === SUPER_RESOLUTION_SUPERSEDED_ERROR ||
        !ReaderSuperResolutionService.hasActiveOwner(inFlight)) {
        DiagnosticLogger.info(
          'reader-super-resolution',
          'process_superseded',
          `request=${inFlight.requestId} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
        )
        return ReaderSuperResolutionService.skipResult(
          sourcePath,
          sourceWidth,
          sourceHeight,
          startedAt,
          'superseded',
        )
      }
      DiagnosticLogger.warn(
        'reader-super-resolution',
        'process_failed',
        `reason=${readerSuperResolutionFailureCode(message)} message=${message} keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      return ReaderSuperResolutionService.originalResult(sourcePath, 'processing_failed')
    } finally {
      eventLoopProbe.stop()
      DiagnosticLogger.info(
        'reader-super-resolution',
        'event_loop_probe',
        `samples=${eventLoopProbe.sampleCount()} ` +
          `p95DelayMs=${eventLoopProbe.percentile95DelayMs()} ` +
          `maxDelayMs=${eventLoopProbe.maximumDelayMs()} ` +
          `keyHash=${readerProcessingOwnerHash(sourceKey)}`,
      )
      if (outputFile !== null) {
        try {
          fileIo.closeSync(outputFile)
        } catch (_error) {}
      }
      if (packer !== undefined) {
        await packer.release()
      }
      if (outputPixelMap !== undefined) {
        await outputPixelMap.release()
      }
      if (sourcePixelMap !== undefined) {
        await sourcePixelMap.release()
      }
      if (source !== undefined) {
        await source.release()
      }
    }
  }

  private static pipelineVersion(model: string): string {
    const definition: ReaderSuperResolutionModelDefinition | null =
      ReaderSuperResolutionModelRegistry.find(model)
    if (definition === null) {
      return 'unsupported'
    }
    return definition.systemModel
      ? definition.pipelineVersion
      : `${definition.pipelineVersion}|runtime=${NATIVE_PIPELINE_VERSION}`
  }

  private static nativeConfig(
    model: string,
    backendPreference: string,
  ): ReaderNativeSuperResolutionConfig {
    const definition: ReaderSuperResolutionModelDefinition | null =
      ReaderSuperResolutionModelRegistry.find(model)
    const config: ReaderNativeSuperResolutionConfig = definition === null
      ? new ReaderNativeSuperResolutionConfig()
      : definition.nativeConfig()
    if (backendPreference === ReaderSuperResolutionBackend.VULKAN) {
      config.backendPreference = ReaderNativeBackendPreference.VULKAN
    } else if (backendPreference === ReaderSuperResolutionBackend.CPU) {
      config.backendPreference = ReaderNativeBackendPreference.CPU
    }
    return config
  }

  private static async nnrtModelPath(
    context: common.UIAbilityContext,
    model: string,
    backendPreference: string,
  ): Promise<string | null> {
    const nnrtSupported: boolean =
      model === ReaderSuperResolutionModel.REAL_ESRGAN_X2PLUS ||
        model === ReaderSuperResolutionModel.WAIFU2X_PHOTO_NOISE0_2X ||
        model === ReaderSuperResolutionModel.WAIFU2X_ART_NOISE0_2X ||
        model === ReaderSuperResolutionModel.WAIFU2X_CUNET_NOISE0_2X ||
        model === ReaderSuperResolutionModel.ESPCN_X2 ||
        model === ReaderSuperResolutionModel.REAL_CUGAN_SE_2X_CONSERVATIVE
    if (!nnrtSupported ||
      (backendPreference !== ReaderSuperResolutionBackend.AUTO &&
        backendPreference !== NNRT_VALIDATION_BACKEND)) {
      return null
    }
    try {
      const acceleratorAvailable: boolean =
        ReaderMindSporeSuperResolution.acceleratorAvailable()
      const modelPath: string | null = acceleratorAvailable
        ? await ReaderSuperResolutionModelService.acceleratedModelPathIfReady(context, model)
        : null
      DiagnosticLogger.info(
        'reader-super-resolution',
        'nnrt_probe',
        `model=${model} accelerator=${acceleratorAvailable} modelReady=${modelPath !== null}`,
      )
      if (!acceleratorAvailable) {
        return null
      }
      return modelPath
    } catch (_error) {
      return null
    }
  }

  private static async waitForNnrtAllowed(
    task: ReaderSuperResolutionInFlightTask,
  ): Promise<void> {
    while (readerSuperResolutionInteractionPaused) {
      ReaderSuperResolutionService.ensureTaskActive(task)
      await new Promise<void>((resolve: () => void): void => {
        setTimeout(resolve, 16)
      })
    }
    ReaderSuperResolutionService.ensureTaskActive(task)
  }

  private static skipResult(
    sourcePath: string,
    width: number,
    height: number,
    startedAt: number,
    reason: string,
  ): ReaderSuperResolutionResult {
    const result: ReaderSuperResolutionResult = ReaderSuperResolutionService.originalResult(sourcePath, reason)
    result.sourceWidth = width
    result.sourceHeight = height
    result.elapsedMs = Date.now() - startedAt
    DiagnosticLogger.info(
      'reader-super-resolution',
      'process_skipped',
      `source=${width}x${height} reason=${reason}`,
    )
    return result
  }

  private static originalResult(sourcePath: string, reason: string): ReaderSuperResolutionResult {
    const result: ReaderSuperResolutionResult = new ReaderSuperResolutionResult()
    result.filePath = sourcePath
    result.displayUri = ReaderSuperResolutionService.displayUri(sourcePath)
    result.reason = reason
    return result
  }

  private static pruneToLimit(
    context: common.UIAbilityContext,
    protectedPath: string,
  ): Promise<void> {
    // The single processing slot stays occupied until the scan and eviction
    // finish. The next task cannot begin writing its own .part in this window.
    const directory = ReaderSuperResolutionService.cacheDir(context)
    const task: Promise<void> = ReaderSuperResolutionService.pruneChain.then(async (): Promise<void> => {
      try {
        await taskpool.execute(pruneSuperResolutionCacheOnWorker, directory, protectedPath, MAX_CACHE_BYTES, MAX_CACHE_FILE_COUNT)
      } catch (error) {
        DiagnosticLogger.warn('reader-super-resolution', 'cache_scan_failed', (error as Error).message)
      }
    })
    ReaderSuperResolutionService.pruneChain = task
    return task
  }

  private static outputPath(context: common.UIAbilityContext, identity: string): string {
    const dir: string = ReaderSuperResolutionService.cacheDir(context)
    ReaderSuperResolutionService.ensureDir(dir)
    return `${dir}/${ReaderSuperResolutionService.hashKey(identity)}.jpg`
  }

  private static cacheDir(context: common.UIAbilityContext): string {
    return `${context.cacheDir}/${CACHE_DIR_NAME}`
  }

  private static ensureDir(dir: string): void {
    try {
      fileIo.mkdirSync(dir, true)
    } catch (error) {
      if (!fileIo.accessSync(dir)) {
        throw error as Error
      }
    }
  }

  private static fileStat(path: string): fileIo.Stat | null {
    try {
      return fileIo.statSync(path)
    } catch (_error) {
      return null
    }
  }

  private static fileSize(path: string): number {
    const stat: fileIo.Stat | null = ReaderSuperResolutionService.fileStat(path)
    return stat === null ? 0 : stat.size
  }

  private static touch(path: string): void {
    try {
      fileIo.utimes(path, Date.now())
    } catch (_error) {}
  }

  private static removeIfExists(path: string): void {
    removeSuperResolutionCacheFile(path)
  }

  private static backendMetadataPath(outputPath: string): string {
    return `${outputPath}.backend`
  }

  private static writeBackendMetadata(outputPath: string, backend: string): void {
    if (backend !== 'vulkan' && backend !== 'cpu' && backend !== 'system') {
      return
    }
    const path: string = ReaderSuperResolutionService.backendMetadataPath(outputPath)
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(
        path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC,
      )
      fileIo.writeSync(file.fd, backend)
    } catch (error) {
      ReaderSuperResolutionService.removeIfExists(path)
      DiagnosticLogger.warn(
        'reader-super-resolution',
        'cache_backend_write_failed',
        (error as Error).message,
      )
    } finally {
      if (file !== null) {
        try {
          fileIo.closeSync(file)
        } catch (_error) {}
      }
    }
  }

  private static readBackendMetadata(outputPath: string): string {
    try {
      const value: string = fileIo.readTextSync(
        ReaderSuperResolutionService.backendMetadataPath(outputPath),
      ).trim()
      return value === 'vulkan' || value === 'cpu' || value === 'system' ? value : ''
    } catch (_error) {
      return ''
    }
  }

  private static displayUri(path: string): string {
    if (path.startsWith('file://')) {
      return path
    }
    if (path.startsWith('/')) {
      return `file://${path}`
    }
    return `file:///${path}`
  }

  private static hashKey(value: string): string {
    let hash: number = 5381
    for (let i: number = 0; i < value.length; i++) {
      hash = ((hash << 5) + hash + value.charCodeAt(i)) >>> 0
    }
    return hash.toString(16)
  }

}

/** Feature-HAR safe calls for the optional shared reader adapter. */
export function readerSuperResolutionSetInteractionPaused(paused: boolean): void {
  ReaderSuperResolutionService.setInteractionPaused(paused)
}

export function readerSuperResolutionUpdateOwnerPriority(ownerKey: string, priority: number): void {
  ReaderSuperResolutionService.updateOwnerPriority(ownerKey, priority)
}

export function readerSuperResolutionReleaseOwner(ownerKey: string): void {
  ReaderSuperResolutionService.releaseOwner(ownerKey)
}

export function readerSuperResolutionProcess(
  context: common.UIAbilityContext,
  sourcePath: string,
  sourceKey: string,
  onTaskState: (state: ReaderSuperResolutionTaskState) => void = (_state: ReaderSuperResolutionTaskState): void => {},
  ownerKey: string = '',
  priority: () => number = (): number => ReaderSuperResolutionTaskPriority.CURRENT,
  current: () => boolean = (): boolean => true,
): Promise<ReaderSuperResolutionResult> {
  return ReaderSuperResolutionService.process(context, sourcePath, sourceKey, onTaskState, ownerKey, priority, current)
}

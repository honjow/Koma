import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import {
  configureReaderRemoteImageCache,
  fetchAndCacheSourceRuntimeCoverImage,
  invalidateReaderRemoteImageCachePath,
} from '../model/ReaderPageSourceAdapter'
import { ComicSourceKind } from '../model/ComicModels'
import { SourceCoverHeaders } from '../model/SourceModels'
import { invalidateCachedCoverImagePath, resolveCachedCoverImage } from '../model/CoverImageCacheService'
import { waitForRestoredLocalLibraryFolderAccess } from '../model/LocalLibraryFolderAccessService'
import {
  CoverPixelMapLease,
  coverPixelMapMemoryCache,
  coverPixelMapMemoryCacheKey,
} from '../model/CoverPixelMapMemoryCache'
import { coverImageAutomaticRetryDelayMs } from '../model/CoverImageRetryPolicy'

const COVER_DECODE_MAX_EDGE: number = 320
const COVER_FADE_DURATION_MS: number = 200

interface AnimatedCover {
  uri: string
  signature: string
  generation: number
}

/** Native image path used by cross-search results that manage their own URI. */
@ComponentV2
export struct NativeCoverImage {
  @Param uri: string = ''
  @Param objectFit: ImageFit = ImageFit.Cover
  @Event onError: () => void = () => {}
  @Local private visible: boolean = false

  @Monitor('uri')
  private onUriChanged(): void {
    this.visible = false
  }

  build() {
    Image(this.uri)
      .width('100%')
      .height('100%')
      .objectFit(this.objectFit)
      .interpolation(ImageInterpolation.Medium)
      .opacity(this.visible ? 1 : 0)
      .onComplete(() => {
        this.getUIContext().animateTo({ duration: COVER_FADE_DURATION_MS, curve: Curve.EaseOut }, () => {
          this.visible = true
        })
      })
      .onError(() => { this.onError() })
  }
}

export function cachedCoverFailureKey(
  uri: string | undefined,
  sourceRuntimeId?: string,
  sourceImageId?: string,
  sourceKind?: ComicSourceKind,
  remoteServerId?: string,
  sourceMangaUrl?: string,
  sourceCoverHeaders?: SourceCoverHeaders,
): string {
  const key = `${uri ?? ''}::${(sourceRuntimeId ?? '').trim()}::${(sourceImageId ?? '').trim()}::${sourceKind ?? ''}::${(remoteServerId ?? '').trim()}`
  const route = sourceMangaUrl?.trim() ?? ''
  const routedKey = route.length === 0 ? key : `${key}::${route}`
  return sourceCoverHeaders === undefined ? routedKey : `${routedKey}::${JSON.stringify(sourceCoverHeaders)}`
}

@ComponentV2
export struct CachedCoverImage {
  @Param uri: string = ''
  @Param objectFit: ImageFit = ImageFit.Cover
  @Param sourceRuntimeId: string = ''
  @Param sourceImageId: string = ''
  @Param sourceMangaUrl: string = ''
  @Param sourceCoverHeaders: SourceCoverHeaders | undefined = undefined
  @Param sourceKind: ComicSourceKind | undefined = undefined
  @Param remoteServerId: string = ''
  @Param decodeMaxEdge: number = COVER_DECODE_MAX_EDGE
  @Event onError: () => void = () => {}
  @Local private pixelMap: image.PixelMap | undefined = undefined
  @Local private animatedCover: AnimatedCover | undefined = undefined
  @Local private animatedCoverVisible: boolean = false
  @Local private fadeStaticCover: boolean = false
  @Local private loading: boolean = false
  @Local private failedSignature: string = ''
  private disposed: boolean = false
  private sourceSignature: string = ''
  // This is deliberately separate from sourceSignature. During a source
  // change, sourceSignature describes the requested cover while the current
  // PixelMap may still be the previously rendered cover until the replacement
  // has its own lease.
  private displayedSignature: string = ''
  private decodeGeneration: number = 0
  private loadingSignature: string = ''
  private loadingGeneration: number = 0
  private pixelMapLease: CoverPixelMapLease | undefined = undefined
  private failedAnimationSignature: string = ''
  private automaticRetryTimer: number = -1
  private completedAutomaticRetries: number = 0

  private cancelAutomaticRetry(): void {
    if (this.automaticRetryTimer !== -1) {
      clearTimeout(this.automaticRetryTimer)
      this.automaticRetryTimer = -1
    }
  }

  private scheduleAutomaticRetry(error: Error, signature: string, generation: number,
    sourceRuntimeId: string, sourceImageId: string, sourceKind: ComicSourceKind | undefined,
    remoteServerId: string, sourceMangaUrl: string, decodedCachePath: string, decodeFailure: boolean): boolean {
    const delay = coverImageAutomaticRetryDelayMs(error, this.completedAutomaticRetries, decodeFailure)
    if (delay < 0 || this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
      return false
    }
    this.completedAutomaticRetries += 1
    this.automaticRetryTimer = setTimeout((): void => {
      this.automaticRetryTimer = -1
      if (this.disposed || this.sourceSignature !== signature) return
      void (async (): Promise<void> => {
        if (decodedCachePath.length > 0) {
          const context = getContext(this) as common.UIAbilityContext
          const invalidated = sourceRuntimeId.trim().length > 0
            ? await invalidateReaderRemoteImageCachePath(decodedCachePath).catch((): boolean => false)
            : await invalidateCachedCoverImagePath(context, decodedCachePath).catch((): boolean => false)
          if (!invalidated) {
            if (!this.disposed && this.sourceSignature === signature) this.onError()
            return
          }
          DiagnosticLogger.warn('cached_cover_image', 'cache_invalidated',
            '[CachedCoverImage] step=cache_invalidated stage=decode')
        }
        if (this.disposed || this.sourceSignature !== signature) return
        // A failed decode is a terminal state for one attempt, not for the cover.
        // Clear that attempt and create a fresh generation for the bounded retry.
        this.failedSignature = ''
        this.loading = false
        this.loadingSignature = ''
        this.loadingGeneration = 0
        this.decodeGeneration += 1
        const retryGeneration = this.decodeGeneration
        await this.decodeImage(this.uri, signature, retryGeneration, sourceRuntimeId, sourceImageId,
          sourceKind, remoteServerId, sourceMangaUrl)
      })()
    }, delay)
    return true
  }

  aboutToDisappear(): void {
    // Custom-component disappearance is the destruction boundary. A retained
    // root tab does not remove this component, so its small thumbnail remains
    // available when the tab is shown again.
    this.disposed = true
    this.decodeGeneration += 1
    this.cancelAutomaticRetry()
    // Do not mutate @Local render state during component destruction. The
    // component tree is leaving; only return the ownership lease to the cache.
    const lease = this.pixelMapLease
    this.pixelMapLease = undefined
    void coverPixelMapMemoryCache.release(lease)
  }

  aboutToAppear(): void {
    // aboutToAppear runs before the first build. Starting here lets the synchronous memory-cache
    // lease paint on the initial frame instead of waiting for the post-render onAppear callback.
    this.disposed = false
    void this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId, this.sourceKind, this.remoteServerId, this.sourceMangaUrl)
  }

  private async releasePixelMap(): Promise<void> {
    this.pixelMap = undefined
    this.animatedCover = undefined
    this.displayedSignature = ''
    const lease = this.pixelMapLease
    this.pixelMapLease = undefined
    await coverPixelMapMemoryCache.release(lease)
  }

  private async replacePixelMap(
    lease: CoverPixelMapLease,
    signature: string,
    fromMemory: boolean = false,
  ): Promise<void> {
    // Render the new map before giving the prior lease back to the cache. The
    // cache may release an unindexed, unleased map immediately, so reversing
    // this order would leave Image bound to a released PixelMap (and visibly
    // flash blank) between detail-list cover identities.
    const previousLease = this.pixelMapLease
    this.pixelMapLease = lease
    // A memory hit can paint in the first frame. Keep it immediate; fade only
    // when a loaded image actually replaces a placeholder, not another cover.
    this.fadeStaticCover = !fromMemory && this.pixelMap === undefined && this.animatedCover === undefined
    this.pixelMap = lease.pixelMap
    this.animatedCover = undefined
    this.displayedSignature = signature
    this.failedSignature = ''
    this.completedAutomaticRetries = 0
    this.cancelAutomaticRetry()
    await coverPixelMapMemoryCache.release(previousLease)
  }

  private onAnimatedCoverReady(cover: AnimatedCover): void {
    if (this.disposed || this.animatedCover?.generation !== cover.generation) return
    if (this.pixelMap === undefined) {
      this.getUIContext().animateTo({ duration: COVER_FADE_DURATION_MS, curve: Curve.EaseOut }, () => {
        this.animatedCoverVisible = true
      })
    } else {
      this.animatedCoverVisible = true
    }
    this.completedAutomaticRetries = 0
    this.cancelAutomaticRetry()
    const lease = this.pixelMapLease
    this.pixelMapLease = undefined
    this.pixelMap = undefined
    void coverPixelMapMemoryCache.release(lease)
  }

  private onAnimatedCoverError(cover: AnimatedCover): void {
    if (this.disposed || this.animatedCover?.generation !== cover.generation ||
      this.sourceSignature !== cover.signature) return
    // Let the original first-frame decoder handle a platform animation error.
    this.failedAnimationSignature = cover.signature
    this.animatedCover = undefined
    this.displayedSignature = ''
    this.loading = false
    this.onSourceChanged()
  }

  private createSourceSignature(
    uri: string,
    sourceRuntimeId: string | undefined,
    sourceImageId: string | undefined,
    sourceKind: ComicSourceKind | undefined,
    remoteServerId: string | undefined,
    sourceMangaUrl: string | undefined,
  ): string {
    return `${cachedCoverFailureKey(uri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl,
      this.sourceCoverHeaders)}::${Math.max(1, Math.round(this.decodeMaxEdge))}`
  }

  private async resolveImageUri(
    uri: string,
    sourceRuntimeId: string,
    sourceImageId: string,
    sourceKind: ComicSourceKind | undefined,
    remoteServerId: string,
    sourceMangaUrl: string,
  ): Promise<string> {
    // A selected/restored cover is owned by the app, even when its comic still
    // belongs to a source. Never hand that local file to the source's HTTP resolver.
    if (uri.startsWith('file://')) return uri
    const context = getContext(this) as common.UIAbilityContext
    if (sourceRuntimeId.trim().length > 0) {
      configureReaderRemoteImageCache(context.cacheDir)
      return fetchAndCacheSourceRuntimeCoverImage(sourceRuntimeId, uri, sourceImageId, sourceMangaUrl, this.sourceCoverHeaders)
    }
    return resolveCachedCoverImage(context, {
      uri,
      identity: sourceImageId.trim().length > 0 ? sourceImageId : uri,
      sourceKind,
      remoteServerId,
    })
  }

  private async decodeImage(
    uri: string,
    signature: string,
    generation: number,
    sourceRuntimeId: string,
    sourceImageId: string,
    sourceKind: ComicSourceKind | undefined,
    remoteServerId: string,
    sourceMangaUrl: string,
  ): Promise<void> {
    if (uri.length === 0 ||
      this.disposed ||
      this.sourceSignature !== signature ||
      this.decodeGeneration !== generation ||
      this.failedSignature === signature ||
      (this.loading && this.loadingSignature === signature && this.loadingGeneration === generation)) {
      return
    }
    const memoryCacheKey = coverPixelMapMemoryCacheKey(signature, this.decodeMaxEdge)
    const cachedLease = coverPixelMapMemoryCache.acquire(memoryCacheKey)
    if (cachedLease !== undefined) {
      if (!this.disposed && this.sourceSignature === signature && this.decodeGeneration === generation) {
        await this.replacePixelMap(cachedLease, signature, true)
      } else {
        await coverPixelMapMemoryCache.release(cachedLease)
      }
      return
    }
    this.loading = true
    this.loadingSignature = signature
    this.loadingGeneration = generation
    let imageSource: image.ImageSource | undefined = undefined
    let sourceFile: fs.File | undefined = undefined
    let decodeStep: string = 'resolve'
    let resolvedCachePath: string = ''
    try {
      const resolvedUri = await this.resolveImageUri(uri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl)
      if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
        return
      }
      if (resolvedUri.startsWith('/')) resolvedCachePath = resolvedUri
      // A document URI is not a path with its scheme removed. Let FileIO
      // resolve its read grant, then retain the descriptor through decoding.
      if (resolvedUri.startsWith('file://')) {
        if (resolvedUri.startsWith('file://docs/')) {
          decodeStep = 'folder_access'
          await waitForRestoredLocalLibraryFolderAccess()
        }
        decodeStep = 'open_uri'
        sourceFile = await fs.open(resolvedUri, fs.OpenMode.READ_ONLY)
        decodeStep = 'image_source'
        imageSource = image.createImageSource(sourceFile.fd)
      } else {
        imageSource = image.createImageSource(resolvedUri)
      }
      decodeStep = 'image_info'
      const imageInfo = await imageSource.getImageInfo()
      if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
        return
      }
      const format = imageInfo.mimeType
      if (this.failedAnimationSignature !== signature && (format === 'image/gif' || format === 'image/webp')) {
        const frames = await imageSource.getFrameCount().catch((): number => 1)
        if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) return
        if (frames > 1) {
          const displayUri = resolvedUri.startsWith('/') ? fileUri.getUriFromPath(resolvedUri) : resolvedUri
          // Feed the already cached original to the native Image. Avoid allocating
          // every frame as a PixelMap and keep static covers on the thumbnail cache.
          this.animatedCoverVisible = false
          this.animatedCover = { uri: displayUri, signature, generation }
          this.displayedSignature = signature
          this.failedSignature = ''
          return
        }
      }
      const sourceWidth = Math.max(1, imageInfo.size.width)
      const sourceHeight = Math.max(1, imageInfo.size.height)
      const maxEdge = Math.max(1, this.decodeMaxEdge)
      const scale = Math.min(1, maxEdge / Math.max(sourceWidth, sourceHeight))
      const desiredWidth = Math.max(1, Math.round(sourceWidth * scale))
      const desiredHeight = Math.max(1, Math.round(sourceHeight * scale))
      decodeStep = 'pixel_map'
      const lease = await coverPixelMapMemoryCache.acquireOrLoad(memoryCacheKey, async (): Promise<image.PixelMap> => {
        return imageSource!.createPixelMap({
          desiredSize: {
            width: desiredWidth,
            height: desiredHeight,
          },
        })
      })
      if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
        await coverPixelMapMemoryCache.release(lease)
        return
      }
      await this.replacePixelMap(lease, signature)
    } catch (error) {
      DiagnosticLogger.warn('cached_cover_image', 'decode_failed', '[CachedCoverImage] step=decode_failed stage=' + decodeStep +
        ' code=' + ((error as BusinessError).code ?? 'unknown'))
      if (!this.disposed && this.sourceSignature === signature && this.decodeGeneration === generation) {
        this.failedSignature = signature
        if (!this.scheduleAutomaticRetry(error as Error, signature, generation, sourceRuntimeId,
          sourceImageId, sourceKind, remoteServerId, sourceMangaUrl, resolvedCachePath, decodeStep !== 'resolve')) {
          this.onError()
        } else {
          DiagnosticLogger.info('cached_cover_image', 'automatic_retry',
            '[CachedCoverImage] attempt=1 reason=' + (error as Error).message)
        }
      }
    } finally {
      if (imageSource !== undefined) {
        try {
          await imageSource.release()
        } catch (_error) {
          DiagnosticLogger.warn('cached_cover_image', 'image_source_release_failed', '[CachedCoverImage] step=image_source_release_failed')
        }
      }
      if (sourceFile !== undefined) {
        try {
          await fs.close(sourceFile)
        } catch (_error) {
          DiagnosticLogger.warn('cached_cover_image', 'source_file_close_failed', '[CachedCoverImage] step=source_file_close_failed')
        }
      }
      if (!this.disposed && this.loading && this.loadingSignature === signature && this.loadingGeneration === generation) {
        this.loading = false
        this.loadingSignature = ''
        this.loadingGeneration = 0
      }
    }
  }

  private async handleSourceChanged(
    nextUri: string,
    nextSourceRuntimeId: string | undefined,
    nextSourceImageId: string | undefined,
    nextSourceKind: ComicSourceKind | undefined,
    nextRemoteServerId: string | undefined,
    nextSourceMangaUrl: string | undefined,
  ): Promise<void> {
    const nextSignature = this.createSourceSignature(
      nextUri,
      nextSourceRuntimeId,
      nextSourceImageId,
      nextSourceKind,
      nextRemoteServerId,
      nextSourceMangaUrl,
    )
    if (this.sourceSignature === nextSignature &&
      (this.displayedSignature === nextSignature ||
        (this.loading && this.loadingSignature === nextSignature && this.loadingGeneration === this.decodeGeneration))) {
      return
    }
    this.decodeGeneration += 1
    this.cancelAutomaticRetry()
    this.completedAutomaticRetries = 0
    const generation = this.decodeGeneration
    this.sourceSignature = nextSignature
    this.loading = false
    this.loadingSignature = ''
    this.loadingGeneration = 0
    // A removed cover has no replacement to resolve, so the old lease can be
    // returned immediately. For a non-empty replacement, retain it until
    // decodeImage installs the new lease through replacePixelMap().
    if (nextUri.length === 0) {
      await this.releasePixelMap()
      return
    }
    if (!this.disposed && this.sourceSignature === nextSignature && this.decodeGeneration === generation) {
      await this.decodeImage(
        nextUri,
        nextSignature,
        generation,
        nextSourceRuntimeId ?? '',
        nextSourceImageId ?? '',
        nextSourceKind,
        nextRemoteServerId ?? '',
        nextSourceMangaUrl ?? '',
      )
    }
  }

  @Monitor('uri', 'sourceRuntimeId', 'sourceImageId', 'sourceKind', 'remoteServerId', 'sourceMangaUrl', 'sourceCoverHeaders', 'decodeMaxEdge')
  onSourceChanged(): void {
    this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId, this.sourceKind, this.remoteServerId, this.sourceMangaUrl)
  }

  @Builder
  private AnimatedCoverImage(cover: AnimatedCover) {
    Image(cover.uri)
      .width('100%')
      .height('100%')
      .objectFit(this.objectFit)
      .interpolation(ImageInterpolation.Medium)
      .opacity(this.animatedCoverVisible ? 1 : 0)
      .onComplete(() => { this.onAnimatedCoverReady(cover) })
      .onError(() => { this.onAnimatedCoverError(cover) })
  }

  build() {
    Stack() {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(this.objectFit)
          .interpolation(ImageInterpolation.Medium)
          .transition(this.fadeStaticCover
            ? TransitionEffect.asymmetric(TransitionEffect.OPACITY.animation({ duration: COVER_FADE_DURATION_MS, curve: Curve.EaseOut }), TransitionEffect.IDENTITY)
            : TransitionEffect.IDENTITY)
      }
      if (this.animatedCover !== undefined) {
        this.AnimatedCoverImage(this.animatedCover)
      }
    }
    .width('100%')
    .height('100%')
  }
}

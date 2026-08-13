import { common } from '@kit.AbilityKit'
import { image } from '@kit.ImageKit'
import {
  configureReaderRemoteImageCache,
  fetchAndCacheSourceRuntimeRemoteImage,
} from '../model/ReaderPageSourceAdapter'
import { ComicSourceKind } from '../model/ComicModels'
import { resolveCachedCoverImage } from '../model/CoverImageCacheService'
import {
  CoverPixelMapLease,
  coverPixelMapMemoryCache,
  coverPixelMapMemoryCacheKey,
} from '../model/CoverPixelMapMemoryCache'

const COVER_DECODE_MAX_EDGE: number = 320

export function cachedCoverFailureKey(
  uri: string | undefined,
  sourceRuntimeId?: string,
  sourceImageId?: string,
  sourceKind?: ComicSourceKind,
  remoteServerId?: string,
): string {
  return `${uri ?? ''}::${(sourceRuntimeId ?? '').trim()}::${(sourceImageId ?? '').trim()}::${sourceKind ?? ''}::${(remoteServerId ?? '').trim()}`
}

@ComponentV2
export struct CachedCoverImage {
  @Param uri: string = ''
  @Param objectFit: ImageFit = ImageFit.Cover
  @Param sourceRuntimeId: string = ''
  @Param sourceImageId: string = ''
  @Param sourceKind: ComicSourceKind | undefined = undefined
  @Param remoteServerId: string = ''
  @Param decodeMaxEdge: number = COVER_DECODE_MAX_EDGE
  @Event onError: () => void = () => {}
  @Local private pixelMap: image.PixelMap | undefined = undefined
  @Local private loading: boolean = false
  @Local private failedSignature: string = ''
  private disposed: boolean = false
  private sourceSignature: string = ''
  private decodeGeneration: number = 0
  private loadingSignature: string = ''
  private loadingGeneration: number = 0
  private pixelMapLease: CoverPixelMapLease | undefined = undefined

  aboutToDisappear(): void {
    // Custom-component disappearance is the destruction boundary. A retained
    // root tab does not remove this component, so its small thumbnail remains
    // available when the tab is shown again.
    this.disposed = true
    this.decodeGeneration += 1
    // Do not mutate @Local render state during component destruction. The
    // component tree is leaving; only return the ownership lease to the cache.
    const lease = this.pixelMapLease
    this.pixelMapLease = undefined
    void coverPixelMapMemoryCache.release(lease)
  }

  private async releasePixelMap(): Promise<void> {
    this.pixelMap = undefined
    const lease = this.pixelMapLease
    this.pixelMapLease = undefined
    await coverPixelMapMemoryCache.release(lease)
  }

  private createSourceSignature(
    uri: string,
    sourceRuntimeId: string | undefined,
    sourceImageId: string | undefined,
    sourceKind: ComicSourceKind | undefined,
    remoteServerId: string | undefined,
  ): string {
    return `${cachedCoverFailureKey(uri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId)}::${Math.max(1, Math.round(this.decodeMaxEdge))}`
  }

  private async resolveImageUri(
    uri: string,
    sourceRuntimeId: string,
    sourceImageId: string,
    sourceKind: ComicSourceKind | undefined,
    remoteServerId: string,
  ): Promise<string> {
    const context = getContext(this) as common.UIAbilityContext
    if (sourceRuntimeId.trim().length > 0) {
      configureReaderRemoteImageCache(context.cacheDir)
      return fetchAndCacheSourceRuntimeRemoteImage(sourceRuntimeId, uri, sourceImageId)
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
        this.pixelMapLease = cachedLease
        this.pixelMap = cachedLease.pixelMap
        this.failedSignature = ''
      } else {
        await coverPixelMapMemoryCache.release(cachedLease)
      }
      return
    }
    this.loading = true
    this.loadingSignature = signature
    this.loadingGeneration = generation
    let imageSource: image.ImageSource | undefined = undefined
    try {
      const resolvedUri = await this.resolveImageUri(uri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId)
      if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
        return
      }
      // The cache returns a file URI for local covers. ImageSource consumes the
      // filesystem path, matching the Reader's existing local-image path.
      const imageSourcePath = resolvedUri.startsWith('file://')
        ? resolvedUri.substring('file://'.length)
        : resolvedUri
      imageSource = image.createImageSource(imageSourcePath)
      const imageInfo = await imageSource.getImageInfo()
      if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
        return
      }
      const sourceWidth = Math.max(1, imageInfo.size.width)
      const sourceHeight = Math.max(1, imageInfo.size.height)
      const maxEdge = Math.max(1, this.decodeMaxEdge)
      const scale = Math.min(1, maxEdge / Math.max(sourceWidth, sourceHeight))
      const desiredWidth = Math.max(1, Math.round(sourceWidth * scale))
      const desiredHeight = Math.max(1, Math.round(sourceHeight * scale))
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
      this.pixelMapLease = lease
      this.pixelMap = lease.pixelMap
      this.failedSignature = ''
    } catch (_error) {
      if (!this.disposed && this.sourceSignature === signature && this.decodeGeneration === generation) {
        this.failedSignature = signature
        this.onError()
      }
    } finally {
      if (imageSource !== undefined) {
        try {
          await imageSource.release()
        } catch (_error) {
          console.warn('[CachedCoverImage] step=image_source_release_failed')
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
  ): Promise<void> {
    const nextSignature = this.createSourceSignature(
      nextUri,
      nextSourceRuntimeId,
      nextSourceImageId,
      nextSourceKind,
      nextRemoteServerId,
    )
    if (this.sourceSignature === nextSignature && this.pixelMap !== undefined) {
      return
    }
    this.decodeGeneration += 1
    const generation = this.decodeGeneration
    this.sourceSignature = nextSignature
    this.loading = false
    this.loadingSignature = ''
    this.loadingGeneration = 0
    await this.releasePixelMap()
    if (!this.disposed && this.sourceSignature === nextSignature && this.decodeGeneration === generation) {
      await this.decodeImage(
        nextUri,
        nextSignature,
        generation,
        nextSourceRuntimeId ?? '',
        nextSourceImageId ?? '',
        nextSourceKind,
        nextRemoteServerId ?? '',
      )
    }
  }

  @Monitor('uri', 'sourceRuntimeId', 'sourceImageId', 'sourceKind', 'remoteServerId', 'decodeMaxEdge')
  onSourceChanged(): void {
    this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId, this.sourceKind, this.remoteServerId)
  }

  build() {
    Stack() {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(this.objectFit)
          .interpolation(ImageInterpolation.Medium)
      }
    }
    .width('100%')
    .height('100%')
    .onAppear(() => {
      this.disposed = false
      this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId, this.sourceKind, this.remoteServerId)
    })
  }
}

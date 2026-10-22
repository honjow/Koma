import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import {
  configureReaderRemoteImageCache,
  fetchAndCacheSourceRuntimeRemoteImage,
} from '../model/ReaderPageSourceAdapter'
import { ComicSourceKind } from '../model/ComicModels'
import { resolveCachedCoverImage } from '../model/CoverImageCacheService'
import { waitForRestoredLocalLibraryFolderAccess } from '../model/LocalLibraryFolderAccessService'
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
  sourceMangaUrl?: string,
): string {
  const key = `${uri ?? ''}::${(sourceRuntimeId ?? '').trim()}::${(sourceImageId ?? '').trim()}::${sourceKind ?? ''}::${(remoteServerId ?? '').trim()}`
  const route = sourceMangaUrl?.trim() ?? ''
  return route.length === 0 ? key : `${key}::${route}`
}

@ComponentV2
export struct CachedCoverImage {
  @Param uri: string = ''
  @Param objectFit: ImageFit = ImageFit.Cover
  @Param sourceRuntimeId: string = ''
  @Param sourceImageId: string = ''
  @Param sourceMangaUrl: string = ''
  @Param sourceKind: ComicSourceKind | undefined = undefined
  @Param remoteServerId: string = ''
  @Param decodeMaxEdge: number = COVER_DECODE_MAX_EDGE
  @Event onError: () => void = () => {}
  @Local private pixelMap: image.PixelMap | undefined = undefined
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

  aboutToAppear(): void {
    // aboutToAppear runs before the first build. Starting here lets the synchronous memory-cache
    // lease paint on the initial frame instead of waiting for the post-render onAppear callback.
    this.disposed = false
    void this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId, this.sourceKind, this.remoteServerId, this.sourceMangaUrl)
  }

  private async releasePixelMap(): Promise<void> {
    this.pixelMap = undefined
    this.displayedSignature = ''
    const lease = this.pixelMapLease
    this.pixelMapLease = undefined
    await coverPixelMapMemoryCache.release(lease)
  }

  private async replacePixelMap(
    lease: CoverPixelMapLease,
    signature: string,
  ): Promise<void> {
    // Render the new map before giving the prior lease back to the cache. The
    // cache may release an unindexed, unleased map immediately, so reversing
    // this order would leave Image bound to a released PixelMap (and visibly
    // flash blank) between detail-list cover identities.
    const previousLease = this.pixelMapLease
    this.pixelMapLease = lease
    this.pixelMap = lease.pixelMap
    this.displayedSignature = signature
    this.failedSignature = ''
    await coverPixelMapMemoryCache.release(previousLease)
  }

  private createSourceSignature(
    uri: string,
    sourceRuntimeId: string | undefined,
    sourceImageId: string | undefined,
    sourceKind: ComicSourceKind | undefined,
    remoteServerId: string | undefined,
    sourceMangaUrl: string | undefined,
  ): string {
    return `${cachedCoverFailureKey(uri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl)}::${Math.max(1, Math.round(this.decodeMaxEdge))}`
  }

  private async resolveImageUri(
    uri: string,
    sourceRuntimeId: string,
    sourceImageId: string,
    sourceKind: ComicSourceKind | undefined,
    remoteServerId: string,
    sourceMangaUrl: string,
  ): Promise<string> {
    const context = getContext(this) as common.UIAbilityContext
    if (sourceRuntimeId.trim().length > 0) {
      configureReaderRemoteImageCache(context.cacheDir)
      return fetchAndCacheSourceRuntimeRemoteImage(sourceRuntimeId, uri, sourceImageId, sourceMangaUrl)
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
        await this.replacePixelMap(cachedLease, signature)
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
    try {
      const resolvedUri = await this.resolveImageUri(uri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl)
      if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
        return
      }
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
        this.onError()
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

  @Monitor('uri', 'sourceRuntimeId', 'sourceImageId', 'sourceKind', 'remoteServerId', 'sourceMangaUrl', 'decodeMaxEdge')
  onSourceChanged(): void {
    this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId, this.sourceKind, this.remoteServerId, this.sourceMangaUrl)
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
  }
}

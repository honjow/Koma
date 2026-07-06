import { common } from '@kit.AbilityKit'
import { image } from '@kit.ImageKit'
import {
  configureReaderRemoteImageCache,
  fetchAndCacheReaderRemoteImage,
  fetchAndCacheSourceRuntimeRemoteImage,
} from '../model/ReaderPageSourceAdapter'

@ComponentV2
export struct CachedCoverImage {
  @Param uri: string = ''
  @Param objectFit: ImageFit = ImageFit.Cover
  @Param sourceRuntimeId: string = ''
  @Param sourceImageId: string = ''
  @Event onError: () => void = () => {}
  @Local private pixelMap: image.PixelMap | undefined = undefined
  @Local private loading: boolean = false
  @Local private failedSignature: string = ''
  private disposed: boolean = false
  private sourceUri: string = ''
  private sourceSignature: string = ''
  private decodeGeneration: number = 0

  private isRemoteUri(uri: string): boolean {
    const normalized = uri.toLocaleLowerCase()
    return normalized.startsWith('http://') || normalized.startsWith('https://')
  }

  private async releasePixelMap(): Promise<void> {
    const pixelMap = this.pixelMap
    if (pixelMap === undefined) {
      return
    }
    this.pixelMap = undefined
    try {
      await pixelMap.release()
    } catch (_error) {
      console.warn('[CachedCoverImage] step=release_failed')
    }
  }

  private createSourceSignature(uri: string, sourceRuntimeId: string | undefined, sourceImageId: string | undefined): string {
    return `${uri}::${(sourceRuntimeId ?? '').trim()}::${(sourceImageId ?? '').trim()}`
  }

  private async resolveImageUri(uri: string, sourceRuntimeId: string, sourceImageId: string): Promise<string> {
    if (!this.isRemoteUri(uri)) {
      return uri
    }
    const context = getContext(this) as common.UIAbilityContext
    configureReaderRemoteImageCache(context.cacheDir)
    if (sourceRuntimeId.trim().length > 0) {
      return fetchAndCacheSourceRuntimeRemoteImage(sourceRuntimeId, uri, sourceImageId)
    }
    return fetchAndCacheReaderRemoteImage(uri)
  }

  private async decodeImage(uri: string, signature: string, sourceRuntimeId: string, sourceImageId: string): Promise<void> {
    if (uri.length === 0 || this.loading || this.failedSignature === signature) {
      return
    }
    const generation = this.decodeGeneration
    this.loading = true
    let imageSource: image.ImageSource | undefined = undefined
    try {
      const resolvedUri = await this.resolveImageUri(uri, sourceRuntimeId, sourceImageId)
      imageSource = image.createImageSource(resolvedUri)
      const pixelMap = await imageSource.createPixelMap()
      if (this.disposed || this.sourceSignature !== signature || this.decodeGeneration !== generation) {
        await pixelMap.release()
        return
      }
      this.pixelMap = pixelMap
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
      if (!this.disposed && this.sourceSignature === signature && this.decodeGeneration === generation) {
        this.loading = false
      }
    }
  }

  private async handleSourceChanged(nextUri: string, nextSourceRuntimeId: string | undefined, nextSourceImageId: string | undefined): Promise<void> {
    const nextSignature = this.createSourceSignature(nextUri, nextSourceRuntimeId, nextSourceImageId)
    if (this.sourceSignature === nextSignature && this.pixelMap !== undefined) {
      return
    }
    this.decodeGeneration += 1
    this.sourceUri = nextUri
    this.sourceSignature = nextSignature
    this.loading = false
    await this.releasePixelMap()
    if (!this.disposed) {
      await this.decodeImage(nextUri, nextSignature, nextSourceRuntimeId ?? '', nextSourceImageId ?? '')
    }
  }

  @Monitor('uri', 'sourceRuntimeId', 'sourceImageId')
  onSourceChanged(): void {
    this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId)
  }

  aboutToReuse(params: Record<string, ESObject>): void {
    this.handleSourceChanged(
      params.uri as string,
      params.sourceRuntimeId as string | undefined,
      params.sourceImageId as string | undefined,
    )
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
      this.handleSourceChanged(this.uri, this.sourceRuntimeId, this.sourceImageId)
    })
    .onDisAppear(() => {
      this.disposed = true
      this.decodeGeneration += 1
      this.releasePixelMap()
    })
  }
}

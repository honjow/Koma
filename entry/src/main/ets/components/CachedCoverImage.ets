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
  @Local private failedUri: string = ''
  private disposed: boolean = false
  private sourceUri: string = ''
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

  private async resolveImageUri(uri: string): Promise<string> {
    if (!this.isRemoteUri(uri)) {
      return uri
    }
    const context = getContext(this) as common.UIAbilityContext
    configureReaderRemoteImageCache(context.cacheDir)
    if (this.sourceRuntimeId.trim().length > 0) {
      return fetchAndCacheSourceRuntimeRemoteImage(this.sourceRuntimeId, uri, this.sourceImageId)
    }
    return fetchAndCacheReaderRemoteImage(uri)
  }

  private async decodeImage(uri: string): Promise<void> {
    if (uri.length === 0 || this.loading || this.failedUri === uri) {
      return
    }
    const generation = this.decodeGeneration
    this.loading = true
    let imageSource: image.ImageSource | undefined = undefined
    try {
      const resolvedUri = await this.resolveImageUri(uri)
      imageSource = image.createImageSource(resolvedUri)
      const pixelMap = await imageSource.createPixelMap()
      if (this.disposed || this.sourceUri !== uri || this.decodeGeneration !== generation) {
        await pixelMap.release()
        return
      }
      this.pixelMap = pixelMap
      this.failedUri = ''
    } catch (_error) {
      if (!this.disposed && this.sourceUri === uri && this.decodeGeneration === generation) {
        this.failedUri = uri
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
      if (!this.disposed && this.sourceUri === uri && this.decodeGeneration === generation) {
        this.loading = false
      }
    }
  }

  private async handleUriChanged(nextUri: string): Promise<void> {
    if (this.sourceUri === nextUri && this.pixelMap !== undefined) {
      return
    }
    this.decodeGeneration += 1
    this.sourceUri = nextUri
    this.loading = false
    await this.releasePixelMap()
    if (!this.disposed) {
      await this.decodeImage(nextUri)
    }
  }

  @Monitor('uri')
  onUriChanged(): void {
    this.handleUriChanged(this.uri)
  }

  aboutToReuse(params: Record<string, ESObject>): void {
    this.handleUriChanged(params.uri as string)
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
      this.handleUriChanged(this.uri)
    })
    .onDisAppear(() => {
      this.disposed = true
      this.decodeGeneration += 1
      this.releasePixelMap()
    })
  }
}

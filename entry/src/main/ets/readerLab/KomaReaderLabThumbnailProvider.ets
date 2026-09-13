import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ReaderAsset, ReaderCancellation } from '@reader-kit/core'

/** Local, optional-reader derivatives. Original/downloaded files are never owned here. */
export class KomaReaderLabThumbnailProvider {
  private cacheDir: string
  private closed: boolean = false
  private tail: Promise<void> = Promise.resolve()

  constructor(cacheDir: string) { this.cacheDir = cacheDir }

  load(uri: string, cancellation: ReaderCancellation): Promise<ReaderAsset> {
    const request = this.tail.then((): Promise<ReaderAsset> => this.derive(uri, cancellation))
    this.tail = request.then((): void => {}, (): void => {})
    return request
  }

  close(): void { this.closed = true }

  private check(cancellation: ReaderCancellation): void {
    cancellation.check()
    if (this.closed) throw new Error('koma_thumbnail_closed')
  }

  private remove(directory: string, path: string): void {
    try { if (fs.accessSync(path)) fs.unlinkSync(path) } catch (_) {
      console.warn('[KomaReaderLabThumbnail] file_cleanup_failed')
    }
    // rmdirSync is recursive on this platform: call only after an empty-directory readback.
    try { if (fs.listFileSync(directory).length === 0) fs.rmdirSync(directory) } catch (_) {
      console.warn('[KomaReaderLabThumbnail] directory_cleanup_failed')
    }
  }

  private async derive(uri: string, cancellation: ReaderCancellation): Promise<ReaderAsset> {
    this.check(cancellation)
    const directory = fs.mkdtempSync(`${this.cacheDir}/rkit-thumbnail-XXXXXX`)
    const path = `${directory}/thumbnail.png`
    let source: image.ImageSource | undefined = undefined
    let pixels: image.PixelMap | undefined = undefined
    let packer: image.ImagePacker | undefined = undefined
    let file: fs.File | undefined = undefined
    try {
      try {
        source = image.createImageSource(uri.startsWith('file://') ? uri.substring(7) : uri)
        const info = await source.getImageInfo()
        this.check(cancellation)
        const width = info.size.width
        const height = info.size.height
        if (width <= 0 || height <= 0) throw new Error('koma_thumbnail_invalid_dimensions')
        // Keep these cover limits aligned with ReaderThumbnailRail.widthValue().
        // Crop the source window before downsampling: a full-strip 192px decode
        // would leave too few horizontal pixels for the bounded cover tile.
        const aspect = width / height
        const regionWidth = aspect > 1.4 ? Math.max(1, Math.min(width, Math.round(height * 1.4))) : width
        const regionHeight = aspect < 0.45 ? Math.max(1, Math.min(height, Math.round(width / 0.45))) : height
        const scale = Math.min(1, 192 / Math.max(regionWidth, regionHeight))
        pixels = await source.createPixelMap({
          desiredRegion: {
            x: Math.floor((width - regionWidth) / 2), y: Math.floor((height - regionHeight) / 2),
            size: { width: regionWidth, height: regionHeight },
          },
          desiredSize: {
            width: Math.max(1, Math.round(regionWidth * scale)),
            height: Math.max(1, Math.round(regionHeight * scale)),
          },
          cropAndScaleStrategy: image.CropAndScaleStrategy.CROP_FIRST,
        })
        this.check(cancellation)
        packer = image.createImagePacker()
        file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
        await packer.packToFile(pixels, file.fd, { format: 'image/png', quality: 100 })
        this.check(cancellation)
      } finally {
        // Packing must have settled before any of its inputs are released.
        if (file !== undefined) { try { fs.closeSync(file) } catch (_) {} }
        if (packer !== undefined) { try { await packer.release() } catch (_) {} }
        if (pixels !== undefined) { try { await pixels.release() } catch (_) {} }
        if (source !== undefined) { try { await source.release() } catch (_) {} }
      }
      this.check(cancellation)
      return new ReaderAsset(`file://${path}`, (): void => { this.remove(directory, path) })
    } catch (_error) {
      this.remove(directory, path)
      throw new Error('koma_thumbnail_generation_failed')
    }
  }
}

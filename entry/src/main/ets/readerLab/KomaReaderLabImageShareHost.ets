import { common } from '@kit.AbilityKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { systemShare } from '@kit.ShareKit'
import { ReaderCancellation, ReaderImageShareHost, ReaderImageSharePresentation,
  ReaderImageShareTarget } from '@reader-kit/core'
import { ReaderSystemSharePresentation } from '@reader-kit/ui'
import { KomaReaderLabAdapter } from './KomaReaderLabAdapter'

function extensionFor(mime: string): string {
  switch (mime.toLowerCase()) {
    case 'image/jpeg': return 'jpg'
    case 'image/png': return 'png'
    case 'image/gif': return 'gif'
    case 'image/webp': return 'webp'
    case 'image/bmp': return 'bmp'
    case 'image/heic': return 'heic'
    case 'image/heif': return 'heif'
    default: throw new Error('koma_lab_share_unsupported_image_format')
  }
}

class KomaReaderLabSharePresentation implements ReaderImageSharePresentation {
  private inner: ReaderSystemSharePresentation
  private path: string
  private directory: string
  private released: boolean = false

  constructor(inner: ReaderSystemSharePresentation, path: string, directory: string) {
    this.inner = inner
    this.path = path
    this.directory = directory
  }

  present(): Promise<void> { return this.inner.present() }

  release(): void {
    if (this.released) return
    this.released = true
    this.inner.release()
    try { fileIo.unlinkSync(this.path) } catch (_) { console.warn('[KomaReaderLabShare] file cleanup failed') }
    try { fileIo.rmdirSync(this.directory) } catch (_) { console.warn('[KomaReaderLabShare] directory cleanup failed') }
  }
}

/** Resolves Koma's page through its production cache and owns only a per-share copy. */
export class KomaReaderLabImageShareHost implements ReaderImageShareHost {
  private context: common.UIAbilityContext
  private adapter: KomaReaderLabAdapter

  constructor(context: common.UIAbilityContext, adapter: KomaReaderLabAdapter) {
    this.context = context
    this.adapter = adapter
  }

  async prepare(target: ReaderImageShareTarget,
    cancellation: ReaderCancellation): Promise<ReaderImageSharePresentation> {
    let source: fileIo.File | null = null
    let directory: string = ''
    let path: string = ''
    try {
      cancellation.check()
      const resolved = await this.adapter.imageShareSource(target.copy(), cancellation)
      const sourcePath = resolved.uri.startsWith('file://') ? new fileUri.FileUri(resolved.uri).path : resolved.uri
      source = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY)
      directory = fileIo.mkdtempSync(this.context.cacheDir + '/reader-share-XXXXXX')
      path = directory + '/image'
      await fileIo.copyFile(source.fd, path)
      cancellation.check()
      const decoder = image.createImageSource(path)
      let extension: string
      try { extension = extensionFor((await decoder.getImageInfo()).mimeType) }
      finally { await decoder.release() }
      cancellation.check()
      const finalPath = path + '.' + extension
      fileIo.renameSync(path, finalPath)
      path = finalPath
      const record: systemShare.SharedRecord = {
        utd: utd.getUniformDataTypeByFilenameExtension(`.${extension}`, utd.UniformDataType.IMAGE),
        uri: fileUri.getUriFromPath(path), title: resolved.title,
      }
      const presentation = new ReaderSystemSharePresentation(this.context, new systemShare.SharedData(record), {
        selectionMode: systemShare.SelectionMode.SINGLE, previewMode: systemShare.SharePreviewMode.DETAIL,
      })
      return new KomaReaderLabSharePresentation(presentation, path, directory)
    } catch (_) {
      if (path.length > 0) {
        try { fileIo.unlinkSync(path) } catch (_) {}
      }
      if (directory.length > 0) {
        try { fileIo.rmdirSync(directory) } catch (_) {}
      }
      throw new Error('koma_lab_share_prepare_failed')
    } finally {
      if (source !== null) {
        try { fileIo.closeSync(source) } catch (_) { console.warn('[KomaReaderLabShare] source close failed') }
      }
    }
  }
}

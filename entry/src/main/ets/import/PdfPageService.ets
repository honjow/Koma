import { taskpool } from '@kit.ArkTS'
import { pdfService } from '@kit.PDFKit'
import { image } from '@kit.ImageKit'

export interface PdfPageReference { path: string; index: number }
export interface PdfBookmark { title: string; pageIndex: number }

/** A PDF remains the source of truth. Rendered pages are disposable reader cache entries. */
export function pdfPageUri(path: string, index: number): string {
  return `koma-pdf-page://${encodeURIComponent(path)}/${index}`
}

export function parsePdfPageUri(uri: string): PdfPageReference | undefined {
  const match = /^koma-pdf-page:\/\/([^/]+)\/(\d+)$/.exec(uri)
  if (match === null) return undefined
  try {
    const index = Number(match[2])
    const path = decodeURIComponent(match[1])
    if (!path.startsWith('/') || !Number.isSafeInteger(index) || index < 0) return undefined
    return { path, index }
  } catch (_error) { return undefined }
}

@Concurrent
function inspectPdfWorker(path: string): number {
  const document = new pdfService.PdfDocument()
  const result = document.loadDocument(path)
  if (result !== pdfService.ParseResult.PARSE_SUCCESS) throw new Error(`pdf_open_failed_${result}`)
  try {
    const count = document.getPageCount()
    if (!Number.isSafeInteger(count) || count < 1) throw new Error('pdf_empty')
    return count
  } finally { document.releaseDocument() }
}

@Concurrent
async function renderPdfPageWorker(path: string, index: number): Promise<ArrayBuffer> {
  const document = new pdfService.PdfDocument()
  const result = document.loadDocument(path)
  if (result !== pdfService.ParseResult.PARSE_SUCCESS) throw new Error(`pdf_open_failed_${result}`)
  let pixels: image.PixelMap | undefined
  let packer: image.ImagePacker | undefined
  try {
    if (index < 0 || index >= document.getPageCount()) throw new Error('pdf_page_out_of_range')
    const page = document.getPage(index)
    const width = page.getWidth()
    const height = page.getHeight()
    if (!(width > 0) || !(height > 0)) throw new Error('pdf_page_invalid_size')
    const scale = Math.min(2048 / width, 3072 / height)
    const outputWidth = Math.max(1, Math.round(width * scale))
    const outputHeight = Math.max(1, Math.round(height * scale))
    const matrix = new pdfService.PdfMatrix()
    matrix.x = 0; matrix.y = 0; matrix.width = outputWidth; matrix.height = outputHeight; matrix.rotate = 0
    pixels = page.getAreaPixelMap(matrix, outputWidth, outputHeight, false, true)
    packer = image.createImagePacker()
    return await packer.packing(pixels, { format: 'image/jpeg', quality: 95 })
  } finally {
    if (packer !== undefined) await packer.release()
    if (pixels !== undefined) await pixels.release()
    document.releaseDocument()
  }
}

@Concurrent
function readPdfBookmarksWorker(path: string): PdfBookmark[] {
  const document = new pdfService.PdfDocument()
  if (document.loadDocument(path) !== pdfService.ParseResult.PARSE_SUCCESS) return []
  try {
    const count = document.getPageCount()
    const result: PdfBookmark[] = []
    const pending = document.getRootBookmarks().reverse()
    while (pending.length > 0) {
      const bookmark = pending.pop() as pdfService.Bookmark
      try {
        const title = bookmark.getBookmarkInfo().title.trim()
        const pageIndex = bookmark.getDestInfo().pageIndex
        if (title.length > 0 && Number.isSafeInteger(pageIndex) && pageIndex >= 0 && pageIndex < count) {
          result.push({ title, pageIndex })
        }
      } catch (_error) { /* A grouping-only bookmark can still contain usable children. */ }
      try {
        if (bookmark.hasChild()) {
          const children = bookmark.getChildren()
          for (let index = children.length - 1; index >= 0; index -= 1) pending.push(children[index])
        }
      } catch (_error) { /* Keep other usable bookmarks. */ }
    }
    return result
  } finally { document.releaseDocument() }
}

export async function inspectPdf(path: string): Promise<number> {
  return await taskpool.execute<[string], number>(inspectPdfWorker, path)
}

export async function renderPdfPage(path: string, index: number): Promise<ArrayBuffer> {
  return await taskpool.execute<[string, number], ArrayBuffer>(renderPdfPageWorker, path, index)
}

export async function readPdfBookmarks(path: string): Promise<PdfBookmark[]> {
  try { return await taskpool.execute<[string], PdfBookmark[]>(readPdfBookmarksWorker, path) }
  catch (_error) { return [] }
}

import { parseComicZipPage, readComicZipPage } from '../import/ComicZipPage'
import { nativeComicArchive } from '../import/NativeArchiveExtraction'
import { readerImagePixelSize } from '@reader-kit/core'
import { image } from '@kit.ImageKit'
import { fileUri } from '@kit.CoreFileKit'
import { taskpool } from '@kit.ArkTS'
import { ComicSourceKind, ReaderSeriesFormat } from './ComicModels'
import {
  cloneReaderSessionConfig,
  ReaderSessionConfig,
  readerSessionFormat,
} from './ReaderSessionStore'

const READER_LOCAL_FORMAT_PROBE_LIMIT: number = 6

@Concurrent
async function readReaderLocalPageSize(path: string, bytes?: ArrayBuffer): Promise<string> {
  let source: image.ImageSource | undefined = undefined
  try {
    source = bytes === undefined ? image.createImageSource(path) : image.createImageSource(bytes)
    const info = await source.getImageInfo()
    return `${info.size.width},${info.size.height}`
  } finally {
    if (source !== undefined) await source.release()
  }
}

function localReaderPagePath(uri: string): string {
  if (!uri.startsWith('file://')) return ''
  try {
    const path = uri.startsWith('file://docs/')
      ? new fileUri.FileUri(uri).path
      : decodeURIComponent(uri.substring('file://'.length))
    return path.trim().length === 0 ? '' : path
  } catch (_error) {
    return ''
  }
}

/**
 * Local imports historically retain no page dimensions. Give the existing
 * first-open format decision the same bounded evidence remote pages get:
 * inspect only a few local originals, then reuse readerSessionFormat. This
 * does not seed the session's layout: an unknown row height keeps the shared
 * reader's 0.75 placeholder until the image is actually measured.
 */
export async function readerSessionFormatForOpen(config?: ReaderSessionConfig): Promise<ReaderSeriesFormat | undefined> {
  const existing = readerSessionFormat(config)
  if (existing !== undefined) return existing
  if (config === undefined || (config.sourceKind !== ComicSourceKind.LOCAL_FOLDER &&
    config.sourceKind !== ComicSourceKind.LOCAL_ARCHIVE)) return undefined
  const pageCount = Math.min(config.pageUris.length, READER_LOCAL_FORMAT_PROBE_LIMIT)
  if (pageCount < 3) return undefined
  const widths: Array<number | undefined> = config.pageWidths === undefined ? [] : config.pageWidths.slice()
  const heights: Array<number | undefined> = config.pageHeights === undefined ? [] : config.pageHeights.slice()
  const pending: Array<Promise<void>> = []
  for (let index = 0; index < pageCount; index += 1) {
    const width = widths[index] ?? 0
    const height = heights[index] ?? 0
    if (Number.isFinite(width) && width > 0 && Number.isFinite(height) && height > 0) continue
    const uri = config.pageUris[index] ?? ''
    const zip = parseComicZipPage(uri)
    const path = localReaderPagePath(uri)
    if (zip === undefined && path.length === 0) continue
    const record = (size: string): void => {
      const values = size.split(',')
      const measuredWidth = Number(values[0])
      const measuredHeight = Number(values[1])
      if (Number.isFinite(measuredWidth) && measuredWidth > 0 &&
        Number.isFinite(measuredHeight) && measuredHeight > 0) {
        widths[index] = measuredWidth
        heights[index] = measuredHeight
      }
    }
    if (zip !== undefined) {
      // Bound the live buffers for large compressed webtoon pages.
      try {
        const header = await nativeComicArchive.readZipPrefix(zip.archive, zip.entry, 64 * 1024)
        const size = readerImagePixelSize(new Uint8Array(header))
        if (size !== undefined && size.width > 0 && size.height > 0) {
          widths[index] = size.width
          heights[index] = size.height
        } else {
          const bytes = await readComicZipPage(zip)
          record(await taskpool.execute<[string, ArrayBuffer], string>(readReaderLocalPageSize, '', bytes))
        }
      } catch (_error) {}
    } else {
      pending.push(taskpool.execute<[string], string>(readReaderLocalPageSize, path).then(record).catch((): void => {}))
    }
  }
  await Promise.all(pending)
  const probe = cloneReaderSessionConfig(config)
  probe.pageWidths = widths
  probe.pageHeights = heights
  return readerSessionFormat(probe)
}

import { convertxml } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { isSupportedImagePath, isSafeArchiveEntryPath } from './ImageSortUtils'

interface EpubNode {
  _name?: string
  _attributes?: Record<string, string>
  _elements?: EpubNode[]
}
interface EpubItem { href: string; mediaType: string; properties: string }

export interface EpubResource {
  path: string
  mediaType: string
}

export interface EpubPublication {
  covers: EpubResource[]
  readingOrder: EpubResource[]
}

export const EPUB_CONTAINER_PATH: string = 'META-INF/container.xml'
export const EPUB_LEGACY_PACKAGE_PATH: string = 'OEBPS/content.opf'

function namedElements(node: EpubNode, name: string): EpubNode[] {
  const result: EpubNode[] = []
  if (node._name?.split(':').pop() === name) result.push(node)
  node._elements?.forEach((child: EpubNode): void => { result.push(...namedElements(child, name)) })
  return result
}

function parseXml(xml: string): EpubNode {
  return new convertxml.ConvertXML().fastConvertToJSObject(xml) as EpubNode
}

/** Resolve book-relative paths, including percent encoding and ../ inside the book, never outside it. */
export function resolveEpubEntry(base: string, reference: string): string {
  const value = decodeURIComponent(reference.split('#')[0].split('?')[0]).replace(/\\/g, '/')
  if (!value || value.startsWith('/') || /^[a-z][a-z0-9+.-]*:/i.test(value)) throw new Error('Invalid EPUB entry reference')
  const parts = base.split('/').filter((part: string): boolean => part.length > 0)
  value.split('/').forEach((part: string): void => {
    if (part === '..') { if (parts.length === 0) throw new Error('EPUB entry escapes book'); parts.pop() }
    else if (part !== '.' && part.length > 0) parts.push(part)
  })
  const path = parts.join('/')
  if (!isSafeArchiveEntryPath(path)) throw new Error('Invalid EPUB entry path')
  return path
}
function parent(path: string): string { return path.includes('/') ? path.slice(0, path.lastIndexOf('/')) : '' }

export function epubPackagePath(containerXml: string | undefined): string {
  if (containerXml === undefined) return EPUB_LEGACY_PACKAGE_PATH
  const files = namedElements(parseXml(containerXml), 'rootfile')
  const rootfile = files.find((file: EpubNode): boolean =>
    file._attributes?.['media-type'] === 'application/oebps-package+xml') ?? files[0]
  return resolveEpubEntry('', rootfile?._attributes?.['full-path'] ?? '')
}

export function readEpubPackage(root: string, includeReadingOrder: boolean): EpubPublication {
  const container = `${root}/${EPUB_CONTAINER_PATH}`
  const packagePath = epubPackagePath(fs.accessSync(container) ? fs.readTextSync(container) : undefined)
  return parseEpubPackage(fs.readTextSync(`${root}/${packagePath}`), packagePath, includeReadingOrder)
}

export function parseEpubPackage(xml: string, packagePath: string, includeReadingOrder: boolean = true): EpubPublication {
  const document = parseXml(xml)
  const directory = parent(packagePath)
  const manifest = namedElements(document, 'manifest')[0]
  if (manifest === undefined) throw new Error('EPUB manifest missing')
  const items = new Map<string, EpubItem>()
  namedElements(manifest, 'item').forEach((item: EpubNode): void => {
    const attrs = item._attributes ?? {}
    if (attrs['id'] && attrs['href']) {
      items.set(attrs['id'], { href: attrs['href'], mediaType: attrs['media-type'] ?? '',
        properties: attrs['properties'] ?? '' })
    }
  })

  const covers: EpubResource[] = []
  const coverPaths = new Set<string>()
  const addCover = (href: string, mediaType: string): void => {
    try {
      const path = resolveEpubEntry(directory, href)
      if (coverPaths.has(path)) return
      covers.push({ path, mediaType })
      coverPaths.add(path)
    } catch (_error) {
      // Optional cover metadata must never prevent a valid book from importing.
    }
  }
  // EPUB 3 manifest, EPUB 2 metadata, then the legacy guide's cover page.
  items.forEach((item: EpubItem): void => {
    if (item.properties.split(/\s+/).includes('cover-image')) addCover(item.href, item.mediaType)
  })
  const metadata = namedElements(document, 'metadata')[0]
  if (metadata !== undefined) {
    namedElements(metadata, 'meta').forEach((meta: EpubNode): void => {
      if (meta._attributes?.['name']?.toLowerCase() !== 'cover') return
      const item = items.get(meta._attributes?.['content']?.trim() ?? '')
      if (item !== undefined) addCover(item.href, item.mediaType)
    })
  }
  const guide = namedElements(document, 'guide')[0]
  if (guide !== undefined) {
    namedElements(guide, 'reference').forEach((ref: EpubNode): void => {
      const attrs = ref._attributes ?? {}
      if (attrs['type']?.toLowerCase() === 'cover' && attrs['href']) addCover(attrs['href'], '')
    })
  }
  const readingOrder: EpubResource[] = []
  if (!includeReadingOrder) return { covers, readingOrder }
  const spine = namedElements(document, 'spine')[0]
  if (spine === undefined) throw new Error('EPUB reading order missing')
  namedElements(spine, 'itemref').forEach((ref: EpubNode): void => {
    if (ref._attributes?.['linear']?.toLowerCase() === 'no') return
    const item = items.get(ref._attributes?.['idref'] ?? '')
    if (item === undefined) throw new Error('EPUB reading order references a missing item')
    readingOrder.push({ path: resolveEpubEntry(directory, item.href), mediaType: item.mediaType })
  })
  return { covers, readingOrder }
}

export function epubImageReferences(xml: string, documentPath: string, strict: boolean): string[] {
  const images: string[] = []
  const visit = (node: EpubNode): void => {
    const tag = node._name?.split(':').pop()
    const attrs = node._attributes ?? {}
    const source = tag === 'img' ? attrs['src'] : tag === 'image' ? attrs['xlink:href'] ?? attrs['href'] : undefined
    if (source && !/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(source)) {
      try {
        const path = resolveEpubEntry(parent(documentPath), source)
        if (isSupportedImagePath(path)) images.push(path)
      } catch (error) {
        if (strict) throw error as Error
      }
    }
    node._elements?.forEach(visit)
  }
  visit(parseXml(xml))
  return images
}

export function epubIsPageDocument(resource: EpubResource): boolean {
  return resource.mediaType === 'application/xhtml+xml' || resource.mediaType === 'text/html'
}

/** OPF spine -> XHTML document order -> img / SVG image references.
 * Non-linear documents are auxiliary links, not sequential reading pages; preserve
 * intentional repeated image references in the remaining linear documents.
 */
export function readEpubImages(root: string): string[] {
  const publication = readEpubPackage(root, true)
  const result: string[] = []
  publication.readingOrder.forEach((item: EpubResource): void => {
    const path = item.path
    if (item.mediaType.startsWith('image/') && isSupportedImagePath(path)) { result.push(path); return }
    if (!epubIsPageDocument(item)) return
    epubImageReferences(fs.readTextSync(`${root}/${path}`), path, true).forEach((image: string): void => {
      if (!fs.accessSync(`${root}/${image}`)) throw new Error('EPUB page image missing')
      result.push(image)
    })
  })
  if (result.length === 0) throw new Error('EPUB contains no supported image pages')
  return result
}

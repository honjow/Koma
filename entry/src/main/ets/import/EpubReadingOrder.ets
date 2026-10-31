import { convertxml } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { isSupportedImagePath, isSafeArchiveEntryPath } from './ImageSortUtils'

interface EpubNode {
  _name?: string
  _attributes?: Record<string, string>
  _elements?: EpubNode[]
}
interface EpubItem { href: string; mediaType: string }

function namedElements(node: EpubNode, name: string): EpubNode[] {
  const result: EpubNode[] = []
  if (node._name?.split(':').pop() === name) result.push(node)
  node._elements?.forEach((child: EpubNode): void => { result.push(...namedElements(child, name)) })
  return result
}

function readXml(path: string): EpubNode {
  return new convertxml.ConvertXML().fastConvertToJSObject(fs.readTextSync(path)) as EpubNode
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

/** Mihon EpubReader: OPF spine -> XHTML document order -> img / SVG image references.
 * Never natural-sort the result or append unreferenced covers/thumbnails from the archive.
 */
export function readEpubImages(root: string): string[] {
  let packagePath = 'OEBPS/content.opf'
  if (fs.accessSync(`${root}/META-INF/container.xml`)) {
    const rootfile = namedElements(readXml(`${root}/META-INF/container.xml`), 'rootfile')[0]
    packagePath = resolveEpubEntry('', rootfile?._attributes?.['full-path'] ?? '')
  }
  const document = readXml(`${root}/${packagePath}`)
  const items = new Map<string, EpubItem>()
  const manifest = namedElements(document, 'manifest')[0]
  if (manifest === undefined) throw new Error('EPUB manifest missing')
  namedElements(manifest, 'item').forEach((item: EpubNode): void => {
    const attrs = item._attributes ?? {}
    if (attrs['id'] && attrs['href']) items.set(attrs['id'], { href: attrs['href'], mediaType: attrs['media-type'] ?? '' })
  })
  const spine = namedElements(document, 'spine')[0]
  if (spine === undefined) throw new Error('EPUB reading order missing')
  const result: string[] = []
  namedElements(spine, 'itemref').forEach((ref: EpubNode): void => {
    const item = items.get(ref._attributes?.['idref'] ?? '')
    if (item === undefined) throw new Error('EPUB reading order references a missing item')
    const path = resolveEpubEntry(parent(packagePath), item.href)
    if (item.mediaType.startsWith('image/') && isSupportedImagePath(path)) { result.push(path); return }
    if (item.mediaType !== 'application/xhtml+xml' && item.mediaType !== 'text/html') return
    const page = readXml(`${root}/${path}`)
    const visit = (node: EpubNode): void => {
      const tag = node._name?.split(':').pop()
      const attrs = node._attributes ?? {}
      const source = tag === 'img' ? attrs['src'] : tag === 'image' ? attrs['xlink:href'] ?? attrs['href'] : undefined
      if (source && !/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(source)) {
        const image = resolveEpubEntry(parent(path), source)
        if (isSupportedImagePath(image)) {
          if (!fs.accessSync(`${root}/${image}`)) throw new Error('EPUB page image missing')
          result.push(image)
        }
      }
      node._elements?.forEach(visit)
    }
    visit(page)
  })
  if (result.length === 0) throw new Error('EPUB contains no supported image pages')
  return result
}

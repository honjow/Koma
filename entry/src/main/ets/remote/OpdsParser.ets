import {
  OPDS_ACQUISITION_REL_PREFIX,
  OPDS_SUPPORTED_ACQUISITION_MIME_TYPES,
  OpdsAcquisitionStatus,
  OpdsLink,
  OpdsLinkKind,
  OpdsNavigationItem,
  OpdsParseResult,
  OpdsPublication,
  OpdsVersion,
  createEmptyOpdsParseResult,
} from './OpdsModels'

interface Opds1Entry {
  id?: string
  title: string
  summary?: string
  author?: string
  links: OpdsLink[]
}

interface XmlTag {
  name: string
  attrs: Record<string, string>
  body: string
}

export function parseOpdsCatalog(source: string, feedUrl: string, contentType?: string): OpdsParseResult {
  const trimmed = source.trim()
  if (contentType !== undefined && contentType.toLocaleLowerCase().indexOf('json') >= 0) {
    return parseOpds2Catalog(trimmed, feedUrl)
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return parseOpds2Catalog(trimmed, feedUrl)
  }
  return parseOpds1Catalog(trimmed, feedUrl)
}

export function parseOpds1Catalog(xml: string, feedUrl: string): OpdsParseResult {
  const result = createEmptyOpdsParseResult(OpdsVersion.OPDS_1, feedUrl, readFirstXmlText(xml, 'title'))
  result.links = readXmlLinks(xml, feedUrl)

  const entries = readXmlBlocks(xml, 'entry').map((entryXml: string): Opds1Entry => {
    return {
      id: readFirstXmlText(entryXml, 'id'),
      title: readFirstXmlText(entryXml, 'title') ?? 'Untitled',
      summary: readFirstXmlText(entryXml, 'summary') ?? readFirstXmlText(entryXml, 'content'),
      author: readFirstXmlText(readFirstXmlBlock(entryXml, 'author') ?? '', 'name'),
      links: readXmlLinks(entryXml, feedUrl),
    }
  })

  entries.forEach((entry: Opds1Entry, index: number) => {
    const acquisitionLinks = entry.links.filter((link: OpdsLink) => link.kind === OpdsLinkKind.ACQUISITION)
    const unsupportedLinks = entry.links.filter((link: OpdsLink) => link.kind === OpdsLinkKind.UNSUPPORTED)
    if (acquisitionLinks.length > 0 || unsupportedLinks.length > 0) {
      result.publications.push(createPublication(entry.id ?? entry.title, entry.title, entry.summary, entry.author, entry.links))
    } else {
      const navigationLink = entry.links.find((link: OpdsLink) => link.kind === OpdsLinkKind.NAVIGATION || link.kind === OpdsLinkKind.ALTERNATE)
      if (navigationLink !== undefined) {
        result.navigation.push({
          id: entry.id ?? `navigation-${index}`,
          title: entry.title,
          href: navigationLink.href,
          type: navigationLink.type,
        })
      }
    }
  })

  return result
}

export function parseOpds2Catalog(json: string, feedUrl: string): OpdsParseResult {
  const parsed = JSON.parse(json) as Record<string, any>
  const metadata = readRecord(parsed['metadata'])
  const result = createEmptyOpdsParseResult(OpdsVersion.OPDS_2, feedUrl, readString(metadata['title']))

  result.links = readOpds2Links(parsed['links'], feedUrl)
  readArray(parsed['navigation']).forEach((item: any, index: number) => {
    const navigation = readRecord(item)
    const href = readString(navigation['href'])
    if (href !== undefined && href.length > 0) {
      result.navigation.push({
        id: readString(navigation['identifier']) ?? readString(navigation['title']) ?? `navigation-${index}`,
        title: readString(navigation['title']) ?? href,
        href: resolveOpdsHref(feedUrl, href),
        type: readString(navigation['type']),
      })
    }
  })

  readArray(parsed['publications']).forEach((item: any, index: number) => {
    const publication = readRecord(item)
    const publicationMetadata = readRecord(publication['metadata'])
    const title = readString(publicationMetadata['title']) ?? readString(publication['title']) ?? 'Untitled'
    const links = readOpds2Links(publication['links'], feedUrl)
      .concat(readOpds2Images(publication['images'], feedUrl))
    result.publications.push(createPublication(
      readString(publicationMetadata['identifier']) ?? readString(publication['href']) ?? `publication-${index}`,
      title,
      readString(publicationMetadata['description']) ?? readString(publicationMetadata['subtitle']),
      readOpds2Author(publicationMetadata['author']),
      links
    ))
  })

  return result
}

export function resolveOpdsHref(baseUrl: string, href: string): string {
  try {
    return new URL(href, baseUrl).toString()
  } catch (error) {
    return href
  }
}

export function classifyOpdsLink(rel?: string, type?: string, href?: string): OpdsLinkKind {
  const normalizedRel = normalizeRel(rel)
  if (normalizedRel.indexOf('thumbnail') >= 0) {
    return OpdsLinkKind.THUMBNAIL
  }
  if (normalizedRel.indexOf('image') >= 0 || normalizedRel.indexOf('cover') >= 0) {
    return OpdsLinkKind.IMAGE
  }
  if (isUnsupportedOpdsFlow(normalizedRel)) {
    return OpdsLinkKind.UNSUPPORTED
  }
  if (isAcquisitionRel(normalizedRel)) {
    return isSupportedOpdsAcquisition(type, href) ? OpdsLinkKind.ACQUISITION : OpdsLinkKind.UNSUPPORTED
  }
  if (normalizedRel === 'self') {
    return OpdsLinkKind.SELF
  }
  if (normalizedRel === 'next') {
    return OpdsLinkKind.NEXT
  }
  if (normalizedRel === 'previous' || normalizedRel === 'prev') {
    return OpdsLinkKind.PREVIOUS
  }
  if (normalizedRel === 'alternate' || normalizedRel.length === 0) {
    return OpdsLinkKind.ALTERNATE
  }
  return OpdsLinkKind.NAVIGATION
}

export function isSupportedOpdsAcquisition(type?: string, href?: string): boolean {
  const normalizedType = type === undefined ? '' : type.toLocaleLowerCase().split(';')[0].trim()
  if (OPDS_SUPPORTED_ACQUISITION_MIME_TYPES.indexOf(normalizedType) >= 0) {
    return true
  }
  const normalizedHref = href === undefined ? '' : href.toLocaleLowerCase().split('?')[0].split('#')[0]
  return normalizedHref.endsWith('.cbz') || normalizedHref.endsWith('.zip')
}

export function isUnsupportedOpdsFlow(rel?: string): boolean {
  const normalizedRel = normalizeRel(rel)
  return normalizedRel.indexOf('buy') >= 0 ||
    normalizedRel.indexOf('borrow') >= 0 ||
    normalizedRel.indexOf('subscribe') >= 0
}

function createPublication(
  id: string,
  title: string,
  summary: string | undefined,
  author: string | undefined,
  links: OpdsLink[]
): OpdsPublication {
  return {
    id,
    title,
    summary,
    author,
    acquisitionLinks: links.filter((link: OpdsLink) => link.kind === OpdsLinkKind.ACQUISITION),
    unsupportedLinks: links.filter((link: OpdsLink) => link.kind === OpdsLinkKind.UNSUPPORTED),
    imageLinks: links.filter((link: OpdsLink) => link.kind === OpdsLinkKind.IMAGE),
    thumbnailLinks: links.filter((link: OpdsLink) => link.kind === OpdsLinkKind.THUMBNAIL),
    links,
  }
}

function readXmlLinks(xml: string, feedUrl: string): OpdsLink[] {
  return readXmlSelfClosingTags(xml, 'link').map((tag: XmlTag): OpdsLink => {
    const rel = tag.attrs['rel']
    const type = tag.attrs['type']
    const href = resolveOpdsHref(feedUrl, tag.attrs['href'] ?? '')
    const kind = classifyOpdsLink(rel, type, href)
    return {
      href,
      rel,
      type,
      title: tag.attrs['title'],
      kind,
      acquisitionStatus: readAcquisitionStatus(kind, rel, type, href),
    }
  })
}

function readOpds2Links(value: any, feedUrl: string): OpdsLink[] {
  return readArray(value).map((item: any): OpdsLink => {
    const link = readRecord(item)
    const rel = readRelValue(link['rel'])
    const type = readString(link['type']) ?? readString(link['encodingFormat'])
    const href = resolveOpdsHref(feedUrl, readString(link['href']) ?? '')
    const kind = classifyOpdsLink(rel, type, href)
    return {
      href,
      rel,
      type,
      title: readString(link['title']),
      kind,
      acquisitionStatus: readAcquisitionStatus(kind, rel, type, href),
    }
  })
}

function readOpds2Images(value: any, feedUrl: string): OpdsLink[] {
  return readArray(value).map((item: any): OpdsLink => {
    if (typeof item === 'string') {
      return {
        href: resolveOpdsHref(feedUrl, item),
        rel: 'cover',
        kind: OpdsLinkKind.IMAGE,
      }
    }
    const image = readRecord(item)
    const href = resolveOpdsHref(feedUrl, readString(image['href']) ?? '')
    const rel = readRelValue(image['rel']) ?? 'cover'
    const type = readString(image['type'])
    const kind = classifyOpdsLink(rel, type, href)
    return {
      href,
      rel,
      type,
      title: readString(image['title']),
      kind,
    }
  })
}

function readAcquisitionStatus(kind: OpdsLinkKind, rel?: string, type?: string, href?: string): OpdsAcquisitionStatus | undefined {
  if (kind === OpdsLinkKind.ACQUISITION) {
    return OpdsAcquisitionStatus.SUPPORTED
  }
  if (!isAcquisitionRel(normalizeRel(rel)) && !isUnsupportedOpdsFlow(rel)) {
    return undefined
  }
  if (isUnsupportedOpdsFlow(rel)) {
    return OpdsAcquisitionStatus.UNSUPPORTED_FLOW
  }
  return isSupportedOpdsAcquisition(type, href) ? OpdsAcquisitionStatus.SUPPORTED : OpdsAcquisitionStatus.UNSUPPORTED_TYPE
}

function isAcquisitionRel(rel: string): boolean {
  return rel === 'acquisition' || rel.indexOf(OPDS_ACQUISITION_REL_PREFIX) >= 0
}

function normalizeRel(rel?: string): string {
  return rel === undefined ? '' : rel.toLocaleLowerCase().trim()
}

function readRelValue(value: any): string | undefined {
  if (Array.isArray(value)) {
    return value.join(' ')
  }
  return readString(value)
}

function readOpds2Author(value: any): string | undefined {
  if (typeof value === 'string') {
    return value
  }
  if (Array.isArray(value)) {
    const names = value.map((item: any): string | undefined => readString(readRecord(item)['name'])).filter((name: string | undefined) => name !== undefined) as string[]
    return names.length === 0 ? undefined : names.join(', ')
  }
  return readString(readRecord(value)['name'])
}

function readString(value: any): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function readRecord(value: any): Record<string, any> {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, any> : {}
}

function readArray(value: any): any[] {
  return Array.isArray(value) ? value : []
}

function readFirstXmlBlock(xml: string, tagName: string): string | undefined {
  const blocks = readXmlBlocks(xml, tagName)
  return blocks.length === 0 ? undefined : blocks[0]
}

function readXmlBlocks(xml: string, tagName: string): string[] {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z0-9_-]+:)?${tagName}>`, 'gi')
  const blocks: string[] = []
  let match = pattern.exec(xml)
  while (match !== null) {
    blocks.push(match[1])
    match = pattern.exec(xml)
  }
  return blocks
}

function readFirstXmlText(xml: string, tagName: string): string | undefined {
  const block = readFirstXmlBlock(xml, tagName)
  if (block === undefined) {
    return undefined
  }
  const text = decodeXmlEntities(block.replace(/<[^>]+>/g, '').trim())
  return text.length === 0 ? undefined : text
}

function readXmlSelfClosingTags(xml: string, tagName: string): XmlTag[] {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b([^>]*)\\/?\\s*>`, 'gi')
  const tags: XmlTag[] = []
  let match = pattern.exec(xml)
  while (match !== null) {
    tags.push({
      name: tagName,
      attrs: readXmlAttributes(match[1]),
      body: '',
    })
    match = pattern.exec(xml)
  }
  return tags
}

function readXmlAttributes(source: string): Record<string, string> {
  const attrs: Record<string, string> = {}
  const pattern = /([A-Za-z_:][A-Za-z0-9_.:-]*)\s*=\s*(['"])(.*?)\2/g
  let match = pattern.exec(source)
  while (match !== null) {
    attrs[stripXmlPrefix(match[1])] = decodeXmlEntities(match[3])
    match = pattern.exec(source)
  }
  return attrs
}

function stripXmlPrefix(name: string): string {
  const index = name.indexOf(':')
  return index < 0 ? name : name.substring(index + 1)
}

function decodeXmlEntities(value: string): string {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, '\'')
}

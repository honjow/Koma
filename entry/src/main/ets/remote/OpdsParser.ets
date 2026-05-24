import {
  OPDS_ACQUISITION_REL_PREFIX,
  OPDS_SUPPORTED_ACQUISITION_MIME_TYPES,
  OpdsAcquisitionDto,
  OpdsAcquisitionStatus,
  OpdsBookDto,
  OpdsCatalogDto,
  OpdsImageDto,
  OpdsLink,
  OpdsLinkKind,
  OpdsParseResult,
  OpdsPublication,
  OpdsPublicationGroup,
  OpdsVersion,
  createEmptyOpdsParseResult,
} from './OpdsModels'

export interface OpdsHeaders {
  authorization?: string
  accept?: string
  contentType?: string
}

export interface OpdsHttpRequest {
  method: 'GET'
  url: string
  headers: OpdsHeaders
}

export interface OpdsHttpResponse {
  status: number
  body: string
  contentType?: string
}

export interface OpdsHttpAdapter {
  request(request: OpdsHttpRequest): Promise<OpdsHttpResponse>
}

export interface OpdsClientOptions {
  rootUrl: string
  authorization?: string
  http?: OpdsHttpAdapter
}

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

export function normalizeOpdsRootUrl(rootUrl: string): string {
  return rootUrl.trim()
}

export function buildOpdsHeaders(authorization?: string, accept: string = 'application/opds+json, application/atom+xml, application/xml, text/xml, application/json'): OpdsHeaders {
  const headers: OpdsHeaders = { accept } as OpdsHeaders
  if (authorization !== undefined && authorization.length > 0) {
    headers.authorization = authorization
  }
  return headers
}

export function opdsHeadersToHttpHeaderObject(headers: OpdsHeaders): Object {
  const entries: string[] = []
  if (headers.authorization !== undefined) {
    entries.push(`"Authorization":${JSON.stringify(headers.authorization)}`)
  }
  if (headers.accept !== undefined) {
    entries.push(`"Accept":${JSON.stringify(headers.accept)}`)
  }
  if (headers.contentType !== undefined) {
    entries.push(`"Content-Type":${JSON.stringify(headers.contentType)}`)
  }
  return JSON.parse(`{${entries.join(',')}}`) as Object
}

export function parseOpdsPublicationImages(source: string, feedUrl: string, contentType?: string): OpdsImageDto[] {
  const trimmed = source.trim()
  if ((contentType !== undefined && contentType.toLocaleLowerCase().indexOf('json') >= 0) || trimmed.startsWith('{')) {
    return readOpds2ManifestImages(trimmed, feedUrl)
  }
  const result = parseOpds1Catalog(trimmed, feedUrl)
  const images: OpdsImageDto[] = []
  result.publications.forEach((publication: OpdsPublication) => {
    images.push(...mapOpdsPublicationToImages(publication))
  })
  return images
}

export class OpdsClient {
  private rootUrl: string
  private authorization?: string
  private http?: OpdsHttpAdapter

  constructor(options: OpdsClientOptions) {
    this.rootUrl = normalizeOpdsRootUrl(options.rootUrl)
    this.authorization = options.authorization
    this.http = options.http
  }

  getRootUrl(): string {
    return this.rootUrl
  }

  getUrlPrefix(): string {
    const origin = readOpdsUrlOrigin(this.rootUrl)
    return origin.length === 0 ? this.rootUrl : origin
  }

  buildHeaders(accept?: string): OpdsHeaders {
    return buildOpdsHeaders(this.authorization, accept)
  }

  async fetchCatalog(url: string = this.rootUrl): Promise<OpdsParseResult> {
    const response = await this.send({
      method: 'GET',
      url,
      headers: this.buildHeaders(),
    })
    return parseOpdsCatalog(response.body, url, response.contentType)
  }

  async fetchPublicationImages(url: string): Promise<OpdsImageDto[]> {
    const response = await this.send({
      method: 'GET',
      url,
      headers: this.buildHeaders('application/divina+json, application/webpub+json, application/json, application/opds+json, image/*'),
    })
    return parseOpdsPublicationImages(response.body, url, response.contentType)
  }

  private async send(request: OpdsHttpRequest): Promise<OpdsHttpResponse> {
    if (this.http === undefined) {
      throw new Error('OpdsHttpAdapter is required for network requests')
    }
    const response = await this.http.request(request)
    if (response.status < 200 || response.status >= 300) {
      throw new Error(`OPDS request failed with status ${response.status}`)
    }
    return response
  }
}

export function parseOpds1Catalog(xml: string, feedUrl: string): OpdsParseResult {
  const result = createEmptyOpdsParseResult(OpdsVersion.OPDS_1, feedUrl, readFirstXmlText(xml, 'title'))
  result.links = readXmlLinks(stripXmlBlocks(xml, 'entry'), feedUrl)

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
  const parsed = JSON.parse(json) as Record<string, Object>
  const metadata = readRecord(parsed['metadata'])
  const result = createEmptyOpdsParseResult(OpdsVersion.OPDS_2, feedUrl, readString(metadata['title']))

  result.links = readOpds2Links(parsed['links'], feedUrl)
  readArray(parsed['navigation']).forEach((item: Object, index: number) => {
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

  readArray(parsed['publications']).forEach((item: Object, index: number) => {
    result.publications.push(readOpds2Publication(item, feedUrl, `publication-${index}`))
  })

  readArray(parsed['groups']).forEach((item: Object, index: number) => {
    const group = readOpds2Group(item, feedUrl, `group-${index}`)
    result.groups.push(group)
    result.navigation = result.navigation.concat(group.navigation)
    result.publications = result.publications.concat(group.publications)
  })

  return result
}

export function mapOpdsPublicationToAcquisitions(publication: OpdsPublication): OpdsAcquisitionDto[] {
  return publication.acquisitionLinks.concat(publication.unsupportedLinks).map((link: OpdsLink): OpdsAcquisitionDto => {
    return {
      href: link.href,
      type: link.type,
      title: link.title,
      status: link.acquisitionStatus === undefined ? OpdsAcquisitionStatus.UNSUPPORTED_TYPE : link.acquisitionStatus,
    }
  })
}

export function mapOpdsPublicationToImages(publication: OpdsPublication): OpdsImageDto[] {
  const fullImages = publication.imageLinks.map((link: OpdsLink): OpdsImageDto => {
    return {
      href: link.href,
      type: link.type,
      title: link.title,
      isThumbnail: false,
    }
  })
  const thumbnails = publication.thumbnailLinks.map((link: OpdsLink): OpdsImageDto => {
    return {
      href: link.href,
      type: link.type,
      title: link.title,
      isThumbnail: true,
    }
  })
  return fullImages.concat(thumbnails)
}

export function resolveOpdsHref(baseUrl: string, href: string): string {
  if (href.startsWith('http://') || href.startsWith('https://')) {
    return href
  }
  const origin = readOpdsUrlOrigin(baseUrl)
  if (href.startsWith('//')) {
    const protocolEnd = baseUrl.indexOf(':')
    return protocolEnd < 0 ? href : baseUrl.substring(0, protocolEnd + 1) + href
  }
  if (href.startsWith('/')) {
    return origin.length === 0 ? href : origin + href
  }
  const cleanBase = stripOpdsQueryAndHash(baseUrl)
  const slashIndex = cleanBase.lastIndexOf('/')
  if (slashIndex < 0) {
    return href
  }
  const baseDir = cleanBase.endsWith('/') ? cleanBase : cleanBase.substring(0, slashIndex + 1)
  return baseDir + href
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
  return (normalizedType === 'application/octet-stream' || normalizedType.length === 0) &&
    (normalizedHref.endsWith('.cbz') || normalizedHref.endsWith('.zip'))
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

function readOpds2Publication(value: Object, feedUrl: string, fallbackId: string): OpdsBookDto {
  const publication = readRecord(value)
  const publicationMetadata = readRecord(publication['metadata'])
  const title = readString(publicationMetadata['title']) ?? readString(publication['title']) ?? 'Untitled'
  const links = readOpds2Links(publication['links'], feedUrl)
    .concat(readOpds2Images(publication['images'], feedUrl))
  return createPublication(
    readString(publicationMetadata['identifier']) ?? readString(publication['href']) ?? fallbackId,
    title,
    readString(publicationMetadata['description']) ?? readString(publicationMetadata['subtitle']),
    readOpds2Author(publicationMetadata['author']),
    links
  )
}

function readOpds2Group(value: Object, feedUrl: string, fallbackTitle: string): OpdsPublicationGroup {
  const group = readRecord(value)
  const metadata = readRecord(group['metadata'])
  const title = readString(metadata['title']) ?? readString(group['title']) ?? fallbackTitle
  const navigation: OpdsCatalogDto[] = []
  readArray(group['navigation']).forEach((item: Object, index: number) => {
    const nav = readRecord(item)
    const href = readString(nav['href'])
    if (href !== undefined && href.length > 0) {
      navigation.push({
        id: readString(nav['identifier']) ?? readString(nav['title']) ?? `${fallbackTitle}-navigation-${index}`,
        title: readString(nav['title']) ?? href,
        href: resolveOpdsHref(feedUrl, href),
        type: readString(nav['type']),
      })
    }
  })
  const publications = readArray(group['publications']).map((item: Object, index: number): OpdsBookDto => {
    return readOpds2Publication(item, feedUrl, `${fallbackTitle}-publication-${index}`)
  })
  return {
    title,
    navigation,
    publications,
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

function readOpds2Links(value: Object | undefined, feedUrl: string): OpdsLink[] {
  return readArray(value).map((item: Object): OpdsLink => {
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

function readOpds2Images(value: Object | undefined, feedUrl: string): OpdsLink[] {
  return readArray(value).map((item: Object): OpdsLink => {
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

function readOpds2ManifestImages(json: string, feedUrl: string): OpdsImageDto[] {
  const parsed = JSON.parse(json) as Record<string, Object>
  const links = readOpds2Images(parsed['images'], feedUrl)
    .concat(readImageCandidates(parsed['readingOrder'], feedUrl))
    .concat(readImageCandidates(parsed['resources'], feedUrl))
    .concat(readImageCandidates(parsed['pageList'], feedUrl))
  return links.filter((link: OpdsLink): boolean => {
    const type = link.type === undefined ? '' : link.type.toLocaleLowerCase()
    const href = link.href.toLocaleLowerCase().split('?')[0].split('#')[0]
    return type.startsWith('image/') ||
      href.endsWith('.jpg') ||
      href.endsWith('.jpeg') ||
      href.endsWith('.png') ||
      href.endsWith('.webp') ||
      href.endsWith('.gif')
  }).map((link: OpdsLink): OpdsImageDto => {
    return {
      href: link.href,
      type: link.type,
      title: link.title,
      isThumbnail: link.kind === OpdsLinkKind.THUMBNAIL,
    }
  })
}

function readImageCandidates(value: Object | undefined, feedUrl: string): OpdsLink[] {
  return readArray(value).map((item: Object): OpdsLink => {
    if (typeof item === 'string') {
      return {
        href: resolveOpdsHref(feedUrl, item),
        kind: OpdsLinkKind.IMAGE,
      }
    }
    const link = readRecord(item)
    const href = resolveOpdsHref(feedUrl, readString(link['href']) ?? readString(link['url']) ?? '')
    const rel = readRelValue(link['rel'])
    const type = readString(link['type']) ?? readString(link['encodingFormat'])
    return {
      href,
      rel,
      type,
      title: readString(link['title']),
      kind: classifyOpdsLink(rel ?? 'image', type, href),
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

function readRelValue(value: Object | undefined): string | undefined {
  if (Array.isArray(value)) {
    return value.join(' ')
  }
  return readString(value)
}

function readOpds2Author(value: Object | undefined): string | undefined {
  if (typeof value === 'string') {
    return value
  }
  if (Array.isArray(value)) {
    const names = (value as Object[]).map((item: Object): string | undefined => readString(readRecord(item)['name'])).filter((name: string | undefined) => name !== undefined) as string[]
    return names.length === 0 ? undefined : names.join(', ')
  }
  return readString(readRecord(value)['name'])
}

function readString(value: Object | undefined): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function readRecord(value: Object | undefined): Record<string, Object> {
  return value !== undefined && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : {}
}

function readArray(value: Object | undefined): Object[] {
  return Array.isArray(value) ? value as Object[] : []
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

function stripXmlBlocks(xml: string, tagName: string): string {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b[^>]*>[\\s\\S]*?<\\/(?:[A-Za-z0-9_-]+:)?${tagName}>`, 'gi')
  return xml.replace(pattern, '')
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

function readOpdsUrlOrigin(url: string): string {
  const match = /^(https?:\/\/[^\/?#]+)/i.exec(url)
  return match === null ? '' : match[1]
}

function stripOpdsQueryAndHash(url: string): string {
  const queryIndex = url.indexOf('?')
  const hashIndex = url.indexOf('#')
  let end = url.length
  if (queryIndex >= 0 && queryIndex < end) {
    end = queryIndex
  }
  if (hashIndex >= 0 && hashIndex < end) {
    end = hashIndex
  }
  return url.substring(0, end)
}

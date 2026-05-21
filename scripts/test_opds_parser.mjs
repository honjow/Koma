import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const modelPath = resolve(root, 'entry/src/main/ets/remote/OpdsModels.ets')
const parserPath = resolve(root, 'entry/src/main/ets/remote/OpdsParser.ets')

const modelSource = readFileSync(modelPath, 'utf8')
const parserSource = readFileSync(parserPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|enum|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

const OpdsLinkKind = {
  NAVIGATION: 'navigation',
  ACQUISITION: 'acquisition',
  IMAGE: 'image',
  THUMBNAIL: 'thumbnail',
  SELF: 'self',
  NEXT: 'next',
  PREVIOUS: 'previous',
  ALTERNATE: 'alternate',
  UNSUPPORTED: 'unsupported',
}

const OpdsAcquisitionStatus = {
  SUPPORTED: 'supported',
  UNSUPPORTED_TYPE: 'unsupported_type',
  UNSUPPORTED_FLOW: 'unsupported_flow',
}

const supportedTypes = new Set([
  'application/zip',
  'application/x-cbz',
  'application/vnd.comicbook+zip',
])

function resolveOpdsHref(baseUrl, href) {
  try {
    return new URL(href, baseUrl).toString()
  } catch {
    return href
  }
}

function normalizeRel(rel) {
  return rel === undefined ? '' : rel.toLowerCase().trim()
}

function isUnsupportedOpdsFlow(rel) {
  const normalized = normalizeRel(rel)
  return normalized.includes('buy') || normalized.includes('borrow') || normalized.includes('subscribe')
}

function isSupportedOpdsAcquisition(type, href) {
  const normalizedType = type === undefined ? '' : type.toLowerCase().split(';')[0].trim()
  if (supportedTypes.has(normalizedType)) return true
  const normalizedHref = href === undefined ? '' : href.toLowerCase().split('?')[0].split('#')[0]
  return normalizedHref.endsWith('.cbz') || normalizedHref.endsWith('.zip')
}

function classifyOpdsLink(rel, type, href) {
  const normalized = normalizeRel(rel)
  if (normalized.includes('thumbnail')) return OpdsLinkKind.THUMBNAIL
  if (normalized.includes('image') || normalized.includes('cover')) return OpdsLinkKind.IMAGE
  if (isUnsupportedOpdsFlow(normalized)) return OpdsLinkKind.UNSUPPORTED
  if (normalized === 'acquisition' || normalized.includes('http://opds-spec.org/acquisition')) {
    return isSupportedOpdsAcquisition(type, href) ? OpdsLinkKind.ACQUISITION : OpdsLinkKind.UNSUPPORTED
  }
  if (normalized === 'self') return OpdsLinkKind.SELF
  if (normalized === 'next') return OpdsLinkKind.NEXT
  if (normalized === 'previous' || normalized === 'prev') return OpdsLinkKind.PREVIOUS
  if (normalized === 'alternate' || normalized.length === 0) return OpdsLinkKind.ALTERNATE
  return OpdsLinkKind.NAVIGATION
}

function readAcquisitionStatus(kind, rel, type, href) {
  const normalized = normalizeRel(rel)
  if (kind === OpdsLinkKind.ACQUISITION) return OpdsAcquisitionStatus.SUPPORTED
  if (!normalized.includes('acquisition') && !isUnsupportedOpdsFlow(rel)) return undefined
  if (isUnsupportedOpdsFlow(rel)) return OpdsAcquisitionStatus.UNSUPPORTED_FLOW
  return isSupportedOpdsAcquisition(type, href) ? OpdsAcquisitionStatus.SUPPORTED : OpdsAcquisitionStatus.UNSUPPORTED_TYPE
}

function decodeXmlEntities(value) {
  return value
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
}

function readXmlBlocks(xml, tagName) {
  const pattern = new RegExp(`<(?:[A-Za-z0-9_-]+:)?${tagName}\\b[^>]*>([\\s\\S]*?)<\\/(?:[A-Za-z0-9_-]+:)?${tagName}>`, 'gi')
  return [...xml.matchAll(pattern)].map((match) => match[1])
}

function readFirstXmlText(xml, tagName) {
  const block = readXmlBlocks(xml, tagName)[0]
  if (block === undefined) return undefined
  const text = decodeXmlEntities(block.replace(/<[^>]+>/g, '').trim())
  return text.length === 0 ? undefined : text
}

function readXmlAttributes(source) {
  const attrs = {}
  const pattern = /([A-Za-z_:][A-Za-z0-9_.:-]*)\s*=\s*(['"])(.*?)\2/g
  for (const match of source.matchAll(pattern)) {
    const key = match[1].includes(':') ? match[1].split(':').at(-1) : match[1]
    attrs[key] = decodeXmlEntities(match[3])
  }
  return attrs
}

function readXmlLinks(xml, feedUrl) {
  const pattern = /<(?:[A-Za-z0-9_-]+:)?link\b([^>]*)\/?\s*>/gi
  return [...xml.matchAll(pattern)].map((match) => {
    const attrs = readXmlAttributes(match[1])
    const href = resolveOpdsHref(feedUrl, attrs.href ?? '')
    const kind = classifyOpdsLink(attrs.rel, attrs.type, href)
    return {
      href,
      rel: attrs.rel,
      type: attrs.type,
      title: attrs.title,
      kind,
      acquisitionStatus: readAcquisitionStatus(kind, attrs.rel, attrs.type, href),
    }
  })
}

function createPublication(id, title, summary, author, links) {
  return {
    id,
    title,
    summary,
    author,
    acquisitionLinks: links.filter((link) => link.kind === OpdsLinkKind.ACQUISITION),
    unsupportedLinks: links.filter((link) => link.kind === OpdsLinkKind.UNSUPPORTED),
    imageLinks: links.filter((link) => link.kind === OpdsLinkKind.IMAGE),
    thumbnailLinks: links.filter((link) => link.kind === OpdsLinkKind.THUMBNAIL),
    links,
  }
}

function parseOpds1Catalog(xml, feedUrl) {
  const result = {
    version: 'opds1',
    feedUrl,
    title: readFirstXmlText(xml, 'title'),
    navigation: [],
    publications: [],
    links: readXmlLinks(xml, feedUrl),
  }

  for (const [index, entryXml] of readXmlBlocks(xml, 'entry').entries()) {
    const authorBlock = readXmlBlocks(entryXml, 'author')[0] ?? ''
    const entry = {
      id: readFirstXmlText(entryXml, 'id'),
      title: readFirstXmlText(entryXml, 'title') ?? 'Untitled',
      summary: readFirstXmlText(entryXml, 'summary') ?? readFirstXmlText(entryXml, 'content'),
      author: readFirstXmlText(authorBlock, 'name'),
      links: readXmlLinks(entryXml, feedUrl),
    }
    const acquisitionLinks = entry.links.filter((link) => link.kind === OpdsLinkKind.ACQUISITION)
    const unsupportedLinks = entry.links.filter((link) => link.kind === OpdsLinkKind.UNSUPPORTED)
    if (acquisitionLinks.length > 0 || unsupportedLinks.length > 0) {
      result.publications.push(createPublication(entry.id ?? entry.title, entry.title, entry.summary, entry.author, entry.links))
    } else {
      const navigationLink = entry.links.find((link) => link.kind === OpdsLinkKind.NAVIGATION || link.kind === OpdsLinkKind.ALTERNATE)
      if (navigationLink !== undefined) {
        result.navigation.push({
          id: entry.id ?? `navigation-${index}`,
          title: entry.title,
          href: navigationLink.href,
          type: navigationLink.type,
        })
      }
    }
  }
  return result
}

function asArray(value) {
  return Array.isArray(value) ? value : []
}

function asObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? value : {}
}

function asString(value) {
  return typeof value === 'string' && value.length > 0 ? value : undefined
}

function readRelValue(value) {
  return Array.isArray(value) ? value.join(' ') : asString(value)
}

function readOpds2Links(value, feedUrl) {
  return asArray(value).map((item) => {
    const link = asObject(item)
    const rel = readRelValue(link.rel)
    const type = asString(link.type) ?? asString(link.encodingFormat)
    const href = resolveOpdsHref(feedUrl, asString(link.href) ?? '')
    const kind = classifyOpdsLink(rel, type, href)
    return {
      href,
      rel,
      type,
      title: asString(link.title),
      kind,
      acquisitionStatus: readAcquisitionStatus(kind, rel, type, href),
    }
  })
}

function readOpds2Images(value, feedUrl) {
  return asArray(value).map((item) => {
    if (typeof item === 'string') {
      return { href: resolveOpdsHref(feedUrl, item), rel: 'cover', kind: OpdsLinkKind.IMAGE }
    }
    const image = asObject(item)
    const rel = readRelValue(image.rel) ?? 'cover'
    const type = asString(image.type)
    const href = resolveOpdsHref(feedUrl, asString(image.href) ?? '')
    return { href, rel, type, title: asString(image.title), kind: classifyOpdsLink(rel, type, href) }
  })
}

function readOpds2Author(value) {
  if (typeof value === 'string') return value
  if (Array.isArray(value)) {
    const names = value.map((item) => asString(asObject(item).name)).filter(Boolean)
    return names.length === 0 ? undefined : names.join(', ')
  }
  return asString(asObject(value).name)
}

function parseOpds2Catalog(json, feedUrl) {
  const parsed = JSON.parse(json)
  const metadata = asObject(parsed.metadata)
  const result = {
    version: 'opds2',
    feedUrl,
    title: asString(metadata.title),
    navigation: [],
    publications: [],
    links: readOpds2Links(parsed.links, feedUrl),
  }

  for (const [index, item] of asArray(parsed.navigation).entries()) {
    const navigation = asObject(item)
    const href = asString(navigation.href)
    if (href !== undefined) {
      result.navigation.push({
        id: asString(navigation.identifier) ?? asString(navigation.title) ?? `navigation-${index}`,
        title: asString(navigation.title) ?? href,
        href: resolveOpdsHref(feedUrl, href),
        type: asString(navigation.type),
      })
    }
  }

  for (const [index, item] of asArray(parsed.publications).entries()) {
    const publication = asObject(item)
    const publicationMetadata = asObject(publication.metadata)
    const title = asString(publicationMetadata.title) ?? asString(publication.title) ?? 'Untitled'
    const links = readOpds2Links(publication.links, feedUrl).concat(readOpds2Images(publication.images, feedUrl))
    result.publications.push(createPublication(
      asString(publicationMetadata.identifier) ?? asString(publication.href) ?? `publication-${index}`,
      title,
      asString(publicationMetadata.description) ?? asString(publicationMetadata.subtitle),
      readOpds2Author(publicationMetadata.author),
      links,
    ))
  }
  return result
}

const originalFetch = globalThis.fetch
globalThis.fetch = async () => {
  throw new Error('Real network fetch is forbidden in OPDS parser tests')
}

try {
  for (const symbol of [
    'OpdsVersion',
    'OpdsLinkKind',
    'OpdsAcquisitionStatus',
    'OpdsLink',
    'OpdsNavigationItem',
    'OpdsPublication',
    'OpdsParseResult',
    'OPDS_SUPPORTED_ACQUISITION_MIME_TYPES',
  ]) {
    assertExport(modelSource, symbol)
  }
  for (const symbol of [
    'parseOpdsCatalog',
    'parseOpds1Catalog',
    'parseOpds2Catalog',
    'resolveOpdsHref',
    'classifyOpdsLink',
    'isSupportedOpdsAcquisition',
    'isUnsupportedOpdsFlow',
  ]) {
    assertExport(parserSource, symbol)
  }

  assert.doesNotMatch(parserSource, /\bfetch\s*\(|@ohos\.net\.http|http\.request/i, 'OPDS parser must not access network')
  assert.doesNotMatch(modelSource + parserSource, /market|plugin|source store|全网|免费漫画/i, 'OPDS spike must not introduce public source marketplace language')
  assert.doesNotMatch(modelSource, /rar/i, 'OPDS acquisition whitelist must stay limited to CBZ/ZIP')

  const opds1Fixture = `<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Private OPDS 1 Shelf</title>
  <link rel="self" href="/opds/root.xml" type="application/atom+xml;profile=opds-catalog"/>
  <entry>
    <id>urn:navigation:series</id>
    <title>Series A</title>
    <link rel="subsection" href="../series/a.xml" type="application/atom+xml;profile=opds-catalog"/>
  </entry>
  <entry>
    <id>urn:book:vol1</id>
    <title>Series A Vol. 1</title>
    <summary>Offline CBZ entry</summary>
    <author><name>Creator One</name></author>
    <link rel="http://opds-spec.org/image" href="covers/vol1.jpg" type="image/jpeg"/>
    <link rel="http://opds-spec.org/image/thumbnail" href="covers/vol1-thumb.jpg" type="image/jpeg"/>
    <link rel="http://opds-spec.org/acquisition" href="files/vol1.cbz" type="application/x-cbz"/>
    <link rel="http://opds-spec.org/acquisition" href="files/vol1.epub" type="application/epub+zip"/>
    <link rel="http://opds-spec.org/acquisition/buy" href="https://store.invalid/vol1" type="text/html"/>
  </entry>
  <entry>
    <id>urn:book:zip</id>
    <title>Archive By Extension</title>
    <link rel="http://opds-spec.org/acquisition/open-access" href="/downloads/archive.zip?token=fixture" type="application/octet-stream"/>
  </entry>
</feed>`

  const opds1 = parseOpds1Catalog(opds1Fixture, 'https://library.invalid/opds/root.xml')
  assert.equal(opds1.version, 'opds1')
  assert.equal(opds1.title, 'Private OPDS 1 Shelf')
  assert.equal(opds1.links[0].kind, OpdsLinkKind.SELF)
  assert.equal(opds1.navigation.length, 1)
  assert.equal(opds1.navigation[0].href, 'https://library.invalid/series/a.xml')
  assert.equal(opds1.publications.length, 2)
  assert.equal(opds1.publications[0].title, 'Series A Vol. 1')
  assert.equal(opds1.publications[0].author, 'Creator One')
  assert.equal(opds1.publications[0].thumbnailLinks[0].href, 'https://library.invalid/opds/covers/vol1-thumb.jpg')
  assert.deepEqual(opds1.publications[0].acquisitionLinks.map((link) => link.href), ['https://library.invalid/opds/files/vol1.cbz'])
  assert.equal(opds1.publications[0].unsupportedLinks.length, 2)
  assert.equal(opds1.publications[0].unsupportedLinks.find((link) => link.href.endsWith('vol1.epub')).acquisitionStatus, OpdsAcquisitionStatus.UNSUPPORTED_TYPE)
  assert.equal(opds1.publications[0].unsupportedLinks.find((link) => link.href.includes('store.invalid')).acquisitionStatus, OpdsAcquisitionStatus.UNSUPPORTED_FLOW)
  assert.equal(opds1.publications[1].acquisitionLinks[0].href, 'https://library.invalid/downloads/archive.zip?token=fixture')

  const opds2Fixture = JSON.stringify({
    metadata: { title: 'Private OPDS 2 Shelf' },
    links: [
      { rel: 'self', href: '/opds2/root.json', type: 'application/opds+json' },
      { rel: 'next', href: 'page-2.json', type: 'application/opds+json' },
    ],
    navigation: [
      { title: 'Recently Added', href: './recent.json', type: 'application/opds+json' },
    ],
    publications: [
      {
        metadata: {
          identifier: 'pub-json-1',
          title: 'JSON Volume',
          description: 'OPDS 2 publication',
          author: [{ name: 'Creator Two' }],
        },
        links: [
          { rel: 'http://opds-spec.org/acquisition/open-access', href: '../files/json-volume.zip', type: 'application/zip' },
          { rel: 'http://opds-spec.org/acquisition/borrow', href: '../borrow/json-volume', type: 'text/html' },
          { rel: 'alternate', href: '../read/json-volume.html', type: 'text/html' },
        ],
        images: [
          { rel: 'cover', href: '../covers/json-volume.jpg', type: 'image/jpeg' },
          { rel: 'thumbnail', href: '../covers/json-volume-thumb.jpg', type: 'image/jpeg' },
        ],
      },
      {
        metadata: { title: 'Unsupported PDF' },
        links: [
          { rel: 'http://opds-spec.org/acquisition', href: '../files/book.pdf', type: 'application/pdf' },
        ],
      },
    ],
  })

  const opds2 = parseOpds2Catalog(opds2Fixture, 'https://library.invalid/opds2/root.json')
  assert.equal(opds2.version, 'opds2')
  assert.equal(opds2.title, 'Private OPDS 2 Shelf')
  assert.deepEqual(opds2.links.map((link) => link.kind), [OpdsLinkKind.SELF, OpdsLinkKind.NEXT])
  assert.equal(opds2.navigation[0].href, 'https://library.invalid/opds2/recent.json')
  assert.equal(opds2.publications.length, 2)
  assert.equal(opds2.publications[0].author, 'Creator Two')
  assert.equal(opds2.publications[0].acquisitionLinks[0].href, 'https://library.invalid/files/json-volume.zip')
  assert.equal(opds2.publications[0].unsupportedLinks[0].acquisitionStatus, OpdsAcquisitionStatus.UNSUPPORTED_FLOW)
  assert.equal(opds2.publications[0].imageLinks[0].href, 'https://library.invalid/covers/json-volume.jpg')
  assert.equal(opds2.publications[0].thumbnailLinks[0].href, 'https://library.invalid/covers/json-volume-thumb.jpg')
  assert.equal(opds2.publications[1].acquisitionLinks.length, 0)
  assert.equal(opds2.publications[1].unsupportedLinks[0].acquisitionStatus, OpdsAcquisitionStatus.UNSUPPORTED_TYPE)

  assert.equal(isSupportedOpdsAcquisition('application/octet-stream', '/books/private.cbz'), true)
  assert.equal(isSupportedOpdsAcquisition('application/vnd.comicbook+zip', '/books/private.bin'), true)
  assert.equal(isSupportedOpdsAcquisition('application/pdf', '/books/private.pdf'), false)
  assert.equal(classifyOpdsLink('http://opds-spec.org/acquisition/subscribe', 'text/html', '/sub'), OpdsLinkKind.UNSUPPORTED)

  console.log('PASS OPDS parser fixture contracts')
} finally {
  globalThis.fetch = originalFetch
}

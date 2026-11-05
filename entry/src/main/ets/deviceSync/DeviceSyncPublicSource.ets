import { http } from '@kit.NetworkKit'
import { util, url } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { appSourceRuntimeRegistry, getInstalledSourcePackage } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { resolveIndexDocumentUrl, subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'
import {
  MANGADEX_SYNC_SOURCE, XKCD_SYNC_SOURCE, SYNC_OFFICIAL_CATALOG, syncChapterBelongsToSource, syncKnownSource,
  syncPublicLabel, syncSupportedSource, syncWorksOnSource, SyncWorkLabel,
} from './DeviceSyncData'
import { syncDigest, syncDigestBytes } from './DeviceSyncWire'

export interface SyncPublicWorkProof extends SyncWorkLabel {
  source: string
  work: string
}

export interface SyncPublicChapterProof {
  title: string
  pages: number
  pageTable: string
  normalPages: string[]
  saverPages: string[]
  chapterHash: string
}

interface MangaDexAttributes {
  title?: Record<string, string>
  altTitles?: Record<string, string>[]
  chapter?: string
}

interface MangaDexRelation {
  id: string
  type: string
}

interface MangaDexEntity {
  id: string
  attributes: MangaDexAttributes
  relationships?: MangaDexRelation[]
}

interface MangaDexEntityResponse {
  result: string
  data: MangaDexEntity
}

interface MangaDexPageTable {
  hash: string
  data: string[]
  dataSaver: string[]
}

interface MangaDexPageResponse {
  result: string
  chapter: MangaDexPageTable
}

interface XkcdPublicEntry {
  title: string
  image: string
}

function isPinnedOfficialManifest(source: string, path: string | undefined): boolean {
  if (path === undefined) return false
  const expected = source === MANGADEX_SYNC_SOURCE ?
    'bf834cd800ec054651d7c5e327f82f01a5c344f4a1221ef2406da51ec85cf7fa' :
    'c6d04fc5e7376c8a0d792569699f48a9a5a9a2563e89b24c6575e26c6ec3d71f'
  const restored = source === MANGADEX_SYNC_SOURCE ?
    'cc50a58cd2f9e16e8ca52f8dc726f05704c16843bfaeec50c5196aa5fdc94019' :
    '8cbd712d9f7aff2239829bcb79875db2ca12caf4f1a14b8e5951685c13ac1b38'
  try {
    const size = fs.statSync(path).size
    const originalSize = source === MANGADEX_SYNC_SOURCE ? 314 : 513
    const restoredSize = source === MANGADEX_SYNC_SOURCE ? 839 : 980
    if (size !== originalSize && size !== restoredSize) return false
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    try {
      const data = new Uint8Array(size)
      if (fs.readSync(file.fd, data.buffer) !== size) return false
      const hash = syncDigestBytes(data)
      // Backups store the host-normalized form of the same official package.
      return hash === expected || hash === restored
    } finally {
      fs.closeSync(file)
    }
  } catch (_error) {
    return false
  }
}

export function syncHasTrustedPackage(source: string): boolean {
  const installed = getInstalledSourcePackage(source)
  if (installed === undefined || !installed.enabled || !syncSupportedSource(source, installed.version)) return false
  const registered = appSourceRuntimeRegistry.lookup(source).entry
  if (registered === undefined || registered.manifestId !== source || registered.manifestVersion !== installed.version ||
    (registered.webSessionOrigins?.length ?? 0) > 0) return false
  const expected = source === MANGADEX_SYNC_SOURCE ?
    'ff51c584cbb49819f073d0718d7b76fe855588717982effe033159096d4caed3' :
    '29e9d902619370397815798f6c8b79fad6b0918012f6b794bfd226bd300a5863'
  if (syncDigestBytes(registered.wasmBytes) !== expected) return false
  const officialCatalog = installed.catalogOrigin !== undefined &&
    subscriptionIdentity(resolveIndexDocumentUrl(installed.catalogOrigin)) === subscriptionIdentity(SYNC_OFFICIAL_CATALOG)
  // Local imports and normal backup restores must retain an audited manifest
  // representation and the actual release runtime bytes.
  return officialCatalog || isPinnedOfficialManifest(source, registered.manifestPath)
}

function syncSourceVersion(source: string): string {
  if (source === MANGADEX_SYNC_SOURCE) return '0.1.25'
  if (source === XKCD_SYNC_SOURCE) return '0.1.7'
  throw new Error('sync_source_not_supported')
}

function findMangaDexTitle(titles: Record<string, string>[], languages: string[]): string {
  for (const language of languages) {
    for (const table of titles) {
      const value = table?.[language]
      const title = typeof value === 'string' ? syncPublicLabel(value, 240) : ''
      if (title !== '') return title
    }
  }
  return ''
}

function mangaDexTitle(attributes: MangaDexAttributes): string {
  const raw = attributes.title
  const primary: Record<string, string> = typeof raw === 'object' && raw !== null && !Array.isArray(raw) ? raw : {}
  const alternatives = Array.isArray(attributes.altTitles) ? attributes.altTitles : []
  const preferred = ['zh', 'zh-hk', 'en', 'ja-ro', 'ja']
  // MangaDex may supply only a romanized or otherwise unlisted primary title.
  return findMangaDexTitle([primary], preferred) || findMangaDexTitle(alternatives, preferred) ||
    findMangaDexTitle([primary], Object.keys(primary))
}

/**
 * Public proof uses fixed HTTPS catalogue endpoints, never the source WASM,
 * its settings, web sessions, signed page URLs or arbitrary remote strings.
 */
async function readPublicText(address: string, max: number): Promise<string> {
  const request = http.createHttp()
  try {
    const response = await request.request(address, {
      method: http.RequestMethod.GET, maxRedirects: 0, usingCache: false,
      connectTimeout: 4500, readTimeout: 6500, maxLimit: max, expectDataType: http.HttpDataType.ARRAY_BUFFER,
      header: { 'Accept': 'application/json, text/html' },
    })
    if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) {
      throw new Error('sync_public_source_unavailable')
    }
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(response.result))
  } catch (_error) {
    throw new Error('sync_public_source_unavailable')
  } finally {
    request.destroy()
  }
}

async function readPublicJson(address: string, max: number): Promise<Object> {
  return JSON.parse(await readPublicText(address, max)) as Object
}

function htmlTagAttribute(tag: string, name: string): string | undefined {
  const prefix = /^<\/?[a-z][a-z0-9:-]*/i.exec(tag)
  if (prefix === null) return undefined
  const attributes = tag.substring(prefix[0].length, tag.length - 1)
  const tokens = /([^\s"'<>\/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g
  let attribute: RegExpExecArray | null
  while ((attribute = tokens.exec(attributes)) !== null) {
    if (attribute[1].toLowerCase() === name) return attribute[2] ?? attribute[3] ?? attribute[4] ?? ''
  }
  return undefined
}

function checkedXkcdPagePaths(html: string): string[] {
  const tags = /<!--[\s\S]*?-->|<(script|style)\b[^>]*>[\s\S]*?<\/\1\s*>|<\/?([a-z][a-z0-9:-]*)\b(?:[^"'<>]|"[^"]*"|'[^']*')*>/gi
  const stack: string[] = []
  const paths: string[] = []
  const voidTags = ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr']
  let tag: RegExpExecArray | null
  // Match the source's #content > img:not([id]) selector across nested controls.
  while ((tag = tags.exec(html)) !== null) {
    if (tag[2] === undefined) continue
    const name = tag[2].toLowerCase()
    if (stack.length === 0) {
      if (name === 'div' && htmlTagAttribute(tag[0], 'id') === 'content') stack.push(name)
      continue
    }
    if (tag[0].startsWith('</')) {
      if (stack[stack.length - 1] !== name) return []
      stack.pop()
      if (stack.length === 0) return paths
    } else {
      if (name === 'img' && stack.length === 1 && htmlTagAttribute(tag[0], 'id') === undefined) {
        const src = htmlTagAttribute(tag[0], 'src')
        if (src !== undefined && /^(?:https:\/\/xkcd\.tw)?\/strip\/[A-Za-z0-9._\/-]+$/.test(src)) {
          paths.push(src.replace(/^https:\/\/xkcd\.tw/, ''))
        }
      }
      if (!voidTags.includes(name) && !/\/\s*>$/.test(tag[0])) stack.push(name)
    }
  }
  return []
}

/** Match the actual Reader descriptor order, including source-specific quality. */
export function matchesPublicSyncPages(source: string, proof: SyncPublicChapterProof, uris: string[]): boolean {
  return matchesPublicSyncPageHash(source, proof, syncPageDescriptorHash(source, uris))
}

export function syncPageDescriptorHash(source: string, uris: string[]): string {
  const paths: string[] = []
  for (const uri of uris) {
    try {
      const parsed = url.URL.parseURL(uri)
      if (parsed.protocol !== 'https:' || parsed.username.length > 0 || parsed.password.length > 0 ||
        (source === XKCD_SYNC_SOURCE && parsed.hostname !== 'xkcd.tw')) return ''
      paths.push(parsed.pathname)
    } catch (_error) {
      return ''
    }
  }
  return paths.length === 0 ? '' : syncDigest(JSON.stringify(paths))
}

export function matchesPublicSyncPageHash(source: string, proof: SyncPublicChapterProof, hash: string): boolean {
  if (hash === '') return false
  if (source === XKCD_SYNC_SOURCE) return hash === syncDigest(JSON.stringify(proof.normalPages))
  return hash === syncDigest(JSON.stringify(proof.normalPages.map((page: string): string =>
    '/data/' + proof.chapterHash + '/' + page))) ||
    (proof.saverPages.length === proof.pages && hash === syncDigest(JSON.stringify(proof.saverPages.map((page: string): string =>
      '/data-saver/' + proof.chapterHash + '/' + page))))
}

export class DeviceSyncPublicSources {
  private readonly works = new Map<string, SyncPublicWorkProof>()
  private readonly chapters = new Map<string, SyncPublicChapterProof>()
  private xkcd?: Promise<Record<string, XkcdPublicEntry>>

  async work(source: string, id: string, allowFetch: boolean): Promise<SyncPublicWorkProof | undefined> {
    if (!syncWorksOnSource(source, id) || !syncHasTrustedPackage(source)) return undefined
    const key = JSON.stringify([source, id])
    const cached = this.works.get(key)
    if (cached !== undefined || !allowFetch) return cached
    try {
      let title = 'xkcd'
      let sourceName = 'xkcd'
      if (source === MANGADEX_SYNC_SOURCE) {
        const uuid = id.substring(4)
        const response = await readPublicJson('https://api.mangadex.org/manga/' + uuid, 512 * 1024) as MangaDexEntityResponse
        if (response.result !== 'ok' || response.data.id !== uuid) return undefined
        title = mangaDexTitle(response.data.attributes)
        sourceName = 'MangaDex'
        if (!title) return undefined
      } else {
        // The archive itself establishes this public namespace.
        const entries = await this.xkcdArchive()
        if (Object.keys(entries).length === 0) return undefined
        if (id !== 'xkcd:zh') title += ' ' + id.substring('xkcd:zh:g:'.length)
      }
      const proof: SyncPublicWorkProof = { source, work: id, title, sourceName, sourceVersion: syncSourceVersion(source) }
      this.works.set(key, proof)
      return proof
    } catch (_error) {
      return undefined
    }
  }

  async chapter(source: string, work: string, id: string, allowFetch: boolean): Promise<SyncPublicChapterProof | undefined> {
    if (!syncChapterBelongsToSource(source, work, id) || !syncHasTrustedPackage(source)) return undefined
    const key = JSON.stringify([source, work, id])
    const cached = this.chapters.get(key)
    if (cached !== undefined || !allowFetch) return cached
    try {
      let proof: SyncPublicChapterProof
      if (source === MANGADEX_SYNC_SOURCE) {
        const uuid = id.substring(3)
        const chapter = await readPublicJson('https://api.mangadex.org/chapter/' + uuid, 256 * 1024) as MangaDexEntityResponse
        if (chapter.result !== 'ok' || chapter.data.id !== uuid ||
          !chapter.data.relationships?.some((item: MangaDexRelation): boolean =>
            item.type === 'manga' && item.id === work.substring(4))) return undefined
        const pages = await readPublicJson('https://api.mangadex.org/at-home/server/' + uuid, 1024 * 1024) as MangaDexPageResponse
        const table = pages.chapter
        if (pages.result !== 'ok' || !table || !/^[0-9a-f]{32,64}$/.test(table.hash) ||
          !Array.isArray(table.data) || !Array.isArray(table.dataSaver) || table.data.length === 0 ||
          table.data.length > 10000 || table.data.length !== table.dataSaver.length ||
          table.data.concat(table.dataSaver).some((file: string): boolean => typeof file !== 'string' ||
            !/^[a-zA-Z0-9._-]{1,256}$/.test(file))) return undefined
        proof = { title: syncPublicLabel(chapter.data.attributes.chapter ?? '', 240), pages: table.data.length,
          pageTable: syncDigest(JSON.stringify([table.hash, table.data, table.dataSaver])),
          normalPages: table.data, saverPages: table.dataSaver, chapterHash: table.hash }
      } else {
        const archive = await this.xkcdArchive()
        const number = id.substring(id.lastIndexOf(':') + 1)
        const item = archive[number]
        if (!item || typeof item.title !== 'string') return undefined
        const paths = checkedXkcdPagePaths(await readPublicText('https://xkcd.tw/' + number, 1024 * 1024))
        if (paths.length === 0) return undefined
        proof = { title: syncPublicLabel(item.title, 240), pages: paths.length, pageTable: syncDigest(JSON.stringify(paths)),
          normalPages: paths, saverPages: [], chapterHash: '' }
      }
      this.chapters.set(key, proof)
      return proof
    } catch (_error) {
      return undefined
    }
  }

  invalidate(): void {
    this.works.clear()
    this.chapters.clear()
    this.xkcd = undefined
  }

  private xkcdArchive(): Promise<Record<string, XkcdPublicEntry>> {
    if (this.xkcd === undefined) {
      this.xkcd = readPublicJson('https://xkcd.tw/api/strips.json', 6 * 1024 * 1024)
        .then((raw: Object): Record<string, XkcdPublicEntry> => raw as Record<string, XkcdPublicEntry>)
        .catch((error: Error): Record<string, XkcdPublicEntry> => {
          this.xkcd = undefined
          throw error
        })
    }
    return this.xkcd
  }
}

export function knownSyncSourceDisplayName(source: string): string {
  if (source === MANGADEX_SYNC_SOURCE) return 'MangaDex'
  if (source === XKCD_SYNC_SOURCE) return 'xkcd'
  return syncKnownSource(source) ? source : ''
}

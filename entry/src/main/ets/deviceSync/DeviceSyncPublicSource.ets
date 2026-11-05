import { http } from '@kit.NetworkKit'
import { util, url } from '@kit.ArkTS'
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

const trustedBytes = new Map<string, Uint8Array>()

export function syncHasTrustedPackage(source: string): boolean {
  const installed = getInstalledSourcePackage(source)
  if (installed === undefined || installed.catalogOrigin === undefined || !syncSupportedSource(source, installed.version)) return false
  if (!installed.enabled || subscriptionIdentity(resolveIndexDocumentUrl(installed.catalogOrigin)) !==
    subscriptionIdentity(SYNC_OFFICIAL_CATALOG)) return false
  const registered = appSourceRuntimeRegistry.lookup(source).entry
  if (registered === undefined) return false
  const expected = source === MANGADEX_SYNC_SOURCE ?
    'ff51c584cbb49819f073d0718d7b76fe855588717982effe033159096d4caed3' :
    '29e9d902619370397815798f6c8b79fad6b0918012f6b794bfd226bd300a5863'
  const verified = trustedBytes.get(source)
  if (verified === registered.wasmBytes) return true
  if (syncDigestBytes(registered.wasmBytes) !== expected) return false
  trustedBytes.set(source, registered.wasmBytes)
  return true
}

function syncSourceVersion(source: string): string {
  if (source === MANGADEX_SYNC_SOURCE) return '0.1.25'
  if (source === XKCD_SYNC_SOURCE) return '0.1.7'
  throw new Error('sync_source_not_supported')
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

function checkedXkcdPagePaths(html: string): string[] {
  const section = /<div\b[^>]*\bid=["']content["'][^>]*>([\s\S]*?)<\/div>/i.exec(html)
  if (section === null) return []
  const images = section[1].match(/<img\b[^>]*>/gi) ?? []
  const paths: string[] = []
  images.forEach((image: string): void => {
    if (/\s+id\s*=/i.test(image)) return
    const match = /\s+src=["']((?:https:\/\/xkcd\.tw)?\/strip\/[A-Za-z0-9._\/-]+)["']/i.exec(image)
    if (match !== null) paths.push(match[1].replace(/^https:\/\/xkcd\.tw/, ''))
  })
  return paths
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
        const fields = response.data.attributes.title
        title = syncPublicLabel(fields?.['zh'] ?? fields?.['zh-hk'] ?? fields?.['en'] ?? fields?.['ja-ro'] ?? fields?.['ja'] ?? '', 240)
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

import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { appSourceRuntimeRegistry, getInstalledSourcePackage } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { resolveIndexDocumentUrl, subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'
import {
  MANGADEX_SYNC_SOURCE, XKCD_SYNC_SOURCE, SYNC_OFFICIAL_CATALOG,
  syncPublicLabel, syncSupportedSource, syncWorksOnSource, SyncWorkLabel,
} from './DeviceSyncData'
import { syncDigestBytes } from './DeviceSyncWire'

export interface SyncPublicWorkProof extends SyncWorkLabel {
  source: string
  work: string
}

interface MangaDexAttributes {
  title?: Record<string, string>
  altTitles?: Record<string, string>[]
}

interface MangaDexEntity {
  id: string
  attributes: MangaDexAttributes
}

interface MangaDexEntityResponse {
  result: string
  data: MangaDexEntity
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

// Shelf, per-title preferences and shared search still use the original
// public catalogue contract. Reading history uses the Reader owner directly.
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
async function readPublicText(address: string, max: number, guard: () => void): Promise<string> {
  guard()
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

async function readPublicJson(address: string, max: number, guard: () => void): Promise<Object> {
  return JSON.parse(await readPublicText(address, max, guard)) as Object
}

export class DeviceSyncPublicSources {
  private readonly works = new Map<string, SyncPublicWorkProof>()
  private xkcd?: Promise<Record<string, XkcdPublicEntry>>

  async work(source: string, id: string, allowFetch: boolean, guard: () => void = (): void => {}): Promise<SyncPublicWorkProof | undefined> {
    if (!syncWorksOnSource(source, id) || !syncHasTrustedPackage(source)) return undefined
    const key = JSON.stringify([source, id])
    const cached = this.works.get(key)
    if (cached !== undefined || !allowFetch) return cached
    try {
      let title = 'xkcd'
      let sourceName = 'xkcd'
      if (source === MANGADEX_SYNC_SOURCE) {
        const uuid = id.substring(4)
        const response = await readPublicJson('https://api.mangadex.org/manga/' + uuid, 512 * 1024, guard) as MangaDexEntityResponse
        if (response.result !== 'ok' || response.data.id !== uuid) return undefined
        title = mangaDexTitle(response.data.attributes)
        sourceName = 'MangaDex'
        if (!title) return undefined
      } else {
        // The archive itself establishes this public namespace.
        const entries = await this.xkcdArchive(guard)
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

  invalidate(): void {
    this.works.clear()
    this.xkcd = undefined
  }

  private xkcdArchive(guard: () => void): Promise<Record<string, XkcdPublicEntry>> {
    if (this.xkcd === undefined) {
      this.xkcd = readPublicJson('https://xkcd.tw/api/strips.json', 6 * 1024 * 1024, guard)
        .then((raw: Object): Record<string, XkcdPublicEntry> => raw as Record<string, XkcdPublicEntry>)
        .catch((error: Error): Record<string, XkcdPublicEntry> => {
          this.xkcd = undefined
          throw error
        })
    }
    return this.xkcd
  }
}

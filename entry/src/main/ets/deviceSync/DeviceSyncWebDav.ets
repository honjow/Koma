import { util, url } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { DavResource } from '../remote/WebDavModels'
import { parseWebDavMultiStatus, buildPropfindBody } from '../remote/WebDavClient'
import {
  decodeSyncManifest, strongSyncTag, syncDigest, syncShardPath, syncUtf8, SyncManifest, SyncObject,
  SyncDatasetRef, SyncShardRef, SYNC_COLLECTION, SYNC_MAX_OBJECT_BYTES,
} from './DeviceSyncWire'

export interface SyncConnectionDraft {
  directory: string
  username: string
  password: string
}

export interface SyncRemoteManifest {
  manifest?: SyncManifest
  etag: string
  hash: string
}

interface SyncHttpResponse {
  status: number
  body: string
  etag: string
}

export type SyncRequestGuard = () => void

const MANIFEST = 'manifest.json'
const OBJECT_NAME = /^object-([1-9][0-9]*)-([0-9a-f]{64})\.json$/

export function canonicalSyncDirectory(input: string): string {
  try {
    const raw = input.trim()
    const parsed = url.URL.parseURL(raw)
    if (parsed.protocol === 'https:' && parsed.hostname.length > 0 && parsed.username.length === 0 &&
      parsed.password.length === 0 && !raw.includes('?') && !raw.includes('#') &&
      !/%2e|%2f|%5c|%00|\\/i.test(raw) && raw.length <= 1024) {
      return parsed.toString().replace(/\/+$/, '')
    }
  } catch (_error) {
  }
  throw new Error('sync_https_directory_required')
}

function responseTag(header: Object): string {
  const fields = header as Record<string, string>
  const key = Object.keys(fields).find((name: string): boolean => name.toLowerCase() === 'etag')
  return key === undefined || typeof fields[key] !== 'string' ? '' : fields[key].trim()
}

function requireSuccess(status: number): void {
  if (status >= 200 && status < 300) return
  if (status === 401) throw new Error('sync_authentication_failed')
  if (status === 403 || status === 405) throw new Error('sync_permission_denied')
  if (status === 507 || status === 413) throw new Error('sync_server_storage_full')
  if (status >= 300 && status < 400) throw new Error('sync_directory_redirected')
  if (status === 404) throw new Error('sync_directory_missing')
  throw new Error('sync_server_unavailable')
}

function conflict(status: number): boolean {
  return status === 409 || status === 412
}

/** No operation accepts a URL supplied by a manifest. Redirects are disabled by NetworkKit. */
export class DeviceSyncWebDav {
  private readonly root: string
  private readonly authorization: string

  constructor(draft: SyncConnectionDraft) {
    this.root = canonicalSyncDirectory(draft.directory) + '/' + SYNC_COLLECTION + '/'
    if (draft.username.includes(':') || /[\r\n\u0000]/.test(draft.username) ||
      (draft.username.length === 0 && draft.password.length > 0)) throw new Error('sync_invalid_username')
    this.authorization = draft.username.length === 0 ? '' :
      'Basic ' + new util.Base64Helper().encodeToStringSync(syncUtf8(draft.username + ':' + draft.password))
  }

  async probe(id: string, guard: SyncRequestGuard): Promise<void> {
    const mkcol = await this.request('MKCOL', '', guard)
    if (mkcol.status !== 405) requireSuccess(mkcol.status)
    const path = 'probe-' + id + '.json'
    const first = '{"probe":1}'
    const next = '{"probe":2}'
    try {
      requireSuccess((await this.request('PUT', path, guard, first, '', true)).status)
      const loaded = await this.request('GET', path, guard)
      requireSuccess(loaded.status)
      if (!strongSyncTag(loaded.etag) || loaded.body !== first) throw new Error('sync_preconditions_unsupported')
      const duplicate = await this.request('PUT', path, guard, next, '', true)
      if (!conflict(duplicate.status) || (await this.request('GET', path, guard)).body !== first) {
        throw new Error('sync_preconditions_unsupported')
      }
      requireSuccess((await this.request('PUT', path, guard, next, loaded.etag)).status)
      const updated = await this.request('GET', path, guard)
      if (updated.status !== 200 || updated.body !== next || !strongSyncTag(updated.etag) || loaded.etag === updated.etag) {
        throw new Error('sync_preconditions_unsupported')
      }
      const stale = await this.request('PUT', path, guard, first, loaded.etag)
      if (!conflict(stale.status) || (await this.request('GET', path, guard)).body !== next) {
        throw new Error('sync_preconditions_unsupported')
      }
    } finally {
      await this.cleanProbe(id, guard)
    }
  }

  async cleanProbe(id: string, guard: SyncRequestGuard): Promise<void> {
    if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error('sync_invalid_probe')
    const result = await this.request('DELETE', 'probe-' + id + '.json', guard)
    if (result.status !== 404) requireSuccess(result.status)
  }

  async readManifest(guard: SyncRequestGuard, requiredTag: string = ''): Promise<SyncRemoteManifest> {
    const response = await this.request('GET', MANIFEST, guard, '', requiredTag)
    if (conflict(response.status)) throw new Error('sync_preview_changed')
    if (response.status === 404) return { etag: '', hash: '' }
    requireSuccess(response.status)
    if (!strongSyncTag(response.etag)) throw new Error('sync_preconditions_unsupported')
    return { etag: response.etag, manifest: decodeSyncManifest(response.body), hash: syncDigest(response.body) }
  }

  async readObject(ref: SyncShardRef, guard: SyncRequestGuard): Promise<string> {
    const result = await this.request('GET', syncShardPath(ref), guard)
    if (result.status === 404) throw new Error('sync_shard_missing')
    requireSuccess(result.status)
    return result.body
  }

  async storeObject(object: SyncObject, guard: SyncRequestGuard): Promise<void> {
    const path = syncShardPath(object.ref)
    const result = await this.request('PUT', path, guard, object.body, '', true)
    if (!conflict(result.status)) requireSuccess(result.status)
    if (result.status === 409) throw new Error('sync_remote_changed')
    const existing = await this.readObject(object.ref, guard)
    if (existing !== object.body) throw new Error('sync_shard_damaged')
  }

  async publish(manifest: SyncManifest, tag: string, guard: SyncRequestGuard): Promise<boolean> {
    const body = JSON.stringify(manifest)
    if (syncUtf8(body).byteLength > SYNC_MAX_OBJECT_BYTES) throw new Error('sync_manifest_too_large')
    if (tag !== '' && !strongSyncTag(tag)) throw new Error('sync_preconditions_unsupported')
    const result = await this.request('PUT', MANIFEST, guard, body, tag, tag === '')
    if (conflict(result.status)) return false
    requireSuccess(result.status)
    return true
  }

  async sweepable(manifest: SyncManifest, guard: SyncRequestGuard): Promise<string[]> {
    // An unknown dataset may have opaque references that this writer cannot protect.
    const protectedObjects = new Set<string>()
    manifest.datasets.concat(manifest.previous).forEach((dataset: SyncDatasetRef): void => {
      dataset.shards.forEach((ref: SyncShardRef): void => { protectedObjects.add(syncShardPath(ref)) })
    })
    const result = await this.request('PROPFIND', '', guard, buildPropfindBody())
    requireSuccess(result.status)
    if (result.status !== 207) throw new Error('sync_collection_listing_failed')
    const paths = new Set<string>()
    parseWebDavMultiStatus(result.body, this.root).forEach((item: DavResource): void => {
      if (item.isCollection || !item.href.startsWith(this.root)) return
      const name = item.href.substring(this.root.length)
      const match = OBJECT_NAME.exec(name)
      if (match && Number(match[1]) < manifest.epoch && !protectedObjects.has(name)) paths.add(name)
    })
    return Array.from(paths).sort()
  }

  async removeUnreferenced(path: string, guard: SyncRequestGuard): Promise<void> {
    if (!OBJECT_NAME.test(path)) throw new Error('sync_invalid_object')
    const result = await this.request('DELETE', path, guard)
    if (result.status !== 404) requireSuccess(result.status)
  }

  private async request(method: string, path: string, guard: SyncRequestGuard, body: string = '',
    tag: string = '', create: boolean = false): Promise<SyncHttpResponse> {
    guard()
    if (path.length > 0 && path !== MANIFEST && !OBJECT_NAME.test(path) && !/^probe-[0-9a-f-]{36}\.json$/.test(path)) {
      throw new Error('sync_invalid_path')
    }
    const headers: Record<string, string> = {
      'Accept': method === 'PROPFIND' ? 'application/xml' : 'application/json',
      'Cache-Control': 'no-cache, no-store',
    }
    if (this.authorization.length > 0) headers['Authorization'] = this.authorization
    if (method === 'PROPFIND') headers['Depth'] = '1'
    if (body.length > 0) headers['Content-Type'] = method === 'PROPFIND' ? 'application/xml' : 'application/json'
    if (tag.length > 0) headers['If-Match'] = tag
    if (create) headers['If-None-Match'] = '*'
    const request = http.createHttp()
    let response: http.HttpResponse
    try {
      response = await request.request(this.root + path, {
        customMethod: method, maxRedirects: 0, usingCache: false, header: headers,
        extraData: body.length === 0 ? undefined : body,
        connectTimeout: 5000, readTimeout: 10000, maxLimit: SYNC_MAX_OBJECT_BYTES,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
      })
    } catch (error) {
      const code = (error as BusinessError).code
      if (code === 2300047) throw new Error('sync_directory_redirected')
      if (code === 2300060 || code === 2300051 || code === 2300035) throw new Error('sync_tls_failed')
      throw new Error('sync_network_failed')
    } finally {
      request.destroy()
    }
    guard()
    const data = response.result instanceof ArrayBuffer ? new Uint8Array(response.result) : new Uint8Array(0)
    const text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(data)
    return { status: response.responseCode, body: text, etag: responseTag(response.header) }
  }
}

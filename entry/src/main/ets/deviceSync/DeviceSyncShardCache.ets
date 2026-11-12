import { fileIo as fs } from '@kit.CoreFileKit'
import { taskpool, util } from '@kit.ArkTS'
import { syncDigest, SyncShardRef, SYNC_MAX_OBJECT_BYTES } from './DeviceSyncWire'

// This cache is disposable: it is never proof that the remote object exists.
// The Engine must validate every disk hit using the normal dataset decoder.
interface CacheFile {
  name: string
  size: number
  modified: number
}

@Concurrent
function readCachedShard(root: string, scope: string, group: string, dataset: string, ref: SyncShardRef): string {
  try {
    const key = syncDigest(JSON.stringify([scope, group, dataset, ref.bucket, ref.epoch, ref.hash, ref.bytes]))
    const path = root + '/' + key + '.json'
    if (!fs.accessSync(path) || fs.statSync(path).size !== ref.bytes) return ''
    const body = fs.readTextSync(path, { encoding: 'utf-8' })
    return body
  } catch (_error) { return '' }
}

@Concurrent
function writeCachedShard(root: string, scope: string, group: string, dataset: string,
  ref: SyncShardRef, body: string): boolean {
  let file: fs.File | undefined
  let temporary = ''
  try {
    const key = syncDigest(JSON.stringify([scope, group, dataset, ref.bucket, ref.epoch, ref.hash, ref.bytes]))
    if (!fs.accessSync(root)) fs.mkdirSync(root, true)
    const path = root + '/' + key + '.json'
    temporary = path + '.' + util.generateRandomUUID() + '.tmp'
    file = fs.openSync(temporary, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    if (fs.writeSync(file.fd, body, { encoding: 'utf-8' }) !== ref.bytes) return false
    fs.closeSync(file)
    file = undefined
    fs.renameSync(temporary, path)
    temporary = ''
    return true
  } catch (_error) { return false } finally {
    if (file !== undefined) { try { fs.closeSync(file) } catch (_error) {} }
    if (temporary.length > 0) { try { fs.unlinkSync(temporary) } catch (_error) {} }
  }
}

@Concurrent
function pruneShardCache(root: string): void {
  try {
    if (!fs.accessSync(root)) return
    const files: CacheFile[] = []
    let total = 0
    for (const name of fs.listFileSync(root)) {
      if (/^[0-9a-f]{64}\.json\.[0-9a-f-]{36}\.tmp$/.test(name)) {
        try {
          const stat = fs.statSync(root + '/' + name)
          if (Date.now() - stat.mtime * 1000 > 24 * 60 * 60 * 1000) fs.unlinkSync(root + '/' + name)
        } catch (_error) {}
        continue
      }
      if (!/^[0-9a-f]{64}\.json$/.test(name)) continue
      try {
        const stat = fs.statSync(root + '/' + name)
        files.push({ name, size: stat.size, modified: stat.mtime })
        total += stat.size
      } catch (_error) {}
    }
    files.sort((a: CacheFile, b: CacheFile): number => a.modified - b.modified)
    for (const file of files) {
      if (total <= 128 * SYNC_MAX_OBJECT_BYTES) break
      try { fs.unlinkSync(root + '/' + file.name); total -= file.size } catch (_error) {}
    }
  } catch (_error) {}
}

export interface SyncShardCachePort {
  read(scope: string, group: string, dataset: string, ref: SyncShardRef): Promise<string | undefined>
  write(scope: string, group: string, dataset: string, ref: SyncShardRef, body: string): Promise<void>
}

export class DeviceSyncShardCache implements SyncShardCachePort {
  private readonly root: string
  private writes: number = 0
  private pruning?: Promise<void>

  constructor(cacheDir: string) { this.root = cacheDir + '/device-sync-shards' }

  async read(scope: string, group: string, dataset: string, ref: SyncShardRef): Promise<string | undefined> {
    if (this.pruning === undefined) {
      this.pruning = taskpool.execute(pruneShardCache, this.root).then((): void => {}).catch((): void => {})
    }
    const body = await taskpool.execute(readCachedShard, this.root, scope, group, dataset, ref) as string
    return body.length === 0 ? undefined : body
  }

  async write(scope: string, group: string, dataset: string, ref: SyncShardRef, body: string): Promise<void> {
    try {
      const written = await taskpool.execute(writeCachedShard, this.root, scope, group, dataset, ref, body) as boolean
      if (!written) return
      this.writes++
      if (this.writes >= 16) {
        this.writes = 0
        await this.pruning
        this.pruning = taskpool.execute(pruneShardCache, this.root).then((): void => {}).catch((): void => {})
      }
    } catch (_error) {}
  }
}

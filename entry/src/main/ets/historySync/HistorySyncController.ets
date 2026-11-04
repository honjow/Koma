import { common } from '@kit.AbilityKit'
import { asset } from '@kit.AssetStoreKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { util } from '@kit.ArkTS'
import { BackupRestoreActivity } from '../model/BackupRestoreActivity'
import { appReaderSessionStore, PersistentReaderSessionStore } from '../model/ReaderSessionStore'
import { HistorySyncConfig, HistorySyncProvider, WebDavHistorySync } from './WebDavHistorySync'

interface StoredHistorySyncConfig extends HistorySyncConfig {
  lastSuccessAt?: number
  status?: string
}

function emptyConfig(): StoredHistorySyncConfig {
  return { enabled: false, directoryUrl: '', username: '', password: '' }
}

function configAsset(): asset.AssetMap {
  const attributes: asset.AssetMap = new Map()
  attributes.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto('koma.reading-history.sync.v1'))
  return attributes
}

async function readConfig(): Promise<StoredHistorySyncConfig> {
  const query = configAsset()
  query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
  try {
    const rows = await asset.query(query)
    if (rows.length === 0) return emptyConfig()
    const secret = rows[0].get(asset.Tag.SECRET) as Uint8Array
    const value = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(secret)) as StoredHistorySyncConfig
    if (typeof value.enabled !== 'boolean' || typeof value.directoryUrl !== 'string' ||
      typeof value.username !== 'string' || typeof value.password !== 'string') throw new Error('storage')
    return value
  } catch (error) {
    if ((error as BusinessError).code === 24000002) return emptyConfig()
    throw new Error('storage')
  }
}

async function writeConfig(value: StoredHistorySyncConfig): Promise<void> {
  // App-private, device-bound asset. An ordinary backup must not enable sync
  // against a different device's account or export a WebDAV password.
  const secret = new util.TextEncoder().encodeInto(JSON.stringify(value))
  if (secret.byteLength > 1024) throw new Error('config-size')
  const attributes = configAsset()
  attributes.set(asset.Tag.SECRET, secret)
  attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
  attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
  try {
    await asset.add(attributes)
  } catch (_error) {
    throw new Error('storage')
  }
}

@ObservedV2
export class HistorySyncController {
  @Trace ready: boolean = false
  @Trace loadFailed: boolean = false
  @Trace busy: boolean = false
  @Trace status: string = ''
  @Trace lastSuccessAt: number = 0
  @Trace revision: number = 0
  private config: HistorySyncConfig = emptyConfig()
  private loaded?: Promise<void>
  private persistence: Promise<void> = Promise.resolve()
  private provider?: HistorySyncProvider
  private epoch: number = 0
  private store?: PersistentReaderSessionStore
  private foreground: boolean = false
  private editingDepth: number = 0
  private timer: number = -1
  private lastAttemptAt: number = 0
  private failures: number = 0

  async initialize(): Promise<void> {
    if (this.ready) {
      await this.persistence
      return
    }
    if (this.loaded === undefined) {
      this.loadFailed = false
      this.loaded = readConfig().then((value: StoredHistorySyncConfig): void => {
        this.config = { enabled: value.enabled, directoryUrl: value.directoryUrl,
          username: value.username, password: value.password }
        this.status = value.status ?? ''
        this.lastSuccessAt = value.lastSuccessAt ?? 0
        this.ready = true
      }).catch((): void => {
        this.loadFailed = true
      }).finally((): void => { this.loaded = undefined })
    }
    await this.loaded
  }

  current(): HistorySyncConfig {
    return { enabled: this.config.enabled, directoryUrl: this.config.directoryUrl,
      username: this.config.username, password: this.config.password }
  }

  startEditing(): void {
    this.editingDepth += 1
    this.cancelTimer()
  }

  finishEditing(): void {
    this.editingDepth = Math.max(0, this.editingDepth - 1)
    this.schedule(3000)
  }

  async save(next: HistorySyncConfig): Promise<void> {
    if (!this.ready) throw new Error('storage')
    const config: HistorySyncConfig = { enabled: next.enabled, directoryUrl: next.directoryUrl.trim(),
      username: next.username.trim(), password: next.password }
    const serialized = this.persistence.then(async (): Promise<void> => {
      if (JSON.stringify(config) === JSON.stringify(this.config)) return
      const accountChanged = config.directoryUrl !== this.config.directoryUrl ||
        config.username !== this.config.username || config.password !== this.config.password
      await writeConfig({ enabled: config.enabled, directoryUrl: config.directoryUrl,
        username: config.username, password: config.password,
        lastSuccessAt: accountChanged ? 0 : this.lastSuccessAt, status: accountChanged ? '' : this.status })
      this.config = config
      this.epoch += 1
      this.cancelTimer()
      if (accountChanged) {
        this.provider = undefined
        this.status = ''
        this.lastSuccessAt = 0
        this.failures = 0
        this.lastAttemptAt = 0
      }
    })
    this.persistence = serialized.catch((): void => {})
    await serialized
  }

  async setForeground(context: common.UIAbilityContext, foreground: boolean): Promise<void> {
    this.context = context
    this.foreground = foreground
    if (!foreground) {
      this.cancelTimer()
      return
    }
    await this.initialize()
    if (this.store === undefined) {
      try {
        this.store = appReaderSessionStore(context.filesDir)
        this.store.onLocalHistoryCommitted((): void => { this.schedule(15000) })
      } catch (_error) {
        return
      }
    }
    this.schedule(3000)
  }

  async run(context: common.UIAbilityContext, test: boolean): Promise<string> {
    if (this.busy || (!test && (!this.config.enabled || BackupRestoreActivity.isRestoring()))) return 'cancelled'
    this.cancelTimer()
    this.busy = true
    const epoch = this.epoch
    try {
      if (this.provider === undefined) this.provider = new WebDavHistorySync(this.config)
      if (test) {
        await this.provider.test()
        return epoch === this.epoch ? 'ok' : 'cancelled'
      }
      this.lastAttemptAt = Date.now()
      const store = this.store ?? appReaderSessionStore(context.filesDir)
      if (!store.flush()) throw new Error('storage')
      const snapshot = store.sourceSyncSnapshot()
      const storageRevision = store.sourceSyncReloadRevision()
      const active = (): boolean => epoch === this.epoch && this.config.enabled &&
        !BackupRestoreActivity.isRestoring() && store.sourceSyncReloadRevision() === storageRevision
      const merged = await this.provider.reconcile(snapshot, active)
      if (!active()) return 'cancelled'
      const changed = store.applySourceSync(merged)
      if (changed) this.revision += 1
      this.status = 'ok'
      this.lastSuccessAt = Date.now()
      this.failures = 0
      await this.saveRunStatus(epoch)
      return 'ok'
    } catch (error) {
      if (epoch !== this.epoch) return 'cancelled'
      const message = (error as Error).message
      const codes: string[] = ['url', 'conditions', 'cleanup', 'data', 'size', 'network',
        'conflict', 'cancelled', 'storage', 'config-size']
      const code = codes.includes(message) || /^http-[0-9]{3}$/.test(message) ? message : 'data'
      if (!test && code !== 'cancelled') {
        this.status = code
        this.failures = Math.min(4, this.failures + 1)
        await this.saveRunStatus(epoch).catch((): void => {})
        if (code === 'network' || code === 'conflict') this.schedule(60000)
      }
      return code
    } finally {
      this.busy = false
    }
  }

  private async saveRunStatus(epoch: number): Promise<void> {
    const serialized = this.persistence.then(async (): Promise<void> => {
      if (epoch !== this.epoch) return
      const config = this.current()
      await writeConfig({ enabled: config.enabled, directoryUrl: config.directoryUrl,
        username: config.username, password: config.password, lastSuccessAt: this.lastSuccessAt, status: this.status })
    })
    this.persistence = serialized.catch((): void => {})
    await serialized
  }

  private cancelTimer(): void {
    if (this.timer >= 0) clearTimeout(this.timer)
    this.timer = -1
  }

  private context?: common.UIAbilityContext

  private schedule(delay: number): void {
    const context = this.context
    if (context === undefined || !this.foreground || this.editingDepth > 0 || !this.ready || !this.config.enabled ||
      this.config.directoryUrl.length === 0 || this.timer >= 0) return
    const spacing = this.failures === 0 ? 45000 : Math.min(300000, 60000 * Math.pow(2, this.failures - 1))
    const next = Math.max(delay, this.lastAttemptAt + spacing - Date.now())
    this.timer = setTimeout((): void => {
      this.timer = -1
      if (this.busy) {
        this.schedule(15000)
      } else {
        void this.run(context, false)
      }
    }, next)
  }
}

export const historySyncController = new HistorySyncController()

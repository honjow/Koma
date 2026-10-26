import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { common } from '@kit.AbilityKit'
import { asset } from '@kit.AssetStoreKit'
import { AppStorageV2 } from '@kit.ArkUI'
import { buffer } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'

/** Only this non-sensitive revision is reactive; credentials never enter AppStorage or backups. */
@ObservedV2
export class KomaTranslationSettingsState {
  @Trace revision: number = 0
}

export function connectKomaTranslationSettings(): KomaTranslationSettingsState {
  return AppStorageV2.connect(KomaTranslationSettingsState, 'komaReaderTranslation',
    () => new KomaTranslationSettingsState())!
}

export class KomaTranslationSettingsSnapshot {
  revision: number = 0
  route: string = 'local'
  sourceLanguage: string = 'auto'
  targetLanguage: string = 'zh-CN'
  apiBaseUrl: string = ''
  apiModel: string = ''
  apiKey: string = ''
  multimodal: boolean = true
  sidecarUrl: string = ''
  sidecarUsername: string = ''
  sidecarPassword: string = ''
  detectionProfile: string = 'high_recall'
  inpaintingProfile: string = 'quality'
  toriiApiKey: string = ''
  toriiModel: string = 'gemini-3.1-flash-lite'
  toriiFont: string = 'noto'

  textConfigured(): boolean {
    return this.apiBaseUrl.length > 0 && this.apiModel.length > 0 && this.apiKey.length > 0
  }

  configured(): boolean {
    if (this.route === 'torii_whole_page') return this.toriiApiKey.length > 0
    return this.textConfigured() && (this.route === 'local' || this.sidecarUrl.length > 0)
  }

  copy(): KomaTranslationSettingsSnapshot {
    const value = new KomaTranslationSettingsSnapshot()
    value.revision = this.revision
    value.route = this.route
    value.sourceLanguage = this.sourceLanguage
    value.targetLanguage = this.targetLanguage
    value.apiBaseUrl = this.apiBaseUrl
    value.apiModel = this.apiModel
    value.apiKey = this.apiKey
    value.multimodal = this.multimodal
    value.sidecarUrl = this.sidecarUrl
    value.sidecarUsername = this.sidecarUsername
    value.sidecarPassword = this.sidecarPassword
    value.detectionProfile = this.detectionProfile
    value.inpaintingProfile = this.inpaintingProfile
    value.toriiApiKey = this.toriiApiKey
    value.toriiModel = this.toriiModel
    value.toriiFont = this.toriiFont
    return value
  }
}

const TRANSLATION_ASSET_ALIAS: string = 'koma.reader.translation.configuration.v1'
const MAX_CONFIGURATION_CHARS: number = 64 * 1024

class KomaTranslationManifest {
  format: string = 'koma-reader-translation-chunks-v1'
  id: string = ''
  revision: number = 0
  chunks: number = 0
  bytes: number = 0
  sha256: string = ''
}

/**
 * AssetStore SECRET is limited to 1024 bytes (Huawei asset-js-add).
 * Immutable encrypted chunks become current only with one atomic short manifest write.
 * Readers/writers share one queue; failed staging never changes the committed configuration.
 */
export class KomaTranslationSettings {
  private static writes: Promise<void> = Promise.resolve()

  static runtimeRevision(): number { return connectKomaTranslationSettings().revision }

  static assertRevision(expected: number, actual: number = KomaTranslationSettings.runtimeRevision()): void {
    if (expected >= 0 && (actual !== expected || KomaTranslationSettings.runtimeRevision() !== expected)) {
      throw new Error('reader_translation_configuration_changed')
    }
  }

  private static bytes(value: string): Uint8Array {
    return new Uint8Array(buffer.from(value, 'utf8').buffer)
  }

  private static identity(alias: string = TRANSLATION_ASSET_ALIAS): asset.AssetMap {
    const values: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    values.set(asset.Tag.ALIAS, KomaTranslationSettings.bytes(alias))
    return values
  }

  static load(_context: common.UIAbilityContext): Promise<KomaTranslationSettingsSnapshot> {
    const task = KomaTranslationSettings.writes.then((): Promise<KomaTranslationSettingsSnapshot> =>
      KomaTranslationSettings.read())
    KomaTranslationSettings.writes = task.then((): void => {}, (): void => {})
    return task
  }

  private static text(bytes: Uint8Array): string {
    const exact = new Uint8Array(bytes.byteLength)
    exact.set(bytes)
    return buffer.from(exact.buffer).toString('utf8')
  }

  private static hex(bytes: Uint8Array): string {
    return Array.from(bytes).map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  }

  private static digest(bytes: Uint8Array): string {
    const md = cryptoFramework.createMd('SHA256')
    md.updateSync({ data: bytes })
    return KomaTranslationSettings.hex(md.digestSync().data)
  }

  private static chunkAlias(id: string, index: number): string {
    return `${TRANSLATION_ASSET_ALIAS}.chunk.${id}.${index}`
  }

  private static async readAsset(alias: string = TRANSLATION_ASSET_ALIAS): Promise<Uint8Array | null> {
    const query = KomaTranslationSettings.identity(alias)
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    query.set(asset.Tag.RETURN_LIMIT, 1)
    let rows: asset.AssetMap[]
    try { rows = await asset.query(query) }
    catch (error) {
      if ((error as BusinessError).code === 24000002) return null
      throw new Error('reader_translation_configuration_read_failed')
    }
    if (rows.length === 0) return null
    const secret = rows[0].get(asset.Tag.SECRET) as Uint8Array | undefined
    if (secret === undefined || secret.byteLength === 0 || secret.byteLength > 1024) {
      throw new Error('reader_translation_configuration_invalid')
    }
    return secret
  }

  private static manifest(raw: string): KomaTranslationManifest | null {
    let value: KomaTranslationManifest
    try { value = JSON.parse(raw) as KomaTranslationManifest }
    catch (_error) { throw new Error('reader_translation_configuration_invalid') }
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error('reader_translation_configuration_invalid')
    }
    if (value.format === undefined) return null // Previously saved short inline configuration.
    if (value.format !== 'koma-reader-translation-chunks-v1' || !/^[0-9a-f]{32}$/.test(value.id) ||
      !Number.isSafeInteger(value.revision) || value.revision < 0 || !Number.isInteger(value.chunks) ||
      !Number.isInteger(value.bytes) || value.bytes <= 0 || value.bytes > MAX_CONFIGURATION_CHARS * 4 ||
      value.chunks !== Math.ceil(value.bytes / 1024) || !/^[0-9a-f]{64}$/.test(value.sha256)) {
      throw new Error('reader_translation_configuration_invalid')
    }
    return value
  }

  private static async read(): Promise<KomaTranslationSettingsSnapshot> {
    const root = await KomaTranslationSettings.readAsset()
    if (root === null) return new KomaTranslationSettingsSnapshot()
    let raw = KomaTranslationSettings.text(root)
    const manifest = KomaTranslationSettings.manifest(raw)
    if (manifest !== null) {
      const bytes = new Uint8Array(manifest.bytes)
      let offset = 0
      for (let index = 0; index < manifest.chunks; index += 1) {
        const chunk = await KomaTranslationSettings.readAsset(KomaTranslationSettings.chunkAlias(manifest.id, index))
        const expected = Math.min(1024, manifest.bytes - offset)
        if (chunk === null || chunk.byteLength !== expected) throw new Error('reader_translation_configuration_invalid')
        bytes.set(chunk, offset); offset += chunk.byteLength
      }
      if (KomaTranslationSettings.digest(bytes) !== manifest.sha256) throw new Error('reader_translation_configuration_invalid')
      raw = KomaTranslationSettings.text(bytes)
    }
    const value = KomaTranslationSettings.decode(raw)
    if (manifest !== null && value.revision !== manifest.revision) throw new Error('reader_translation_configuration_invalid')
    connectKomaTranslationSettings().revision = Math.max(KomaTranslationSettings.runtimeRevision(), value.revision)
    return value
  }

  private static async writeAsset(alias: string, bytes: Uint8Array): Promise<void> {
    if (bytes.byteLength === 0 || bytes.byteLength > 1024) throw new Error('reader_translation_configuration_invalid')
    const attrs = KomaTranslationSettings.identity(alias)
    attrs.set(asset.Tag.SECRET, bytes)
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attrs.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    await asset.add(attrs)
  }

  private static async removeChunks(id: string, count: number): Promise<void> {
    for (let index = 0; index < count; index += 1) {
      try { await asset.remove(KomaTranslationSettings.identity(KomaTranslationSettings.chunkAlias(id, index))) }
      catch (_error) { /* A cleanup failure cannot undo an already committed manifest. */ }
    }
  }

  static save(_context: common.UIAbilityContext, next: KomaTranslationSettingsSnapshot): Promise<void> {
    const value = next.copy()
    const task = KomaTranslationSettings.writes.then(async (): Promise<void> => {
      KomaTranslationSettings.validate(value)
      const root = await KomaTranslationSettings.readAsset()
      const previous = root === null ? null : KomaTranslationSettings.manifest(KomaTranslationSettings.text(root))
      const previousRevision = previous?.revision ?? (root === null ? 0 :
        KomaTranslationSettings.decode(KomaTranslationSettings.text(root)).revision)
      value.revision = Math.max(Date.now(), KomaTranslationSettings.runtimeRevision() + 1, previousRevision + 1)
      const raw = JSON.stringify(value)
      if (raw.length > MAX_CONFIGURATION_CHARS) throw new Error('reader_translation_configuration_invalid')
      const bytes = KomaTranslationSettings.bytes(raw)
      const manifest = new KomaTranslationManifest()
      manifest.id = KomaTranslationSettings.hex(cryptoFramework.createRandom().generateRandomSync(16).data)
      if (manifest.id === previous?.id) throw new Error('reader_translation_configuration_write_failed')
      manifest.revision = value.revision
      manifest.bytes = bytes.byteLength
      manifest.chunks = Math.ceil(bytes.byteLength / 1024)
      manifest.sha256 = KomaTranslationSettings.digest(bytes)
      let staged = 0
      try {
        for (let index = 0; index < manifest.chunks; index += 1) {
          staged = index + 1
          await KomaTranslationSettings.writeAsset(KomaTranslationSettings.chunkAlias(manifest.id, index),
            bytes.slice(index * 1024, Math.min(bytes.byteLength, (index + 1) * 1024)))
        }
        await KomaTranslationSettings.writeAsset(TRANSLATION_ASSET_ALIAS,
          KomaTranslationSettings.bytes(JSON.stringify(manifest)))
      } catch (_error) {
        await KomaTranslationSettings.removeChunks(manifest.id, staged)
        throw new Error('reader_translation_configuration_write_failed')
      }
      connectKomaTranslationSettings().revision = value.revision
      if (previous !== null) await KomaTranslationSettings.removeChunks(previous.id, previous.chunks)
    })
    KomaTranslationSettings.writes = task.then((): void => {}, (): void => {})
    return task
  }

  private static decode(raw: string): KomaTranslationSettingsSnapshot {
    if (raw.length === 0 || raw.length > MAX_CONFIGURATION_CHARS) throw new Error('reader_translation_configuration_invalid')
    let record: Record<string, Object>
    try { record = JSON.parse(raw) as Record<string, Object> }
    catch (_error) { throw new Error('reader_translation_configuration_invalid') }
    if (record === null || typeof record !== 'object' || Array.isArray(record)) throw new Error('reader_translation_configuration_invalid')
    const value = new KomaTranslationSettingsSnapshot()
    value.route = KomaTranslationSettings.stringField(record, 'route', value.route)
    value.sourceLanguage = KomaTranslationSettings.stringField(record, 'sourceLanguage', value.sourceLanguage)
    value.targetLanguage = KomaTranslationSettings.stringField(record, 'targetLanguage', value.targetLanguage)
    value.apiBaseUrl = KomaTranslationSettings.stringField(record, 'apiBaseUrl', '')
    value.apiModel = KomaTranslationSettings.stringField(record, 'apiModel', '')
    value.apiKey = KomaTranslationSettings.stringField(record, 'apiKey', '')
    value.multimodal = record['multimodal'] !== false
    value.sidecarUrl = KomaTranslationSettings.stringField(record, 'sidecarUrl', '')
    value.sidecarUsername = KomaTranslationSettings.stringField(record, 'sidecarUsername', '')
    value.sidecarPassword = KomaTranslationSettings.stringField(record, 'sidecarPassword', '')
    value.detectionProfile = KomaTranslationSettings.stringField(record, 'detectionProfile', value.detectionProfile)
    value.inpaintingProfile = KomaTranslationSettings.stringField(record, 'inpaintingProfile', value.inpaintingProfile)
    value.toriiApiKey = KomaTranslationSettings.stringField(record, 'toriiApiKey', '')
    value.toriiModel = KomaTranslationSettings.stringField(record, 'toriiModel', value.toriiModel)
    value.toriiFont = KomaTranslationSettings.stringField(record, 'toriiFont', value.toriiFont)
    value.revision = typeof record['revision'] === 'number' ? record['revision'] as number : 0
    KomaTranslationSettings.validate(value)
    return value
  }

  private static stringField(record: Record<string, Object>, key: string, fallback: string): string {
    return typeof record[key] === 'string' ? record[key] as string : fallback
  }

  private static validate(value: KomaTranslationSettingsSnapshot): void {
    const languages: string[] = ['auto', 'zh-CN', 'zh-TW', 'en', 'ja', 'ko', 'fr', 'de', 'es', 'pt', 'ru']
    if (!['local', 'self_hosted', 'torii_whole_page'].includes(value.route) ||
      !languages.includes(value.sourceLanguage) || value.targetLanguage === 'auto' ||
      !languages.includes(value.targetLanguage) || !Number.isSafeInteger(value.revision) || value.revision < 0) {
      throw new Error('reader_translation_configuration_invalid')
    }
    if ([value.apiBaseUrl, value.sidecarUrl].some((url: string): boolean =>
      url.length > 2048 || (url.length > 0 && !/^https?:\/\/[^\s/@?#]+(?:\/[^\s]*)?$/.test(url))) ||
      value.apiModel.length > 160 || value.toriiModel.length > 160 || value.apiKey.length > 16384 ||
      value.toriiApiKey.length > 8192 || value.sidecarPassword.length > 2048 || value.sidecarUsername.length > 50 ||
      /[\r\n]/.test(value.apiKey + value.toriiApiKey + value.apiModel + value.toriiModel)) {
      throw new Error('reader_translation_configuration_invalid')
    }
  }
}

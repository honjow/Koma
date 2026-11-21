import type { relationalStore } from '@kit.ArkData'
import type { SourceRuntimeRegistryPersistedEntry, SourceRuntimeRegistryRouteStatus } from './SourceRuntimeRegistry'
import type { SourceChapterOrder } from './SourceChapterOrder'
import { booleanColumn, booleanValue, integerColumn, LocalColumnValue, LocalDataRows, textColumn } from '../model/LocalDataRows'

interface RegistryRow {
  order: number
  occurrence: number
  entry: SourceRuntimeRegistryPersistedEntry
}

const registry = new LocalDataRows<RegistryRow>('source_registry_entries', ['source_id', 'source_occurrence'], [
    'list_order', 'chapter_order', 'manifest_id', 'manifest_name', 'manifest_version', 'route',
    'import_status', 'wasm_byte_count', 'hash_ok', 'allows_network', 'enabled', 'language',
    'source_type', 'nsfw', 'wasm_path', 'manifest_path', 'archive_path', 'package_icon_path',
    'catalog_origin', 'session_storage_identity', 'package_homepage', 'package_author', 'package_description', 'package_content_rating',
    'package_min_app_version', 'presentation_description', 'presentation_icon', 'has_localized_names', 'has_capabilities', 'has_web_origins',
    'has_required_decodes', 'auth_kind', 'login_url', 'username_label', 'password_label', 'credential_storage',
    'user_agent', 'has_login_urls', 'has_cookie_names', 'token_version', 'token_storage_key', 'token_api_origin',
    'token_verify_path', 'token_image_key_derivation',
  ], 'list_order',
  (row: RegistryRow): LocalColumnValue[] => {
    const authentication = row.entry.authentication
    return [row.entry.sourceId, row.occurrence, row.order,
      row.entry.chapterOrder ?? null, row.entry.manifestId ?? null, row.entry.manifestName ?? null,
      row.entry.manifestVersion ?? null, row.entry.route ?? null, row.entry.importStatus ?? null,
      row.entry.wasmByteCount ?? null, booleanValue(row.entry.hashOk), booleanValue(row.entry.network),
      booleanValue(row.entry.enabled), row.entry.language ?? null, row.entry.type ?? null,
      booleanValue(row.entry.nsfw), row.entry.wasmPath ?? null, row.entry.manifestPath ?? null,
      row.entry.archivePath ?? null, row.entry.packageIconPath ?? null, row.entry.catalogOrigin ?? null,
      row.entry.sessionStorageIdentity ?? null, row.entry.packageHomepage ?? null, row.entry.packageAuthor ?? null,
      row.entry.packageDescription ?? null, row.entry.packageContentRating ?? null, row.entry.packageMinAppVersion ?? null,
      row.entry.presentationDescription ?? null, row.entry.presentationIcon ?? null, booleanValue(row.entry.localizedNames !== undefined),
      booleanValue(row.entry.capabilities !== undefined), booleanValue(row.entry.webSessionOrigins !== undefined), booleanValue(row.entry.requiredImageDecodes !== undefined),
      authentication?.kind ?? null, authentication?.loginUrl ?? null, authentication?.usernameLabel ?? null,
      authentication?.passwordLabel ?? null, authentication?.credentialStorage ?? null, authentication?.userAgent ?? null,
      booleanValue(authentication?.loginUrls !== undefined), booleanValue(authentication?.sessionCookieNames !== undefined), authentication?.webToken?.version ?? null,
      authentication?.webToken?.storageKey ?? null, authentication?.webToken?.apiOrigin ?? null, authentication?.webToken?.verifyPath ?? null,
      authentication?.webToken?.imageKeyDerivation ?? null,]
  },
  (row: relationalStore.ResultSet): RegistryRow => ({
    occurrence: row.getLong(1), order: row.getLong(2),
    entry: {
      sourceId: row.getString(0),
      chapterOrder: textColumn(row, 3) as SourceChapterOrder | undefined,
      manifestId: textColumn(row, 4) as string,
      manifestName: textColumn(row, 5) as string,
      manifestVersion: textColumn(row, 6) as string,
      route: textColumn(row, 7) as string,
      importStatus: textColumn(row, 8) as SourceRuntimeRegistryRouteStatus,
      wasmByteCount: integerColumn(row, 9) as number,
      hashOk: booleanColumn(row, 10) as boolean,
      network: booleanColumn(row, 11) as boolean,
      enabled: booleanColumn(row, 12),
      language: textColumn(row, 13),
      type: textColumn(row, 14),
      nsfw: booleanColumn(row, 15),
      wasmPath: textColumn(row, 16),
      manifestPath: textColumn(row, 17),
      archivePath: textColumn(row, 18),
      packageIconPath: textColumn(row, 19),
      catalogOrigin: textColumn(row, 20),
      sessionStorageIdentity: textColumn(row, 21),
      packageHomepage: textColumn(row, 22),
      packageAuthor: textColumn(row, 23),
      packageDescription: textColumn(row, 24),
      packageContentRating: textColumn(row, 25),
      packageMinAppVersion: textColumn(row, 26),
      presentationDescription: textColumn(row, 27),
      presentationIcon: textColumn(row, 28),
      localizedNames: row.getLong(29) === 0 ? undefined : {},
      capabilities: row.getLong(30) === 0 ? undefined : [],
      webSessionOrigins: row.getLong(31) === 0 ? undefined : [],
      requiredImageDecodes: row.getLong(32) === 0 ? undefined : [],
      authentication: row.isColumnNull(33) ? undefined : {
        kind: textColumn(row, 33) as 'web' | 'credentials',
        loginUrl: textColumn(row, 34) as string,
        usernameLabel: textColumn(row, 35),
        passwordLabel: textColumn(row, 36),
        credentialStorage: textColumn(row, 37) as 'private' | 'memory' | undefined,
        userAgent: textColumn(row, 38),
        loginUrls: row.getLong(39) === 0 ? undefined : [],
        sessionCookieNames: row.getLong(40) === 0 ? undefined : [],
        webToken: row.isColumnNull(41) ? undefined : {
          version: integerColumn(row, 41) as number,
          storageKey: textColumn(row, 42) as string,
          apiOrigin: textColumn(row, 43) as string,
          verifyPath: textColumn(row, 44) as string,
          imageKeyDerivation: textColumn(row, 45) as 'sha512_cbc' | undefined,
          verifyIdentityPath: [],
        },
      },
    },
  }))

interface RegistryAttribute {
  sourceId: string
  occurrence: number
  kind: string
  order: number
  label?: string
  value: string
}

const attributes = new LocalDataRows<RegistryAttribute>('source_registry_attributes',
  ['source_id', 'source_occurrence', 'attribute_kind', 'item_order'], ['attribute_label', 'attribute_value'],
  'source_id, source_occurrence, attribute_kind, item_order',
  (row: RegistryAttribute): LocalColumnValue[] => [row.sourceId, row.occurrence, row.kind, row.order, row.label ?? null, row.value],
  (row: relationalStore.ResultSet): RegistryAttribute => ({ sourceId: row.getString(0), occurrence: row.getLong(1),
    kind: row.getString(2), order: row.getLong(3), label: textColumn(row, 4), value: row.getString(5) }))

function addAttributes(out: RegistryAttribute[], row: RegistryRow, kind: string, values?: string[]): void {
  values?.forEach((value: string, order: number): void => {
    out.push({ sourceId: row.entry.sourceId, occurrence: row.occurrence, kind, order, value })
  })
}

function registryKey(sourceId: string, occurrence: number): string {
  return JSON.stringify([sourceId, occurrence])
}

export function readSourceRegistryRows(store: relationalStore.RdbStore): SourceRuntimeRegistryPersistedEntry[] {
  const entries = registry.read(store)
  const byId = new Map<string, SourceRuntimeRegistryPersistedEntry>()
  for (const row of entries) byId.set(registryKey(row.entry.sourceId, row.occurrence), row.entry)
  for (const attr of attributes.read(store)) {
    const entry = byId.get(registryKey(attr.sourceId, attr.occurrence))
    if (entry === undefined) throw new Error('source_registry_orphan_attribute')
    if (attr.kind === 'localized_name' && entry.localizedNames !== undefined && attr.label !== undefined) {
      entry.localizedNames[attr.label] = attr.value
    }
    if (attr.kind === 'capability') entry.capabilities?.push(attr.value)
    if (attr.kind === 'web_origin') entry.webSessionOrigins?.push(attr.value)
    if (attr.kind === 'required_decode') entry.requiredImageDecodes?.push(attr.value)
    if (attr.kind === 'login_url') entry.authentication?.loginUrls?.push(attr.value)
    if (attr.kind === 'cookie_name') entry.authentication?.sessionCookieNames?.push(attr.value)
    if (attr.kind === 'verify_identity') entry.authentication?.webToken?.verifyIdentityPath.push(attr.value)
  }
  return entries.map((row: RegistryRow): SourceRuntimeRegistryPersistedEntry => row.entry)
}

export function replaceSourceRegistryRows(store: relationalStore.RdbStore, entries: SourceRuntimeRegistryPersistedEntry[]): void {
  const occurrences = new Map<string, number>()
  const related: RegistryAttribute[] = []
  const rows = entries.map((entry: SourceRuntimeRegistryPersistedEntry, order: number): RegistryRow => {
    if (entry === null || typeof entry.sourceId !== 'string' || entry.sourceId.length === 0) throw new Error('metadata_invalid')
    const occurrence = occurrences.get(entry.sourceId) ?? 0
    occurrences.set(entry.sourceId, occurrence + 1)
    const row: RegistryRow = { entry, order, occurrence }
    const names = entry.localizedNames
    if (names !== undefined) {
      Object.keys(names).forEach((label: string, index: number): void => {
        related.push({ sourceId: entry.sourceId, occurrence, kind: 'localized_name', order: index, label, value: names[label] })
      })
    }
    addAttributes(related, row, 'capability', entry.capabilities)
    addAttributes(related, row, 'web_origin', entry.webSessionOrigins)
    addAttributes(related, row, 'required_decode', entry.requiredImageDecodes)
    addAttributes(related, row, 'login_url', entry.authentication?.loginUrls)
    addAttributes(related, row, 'cookie_name', entry.authentication?.sessionCookieNames)
    addAttributes(related, row, 'verify_identity', entry.authentication?.webToken?.verifyIdentityPath)
    return row
  })
  registry.replace(store, rows)
  attributes.replace(store, related)
}

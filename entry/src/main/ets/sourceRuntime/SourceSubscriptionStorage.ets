import { common } from '@kit.AbilityKit'
import { preferences, relationalStore } from '@kit.ArkData'
import { syncCatalogAddress, syncPublicLabel } from '../deviceSync/DeviceSyncData'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase } from '../model/UserDataDatabase'
import { UserKeyedRecords, UserRecordValues, writeUserRecords } from '../model/UserKeyedRecords'
import { normalizeSourceIndexRepositories, parseSavedSourceIndexRepositories, SourceIndexRepository,
  subscriptionIdentity } from './SourceIndexMetadata'

export const SOURCE_INDEX_PREFERENCES = 'koma_source_package_manager_v1'
export const SOURCE_INDEX_URL = 'source_index.url'
export const SOURCE_INDEX_REPOSITORIES = 'source_index.repositories.v1'
const DOMAIN = 'source-subscriptions'
const RELATIONAL_MIGRATION = 'source-subscriptions-columns-v1'
const SHARED_SUBSCRIPTIONS_MIGRATION = 'source-subscriptions-shared-addresses-v1'
const REPOSITORY_PREFIX = 'repo/'
const STORE_URL = 'active'
const STORE_LIST = 'list'
const SUBSCRIPTION_COLUMNS = ' (url TEXT PRIMARY KEY, endpoint_url TEXT, list_order INTEGER DEFAULT 0, ' +
  'last_used_at INTEGER DEFAULT 0, disabled INTEGER, custom_name TEXT, repository_name TEXT, website TEXT, local_name TEXT)'
const SUBSCRIPTION_TABLES: string[] = ['source_subscriptions', 'source_subscriptions_local']

interface SourceSubscriptionRow {
  order: number
  repository: SourceIndexRepository
}

export interface SourceSubscriptionPreferences {
  url?: string
  repositories?: SourceIndexRepository[]
}

function decodeLegacySubscriptions(values: UserRecordValues | undefined): SourceSubscriptionPreferences {
  const url = values?.get(STORE_URL)
  let repositories: SourceIndexRepository[] | undefined
  if (values?.has(STORE_LIST)) {
    const rows: SourceSubscriptionRow[] = []
    values.forEach((value: string, key: string): void => {
      if (key.startsWith(REPOSITORY_PREFIX)) rows.push(JSON.parse(value) as SourceSubscriptionRow)
    })
    repositories = rows.sort((left: SourceSubscriptionRow, right: SourceSubscriptionRow): number => left.order - right.order)
      .map((row: SourceSubscriptionRow): SourceIndexRepository => row.repository)
  }
  return { url: url === undefined ? undefined : JSON.parse(url) as string, repositories }
}

export function sourceSubscriptionBackupValues(url: Object | undefined, repositories: Object | undefined): SourceSubscriptionPreferences {
  if (url !== undefined && typeof url !== 'string') throw new Error('source_index_preferences_invalid')
  return { url: url as string | undefined,
    repositories: repositories === undefined ? undefined : parseSavedSourceIndexRepositories(repositories, '') }
}

class SourceSubscriptionRows {
  private readonly store: relationalStore.RdbStore

  constructor(store: relationalStore.RdbStore) {
    this.store = store
  }

  read(previousLayout: boolean = false): SourceSubscriptionPreferences {
    // One query keeps the active fallback address and explicit empty list in
    // the same read snapshot, including during backup or a concurrent write.
    const repositories = previousLayout ? 'source_subscriptions' :
      '(SELECT COALESCE(endpoint_url, url) AS url, list_order, last_used_at, disabled, ' +
      'COALESCE(local_name, custom_name) AS custom_name, repository_name, website FROM source_subscriptions ' +
      'UNION ALL SELECT url, list_order, last_used_at, disabled, custom_name, repository_name, website ' +
      'FROM source_subscriptions_local)'
    const includeRows = previousLayout ? 's.has_repository_list = 1' : '1=1'
    const rows = this.store.querySqlSync('SELECT s.active_url, s.has_repository_list, r.url, r.last_used_at, ' +
      'r.disabled, r.custom_name, r.repository_name, r.website FROM (SELECT 1 AS id) position ' +
      'LEFT JOIN source_subscription_selection s ON s.id = position.id LEFT JOIN ' + repositories +
      ' r ON ' + includeRows + ' ORDER BY r.list_order, r.url')
    try {
      if (!rows.goToNextRow()) return {}
      const url = rows.isColumnNull(0) ? undefined : rows.getString(0)
      if ((rows.isColumnNull(1) || rows.getLong(1) === 0) && rows.isColumnNull(2)) return { url }
      const repositories: SourceIndexRepository[] = []
      do {
        if (!rows.isColumnNull(2)) {
          repositories.push({
            url: rows.getString(2),
            lastUsedAt: rows.getLong(3),
            disabled: rows.isColumnNull(4) ? undefined : rows.getLong(4) !== 0,
            customName: rows.isColumnNull(5) ? undefined : rows.getString(5),
            name: rows.isColumnNull(6) ? undefined : rows.getString(6),
            website: rows.isColumnNull(7) ? undefined : rows.getString(7),
          })
        }
      } while (rows.goToNextRow())
      return { url, repositories }
    } finally {
      rows.close()
    }
  }

  migrateSharedInTransaction(): void {
    if (hasUserDataMigration(this.store, SHARED_SUBSCRIPTIONS_MIGRATION)) return
    const previous = this.read(true)
    this.store.executeSync('ALTER TABLE source_subscriptions RENAME TO source_subscriptions_pre_shared')
    for (const table of SUBSCRIPTION_TABLES) this.store.executeSync('CREATE TABLE ' + table + SUBSCRIPTION_COLUMNS)
    this.replaceInTransaction(previous)
    this.store.executeSync('DROP TABLE source_subscriptions_pre_shared')
    markUserDataMigration(this.store, SHARED_SUBSCRIPTIONS_MIGRATION)
  }

  replaceInTransaction(value: SourceSubscriptionPreferences): void {
    const repositories = value.repositories === undefined ? undefined :
      normalizeSourceIndexRepositories(value.repositories as Object[])
    this.store.executeSync('INSERT INTO source_subscription_selection (id, active_url, has_repository_list) VALUES (1, ?, ?) ' +
      'ON CONFLICT(id) DO UPDATE SET active_url=excluded.active_url, has_repository_list=excluded.has_repository_list',
      [value.url ?? null, repositories === undefined ? 0 : 1])
    const existing = new Map<string, string[]>()
    for (const table of SUBSCRIPTION_TABLES) {
      const rows = this.store.querySqlSync('SELECT url FROM ' + table)
      const urls: string[] = []
      try {
        while (rows.goToNextRow()) urls.push(rows.getString(0))
      } finally {
        rows.close()
      }
      existing.set(table, urls)
    }
    const shared = new Set<string>()
    const retained = new Set<string>()
    repositories?.forEach((repository: SourceIndexRepository, order: number): void => {
      const canonical = subscriptionIdentity(repository.url)
      const portable = syncCatalogAddress(repository.url) && syncCatalogAddress(canonical) && !shared.has(canonical)
      // Keep the working endpoint and device ordering even when the public
      // identity groups several mirrors. One endpoint owns the shared data.
      if (portable) shared.add(canonical)
      const table = portable ? 'source_subscriptions' : 'source_subscriptions_local'
      const url = portable ? canonical : repository.url
      const label = portable ? syncPublicLabel(repository.customName ?? '', 120) || undefined : repository.customName
      retained.add(table + ':' + url)
      this.store.executeSync('INSERT INTO ' + table +
        ' (url, endpoint_url, list_order, last_used_at, disabled, custom_name, repository_name, website, local_name) ' +
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ' +
        'ON CONFLICT(url) DO UPDATE SET endpoint_url=excluded.endpoint_url, list_order=excluded.list_order, last_used_at=excluded.last_used_at, ' +
        'disabled=excluded.disabled, custom_name=excluded.custom_name, repository_name=excluded.repository_name, ' +
        'website=excluded.website, local_name=excluded.local_name WHERE endpoint_url IS NOT excluded.endpoint_url OR ' +
        'list_order IS NOT excluded.list_order OR last_used_at IS NOT excluded.last_used_at ' +
        'OR disabled IS NOT excluded.disabled OR custom_name IS NOT excluded.custom_name ' +
        'OR repository_name IS NOT excluded.repository_name OR website IS NOT excluded.website OR local_name IS NOT excluded.local_name',
        [url, url === repository.url ? null : repository.url, order, repository.lastUsedAt,
          repository.disabled === undefined ? null : (repository.disabled ? 1 : 0),
          label ?? null, repository.name ?? null, repository.website ?? null,
          label === repository.customName ? null : repository.customName ?? null])
    })
    existing.forEach((urls: string[], table: string): void => {
      for (const url of urls) {
        if (!retained.has(table + ':' + url)) this.store.executeSync('DELETE FROM ' + table + ' WHERE url = ?', [url])
      }
    })
  }

  update(value: SourceSubscriptionPreferences, replaceUrl: boolean, replaceRepositories: boolean): void {
    writeUserRecords(this.store, (): void => {
      const current = this.read()
      if (replaceUrl) current.url = value.url
      if (replaceRepositories) current.repositories = value.repositories
      this.replaceInTransaction(current)
    })
  }

  removeCloudAliases(addresses: Set<string>): string[] {
    const removed = new Set<string>()
    writeUserRecords(this.store, (): void => {
      const current = this.read()
      const keep = new Set<string>()
      for (const address of addresses) {
        const rows = this.store.querySqlSync('SELECT 1 FROM source_subscriptions WHERE url = ?', [address])
        try { if (rows.goToNextRow()) keep.add(address) } finally { rows.close() }
      }
      const wasRemoved = (url: string): boolean => {
        const address = subscriptionIdentity(url)
        return addresses.has(address) && !keep.has(address)
      }
      const repositories = current.repositories ?? []
      for (const repository of repositories) {
        if (!wasRemoved(repository.url)) continue
        this.store.executeSync('DELETE FROM source_subscriptions_local WHERE url = ?', [repository.url])
        removed.add(repository.url)
      }
      // The shared row is already gone when the callback arrives. Check the
      // active pointer independently so the legacy fallback cannot revive it.
      const active = current.url
      if (active !== undefined && wasRemoved(active)) {
        const next = repositories.find((repo: SourceIndexRepository): boolean => !removed.has(repo.url))
        this.store.executeSync('UPDATE source_subscription_selection SET active_url = ? WHERE id = 1',
          [next?.url ?? null])
        removed.add(active)
      }
      for (const address of addresses) {
        if (!keep.has(address)) removed.add(address)
      }
    })
    return Array.from(removed)
  }
}

const openings = new Map<string, Promise<SourceSubscriptionRows>>()

async function migrateRecords(context: common.Context): Promise<SourceSubscriptionRows> {
  const store = await openUserDataDatabase(context)
  const records = new SourceSubscriptionRows(store)
  if (hasUserDataMigration(store, RELATIONAL_MIGRATION)) {
    if (!hasUserDataMigration(store, SHARED_SUBSCRIPTIONS_MIGRATION)) {
      writeUserRecords(store, (): void => records.migrateSharedInTransaction())
    }
    return records
  }
  let legacy: SourceSubscriptionPreferences = {}
  if (!hasUserDataMigration(store, DOMAIN)) {
    const prefs = await preferences.getPreferences(context, SOURCE_INDEX_PREFERENCES)
    const url = await prefs.has(SOURCE_INDEX_URL) ? await prefs.get(SOURCE_INDEX_URL, '') : undefined
    const repositories = await prefs.has(SOURCE_INDEX_REPOSITORIES) ? await prefs.get(SOURCE_INDEX_REPOSITORIES, '') : undefined
    legacy = sourceSubscriptionBackupValues(url, repositories)
  }
  writeUserRecords(store, (): void => {
    if (hasUserDataMigration(store, RELATIONAL_MIGRATION)) return
    records.migrateSharedInTransaction()
    records.replaceInTransaction(hasUserDataMigration(store, DOMAIN) ?
      decodeLegacySubscriptions(new UserKeyedRecords(store, DOMAIN).entries()) : legacy)
    markUserDataMigration(store, RELATIONAL_MIGRATION)
  })
  return records
}

async function subscriptionRecords(context: common.Context): Promise<SourceSubscriptionRows> {
  const directory = context.filesDir
  const existing = openings.get(directory)
  if (existing !== undefined) return existing
  const opening = migrateRecords(context).catch((error: Error): never => {
    openings.delete(directory)
    throw error
  })
  openings.set(directory, opening)
  return opening
}

export async function loadSourceSubscriptionPreferences(context: common.Context): Promise<SourceSubscriptionPreferences> {
  return (await subscriptionRecords(context)).read()
}

export async function applyCloudSubscriptionRemovals(context: common.Context, addresses: Set<string>): Promise<string[]> {
  if (addresses.size === 0) return []
  const records = await subscriptionRecords(context)
  return records.removeCloudAliases(addresses)
}

/** Keep the address pointer and ordered subscriptions in the same transaction. */
export async function saveSourceSubscriptionPreferences(context: common.Context, value: SourceSubscriptionPreferences,
  replaceUrl: boolean, replaceRepositories: boolean): Promise<void> {
  (await subscriptionRecords(context)).update(value, replaceUrl, replaceRepositories)
}

export async function recoverSourceSubscriptionPreferences(context: common.Context, url: Object | undefined,
  repositories: Object | undefined): Promise<boolean> {
  const store = await openUserDataDatabase(context)
  if (!hasUserDataMigration(store, RELATIONAL_MIGRATION) && !hasUserDataMigration(store, DOMAIN)) return false
  const records = new SourceSubscriptionRows(store)
  const picture = sourceSubscriptionBackupValues(url, repositories)
  writeUserRecords(store, (): void => {
    records.migrateSharedInTransaction()
    records.replaceInTransaction(picture)
    if (JSON.stringify(records.read()) !== JSON.stringify(picture)) {
      throw new Error('backup_checkpoint_preferences_readback_failed')
    }
    markUserDataMigration(store, RELATIONAL_MIGRATION)
  })
  return true
}

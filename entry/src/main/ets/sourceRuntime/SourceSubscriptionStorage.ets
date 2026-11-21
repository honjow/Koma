import { common } from '@kit.AbilityKit'
import { preferences, relationalStore } from '@kit.ArkData'
import { hasUserDataMigration, markUserDataMigration, openUserDataDatabase } from '../model/UserDataDatabase'
import { UserKeyedRecords, UserRecordValues, writeUserRecords } from '../model/UserKeyedRecords'
import { normalizeSourceIndexRepositories, parseSavedSourceIndexRepositories, SourceIndexRepository } from './SourceIndexMetadata'

export const SOURCE_INDEX_PREFERENCES = 'koma_source_package_manager_v1'
export const SOURCE_INDEX_URL = 'source_index.url'
export const SOURCE_INDEX_REPOSITORIES = 'source_index.repositories.v1'
const DOMAIN = 'source-subscriptions'
const RELATIONAL_MIGRATION = 'source-subscriptions-columns-v1'
const REPOSITORY_PREFIX = 'repo/'
const STORE_URL = 'active'
const STORE_LIST = 'list'

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

  read(): SourceSubscriptionPreferences {
    // One query keeps the active fallback address and explicit empty list in
    // the same read snapshot, including during backup or a concurrent write.
    const rows = this.store.querySqlSync('SELECT s.active_url, s.has_repository_list, r.url, r.last_used_at, ' +
      'r.disabled, r.custom_name, r.repository_name, r.website FROM source_subscription_selection s ' +
      'LEFT JOIN source_subscriptions r ON s.has_repository_list = 1 WHERE s.id = 1 ORDER BY r.list_order')
    try {
      if (!rows.goToNextRow()) return {}
      const url = rows.isColumnNull(0) ? undefined : rows.getString(0)
      if (rows.getLong(1) === 0) return { url }
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

  replaceInTransaction(value: SourceSubscriptionPreferences): void {
    const repositories = value.repositories === undefined ? undefined :
      normalizeSourceIndexRepositories(value.repositories as Object[])
    this.store.executeSync('INSERT INTO source_subscription_selection (id, active_url, has_repository_list) VALUES (1, ?, ?) ' +
      'ON CONFLICT(id) DO UPDATE SET active_url=excluded.active_url, has_repository_list=excluded.has_repository_list',
      [value.url ?? null, repositories === undefined ? 0 : 1])
    const existing = this.store.querySqlSync('SELECT url FROM source_subscriptions')
    const previousUrls: string[] = []
    try {
      while (existing.goToNextRow()) previousUrls.push(existing.getString(0))
    } finally {
      existing.close()
    }
    const retained = new Set<string>()
    repositories?.forEach((repository: SourceIndexRepository, order: number): void => {
      retained.add(repository.url)
      this.store.executeSync('INSERT INTO source_subscriptions ' +
        '(url, list_order, last_used_at, disabled, custom_name, repository_name, website) VALUES (?, ?, ?, ?, ?, ?, ?) ' +
        'ON CONFLICT(url) DO UPDATE SET list_order=excluded.list_order, last_used_at=excluded.last_used_at, ' +
        'disabled=excluded.disabled, custom_name=excluded.custom_name, repository_name=excluded.repository_name, ' +
        'website=excluded.website WHERE list_order IS NOT excluded.list_order OR last_used_at IS NOT excluded.last_used_at ' +
        'OR disabled IS NOT excluded.disabled OR custom_name IS NOT excluded.custom_name ' +
        'OR repository_name IS NOT excluded.repository_name OR website IS NOT excluded.website',
        [repository.url, order, repository.lastUsedAt,
          repository.disabled === undefined ? null : (repository.disabled ? 1 : 0),
          repository.customName ?? null, repository.name ?? null, repository.website ?? null])
    })
    for (const url of previousUrls) {
      if (!retained.has(url)) this.store.executeSync('DELETE FROM source_subscriptions WHERE url = ?', [url])
    }
  }

  update(value: SourceSubscriptionPreferences, replaceUrl: boolean, replaceRepositories: boolean): void {
    writeUserRecords(this.store, (): void => {
      const current = this.read()
      if (replaceUrl) current.url = value.url
      if (replaceRepositories) current.repositories = value.repositories
      this.replaceInTransaction(current)
    })
  }
}

const openings = new Map<string, Promise<SourceSubscriptionRows>>()

async function migrateRecords(context: common.Context): Promise<SourceSubscriptionRows> {
  const store = await openUserDataDatabase(context)
  const records = new SourceSubscriptionRows(store)
  if (hasUserDataMigration(store, RELATIONAL_MIGRATION)) return records
  let legacy: SourceSubscriptionPreferences = {}
  if (!hasUserDataMigration(store, DOMAIN)) {
    const prefs = await preferences.getPreferences(context, SOURCE_INDEX_PREFERENCES)
    const url = await prefs.has(SOURCE_INDEX_URL) ? await prefs.get(SOURCE_INDEX_URL, '') : undefined
    const repositories = await prefs.has(SOURCE_INDEX_REPOSITORIES) ? await prefs.get(SOURCE_INDEX_REPOSITORIES, '') : undefined
    legacy = sourceSubscriptionBackupValues(url, repositories)
  }
  writeUserRecords(store, (): void => {
    if (hasUserDataMigration(store, RELATIONAL_MIGRATION)) return
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
    records.replaceInTransaction(picture)
    if (JSON.stringify(records.read()) !== JSON.stringify(picture)) {
      throw new Error('backup_checkpoint_preferences_readback_failed')
    }
    markUserDataMigration(store, RELATIONAL_MIGRATION)
  })
  return true
}

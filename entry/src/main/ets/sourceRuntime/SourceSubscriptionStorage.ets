import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { openUserDataDatabase } from '../model/UserDataDatabase'
import { UserKeyedRecords, UserRecordValues } from '../model/UserKeyedRecords'
import { normalizeSourceIndexRepositories, parseSavedSourceIndexRepositories, SourceIndexRepository } from './SourceIndexMetadata'

export const SOURCE_INDEX_PREFERENCES = 'koma_source_package_manager_v1'
export const SOURCE_INDEX_URL = 'source_index.url'
export const SOURCE_INDEX_REPOSITORIES = 'source_index.repositories.v1'
const DOMAIN = 'source-subscriptions'
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

function addSubscriptions(values: UserRecordValues, repositories: SourceIndexRepository[] | undefined): void {
  if (repositories === undefined) return
  values.set(STORE_LIST, 'true')
  normalizeSourceIndexRepositories(repositories as Object[]).forEach((repository: SourceIndexRepository, order: number): void => {
    const row: SourceSubscriptionRow = { order, repository }
    values.set(REPOSITORY_PREFIX + repository.url, JSON.stringify(row))
  })
}

function encodeSubscriptions(value: SourceSubscriptionPreferences): UserRecordValues {
  const rows: UserRecordValues = new Map()
  if (value.url !== undefined) rows.set(STORE_URL, JSON.stringify(value.url))
  addSubscriptions(rows, value.repositories)
  return rows
}

function decodeSubscriptions(values: UserRecordValues | undefined): SourceSubscriptionPreferences {
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

const openings = new Map<string, Promise<UserKeyedRecords>>()

async function openRecords(context: common.Context): Promise<UserKeyedRecords> {
  return new UserKeyedRecords(await openUserDataDatabase(context), DOMAIN)
}

async function migrateRecords(context: common.Context): Promise<UserKeyedRecords> {
  const records = await openRecords(context)
  if (!records.isMigrated()) {
    const store = await preferences.getPreferences(context, SOURCE_INDEX_PREFERENCES)
    const url = await store.has(SOURCE_INDEX_URL) ? await store.get(SOURCE_INDEX_URL, '') : undefined
    const repositories = await store.has(SOURCE_INDEX_REPOSITORIES) ? await store.get(SOURCE_INDEX_REPOSITORIES, '') : undefined
    records.migrate(encodeSubscriptions(sourceSubscriptionBackupValues(url, repositories)))
  }
  return records
}

async function subscriptionRecords(context: common.Context): Promise<UserKeyedRecords> {
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
  return decodeSubscriptions((await subscriptionRecords(context)).entries())
}

/** Keep the address pointer and ordered subscriptions in the same transaction. */
export async function saveSourceSubscriptionPreferences(context: common.Context, value: SourceSubscriptionPreferences,
  replaceUrl: boolean, replaceRepositories: boolean): Promise<void> {
  const records = await subscriptionRecords(context)
  const current = decodeSubscriptions(records.entries())
  if (replaceUrl) current.url = value.url
  if (replaceRepositories) current.repositories = value.repositories
  records.replace(encodeSubscriptions(current))
}

export async function recoverSourceSubscriptionPreferences(context: common.Context, url: Object | undefined,
  repositories: Object | undefined): Promise<boolean> {
  const records = await openRecords(context)
  if (!records.isMigrated()) return false
  const picture = sourceSubscriptionBackupValues(url, repositories)
  records.replace(encodeSubscriptions(picture))
  const actual = decodeSubscriptions(records.entries())
  if (JSON.stringify(actual) !== JSON.stringify(picture)) throw new Error('backup_checkpoint_preferences_readback_failed')
  return true
}

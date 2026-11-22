import type { relationalStore } from '@kit.ArkData'
import { syncCoverAddress, syncReadingIdentity, syncReadingWorkAddress, syncShelfIdentity, syncShelfLabel } from '../deviceSync/DeviceSyncData'
import type { PersistedComic } from './LibraryPersistence'
import { LocalColumnValue, LocalDataRows, textColumn, integerColumn } from './LocalDataRows'

export interface ShelfSharedWork {
  comicId: string
  source: string
  workId: string
  title?: string
  sourceName?: string
  workUrl?: string
  coverUri?: string
  sourceCoverUri?: string
  catalogUpdatedAt?: number
  hasSharedChapters?: number
}

const MOVED_COLUMNS: string[] = ['source_runtime_id', 'remote_resource_id', 'title', 'source_name', 'source_path',
  'cover_uri', 'source_cover_uri', 'chapter_catalog_updated_at']

export function sharedShelfIdentity(comicId: string, source: string, workId: string): boolean {
  if (!syncShelfIdentity(source, workId)) return false
  const prefix = source + ':'
  return comicId === (workId.startsWith(prefix) ? workId : prefix + workId)
}

export function sharedShelfWork(comic: PersistedComic): ShelfSharedWork | undefined {
  const source = comic.sourceRuntimeId
  const work = comic.remoteResourceId
  if (comic.sourceKind !== 'private_library' || comic.remoteServerId !== undefined ||
    source === undefined || work === undefined || !sharedShelfIdentity(comic.id, source, work)) return undefined
  const sourceName = comic.sourceMetadata?.sourceName
  const label = syncShelfLabel(source, comic.title, sourceName ?? '', comic.sourcePath)
  const chapters = comic.sourceMetadata?.sharedChapterIds
  const shareCatalog = chapters !== undefined && new Set<string>(chapters).size === chapters.length &&
    chapters.every((chapter: string): boolean => syncReadingIdentity(source, work, chapter))
  return { comicId: comic.id, source, workId: work, title: label.title,
    sourceName: sourceName === undefined ? undefined : label.sourceName, workUrl: label.workUrl,
    coverUri: comic.customCoverUri === undefined ? syncCoverAddress(comic.coverUri) : undefined,
    sourceCoverUri: syncCoverAddress(comic.sourceCoverUri),
    catalogUpdatedAt: shareCatalog ? comic.sourceMetadata?.chapterCatalogUpdatedAt : undefined,
    hasSharedChapters: shareCatalog ? 1 : undefined }
}

function sharedWorkFromRow(row: relationalStore.ResultSet): ShelfSharedWork {
  return { comicId: row.getString(0), source: row.getString(1), workId: row.getString(2), title: textColumn(row, 3),
    sourceName: textColumn(row, 4), workUrl: textColumn(row, 5), coverUri: textColumn(row, 6),
    sourceCoverUri: textColumn(row, 7), catalogUpdatedAt: integerColumn(row, 8), hasSharedChapters: integerColumn(row, 9) }
}

export const shelfSharedWorks = new LocalDataRows<ShelfSharedWork>('shelf_works', ['comic_id'],
  ['source_runtime_id', 'remote_resource_id', 'title', 'source_name', 'source_path', 'cover_uri', 'source_cover_uri',
    'chapter_catalog_updated_at', 'has_shared_chapters'], 'comic_id',
  (row: ShelfSharedWork): LocalColumnValue[] => [row.comicId, row.source, row.workId, row.title ?? null,
    row.sourceName ?? null, row.workUrl ?? null, row.coverUri ?? null, row.sourceCoverUri ?? null, row.catalogUpdatedAt ?? null,
    row.hasSharedChapters ?? null], sharedWorkFromRow)

export async function splitShelfScope(transaction: relationalStore.Transaction): Promise<void> {
  const legacy = await transaction.querySql('PRAGMA table_info(shelf_works)')
  const workColumns: string[] = []
  try {
    while (legacy.goToNextRow()) workColumns.push(legacy.getString(1))
  } finally {
    legacy.close()
  }
  if (!workColumns.includes('list_order')) return
  await transaction.execute('ALTER TABLE shelf_works RENAME TO shelf_work_details')
  await transaction.execute('ALTER TABLE shelf_work_details ADD COLUMN shared_scope INTEGER NOT NULL DEFAULT 0')
  await transaction.execute('ALTER TABLE shelf_memberships RENAME TO shelf_memberships_local')
  await transaction.execute('ALTER TABLE shelf_shared_chapters RENAME TO shelf_shared_chapters_local')
  await transaction.execute('CREATE TABLE shelf_works (comic_id TEXT PRIMARY KEY, ' +
    'source_runtime_id TEXT, remote_resource_id TEXT, ' +
    'title TEXT, source_name TEXT, source_path TEXT, cover_uri TEXT, source_cover_uri TEXT, ' +
    'chapter_catalog_updated_at INTEGER, has_shared_chapters INTEGER)')
  await transaction.execute('CREATE TABLE shelf_memberships (' +
    'comic_id TEXT REFERENCES shelf_works (comic_id) ON DELETE CASCADE, ' +
    'category_id TEXT, category_occurrence INTEGER, list_order INTEGER, PRIMARY KEY (comic_id, category_id, category_occurrence))')
  await transaction.execute('CREATE INDEX shelf_memberships_shared_category ON shelf_memberships (category_id, comic_id)')
  await transaction.execute('CREATE TABLE shelf_shared_chapters (' +
    'comic_id TEXT REFERENCES shelf_works (comic_id) ON DELETE CASCADE, ' +
    'chapter_order INTEGER, chapter_id TEXT, ' +
    'PRIMARY KEY (comic_id, chapter_order))')
  const rows = await transaction.querySql('SELECT comic_id, source_runtime_id, remote_resource_id, title, source_name, source_path, ' +
    'cover_uri, source_cover_uri, custom_cover_uri, chapter_catalog_updated_at, has_shared_chapters ' +
    "FROM shelf_work_details WHERE source_kind = 'private_library' AND remote_server_id IS NULL AND source_runtime_id IS NOT NULL")
  const selected: ShelfSharedWork[] = []
  try {
    while (rows.goToNextRow()) {
      const comicId = rows.getString(0)
      const source = rows.getString(1)
      const work = textColumn(rows, 2)
      if (work === undefined || !sharedShelfIdentity(comicId, source, work)) continue
      const name = textColumn(rows, 4)
      const label = syncShelfLabel(source, textColumn(rows, 3) ?? '', name ?? '', textColumn(rows, 5) ?? '')
      selected.push({ comicId, source, workId: work, title: label.title,
        sourceName: name === undefined ? undefined : label.sourceName, workUrl: label.workUrl,
        coverUri: rows.isColumnNull(8) ? syncCoverAddress(textColumn(rows, 6)) : undefined,
        sourceCoverUri: syncCoverAddress(textColumn(rows, 7)), catalogUpdatedAt: integerColumn(rows, 9),
        hasSharedChapters: rows.getLong(10) === 0 ? undefined : 1 })
    }
  } finally {
    rows.close()
  }
  await shelfSharedWorks.importRows(transaction, selected)
  const catalogSafe = 'shelf_works.comic_id = chapters.comic_id AND shelf_works.has_shared_chapters = 1'
  await transaction.execute('UPDATE shelf_works SET has_shared_chapters = NULL, chapter_catalog_updated_at = NULL WHERE comic_id IN (' +
    'SELECT comic_id FROM shelf_shared_chapters_local WHERE length(chapter_id) NOT BETWEEN 1 AND 512 ' +
    "OR trim(chapter_id) = '' OR instr(chapter_id, char(0)) <> 0 OR chapter_id GLOB ('*[' || char(1) || '-' || char(31) || char(127) || ']*') " +
    'UNION SELECT comic_id FROM shelf_shared_chapters_local GROUP BY comic_id, chapter_id HAVING count(*) > 1)')
  await transaction.execute('INSERT INTO shelf_shared_chapters SELECT chapters.* FROM shelf_shared_chapters_local chapters ' +
    'WHERE EXISTS (SELECT 1 FROM shelf_works WHERE ' + catalogSafe + ')')
  await transaction.execute('DELETE FROM shelf_shared_chapters_local WHERE EXISTS (SELECT 1 FROM shelf_works WHERE ' +
    catalogSafe.replace('chapters.', 'shelf_shared_chapters_local.') + ')')
  const exists = 'EXISTS (SELECT 1 FROM shelf_works WHERE shelf_works.comic_id = '
  const clearShared = MOVED_COLUMNS.map((column: string): string => column + ' = CASE WHEN ' + column +
    ' IS (SELECT s.' + column + ' FROM shelf_works s WHERE s.comic_id = shelf_work_details.comic_id) THEN NULL ELSE ' + column + ' END')
  await transaction.execute('UPDATE shelf_work_details SET shared_scope = 1, ' + clearShared.join(', ') +
    ', has_shared_chapters = CASE WHEN (SELECT s.has_shared_chapters FROM shelf_works s ' +
    'WHERE s.comic_id = shelf_work_details.comic_id) = 1 THEN 0 ELSE has_shared_chapters END WHERE ' +
    exists + 'shelf_work_details.comic_id)')
  await transaction.execute('INSERT INTO shelf_memberships SELECT m.* FROM shelf_memberships_local m WHERE ' +
    exists + 'm.comic_id)')
  await transaction.execute('DELETE FROM shelf_memberships_local WHERE ' + exists + 'shelf_memberships_local.comic_id)')
  const projection = workColumns.map((column: string): string => {
    if (MOVED_COLUMNS.includes(column) || column === 'has_shared_chapters') {
      return 'COALESCE(d.' + column + ', s.' + column + ') AS ' + column
    }
    return 'd.' + column
  })
  const flag = workColumns.indexOf('has_shared_chapters')
  projection[flag] = 'COALESCE(s.has_shared_chapters, d.has_shared_chapters) AS has_shared_chapters'
  await transaction.execute('CREATE VIEW shelf_works_all AS SELECT ' + projection.join(', ') +
    ' FROM shelf_work_details d LEFT JOIN shelf_works s ON s.comic_id = d.comic_id ' +
    'WHERE d.shared_scope = 0 OR s.comic_id IS NOT NULL')
  await transaction.execute('CREATE VIEW shelf_memberships_all AS SELECT * FROM shelf_memberships ' +
    'UNION ALL SELECT * FROM shelf_memberships_local')
  await transaction.execute('CREATE VIEW shelf_shared_chapters_all AS SELECT * FROM shelf_shared_chapters ' +
    'UNION ALL SELECT * FROM shelf_shared_chapters_local')
}

export async function movePublicReadingAddresses(transaction: relationalStore.Transaction, table: string): Promise<void> {
  const columns = await transaction.querySql('PRAGMA table_info(' + table + ')')
  try {
    while (columns.goToNextRow()) {
      if (columns.getString(1) === 'shared_manga_url') return
    }
  } finally { columns.close() }
  await transaction.execute('ALTER TABLE ' + table + ' ADD COLUMN shared_manga_url TEXT')
  await transaction.execute('ALTER TABLE ' + table + ' ADD COLUMN shared_cover_uri TEXT')
  const rows = await transaction.querySql('SELECT comic_id, manga_url, cover_uri FROM ' + table +
    ' WHERE manga_url IS NOT NULL OR cover_uri IS NOT NULL')
  const addresses: LocalColumnValue[][] = []
  try {
    while (rows.goToNextRow()) {
      const originalUrl = textColumn(rows, 1)
      const originalCover = textColumn(rows, 2)
      const url = syncReadingWorkAddress(originalUrl)
      const cover = syncCoverAddress(originalCover)
      if (url !== undefined || cover !== undefined) {
        addresses.push([url === undefined ? originalUrl ?? null : null, cover === undefined ? originalCover ?? null : null,
          url ?? null, cover ?? null, rows.getString(0)])
      }
    }
  } finally { rows.close() }
  for (const values of addresses) await transaction.execute('UPDATE ' + table +
    ' SET manga_url = ?, cover_uri = ?, shared_manga_url = ?, shared_cover_uri = ? WHERE comic_id = ?', values)
}

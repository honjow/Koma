import type { relationalStore } from '@kit.ArkData'
import type { MihonBackupChapter, MihonBackupHistory, MihonBackupTracking, MihonBackupWork, MihonImportRecord } from './MihonBackupReader'
import type { SourceManga, SourceMangaStatus } from './SourceModels'
import { booleanColumn, booleanValue, integerColumn, LocalColumnValue, LocalDataRows, realColumn, textColumn } from './LocalDataRows'

interface MihonImportRow {
  order: number
  id: string
  sourceName: string
  matchedSourceId?: string
  targetComicId?: string
  work: MihonBackupWork
  linkedWork?: SourceManga
}

interface MihonDetail<T> {
  importId: string
  detail: T
}

interface MihonListRow<T> extends MihonDetail<T> {
  order: number
}

function originalWorkValues(work: MihonBackupWork): LocalColumnValue[] {
  return [
    work.sourceId ?? null, work.url ?? null,
    work.title ?? null, work.artist ?? null, work.author ?? null,
    work.description ?? null, work.status ?? null, work.coverUrl ?? null,
    work.addedAt ?? null, booleanValue(work.favorite), work.modifiedAt ?? null,
    work.favoriteModifiedAt ?? null, work.notes ?? null,
  ]
}

function linkedWorkValues(work?: SourceManga): LocalColumnValue[] {
  return [
    work?.id ?? null, work?.sourceId ?? null,
    work?.title ?? null, work?.author ?? null, work?.artist ?? null,
    work?.description ?? null, work?.coverUrl ?? null, work?.status ?? null,
    work?.contentRating ?? null, work?.url ?? null, work?.webUrl ?? null,
    booleanValue(work?.tags !== undefined), booleanValue(work?.coverHeaders !== undefined),
  ]
}

function readOriginalWork(row: relationalStore.ResultSet, offset: number): MihonBackupWork {
  return {
    sourceId: textColumn(row, 0 + offset) as string,
    url: textColumn(row, 1 + offset) as string,
    title: textColumn(row, 2 + offset) as string,
    artist: textColumn(row, 3 + offset) as string,
    author: textColumn(row, 4 + offset) as string,
    description: textColumn(row, 5 + offset) as string,
    status: integerColumn(row, 6 + offset) as number,
    coverUrl: textColumn(row, 7 + offset) as string,
    addedAt: integerColumn(row, 8 + offset) as number,
    favorite: booleanColumn(row, 9 + offset) as boolean,
    modifiedAt: integerColumn(row, 10 + offset) as number,
    favoriteModifiedAt: integerColumn(row, 11 + offset),
    notes: textColumn(row, 12 + offset) as string,
    chapters: [], history: [], tracking: [], genres: [], categoryIds: [],
  }
}

function readLinkedWork(row: relationalStore.ResultSet, offset: number): SourceManga {
  return {
    id: textColumn(row, 0 + offset) as string,
    sourceId: textColumn(row, 1 + offset) as string,
    title: textColumn(row, 2 + offset) as string,
    author: textColumn(row, 3 + offset),
    artist: textColumn(row, 4 + offset),
    description: textColumn(row, 5 + offset),
    coverUrl: textColumn(row, 6 + offset),
    status: textColumn(row, 7 + offset) as SourceMangaStatus | undefined,
    contentRating: textColumn(row, 8 + offset),
    url: textColumn(row, 9 + offset),
    webUrl: textColumn(row, 10 + offset),
    tags: row.getLong(11 + offset) === 0 ? undefined : [],
    coverHeaders: row.getLong(12 + offset) === 0 ? undefined : {},
  }
}

const importedWorks = new LocalDataRows<MihonImportRow>('shelf_mihon_imports', ['import_id'], [
    'list_order', 'source_name', 'matched_source_id', 'target_comic_id',
    'source_id', 'url', 'title', 'artist', 'author', 'description', 'status',
    'cover_url', 'added_at', 'favorite', 'modified_at', 'favorite_modified_at', 'notes',
    'has_linked_work',
    'linked_manga_id', 'linked_source_id', 'linked_title', 'linked_author', 'linked_artist', 'linked_description', 'linked_cover_url',
    'linked_status', 'linked_content_rating', 'linked_url', 'linked_web_url', 'linked_has_tags', 'linked_has_cover_headers',
  ], 'list_order',
  (row: MihonImportRow): LocalColumnValue[] => [
    row.id, row.order, row.sourceName ?? null, row.matchedSourceId ?? null, row.targetComicId ?? null,
    ...originalWorkValues(row.work), row.linkedWork === undefined ? 0 : 1, ...linkedWorkValues(row.linkedWork),
  ],
  (row: relationalStore.ResultSet): MihonImportRow => ({
    id: row.getString(0), order: row.getLong(1), sourceName: textColumn(row, 2) as string,
    matchedSourceId: textColumn(row, 3), targetComicId: textColumn(row, 4),
    work: readOriginalWork(row, 5), linkedWork: row.getLong(18) === 0 ? undefined : readLinkedWork(row, 19),
  }))

const importChapters = new LocalDataRows<MihonListRow<MihonBackupChapter>>('shelf_mihon_chapters', ['import_id', 'item_order'], [
    'url', 'title', 'scanlator', 'is_read', 'bookmarked', 'page_index', 'fetched_at',
    'uploaded_at', 'chapter_number', 'source_order', 'modified_at',
  ], 'import_id, item_order',
  (row: MihonListRow<MihonBackupChapter>): LocalColumnValue[] => [
    row.importId, row.order, row.detail.url ?? null,
    row.detail.title ?? null, row.detail.scanlator ?? null, booleanValue(row.detail.read),
    booleanValue(row.detail.bookmarked), row.detail.pageIndex ?? null, row.detail.fetchedAt ?? null,
    row.detail.uploadedAt ?? null, row.detail.number ?? null, row.detail.sourceOrder ?? null,
    row.detail.modifiedAt ?? null,
  ],
  (row: relationalStore.ResultSet): MihonListRow<MihonBackupChapter> => ({
    importId: row.getString(0), order: row.getLong(1),
    detail: {
      url: textColumn(row, 2) as string,
      title: textColumn(row, 3) as string,
      scanlator: textColumn(row, 4) as string,
      read: booleanColumn(row, 5) as boolean,
      bookmarked: booleanColumn(row, 6) as boolean,
      pageIndex: integerColumn(row, 7) as number,
      fetchedAt: integerColumn(row, 8) as number,
      uploadedAt: integerColumn(row, 9) as number,
      number: realColumn(row, 10) as number,
      sourceOrder: integerColumn(row, 11) as number,
      modifiedAt: integerColumn(row, 12) as number,
    },
  }))

const importHistory = new LocalDataRows<MihonListRow<MihonBackupHistory>>('shelf_mihon_history', ['import_id', 'item_order'], [
    'chapter_url', 'read_at', 'read_duration',
  ], 'import_id, item_order',
  (row: MihonListRow<MihonBackupHistory>): LocalColumnValue[] => [
    row.importId, row.order, row.detail.chapterUrl ?? null,
    row.detail.readAt ?? null, row.detail.readDuration ?? null,
  ],
  (row: relationalStore.ResultSet): MihonListRow<MihonBackupHistory> => ({
    importId: row.getString(0), order: row.getLong(1),
    detail: {
      chapterUrl: textColumn(row, 2) as string,
      readAt: integerColumn(row, 3) as number,
      readDuration: integerColumn(row, 4) as number,
    },
  }))

const importTracking = new LocalDataRows<MihonListRow<MihonBackupTracking>>('shelf_mihon_tracking', ['import_id', 'item_order'], [
    'service_id', 'library_id', 'media_id', 'url', 'title', 'last_chapter_read', 'total_chapters',
    'score', 'status', 'started_at', 'finished_at', 'is_private',
  ], 'import_id, item_order',
  (row: MihonListRow<MihonBackupTracking>): LocalColumnValue[] => [
    row.importId, row.order, row.detail.serviceId ?? null,
    row.detail.libraryId ?? null, row.detail.mediaId ?? null, row.detail.url ?? null,
    row.detail.title ?? null, row.detail.lastChapterRead ?? null, row.detail.totalChapters ?? null,
    row.detail.score ?? null, row.detail.status ?? null, row.detail.startedAt ?? null,
    row.detail.finishedAt ?? null, booleanValue(row.detail.private),
  ],
  (row: relationalStore.ResultSet): MihonListRow<MihonBackupTracking> => ({
    importId: row.getString(0), order: row.getLong(1),
    detail: {
      serviceId: integerColumn(row, 2) as number,
      libraryId: textColumn(row, 3) as string,
      mediaId: textColumn(row, 4) as string,
      url: textColumn(row, 5) as string,
      title: textColumn(row, 6) as string,
      lastChapterRead: realColumn(row, 7) as number,
      totalChapters: integerColumn(row, 8) as number,
      score: realColumn(row, 9) as number,
      status: integerColumn(row, 10) as number,
      startedAt: integerColumn(row, 11) as number,
      finishedAt: integerColumn(row, 12) as number,
      private: booleanColumn(row, 13) as boolean,
    },
  }))

interface MihonTextItem {
  importId: string
  kind: string
  order: number
  text: string
}

const importText = new LocalDataRows<MihonTextItem>('shelf_mihon_text_items', ['import_id', 'item_kind', 'item_order'],
  ['item_text'], 'import_id, item_kind, item_order',
  (record: MihonTextItem): LocalColumnValue[] => [record.importId, record.kind, record.order, record.text],
  (row: relationalStore.ResultSet): MihonTextItem =>
    ({ importId: row.getString(0), kind: row.getString(1), order: row.getLong(2), text: row.getString(3) }))

interface MihonLinkedHeader {
  importId: string
  name: string
  order: number
  value: string
}

const importHeaders = new LocalDataRows<MihonLinkedHeader>('shelf_mihon_cover_headers', ['import_id', 'header_name'],
  ['header_order', 'header_value'], 'import_id, header_order',
  (record: MihonLinkedHeader): LocalColumnValue[] => [record.importId, record.name, record.order, record.value],
  (row: relationalStore.ResultSet): MihonLinkedHeader =>
    ({ importId: row.getString(0), name: row.getString(1), order: row.getLong(2), value: row.getString(3) }))

function appendRows<T>(importId: string, source: T[], target: MihonListRow<T>[]): void {
  source.forEach((detail: T, order: number): void => { target.push({ importId, order, detail }) })
}

export class ShelfMihonImports {
  private readonly roots: MihonImportRow[] = []
  private readonly chapters: MihonListRow<MihonBackupChapter>[] = []
  private readonly history: MihonListRow<MihonBackupHistory>[] = []
  private readonly tracking: MihonListRow<MihonBackupTracking>[] = []
  private readonly text: MihonTextItem[] = []
  private readonly headers: MihonLinkedHeader[] = []

  constructor(records: MihonImportRecord[]) {
    records.forEach((record: MihonImportRecord, order: number): void => {
      this.roots.push({ id: record.id, order, sourceName: record.sourceName,
        matchedSourceId: record.matchedSourceId, targetComicId: record.targetComicId,
        work: record.work, linkedWork: record.linkedWork })
      appendRows(record.id, record.work.chapters, this.chapters)
      appendRows(record.id, record.work.history, this.history)
      appendRows(record.id, record.work.tracking, this.tracking)
      this.pushText(record.id, 'genre', record.work.genres)
      this.pushText(record.id, 'original_category', record.work.categoryIds)
      this.pushText(record.id, 'local_category', record.categoryIds)
      if (record.linkedWork !== undefined) {
        this.pushText(record.id, 'linked_tag', record.linkedWork.tags ?? [])
        const headers = record.linkedWork.coverHeaders ?? {}
        Object.keys(headers).forEach((name: string, index: number): void => {
          this.headers.push({ importId: record.id, name, order: index, value: headers[name] })
        })
      }
    })
  }

  private pushText(importId: string, kind: string, values: string[]): void {
    values.forEach((text: string, order: number): void => { this.text.push({ importId, kind, order, text }) })
  }

  async importRows(transaction: relationalStore.Transaction): Promise<void> {
    await importedWorks.importRows(transaction, this.roots)
    await importChapters.importRows(transaction, this.chapters)
    await importHistory.importRows(transaction, this.history)
    await importTracking.importRows(transaction, this.tracking)
    await importText.importRows(transaction, this.text)
    await importHeaders.importRows(transaction, this.headers)
  }

  async stageCatalogLink(transaction: relationalStore.Transaction): Promise<void> {
    const root = this.roots[0]
    const rows = await transaction.querySql('SELECT list_order FROM shelf_mihon_imports WHERE import_id = ?', [root.id])
    try {
      if (!rows.goToNextRow()) throw new Error('mihon_import_missing_work')
      root.order = rows.getLong(0)
    } finally {
      rows.close()
    }
    await importedWorks.importRows(transaction, this.roots)
    await importText.replaceWorkRows(transaction, this.text.filter((row: MihonTextItem): boolean => row.kind === 'linked_tag'),
      root.id, 'import_id', "item_kind = 'linked_tag'")
    await importHeaders.replaceWorkRows(transaction, this.headers, root.id, 'import_id')
  }

  replace(store: relationalStore.RdbStore): void {
    importedWorks.replace(store, this.roots)
    importChapters.replace(store, this.chapters)
    importHistory.replace(store, this.history)
    importTracking.replace(store, this.tracking)
    importText.replace(store, this.text)
    importHeaders.replace(store, this.headers)
  }
}

export function readMihonImports(store: relationalStore.RdbStore): MihonImportRecord[] {
  const records: MihonImportRecord[] = []
  const byId = new Map<string, MihonImportRecord>()
  for (const row of importedWorks.read(store)) {
    const record: MihonImportRecord = { id: row.id, sourceName: row.sourceName, work: row.work, categoryIds: [],
      matchedSourceId: row.matchedSourceId, targetComicId: row.targetComicId, linkedWork: row.linkedWork }
    records.push(record)
    byId.set(row.id, record)
  }
  for (const row of importChapters.read(store)) byId.get(row.importId)?.work.chapters.push(row.detail)
  for (const row of importHistory.read(store)) byId.get(row.importId)?.work.history.push(row.detail)
  for (const row of importTracking.read(store)) byId.get(row.importId)?.work.tracking.push(row.detail)
  for (const row of importHeaders.read(store)) {
    const headers = byId.get(row.importId)?.linkedWork?.coverHeaders
    if (headers !== undefined) headers[row.name] = row.value
  }
  for (const row of importText.read(store)) {
    const entry = byId.get(row.importId)
    if (row.kind === 'genre') entry?.work.genres.push(row.text)
    if (row.kind === 'original_category') entry?.work.categoryIds.push(row.text)
    if (row.kind === 'local_category') entry?.categoryIds.push(row.text)
    if (row.kind === 'linked_tag') entry?.linkedWork?.tags?.push(row.text)
  }
  return records
}

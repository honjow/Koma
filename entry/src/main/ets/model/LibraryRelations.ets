import type { relationalStore } from '@kit.ArkData'
import type { LocalImportOrigin, SourceMangaMetadata } from './ComicModels'
import type { ComicUpdateSchedule } from './ComicReleaseSchedule'
import type { PersistedComic } from './LibraryPersistence'
import type { ShelfPageRow } from './LibraryCoreRows'
import type { LocalLibraryMetadataStatus, LocalLibraryStoredMetadata } from './LocalLibraryMetadataService'
import type { SourceTextOverlayBalloon } from './SourceTextOverlay'
import { booleanValue, integerColumn, LocalColumnValue, LocalDataRows, realColumn, textColumn } from './LocalDataRows'

export interface ShelfWorkMetadata {
  comicId: string
  updateSchedule?: ComicUpdateSchedule
  localMetadata?: LocalLibraryStoredMetadata
  localImportOrigin?: LocalImportOrigin
  sourceMetadata?: SourceMangaMetadata
}

export const SHELF_METADATA_FIELDS: string[] = [
  'update_interval_days', 'next_check_at', 'has_local_metadata', 'override_title', 'local_status', 'override_cover_path',
  'has_local_authors', 'import_kind', 'epub_order_revision', 'has_source_metadata', 'source_name', 'content_rating',
  'artist', 'source_status', 'web_url', 'settings_fingerprint', 'chapter_catalog_updated_at',
  'has_source_tags', 'has_excluded_chapters', 'has_shared_chapters',
]

export function shelfMetadataValues(entry: ShelfWorkMetadata): LocalColumnValue[] {
  return [
    entry.updateSchedule?.intervalDays ?? null, entry.updateSchedule?.nextCheckAt ?? null,
    booleanValue(entry.localMetadata !== undefined), entry.localMetadata?.titleOverride ?? null,
    entry.localMetadata?.status ?? null, entry.localMetadata?.coverOverridePath ?? null,
    booleanValue(entry.localMetadata?.authors !== undefined),
    entry.localImportOrigin?.kind ?? null, entry.localImportOrigin?.epubOrderRevision ?? null,
    booleanValue(entry.sourceMetadata !== undefined), entry.sourceMetadata?.sourceName ?? null,
    entry.sourceMetadata?.contentRating ?? null, entry.sourceMetadata?.artist ?? null,
    entry.sourceMetadata?.status ?? null, entry.sourceMetadata?.webUrl ?? null,
    entry.sourceMetadata?.settingsFingerprint ?? null, entry.sourceMetadata?.chapterCatalogUpdatedAt ?? null,
    booleanValue(entry.sourceMetadata?.tags !== undefined), booleanValue(entry.sourceMetadata?.excludedChapterIds !== undefined),
    booleanValue(entry.sourceMetadata?.sharedChapterIds !== undefined),
  ]
}

export function readShelfMetadata(row: relationalStore.ResultSet, offset: number, comicId: string): ShelfWorkMetadata {
  return {
    comicId,
    updateSchedule: row.isColumnNull(0 + offset) ? undefined : { intervalDays: row.getLong(0 + offset), nextCheckAt: row.getLong(1 + offset) },
    localMetadata: row.getLong(2 + offset) === 0 ? undefined : {
      titleOverride: textColumn(row, 3 + offset), status: textColumn(row, 4 + offset) as LocalLibraryMetadataStatus | undefined,
      coverOverridePath: textColumn(row, 5 + offset), authors: row.getLong(6 + offset) === 0 ? undefined : [],
    },
    localImportOrigin: row.isColumnNull(7 + offset) ? undefined : {
      kind: row.getString(7 + offset) as 'archive' | 'images', sourceUris: [], epubOrderRevision: integerColumn(row, 8 + offset),
    },
    sourceMetadata: row.getLong(9 + offset) === 0 ? undefined : {
      sourceName: textColumn(row, 10 + offset), contentRating: textColumn(row, 11 + offset), artist: textColumn(row, 12 + offset),
      status: textColumn(row, 13 + offset), webUrl: textColumn(row, 14 + offset), settingsFingerprint: textColumn(row, 15 + offset),
      chapterCatalogUpdatedAt: integerColumn(row, 16 + offset), tags: row.getLong(17 + offset) === 0 ? undefined : [],
      excludedChapterIds: row.getLong(18 + offset) === 0 ? undefined : [], sharedChapterIds: row.getLong(19 + offset) === 0 ? undefined : [],
    },
  }
}

export interface ShelfWorkListValue {
  comicId: string
  kind: string
  order: number
  value: string
}

export const shelfMetadataLists = new LocalDataRows<ShelfWorkListValue>('shelf_work_metadata_items',
  ['comic_id', 'list_kind', 'item_order'], ['item_value'], 'comic_id, list_kind, item_order',
  (entry: ShelfWorkListValue): LocalColumnValue[] => [entry.comicId, entry.kind, entry.order, entry.value],
  (row: relationalStore.ResultSet): ShelfWorkListValue =>
    ({ comicId: row.getString(0), kind: row.getString(1), order: row.getLong(2), value: row.getString(3) }))

export function metadataRow(work: PersistedComic): ShelfWorkMetadata {
  return { comicId: work.id, localMetadata: work.localMetadata, localImportOrigin: work.localImportOrigin,
    sourceMetadata: work.sourceMetadata, updateSchedule: work.updateSchedule }
}

export function metadataItems(row: ShelfWorkMetadata, items: ShelfWorkListValue[]): void {
  collectMetadataList(items, row.comicId, 'local_author', row.localMetadata?.authors)
  collectMetadataList(items, row.comicId, 'import_uri', row.localImportOrigin?.sourceUris)
  collectMetadataList(items, row.comicId, 'source_tag', row.sourceMetadata?.tags)
  collectMetadataList(items, row.comicId, 'excluded_chapter', row.sourceMetadata?.excludedChapterIds)
  collectMetadataList(items, row.comicId, 'shared_chapter', row.sourceMetadata?.sharedChapterIds)
}

function collectMetadataList(items: ShelfWorkListValue[], comicId: string, kind: string, values: string[] | undefined): void {
  values?.forEach((value: string, order: number): void => { items.push({ comicId, kind, order, value }) })
}

export function appendMetadataItem(row: ShelfWorkMetadata, item: ShelfWorkListValue): void {
  if (item.kind === 'local_author') row.localMetadata?.authors?.push(item.value)
  if (item.kind === 'import_uri') row.localImportOrigin?.sourceUris.push(item.value)
  if (item.kind === 'source_tag') row.sourceMetadata?.tags?.push(item.value)
  if (item.kind === 'excluded_chapter') row.sourceMetadata?.excludedChapterIds?.push(item.value)
  if (item.kind === 'shared_chapter') row.sourceMetadata?.sharedChapterIds?.push(item.value)
}

export interface ShelfMembershipRow {
  comicId: string
  categoryId: string
  occurrence: number
  order: number
}

export const shelfMemberships = new LocalDataRows<ShelfMembershipRow>('shelf_memberships',
  ['comic_id', 'category_id', 'category_occurrence'], ['list_order'], 'comic_id, list_order',
  (row: ShelfMembershipRow): LocalColumnValue[] => [row.comicId, row.categoryId, row.occurrence, row.order],
  (row: relationalStore.ResultSet): ShelfMembershipRow => ({
    comicId: row.getString(0), categoryId: row.getString(1), occurrence: row.getLong(2), order: row.getLong(3),
  }))

interface ShelfPageKey {
  comicId: string
  chapterId: string
  chapterOccurrence: number
  pageId: string
  pageOccurrence: number
}

export interface ShelfPageLine extends ShelfPageKey {
  order: number
  text: string
}

export interface ShelfPageBalloon extends ShelfPageKey {
  order: number
  balloon: SourceTextOverlayBalloon
}

const PAGE_KEYS: string[] = ['comic_id', 'chapter_id', 'chapter_occurrence', 'page_id', 'page_occurrence', 'item_order']

export const shelfPageLines = new LocalDataRows<ShelfPageLine>('shelf_page_text_lines', PAGE_KEYS, ['body_text'],
  PAGE_KEYS.join(', '),
  (row: ShelfPageLine): LocalColumnValue[] => [
    row.comicId, row.chapterId, row.chapterOccurrence, row.pageId, row.pageOccurrence, row.order, row.text,
  ],
  (row: relationalStore.ResultSet): ShelfPageLine => ({
    comicId: row.getString(0), chapterId: row.getString(1), chapterOccurrence: row.getLong(2),
    pageId: row.getString(3), pageOccurrence: row.getLong(4), order: row.getLong(5), text: row.getString(6),
  }))

export const shelfPageBalloons = new LocalDataRows<ShelfPageBalloon>('shelf_page_text_balloons', PAGE_KEYS,
  ['body_text', 'x', 'y', 'width'], PAGE_KEYS.join(', '),
  (row: ShelfPageBalloon): LocalColumnValue[] => [
    row.comicId, row.chapterId, row.chapterOccurrence, row.pageId, row.pageOccurrence, row.order,
    row.balloon.text, row.balloon.x, row.balloon.y, row.balloon.width,
  ],
  (row: relationalStore.ResultSet): ShelfPageBalloon => ({
    comicId: row.getString(0), chapterId: row.getString(1), chapterOccurrence: row.getLong(2),
    pageId: row.getString(3), pageOccurrence: row.getLong(4), order: row.getLong(5),
    balloon: { text: row.getString(6), x: realColumn(row, 7) as number, y: realColumn(row, 8) as number, width: row.getLong(9) },
  }))

export function shelfPageKey(comicId: string, chapterId: string, chapterOccurrence: number, pageId: string,
  pageOccurrence: number): string {
  return JSON.stringify([comicId, chapterId, chapterOccurrence, pageId, pageOccurrence])
}

export function appendPageContent(row: ShelfPageRow, lines: ShelfPageLine[], balloons: ShelfPageBalloon[]): void {
  const page = row.page
  page.sourceText?.paragraphs.forEach((text: string, order: number): void => {
    lines.push({ comicId: row.ownerId, chapterId: row.ownerChapterId, chapterOccurrence: row.chapterOccurrence,
      pageId: page.id, pageOccurrence: row.occurrence, order, text })
  })
  page.sourceTextOverlay?.balloons.forEach((balloon: SourceTextOverlayBalloon, order: number): void => {
    balloons.push({ comicId: row.ownerId, chapterId: row.ownerChapterId, chapterOccurrence: row.chapterOccurrence,
      pageId: page.id, pageOccurrence: row.occurrence, order, balloon })
  })
}

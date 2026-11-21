import type { relationalStore } from '@kit.ArkData'
import type { ComicSourceKind, ReadingDirection } from './ComicModels'
import type { PersistedChapter, PersistedComic, PersistedPage } from './LibraryPersistence'
import type { SourceRequiredImageDecode } from './SourceRequiredImageDecode'
import { metadataRow, readShelfMetadata, SHELF_METADATA_FIELDS, shelfMetadataValues } from './LibraryRelations'
import { booleanColumn, booleanValue, integerColumn, LocalColumnValue, LocalDataRows, realColumn, textColumn } from './LocalDataRows'

export interface ShelfWorkRow {
  order: number
  hasCategories: boolean
  work: PersistedComic
}

export interface ShelfChapterRow {
  ownerId: string
  order: number
  occurrence: number
  chapter: PersistedChapter
}

export interface ShelfPageRow {
  ownerId: string
  ownerChapterId: string
  chapterOccurrence: number
  order: number
  occurrence: number
  page: PersistedPage
}

function requiredDecodeValues(value: SourceRequiredImageDecode | undefined): LocalColumnValue[] {
  if (value?.kind === 'jm_stripes_v1') return [value.kind, value.rows, null, null]
  return [value?.kind ?? null, null, value?.bytes ?? null, value?.pixels ?? null]
}

function requiredDecode(row: relationalStore.ResultSet, offset: number): SourceRequiredImageDecode | undefined {
  const kind = textColumn(row, offset)
  if (kind === 'jm_stripes_v1') return { kind, rows: row.getLong(offset + 1) }
  if (kind === 'wasm_image_v1') return { kind, bytes: textColumn(row, offset + 2), pixels: textColumn(row, offset + 3) }
  return undefined
}

export const shelfWorks = new LocalDataRows<ShelfWorkRow>('shelf_works', ['comic_id'], [
    'list_order', 'has_categories', 'title', 'subtitle', 'author',
    'source_kind', 'source_path', 'source_runtime_id', 'remote_server_id', 'remote_resource_id',
    'cover_uri', 'personal_notes', 'custom_cover_uri', 'source_cover_uri', 'sort_title',
    'preferred_direction', 'chapter_count', 'page_count', 'created_at', 'updated_at',
    'last_imported_at',
  ].concat(SHELF_METADATA_FIELDS), 'list_order',
  (entry: ShelfWorkRow): LocalColumnValue[] => [
    entry.work.id, entry.order, booleanValue(entry.hasCategories),
    entry.work.title ?? null, entry.work.subtitle ?? null, entry.work.author ?? null,
    entry.work.sourceKind ?? null, entry.work.sourcePath ?? null, entry.work.sourceRuntimeId ?? null,
    entry.work.remoteServerId ?? null, entry.work.remoteResourceId ?? null, entry.work.coverUri ?? null,
    entry.work.personalNotes ?? null, entry.work.customCoverUri ?? null, entry.work.sourceCoverUri ?? null,
    entry.work.sortTitle ?? null, entry.work.preferredDirection ?? null, entry.work.chapterCount ?? null,
    entry.work.pageCount ?? null, entry.work.createdAt ?? null, entry.work.updatedAt ?? null,
    entry.work.lastImportedAt ?? null, ...shelfMetadataValues(metadataRow(entry.work)),
  ],
  (row: relationalStore.ResultSet): ShelfWorkRow => {
    const details = readShelfMetadata(row, 22, row.getString(0))
    return {
      order: row.getLong(1),
      hasCategories: row.getLong(2) !== 0,
      work: {
        id: row.getString(0),
        title: textColumn(row, 3) as string,
        subtitle: textColumn(row, 4),
        author: textColumn(row, 5),
        sourceKind: textColumn(row, 6) as ComicSourceKind,
        sourcePath: textColumn(row, 7) as string,
        sourceRuntimeId: textColumn(row, 8),
        remoteServerId: textColumn(row, 9),
        remoteResourceId: textColumn(row, 10),
        coverUri: textColumn(row, 11),
        personalNotes: textColumn(row, 12),
        customCoverUri: textColumn(row, 13),
        sourceCoverUri: textColumn(row, 14),
        sortTitle: textColumn(row, 15) as string,
        preferredDirection: textColumn(row, 16) as ReadingDirection,
        chapterCount: integerColumn(row, 17) as number,
        pageCount: integerColumn(row, 18) as number,
        createdAt: integerColumn(row, 19) as number,
        updatedAt: integerColumn(row, 20) as number,
        lastImportedAt: integerColumn(row, 21) as number,
        updateSchedule: details.updateSchedule,
        localMetadata: details.localMetadata,
        localImportOrigin: details.localImportOrigin,
        sourceMetadata: details.sourceMetadata,
        chapters: [],
      },
    }
})

export const shelfChapters = new LocalDataRows<ShelfChapterRow>('shelf_chapters', ['comic_id', 'chapter_id', 'chapter_occurrence'], [
    'list_order', 'title', 'chapter_index', 'chapter_number', 'volume_number',
    'reading_order', 'reading_group', 'reading_variant_group', 'reading_variant_sequence', 'continuation_eligible',
    'scanlator', 'language', 'date_upload', 'source_path', 'sort_key',
    'settings_fingerprint', 'page_count', 'created_at', 'updated_at', 'comic_id_override',
  ], 'comic_id, list_order',
  (entry: ShelfChapterRow): LocalColumnValue[] => [
    entry.ownerId, entry.chapter.id, entry.occurrence,
    entry.order, entry.chapter.title ?? null, entry.chapter.index ?? null,
    entry.chapter.chapterNumber ?? null, entry.chapter.volumeNumber ?? null, entry.chapter.readingOrder ?? null,
    entry.chapter.readingGroup ?? null, entry.chapter.readingVariantGroup ?? null, entry.chapter.readingVariantSequence ?? null,
    booleanValue(entry.chapter.continuationEligible), entry.chapter.scanlator ?? null, entry.chapter.language ?? null,
    entry.chapter.dateUpload ?? null, entry.chapter.sourcePath ?? null, entry.chapter.sortKey ?? null,
    entry.chapter.sourceSettingsFingerprint ?? null, entry.chapter.pageCount ?? null, entry.chapter.createdAt ?? null,
    entry.chapter.updatedAt ?? null, entry.chapter.comicId === entry.ownerId ? null : entry.chapter.comicId,
  ],
  (row: relationalStore.ResultSet): ShelfChapterRow => ({
    ownerId: row.getString(0),
    occurrence: row.getLong(2),
    order: row.getLong(3),
    chapter: {
      comicId: textColumn(row, 22) ?? row.getString(0),
      id: row.getString(1),
      title: textColumn(row, 4) as string,
      index: integerColumn(row, 5) as number,
      chapterNumber: realColumn(row, 6),
      volumeNumber: textColumn(row, 7),
      readingOrder: realColumn(row, 8),
      readingGroup: textColumn(row, 9),
      readingVariantGroup: textColumn(row, 10),
      readingVariantSequence: textColumn(row, 11),
      continuationEligible: booleanColumn(row, 12),
      scanlator: textColumn(row, 13),
      language: textColumn(row, 14),
      dateUpload: integerColumn(row, 15),
      sourcePath: textColumn(row, 16) as string,
      sortKey: textColumn(row, 17) as string,
      sourceSettingsFingerprint: textColumn(row, 18),
      pageCount: integerColumn(row, 19) as number,
      createdAt: integerColumn(row, 20) as number,
      updatedAt: integerColumn(row, 21) as number,
      pages: [],
    },
  }))

export const shelfPages = new LocalDataRows<ShelfPageRow>('shelf_pages', ['comic_id', 'chapter_id', 'chapter_occurrence', 'page_id', 'page_occurrence'], [
    'list_order', 'page_index', 'file_name', 'uri', 'sort_key',
    'width', 'height', 'byte_size', 'text_template', 'text_heading',
    'text_request_template', 'overlay_version', 'required_decode_kind', 'required_decode_rows', 'required_decode_bytes',
    'required_decode_pixels', 'comic_id_override', 'chapter_id_override',
  ], 'comic_id, chapter_id, chapter_occurrence, list_order',
  (entry: ShelfPageRow): LocalColumnValue[] => [
    entry.ownerId, entry.ownerChapterId, entry.chapterOccurrence,
    entry.page.id, entry.occurrence, entry.order,
    entry.page.index ?? null, entry.page.fileName ?? null, entry.page.uri ?? null,
    entry.page.sortKey ?? null, entry.page.width ?? null, entry.page.height ?? null,
    entry.page.byteSize ?? null, entry.page.sourceText?.template ?? null, entry.page.sourceText?.heading ?? null,
    entry.page.sourceTextRequest?.template ?? null, entry.page.sourceTextOverlay?.version ?? null,
    ...requiredDecodeValues(entry.page.requiredImageDecode),
    entry.page.comicId === entry.ownerId ? null : entry.page.comicId,
    entry.page.chapterId === entry.ownerChapterId ? null : entry.page.chapterId,
  ],
  (row: relationalStore.ResultSet): ShelfPageRow => ({
    ownerId: row.getString(0),
    ownerChapterId: row.getString(1),
    chapterOccurrence: row.getLong(2),
    occurrence: row.getLong(4),
    order: row.getLong(5),
    page: {
      comicId: textColumn(row, 21) ?? row.getString(0),
      chapterId: textColumn(row, 22) ?? row.getString(1),
      id: row.getString(3),
      index: integerColumn(row, 6) as number,
      fileName: textColumn(row, 7) as string,
      uri: textColumn(row, 8) as string,
      sortKey: textColumn(row, 9) as string,
      width: integerColumn(row, 10),
      height: integerColumn(row, 11),
      byteSize: integerColumn(row, 12),
      sourceText: row.isColumnNull(13) ? undefined : { template: row.getString(13), heading: row.getString(14), paragraphs: [] },
      sourceTextRequest: row.isColumnNull(15) ? undefined : { template: row.getString(15) },
      sourceTextOverlay: row.isColumnNull(16) ? undefined : { version: row.getLong(16), balloons: [] },
      requiredImageDecode: requiredDecode(row, 17),
    },
  }))

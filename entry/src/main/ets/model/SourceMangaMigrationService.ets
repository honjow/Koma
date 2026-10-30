import { common } from '@kit.AbilityKit'
import { Comic, Chapter, sameComicIdentity } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import { LibraryStorePersistenceService, upsertComicAndPersistLibraryStore,
  removeComicRecordAndPersistLibraryStore } from './LibraryPersistence'
import { ReaderSessionStore } from './ReaderSessionStore'
import { TrackerPreferencesStore } from './TrackerModels'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { MangaDetail, MangaChapterItem, parseMangaDetailFromSourceItem } from './MangaDetailModels'
import { SourceManga } from './SourceModels'
import { SourceRuntimeError } from './SourceRuntimeError'
import { comicFromSourceManga, sourceLibraryComicId } from './SourceLibraryComic'
import { resolveSourceChapterList } from './SourceChapterListResolver'
import { reconcileSourceChapterIdentity } from './SourceChapterIdentity'
import { protectedSourceChapterIds } from './SourceChapterIdentityGuard'
import { mergeSourceChapters } from './LibraryUpdateService'
import { canMigrateLibraryComic, MangaMigrationOptions, migrationCategoryIds,
  planMangaMigrationReadState } from './SourceMangaMigration'
import { SourceRuntimeRegistry, SourceRuntimeRegistryEntry, sourceRuntimeEntryEnabled } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { executeSourceRequestInWorker } from '../sourceRuntime/SourceRuntimeWorkerClient'
import { sourceHttpIdentityJson } from '../sourceRuntime/SourceWebSessionStore'
import { sourceRequestWithHostFeatures } from '../sourceRuntime/SourceHostFeatures'
import { appSourceSettingsStore, SourceSettingsRecord } from '../sourceRuntime/SourceSettingsStore'
import { sourceSettingsFingerprint } from '../sourceRuntime/SourceSettingsIdentity'
import { diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import { sourceMangaDetailSnapshotCache } from './SourceMangaDetailSnapshotCache'

interface MigrationDetailData {
  manga?: Record<string, Object>
  item?: Record<string, Object>
  items?: Record<string, Object>[]
  chapterContext?: Record<string, Object>
}

interface MigrationDetailArgs { mangaId: string; mangaUrl?: string }
interface MigrationDetailHints { network: boolean }
interface MigrationDetailRequest {
  type: string
  version: number
  requestId: string
  sourceId: string
  operation: string
  args: MigrationDetailArgs
  settings: SourceSettingsRecord
  hostHints: MigrationDetailHints
}

export interface PreparedMangaMigration {
  manga: SourceManga
  detail: MangaDetail
  chapters: MangaChapterItem[]
  comic: Comic
  entry: SourceRuntimeRegistryEntry
  settingsRevision: string
}

export async function prepareMangaMigration(
  registry: SourceRuntimeRegistry, manga: SourceManga, isCurrent: () => boolean,
): Promise<PreparedMangaMigration> {
  const entry = registry.lookup(manga.sourceId).entry
  if (!sourceRuntimeEntryEnabled(entry) || entry === undefined) throw new Error('migration_source_changed')
  const settingsRevision = appSourceSettingsStore.revisionForSource(manga.sourceId)
  const current = (): boolean => isCurrent() && registry.lookup(manga.sourceId).entry === entry &&
    settingsRevision === appSourceSettingsStore.revisionForSource(manga.sourceId)
  const settings = appSourceSettingsStore.loadForSource(manga.sourceId)
  const payload: MigrationDetailRequest = { type: 'request', version: 1,
    requestId: `migration-detail-${Date.now()}`, sourceId: manga.sourceId, operation: 'get_manga',
    args: { mangaId: manga.id, mangaUrl: manga.url }, settings, hostHints: { network: true } }
  const request = sourceRequestWithHostFeatures(JSON.stringify(payload))
  const bytes = new Uint8Array(entry.wasmBytes.byteLength)
  bytes.set(entry.wasmBytes)
  const responseJson = await diagnoseSourceOperation(request, () => executeSourceRequestInWorker(request, bytes,
    sourceHttpIdentityJson(entry, undefined, true, 'get_manga')))
  if (!current()) throw new Error('migration_source_changed')
  const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
  if (!response.ok) throw new SourceRuntimeError(response)
  const data = response.data as MigrationDetailData | undefined
  const item = data?.manga ?? data?.item ?? data?.items?.[0]
  if (item === undefined) throw new SourceRuntimeError({ ok: false, reasonCode: 'invalid_response' })
  const detail = parseMangaDetailFromSourceItem(manga.sourceId, item)
  detail.id = manga.id
  detail.sourceId = manga.sourceId
  detail.title = detail.title.trim().length > 0 ? detail.title : manga.title
  detail.url = detail.url ?? manga.url
  detail.coverUrl = detail.coverUrl ?? manga.coverUrl
  detail.sourceName = entry.manifestName
  const catalog = await resolveSourceChapterList(entry, manga.id, detail.url, current, data?.chapterContext)
  if (!current()) throw new Error('migration_source_changed')
  if (!catalog.resolved || catalog.chapters.length === 0) throw new Error('migration_catalog_unavailable')
  detail.chapterCount = catalog.chapters.length
  const comic = comicFromSourceManga(detail, catalog.chapters, sourceLibraryComicId(manga.sourceId, manga.id))
  if (comic.sourceMetadata !== undefined) {
    comic.sourceMetadata.excludedChapterIds = catalog.excludedChapterIds
    comic.sourceMetadata.settingsFingerprint = sourceSettingsFingerprint(settings)
  }
  sourceMangaDetailSnapshotCache.write(entry, manga.sourceId, manga.id,
    { detail, chapters: catalog.chapters, chaptersResolved: true, excludedChapterIds: catalog.excludedChapterIds }, settingsRevision)
  return { manga, detail, chapters: catalog.chapters, comic, entry, settingsRevision }
}

export interface MangaMigrationCommitResult {
  targetComicId: string
  unmatchedReadCount: number
}

/** Destination data is persisted before the old shelf record can be removed.
 * Failures leave the original comic/history/downloads intact; a retry merges the destination.
 * This does not rename/copy cached images, transfer source credentials or write remote trackers.
 */
export async function commitMangaMigration(
  context: common.UIAbilityContext, registry: SourceRuntimeRegistry, library: LibraryStore,
  persistence: LibraryStorePersistenceService, reader: ReaderSessionStore, sourceComicId: string,
  prepared: PreparedMangaMigration, options: MangaMigrationOptions,
): Promise<MangaMigrationCommitResult> {
  return BackupRestoreActivity.runWrite(async (): Promise<MangaMigrationCommitResult> => {
    const source = library.getComic(sourceComicId)
    if (!canMigrateLibraryComic(source) || source === undefined) throw new Error('migration_source_changed')
    if (registry.lookup(prepared.entry.sourceId).entry !== prepared.entry ||
      !sourceRuntimeEntryEnabled(prepared.entry) ||
      prepared.settingsRevision !== appSourceSettingsStore.revisionForSource(prepared.entry.sourceId)) {
      throw new Error('migration_source_changed')
    }
    const existing = library.listComics().find((comic: Comic): boolean =>
      comic.sourceRuntimeId === prepared.manga.sourceId && comic.remoteResourceId === prepared.manga.id)
    const target = JSON.parse(JSON.stringify(prepared.comic)) as Comic
    if (existing !== undefined) {
      const identity = reconcileSourceChapterIdentity(existing, prepared.manga.id, prepared.chapters,
        protectedSourceChapterIds(existing, context.filesDir, reader))
      const retained = JSON.parse(JSON.stringify(existing)) as Comic
      retained.chapters = identity.storedChapters
      target.id = existing.id
      target.createdAt = existing.createdAt
      target.preferredDirection = existing.preferredDirection
      target.chapters = mergeSourceChapters(retained, identity.chapters, Date.now())
      target.categoryIds = existing.categoryIds
    } else {
      target.createdAt = source.createdAt
      target.preferredDirection = source.preferredDirection
    }
    if (source.id === target.id) throw new Error('migration_same_manga')
    target.categoryIds = migrationCategoryIds(source, target, options.categories)
    target.chapterCount = target.chapters.length
    target.pageCount = target.chapters.reduce((sum: number, chapter: Chapter): number => sum + chapter.pageCount, 0)
    const plan = planMangaMigrationReadState(source, target, reader.listChapterStates(),
      reader.getProgress(source.id), reader.getProgress(target.id))
    upsertComicAndPersistLibraryStore(library, persistence, target)
    if (options.readProgress && !reader.commitMigrationReadPlan(plan)) throw new Error('migration_save_failed')
    await new TrackerPreferencesStore(context).copyComicMappings(source.id, target.id)
    const current = library.getComic(source.id)
    if (current === undefined || !sameComicIdentity(source, current)) throw new Error('migration_source_changed')
    if (!options.copy) {
      const progress = reader.getProgress(source.id)
      if (progress !== undefined) {
        reader.saveSourceHistory({ comicId: source.id, sourceId: source.sourceRuntimeId as string,
          mangaId: source.remoteResourceId as string, mangaUrl: source.sourcePath, title: source.title,
          coverUri: source.coverUri, chapterId: progress.chapterId,
          chapterTitle: source.chapters.find((chapter: Chapter): boolean => chapter.id === progress.chapterId)?.title })
        if (!reader.flush()) throw new Error('migration_save_failed')
      }
      removeComicRecordAndPersistLibraryStore(library, persistence, source.id)
    }
    return { targetComicId: target.id, unmatchedReadCount: options.readProgress ? plan.unmatchedReadCount : 0 }
  })
}

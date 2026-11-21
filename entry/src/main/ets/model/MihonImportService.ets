import { common } from '@kit.AbilityKit'
import { taskpool } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'
import { AppStrings } from '../i18n/AppStrings'
import { signalDeviceSyncChange, signalDeviceSyncRestoreStart, signalDeviceSyncRestoreFinish } from '../deviceSync/DeviceSyncSignals'
import { beginAutomationRestore } from './AutomationStateEpoch'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { BackupRestoreCheckpoint } from './BackupRestoreCheckpoint'
import { LIBRARY_STORE_PERSISTENCE_FILE_NAME, usesLibraryDatabase, writeLiveLibrarySnapshot } from './LibraryPersistence'
import { LibraryStore, replaceLibraryContents } from './LibraryStore'
import { appReaderSessionStore, ChapterReadingState, READER_PROGRESS_PERSISTENCE_FILE_NAME,
  usesReaderDatabase, writeLiveReaderSnapshot } from './ReaderSessionStore'
import { MihonImportRecord } from './MihonBackupReader'
import { Comic } from './ComicModels'
import { MihonImportSummary, matchingMihonShelfWork, mihonDeclaredWork, mihonMatchText, mihonSourceMatcher, pickMihonSourceWork } from './MihonImportPlanning'
import { MihonCatalogLink, MihonLinkRequest, MihonPreparedTransaction, MihonSourceMatch, MihonTransactionRequest,
  finishMihonAutomationRestoreTask, prepareMihonTransactionTask, previewMihonBackupTask } from './MihonImportWorker'
import { SourceRuntimeRegistryEntry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { MihonSourceIdentity } from '../sourceRuntime/MihonSourceIdentity'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { prepareMangaMigration } from './SourceMangaMigrationService'
import { SourceMangaDetailSnapshot } from './SourceMangaDetailSnapshotCache'
import { SourceRuntimeError } from './SourceRuntimeError'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { TrackerPreferencesStore } from './TrackerModels'

export interface MihonImportSelection {
  bytes: ArrayBuffer
  summary: MihonImportSummary
}

export interface MihonImportResult {
  unmatchedChapters: number
  targetComicId?: string
}

interface MihonMatch {
  comic: Comic
  entry: SourceRuntimeRegistryEntry
  identity?: MihonSourceIdentity
}

type MihonSourceSummary = SourceRuntimeRegistryInstalledSourceSummary

export class MihonImportService {
  private readonly context: common.UIAbilityContext
  private readonly library: LibraryStore
  constructor(context: common.UIAbilityContext, library: LibraryStore) {
    this.context = context
    this.library = library
  }

  static async preview(bytes: ArrayBuffer): Promise<MihonImportSelection> {
    const task = new taskpool.Task(previewMihonBackupTask, bytes)
    task.setCloneList([bytes])
    return { bytes, summary: await taskpool.execute(task) as MihonImportSummary }
  }

  importBackup(bytes: ArrayBuffer): Promise<MihonImportResult> {
    return this.commit(undefined, bytes)
  }

  private sourceIdentities(): Map<string, MihonSourceIdentity> {
    const identities = new Map<string, MihonSourceIdentity>()
    for (const entry of appSourceRuntimeRegistry.list()) {
      if (entry.mihonImport !== undefined) identities.set(entry.sourceId, entry.mihonImport)
    }
    return identities
  }

  /** The source and the verified edition have independent lifetimes. Keep the
   * source choice even when a request for this particular work fails. */
  private async rememberSources(matchSource: (record: MihonImportRecord) => MihonSourceSummary | undefined,
    sourceIds?: string[], workId?: string, isCurrent?: () => boolean): Promise<boolean> {
    const matches: MihonSourceMatch[] = []
    for (const record of this.library.listMihonImports()) {
      if (record.targetComicId || (workId !== undefined && record.id !== workId)) continue
      const source = matchSource(record)
      if (source === undefined || (sourceIds !== undefined && !sourceIds.includes(source.sourceId))) continue
      const entry = appSourceRuntimeRegistry.lookup(source.sourceId).entry
      const work = mihonDeclaredWork(record, source.sourceId, entry?.mihonImport)
      if (source.sourceId === record.matchedSourceId && (work === undefined ||
        (work.sourceId === record.linkedWork?.sourceId && work.id === record.linkedWork?.id))) continue
      matches.push({ id: record.id, sourceId: source.sourceId,
        work: work ?? (record.linkedWork?.sourceId === source.sourceId ? record.linkedWork : undefined) })
    }
    if (matches.length === 0) return false
    await this.commit(undefined, undefined, matches, isCurrent)
    return isCurrent === undefined || isCurrent()
  }

  private async matchOriginalAddress(record: MihonImportRecord, entry: SourceRuntimeRegistryEntry,
    shelf: Comic[], current: () => boolean): Promise<MihonMatch | undefined> {
    const identity = entry.mihonImport
    const work = mihonDeclaredWork(record, entry.sourceId, identity)
    if (work === undefined) return undefined
    const cached = shelf.find((comic: Comic): boolean => comic.sourceRuntimeId === entry.sourceId &&
      comic.remoteResourceId === work.id && comic.chapters.length > 0)
    const comic = cached ?? (await prepareMangaMigration(appSourceRuntimeRegistry, work, current)).comic
    return { comic, entry, identity }
  }

  /** The normal detail request may recover a chapter catalog after the initial
   * source lookup failed. Use those rows to restore progress before showing it. */
  async linkOpenedCatalog(id: string, snapshot: SourceMangaDetailSnapshot, settingsFingerprint: string,
    isCurrent: () => boolean): Promise<boolean> {
    if (!isCurrent() || !snapshot.chaptersResolved || snapshot.chapters.length === 0) return false
    const record = this.library.listMihonImports().find((row: MihonImportRecord): boolean => row.id === id)
    const work = record?.linkedWork
    if (record === undefined || record.targetComicId || work === undefined || work.sourceId !== snapshot.detail.sourceId ||
      work.id !== snapshot.detail.id) return false
    const entry = appSourceRuntimeRegistry.lookup(work.sourceId).entry
    if (entry === undefined || !entry.enabled) return false
    const current = (): boolean => isCurrent() && entry.enabled &&
      appSourceRuntimeRegistry.lookup(work.sourceId).entry === entry
    const catalog: MihonCatalogLink = { id, detail: snapshot.detail, chapters: snapshot.chapters,
      excludedChapterIds: snapshot.excludedChapterIds ?? [], settingsFingerprint, identity: entry.mihonImport,
      chapterPolicy: entry.websitePolicy?.chapterIdentity }
    const result = await this.commit(undefined, undefined, undefined, current, catalog)
    return result.targetComicId !== undefined
  }

  /** Retry only this work before the history entry falls back to source selection. */
  async retryFromHistory(id: string, isCurrent: () => boolean): Promise<void> {
    const matchSource = mihonSourceMatcher(appSourceRuntimeRegistry.listInstalledSourceSummaries(), this.sourceIdentities())
    if (!isCurrent()) return
    await this.rememberSources((record: MihonImportRecord): MihonSourceSummary | undefined =>
      isCurrent() ? matchSource(record) : undefined, undefined, id, isCurrent)
    const record = this.library.listMihonImports().find((row: MihonImportRecord): boolean => row.id === id)
    if (!isCurrent() || record === undefined || record.targetComicId) return
    const source = matchSource(record)
    if (source === undefined) return
    const entry = appSourceRuntimeRegistry.lookup(source.sourceId).entry
    if (entry === undefined) return
    const current = (): boolean => isCurrent() && entry.enabled &&
      appSourceRuntimeRegistry.lookup(source.sourceId).entry === entry
    const shelf = this.library.listComics(false)
    let target: MihonMatch | undefined
    try {
      target = await this.matchOriginalAddress(record, entry, shelf, current)
    } catch (error) {
      if (error instanceof SourceRuntimeError &&
        (error.diagnostic.kind === 'challenge' || error.diagnostic.code === 'auth_required')) return
    }
    if (!current()) return
    if (target === undefined && record.linkedWork === undefined &&
      source.capabilities.includes('search') && mihonMatchText(record.work.title)) {
      try {
        const cached = matchingMihonShelfWork(record.work, record.sourceName, shelf.filter((comic: Comic): boolean =>
          comic.sourceRuntimeId === source.sourceId))
        if (cached !== undefined) {
          target = { comic: cached, entry }
        } else {
          const browse = new BrowseViewModel(appSourceRuntimeRegistry)
          const catalog = await browse.searchSource(source, record.work.title, 1, '', current)
          const candidate = pickMihonSourceWork(record.work, catalog.manga)
          if (current() && candidate !== undefined) {
            target = { comic: (await prepareMangaMigration(appSourceRuntimeRegistry, candidate, current)).comic, entry }
          }
        }
      } catch (_) {
        // A failed lookup keeps the remembered source available on the next open.
      }
    }
    if (!current() || target === undefined) {
      if (current()) DiagnosticLogger.info('backup', 'mihon_history_retry', 'result=unresolved source=' + source.sourceId)
      return
    }
    const result = await this.commit([{ id, target: target.comic, verifiedEdition: true, identity: target.identity }],
      undefined, undefined, current)
    if (result.targetComicId !== undefined) {
      DiagnosticLogger.info('backup', 'mihon_history_retry', 'result=linked source=' + source.sourceId)
    }
  }

  /** Discovery continues after the local import has finished and its Dialog has
   * closed. Opening a book never waits behind the search for other books. */
  async matchUnresolved(sourceIds?: string[], directOnly: boolean = false): Promise<boolean> {
    const matchSource = mihonSourceMatcher(appSourceRuntimeRegistry.listInstalledSourceSummaries(), this.sourceIdentities())
    const remembered = await this.rememberSources(matchSource, sourceIds)
    if (directOnly) return remembered
    const discovered = await this.discoverWorks(this.library, matchSource, sourceIds)
    if (discovered.size === 0) {
      DiagnosticLogger.info('backup', 'mihon_match_finished', 'linked=0')
      return remembered
    }
    const links: MihonLinkRequest[] = []
    // A manual selection made during discovery takes precedence.
    for (const record of this.library.listMihonImports()) {
      const target = discovered.get(record.id)
      if (!record.targetComicId && target !== undefined &&
        appSourceRuntimeRegistry.lookup(target.entry.sourceId).entry === target.entry && target.entry.enabled) {
        links.push({ id: record.id, target: target.comic, verifiedEdition: true, identity: target.identity })
      }
    }
    if (links.length === 0) return remembered
    await this.commit(links)
    DiagnosticLogger.info('backup', 'mihon_match_finished', 'linked=' + links.length)
    return true
  }

  private async discoverWorks(library: LibraryStore, matchSource: (record: MihonImportRecord) => MihonSourceSummary | undefined,
    sourceIds: string[] | undefined): Promise<Map<string, MihonMatch>> {
    const shelf = library.listComics(false)
    const groups = new Map<SourceRuntimeRegistryInstalledSourceSummary, MihonImportRecord[]>()
    for (const record of library.listMihonImports()) {
      if (record.targetComicId || record.linkedWork !== undefined) continue
      const source = matchSource(record)
      if (source === undefined) continue
      if (sourceIds !== undefined && !sourceIds.includes(source.sourceId)) continue
      const items = groups.get(source) ?? []
      items.push(record)
      groups.set(source, items)
    }
    const selected = Array.from(groups.keys())
    const found = new Map<string, MihonMatch>()
    const search = new BrowseViewModel(appSourceRuntimeRegistry)
    let searched = 0
    let searchFailures = 0
    let emptyResults = 0
    let unverified = 0
    let unavailableChapters = 0
    let verificationRequired = 0
    let next = 0
    const worker = async (): Promise<void> => {
      while (next < selected.length) {
        const source = selected[next++]
        const entry = appSourceRuntimeRegistry.lookup(source.sourceId).entry
        if (entry === undefined) continue
        const current = (): boolean => entry.enabled && appSourceRuntimeRegistry.lookup(source.sourceId).entry === entry
        const works = groups.get(source) ?? []
        for (let index = 0; index < works.length; index++) {
          if (!current()) break
          const record = works[index]
          const work = record.work
          if (!source.capabilities.includes('search') || !mihonMatchText(work.title)) continue
          const saved = matchingMihonShelfWork(work, record.sourceName, shelf.filter((comic: Comic): boolean =>
            comic.sourceRuntimeId === entry.sourceId))
          if (saved !== undefined) {
            found.set(record.id, { comic: saved, entry })
            continue
          }
          let readingCatalog = false
          try {
            // Use the existing source scheduler. Import matching must never
            // launch verification UI or send the work to unrelated sources.
            searched++
            const catalog = await search.searchSource(source, work.title, 1, '', current)
            if (catalog.manga.length === 0) {
              emptyResults++
              continue
            }
            const candidate = pickMihonSourceWork(work, catalog.manga)
            if (candidate === undefined) {
              unverified++
              continue
            }
            readingCatalog = true
            const prepared = await prepareMangaMigration(appSourceRuntimeRegistry, candidate, current)
            found.set(record.id, { comic: prepared.comic, entry })
          } catch (error) {
            if (error instanceof SourceRuntimeError &&
              (error.diagnostic.kind === 'challenge' || error.diagnostic.code === 'auth_required')) {
              verificationRequired += works.length - index
              break
            }
            if (readingCatalog) unavailableChapters++
            else searchFailures++
          }
        }
      }
    }
    await Promise.all([worker(), worker(), worker(), worker()])
    DiagnosticLogger.info('backup', 'mihon_match_lookup',
      `searched=${searched} searchFailures=${searchFailures} empty=${emptyResults} unverified=${unverified} ` +
      `unavailableChapters=${unavailableChapters} verificationRequired=${verificationRequired}`)
    return found
  }

  link(id: string, selection: Comic | string): Promise<MihonImportResult> {
    return this.commit([{ id, target: selection }])
  }

  private async prepareTransaction(staged: string, request: MihonTransactionRequest): Promise<MihonPreparedTransaction> {
    const task = new taskpool.Task(prepareMihonTransactionTask, this.context.filesDir, staged, request)
    if (request.bytes !== undefined) task.setCloneList([request.bytes])
    const comics: Comic[] = []
    const imports: MihonImportRecord[] = []
    const chapters: ChapterReadingState[] = []
    let receivedAll: () => void = () => {}
    const received = new Promise<void>((resolve: () => void): void => { receivedAll = resolve })
    task.onReceiveData((kind: string, rows?: Object[]): void => {
      if (kind === 'complete') receivedAll()
      else if (kind === 'comics') (rows as Comic[]).forEach((row: Comic): void => { comics.push(row) })
      else if (kind === 'imports') (rows as MihonImportRecord[]).forEach((row: MihonImportRecord): void => { imports.push(row) })
      else if (kind === 'chapters') (rows as ChapterReadingState[]).forEach((row: ChapterReadingState): void => { chapters.push(row) })
    })
    hiTraceMeter.startTrace('KomaMihonQueueMerge', 0)
    const execution = taskpool.execute(task)
    hiTraceMeter.finishTrace('KomaMihonQueueMerge', 0)
    const result = await execution as MihonPreparedTransaction
    await received
    result.library.comics = comics
    result.library.mihonImports = imports
    result.reader.chapters = chapters
    return result
  }

  private async commit(links?: MihonLinkRequest[], bytes?: ArrayBuffer,
    sourceMatches?: MihonSourceMatch[], isCurrent?: () => boolean, catalogLink?: MihonCatalogLink): Promise<MihonImportResult> {
    if (bytes !== undefined) {
      BackupRestoreActivity.beginRestore()
    } else if (!await BackupRestoreActivity.beginRestoreWhenIdle(isCurrent)) {
      return { unmatchedChapters: 0 }
    }
    let checkpoint: BackupRestoreCheckpoint | undefined
    let committed = false
    let automationPrepared = false
    const context = this.context
    const reader = appReaderSessionStore(context.filesDir)
    const tracker = new TrackerPreferencesStore(context)
    try {
      signalDeviceSyncRestoreStart(catalogLink !== undefined)
      beginAutomationRestore(context)
      automationPrepared = true
      if (!await reader.flushAsync()) throw new Error('reader_progress_save_failed')
      const beforeMappings = tracker.mappingSnapshot()
      // The detail may reference ArkUI-observed tags or chapter rows. Send
      // only one work's plain data across the TaskPool boundary.
      const catalogLinkJson = catalogLink === undefined ? undefined : JSON.stringify(catalogLink)
      const identities = catalogLink === undefined ? this.sourceIdentities() : new Map<string, MihonSourceIdentity>()
      if (catalogLink?.identity !== undefined && catalogLink.detail.sourceId !== undefined) {
        identities.set(catalogLink.detail.sourceId, catalogLink.identity)
      }
      const request: MihonTransactionRequest = { bytes, links, sourceMatches, catalogLinkJson, identities,
        sources: bytes === undefined ? [] : appSourceRuntimeRegistry.listInstalledSourceSummaries(), trackerMappings: beforeMappings,
        labels: { untitled: AppStrings.get('manga_detail_title_fallback'),
          unnamedSource: AppStrings.get('mihon_import_unnamed_source') } }
      checkpoint = await BackupRestoreCheckpoint.prepare(context, true)
      const staged = checkpoint.stagedFilesDirectory()
      const prepared = await this.prepareTransaction(staged, request)
      const preparedLibrary = staged + '/' + LIBRARY_STORE_PERSISTENCE_FILE_NAME
      if (usesLibraryDatabase(context.filesDir)) {
        writeLiveLibrarySnapshot(context.filesDir, await fs.readText(preparedLibrary))
      } else {
        await fs.rename(preparedLibrary, context.filesDir + '/' + LIBRARY_STORE_PERSISTENCE_FILE_NAME)
      }
      const preparedReader = staged + '/' + READER_PROGRESS_PERSISTENCE_FILE_NAME
      if (usesReaderDatabase(context.filesDir)) {
        writeLiveReaderSnapshot(context.filesDir, await fs.readText(preparedReader))
      } else {
        await fs.rename(preparedReader, context.filesDir + '/' + READER_PROGRESS_PERSISTENCE_FILE_NAME)
      }
      if (prepared.trackerMappings.length > beforeMappings.length) {
        await tracker.saveComicMappingsForBackupRestore(prepared.trackerMappings)
      }
      await checkpoint.commitAsync()
      committed = true
      const linked = prepared.linkedComicIds
      if (linked === undefined) {
        reader.applyCommittedSnapshot(prepared.reader)
        replaceLibraryContents(this.library, prepared.library)
      } else {
        reader.applyCommittedMihonLinks(linked, prepared.reader)
        for (const id of prepared.removedComicIds ?? []) this.library.removeComic(id)
        for (const comic of prepared.library.comics) this.library.upsertComic(comic)
        this.library.updateMihonImports(prepared.library.mihonImports)
      }
      if (prepared.trackerMappings.length > beforeMappings.length) tracker.invalidateMappingSnapshot()
      return { unmatchedChapters: prepared.unmatchedChapters, targetComicId: prepared.targetComicId }
    } catch (error) {
      if (checkpoint !== undefined && !committed) {
        try {
          await checkpoint.rollback()
          tracker.invalidateMappingSnapshot()
          checkpoint.completeRollback()
        } catch (_rollbackError) {
          BackupRestoreActivity.blockUntilRestart()
          await context.terminateSelf()
          throw new Error('backup_recovery_pending')
        }
      }
      throw error as Error
    } finally {
      try {
        if (automationPrepared) await taskpool.execute(finishMihonAutomationRestoreTask, context.filesDir)
      } finally {
        BackupRestoreActivity.finishRestore()
        hiTraceMeter.startTrace('KomaMihonResumeSync', 0)
        try {
          // An additive import preserves the current connection and sync policy.
          signalDeviceSyncRestoreFinish(false, catalogLink !== undefined)
          if (committed && sourceMatches === undefined) {
            signalDeviceSyncChange('shelf')
            signalDeviceSyncChange('reading')
          }
        } finally {
          hiTraceMeter.finishTrace('KomaMihonResumeSync', 0)
        }
      }
    }
  }
}

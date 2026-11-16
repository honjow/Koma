import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { signalDeviceSyncChange, signalDeviceSyncRestoreStart, signalDeviceSyncRestoreFinish } from '../deviceSync/DeviceSyncSignals'
import { beginAutomationRestore, finishAutomationRestore } from './AutomationStateEpoch'
import { BackupRestoreActivity } from './BackupRestoreActivity'
import { BackupRestoreCheckpoint } from './BackupRestoreCheckpoint'
import { AppFilesLibraryStorePersistenceAdapter, LibraryStorePersistenceService } from './LibraryPersistence'
import { InMemoryLibraryStore } from './LibraryStore'
import { AppFilesReaderSessionPersistenceAdapter, ReaderSessionDocumentSnapshot, appReaderSessionStore } from './ReaderSessionStore'
import { MihonBackup, MihonBackupTracking, MihonBackupWork, MihonImportRecord } from './MihonBackupReader'
import { Comic } from './ComicModels'
import { importMihonWorks, linkMihonWork, mergeMihonReading, MihonImportSummary,
  ResolvedMihonImport, summarizeMihonImport, matchingMihonShelfWork, mihonMatchText,
  pickMihonSourceWork } from './MihonImportPlanning'
import { SourceRuntimeRegistryEntry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { MihonSourceIdentity, mihonPathIdentity } from '../sourceRuntime/MihonSourceIdentity'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { prepareMangaMigration } from './SourceMangaMigrationService'
import { SourceRuntimeError } from './SourceRuntimeError'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ComicTrackerMapping, TrackerPreferencesStore, TrackerProviderId, TRACKER_COMIC_MAPPINGS_KEY,
  TRACKER_PREFERENCES_STORE_NAME, normalizeComicTrackerMappings } from './TrackerModels'

export interface MihonImportSelection {
  backup: MihonBackup
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

function mihonSourceMatcher(sources: MihonSourceSummary[]): (record: MihonImportRecord) => MihonSourceSummary | undefined {
  const byId = new Map<string, MihonSourceSummary>()
  const declared = new Map<string, MihonSourceSummary[]>()
  const byName = new Map<string, MihonSourceSummary[]>()
  for (const source of sources) {
    const rule = appSourceRuntimeRegistry.lookup(source.sourceId).entry?.mihonImport
    for (const id of new Set<string>(rule?.sourceIds ?? [])) {
      const matches = declared.get(id) ?? []
      matches.push(source)
      declared.set(id, matches)
    }
    // A source that declares its Mihon editions must not claim other
    // versions of the same title by sharing a provider name.
    if (rule !== undefined) continue
    byId.set(source.sourceId, source)
    if (!source.capabilities.includes('search')) continue
    const names = new Set<string>([mihonMatchText(source.displayName)])
    const localized = source.localizedNames
    if (localized !== undefined) {
      for (const name of Object.keys(localized)) names.add(mihonMatchText(localized[name]))
    }
    names.delete('')
    for (const name of names) {
      const matches = byName.get(name) ?? []
      matches.push(source)
      byName.set(name, matches)
    }
  }
  return (record: MihonImportRecord): MihonSourceSummary | undefined => {
    const matches = declared.get(record.work.sourceId)
    if (matches !== undefined) return matches.length === 1 ? matches[0] : undefined
    const remembered = byId.get(record.matchedSourceId ?? '')
    if (remembered !== undefined) return remembered
    const named = byName.get(mihonMatchText(record.sourceName))
    return named?.length === 1 ? named[0] : undefined
  }
}

function trackerProvider(serviceId: number): TrackerProviderId | undefined {
  // Mihon's TrackerManager defines these numeric identifiers.
  switch (serviceId) {
    case 1: return 'myanimelist'
    case 2: return 'anilist'
    case 3: return 'kitsu'
    case 5: return 'bangumi'
    case 7: return 'mangaupdates'
    default: return undefined
  }
}

export function withMihonTrackerCandidates(current: ComicTrackerMapping[], imported: ResolvedMihonImport[]): ComicTrackerMapping[] {
  const mappings = current.slice()
  for (const entry of imported) {
    for (const track of entry.record.work.tracking ?? []) {
      const providerId = trackerProvider(track.serviceId)
      if (providerId === undefined || !/^\d*[1-9]\d*$/.test(track.mediaId)) continue
      if (mappings.some((row: ComicTrackerMapping): boolean =>
        row.comicId === entry.target.id && row.providerId === providerId)) continue
      // Explicit binding in Koma remains account-scoped. Restoring a candidate
      // preserves the title identity without scheduling any remote mutation.
      mappings.push({ comicId: entry.target.id, providerId, providerTitleId: track.mediaId, providerTitle: track.title,
        mappingState: 'candidate', userConfirmed: false, createdAt: entry.record.work.addedAt || Date.now() })
    }
  }
  return mappings
}

export class MihonImportService {
  private readonly context: common.UIAbilityContext
  constructor(context: common.UIAbilityContext) { this.context = context }

  preview(backup: MihonBackup): MihonImportSelection {
    return { backup, summary: summarizeMihonImport(backup) }
  }

  async importBackup(backup: MihonBackup): Promise<MihonImportResult> {
    return this.commit((library: InMemoryLibraryStore): ResolvedMihonImport[] => {
      const identities = new Map<string, MihonSourceIdentity>()
      for (const entry of appSourceRuntimeRegistry.list()) {
        if (entry.mihonImport !== undefined) identities.set(entry.sourceId, entry.mihonImport)
      }
      const imported = importMihonWorks(backup, library, identities)
      this.rememberSources(imported.map((item: ResolvedMihonImport): MihonImportRecord => item.record),
        mihonSourceMatcher(appSourceRuntimeRegistry.listInstalledSourceSummaries()))
      return imported
    })
  }

  /** The source and the verified edition have independent lifetimes. Keep the
   * source choice even when a request for this particular work fails. */
  private rememberSources(records: MihonImportRecord[], matchSource: (record: MihonImportRecord) => MihonSourceSummary | undefined,
    sourceIds?: string[]): boolean {
    let changed = false
    for (const record of records) {
      if (record.targetComicId) continue
      const source = matchSource(record)
      if (source === undefined || record.matchedSourceId === source.sourceId ||
        (sourceIds !== undefined && !sourceIds.includes(source.sourceId))) continue
      record.matchedSourceId = source.sourceId
      changed = true
    }
    return changed
  }

  private async matchOriginalAddress(record: MihonImportRecord, entry: SourceRuntimeRegistryEntry,
    shelf: Comic[], current: () => boolean): Promise<MihonMatch | undefined> {
    const identity = entry.mihonImport
    if (identity === undefined || !identity.sourceIds.includes(record.work.sourceId)) return undefined
    const id = mihonPathIdentity(record.work.url, identity.work)
    if (id === undefined) return undefined
    const cached = shelf.find((comic: Comic): boolean => comic.sourceRuntimeId === entry.sourceId &&
      comic.remoteResourceId === id && comic.chapters.length > 0)
    const comic = cached ?? (await prepareMangaMigration(appSourceRuntimeRegistry,
      { id, sourceId: entry.sourceId, title: record.work.title }, current)).comic
    return { comic, entry, identity }
  }

  /** Retry only this work before the history entry falls back to source selection. */
  async retryFromHistory(id: string, isCurrent: () => boolean, onSourceSaved?: () => void): Promise<void> {
    const library = new InMemoryLibraryStore()
    const persistence = new LibraryStorePersistenceService(library,
      new AppFilesLibraryStorePersistenceAdapter(this.context.filesDir))
    const matchSource = mihonSourceMatcher(appSourceRuntimeRegistry.listInstalledSourceSummaries())
    await BackupRestoreActivity.runWrite(async (): Promise<void> => {
      persistence.restore()
      if (isCurrent() && this.rememberSources(
        library.listMihonImports().filter((row: MihonImportRecord): boolean => row.id === id), matchSource)) {
        persistence.persist()
        onSourceSaved?.()
      }
    })
    const record = library.listMihonImports().find((row: MihonImportRecord): boolean => row.id === id)
    if (!isCurrent() || record === undefined || record.targetComicId) return
    const source = matchSource(record)
    if (source === undefined) return
    const entry = appSourceRuntimeRegistry.lookup(source.sourceId).entry
    if (entry === undefined) return
    const current = (): boolean => isCurrent() && entry.enabled &&
      appSourceRuntimeRegistry.lookup(source.sourceId).entry === entry
    const shelf = library.listComics(false)
    let target: MihonMatch | undefined
    try {
      target = await this.matchOriginalAddress(record, entry, shelf, current)
    } catch (error) {
      if (error instanceof SourceRuntimeError &&
        (error.diagnostic.kind === 'challenge' || error.diagnostic.code === 'auth_required')) return
    }
    if (!current()) return
    if (target === undefined && source.capabilities.includes('search') && mihonMatchText(record.work.title)) {
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
    const match = target
    const result = await this.commit((latest: InMemoryLibraryStore): ResolvedMihonImport[] => {
      const row = latest.listMihonImports().find((item: MihonImportRecord): boolean => item.id === id)
      return current() && row !== undefined && !row.targetComicId ?
        [linkMihonWork(latest, row, match.comic, true, match.identity)] : []
    })
    if (result.targetComicId !== undefined) {
      DiagnosticLogger.info('backup', 'mihon_history_retry', 'result=linked source=' + source.sourceId)
    }
  }

  /** Discovery continues after the local import has finished and its Dialog has
   * closed. Opening a book never waits behind the search for other books. */
  async matchUnresolved(sourceIds?: string[], directOnly: boolean = false, onSourcesSaved?: () => void): Promise<boolean> {
    const library = new InMemoryLibraryStore()
    const persistence = new LibraryStorePersistenceService(library,
      new AppFilesLibraryStorePersistenceAdapter(this.context.filesDir))
    const matchSource = mihonSourceMatcher(appSourceRuntimeRegistry.listInstalledSourceSummaries())
    await BackupRestoreActivity.runWrite(async (): Promise<void> => {
      persistence.restore()
      if (this.rememberSources(library.listMihonImports(), matchSource, sourceIds)) {
        persistence.persist()
        onSourcesSaved?.()
      }
    })
    const discovered = await this.discoverWorks(library, matchSource, sourceIds, directOnly)
    if (discovered.size === 0) {
      DiagnosticLogger.info('backup', 'mihon_match_finished', 'linked=0')
      return false
    }
    let linked = 0
    await this.commit((current: InMemoryLibraryStore): ResolvedMihonImport[] => {
      // Manual choices and edits made while the installed sources were being
      // queried take precedence over this discovery pass.
      const latest = current.listMihonImports().filter((row: MihonImportRecord): boolean =>
        !row.targetComicId && discovered.has(row.id))
      const byKey = new Map<string, MihonImportRecord>()
      latest.forEach((row: MihonImportRecord): void => { byKey.set(row.id, row) })
      const work: ResolvedMihonImport[] = []
      discovered.forEach((target: MihonMatch, key: string): void => {
        const record = byKey.get(key)
        if (record !== undefined && appSourceRuntimeRegistry.lookup(target.entry.sourceId).entry === target.entry &&
          target.entry.enabled) work.push(linkMihonWork(current, record, target.comic, true, target.identity))
      })
      linked = work.length
      return work
    })
    DiagnosticLogger.info('backup', 'mihon_match_finished', 'linked=' + linked)
    return linked > 0
  }

  private async discoverWorks(library: InMemoryLibraryStore, matchSource: (record: MihonImportRecord) => MihonSourceSummary | undefined,
    sourceIds: string[] | undefined,
    directOnly: boolean): Promise<Map<string, MihonMatch>> {
    const shelf = library.listComics(false)
    const groups = new Map<SourceRuntimeRegistryInstalledSourceSummary, MihonImportRecord[]>()
    for (const record of library.listMihonImports()) {
      if (record.targetComicId) continue
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
    let direct = 0
    let directMatched = 0
    let directFailures = 0
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
          try {
            const match = await this.matchOriginalAddress(record, entry, shelf, current)
            if (match !== undefined) {
              found.set(record.id, match)
              direct++
              directMatched++
              continue
            }
          } catch (error) {
            direct++
            directFailures++
            if (error instanceof SourceRuntimeError &&
              (error.diagnostic.kind === 'challenge' || error.diagnostic.code === 'auth_required')) {
              verificationRequired += works.length - index
              break
            }
          }
          if (directOnly || !current() || !source.capabilities.includes('search') || !mihonMatchText(work.title)) continue
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
      `direct=${direct} directMatched=${directMatched} directFailures=${directFailures} ` +
      `searched=${searched} searchFailures=${searchFailures} empty=${emptyResults} unverified=${unverified} ` +
      `unavailableChapters=${unavailableChapters} verificationRequired=${verificationRequired}`)
    return found
  }

  async link(id: string, selection: Comic | string): Promise<MihonImportResult> {
    return this.commit((library: InMemoryLibraryStore): ResolvedMihonImport[] => {
      const record = library.listMihonImports().find((row: MihonImportRecord): boolean => row.id === id)
      if (record === undefined) throw new Error('mihon_import_missing_work')
      const target = typeof selection === 'string' ? library.getComic(selection) : selection
      if (target === undefined) throw new Error('migration_source_changed')
      return [linkMihonWork(library, record, target)]
    })
  }

  private async commit(prepare: (library: InMemoryLibraryStore) => ResolvedMihonImport[]): Promise<MihonImportResult> {
    BackupRestoreActivity.beginRestore()
    let checkpoint: BackupRestoreCheckpoint | undefined
    let committed = false
    let automationPrepared = false
    const context = this.context
    const reader = appReaderSessionStore(context.filesDir)
    const tracker = new TrackerPreferencesStore(context)
    try {
      signalDeviceSyncRestoreStart()
      beginAutomationRestore(context)
      automationPrepared = true
      if (!await reader.flushAsync()) throw new Error('reader_progress_save_failed')
      const library = new InMemoryLibraryStore()
      const persistence = new LibraryStorePersistenceService(library, new AppFilesLibraryStorePersistenceAdapter(context.filesDir))
      persistence.restore()
      const snapshot = reader.snapshotReadingState()
      const entries = prepare(library)
      for (const item of entries) {
        const identity = appSourceRuntimeRegistry.lookup(item.target.sourceRuntimeId ?? '').entry?.mihonImport
        if (identity !== undefined && identity.sourceIds.includes(item.record.work.sourceId) &&
          item.target.remoteResourceId === mihonPathIdentity(item.record.work.url, identity.work)) {
          item.sameEdition = true
          item.identity = identity
        }
      }
      const unmatchedChapters = mergeMihonReading(snapshot, entries)
      const beforeMappings = tracker.mappingSnapshot()
      const mappings = withMihonTrackerCandidates(beforeMappings, entries)
      const readerDocument: ReaderSessionDocumentSnapshot = {
        progress: snapshot.progress, sourceHistory: snapshot.sourceHistory, remoteHistory: snapshot.remoteHistory,
        chapters: snapshot.chapterStates, readingSessions: snapshot.readingSessions,
        syncPositions: reader.pendingDeviceSyncPositions(), syncActions: reader.pendingDeviceSyncActions(),
      }
      checkpoint = await BackupRestoreCheckpoint.prepare(context)
      persistence.persist()
      new AppFilesReaderSessionPersistenceAdapter(context.filesDir).saveSnapshot(readerDocument)
      if (mappings.length > beforeMappings.length) {
        const store = await preferences.getPreferences(context, TRACKER_PREFERENCES_STORE_NAME)
        await store.put(TRACKER_COMIC_MAPPINGS_KEY, JSON.stringify(normalizeComicTrackerMappings(mappings)))
        await store.flush()
      }
      reader.reload()
      tracker.invalidateMappingSnapshot()
      checkpoint.commit()
      committed = true
      return { unmatchedChapters, targetComicId: entries.length === 1 ? entries[0].target.id : undefined }
    } catch (error) {
      if (checkpoint !== undefined) {
        try {
          await checkpoint.rollback()
          reader.reload()
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
        if (automationPrepared) finishAutomationRestore(context)
      } finally {
        BackupRestoreActivity.finishRestore()
        // An additive import preserves the current connection and sync policy.
        signalDeviceSyncRestoreFinish(false)
        if (committed) {
          signalDeviceSyncChange('shelf')
          signalDeviceSyncChange('reading')
        }
      }
    }
  }
}

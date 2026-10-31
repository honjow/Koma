import { common } from '@kit.AbilityKit'
import { AdvancedDialogV2Button, CustomContentDialogV2 } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { Comic } from '../model/ComicModels'
import { SourceManga } from '../model/SourceModels'
import { LibraryStore, InMemoryLibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService } from '../model/LibraryPersistence'
import { ReaderSessionStore, InMemoryReaderSessionStore } from '../model/ReaderSessionStore'
import { canMigrateLibraryComic } from '../model/SourceMangaMigration'
import { PreparedMangaMigration, prepareMangaMigration, commitMangaMigration } from '../model/SourceMangaMigrationService'
import { SourceRuntimeError } from '../model/SourceRuntimeError'
import { SourceRuntimeRegistry, SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { openSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
import { RouterHelper } from '../common/RouterHelper'
import { BrowseViewModel } from '../viewmodel/BrowseViewModel'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { MangaGridItem } from '../components/MangaGridItem'
import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { MangaMigrationPreferencesStore, MigrationMatchOptions } from '../model/MangaMigrationPreferencesStore'
import { MangaMigrationRouteChromeState } from '../state/MangaMigrationRouteChromeState'
import { chooseMigrationCandidate, migrationSearchQueries, latestMigrationChapter } from '../model/MangaMigrationMatching'
import { sourceLanguageName } from '../sourceRuntime/SourceLanguagePresentation'
import { SearchPage } from './SearchPage'

function s(key: string): string { return AppStrings.get(key) }

interface MigrationRowUpdate {
  comic: Comic
  state: 'idle' | 'searching' | 'ready' | 'failed' | 'skipped' | 'done'
  target?: SourceManga
  error?: string
  errorSourceId?: string
  unmatchedReadCount?: number
  targetComicId?: string
}

// ForEach keeps a row with the same comic ID. Its async result must update
// observed fields on that row, rather than leave the builder holding an old object.
@ObservedV2
class MigrationRow {
  comic: Comic
  @Trace state: 'idle' | 'searching' | 'ready' | 'failed' | 'skipped' | 'done' = 'idle'
  @Trace target?: SourceManga = undefined
  @Trace error?: string = undefined
  @Trace errorSourceId?: string = undefined
  @Trace unmatchedReadCount?: number = undefined
  @Trace targetComicId?: string = undefined

  constructor(comic: Comic) { this.comic = comic }
}

@ComponentV2
export struct MangaMigrationPage {
  @Param comicIds: string[] = []
  @Param initialSources: string[] = []
  @Param initialMatchOptions: MigrationMatchOptions = { deepSearch: false, prioritizeChapters: false }
  @Param chrome: MangaMigrationRouteChromeState = new MangaMigrationRouteChromeState()
  @Param libraryStore: LibraryStore = new InMemoryLibraryStore()
  @Param persistence?: LibraryStorePersistenceService = undefined
  @Param readerStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Param registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
  @Event onLibraryChanged: () => void = () => {}
  @Event onComplete: (targetIds: string[]) => void = () => {}
  @Event onBusyChanged: (busy: boolean) => void = () => {}
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private stage: string = 'sources'
  @Local private sources: SourceRuntimeRegistryInstalledSourceSummary[] = []
  @Local private selectedSources: string[] = []
  @Local private rows: MigrationRow[] = []
  @Local private readProgress: boolean = true
  @Local private categories: boolean = true
  @Local private committing: boolean = false
  @Local private starting: boolean = false
  @Local private deepSearch: boolean = false
  @Local private prioritizeChapters: boolean = false
  @Local private singleConfirmationShown: boolean = false
  private singleDialogId: number = -1
  @Local private searchComicId: string = ''
  private initialized: boolean = false
  private handledCommandSeq: number = 0
  private prepared: Map<string, PreparedMangaMigration> = new Map()
  private generations: Map<string, number> = new Map()
  private matchingRun: number = 0
  private active: boolean = false
  private searcher: BrowseViewModel = new BrowseViewModel()
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.active = true
    if (this.initialized) return
    this.initialized = true
    this.sources = this.registry.listInstalledSourceSummaries().filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean =>
      source.enabled && source.capabilities.includes('search'))
    this.rows = this.comicIds.map((id: string): Comic | undefined => this.libraryStore.getComic(id))
      .filter((comic: Comic | undefined): boolean => canMigrateLibraryComic(comic))
      .map((comic: Comic | undefined): MigrationRow => new MigrationRow(comic as Comic))
    this.selectedSources = this.initialSources.filter((id: string): boolean =>
      this.sources.some((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => source.sourceId === id))
    this.deepSearch = this.initialMatchOptions.deepSearch
    this.prioritizeChapters = this.initialMatchOptions.prioritizeChapters
    this.syncChrome()
  }

  aboutToDisappear(): void { this.active = false; this.closeSingleConfirmation() }

  private syncChrome(): void {
    this.chrome.stage = this.stage
    this.chrome.single = this.rows.length === 1
    this.chrome.busy = this.committing || this.starting
    this.chrome.canContinue = !this.chrome.busy && this.selectedSources.length > 0 && this.rows.length > 0
    this.chrome.readyCount = this.readyCount()
    this.chrome.failedCount = this.rows.filter((row: MigrationRow): boolean => row.state === 'failed').length
    this.chrome.searchingCount = this.rows.filter((row: MigrationRow): boolean => row.state === 'searching').length
    this.syncSearchVisibility()
  }

  @Monitor('chrome.visible', 'singleConfirmationShown')
  private syncSearchVisibility(): void {
    this.chrome.search.visible = this.chrome.visible && this.stage === 'search' && !this.singleConfirmationShown
  }

  @Monitor('chrome.commandSeq')
  private handleTitleCommand(): void {
    if (this.chrome.commandSeq <= this.handledCommandSeq || this.chrome.busy) return
    this.handledCommandSeq = this.chrome.commandSeq
    if (this.chrome.command === 'continue' && this.stage === 'sources') void this.startMatching()
    else if (this.chrome.command === 'copy' && this.readyCount() > 0) this.confirm(true)
    else if (this.chrome.command === 'move' && this.readyCount() > 0) this.confirm(false)
    else if (this.chrome.command === 'finish') this.finish()
    else if (this.chrome.command === 'matches') { this.stage = 'matches'; this.syncChrome() }
    else if (this.chrome.command === 'retryFailed') void this.runMatches(this.rows.filter((row: MigrationRow): boolean => row.state === 'failed'))
    else if (this.chrome.command === 'sources') {
      this.matchingRun += 1
      this.rows.filter((row: MigrationRow): boolean => row.state === 'searching').forEach((row: MigrationRow): void => {
        this.generations.set(row.comic.id, (this.generations.get(row.comic.id) ?? 0) + 1)
        this.updateRow(row.comic.id, { comic: row.comic, state: 'idle' })
      })
      this.stage = 'sources'
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
      this.syncChrome()
    }
  }

  private saveSelectedSources(): Promise<void> {
    return new MangaMigrationPreferencesStore(getContext(this) as common.UIAbilityContext).save(this.selectedSources)
  }

  private showSaveFailure(): void {
    this.getUIContext().getPromptAction().showToast({ message: s('migration_save_failed') })
  }

  private saveMatchOptions(): void {
    void new MangaMigrationPreferencesStore(getContext(this) as common.UIAbilityContext)
      .saveOptions({ deepSearch: this.deepSearch, prioritizeChapters: this.prioritizeChapters })
      .catch((): void => { this.showSaveFailure() })
  }

  private moveSource(from: number, to: number): void {
    if (this.starting || from === to) return
    const sources = this.selectedSources.slice()
    const moved = sources.splice(from, 1)
    sources.splice(to, 0, moved[0])
    this.selectedSources = sources
    void this.saveSelectedSources().catch((): void => { this.showSaveFailure() })
  }

  private updateRow(id: string, next: MigrationRowUpdate): void {
    const row = this.rows.find((value: MigrationRow): boolean => value.comic.id === id)
    if (!this.active || row === undefined) return
    row.state = next.state
    row.target = next.target
    row.error = next.error
    row.errorSourceId = next.errorSourceId
    row.unmatchedReadCount = next.unmatchedReadCount
    row.targetComicId = next.targetComicId
    this.syncChrome()
  }

  private toggleSource(id: string): void {
    this.selectedSources = this.selectedSources.includes(id)
      ? this.selectedSources.filter((value: string): boolean => value !== id) : this.selectedSources.concat([id])
    this.syncChrome()
    void this.saveSelectedSources().catch((): void => { this.showSaveFailure() })
  }

  private selected(): SourceRuntimeRegistryInstalledSourceSummary[] {
    return this.selectedSources.map((id: string): SourceRuntimeRegistryInstalledSourceSummary | undefined =>
      this.sources.find((source: SourceRuntimeRegistryInstalledSourceSummary): boolean => source.sourceId === id))
      .filter((source: SourceRuntimeRegistryInstalledSourceSummary | undefined): boolean => source !== undefined) as SourceRuntimeRegistryInstalledSourceSummary[]
  }

  private sourceName(id: string): string {
    const source = this.registry.listInstalledSourceSummaries().find((row: SourceRuntimeRegistryInstalledSourceSummary): boolean => row.sourceId === id)
    return sourceDisplayName(id, source?.displayName ?? id)
  }

  private originalManga(comic: Comic): SourceManga {
    return { id: comic.remoteResourceId ?? comic.id, sourceId: comic.sourceRuntimeId ?? '', title: comic.title,
      coverUrl: comic.coverUri, url: comic.sourcePath }
  }

  private failureText(error: Object): string {
    if (error instanceof SourceRuntimeError) return error.userText
    const code = (error as Error).message
    if (code === 'migration_catalog_unavailable') return s('migration_catalog_unavailable')
    if (code === 'migration_same_manga') return s('migration_same_manga')
    if (code === 'migration_source_changed') return s('migration_source_changed')
    return s('migration_failed')
  }

  private async match(row: MigrationRow, run?: number): Promise<void> {
    const id = row.comic.id
    const generation = (this.generations.get(id) ?? 0) + 1
    this.generations.set(id, generation)
    // Manual selection is another view of the same batch; other rows keep
    // matching while it is open. Changing sources invalidates matchingRun.
    const current = (): boolean => this.active && this.stage !== 'sources' && this.generations.get(id) === generation &&
      (run === undefined || run === this.matchingRun)
    this.prepared.delete(id)
    this.updateRow(id, { comic: row.comic, state: 'searching' })
    let errorText = ''
    let errorSource = ''
    let best: PreparedMangaMigration | undefined = undefined
    let bestManga: SourceManga | undefined = undefined
    for (const source of this.selected()) {
      if (!current()) return
      try {
        const candidates: SourceManga[] = []
        for (const query of migrationSearchQueries(row.comic.title, this.deepSearch)) {
          if (!current()) return
          const result = await this.searcher.searchSource(source, query, 1, '', current)
          if (!current()) return
          result.manga.forEach((manga: SourceManga): void => {
            if ((manga.sourceId !== row.comic.sourceRuntimeId || manga.id !== row.comic.remoteResourceId) &&
              !candidates.some((value: SourceManga): boolean => value.id === manga.id)) candidates.push(manga)
          })
        }
        const selected = chooseMigrationCandidate(row.comic.title, candidates, this.deepSearch)
        if (selected === undefined) continue
        const target = await prepareMangaMigration(this.registry, selected, current)
        if (!current()) return
        if (best === undefined || (latestMigrationChapter(target.chapters) ?? 0) > (latestMigrationChapter(best.chapters) ?? 0)) {
          best = target
          bestManga = selected
        }
        if (!this.prioritizeChapters) break
      } catch (error) {
        errorText = this.failureText(error as Object)
        errorSource = source.sourceId
      }
    }
    if (!current()) return
    if (best !== undefined && bestManga !== undefined) {
      this.prepared.set(id, best)
      this.updateRow(id, { comic: row.comic, state: 'ready', target: bestManga })
    } else this.updateRow(id, { comic: row.comic, state: 'failed', error: errorText || s('migration_no_match'), errorSourceId: errorSource })
  }

  private async startMatching(): Promise<void> {
    if (!this.chrome.canContinue || this.starting) return
    this.starting = true
    this.syncChrome()
    try { await this.saveSelectedSources() }
    catch (_) { this.showSaveFailure(); return }
    finally { this.starting = false; this.syncChrome() }
    if (!this.active) return
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
    this.stage = 'matches'
    this.syncChrome()
    if (this.rows.length === 1) { this.searchManually(this.rows[0]); return }
    const pending = this.rows.filter((row: MigrationRow): boolean => row.state !== 'done' && row.state !== 'skipped')
    await this.runMatches(pending)
  }

  private async runMatches(pending: MigrationRow[]): Promise<void> {
    if (this.committing) return
    const run = ++this.matchingRun
    let next = 0
    const worker = async (): Promise<void> => {
      while (this.active && run === this.matchingRun && next < pending.length) {
        const row = pending[next++]
        await this.match(row, run)
      }
    }
    // Source calls still pass through the shared per-source admission owner.
    await Promise.all([worker(), worker()])
  }

  private searchManually(row: MigrationRow): void {
    if (this.committing) return
    this.generations.set(row.comic.id, (this.generations.get(row.comic.id) ?? 0) + 1)
    if (row.state === 'searching') this.updateRow(row.comic.id, { comic: row.comic, state: 'idle' })
    // One migration destination owns selection, results and confirmation.
    // Search is an in-place stage, not another route that must pop back first.
    const query = this.searchComicId === row.comic.id ? this.chrome.search.query : row.comic.title
    this.searchComicId = row.comic.id
    this.chrome.search.submitQuery(query)
    this.stage = 'search'
    this.syncChrome()
  }

  private selectSearchTarget(manga: SourceManga): void {
    const row = this.rows.find((item: MigrationRow): boolean => item.comic.id === this.searchComicId)
    if (row === undefined || this.committing) return
    if (this.rows.length > 1) { this.stage = 'matches'; this.syncChrome() }
    void this.selectTarget(row.comic, manga)
  }

  private async selectTarget(comic: Comic, manga: SourceManga): Promise<void> {
    const id = comic.id
    const generation = (this.generations.get(id) ?? 0) + 1
    this.generations.set(id, generation)
    const current = (): boolean => this.active && this.generations.get(id) === generation
    this.prepared.delete(id)
    this.updateRow(id, { comic, target: manga, state: 'searching' })
    if (this.rows.length === 1) {
      this.showSingleConfirmation()
    }
    try {
      if (comic.sourceRuntimeId === manga.sourceId && comic.remoteResourceId === manga.id) throw new Error('migration_same_manga')
      const prepared = await prepareMangaMigration(this.registry, manga, current)
      if (!current()) return
      this.prepared.set(id, prepared)
      this.updateRow(id, { comic, target: manga, state: 'ready' })
    } catch (error) {
      if (current()) this.updateRow(id, { comic, target: manga, state: 'failed',
        error: this.failureText(error as Object), errorSourceId: manga.sourceId })
    }
  }

  private skip(row: MigrationRow): void {
    this.generations.set(row.comic.id, (this.generations.get(row.comic.id) ?? 0) + 1)
    this.prepared.delete(row.comic.id)
    this.updateRow(row.comic.id, { comic: row.comic, state: 'skipped' })
  }

  private readyCount(): number { return this.rows.filter((row: MigrationRow): boolean => row.state === 'ready').length }

  private confirm(copy: boolean): void {
    this.getUIContext().showAlertDialog({ title: s(copy ? 'migration_copy' : 'migration_move'),
      message: s(copy ? 'migration_copy_confirm' : 'migration_move_confirm').replace('%s', `${this.readyCount()}`),
      autoCancel: true,
      primaryButton: { value: s(copy ? 'migration_copy' : 'migration_move'), action: () => { void this.commit(copy) } },
      secondaryButton: { value: s('common_cancel'), action: () => {} },
    })
  }

  private async commit(copy: boolean): Promise<void> {
    if (this.committing || this.persistence === undefined) return
    this.committing = true
    this.syncChrome()
    this.onBusyChanged(true)
    try {
      const pending = this.rows.filter((row: MigrationRow): boolean => row.state === 'ready')
      for (const row of pending) {
        const target = this.prepared.get(row.comic.id)
        if (!this.active || target === undefined) break
        try {
          const result = await commitMangaMigration(getContext(this) as common.UIAbilityContext, this.registry,
            this.libraryStore, this.persistence, this.readerStore, row.comic.id, target,
            { copy, readProgress: this.readProgress, categories: this.categories })
          this.updateRow(row.comic.id, { comic: row.comic, target: row.target, state: 'done',
            unmatchedReadCount: result.unmatchedReadCount, targetComicId: result.targetComicId })
          this.onLibraryChanged()
        } catch (error) {
          this.updateRow(row.comic.id, { comic: row.comic, target: row.target, state: 'failed', error: this.failureText(error as Object) })
          this.onLibraryChanged()
        }
      }
    } finally {
      this.committing = false
      this.syncChrome()
      this.onBusyChanged(false)
      if (this.rows.length === 1 && this.rows[0].state === 'done') {
        this.closeSingleConfirmation()
        this.finish()
      }
    }
  }

  private finish(): void {
    const ids: string[] = []
    this.rows.filter((row: MigrationRow): boolean => row.state === 'done').forEach((row: MigrationRow): void => {
      if (row.targetComicId !== undefined && !ids.includes(row.targetComicId)) ids.push(row.targetComicId)
    })
    DiagnosticLogger.info('manga_migration', 'finish', `targets=${ids.length}`)
    this.onComplete(ids)
  }

  private verify(row: MigrationRow): void {
    const sourceId = row.errorSourceId ?? row.target?.sourceId ?? ''
    openSourceWebSession(sourceId, this.sourceName(sourceId), (): void => {
      if (row.target !== undefined) void this.selectTarget(row.comic, row.target)
      else void this.match(row)
    })
  }

  private previewManga(manga: SourceManga): void {
    if (this.committing) return
    this.closeSingleConfirmation()
    RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
  }

  @Builder
  private MatchComparison(row: MigrationRow) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Column({ space: ThemeConstants.SPACE_SM }) {
          MangaGridItem({ manga: this.originalManga(row.comic),
            onMangaTap: (): void => { this.previewManga(this.originalManga(row.comic)) } })
          Text(this.sourceName(row.comic.sourceRuntimeId ?? '')).fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(2)
          Text(this.chapterSummary(row.comic.chapters.length, latestMigrationChapter(row.comic.chapters)))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor(ThemeConstants.TEXT_SECONDARY)
        }.layoutWeight(1)
        SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor([ThemeConstants.TEXT_SECONDARY])
        Column({ space: ThemeConstants.SPACE_SM }) {
          if (row.target !== undefined) {
            MangaGridItem({ manga: row.target, onMangaTap: (manga: SourceManga): void => {
              this.previewManga(manga)
            } })
            Text(this.sourceName(row.target.sourceId)).fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(2)
            if (row.state === 'ready' || row.state === 'done') {
              Text(this.targetChapterSummary(row))
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor(ThemeConstants.TEXT_SECONDARY)
            }
          } else {
            Text(s(row.state === 'searching' ? 'migration_searching' : 'migration_no_match'))
              .fontColor(ThemeConstants.TEXT_SECONDARY).fontSize(ThemeConstants.FONT_SIZE_BODY)
          }
        }.layoutWeight(1)
      }.alignItems(VerticalAlign.Center).padding(ThemeConstants.SPACE_MD)
  }

  private chapterSummary(count: number, latest?: number): string {
    const text = s('migration_chapter_count').replace('%s', `${count}`)
    return latest === undefined ? text : text + ' · ' + s('migration_latest_chapter').replace('%s', `${latest}`)
  }

  private targetChapterSummary(row: MigrationRow): string {
    const prepared = this.prepared.get(row.comic.id)
    return prepared === undefined ? '' : this.chapterSummary(prepared.chapters.length, latestMigrationChapter(prepared.chapters))
  }

  @Builder
  private MatchRow(row: MigrationRow) {
    GroupedListSection() {
      this.MatchComparison(row)
      if (row.state === 'failed') {
        ConciseListRow({ title: row.error ?? s('migration_failed'), wrapTitle: true, showChevron: false,
          isEnabled: !this.committing,
          actionButtonText: s('common_retry'), actionButtonAction: (): void => {
            if (row.target !== undefined) void this.selectTarget(row.comic, row.target)
            else void this.match(row)
          } })
        if ((this.registry.lookup(row.errorSourceId ?? '').entry?.webSessionOrigins?.length ?? 0) > 0) {
          ConciseListRow({ title: s('source_web_open'), isEnabled: !this.committing,
            action: (): void => { this.verify(row) } })
        }
      }
      if (row.state === 'done') {
        ConciseListRow({ title: s('migration_done'), showChevron: false,
          subtitle: (row.unmatchedReadCount ?? 0) > 0
            ? s('migration_unmatched_read').replace('%s', `${row.unmatchedReadCount}`) : '' })
      } else if (row.state === 'skipped') {
        ConciseListRow({ title: s('migration_skipped'), showChevron: false, isEnabled: !this.committing,
          actionButtonText: s('common_retry'), actionButtonAction: (): void => { void this.match(row) } })
      } else {
        ConciseListRow({ title: s('migration_change_match'), isEnabled: !this.committing,
          action: (): void => { this.searchManually(row) } })
        ListDivider()
        ConciseListRow({ title: s('migration_skip'), showChevron: false, isEnabled: !this.committing,
          action: (): void => { this.skip(row) } })
      }
    }
  }

  @Builder
  private SourceSelectionRow(source: SourceRuntimeRegistryInstalledSourceSummary, selected: boolean) {
    ConciseListRow({ title: this.sourceName(source.sourceId), showChevron: false, wrapTitle: true,
      subtitle: sourceLanguageName(source.language), hasSourceIdentityPrefix: true,
      sourceIdentityIconUri: source.icon ?? '', sourceIdentitySourceId: source.sourceId, sourceIdentityVersion: source.version,
      isEnabled: !this.starting,
      surfaceRadius: ThemeConstants.GROUPED_LIST_INNER_RADIUS,
      suffixBuilderParam: selected ? (): void => { this.SourceDragHandle() } : undefined,
      action: (): void => { this.toggleSource(source.sourceId) } })
  }

  @Builder
  private SourceDragHandle() {
    SymbolGlyph($r('sys.symbol.line_3_horizontal'))
      .fontSize(20)
      .fontColor([ThemeConstants.TEXT_SECONDARY])
  }

  @Builder
  private TransferOptions() {
    GroupedListSection({ title: s('migration_include') }) {
      ConciseListRow({ title: s('migration_read_progress'), hasSwitch: true, checked: this.readProgress,
        isEnabled: !this.committing, switchAction: (value: boolean): void => { this.readProgress = value } })
      ListDivider()
      ConciseListRow({ title: s('migration_categories'), hasSwitch: true, checked: this.categories,
        isEnabled: !this.committing, switchAction: (value: boolean): void => { this.categories = value } })
    }
  }

  // The result page owns Mihon-style confirmation. Viewing a work dismisses
  // the dialog and returns to the same results, without a selection route pop.
  private showSingleConfirmation(): void {
    if (this.singleConfirmationShown) return
    this.singleConfirmationShown = true
    this.getUIContext().getPromptAction().openCustomDialog({
      builder: () => { this.SingleConfirmation() },
      alignment: DialogAlignment.Center,
      autoCancel: true,
      onWillDismiss: (action: DismissDialogAction): void => {
        if (this.committing) return
        this.singleDialogId = -1
        this.singleConfirmationShown = false
        action.dismiss()
      },
    }).then((id: number): void => {
      if (this.singleConfirmationShown && this.active) this.singleDialogId = id
      else this.getUIContext().getPromptAction().closeCustomDialog(id)
    }).catch((): void => { this.singleConfirmationShown = false })
  }

  private closeSingleConfirmation(): void {
    this.singleConfirmationShown = false
    if (this.singleDialogId < 0) return
    const id = this.singleDialogId
    this.singleDialogId = -1
    this.getUIContext().getPromptAction().closeCustomDialog(id)
  }

  @Builder
  private SingleConfirmationContent() {
        Column({ space: ThemeConstants.SPACE_SM }) {
          if (this.rows.length === 1) {
            // Preparation updates this one-line summary in place. Keep the
            // spinner's slot so ready/committing never add a trailing row.
            Row({ space: ThemeConstants.SPACE_SM }) {
              Text(this.chapterSummary(this.rows[0].comic.chapters.length, latestMigrationChapter(this.rows[0].comic.chapters))
                + (this.rows[0].state === 'ready' ? ' → ' + this.targetChapterSummary(this.rows[0]) : ''))
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor(ThemeConstants.TEXT_SECONDARY)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              LoadingProgress().width(24).height(24).color(ThemeConstants.BRAND_PRIMARY)
                .visibility(this.rows[0].state === 'searching' || this.committing ? Visibility.Visible : Visibility.Hidden)
            }.width('100%').constraintSize({ minHeight: 24 })
            Row({ space: ThemeConstants.SPACE_SM }) {
              Checkbox({ name: 'migrationReadProgress' }).select(this.readProgress).enabled(!this.committing)
                .onChange((checked: boolean): void => { this.readProgress = checked })
              Text(s('migration_read_progress')).layoutWeight(1).fontColor(ThemeConstants.TEXT_PRIMARY)
                .onClick((): void => { if (!this.committing) this.readProgress = !this.readProgress })
            }.width('100%')
            Row({ space: ThemeConstants.SPACE_SM }) {
              Checkbox({ name: 'migrationCategories' }).select(this.categories).enabled(!this.committing)
                .onChange((checked: boolean): void => { this.categories = checked })
              Text(s('migration_categories')).layoutWeight(1).fontColor(ThemeConstants.TEXT_PRIMARY)
                .onClick((): void => { if (!this.committing) this.categories = !this.categories })
            }.width('100%')
            if (this.rows[0].state === 'failed') {
              Text(this.rows[0].error ?? s('migration_failed')).fontColor(ThemeConstants.DANGER).width('100%')
              Button(s('common_retry'), { buttonStyle: ButtonStyleMode.TEXTUAL })
                .onClick((): void => { if (this.rows[0].target !== undefined) void this.selectTarget(this.rows[0].comic, this.rows[0].target!) })
              if ((this.registry.lookup(this.rows[0].errorSourceId ?? '').entry?.webSessionOrigins?.length ?? 0) > 0) {
                Button(s('source_web_open'), { buttonStyle: ButtonStyleMode.TEXTUAL })
                  .onClick((): void => { this.closeSingleConfirmation(); this.verify(this.rows[0]) })
              }
            }
          }
        }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private SingleConfirmation() {
    CustomContentDialogV2({
      primaryTitle: this.rows[0]?.target?.title ?? s('migration_include'),
      contentBuilder: () => { this.SingleConfirmationContent() },
      buttons: [
        new AdvancedDialogV2Button({ content: s('migration_show_manga'), enabled: !this.committing,
          action: (): void => { const target = this.rows[0]?.target; if (target !== undefined) this.previewManga(target) } }),
        new AdvancedDialogV2Button({ content: s('migration_copy'), enabled: !this.committing && this.readyCount() > 0,
          action: (): void => { void this.commit(true) } }),
        new AdvancedDialogV2Button({ content: s('migration_move'), enabled: !this.committing && this.readyCount() > 0,
          action: (): void => { void this.commit(false) } }),
      ],
    })
  }

  build() {
    Stack() {
    if (this.stage === 'search') {
      SearchPage({ chrome: this.chrome.search, migrationSources: this.selectedSources,
        libraryStore: this.libraryStore, libraryPersistenceService: this.persistence,
        onMangaSelected: (manga: SourceManga): void => { this.selectSearchTarget(manga) } })
    } else {
    SecondaryListScaffold({ scroller: this.scroller, listSpace: this.stage === 'sources' ? 0 : ThemeConstants.SPACE_SM - 2 }) {
      if (this.stage === 'sources') {
        if (this.selectedSources.length > 0) {
          ListItem() {
            SectionHeader({ title: s('migration_selected_sources') })
          }.margin({ bottom: ThemeConstants.SPACE_XS })
          // Native onMove requires direct ListItem children. Keep the existing
          // grouped surface while allowing the system to animate the rows.
          ForEach(this.selected(), (source: SourceRuntimeRegistryInstalledSourceSummary, index: number) => {
            ListItem() {
              Column() {
                this.SourceSelectionRow(source, true)
                if (index < this.selectedSources.length - 1) ListDivider()
              }.padding({ left: ThemeConstants.LIST_SECTION_INSET, right: ThemeConstants.LIST_SECTION_INSET,
                top: index === 0 ? ThemeConstants.LIST_SECTION_INSET : 0,
                bottom: index === this.selectedSources.length - 1 ? ThemeConstants.LIST_SECTION_INSET : 0 })
            }
            .backgroundColor(ThemeConstants.CARD)
            .borderRadius({ topLeft: index === 0 ? ThemeConstants.RADIUS_CARD : 0,
              topRight: index === 0 ? ThemeConstants.RADIUS_CARD : 0,
              bottomLeft: index === this.selectedSources.length - 1 ? ThemeConstants.RADIUS_CARD : 0,
              bottomRight: index === this.selectedSources.length - 1 ? ThemeConstants.RADIUS_CARD : 0 })
          }, (source: SourceRuntimeRegistryInstalledSourceSummary) => source.sourceId)
          .onMove((from: number, to: number): void => { this.moveSource(from, to) })
        }
        if (this.rows.length > 1) {
          ListItem() {
            GroupedListSection({ title: s('migration_matching_options') }) {
              ConciseListRow({ title: s('migration_deep_search'), hasSwitch: true, checked: this.deepSearch,
                isEnabled: !this.starting, switchAction: (value: boolean): void => { this.deepSearch = value; this.saveMatchOptions() } })
              ListDivider()
              ConciseListRow({ title: s('migration_prioritize_chapters'), hasSwitch: true, checked: this.prioritizeChapters,
                isEnabled: !this.starting, switchAction: (value: boolean): void => { this.prioritizeChapters = value; this.saveMatchOptions() } })
            }
          }.margin({ top: ThemeConstants.SPACE_SM - 2 })
        }
        ListItem() {
          GroupedListSection({ title: s('migration_available_sources') }) {
            ForEach(this.sources.filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean =>
              !this.selectedSources.includes(source.sourceId)), (source: SourceRuntimeRegistryInstalledSourceSummary, index: number) => {
              this.SourceSelectionRow(source, false)
              if (index < this.sources.length - this.selectedSources.length - 1) ListDivider()
            }, (source: SourceRuntimeRegistryInstalledSourceSummary) => source.sourceId)
            if (this.sources.length === 0) ConciseListRow({ title: s('migration_no_sources'), showChevron: false })
          }
        }.margin({ top: this.selectedSources.length > 0 || this.rows.length > 1 ? ThemeConstants.SPACE_SM - 2 : 0 })

      } else {
        ListItem() {
          ConciseListRow({ title: s('migration_matching_progress')
            .replace('%s', `${this.rows.filter((row: MigrationRow): boolean => row.state !== 'searching' && row.state !== 'idle').length}`)
            .replace('%s', `${this.rows.length}`),
            subtitle: s('migration_ready_progress').replace('%s', `${this.readyCount()}`)
              .replace('%s', `${this.chrome.failedCount}`), showChevron: false })
        }
        ForEach(this.rows, (row: MigrationRow) => {
          ListItem() { this.MatchRow(row) }
        }, (row: MigrationRow) => row.comic.id)
        ListItem() {
          this.TransferOptions()
        }
      }
    }
    }
    }.width('100%').height('100%')
  }
}

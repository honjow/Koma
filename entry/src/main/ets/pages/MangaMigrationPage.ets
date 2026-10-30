import { common } from '@kit.AbilityKit'
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
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { MangaGridItem } from '../components/MangaGridItem'
import { KomaMenuListRow } from '../components/ui/KomaMenuListRow'
import { ThemeConstants } from '../theme/ThemeConstants'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

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
  @Local private searchMenuId: string = ''
  private prepared: Map<string, PreparedMangaMigration> = new Map()
  private generations: Map<string, number> = new Map()
  private active: boolean = false
  private searcher: BrowseViewModel = new BrowseViewModel()
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.active = true
    this.sources = this.registry.listInstalledSourceSummaries().filter((source: SourceRuntimeRegistryInstalledSourceSummary): boolean =>
      source.enabled && source.capabilities.includes('search'))
    this.rows = this.comicIds.map((id: string): Comic | undefined => this.libraryStore.getComic(id))
      .filter((comic: Comic | undefined): boolean => canMigrateLibraryComic(comic))
      .map((comic: Comic | undefined): MigrationRow => new MigrationRow(comic as Comic))
  }

  aboutToDisappear(): void { this.active = false }

  private updateRow(id: string, next: MigrationRowUpdate): void {
    const row = this.rows.find((value: MigrationRow): boolean => value.comic.id === id)
    if (!this.active || row === undefined) return
    row.state = next.state
    row.target = next.target
    row.error = next.error
    row.errorSourceId = next.errorSourceId
    row.unmatchedReadCount = next.unmatchedReadCount
    row.targetComicId = next.targetComicId
  }

  private toggleSource(id: string): void {
    this.selectedSources = this.selectedSources.includes(id)
      ? this.selectedSources.filter((value: string): boolean => value !== id) : this.selectedSources.concat([id])
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

  private async match(row: MigrationRow): Promise<void> {
    const id = row.comic.id
    const generation = (this.generations.get(id) ?? 0) + 1
    this.generations.set(id, generation)
    const current = (): boolean => this.active && this.generations.get(id) === generation
    this.prepared.delete(id)
    this.updateRow(id, { comic: row.comic, state: 'searching' })
    let errorText = ''
    let errorSource = ''
    for (const source of this.selected()) {
      if (!current()) return
      try {
        const result = await this.searcher.searchSource(source, row.comic.title, 1, '', current)
        if (!current()) return
        const candidates = result.manga.filter((manga: SourceManga): boolean =>
          manga.sourceId !== row.comic.sourceRuntimeId || manga.id !== row.comic.remoteResourceId)
        const selected = candidates.find((manga: SourceManga): boolean =>
          manga.title.trim().toLocaleLowerCase() === row.comic.title.trim().toLocaleLowerCase()) ?? candidates[0]
        if (selected === undefined) continue
        const target = await prepareMangaMigration(this.registry, selected, current)
        if (!current()) return
        this.prepared.set(id, target)
        this.updateRow(id, { comic: row.comic, state: 'ready', target: selected })
        return
      } catch (error) {
        errorText = this.failureText(error as Object)
        errorSource = source.sourceId
      }
    }
    if (current()) this.updateRow(id, { comic: row.comic, state: 'failed', error: errorText || s('migration_no_match'), errorSourceId: errorSource })
  }

  private async startMatching(): Promise<void> {
    this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
    this.stage = 'matches'
    const pending = this.rows.filter((row: MigrationRow): boolean => row.state !== 'done' && row.state !== 'skipped')
    let next = 0
    const worker = async (): Promise<void> => {
      while (this.active && next < pending.length) {
        const row = pending[next++]
        await this.match(row)
      }
    }
    // Source calls still pass through the shared per-source admission owner.
    await Promise.all([worker(), worker()])
  }

  private searchManually(row: MigrationRow, source: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.searchMenuId = ''
    this.generations.set(row.comic.id, (this.generations.get(row.comic.id) ?? 0) + 1)
    RouterHelper.pushSourceSearch({ source }, row.comic.title, (manga: SourceManga): void => {
      void this.selectTarget(row.comic, manga)
    })
  }

  private async selectTarget(comic: Comic, manga: SourceManga): Promise<void> {
    const id = comic.id
    const generation = (this.generations.get(id) ?? 0) + 1
    this.generations.set(id, generation)
    const current = (): boolean => this.active && this.generations.get(id) === generation
    this.prepared.delete(id)
    this.updateRow(id, { comic, target: manga, state: 'searching' })
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
    } finally { this.committing = false; this.onBusyChanged(false) }
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

  @Builder
  private SearchMenu(row: MigrationRow) {
    Menu() {
      ForEach(this.selected(), (source: SourceRuntimeRegistryInstalledSourceSummary) => {
        MenuItem({ content: this.sourceName(source.sourceId) })
          .onClick(() => { this.searchManually(row, source) })
      }, (source: SourceRuntimeRegistryInstalledSourceSummary) => source.sourceId)
    }
  }

  @Builder
  private MatchRow(row: MigrationRow) {
    GroupedListSection() {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Column({ space: ThemeConstants.SPACE_SM }) {
          MangaGridItem({ manga: this.originalManga(row.comic), onMangaTap: (): void => {
            if (this.committing) return
            RouterHelper.pushMangaDetail({ mangaId: row.comic.remoteResourceId ?? row.comic.id, sourceId: row.comic.sourceRuntimeId })
          } })
          Text(this.sourceName(row.comic.sourceRuntimeId ?? '')).fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(2)
        }.layoutWeight(1)
        SymbolGlyph($r('sys.symbol.arrow_right')).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor([ThemeConstants.TEXT_SECONDARY])
        Column({ space: ThemeConstants.SPACE_SM }) {
          if (row.target !== undefined) {
            MangaGridItem({ manga: row.target, onMangaTap: (manga: SourceManga): void => {
              if (this.committing) return
              RouterHelper.pushMangaDetail({ mangaId: manga.id, sourceId: manga.sourceId, initialManga: manga })
            } })
            Text(this.sourceName(row.target.sourceId)).fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY).maxLines(2)
          } else {
            Text(s(row.state === 'searching' ? 'migration_searching' : 'migration_no_match'))
              .fontColor(ThemeConstants.TEXT_SECONDARY).fontSize(ThemeConstants.FONT_SIZE_BODY)
          }
        }.layoutWeight(1)
      }.alignItems(VerticalAlign.Center).padding(ThemeConstants.SPACE_MD)
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
        KomaMenuListRow({ title: s('migration_change_match'), isEnabled: !this.committing,
          isMenuOpen: this.searchMenuId === row.comic.id,
          action: (): void => { this.searchMenuId = this.searchMenuId === row.comic.id ? '' : row.comic.id },
          menuBuilderParam: (): void => { this.SearchMenu(row) } })
        ListDivider()
        ConciseListRow({ title: s('migration_skip'), showChevron: false, isEnabled: !this.committing,
          action: (): void => { this.skip(row) } })
      }
    }
  }

  build() {
    SecondaryListScaffold({ scroller: this.scroller }) {
      if (this.stage === 'sources') {
        ListItem() {
          GroupedListSection({ title: s('migration_target_sources') }) {
            ForEach(this.sources, (source: SourceRuntimeRegistryInstalledSourceSummary) => {
              ConciseListRow({ title: this.sourceName(source.sourceId), hasSwitch: true,
                checked: this.selectedSources.includes(source.sourceId), showChevron: false,
                switchAction: (): void => { this.toggleSource(source.sourceId) },
                action: (): void => { this.toggleSource(source.sourceId) } })
            }, (source: SourceRuntimeRegistryInstalledSourceSummary) => source.sourceId)
            if (this.sources.length === 0) ConciseListRow({ title: s('migration_no_sources'), showChevron: false })
          }
        }
        ListItem() {
          KomaActionButton({ label: s('migration_continue'), kind: 'primary', fullWidth: true,
            isEnabled: this.selectedSources.length > 0 && this.rows.length > 0,
            action: (): void => { void this.startMatching() } })
        }
      } else {
        ListItem() {
          ConciseListRow({ title: s('migration_choose_sources'), isEnabled: !this.committing,
            action: (): void => {
              this.scroller.scrollTo({ xOffset: 0, yOffset: 0 })
              this.stage = 'sources'
            } })
        }
        ForEach(this.rows, (row: MigrationRow) => {
          ListItem() { this.MatchRow(row) }
        }, (row: MigrationRow) => row.comic.id)
        ListItem() {
          GroupedListSection({ title: s('migration_include') }) {
            ConciseListRow({ title: s('migration_read_progress'), hasSwitch: true, checked: this.readProgress,
              isEnabled: !this.committing, switchAction: (value: boolean): void => { this.readProgress = value } })
            ListDivider()
            ConciseListRow({ title: s('migration_categories'), hasSwitch: true, checked: this.categories,
              isEnabled: !this.committing, switchAction: (value: boolean): void => { this.categories = value } })
          }
        }
        ListItem() {
          Row({ space: ThemeConstants.SPACE_MD }) {
            KomaActionButton({ label: s('migration_copy'), busy: this.committing,
              isEnabled: this.readyCount() > 0 && !this.committing, fullWidth: true,
              action: (): void => { this.confirm(true) } }).layoutWeight(1)
            KomaActionButton({ label: s('migration_move'), kind: 'primary', busy: this.committing,
              isEnabled: this.readyCount() > 0 && !this.committing, fullWidth: true,
              action: (): void => { this.confirm(false) } }).layoutWeight(1)
          }
        }
        ListItem() {
          KomaActionButton({ label: s('migration_finish'), fullWidth: true, isEnabled: !this.committing,
            action: (): void => { this.finish() } })
        }
      }
    }
  }
}

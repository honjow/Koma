import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import { Chapter, Comic } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { ReaderSessionStore } from '../model/ReaderSessionStore'
import { LibraryChapterUpdate, cachedLibraryChapterUpdates } from '../model/LibraryChapterUpdates'
import { LibraryUpdateResultStore } from '../model/LibraryUpdateResultStore'
import { connectLibraryUpdateState, LibraryUpdateState } from '../state/LibraryUpdateState'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { PullRefreshController } from '../components/PullRefresh'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { CachedCoverImage } from '../components/CachedCoverImage'
import { ThemeConstants } from '../theme/ThemeConstants'

interface ChapterUpdateRow { comic: Comic; chapter: Chapter; discoveredAt: number }

@ComponentV2
export struct LibraryUpdatesPage {
  @Param @Require libraryStore: LibraryStore
  @Param libraryRevision: number = 0
  @Param readerSessionStore?: ReaderSessionStore = undefined
  @Param readerProgressRevision: number = 0
  @Event onOpenReader: (comicId: string, chapterId: string) => void = () => {}
  @Event onOpenComic: (comicId: string) => void = () => {}
  @Event onRefresh: () => Promise<void> = async () => {}
  @Param refreshController: PullRefreshController = new PullRefreshController()
  @Local private refreshing: boolean = false
  @Local private updateState: LibraryUpdateState = connectLibraryUpdateState()
  @Local private language: LanguageState = connectLanguageState()
  @Local private records: LibraryChapterUpdate[] = cachedLibraryChapterUpdates() ?? []
  @Local private loading: boolean = cachedLibraryChapterUpdates() === undefined
  @Local private error: boolean = false
  @Local private visibleLimit: number = 80
  private loadRevision: number = 0

  aboutToAppear(): void { this.reload() }
  aboutToDisappear(): void { this.loadRevision += 1 }

  @Monitor('updateState.revision')
  private reload(): void {
    const revision = ++this.loadRevision
    void new LibraryUpdateResultStore(getContext(this) as common.UIAbilityContext).loadChapterUpdates()
      .then((records: LibraryChapterUpdate[]): void => {
        if (revision !== this.loadRevision) return
        this.records = records; this.loading = false; this.error = false
      }).catch((): void => {
        if (revision !== this.loadRevision) return
        this.loading = false; this.error = true
      })
  }

  private day(value: number): string {
    return new Intl.DateTimeFormat(this.language.effectiveLocale,
      { year: 'numeric', month: 'long', day: 'numeric' }).format(new Date(value))
  }

  @Computed
  private get rows(): ChapterUpdateRow[] {
    void this.libraryRevision
    const rows: ChapterUpdateRow[] = []
    const chaptersByComic = new Map<string, Map<string, Chapter>>()
    this.records.forEach((record: LibraryChapterUpdate): void => {
      const comic = this.libraryStore.getComic(record.comicId)
      if (comic !== undefined && !chaptersByComic.has(comic.id)) {
        const chapters = new Map<string, Chapter>()
        comic.chapters.forEach((chapter: Chapter): void => { chapters.set(chapter.id, chapter) })
        chaptersByComic.set(comic.id, chapters)
      }
      const chapter = chaptersByComic.get(record.comicId)?.get(record.chapterId)
      if (comic !== undefined && chapter !== undefined) rows.push({ comic, chapter, discoveredAt: record.discoveredAt })
    })
    return rows
  }

  @Computed
  private get rowsByDay(): Record<string, ChapterUpdateRow[]> {
    const groups: Record<string, ChapterUpdateRow[]> = {}
    this.rows.slice(0, this.visibleLimit).forEach((row: ChapterUpdateRow): void => {
      const date = this.day(row.discoveredAt)
      if (groups[date] === undefined) groups[date] = []
      groups[date].push(row)
    })
    return groups
  }

  @Computed
  private get days(): string[] { return Object.keys(this.rowsByDay) }

  private isLastRow(day: string, row: ChapterUpdateRow): boolean {
    const rows = this.rowsByDay[day]
    const last = rows[rows.length - 1]
    return last.comic.id === row.comic.id && last.chapter.id === row.chapter.id
  }

  @Builder
  private Cover(comic: Comic) {
    Button({ type: ButtonType.Normal }) {
      CachedCoverImage({ uri: comic.coverUri ?? '', sourceRuntimeId: comic.sourceRuntimeId ?? '',
        sourceImageId: comic.remoteResourceId ?? comic.id, sourceMangaUrl: comic.sourcePath,
        sourceKind: comic.sourceKind, remoteServerId: comic.remoteServerId ?? '' })
        .width(44).height(60).borderRadius(ThemeConstants.RADIUS_COVER).clip(true)
    }.backgroundColor(Color.Transparent)
      // Match the grouped card's 12vp cover inset on both axes: the group
      // supplies 4vp, and the native row prefix already supplies 8vp at left.
      .margin({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      .onClick(() => { this.onOpenComic(comic.id) })
  }

  @Builder
  private UpdateRow(row: ChapterUpdateRow) {
    ConciseListRow({ title: row.comic.title, subtitle: row.chapter.title,
      trailingText: this.readerSessionStore?.isChapterRead(row.comic.id, row.chapter.id)
        ? AppStrings.get('chapter_list_filter_read') : '', showChevron: false,
      prefixBuilderParam: () => { this.Cover(row.comic) },
      action: (): void => { this.onOpenReader(row.comic.id, row.chapter.id) } })
  }

  build() {
    if (this.language.effectiveLocale.length > 0 && this.readerProgressRevision >= 0) {
      PullRefreshListScaffold({ controller: this.refreshController, onRefresh: async (): Promise<void> => {
        this.refreshing = true
        try { await this.onRefresh(); this.reload() } finally { this.refreshing = false }
      },
        onReachEnd: (): void => { this.visibleLimit = Math.min(this.visibleLimit + 80, this.rows.length) },
        bottomPadding: ThemeConstants.SPACE_XL }) {
        if (this.updateState.busy && !this.refreshing) {
          ListItem() {
            Row({ space: ThemeConstants.SPACE_SM }) {
              Text(AppStrings.get('library_updates_checking')).fontColor(ThemeConstants.TEXT_SECONDARY)
            }.padding(ThemeConstants.SPACE_MD)
          }
        }
        // Refresh updates the saved snapshot in the background. Its activity
        // must not replace either existing rows or the confirmed empty state.
        if (this.rows.length === 0) {
          ListItem() {
            if (this.loading) {
              LoadingProgress().width(32).height(32).color(ThemeConstants.BRAND_PRIMARY)
                .visibility(this.refreshing ? Visibility.Hidden : Visibility.Visible)
            }
            else {
              KomaEmptyState({ icon: $r('sys.symbol.bell'),
                title: AppStrings.get(this.error ? 'library_updates_load_failed' : 'library_updates_empty'),
                message: AppStrings.get('library_updates_empty_hint'),
                showAction: this.error, actionLabel: AppStrings.get('common_retry'),
                action: (): void => { this.reload() } })
            }
          }
        } else {
          ForEach(this.days, (day: string) => {
            ListItem() {
              GroupedListSection({ title: day }) {
                ForEach(this.rowsByDay[day], (row: ChapterUpdateRow) => {
                  this.UpdateRow(row)
                  if (!this.isLastRow(day, row)) { ListDivider() }
                }, (row: ChapterUpdateRow): string => JSON.stringify([row.comic.id, row.chapter.id,
                  row.comic.title, row.chapter.title, row.comic.coverUri,
                  this.readerSessionStore?.isChapterRead(row.comic.id, row.chapter.id)]))
              }
            }
          }, (day: string): string => day)
        }
      }
    }
  }
}

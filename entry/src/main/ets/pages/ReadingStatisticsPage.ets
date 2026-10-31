import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaMenuListRow } from '../components/ui/KomaMenuListRow'
import { LibraryStore } from '../model/LibraryStore'
import { ReaderSessionStore } from '../model/ReaderSessionStore'
import { OfflineDownloadQueueStore, OfflineDownloadQueueEntry } from '../model/OfflineDownloadQueueStore'
import { OfflineDownloadStatus } from '../model/OfflineDownloadStore'
import { ReadingStatistics, ReadingLibraryStatistics, ReadingStatisticsPeriod, ReadingSessionRecord,
  ReadingDayStatistics, summarizeReadingSessions, summarizeReadingLibrary, readingCalendarDays } from '../model/ReadingStatistics'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(key: string): string { return AppStrings.get(key) }

@ComponentV2
export struct ReadingStatisticsPage {
  @Param libraryStore?: LibraryStore = undefined
  @Param sessionStore?: ReaderSessionStore = undefined
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private period: ReadingStatisticsPeriod = 'all'
  @Local private selectedDate: number = Date.now()
  @Local private menuKey: string = ''
  @Local private statistics: ReadingStatistics = summarizeReadingSessions([], 'all', Date.now())
  @Local private libraryStatistics: ReadingLibraryStatistics = { books: 0, startedBooks: 0,
    completedBooks: 0, chapters: 0, readChapters: 0, downloadedChapters: 0 }
  @Local private calendar: ReadingDayStatistics[] = []
  private records: ReadingSessionRecord[] = []
  private calendarScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.records = this.sessionStore?.listReadingSessions() ?? []
    const downloaded = new Set<string>()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    new OfflineDownloadQueueStore(context.filesDir).load().forEach((entry: OfflineDownloadQueueEntry): void => {
      if (entry.status === OfflineDownloadStatus.DOWNLOADED) downloaded.add(JSON.stringify([entry.comicId, entry.chapterId]))
    })
    if (this.sessionStore !== undefined) this.libraryStatistics = summarizeReadingLibrary(
      this.libraryStore?.listComics() ?? [], this.sessionStore, downloaded)
    this.refreshPeriod()
  }

  private refreshPeriod(): void {
    this.statistics = summarizeReadingSessions(this.records, this.period, this.selectedDate)
    this.calendar = readingCalendarDays(this.statistics, this.period, this.selectedDate)
  }

  private periodTitle(period: ReadingStatisticsPeriod): string { return s(`reading_statistics_${period}`) }
  private dateTitle(timestamp: number): string {
    const date = new Date(timestamp)
    return this.period === 'month' ? `${date.getFullYear()}-${`${date.getMonth() + 1}`.padStart(2, '0')}` : `${date.getFullYear()}`
  }
  private dateOptions(): number[] {
    const options = new Set<number>()
    const dates = this.records.map((record: ReadingSessionRecord): number => record.endedAt).concat([Date.now()])
    dates.forEach((timestamp: number): void => {
      const date = new Date(timestamp)
      options.add(new Date(date.getFullYear(), this.period === 'month' ? date.getMonth() : 0, 1).getTime())
    })
    return Array.from(options).sort((a: number, b: number): number => b - a)
  }
  private duration(value: number): string {
    if (value < 60000) return AppStrings.format('reading_statistics_seconds_value', Math.floor(value / 1000))
    const minutes = Math.floor(value / 60000)
    return AppStrings.format('reading_statistics_duration_value', Math.floor(minutes / 60), minutes % 60)
  }

  @Builder
  private PeriodMenu() {
    Menu() {
      ForEach(['all', 'month', 'year'], (key: string) => {
        MenuItem({ content: this.periodTitle(key as ReadingStatisticsPeriod) })
          .selected(this.period === key)
          .onClick((): void => { this.period = key as ReadingStatisticsPeriod; this.menuKey = ''; this.refreshPeriod() })
      })
    }
  }

  @Builder
  private DateMenu() {
    Menu() {
      ForEach(this.dateOptions(), (timestamp: number) => {
        MenuItem({ content: this.dateTitle(timestamp) })
          .selected(this.dateTitle(this.selectedDate) === this.dateTitle(timestamp))
          .onClick((): void => { this.selectedDate = timestamp; this.menuKey = ''; this.refreshPeriod() })
      })
    }
  }

  @Builder
  private ValueRow(title: string, value: string) {
    ConciseListRow({ title, trailingText: value, showChevron: false })
  }

  private calendarRows(): number[] { return Array.from({ length: 7 }, (_: Object, index: number): number => index) }
  private calendarColumns(): number[] { return Array.from({ length: Math.ceil(this.calendar.length / 7) },
    (_: Object, index: number): number => index) }
  private calendarDay(column: number, row: number): ReadingDayStatistics | undefined { return this.calendar[column * 7 + row] }
  private calendarOpacity(column: number, row: number): number {
    const day = this.calendarDay(column, row)
    return day === undefined ? 0 : day.pagesRead === 0 ? 0.12 : Math.min(1, 0.35 + day.durationMs / 3600000)
  }
  private showDay(column: number, row: number): void {
    const day = this.calendarDay(column, row)
    if (day !== undefined) this.getUIContext().getPromptAction().showToast({ message:
      `${day.day} · ${this.duration(day.durationMs)} · ${AppStrings.format('reading_statistics_pages_value', day.pagesRead)}` })
  }

  @Builder
  private ReadingCalendar() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Scroll(this.calendarScroller) {
        Row({ space: 4 }) {
          ForEach(this.calendarColumns(), (column: number) => {
            Column({ space: 4 }) {
              ForEach(this.calendarRows(), (row: number) => {
                Button({ type: ButtonType.Normal, stateEffect: true }) {}
                  .width(14).height(14).borderRadius(3)
                  .backgroundColor(ThemeConstants.BRAND_PRIMARY).opacity(this.calendarOpacity(column, row))
                  .accessibilityText(this.calendarDay(column, row)?.day ?? '')
                  .onClick((): void => { this.showDay(column, row) })
              })
            }
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      .onAppear((): void => { this.calendarScroller.scrollEdge(Edge.End) })
      Text(`${this.calendar[0]?.day ?? ''} — ${this.calendar[this.calendar.length - 1]?.day ?? ''}`)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION).fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%').alignItems(HorizontalAlign.Start).padding(ThemeConstants.SPACE_MD)
  }

  @Builder
  private Content() {
    ListItem() {
      GroupedListSection() {
        KomaMenuListRow({ title: s('reading_statistics_period'), trailingText: this.periodTitle(this.period),
          trailingDropdown: true, showChevron: false, isMenuOpen: this.menuKey === 'period',
          action: (): void => { this.menuKey = this.menuKey === 'period' ? '' : 'period' },
          menuBuilderParam: (): void => { this.PeriodMenu() } })
        if (this.period !== 'all') {
          ListDivider()
          KomaMenuListRow({ title: this.periodTitle(this.period), trailingText: this.dateTitle(this.selectedDate),
            trailingDropdown: true, showChevron: false, isMenuOpen: this.menuKey === 'date',
            action: (): void => { this.menuKey = this.menuKey === 'date' ? '' : 'date' },
            menuBuilderParam: (): void => { this.DateMenu() } })
        }
      }
    }
    ListItem() {
      GroupedListSection({ title: s('reading_statistics_reading') }) {
        this.ValueRow(s('reading_statistics_duration'), this.duration(this.statistics.durationMs))
        ListDivider()
        this.ValueRow(s('reading_statistics_pages'), `${this.statistics.pagesRead}`)
        ListDivider()
        this.ValueRow(s('reading_statistics_books'), `${this.statistics.booksRead}`)
      }
    }
    ListItem() {
      GroupedListSection({ title: s('reading_statistics_streaks') }) {
        this.ValueRow(s('reading_statistics_current_streak'), AppStrings.format('reading_statistics_days_value', this.statistics.currentStreak))
        ListDivider()
        this.ValueRow(s('reading_statistics_longest_streak'), AppStrings.format('reading_statistics_days_value', this.statistics.longestStreak))
      }
    }
    ListItem() { GroupedListSection({ title: s('reading_statistics_daily') }) { this.ReadingCalendar() } }
    ListItem() {
      GroupedListSection({ title: s('reading_statistics_library') }) {
        this.ValueRow(s('reading_statistics_total_books'), `${this.libraryStatistics.books}`)
        ListDivider()
        this.ValueRow(s('reading_statistics_started_books'), `${this.libraryStatistics.startedBooks}`)
        ListDivider()
        this.ValueRow(s('reading_statistics_completed_books'), `${this.libraryStatistics.completedBooks}`)
        ListDivider()
        this.ValueRow(s('reading_statistics_total_chapters'), `${this.libraryStatistics.chapters}`)
        ListDivider()
        this.ValueRow(s('reading_statistics_read_chapters'), `${this.libraryStatistics.readChapters}`)
        ListDivider()
        this.ValueRow(s('reading_statistics_downloaded_chapters'), `${this.libraryStatistics.downloadedChapters}`)
      }
    }
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) SecondaryListScaffold({ content: (): void => { this.Content() } })
  }
}

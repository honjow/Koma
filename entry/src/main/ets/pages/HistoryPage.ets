import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { connectRemoteProgressSyncState, RemoteProgressSyncState } from '../state/RemoteProgressSyncState'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  Chapter,
  Comic,
  ComicId,
  LibraryItem,
  ReadingProgress,
} from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import {
  AppFilesReaderSessionPersistenceAdapter,
  PersistentReaderSessionStore,
  ReaderSessionStore,
} from '../model/ReaderSessionStore'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

const HISTORY_LIMIT: number = 50
const MS_PER_MINUTE: number = 60 * 1000
const MS_PER_HOUR: number = 60 * MS_PER_MINUTE
const MS_PER_DAY: number = 24 * MS_PER_HOUR
const MS_PER_MONTH: number = 30 * MS_PER_DAY
const MS_PER_YEAR: number = 365 * MS_PER_DAY

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct HistoryPage {
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param active: boolean = false
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private remoteProgress: RemoteProgressSyncState = connectRemoteProgressSyncState()
  @Local private historyItems: LibraryItem[] = []
  @Local private revision: number = 0
  @Event onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}

  @Monitor('active')
  private onActiveChanged(): void {
    if (this.active) {
      this.reloadHistory('tab_active')
    }
  }

  @Monitor('remoteProgress.syncRevision')
  private onRemoteProgressSyncRevChanged(): void {
    void this.remoteProgress.syncRevision
    this.reloadHistory('bootstrap_sync')
  }

  private createReaderSessionStore(): ReaderSessionStore | undefined {
    try {
      const context = getContext(this) as common.UIAbilityContext
      if (context === undefined || context.filesDir === undefined || context.filesDir.length === 0) {
        console.info('[History] step=session_store_unavailable reason=context')
        return undefined
      }
      return new PersistentReaderSessionStore(
        new AppFilesReaderSessionPersistenceAdapter(context.filesDir)
      )
    } catch (error) {
      void error
      console.info('[History] step=session_store_unavailable reason=context')
      return undefined
    }
  }

  private reloadHistory(reason: string): void {
    console.info(`[History] step=load_start reason=${reason}`)
    const sessionStore = this.createReaderSessionStore()
    const progressByComicId: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
    this.libraryStore.listComics().forEach((comic: Comic) => {
      const progress = sessionStore === undefined ? undefined : sessionStore.getProgress(comic.id)
      if (progress !== undefined) {
        progressByComicId.set(comic.id, progress)
      }
    })
    this.historyItems = this.libraryStore.listLibraryItems(progressByComicId)
      .filter((item: LibraryItem) => item.lastReadAt !== undefined)
      .sort((a: LibraryItem, b: LibraryItem) => {
        return (b.lastReadAt ?? 0) - (a.lastReadAt ?? 0)
      })
      .slice(0, HISTORY_LIMIT)
    this.revision += 1
    console.info(`[History] step=load_done count=${this.historyItems.length} revision=${this.revision}`)
  }

  private relativeTime(timestampMs: number | undefined): string {
    if (timestampMs === undefined || timestampMs <= 0) {
      return ''
    }
    const diff = Math.max(0, Date.now() - timestampMs)
    if (diff < MS_PER_MINUTE) {
      return s('history_relative_just_now')
    }
    if (diff < MS_PER_HOUR) {
      return s('history_relative_minutes_ago').replace('%s', `${Math.floor(diff / MS_PER_MINUTE)}`)
    }
    if (diff < MS_PER_DAY) {
      return s('history_relative_hours_ago').replace('%s', `${Math.floor(diff / MS_PER_HOUR)}`)
    }
    if (diff < MS_PER_MONTH) {
      return s('history_relative_days_ago').replace('%s', `${Math.floor(diff / MS_PER_DAY)}`)
    }
    if (diff < MS_PER_YEAR) {
      return s('history_relative_months_ago').replace('%s', `${Math.floor(diff / MS_PER_MONTH)}`)
    }
    return s('history_relative_years_ago').replace('%s', `${Math.floor(diff / MS_PER_YEAR)}`)
  }

  private coverColor(item: LibraryItem): string {
    let hash = 0
    for (let index = 0; index < item.comicId.length; index += 1) {
      hash = (hash + item.comicId.charCodeAt(index)) % ThemeConstants.COVER_PALETTE.length
    }
    return ThemeConstants.COVER_PALETTE[hash]
  }

  private chapterText(item: LibraryItem): string {
    if (item.progress === undefined) {
      return s('history_chapter_count').replace('%s', `${item.chapterCount}`)
    }
    const comic = this.libraryStore.getComic(item.comicId)
    const chapterIndex = comic === undefined ? -1 : comic.chapters.findIndex((chapter: Chapter) => {
      return chapter.id === item.progress?.chapterId
    })
    if (chapterIndex >= 0) {
      return s('history_chapter_index').replace('%s', `${chapterIndex + 1}`)
    }
    return item.progress.chapterId.length > 0
      ? s('history_chapter_read')
      : s('history_chapter_count').replace('%s', `${item.chapterCount}`)
  }

  private progressText(item: LibraryItem): string {
    if (item.progress === undefined) {
      return s('history_page_chapter_count')
        .replace('%s', `${item.pageCount}`)
        .replace('%s', `${item.chapterCount}`)
    }
    const page = item.progress.pageIndex + 1
    const total = item.progress.totalPages > 0 ? item.progress.totalPages : item.pageCount
    return s('history_page_progress')
      .replace('%s', `${page}`)
      .replace('%s', `${total}`)
      .replace('%s', this.chapterText(item))
  }

  private openHistoryItem(item: LibraryItem): void {
    const chapterId = item.progress === undefined ? undefined : item.progress.chapterId
    console.info(`[History] step=open_resume comic=${item.comicId} chapter=${chapterId ?? ''} page=${item.progress?.pageIndex ?? 0}`)
    this.onOpenReader(item.comicId, chapterId)
  }

  private removeHistoryItem(item: LibraryItem): void {
    const sessionStore = this.createReaderSessionStore()
    if (sessionStore === undefined) {
      return
    }
    sessionStore.removeProgress(item.comicId)
    this.historyItems = this.historyItems.filter((historyItem: LibraryItem): boolean => {
      return historyItem.comicId !== item.comicId
    })
    this.revision += 1
    console.info('[History] step=remove_item')
  }

  private clearHistory(): void {
    const sessionStore = this.createReaderSessionStore()
    if (sessionStore === undefined) {
      return
    }
    sessionStore.listProgress().forEach((progress: ReadingProgress) => {
      sessionStore.removeProgress(progress.comicId)
    })
    this.historyItems = []
    this.revision += 1
    console.info('[History] step=clear')
  }

  @Builder
  private EmptyHistory() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(s('history_empty_title'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(s('history_empty_message'))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height(220)
    .padding(ThemeConstants.SPACE_XL)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private Cover(item: LibraryItem) {
    Stack({ alignContent: Alignment.Center }) {
      if (item.coverUri !== undefined && item.coverUri.length > 0) {
        Image(item.coverUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Text('K')
          .fontSize(ThemeConstants.FONT_SIZE_H1)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
    }
    .width(64)
    .height(88)
    .borderRadius(ThemeConstants.RADIUS_THUMB)
    .clip(true)
    .backgroundColor(this.coverColor(item))
  }

  @Builder
  private HistoryRow(item: LibraryItem) {
    Row({ space: ThemeConstants.SPACE_LG }) {
      Row({ space: ThemeConstants.SPACE_LG }) {
        this.Cover(item)

        Column({ space: ThemeConstants.SPACE_SM }) {
          Row() {
            Text(item.title)
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(this.relativeTime(item.lastReadAt))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .margin({ left: ThemeConstants.SPACE_MD })
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          Text(this.progressText(item))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Progress({
            value: item.progress === undefined ? 0 : Math.round(item.progress.progressRatio * 100),
            total: 100,
            type: ProgressType.Linear,
          })
            .height(4)
            .color(ThemeConstants.BRAND_PRIMARY)
            .backgroundColor(ThemeConstants.SOFT_TINT)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick(() => {
        this.openHistoryItem(item)
      })

      KomaIconButton({
        icon: $r('sys.symbol.trash'),
        kind: 'ghost',
        accentColor: ThemeConstants.TEXT_SECONDARY,
        action: () => {
          this.removeHistoryItem(item)
        },
      })
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private HistoryHeader() {
    Row() {
      Text(s('history_recent_title'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .layoutWeight(1)
      KomaActionButton({
        label: s('common_clear'),
        kind: 'ghost',
        compact: true,
        controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
        action: () => {
          this.clearHistory()
        },
      })
    }
    .width('100%')
  }

  aboutToAppear(): void {
    this.reloadHistory('appear')
  }

  onPageShow(): void {
    this.reloadHistory('page_show')
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        if (this.historyItems.length === 0) {
          ListItem() {
            this.EmptyHistory()
          }
        } else {
          ListItem() {
            this.HistoryHeader()
          }
          ForEach(this.historyItems, (item: LibraryItem) => {
            ListItem() {
              this.HistoryRow(item)
            }
          }, (item: LibraryItem) => `${this.revision}:${item.comicId}:${item.lastReadAt ?? 0}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

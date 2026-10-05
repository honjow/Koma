import { common } from '@kit.AbilityKit'
import { CachedCoverImage, cachedCoverFailureKey } from '../components/CachedCoverImage'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { connectRemoteProgressSyncState, RemoteProgressSyncState } from '../state/RemoteProgressSyncState'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  Chapter,
  ComicId,
  ComicSourceKind,
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
import {
  SourceReadHistoryEntry,
  SourceReaderSessionRequest,
  sourceReaderSessionRequestFromHistory,
} from '../model/SourceReaderSession'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

const HISTORY_LIMIT: number = 50
const MS_PER_MINUTE: number = 60 * 1000
const MS_PER_HOUR: number = 60 * MS_PER_MINUTE
const MS_PER_DAY: number = 24 * MS_PER_HOUR
const MS_PER_WEEK: number = 7 * MS_PER_DAY
const MS_PER_MONTH: number = 30 * MS_PER_DAY
const MS_PER_YEAR: number = 365 * MS_PER_DAY

function s(name: string): string {
  return AppStrings.get(name)
}

type HistoryGroupKey = 'today' | 'yesterday' | 'last_7_days' | 'older'

interface HistorySection {
  key: HistoryGroupKey
  title: string
  items: HistoryItem[]
}

/**
 * History can project a normal shelf item or an un-shelved source reading
 * session.  This is a view model only; a source entry never pretends to be a
 * `Comic` in LibraryStore.
 */
interface HistoryItem {
  id: string
  comicId: ComicId
  title: string
  coverUri?: string
  sourceRuntimeId?: string
  sourceImageId?: string
  sourceKind?: ComicSourceKind
  remoteServerId?: string
  chapterCount: number
  pageCount: number
  lastReadAt?: number
  progress?: ReadingProgress
  sourceHistory?: SourceReadHistoryEntry
}

@ComponentV2
export struct HistoryPage {
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param active: boolean = false
  @Param readerSessionStore?: ReaderSessionStore = undefined
  @Param readerProgressRevision: number = 0
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private remoteProgress: RemoteProgressSyncState = connectRemoteProgressSyncState()
  @Local private historyItems: HistoryItem[] = []
  @Local private failedCoverUris: string[] = []
  @Event onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}
  @Event onOpenSourceReader: (request: SourceReaderSessionRequest) => void = (_request: SourceReaderSessionRequest) => {}

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

  @Monitor('readerProgressRevision')
  private onReaderProgressRevisionChanged(): void {
    this.reloadHistory('reader_progress')
  }

  private createReaderSessionStore(): ReaderSessionStore | undefined {
    if (this.readerSessionStore !== undefined) {
      return this.readerSessionStore
    }
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
    if (sessionStore !== undefined) {
      sessionStore.listProgress().forEach((progress: ReadingProgress): void => {
        progressByComicId.set(progress.comicId, progress)
      })
    }
    const libraryItems: HistoryItem[] = this.libraryStore.listLibraryItems(progressByComicId)
      .filter((item: LibraryItem) => item.lastReadAt !== undefined)
      .map((item: LibraryItem): HistoryItem => this.libraryHistoryItem(item))
    const libraryComicIds: Set<ComicId> = new Set<ComicId>()
    libraryItems.forEach((item: HistoryItem): void => {
      libraryComicIds.add(item.comicId)
    })
    const sourceItems: HistoryItem[] = []
    if (sessionStore !== undefined) {
      sessionStore.listSourceHistory().forEach((entry: SourceReadHistoryEntry): void => {
        const progress = progressByComicId.get(entry.comicId)
        if (!libraryComicIds.has(entry.comicId) && progress !== undefined) {
          sourceItems.push(this.sourceHistoryItem(entry, progress))
        }
      })
    }
    this.historyItems = libraryItems.concat(sourceItems)
      .sort((a: HistoryItem, b: HistoryItem): number => {
        return (b.lastReadAt ?? 0) - (a.lastReadAt ?? 0)
      })
      .slice(0, HISTORY_LIMIT)
    console.info(`[History] step=load_done count=${this.historyItems.length}`)
  }

  private libraryHistoryItem(item: LibraryItem): HistoryItem {
    return {
      id: item.id,
      comicId: item.comicId,
      title: item.title,
      coverUri: item.coverUri,
      sourceRuntimeId: item.sourceRuntimeId,
      sourceImageId: item.sourceImageId,
      sourceKind: item.sourceKind,
      remoteServerId: item.remoteServerId,
      chapterCount: item.chapterCount,
      pageCount: item.pageCount,
      lastReadAt: item.lastReadAt,
      progress: item.progress,
    }
  }

  private sourceHistoryItem(entry: SourceReadHistoryEntry, progress: ReadingProgress): HistoryItem {
    return {
      id: `source-history:${entry.comicId}`,
      comicId: entry.comicId,
      title: entry.title,
      coverUri: entry.coverUri,
      sourceRuntimeId: entry.sourceId,
      sourceImageId: entry.mangaId,
      chapterCount: 1,
      pageCount: progress.totalPages,
      lastReadAt: progress.updatedAt,
      progress,
      sourceHistory: entry,
    }
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

  private coverColor(item: HistoryItem): string {
    let hash = 0
    for (let index = 0; index < item.comicId.length; index += 1) {
      hash = (hash + item.comicId.charCodeAt(index)) % ThemeConstants.COVER_PALETTE.length
    }
    return ThemeConstants.COVER_PALETTE[hash]
  }

  private chapterText(item: HistoryItem): string {
    if (item.progress === undefined) {
      return s('history_chapter_count').replace('%s', `${item.chapterCount}`)
    }
    const sourceChapterTitle = item.sourceHistory?.chapterTitle?.trim()
    if (sourceChapterTitle !== undefined && sourceChapterTitle.length > 0) {
      return sourceChapterTitle
    }
    if (item.sourceHistory !== undefined) {
      return s('history_chapter_read')
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

  private progressText(item: HistoryItem): string {
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

  private openHistoryItem(item: HistoryItem): void {
    const chapterId = item.progress === undefined ? undefined : item.progress.chapterId
    console.info(`[History] step=open_resume comic=${item.comicId} chapter=${chapterId ?? ''} page=${item.progress?.pageIndex ?? 0}`)
    if (item.sourceHistory !== undefined) {
      const request = sourceReaderSessionRequestFromHistory(item.sourceHistory)
      if (request !== undefined) {
        this.onOpenSourceReader(request)
      }
      return
    }
    this.onOpenReader(item.comicId, chapterId)
  }

  private removeHistoryItem(item: HistoryItem): void {
    const sessionStore = this.createReaderSessionStore()
    if (sessionStore === undefined) {
      return
    }
    sessionStore.removeProgress(item.comicId)
    sessionStore.removeSourceHistory(item.comicId)
    this.historyItems = this.historyItems.filter((historyItem: HistoryItem): boolean => {
      return historyItem.comicId !== item.comicId
    })
    console.info('[History] step=remove_item')
  }

  private confirmRemoveHistoryItem(item: HistoryItem): void {
    this.getUIContext().showAlertDialog({
      title: s('history_remove_title'),
      message: s('history_remove_message').replace('%s', item.title),
      autoCancel: true,
      primaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeHistoryItem(item)
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private clearHistory(): void {
    const sessionStore = this.createReaderSessionStore()
    if (sessionStore === undefined) {
      return
    }
    sessionStore.listProgress().forEach((progress: ReadingProgress) => {
      sessionStore.removeProgress(progress.comicId)
    })
    sessionStore.listSourceHistory().forEach((entry: SourceReadHistoryEntry): void => {
      sessionStore.removeSourceHistory(entry.comicId)
    })
    this.historyItems = []
    console.info('[History] step=clear')
  }

  private confirmClearHistory(): void {
    if (this.historyItems.length === 0) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: s('history_clear_title'),
      message: s('history_clear_message').replace('%s', `${this.historyItems.length}`),
      autoCancel: true,
      primaryButton: {
        value: s('common_clear'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearHistory()
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private todayStartMs(): number {
    const now = new Date()
    return new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  }

  private historyGroupKey(timestampMs: number | undefined): HistoryGroupKey {
    if (timestampMs === undefined || timestampMs <= 0) {
      return 'older'
    }
    const todayStart = this.todayStartMs()
    if (timestampMs >= todayStart) {
      return 'today'
    }
    if (timestampMs >= todayStart - MS_PER_DAY) {
      return 'yesterday'
    }
    if (timestampMs >= todayStart - MS_PER_WEEK) {
      return 'last_7_days'
    }
    return 'older'
  }

  private historyGroupTitle(key: HistoryGroupKey): string {
    if (key === 'today') {
      return s('history_group_today')
    }
    if (key === 'yesterday') {
      return s('history_group_yesterday')
    }
    if (key === 'last_7_days') {
      return s('history_group_last_7_days')
    }
    return s('history_group_older')
  }

  private historySections(): HistorySection[] {
    const sectionKeys: HistoryGroupKey[] = ['today', 'yesterday', 'last_7_days', 'older']
    const sections: HistorySection[] = sectionKeys.map((key: HistoryGroupKey): HistorySection => {
      return {
        key,
        title: this.historyGroupTitle(key),
        items: [],
      }
    })
    this.historyItems.forEach((item: HistoryItem) => {
      const key = this.historyGroupKey(item.lastReadAt)
      const section = sections.find((candidate: HistorySection): boolean => candidate.key === key)
      if (section !== undefined) {
        section.items.push(item)
      }
    })
    return sections.filter((section: HistorySection): boolean => section.items.length > 0)
  }

  /** ArkUI ForEach keys must change when a history row moves groups or advances within a chapter. */
  private historyItemRenderIdentity(item: HistoryItem): string {
    return JSON.stringify([
      item.id,
      item.title,
      item.coverUri ?? '',
      item.progress?.chapterId ?? '',
      item.progress?.pageIndex ?? -1,
      item.progress?.totalPages ?? 0,
      item.lastReadAt ?? 0,
      item.sourceHistory?.chapterId ?? '',
      item.sourceHistory?.chapterTitle ?? '',
    ])
  }

  private historySectionRenderIdentity(section: HistorySection): string {
    return `${section.key}:${section.items.map((item: HistoryItem): string =>
      this.historyItemRenderIdentity(item)).join('|')}`
  }

  private shouldShowCoverUri(
    coverUri: string | undefined,
    sourceRuntimeId?: string,
    sourceImageId?: string,
    sourceKind?: ComicSourceKind,
    remoteServerId?: string,
  ): boolean {
    const normalized = coverUri ?? ''
    return normalized.length > 0 && this.failedCoverUris.indexOf(
      cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId),
    ) < 0
  }

  private markCoverUriFailed(
    coverUri: string | undefined,
    sourceRuntimeId?: string,
    sourceImageId?: string,
    sourceKind?: ComicSourceKind,
    remoteServerId?: string,
  ): void {
    const normalized = coverUri ?? ''
    const failureKey = cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId)
    if (normalized.length > 0 && this.failedCoverUris.indexOf(failureKey) < 0) {
      this.failedCoverUris = this.failedCoverUris.concat([failureKey])
    }
  }

  private sourceImageIdForItem(item: HistoryItem): string {
    return item.sourceImageId ?? item.comicId
  }

  @Builder
  private EmptyHistory() {
    KomaEmptyState({
      icon: $r('sys.symbol.clock'),
      title: s('history_empty_title'),
      message: s('history_empty_message'),
      showAction: false,
    })
  }

  @Builder
  private Cover(item: HistoryItem) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldShowCoverUri(
        item.coverUri,
        item.sourceRuntimeId,
        this.sourceImageIdForItem(item),
        item.sourceKind,
        item.remoteServerId,
      )) {
        CachedCoverImage({
          uri: item.coverUri ?? '',
          objectFit: ImageFit.Cover,
          sourceRuntimeId: item.sourceRuntimeId ?? '',
          sourceImageId: this.sourceImageIdForItem(item),
            sourceKind: item.sourceKind,
            remoteServerId: item.remoteServerId ?? '',
            decodeMaxEdge: 192,
            onError: () => {
            this.markCoverUriFailed(
              item.coverUri,
              item.sourceRuntimeId,
              this.sourceImageIdForItem(item),
              item.sourceKind,
              item.remoteServerId,
            )
          },
        })
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
  private HistoryGroupHeader(section: HistorySection) {
    Row() {
      Text(section.title)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .layoutWeight(1)
      Text(s('library_count_books').replace('%s', `${section.items.length}`))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
  }

  @Builder
  private HistoryRow(item: HistoryItem) {
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
          this.confirmRemoveHistoryItem(item)
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
          this.confirmClearHistory()
        },
      })
    }
    .width('100%')
  }

  aboutToAppear(): void {
    this.reloadHistory('appear')
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
        floatingTabTailPadding: ThemeConstants.FLOATING_TAB_BAR_CLEARANCE,
      }) {
        if (this.historyItems.length === 0) {
          ListItem() {
            this.EmptyHistory()
          }
        } else {
          ListItem() {
            this.HistoryHeader()
          }
          ForEach(this.historySections(), (section: HistorySection) => {
            ListItem() {
              this.HistoryGroupHeader(section)
            }
            ForEach(section.items, (item: HistoryItem) => {
              ListItem() {
                this.HistoryRow(item)
              }
            }, (item: HistoryItem) => this.historyItemRenderIdentity(item))
          }, (section: HistorySection) => this.historySectionRenderIdentity(section))
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

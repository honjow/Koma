import { komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { common } from '@kit.AbilityKit'
import { connectLibraryPrivacyState, LibraryPrivacyState } from '../state/LibraryPrivacyState'
import { privateLibraryCategoryIds, showLibraryComic } from '../model/LibraryPrivacyVisibility'
import { CachedCoverImage, cachedCoverFailureKey, coverDecodeEdgeForDisplay } from '../components/CachedCoverImage'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { PullRefresh } from '../components/PullRefresh'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { connectRemoteProgressSyncState, RemoteProgressSyncState } from '../state/RemoteProgressSyncState'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  ComicId,
  ComicSourceKind,
  comicToLibraryItem,
  LibraryItem,
  ReadingProgress,
} from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { createSeededLibraryStore } from '../model/MockLibraryData'
import {
  appReaderSessionStore,
  ReadingPresentationChange,
  ReaderSessionStore,
} from '../model/ReaderSessionStore'
import {
  SourceReadHistoryEntry,
  SourceReaderSessionRequest,
  sourceReaderSessionRequestFromHistory,
} from '../model/SourceReaderSession'
import { AppStrings } from '../i18n/AppStrings'
import { RemoteReadHistoryEntry } from '../model/RemoteReaderSession'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { RootNavigationState } from '../state/RootNavigationState'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'

const HISTORY_LIMIT: number = 50
const MS_PER_MINUTE: number = 60 * 1000
const MS_PER_HOUR: number = 60 * MS_PER_MINUTE
const MS_PER_DAY: number = 24 * MS_PER_HOUR
const MS_PER_WEEK: number = 7 * MS_PER_DAY
const MS_PER_MONTH: number = 30 * MS_PER_DAY
const MS_PER_YEAR: number = 365 * MS_PER_DAY

const HISTORY_COVER_HEIGHT = 88

function s(name: string): string {
  return AppStrings.get(name)
}

type HistoryGroupKey = 'today' | 'yesterday' | 'last_7_days' | 'older'

interface HistorySection {
  key: HistoryGroupKey
  title: string
  items: HistoryItem[]
}

@ObservedV2
class HistoryListRow {
  readonly key: string
  @Trace section?: HistorySection = undefined
  @Trace item?: HistoryItem = undefined

  constructor(key: string) {
    this.key = key
  }
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
  sourceName: string
  sourceImageId?: string
  sourceMangaUrl?: string
  sourceKind?: ComicSourceKind
  remoteServerId?: string
  chapterCount: number
  pageCount: number
  lastReadAt?: number
  progress?: ReadingProgress
  sourceHistory?: SourceReadHistoryEntry
  remoteHistory?: RemoteReadHistoryEntry
}

@ComponentV2
export struct HistoryPage {
  @Param scroller: Scroller = new Scroller()
  @Event onRootScroll: (offset: number, state: ScrollState) => void = (_offset: number, _state: ScrollState) => {}
  @Param libraryStore: LibraryStore = createSeededLibraryStore()
  @Param libraryRevision: number = 0
  @Param active: boolean = false
  @Param rootNavigation: RootNavigationState = new RootNavigationState()
  @Param readerSessionStore?: ReaderSessionStore = undefined
  @Param readerProgressRevision: number = 0
  @Param readingPresentationChange?: ReadingPresentationChange = undefined
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private remoteProgress: RemoteProgressSyncState = connectRemoteProgressSyncState()
  @Local private scrollEnabled: boolean = true
  private historyItems: HistoryItem[] = []
  @Local private historyRows: HistoryListRow[] = []
  private presentedReadingRevision: number = -1
  private presentedLibraryRevision: number = -1
  @Local private privacy: LibraryPrivacyState = connectLibraryPrivacyState()
  @Local private failedCoverUris: string[] = []
  @Event onOpenDetail: (comicId: ComicId, source?: SourceReadHistoryEntry, remote?: RemoteReadHistoryEntry) => void = () => {}
  @Event onOpenReader: (comicId: ComicId, chapterId?: string) => void = (_comicId: ComicId, _chapterId?: string) => {}
  @Event onOpenSourceReader: (request: SourceReaderSessionRequest) => void = (_request: SourceReaderSessionRequest) => {}
  @Event onOpenRemoteReader: (entry: RemoteReadHistoryEntry) => void = () => {}
  @Event onReadingStateChanged: (comicIds: string[]) => void = () => {}
  @Event onRefresh: () => Promise<void> = async () => {}

  @Monitor('active', 'rootNavigation.visible')
  private onActiveChanged(): void {
    if (this.active && this.rootNavigation.visible) {
      if (this.presentedLibraryRevision === this.libraryRevision) {
        this.onReaderProgressRevisionChanged()
        this.publishHistoryRows()
      } else this.reloadHistory('tab_active')
    }
  }

  @Monitor('remoteProgress.syncRevision')
  private onRemoteProgressSyncRevChanged(): void {
    if (!this.active || !this.rootNavigation.visible) return
    void this.remoteProgress.syncRevision
    this.reloadHistory('bootstrap_sync')
  }

  @Monitor('readerProgressRevision')
  private onReaderProgressRevisionChanged(): void {
    if (!this.active || !this.rootNavigation.visible || this.presentedReadingRevision === this.readerProgressRevision) return
    const change = this.readingPresentationChange
    if (change?.revision === this.readerProgressRevision && this.presentedReadingRevision + 1 === change.revision &&
      this.presentedLibraryRevision === this.libraryRevision) {
      this.applyReadingChanges(change.comicIds)
      this.presentedReadingRevision = this.readerProgressRevision
    } else this.reloadHistory('reader_progress')
  }

  @Monitor('libraryRevision', 'privacy.categoryId', 'privacy.unlocked')
  private onVisibilityChanged(): void {
    if (this.active && this.rootNavigation.visible) this.reloadHistory('visibility_changed')
  }

  @Computed
  private get privateCategoryIds(): Set<string> {
    void this.libraryRevision
    return privateLibraryCategoryIds(this.libraryStore.listCustomCategories())
  }

  private canShowHistory(comicId: ComicId, visibleCategoryId: string): boolean {
    return showLibraryComic(this.libraryStore.getComicSummary(comicId), this.privateCategoryIds, visibleCategoryId)
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
      return appReaderSessionStore(context.filesDir)
    } catch (error) {
      void error
      console.info('[History] step=session_store_unavailable reason=context')
      return undefined
    }
  }

  private reloadHistory(reason: string): void {
    this.presentedReadingRevision = this.readerProgressRevision
    this.presentedLibraryRevision = this.libraryRevision
    console.info(`[History] step=load_start reason=${reason}`)
    const sessionStore = this.createReaderSessionStore()
    const sourceEntries = sessionStore?.listSourceHistory() ?? []
    const sourceByComic = new Map<ComicId, SourceReadHistoryEntry>()
    sourceEntries.forEach((entry: SourceReadHistoryEntry): void => { sourceByComic.set(entry.comicId, entry) })
    const progressByComicId: Map<ComicId, ReadingProgress> = new Map<ComicId, ReadingProgress>()
    if (sessionStore !== undefined) {
      sessionStore.listProgress().forEach((progress: ReadingProgress): void => {
        progressByComicId.set(progress.comicId, progress)
      })
    }
    const libraryItems: HistoryItem[] = this.libraryStore.listReadLibraryItems(progressByComicId)
      .map((item: LibraryItem): HistoryItem => this.libraryHistoryItem(item, sourceByComic.get(item.comicId)))
    const libraryComicIds: Set<ComicId> = new Set<ComicId>()
    libraryItems.forEach((item: HistoryItem): void => {
      libraryComicIds.add(item.comicId)
    })
    const sourceItems: HistoryItem[] = []
    const remoteItems: HistoryItem[] = []
    if (sessionStore !== undefined) {
      sourceEntries.forEach((entry: SourceReadHistoryEntry): void => {
        const progress = progressByComicId.get(entry.comicId)
        if (!libraryComicIds.has(entry.comicId) && progress !== undefined) {
          sourceItems.push(this.sourceHistoryItem(sessionStore.getSourceHistoryForResume(entry.comicId) ?? entry, progress))
        }
      })
      sessionStore.listRemoteHistory().forEach((entry: RemoteReadHistoryEntry): void => {
        const progress = progressByComicId.get(entry.comicId)
        if (!libraryComicIds.has(entry.comicId) && progress !== undefined && progress.chapterId === entry.chapterId) {
          remoteItems.push(this.remoteHistoryItem(entry, progress))
        }
      })
    }
    this.publishHistoryItems(libraryItems.concat(sourceItems, remoteItems)
      .filter((item: HistoryItem): boolean => this.canShowHistory(item.comicId, this.privacy.visibleCategoryId))
      .sort((a: HistoryItem, b: HistoryItem): number => {
        return (b.lastReadAt ?? 0) - (a.lastReadAt ?? 0)
      })
      .slice(0, HISTORY_LIMIT))
    console.info(`[History] step=load_done count=${this.historyItems.length}`)
  }

  private applyReadingChanges(comicIds: ComicId[]): void {
    const store = this.createReaderSessionStore()
    if (store === undefined || comicIds.length === 0) return
    const changed = new Set(comicIds)
    const next = this.historyItems.filter((item: HistoryItem): boolean => !changed.has(item.comicId))
    for (const id of changed) {
      const updated = this.historyItemsForWork(store, id)
      const old = this.historyItems.find((item: HistoryItem): boolean => item.comicId === id)
      // A shortened capped list may need rows outside its current window.
      if (old !== undefined && this.historyItems.length === HISTORY_LIMIT &&
        (updated.length !== this.historyItems.filter((item: HistoryItem): boolean => item.comicId === id).length ||
          updated.some((item: HistoryItem): boolean => (item.lastReadAt ?? 0) < (old.lastReadAt ?? 0)))) {
        this.reloadHistory('history_window_changed')
        return
      }
      // Preserve the original library/source/remote tie order on exact dates.
      if (updated.some((item: HistoryItem): boolean => next.some((row: HistoryItem): boolean => row.lastReadAt === item.lastReadAt))) {
        this.reloadHistory('history_date_tie')
        return
      }
      next.push(...updated)
    }
    this.publishHistoryItems(next.sort((a: HistoryItem, b: HistoryItem): number =>
      (b.lastReadAt ?? 0) - (a.lastReadAt ?? 0)).slice(0, HISTORY_LIMIT))
  }

  private historyItemsForWork(store: ReaderSessionStore, id: ComicId): HistoryItem[] {
    const progress = store.getProgress(id)
    if (progress === undefined || !this.canShowHistory(id, this.privacy.visibleCategoryId)) return []
    const comic = this.libraryStore.getComicSummary(id)
    const history = store.getSourceHistory(id)
    if (comic !== undefined) return [this.libraryHistoryItem(comicToLibraryItem(comic, progress), history)]
    const rows: HistoryItem[] = []
    if (history !== undefined) rows.push(this.sourceHistoryItem(store.getSourceHistoryForResume(id) ?? history, progress))
    const remote = store.getRemoteHistory(id)
    if (remote?.chapterId === progress.chapterId) rows.push(this.remoteHistoryItem(remote, progress))
    return rows
  }

  private remoteHistoryItem(entry: RemoteReadHistoryEntry, progress: ReadingProgress): HistoryItem {
    return { id: `remote-history:${entry.comicId}`, comicId: entry.comicId,
      title: entry.title, sourceName: '', remoteServerId: entry.serverId, chapterCount: 1,
      pageCount: progress.totalPages, lastReadAt: progress.updatedAt, progress, remoteHistory: entry }
  }

  private historySourceName(sourceId?: string, savedName?: string, historyName?: string): string {
    if (!sourceId) return ''
    const name = savedName?.trim() ?? ''
    const fallback = historyName?.trim() ?? ''
    return sourceDisplayName(sourceId, name && name !== sourceId ? name : fallback === sourceId ? '' : fallback)
  }

  private libraryHistoryItem(item: LibraryItem, history?: SourceReadHistoryEntry): HistoryItem {
    return {
      id: item.id,
      comicId: item.comicId,
      title: item.title,
      coverUri: item.coverUri || history?.coverUri,
      sourceRuntimeId: item.sourceRuntimeId,
      sourceName: this.historySourceName(item.sourceRuntimeId,
        this.libraryStore.getComicSummary(item.comicId)?.sourceMetadata?.sourceName,
        history?.sourceId === item.sourceRuntimeId ? history?.sourceName : undefined),
      sourceMangaUrl: item.sourcePath,
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
      sourceName: this.historySourceName(entry.sourceId, entry.sourceName),
      sourceMangaUrl: entry.mangaUrl,
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
    const sourceChapterTitle = (item.sourceHistory?.chapterTitle ?? item.remoteHistory?.chapterTitle)?.trim()
    if (sourceChapterTitle !== undefined && sourceChapterTitle.length > 0) {
      return sourceChapterTitle
    }
    if (item.sourceHistory !== undefined || item.remoteHistory !== undefined) {
      return s('history_chapter_read')
    }
    const chapterTitle = this.libraryStore.readComicChapterTitle(item.comicId, item.progress.chapterId)?.trim()
    if (chapterTitle !== undefined && chapterTitle.length > 0) {
      return chapterTitle
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
    const total = item.progress.totalPages > 0 ? item.progress.totalPages : item.sourceHistory !== undefined ? 0 : item.pageCount
    // A migrated position knows the corresponding chapter before the new
    // edition's images are loaded. Do not present that unknown size as "1 / 0".
    if (total <= 0) return this.chapterText(item)
    return s('history_page_progress')
      .replace('%s', `${page}`)
      .replace('%s', `${total}`)
      .replace('%s', this.chapterText(item))
  }

  private openHistoryItem(item: HistoryItem): void {
    if (!this.canShowHistory(item.comicId, this.privacy.visibleCategoryId)) return
    const chapterId = item.progress === undefined ? undefined : item.progress.chapterId
    console.info(`[History] step=open_resume comic=${item.comicId} chapter=${chapterId ?? ''} page=${item.progress?.pageIndex ?? 0}`)
    if (item.remoteHistory !== undefined) {
      this.onOpenRemoteReader(item.remoteHistory)
      return
    }
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
    if (!this.canShowHistory(item.comicId, this.privacy.visibleCategoryId)) return
    const sessionStore = this.createReaderSessionStore()
    if (sessionStore === undefined) {
      return
    }
    if (!sessionStore.removeHistoryEntries([item.comicId])) {
      this.showHistorySaveFailed()
      return
    }
    this.publishHistoryItems(this.historyItems.filter((historyItem: HistoryItem): boolean => {
      return historyItem.comicId !== item.comicId
    }))
    this.onReadingStateChanged([item.comicId])
    console.info('[History] step=remove_item')
  }

  private confirmRemoveHistoryItem(item: HistoryItem): void {
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('history_remove_title'),
      message: s('history_remove_message').replace('%s', item.title),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_remove'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.removeHistoryItem(item)
        },
      },
    })
  }

  private clearHistory(): void {
    const sessionStore = this.createReaderSessionStore()
    if (sessionStore === undefined) {
      return
    }
    const comicIds = sessionStore.listProgress().map((progress: ReadingProgress): ComicId => progress.comicId)
      .concat(sessionStore.listSourceHistory().map((entry: SourceReadHistoryEntry): ComicId => entry.comicId),
        sessionStore.listRemoteHistory().map((entry: RemoteReadHistoryEntry): ComicId => entry.comicId),
        sessionStore.listReadingSessions().map((entry): ComicId => entry.comicId))
      .filter((id: ComicId): boolean => this.canShowHistory(id, ''))
    if (!sessionStore.removeHistoryEntries(comicIds, true)) {
      this.showHistorySaveFailed()
      return
    }
    this.reloadHistory('clear_public')
    this.onReadingStateChanged(comicIds)
    console.info('[History] step=clear')
  }

  private showHistorySaveFailed(): void {
    try {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: s('reader_progress_save_failed') }))
    } catch (_error) {
    }
    DiagnosticLogger.warn('history_page', 'remove_failed', '[History] step=remove_failed reason=persistence')
  }

  private confirmClearHistory(): void {
    const publicCount = this.historyItems.filter((item: HistoryItem): boolean => this.canShowHistory(item.comicId, '')).length
    if (publicCount === 0) {
      return
    }
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('history_clear_title'),
      message: s('history_clear_message').replace('%s', `${publicCount}`),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('common_clear'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          this.clearHistory()
        },
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
      if (!this.canShowHistory(item.comicId, this.privacy.visibleCategoryId)) return
      const key = this.historyGroupKey(item.lastReadAt)
      const section = sections.find((candidate: HistorySection): boolean => candidate.key === key)
      if (section !== undefined) {
        section.items.push(item)
      }
    })
    return sections.filter((section: HistorySection): boolean => section.items.length > 0)
  }

  private publishHistoryItems(items: HistoryItem[]): void {
    this.historyItems = items
    this.publishHistoryRows()
  }

  @Monitor('languageState.effectiveLocale')
  private publishHistoryRows(): void {
    const existing = new Map<string, HistoryListRow>()
    for (const row of this.historyRows) existing.set(row.key, row)
    const rows: HistoryListRow[] = []
    this.historySections().forEach((section: HistorySection): void => {
      const key = `group:${section.key}`
      const header = existing.get(key) ?? new HistoryListRow(key)
      if (header.section?.title !== section.title || header.section.items.length !== section.items.length) {
        header.section = section
      }
      rows.push(header)
      section.items.forEach((item: HistoryItem): void => {
        const key = `item:${item.id}`
        const row = existing.get(key) ?? new HistoryListRow(key)
        if (row.item !== item) row.item = item
        rows.push(row)
      })
    })
    // Repeat observes row fields independently. Change list slots only when
    // records really move or date headers enter or leave the list.
    let start = 0
    while (start < this.historyRows.length && start < rows.length && this.historyRows[start] === rows[start]) start++
    let oldEnd = this.historyRows.length
    let newEnd = rows.length
    while (oldEnd > start && newEnd > start && this.historyRows[oldEnd - 1] === rows[newEnd - 1]) {
      oldEnd--
      newEnd--
    }
    if (oldEnd > start || newEnd > start) this.historyRows.splice(start, oldEnd - start, ...rows.slice(start, newEnd))
  }

  private shouldShowCoverUri(
    coverUri: string | undefined,
    sourceRuntimeId?: string,
    sourceImageId?: string,
    sourceKind?: ComicSourceKind,
    remoteServerId?: string,
    sourceMangaUrl?: string,
  ): boolean {
    const normalized = coverUri ?? ''
    return normalized.length > 0 && this.failedCoverUris.indexOf(
      cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl),
    ) < 0
  }

  private markCoverUriFailed(
    coverUri: string | undefined,
    sourceRuntimeId?: string,
    sourceImageId?: string,
    sourceKind?: ComicSourceKind,
    remoteServerId?: string,
    sourceMangaUrl?: string,
  ): void {
    const normalized = coverUri ?? ''
    const failureKey = cachedCoverFailureKey(coverUri, sourceRuntimeId, sourceImageId, sourceKind, remoteServerId, sourceMangaUrl)
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
  private Cover(row: RepeatItem<HistoryListRow>) {
    Stack({ alignContent: Alignment.Center }) {
      if (this.shouldShowCoverUri(
        row.item.item!.coverUri,
        row.item.item!.sourceRuntimeId,
        this.sourceImageIdForItem(row.item.item!),
        row.item.item!.sourceKind,
        row.item.item!.remoteServerId,
        row.item.item!.sourceMangaUrl,
      )) {
        CachedCoverImage({
          uri: row.item.item!.coverUri ?? '',
          objectFit: ImageFit.Cover,
          sourceRuntimeId: row.item.item!.sourceRuntimeId ?? '',
          sourceImageId: this.sourceImageIdForItem(row.item.item!),
          sourceKind: row.item.item!.sourceKind,
          remoteServerId: row.item.item!.remoteServerId ?? '',
          sourceMangaUrl: row.item.item!.sourceMangaUrl ?? '',
          decodeMaxEdge: coverDecodeEdgeForDisplay(HISTORY_COVER_HEIGHT, 192),
          onError: () => {
            const item = row.item.item!
            this.markCoverUriFailed(
              item.coverUri,
              item.sourceRuntimeId,
              this.sourceImageIdForItem(item),
              item.sourceKind,
              item.remoteServerId,
              item.sourceMangaUrl,
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
    .height(HISTORY_COVER_HEIGHT)
    .borderRadius(ThemeConstants.RADIUS_CARD - ThemeConstants.SPACE_MD)
    .clip(true)
    .backgroundColor(this.coverColor(row.item.item!))
  }

  @Builder
  private HistoryGroupHeader(row: RepeatItem<HistoryListRow>) {
    Row() {
      Text(row.item.section!.title)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .layoutWeight(1)
      Text(s('library_count_books').replace('%s', `${row.item.section!.items.length}`))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS })
  }

  @Builder
  private HistoryMetadata(row: RepeatItem<HistoryListRow>) {
    // Let a long source name shrink first so the existing time stays on this line.
    Row() {
      if (row.item.item!.sourceName.length > 0) {
        Text(row.item.item!.sourceName)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .flexShrink(1)
      }
      if ((row.item.item!.lastReadAt ?? 0) > 0) {
        Text((row.item.item!.sourceName.length > 0 ? ' · ' : '') + this.relativeTime(row.item.item!.lastReadAt))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .flexShrink(0)
      }
    }
    .layoutWeight(1)
  }

  @Builder
  private HistoryRow(row: RepeatItem<HistoryListRow>) {
    Row({ space: ThemeConstants.SPACE_LG }) {
      Row() {
        this.Cover(row)
      }
        .id(`history-cover-${row.item.item!.comicId}`)
        .onClick(() => {
          const item = row.item.item!
          this.onOpenDetail(item.comicId, item.sourceHistory, item.remoteHistory)
        })

      Column({ space: ThemeConstants.SPACE_SM }) {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Text(row.item.item!.title)
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .width('100%')

          Text(this.progressText(row.item.item!))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .width('100%')

          Progress({
            value: Math.round((row.item.item!.progress?.progressRatio ?? 0) * 100),
            total: 100,
            type: ProgressType.Linear,
          })
            .height(4)
            .color(ThemeConstants.BRAND_PRIMARY)
            .backgroundColor(ThemeConstants.SOFT_TINT)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row() {
          this.HistoryMetadata(row)
          KomaIconButton({
            icon: $r('sys.symbol.trash'),
            controlSize: 24,
            iconSize: ThemeConstants.FONT_SIZE_HEADING,
            kind: 'ghost',
            accentColor: ThemeConstants.TEXT_SECONDARY,
            action: () => {
              this.confirmRemoveHistoryItem(row.item.item!)
            },
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: ThemeConstants.SPACE_MD,
      right: ThemeConstants.SPACE_MD,
      top: ThemeConstants.SPACE_MD,
      bottom: ThemeConstants.SPACE_MD,
    })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.openHistoryItem(row.item.item!) })
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

  @Builder
  private HistoryList() {
    SecondaryListScaffold({
      scroller: this.scroller,
      onDidScroll: this.onRootScroll,
      scrollEnabled: this.scrollEnabled,
      alwaysEnableEdgeSpring: false,
      listSpace: ThemeConstants.SPACE_MD,
      bottomPadding: ThemeConstants.SPACE_XL,
      floatingTabTailPadding: ThemeConstants.FLOATING_TAB_BAR_CLEARANCE,
    }) {
      if (this.historyRows.length === 0) {
        ListItem() {
          this.EmptyHistory()
        }
      } else {
        ListItem() {
          this.HistoryHeader()
        }
        // Keep date headers and records at the same List level so one changed
        // record can move between dates without remounting its entire group.
        Repeat<HistoryListRow>(this.historyRows)
          .each((row: RepeatItem<HistoryListRow>) => {
            ListItem() {
              if (row.item.section !== undefined) {
                this.HistoryGroupHeader(row)
              } else {
                this.HistoryRow(row)
              }
            }
          })
          .key((row: HistoryListRow): string => row.key)
          .virtualScroll()
      }
    }
  }

  build() {
    Column() {
      PullRefresh({
        scroller: this.scroller,
        indicatorTop: this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT / 2,
        onRefresh: async (): Promise<void> => {
          try {
            await this.onRefresh()
          } finally {
            this.reloadHistory('pull_refresh')
          }
        },
        onScrollEnableChange: (enabled: boolean): void => { this.scrollEnabled = enabled },
      }) {
        this.HistoryList()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

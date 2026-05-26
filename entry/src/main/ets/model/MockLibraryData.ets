import {
  Chapter,
  Comic,
  ComicId,
  ComicSourceKind,
  LIBRARY_CATEGORY_FAVORITE_ID,
  LIBRARY_CATEGORY_READ_LATER_ID,
  Page,
  ReadingDirection,
  ReadingProgress,
  normalizeCategoryIds,
  normalizeSortKey,
} from './ComicModels'
import { InMemoryLibraryStore, LibraryStore } from './LibraryStore'
import { ReaderSessionConfig, ReaderSessionStore } from './ReaderSessionStore'

export interface MockLibraryComic {
  id: ComicId
  title: string
  subtitle: string
  chapterTitle: string
  fallbackProgressText: string
  coverColor: string
  accentColor: string
  chapterCount?: number
  pageCount?: number
  readerSession?: ReaderSessionConfig
}

export interface LibraryComicCardViewModel {
  id: ComicId
  title: string
  subtitle: string
  progressText: string
  coverColor: string
  accentColor: string
  pageCount: number
  coverUri?: string
  categoryLabels: string[]
}

export interface ContinueReadingCardViewModel {
  title: string
  detail: string
  progress: number
  color: string
  comicId: ComicId
  coverUri?: string
}

export interface LibraryViewModel {
  comics: LibraryComicCardViewModel[]
  continueReading: ContinueReadingCardViewModel
}

export interface LibraryComicPresentation {
  subtitle?: string
  chapterTitle?: string
  fallbackProgressText: string
  coverColor: string
  accentColor: string
}

export type LibraryPresentationByComicId = Map<ComicId, LibraryComicPresentation>

export const MOCK_LIBRARY_READER_SESSION: ReaderSessionConfig = {
  comicId: 'local-01',
  chapterId: 'chapter-8',
  totalPages: 5,
  pageUris: [
    'mock://local-01/001.jpg',
    'mock://local-01/002.jpg',
    'mock://local-01/003.jpg',
    'mock://local-01/004.jpg',
    'mock://local-01/005.jpg',
  ],
  pageIds: [
    'chapter-8-page-1',
    'chapter-8-page-2',
    'chapter-8-page-3',
    'chapter-8-page-4',
    'chapter-8-page-5',
  ],
}

export const MOCK_LIBRARY_COMICS: MockLibraryComic[] = [
  {
    id: 'local-01',
    title: '雨后街区',
    subtitle: '本地 ZIP - 12 章',
    chapterTitle: '第 8 话',
    fallbackProgressText: '第 8 话',
    coverColor: '#16745F',
    accentColor: '#2FAE84',
    readerSession: MOCK_LIBRARY_READER_SESSION,
  },
  {
    id: 'local-02',
    title: '北窗短篇集',
    subtitle: '图片文件夹 - 6 章',
    chapterTitle: '第 1 话',
    fallbackProgressText: '未读',
    coverColor: '#344E7A',
    accentColor: '#6E92CE',
  },
  {
    id: 'local-03',
    title: '海边的慢速列车',
    subtitle: 'CBZ - 4 章',
    chapterTitle: '第 2 话',
    fallbackProgressText: '42%',
    coverColor: '#8A6240',
    accentColor: '#D39A62',
  },
  {
    id: 'local-04',
    title: '午后三点的笔记',
    subtitle: '本地 ZIP - 18 章',
    chapterTitle: '第 3 话',
    fallbackProgressText: '第 3 话',
    coverColor: '#7A405D',
    accentColor: '#C46B92',
  },
  {
    id: 'local-05',
    title: '旧书店巡礼',
    subtitle: '图片文件夹 - 9 章',
    chapterTitle: '第 1 话',
    fallbackProgressText: '新加入',
    coverColor: '#51624D',
    accentColor: '#89A57D',
  },
  {
    id: 'local-06',
    title: '银河便签',
    subtitle: 'CBZ - 21 章',
    chapterTitle: '第 15 话',
    fallbackProgressText: '第 15 话',
    coverColor: '#4C4A70',
    accentColor: '#928FD2',
  },
]

const FALLBACK_COVER_COLORS: string[] = [
  '#16745F',
  '#344E7A',
  '#7A405D',
  '#51624D',
  '#4C4A70',
  '#8A6240',
]

const FALLBACK_ACCENT_COLORS: string[] = [
  '#2FAE84',
  '#6E92CE',
  '#C46B92',
  '#89A57D',
  '#928FD2',
  '#D39A62',
]

function hashComicId(comicId: ComicId): number {
  let hash = 2166136261
  for (let index = 0; index < comicId.length; index += 1) {
    hash = (hash ^ comicId.charCodeAt(index)) >>> 0
    hash = Math.imul(hash, 16777619) >>> 0
  }
  return hash
}

function createMockPages(comic: MockLibraryComic, chapterId: string, pageCount: number): Page[] {
  const pages: Page[] = []
  for (let index = 0; index < pageCount; index += 1) {
    const pageNumber = index + 1
    const fileName = `${pageNumber.toString().padStart(3, '0')}.jpg`
    pages.push({
      id: `${chapterId}-page-${pageNumber}`,
      comicId: comic.id,
      chapterId,
      index,
      fileName,
      uri: `mock://${comic.id}/${fileName}`,
      sortKey: normalizeSortKey(fileName),
    })
  }
  return pages
}

export function createMockComic(comic: MockLibraryComic, now: number = 1): Comic {
  const chapterId = comic.readerSession === undefined ? `${comic.id}-chapter-1` : comic.readerSession.chapterId
  const pageCount = comic.pageCount === undefined ? (comic.readerSession === undefined ? 1 : comic.readerSession.totalPages) : comic.pageCount
  const pages = createMockPages(comic, chapterId, pageCount)
  const chapter: Chapter = {
    id: chapterId,
    comicId: comic.id,
    title: comic.chapterTitle,
    index: 0,
    sourcePath: `mock://${comic.id}`,
    sortKey: normalizeSortKey(comic.chapterTitle),
    pages,
    pageCount,
    createdAt: now,
    updatedAt: now,
  }
  return {
    id: comic.id,
    title: comic.title,
    subtitle: comic.subtitle,
    sourceKind: ComicSourceKind.LOCAL_ARCHIVE,
    sourcePath: `mock://${comic.id}`,
    coverUri: pages.length === 0 ? undefined : pages[0].uri,
    sortTitle: normalizeSortKey(comic.title),
    preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters: [chapter],
    chapterCount: comic.chapterCount === undefined ? 1 : comic.chapterCount,
    pageCount,
    createdAt: now,
    updatedAt: now,
    lastImportedAt: now,
  }
}

export function createMockLibraryPresentationMap(seed: MockLibraryComic[] = MOCK_LIBRARY_COMICS): LibraryPresentationByComicId {
  const presentationByComicId: LibraryPresentationByComicId = new Map<ComicId, LibraryComicPresentation>()
  seed.forEach((comic: MockLibraryComic) => {
    presentationByComicId.set(comic.id, {
      subtitle: comic.subtitle,
      chapterTitle: comic.chapterTitle,
      fallbackProgressText: comic.fallbackProgressText,
      coverColor: comic.coverColor,
      accentColor: comic.accentColor,
    })
  })
  return presentationByComicId
}

// Empty by default — production ships with no demo rows.
// Pass MOCK_LIBRARY_COMICS explicitly when seeding mock data for tests / dev fixtures.
export function createSeededLibraryStore(seed: MockLibraryComic[] = []): LibraryStore {
  const store = new InMemoryLibraryStore()
  seed.forEach((comic: MockLibraryComic, index: number) => {
    store.upsertComic(createMockComic(comic, index + 1))
  })
  return store
}

export function progressPercent(progress?: ReadingProgress): number {
  if (progress === undefined) {
    return 0
  }
  return Math.round(progress.progressRatio * 100)
}

export function formatLibraryProgressText(comic: MockLibraryComic, progress?: ReadingProgress): string {
  if (progress === undefined) {
    return comic.fallbackProgressText
  }
  if (progress.completed) {
    return '已读完'
  }
  return `${progressPercent(progress)}%`
}

export function formatContinueReadingDetail(comic: MockLibraryComic, progress?: ReadingProgress): string {
  if (progress === undefined) {
    return `继续阅读 ${comic.chapterTitle}`
  }
  return `继续阅读 ${comic.chapterTitle} / 第 ${progress.pageIndex + 1} 页 · ${progressPercent(progress)}%`
}

function formatSourceSubtitle(comic: Comic): string {
  if (comic.subtitle !== undefined && comic.subtitle.length > 0) {
    return comic.subtitle
  }
  if (comic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
    return `图片文件夹 - ${comic.chapterCount} 章`
  }
  if (comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY) {
    return `私有库 - ${comic.chapterCount} 章`
  }
  return `本地 ZIP - ${comic.chapterCount} 章`
}

function createFallbackPresentation(comic: Comic): LibraryComicPresentation {
  const colorIndex = hashComicId(comic.id) % FALLBACK_COVER_COLORS.length
  return {
    subtitle: formatSourceSubtitle(comic),
    chapterTitle: comic.chapters.length === 0 ? comic.title : comic.chapters[0].title,
    fallbackProgressText: '未读',
    coverColor: FALLBACK_COVER_COLORS[colorIndex],
    accentColor: FALLBACK_ACCENT_COLORS[colorIndex],
  }
}

function getProgressChapterTitle(comic: Comic, presentation: LibraryComicPresentation, progress?: ReadingProgress): string {
  if (progress !== undefined) {
    const chapter = comic.chapters.find((item: Chapter) => item.id === progress.chapterId)
    if (chapter !== undefined) {
      return chapter.title
    }
  }
  if (presentation.chapterTitle !== undefined) {
    return presentation.chapterTitle
  }
  return comic.chapters.length === 0 ? comic.title : comic.chapters[0].title
}

function formatProgressText(fallbackProgressText: string, progress?: ReadingProgress): string {
  if (progress === undefined) {
    return fallbackProgressText
  }
  if (progress.completed) {
    return '已读完'
  }
  return `${progressPercent(progress)}%`
}

function formatCategoryLabels(categoryIds?: string[]): string[] {
  const labels: string[] = []
  normalizeCategoryIds(categoryIds).forEach((categoryId: string) => {
    if (categoryId === LIBRARY_CATEGORY_FAVORITE_ID) {
      labels.push('收藏')
    } else if (categoryId === LIBRARY_CATEGORY_READ_LATER_ID) {
      labels.push('稍后阅读')
    }
  })
  return labels
}

function formatContinueDetail(chapterTitle: string, progress?: ReadingProgress): string {
  if (progress === undefined) {
    return `继续阅读 ${chapterTitle}`
  }
  return `继续阅读 ${chapterTitle} / 第 ${progress.pageIndex + 1} 页 · ${progressPercent(progress)}%`
}

export function createLibraryViewModelFromComics(
  comics: Comic[],
  sessionStore?: ReaderSessionStore,
  presentationByComicId: LibraryPresentationByComicId = new Map<ComicId, LibraryComicPresentation>()
): LibraryViewModel {
  const cards = comics.map((comic: Comic): LibraryComicCardViewModel => {
    const progress = sessionStore === undefined ? undefined : sessionStore.getProgress(comic.id)
    const presentation = presentationByComicId.get(comic.id) ?? createFallbackPresentation(comic)
    return {
      id: comic.id,
      title: comic.title,
      subtitle: presentation.subtitle ?? formatSourceSubtitle(comic),
      progressText: formatProgressText(presentation.fallbackProgressText, progress),
      coverColor: presentation.coverColor,
      accentColor: presentation.accentColor,
      pageCount: comic.pageCount,
      coverUri: comic.coverUri,
      categoryLabels: formatCategoryLabels(comic.categoryIds),
    }
  })

  let continueComic = comics.length === 0 ? undefined : comics[0]
  let continueProgress: ReadingProgress | undefined = undefined
  comics.forEach((comic: Comic) => {
    const progress = sessionStore === undefined ? undefined : sessionStore.getProgress(comic.id)
    if (progress !== undefined && (continueProgress === undefined || progress.updatedAt > continueProgress.updatedAt)) {
      continueComic = comic
      continueProgress = progress
    }
  })

  if (continueComic === undefined) {
    return {
      comics: cards,
      continueReading: {
        comicId: '',
        title: '',
        detail: '',
        progress: 0,
        color: '#16745F',
      },
    }
  }

  const continuePresentation = presentationByComicId.get(continueComic.id) ?? createFallbackPresentation(continueComic)
  const chapterTitle = getProgressChapterTitle(continueComic, continuePresentation, continueProgress)
  return {
    comics: cards,
    continueReading: {
      title: continueComic.title,
      detail: formatContinueDetail(chapterTitle, continueProgress),
      progress: continueProgress === undefined ? 0 : progressPercent(continueProgress),
      color: continuePresentation.coverColor,
      comicId: continueComic.id,
      coverUri: continueComic.coverUri,
    },
  }
}

export function createLibraryViewModelFromStores(
  libraryStore: LibraryStore,
  sessionStore?: ReaderSessionStore,
  presentationByComicId: LibraryPresentationByComicId = new Map<ComicId, LibraryComicPresentation>()
): LibraryViewModel {
  return createLibraryViewModelFromComics(libraryStore.listComics(), sessionStore, presentationByComicId)
}

export function createLibraryViewModel(sessionStore?: ReaderSessionStore): LibraryViewModel {
  return createLibraryViewModelFromStores(
    createSeededLibraryStore(),
    sessionStore,
    createMockLibraryPresentationMap()
  )
}

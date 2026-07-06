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
import { AppStrings } from '../i18n/AppStrings'

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
  sourceRuntimeId?: string
  sourceImageId?: string
  categoryLabels: string[]
}

export interface ContinueReadingCardViewModel {
  title: string
  detail: string
  progress: number
  color: string
  comicId: ComicId
  coverUri?: string
  sourceRuntimeId?: string
  sourceImageId?: string
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
  chapterIds: ['chapter-8'],
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
  pageWidths: [],
  pageHeights: [],
}

export const MOCK_LIBRARY_COMICS: MockLibraryComic[] = [
  {
    id: 'local-01',
    title: 'Rain After Town',
    subtitle: 'Local ZIP - 12 chapters',
    chapterTitle: 'Chapter 8',
    fallbackProgressText: 'Chapter 8',
    coverColor: '#16745F',
    accentColor: '#2FAE84',
    readerSession: MOCK_LIBRARY_READER_SESSION,
  },
  {
    id: 'local-02',
    title: 'North Window Shorts',
    subtitle: 'Image folder - 6 chapters',
    chapterTitle: 'Chapter 1',
    fallbackProgressText: 'Unread',
    coverColor: '#344E7A',
    accentColor: '#6E92CE',
  },
  {
    id: 'local-03',
    title: 'Seaside Slow Train',
    subtitle: 'CBZ - 4 chapters',
    chapterTitle: 'Chapter 2',
    fallbackProgressText: '42%',
    coverColor: '#8A6240',
    accentColor: '#D39A62',
  },
  {
    id: 'local-04',
    title: 'Three PM Notes',
    subtitle: 'Local ZIP - 18 chapters',
    chapterTitle: 'Chapter 3',
    fallbackProgressText: 'Chapter 3',
    coverColor: '#7A405D',
    accentColor: '#C46B92',
  },
  {
    id: 'local-05',
    title: 'Old Bookshop Tour',
    subtitle: 'Image folder - 9 chapters',
    chapterTitle: 'Chapter 1',
    fallbackProgressText: 'Newly added',
    coverColor: '#51624D',
    accentColor: '#89A57D',
  },
  {
    id: 'local-06',
    title: 'Galaxy Notes',
    subtitle: 'CBZ - 21 chapters',
    chapterTitle: 'Chapter 15',
    fallbackProgressText: 'Chapter 15',
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
    return AppStrings.get('library_progress_finished')
  }
  return `${progressPercent(progress)}%`
}

export function formatContinueReadingDetail(comic: MockLibraryComic, progress?: ReadingProgress): string {
  if (progress === undefined) {
    return AppStrings.get('library_progress_continue_chapter').replace('%s', comic.chapterTitle)
  }
  return AppStrings.get('library_progress_continue_page')
    .replace('%s', comic.chapterTitle)
    .replace('%s', `${progress.pageIndex + 1}`)
    .replace('%s', `${progressPercent(progress)}`)
}

function formatSourceSubtitle(comic: Comic): string {
  if (comic.subtitle !== undefined && comic.subtitle.length > 0) {
    return comic.subtitle
  }
  if (comic.sourceKind === ComicSourceKind.LOCAL_FOLDER) {
    return AppStrings.get('library_source_subtitle_folder').replace('%s', `${comic.chapterCount}`)
  }
  if (comic.sourceKind === ComicSourceKind.PRIVATE_LIBRARY) {
    return AppStrings.get('library_source_subtitle_private').replace('%s', `${comic.chapterCount}`)
  }
  return AppStrings.get('library_source_subtitle_archive').replace('%s', `${comic.chapterCount}`)
}

function createFallbackPresentation(comic: Comic): LibraryComicPresentation {
  const colorIndex = hashComicId(comic.id) % FALLBACK_COVER_COLORS.length
  return {
    subtitle: formatSourceSubtitle(comic),
    chapterTitle: comic.chapters.length === 0 ? comic.title : comic.chapters[0].title,
    fallbackProgressText: AppStrings.get('library_progress_unread'),
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
    return AppStrings.get('library_progress_finished')
  }
  return `${progressPercent(progress)}%`
}

function isTechnicalChapterTitle(chapterTitle: string): boolean {
  const trimmed = chapterTitle.trim()
  if (trimmed.length === 0) {
    return true
  }
  if (trimmed.startsWith('ch:')) {
    return true
  }
  return trimmed.length >= 32 && trimmed.includes('-')
}

function formatCategoryLabels(categoryIds?: string[]): string[] {
  const labels: string[] = []
  normalizeCategoryIds(categoryIds).forEach((categoryId: string) => {
    if (categoryId === LIBRARY_CATEGORY_FAVORITE_ID) {
      labels.push(AppStrings.get('library_category_favorite'))
    } else if (categoryId === LIBRARY_CATEGORY_READ_LATER_ID) {
      labels.push(AppStrings.get('library_category_read_later'))
    }
  })
  return labels
}

function formatContinueDetail(chapterTitle: string, progress?: ReadingProgress): string {
  if (progress === undefined) {
    return isTechnicalChapterTitle(chapterTitle) ?
      AppStrings.get('library_progress_continue_generic') :
      AppStrings.get('library_progress_continue_chapter').replace('%s', chapterTitle)
  }
  if (isTechnicalChapterTitle(chapterTitle)) {
    return AppStrings.get('library_progress_continue_page_only')
      .replace('%s', `${progress.pageIndex + 1}`)
      .replace('%s', `${progressPercent(progress)}`)
  }
  return AppStrings.get('library_progress_continue_page')
    .replace('%s', chapterTitle)
    .replace('%s', `${progress.pageIndex + 1}`)
    .replace('%s', `${progressPercent(progress)}`)
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
      sourceRuntimeId: comic.sourceRuntimeId,
      sourceImageId: comic.remoteResourceId ?? comic.id,
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
      sourceRuntimeId: continueComic.sourceRuntimeId,
      sourceImageId: continueComic.remoteResourceId ?? continueComic.id,
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

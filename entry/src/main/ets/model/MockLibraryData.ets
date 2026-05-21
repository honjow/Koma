import { ComicId, ReadingProgress } from './ComicModels'
import { ReaderSessionConfig, ReaderSessionStore } from './ReaderSessionStore'

export interface MockLibraryComic {
  id: ComicId
  title: string
  subtitle: string
  chapterTitle: string
  fallbackProgressText: string
  coverColor: string
  accentColor: string
  readerSession?: ReaderSessionConfig
}

export interface LibraryComicCardViewModel {
  id: ComicId
  title: string
  subtitle: string
  progressText: string
  coverColor: string
  accentColor: string
}

export interface ContinueReadingCardViewModel {
  title: string
  detail: string
  progress: number
  color: string
}

export interface LibraryViewModel {
  comics: LibraryComicCardViewModel[]
  continueReading: ContinueReadingCardViewModel
}

export const MOCK_LIBRARY_READER_SESSION: ReaderSessionConfig = {
  comicId: 'local-01',
  chapterId: 'chapter-8',
  totalPages: 5,
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

export function createLibraryViewModel(sessionStore?: ReaderSessionStore): LibraryViewModel {
  const comics = MOCK_LIBRARY_COMICS.map((comic: MockLibraryComic): LibraryComicCardViewModel => {
    const progress = sessionStore === undefined ? undefined : sessionStore.getProgress(comic.id)
    return {
      id: comic.id,
      title: comic.title,
      subtitle: comic.subtitle,
      progressText: formatLibraryProgressText(comic, progress),
      coverColor: comic.coverColor,
      accentColor: comic.accentColor,
    }
  })

  const continueComic = MOCK_LIBRARY_COMICS[0]
  const continueProgress = sessionStore === undefined ? undefined : sessionStore.getProgress(continueComic.id)
  return {
    comics,
    continueReading: {
      title: continueComic.title,
      detail: formatContinueReadingDetail(continueComic, continueProgress),
      progress: continueProgress === undefined ? 0 : progressPercent(continueProgress),
      color: continueComic.coverColor,
    },
  }
}

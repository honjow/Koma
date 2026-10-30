import { Chapter, Comic, ComicSourceKind, ReadingDirection, normalizeSortKey } from './ComicModels'
import { MangaDetail, MangaChapterItem } from './MangaDetailModels'
import { AppStrings } from '../i18n/AppStrings'

export function sourceLibraryComicId(sourceId: string | undefined, mangaId: string): string {
  const normalized = sourceId?.trim() ?? ''
  return normalized.length === 0 || mangaId.startsWith(`${normalized}:`) ? mangaId : `${normalized}:${mangaId}`
}

export function comicFromSourceManga(manga: MangaDetail, chapters: MangaChapterItem[], comicId: string): Comic {
  const now = Date.now()
  const comicChapters = chapters.map((chapter: MangaChapterItem, index: number): Chapter => {
    return {
      id: chapter.id,
      comicId,
      title: chapter.title.length > 0
        ? chapter.title
        : AppStrings.get('library_update_chapter_fallback_title').replace('%s', `${index + 1}`),
      index,
      chapterNumber: chapter.chapterNumber,
      volumeNumber: chapter.volumeNumber,
      readingOrder: chapter.readingOrder,
      readingGroup: chapter.readingGroup,
      continuationEligible: chapter.continuationEligible,
      scanlator: chapter.scanlator,
      language: chapter.language,
      dateUpload: chapter.dateUpload,
      sourcePath: `${manga.url ?? manga.id}#${chapter.id}`,
      sortKey: chapter.chapterNumber === undefined ? `${index}` : `${chapter.chapterNumber}`,
      pages: [],
      pageCount: chapter.pageCount ?? 0,
      createdAt: now,
      updatedAt: now,
    }
  })
  const title = manga.title.length > 0 ? manga.title : AppStrings.get('manga_detail_title_fallback')
  return {
    id: comicId,
    title,
    subtitle: manga.description,
    author: manga.author,
    sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
    sourcePath: manga.url ?? `source://${manga.sourceId ?? 'unknown'}/${manga.id}`,
    sourceRuntimeId: manga.sourceId,
    remoteResourceId: manga.id,
    coverUri: manga.coverUrl,
    sourceMetadata: {
      artist: manga.artist,
      status: manga.status,
      tags: manga.tags?.slice(),
      webUrl: manga.webUrl,
    },
    sortTitle: normalizeSortKey(title),
    preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters: comicChapters,
    chapterCount: comicChapters.length,
    pageCount: comicChapters.reduce((total: number, chapter: Chapter): number => total + chapter.pageCount, 0),
    createdAt: now,
    updatedAt: now,
    lastImportedAt: now,
  }
}

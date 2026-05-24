export interface MangaDetail {
  id: string
  title: string
  author?: string
  artist?: string
  description?: string
  coverUrl?: string
  status?: MangaStatus
  tags?: string[]
  sourceId?: string
  sourceName?: string
  chapterCount: number
  isInLibrary: boolean
  url?: string
}

export enum MangaStatus {
  ONGOING = 'ongoing',
  COMPLETED = 'completed',
  HIATUS = 'hiatus',
  CANCELLED = 'cancelled',
  UNKNOWN = 'unknown',
}

export interface MangaChapterItem {
  id: string
  title: string
  chapterNumber?: number
  volumeNumber?: string
  scanlator?: string
  dateUpload?: number
  isRead: boolean
  isDownloaded: boolean
}

export enum ChapterSortOrder {
  NEWEST_FIRST = 'newest_first',
  OLDEST_FIRST = 'oldest_first',
  BY_NUMBER_DESC = 'by_number_desc',
  BY_NUMBER_ASC = 'by_number_asc',
}

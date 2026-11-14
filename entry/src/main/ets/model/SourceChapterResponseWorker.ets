import type { MangaChapterItem } from './MangaDetailModels'
import type { SourceSettingObservations } from '../sourceRuntime/SourceSettingObservations'
import { parseSourceChapterRow } from './SourceChapterRow'

interface SourceChapterPage {
  hasMore?: boolean
  hasNextPage?: boolean
  has_more?: boolean
  nextCursor?: string | null
  next_cursor?: string | null
}

interface SourceChapterData {
  settingObservations?: SourceSettingObservations
  excludedChapterIds?: string[]
  items?: Record<string, Object>[]
  chapters?: Record<string, Object>[]
  page?: SourceChapterPage
  hasNextPage?: boolean
  hasMore?: boolean
  has_more?: boolean
}

interface SourceChapterResponse {
  ok?: boolean
  reasonCode?: string
  error?: Record<string, Object | string | number | boolean | null>
  data?: SourceChapterData
}

export interface SourceChapterProjection {
  response: SourceChapterResponse
  chapters: MangaChapterItem[]
}

@Concurrent
export function projectSourceChapterResponse(payload: string, untitled: string, numbered: string): SourceChapterProjection {
  const response = JSON.parse(payload) as SourceChapterResponse
  const rows = response.ok === true ? response.data?.items ?? response.data?.chapters ?? [] : []
  const chapters = rows.map((item: Record<string, Object>): MangaChapterItem =>
    parseSourceChapterRow(item, untitled, numbered))
  // Only the normalized rows and pagination metadata need to cross back to UI.
  if (response.data !== undefined && response.data !== null) {
    response.data.items = undefined
    response.data.chapters = undefined
  }
  return { response, chapters }
}

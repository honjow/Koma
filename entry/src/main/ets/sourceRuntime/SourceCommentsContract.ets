export type SourceCommentScope = 'manga' | 'chapter'

export interface SourceCommentsCapability {
  version: number
  scopes: SourceCommentScope[]
}

export interface SourceCommentsTarget {
  sourceId: string
  mangaId: string
  chapterId?: string
  subtitle: string
}

export interface SourceComment {
  id: string
  author: string
  content: string
  createdAt?: string
  deleted?: boolean
}

export interface SourceCommentsPage {
  items: SourceComment[]
  nextCursor?: string
}

// Keep the versioned extension separate from the legacy operation list so
// updated packages and backups can still be used by clients without comments.
export function normalizeSourceCommentsCapability(value?: SourceCommentsCapability): SourceCommentsCapability | undefined {
  if (value?.version !== 1 || !Array.isArray(value.scopes)) return undefined
  const scopes: SourceCommentScope[] = []
  if (value.scopes.includes('manga')) scopes.push('manga')
  if (value.scopes.includes('chapter')) scopes.push('chapter')
  return scopes.length > 0 ? { version: 1, scopes } : undefined
}

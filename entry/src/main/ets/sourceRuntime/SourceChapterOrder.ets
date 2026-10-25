/** Package-owned chronology of the unchanged source catalog, never display sort. */
export type SourceChapterOrder = 'newest_first' | 'oldest_first'

export function isValidSourceChapterOrder(value: string | undefined): boolean {
  return value === undefined || value === 'newest_first' || value === 'oldest_first'
}

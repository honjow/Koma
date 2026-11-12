import { Comic, Page, ReadingProgress } from '../model/ComicModels'

export interface LegacyEpubOrderPlan {
  comic: Comic
  /** IDs to anchor before publishing the new list, in the same order as the supplied positions. */
  anchoredPageIds: string[]
}

function pagePath(page: Page): string | undefined {
  if (!page.uri.startsWith('file://')) return undefined
  try { return decodeURIComponent(page.uri.substring('file://'.length)) } catch (_error) { return undefined }
}

/** Preserve chapter identity and the exact displayed image. Ambiguous repeated
 * images or removed positions leave the entire legacy book untouched. */
export function planLegacyEpubOrder(comic: Comic, extractionRoot: string, orderedPaths: string[],
  positions: ReadingProgress[]): LegacyEpubOrderPlan | undefined {
  if (comic.chapters.length !== 1 || orderedPaths.length === 0 || new Set(orderedPaths).size !== orderedPaths.length) return undefined
  const chapter = comic.chapters[0]
  const oldPages = chapter.pages
  const byPath = new Map<string, Page[]>()
  for (const page of oldPages) {
    const path = pagePath(page)
    if (path === undefined) return undefined
    const pages = byPath.get(path) ?? []
    pages.push(page)
    byPath.set(path, pages)
  }
  const canonicalPaths = orderedPaths.map((path: string): string => `${extractionRoot}/${path}`)
  const canonicalSet = new Set(canonicalPaths)
  const preferred = new Map<string, string>()
  const anchoredPageIds: string[] = []
  for (const position of positions) {
    if (position.chapterId !== chapter.id || !Number.isSafeInteger(position.pageIndex)) return undefined
    let index = position.pageId === undefined ? -1 : oldPages.findIndex((page: Page): boolean => page.id === position.pageId)
    if (index < 0) index = Math.max(0, Math.min(position.pageIndex, oldPages.length - 1))
    const page = oldPages[index]
    const path = page === undefined ? undefined : pagePath(page)
    if (path === undefined || !canonicalSet.has(path)) return undefined
    const prior = preferred.get(path)
    if (prior !== undefined && prior !== page.id) return undefined
    preferred.set(path, page.id)
    anchoredPageIds.push(page.id)
  }
  const pages: Page[] = []
  for (const path of canonicalPaths) {
    const candidates = byPath.get(path)
    if (candidates === undefined || candidates.length === 0) return undefined
    const wanted = preferred.get(path)
    const selected = wanted === undefined ? candidates[0] : candidates.find((page: Page): boolean => page.id === wanted)
    if (selected === undefined) return undefined
    const page = JSON.parse(JSON.stringify(selected)) as Page
    page.index = pages.length
    pages.push(page)
  }
  const next = JSON.parse(JSON.stringify(comic)) as Comic
  next.chapters[0].pages = pages
  next.chapters[0].pageCount = pages.length
  next.pageCount = pages.length
  if (next.localImportOrigin === undefined) next.localImportOrigin = { kind: 'archive', sourceUris: [next.sourcePath] }
  next.localImportOrigin.epubOrderRevision = 1
  return { comic: next, anchoredPageIds }
}

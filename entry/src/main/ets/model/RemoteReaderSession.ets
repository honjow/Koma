import { util, url } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

export type RemoteHistoryKind = 'komga' | 'kavita' | 'webdav' | 'opds'

/** Catalog identity only; progress, images and credentials keep their own owners. */
export interface RemoteReadHistoryEntry {
  kind: RemoteHistoryKind
  comicId: string
  chapterId: string
  serverId: string
  resourceId: string
  title: string
  chapterTitle?: string
  libraryId?: number
  pathSegments?: string[]
  opdsRootFeed?: boolean
  opdsFeedPath?: string
  opdsSearchQuery?: string
}

export interface OpdsHistoryLocator {
  opdsRootFeed?: boolean
  opdsFeedPath?: string
  opdsSearchQuery?: string
}

export function validRemoteHistorySegments(segments: string[]): boolean {
  return segments.every((segment: string): boolean => typeof segment === 'string' &&
    segment.length > 0 && segment !== '.' && segment !== '..' && !/[\/\\\u0000-\u001f\u007f]/.test(segment))
}

function validOpdsHistoryPath(path: string): boolean {
  if (!path.startsWith('/') || path.startsWith('//') || /[?#\\\u0000-\u001f\u007f]/.test(path)) return false
  try {
    return path.split('/').filter((segment: string): boolean => segment.length > 0)
      .every((segment: string): boolean => validRemoteHistorySegments([decodeURIComponent(segment)]))
  } catch (_error) {
    return false
  }
}

function text(value: string | undefined): string {
  return typeof value === 'string' ? value.trim() : ''
}

export function copyRemoteReadHistoryEntry(entry: RemoteReadHistoryEntry): RemoteReadHistoryEntry | undefined {
  if (entry === undefined || entry === null) return undefined
  if (entry.kind !== 'komga' && entry.kind !== 'kavita' && entry.kind !== 'webdav' && entry.kind !== 'opds') return undefined
  const comicId = text(entry.comicId)
  const chapterId = text(entry.chapterId)
  const serverId = text(entry.serverId)
  const resourceId = text(entry.resourceId)
  const title = text(entry.title)
  if (serverId.length === 0 || resourceId.length === 0 || title.length === 0 ||
    !comicId.startsWith(`${entry.kind}:${serverId}:`) || !chapterId.startsWith(`${entry.kind}:${serverId}:`)) return undefined
  const copied: RemoteReadHistoryEntry = { kind: entry.kind, comicId, chapterId, serverId, resourceId, title }
  const chapterTitle = text(entry.chapterTitle)
  if (chapterTitle.length > 0) copied.chapterTitle = chapterTitle
  if (entry.kind === 'kavita') {
    if (!Number.isInteger(entry.libraryId) || (entry.libraryId ?? 0) <= 0 || !/^[1-9][0-9]*$/.test(resourceId)) return undefined
    copied.libraryId = entry.libraryId
  } else if (entry.kind === 'webdav') {
    if (!Array.isArray(entry.pathSegments) || !validRemoteHistorySegments(entry.pathSegments)) return undefined
    copied.pathSegments = entry.pathSegments.slice()
  } else if (entry.kind === 'opds') {
    if (!/^[0-9a-f]{64}$/.test(resourceId)) return undefined
    if (entry.opdsSearchQuery !== undefined) {
      if (entry.opdsRootFeed !== undefined || entry.opdsFeedPath !== undefined ||
        typeof entry.opdsSearchQuery !== 'string' || entry.opdsSearchQuery.trim().length === 0 ||
        /[\u0000-\u001f\u007f]/.test(entry.opdsSearchQuery)) return undefined
      copied.opdsSearchQuery = entry.opdsSearchQuery
    } else if (entry.opdsRootFeed === true && entry.opdsFeedPath === undefined) {
      copied.opdsRootFeed = true
    } else if (entry.opdsRootFeed !== true && typeof entry.opdsFeedPath === 'string' && validOpdsHistoryPath(entry.opdsFeedPath)) {
      copied.opdsFeedPath = entry.opdsFeedPath
    } else {
      return undefined
    }
  }
  return copied
}

/** The key may derive from a signed publication ID; never retain that raw URL. */
export function opdsHistoryPublicationKey(publicationId: string): string {
  const md = cryptoFramework.createMd('SHA256')
  md.updateSync({ data: new util.TextEncoder().encodeInto(publicationId) })
  return Array.from(md.digestSync().data).map((value: number): string => value.toString(16).padStart(2, '0')).join('')
}

export function opdsHistoryLocator(rootUrl: string, feedUrl: string): OpdsHistoryLocator | undefined {
  try {
    const root = url.URL.parseURL(rootUrl)
    const feed = url.URL.parseURL(feedUrl)
    if ((root.protocol !== 'http:' && root.protocol !== 'https:') || feed.origin !== root.origin ||
      root.username.length > 0 || root.password.length > 0 || feed.username.length > 0 || feed.password.length > 0) return undefined
    if (feed.toString() === root.toString()) return { opdsRootFeed: true }
    // A configured feed is an endpoint, not a directory ancestor. OPDS navigation
    // can use sibling paths on this origin; the saved server identity owns it.
    if (feed.search.length > 0 || feed.hash.length > 0 || !validOpdsHistoryPath(feed.pathname)) return undefined
    return { opdsFeedPath: feed.pathname }
  } catch (_error) {
    return undefined
  }
}

/** Rebuild a search from user intent; signed feed URLs never enter history. */
export function canRequestOpdsHistoryUrl(rootUrl: string, targetUrl: string): boolean {
  try {
    const root = url.URL.parseURL(rootUrl)
    const target = url.URL.parseURL(targetUrl)
    return (root.protocol === 'http:' || root.protocol === 'https:') && target.origin === root.origin &&
      root.username.length === 0 && root.password.length === 0 &&
      target.username.length === 0 && target.password.length === 0 && target.hash.length === 0
  } catch (_error) {
    return false
  }
}

export function opdsSearchHistoryLocator(rootUrl: string, feedUrl: string, query: string): OpdsHistoryLocator | undefined {
  if (!canRequestOpdsHistoryUrl(rootUrl, feedUrl) || typeof query !== 'string' || query.trim().length === 0 ||
    /[\u0000-\u001f\u007f]/.test(query)) return undefined
  return { opdsSearchQuery: query }
}

/** Recheck restored metadata against today's configured endpoint before HTTP. */
export function resolveOpdsHistoryFeed(rootUrl: string, entry: RemoteReadHistoryEntry): string | undefined {
  if (copyRemoteReadHistoryEntry(entry) === undefined || entry.kind !== 'opds') return undefined
  if (entry.opdsSearchQuery !== undefined || entry.opdsRootFeed === true) {
    return opdsHistoryLocator(rootUrl, rootUrl) === undefined ? undefined : rootUrl
  }
  try {
    const root = url.URL.parseURL(rootUrl)
    const candidate = `${root.origin}${entry.opdsFeedPath}`
    return opdsHistoryLocator(rootUrl, candidate) === undefined ? undefined : candidate
  } catch (_error) {
    return undefined
  }
}

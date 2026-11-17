export interface MihonPathIdentity {
  pathPrefix: string
  pathSuffix?: string
  pathTitleAfterId?: boolean
  pathIdSegment?: number
  idPrefix: string
  idSuffix?: string
}

export interface MihonChapterIdentity extends MihonPathIdentity {
  pathWorkIdSeparator?: string
  targetIdSegment?: number
}

export interface MihonSourceIdentity {
  sourceIds: string[]
  work: MihonPathIdentity
  chapter?: MihonChapterIdentity
  samePageOrder?: boolean
}

function validPathIdentity(rule: MihonPathIdentity | undefined): boolean {
  if (rule === undefined || rule === null) return false
  const token = /^[A-Za-z0-9._:/?=&,-]{0,128}$/
  const fixedOrigin = /^https:\/\/[A-Za-z0-9.-]+\//
  return typeof rule.pathPrefix === 'string' &&
    (rule.pathPrefix === '' || rule.pathPrefix.startsWith('/') || fixedOrigin.test(rule.pathPrefix)) &&
    token.test(rule.pathPrefix) && (rule.pathSuffix === undefined ||
      typeof rule.pathSuffix === 'string' && token.test(rule.pathSuffix)) &&
    (rule.pathTitleAfterId === undefined || typeof rule.pathTitleAfterId === 'boolean' &&
      (!rule.pathTitleAfterId || rule.pathPrefix.endsWith('/') && rule.pathSuffix === '/')) &&
    typeof rule.idPrefix === 'string' && token.test(rule.idPrefix) &&
    (rule.idSuffix === undefined || typeof rule.idSuffix === 'string' && token.test(rule.idSuffix))
}

export function validMihonSourceIdentity(value: MihonSourceIdentity | undefined): boolean {
  if (value === undefined) return true
  return value !== null && Array.isArray(value.sourceIds) && value.sourceIds.length > 0 &&
    value.sourceIds.every((id: string): boolean => typeof id === 'string' && /^-?\d{1,19}$/.test(id)) &&
    validPathIdentity(value.work) && value.work.pathIdSegment === undefined &&
    (value.chapter === undefined || (validPathIdentity(value.chapter) &&
      value.chapter.pathTitleAfterId === undefined &&
      (value.chapter.pathWorkIdSeparator === undefined ||
        typeof value.chapter.pathWorkIdSeparator === 'string' && value.chapter.pathPrefix.length > 0 &&
        value.chapter.pathWorkIdSeparator.length > 0 && /^[A-Za-z0-9._:/?=&,-]{1,128}$/.test(
          value.chapter.pathWorkIdSeparator) && value.chapter.pathIdSegment === undefined) &&
      (value.chapter.pathIdSegment === undefined || (Number.isInteger(value.chapter.pathIdSegment) &&
        value.chapter.pathIdSegment >= -8 && value.chapter.pathIdSegment <= 7)) &&
      (value.chapter.targetIdSegment === undefined || (Number.isInteger(value.chapter.targetIdSegment) &&
        value.chapter.targetIdSegment >= 0 && value.chapter.targetIdSegment <= 7)))) &&
    (value.samePageOrder === undefined || value.samePageOrder === false ||
      value.samePageOrder === true && value.chapter !== undefined)
}

/** Consume declared literal prefixes and suffixes. Only a plain ID or path
 * can occupy the variable part, including for routes with a query prefix. */
export function mihonPathIdentity(path: string, rule: MihonPathIdentity): string | undefined {
  const relative = path.startsWith('https://') ? path.substring('https://'.length) : path
  if (relative.includes('//') ||
    relative.split('/').some((segment: string): boolean => segment === '.' || segment === '..')) return undefined
  const suffix = rule.pathSuffix ?? ''
  if (!path.startsWith(rule.pathPrefix)) return undefined
  if (rule.pathTitleAfterId === true) {
    const remainder = path.substring(rule.pathPrefix.length)
    const separator = remainder.indexOf('/')
    const title = separator < 0 ? '' : remainder.substring(separator + 1)
    const id = separator < 0 ? remainder : remainder.substring(0, separator)
    if (!/^[A-Za-z0-9._,-]+$/.test(id) || /[/\\?#\u0000-\u001f\u007f]/.test(title)) return undefined
    return rule.idPrefix + id + (rule.idSuffix ?? '')
  }
  if (!path.endsWith(suffix)) return undefined
  let stem = path.substring(rule.pathPrefix.length, path.length - suffix.length)
  if (rule.pathIdSegment !== undefined) {
    if (rule.pathPrefix === '' && stem.startsWith('/')) stem = stem.substring(1)
    if (suffix.length === 0 && stem.endsWith('/')) stem = stem.substring(0, stem.length - 1)
  }
  if (path.length <= rule.pathPrefix.length + suffix.length ||
    !/^[A-Za-z0-9._,-]+(?:\/[A-Za-z0-9._,-]+)*$/.test(stem)) return undefined
  if (rule.pathIdSegment === undefined) return rule.idPrefix + stem + (rule.idSuffix ?? '')
  const segments = stem.split('/')
  const index = rule.pathIdSegment < 0 ? segments.length + rule.pathIdSegment : rule.pathIdSegment
  const id = segments[index]
  return id === undefined ? undefined : rule.idPrefix + id + (rule.idSuffix ?? '')
}

export function mihonChapterPathIdentity(path: string, workId: string, identity: MihonSourceIdentity): string | undefined {
  const rule = identity.chapter
  if (rule === undefined) return undefined
  const separator = rule.pathWorkIdSeparator
  if (separator === undefined) return mihonPathIdentity(path, rule)
  if (!path.startsWith(rule.pathPrefix)) return undefined
  // A title fragment is display metadata. The two identifiers on either
  // side of the separator must belong to this work and chapter.
  const address = path.split('#', 1)[0]
  const start = address.indexOf(separator, rule.pathPrefix.length)
  if (start < 0) return undefined
  const work = address.substring(rule.pathPrefix.length, start)
  if (!/^[A-Za-z0-9._,-]+$/.test(work) || work === '.' || work === '..' ||
    identity.work.idPrefix + work + (identity.work.idSuffix ?? '') !== workId) return undefined
  const chapterPath = address.substring(start + separator.length)
  const chapterRule: MihonPathIdentity = { pathPrefix: '', pathSuffix: rule.pathSuffix,
    idPrefix: rule.idPrefix, idSuffix: rule.idSuffix }
  return mihonPathIdentity(chapterPath, chapterRule)
}

export function mihonTargetChapterId(id: string, rule: MihonChapterIdentity): string | undefined {
  const stableId = rule.pathWorkIdSeparator === undefined ? id : id.split('#', 1)[0]
  return rule.targetIdSegment === undefined ? stableId : stableId.split(':')[rule.targetIdSegment]
}

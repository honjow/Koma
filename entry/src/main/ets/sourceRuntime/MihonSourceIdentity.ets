export interface MihonPathIdentity {
  pathPrefix: string
  pathSuffix?: string
  idPrefix: string
  idSuffix?: string
}

export interface MihonChapterIdentity extends MihonPathIdentity {
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
    typeof rule.idPrefix === 'string' && token.test(rule.idPrefix) &&
    (rule.idSuffix === undefined || typeof rule.idSuffix === 'string' && token.test(rule.idSuffix))
}

export function validMihonSourceIdentity(value: MihonSourceIdentity | undefined): boolean {
  if (value === undefined) return true
  return value !== null && Array.isArray(value.sourceIds) && value.sourceIds.length > 0 &&
    value.sourceIds.every((id: string): boolean => typeof id === 'string' && /^-?\d{1,19}$/.test(id)) &&
    validPathIdentity(value.work) && (value.chapter === undefined || (validPathIdentity(value.chapter) &&
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
  if (!path.startsWith(rule.pathPrefix) || !path.endsWith(suffix)) return undefined
  const stem = path.substring(rule.pathPrefix.length, path.length - suffix.length)
  if (path.length <= rule.pathPrefix.length + suffix.length ||
    !/^[A-Za-z0-9._,-]+(?:\/[A-Za-z0-9._,-]+)*$/.test(stem)) return undefined
  return rule.idPrefix + stem + (rule.idSuffix ?? '')
}

export function mihonTargetChapterId(id: string, rule: MihonChapterIdentity): string | undefined {
  return rule.targetIdSegment === undefined ? id : id.split(':')[rule.targetIdSegment]
}

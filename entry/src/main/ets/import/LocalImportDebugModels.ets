export const LOCAL_ARCHIVE_DEBUG_STEP_PICKER_STARTED = 'picker_started'
export const LOCAL_ARCHIVE_DEBUG_STEP_PICKER_RETURNED = 'picker_returned'
export const LOCAL_ARCHIVE_DEBUG_STEP_CACHE_PATHS = 'cache_paths'
export const LOCAL_ARCHIVE_DEBUG_STEP_COPY_STARTED = 'copy_started'
export const LOCAL_ARCHIVE_DEBUG_STEP_COPY_SUCCEEDED = 'copy_succeeded'
export const LOCAL_ARCHIVE_DEBUG_STEP_COPY_FAILED = 'copy_failed'
export const LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_STARTED = 'extraction_started'
export const LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_SUCCEEDED = 'extraction_succeeded'
export const LOCAL_ARCHIVE_DEBUG_STEP_EXTRACTION_FAILED = 'extraction_failed'
export const LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_SUCCEEDED = 'import_succeeded'
export const LOCAL_ARCHIVE_DEBUG_STEP_IMPORT_FAILED = 'import_failed'

const DEBUG_VALUE_MAX_LENGTH = 180
const DEBUG_VALUE_HEAD_LENGTH = 64
const DEBUG_VALUE_TAIL_LENGTH = 96

export interface LocalArchiveImportDebugEvent {
  step: string
  timestamp?: number
  uriCount?: number
  sourceUri?: string
  sandboxZipPath?: string
  cacheRootDir?: string
  extractionDir?: string
  comicId?: string
  title?: string
  pageCount?: number
  error?: string
}

export interface LocalArchiveImportDebugSnapshot {
  events: LocalArchiveImportDebugEvent[]
  lines: string[]
}

export type LocalArchiveImportDebugSink = (event: LocalArchiveImportDebugEvent) => void

function redactSensitiveQueryValues(value: string): string {
  return value
    .replace(/([?&](?:token|access_token|refresh_token|password|secret|signature|credential|auth|code|key)=)[^&#]*/gi, '$1<redacted>')
}

export function sanitizeLocalArchiveDebugValue(value: string | undefined): string {
  if (value === undefined) {
    return ''
  }
  const redacted = redactSensitiveQueryValues(value.replace(/\s+/g, ' ').trim())
  if (redacted.length <= DEBUG_VALUE_MAX_LENGTH) {
    return redacted
  }
  return `${redacted.substring(0, DEBUG_VALUE_HEAD_LENGTH)}...${redacted.substring(redacted.length - DEBUG_VALUE_TAIL_LENGTH)}`
}

function appendField(fields: string[], label: string, value: string | undefined): void {
  const sanitizedValue = sanitizeLocalArchiveDebugValue(value)
  if (sanitizedValue.length > 0) {
    fields.push(`${label}=${sanitizedValue}`)
  }
}

function appendNumberField(fields: string[], label: string, value: number | undefined): void {
  if (value !== undefined) {
    fields.push(`${label}=${value}`)
  }
}

export function formatLocalArchiveImportDebugEvent(event: LocalArchiveImportDebugEvent): string {
  const fields: string[] = [event.step]
  appendNumberField(fields, 'uris', event.uriCount)
  appendField(fields, 'sourceUri', event.sourceUri)
  appendField(fields, 'sandboxZipPath', event.sandboxZipPath)
  appendField(fields, 'cacheRootDir', event.cacheRootDir)
  appendField(fields, 'extractionDir', event.extractionDir)
  appendField(fields, 'comicId', event.comicId)
  appendField(fields, 'title', event.title)
  appendNumberField(fields, 'pages', event.pageCount)
  appendField(fields, 'error', event.error)
  return fields.join(' | ')
}

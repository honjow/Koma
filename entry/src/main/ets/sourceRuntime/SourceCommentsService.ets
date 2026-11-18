import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { configureSourceRequestPolicy } from './SourceRequestPolicy'
import { SourceRuntimeError } from '../model/SourceRuntimeError'
import { SourceRuntimeCallResponse } from './NativeSourceRuntime'
import { SourceCommentsTarget, SourceCommentsPage, SourceCommentScope } from './SourceCommentsContract'
import { SourceRuntimeRegistry, sourceRuntimeEntryEnabled } from './SourceRuntimeRegistry'
import { appSourceSettingsStore, SourceSettingsRecord } from './SourceSettingsStore'
import { sourceHttpIdentityJson } from './SourceWebSessionStore'
import { registerSourceRuntimeOperationGuard } from './SourceRuntimeOperationGuard'
import { executeSourceRequestInWorker, SourceWorkerPriority } from './SourceRuntimeWorkerClient'

interface SourceCommentsArgs {
  scope: SourceCommentScope
  mangaId: string
  chapterId?: string
  cursor?: string
}

interface SourceCommentsHints {
  network: boolean
}

interface SourceCommentsRequest {
  type: string
  version: number
  requestId: string
  sourceId: string
  operation: string
  args: SourceCommentsArgs
  settings: SourceSettingsRecord
  hostHints: SourceCommentsHints
}

let nextCommentsRequestId: number = 0

export function hasSourceComments(registry: SourceRuntimeRegistry, sourceId: string, scope: SourceCommentScope): boolean {
  const entry = registry.lookup(sourceId).entry
  return sourceRuntimeEntryEnabled(entry) && entry?.comments?.scopes.includes(scope) === true
}

function invalidComments(): SourceRuntimeError {
  return new SourceRuntimeError({ ok: false, reasonCode: 'invalid_response' })
}

export async function loadSourceComments(registry: SourceRuntimeRegistry, target: SourceCommentsTarget,
  cursor: string | undefined, isVisible: () => boolean): Promise<SourceCommentsPage> {
  const scope: SourceCommentScope = target.chapterId === undefined ? 'manga' : 'chapter'
  const entry = registry.lookup(target.sourceId).entry
  if (entry === undefined || !sourceRuntimeEntryEnabled(entry) || !entry.comments?.scopes.includes(scope)) {
    throw new SourceRuntimeError({ ok: false, reasonCode: 'unsupported_operation' })
  }
  if (target.mangaId.length === 0 || target.chapterId === '') throw invalidComments()
  const requestId = 'comments-' + (++nextCommentsRequestId)
  const settingsRevision = appSourceSettingsStore.revisionForSource(target.sourceId)
  const isCurrent = (): boolean => isVisible() && registry.lookup(target.sourceId).entry === entry &&
    appSourceSettingsStore.revisionForSource(target.sourceId) === settingsRevision
  const request: SourceCommentsRequest = {
    type: 'request', version: 1, sourceId: target.sourceId, requestId, operation: 'get_comments',
    args: { scope, mangaId: target.mangaId, chapterId: target.chapterId, cursor },
    settings: appSourceSettingsStore.loadForSource(target.sourceId), hostHints: { network: true },
  }
  configureSourceRequestPolicy(entry.requestLimits, request.settings)
  const release = registerSourceRuntimeOperationGuard(requestId, isCurrent)
  try {
    const raw = await executeSourceRequestInWorker(JSON.stringify(request), entry.wasmBytes,
      sourceHttpIdentityJson(entry, requestId, false, request.operation), SourceWorkerPriority.BACKGROUND, isCurrent)
    if (!isCurrent()) throw new SourceRuntimeError({ ok: false, reasonCode: 'source_changed' })
    const response = JSON.parse(raw) as SourceRuntimeCallResponse
    if (!response.ok) throw new SourceRuntimeError(response)
    const page = response.data as Object as SourceCommentsPage | undefined
    if (response.operation !== request.operation || page === undefined || page === null || !Array.isArray(page.items) ||
      page.items.some(row => typeof row?.id !== 'string' || row.id.length === 0 ||
        typeof row.author !== 'string' || typeof row.content !== 'string' ||
        (row.createdAt !== undefined && typeof row.createdAt !== 'string') ||
        (row.deleted !== undefined && typeof row.deleted !== 'boolean')) ||
      (page.nextCursor !== undefined && (typeof page.nextCursor !== 'string' ||
        page.nextCursor.length === 0 || page.nextCursor === cursor || page.items.length === 0))) {
      throw invalidComments()
    }
    DiagnosticLogger.info('source', 'comments_page_loaded',
      `source=${target.sourceId} scope=${scope} continuation=${cursor !== undefined} count=${page.items.length} hasMore=${page.nextCursor !== undefined}`)
    return page
  } finally {
    release()
  }
}

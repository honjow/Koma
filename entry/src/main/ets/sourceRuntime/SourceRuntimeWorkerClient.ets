import { taskpool } from '@kit.ArkTS'
import { SourcePrivateSessionHost } from './SourcePrivateSessionHost'
import { executeSourceRuntimeRequest, runBrowseSourceOperationTask, runLocalCoverOperationTask } from './SourceRuntimeWorker'
import { sourceRuntimeExecutionHasDnsBootstrap, sourceRuntimeExecutionSourceId } from './SourceRuntimeExecutionIdentity'

export enum SourceWorkerPriority {
  FOREGROUND = 'foreground',
  BACKGROUND = 'background',
}

interface PendingSourceWorkerOperation {
  sourceId: string
  requestJson: string
  wasmBytes: Uint8Array
  httpContextJson: string
  browse: boolean
  priority: SourceWorkerPriority
  isActive?: () => boolean
  resolve: (value: string) => void
  reject: (reason: Object) => void
}

const SOURCE_OPERATION_CONCURRENCY: number = 4
const activeSources: Set<string> = new Set<string>()
const pendingOperations: PendingSourceWorkerOperation[] = []
let activeOperations: number = 0
let unidentifiedActive: boolean = false
const LOCAL_COVER_CONCURRENCY: number = 2
const pendingLocalCovers: (() => Promise<void>)[] = []
const localCoverFallbackTails: Map<string, Promise<void>> = new Map<string, Promise<void>>()
let activeLocalCovers: number = 0

function startWaitingLocalCovers(): void {
  while (activeLocalCovers < LOCAL_COVER_CONCURRENCY && pendingLocalCovers.length > 0) {
    const run = pendingLocalCovers.shift()
    if (run === undefined) return
    activeLocalCovers += 1
    run().finally((): void => {
      activeLocalCovers -= 1
      startWaitingLocalCovers()
    })
  }
}

function canAdmit(operation: PendingSourceWorkerOperation): boolean {
  if (unidentifiedActive) return false
  return operation.sourceId.length === 0 ? activeOperations === 0 : !activeSources.has(operation.sourceId)
}

function startWaitingSourceOperations(): void {
  while (activeOperations < SOURCE_OPERATION_CONCURRENCY && pendingOperations.length > 0) {
    const first = pendingOperations.findIndex(canAdmit)
    if (first < 0) return
    const sourceId = pendingOperations[first].sourceId
    // Preserve FIFO between different sources. Within one source, an interactive
    // request may pass covers that have not started. Reader page images retain
    // foreground priority; running work and native per-source isolation stay intact.
    const foreground = pendingOperations.findIndex((operation: PendingSourceWorkerOperation): boolean =>
      operation.sourceId === sourceId && operation.priority === SourceWorkerPriority.FOREGROUND)
    const next = pendingOperations.splice(foreground < 0 ? first : foreground, 1)[0]
    try {
      if (next.isActive !== undefined && !next.isActive()) {
        next.reject(new Error('search_cancelled'))
        continue
      }
    } catch (error) {
      next.reject(error as Object)
      continue
    }
    activeOperations += 1
    if (sourceId.length === 0) unidentifiedActive = true
    else activeSources.add(sourceId)
    Promise.resolve().then((): Promise<string> => {
      if (next.isActive !== undefined && !next.isActive()) return Promise.reject(new Error('search_cancelled'))
      return runSourceWorker(next.requestJson, next.wasmBytes, next.httpContextJson, next.browse,
        next.browse || next.priority === SourceWorkerPriority.BACKGROUND)
    }).then(next.resolve, next.reject).finally((): void => {
      activeOperations -= 1
      if (sourceId.length === 0) unidentifiedActive = false
      else activeSources.delete(sourceId)
      startWaitingSourceOperations()
    })
  }
}

function enqueueSourceWorker(requestJson: string, wasmBytes: Uint8Array, httpContextJson: string,
  browse: boolean, priority: SourceWorkerPriority, isActive?: () => boolean): Promise<string> {
  const scopeCurrent = SourcePrivateSessionHost.callAdmission(httpContextJson)
  const current = (): boolean => scopeCurrent() && (isActive === undefined || isActive())
  return new Promise<string>((resolve, reject) => {
    pendingOperations.push({ sourceId: sourceRuntimeExecutionSourceId(httpContextJson), requestJson, wasmBytes,
      httpContextJson, browse, priority, isActive: current, resolve, reject })
    startWaitingSourceOperations()
  })
}

// UI-side lifecycle only. The worker must retain its Native-only import graph.
// A trapped/cancelled module cannot leave its private-session initializer owned.
async function runSourceWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string, browse: boolean, copyOnAdmission: boolean): Promise<string> {
  let publicInitializationAllowed = false
  if (sourceRuntimeExecutionHasDnsBootstrap(httpContextJson)) {
    try {
      const request = JSON.parse(requestJson) as Record<string, Object>
      const hints = request['hostHints'] as Record<string, Object> | undefined
      publicInitializationAllowed = hints?.['network'] === true && ['search', 'get_manga', 'get_chapters', 'get_pages',
        'get_manga_list', 'get_home', 'get_listings', 'get_filters', 'get_image_request', 'authenticate'].includes(request['operation'] as string)
    } catch (_error) {}
  }
  const call = SourcePrivateSessionHost.beginCall(httpContextJson, publicInitializationAllowed)
  try {
    // Browse and queued cover requests keep the immutable installed bytes by
    // reference until admission. Foreground image/detail callers pass a snapshot.
    const workerBytes = copyOnAdmission ? new Uint8Array(wasmBytes.byteLength) : wasmBytes
    if (copyOnAdmission) workerBytes.set(wasmBytes)
    return browse
      ? await taskpool.execute(runBrowseSourceOperationTask, requestJson, workerBytes, call.httpContextJson) as string
      : await taskpool.execute(executeSourceRuntimeRequest, requestJson, workerBytes, call.httpContextJson) as string
  } finally {
    if (call.id.length > 0) SourcePrivateSessionHost.finishCall(call.id)
  }
}

export function executeSourceRequestInWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string, priority: SourceWorkerPriority = SourceWorkerPriority.FOREGROUND,
  isActive?: () => boolean): Promise<string> {
  return enqueueSourceWorker(requestJson, wasmBytes, httpContextJson, false, priority, isActive)
}

// Only host cover callers can opt in. A restricted run never owns a private
// session or opens HTTP. If it needs either, queue the original request once.
export function executeSourceCoverRequestInWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string): Promise<string> {
  const sourceId = sourceRuntimeExecutionSourceId(httpContextJson)
  if (sourceId.length === 0) return enqueueSourceWorker(requestJson, wasmBytes, httpContextJson, false,
    SourceWorkerPriority.BACKGROUND)
  const current = SourcePrivateSessionHost.callAdmission(httpContextJson)
  const probe = new Promise<string>((resolve, reject) => {
    pendingLocalCovers.push(async (): Promise<void> => {
      if (!current()) {
        reject(new Error('search_cancelled'))
        return
      }
      try {
        resolve(await taskpool.execute(runLocalCoverOperationTask, requestJson, new Uint8Array(wasmBytes),
          httpContextJson) as string)
      } catch (_error) {
        resolve('')
      }
    })
    startWaitingLocalCovers()
  })
  return new Promise<string>((resolve, reject) => {
    // A fast local answer can return immediately. The fallbacks enter the
    // ordinary lane in their original same-source order even if probes finish
    // out of order. No probe slot waits for an ordinary call to complete.
    const previous = localCoverFallbackTails.get(sourceId) ?? Promise.resolve()
    const classified = probe.then(async (response: string): Promise<void> => {
      if (response.length === 0) {
        await previous
        if (!current()) throw new Error('search_cancelled')
        resolve(enqueueSourceWorker(requestJson, wasmBytes, httpContextJson, false,
          SourceWorkerPriority.BACKGROUND, current))
      } else {
        if (!current()) throw new Error('search_cancelled')
        resolve(response)
      }
    }).catch(reject)
    const tail = previous.then((): Promise<void> => classified)
    localCoverFallbackTails.set(sourceId, tail)
    tail.finally((): void => {
      if (localCoverFallbackTails.get(sourceId) === tail) localCoverFallbackTails.delete(sourceId)
    })
  })
}

export function runBrowseSourceRequestInWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string, isActive?: () => boolean): Promise<string> {
  return enqueueSourceWorker(requestJson, wasmBytes, httpContextJson, true, SourceWorkerPriority.FOREGROUND, isActive)
}

import { taskpool } from '@kit.ArkTS'
import { SourcePrivateSessionHost } from './SourcePrivateSessionHost'
import { executeSourceRuntimeRequest, runBrowseSourceOperationTask } from './SourceRuntimeWorker'
import { sourceRuntimeExecutionSourceId } from './SourceRuntimeExecutionIdentity'

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
      return runSourceWorker(next.requestJson, next.wasmBytes, next.httpContextJson, next.browse)
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
  return new Promise<string>((resolve, reject) => {
    pendingOperations.push({ sourceId: sourceRuntimeExecutionSourceId(httpContextJson), requestJson, wasmBytes,
      httpContextJson, browse, priority, isActive, resolve, reject })
    startWaitingSourceOperations()
  })
}

// UI-side lifecycle only. The worker must retain its Native-only import graph.
// A trapped/cancelled module cannot leave its private-session initializer owned.
async function runSourceWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string, browse: boolean): Promise<string> {
  const call = SourcePrivateSessionHost.beginCall(httpContextJson)
  try {
    // Keep queued registry bytes by reference; only copy an admitted Browse
    // request. Image/detail callers already pass their private byte snapshot.
    const workerBytes = browse ? new Uint8Array(wasmBytes.byteLength) : wasmBytes
    if (browse) workerBytes.set(wasmBytes)
    return browse
      ? await taskpool.execute(runBrowseSourceOperationTask, requestJson, workerBytes, call.httpContextJson) as string
      : await taskpool.execute(executeSourceRuntimeRequest, requestJson, workerBytes, call.httpContextJson) as string
  } finally {
    if (call.id.length > 0) SourcePrivateSessionHost.finishCall(call.id)
  }
}

export function executeSourceRequestInWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string, priority: SourceWorkerPriority = SourceWorkerPriority.FOREGROUND): Promise<string> {
  return enqueueSourceWorker(requestJson, wasmBytes, httpContextJson, false, priority)
}

export function runBrowseSourceRequestInWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string, isActive?: () => boolean): Promise<string> {
  return enqueueSourceWorker(requestJson, wasmBytes, httpContextJson, true, SourceWorkerPriority.FOREGROUND, isActive)
}

import { taskpool } from '@kit.ArkTS'
import { SourcePrivateSessionHost } from './SourcePrivateSessionHost'
import { executeSourceRuntimeRequest, runBrowseSourceOperationTask } from './SourceRuntimeWorker'

// UI-side lifecycle only. The worker must retain its Native-only import graph.
// A trapped/cancelled module cannot leave its private-session initializer owned.
async function runSourceWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string, browse: boolean): Promise<string> {
  const call = SourcePrivateSessionHost.beginCall(httpContextJson)
  try {
    return browse
      ? await taskpool.execute(runBrowseSourceOperationTask, requestJson, wasmBytes, call.httpContextJson) as string
      : await taskpool.execute(executeSourceRuntimeRequest, requestJson, wasmBytes, call.httpContextJson) as string
  } finally {
    if (call.id.length > 0) SourcePrivateSessionHost.finishCall(call.id)
  }
}

export function executeSourceRequestInWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string): Promise<string> {
  return runSourceWorker(requestJson, wasmBytes, httpContextJson, false)
}

export function runBrowseSourceRequestInWorker(requestJson: string, wasmBytes: Uint8Array,
  httpContextJson: string): Promise<string> {
  return runSourceWorker(requestJson, wasmBytes, httpContextJson, true)
}

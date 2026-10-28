import { NativeSourceRuntime } from './NativeSourceRuntime'
import { sourceRequestWithHostFeatures } from './SourceHostFeatures'
import { sourceRuntimeExecutionHasDetailChapterContext, sourceRuntimeExecutionHasGuard,
  sourceRuntimeExecutionSourceId } from './SourceRuntimeExecutionIdentity'

// TaskPool evaluates this module's transitive imports on a worker. Keep this
// entry Native-only: Service/Runner pull in UI state and localization, whose
// decorators fail during worker initialization even when no UI method is called.
// Admission, HTTP identity, diagnostics and source-changed checks stay with the
// calling Service; do not move them here or fall back to blocking the UI thread.
// Browse and detail also call these workers directly. Advertise the Host's pure
// protocol features here so their source settings reach the same Native boundary.
@Concurrent
export function executeSourceRuntimeRequest(requestJson: string, wasmBytes: Uint8Array, httpContextJson: string): string {
  return JSON.stringify(NativeSourceRuntime.runJsonCallFromBytes(
    sourceRequestWithHostFeatures(requestJson, sourceRuntimeExecutionHasGuard(httpContextJson),
      sourceRuntimeExecutionHasDetailChapterContext(httpContextJson)), wasmBytes, httpContextJson))
}

// Browse historically uses the asynchronous raw-string Native entry. Preserve
// that transport separately; image/detail callers must keep the static Native
// wrapper above (dynamic image-worker loading previously crashed ticketed reads).
@Concurrent
export async function runBrowseSourceOperationTask(requestJson: string, wasmBytes: Uint8Array, httpContextJson: string): Promise<string> {
  const mod: Record<string, Object> = await import('libkoma_source_runtime.so') as Record<string, Object>
  const nativeRuntime = (mod.default ?? mod) as Record<string, Function>
  return nativeRuntime.runJsonCallFromBytes(sourceRequestWithHostFeatures(requestJson,
    sourceRuntimeExecutionHasGuard(httpContextJson), sourceRuntimeExecutionHasDetailChapterContext(httpContextJson)), wasmBytes, httpContextJson,
    sourceRuntimeExecutionSourceId(httpContextJson)) as string
}

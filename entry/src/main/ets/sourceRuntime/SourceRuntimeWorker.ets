import { NativeSourceRuntime } from './NativeSourceRuntime'
import { sourceRequestWithHostFeatures } from './SourceHostFeatures'
import { sourceRuntimeExecutionHasDetailChapterContext, sourceRuntimeExecutionHasGuard, sourceRuntimeExecutionHasRequestLimits,
  sourceRuntimeExecutionManifestUnavailable, UNAVAILABLE_SOURCE_MANIFEST } from './SourceRuntimeExecutionIdentity'

// TaskPool evaluates this module's transitive imports on a worker. Keep this
// entry Native-only: Service/Runner pull in UI state and localization, whose
// decorators fail during worker initialization even when no UI method is called.
// Admission, HTTP identity, diagnostics and source-changed checks stay with the
// calling Service; do not move them here or fall back to blocking the UI thread.
// Browse and detail also call these workers directly. Advertise the Host's pure
// protocol features here so their source settings reach the same Native boundary.
@Concurrent
export function executeSourceRuntimeRequest(requestJson: string, wasmBytes: Uint8Array, httpContextJson: string): string {
  if (sourceRuntimeExecutionManifestUnavailable(httpContextJson)) return UNAVAILABLE_SOURCE_MANIFEST
  return JSON.stringify(NativeSourceRuntime.runJsonCallFromBytes(
    sourceRequestWithHostFeatures(requestJson, sourceRuntimeExecutionHasGuard(httpContextJson),
      sourceRuntimeExecutionHasDetailChapterContext(httpContextJson), sourceRuntimeExecutionHasRequestLimits(httpContextJson)), wasmBytes, httpContextJson))
}

// Browse consumes the raw string. Use the same statically loaded NAPI module
// that the worker already uses for detail and images.
@Concurrent
export function runBrowseSourceOperationTask(requestJson: string, wasmBytes: Uint8Array, httpContextJson: string): string {
  if (sourceRuntimeExecutionManifestUnavailable(httpContextJson)) return UNAVAILABLE_SOURCE_MANIFEST
  return NativeSourceRuntime.runRawJsonCallFromBytes(sourceRequestWithHostFeatures(requestJson,
    sourceRuntimeExecutionHasGuard(httpContextJson), sourceRuntimeExecutionHasDetailChapterContext(httpContextJson), sourceRuntimeExecutionHasRequestLimits(httpContextJson)),
    wasmBytes, httpContextJson)
}

@Concurrent
export function runLocalCoverOperationTask(requestJson: string, wasmBytes: Uint8Array, httpContextJson: string): string {
  if (sourceRuntimeExecutionManifestUnavailable(httpContextJson)) return UNAVAILABLE_SOURCE_MANIFEST
  return NativeSourceRuntime.runRawJsonCallFromBytes(sourceRequestWithHostFeatures(requestJson,
    sourceRuntimeExecutionHasGuard(httpContextJson), sourceRuntimeExecutionHasDetailChapterContext(httpContextJson), sourceRuntimeExecutionHasRequestLimits(httpContextJson)),
    wasmBytes, httpContextJson, true)
}

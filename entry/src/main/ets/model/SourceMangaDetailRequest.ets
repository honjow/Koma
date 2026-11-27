import { MangaDetail, parseMangaDetailFromSourceItem } from './MangaDetailModels'
import { SourceRuntimeError } from './SourceRuntimeError'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { sourceRequestWithHostFeatures } from '../sourceRuntime/SourceHostFeatures'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { diagnoseSourceOperation } from '../sourceRuntime/SourceRuntimeRunner'
import { executeSourceRequestInWorker } from '../sourceRuntime/SourceRuntimeWorkerClient'
import { SourceSettingsRecord } from '../sourceRuntime/SourceSettingsStore'
import { sourceHttpIdentityJson } from '../sourceRuntime/SourceWebSessionStore'
import { configureSourceRequestPolicy } from '../sourceRuntime/SourceRequestPolicy'

interface SourceMangaDetailData {
  manga?: Record<string, Object>
  item?: Record<string, Object>
  items?: Record<string, Object>[]
  chapterContext?: Record<string, Object>
}

interface SourceMangaDetailArgs { mangaId: string; mangaUrl?: string }
interface SourceMangaDetailHints { network: boolean }
interface SourceMangaDetailRequest {
  type: string
  version: number
  requestId: string
  sourceId: string
  operation: string
  args: SourceMangaDetailArgs
  settings: SourceSettingsRecord
  hostHints: SourceMangaDetailHints
}

export interface SourceMangaDetailResponse {
  detail: MangaDetail
  chapterContext?: Record<string, Object>
}

export async function fetchSourceMangaDetail(entry: SourceRuntimeRegistryEntry, mangaId: string,
  mangaUrl: string | undefined, settings: SourceSettingsRecord, requestPurpose: string): Promise<SourceMangaDetailResponse> {
  configureSourceRequestPolicy(entry.requestLimits, settings)
  const payload: SourceMangaDetailRequest = { type: 'request', version: 1,
    requestId: `${requestPurpose}-detail-${entry.sourceId}-${Date.now()}`, sourceId: entry.sourceId, operation: 'get_manga',
    args: { mangaId, mangaUrl }, settings, hostHints: { network: true } }
  const request = sourceRequestWithHostFeatures(JSON.stringify(payload))
  const bytes = new Uint8Array(entry.wasmBytes.byteLength)
  bytes.set(entry.wasmBytes)
  const responseJson = await diagnoseSourceOperation(request, () => executeSourceRequestInWorker(request, bytes,
    sourceHttpIdentityJson(entry, undefined, true, 'get_manga')))
  const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
  if (!response.ok) throw new SourceRuntimeError(response)
  const data = response.data as SourceMangaDetailData | undefined
  const item = data?.manga ?? data?.item ?? data?.items?.[0]
  if (item === undefined) throw new SourceRuntimeError({ ok: false, reasonCode: 'invalid_response' })
  const context = data?.chapterContext
  return { detail: parseMangaDetailFromSourceItem(entry.sourceId, item),
    chapterContext: context !== undefined && context !== null && typeof context === 'object' && !Array.isArray(context)
      ? context : undefined }
}

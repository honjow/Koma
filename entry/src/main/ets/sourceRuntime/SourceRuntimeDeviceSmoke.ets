import { common, Want } from '@kit.AbilityKit'
import { resourceManager } from '@kit.LocalizationKit'
import { taskpool } from '@kit.ArkTS'
import {
  appSourceRuntimeRegistry,
  installFromBytes,
  remove as removeInstalledSourcePackage,
} from './SourceRuntimeAppRegistry'
import {
  SourceIndexEntry,
  SourceIndexService,
} from './SourceIndexService'
import {
  NativeSourceRuntime,
  SourceRuntimeCallResponse,
} from './NativeSourceRuntime'
import {
  Comic,
  ComicSourceKind,
  Page,
  ReadingDirection,
} from '../model/ComicModels'
import {
  OfflineDownloadService,
} from '../model/OfflineDownloadService'
import {
  OfflineDownloadStatus,
  OfflineDownloadStore,
} from '../model/OfflineDownloadStore'
import {
  DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES,
  OfflineDownloadQueueStore,
} from '../model/OfflineDownloadQueueStore'
import {
  ReaderPageRenderKind,
  configureReaderOfflineDownloads,
  createReaderPageRenderSource,
} from '../model/ReaderPageSourceAdapter'
import {
  ReaderSessionConfig,
  createReaderSessionConfigFromComic,
} from '../model/ReaderSessionStore'
import {
  SourceArchiveNegativeCaseFixture,
  SourceArchiveNegativeImportResult,
} from './SourcePackageImporter'
import {
  importAndRegisterLocalSourceArchive,
  importAndRunLocalSourceArchive,
  importArchiveNegativeFixturesWithoutExecution,
  importRegisterPersistReloadAndRunLocalSourceArchiveRequest,
  importRegisterPersistRemovePayloadReloadAndRunLocalSourceArchiveRequest,
  persistReloadAndRunRegisteredSourcesById,
  reloadPersistedSourceInventoryAndRunRequestById,
  runRegisteredSourceApiOperationsById,
  runRegisteredSourceRequestById,
  runStagedRawfileSourcePackage,
  runSourceRuntimeRegistryNegativeEvidence,
  stageAndRegisterRawfileSourcePackage,
  SourceRuntimeServiceArchiveIngestionRunSummary,
  SourceRuntimeServicePersistedInventoryReloadSummary,
  SourceRuntimeServicePersistedPayloadMissingSummary,
  SourceRuntimeServiceRegistrationSummary,
  SourceRuntimeServiceRegistryNegativeSummary,
  SourceRuntimeServiceRegistryReloadSummary,
  SourceRuntimeServiceRunByIdSummary,
  SourceRuntimeServiceRunRequestByIdSummary,
  SourceRuntimeServiceRunSummary,
} from './SourceRuntimeService'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryInstalledSourceSummary,
} from './SourceRuntimeRegistry'
import {
  responseReachedFixture,
  runBundledSourceOperation,
  runSourceApiFixtureOperationsFromBytes,
  runSourceApiV02SurfaceFromBytes,
  runSearchFixtureFromBytes,
  runSourceOperationFromBytes,
  runSourceRuntimeCancelTimeoutNegativesFromBytes,
  runSourceRuntimeSizeLimitNegativesFromBytes,
  SourceRuntimeApiOperationsSummary,
  SourceRuntimeCancelTimeoutNegativeCaseSummary,
  SourceRuntimeCancelTimeoutNegativeSummary,
  SourceRuntimeNegativeExecutionCaseSummary,
  SourceRuntimeSizeLimitNegativeCaseSummary,
  SourceRuntimeSizeLimitNegativeSummary,
  SourceRuntimeV02SurfaceSummary,
} from './SourceRuntimeRunner'

const SMOKE_TRIGGER_PARAM: string = 'koma.sourceRuntimeSmoke'
const SMOKE_TRIGGER_VALUE: string = 'run'
const SMOKE_PHASE_PARAM: string = 'koma.sourceRuntimeSmoke.phase'
const SMOKE_INDEX_URL_PARAM: string = 'koma.sourceRuntimeSmoke.indexUrl'
const SMOKE_SOURCE_ID_PARAM: string = 'koma.sourceRuntimeSmoke.sourceId'
const SMOKE_PHASE_FULL: string = 'full'
const SMOKE_PHASE_SETUP_PERSISTED_INVENTORY: string = 'setup-persisted-inventory'
const SMOKE_PHASE_RELOAD_PERSISTED_INVENTORY: string = 'reload-persisted-inventory'
const SMOKE_PHASE_PERSISTED_PAYLOAD_MISSING: string = 'persisted-payload-missing'
const SMOKE_PHASE_SOURCE_API_V02: string = 'source-api-v02'
const SMOKE_PHASE_SIZE_LIMIT_NEGATIVES: string = 'size-limit-negatives'
const SMOKE_PHASE_CANCEL_TIMEOUT_NEGATIVES: string = 'cancel-timeout-negatives'
const SMOKE_PHASE_REAL_SOURCE_SEARCH: string = 'real-source-search'
const SMOKE_PHASE_REAL_SOURCE_READER: string = 'real-source-reader'
const SMOKE_PHASE_INSTALLED_SOURCE_READER: string = 'installed-source-reader'
const SMOKE_PHASE_SOURCE_INDEX_READER: string = 'source-index-reader'
const SMOKE_PHASE_SOURCE_INDEX_DOWNLOAD_READER: string = 'source-index-download-reader'
const REAL_SOURCE_RAWFILE_PATH: string = 'test/baozimh.wasm'
const MANGADEX_RAWFILE_PATH: string = 'test/mangadex.wasm'
const REAL_SOURCE_SEARCH_REQUEST: string = '{"operation":"search","query":"test"}'
const SOURCE_INDEX_READER_DEFAULT_SOURCE_ID: string = 'online.baozimh.koma'
const SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-smoke"}'
const RUST_SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-rust-smoke"}'
const PACKAGE_SMOKE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-package-smoke"}'
const SMOKE_LOG_PREFIX: string = 'KOMA_SOURCE_RUNTIME_SMOKE_RESULT '
const SMOKE_RAWFILE_PATH: string = 'test/source_runtime_fixture.wasm'
const RUST_SMOKE_RAWFILE_PATH: string = 'test/rust_source_runtime_fixture.wasm'
const PACKAGE_ROUTE_LABEL: string = 'app-local-source-package-test-only'
const ARCHIVE_ROUTE_LABEL: string = 'app-local-source-archive-import-test-only'
const PACKAGE_REGISTRY_ROUTE_LABEL: string = 'app-local-source-package-registry-test-only'
const ARCHIVE_REGISTRY_ROUTE_LABEL: string = 'app-local-source-archive-registry-test-only'
const ARCHIVE_INGESTION_ROUTE_LABEL: string = 'app-local-source-archive-ingestion-run-request-test-only'
const PERSISTED_PAYLOAD_MISSING_ROUTE_LABEL: string = 'app-local-source-persisted-payload-missing-test-only'
const PACKAGE_REGISTRY_SOURCE_ID: string = 'local.test.koma.fixture.package.registry'
const ARCHIVE_REGISTRY_SOURCE_ID: string = 'local.test.koma.fixture.archive.registry'
const ARCHIVE_INGESTION_SOURCE_ID: string = 'local.test.koma.fixture.archive.ingestion'
const PERSISTED_PAYLOAD_MISSING_SOURCE_ID: string = 'local.test.koma.fixture.persisted.payload.missing'
const REGISTRY_RELOAD_METADATA_FILE: string = 'registry-metadata.json'
const REGISTRY_RELOAD_MISSING_METADATA_FILE: string = 'missing-registry-metadata.json'
const REGISTRY_RELOAD_CORRUPT_METADATA_FILE: string = 'corrupt-registry-metadata.json'
const ARCHIVE_INGESTION_METADATA_FILE: string = 'archive-ingestion-registry-metadata.json'
const PERSISTED_PAYLOAD_MISSING_METADATA_FILE: string = 'persisted-payload-missing-registry-metadata.json'
const ARCHIVE_RAWFILE_PATH: string = 'test/local_source_runtime_fixture.koma'
const ARCHIVE_SANDBOX_ZIP_FILE: string = 'local_source_runtime_fixture.koma.zip'
const ARCHIVE_REQUEST_JSON: string = '{"operation":"search","query":"fixture","smoke":"koma-archive-smoke"}'
const INSTALLED_READER_SOURCE_ID: string = 'local.test.koma.fixture'
const ARCHIVE_INGESTION_SEARCH_REQUEST_JSON: string = `{"type":"request","version":1,"requestId":"device-archive-ingestion-search-001","operation":"search","sourceId":"${ARCHIVE_INGESTION_SOURCE_ID}","args":{"query":"fixture","page":{"cursor":null,"limit":20}},"settings":{},"hostHints":{"network":false}}`
const ARCHIVE_INGESTION_NON_SEARCH_REQUEST_JSON: string = `{"type":"request","version":1,"requestId":"device-archive-ingestion-manga-001","operation":"get_manga","sourceId":"${ARCHIVE_INGESTION_SOURCE_ID}","args":{"mangaId":"manga:fixture-series"},"settings":{},"hostHints":{"network":false}}`
const ARCHIVE_NEGATIVE_ROUTE_LABEL: string = 'app-local-source-archive-negative-test-only'
const ARCHIVE_NEGATIVE_CASES: SourceArchiveNegativeCaseFixture[] = [
  {
    id: 'checksum_mismatch',
    rawfilePath: 'test/archive-negative/checksum_mismatch.koma-source',
    expectedReason: 'checksum_mismatch',
  },
  {
    id: 'network_not_allowed',
    rawfilePath: 'test/archive-negative/network_not_allowed.koma-source',
    expectedReason: 'network_not_allowed',
  },
  {
    id: 'unsafe_archive_entry',
    rawfilePath: 'test/archive-negative/unsafe_archive_entry.koma-source',
    expectedReason: 'unsafe_archive_entry',
  },
  {
    id: 'missing_manifest',
    rawfilePath: 'test/archive-negative/missing_manifest.koma-source',
    expectedReason: 'missing_manifest',
  },
  {
    id: 'missing_wasm',
    rawfilePath: 'test/archive-negative/missing_wasm.koma-source',
    expectedReason: 'missing_wasm',
  },
]

type WantParameterValue = Object | string | number | boolean | null | undefined
type WantParameters = Record<string, WantParameterValue>

export interface SourceArchiveNegativeCaseEvidence {
  id: string
  reasonCode?: string
  reasonMatchesExpected: boolean
  attemptedWamrExecution: boolean
}

export interface SourceRuntimeExecutionNegativeCaseEvidence {
  route: string
  id: string
  rejected: boolean
  didNotDefaultToSearch: boolean
  responseOk: boolean
  responseOperation?: string
  responseFirstTitle?: string
  error?: string
}

export interface SourceRuntimeRegistryEntryEvidence {
  sourceId: string
  manifestId: string
  manifestVersion: string
  route: string
  importStatus: string
  wasmBytes: number
  hashOk: boolean
  network: boolean
  validationEvidence: string[]
}

export interface SourceRuntimeRunRequestByIdEvidence {
  sourceId: string
  operation?: string
  ok: boolean
  responseOk: boolean
  reasonCode?: string
  attemptedWamrExecution: boolean
}

export interface SourceRuntimeSizeLimitNegativeCaseEvidence {
  id: string
  rejected: boolean
  reasonCode?: string
  attemptedWamrExecution: boolean
  requestBytes?: number
  resultBytes?: number
  noRawPayloadOrPathLeak: boolean
}

export interface SourceRuntimeCancelTimeoutNegativeCaseEvidence {
  id: string
  rejected: boolean
  reasonCode?: string
  attemptedWamrExecution: boolean
  noRawPayloadOrPathLeak: boolean
}

export interface SourceRuntimeSmokeResult {
  ok: boolean
  route: string
  smokePhase?: string
  nativeHelloOk?: boolean
  nativeAddOk?: boolean
  requestJson: string
  rawfilePath?: string
  rawfileBytes?: number
  rustRequestJson?: string
  rustRawfilePath?: string
  rustRawfileBytes?: number
  response?: SourceRuntimeCallResponse
  responseOk?: boolean
  resourceResponse?: SourceRuntimeCallResponse
  resourceResponseOk?: boolean
  rustSourceResponse?: SourceRuntimeCallResponse
  rustSourceResponseOk?: boolean
  rustSourceApiOperationsOk?: boolean
  rustSourceApiOperations?: SourceRuntimeApiOperationsSummary
  sourceApiV02Ok?: boolean
  sourceApiV02SourceInfoOk?: boolean
  sourceApiV02CoreOpsOk?: boolean
  sourceApiV02BrowseOpsOk?: boolean
  sourceApiV02SettingsImageRefsOk?: boolean
  sourceApiV02NetworkFalse?: boolean
  sourceApiV02NoSecretOrPathLeak?: boolean
  sourceApiV02Operations?: string[]
  sourceApiV02UnsupportedOperations?: string[]
  sourceApiV02Evidence?: string[]
  packageResponse?: SourceRuntimeCallResponse
  packageResponseOk?: boolean
  packageSourceApiOperationsOk?: boolean
  packageSourceApiOperations?: SourceRuntimeApiOperationsSummary
  packageOperation?: string
  packageRequestEcho?: string
  packageFirstTitle?: string
  packageNetwork?: boolean
  packageWasmBytes?: number
  packageManifestId?: string
  packageManifestVersion?: string
  packageManifestPath?: string
  packageWasmPath?: string
  packageHashOk?: boolean
  packageRoute?: string
  archiveRoute?: string
  archiveRawfilePath?: string
  archivePath?: string
  archiveImportOk?: boolean
  archiveResponse?: SourceRuntimeCallResponse
  archiveResponseOk?: boolean
  archiveSourceApiOperationsOk?: boolean
  archiveSourceApiOperations?: SourceRuntimeApiOperationsSummary
  archiveOperation?: string
  archiveRequestEcho?: string
  archiveFirstTitle?: string
  archiveNetwork?: boolean
  archiveWasmBytes?: number
  archiveManifestId?: string
  archiveManifestVersion?: string
  archiveManifestPath?: string
  archiveImportedWasmPath?: string
  archiveHashOk?: boolean
  archiveNegativeRoute?: string
  archiveNegativeOk?: boolean
  archiveNegativeCases?: SourceArchiveNegativeCaseEvidence[]
  sourceRuntimeExecutionNegativeOk?: boolean
  sourceRuntimeExecutionNegativeCases?: SourceRuntimeExecutionNegativeCaseEvidence[]
  sourceRuntimeExecutionNegativeCaseCount?: number
  sourceRuntimeRegistryOk?: boolean
  sourceRuntimeRegistrySourceCount?: number
  sourceRuntimeRegistryPackageSourceId?: string
  sourceRuntimeRegistryArchiveSourceId?: string
  sourceRuntimeRegistryPackageEntry?: SourceRuntimeRegistryEntryEvidence
  sourceRuntimeRegistryArchiveEntry?: SourceRuntimeRegistryEntryEvidence
  sourceRuntimeRegistryPackageRunByIdOk?: boolean
  sourceRuntimeRegistryPackageRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryArchiveRunByIdOk?: boolean
  sourceRuntimeRegistryArchiveRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryDuplicateRejected?: boolean
  sourceRuntimeRegistryDuplicateReasonCode?: string
  sourceRuntimeRegistryMissingSourceIdRejected?: boolean
  sourceRuntimeRegistryMissingSourceIdReasonCode?: string
  sourceRuntimeRegistryInvalidRunRejected?: boolean
  sourceRuntimeRegistryInvalidRunReasonCode?: string
  sourceRuntimeRegistryReloadOk?: boolean
  sourceRuntimeRegistryReloadMetadataPath?: string
  sourceRuntimeRegistryPersistedSourceCount?: number
  sourceRuntimeRegistryReloadedSourceCount?: number
  sourceRuntimeRegistryPackageReloadRunByIdOk?: boolean
  sourceRuntimeRegistryPackageReloadRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryArchiveReloadRunByIdOk?: boolean
  sourceRuntimeRegistryArchiveReloadRunByIdOperations?: SourceRuntimeApiOperationsSummary
  sourceRuntimeRegistryReloadNegativeRejected?: boolean
  sourceRuntimeRegistryReloadNegativeReasonCode?: string
  sourceRuntimeRegistryReloadNegativeAttemptedWamrExecution?: boolean
  sourceRuntimeRegistryReloadCorruptMetadataRejected?: boolean
  sourceRuntimeRegistryReloadCorruptMetadataReasonCode?: string
  sourceRuntimeRegistryReloadCorruptMetadataAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdOk?: boolean
  sourceRuntimeRunRequestByIdPackageSearchOk?: boolean
  sourceRuntimeRunRequestByIdPackageSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeRunRequestByIdArchiveSearchOk?: boolean
  sourceRuntimeRunRequestByIdArchiveSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeRunRequestByIdNonSearchOk?: boolean
  sourceRuntimeRunRequestByIdNonSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeRunRequestByIdUnknownSourceRejected?: boolean
  sourceRuntimeRunRequestByIdUnknownSourceReasonCode?: string
  sourceRuntimeRunRequestByIdUnknownSourceAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdSourceIdMismatchRejected?: boolean
  sourceRuntimeRunRequestByIdSourceIdMismatchReasonCode?: string
  sourceRuntimeRunRequestByIdSourceIdMismatchAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdMalformedRejected?: boolean
  sourceRuntimeRunRequestByIdMalformedReasonCode?: string
  sourceRuntimeRunRequestByIdMalformedAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdNullRequestRejected?: boolean
  sourceRuntimeRunRequestByIdNullRequestReasonCode?: string
  sourceRuntimeRunRequestByIdNullRequestAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdArrayRequestRejected?: boolean
  sourceRuntimeRunRequestByIdArrayRequestReasonCode?: string
  sourceRuntimeRunRequestByIdArrayRequestAttemptedWamrExecution?: boolean
  sourceRuntimeRunRequestByIdMissingOperationRejected?: boolean
  sourceRuntimeRunRequestByIdMissingOperationReasonCode?: string
  sourceRuntimeRunRequestByIdMissingOperationAttemptedWamrExecution?: boolean
  sourceRuntimeArchiveIngestionRunRequestOk?: boolean
  sourceRuntimeArchiveIngestionImportRegisterOk?: boolean
  sourceRuntimeArchiveIngestionPersistReloadOk?: boolean
  sourceRuntimeArchiveIngestionSourceId?: string
  sourceRuntimeArchiveIngestionRoute?: string
  sourceRuntimeArchiveIngestionMetadataPath?: string
  sourceRuntimeArchiveIngestionPersistedSourceCount?: number
  sourceRuntimeArchiveIngestionReloadedSourceCount?: number
  sourceRuntimeArchiveIngestionHashOk?: boolean
  sourceRuntimeArchiveIngestionNetwork?: boolean
  sourceRuntimeInstalledSourceInventoryOk?: boolean
  sourceRuntimeInstalledSourceInventory?: SourceRuntimeRegistryInstalledSourceSummary[]
  sourceRuntimeInstalledSourceInventoryExpectedSourceIdCount?: number
  sourceRuntimeInstalledSourceInventoryExpectedSourceIdPresentOnce?: boolean
  sourceRuntimeInstalledSourceInventorySafeFieldsOk?: boolean
  sourceRuntimeInstalledSourceInventoryNoRawPathLeak?: boolean
  sourceRuntimeInstalledSourceInventoryNoFullManifestLeak?: boolean
  sourceRuntimeInstalledSourceInventoryNoWasmBytesLeak?: boolean
  sourceRuntimeInstalledSourceInventorySelectedSourceId?: string
  sourceRuntimeInstalledSourceInventorySelectedRunRequestOk?: boolean
  sourceRuntimeInstalledSourceInventorySelectedRunRequest?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimePersistedInventoryRestartOk?: boolean
  sourceRuntimePersistedInventoryRestartSetupOk?: boolean
  sourceRuntimePersistedInventoryRestartReloadOnlyOk?: boolean
  sourceRuntimePersistedInventoryRestartMetadataWrittenOk?: boolean
  sourceRuntimePersistedInventoryRestartMetadataReloadedOk?: boolean
  sourceRuntimePersistedInventoryRestartReloadOnlyDidNotImportArchive?: boolean
  sourceRuntimePersistedInventoryRestartReloadedSourceCount?: number
  sourceRuntimePersistedInventoryRestartPhase?: string
  sourceRuntimePersistedPayloadMissingOk?: boolean
  sourceRuntimePersistedPayloadMissingImportRegisterOk?: boolean
  sourceRuntimePersistedPayloadMissingMetadataWrittenOk?: boolean
  sourceRuntimePersistedPayloadMissingMutationApplied?: boolean
  sourceRuntimePersistedPayloadMissingMetadataReloadRejected?: boolean
  sourceRuntimePersistedPayloadMissingReasonCode?: string
  sourceRuntimePersistedPayloadMissingReloadOnlyDidNotImportArchive?: boolean
  sourceRuntimePersistedPayloadMissingAttemptedWamrExecution?: boolean
  sourceRuntimePersistedPayloadMissingRunRejected?: boolean
  sourceRuntimePersistedPayloadMissingRunRequest?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeSizeLimitNegativesOk?: boolean
  sourceRuntimeOversizedRequestRejected?: boolean
  sourceRuntimeOversizedRequestReasonCode?: string
  sourceRuntimeOversizedRequestAttemptedWamrExecution?: boolean
  sourceRuntimeOversizedResultRejected?: boolean
  sourceRuntimeOversizedResultReasonCode?: string
  sourceRuntimeOversizedResultAttemptedWamrExecution?: boolean
  sourceRuntimeMalformedResultRejected?: boolean
  sourceRuntimeMalformedResultReasonCode?: string
  sourceRuntimeMalformedResultAttemptedWamrExecution?: boolean
  sourceRuntimeSizeLimitStableReasonCodes?: string[]
  sourceRuntimeSizeLimitNoRawPayloadOrPathLeak?: boolean
  sourceRuntimeSizeLimitNegativeCases?: SourceRuntimeSizeLimitNegativeCaseEvidence[]
  sourceRuntimeCancelTimeoutNegativesOk?: boolean
  sourceRuntimeCancelledGuardRejected?: boolean
  sourceRuntimeCancelledGuardReasonCode?: string
  sourceRuntimeCancelledGuardAttemptedWamrExecution?: boolean
  sourceRuntimeTimeoutGuardRejected?: boolean
  sourceRuntimeTimeoutGuardReasonCode?: string
  sourceRuntimeTimeoutGuardAttemptedWamrExecution?: boolean
  sourceRuntimeCancelTimeoutStableReasonCodes?: string[]
  sourceRuntimeCancelTimeoutNoRawPayloadOrPathLeak?: boolean
  sourceRuntimeCancelTimeoutNegativeCases?: SourceRuntimeCancelTimeoutNegativeCaseEvidence[]
  sourceRuntimeArchiveIngestionSearchOk?: boolean
  sourceRuntimeArchiveIngestionSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeArchiveIngestionNonSearchOk?: boolean
  sourceRuntimeArchiveIngestionNonSearch?: SourceRuntimeRunRequestByIdEvidence
  sourceRuntimeArchiveIngestionUnknownSourceRejected?: boolean
  sourceRuntimeArchiveIngestionUnknownSourceReasonCode?: string
  sourceRuntimeArchiveIngestionUnknownSourceAttemptedWamrExecution?: boolean
  sourceRuntimeArchiveIngestionSourceIdMismatchRejected?: boolean
  sourceRuntimeArchiveIngestionSourceIdMismatchReasonCode?: string
  sourceRuntimeArchiveIngestionSourceIdMismatchAttemptedWamrExecution?: boolean
  realSourceWasmBytes?: number
  realSourceResponse?: SourceRuntimeCallResponse
  realSourceReaderMangaId?: string
  realSourceReaderChapterId?: string
  realSourceReaderSearchCount?: number
  realSourceReaderChapterCount?: number
  realSourceReaderPageCount?: number
  realSourceReaderDetailOk?: boolean
  realSourceReaderChaptersOk?: boolean
  realSourceReaderPagesOk?: boolean
  installedSourceReaderInstallOk?: boolean
  installedSourceReaderSourceId?: string
  installedSourceReaderSearchOk?: boolean
  installedSourceReaderDetailOk?: boolean
  installedSourceReaderChaptersOk?: boolean
  installedSourceReaderPagesOk?: boolean
  installedSourceReaderMangaId?: string
  installedSourceReaderChapterId?: string
  installedSourceReaderPageId?: string
  installedSourceReaderSearchCount?: number
  installedSourceReaderChapterCount?: number
  installedSourceReaderPageCount?: number
  installedSourceReaderRenderSourceOk?: boolean
  installedSourceReaderRenderKind?: string
  installedSourceReaderRenderHasSourceRuntimeId?: boolean
  installedSourceReaderRenderHasPageId?: boolean
  installedSourceReaderCleanupOk?: boolean
  sourceIndexReaderIndexUrlProvided?: boolean
  sourceIndexReaderFetchOk?: boolean
  sourceIndexReaderEntryCount?: number
  sourceIndexReaderSelectedSourceId?: string
  sourceIndexReaderInstallOk?: boolean
  sourceIndexReaderWasmBytes?: number
  sourceIndexReaderSearchOk?: boolean
  sourceIndexReaderSearchCount?: number
  sourceIndexReaderMangaId?: string
  sourceIndexReaderDetailOk?: boolean
  sourceIndexReaderChaptersOk?: boolean
  sourceIndexReaderChapterCount?: number
  sourceIndexReaderChapterId?: string
  sourceIndexReaderPagesOk?: boolean
  sourceIndexReaderPageCount?: number
  sourceIndexReaderPageId?: string
  sourceIndexReaderRenderSourceOk?: boolean
  sourceIndexDownloadOk?: boolean
  sourceIndexDownloadStatus?: string
  sourceIndexDownloadPageCount?: number
  sourceIndexDownloadDownloadedPageCount?: number
  sourceIndexDownloadOfflineReaderOk?: boolean
  sourceIndexDownloadOfflineReaderKind?: string
  sourceIndexDownloadCleanupOk?: boolean
  sourceIndexReaderCleanupOk?: boolean
  mangadexWasmBytes?: number
  mangadexResponse?: SourceRuntimeCallResponse
  error?: string
}

@Concurrent
async function runRealSourceSearchTask(requestJson: string, wasmBytes: Uint8Array): Promise<string> {
  const mod: Record<string, Object> = await import('libkoma_source_runtime.so') as Record<string, Object>
  const nativeRuntime = (mod.default ?? mod) as Record<string, Function>
  return nativeRuntime.runJsonCallFromBytes(requestJson, wasmBytes) as string
}

function responseDataRecord(response: SourceRuntimeCallResponse): Record<string, Object> {
  return (response.data ?? {}) as Record<string, Object>
}

function responseItems(response: SourceRuntimeCallResponse): Record<string, Object>[] {
  const items = responseDataRecord(response)['items']
  return Array.isArray(items) ? items as Record<string, Object>[] : []
}

function responseChapters(response: SourceRuntimeCallResponse): Record<string, Object>[] {
  const data = responseDataRecord(response)
  const chapters = data['chapters']
  if (Array.isArray(chapters)) {
    return chapters as Record<string, Object>[]
  }
  const items = data['items']
  return Array.isArray(items) ? items as Record<string, Object>[] : []
}

function responsePages(response: SourceRuntimeCallResponse): Record<string, Object>[] {
  const pages = responseDataRecord(response)['pages']
  return Array.isArray(pages) ? pages as Record<string, Object>[] : []
}

function firstStringField(rows: Record<string, Object>[], field: string): string {
  if (rows.length === 0) {
    return ''
  }
  const value = rows[0][field]
  return typeof value === 'string' ? value : ''
}

function sourcePageImageUrl(page: Record<string, Object>): string {
  const directUrl = firstStringField([page], 'url') || firstStringField([page], 'uri')
  if (directUrl.length > 0) {
    return directUrl
  }
  const image = page['image']
  if (image === undefined || typeof image !== 'object' || Array.isArray(image)) {
    return ''
  }
  const imageRecord = image as Record<string, Object>
  return firstStringField([imageRecord], 'url') || firstStringField([imageRecord], 'uri')
}

function copySmokeWasmBytes(bytes: Uint8Array): Uint8Array {
  const copy = new Uint8Array(bytes.byteLength)
  copy.set(bytes)
  return copy
}

function sourceRuntimeRequest(sourceId: string, operation: string, args: string, requestId: string): string {
  return `{"type":"request","version":1,"requestId":"${requestId}","operation":"${operation}","sourceId":"${sourceId}","args":${args},"settings":{},"hostHints":{"network":false,"imageStrategy":"descriptor-only"}}`
}

function pageImageDimension(page: Record<string, Object>, field: string): number | undefined {
  const image = page['image']
  if (image === undefined || typeof image !== 'object' || Array.isArray(image)) {
    return undefined
  }
  const value = (image as Record<string, Object>)[field]
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function sourcePageRowsToComic(
  selectedSourceId: string,
  mangaId: string,
  chapterId: string,
  pages: Record<string, Object>[],
): Comic {
  const now = Date.now()
  const comicId = `source-index-download-smoke:${selectedSourceId}:${mangaId}`
  const chapterPages: Page[] = pages.map((page: Record<string, Object>, index: number): Page => {
    const pageId = firstStringField([page], 'id') || `${chapterId}:page:${index + 1}`
    return {
      id: pageId,
      comicId,
      chapterId,
      index,
      fileName: `source-page-${index + 1}`,
      uri: sourcePageImageUrl(page),
      sortKey: `${index}`.padStart(6, '0'),
      width: pageImageDimension(page, 'width'),
      height: pageImageDimension(page, 'height'),
    }
  })
  return {
    id: comicId,
    title: 'Source Index Download Smoke',
    sourceKind: ComicSourceKind.PRIVATE_LIBRARY,
    sourcePath: `source://${selectedSourceId}/${mangaId}`,
    sourceRuntimeId: selectedSourceId,
    remoteResourceId: mangaId,
    sortTitle: 'source index download smoke',
    preferredDirection: ReadingDirection.RIGHT_TO_LEFT,
    chapters: [
      {
        id: chapterId,
        comicId,
        title: 'Chapter',
        index: 0,
        sourcePath: `source://${selectedSourceId}/${chapterId}`,
        sortKey: '000000',
        pages: chapterPages,
        pageCount: chapterPages.length,
        createdAt: now,
        updatedAt: now,
      },
    ],
    chapterCount: 1,
    pageCount: chapterPages.length,
    createdAt: now,
    updatedAt: now,
    lastImportedAt: now,
  }
}

function joinSourceRuntimeSmokePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
}

function wantParameters(want: Want): WantParameters {
  const rawParameters = want.parameters as WantParameters | undefined
  return rawParameters === undefined ? {} : rawParameters
}

function hasSmokeTrigger(want: Want): boolean {
  const parameters = wantParameters(want)
  return parameters[SMOKE_TRIGGER_PARAM] === SMOKE_TRIGGER_VALUE
}

function smokePhase(want: Want): string {
  const parameters = wantParameters(want)
  const phase = parameters[SMOKE_PHASE_PARAM]
  return typeof phase === 'string' && phase.length > 0 ? phase : SMOKE_PHASE_FULL
}

function smokeStringParam(want: Want, name: string): string {
  const value = wantParameters(want)[name]
  return typeof value === 'string' ? value.trim() : ''
}

function applyPackageServiceSummary(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunSummary,
): void {
  result.packageResponseOk = summary.responseOk
  result.packageSourceApiOperationsOk = summary.sourceApiOperationsOk
  result.packageSourceApiOperations = compactSourceApiOperations(summary.sourceApiOperations)
  result.packageOperation = summary.operation
  result.packageRequestEcho = summary.requestEcho
  result.packageFirstTitle = summary.firstTitle
  result.packageNetwork = summary.network
  result.packageWasmBytes = summary.wasmBytes
  result.packageManifestId = summary.manifestId
  result.packageManifestVersion = summary.manifestVersion
  result.packageHashOk = summary.hashOk
  result.packageRoute = summary.route
  appendSourceRuntimeExecutionNegativeCases(result, summary)
}

function applyArchiveServiceSummary(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunSummary,
): void {
  result.archiveResponseOk = summary.responseOk
  result.archiveSourceApiOperationsOk = summary.sourceApiOperationsOk
  result.archiveSourceApiOperations = compactSourceApiOperations(summary.sourceApiOperations)
  result.archiveOperation = summary.operation
  result.archiveRequestEcho = summary.requestEcho
  result.archiveFirstTitle = summary.firstTitle
  result.archiveNetwork = summary.network
  result.archiveWasmBytes = summary.wasmBytes
  result.archiveManifestId = summary.manifestId
  result.archiveManifestVersion = summary.manifestVersion
  result.archiveHashOk = summary.hashOk
  result.archiveImportOk = summary.importStatus === 'imported'
  result.archiveRoute = summary.route
  appendSourceRuntimeExecutionNegativeCases(result, summary)
}

function compactSourceApiOperations(summary: SourceRuntimeApiOperationsSummary): SourceRuntimeApiOperationsSummary {
  return {
    ok: summary.ok,
    operations: summary.operations,
    evidence: [],
  }
}

function applySourceApiV02Evidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeV02SurfaceSummary,
): void {
  result.sourceApiV02Ok = summary.ok
  result.sourceApiV02SourceInfoOk = summary.sourceInfoOk
  result.sourceApiV02CoreOpsOk = summary.coreOpsOk
  result.sourceApiV02BrowseOpsOk = summary.browseOpsOk
  result.sourceApiV02SettingsImageRefsOk = summary.settingsImageRefsOk
  result.sourceApiV02NetworkFalse = summary.networkFalse
  result.sourceApiV02NoSecretOrPathLeak = summary.noSecretOrPathLeak
  result.sourceApiV02Operations = summary.operations
  result.sourceApiV02UnsupportedOperations = summary.unsupportedOperations
  result.sourceApiV02Evidence = summary.evidence
}

function compactSizeLimitNegativeCase(
  summary: SourceRuntimeSizeLimitNegativeCaseSummary,
): SourceRuntimeSizeLimitNegativeCaseEvidence {
  return {
    id: summary.id,
    rejected: summary.rejected,
    reasonCode: summary.reasonCode,
    attemptedWamrExecution: summary.attemptedWamrExecution,
    requestBytes: summary.requestBytes,
    resultBytes: summary.resultBytes,
    noRawPayloadOrPathLeak: summary.noRawPayloadOrPathLeak,
  }
}

function compactCancelTimeoutNegativeCase(
  summary: SourceRuntimeCancelTimeoutNegativeCaseSummary,
): SourceRuntimeCancelTimeoutNegativeCaseEvidence {
  return {
    id: summary.id,
    rejected: summary.rejected,
    reasonCode: summary.reasonCode,
    attemptedWamrExecution: summary.attemptedWamrExecution,
    noRawPayloadOrPathLeak: summary.noRawPayloadOrPathLeak,
  }
}

function applySizeLimitNegativeEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeSizeLimitNegativeSummary,
): void {
  result.sourceRuntimeSizeLimitNegativesOk = summary.ok
  result.sourceRuntimeOversizedRequestRejected = summary.oversizedRequest.rejected
  result.sourceRuntimeOversizedRequestReasonCode = summary.oversizedRequest.reasonCode
  result.sourceRuntimeOversizedRequestAttemptedWamrExecution = summary.oversizedRequest.attemptedWamrExecution
  result.sourceRuntimeOversizedResultRejected = summary.oversizedResult.rejected
  result.sourceRuntimeOversizedResultReasonCode = summary.oversizedResult.reasonCode
  result.sourceRuntimeOversizedResultAttemptedWamrExecution = summary.oversizedResult.attemptedWamrExecution
  result.sourceRuntimeMalformedResultRejected = summary.malformedResult.rejected
  result.sourceRuntimeMalformedResultReasonCode = summary.malformedResult.reasonCode
  result.sourceRuntimeMalformedResultAttemptedWamrExecution = summary.malformedResult.attemptedWamrExecution
  result.sourceRuntimeSizeLimitStableReasonCodes = summary.stableReasonCodes
  result.sourceRuntimeSizeLimitNoRawPayloadOrPathLeak = summary.noRawPayloadOrPathLeak
  result.sourceRuntimeSizeLimitNegativeCases = [
    compactSizeLimitNegativeCase(summary.oversizedRequest),
    compactSizeLimitNegativeCase(summary.oversizedResult),
    compactSizeLimitNegativeCase(summary.malformedResult),
  ]
}

function applyCancelTimeoutNegativeEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeCancelTimeoutNegativeSummary,
): void {
  result.sourceRuntimeCancelTimeoutNegativesOk = summary.ok
  result.sourceRuntimeCancelledGuardRejected = summary.cancelled.rejected
  result.sourceRuntimeCancelledGuardReasonCode = summary.cancelled.reasonCode
  result.sourceRuntimeCancelledGuardAttemptedWamrExecution = summary.cancelled.attemptedWamrExecution
  result.sourceRuntimeTimeoutGuardRejected = summary.timeout.rejected
  result.sourceRuntimeTimeoutGuardReasonCode = summary.timeout.reasonCode
  result.sourceRuntimeTimeoutGuardAttemptedWamrExecution = summary.timeout.attemptedWamrExecution
  result.sourceRuntimeCancelTimeoutStableReasonCodes = summary.stableReasonCodes
  result.sourceRuntimeCancelTimeoutNoRawPayloadOrPathLeak = summary.noRawPayloadOrPathLeak
  result.sourceRuntimeCancelTimeoutNegativeCases = [
    compactCancelTimeoutNegativeCase(summary.cancelled),
    compactCancelTimeoutNegativeCase(summary.timeout),
  ]
}

function compactRegistryEntry(summary: SourceRuntimeServiceRegistrationSummary): SourceRuntimeRegistryEntryEvidence | undefined {
  if (!summary.ok || summary.entry === undefined) {
    return undefined
  }
  return {
    sourceId: summary.entry.sourceId,
    manifestId: summary.entry.manifestId,
    manifestVersion: summary.entry.manifestVersion,
    route: summary.entry.route,
    importStatus: summary.entry.importStatus,
    wasmBytes: summary.entry.wasmByteCount,
    hashOk: summary.entry.hashOk,
    network: summary.entry.network,
    validationEvidence: [],
  }
}

function appendSourceRuntimeExecutionNegativeCases(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunSummary,
): void {
  const existing = result.sourceRuntimeExecutionNegativeCases ?? []
  const nextCases = summary.sourceRuntimeExecutionNegativeCases.cases.map(
    (item: SourceRuntimeNegativeExecutionCaseSummary) => {
      const evidence: SourceRuntimeExecutionNegativeCaseEvidence = {
        route: summary.route,
        id: item.id,
        rejected: item.rejected,
        didNotDefaultToSearch: item.didNotDefaultToSearch,
        responseOk: item.responseOk,
        responseOperation: item.responseOperation,
        responseFirstTitle: item.responseFirstTitle,
        error: item.error,
      }
      return evidence
    },
  )
  const combined = existing.concat(nextCases)
  result.sourceRuntimeExecutionNegativeCaseCount = combined.length
  result.sourceRuntimeExecutionNegativeOk =
    (result.sourceRuntimeExecutionNegativeOk !== false) &&
      summary.sourceRuntimeExecutionNegativeOk &&
      combined.length >= 3 &&
      combined.every((item: SourceRuntimeExecutionNegativeCaseEvidence) =>
        item.rejected && item.didNotDefaultToSearch && item.responseOk === false)
}

function runLocalSourcePackageSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): void {
  const summary = runStagedRawfileSourcePackage(
    context,
    resourceMgr,
    RUST_SMOKE_RAWFILE_PATH,
    'source-runtime-package-smoke',
    PACKAGE_SMOKE_REQUEST_JSON,
    PACKAGE_ROUTE_LABEL,
  )
  applyPackageServiceSummary(result, summary)
}

async function runLocalSourceArchiveSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): Promise<void> {
  const summary = await importAndRunLocalSourceArchive(
    context,
    resourceMgr,
    ARCHIVE_RAWFILE_PATH,
    'source-runtime-archive-smoke',
    ARCHIVE_SANDBOX_ZIP_FILE,
    ARCHIVE_REQUEST_JSON,
    ARCHIVE_ROUTE_LABEL,
  )
  applyArchiveServiceSummary(result, summary)
}

async function runSourceRuntimeRegistrySmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): Promise<void> {
  const registry = new SourceRuntimeRegistry()
  const packageRegistered = stageAndRegisterRawfileSourcePackage(
    registry,
    context,
    resourceMgr,
    RUST_SMOKE_RAWFILE_PATH,
    'source-runtime-package-registry-smoke',
    PACKAGE_REGISTRY_SOURCE_ID,
    PACKAGE_REGISTRY_ROUTE_LABEL,
  )
  const archiveRegistered = await importAndRegisterLocalSourceArchive(
    registry,
    context,
    resourceMgr,
    ARCHIVE_RAWFILE_PATH,
    'source-runtime-archive-registry-smoke',
    'local_source_runtime_registry_fixture.zip',
    ARCHIVE_REGISTRY_SOURCE_ID,
    ARCHIVE_REGISTRY_ROUTE_LABEL,
  )
  const packageRunById = runRegisteredSourceApiOperationsById(registry, PACKAGE_REGISTRY_SOURCE_ID)
  const archiveRunById = runRegisteredSourceApiOperationsById(registry, ARCHIVE_REGISTRY_SOURCE_ID)
  const metadataRoot = joinSourceRuntimeSmokePath(context.filesDir, 'source-runtime-registry-reload-smoke')
  const reloadSummary = persistReloadAndRunRegisteredSourcesById(
    registry,
    joinSourceRuntimeSmokePath(metadataRoot, REGISTRY_RELOAD_METADATA_FILE),
    joinSourceRuntimeSmokePath(metadataRoot, REGISTRY_RELOAD_MISSING_METADATA_FILE),
    joinSourceRuntimeSmokePath(metadataRoot, REGISTRY_RELOAD_CORRUPT_METADATA_FILE),
    PACKAGE_REGISTRY_SOURCE_ID,
    ARCHIVE_REGISTRY_SOURCE_ID,
  )
  result.sourceRuntimeRegistrySourceCount = registry.count()
  result.sourceRuntimeRegistryPackageSourceId = PACKAGE_REGISTRY_SOURCE_ID
  result.sourceRuntimeRegistryArchiveSourceId = ARCHIVE_REGISTRY_SOURCE_ID
  result.sourceRuntimeRegistryPackageEntry = compactRegistryEntry(packageRegistered)
  result.sourceRuntimeRegistryArchiveEntry = compactRegistryEntry(archiveRegistered)
  applyRunByIdEvidence(result, packageRunById, true)
  applyRunByIdEvidence(result, archiveRunById, false)
  applyRegistryReloadEvidence(result, reloadSummary)
  if (packageRegistered.entry !== undefined) {
    const negative = runSourceRuntimeRegistryNegativeEvidence(registry, packageRegistered.entry)
    applyRegistryNegativeEvidence(result, negative)
  }
  result.sourceRuntimeRegistryOk = packageRegistered.ok &&
    archiveRegistered.ok &&
    result.sourceRuntimeRegistrySourceCount >= 2 &&
    result.sourceRuntimeRegistryPackageEntry !== undefined &&
    result.sourceRuntimeRegistryArchiveEntry !== undefined &&
    result.sourceRuntimeRegistryPackageRunByIdOk === true &&
    result.sourceRuntimeRegistryArchiveRunByIdOk === true &&
    result.sourceRuntimeRegistryDuplicateRejected === true &&
    result.sourceRuntimeRegistryMissingSourceIdRejected === true &&
    result.sourceRuntimeRegistryInvalidRunRejected === true &&
    result.sourceRuntimeRegistryReloadOk === true &&
    result.sourceRuntimeRunRequestByIdOk === true
}

async function runSourceRuntimeArchiveIngestionSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): Promise<void> {
  const metadataRoot = joinSourceRuntimeSmokePath(context.filesDir, 'source-runtime-archive-ingestion-smoke')
  const summary = await importRegisterPersistReloadAndRunLocalSourceArchiveRequest(
    context,
    resourceMgr,
    ARCHIVE_RAWFILE_PATH,
    'source-runtime-archive-ingestion-smoke',
    'local_source_runtime_ingestion_fixture.zip',
    joinSourceRuntimeSmokePath(metadataRoot, ARCHIVE_INGESTION_METADATA_FILE),
    ARCHIVE_INGESTION_SOURCE_ID,
    ARCHIVE_INGESTION_ROUTE_LABEL,
    ARCHIVE_INGESTION_SEARCH_REQUEST_JSON,
    ARCHIVE_INGESTION_NON_SEARCH_REQUEST_JSON,
  )
  applyArchiveIngestionEvidence(result, summary)
}

function runSourceRuntimePersistedInventoryReloadSmoke(
  context: common.UIAbilityContext,
  result: SourceRuntimeSmokeResult,
): void {
  const metadataRoot = joinSourceRuntimeSmokePath(context.filesDir, 'source-runtime-archive-ingestion-smoke')
  const summary = reloadPersistedSourceInventoryAndRunRequestById(
    joinSourceRuntimeSmokePath(metadataRoot, ARCHIVE_INGESTION_METADATA_FILE),
    ARCHIVE_INGESTION_SOURCE_ID,
    ARCHIVE_INGESTION_ROUTE_LABEL,
    ARCHIVE_INGESTION_SEARCH_REQUEST_JSON,
    ARCHIVE_INGESTION_NON_SEARCH_REQUEST_JSON,
  )
  applyPersistedInventoryReloadEvidence(result, summary)
}

async function runSourceRuntimePersistedPayloadMissingSmoke(
  context: common.UIAbilityContext,
  resourceMgr: resourceManager.ResourceManager,
  result: SourceRuntimeSmokeResult,
): Promise<void> {
  const metadataRoot = joinSourceRuntimeSmokePath(context.filesDir, 'source-runtime-persisted-payload-missing-smoke')
  const searchRequestJson = `{"type":"request","version":1,"requestId":"device-persisted-payload-missing-search-001","operation":"search","sourceId":"${PERSISTED_PAYLOAD_MISSING_SOURCE_ID}","args":{"query":"fixture","page":{"cursor":null,"limit":20}},"settings":{},"hostHints":{"network":false}}`
  const summary = await importRegisterPersistRemovePayloadReloadAndRunLocalSourceArchiveRequest(
    context,
    resourceMgr,
    ARCHIVE_RAWFILE_PATH,
    'source-runtime-persisted-payload-missing-smoke',
    'local_source_runtime_persisted_payload_missing_fixture.zip',
    joinSourceRuntimeSmokePath(metadataRoot, PERSISTED_PAYLOAD_MISSING_METADATA_FILE),
    PERSISTED_PAYLOAD_MISSING_SOURCE_ID,
    PERSISTED_PAYLOAD_MISSING_ROUTE_LABEL,
    searchRequestJson,
  )
  applyPersistedPayloadMissingEvidence(result, summary)
}

function applyRunByIdEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRunByIdSummary,
  isPackage: boolean,
): void {
  if (isPackage) {
    result.sourceRuntimeRegistryPackageRunByIdOk = summary.ok && summary.sourceApiOperationsOk
    result.sourceRuntimeRegistryPackageRunByIdOperations = compactSourceApiOperations(summary.sourceApiOperations)
    return
  }
  result.sourceRuntimeRegistryArchiveRunByIdOk = summary.ok && summary.sourceApiOperationsOk
  result.sourceRuntimeRegistryArchiveRunByIdOperations = compactSourceApiOperations(summary.sourceApiOperations)
}

function applyRegistryNegativeEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRegistryNegativeSummary,
): void {
  result.sourceRuntimeRegistryDuplicateRejected = summary.duplicateRejected
  result.sourceRuntimeRegistryDuplicateReasonCode = summary.duplicateReasonCode
  result.sourceRuntimeRegistryMissingSourceIdRejected = summary.missingSourceIdRejected
  result.sourceRuntimeRegistryMissingSourceIdReasonCode = summary.missingSourceIdReasonCode
  result.sourceRuntimeRegistryInvalidRunRejected = summary.invalidRunRejected
  result.sourceRuntimeRegistryInvalidRunReasonCode = summary.invalidRunReasonCode
}

function applyRegistryReloadEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceRegistryReloadSummary,
): void {
  result.sourceRuntimeRegistryReloadMetadataPath = summary.metadataPath
  result.sourceRuntimeRegistryPersistedSourceCount = summary.persistedSourceCount
  result.sourceRuntimeRegistryReloadedSourceCount = summary.reloadedSourceCount
  result.sourceRuntimeRegistryPackageReloadRunByIdOk = summary.packageRunByIdOk
  result.sourceRuntimeRegistryPackageReloadRunByIdOperations = compactSourceApiOperations(summary.packageRunByIdOperations)
  result.sourceRuntimeRegistryArchiveReloadRunByIdOk = summary.archiveRunByIdOk
  result.sourceRuntimeRegistryArchiveReloadRunByIdOperations = compactSourceApiOperations(summary.archiveRunByIdOperations)
  result.sourceRuntimeRegistryReloadNegativeRejected = summary.negative.rejected
  result.sourceRuntimeRegistryReloadNegativeReasonCode = summary.negative.reasonCode
  result.sourceRuntimeRegistryReloadNegativeAttemptedWamrExecution = summary.negative.attemptedWamrExecution
  result.sourceRuntimeRegistryReloadCorruptMetadataRejected = summary.corruptNegative.rejected
  result.sourceRuntimeRegistryReloadCorruptMetadataReasonCode = summary.corruptNegative.reasonCode
  result.sourceRuntimeRegistryReloadCorruptMetadataAttemptedWamrExecution = summary.corruptNegative.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdPackageSearchOk = summary.packageRunRequestById.ok
  result.sourceRuntimeRunRequestByIdPackageSearch = compactRunRequestByIdEvidence(summary.packageRunRequestById)
  result.sourceRuntimeRunRequestByIdArchiveSearchOk = summary.archiveRunRequestById.ok
  result.sourceRuntimeRunRequestByIdArchiveSearch = compactRunRequestByIdEvidence(summary.archiveRunRequestById)
  result.sourceRuntimeRunRequestByIdNonSearchOk = summary.nonSearchRunRequestById.ok
  result.sourceRuntimeRunRequestByIdNonSearch = compactRunRequestByIdEvidence(summary.nonSearchRunRequestById)
  result.sourceRuntimeRunRequestByIdUnknownSourceRejected = !summary.unknownSourceRunRequestById.ok &&
    summary.unknownSourceRunRequestById.reasonCode === 'source_id_not_registered'
  result.sourceRuntimeRunRequestByIdUnknownSourceReasonCode = summary.unknownSourceRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdUnknownSourceAttemptedWamrExecution =
    summary.unknownSourceRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdSourceIdMismatchRejected = !summary.sourceIdMismatchRunRequestById.ok &&
    summary.sourceIdMismatchRunRequestById.reasonCode === 'source_id_mismatch'
  result.sourceRuntimeRunRequestByIdSourceIdMismatchReasonCode = summary.sourceIdMismatchRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdSourceIdMismatchAttemptedWamrExecution =
    summary.sourceIdMismatchRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdMalformedRejected = !summary.malformedRunRequestById.ok &&
    summary.malformedRunRequestById.reasonCode === 'malformed_json'
  result.sourceRuntimeRunRequestByIdMalformedReasonCode = summary.malformedRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdMalformedAttemptedWamrExecution =
    summary.malformedRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdNullRequestRejected = !summary.nullRequestRunRequestById.ok &&
    summary.nullRequestRunRequestById.reasonCode === 'missing_or_invalid_operation'
  result.sourceRuntimeRunRequestByIdNullRequestReasonCode = summary.nullRequestRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdNullRequestAttemptedWamrExecution =
    summary.nullRequestRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdArrayRequestRejected = !summary.arrayRequestRunRequestById.ok &&
    summary.arrayRequestRunRequestById.reasonCode === 'missing_or_invalid_operation'
  result.sourceRuntimeRunRequestByIdArrayRequestReasonCode = summary.arrayRequestRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdArrayRequestAttemptedWamrExecution =
    summary.arrayRequestRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdMissingOperationRejected = !summary.missingOperationRunRequestById.ok &&
    summary.missingOperationRunRequestById.reasonCode === 'missing_or_invalid_operation'
  result.sourceRuntimeRunRequestByIdMissingOperationReasonCode = summary.missingOperationRunRequestById.reasonCode
  result.sourceRuntimeRunRequestByIdMissingOperationAttemptedWamrExecution =
    summary.missingOperationRunRequestById.attemptedWamrExecution
  result.sourceRuntimeRunRequestByIdOk =
    summary.packageRunRequestById.ok &&
      summary.packageRunRequestById.operation === 'search' &&
      summary.archiveRunRequestById.ok &&
      summary.archiveRunRequestById.operation === 'search' &&
      summary.nonSearchRunRequestById.ok &&
      summary.nonSearchRunRequestById.operation === 'get_manga' &&
      result.sourceRuntimeRunRequestByIdUnknownSourceRejected === true &&
      summary.unknownSourceRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdSourceIdMismatchRejected === true &&
      summary.sourceIdMismatchRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdMalformedRejected === true &&
      summary.malformedRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdNullRequestRejected === true &&
      summary.nullRequestRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdArrayRequestRejected === true &&
      summary.arrayRequestRunRequestById.attemptedWamrExecution === false &&
      result.sourceRuntimeRunRequestByIdMissingOperationRejected === true &&
      summary.missingOperationRunRequestById.attemptedWamrExecution === false
  result.sourceRuntimeRegistryReloadOk = summary.ok &&
    summary.persistedSourceCount >= 2 &&
    summary.reloadedSourceCount >= 2 &&
    summary.packageRunByIdOk &&
    summary.archiveRunByIdOk &&
    summary.negative.rejected &&
    summary.negative.reasonCode === 'metadata_missing' &&
    summary.negative.attemptedWamrExecution === false &&
    summary.corruptNegative.rejected &&
    summary.corruptNegative.reasonCode === 'metadata_invalid' &&
    summary.corruptNegative.attemptedWamrExecution === false
}

function applyArchiveIngestionEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServiceArchiveIngestionRunSummary,
): void {
  result.sourceRuntimeArchiveIngestionSourceId = summary.sourceId
  result.sourceRuntimeArchiveIngestionRoute = summary.route
  result.sourceRuntimeArchiveIngestionMetadataPath = summary.metadataPath
  result.sourceRuntimeArchiveIngestionPersistedSourceCount = summary.persistedSourceCount
  result.sourceRuntimeArchiveIngestionReloadedSourceCount = summary.reloadedSourceCount
  result.sourceRuntimeArchiveIngestionHashOk = summary.hashOk
  result.sourceRuntimeArchiveIngestionNetwork = summary.network
  result.sourceRuntimeInstalledSourceInventory = summary.installedSourceInventory
  result.sourceRuntimeInstalledSourceInventoryExpectedSourceIdCount = summary.inventoryExpectedSourceIdCount
  result.sourceRuntimeInstalledSourceInventoryExpectedSourceIdPresentOnce =
    summary.inventoryExpectedSourceIdCount === 1
  const inventoryText = JSON.stringify(summary.installedSourceInventory)
  result.sourceRuntimeInstalledSourceInventoryNoRawPathLeak =
      !inventoryText.includes('manifestPath') &&
      !inventoryText.includes('wasmPath') &&
      !inventoryText.includes('archivePath') &&
      !inventoryText.includes('/data/')
  result.sourceRuntimeInstalledSourceInventoryNoFullManifestLeak =
    !inventoryText.includes('runtime') &&
      !inventoryText.includes('permissions') &&
      !inventoryText.includes('contentPolicy') &&
      !inventoryText.includes('wasmSha256')
  result.sourceRuntimeInstalledSourceInventoryNoWasmBytesLeak = !inventoryText.includes('wasmBytes')
  result.sourceRuntimeInstalledSourceInventorySafeFieldsOk =
    summary.inventorySafetyOk &&
      result.sourceRuntimeInstalledSourceInventoryNoRawPathLeak === true &&
      result.sourceRuntimeInstalledSourceInventoryNoFullManifestLeak === true &&
      result.sourceRuntimeInstalledSourceInventoryNoWasmBytesLeak === true
  result.sourceRuntimeInstalledSourceInventorySelectedSourceId = summary.selectedSourceId
  result.sourceRuntimeArchiveIngestionImportRegisterOk = summary.importRegister.ok &&
    summary.importRegister.entry !== undefined &&
    summary.importRegister.entry.importStatus === 'imported'
  result.sourceRuntimeArchiveIngestionPersistReloadOk =
    summary.persistedSourceCount === 1 && summary.reloadedSourceCount === 1
  result.sourceRuntimeArchiveIngestionSearchOk = summary.searchRunRequestById.ok &&
    summary.searchRunRequestById.operation === 'search'
  result.sourceRuntimeArchiveIngestionSearch = compactRunRequestByIdEvidence(summary.searchRunRequestById)
  result.sourceRuntimeInstalledSourceInventorySelectedRunRequestOk =
    summary.selectedSourceId === summary.sourceId &&
      result.sourceRuntimeArchiveIngestionSearchOk === true
  result.sourceRuntimeInstalledSourceInventorySelectedRunRequest =
    compactRunRequestByIdEvidence(summary.searchRunRequestById)
  result.sourceRuntimeArchiveIngestionNonSearchOk = summary.nonSearchRunRequestById.ok &&
    summary.nonSearchRunRequestById.operation === 'get_manga'
  result.sourceRuntimeArchiveIngestionNonSearch = compactRunRequestByIdEvidence(summary.nonSearchRunRequestById)
  result.sourceRuntimeArchiveIngestionUnknownSourceRejected = !summary.unknownSourceRunRequestById.ok &&
    summary.unknownSourceRunRequestById.reasonCode === 'source_id_not_registered'
  result.sourceRuntimeArchiveIngestionUnknownSourceReasonCode = summary.unknownSourceRunRequestById.reasonCode
  result.sourceRuntimeArchiveIngestionUnknownSourceAttemptedWamrExecution =
    summary.unknownSourceRunRequestById.attemptedWamrExecution
  result.sourceRuntimeArchiveIngestionSourceIdMismatchRejected = !summary.sourceIdMismatchRunRequestById.ok &&
    summary.sourceIdMismatchRunRequestById.reasonCode === 'source_id_mismatch'
  result.sourceRuntimeArchiveIngestionSourceIdMismatchReasonCode = summary.sourceIdMismatchRunRequestById.reasonCode
  result.sourceRuntimeArchiveIngestionSourceIdMismatchAttemptedWamrExecution =
    summary.sourceIdMismatchRunRequestById.attemptedWamrExecution
  result.sourceRuntimeArchiveIngestionRunRequestOk = summary.ok &&
    result.sourceRuntimeArchiveIngestionImportRegisterOk === true &&
    result.sourceRuntimeArchiveIngestionPersistReloadOk === true &&
    result.sourceRuntimeArchiveIngestionHashOk === true &&
    result.sourceRuntimeArchiveIngestionNetwork === false &&
    result.sourceRuntimeArchiveIngestionSearchOk === true &&
    result.sourceRuntimeArchiveIngestionNonSearchOk === true &&
    result.sourceRuntimeArchiveIngestionUnknownSourceRejected === true &&
    summary.unknownSourceRunRequestById.attemptedWamrExecution === false &&
    result.sourceRuntimeArchiveIngestionSourceIdMismatchRejected === true &&
    summary.sourceIdMismatchRunRequestById.attemptedWamrExecution === false
  result.sourceRuntimeInstalledSourceInventoryOk =
    summary.installedSourceInventoryOk &&
      result.sourceRuntimeInstalledSourceInventoryExpectedSourceIdPresentOnce === true &&
      result.sourceRuntimeInstalledSourceInventorySafeFieldsOk === true &&
      result.sourceRuntimeInstalledSourceInventorySelectedRunRequestOk === true
}

function applyPersistedInventoryReloadEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServicePersistedInventoryReloadSummary,
): void {
  result.sourceRuntimeArchiveIngestionSourceId = summary.sourceId
  result.sourceRuntimeArchiveIngestionRoute = summary.route
  result.sourceRuntimeArchiveIngestionMetadataPath = summary.metadataPath
  result.sourceRuntimeArchiveIngestionReloadedSourceCount = summary.reloadedSourceCount
  result.sourceRuntimeInstalledSourceInventory = summary.installedSourceInventory
  result.sourceRuntimeInstalledSourceInventoryExpectedSourceIdCount = summary.inventoryExpectedSourceIdCount
  result.sourceRuntimeInstalledSourceInventoryExpectedSourceIdPresentOnce =
    summary.inventoryExpectedSourceIdCount === 1
  const inventoryText = JSON.stringify(summary.installedSourceInventory)
  result.sourceRuntimeInstalledSourceInventoryNoRawPathLeak =
      !inventoryText.includes('manifestPath') &&
      !inventoryText.includes('wasmPath') &&
      !inventoryText.includes('archivePath') &&
      !inventoryText.includes('/data/')
  result.sourceRuntimeInstalledSourceInventoryNoFullManifestLeak =
    !inventoryText.includes('runtime') &&
      !inventoryText.includes('permissions') &&
      !inventoryText.includes('contentPolicy') &&
      !inventoryText.includes('wasmSha256')
  result.sourceRuntimeInstalledSourceInventoryNoWasmBytesLeak = !inventoryText.includes('wasmBytes')
  result.sourceRuntimeInstalledSourceInventorySafeFieldsOk =
    summary.inventorySafetyOk &&
      result.sourceRuntimeInstalledSourceInventoryNoRawPathLeak === true &&
      result.sourceRuntimeInstalledSourceInventoryNoFullManifestLeak === true &&
      result.sourceRuntimeInstalledSourceInventoryNoWasmBytesLeak === true
  result.sourceRuntimeInstalledSourceInventorySelectedSourceId = summary.selectedSourceId
  result.sourceRuntimeArchiveIngestionSearchOk = summary.searchRunRequestById.ok &&
    summary.searchRunRequestById.operation === 'search'
  result.sourceRuntimeArchiveIngestionSearch = compactRunRequestByIdEvidence(summary.searchRunRequestById)
  result.sourceRuntimeInstalledSourceInventorySelectedRunRequestOk =
    summary.selectedSourceId === summary.sourceId &&
      result.sourceRuntimeArchiveIngestionSearchOk === true
  result.sourceRuntimeInstalledSourceInventorySelectedRunRequest =
    compactRunRequestByIdEvidence(summary.searchRunRequestById)
  result.sourceRuntimeArchiveIngestionNonSearchOk = summary.nonSearchRunRequestById.ok &&
    summary.nonSearchRunRequestById.operation === 'get_manga'
  result.sourceRuntimeArchiveIngestionNonSearch = compactRunRequestByIdEvidence(summary.nonSearchRunRequestById)
  result.sourceRuntimeArchiveIngestionUnknownSourceRejected = !summary.unknownSourceRunRequestById.ok &&
    summary.unknownSourceRunRequestById.reasonCode === 'source_id_not_registered'
  result.sourceRuntimeArchiveIngestionUnknownSourceReasonCode = summary.unknownSourceRunRequestById.reasonCode
  result.sourceRuntimeArchiveIngestionUnknownSourceAttemptedWamrExecution =
    summary.unknownSourceRunRequestById.attemptedWamrExecution
  result.sourceRuntimeArchiveIngestionSourceIdMismatchRejected = !summary.sourceIdMismatchRunRequestById.ok &&
    summary.sourceIdMismatchRunRequestById.reasonCode === 'source_id_mismatch'
  result.sourceRuntimeArchiveIngestionSourceIdMismatchReasonCode = summary.sourceIdMismatchRunRequestById.reasonCode
  result.sourceRuntimeArchiveIngestionSourceIdMismatchAttemptedWamrExecution =
    summary.sourceIdMismatchRunRequestById.attemptedWamrExecution
  result.sourceRuntimeInstalledSourceInventoryOk =
    summary.installedSourceInventoryOk &&
      result.sourceRuntimeInstalledSourceInventoryExpectedSourceIdPresentOnce === true &&
      result.sourceRuntimeInstalledSourceInventorySafeFieldsOk === true &&
      result.sourceRuntimeInstalledSourceInventorySelectedRunRequestOk === true
  result.sourceRuntimePersistedInventoryRestartReloadOnlyOk = summary.ok
  result.sourceRuntimePersistedInventoryRestartMetadataReloadedOk =
    summary.reasonCode === undefined && summary.reloadedSourceCount === 1
  result.sourceRuntimePersistedInventoryRestartReloadOnlyDidNotImportArchive = summary.reloadOnlyDidNotImportArchive
  result.sourceRuntimePersistedInventoryRestartReloadedSourceCount = summary.reloadedSourceCount
  result.sourceRuntimePersistedInventoryRestartOk =
    summary.ok &&
      summary.reloadOnlyDidNotImportArchive &&
      result.sourceRuntimeInstalledSourceInventoryOk === true &&
      result.sourceRuntimeInstalledSourceInventorySelectedRunRequestOk === true
}

function applyPersistedPayloadMissingEvidence(
  result: SourceRuntimeSmokeResult,
  summary: SourceRuntimeServicePersistedPayloadMissingSummary,
): void {
  result.sourceRuntimeArchiveIngestionSourceId = summary.sourceId
  result.sourceRuntimeArchiveIngestionRoute = summary.route
  result.sourceRuntimeArchiveIngestionMetadataPath = summary.metadataPath
  result.sourceRuntimeArchiveIngestionPersistedSourceCount = summary.persistedSourceCount
  result.sourceRuntimeArchiveIngestionReloadedSourceCount = summary.reloadedSourceCount
  result.sourceRuntimePersistedPayloadMissingImportRegisterOk = summary.importRegister.ok &&
    summary.importRegister.entry !== undefined &&
    summary.importRegister.entry.importStatus === 'imported'
  result.sourceRuntimePersistedPayloadMissingMetadataWrittenOk = summary.persistedSourceCount === 1
  result.sourceRuntimePersistedPayloadMissingMutationApplied = summary.payloadMutationApplied
  result.sourceRuntimePersistedPayloadMissingMetadataReloadRejected = summary.metadataReloadRejected
  result.sourceRuntimePersistedPayloadMissingReasonCode = summary.reasonCode
  result.sourceRuntimePersistedPayloadMissingReloadOnlyDidNotImportArchive = summary.reloadOnlyDidNotImportArchive
  result.sourceRuntimePersistedPayloadMissingAttemptedWamrExecution =
    summary.searchRunRequestById.attemptedWamrExecution
  result.sourceRuntimePersistedPayloadMissingRunRejected =
    !summary.searchRunRequestById.ok && summary.searchRunRequestById.reasonCode === 'wasm_missing'
  result.sourceRuntimePersistedPayloadMissingRunRequest =
    compactRunRequestByIdEvidence(summary.searchRunRequestById)
  result.sourceRuntimePersistedPayloadMissingOk =
    summary.ok &&
      result.sourceRuntimePersistedPayloadMissingImportRegisterOk === true &&
      result.sourceRuntimePersistedPayloadMissingMetadataWrittenOk === true &&
      result.sourceRuntimePersistedPayloadMissingMutationApplied === true &&
      result.sourceRuntimePersistedPayloadMissingMetadataReloadRejected === true &&
      result.sourceRuntimePersistedPayloadMissingReasonCode === 'wasm_missing' &&
      result.sourceRuntimePersistedPayloadMissingReloadOnlyDidNotImportArchive === true &&
      result.sourceRuntimePersistedPayloadMissingRunRejected === true &&
      result.sourceRuntimePersistedPayloadMissingAttemptedWamrExecution === false
}

function compactRunRequestByIdEvidence(
  summary: SourceRuntimeServiceRunRequestByIdSummary,
): SourceRuntimeRunRequestByIdEvidence {
  return {
    sourceId: summary.sourceId,
    operation: summary.operation,
    ok: summary.ok,
    responseOk: summary.responseOk,
    reasonCode: summary.reasonCode,
    attemptedWamrExecution: summary.attemptedWamrExecution,
  }
}

function compactInstalledSourceInventoryForHilog(
  inventory?: SourceRuntimeRegistryInstalledSourceSummary[],
): SourceRuntimeRegistryInstalledSourceSummary[] | undefined {
  if (inventory === undefined) {
    return undefined
  }
  const compactInventory: SourceRuntimeRegistryInstalledSourceSummary[] = []
  for (let index = 0; index < inventory.length; index += 1) {
    const item = inventory[index]
    compactInventory.push({
      sourceId: item.sourceId,
      displayName: item.displayName,
      version: item.version,
      wasmByteCount: item.wasmByteCount,
      importStatus: item.importStatus,
      networkEnabled: item.networkEnabled,
      httpEnabled: item.httpEnabled,
      enabled: item.enabled,
      language: item.language,
      nsfw: item.nsfw,
      status: item.status,
      capabilities: item.capabilities,
    })
  }
  return compactInventory
}

function compactSmokeResultForHilog(result: SourceRuntimeSmokeResult): void {
  result.sourceRuntimeInstalledSourceInventory = compactInstalledSourceInventoryForHilog(
    result.sourceRuntimeInstalledSourceInventory,
  )
  result.route = ''
  result.requestJson = ''
  result.rawfilePath = undefined
  result.rawfileBytes = undefined
  result.rustRequestJson = undefined
  result.rustRawfilePath = undefined
  result.rustRawfileBytes = undefined
  result.packageRoute = undefined
  result.packageOperation = undefined
  result.packageRequestEcho = undefined
  result.packageFirstTitle = undefined
  result.packageWasmBytes = undefined
  result.packageManifestId = undefined
  result.packageManifestVersion = undefined
  result.packageManifestPath = undefined
  result.packageWasmPath = undefined
  result.archiveRoute = undefined
  result.archiveRawfilePath = undefined
  result.archivePath = undefined
  result.archiveOperation = undefined
  result.archiveRequestEcho = undefined
  result.archiveFirstTitle = undefined
  result.archiveWasmBytes = undefined
  result.archiveManifestId = undefined
  result.archiveManifestVersion = undefined
  result.archiveManifestPath = undefined
  result.archiveImportedWasmPath = undefined
  result.archiveNegativeRoute = undefined
  result.rustSourceApiOperations = undefined
  if (result.smokePhase !== SMOKE_PHASE_SOURCE_API_V02) {
    result.sourceApiV02Evidence = undefined
    result.sourceApiV02Operations = undefined
    result.sourceApiV02UnsupportedOperations = undefined
  }
  result.packageSourceApiOperations = undefined
  result.archiveSourceApiOperations = undefined
  result.sourceRuntimeRegistrySourceCount = undefined
  result.sourceRuntimeRegistryPackageSourceId = undefined
  result.sourceRuntimeRegistryArchiveSourceId = undefined
  result.sourceRuntimeRegistryPackageRunByIdOperations = undefined
  result.sourceRuntimeRegistryArchiveRunByIdOperations = undefined
  result.sourceRuntimeRegistryReloadMetadataPath = undefined
  result.sourceRuntimeRegistryPersistedSourceCount = undefined
  result.sourceRuntimeRegistryReloadedSourceCount = undefined
  result.sourceRuntimeRegistryPackageReloadRunByIdOperations = undefined
  result.sourceRuntimeRegistryArchiveReloadRunByIdOperations = undefined
  result.sourceRuntimeRegistryPackageEntry = undefined
  result.sourceRuntimeRegistryArchiveEntry = undefined
  result.sourceRuntimeExecutionNegativeCases = undefined
  result.archiveNegativeCases = undefined
  result.sourceRuntimeRunRequestByIdPackageSearch = undefined
  result.sourceRuntimeRunRequestByIdArchiveSearch = undefined
  result.sourceRuntimeRunRequestByIdNonSearch = undefined
  result.sourceRuntimeRunRequestByIdUnknownSourceAttemptedWamrExecution = undefined
  result.sourceRuntimeRunRequestByIdSourceIdMismatchAttemptedWamrExecution = undefined
  result.sourceRuntimeRunRequestByIdMalformedAttemptedWamrExecution = undefined
  result.sourceRuntimeRunRequestByIdNullRequestAttemptedWamrExecution = undefined
  result.sourceRuntimeRunRequestByIdArrayRequestAttemptedWamrExecution = undefined
  result.sourceRuntimeRunRequestByIdMissingOperationAttemptedWamrExecution = undefined
  result.sourceRuntimeRunRequestByIdUnknownSourceReasonCode = undefined
  result.sourceRuntimeRunRequestByIdSourceIdMismatchReasonCode = undefined
  result.sourceRuntimeRunRequestByIdMalformedReasonCode = undefined
  result.sourceRuntimeRunRequestByIdNullRequestReasonCode = undefined
  result.sourceRuntimeRunRequestByIdArrayRequestReasonCode = undefined
  result.sourceRuntimeRunRequestByIdMissingOperationReasonCode = undefined
  result.sourceRuntimeArchiveIngestionSourceId = undefined
  result.sourceRuntimeArchiveIngestionRoute = undefined
  result.sourceRuntimeArchiveIngestionMetadataPath = undefined
  result.sourceRuntimeArchiveIngestionPersistedSourceCount = undefined
  result.sourceRuntimeArchiveIngestionReloadedSourceCount = undefined
  result.sourceRuntimeInstalledSourceInventorySelectedRunRequest = undefined
  result.sourceRuntimeArchiveIngestionSearch = undefined
  result.sourceRuntimeArchiveIngestionNonSearch = undefined
  result.sourceRuntimeArchiveIngestionUnknownSourceReasonCode = undefined
  result.sourceRuntimeArchiveIngestionSourceIdMismatchReasonCode = undefined
  result.sourceRuntimeArchiveIngestionUnknownSourceAttemptedWamrExecution = undefined
  result.sourceRuntimeArchiveIngestionSourceIdMismatchAttemptedWamrExecution = undefined
}

export async function maybeRunSourceRuntimeDeviceSmoke(
  want: Want,
  resourceMgr?: resourceManager.ResourceManager,
  context?: common.UIAbilityContext,
): Promise<void> {
  if (!hasSmokeTrigger(want)) {
    return
  }

  const result: SourceRuntimeSmokeResult = {
    ok: false,
    route: 'entryability-want-test-only',
    smokePhase: smokePhase(want),
    requestJson: SMOKE_REQUEST_JSON,
    rawfilePath: SMOKE_RAWFILE_PATH,
    rustRequestJson: RUST_SMOKE_REQUEST_JSON,
    rustRawfilePath: RUST_SMOKE_RAWFILE_PATH,
    packageRoute: PACKAGE_ROUTE_LABEL,
    archiveRoute: ARCHIVE_ROUTE_LABEL,
    archiveRawfilePath: ARCHIVE_RAWFILE_PATH,
    archiveNegativeRoute: ARCHIVE_NEGATIVE_ROUTE_LABEL,
  }

  try {
    const nativeHello = NativeSourceRuntime.hello()
    const nativeAdd = NativeSourceRuntime.add(2, 3)
    result.nativeHelloOk = nativeHello.indexOf('Koma native source runtime') >= 0
    result.nativeAddOk = nativeAdd === 5
    console.info(`[SourceRuntime] step=native_loaded helloOk=${result.nativeHelloOk} addOk=${result.nativeAddOk}`)
    if (result.nativeHelloOk !== true || result.nativeAddOk !== true) {
      result.error = 'native source runtime hello/add smoke failed'
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_SETUP_PERSISTED_INVENTORY) {
      result.sourceRuntimePersistedInventoryRestartPhase = SMOKE_PHASE_SETUP_PERSISTED_INVENTORY
      if (resourceMgr === undefined || context === undefined) {
        result.error = 'source runtime persisted inventory setup smoke requires resource manager and ability context'
      } else {
        await runSourceRuntimeArchiveIngestionSmoke(context, resourceMgr, result)
        result.sourceRuntimePersistedInventoryRestartSetupOk =
          result.sourceRuntimeArchiveIngestionRunRequestOk === true
        result.sourceRuntimePersistedInventoryRestartMetadataWrittenOk =
          result.sourceRuntimeArchiveIngestionPersistedSourceCount === 1
        result.sourceRuntimePersistedInventoryRestartOk =
          result.sourceRuntimePersistedInventoryRestartSetupOk === true &&
            result.sourceRuntimePersistedInventoryRestartMetadataWrittenOk === true &&
            result.sourceRuntimeInstalledSourceInventoryOk === true
        result.ok = result.sourceRuntimePersistedInventoryRestartOk === true
        if (!result.ok && result.error === undefined) {
          result.error = 'Persisted inventory setup phase failed to import/register/persist local source archive'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_RELOAD_PERSISTED_INVENTORY) {
      result.sourceRuntimePersistedInventoryRestartPhase = SMOKE_PHASE_RELOAD_PERSISTED_INVENTORY
      if (context === undefined) {
        result.error = 'source runtime persisted inventory reload smoke requires ability context'
      } else {
        runSourceRuntimePersistedInventoryReloadSmoke(context, result)
        result.ok = result.sourceRuntimePersistedInventoryRestartOk === true
        if (!result.ok && result.error === undefined) {
          result.error = 'Persisted inventory reload-only phase failed to reload metadata and run selected source request'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_PERSISTED_PAYLOAD_MISSING) {
      result.sourceRuntimePersistedInventoryRestartPhase = SMOKE_PHASE_PERSISTED_PAYLOAD_MISSING
      if (resourceMgr === undefined || context === undefined) {
        result.error = 'source runtime persisted payload missing smoke requires resource manager and ability context'
      } else {
        await runSourceRuntimePersistedPayloadMissingSmoke(context, resourceMgr, result)
        result.ok = result.sourceRuntimePersistedPayloadMissingOk === true
        if (!result.ok && result.error === undefined) {
          result.error = 'Persisted payload missing phase failed to reject metadata reload/run without archive re-import or WAMR execution'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_SOURCE_API_V02) {
      if (resourceMgr === undefined) {
        result.error = 'source api v0.2 device smoke requires resource manager'
      } else {
        const rustWasmBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
        result.rustRawfileBytes = rustWasmBytes.byteLength
        applySourceApiV02Evidence(result, runSourceApiV02SurfaceFromBytes(rustWasmBytes))
        result.ok = result.sourceApiV02Ok === true
        if (!result.ok && result.error === undefined) {
          result.error = 'Source API v0.2 NAPI smoke failed or reported unsupported operations'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_SIZE_LIMIT_NEGATIVES) {
      if (resourceMgr === undefined) {
        result.error = 'source runtime size-limit negative smoke requires resource manager'
      } else {
        const rustWasmBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
        result.rustRawfileBytes = rustWasmBytes.byteLength
        applySizeLimitNegativeEvidence(result, runSourceRuntimeSizeLimitNegativesFromBytes(rustWasmBytes))
        result.ok = result.sourceRuntimeSizeLimitNegativesOk === true
        if (!result.ok && result.error === undefined) {
          result.error = 'Size-limit negative phase failed to reject request/result/malformed envelope with stable reasons'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_CANCEL_TIMEOUT_NEGATIVES) {
      if (resourceMgr === undefined) {
        result.error = 'source runtime cancel/timeout negative smoke requires resource manager'
      } else {
        const rustWasmBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
        result.rustRawfileBytes = rustWasmBytes.byteLength
        applyCancelTimeoutNegativeEvidence(result, runSourceRuntimeCancelTimeoutNegativesFromBytes(rustWasmBytes))
        result.ok = result.sourceRuntimeCancelTimeoutNegativesOk === true
        if (!result.ok && result.error === undefined) {
          result.error = 'Cancel/timeout negative phase failed to reject guard cases with stable reasons'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_REAL_SOURCE_SEARCH) {
      if (resourceMgr === undefined) {
        result.error = 'real-source-search phase requires resource manager'
      } else {
        // baozimh
        const wasmBytes = resourceMgr.getRawFileContentSync(REAL_SOURCE_RAWFILE_PATH)
        result.realSourceWasmBytes = wasmBytes.byteLength
        console.info(SMOKE_LOG_PREFIX + '{"phase":"real-source-search","source":"baozimh","status":"loading","bytes":' + wasmBytes.byteLength + '}')
        const responseJson = await taskpool.execute(runRealSourceSearchTask, REAL_SOURCE_SEARCH_REQUEST, new Uint8Array(wasmBytes.buffer)) as string
        const response: SourceRuntimeCallResponse = JSON.parse(responseJson) as SourceRuntimeCallResponse
        result.realSourceResponse = response

        // mangadex
        const mangadexBytes = resourceMgr.getRawFileContentSync(MANGADEX_RAWFILE_PATH)
        result.mangadexWasmBytes = mangadexBytes.byteLength
        console.info(SMOKE_LOG_PREFIX + '{"phase":"real-source-search","source":"mangadex","status":"loading","bytes":' + mangadexBytes.byteLength + '}')
        const mangadexJson = await taskpool.execute(runRealSourceSearchTask, REAL_SOURCE_SEARCH_REQUEST, new Uint8Array(mangadexBytes.buffer)) as string
        const mangadexResponse: SourceRuntimeCallResponse = JSON.parse(mangadexJson) as SourceRuntimeCallResponse
        result.mangadexResponse = mangadexResponse

        result.ok = response !== undefined && response.ok === true &&
          mangadexResponse !== undefined && mangadexResponse.ok === true
        if (!result.ok && result.error === undefined) {
          const failures: string[] = []
          if (!response?.ok) failures.push('baozimh')
          if (!mangadexResponse?.ok) failures.push('mangadex')
          result.error = 'real-source-search failed: ' + failures.join(', ')
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_REAL_SOURCE_READER) {
      if (resourceMgr === undefined) {
        result.error = 'real-source-reader phase requires resource manager'
      } else {
        const wasmBytes = resourceMgr.getRawFileContentSync(REAL_SOURCE_RAWFILE_PATH)
        result.realSourceWasmBytes = wasmBytes.byteLength
        console.info(SMOKE_LOG_PREFIX + '{"phase":"real-source-reader","source":"baozimh","status":"loading","bytes":' + wasmBytes.byteLength + '}')

        const sourceBytes = new Uint8Array(wasmBytes.buffer)
        const searchJson = await taskpool.execute(
          runRealSourceSearchTask,
          REAL_SOURCE_SEARCH_REQUEST,
          copySmokeWasmBytes(sourceBytes),
        ) as string
        const searchResponse: SourceRuntimeCallResponse = JSON.parse(searchJson) as SourceRuntimeCallResponse
        const searchItems = responseItems(searchResponse)
        const mangaId = firstStringField(searchItems, 'id')
        result.realSourceReaderSearchCount = searchItems.length
        result.realSourceReaderMangaId = mangaId

        const detailJson = await taskpool.execute(
          runRealSourceSearchTask,
          `{"operation":"get_manga","mangaId":"${mangaId}"}`,
          copySmokeWasmBytes(sourceBytes),
        ) as string
        const detailResponse: SourceRuntimeCallResponse = JSON.parse(detailJson) as SourceRuntimeCallResponse
        result.realSourceReaderDetailOk = detailResponse.ok === true

        const chaptersJson = await taskpool.execute(
          runRealSourceSearchTask,
          `{"operation":"get_chapters","mangaId":"${mangaId}"}`,
          copySmokeWasmBytes(sourceBytes),
        ) as string
        const chaptersResponse: SourceRuntimeCallResponse = JSON.parse(chaptersJson) as SourceRuntimeCallResponse
        const chapters = responseItems(chaptersResponse)
        const chapterId = firstStringField(chapters, 'id')
        result.realSourceReaderChaptersOk = chaptersResponse.ok === true
        result.realSourceReaderChapterCount = chapters.length
        result.realSourceReaderChapterId = chapterId

        const pagesJson = await taskpool.execute(
          runRealSourceSearchTask,
          `{"operation":"get_pages","chapterId":"${chapterId}"}`,
          copySmokeWasmBytes(sourceBytes),
        ) as string
        const pagesResponse: SourceRuntimeCallResponse = JSON.parse(pagesJson) as SourceRuntimeCallResponse
        result.realSourceReaderPagesOk = pagesResponse.ok === true
        result.realSourceReaderPageCount = responsePages(pagesResponse).length

        result.ok = searchResponse.ok === true &&
          mangaId.length > 0 &&
          result.realSourceReaderDetailOk === true &&
          result.realSourceReaderChaptersOk === true &&
          chapterId.length > 0 &&
          result.realSourceReaderPagesOk === true &&
          (result.realSourceReaderPageCount ?? 0) > 0
        if (!result.ok && result.error === undefined) {
          result.error = 'real-source-reader failed'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_INSTALLED_SOURCE_READER) {
      if (resourceMgr === undefined || context === undefined) {
        result.error = 'installed-source-reader phase requires resource manager and ability context'
      } else {
        const archiveBytes = resourceMgr.getRawFileContentSync(ARCHIVE_RAWFILE_PATH)
        const install = await installFromBytes(
          context,
          new Uint8Array(archiveBytes.buffer),
          ARCHIVE_SANDBOX_ZIP_FILE,
          INSTALLED_READER_SOURCE_ID,
        )
        result.installedSourceReaderInstallOk = install.ok === true && install.id === INSTALLED_READER_SOURCE_ID
        result.installedSourceReaderSourceId = install.id

        if (result.installedSourceReaderInstallOk === true) {
          const search = runRegisteredSourceRequestById(
            appSourceRuntimeRegistry,
            INSTALLED_READER_SOURCE_ID,
            sourceRuntimeRequest(
              INSTALLED_READER_SOURCE_ID,
              'search',
              '{"query":"fixture","page":{"cursor":null,"limit":20},"filters":{"tags":["fixture"]}}',
              'installed-reader-search-001',
            ),
          )
          const searchItems = search.response === undefined ? [] : responseItems(search.response)
          const mangaId = firstStringField(searchItems, 'id')
          result.installedSourceReaderSearchOk = search.ok === true && mangaId.length > 0
          result.installedSourceReaderSearchCount = searchItems.length
          result.installedSourceReaderMangaId = mangaId

          const detail = runRegisteredSourceRequestById(
            appSourceRuntimeRegistry,
            INSTALLED_READER_SOURCE_ID,
            sourceRuntimeRequest(
              INSTALLED_READER_SOURCE_ID,
              'get_manga',
              `{"mangaId":"${mangaId}"}`,
              'installed-reader-detail-001',
            ),
          )
          result.installedSourceReaderDetailOk = detail.ok === true

          const chapters = runRegisteredSourceRequestById(
            appSourceRuntimeRegistry,
            INSTALLED_READER_SOURCE_ID,
            sourceRuntimeRequest(
              INSTALLED_READER_SOURCE_ID,
              'get_chapters',
              `{"mangaId":"${mangaId}","page":{"cursor":null,"limit":100}}`,
              'installed-reader-chapters-001',
            ),
          )
          const chapterRows = chapters.response === undefined ? [] : responseChapters(chapters.response)
          const chapterId = firstStringField(chapterRows, 'id')
          result.installedSourceReaderChaptersOk = chapters.ok === true && chapterId.length > 0
          result.installedSourceReaderChapterCount = chapterRows.length
          result.installedSourceReaderChapterId = chapterId

          const pages = runRegisteredSourceRequestById(
            appSourceRuntimeRegistry,
            INSTALLED_READER_SOURCE_ID,
            sourceRuntimeRequest(
              INSTALLED_READER_SOURCE_ID,
              'get_pages',
              `{"chapterId":"${chapterId}"}`,
              'installed-reader-pages-001',
            ),
          )
          const pageRows = pages.response === undefined ? [] : responsePages(pages.response)
          const pageId = firstStringField(pageRows, 'id')
          result.installedSourceReaderPagesOk = pages.ok === true && pageId.length > 0
          result.installedSourceReaderPageCount = pageRows.length
          result.installedSourceReaderPageId = pageId

          const readerConfig: ReaderSessionConfig = {
            comicId: mangaId,
            chapterId,
            title: 'Installed Source Reader Smoke',
            chapterTitle: 'Chapter',
            chapterIds: [chapterId],
            totalPages: pageRows.length,
            pageUris: pageRows.map((page: Record<string, Object>): string => firstStringField([page], 'uri')),
            pageIds: pageRows.map((page: Record<string, Object>): string => firstStringField([page], 'id')),
            pageWidths: pageRows.map((page: Record<string, Object>): number | undefined => pageImageDimension(page, 'width')),
            pageHeights: pageRows.map((page: Record<string, Object>): number | undefined => pageImageDimension(page, 'height')),
            sourceRuntimeId: INSTALLED_READER_SOURCE_ID,
          }
          const renderSource = createReaderPageRenderSource(readerConfig, 0, { preferOffline: false })
          result.installedSourceReaderRenderKind = renderSource.kind
          result.installedSourceReaderRenderHasSourceRuntimeId =
            renderSource.sourceRuntimeId === INSTALLED_READER_SOURCE_ID
          result.installedSourceReaderRenderHasPageId = renderSource.pageId === pageId
          result.installedSourceReaderRenderSourceOk =
            renderSource.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE &&
              result.installedSourceReaderRenderHasSourceRuntimeId === true &&
              result.installedSourceReaderRenderHasPageId === true
        }

        result.installedSourceReaderCleanupOk = await removeInstalledSourcePackage(context, INSTALLED_READER_SOURCE_ID)
        result.ok = result.installedSourceReaderInstallOk === true &&
          result.installedSourceReaderSearchOk === true &&
          result.installedSourceReaderDetailOk === true &&
          result.installedSourceReaderChaptersOk === true &&
          result.installedSourceReaderPagesOk === true &&
          (result.installedSourceReaderPageCount ?? 0) > 0 &&
          result.installedSourceReaderRenderSourceOk === true &&
          result.installedSourceReaderCleanupOk === true
        if (!result.ok && result.error === undefined) {
          result.error = 'installed-source-reader failed'
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase === SMOKE_PHASE_SOURCE_INDEX_READER ||
      result.smokePhase === SMOKE_PHASE_SOURCE_INDEX_DOWNLOAD_READER) {
      if (context === undefined) {
        result.error = `${result.smokePhase} phase requires ability context`
      } else {
        const isDownloadReaderPhase = result.smokePhase === SMOKE_PHASE_SOURCE_INDEX_DOWNLOAD_READER
        const indexUrl = smokeStringParam(want, SMOKE_INDEX_URL_PARAM)
        const requestedSourceId = smokeStringParam(want, SMOKE_SOURCE_ID_PARAM)
        const selectedSourceId = requestedSourceId.length > 0 ? requestedSourceId : SOURCE_INDEX_READER_DEFAULT_SOURCE_ID
        result.sourceIndexReaderIndexUrlProvided = indexUrl.length > 0
        result.sourceIndexReaderSelectedSourceId = selectedSourceId
        const alreadyInstalled = appSourceRuntimeRegistry.lookup(selectedSourceId).ok
        if (indexUrl.length === 0) {
          result.error = `${result.smokePhase} requires indexUrl`
        } else if (alreadyInstalled) {
          result.error = `${result.smokePhase} refuses to overwrite installed source`
        } else {
          const sourceIndexService = new SourceIndexService(context)
          const fetch = await sourceIndexService.fetchIndex(indexUrl)
          result.sourceIndexReaderFetchOk = fetch.ok === true
          result.sourceIndexReaderEntryCount = fetch.entries.length
          const entry = fetch.entries.find((item: SourceIndexEntry): boolean => item.id === selectedSourceId)
          if (!fetch.ok || entry === undefined) {
            result.error = 'source-index-reader source entry not found'
          } else {
            const install = await sourceIndexService.installPackage(indexUrl, entry)
            result.sourceIndexReaderInstallOk = install.ok === true && install.install?.id === selectedSourceId
            if (result.sourceIndexReaderInstallOk === true) {
              const lookup = appSourceRuntimeRegistry.lookup(selectedSourceId)
              const sourceBytes = lookup.entry?.wasmBytes
              result.sourceIndexReaderWasmBytes = sourceBytes?.byteLength ?? 0
              if (sourceBytes !== undefined) {
                const searchJson = await taskpool.execute(
                  runRealSourceSearchTask,
                  REAL_SOURCE_SEARCH_REQUEST,
                  copySmokeWasmBytes(sourceBytes),
                ) as string
                const searchResponse: SourceRuntimeCallResponse = JSON.parse(searchJson) as SourceRuntimeCallResponse
                const searchItems = responseItems(searchResponse)
                const mangaId = firstStringField(searchItems, 'id')
                result.sourceIndexReaderSearchOk = searchResponse.ok === true && mangaId.length > 0
                result.sourceIndexReaderSearchCount = searchItems.length
                result.sourceIndexReaderMangaId = mangaId

                const detailJson = await taskpool.execute(
                  runRealSourceSearchTask,
                  `{"operation":"get_manga","mangaId":"${mangaId}"}`,
                  copySmokeWasmBytes(sourceBytes),
                ) as string
                const detailResponse: SourceRuntimeCallResponse = JSON.parse(detailJson) as SourceRuntimeCallResponse
                result.sourceIndexReaderDetailOk = detailResponse.ok === true

                const chaptersJson = await taskpool.execute(
                  runRealSourceSearchTask,
                  `{"operation":"get_chapters","mangaId":"${mangaId}"}`,
                  copySmokeWasmBytes(sourceBytes),
                ) as string
                const chaptersResponse: SourceRuntimeCallResponse = JSON.parse(chaptersJson) as SourceRuntimeCallResponse
                const chapters = responseChapters(chaptersResponse)
                const chapterId = firstStringField(chapters, 'id')
                result.sourceIndexReaderChaptersOk = chaptersResponse.ok === true && chapterId.length > 0
                result.sourceIndexReaderChapterCount = chapters.length
                result.sourceIndexReaderChapterId = chapterId

                const pagesJson = await taskpool.execute(
                  runRealSourceSearchTask,
                  `{"operation":"get_pages","chapterId":"${chapterId}"}`,
                  copySmokeWasmBytes(sourceBytes),
                ) as string
                const pagesResponse: SourceRuntimeCallResponse = JSON.parse(pagesJson) as SourceRuntimeCallResponse
                const pages = responsePages(pagesResponse)
                const pageId = firstStringField(pages, 'id')
                result.sourceIndexReaderPagesOk = pagesResponse.ok === true && pageId.length > 0
                result.sourceIndexReaderPageCount = pages.length
                result.sourceIndexReaderPageId = pageId

                const readerConfig: ReaderSessionConfig = {
                  comicId: mangaId,
                  chapterId,
                  title: 'Source Index Reader Smoke',
                  chapterTitle: 'Chapter',
                  chapterIds: [chapterId],
                  totalPages: pages.length,
                  pageUris: pages.map((page: Record<string, Object>): string => firstStringField([page], 'uri')),
                  pageIds: pages.map((page: Record<string, Object>): string => firstStringField([page], 'id')),
                  pageWidths: pages.map((page: Record<string, Object>): number | undefined => pageImageDimension(page, 'width')),
                  pageHeights: pages.map((page: Record<string, Object>): number | undefined => pageImageDimension(page, 'height')),
                  sourceRuntimeId: selectedSourceId,
                }
                const renderSource = createReaderPageRenderSource(readerConfig, 0, { preferOffline: false })
                result.sourceIndexReaderRenderSourceOk =
                  renderSource.kind === ReaderPageRenderKind.REMOTE_URL_IMAGE &&
                    renderSource.sourceRuntimeId === selectedSourceId &&
                    renderSource.pageId === pageId
                if (isDownloadReaderPhase && result.sourceIndexReaderRenderSourceOk === true) {
                  const comic = sourcePageRowsToComic(selectedSourceId, mangaId, chapterId, pages)
                  const downloadStore = new OfflineDownloadStore(context.filesDir)
                  const queueStore = new OfflineDownloadQueueStore(downloadStore.filesRootDir())
                  queueStore.savePreferences(DEFAULT_OFFLINE_DOWNLOAD_QUEUE_PREFERENCES)
                  const downloadService = new OfflineDownloadService(downloadStore, queueStore)
                  const manifest = await downloadService.downloadChapter(comic, chapterId, {
                    comicTitle: comic.title,
                    chapterTitle: comic.chapters[0].title,
                  })
                  result.sourceIndexDownloadStatus = manifest.status
                  result.sourceIndexDownloadPageCount = manifest.pageCount
                  result.sourceIndexDownloadDownloadedPageCount = manifest.downloadedPageCount
                  result.sourceIndexDownloadOk =
                    manifest.status === OfflineDownloadStatus.DOWNLOADED &&
                      manifest.downloadedPageCount === pages.length &&
                      downloadStore.isChapterFullyDownloaded(comic.id, chapterId)
                  configureReaderOfflineDownloads(context.filesDir)
                  const offlineConfig = createReaderSessionConfigFromComic(comic, chapterId)
                  const offlineSource = createReaderPageRenderSource(offlineConfig, 0)
                  result.sourceIndexDownloadOfflineReaderKind = offlineSource.kind
                  result.sourceIndexDownloadOfflineReaderOk =
                    offlineSource.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE &&
                      offlineSource.pageId === pageId &&
                      offlineSource.imageUri.length > 0
                  await downloadStore.deleteChapterDownload(comic.id, chapterId)
                  result.sourceIndexDownloadCleanupOk =
                    !downloadStore.isChapterFullyDownloaded(comic.id, chapterId)
                }
              }
            }
            result.sourceIndexReaderCleanupOk = await removeInstalledSourcePackage(context, selectedSourceId)
          }
        }
        result.ok = result.sourceIndexReaderIndexUrlProvided === true &&
          result.sourceIndexReaderFetchOk === true &&
          result.sourceIndexReaderInstallOk === true &&
          result.sourceIndexReaderSearchOk === true &&
          result.sourceIndexReaderDetailOk === true &&
          result.sourceIndexReaderChaptersOk === true &&
          result.sourceIndexReaderPagesOk === true &&
          (result.sourceIndexReaderPageCount ?? 0) > 0 &&
          result.sourceIndexReaderRenderSourceOk === true &&
          (!isDownloadReaderPhase ||
            (result.sourceIndexDownloadOk === true &&
              result.sourceIndexDownloadOfflineReaderOk === true &&
              result.sourceIndexDownloadCleanupOk === true)) &&
          result.sourceIndexReaderCleanupOk === true
        if (!result.ok && result.error === undefined) {
          result.error = `${result.smokePhase} failed`
        }
      }
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    if (result.smokePhase !== SMOKE_PHASE_FULL) {
      result.error = 'unknown source runtime smoke phase'
      compactSmokeResultForHilog(result)
      console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
      return
    }

    const response = runBundledSourceOperation(SMOKE_REQUEST_JSON)
    result.responseOk = responseReachedFixture(response)
    if (result.responseOk === true) {
      console.info('[SourceRuntime] step=wasm_smoke_ok route=bundled')
    }
    let resourceResponse: SourceRuntimeCallResponse | undefined = undefined
    let rustSourceResponseOk = false
    if (resourceMgr !== undefined) {
      const wasmBytes = resourceMgr.getRawFileContentSync(SMOKE_RAWFILE_PATH)
      result.rawfileBytes = wasmBytes.byteLength
      resourceResponse = runSourceOperationFromBytes(SMOKE_REQUEST_JSON, wasmBytes)
      result.resourceResponseOk = responseReachedFixture(resourceResponse)

      const rustWasmBytes = resourceMgr.getRawFileContentSync(RUST_SMOKE_RAWFILE_PATH)
      result.rustRawfileBytes = rustWasmBytes.byteLength
      const rustSourceRun = runSearchFixtureFromBytes(RUST_SMOKE_REQUEST_JSON, rustWasmBytes)
      const rustSourceOperations = runSourceApiFixtureOperationsFromBytes(rustWasmBytes)
      const sourceApiV02 = runSourceApiV02SurfaceFromBytes(rustWasmBytes)
      const sizeLimitNegatives = runSourceRuntimeSizeLimitNegativesFromBytes(rustWasmBytes)
      const cancelTimeoutNegatives = runSourceRuntimeCancelTimeoutNegativesFromBytes(rustWasmBytes)
      rustSourceResponseOk = rustSourceRun.responseOk
      result.rustSourceResponseOk = rustSourceResponseOk
      result.rustSourceApiOperationsOk = rustSourceOperations.ok
      result.rustSourceApiOperations = compactSourceApiOperations(rustSourceOperations)
      applySourceApiV02Evidence(result, sourceApiV02)
      applySizeLimitNegativeEvidence(result, sizeLimitNegatives)
      applyCancelTimeoutNegativeEvidence(result, cancelTimeoutNegatives)
      if (context !== undefined) {
        runLocalSourcePackageSmoke(context, resourceMgr, result)
        await runLocalSourceArchiveSmoke(context, resourceMgr, result)
        await runSourceRuntimeRegistrySmoke(context, resourceMgr, result)
        await runSourceRuntimeArchiveIngestionSmoke(context, resourceMgr, result)
        const archiveNegativeCases = await importArchiveNegativeFixturesWithoutExecution(
          context,
          resourceMgr,
          ARCHIVE_NEGATIVE_CASES,
          'source-runtime-archive-negative-smoke',
        )
        result.archiveNegativeCases = archiveNegativeCases.map((item: SourceArchiveNegativeImportResult) => {
          const evidence: SourceArchiveNegativeCaseEvidence = {
            id: item.id,
            reasonCode: item.reasonCode,
            reasonMatchesExpected: item.reasonMatchesExpected,
            attemptedWamrExecution: item.attemptedWamrExecution,
          }
          return evidence
        })
        result.archiveNegativeOk = archiveNegativeCases.length === ARCHIVE_NEGATIVE_CASES.length &&
          archiveNegativeCases.every((item: SourceArchiveNegativeImportResult) =>
            item.rejected && item.reasonMatchesExpected && item.attemptedWamrExecution === false)
      }
    }
    result.ok = result.responseOk === true &&
      result.nativeHelloOk === true &&
      result.nativeAddOk === true &&
      resourceResponse !== undefined &&
      result.resourceResponseOk === true &&
      rustSourceResponseOk &&
      result.packageResponseOk === true &&
      result.packageSourceApiOperationsOk === true &&
      result.packageHashOk === true &&
      result.packageNetwork === false &&
      result.archiveImportOk === true &&
      result.archiveResponseOk === true &&
      result.archiveSourceApiOperationsOk === true &&
      result.archiveHashOk === true &&
      result.archiveNetwork === false &&
      result.rustSourceApiOperationsOk === true &&
      result.archiveNegativeOk === true &&
      result.sourceApiV02Ok === true &&
      result.sourceRuntimeSizeLimitNegativesOk === true &&
      result.sourceRuntimeCancelTimeoutNegativesOk === true &&
      result.sourceRuntimeExecutionNegativeOk === true &&
      result.sourceRuntimeRegistryOk === true &&
      result.sourceRuntimeRegistryReloadOk === true &&
      result.sourceRuntimeArchiveIngestionRunRequestOk === true &&
      result.sourceRuntimeInstalledSourceInventoryOk === true
    if (!result.ok) {
      result.error = 'WAMR fixture JSON assertion failed for bundled, legacy rawfile, Rust source rawfile, Source API v0.2 surface, size-limit negatives, cancel/timeout negatives, local source package, local source archive import, archive negative rejection, negative execution, registry run-by-id, registry persistence/reload, and archive ingestion run-request paths'
    }
  } catch (error) {
    const e = error as Error
    result.error = e.message
  }

  compactSmokeResultForHilog(result)
  console.info(SMOKE_LOG_PREFIX + JSON.stringify(result))
}

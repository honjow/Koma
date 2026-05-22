#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cpp_file="entry/src/main/cpp/source_runtime_sample.cpp"
cmake_file="entry/src/main/cpp/CMakeLists.txt"
adapter_cpp="entry/src/main/cpp/wasm_runtime_adapter.cpp"
adapter_h="entry/src/main/cpp/wasm_runtime_adapter.h"
wrapper_file="entry/src/main/ets/sourceRuntime/NativeSourceRuntime.ets"
smoke_file="entry/src/main/ets/sourceRuntime/SourceRuntimeDeviceSmoke.ets"
source_package_importer_file="entry/src/main/ets/sourceRuntime/SourcePackageImporter.ets"
source_runtime_runner_file="entry/src/main/ets/sourceRuntime/SourceRuntimeRunner.ets"
source_runtime_service_file="entry/src/main/ets/sourceRuntime/SourceRuntimeService.ets"
source_runtime_registry_file="entry/src/main/ets/sourceRuntime/SourceRuntimeRegistry.ets"
entry_ability_file="entry/src/main/ets/entryability/EntryAbility.ets"
build_profile="entry/build-profile.json5"
rawfile_fixture="entry/src/main/resources/rawfile/test/source_runtime_fixture.wasm"
rust_rawfile_fixture="entry/src/main/resources/rawfile/test/rust_source_runtime_fixture.wasm"
archive_fixture="entry/src/main/resources/rawfile/test/local_source_runtime_fixture.koma-source"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing required file: $path" >&2
    exit 1
  fi
}

require_text() {
  local path="$1"
  local pattern="$2"
  if ! rg -q -- "$pattern" "$path"; then
    echo "missing pattern '$pattern' in $path" >&2
    exit 1
  fi
}

require_file "$cpp_file"
require_file "$cmake_file"
require_file "$adapter_cpp"
require_file "$adapter_h"
require_file "$wrapper_file"
require_file "$smoke_file"
require_file "$source_package_importer_file"
require_file "$source_runtime_runner_file"
require_file "$source_runtime_service_file"
require_file "$source_runtime_registry_file"
require_file "$entry_ability_file"
require_file "$rawfile_fixture"
require_file "$rust_rawfile_fixture"
require_file "$archive_fixture"

require_text "$cpp_file" '#include <napi/native_api.h>'
require_text "$cpp_file" 'napi_module_register'
require_text "$cpp_file" '"hello"'
require_text "$cpp_file" '"add"'
require_text "$cpp_file" '"runJsonCall"'
require_text "$cpp_file" '"runJsonCallFromBytes"'
require_text "$cpp_file" 'RunBundledWasmJsonCall'
require_text "$cpp_file" 'RunWasmJsonCallFromBytes'
require_text "$cpp_file" 'napi_get_typedarray_info'

require_text "$adapter_cpp" 'KOMA_ENABLE_WAMR'
require_text "$adapter_cpp" 'wasm_runtime_full_init'
require_text "$adapter_cpp" 'native_module_name = "koma_host"'
require_text "$adapter_cpp" 'NativeSymbol g_komaHostSymbols'
require_text "$adapter_cpp" '"log".*HostLog'
require_text "$adapter_cpp" '"check_cancel".*HostCheckCancel'
require_text "$adapter_cpp" 'wasm_runtime_load'
require_text "$adapter_cpp" 'wasm_runtime_module_dup_data'
require_text "$adapter_cpp" 'LoadWasmBytesFromBundledFixture'
require_text "$adapter_cpp" 'LoadWasmBytesFromExternalBytes'
require_text "$adapter_cpp" 'ExtractOperation'
require_text "$adapter_cpp" 'ExportForOperation'
require_text "$adapter_cpp" 'koma_source_search'
require_text "$adapter_cpp" 'koma_source_get_manga'
require_text "$adapter_cpp" 'koma_source_get_chapters'
require_text "$adapter_cpp" 'koma_source_get_pages'
require_text "$adapter_cpp" 'koma_source_free'
require_text "$adapter_cpp" 'kKomaMagic'
require_text "$adapter_cpp" 'WAMR_NOT_BUILT'
require_text "$adapter_cpp" 'koma-host-v0.1'
require_text "$adapter_cpp" 'maxPayloadBytes'

if rg -q 'runtime\\":\\"napi-sample' "$cpp_file" "$adapter_cpp"; then
  echo "runJsonCall still contains the old hardcoded napi-sample response" >&2
  exit 1
fi

require_text "$cmake_file" 'wasm-runtime-spike/wasm/source_fixture.c'
require_text "$cmake_file" 'KOMA_ENABLE_WAMR'
require_text "$cmake_file" 'WAMR_ROOT_DIR'
require_text "$cmake_file" '--allow-undefined'
require_text "$cmake_file" 'WAMR_BUILD_INTERP 1'
require_text "$cmake_file" 'WAMR_BUILD_AOT 0'
require_text "$cmake_file" 'WAMR_BUILD_JIT 0'
require_text "$cmake_file" 'add_library\(koma_source_runtime SHARED'
require_text "$cmake_file" 'libace_napi.z.so'
require_text "$build_profile" '"externalNativeOptions"'
require_text "$build_profile" '"./src/main/cpp/CMakeLists.txt"'

require_text "$wrapper_file" "import nativeRuntime from 'libkoma_source_runtime.so'"
require_text "$wrapper_file" 'class NativeSourceRuntime'
require_text "$wrapper_file" 'JSON.parse'
require_text "$wrapper_file" 'runJsonCallFromBytes'

require_text "$smoke_file" 'maybeRunSourceRuntimeDeviceSmoke'
require_text "$smoke_file" 'runBundledSourceOperation'
require_text "$smoke_file" 'runSourceOperationFromBytes'
require_text "$smoke_file" 'runSearchFixtureFromBytes'
require_text "$smoke_file" 'runSourceApiFixtureOperationsFromBytes'
require_text "$smoke_file" 'getRawFileContentSync'
require_text "$smoke_file" 'test/source_runtime_fixture.wasm'
require_text "$smoke_file" 'test/rust_source_runtime_fixture.wasm'
require_text "$smoke_file" '"query":"fixture"'
require_text "$smoke_file" '"operation":"search"'
require_text "$smoke_file" 'koma-smoke'
require_text "$smoke_file" 'koma-rust-smoke'
require_text "$smoke_file" 'rustSourceResponse'
require_text "$smoke_file" 'rustRawfileBytes'
require_text "$smoke_file" 'KOMA_SOURCE_RUNTIME_SMOKE_RESULT'
require_text "$smoke_file" 'entryability-want-test-only'
require_text "$smoke_file" 'local_source_runtime_fixture.koma-source'
require_text "$smoke_file" 'app-local-source-archive-import-test-only'
require_text "$smoke_file" 'SourceRuntimeService'
require_text "$smoke_file" 'runStagedRawfileSourcePackage'
require_text "$smoke_file" 'importAndRunLocalSourceArchive'
require_text "$smoke_file" 'importRegisterPersistReloadAndRunLocalSourceArchiveRequest'
require_text "$smoke_file" 'SourceRuntimeRegistry'
require_text "$smoke_file" 'stageAndRegisterRawfileSourcePackage'
require_text "$smoke_file" 'importAndRegisterLocalSourceArchive'
require_text "$smoke_file" 'runRegisteredSourceApiOperationsById'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdOk'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdPackageSearchOk'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdArchiveSearchOk'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdNonSearchOk'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdUnknownSourceRejected'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdSourceIdMismatchRejected'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdMalformedRejected'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdMissingOperationRejected'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdUnknownSourceAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdSourceIdMismatchAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdMalformedAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdMissingOperationAttemptedWamrExecution'
require_text "$smoke_file" 'importArchiveNegativeFixturesWithoutExecution'
require_text "$smoke_file" 'archiveImportOk'
require_text "$smoke_file" 'archiveResponseOk'
require_text "$smoke_file" 'archiveImportedWasmPath'
require_text "$smoke_file" 'rustSourceApiOperationsOk'
require_text "$smoke_file" 'packageSourceApiOperationsOk'
require_text "$smoke_file" 'archiveSourceApiOperationsOk'
require_text "$smoke_file" 'sourceRuntimeExecutionNegativeOk'
require_text "$smoke_file" 'sourceRuntimeExecutionNegativeCases'
require_text "$smoke_file" 'didNotDefaultToSearch'
require_text "$smoke_file" 'sourceRuntimeRegistryOk'
require_text "$smoke_file" 'sourceRuntimeRegistrySourceCount'
require_text "$smoke_file" 'sourceRuntimeRegistryPackageSourceId'
require_text "$smoke_file" 'sourceRuntimeRegistryArchiveSourceId'
require_text "$smoke_file" 'sourceRuntimeRegistryPackageEntry'
require_text "$smoke_file" 'sourceRuntimeRegistryArchiveEntry'
require_text "$smoke_file" 'sourceRuntimeRegistryPackageRunByIdOk'
require_text "$smoke_file" 'sourceRuntimeRegistryArchiveRunByIdOk'
require_text "$smoke_file" 'sourceRuntimeRegistryDuplicateRejected'
require_text "$smoke_file" 'sourceRuntimeRegistryMissingSourceIdRejected'
require_text "$smoke_file" 'sourceRuntimeRegistryInvalidRunRejected'
require_text "$smoke_file" 'persistReloadAndRunRegisteredSourcesById'
require_text "$smoke_file" 'sourceRuntimeRegistryReloadOk'
require_text "$smoke_file" 'sourceRuntimeRegistryPersistedSourceCount'
require_text "$smoke_file" 'sourceRuntimeRegistryReloadedSourceCount'
require_text "$smoke_file" 'sourceRuntimeRegistryPackageReloadRunByIdOk'
require_text "$smoke_file" 'sourceRuntimeRegistryArchiveReloadRunByIdOk'
require_text "$smoke_file" 'sourceRuntimeRegistryReloadNegativeRejected'
require_text "$smoke_file" 'sourceRuntimeRegistryReloadNegativeReasonCode'
require_text "$smoke_file" 'sourceRuntimeRegistryReloadCorruptMetadataRejected'
require_text "$smoke_file" 'sourceRuntimeRegistryReloadCorruptMetadataReasonCode'
require_text "$smoke_file" 'sourceRuntimeRegistryReloadCorruptMetadataAttemptedWamrExecution'
require_text "$smoke_file" 'metadata_missing'
require_text "$smoke_file" 'metadata_invalid'
require_text "$smoke_file" 'source_id_mismatch'
require_text "$smoke_file" 'malformed_json'
require_text "$smoke_file" 'missing_or_invalid_operation'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdNullRequestRejected'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdNullRequestAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdArrayRequestRejected'
require_text "$smoke_file" 'sourceRuntimeRunRequestByIdArrayRequestAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionRunRequestOk'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionImportRegisterOk'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionPersistReloadOk'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionSearchOk'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionNonSearchOk'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionUnknownSourceRejected'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionUnknownSourceAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionSourceIdMismatchRejected'
require_text "$smoke_file" 'sourceRuntimeArchiveIngestionSourceIdMismatchAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimeInstalledSourceInventoryOk'
require_text "$smoke_file" 'sourceRuntimeInstalledSourceInventoryExpectedSourceIdPresentOnce'
require_text "$smoke_file" 'sourceRuntimeInstalledSourceInventorySafeFieldsOk'
require_text "$smoke_file" 'sourceRuntimeInstalledSourceInventoryNoRawPathLeak'
require_text "$smoke_file" 'sourceRuntimeInstalledSourceInventoryNoFullManifestLeak'
require_text "$smoke_file" 'sourceRuntimeInstalledSourceInventoryNoWasmBytesLeak'
require_text "$smoke_file" 'sourceRuntimeInstalledSourceInventorySelectedRunRequestOk'
require_text "$smoke_file" 'compactInstalledSourceInventoryForHilog'
require_text "$smoke_file" 'koma.sourceRuntimeSmoke.phase'
require_text "$smoke_file" 'setup-persisted-inventory'
require_text "$smoke_file" 'reload-persisted-inventory'
require_text "$smoke_file" 'persisted-payload-missing'
require_text "$smoke_file" 'sourceRuntimePersistedInventoryRestartOk'
require_text "$smoke_file" 'sourceRuntimePersistedInventoryRestartSetupOk'
require_text "$smoke_file" 'sourceRuntimePersistedInventoryRestartReloadOnlyOk'
require_text "$smoke_file" 'sourceRuntimePersistedInventoryRestartMetadataWrittenOk'
require_text "$smoke_file" 'sourceRuntimePersistedInventoryRestartMetadataReloadedOk'
require_text "$smoke_file" 'sourceRuntimePersistedInventoryRestartReloadOnlyDidNotImportArchive'
require_text "$smoke_file" 'runSourceRuntimePersistedInventoryReloadSmoke'
require_text "$smoke_file" 'sourceRuntimePersistedPayloadMissingOk'
require_text "$smoke_file" 'sourceRuntimePersistedPayloadMissingReasonCode'
require_text "$smoke_file" 'sourceRuntimePersistedPayloadMissingAttemptedWamrExecution'
require_text "$smoke_file" 'sourceRuntimePersistedPayloadMissingReloadOnlyDidNotImportArchive'
require_text "$smoke_file" 'runSourceRuntimePersistedPayloadMissingSmoke'
require_text "$smoke_file" 'importRegisterPersistRemovePayloadReloadAndRunLocalSourceArchiveRequest'
require_text "$smoke_file" 'sourceId: item.sourceId'
require_text "$smoke_file" 'displayName: item.displayName'
require_text "$smoke_file" 'wasmByteCount: item.wasmByteCount'
require_text "$smoke_file" 'app-local-source-archive-ingestion-run-request-test-only'
if rg -q 'sourceRuntimeInstalledSourceInventory = undefined' "$smoke_file"; then
  echo "compact smoke result must emit sanitized sourceRuntimeInstalledSourceInventory evidence" >&2
  exit 1
fi
if rg -q 'stageRawfileSourcePackage|importLocalSourceArchive' "$smoke_file"; then
  echo "device smoke must consume SourceRuntimeService for package/archive happy paths, not direct importer helpers" >&2
  exit 1
fi
require_text "$source_runtime_runner_file" 'NativeSourceRuntime.runJsonCall'
require_text "$source_runtime_runner_file" 'NativeSourceRuntime.runJsonCallFromBytes'
require_text "$source_runtime_runner_file" 'runSourceOperationFromBytes'
require_text "$source_runtime_runner_file" 'runSearchFixtureFromBytes'
require_text "$source_runtime_runner_file" 'runSourceApiFixtureOperationsFromBytes'
require_text "$source_runtime_runner_file" 'runSourceApiFixtureOperationsForSourceIdFromBytes'
require_text "$source_runtime_runner_file" 'runSourceRuntimeNegativeExecutionFromBytes'
require_text "$source_runtime_runner_file" 'SOURCE_RUNTIME_NEGATIVE_EXECUTION_REQUESTS'
require_text "$source_runtime_runner_file" '"operation":"unknown_operation"'
require_text "$source_runtime_runner_file" '"requestId":"device-negative-missing-operation-001"'
require_text "$source_runtime_runner_file" '"operation":123'
require_text "$source_runtime_runner_file" 'didNotDefaultToSearch'
require_text "$source_runtime_runner_file" 'responseReachedSearchFixture'
require_text "$source_runtime_runner_file" 'responseReachedSearchFixture'
require_text "$source_runtime_runner_file" 'Fixture Series'
require_text "$source_runtime_runner_file" 'manga:fixture-series'
require_text "$source_runtime_runner_file" 'chapter:fixture-series:001'
require_text "$source_runtime_runner_file" 'page:fixture-series:001:0001'
require_text "$source_runtime_runner_file" 'fixture-page-1'
require_text "$source_runtime_runner_file" 'get_manga'
require_text "$source_runtime_runner_file" 'get_chapters'
require_text "$source_runtime_runner_file" 'get_pages'
require_text "$source_runtime_runner_file" '"network":false'
require_text "$source_package_importer_file" 'zlib.decompressFile'
require_text "$source_package_importer_file" 'SourceArchiveValidationReason'
require_text "$source_package_importer_file" 'checksum_mismatch'
require_text "$source_package_importer_file" 'network_not_allowed'
require_text "$source_package_importer_file" 'unsafe_archive_entry'
require_text "$source_package_importer_file" 'missing_manifest'
require_text "$source_package_importer_file" 'missing_wasm'
require_text "$source_package_importer_file" 'attemptedWamrExecution: false'
require_text "$source_runtime_service_file" 'runStagedRawfileSourcePackage'
require_text "$source_runtime_service_file" 'importAndRunLocalSourceArchive'
require_text "$source_runtime_service_file" 'importRegisterPersistReloadAndRunLocalSourceArchiveRequest'
require_text "$source_runtime_service_file" 'importArchiveNegativeFixturesWithoutExecution'
require_text "$source_runtime_service_file" 'SourceRuntimeRegistry'
require_text "$source_runtime_service_file" 'stageAndRegisterRawfileSourcePackage'
require_text "$source_runtime_service_file" 'importAndRegisterLocalSourceArchive'
require_text "$source_runtime_service_file" 'runRegisteredSourceApiOperationsById'
require_text "$source_runtime_service_file" 'runRegisteredSourceRequestById'
require_text "$source_runtime_service_file" 'runSourceRuntimeRegistryNegativeEvidence'
require_text "$source_runtime_service_file" 'persistReloadAndRunRegisteredSourcesById'
require_text "$source_runtime_service_file" 'persistSourceRuntimeRegistryMetadata'
require_text "$source_runtime_service_file" 'reloadSourceRuntimeRegistryFromMetadata'
require_text "$source_runtime_service_file" 'runSourceRuntimeRegistryReloadNegativeEvidence'
require_text "$source_runtime_service_file" 'runSourceRuntimeRegistryReloadCorruptMetadataEvidence'
require_text "$source_runtime_service_file" 'SourceRuntimeServiceRegistryReloadSummary'
require_text "$source_runtime_service_file" 'metadata_missing'
require_text "$source_runtime_service_file" 'metadata_invalid'
require_text "$source_runtime_service_file" 'source_id_mismatch'
require_text "$source_runtime_service_file" 'malformed_json'
require_text "$source_runtime_service_file" 'missing_or_invalid_operation'
require_text "$source_runtime_service_file" 'source_id_not_registered'
require_text "$source_runtime_service_file" 'SourceRuntimeServiceRunRequestByIdSummary'
require_text "$source_runtime_service_file" 'SourceRuntimeServiceArchiveIngestionRunSummary'
require_text "$source_runtime_service_file" 'SourceRuntimeServicePersistedInventoryReloadSummary'
require_text "$source_runtime_service_file" 'SourceRuntimeServicePersistedPayloadMissingSummary'
require_text "$source_runtime_service_file" 'reloadPersistedSourceInventoryAndRunRequestById'
require_text "$source_runtime_service_file" 'importRegisterPersistRemovePayloadReloadAndRunLocalSourceArchiveRequest'
require_text "$source_runtime_service_file" 'reloadOnlyDidNotImportArchive: true'
require_text "$source_runtime_service_file" 'listInstalledSourceSummaries'
require_text "$source_runtime_service_file" 'installedSourceInventoryOk'
require_text "$source_runtime_service_file" 'sourceRuntimeInstalledSourceInventorySafetyOk'
require_text "$source_runtime_service_file" 'selectedSourceIdRunRequestById'
require_text "$source_runtime_service_file" 'attemptedWamrExecution: false'
require_text "$source_runtime_service_file" "request === null || typeof request !== 'object' || Array.isArray(request)"
require_text "$source_runtime_service_file" 'nullRequestRunRequestById'
require_text "$source_runtime_service_file" 'arrayRequestRunRequestById'
require_text "$source_runtime_service_file" 'stageRawfileSourcePackage'
require_text "$source_runtime_service_file" 'importLocalSourceArchive'
require_text "$source_runtime_service_file" 'runSearchFixtureFromBytes'
require_text "$source_runtime_service_file" 'runSourceApiFixtureOperationsForSourceIdFromBytes'
require_text "$source_runtime_service_file" 'runSourceApiFixtureOperationsFromBytes'
require_text "$source_runtime_service_file" 'runSourceRuntimeNegativeExecutionFromBytes'
require_text "$source_runtime_service_file" 'SourceRuntimeServiceRunSummary'
require_text "$source_runtime_service_file" 'sourceRuntimeExecutionNegativeOk'
require_text "$source_runtime_service_file" 'sourceRuntimeExecutionNegativeCases'
require_text "$source_runtime_service_file" 'searchResponseCompatible'
require_text "$source_runtime_service_file" 'attemptedWamrExecution: true'
require_text "$source_runtime_service_file" 'network'
if ! rg -U -q 'importRegisterPersistReloadAndRunLocalSourceArchiveRequest[\s\S]*importAndRegisterLocalSourceArchive[\s\S]*persistSourceRuntimeRegistryMetadata[\s\S]*reloadSourceRuntimeRegistryFromMetadata[\s\S]*runRegisteredSourceRequestById' "$source_runtime_service_file"; then
  echo "archive ingestion helper must compose import/register, persist, reload, then run-request-by-id" >&2
  exit 1
fi

if ! rg -U -q 'runRegisteredSourceRequestById[\s\S]*registry\.lookup[\s\S]*JSON\.parse[\s\S]*runSourceOperationFromBytes' "$source_runtime_service_file"; then
  echo "single-request run-by-id must lookup and validate before WAMR execution" >&2
  exit 1
fi

if ! rg -U -q 'reloadPersistedSourceInventoryAndRunRequestById[\s\S]*reloadSourceRuntimeRegistryFromMetadata[\s\S]*listInstalledSourceSummaries[\s\S]*runRegisteredSourceRequestById' "$source_runtime_service_file"; then
  echo "persisted inventory reload helper must reload metadata, list sanitized inventory, then run request by sourceId" >&2
  exit 1
fi

if ! rg -U -q 'importRegisterPersistRemovePayloadReloadAndRunLocalSourceArchiveRequest[\s\S]*importAndRegisterLocalSourceArchive[\s\S]*persistSourceRuntimeRegistryMetadata[\s\S]*fs\.unlink[\s\S]*reloadPersistedSourceInventoryAndRunRequestById' "$source_runtime_service_file"; then
  echo "persisted payload missing helper must import/register, persist metadata, remove app-local wasm payload, then use reload-only request path" >&2
  exit 1
fi

reload_helper="$(sed -n '/export function reloadPersistedSourceInventoryAndRunRequestById/,/^}/p' "$source_runtime_service_file")"
if printf '%s\n' "$reload_helper" | rg -q 'importAndRegisterLocalSourceArchive|importLocalSourceArchive|stageRawfileSourcePackage'; then
  echo "persisted inventory reload-only helper must not import or stage source archives" >&2
  exit 1
fi

payload_missing_helper="$(sed -n '/export async function importRegisterPersistRemovePayloadReloadAndRunLocalSourceArchiveRequest/,/^}/p' "$source_runtime_service_file")"
if ! printf '%s\n' "$payload_missing_helper" | rg -q 'reloadPersistedSourceInventoryAndRunRequestById'; then
  echo "persisted payload missing helper must delegate reload/run to the reload-only helper" >&2
  exit 1
fi
require_text "$source_runtime_registry_file" 'class SourceRuntimeRegistry'
require_text "$source_runtime_registry_file" 'register'
require_text "$source_runtime_registry_file" 'lookup'
require_text "$source_runtime_registry_file" 'missing_source_id'
require_text "$source_runtime_registry_file" 'duplicate_source_id'
require_text "$source_runtime_registry_file" 'validation_failed'
require_text "$source_runtime_registry_file" 'source_id_not_registered'
require_text "$source_runtime_registry_file" 'persistToAppLocalMetadata'
require_text "$source_runtime_registry_file" 'reloadFromAppLocalMetadata'
require_text "$source_runtime_registry_file" 'SourceRuntimeRegistryPersistedMetadata'
require_text "$source_runtime_registry_file" 'SourceRuntimeRegistryPersistedEntry'
require_text "$source_runtime_registry_file" 'SourceRuntimeRegistryInstalledSourceSummary'
require_text "$source_runtime_registry_file" 'listInstalledSourceSummaries'
require_text "$source_runtime_registry_file" 'displayName'
require_text "$source_runtime_registry_file" 'wasmByteCount'
require_text "$source_runtime_registry_file" 'httpEnabled: false'
require_text "$source_runtime_registry_file" 'schemaVersion'
require_text "$source_runtime_registry_file" 'Array.isArray'
require_text "$source_runtime_registry_file" 'persistedEntryShapeInvalid'
require_text "$source_runtime_registry_file" "typeof entry.sourceId !== 'string'"
require_text "$source_runtime_registry_file" "typeof entry.wasmByteCount !== 'number'"
require_text "$source_runtime_registry_file" 'Number.isInteger'
require_text "$source_runtime_registry_file" "entry.importStatus !== 'staged'"
require_text "$source_runtime_registry_file" 'metadata_missing'
require_text "$source_runtime_registry_file" 'metadata_invalid'
require_text "$source_runtime_registry_file" 'missing_wasm_path'
require_text "$source_runtime_registry_file" 'wasm_missing'
require_text "$source_runtime_registry_file" 'wasm_byte_count_mismatch'
require_text "$source_runtime_registry_file" 'readBytesSync'
require_text "$source_runtime_registry_file" 'hashOk:true'
require_text "$source_runtime_registry_file" 'network:false'
require_text "$entry_ability_file" 'maybeRunSourceRuntimeDeviceSmoke'
require_text "$entry_ability_file" 'onCreate'
require_text "$entry_ability_file" 'onNewWant'

rawfile_magic="$(od -An -tx1 -N8 "$rawfile_fixture" | tr -d ' \n')"
if [[ "$rawfile_magic" != "0061736d01000000" ]]; then
  echo "rawfile wasm fixture does not start with wasm magic/version: $rawfile_magic" >&2
  exit 1
fi
rawfile_size="$(wc -c < "$rawfile_fixture" | tr -d ' ')"
if (( rawfile_size <= 0 || rawfile_size > 4096 )); then
  echo "rawfile wasm fixture must stay a small test-only fixture, got ${rawfile_size} bytes" >&2
  exit 1
fi
if ! strings "$rawfile_fixture" | rg -q 'Fixture Series|fixture init reached host imports'; then
  echo "rawfile wasm fixture does not contain expected test fixture evidence" >&2
  exit 1
fi

rust_rawfile_magic="$(od -An -tx1 -N8 "$rust_rawfile_fixture" | tr -d ' \n')"
if [[ "$rust_rawfile_magic" != "0061736d01000000" ]]; then
  echo "rust rawfile wasm fixture does not start with wasm magic/version: $rust_rawfile_magic" >&2
  exit 1
fi
rust_rawfile_size="$(wc -c < "$rust_rawfile_fixture" | tr -d ' ')"
if (( rust_rawfile_size <= 0 || rust_rawfile_size > 131072 )); then
  echo "rust rawfile wasm fixture must stay inside the source-package maxWasmBytes test boundary, got ${rust_rawfile_size} bytes" >&2
  exit 1
fi
if ! strings "$rust_rawfile_fixture" | rg -q 'Rust WAMR runtime smoke|rust fixture init reached host imports'; then
  echo "rust rawfile wasm fixture does not contain expected Rust fixture evidence" >&2
  exit 1
fi
if ! strings "$rust_rawfile_fixture" | rg -q '"requestEcho":"fixture"'; then
  echo "rust rawfile wasm fixture does not contain requestEcho fixture evidence" >&2
  exit 1
fi

python3 tools/wasm-runtime-spike/source-package/validate-local-source-archive-fixture.py \
  --archive "$archive_fixture" \
  --artifact-dir "${KOMA_NAPI_SOURCE_RUNTIME_ARTIFACT_DIR:-.hermes-artifacts/napi-source-runtime-static/source-archive-fixture}" >/dev/null

if rg -q 'NativeSourceRuntime\\.(hello|add)' "$smoke_file"; then
  echo "device smoke route must prove runJsonCall, not hello/add sample methods" >&2
  exit 1
fi

if rg -q 'NativeSourceRuntime\\.runJsonCall' "$smoke_file"; then
  echo "device smoke route must execute through SourceRuntimeRunner, not direct native runtime calls" >&2
  exit 1
fi

if rg -q 'napi-sample|Koma native source runtime sample' "$smoke_file"; then
  echo "device smoke route still references old hardcoded napi sample proof" >&2
  exit 1
fi

changed_ui_files="$(git diff --name-only -- entry/src/main/ets/pages entry/src/main/ets/components entry/src/main/ets/model entry/src/main/ets/import entry/src/main/ets/remote entry/src/main/module.json5)"
if [[ -n "$changed_ui_files" ]]; then
  echo "unexpected product/UI changes:" >&2
  echo "$changed_ui_files" >&2
  exit 1
fi

unexpected_entryability_changes="$(git diff --name-only -- entry/src/main/ets/entryability | rg -v '^entry/src/main/ets/entryability/EntryAbility\.ets$' || true)"
if [[ -n "$unexpected_entryability_changes" ]]; then
  echo "unexpected entryability changes:" >&2
  echo "$unexpected_entryability_changes" >&2
  exit 1
fi

if git diff --name-only | rg -q '(^|/)(Aidoku|AidokuRunner|aidoku-rs|source-market|marketplace|plugin-market)'; then
  echo "unexpected source marketplace/plugin/Aidoku-shaped path changed" >&2
  exit 1
fi

require_text "tools/wasm-runtime-spike/wasm/source_fixture.c" 'import_module\("koma_host"\)'
require_text "tools/wasm-runtime-spike/wasm/source_fixture.c" 'import_name\("log"\)'
require_text "tools/wasm-runtime-spike/wasm/source_fixture.c" 'import_name\("check_cancel"\)'
require_text "tools/wasm-runtime-spike/host/host_runner.cpp" 'native_module_name = "koma_host"'
require_text "tools/wasm-runtime-spike/host/host_runner.cpp" 'HOST_LOG'
require_text "tools/wasm-runtime-spike/host/host_runner.cpp" 'HOST_CHECK_CANCEL'

source_management_changes="$(git diff --name-only | rg '(^|/)(source|sources|market|marketplace|plugin).*(Page|View|Store|Service|Client)\.(ets|ts|cpp)$' | rg -v '^entry/src/main/ets/sourceRuntime/SourceRuntimeService\.ets$' || true)"
if [[ -n "$source_management_changes" ]]; then
  echo "unexpected source management or marketplace-shaped product changes" >&2
  echo "$source_management_changes" >&2
  exit 1
fi

echo "NAPI source runtime sample static contract OK"

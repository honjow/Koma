import { fileIo as fs } from '@kit.CoreFileKit'
import {
  LocalSourcePackageManifest,
  normalizeSourceOperationCapabilityToken,
  normalizeSourceOperationCapabilityTokens,
} from './SourcePackageImporter'

export type SourceRuntimeRegistryRouteStatus = 'staged' | 'imported'

export interface SourceRuntimeRegistryEntryInput {
  sourceId: string
  route: string
  importStatus: SourceRuntimeRegistryRouteStatus
  manifest: LocalSourcePackageManifest
  wasmBytes: Uint8Array
  hashOk: boolean
  network: boolean
  enabled?: boolean
  capabilities?: string[]
  manifestPath?: string
  wasmPath?: string
  archivePath?: string
}

export interface SourceRuntimeRegistryEntry {
  sourceId: string
  manifestId: string
  manifestName: string
  manifestVersion: string
  route: string
  importStatus: SourceRuntimeRegistryRouteStatus
  wasmBytes: Uint8Array
  wasmByteCount: number
  hashOk: boolean
  network: boolean
  enabled: boolean
  language: string
  type: string
  nsfw: boolean
  capabilities: string[]
  validationEvidence: string[]
  manifestPath?: string
  wasmPath?: string
  archivePath?: string
}

export interface SourceRuntimeRegistryRegisterResult {
  ok: boolean
  reasonCode?: string
  entry?: SourceRuntimeRegistryEntry
  sourceCount: number
}

export interface SourceRuntimeRegistryLookupResult {
  ok: boolean
  reasonCode?: string
  entry?: SourceRuntimeRegistryEntry
  sourceCount: number
}

export interface SourceRuntimeRegistryPersistedEntry {
  sourceId: string
  manifestId: string
  manifestName: string
  manifestVersion: string
  route: string
  importStatus: SourceRuntimeRegistryRouteStatus
  wasmByteCount: number
  hashOk: boolean
  network: boolean
  enabled?: boolean
  language?: string
  type?: string
  nsfw?: boolean
  capabilities?: string[]
  wasmPath?: string
  manifestPath?: string
  archivePath?: string
}

export interface SourceRuntimeRegistryPersistedMetadata {
  schemaVersion: number
  entries: SourceRuntimeRegistryPersistedEntry[]
}

export interface SourceRuntimeRegistryPersistResult {
  ok: boolean
  reasonCode?: string
  metadataPath: string
  persistedSourceCount: number
}

export interface SourceRuntimeRegistryReloadResult {
  ok: boolean
  reasonCode?: string
  metadataPath: string
  registry: SourceRuntimeRegistry
  reloadedSourceCount: number
}

export interface SourceRuntimeRegistryInstalledSourceSummary {
  sourceId: string
  displayName: string
  version: string
  wasmByteCount: number
  importStatus: SourceRuntimeRegistryRouteStatus
  networkEnabled: boolean
  httpEnabled: boolean
  enabled: boolean
  language: string
  nsfw: boolean
  status: string
  capabilities: string[]
}

export function sourceRuntimeEntryEnabled(entry: SourceRuntimeRegistryEntry | undefined): boolean {
  return entry !== undefined && entry.enabled !== false
}

function normalizeSourceRuntimeSourceId(sourceId: string): string {
  return sourceId.trim()
}

function sourceRuntimeRegistryEvidence(input: SourceRuntimeRegistryEntryInput): string[] {
  const evidence: string[] = []
  if (input.hashOk) {
    evidence.push('hashOk:true')
  }
  if (input.network === false) {
    evidence.push('network:false')
  }
  evidence.push(`wasmBytes:${input.wasmBytes.byteLength}`)
  evidence.push(`manifestId:${input.manifest.package.id}`)
  evidence.push(`manifestVersion:${input.manifest.package.version}`)
  evidence.push(`route:${input.route}`)
  evidence.push(`importStatus:${input.importStatus}`)
  evidence.push(`enabled:${input.enabled === false ? 'false' : 'true'}`)
  return evidence
}

function capabilitiesFromManifest(manifest: LocalSourcePackageManifest): string[] {
  const capabilities: string[] = ['search', 'detail', 'chapters', 'pages']
  const operationCapabilities = normalizeSourceOperationCapabilityTokens(manifest.operationCapabilities)
  operationCapabilities.forEach((capability: string) => {
    if (capabilities.indexOf(capability) < 0) {
      capabilities.push(capability)
    }
  })
  if (manifest.permissions.network) {
    capabilities.push('network')
  }
  if (manifest.permissions.hostImports.length > 0) {
    capabilities.push('hostImports:' + manifest.permissions.hostImports.length.toString())
  }
  return capabilities
}

function displayCapabilityTokenAllowed(token: string): boolean {
  return normalizeSourceOperationCapabilityToken(token) === token ||
    token === 'network' ||
    token.startsWith('hostImports:')
}

function normalizedCapabilityList(input: string[] | undefined, manifest: LocalSourcePackageManifest): string[] {
  const manifestCapabilities = capabilitiesFromManifest(manifest)
  if (input === undefined || input.length === 0) {
    return manifestCapabilities
  }
  const capabilities: string[] = []
  input.forEach((item: string) => {
    const trimmed = item.trim()
    if (displayCapabilityTokenAllowed(trimmed) &&
      manifestCapabilities.indexOf(trimmed) >= 0 &&
      capabilities.indexOf(trimmed) < 0) {
      capabilities.push(trimmed)
    }
  })
  return capabilities.length > 0 ? capabilities : manifestCapabilities
}

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
  } finally {
    closeFileQuietly(file)
  }
}

function readTextSync(path: string): string {
  return fs.readTextSync(path, { encoding: 'utf-8' })
}

function readBytesSync(path: string): Uint8Array {
  let file: fs.File | undefined = undefined
  try {
    const stat = fs.statSync(path)
    const buffer = new ArrayBuffer(stat.size)
    file = fs.openSync(path, fs.OpenMode.READ_ONLY)
    const readBytes = fs.readSync(file.fd, buffer)
    return new Uint8Array(buffer, 0, readBytes)
  } finally {
    closeFileQuietly(file)
  }
}

function ensureDirSync(path: string): void {
  if (fs.accessSync(path)) {
    return
  }
  fs.mkdirSync(path, true)
}

function parentPath(path: string): string {
  const normalized = path.replace(/\\/g, '/')
  const marker = normalized.lastIndexOf('/')
  return marker < 0 ? '' : normalized.substring(0, marker)
}

function ensureParentDirSync(path: string): void {
  const parent = parentPath(path)
  if (parent.length > 0) {
    ensureDirSync(parent)
  }
}

function manifestForReload(entry: SourceRuntimeRegistryPersistedEntry): LocalSourcePackageManifest {
  return {
    schemaVersion: 1,
    package: {
      id: entry.manifestId,
      name: entry.manifestName,
      version: entry.manifestVersion,
      language: entry.language ?? 'en',
      type: entry.type ?? 'wasm-source-fixture',
      nsfw: entry.nsfw === true,
    },
    runtime: {
      abi: 'koma-source-abi-v0.1',
      hostAbi: 'koma-host-v0.1',
      wasmPath: entry.wasmPath ?? '',
      wasmSha256: '',
      wasmSizeBytes: entry.wasmByteCount,
      maxWasmBytes: entry.wasmByteCount,
    },
    permissions: {
      network: false,
      hostImports: [],
    },
    operationCapabilities: normalizeSourceOperationCapabilityTokens(entry.capabilities),
    contentPolicy: {
      publicIndex: false,
      marketplace: false,
      builtInSource: false,
      remoteInstall: false,
    },
  }
}

function persistedEntryFromRegistryEntry(entry: SourceRuntimeRegistryEntry): SourceRuntimeRegistryPersistedEntry {
  return {
    sourceId: entry.sourceId,
    manifestId: entry.manifestId,
    manifestName: entry.manifestName,
    manifestVersion: entry.manifestVersion,
    route: entry.route,
    importStatus: entry.importStatus,
    wasmByteCount: entry.wasmByteCount,
    hashOk: entry.hashOk,
    network: entry.network,
    enabled: entry.enabled,
    language: entry.language,
    type: entry.type,
    nsfw: entry.nsfw,
    capabilities: entry.capabilities,
    wasmPath: entry.wasmPath,
    manifestPath: entry.manifestPath,
    archivePath: entry.archivePath,
  }
}

function parseSourceRuntimeRegistryMetadata(metadataPath: string): SourceRuntimeRegistryPersistedMetadata | undefined {
  try {
    return JSON.parse(readTextSync(metadataPath)) as SourceRuntimeRegistryPersistedMetadata
  } catch (_err) {
    return undefined
  }
}

function reloadFailure(
  reasonCode: string,
  metadataPath: string,
  registry: SourceRuntimeRegistry,
): SourceRuntimeRegistryReloadResult {
  return {
    ok: false,
    reasonCode,
    metadataPath,
    registry,
    reloadedSourceCount: registry.count(),
  }
}

function isPositiveInteger(value: number): boolean {
  return Number.isInteger(value) && value > 0
}

function optionalPersistedPathIsValid(value: string | undefined): boolean {
  return value === undefined || typeof value === 'string'
}

function persistedEntryShapeInvalid(entry: SourceRuntimeRegistryPersistedEntry): boolean {
  if (typeof entry.sourceId !== 'string' ||
    typeof entry.manifestId !== 'string' ||
    typeof entry.manifestName !== 'string' ||
    typeof entry.manifestVersion !== 'string' ||
    typeof entry.route !== 'string' ||
    typeof entry.importStatus !== 'string' ||
    typeof entry.wasmPath !== 'string') {
    return true
  }
  if (entry.importStatus !== 'staged' && entry.importStatus !== 'imported') {
    return true
  }
  if (typeof entry.wasmByteCount !== 'number' || !isPositiveInteger(entry.wasmByteCount)) {
    return true
  }
  if (entry.hashOk !== true || entry.network !== false) {
    return true
  }
  if (entry.enabled !== undefined && typeof entry.enabled !== 'boolean') {
    return true
  }
  if (entry.language !== undefined && typeof entry.language !== 'string') {
    return true
  }
  if (entry.type !== undefined && typeof entry.type !== 'string') {
    return true
  }
  if (entry.nsfw !== undefined && typeof entry.nsfw !== 'boolean') {
    return true
  }
  if (entry.capabilities !== undefined) {
    if (!Array.isArray(entry.capabilities)) {
      return true
    }
    for (let index = 0; index < entry.capabilities.length; index += 1) {
      if (typeof entry.capabilities[index] !== 'string') {
        return true
      }
    }
  }
  return !optionalPersistedPathIsValid(entry.manifestPath) || !optionalPersistedPathIsValid(entry.archivePath)
}

export class SourceRuntimeRegistry {
  private entries: SourceRuntimeRegistryEntry[] = []

  register(input: SourceRuntimeRegistryEntryInput): SourceRuntimeRegistryRegisterResult {
    const sourceId = normalizeSourceRuntimeSourceId(input.sourceId)
    if (sourceId.length === 0) {
      return { ok: false, reasonCode: 'missing_source_id', sourceCount: this.entries.length }
    }
    if (input.manifest.package.id.trim().length === 0) {
      return { ok: false, reasonCode: 'missing_manifest_id', sourceCount: this.entries.length }
    }
    if (!input.hashOk || input.network !== false || input.wasmBytes.byteLength <= 0) {
      return { ok: false, reasonCode: 'validation_failed', sourceCount: this.entries.length }
    }
    for (let index = 0; index < this.entries.length; index += 1) {
      if (this.entries[index].sourceId === sourceId) {
        return { ok: false, reasonCode: 'duplicate_source_id', sourceCount: this.entries.length }
      }
    }

    const entry: SourceRuntimeRegistryEntry = {
      sourceId,
      manifestId: input.manifest.package.id,
      manifestName: input.manifest.package.name,
      manifestVersion: input.manifest.package.version,
      route: input.route,
      importStatus: input.importStatus,
      wasmBytes: input.wasmBytes,
      wasmByteCount: input.wasmBytes.byteLength,
      hashOk: input.hashOk,
      network: input.network,
      enabled: input.enabled === false ? false : true,
      language: input.manifest.package.language,
      type: input.manifest.package.type,
      nsfw: input.manifest.package.nsfw,
      capabilities: normalizedCapabilityList(input.capabilities, input.manifest),
      validationEvidence: sourceRuntimeRegistryEvidence(input),
      manifestPath: input.manifestPath,
      wasmPath: input.wasmPath,
      archivePath: input.archivePath,
    }
    this.entries.push(entry)
    return { ok: true, entry, sourceCount: this.entries.length }
  }

  lookup(sourceId: string): SourceRuntimeRegistryLookupResult {
    const normalized = normalizeSourceRuntimeSourceId(sourceId)
    if (normalized.length === 0) {
      return { ok: false, reasonCode: 'missing_source_id', sourceCount: this.entries.length }
    }
    for (let index = 0; index < this.entries.length; index += 1) {
      const entry = this.entries[index]
      if (entry.sourceId === normalized) {
        return { ok: true, entry, sourceCount: this.entries.length }
      }
    }
    return { ok: false, reasonCode: 'source_id_not_registered', sourceCount: this.entries.length }
  }

  count(): number {
    return this.entries.length
  }

  list(): SourceRuntimeRegistryEntry[] {
    return this.entries.slice()
  }

  setEnabled(sourceId: string, enabled: boolean): boolean {
    const normalized = normalizeSourceRuntimeSourceId(sourceId)
    for (let index = 0; index < this.entries.length; index += 1) {
      if (this.entries[index].sourceId === normalized) {
        this.entries[index].enabled = enabled
        return true
      }
    }
    return false
  }

  remove(sourceId: string): SourceRuntimeRegistryEntry | undefined {
    const normalized = normalizeSourceRuntimeSourceId(sourceId)
    for (let index = 0; index < this.entries.length; index += 1) {
      if (this.entries[index].sourceId === normalized) {
        const removed = this.entries[index]
        this.entries.splice(index, 1)
        return removed
      }
    }
    return undefined
  }

  listInstalledSourceSummaries(): SourceRuntimeRegistryInstalledSourceSummary[] {
    const summaries: SourceRuntimeRegistryInstalledSourceSummary[] = []
    for (let index = 0; index < this.entries.length; index += 1) {
      const entry = this.entries[index]
      if (!entry.enabled) {
        continue
      }
      const summary: SourceRuntimeRegistryInstalledSourceSummary = {
        sourceId: entry.sourceId,
        displayName: entry.manifestName,
        version: entry.manifestVersion,
        wasmByteCount: entry.wasmByteCount,
        importStatus: entry.importStatus,
        networkEnabled: false,
        httpEnabled: false,
        enabled: entry.enabled,
        language: entry.language,
        nsfw: entry.nsfw,
        status: entry.importStatus,
        capabilities: entry.capabilities,
      }
      summaries.push(summary)
    }
    return summaries
  }

  persistToAppLocalMetadata(metadataPath: string): SourceRuntimeRegistryPersistResult {
    for (let index = 0; index < this.entries.length; index += 1) {
      const entry = this.entries[index]
      if (entry.wasmPath === undefined || entry.wasmPath.trim().length === 0) {
        return {
          ok: false,
          reasonCode: 'missing_wasm_path',
          metadataPath,
          persistedSourceCount: 0,
        }
      }
      if (!fs.accessSync(entry.wasmPath)) {
        return {
          ok: false,
          reasonCode: 'wasm_missing',
          metadataPath,
          persistedSourceCount: 0,
        }
      }
      const wasmBytes = readBytesSync(entry.wasmPath)
      if (wasmBytes.byteLength !== entry.wasmByteCount) {
        return {
          ok: false,
          reasonCode: 'wasm_byte_count_mismatch',
          metadataPath,
          persistedSourceCount: 0,
        }
      }
    }

    const metadata: SourceRuntimeRegistryPersistedMetadata = {
      schemaVersion: 1,
      entries: this.entries.map((entry: SourceRuntimeRegistryEntry) => persistedEntryFromRegistryEntry(entry)),
    }
    ensureParentDirSync(metadataPath)
    writeTextSync(metadataPath, JSON.stringify(metadata))
    return {
      ok: true,
      metadataPath,
      persistedSourceCount: metadata.entries.length,
    }
  }

  static reloadFromAppLocalMetadata(metadataPath: string): SourceRuntimeRegistryReloadResult {
    const registry = new SourceRuntimeRegistry()
    if (!fs.accessSync(metadataPath)) {
      return reloadFailure('metadata_missing', metadataPath, registry)
    }

    try {
      const metadata = parseSourceRuntimeRegistryMetadata(metadataPath)
      if (metadata === undefined || metadata.schemaVersion !== 1 || !Array.isArray(metadata.entries)) {
        return reloadFailure('metadata_invalid', metadataPath, registry)
      }

      for (let index = 0; index < metadata.entries.length; index += 1) {
        const entry = metadata.entries[index]
        if (entry === undefined || entry === null || Array.isArray(entry) || typeof entry !== 'object') {
          return reloadFailure('metadata_invalid', metadataPath, registry)
        }
        if (persistedEntryShapeInvalid(entry)) {
          return reloadFailure('metadata_invalid', metadataPath, registry)
        }

        const sourceId = normalizeSourceRuntimeSourceId(entry.sourceId)
        if (sourceId.length === 0) {
          return reloadFailure('missing_source_id', metadataPath, registry)
        }
        const wasmPath = entry.wasmPath as string
        if (wasmPath.trim().length === 0) {
          return reloadFailure('missing_wasm_path', metadataPath, registry)
        }
        if (!fs.accessSync(wasmPath)) {
          return reloadFailure('wasm_missing', metadataPath, registry)
        }

        const wasmBytes = readBytesSync(wasmPath)
        if (wasmBytes.byteLength !== entry.wasmByteCount) {
          return reloadFailure('wasm_byte_count_mismatch', metadataPath, registry)
        }

        const registered = registry.register({
          sourceId,
          route: entry.route,
          importStatus: entry.importStatus,
          manifest: manifestForReload(entry),
          wasmBytes,
          hashOk: entry.hashOk,
          network: entry.network,
          enabled: entry.enabled === false ? false : true,
          capabilities: entry.capabilities,
          manifestPath: entry.manifestPath,
          wasmPath,
          archivePath: entry.archivePath,
        })
        if (!registered.ok) {
          return reloadFailure(registered.reasonCode ?? 'metadata_invalid', metadataPath, registry)
        }
      }

      return {
        ok: true,
        metadataPath,
        registry,
        reloadedSourceCount: registry.count(),
      }
    } catch (_err) {
      return reloadFailure('metadata_invalid', metadataPath, registry)
    }
  }
}

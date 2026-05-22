import { LocalSourcePackageManifest } from './SourcePackageImporter'

export type SourceRuntimeRegistryRouteStatus = 'staged' | 'imported'

export interface SourceRuntimeRegistryEntryInput {
  sourceId: string
  route: string
  importStatus: SourceRuntimeRegistryRouteStatus
  manifest: LocalSourcePackageManifest
  wasmBytes: Uint8Array
  hashOk: boolean
  network: boolean
  manifestPath?: string
  wasmPath?: string
  archivePath?: string
}

export interface SourceRuntimeRegistryEntry {
  sourceId: string
  manifestId: string
  manifestVersion: string
  route: string
  importStatus: SourceRuntimeRegistryRouteStatus
  wasmBytes: Uint8Array
  wasmByteCount: number
  hashOk: boolean
  network: boolean
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
  return evidence
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
      manifestVersion: input.manifest.package.version,
      route: input.route,
      importStatus: input.importStatus,
      wasmBytes: input.wasmBytes,
      wasmByteCount: input.wasmBytes.byteLength,
      hashOk: input.hashOk,
      network: input.network,
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
}

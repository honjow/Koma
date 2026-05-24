import { resourceManager } from '@kit.LocalizationKit'
import { LocalSourcePackageManifest } from './SourcePackageImporter'
import { SourceRuntimeRegistry } from './SourceRuntimeRegistry'

const DEV_SOURCE_ROUTE: string = 'bundled-dev-rawfile-source'

interface BundledDevSource {
  sourceId: string
  displayName: string
  version: string
  rawfilePath: string
}

const BUNDLED_DEV_SOURCES: BundledDevSource[] = [
  {
    sourceId: 'baozimh-browse',
    displayName: 'Baozimh',
    version: 'dev',
    rawfilePath: 'test/baozimh.wasm',
  },
  {
    sourceId: 'mangadex-browse',
    displayName: 'MangaDex',
    version: 'dev',
    rawfilePath: 'test/mangadex.wasm',
  },
]

export const appSourceRuntimeRegistry: SourceRuntimeRegistry = new SourceRuntimeRegistry()

function createBundledDevManifest(source: BundledDevSource, wasmByteCount: number): LocalSourcePackageManifest {
  return {
    schemaVersion: 1,
    package: {
      id: source.sourceId,
      name: source.displayName,
      version: source.version,
      language: 'multi',
      type: 'wasm-source-dev',
      nsfw: false,
    },
    runtime: {
      abi: 'koma-source-abi-v0.1',
      hostAbi: 'koma-host-v0.1',
      wasmPath: source.rawfilePath,
      wasmSha256: '',
      wasmSizeBytes: wasmByteCount,
      maxWasmBytes: wasmByteCount,
    },
    permissions: {
      network: false,
      hostImports: [],
    },
    contentPolicy: {
      publicIndex: false,
      marketplace: false,
      builtInSource: false,
      remoteInstall: false,
    },
  }
}

export function registerBundledDevSourcesForBrowse(resourceMgr: resourceManager.ResourceManager): number {
  if (appSourceRuntimeRegistry.count() > 0) {
    return appSourceRuntimeRegistry.count()
  }

  for (let index = 0; index < BUNDLED_DEV_SOURCES.length; index += 1) {
    const source = BUNDLED_DEV_SOURCES[index]
    try {
      const wasmBytes = resourceMgr.getRawFileContentSync(source.rawfilePath)
      appSourceRuntimeRegistry.register({
        sourceId: source.sourceId,
        route: DEV_SOURCE_ROUTE,
        importStatus: 'staged',
        manifest: createBundledDevManifest(source, wasmBytes.byteLength),
        wasmBytes: new Uint8Array(wasmBytes.buffer),
        hashOk: true,
        network: false,
        wasmPath: source.rawfilePath,
      })
    } catch (error) {
      const e = error as Error
      console.error('register bundled browse source failed: ' + source.sourceId + ': ' + e.message)
    }
  }

  return appSourceRuntimeRegistry.count()
}

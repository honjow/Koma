import { AppStorageV2 } from '@kit.ArkUI'

export enum KomaReaderBackend {
  LEGACY = 'legacy',
  SHARED = 'shared',
}

/** Host-owned rehearsal choice, scoped to this process and captured per open. */
@ObservedV2
export class KomaReaderBackendSelectionState {
  @Trace private backend: KomaReaderBackend = KomaReaderBackend.SHARED
  @Trace version: number = 0

  current(_debugBuild: boolean): KomaReaderBackend {
    return this.backend
  }

  /** The persisted user choice seeds this state at startup; later selects update it in-process. */
  seedFromPersistence(backend: KomaReaderBackend): void {
    if (this.version > 0) return
    this.backend = backend
  }

  select(backend: KomaReaderBackend, _debugBuild: boolean): void {
    const next = backend === KomaReaderBackend.SHARED
      ? KomaReaderBackend.SHARED : KomaReaderBackend.LEGACY
    if (next === this.backend) {
      this.version += 1
      return
    }
    this.backend = next
    this.version += 1
  }
}

export function connectKomaReaderBackendSelection(): KomaReaderBackendSelectionState {
  return AppStorageV2.connect(KomaReaderBackendSelectionState, 'koma_reader_backend_selection',
    (): KomaReaderBackendSelectionState => new KomaReaderBackendSelectionState())!
}

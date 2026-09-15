import { AppStorageV2 } from '@kit.ArkUI'

export enum KomaReaderBackend {
  LEGACY = 'legacy',
  SHARED = 'shared',
}

/** Host-owned rehearsal choice, scoped to this process and captured per open. */
@ObservedV2
export class KomaReaderBackendSelectionState {
  @Trace private backend: KomaReaderBackend = KomaReaderBackend.LEGACY

  current(debugBuild: boolean): KomaReaderBackend {
    return debugBuild ? this.backend : KomaReaderBackend.LEGACY
  }

  select(backend: KomaReaderBackend, debugBuild: boolean): void {
    const next = debugBuild && backend === KomaReaderBackend.SHARED
      ? KomaReaderBackend.SHARED : KomaReaderBackend.LEGACY
    if (next === this.backend) return
    this.backend = next
  }
}

export function connectKomaReaderBackendSelection(): KomaReaderBackendSelectionState {
  return AppStorageV2.connect(KomaReaderBackendSelectionState, 'koma_reader_backend_selection',
    (): KomaReaderBackendSelectionState => new KomaReaderBackendSelectionState())!
}

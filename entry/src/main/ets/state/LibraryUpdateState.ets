import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class LibraryUpdateState {
  @Trace busy: boolean = false
  @Trace revision: number = 0
  shelfChanged: boolean = false
}

const LIBRARY_UPDATE_STATE_KEY: string = 'v2:libraryUpdate'

export function connectLibraryUpdateState(): LibraryUpdateState {
  return AppStorageV2.connect(LibraryUpdateState, LIBRARY_UPDATE_STATE_KEY, () => new LibraryUpdateState())!
}

export class LibraryUpdateStateBridge {
  static setBusy(value: boolean): void {
    connectLibraryUpdateState().busy = value
  }

  static notifyCompleted(shelfChanged: boolean = true): void {
    const state = connectLibraryUpdateState()
    state.shelfChanged = shelfChanged
    state.revision += 1
  }
}

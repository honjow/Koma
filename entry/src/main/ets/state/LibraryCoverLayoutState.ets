import { AppStorageV2 } from '@kit.ArkUI'

/** A projection of committed LibraryFilterStore preferences, not another store. */
@ObservedV2
export class LibraryCoverLayoutState {
  @Trace density: string = 'standard'
}

export function connectLibraryCoverLayout(): LibraryCoverLayoutState {
  return AppStorageV2.connect(LibraryCoverLayoutState, 'komaLibraryCoverLayout',
    () => new LibraryCoverLayoutState())!
}

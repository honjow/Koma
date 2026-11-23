import { AppStorageV2 } from '@kit.ArkUI'
import { LibraryGridSpacing } from '../model/LibraryGridPreferences'

/** A projection of committed LibraryFilterStore preferences, not another store. */
@ObservedV2
export class LibraryCoverLayoutState {
  @Trace gridSpacing: LibraryGridSpacing = 'standard'
  @Trace gridColumnWidth: number = 0
}

export function connectLibraryCoverLayout(): LibraryCoverLayoutState {
  return AppStorageV2.connect(LibraryCoverLayoutState, 'komaLibraryCoverLayout',
    () => new LibraryCoverLayoutState())!
}

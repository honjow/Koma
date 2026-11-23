import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class SourceBrowseState {
  @Trace hideInLibrary: boolean = false
}

export function connectSourceBrowseState(): SourceBrowseState {
  return AppStorageV2.connect(SourceBrowseState, 'koma_source_browse', () => new SourceBrowseState())!
}

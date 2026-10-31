import { AppStorageV2 } from '@kit.ArkUI'
import { ReaderDisplaySettings, normalizeReaderDisplaySettings } from '../model/ReaderDisplaySettings'

/** A sheet's live slider draft; durable preferences still belong to ReaderPreferencesStore. */
@ObservedV2
export class ReaderDisplayPreviewState {
  @Trace settings: ReaderDisplaySettings | null = null
  set(settings: ReaderDisplaySettings | null): void {
    this.settings = settings === null ? null : normalizeReaderDisplaySettings(settings)
  }
}

export function connectReaderDisplayPreview(): ReaderDisplayPreviewState {
  return AppStorageV2.connect(ReaderDisplayPreviewState, 'koma:readerDisplayPreview',
    (): ReaderDisplayPreviewState => new ReaderDisplayPreviewState())!
}

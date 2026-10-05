import { ReaderAssetFailure } from '@reader-kit/core'
import { AppStrings } from '../i18n/AppStrings'

/** Koma owns its reader failure copy; reader-kit only carries this presentation value. */
export class KomaReaderFailure {
  static from(_error: Error): ReaderAssetFailure {
    return new ReaderAssetFailure('pageUnavailable', AppStrings.get('reader_page_load_failed'))
  }
}

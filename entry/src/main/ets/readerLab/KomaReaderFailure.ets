import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ReaderAssetFailure } from '@reader-kit/core'
import { AppStrings } from '../i18n/AppStrings'

/** Koma owns its reader failure copy; reader-kit only carries this presentation value. */
export class KomaReaderFailure {
  static catalogMessage(error: Error): string {
    return error.message === 'koma_reader_source_chapter_unsupported'
      ? AppStrings.get('reader_source_chapter_unsupported') : ''
  }

  static from(error: Error): ReaderAssetFailure {
    DiagnosticLogger.warn('reader', 'page_unavailable',
      DiagnosticLogger.errorSummary(error))
    return new ReaderAssetFailure('pageUnavailable',
      KomaReaderFailure.catalogMessage(error) || AppStrings.get('reader_page_load_failed'))
  }
}

import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ReaderAssetFailure } from '@reader-kit/core'
import { AppStrings } from '../i18n/AppStrings'
import { SourceFailureDetails, SourceRuntimeError } from '../model/SourceRuntimeError'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'

/** Koma owns its reader failure copy; reader-kit only carries this presentation value. */
export class KomaReaderFailure {
  static sourceError(reason?: string, details?: SourceFailureDetails): Error {
    if (reason === 'unsupported' && details?.kind !== 'host_feature_required') {
      return new Error('koma_reader_source_chapter_unsupported')
    }
    if (details !== undefined) {
      const error: Record<string, Object | string | number | boolean | null> = {}
      error['code'] = details.code
      error['status'] = details.status
      const response: SourceRuntimeCallResponse = { ok: false, reasonCode: details.reason, error }
      return new SourceRuntimeError(response)
    }
    return new Error('koma_reader_chapter_pages_unavailable')
  }

  static catalogMessage(error: Error): string {
    if (error instanceof SourceRuntimeError) return error.userTextFor(AppStrings.get('reader_page_load_failed'))
    return error.message === 'koma_reader_source_chapter_unsupported'
      ? AppStrings.get('reader_source_chapter_unsupported') : ''
  }

  static from(error: Error): ReaderAssetFailure {
    DiagnosticLogger.warn('reader', 'page_unavailable',
      error instanceof SourceRuntimeError
        ? `kind=${error.diagnostic.kind} reason=${error.diagnostic.reason} error=${error.diagnostic.code} http=${error.diagnostic.status}`
        : DiagnosticLogger.errorSummary(error))
    if (error instanceof SourceRuntimeError && error.diagnostic.kind === 'image_quota_exhausted') {
      return new ReaderAssetFailure('pageUnavailable', AppStrings.get('source_failure_image_quota_exhausted'),
        AppStrings.get('source_failure_image_quota_hint'))
    }
    return new ReaderAssetFailure('pageUnavailable',
      KomaReaderFailure.catalogMessage(error) || AppStrings.get('reader_page_load_failed'))
  }
}

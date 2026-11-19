import { AppStrings } from '../i18n/AppStrings'
import { Comic } from './ComicModels'

export function libraryUpdateComicTitle(comic: Comic | undefined): string {
  const title = comic?.title.trim() ?? ''
  return title.length > 0 ? title : AppStrings.get('library_update_results_unavailable_comic')
}

export function libraryUpdateFailureText(code: string): string {
  switch (code) {
    case 'timeout': return AppStrings.get('library_update_failure_timeout')
    case 'network_error': return AppStrings.get('source_pkg_reason_network_error')
    case 'auth_error': return AppStrings.get('library_update_failure_auth')
    case 'source_runtime_error': return AppStrings.get('library_update_failure_source')
    case 'storage_error': return AppStrings.get('library_update_failure_storage')
    default: return AppStrings.get('library_update_failure_unknown')
  }
}

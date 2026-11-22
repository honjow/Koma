import { AppStrings } from '../i18n/AppStrings'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { Comic, ComicSourceKind } from './ComicModels'

export function libraryUpdateComicTitle(comic: Comic | undefined): string {
  const title = comic?.title.trim() ?? ''
  return title.length > 0 ? title : AppStrings.get('library_update_results_unavailable_comic')
}

function libraryUpdateComicSourceName(comic: Comic | undefined): string {
  const sourceId = comic?.sourceRuntimeId?.trim() ?? ''
  if (sourceId.length > 0) {
    // Resolve the exact library work's source. Older records may only have an
    // opaque result key, while the work can still retain its public source name.
    const savedName = comic?.sourceMetadata?.sourceName?.trim() ?? ''
    const fallback = savedName.length > 0 && savedName !== sourceId
      ? savedName : AppStrings.get('library_source_package')
    return sourceDisplayName(sourceId, fallback).trim() || fallback
  }
  switch (comic?.sourceKind) {
    case ComicSourceKind.LOCAL_ARCHIVE:
    case ComicSourceKind.LOCAL_FOLDER: return AppStrings.get('library_source_local')
    case ComicSourceKind.PRIVATE_LIBRARY: return AppStrings.get('library_source_private')
    case ComicSourceKind.KOMGA_REMOTE: return AppStrings.get('route_komga_title')
    case ComicSourceKind.KAVITA_REMOTE: return AppStrings.get('route_kavita_title')
    case ComicSourceKind.OPDS_REMOTE: return AppStrings.get('route_opds_title')
    case ComicSourceKind.WEBDAV_REMOTE: return AppStrings.get('route_webdav_title')
    default: return ''
  }
}

export function libraryUpdateRowSubtitle(comic: Comic | undefined, detail: string): string {
  const source = libraryUpdateComicSourceName(comic)
  if (source.length === 0) return detail
  return detail.trim().length > 0 ? `${source} · ${detail}` : source
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

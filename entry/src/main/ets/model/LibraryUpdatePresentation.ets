import { AppStrings } from '../i18n/AppStrings'
import { Comic } from './ComicModels'
import { LibraryUpdateComicResult, LibraryUpdateProviderKind, LibraryUpdateProviderSummary } from './LibraryUpdateService'

export interface LibraryUpdateSourceLabel {
  id: string
  name: string
}

export function libraryUpdateComicTitle(comic: Comic | undefined): string {
  const title = comic?.title.trim() ?? ''
  return title.length > 0 ? title : AppStrings.get('library_update_results_unavailable_comic')
}

function libraryUpdateProviderKindTitle(kind: LibraryUpdateProviderKind): string {
  switch (kind) {
    case 'local': return AppStrings.get('library_source_local')
    case 'source_runtime': return AppStrings.get('library_source_package')
    case 'komga': return AppStrings.get('route_komga_title')
    case 'kavita': return AppStrings.get('route_kavita_title')
    case 'opds': return AppStrings.get('route_opds_title')
    case 'webdav': return AppStrings.get('route_webdav_title')
    case 'private_library': return AppStrings.get('library_source_private')
    default: return AppStrings.get('library_update_results_unsupported_source')
  }
}

// The persisted source key is deliberately opaque. Resolve through matching
// result identities instead of displaying that key or inventing another hash.
export function libraryUpdateProviderTitle(
  provider: LibraryUpdateProviderSummary,
  results: LibraryUpdateComicResult[],
  comics: Comic[],
  sources: LibraryUpdateSourceLabel[],
): string {
  if (provider.providerKind === 'source_runtime') {
    for (const result of results) {
      if (result.providerKind !== provider.providerKind || result.sourceKey !== provider.sourceKey) {
        continue
      }
      const comic = comics.find((item: Comic): boolean => item.id === result.comicId)
      const source = sources.find((item: LibraryUpdateSourceLabel): boolean => item.id === comic?.sourceRuntimeId)
      if (source !== undefined && source.name.trim().length > 0) {
        return source.name.trim()
      }
    }
  }
  return libraryUpdateProviderKindTitle(provider.providerKind)
}

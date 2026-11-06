import { AppStrings } from '../i18n/AppStrings'
import { LibrarySortBy, LibrarySortDirection, librarySortDirection } from '../model/LibraryStore'

interface LibrarySortOption {
  key: LibrarySortBy
  labelKey: string
}

const SORT_OPTIONS: LibrarySortOption[] = [
  { key: 'lastRead', labelKey: 'library_sort_last_read' },
  { key: 'lastUpdate', labelKey: 'library_sort_last_update' },
  { key: 'latestChapter', labelKey: 'library_sort_latest_chapter' },
  { key: 'added', labelKey: 'library_sort_added' },
  { key: 'unreadCount', labelKey: 'library_sort_unread_count' },
  { key: 'chapterCount', labelKey: 'library_sort_chapter_count' },
  { key: 'title', labelKey: 'library_sort_title' },
  { key: 'source', labelKey: 'library_sort_source' },
]

function directionLabel(sortBy: LibrarySortBy, direction: LibrarySortDirection): string {
  const ascending = direction === 'asc'
  if (sortBy === 'title' || sortBy === 'source') {
    return AppStrings.get(ascending ? 'library_sort_forward' : 'library_sort_reverse')
  }
  if (sortBy === 'unreadCount' || sortBy === 'chapterCount') {
    return AppStrings.get(ascending ? 'library_sort_fewest_first' : 'library_sort_most_first')
  }
  return AppStrings.get(ascending ? 'library_sort_oldest_first' : 'library_sort_newest_first')
}

export function librarySortSummary(sortBy: LibrarySortBy, direction?: LibrarySortDirection): string {
  const option = SORT_OPTIONS.find((item: LibrarySortOption): boolean => item.key === sortBy) ?? SORT_OPTIONS[0]
  return AppStrings.get(option.labelKey) + ' · ' + directionLabel(sortBy, librarySortDirection(sortBy, direction))
}

// All shelf sorting entries share the native group separator and checkmarks.
@Builder
export function LibrarySortMenuItems(
  sortBy: LibrarySortBy,
  direction: LibrarySortDirection,
  select: (sortBy: LibrarySortBy, direction: LibrarySortDirection) => void,
) {
  MenuItemGroup() {
    ForEach(SORT_OPTIONS, (option: LibrarySortOption) => {
      MenuItem({ content: AppStrings.get(option.labelKey) })
        .selected(sortBy === option.key)
        .selectIcon(true)
        .onClick(() => {
          if (sortBy !== option.key) select(option.key, librarySortDirection(option.key))
        })
    }, (option: LibrarySortOption): string => option.key)
  }
  MenuItemGroup() {
    MenuItem({ content: directionLabel(sortBy, librarySortDirection(sortBy)) })
      .selected(direction === librarySortDirection(sortBy))
      .selectIcon(true)
      .onClick(() => { select(sortBy, librarySortDirection(sortBy)) })
    MenuItem({ content: directionLabel(sortBy, librarySortDirection(sortBy) === 'asc' ? 'desc' : 'asc') })
      .selected(direction !== librarySortDirection(sortBy))
      .selectIcon(true)
      .onClick(() => { select(sortBy, librarySortDirection(sortBy) === 'asc' ? 'desc' : 'asc') })
  }
}

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')

function source(path) {
  return readFileSync(resolve(root, path), 'utf8')
}

const comicModels = source('entry/src/main/ets/model/ComicModels.ets')
const libraryStore = source('entry/src/main/ets/model/LibraryStore.ets')
const libraryFilterStore = source('entry/src/main/ets/model/LibraryFilterStore.ets')
const libraryPersistence = source('entry/src/main/ets/model/LibraryPersistence.ets')
const mockLibraryData = source('entry/src/main/ets/model/MockLibraryData.ets')
const comicCoverCard = source('entry/src/main/ets/components/ComicCoverCard.ets')
const libraryPage = source('entry/src/main/ets/pages/LibraryPage.ets')
const libraryCategoryPage = source('entry/src/main/ets/pages/LibraryCategoryManagementPage.ets')
const settingsPage = source('entry/src/main/ets/pages/SettingsPage.ets')
const indexPage = source('entry/src/main/ets/pages/Index.ets')

function assertContains(haystack, needle, message) {
  assert.notEqual(haystack.indexOf(needle), -1, message)
}

function normalizeCategoryIds(categoryIds) {
  if (categoryIds === undefined) return []
  const nextIds = []
  for (const categoryId of categoryIds) {
    const normalized = categoryId.trim()
    if (normalized.length > 0 && !nextIds.includes(normalized)) {
      nextIds.push(normalized)
    }
  }
  return nextIds
}

function addCategoryId(categoryIds, categoryId) {
  return normalizeCategoryIds([...normalizeCategoryIds(categoryIds), categoryId])
}

function removeCategoryId(categoryIds, categoryId) {
  return normalizeCategoryIds(categoryIds).filter((item) => item !== categoryId)
}

assertContains(comicModels, "LIBRARY_CATEGORY_FAVORITE_ID: string = 'favorite'", 'favorite category id must remain stable')
assertContains(comicModels, "LIBRARY_CATEGORY_READ_LATER_ID: string = 'read_later'", 'read later category id must remain stable')
assert.match(comicModels, /categoryIds\?:\s*string\[\][\s\S]*export function normalizeCategoryIds/, 'Comic must keep durable optional categoryIds with normalization')

assert.match(libraryPersistence, /categoryIds\?:\s*string\[\][\s\S]*const categoryIds = normalizeCategoryIds\(comic\.categoryIds\)[\s\S]*row\.categoryIds = categoryIds[\s\S]*const categoryIds = normalizeCategoryIds\(row\.categoryIds\)[\s\S]*comic\.categoryIds = categoryIds/, 'LibraryPersistence must persist and hydrate categoryIds')
assert.match(libraryPersistence, /export function updateComicCategoryMembershipAndPersistLibraryStore\([\s\S]*categoryId: string,[\s\S]*selected: boolean[\s\S]*withComicAddedCategoryId[\s\S]*withComicRemovedCategoryId[\s\S]*persistenceService\.persist\(\)/, 'batch category actions must add or remove one category without replacing unrelated categories')

assert.match(libraryStore, /filterSource\?:\s*ComicSourceKind\[\][\s\S]*filterReadState\?:\s*LibraryReadStateFilter[\s\S]*filterCategoryId\?:\s*LibraryCategoryFilter/, 'category filtering must compose with source and read-state filters')
assert.match(libraryStore, /categoryFilter === 'all'[\s\S]*categoryFilter === 'uncategorized'[\s\S]*categoryIds\.includes\(categoryFilter\)/, 'LibraryStore must support all, uncategorized, and concrete category filters')
assert.match(libraryStore, /moveCustomCategory\(categoryId: string, direction: 'up' \| 'down'[\s\S]*targetIndex = direction === 'up' \? index - 1 : index \+ 1[\s\S]*sortOrder: target\.sortOrder[\s\S]*sortOrder: current\.sortOrder/, 'LibraryStore must reorder custom categories by swapping durable sortOrder values')
assert.match(libraryStore, /export interface LibraryCategoryDisplayStrategy[\s\S]*categoryId: LibraryCategoryDisplayCategoryId[\s\S]*sortBy: LibrarySortBy[\s\S]*readState: LibraryReadStateFilter[\s\S]*listCategoryDisplayStrategies\(\): LibraryCategoryDisplayStrategy\[\][\s\S]*setCategoryDisplayStrategy\(strategy: LibraryCategoryDisplayStrategy\)/, 'LibraryStore must expose durable category display strategies')
assert.match(libraryFilterStore, /LIBRARY_SORT_KEY[\s\S]*LIBRARY_FILTER_SOURCE_KEY[\s\S]*LIBRARY_FILTER_READ_STATE_KEY[\s\S]*LIBRARY_FILTER_CATEGORY_KEY[\s\S]*category: normalizeCategory\(category\)[\s\S]*store\.put\(LIBRARY_FILTER_CATEGORY_KEY/, 'filter preferences must persist category alongside existing sort/source/read-state filters')
assert.match(libraryPersistence, /categoryDisplayStrategies\?: PersistedCategoryDisplayStrategy\[\][\s\S]*persistCategoryDisplayStrategy[\s\S]*hydrateCategoryDisplayStrategy[\s\S]*replaceCategoryDisplayStrategies[\s\S]*setCategoryDisplayStrategyAndPersistLibraryStore/, 'LibraryPersistence must persist and hydrate category display strategies')
assert.match(libraryPersistence, /function assertValidPersistedCategoryDisplayStrategy[\s\S]*assertStringField\(row\.categoryId, 'categoryDisplayStrategy\.categoryId'\)[\s\S]*row\.categoryId\.trim\(\)\.length === 0[\s\S]*throw new Error\('Invalid library store persistence categoryDisplayStrategy\.categoryId: expected non-empty category id'\)[\s\S]*function parseValidatedLibraryStoreDocument[\s\S]*assertValidPersistedCategoryDisplayStrategy[\s\S]*export function hydrateLibraryStoreFromJson[\s\S]*const document = parseValidatedLibraryStoreDocument\(payload\)[\s\S]*libraryStore\.clear\(\)[\s\S]*libraryStore\.replaceCategoryDisplayStrategies/, 'LibraryPersistence parser must reject whitespace-only categoryDisplayStrategies.categoryId before mutating the live store')
assert.match(libraryPersistence, /document\.categoryDisplayStrategies === undefined \? \[\] : document\.categoryDisplayStrategies\.map/, 'LibraryPersistence must preserve backwards compatibility for documents missing categoryDisplayStrategies')
assert.match(libraryPersistence, /moveCustomCategoryAndPersistLibraryStore\([\s\S]*previousPayload = serializeLibraryStore\(libraryStore\)[\s\S]*libraryStore\.moveCustomCategory\(categoryId, direction\)[\s\S]*persistenceService\.persist\(\)[\s\S]*hydrateLibraryStoreFromJson\(libraryStore, previousPayload\)/, 'custom category reorder must persist atomically and roll back on persistence failure')
assert.match(libraryCategoryPage, /import \{ AppStrings \} from '..\/i18n\/AppStrings'[\s\S]*connectLanguageState[\s\S]*function s\(name: string\): string[\s\S]*AppStrings\.get\(name\)/, 'category management page must use AppStrings and subscribe to language state')
assert.doesNotMatch(libraryCategoryPage, /['"`][^'"`]*[\u4e00-\u9fff][^'"`]*['"`]/, 'category management page must not keep hardcoded Chinese UI strings')
assert.match(libraryCategoryPage, /persistMove\(categoryId: string, direction: 'up' \| 'down'\)[\s\S]*moveCustomCategoryAndPersistLibraryStore\([\s\S]*refreshCategories\(\)[\s\S]*onLibraryChanged\(\)/, 'category management page must persist category reorder and refresh library state')
assert.match(libraryCategoryPage, /MenuItem\(\{ content: s\('library_category_action_move_up'\) \}\)[\s\S]*enabled\(!this\.isFirstCategory\(category\)\)[\s\S]*persistMove\(category\.id, 'up'\)[\s\S]*MenuItem\(\{ content: s\('library_category_action_move_down'\) \}\)[\s\S]*enabled\(!this\.isLastCategory\(category\)\)[\s\S]*persistMove\(category\.id, 'down'\)/, 'category management page must expose bounded up/down controls')
assert.match(libraryCategoryPage, /setCategoryDisplayStrategyAndPersistLibraryStore[\s\S]*DisplayStrategySection\(\)[\s\S]*StrategySummaryRow\('all', s\('library_category_all'\)\)[\s\S]*StrategySummaryRow\('uncategorized', s\('library_category_uncategorized'\)\)[\s\S]*StrategySummaryRow\(LIBRARY_CATEGORY_FAVORITE_ID, s\('library_category_favorite'\)\)/, 'category management page must expose category display strategy controls from settings')
assert.match(libraryPage, /private setCategoryFilter\(category: LibraryCategoryFilter\)[\s\S]*applyCategoryDisplayStrategy\(category\)[\s\S]*getCategoryDisplayStrategy\(category\)[\s\S]*this\.sortBy = strategy\.sortBy[\s\S]*this\.filterReadState = strategy\.readState/, 'LibraryPage must apply category display strategy when users switch categories')
assert.match(libraryPage, /private hasActiveFilters\(\): boolean[\s\S]*this\.sortBy !== 'lastRead'[\s\S]*this\.filterSource !== 'all'[\s\S]*this\.filterReadState !== 'all'[\s\S]*this\.filterCategory !== 'all'[\s\S]*this\.filterAvailability !== 'all'/, 'LibraryPage must know when sort or any filter is active')
assert.match(libraryPage, /private resetFilters\(\): void[\s\S]*this\.sortBy = 'lastRead'[\s\S]*this\.filterSource = 'all'[\s\S]*this\.filterReadState = 'all'[\s\S]*this\.filterCategory = 'all'[\s\S]*this\.filterAvailability = 'all'[\s\S]*this\.refreshDisplayedSnapshotFromStore\(\)[\s\S]*this\.saveFilterPreferences\(\)/, 'LibraryPage reset must restore default sort/source/read/category/download filters and persist them')
assert.match(libraryPage, /if \(this\.hasActiveFilters\(\)\) \{[\s\S]*KomaActionButton\(\{[\s\S]*label: s\('common_reset'\)[\s\S]*this\.resetFilters\(\)/, 'LibraryPage filter bar must expose a reset action when any sort or filter is active')
assert.match(settingsPage, /key: 'library-default-sort', titleKey: 'settings_row_library_default_sort_title'[^}]*}/, 'Settings must expose library default sort as a real row')
assert.doesNotMatch(settingsPage, /key: 'library-default-sort'[^}]*placeholder: true/, 'Settings library default sort must not remain a placeholder')
assert.match(settingsPage, /LibraryFilterStore[\s\S]*loadLibraryFilterPreferences\(\)[\s\S]*this\.libraryDefaultSortBy = preferences\.sortBy/, 'Settings must load library default sort from the library filter store')
assert.match(settingsPage, /saveLibraryDefaultSort\(sortBy: LibrarySortBy\)[\s\S]*preferences\.sortBy = sortBy[\s\S]*this\.libraryFilterStore\(\)\.save\(preferences\)/, 'Settings library default sort must persist through LibraryFilterStore')
assert.match(settingsPage, /row\.key === 'library-default-sort'[\s\S]*library_sort_last_read[\s\S]*library_sort_added[\s\S]*library_sort_title[\s\S]*library_sort_source/, 'Settings library default sort must render the existing sort menu options')

assert.match(libraryPage, /private addSelectedCategory\(categoryId: string\)[\s\S]*onUpdateCategoryMembershipRequested\(comicIds, categoryId, true\)/, 'LibraryPage batch bar must expose an add-category action for selected comics')
assert.match(libraryPage, /private removeSelectedCategory\(categoryId: string\)[\s\S]*onUpdateCategoryMembershipRequested\(comicIds, categoryId, false\)/, 'LibraryPage batch bar must expose a remove-category action for selected comics')
assert.match(libraryPage, /MenuItem\(\{ content: s\('library_batch_add_favorite'\) \}\)[\s\S]*addSelectedCategory\(LIBRARY_CATEGORY_FAVORITE_ID\)[\s\S]*MenuItem\(\{ content: s\('library_batch_remove_favorite'\) \}\)[\s\S]*removeSelectedCategory\(LIBRARY_CATEGORY_FAVORITE_ID\)/, 'batch actions must add and remove Favorite')
assert.match(libraryPage, /MenuItem\(\{ content: s\('library_batch_add_read_later'\) \}\)[\s\S]*addSelectedCategory\(LIBRARY_CATEGORY_READ_LATER_ID\)[\s\S]*MenuItem\(\{ content: s\('library_batch_remove_read_later'\) \}\)[\s\S]*removeSelectedCategory\(LIBRARY_CATEGORY_READ_LATER_ID\)/, 'batch actions must add and remove Read Later')
assert.match(libraryPage, /MenuItem\(\{ content: s\('library_batch_clear_categories'\) \}\)[\s\S]*assignSelectedCategory\(undefined\)/, 'batch actions must keep clear category assignment')
assert.match(libraryPage, /KomaActionButton\(\{[\s\S]*label: s\('common_remove'\)[\s\S]*kind: 'danger'[\s\S]*showBatchRemoveConfirmation\(\)/, 'existing multi-select remove action must remain available')
assert.match(indexPage, /onUpdateCategoryMembershipRequested:\s*\(comicIds: ComicId\[\], categoryId: string, selected: boolean\)[\s\S]*handleUpdateCategoryMembershipRequested\(comicIds, categoryId, selected\)/, 'Index must wire additive category membership changes into persistent library store')

assert.match(mockLibraryData, /categoryLabels: string\[\][\s\S]*formatCategoryLabels\(comic\.categoryIds\)/, 'library view model must expose category labels for cards')
assert.match(comicCoverCard, /categoryLabels\?: string\[\][\s\S]*displayCategoryLabels\(\)[\s\S]*ForEach\(this\.displayCategoryLabels\(\)[\s\S]*Text\(categoryLabel\)/, 'Library cards must render category labels for QA visibility')

assert.deepEqual(addCategoryId(['read_later'], 'favorite'), ['read_later', 'favorite'], 'adding Favorite must preserve Read Later')
assert.deepEqual(addCategoryId(['favorite'], 'favorite'), ['favorite'], 'adding a category must deduplicate')
assert.deepEqual(removeCategoryId(['read_later', 'favorite'], 'favorite'), ['read_later'], 'removing Favorite must preserve Read Later')
assert.deepEqual(removeCategoryId(['read_later'], 'read_later'), [], 'removing the only category returns uncategorized semantics')

console.log('library category static contract ok')

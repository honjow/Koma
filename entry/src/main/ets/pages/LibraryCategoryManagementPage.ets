import {
  Comic,
  CustomLibraryCategory,
  LIBRARY_CATEGORY_FAVORITE_ID,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH,
  LIBRARY_CATEGORY_READ_LATER_ID,
} from '../model/ComicModels'
import {
  LibraryCategoryDisplayCategoryId,
  LibraryCategoryDisplayStrategy,
  LibraryReadStateFilter,
  LibrarySortBy,
  LibraryStore,
} from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  createCustomCategoryAndPersistLibraryStore,
  deleteCustomCategoryAndPersistLibraryStore,
  moveCustomCategoryAndPersistLibraryStore,
  renameCustomCategoryAndPersistLibraryStore,
  setCategoryDisplayStrategyAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaDisclosureListRow } from '../components/ui/KomaDisclosureListRow'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaMenuListRow } from '../components/ui/KomaMenuListRow'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct LibraryCategoryManagementPage {
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Local private categories: CustomLibraryCategory[] = []
  @Local private draftName: string = ''
  @Local private editingCategoryId: string = ''
  @Local private editingName: string = ''
  @Local private categoryMenuKey: string = ''
  @Local private expandedStrategyCategoryId: LibraryCategoryDisplayCategoryId = 'all'
  @Local private languageState: LanguageState = connectLanguageState()

  private refreshCategories(): void {
    this.categories = this.libraryStore === undefined ? [] : this.libraryStore.listCustomCategories()
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {
    }
  }

  private categoryStrategy(categoryId: LibraryCategoryDisplayCategoryId): LibraryCategoryDisplayStrategy {
    const strategy = this.libraryStore?.getCategoryDisplayStrategy(categoryId)
    if (strategy !== undefined) {
      return strategy
    }
    return {
      categoryId,
      sortBy: 'lastRead',
      readState: 'all',
      updatedAt: 0,
    }
  }

  private sortLabel(sortBy: LibrarySortBy): string {
    if (sortBy === 'added') {
      return s('library_sort_added')
    }
    if (sortBy === 'title') {
      return s('library_sort_title')
    }
    if (sortBy === 'source') {
      return s('library_sort_source')
    }
    return s('library_sort_last_read')
  }

  private readStateLabel(readState: LibraryReadStateFilter): string {
    if (readState === 'unread') {
      return s('library_read_state_unread')
    }
    if (readState === 'reading') {
      return s('library_read_state_reading')
    }
    if (readState === 'completed') {
      return s('library_read_state_completed')
    }
    return s('library_read_state_all')
  }

  private persistCategoryStrategy(
    categoryId: LibraryCategoryDisplayCategoryId,
    sortBy: LibrarySortBy,
    readState: LibraryReadStateFilter
  ): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      setCategoryDisplayStrategyAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, {
        categoryId,
        sortBy,
        readState,
        updatedAt: Date.now(),
      })
      this.onLibraryChanged()
      this.showToast(s('library_category_display_updated'))
    } catch (_error) {
      this.showToast(s('library_category_display_save_failed'))
    }
  }

  private setCategorySort(categoryId: LibraryCategoryDisplayCategoryId, sortBy: LibrarySortBy): void {
    const strategy = this.categoryStrategy(categoryId)
    this.persistCategoryStrategy(categoryId, sortBy, strategy.readState)
    this.categoryMenuKey = ''
  }

  private setCategoryReadState(categoryId: LibraryCategoryDisplayCategoryId, readState: LibraryReadStateFilter): void {
    const strategy = this.categoryStrategy(categoryId)
    this.persistCategoryStrategy(categoryId, strategy.sortBy, readState)
    this.categoryMenuKey = ''
  }

  private strategyMenuKey(categoryId: LibraryCategoryDisplayCategoryId, kind: string): string {
    return `${categoryId}:${kind}`
  }

  private categoryActionMenuKey(categoryId: string): string {
    return `${categoryId}:actions`
  }

  private categoryStrategySummary(categoryId: LibraryCategoryDisplayCategoryId): string {
    const strategy = this.categoryStrategy(categoryId)
    return `${this.sortLabel(strategy.sortBy)} · ${this.readStateLabel(strategy.readState)}`
  }

  private toggleStrategyExpansion(categoryId: LibraryCategoryDisplayCategoryId): void {
    this.expandedStrategyCategoryId = this.expandedStrategyCategoryId === categoryId ? '' : categoryId
    this.categoryMenuKey = ''
  }

  private persistCreate(): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      createCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, this.draftName)
      this.draftName = ''
      this.refreshCategories()
      this.onLibraryChanged()
      this.showToast(s('library_category_created'))
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  private startRename(category: CustomLibraryCategory): void {
    this.editingCategoryId = category.id
    this.editingName = category.name
    this.categoryMenuKey = ''
  }

  private cancelRename(): void {
    this.editingCategoryId = ''
    this.editingName = ''
  }

  private persistRename(categoryId: string): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      renameCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, categoryId, this.editingName)
      this.cancelRename()
      this.refreshCategories()
      this.onLibraryChanged()
      this.showToast(s('library_category_renamed'))
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  private confirmDelete(category: CustomLibraryCategory): void {
    this.getUIContext().showAlertDialog({
      title: s('library_category_delete_title'),
      message: s('library_category_delete_message').replace('%s', category.name),
      autoCancel: true,
      primaryButton: {
        value: s('library_category_action_delete'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.persistDelete(category.id)
        },
      },
      secondaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
    })
  }

  private persistDelete(categoryId: string): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      if (deleteCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, categoryId)) {
        if (this.expandedStrategyCategoryId === categoryId) {
          this.expandedStrategyCategoryId = 'all'
        }
        this.categoryMenuKey = ''
        this.refreshCategories()
        this.onLibraryChanged()
        this.showToast(s('library_category_deleted'))
      }
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  @Builder
  private CategorySortMenu(categoryId: LibraryCategoryDisplayCategoryId) {
    Menu() {
      MenuItem({ content: s('library_sort_last_read') })
        .onClick(() => {
          this.setCategorySort(categoryId, 'lastRead')
        })
      MenuItem({ content: s('library_sort_added') })
        .onClick(() => {
          this.setCategorySort(categoryId, 'added')
        })
      MenuItem({ content: s('library_sort_title') })
        .onClick(() => {
          this.setCategorySort(categoryId, 'title')
        })
      MenuItem({ content: s('library_sort_source') })
        .onClick(() => {
          this.setCategorySort(categoryId, 'source')
        })
    }
  }

  @Builder
  private CategoryReadStateMenu(categoryId: LibraryCategoryDisplayCategoryId) {
    Menu() {
      MenuItem({ content: s('library_read_state_all') })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'all')
        })
      MenuItem({ content: s('library_read_state_unread') })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'unread')
        })
      MenuItem({ content: s('library_read_state_reading') })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'reading')
        })
      MenuItem({ content: s('library_read_state_completed') })
        .onClick(() => {
          this.setCategoryReadState(categoryId, 'completed')
        })
    }
  }

  @Builder
  private StrategySummaryRow(categoryId: LibraryCategoryDisplayCategoryId, title: string) {
    KomaDisclosureListRow({
      title,
      subtitle: this.categoryStrategySummary(categoryId),
      isExpanded: this.expandedStrategyCategoryId === categoryId,
      toggle: () => {
        this.toggleStrategyExpansion(categoryId)
      },
    }) {
      KomaMenuListRow({
        title: s('settings_row_library_default_sort_title'),
        trailingText: this.sortLabel(this.categoryStrategy(categoryId).sortBy),
        trailingDropdown: true,
        showChevron: false,
        isMenuOpen: this.categoryMenuKey === this.strategyMenuKey(categoryId, 'sort'),
        action: () => {
          this.categoryMenuKey = this.strategyMenuKey(categoryId, 'sort')
        },
      }) {
        this.CategorySortMenu(categoryId)
      }
      ListDivider()
      KomaMenuListRow({
        title: s('library_category_read_state_title'),
        trailingText: this.readStateLabel(this.categoryStrategy(categoryId).readState),
        trailingDropdown: true,
        showChevron: false,
        isMenuOpen: this.categoryMenuKey === this.strategyMenuKey(categoryId, 'read'),
        action: () => {
          this.categoryMenuKey = this.strategyMenuKey(categoryId, 'read')
        },
      }) {
        this.CategoryReadStateMenu(categoryId)
      }
    }
  }

  @Builder
  private DisplayStrategySection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: s('library_category_display_section') })
      GroupedListSection() {
        this.StrategySummaryRow('all', s('library_category_all'))
        ListDivider()
        this.StrategySummaryRow('uncategorized', s('library_category_uncategorized'))
        ListDivider()
        this.StrategySummaryRow(LIBRARY_CATEGORY_FAVORITE_ID, s('library_category_favorite'))
        ListDivider()
        this.StrategySummaryRow(LIBRARY_CATEGORY_READ_LATER_ID, s('library_category_read_later'))
        if (this.categories.length > 0) {
          ListDivider()
        }
        ForEach(this.categories, (category: CustomLibraryCategory, index: number) => {
          this.StrategySummaryRow(category.id, category.name)
          if (index < this.categories.length - 1) {
            ListDivider()
          }
        }, (category: CustomLibraryCategory) => category.id)
      }
    }
    .width('100%')
  }

  private persistMove(categoryId: string, direction: 'up' | 'down'): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      if (moveCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, categoryId, direction)) {
        this.refreshCategories()
        this.onLibraryChanged()
        this.showToast(s('library_category_order_updated'))
      }
    } catch (error) {
      const e = error as Error
      this.showToast(e.message)
    }
  }

  private isFirstCategory(category: CustomLibraryCategory): boolean {
    return this.categories.length > 0 && this.categories[0].id === category.id
  }

  private isLastCategory(category: CustomLibraryCategory): boolean {
    return this.categories.length > 0 && this.categories[this.categories.length - 1].id === category.id
  }

  private categoryUsageCount(categoryId: string): number {
    if (this.libraryStore === undefined) {
      return 0
    }
    return this.libraryStore.listComics().filter((comic: Comic): boolean => {
      return comic.categoryIds !== undefined && comic.categoryIds.includes(categoryId)
    }).length
  }

  @Builder
  private CategoryActionMenu(category: CustomLibraryCategory) {
    Menu() {
      MenuItem({ content: s('library_category_action_rename') })
        .onClick(() => {
          this.startRename(category)
        })
      MenuItem({ content: s('library_category_action_move_up') })
        .enabled(!this.isFirstCategory(category))
        .onClick(() => {
          this.persistMove(category.id, 'up')
        })
      MenuItem({ content: s('library_category_action_move_down') })
        .enabled(!this.isLastCategory(category))
        .onClick(() => {
          this.persistMove(category.id, 'down')
        })
      MenuItem({ content: s('library_category_action_delete') })
        .onClick(() => {
          this.confirmDelete(category)
        })
    }
  }

  @Builder
  private CustomCategoriesSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: s('library_category_custom_section') })
      GroupedListSection() {
        if (this.categories.length === 0) {
          ConciseListRow({
            title: s('library_category_empty_title'),
            showChevron: false,
          })
        } else {
          ForEach(this.categories, (category: CustomLibraryCategory, index: number) => {
            this.CategoryRow(category)
            if (index < this.categories.length - 1) {
              ListDivider()
            }
          }, (category: CustomLibraryCategory) => category.id)
        }
      }
    }
    .width('100%')
  }

  @Builder
  private CreateSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      SectionHeader({ title: s('library_category_create_section') })
      GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          KomaFormTextField({
            label: s('library_category_name_label'),
            placeholder: s('library_category_name_placeholder').replace('%s', `${LIBRARY_CATEGORY_NAME_MAX_LENGTH}`),
            value: this.draftName,
            submit: () => {
              this.persistCreate()
            },
            change: (value: string) => {
              this.draftName = value
            },
          })
          KomaActionButton({
            label: s('library_category_action_create'),
            kind: 'primary',
            fullWidth: true,
            isEnabled: this.draftName.trim().length > 0,
            action: () => {
              this.persistCreate()
            },
          })
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private CategoryRow(category: CustomLibraryCategory) {
    if (this.editingCategoryId === category.id) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        KomaFormTextField({
          label: s('library_category_name_label'),
          value: this.editingName,
          submit: () => {
            this.persistRename(category.id)
          },
          change: (value: string) => {
            this.editingName = value
          },
        })
        Row({ space: ThemeConstants.SPACE_MD }) {
          KomaActionButton({
            label: s('library_category_action_save'),
            kind: 'primary',
            fill: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.persistRename(category.id)
            },
          })
          KomaActionButton({
            label: s('common_cancel'),
            kind: 'secondary',
            fill: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.cancelRename()
            },
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    } else {
      KomaMenuListRow({
        title: category.name,
        subtitle: s('library_count_books').replace('%s', `${this.categoryUsageCount(category.id)}`),
        isMenuOpen: this.categoryMenuKey === this.categoryActionMenuKey(category.id),
        action: () => {
          this.categoryMenuKey = this.categoryActionMenuKey(category.id)
        },
      }) {
        this.CategoryActionMenu(category)
      }
    }
  }

  aboutToAppear(): void {
    this.refreshCategories()
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        ListItem() {
          this.DisplayStrategySection()
        }
        ListItem() {
          this.CustomCategoriesSection()
        }
        ListItem() {
          this.CreateSection()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

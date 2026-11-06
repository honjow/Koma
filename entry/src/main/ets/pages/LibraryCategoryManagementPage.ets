import { komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { LibrarySortMenuItems, libraryCategorySortSummary } from '../components/LibrarySortMenu'
import { common } from '@kit.AbilityKit'
import { effectiveLibraryDefaultSort, LibraryFilterStore, LibrarySortSelection } from '../model/LibraryFilterStore'
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
  LibrarySortDirection,
  librarySortDirection,
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
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaMenuListRow } from '../components/ui/KomaMenuListRow'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { LibrarySmartCategorySection } from '../components/LibrarySmartCategorySection'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct LibraryCategoryManagementPage {
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Event onDisplayStrategyChanged: (strategy: LibraryCategoryDisplayStrategy) => void = () => {}
  @Local private categoryDisplayStrategies: LibraryCategoryDisplayStrategy[] = []
  @Local private defaultSort: LibrarySortSelection = { sortBy: 'lastRead', sortDirection: 'desc' }
  @Local private categories: CustomLibraryCategory[] = []
  @Local private draftName: string = ''
  @Local private editingCategoryId: string = ''
  @Local private editingName: string = ''
  @Local private categoryMenuKey: string = ''
  @Local private languageState: LanguageState = connectLanguageState()

  private refreshCategories(): void {
    this.categories = this.libraryStore === undefined ? [] : this.libraryStore.listCustomCategories()
    this.categoryDisplayStrategies = this.libraryStore?.listCategoryDisplayStrategies() ?? []
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: message }))
    } catch (_error) {
    }
  }

  private categoryMutationErrorMessage(error: Error): string {
    const message = error.message
    const allowedValidationMessages: string[] = [
      s('library_category_error_missing'),
      s('library_category_error_name_empty'),
      AppStrings.format('library_category_error_name_too_long', LIBRARY_CATEGORY_NAME_MAX_LENGTH),
      s('library_category_error_name_builtin'),
      s('library_category_error_name_duplicate'),
    ]
    if (allowedValidationMessages.includes(message)) {
      return message
    }
    DiagnosticLogger.warn('library_category_management_page', 'mutation_failed', '[LibraryCategory] step=mutation_failed reason=category_persist')
    return s('library_category_save_failed')
  }

  private categoryStrategy(categoryId: LibraryCategoryDisplayCategoryId): LibraryCategoryDisplayStrategy {
    const strategy = this.categoryDisplayStrategies.find((value: LibraryCategoryDisplayStrategy): boolean => {
      return value.categoryId === categoryId
    })
    if (strategy !== undefined) {
      return strategy
    }
    return {
      categoryId,
      sortBy: this.defaultSort.sortBy,
      sortDirection: this.defaultSort.sortDirection,
      followsDefaultSort: true,
      readState: 'all',
      updatedAt: 0,
    }
  }

  private sortSummary(categoryId: LibraryCategoryDisplayCategoryId): string {
    return libraryCategorySortSummary(this.categoryStrategy(categoryId))
  }

  private categorySort(categoryId: LibraryCategoryDisplayCategoryId): LibrarySortSelection {
    const strategy = this.categoryStrategy(categoryId)
    return strategy.followsDefaultSort === true ? this.defaultSort : {
      sortBy: strategy.sortBy, sortDirection: librarySortDirection(strategy.sortBy, strategy.sortDirection),
    }
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
    sortDirection: LibrarySortDirection | undefined,
    readState: LibraryReadStateFilter,
    followsDefaultSort?: boolean,
  ): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      const savedStrategy = setCategoryDisplayStrategyAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, {
        categoryId,
        sortBy,
        sortDirection,
        readState,
        followsDefaultSort,
        updatedAt: Date.now(),
      })
      this.onLibraryChanged()
      this.refreshCategories()
      this.onDisplayStrategyChanged(savedStrategy)
      this.showToast(s('library_category_display_updated'))
    } catch (_error) {
      this.showToast(s('library_category_display_save_failed'))
    }
  }

  private setCategorySort(categoryId: LibraryCategoryDisplayCategoryId, sortBy: LibrarySortBy,
    direction: LibrarySortDirection, followsDefaultSort: boolean = false): void {
    const strategy = this.categoryStrategy(categoryId)
    if ((strategy.followsDefaultSort === true) === followsDefaultSort && strategy.sortBy === sortBy &&
      librarySortDirection(strategy.sortBy, strategy.sortDirection) === direction) return
    this.persistCategoryStrategy(categoryId, sortBy, direction, strategy.readState, followsDefaultSort)
    this.categoryMenuKey = ''
  }

  private setCategoryReadState(categoryId: LibraryCategoryDisplayCategoryId, readState: LibraryReadStateFilter): void {
    const strategy = this.categoryStrategy(categoryId)
    this.persistCategoryStrategy(categoryId, strategy.sortBy, strategy.sortDirection, readState, strategy.followsDefaultSort)
    this.categoryMenuKey = ''
  }

  private categoryActionMenuKey(categoryId: string): string {
    return `${categoryId}:actions`
  }

  private categoryStrategySummary(categoryId: LibraryCategoryDisplayCategoryId): string {
    const strategy = this.categoryStrategy(categoryId)
    if (categoryId === 'all') return this.readStateLabel(strategy.readState)
    return `${this.sortSummary(categoryId)} · ${this.readStateLabel(strategy.readState)}`
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
      this.showToast(this.categoryMutationErrorMessage(e))
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
      this.showToast(this.categoryMutationErrorMessage(e))
    }
  }

  private confirmDelete(category: CustomLibraryCategory): void {
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: s('library_category_delete_title'),
      message: s('library_category_delete_message').replace('%s', category.name),
      autoCancel: true,
      primaryButton: {
        value: s('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: s('library_category_action_delete'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.persistDelete(category.id)
        },
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
        this.categoryMenuKey = ''
        this.refreshCategories()
        this.onLibraryChanged()
        this.showToast(s('library_category_deleted'))
      }
    } catch (error) {
      const e = error as Error
      this.showToast(this.categoryMutationErrorMessage(e))
    }
  }

  @Builder
  private CategorySortMenu(categoryId: LibraryCategoryDisplayCategoryId, select: (action: () => void) => void) {
    Menu() {
      LibrarySortMenuItems(this.categorySort(categoryId).sortBy, this.categorySort(categoryId).sortDirection,
        (sortBy: LibrarySortBy, direction: LibrarySortDirection): void => {
          select(() => { this.setCategorySort(categoryId, sortBy, direction) })
        }, (): void => {
          select(() => {
            if (this.categoryStrategy(categoryId).followsDefaultSort !== true) {
              this.setCategorySort(categoryId, this.defaultSort.sortBy, this.defaultSort.sortDirection, true)
            }
          })
        }, this.categoryStrategy(categoryId).followsDefaultSort === true)
    }
  }

  @Builder
  private CategoryReadStateMenu(categoryId: LibraryCategoryDisplayCategoryId, select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('library_read_state_all') })
        .selected(this.categoryStrategy(categoryId).readState === 'all').selectIcon(true)
        .onClick(() => {
          select(() => { this.setCategoryReadState(categoryId, 'all') })
        })
      MenuItem({ content: s('library_read_state_unread') })
        .selected(this.categoryStrategy(categoryId).readState === 'unread').selectIcon(true)
        .onClick(() => {
          select(() => { this.setCategoryReadState(categoryId, 'unread') })
        })
      MenuItem({ content: s('library_read_state_reading') })
        .selected(this.categoryStrategy(categoryId).readState === 'reading').selectIcon(true)
        .onClick(() => {
          select(() => { this.setCategoryReadState(categoryId, 'reading') })
        })
      MenuItem({ content: s('library_read_state_completed') })
        .selected(this.categoryStrategy(categoryId).readState === 'completed').selectIcon(true)
        .onClick(() => {
          select(() => { this.setCategoryReadState(categoryId, 'completed') })
        })
    }
  }

  @Builder
  private StrategySummaryRow(categoryId: LibraryCategoryDisplayCategoryId, title: string) {
    ConciseListRow({ title, subtitle: this.categoryStrategySummary(categoryId),
      trailingDropdown: true, showChevron: false, dropdownMenuEnabled: true,
      dropdownMenuBuilder: (select: (action: () => void) => void): void => {
        this.DisplayStrategyMenu(categoryId, select)
      } })
  }

  @Builder
  private DisplayStrategyMenu(categoryId: LibraryCategoryDisplayCategoryId, select: (action: () => void) => void) {
    Menu() {
      this.DisplayStrategyItems(categoryId, select)
    }.subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  private DisplayStrategyItems(categoryId: LibraryCategoryDisplayCategoryId, select: (action: () => void) => void) {
    if (categoryId !== 'all') {
      MenuItem({ content: s('library_category_sort_title'), labelInfo: this.sortSummary(categoryId),
        builder: (): void => { this.CategorySortMenu(categoryId, select) } })
    }
    MenuItem({ content: s('library_category_read_state_title'),
      labelInfo: this.readStateLabel(this.categoryStrategy(categoryId).readState),
      builder: (): void => { this.CategoryReadStateMenu(categoryId, select) } })
  }

  @Builder
  private DisplayStrategySection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      GroupedListSection({ title: s('library_category_builtin_section') }) {
        this.StrategySummaryRow('all', s('library_category_all'))
        ListDivider()
        this.StrategySummaryRow('uncategorized', s('library_category_uncategorized'))
        ListDivider()
        this.StrategySummaryRow(LIBRARY_CATEGORY_FAVORITE_ID, s('library_category_favorite'))
        ListDivider()
        this.StrategySummaryRow(LIBRARY_CATEGORY_READ_LATER_ID, s('library_category_read_later'))
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
        this.categoryMenuKey = ''
        this.refreshCategories()
        this.onLibraryChanged()
        this.showToast(s('library_category_order_updated'))
      }
    } catch (error) {
      const e = error as Error
      this.showToast(this.categoryMutationErrorMessage(e))
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
      this.DisplayStrategyItems(category.id, (action: () => void): void => {
        this.categoryMenuKey = ''
        action()
      })
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
    }.subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  private CustomCategoriesSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      GroupedListSection({ title: s('library_category_custom_section') }) {
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
          }, (category: CustomLibraryCategory) => JSON.stringify(category))
        }
      }
    }
    .width('100%')
  }

  @Builder
  private CreateSection() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      GroupedListSection({ title: s('library_category_create_section'), inset: ThemeConstants.SPACE_LG }) {
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
        subtitle: s('library_count_books').replace('%s', `${this.categoryUsageCount(category.id)}`) +
          ' · ' + this.sortSummary(category.id),
        isMenuOpen: this.categoryMenuKey === this.categoryActionMenuKey(category.id),
        onDismiss: (): void => {
          if (this.categoryMenuKey === this.categoryActionMenuKey(category.id)) this.categoryMenuKey = ''
        },
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
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    void new LibraryFilterStore(context).load().then((value): void => {
      this.defaultSort = effectiveLibraryDefaultSort(value, this.libraryStore)
    }).catch((): void => {
      DiagnosticLogger.warn('library_category_management_page', 'load_default_sort_failed', '[LibraryCategory] step=load_default_sort_failed')
    })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        bottomPadding: ThemeConstants.SPACE_XL,
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
        ListItem() {
          LibrarySmartCategorySection({ libraryStore: this.libraryStore, persistence: this.libraryPersistenceService,
            displayStrategies: this.categoryDisplayStrategies,
            strategyItems: (categoryId: string, select: (action: () => void) => void): void => {
              this.DisplayStrategyItems(categoryId, select)
            },
            onChanged: (): void => {
              this.refreshCategories()
              this.onLibraryChanged()
            } })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

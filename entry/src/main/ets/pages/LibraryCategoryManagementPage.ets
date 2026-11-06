import { komaMenuOptions, komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  Comic,
  CustomLibraryCategory,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH,
} from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import {
  LibraryStorePersistenceService,
  createCustomCategoryAndPersistLibraryStore,
  deleteCustomCategoryAndPersistLibraryStore,
  moveCustomCategoryAndPersistLibraryStore,
  renameCustomCategoryAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaTextInputDialog } from '../components/ui/KomaTextInputDialog'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { LibrarySmartCategorySection } from '../components/LibrarySmartCategorySection'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ObservedV2
export class LibraryCategoryManagementChrome {
  @Trace createRequest: number = 0
}

@ComponentV2
export struct LibraryCategoryManagementPage {
  @Param chrome: LibraryCategoryManagementChrome = new LibraryCategoryManagementChrome()
  @Param libraryStore?: LibraryStore = undefined
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Local private categories: CustomLibraryCategory[] = []
  @Local private draftName: string = ''
  @Local private draftError: string = ''
  private categoryDialogId: number = -1
  private categoryDialogOpening: boolean = false
  private pageVisible: boolean = false
  @Local private editingCategoryId: string = ''
  @Local private languageState: LanguageState = connectLanguageState()

  private refreshCategories(): void {
    this.categories = this.libraryStore === undefined ? [] : this.libraryStore.listCustomCategories()
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
      s('library_category_error_name_duplicate'),
    ]
    if (allowedValidationMessages.includes(message)) {
      return message
    }
    DiagnosticLogger.warn('library_category_management_page', 'mutation_failed', '[LibraryCategory] step=mutation_failed reason=category_persist')
    return s('library_category_save_failed')
  }

  @Monitor('chrome.createRequest')
  private onCreateRequested(): void {
    this.openCategoryDialog()
  }

  private openCategoryDialog(category?: CustomLibraryCategory): void {
    if (this.categoryDialogId >= 0 || this.categoryDialogOpening) return
    this.categoryDialogOpening = true
    this.editingCategoryId = category?.id ?? ''
    this.draftName = category?.name ?? ''
    this.draftError = ''
    const prompt = this.getUIContext().getPromptAction()
    void prompt.openCustomDialog({
      systemMaterial: komaDialogMaterial(),
      builder: (): void => { this.CategoryDialog() },
      alignment: DialogAlignment.Center,
      autoCancel: true,
      onDidDisappear: (): void => { this.categoryDialogId = -1 },
    }).then((id: number): void => {
      this.categoryDialogId = id
      if (!this.pageVisible) this.closeCategoryDialog()
    }).catch((): void => {
      this.showToast(s('library_category_management_unavailable'))
    }).finally((): void => { this.categoryDialogOpening = false })
  }

  private closeCategoryDialog(): void {
    if (this.categoryDialogId < 0) return
    const id = this.categoryDialogId
    this.categoryDialogId = -1
    this.getUIContext().getPromptAction().closeCustomDialog(id)
  }

  private saveCategoryDialog(): void {
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.draftError = s('library_category_management_unavailable')
      return
    }
    try {
      const creating = this.editingCategoryId.length === 0
      if (creating) {
        createCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, this.draftName)
      } else {
        renameCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService,
          this.editingCategoryId, this.draftName)
      }
      this.closeCategoryDialog()
      this.refreshCategories()
      this.onLibraryChanged()
      this.showToast(s(creating ? 'library_category_created' : 'library_category_renamed'))
    } catch (error) {
      const e = error as Error
      this.draftError = this.categoryMutationErrorMessage(e)
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
        this.refreshCategories()
        this.onLibraryChanged()
        this.showToast(s('library_category_deleted'))
      }
    } catch (error) {
      const e = error as Error
      this.showToast(this.categoryMutationErrorMessage(e))
    }
  }

  private persistMove(from: number, to: number): void {
    const category = this.categories[from]
    const destination = this.categories[to]
    if (category === undefined || destination === undefined || from === to) return
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      if (moveCustomCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, category.id, destination.id)) {
        this.refreshCategories()
        this.onLibraryChanged()
      }
    } catch (error) {
      this.refreshCategories()
      this.showToast(this.categoryMutationErrorMessage(error as Error))
    }
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
        .onClick((): void => { this.openCategoryDialog(category) })
      MenuItem({ content: s('library_category_action_delete') })
        .contentFontColor(ThemeConstants.DANGER)
        .onClick((): void => { this.confirmDelete(category) })
    }
  }

  @Builder
  private CategoryActions(category: CustomLibraryCategory) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20).fontColor([ThemeConstants.TEXT_SECONDARY])
      }
      .id('library-category-actions-' + category.id)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .accessibilityText(s('common_more_actions'))
      .bindMenu(this.CategoryActionMenu(category), komaMenuOptions({ placement: Placement.BottomRight }))

      if (this.categories.length > 1) {
        SymbolGlyph($r('sys.symbol.line_3_horizontal'))
          .fontSize(20)
          .fontColor([ThemeConstants.TEXT_SECONDARY])
          .accessibilityText(s('library_category_drag_to_sort'))
      }
    }
  }

  @Builder
  private CategoryDialog() {
    KomaTextInputDialog({
      title: s(this.editingCategoryId.length === 0 ? 'library_category_create_section' : 'library_category_action_rename'),
      label: s('library_category_name_label'),
      placeholder: AppStrings.format('library_category_name_placeholder', LIBRARY_CATEGORY_NAME_MAX_LENGTH),
      value: this.draftName,
      error: this.draftError,
      confirmLabel: s(this.editingCategoryId.length === 0 ? 'library_category_action_create' : 'common_save'),
      confirmEnabled: this.draftName.trim().length > 0,
      change: (value: string): void => {
        this.draftName = value
        this.draftError = ''
      },
      confirm: (): void => { this.saveCategoryDialog() },
      cancel: (): void => { this.closeCategoryDialog() },
    })
  }

  @Builder
  private CategoryRow(category: CustomLibraryCategory) {
    ConciseListRow({
      title: category.name,
      wrapTitle: true,
      subtitle: AppStrings.format('library_count_books', this.categoryUsageCount(category.id)),
      showChevron: false,
      surfaceRadius: ThemeConstants.GROUPED_LIST_INNER_RADIUS,
      suffixBuilderParam: (): void => { this.CategoryActions(category) },
    })
  }

  private isFirstCategory(category: CustomLibraryCategory): boolean {
    return this.categories[0]?.id === category.id
  }

  private isLastCategory(category: CustomLibraryCategory): boolean {
    return this.categories[this.categories.length - 1]?.id === category.id
  }

  aboutToAppear(): void {
    this.pageVisible = true
    this.refreshCategories()
  }

  aboutToDisappear(): void {
    this.pageVisible = false
    this.closeCategoryDialog()
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 0,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        if (this.categories.length === 0) {
          ListItem() {
            GroupedListSection() {
              ConciseListRow({ title: s('library_category_empty_title'), showChevron: false })
            }
          }
        } else {
          // The native onMove callback needs direct ListItem children. Stable
          // keys preserve each row during a drag, while a rename updates its row.
          ForEach(this.categories, (category: CustomLibraryCategory) => {
            ListItem() {
              Column() {
                this.CategoryRow(category)
                if (!this.isLastCategory(category)) ListDivider()
              }
              .padding({ left: ThemeConstants.LIST_SECTION_INSET, right: ThemeConstants.LIST_SECTION_INSET,
                top: this.isFirstCategory(category) ? ThemeConstants.LIST_SECTION_INSET : 0,
                bottom: this.isLastCategory(category) ? ThemeConstants.LIST_SECTION_INSET : 0 })
            }
            .backgroundColor(ThemeConstants.CARD)
            .borderRadius({
              topLeft: this.isFirstCategory(category) ? ThemeConstants.RADIUS_CARD : 0,
              topRight: this.isFirstCategory(category) ? ThemeConstants.RADIUS_CARD : 0,
              bottomLeft: this.isLastCategory(category) ? ThemeConstants.RADIUS_CARD : 0,
              bottomRight: this.isLastCategory(category) ? ThemeConstants.RADIUS_CARD : 0,
            })
          }, (category: CustomLibraryCategory): string => category.id + ':' + category.name)
            .onMove((from: number, to: number): void => { this.persistMove(from, to) })
        }
        ListItem() {
          LibrarySmartCategorySection({ libraryStore: this.libraryStore, persistence: this.libraryPersistenceService,
            onChanged: (): void => {
              this.refreshCategories()
              this.onLibraryChanged()
            } })
        }.margin({ top: ThemeConstants.SPACE_LG })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

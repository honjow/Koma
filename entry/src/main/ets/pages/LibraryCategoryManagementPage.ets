import { common } from '@kit.AbilityKit'
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
  moveSmartCategoryAndPersistLibraryStore,
  renameCustomCategoryAndPersistLibraryStore,
  setCustomCategoryPrivacyAndPersistLibraryStore,
} from '../model/LibraryPersistence'
import { LibrarySmartCategory } from '../model/LibrarySmartCategory'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { KomaTextInputDialog } from '../components/ui/KomaTextInputDialog'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { LibrarySmartCategoryEditorController, LibrarySmartCategorySection } from '../components/LibrarySmartCategorySection'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLibraryPrivacyState, LibraryPrivacyAuthResult, LibraryPrivacyState, libraryPrivacyAuthMessage } from '../state/LibraryPrivacyState'

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
  @Param libraryRevision: number = 0
  @Param libraryPersistenceService?: LibraryStorePersistenceService = undefined
  @Event onLibraryChanged: () => void = () => {}
  @Local private categories: CustomLibraryCategory[] = []
  @Local private smartCategories: LibrarySmartCategory[] = []
  @Local private draftName: string = ''
  @Local private draftError: string = ''
  private categoryDialogId: number = -1
  private categoryDialogOpening: boolean = false
  private pageVisible: boolean = false
  @Local private editingCategoryId: string = ''
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private privacy: LibraryPrivacyState = connectLibraryPrivacyState()
  private smartCategoryEditor: LibrarySmartCategoryEditorController = new LibrarySmartCategoryEditorController()

  @Monitor('libraryRevision')
  private refreshCategories(): void {
    this.categories = this.libraryStore === undefined ? [] : this.libraryStore.listCustomCategories()
    this.smartCategories = this.libraryStore === undefined ? [] : this.libraryStore.listSmartCategories()
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
          void this.deleteAfterPrivacyCheck(category.id)
        },
      },
    })
  }

  private async verifyPrivacyChange(): Promise<boolean> {
    const result = await this.privacy.verify(this.getUIContext().getHostContext() as common.UIAbilityContext)
    const message = libraryPrivacyAuthMessage(result)
    if (message.length > 0 && this.pageVisible) this.showToast(message)
    return this.pageVisible && result === LibraryPrivacyAuthResult.SUCCESS
  }

  private async deleteAfterPrivacyCheck(id: string): Promise<void> {
    const current = this.libraryStore?.listCustomCategories().find((item: CustomLibraryCategory): boolean => item.id === id)
    if (current?.isPrivate === true && !await this.verifyPrivacyChange()) return
    if (this.pageVisible) this.persistDelete(id)
  }

  private confirmPrivacyChange(category: CustomLibraryCategory): void {
    const enabled = category.isPrivate !== true
    const title = s(enabled ? 'library_privacy_set' : 'library_privacy_unset')
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(), title,
      message: enabled ? undefined : s('library_privacy_disable_message'),
      primaryButton: { value: s('common_cancel'), action: () => {} },
      secondaryButton: { value: s('common_confirm'), action: () => { void this.persistPrivacyChange(category.id, enabled) } },
    })
  }

  private async persistPrivacyChange(id: string, enabled: boolean): Promise<void> {
    if (!await this.verifyPrivacyChange()) return
    const store = this.libraryStore
    const persistence = this.libraryPersistenceService
    if (store === undefined || persistence === undefined) return
    try {
      if (setCustomCategoryPrivacyAndPersistLibraryStore(store, persistence, id, enabled)) {
        this.refreshCategories()
        this.onLibraryChanged()
      }
    } catch (error) {
      this.showToast(this.categoryMutationErrorMessage(error as Error))
    }
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

  private smartCategoryIndex(categoryId: string): number {
    return this.smartCategories.findIndex((item: LibrarySmartCategory): boolean => item.id === categoryId)
  }

  private moveSmartByOffset(categoryId: string, offset: number): void {
    const index = this.smartCategoryIndex(categoryId)
    if (index < 0 || index + offset < 0 || index + offset >= this.smartCategories.length) return
    this.persistSmartMove(index, index + offset)
  }

  private persistSmartMove(from: number, to: number): void {
    const category = this.smartCategories[from]
    const destination = this.smartCategories[to]
    if (category === undefined || destination === undefined || from === to) return
    if (this.libraryStore === undefined || this.libraryPersistenceService === undefined) {
      this.showToast(s('library_category_management_unavailable'))
      return
    }
    try {
      if (moveSmartCategoryAndPersistLibraryStore(this.libraryStore, this.libraryPersistenceService, category.id, destination.id)) {
        this.refreshCategories()
        this.onLibraryChanged()
      }
    } catch (error) {
      this.refreshCategories()
      this.showToast(this.categoryMutationErrorMessage(error as Error))
    }
  }

  @Computed
  private get categoryUsageCounts(): Map<string, number> {
    // Category rows must not rescan the complete library once per row during
    // every build. Rebuild this projection only when the page refreshes its
    // categories or the shelf changes.
    void this.categories
    return this.libraryStore?.listCategoryUsageCounts() ?? new Map<string, number>()
  }

  private categoryUsageCount(categoryId: string): number {
    return this.categoryUsageCounts.get(categoryId) ?? 0
  }

  @Builder
  private CategoryActionMenu(category: CustomLibraryCategory) {
    Menu() {
      MenuItem({ content: s('library_category_action_rename') })
        .onClick((): void => { this.openCategoryDialog(category) })
      MenuItem({ content: s(category.isPrivate !== true ? 'library_privacy_set' : 'library_privacy_unset'),
        startIcon: $r('sys.symbol.lock') })
        .onClick((): void => { this.confirmPrivacyChange(category) })
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
      leadingIcon: category.isPrivate === true ? $r('sys.symbol.lock') : undefined,
      subtitle: category.isPrivate === true && this.privacy.visibleCategoryId !== category.id ? '' :
        AppStrings.format('library_count_books', this.categoryUsageCount(category.id)),
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

  private isFirstSmartCategory(category: LibrarySmartCategory): boolean {
    return this.smartCategories[0]?.id === category.id
  }

  @Builder
  private SmartCategoryActionMenu(group: LibrarySmartCategory) {
    Menu() {
      MenuItem({ content: s('library_smart_edit') })
        .onClick((): void => { this.smartCategoryEditor.openEdit(group) })
      MenuItem({ content: s('library_category_action_move_up') })
        .enabled(this.smartCategoryIndex(group.id) > 0)
        .onClick((): void => { this.moveSmartByOffset(group.id, -1) })
      MenuItem({ content: s('library_category_action_move_down') })
        .enabled(this.smartCategoryIndex(group.id) >= 0 && this.smartCategoryIndex(group.id) < this.smartCategories.length - 1)
        .onClick((): void => { this.moveSmartByOffset(group.id, 1) })
      MenuItem({ content: s('common_delete') })
        .contentFontColor(ThemeConstants.DANGER)
        .onClick((): void => { this.smartCategoryEditor.requestDelete(group) })
    }
  }

  @Builder
  private SmartCategoryActions(group: LibrarySmartCategory) {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.ellipsis_circle')).fontSize(20).fontColor([ThemeConstants.TEXT_SECONDARY])
      }
      .id('library-smart-category-actions-' + group.id)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .accessibilityText(s('common_more_actions'))
      .bindMenu(this.SmartCategoryActionMenu(group), komaMenuOptions({ placement: Placement.BottomRight }))

      if (this.smartCategories.length > 1) {
        SymbolGlyph($r('sys.symbol.line_3_horizontal'))
          .fontSize(20)
          .fontColor([ThemeConstants.TEXT_SECONDARY])
          .accessibilityText(s('library_category_drag_to_sort'))
      }
    }
  }

  @Builder
  private SmartCategoryRow(group: LibrarySmartCategory) {
    ConciseListRow({
      title: group.name,
      wrapTitle: true,
      subtitle: AppStrings.format('library_smart_rules_count', group.filters.length),
      showChevron: false,
      surfaceRadius: ThemeConstants.GROUPED_LIST_INNER_RADIUS,
      suffixBuilderParam: (): void => { this.SmartCategoryActions(group) },
    })
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
          // Native onMove needs direct ListItem children. Keep keys stable across a drag.
          // Rebuild the row and its bound menu when the name or privacy changes.
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
          }, (category: CustomLibraryCategory): string => category.id + ':' + category.name + ':' +
            (category.isPrivate === true ? 'private' : 'public'))
            .onMove((from: number, to: number): void => { this.persistMove(from, to) })
        }
        ListItem() {
          SectionHeader({ title: s('library_smart_title') })
        }
        .margin({ top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_XS })
        if (this.smartCategories.length > 0) {
          // Keep drag keys free of sortOrder/updatedAt so reordering does not recreate rows mid-gesture.
          ForEach(this.smartCategories, (group: LibrarySmartCategory) => {
            ListItem() {
              Column() {
                this.SmartCategoryRow(group)
                ListDivider()
              }
              .padding({ left: ThemeConstants.LIST_SECTION_INSET, right: ThemeConstants.LIST_SECTION_INSET,
                top: this.isFirstSmartCategory(group) ? ThemeConstants.LIST_SECTION_INSET : 0 })
            }
            .backgroundColor(ThemeConstants.CARD)
            .borderRadius({
              topLeft: this.isFirstSmartCategory(group) ? ThemeConstants.RADIUS_CARD : 0,
              topRight: this.isFirstSmartCategory(group) ? ThemeConstants.RADIUS_CARD : 0,
              bottomLeft: 0,
              bottomRight: 0,
            })
          }, (group: LibrarySmartCategory): string => group.id + ':' + group.name + ':' + JSON.stringify(group.filters))
            .onMove((from: number, to: number): void => { this.persistSmartMove(from, to) })
        }
        ListItem() {
          Column() {
            ConciseListRow({
              title: s('library_smart_create'),
              leadingIcon: $r('sys.symbol.plus'),
              surfaceRadius: ThemeConstants.GROUPED_LIST_INNER_RADIUS,
              action: (): void => { this.smartCategoryEditor.openCreate() },
            })
          }
          .padding({ left: ThemeConstants.LIST_SECTION_INSET, right: ThemeConstants.LIST_SECTION_INSET,
            top: this.smartCategories.length === 0 ? ThemeConstants.LIST_SECTION_INSET : 0,
            bottom: ThemeConstants.LIST_SECTION_INSET })
        }
        .backgroundColor(ThemeConstants.CARD)
        .borderRadius({
          topLeft: this.smartCategories.length === 0 ? ThemeConstants.RADIUS_CARD : 0,
          topRight: this.smartCategories.length === 0 ? ThemeConstants.RADIUS_CARD : 0,
          bottomLeft: ThemeConstants.RADIUS_CARD,
          bottomRight: ThemeConstants.RADIUS_CARD,
        })
      }
      LibrarySmartCategorySection({
        controller: this.smartCategoryEditor,
        libraryStore: this.libraryStore,
        persistence: this.libraryPersistenceService,
        onChanged: (): void => {
          this.refreshCategories()
          this.onLibraryChanged()
        },
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

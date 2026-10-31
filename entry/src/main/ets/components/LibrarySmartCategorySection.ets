import { Comic, CustomLibraryCategory, LIBRARY_CATEGORY_FAVORITE_ID, LIBRARY_CATEGORY_READ_LATER_ID,
  LIBRARY_CATEGORY_NAME_MAX_LENGTH } from '../model/ComicModels'
import { LibraryStore } from '../model/LibraryStore'
import { LibraryStorePersistenceService, replaceSmartCategoriesAndPersistLibraryStore } from '../model/LibraryPersistence'
import { LibrarySmartCategory, LibrarySmartFilter, LibrarySmartFilterMethod, LIBRARY_SMART_FILTER_METHODS,
  copyLibrarySmartCategory, comicSmartSourceKey, comicSmartContentRating } from '../model/LibrarySmartCategory'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { AppStrings } from '../i18n/AppStrings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ThemeConstants } from '../theme/ThemeConstants'
import { komaSheetOptions } from '../theme/KomaPopupOptions'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { ConciseListRow } from './ui/ConciseListRow'
import { KomaModalScaffold } from './KomaModalScaffold'
import { KomaFormTextField } from './ui/KomaFormTextField'

interface SmartFilterChoice { value: string; title: string }
function s(key: string): string { return AppStrings.get(key) }

@ComponentV2
export struct LibrarySmartCategorySection {
  @Param libraryStore?: LibraryStore = undefined
  @Param persistence?: LibraryStorePersistenceService = undefined
  @Event onChanged: () => void = () => {}
  @Local private groups: LibrarySmartCategory[] = []
  @Local private editorShown: boolean = false
  @Local private editingId: string = ''
  @Local private draftName: string = ''
  @Local private draftFilters: LibrarySmartFilter[] = []

  aboutToAppear(): void { this.groups = this.libraryStore?.listSmartCategories() ?? [] }

  private openEditor(group?: LibrarySmartCategory): void {
    this.editingId = group?.id ?? ''
    this.draftName = group?.name ?? ''
    this.draftFilters = group === undefined ? [] : copyLibrarySmartCategory(group).filters
    this.editorShown = true
  }

  private commit(groups: LibrarySmartCategory[]): boolean {
    if (this.libraryStore === undefined || this.persistence === undefined) return false
    try {
      replaceSmartCategoriesAndPersistLibraryStore(this.libraryStore, this.persistence, groups)
      this.groups = this.libraryStore.listSmartCategories()
      this.onChanged()
      return true
    } catch (error) {
      const message = (error as Error).message
      const validation = [s('library_category_error_name_empty'), s('library_category_error_name_duplicate'),
        s('library_category_error_name_builtin'), AppStrings.format('library_category_error_name_too_long', LIBRARY_CATEGORY_NAME_MAX_LENGTH)]
      DiagnosticLogger.exception('library', 'smart_category_save_failed', error)
      this.getUIContext().getPromptAction().showToast({ message: validation.includes(message) ? message : s('library_category_save_failed') })
      return false
    }
  }

  private saveDraft(): void {
    const groups = this.libraryStore?.listSmartCategories() ?? []
    const existing = groups.find((group: LibrarySmartCategory): boolean => group.id === this.editingId)
    const now = Date.now()
    const next: LibrarySmartCategory = { id: existing?.id ?? `smart:${now}`, name: this.draftName.trim(),
      sortOrder: existing?.sortOrder ?? groups.length, createdAt: existing?.createdAt ?? now,
      updatedAt: now, filters: this.draftFilters }
    const updated = groups.filter((group: LibrarySmartCategory): boolean => group.id !== next.id)
    updated.push(next)
    if (this.commit(updated)) this.editorShown = false
  }

  private move(group: LibrarySmartCategory, direction: number): void {
    const groups = this.libraryStore?.listSmartCategories() ?? []
    const index = groups.findIndex((item: LibrarySmartCategory): boolean => item.id === group.id)
    const target = index + direction
    if (index < 0 || target < 0 || target >= groups.length) return
    const other = groups[target]; groups[target] = groups[index]; groups[index] = other
    groups.forEach((item: LibrarySmartCategory, i: number): void => { item.sortOrder = i; item.updatedAt = Date.now() })
    this.commit(groups)
  }

  private confirmDelete(group: LibrarySmartCategory): void {
    this.getUIContext().showAlertDialog({ title: s('library_smart_delete'), message: group.name,
      primaryButton: { value: s('common_delete'), fontColor: ThemeConstants.DANGER,
        action: (): void => { this.commit((this.libraryStore?.listSmartCategories() ?? [])
          .filter((item: LibrarySmartCategory): boolean => item.id !== group.id)) } },
      secondaryButton: { value: s('common_cancel'), action: (): void => {} } })
  }

  private state(method: LibrarySmartFilterMethod, value?: string): string {
    const filter = this.draftFilters.find((item: LibrarySmartFilter): boolean => item.method === method && item.value === value)
    return filter === undefined ? 'any' : filter.exclude ? 'exclude' : 'include'
  }
  private setState(method: LibrarySmartFilterMethod, value: string | undefined, state: string): void {
    const next = this.draftFilters.filter((item: LibrarySmartFilter): boolean => item.method !== method || item.value !== value)
    if (state !== 'any') next.push({ method, value, exclude: state === 'exclude' })
    this.draftFilters = next
  }

  private choices(method: LibrarySmartFilterMethod): SmartFilterChoice[] {
    const choices = new Map<string, string>()
    if (method === 'category') {
      choices.set('uncategorized', s('library_category_uncategorized'))
      choices.set(LIBRARY_CATEGORY_FAVORITE_ID, s('library_category_favorite'))
      choices.set(LIBRARY_CATEGORY_READ_LATER_ID, s('library_category_read_later'))
      this.libraryStore?.listCustomCategories().forEach((category: CustomLibraryCategory): void => { choices.set(category.id, category.name) })
    } else if (method === 'contentRating') {
      choices.set('unknown', s('library_smart_unknown_rating'))
      this.libraryStore?.listComics().forEach((comic: Comic): void => {
        const value = comicSmartContentRating(comic)
        if (value !== 'unknown') choices.set(value, value)
      })
    } else {
      this.libraryStore?.listComics().forEach((comic: Comic): void => {
        const key = comicSmartSourceKey(comic)
        const title = comic.sourceRuntimeId ? sourceDisplayName(comic.sourceRuntimeId, comic.sourceRuntimeId) :
          key === 'local' ? s('library_source_local') : comic.sourceKind === 'private_library' ? s('library_source_private') :
            s(`route_${comic.sourceKind.split('_')[0]}_title`)
        choices.set(key, title)
      })
    }
    // A removed source/category remains editable and is never silently discarded.
    this.draftFilters.filter((filter: LibrarySmartFilter): boolean => filter.method === method && filter.value !== undefined)
      .forEach((filter: LibrarySmartFilter): void => { if (!choices.has(filter.value!)) choices.set(filter.value!, filter.value!) })
    return Array.from(choices.keys()).map((value: string): SmartFilterChoice => ({ value, title: choices.get(value)! }))
  }

  @Builder
  private StateMenu(method: LibrarySmartFilterMethod, value: string | undefined, select: (action: () => void) => void) {
    Menu() {
      ForEach(['any', 'include', 'exclude'], (state: string) => {
        MenuItem({ content: s(`library_smart_${state}`) }).selected(this.state(method, value) === state).selectIcon(true)
          .onClick((): void => { select((): void => { this.setState(method, value, state) }) })
      })
    }
  }

  @Builder
  private RuleRow(method: LibrarySmartFilterMethod, title: string, value?: string) {
    ConciseListRow({ title, showChevron: false, trailingText: s(`library_smart_${this.state(method, value)}`),
      trailingDropdown: true, dropdownMenuEnabled: true,
      dropdownMenuBuilder: (select: (action: () => void) => void): void => { this.StateMenu(method, value, select) } })
  }

  @Builder
  private Editor() {
    KomaModalScaffold({ title: s(this.editingId ? 'library_smart_edit' : 'library_smart_create'),
      contentHorizontalPadding: ThemeConstants.SPACE_LG,
      confirmLabel: s('common_save'), confirmEnabled: this.draftName.trim().length > 0 && this.draftFilters.length > 0,
      onConfirm: (): void => { this.saveDraft() }, onClose: (): void => { this.editorShown = false } }) {
      ListItem() {
        Column({ space: ThemeConstants.SPACE_MD }) {
          GroupedListSection({ inset: ThemeConstants.SPACE_MD }) {
            KomaFormTextField({ label: s('library_category_name_label'), value: this.draftName,
              change: (name: string): void => { this.draftName = name } })
          }
          GroupedListSection({ title: s('library_smart_rules'), actionLabel: s('common_reset'),
            action: (): void => { this.draftFilters = [] } }) {
            ForEach(LIBRARY_SMART_FILTER_METHODS.slice(0, 5), (method: LibrarySmartFilterMethod, index: number) => {
              if (index > 0) { ListDivider() }
              this.RuleRow(method, s(`library_smart_rule_${method}`))
            })
          }
          ForEach(LIBRARY_SMART_FILTER_METHODS.slice(5), (method: LibrarySmartFilterMethod) => {
            GroupedListSection() {
              ConciseListRow({ title: s(`library_smart_rule_${method}`),
                trailingText: AppStrings.format('library_smart_rules_count',
                  this.draftFilters.filter((filter: LibrarySmartFilter): boolean => filter.method === method).length),
                trailingDropdown: true, showChevron: false, dropdownMenuEnabled: true,
                dropdownMenuBuilder: (select: (action: () => void) => void): void => { this.RuleChoicesMenu(method, select) } })
            }
          })
        }.width('100%')
      }
    }
  }

  @Builder
  private RuleChoicesMenu(method: LibrarySmartFilterMethod, select: (action: () => void) => void) {
    Menu() {
      ForEach(this.choices(method), (choice: SmartFilterChoice) => {
        MenuItem({ content: choice.title, labelInfo: s(`library_smart_${this.state(method, choice.value)}`),
          builder: (): void => { this.StateMenu(method, choice.value, select) } })
      }, (choice: SmartFilterChoice) => choice.value)
    }.subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }

  @Builder
  private GroupMenu(group: LibrarySmartCategory, index: number, select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: s('library_smart_edit') }).onClick((): void => { select((): void => { this.openEditor(group) }) })
      MenuItem({ content: s('library_category_action_move_up') }).enabled(index > 0)
        .onClick((): void => { select((): void => { this.move(group, -1) }) })
      MenuItem({ content: s('library_category_action_move_down') }).enabled(index < this.groups.length - 1)
        .onClick((): void => { select((): void => { this.move(group, 1) }) })
      MenuItem({ content: s('common_delete') }).contentFontColor(ThemeConstants.DANGER)
        .onClick((): void => { select((): void => { this.confirmDelete(group) }) })
    }
  }

  build() {
    Column() {
      GroupedListSection({ title: s('library_smart_title') }) {
        ForEach(this.groups, (group: LibrarySmartCategory, index: number) => {
          ConciseListRow({ title: group.name,
            trailingText: AppStrings.format('library_smart_rules_count', group.filters.length),
            showChevron: false, trailingDropdown: true, dropdownMenuEnabled: true,
            dropdownMenuBuilder: (select: (action: () => void) => void): void => { this.GroupMenu(group, index, select) } })
          ListDivider()
        }, (group: LibrarySmartCategory) => JSON.stringify(group))
        ConciseListRow({ title: s('library_smart_create'), leadingIcon: $r('sys.symbol.plus'),
          action: (): void => { this.openEditor() } })
      }
    }.width('100%')
      .bindSheet($$this.editorShown, this.Editor, komaSheetOptions({ detents: [SheetSize.LARGE],
        showClose: false, enableFloatingDragBar: true,
        onWillDismiss: (action: DismissSheetAction): void => { this.editorShown = false; action.dismiss() } }))
  }
}

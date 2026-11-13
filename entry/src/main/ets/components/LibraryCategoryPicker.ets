import { KomaModalScaffold, komaModalSheetOptions } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

type CategoryCheckState = 'none' | 'mixed' | 'all'

export interface LibraryCategoryChoice {
  id: string
  name: string
  initial: CategoryCheckState
}

export function libraryCategoryPickerSheetOptions(): SheetOptions {
  return komaModalSheetOptions({
    height: SheetSize.MEDIUM, detents: [SheetSize.MEDIUM, SheetSize.LARGE],
    showClose: false, enableOutsideInteractive: false, scrollSizeMode: ScrollSizeMode.CONTINUOUS,
  })
}

@ComponentV2
export struct LibraryCategoryPicker {
  @Param title: ResourceStr = ''
  @Param confirmLabel: ResourceStr = ''
  @Param choices: LibraryCategoryChoice[] = []
  // A new favorite can be saved to the shelf with no manual memberships.
  // Batch edits confirm only explicit changes and retain untouched mixed rows.
  @Param confirmWithoutChanges: boolean = false
  @Event onConfirm: (added: string[], removed: string[]) => void = (_added: string[], _removed: string[]) => {}
  @Event onClose: () => void = () => {}
  @Event onManageCategories: () => void = () => {}
  @Local private checks: Map<string, CategoryCheckState> = new Map<string, CategoryCheckState>()

  private categoryCheck(choice: LibraryCategoryChoice): CategoryCheckState {
    return this.checks.get(choice.id) ?? choice.initial
  }

  private toggleCategoryCheck(choice: LibraryCategoryChoice): void {
    const current = this.categoryCheck(choice)
    const next = current === 'all' ? 'none' : current === 'none' && choice.initial === 'mixed' ? 'mixed' : 'all'
    const checks = new Map<string, CategoryCheckState>(this.checks)
    if (next === choice.initial) checks.delete(choice.id)
    else checks.set(choice.id, next)
    this.checks = checks
  }

  private confirm(): void {
    const added: string[] = []
    const removed: string[] = []
    this.checks.forEach((state: CategoryCheckState, id: string): void => {
      if (state === 'all') added.push(id)
      else if (state === 'none') removed.push(id)
    })
    this.onConfirm(added, removed)
  }

  build() {
    KomaModalScaffold({
      title: this.title,
      confirmLabel: this.choices.length > 0 ? this.confirmLabel : undefined,
      confirmEnabled: this.confirmWithoutChanges || this.checks.size > 0,
      onConfirm: (): void => { this.confirm() },
      onClose: (): void => { this.onClose() },
    }) {
      ListItem() {
        GroupedListSection({ inModal: true }) {
          if (this.choices.length === 0) {
            ConciseListRow({ title: AppStrings.get('settings_row_library_categories_title'),
              leadingIcon: $r('sys.symbol.plus'), action: (): void => { this.onManageCategories() } })
          } else {
            ForEach(this.choices, (choice: LibraryCategoryChoice, index: number) => {
              ConciseListRow({
                title: choice.name,
                wrapTitle: true,
                showChevron: false,
                trailingIcon: this.categoryCheck(choice) === 'all' ? $r('sys.symbol.checkmark') :
                  this.categoryCheck(choice) === 'mixed' ? $r('sys.symbol.minus') : undefined,
                trailingIconColor: ThemeConstants.BRAND_PRIMARY,
                trailingIconLabel: AppStrings.get(this.categoryCheck(choice) === 'mixed' ?
                  'library_category_partial_selection' : 'library_category_selection_checked'),
                trailingIconAction: (): void => { this.toggleCategoryCheck(choice) },
                action: (): void => { this.toggleCategoryCheck(choice) },
              })
              if (index < this.choices.length - 1) ListDivider()
            }, (choice: LibraryCategoryChoice): string => choice.id)
          }
        }
      }
    }
  }
}

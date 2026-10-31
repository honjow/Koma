import { SymbolGlyphModifier } from '@kit.ArkUI'
import { AppStrings } from '../i18n/AppStrings'
import { LibraryCategoryDefinition } from '../model/ComicModels'
import { LibraryAutomationPreferences, defaultLibraryAutomationPreferences } from '../model/LibraryAutomationPolicy'
import { ConciseListRow } from './ui/ConciseListRow'

export const LIBRARY_AUTOMATION_SETTING_KEYS: string[] = [
  'library-update-range', 'library-update-skip', 'library-update-wifi-only', 'library-update-charging-only',
  'download-auto-new', 'download-auto-unread', 'download-auto-range', 'download-read-cleanup', 'download-cleanup-exclude',
]

interface AutomationChoice { key: string; title: string }

@ComponentV2
export struct LibraryAutomationSettingRow {
  @Param rowKey: string = ''
  @Param title: string = ''
  @Param policy: LibraryAutomationPreferences = defaultLibraryAutomationPreferences()
  @Param categories: LibraryCategoryDefinition[] = []
  @Event onChange: (change: (policy: LibraryAutomationPreferences) => void) => void = () => {}

  private isSwitch(): boolean {
    return ['library-update-wifi-only', 'library-update-charging-only', 'download-auto-new', 'download-auto-unread'].includes(this.rowKey)
  }

  private value(): boolean {
    if (this.rowKey === 'library-update-wifi-only') return this.policy.updateWifiOnly
    if (this.rowKey === 'library-update-charging-only') return this.policy.updateChargingOnly
    if (this.rowKey === 'download-auto-new') return this.policy.autoDownloadNewChapters
    return this.policy.downloadUnreadOnly
  }

  private setValue(value: boolean): void {
    this.onChange((policy: LibraryAutomationPreferences): void => {
      if (this.rowKey === 'library-update-wifi-only') policy.updateWifiOnly = value
      else if (this.rowKey === 'library-update-charging-only') policy.updateChargingOnly = value
      else if (this.rowKey === 'download-auto-new') policy.autoDownloadNewChapters = value
      else policy.downloadUnreadOnly = value
    })
  }

  private included(): string[] {
    return this.rowKey === 'library-update-range' ? this.policy.updateIncludedCategories : this.policy.downloadIncludedCategories
  }

  private excluded(): string[] {
    return this.rowKey === 'library-update-range' ? this.policy.updateExcludedCategories :
      this.rowKey === 'download-cleanup-exclude' ? this.policy.cleanupExcludedCategories : this.policy.downloadExcludedCategories
  }

  private categoryLabel(id: string): string {
    return this.categories.find((item: LibraryCategoryDefinition): boolean => item.id === id)?.name ?? id
  }

  private categoryState(id: string): string {
    return AppStrings.get(this.excluded().includes(id) ? 'automation_excluded' :
      this.included().includes(id) ? 'automation_included' : 'automation_unrestricted')
  }

  private detail(): string {
    if (this.rowKey === 'download-read-cleanup') return AppStrings.get(this.policy.removeAfterRead < 0 ? 'common_off' :
      this.policy.removeAfterRead === 0 ? 'automation_delete_read' : 'automation_keep_chapters')
        .replace('%s', `${this.policy.removeAfterRead}`)
    if (this.rowKey === 'library-update-skip') {
      const names: string[] = []
      if (this.policy.skipCompleted) names.push(AppStrings.get('automation_skip_completed'))
      if (this.policy.skipNotStarted) names.push(AppStrings.get('automation_skip_not_started'))
      if (this.policy.skipHasUnread) names.push(AppStrings.get('automation_skip_unread'))
      if (this.policy.skipOutsideReleasePeriod) names.push(AppStrings.get('automation_skip_not_due'))
      return names.join('、') || AppStrings.get('automation_none')
    }
    if (this.rowKey === 'download-cleanup-exclude') return this.excluded().map((id: string): string =>
      this.categoryLabel(id)).join('、') || AppStrings.get('automation_none')
    const included = this.included().map((id: string): string => this.categoryLabel(id)).join('、')
    const excluded = this.excluded().map((id: string): string => this.categoryLabel(id)).join('、')
    return [included.length > 0 ? `${AppStrings.get('automation_included')}：${included}` : '',
      excluded.length > 0 ? `${AppStrings.get('automation_excluded')}：${excluded}` : ''].filter((s: string): boolean => s.length > 0)
      .join('；') || AppStrings.get('automation_all_categories')
  }

  private toggleCategory(id: string): void {
    this.onChange((policy: LibraryAutomationPreferences): void => {
      const included = (this.rowKey === 'library-update-range' ? policy.updateIncludedCategories : policy.downloadIncludedCategories).slice()
      const excluded = (this.rowKey === 'library-update-range' ? policy.updateExcludedCategories :
        this.rowKey === 'download-cleanup-exclude' ? policy.cleanupExcludedCategories : policy.downloadExcludedCategories).slice()
      if (this.rowKey === 'download-cleanup-exclude') {
        policy.cleanupExcludedCategories = excluded.includes(id) ? excluded.filter((key: string): boolean => key !== id) : excluded.concat(id)
        return
      }
      if (excluded.includes(id)) excluded.splice(excluded.indexOf(id), 1)
      else if (included.includes(id)) { included.splice(included.indexOf(id), 1); excluded.push(id) }
      else included.push(id)
      if (this.rowKey === 'library-update-range') { policy.updateIncludedCategories = included; policy.updateExcludedCategories = excluded }
      else { policy.downloadIncludedCategories = included; policy.downloadExcludedCategories = excluded }
    })
  }

  private skipChoices(): AutomationChoice[] {
    return [{ key: 'completed', title: AppStrings.get('automation_skip_completed') },
      { key: 'not_started', title: AppStrings.get('automation_skip_not_started') },
      { key: 'unread', title: AppStrings.get('automation_skip_unread') },
      { key: 'not_due', title: AppStrings.get('automation_skip_not_due') }]
  }

  private skipChecked(key: string): boolean {
    return key === 'completed' ? this.policy.skipCompleted : key === 'not_started' ? this.policy.skipNotStarted :
      key === 'not_due' ? this.policy.skipOutsideReleasePeriod : this.policy.skipHasUnread
  }

  @Builder
  private Options(select: (action: () => void) => void) {
    Menu() {
      if (this.rowKey === 'download-read-cleanup') {
        ForEach([-1, 0, 2, 3, 5], (count: number) => {
          MenuItem({ content: AppStrings.get(count < 0 ? 'common_off' : count === 0 ? 'automation_delete_read' : 'automation_keep_chapters')
            .replace('%s', `${count}`), symbolEndIcon: this.policy.removeAfterRead === count ?
              new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
            .onClick(() => { select(() => { this.onChange((policy: LibraryAutomationPreferences): void => { policy.removeAfterRead = count }) }) })
        })
      } else if (this.rowKey === 'library-update-skip') {
        ForEach(this.skipChoices(), (choice: AutomationChoice) => {
          MenuItem({ content: choice.title, symbolEndIcon: this.skipChecked(choice.key) ?
            new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
            .onClick(() => { select(() => { this.onChange((policy: LibraryAutomationPreferences): void => {
              if (choice.key === 'completed') policy.skipCompleted = !policy.skipCompleted
              else if (choice.key === 'not_started') policy.skipNotStarted = !policy.skipNotStarted
              else if (choice.key === 'not_due') policy.skipOutsideReleasePeriod = !policy.skipOutsideReleasePeriod
              else policy.skipHasUnread = !policy.skipHasUnread
            }) }) })
        })
      } else {
        ForEach(this.categories, (category: LibraryCategoryDefinition) => {
          MenuItem({ content: category.name, labelInfo: this.rowKey === 'download-cleanup-exclude'
            ? (this.excluded().includes(category.id) ? AppStrings.get('automation_excluded') : '') : this.categoryState(category.id) })
            .onClick(() => { select(() => { this.toggleCategory(category.id) }) })
        }, (category: LibraryCategoryDefinition): string => category.id)
      }
    }
  }

  build() {
    if (this.isSwitch()) {
      ConciseListRow({ title: this.title, hasSwitch: true, checked: this.value(), showChevron: false,
        switchAction: (value: boolean) => { this.setValue(value) } })
    } else {
      ConciseListRow({ title: this.title, trailingText: this.detail(), trailingMaxLines: 2,
        trailingDropdown: true, dropdownMenuEnabled: true,
        dropdownMenuBuilder: (select: (action: () => void) => void) => { this.Options(select) } })
    }
  }
}

import { common } from '@kit.AbilityKit'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { ImageRuleSubscription, effectiveBannerFilter } from '../model/ImageBannerRules'
import { ImagePluginsRequest } from '../model/ImagePluginManagement'
import { ReaderPreferences, DEFAULT_READER_PREFERENCES, normalizeReaderPreferences } from '../model/ReaderPreferencesStore'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { AppStrings } from '../i18n/AppStrings'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { ImagePluginsListContent } from '../components/ImagePluginsListContent'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct ImagePluginsPage {
  @Require @Param request: ImagePluginsRequest
  @Local private preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Local private subscriptions: ImageRuleSubscription[] = []
  @Local private state: ImageRuleState = connectImageRuleState()
  @Local private error: string = ''
  private store(): ImageRuleStore { return ImageRuleStore.forContext(this.getUIContext().getHostContext() as common.UIAbilityContext) }
  aboutToAppear(): void { this.preferences = normalizeReaderPreferences(this.request.preferences); void this.load() }
  @Monitor('state.dataRevision')
  private changed(): void { void this.load() }
  private async load(): Promise<void> { this.subscriptions = await this.store().list() }
  private usesGlobal(): boolean {
    return this.preferences.bannerFilterOverride === undefined || this.preferences.bannerFilterOverride === 'global'
  }
  private pluginsEnabled(): boolean {
    return effectiveBannerFilter(this.preferences.bannerFilter,
      this.request.bookOptions ? this.preferences.bannerFilterOverride : undefined) !== 'off'
  }
  private changeEnabled(enabled: boolean): void {
    const next = normalizeReaderPreferences(this.preferences)
    if (this.request.bookOptions) next.bannerFilterOverride = enabled ? 'auto' : 'off'
    else next.bannerFilter = enabled ? 'auto' : 'off'
    this.request.apply(next); this.preferences = next
  }
  private changeUseGlobal(enabled: boolean): void {
    const next = normalizeReaderPreferences(this.preferences)
    next.bannerFilterOverride = enabled ? 'global' : this.pluginsEnabled() ? 'auto' : 'off'
    this.request.apply(next); this.preferences = next
  }
  private async refresh(): Promise<void> {
    this.error = ''
    for (const subscription of this.subscriptions) {
      try { await this.store().refresh(subscription.url) }
      catch (_error) { this.error = AppStrings.get('image_rules_update_failed') }
    }
    await this.load()
  }
  build() {
    PullRefreshListScaffold({ onRefresh: (): Promise<void> => this.refresh(), bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() {
        GroupedListSection() {
          if (this.request.bookOptions) {
            ConciseListRow({ title: AppStrings.get('image_plugins_use_global'), hasSwitch: true, showChevron: false,
              subtitle: AppStrings.get('image_plugins_book_hint'), checked: this.usesGlobal(),
              switchAction: (enabled: boolean): void => { this.changeUseGlobal(enabled) } })
            ListDivider()
          }
          ConciseListRow({ title: AppStrings.get('image_plugins_use'), hasSwitch: true, showChevron: false,
            subtitle: AppStrings.get('image_plugins_use_hint'), subtitleMaxLines: 3, checked: this.pluginsEnabled(),
            isEnabled: !this.request.bookOptions || !this.usesGlobal(),
            switchAction: (enabled: boolean): void => { this.changeEnabled(enabled) } })
        }
      }
      ListItem() { ImagePluginsListContent({ subscriptions: this.subscriptions }) }
      if (this.subscriptions.length === 0) {
        ListItem() { Text(AppStrings.get('image_plugins_empty')).fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_LG).width('100%') }
      }
      if (this.error) {
        ListItem() { Text(this.error).fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_LG).onClick(() => { void this.refresh() }) }
      }
    }
  }
}

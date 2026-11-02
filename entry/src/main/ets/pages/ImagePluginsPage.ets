import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { ImageRuleSubscription, normalizeBannerFilter } from '../model/ImageBannerRules'
import { ImagePluginsRequest } from '../model/ImagePluginManagement'
import { ReaderPreferences, DEFAULT_READER_PREFERENCES, normalizeReaderPreferences } from '../model/ReaderPreferencesStore'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { AppStrings } from '../i18n/AppStrings'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { ImagePluginsListContent } from '../components/ImagePluginsListContent'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection } from '../components/ui/GroupedListSection'
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
  private choice(): string { return this.request.bookOptions ? this.preferences.bannerFilterOverride ?? 'global' : normalizeBannerFilter(this.preferences.bannerFilter) }
  private async refresh(): Promise<void> {
    this.error = ''
    for (const subscription of this.subscriptions) {
      try { await this.store().refresh(subscription.url) }
      catch (_error) { this.error = AppStrings.get('image_rules_update_failed') }
    }
    await this.load()
  }
  @Builder
  private ModeMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(this.request.bookOptions ? ['global', 'source', 'auto', 'off'] : ['source', 'auto', 'off'], (choice: string) => {
        MenuItem({ content: AppStrings.get('reader_banner_' + choice), symbolEndIcon:
          this.choice() === choice ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick(() => { select((): void => {
            const next = normalizeReaderPreferences(this.preferences)
            if (this.request.bookOptions) next.bannerFilterOverride = choice
            else next.bannerFilter = normalizeBannerFilter(choice)
            this.request.apply(next); this.preferences = next
          }) })
      })
    }
  }
  build() {
    PullRefreshListScaffold({ onRefresh: (): Promise<void> => this.refresh(), bottomPadding: ThemeConstants.SPACE_XL }) {
      ListItem() {
        GroupedListSection() {
          ConciseListRow({ title: AppStrings.get('image_plugins_application'),
            subtitle: AppStrings.get('image_plugins_application_hint'), subtitleMaxLines: 4,
            trailingText: AppStrings.get('reader_banner_' + this.choice()), trailingDropdown: true, dropdownMenuEnabled: true,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.ModeMenu(select) } })
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

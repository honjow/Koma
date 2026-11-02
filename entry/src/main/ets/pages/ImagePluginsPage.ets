import { common } from '@kit.AbilityKit'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { ImageRuleSubscription, ImagePluginCollection, effectiveBannerFilter } from '../model/ImageBannerRules'
import { ImagePluginsRequest } from '../model/ImagePluginManagement'
import { ReaderPreferences, ReaderPreferencesStore, DEFAULT_READER_PREFERENCES, normalizeReaderPreferences } from '../model/ReaderPreferencesStore'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { AppStrings } from '../i18n/AppStrings'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { ImagePluginsListContent } from '../components/ImagePluginsListContent'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct ImagePluginsPage {
  @Param request: ImagePluginsRequest | undefined = undefined
  @Param pinnedOverlayHeight: number = 0
  @Param embedded: boolean = false
  @Local private preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Local private preferencesReady: boolean = false
  @Local private subscriptions: ImageRuleSubscription[] = []
  @Local private installations: ImagePluginCollection[] = []
  @Local private state: ImageRuleState = connectImageRuleState()
  @Local private error: string = ''
  private preferenceMutation: number = 0
  private store(): ImageRuleStore { return ImageRuleStore.forContext(this.getUIContext().getHostContext() as common.UIAbilityContext) }
  private preferencesStore(): ReaderPreferencesStore {
    return new ReaderPreferencesStore(this.getUIContext().getHostContext() as common.UIAbilityContext)
  }
  aboutToAppear(): void {
    if (this.request !== undefined) {
      this.preferences = normalizeReaderPreferences(this.request.preferences)
      this.preferencesReady = true
    } else void this.loadGlobalPreferences()
    void this.load()
  }
  private async loadGlobalPreferences(): Promise<void> {
    try {
      this.preferences = await this.preferencesStore().load()
      this.preferencesReady = true
    } catch (_error) { this.error = AppStrings.get('common_load_failed') }
  }
  private applyPreferences(next: ReaderPreferences): void {
    if (this.request !== undefined) {
      this.request.apply(next)
      this.preferences = next
      return
    }
    // The catalog is a global entry, using the same preference transaction as
    // Settings. Reader callers retain their existing book-owned write callback.
    const previous = this.preferences
    const revision = ++this.preferenceMutation
    this.error = ''
    this.preferences = next
    void this.preferencesStore().saveChanges(previous, next).then((saved: ReaderPreferences): void => {
      if (revision === this.preferenceMutation) this.preferences = saved
    }).catch((): void => {
      if (revision === this.preferenceMutation) {
        this.error = AppStrings.get('automation_save_failed')
        void this.loadGlobalPreferences()
      }
    })
  }
  @Monitor('state.dataRevision')
  private changed(): void { void this.load() }
  private async load(): Promise<void> {
    try {
      this.subscriptions = await this.store().list()
      this.installations = await this.store().installed()
    } catch (_error) { this.error = AppStrings.get('image_plugins_storage_failed') }
  }
  private usesGlobal(): boolean {
    return this.preferences.bannerFilterOverride === undefined || this.preferences.bannerFilterOverride === 'global'
  }
  private pluginsEnabled(): boolean {
    return effectiveBannerFilter(this.preferences.bannerFilter,
      this.request?.bookOptions ? this.preferences.bannerFilterOverride : undefined) !== 'off'
  }
  private changeEnabled(enabled: boolean): void {
    const next = normalizeReaderPreferences(this.preferences)
    if (this.request?.bookOptions) next.bannerFilterOverride = enabled ? 'auto' : 'off'
    else next.bannerFilter = enabled ? 'auto' : 'off'
    this.applyPreferences(next)
  }
  private changeUseGlobal(enabled: boolean): void {
    const next = normalizeReaderPreferences(this.preferences)
    next.bannerFilterOverride = enabled ? 'global' : this.pluginsEnabled() ? 'auto' : 'off'
    this.applyPreferences(next)
  }
  private async refresh(): Promise<void> {
    this.error = ''
    if (this.state.readFailed) await this.store().reload()
    if (!this.preferencesReady && this.request === undefined) await this.loadGlobalPreferences()
    for (const subscription of this.subscriptions) {
      try { await this.store().refresh(subscription.url) }
      catch (_error) { this.error = AppStrings.get('image_rules_update_failed') }
    }
    await this.load()
  }
  build() {
    PullRefreshListScaffold({ onRefresh: (): Promise<void> => this.refresh(), bottomPadding: ThemeConstants.SPACE_XL,
      reserveTitleBar: !this.embedded, reserveSystemSafeArea: !this.embedded,
      surfaceColor: this.embedded ? Color.Transparent : ThemeConstants.BG_SUB,
      horizontalPadding: this.embedded ? 0 : ThemeConstants.SPACE_MD,
      pinnedOverlayHeight: this.pinnedOverlayHeight }) {
      if (this.preferencesReady) {
      ListItem() {
        GroupedListSection() {
          if (this.request?.bookOptions) {
            ConciseListRow({ title: AppStrings.get('image_plugins_use_global'), hasSwitch: true, showChevron: false,
              subtitle: AppStrings.get('image_plugins_book_hint'), checked: this.usesGlobal(),
              switchAction: (enabled: boolean): void => { this.changeUseGlobal(enabled) } })
            ListDivider()
          }
          ConciseListRow({ title: AppStrings.get('image_plugins_use'), hasSwitch: true, showChevron: false,
            subtitle: AppStrings.get('image_plugins_use_hint'), subtitleMaxLines: 3, checked: this.pluginsEnabled(),
            isEnabled: !this.request?.bookOptions || !this.usesGlobal(),
            switchAction: (enabled: boolean): void => { this.changeEnabled(enabled) } })
        }
      }
      }
      if (this.request?.bookOptions) {
        ListItem() { Text(AppStrings.get('image_plugins_global_management')).fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY).width('100%').padding(ThemeConstants.SPACE_MD) }
      }
      ListItem() { ImagePluginsListContent({ subscriptions: this.subscriptions, installations: this.installations }) }
      if (this.subscriptions.length === 0 && this.installations.length === 0 && !this.state.readFailed) {
        ListItem() { Text(AppStrings.get('image_plugins_empty')).fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_LG).width('100%') }
      }
      if (this.error) {
        ListItem() { Text(this.error).fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_LG).onClick(() => { void this.refresh() }) }
      }
    }
  }
}

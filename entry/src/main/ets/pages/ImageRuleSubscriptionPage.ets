import { ImagePluginsListContent } from '../components/ImagePluginsListContent'
import { common } from '@kit.AbilityKit'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { ImageRuleSubscription, ImageRulePack, ImageBannerRule, imageRuleKey } from '../model/ImageBannerRules'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { AppStrings } from '../i18n/AppStrings'
import { PullRefreshListScaffold } from '../components/PullRefreshListScaffold'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { ThemeConstants } from '../theme/ThemeConstants'

export class ImageRuleSubscriptionRouteParam {
  url: string
  title: string
  constructor(url: string, title: string) { this.url = url; this.title = title }
}
@ComponentV2
export struct ImageRuleSubscriptionPage {
  @Param url: string = ''
  @Local private language: LanguageState = connectLanguageState()
  @Local private subscription: ImageRuleSubscription | null = null
  @Local private state: ImageRuleState = connectImageRuleState()
  @Local private busy: boolean = false
  @Local private error: string = ''
  private store(): ImageRuleStore { return ImageRuleStore.forContext(this.getUIContext().getHostContext() as common.UIAbilityContext) }
  aboutToAppear(): void { void this.load() }
  @Monitor('state.dataRevision')
  private changed(): void { void this.load() }
  private async load(): Promise<void> {
    this.subscription = (await this.store().list()).find((s: ImageRuleSubscription): boolean => s.url === this.url) ?? null
  }
  private async edit(operation: () => Promise<void>): Promise<void> {
    if (this.busy) return
    this.busy = true; this.error = ''
    try { await operation(); await this.load() }
    catch (_error) { this.error = AppStrings.get('image_rules_change_failed') }
    finally { this.busy = false }
  }
  private async refresh(): Promise<void> {
    this.error = ''
    try { await this.store().refresh(this.url); await this.load() }
    catch (_error) { this.error = AppStrings.get('image_rules_update_failed') }
  }
  @Builder
  private RuleSection(pack: ImageRulePack) {
    GroupedListSection({ title: `${pack.meta?.name ?? pack.id} · v${pack.version}` }) {
      ForEach(pack.rules, (rule: ImageBannerRule, index: number) => {
        ConciseListRow({ title: rule.name ?? rule.id, wrapTitle: true, subtitle: rule.description ?? '',
          subtitleMaxLines: 5, hasSwitch: true, showChevron: false,
          checked: !this.subscription!.disabledRules.includes(imageRuleKey(pack.id, rule.id)),
          isEnabled: !this.busy && this.subscription!.enabled,
          switchAction: (enabled: boolean): void => { void this.edit(() => this.store().setRuleEnabled(this.url, pack.id, rule.id, enabled)) } })
        if (index + 1 < pack.rules.length) { ListDivider() }
      }, (rule: ImageBannerRule): string => imageRuleKey(pack.id, rule.id))
    }
  }
  build() {
    PullRefreshListScaffold({ onRefresh: (): Promise<void> => this.refresh(), bottomPadding: ThemeConstants.SPACE_XL }) {
      if (this.subscription !== null) {
        ListItem() {
          GroupedListSection() {
            ConciseListRow({ title: AppStrings.get('image_rules_enable_subscription'), hasSwitch: true,
              checked: this.subscription.enabled, showChevron: false, isEnabled: !this.busy,
              switchAction: (enabled: boolean): void => { void this.edit(() => this.store().setEnabled(this.url, enabled)) } })
            ListDivider()
            ConciseListRow({ title: AppStrings.get('image_rules_automatic_updates'),
              subtitle: AppStrings.get('image_rules_automatic_updates_detail'), subtitleMaxLines: 3, hasSwitch: true,
              checked: this.subscription.automaticUpdates, showChevron: false, isEnabled: !this.busy,
              switchAction: (enabled: boolean): void => { void this.edit(() => this.store().setEnabled(this.url, enabled, true)) } })
          }
        }
        if (this.subscription.description) {
          ListItem() {
            Text(this.subscription.description).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor(ThemeConstants.TEXT_SECONDARY)
              .width('100%').padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_SM })
          }
        }
        ListItem() { ImagePluginsListContent({ subscriptions: [this.subscription] }) }
        ListItem() {
          Text(AppStrings.format('image_rules_updated_at', new Intl.DateTimeFormat(this.language.effectiveLocale, { year: 'numeric', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(this.subscription.updatedAt))))
            .fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
            .width('100%').padding(ThemeConstants.SPACE_LG)
        }
      }
      if (this.error) {
        ListItem() {
          Text(this.error).fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_LG)
            .onClick(() => { void this.refresh() })
        }
      }
    }
  }
}

import { ReaderPreferences } from './ReaderPreferencesStore'
import { ImageRuleSubscription, ImageRulePack, ImageBannerRule } from './ImageBannerRules'
import { ImageProcessingPlugin } from './ImageProcessingPlugins'

export class ImagePluginsRequest {
  preferences: ReaderPreferences
  bookOptions: boolean
  apply: (next: ReaderPreferences) => void
  constructor(preferences: ReaderPreferences, bookOptions: boolean, apply: (next: ReaderPreferences) => void) {
    this.preferences = preferences; this.bookOptions = bookOptions; this.apply = apply
  }
}
export class ImagePluginRow {
  subscription: ImageRuleSubscription
  plugin?: ImageProcessingPlugin
  offered?: ImageProcessingPlugin
  pack?: ImageRulePack
  rule?: ImageBannerRule
  group: string
  constructor(subscription: ImageRuleSubscription, group: string) { this.subscription = subscription; this.group = group }
  key(): string { return JSON.stringify([this.subscription.url, this.plugin?.id ?? this.offered?.id ?? this.pack?.id, this.rule?.id]) }
}
export function imagePluginRows(subscriptions: ImageRuleSubscription[]): ImagePluginRow[] {
  const rows: ImagePluginRow[] = []
  for (const subscription of subscriptions) {
    for (const plugin of subscription.plugins ?? []) {
      const offered = subscription.catalog?.find((value: ImageProcessingPlugin): boolean => value.id === plugin.id)
      const row = new ImagePluginRow(subscription, offered !== undefined && offered.version > plugin.version ? 'updates' : 'installed')
      row.plugin = plugin; row.offered = offered; rows.push(row)
    }
    for (const offered of subscription.catalog ?? []) {
      if (subscription.plugins?.some((value: ImageProcessingPlugin): boolean => value.id === offered.id)) continue
      const row = new ImagePluginRow(subscription, 'available'); row.offered = offered; rows.push(row)
    }
    for (const pack of subscription.packs) for (const rule of pack.rules) {
      const row = new ImagePluginRow(subscription, 'installed'); row.pack = pack; row.rule = rule; rows.push(row)
    }
  }
  return rows
}

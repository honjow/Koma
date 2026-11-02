import { ReaderPreferences } from './ReaderPreferencesStore'
import { ImageRuleSubscription, ImagePluginCollection, ImageRulePack, ImageBannerRule, imageRuleKey } from './ImageBannerRules'
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
  source: ImagePluginCollection
  plugin?: ImageProcessingPlugin
  offered?: ImageProcessingPlugin
  offeredPack?: ImageRulePack
  pack?: ImageRulePack
  rule?: ImageBannerRule
  group: string
  constructor(source: ImagePluginCollection, group: string) { this.source = source; this.group = group }
  id(): string { return this.plugin?.id ?? this.offered?.id ?? this.pack?.id ?? this.offeredPack!.id }
  key(): string { return JSON.stringify([this.source.origin, this.id(), this.rule?.id]) }
  enabled(): boolean { return !this.source.disabledRules.includes(imageRuleKey(this.id(), this.rule?.id ?? this.id())) }
}
export function imagePluginRows(subscriptions: ImageRuleSubscription[], installations: ImagePluginCollection[] = []): ImagePluginRow[] {
  const rows: ImagePluginRow[] = []
  const installedIds: Set<string> = new Set()
  for (const source of installations) {
    const catalog = subscriptions.find((s: ImageRuleSubscription): boolean => s.url === source.origin)
    for (const plugin of source.plugins) {
      installedIds.add(plugin.id)
      const offered = catalog?.catalog?.find((value: ImageProcessingPlugin): boolean => value.id === plugin.id)
      const row = new ImagePluginRow(source, offered !== undefined && offered.version > plugin.version ? 'updates' : 'installed')
      row.plugin = plugin; row.offered = offered; rows.push(row)
    }
    for (const pack of source.packs) {
      installedIds.add(pack.id)
      const offered = catalog?.catalog?.find((value: ImageProcessingPlugin): boolean => value.id === pack.id)
      const offeredPack = catalog?.packs.find((value: ImageRulePack): boolean => value.id === pack.id)
      for (const rule of pack.rules) {
        const row = new ImagePluginRow(source, offered !== undefined || (offeredPack !== undefined && offeredPack.version > pack.version) ? 'updates' : 'installed')
        row.pack = pack; row.rule = rule; row.offered = offered; row.offeredPack = offeredPack; rows.push(row)
      }
    }
  }
  for (const subscription of subscriptions) {
    const source: ImagePluginCollection = { origin: subscription.url, name: subscription.customName || subscription.name,
      plugins: [], packs: [], disabledRules: [], pluginSettings: {} }
    for (const offered of subscription.catalog ?? []) {
      if (installedIds.has(offered.id)) continue
      const row = new ImagePluginRow(source, 'available'); row.offered = offered; rows.push(row)
    }
    for (const pack of subscription.packs) {
      if (installedIds.has(pack.id) || subscription.catalog?.some((plugin: ImageProcessingPlugin): boolean => plugin.id === pack.id)) continue
      for (const rule of pack.rules) {
        const row = new ImagePluginRow(source, 'available'); row.offeredPack = pack; row.rule = rule; rows.push(row)
      }
    }
  }
  return rows
}

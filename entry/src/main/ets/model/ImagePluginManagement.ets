import { ReaderPreferences } from './ReaderPreferencesStore'
import { ImageRuleSubscription, ImagePluginCollection, ImageRulePack, ImageBannerRule, imageRuleKey } from './ImageBannerRules'
import { ImageProcessingPlugin } from './ImageProcessingPlugins'
import { subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'

export interface ImagePluginOffer {
  subscription: ImageRuleSubscription
  plugin: ImageProcessingPlugin
  manifestHash?: string
}

// Consider every enabled subscription; an old address or its stale cache must
// not prevent updating an installed plugin from a currently available catalog.
export function imagePluginOffers(subscriptions: ImageRuleSubscription[], id: string, origin?: string): ImagePluginOffer[] {
  const offers: ImagePluginOffer[] = []
  for (const subscription of subscriptions) {
    if (subscription.disabled) continue
    const plugin = subscription.catalog?.find((item: ImageProcessingPlugin): boolean => item.id === id)
    if (plugin === undefined) continue
    const manifestHash = subscription.manifestHashes?.[id]
    offers.push({ subscription, plugin, manifestHash })
  }
  return offers.sort((a: ImagePluginOffer, b: ImagePluginOffer): number => b.plugin.version - a.plugin.version ||
    Number(!!a.subscription.lastError) - Number(!!b.subscription.lastError) ||
    Number(b.subscription.url === origin) - Number(a.subscription.url === origin) ||
    (b.subscription.lastDownloadAt ?? 0) - (a.subscription.lastDownloadAt ?? 0))
}

export interface ImageRulePackOffer {
  subscription: ImageRuleSubscription
  pack: ImageRulePack
}

export function imageRulePackOffers(subscriptions: ImageRuleSubscription[], id: string, origin?: string): ImageRulePackOffer[] {
  const offers: ImageRulePackOffer[] = []
  for (const subscription of subscriptions) {
    if (subscription.disabled) continue
    const pack = subscription.packs.find((item: ImageRulePack): boolean => item.id === id)
    if (pack !== undefined) offers.push({ subscription, pack })
  }
  return offers.sort((a: ImageRulePackOffer, b: ImageRulePackOffer): number => b.pack.version - a.pack.version ||
    Number(!!a.subscription.lastError) - Number(!!b.subscription.lastError) ||
    Number(b.subscription.url === origin) - Number(a.subscription.url === origin))
}

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
  key(): string { return JSON.stringify([this.group === 'available' ? subscriptionIdentity(this.source.origin) : this.source.origin,
    this.id(), this.rule?.id]) }
  enabled(): boolean { return !this.source.disabledRules.includes(imageRuleKey(this.id(), this.rule?.id ?? this.id())) }
}
export function imagePluginRows(subscriptions: ImageRuleSubscription[], installations: ImagePluginCollection[] = []): ImagePluginRow[] {
  const rows: ImagePluginRow[] = []
  const installedIds: Set<string> = new Set()
  for (const source of installations) {
    for (const plugin of source.plugins) {
      installedIds.add(plugin.id)
      const offers = imagePluginOffers(subscriptions, plugin.id, source.origin)
      const offered = offers[0]?.plugin
      const row = new ImagePluginRow(source, offered !== undefined && offered.version > plugin.version ? 'updates' : 'installed')
      row.plugin = plugin; row.offered = offered; rows.push(row)
    }
    for (const pack of source.packs) {
      installedIds.add(pack.id)
      const offers = imagePluginOffers(subscriptions, pack.id, source.origin)
      const offered = offers[0]?.plugin
      const offeredPack = imageRulePackOffers(subscriptions, pack.id, source.origin)[0]?.pack
      for (const rule of pack.rules) {
        const row = new ImagePluginRow(source, offered !== undefined || (offeredPack !== undefined && offeredPack.version > pack.version) ? 'updates' : 'installed')
        row.pack = pack; row.rule = rule; row.offered = offered; row.offeredPack = offeredPack; rows.push(row)
      }
    }
  }
  const listedIds = new Set<string>(installedIds)
  for (const subscription of subscriptions) {
    if (subscription.disabled) continue
    for (const offered of subscription.catalog ?? []) {
      if (listedIds.has(offered.id)) continue
      listedIds.add(offered.id)
      const offers = imagePluginOffers(subscriptions, offered.id)
      const best = offers[0]
      const row = new ImagePluginRow({ origin: best.subscription.url,
        name: best.subscription.customName || best.subscription.name, plugins: [], packs: [],
        disabledRules: [], pluginSettings: {} }, 'available')
      row.offered = best.plugin; rows.push(row)
    }
    for (const pack of subscription.packs) {
      if (listedIds.has(pack.id) || imagePluginOffers(subscriptions, pack.id).length > 0) continue
      listedIds.add(pack.id)
      const best = imageRulePackOffers(subscriptions, pack.id)[0]
      const availableSource: ImagePluginCollection = { origin: best.subscription.url,
        name: best.subscription.customName || best.subscription.name, plugins: [], packs: [],
        disabledRules: [], pluginSettings: {} }
      for (const rule of best.pack.rules) {
        const row = new ImagePluginRow(availableSource, 'available'); row.offeredPack = best.pack; row.rule = rule; rows.push(row)
      }
    }
  }
  return rows
}

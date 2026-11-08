import { ReaderPreferences } from './ReaderPreferencesStore'
import { ImageRuleSubscription, ImagePluginCollection, ImageRulePack, ImageBannerRule, imageRuleKey } from './ImageBannerRules'
import { ImageProcessingPlugin } from './ImageProcessingPlugins'
import { subscriptionIdentity } from '../sourceRuntime/SourceIndexMetadata'

export interface ImagePluginOffer {
  subscription: ImageRuleSubscription
  plugin: ImageProcessingPlugin
  manifestHash?: string
}

// Match the installed publisher independently of its transport address.
// A version is selected once and all fallback endpoints must offer its bytes.
export function imagePluginOffers(subscriptions: ImageRuleSubscription[], id: string, origin?: string): ImagePluginOffer[] {
  const offers: ImagePluginOffer[] = []
  const identity = origin === undefined ? undefined : subscriptionIdentity(origin)
  const pinned = origin === undefined ? undefined : subscriptions.find((subscription: ImageRuleSubscription): boolean =>
    subscription.url === origin)
  const published = pinned?.catalog?.find((plugin: ImageProcessingPlugin): boolean => plugin.id === id)
  const manifest = pinned?.manifestHashes?.[id]
  for (const subscription of subscriptions) {
    if (subscription.disabled || (identity !== undefined && subscriptionIdentity(subscription.url) !== identity)) continue
    const plugin = subscription.catalog?.find((item: ImageProcessingPlugin): boolean => item.id === id)
    if (plugin === undefined) continue
    const manifestHash = subscription.manifestHashes?.[id]
    // A proxy URL groups the catalog, but another publisher cannot choose the
    // bytes for a source the user already selected.
    if (origin !== undefined && subscription.url !== origin && (published === undefined || manifest === undefined ||
      plugin.version !== published.version || manifestHash !== manifest || plugin.processor.sha256 !== published.processor.sha256)) continue
    offers.push({ subscription, plugin, manifestHash })
  }
  return offers.sort((a: ImagePluginOffer, b: ImagePluginOffer): number => b.plugin.version - a.plugin.version ||
    Number(!!a.subscription.lastError) - Number(!!b.subscription.lastError) ||
    (b.subscription.lastDownloadAt ?? 0) - (a.subscription.lastDownloadAt ?? 0))
}

export function imagePluginOffersConflict(offers: ImagePluginOffer[]): boolean {
  if (offers.length < 2) return false
  const first = offers[0]
  const identity = subscriptionIdentity(first.subscription.url)
  return offers.some((offer: ImagePluginOffer): boolean =>
    subscriptionIdentity(offer.subscription.url) !== identity ||
    (offer.plugin.version === first.plugin.version && (offer.plugin.processor.sha256 !== first.plugin.processor.sha256 ||
      (offer.manifestHash !== undefined && first.manifestHash !== undefined && offer.manifestHash !== first.manifestHash))))
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
  conflictSources: string[] = []
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
    const catalog = subscriptions.find((s: ImageRuleSubscription): boolean => !s.disabled && s.url === source.origin)
    for (const plugin of source.plugins) {
      installedIds.add(plugin.id)
      const offers = imagePluginOffers(subscriptions, plugin.id, source.origin)
      const sameVersionConflict = offers.some((offer: ImagePluginOffer): boolean => offer.plugin.version === plugin.version &&
        offer.plugin.processor.sha256 !== plugin.processor.sha256)
      const conflict = imagePluginOffersConflict(offers) || sameVersionConflict
      const offered = conflict ? undefined : offers[0]?.plugin
      const row = new ImagePluginRow(source, offered !== undefined && offered.version > plugin.version ? 'updates' : 'installed')
      if (conflict) row.conflictSources = Array.from(new Set([source.origin].concat(
        offers.map((offer: ImagePluginOffer): string => offer.subscription.url))))
      row.plugin = plugin; row.offered = offered; rows.push(row)
    }
    for (const pack of source.packs) {
      installedIds.add(pack.id)
      const offers = imagePluginOffers(subscriptions, pack.id, source.origin)
      const conflict = imagePluginOffersConflict(offers)
      const offered = conflict ? undefined : offers[0]?.plugin
      const offeredPack = catalog?.packs.find((value: ImageRulePack): boolean => value.id === pack.id)
      for (const rule of pack.rules) {
        const row = new ImagePluginRow(source, offered !== undefined || (offeredPack !== undefined && offeredPack.version > pack.version) ? 'updates' : 'installed')
        if (conflict) row.conflictSources = offers.map((offer: ImagePluginOffer): string => offer.subscription.url)
        row.pack = pack; row.rule = rule; row.offered = offered; row.offeredPack = offeredPack; rows.push(row)
      }
    }
  }
  const listedIds = new Set<string>(installedIds)
  for (const subscription of subscriptions) {
    if (subscription.disabled) continue
    const source: ImagePluginCollection = { origin: subscription.url, name: subscription.customName || subscription.name,
      plugins: [], packs: [], disabledRules: [], pluginSettings: {} }
    for (const offered of subscription.catalog ?? []) {
      if (listedIds.has(offered.id)) continue
      listedIds.add(offered.id)
      const offers = imagePluginOffers(subscriptions, offered.id)
      const best = offers[0]
      const row = new ImagePluginRow({ origin: best.subscription.url,
        name: best.subscription.customName || best.subscription.name, plugins: [], packs: [],
        disabledRules: [], pluginSettings: {} }, 'available')
      if (imagePluginOffersConflict(offers)) row.conflictSources = offers.map((offer: ImagePluginOffer): string => offer.subscription.url)
      row.offered = best.plugin; rows.push(row)
    }
    for (const pack of subscription.packs) {
      if (listedIds.has(pack.id) || imagePluginOffers(subscriptions, pack.id).length > 0) continue
      listedIds.add(pack.id)
      for (const rule of pack.rules) {
        const row = new ImagePluginRow(source, 'available'); row.offeredPack = pack; row.rule = rule; rows.push(row)
      }
    }
  }
  return rows
}

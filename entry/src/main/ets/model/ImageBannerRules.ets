import { ImageProcessingPlugin, ImagePluginHint, validateImageProcessingPlugin } from './ImageProcessingPlugins'
import { SettingsFieldValues } from './SettingsFormFields'

/** Legacy rule compatibility. Downloaded algorithms use ImageProcessingPlugins. */
export interface ImageRuleScale { minWidthExclusive: number; maxWidthExclusive: number; referenceWidth: number }
export interface ImageRuleSignature { id: string; width: number; height: number; averages: number[]; scale?: ImageRuleScale }
export interface ImageRuleEdge { signature: string; height?: number }
export interface ImageRuleLegacy { sourceIds?: string[]; kind: string; singleModes: string[]; stackedModes: string[] }
export interface ImageBannerRule {
  id: string; name?: string; description?: string; kind: string; crossSource: boolean; signatures: ImageRuleSignature[]
  top: ImageRuleEdge[]; bottom: ImageRuleEdge[]; legacy: ImageRuleLegacy[]
}
export interface ImageRuleMetadata { name: string; description?: string; website?: string }
export interface ImageRulePack { schemaVersion: number; id: string; version: number; rules: ImageBannerRule[]; meta?: ImageRuleMetadata }
export interface ImageRulePackReference { id: string; version: number; path: string; sha256: string }
export interface ImageRuleIndex { schemaVersion: number; kind?: string; meta?: ImageRuleMetadata; revision: string; packs: ImageRulePackReference[] }
export interface ImageRuleDescriptor { schemaVersion: number; indexUrl: string }
export interface ImageRuleRecord {
  origin: string; revision: string; packs: ImageRulePack[]
  plugins?: ImageProcessingPlugin[]
  pluginSettings?: Record<string, SettingsFieldValues>
}
export interface ImageRuleSnapshot { schemaVersion: number; records: ImageRuleRecord[] }
export interface ImageRuleSubscription {
  url: string; name: string; customName?: string; description?: string; website?: string
  enabled: boolean; automaticUpdates: boolean; updatedAt: number; lastAutomaticCheckAt?: number; revision: string
  packs: ImageRulePack[]; disabledRules: string[]
  catalog?: ImageProcessingPlugin[]
  plugins?: ImageProcessingPlugin[]
  pluginSettings?: Record<string, SettingsFieldValues>
}
export interface ImageRuleConfiguration { schemaVersion: number; subscriptions: ImageRuleSubscription[] }
export type ImageProcessingHint = ImagePluginHint
export interface ImageBannerPlan { rule: ImageBannerRule; mode: string; revision: string }
export function imageRuleKey(packId: string, ruleId: string): string { return JSON.stringify([packId, ruleId]) }
export function imageRuleSubscriptionName(value: ImageRuleSubscription): string { return value.customName || value.name }
export function validateImageRuleConfiguration(raw: Object): ImageRuleConfiguration {
  const value = raw as ImageRuleConfiguration
  // The previous implicit-download snapshot does not represent user consent to a subscription.
  // It may be restored as old backup data, but must never become enabled subscriptions.
  if (value?.schemaVersion === 1 && Array.isArray((raw as ImageRuleSnapshot).records))
    return { schemaVersion: 2, subscriptions: [] }
  if (!value || value.schemaVersion !== 2 || !Array.isArray(value.subscriptions) || value.subscriptions.length > 64)
    throw new Error('invalid_image_rule_subscriptions')
  const urls: Set<string> = new Set()
  for (const subscription of value.subscriptions) {
    if (!subscription || typeof subscription.url !== 'string' || !/^https?:\/\//.test(subscription.url) || urls.has(subscription.url) ||
      typeof subscription.name !== 'string' || !subscription.name.trim() || typeof subscription.revision !== 'string' ||
      typeof subscription.enabled !== 'boolean' || typeof subscription.automaticUpdates !== 'boolean' ||
      !Number.isFinite(subscription.updatedAt) || (subscription.lastAutomaticCheckAt !== undefined && !Number.isFinite(subscription.lastAutomaticCheckAt)) || !Array.isArray(subscription.packs) || subscription.packs.length > 32 ||
      !Array.isArray(subscription.disabledRules) || subscription.disabledRules.some((key: string): boolean => typeof key !== 'string'))
      throw new Error('invalid_image_rule_subscription')
    urls.add(subscription.url)
    for (const pack of subscription.packs) validateImageRulePack(pack)
    for (const plugin of subscription.catalog ?? []) validateImageProcessingPlugin(plugin)
    for (const plugin of subscription.plugins ?? []) {
      validateImageProcessingPlugin(plugin)
      if (typeof plugin.processor.moduleBase64 !== 'string' || !plugin.processor.moduleBase64)
        throw new Error('missing_installed_image_processor')
    }
  }
  return value
}
export type BannerFilterMode = 'source' | 'auto' | 'off'
export function normalizeBannerFilter(value: Object | undefined): BannerFilterMode {
  return value === 'auto' ? 'auto' : value === 'off' ? 'off' : 'source'
}
export function effectiveBannerFilter(global: Object | undefined, override: string | undefined): BannerFilterMode {
  return normalizeBannerFilter(override === undefined || override === 'global' ? global : override)
}
/** Compatibility discovery only, never an image eligibility gate. Fresh declarations work for any source;
 * Auto/Off and cached images from other producers must not acquire a new runtime/network dependency. */
export function canDiscoverSourceImageProcessing(snapshot: ImageRuleSnapshot, sourceId: string): boolean {
  return snapshot.records.some((record: ImageRuleRecord): boolean => record.packs.some((pack: ImageRulePack): boolean =>
    pack.rules.some((rule: ImageBannerRule): boolean => rule.legacy.some((alias: ImageRuleLegacy): boolean =>
      alias.sourceIds?.includes(sourceId) === true))) || (record.plugins ?? []).some((plugin: ImageProcessingPlugin): boolean =>
        plugin.application.sourceHints.some((hint): boolean => hint.sourceIds?.includes(sourceId) === true)))
}
export function imageBannerPlans(snapshot: ImageRuleSnapshot, policy: BannerFilterMode,
  hint?: ImageProcessingHint): ImageBannerPlan[] {
  if (policy === 'off') return []
  const result: ImageBannerPlan[] = []
  const seen: Set<string> = new Set()
  for (const record of snapshot.records) for (const pack of record.packs) for (const rule of pack.rules) {
    const identity = JSON.stringify(rule)
    if (seen.has(identity)) continue
    seen.add(identity)
    const revision = JSON.stringify([record.origin, pack.id, pack.version, record.revision])
    if (policy === 'auto' && rule.crossSource) result.push({ rule, mode: '2', revision })
    else if (policy === 'source' && hint !== undefined) {
      const alias = rule.legacy.find((value: ImageRuleLegacy): boolean => value.kind === hint.kind)
      if (alias?.singleModes.includes(hint.mode)) result.push({ rule, mode: '1', revision })
      else if (alias?.stackedModes.includes(hint.mode)) result.push({ rule, mode: '2', revision })
    }
  }
  return result
}

export function validateImageRulePack(raw: Object): ImageRulePack {
  const pack = raw as ImageRulePack
  if (!pack || pack.schemaVersion !== 1 || typeof pack.id !== 'string' || !pack.id ||
    !Number.isInteger(pack.version) || pack.version < 1 || !Array.isArray(pack.rules) ||
    pack.rules.length === 0 || pack.rules.length > 32) throw new Error('invalid_image_rule_pack')
  const ids: Set<string> = new Set()
  for (const rule of pack.rules) {
    if (!rule || typeof rule.id !== 'string' || !rule.id || ids.has(rule.id) || rule.kind !== 'edge_signature_v1' ||
      typeof rule.crossSource !== 'boolean' || !Array.isArray(rule.signatures) || rule.signatures.length === 0 ||
      rule.signatures.length > 32 || !Array.isArray(rule.top) || !Array.isArray(rule.bottom) || !Array.isArray(rule.legacy))
      throw new Error('invalid_image_rule')
    ids.add(rule.id)
    const signatures: Set<string> = new Set()
    for (const signature of rule.signatures) {
      if (!signature || typeof signature.id !== 'string' || !signature.id || signatures.has(signature.id) ||
        !Number.isInteger(signature.width) || signature.width < 1 || signature.width > 8192 ||
        !Number.isInteger(signature.height) || signature.height < 1 || signature.height > 4096 ||
        !Array.isArray(signature.averages) || signature.averages.length !== signature.height * 3 ||
        signature.averages.some((v: number): boolean => !Number.isInteger(v) || v < 0 || v > 255))
        throw new Error('invalid_image_signature')
      signatures.add(signature.id)
      const scale = signature.scale
      if (scale !== undefined && (!Number.isInteger(scale.referenceWidth) || scale.referenceWidth !== signature.width ||
        !Number.isInteger(scale.minWidthExclusive) || !Number.isInteger(scale.maxWidthExclusive) ||
        scale.minWidthExclusive < 1 || scale.maxWidthExclusive <= scale.minWidthExclusive || scale.maxWidthExclusive > 8192))
        throw new Error('invalid_image_signature_scale')
    }
    for (const edge of rule.top.concat(rule.bottom)) {
      const signature = rule.signatures.find((s: ImageRuleSignature): boolean => s.id === edge.signature)
      if (signature === undefined || (edge.height !== undefined &&
        (!Number.isInteger(edge.height) || edge.height < 1 || edge.height > signature.height))) throw new Error('invalid_image_rule_edge')
    }
    for (const alias of rule.legacy) {
      if (alias?.sourceIds !== undefined && (!Array.isArray(alias.sourceIds) || alias.sourceIds.some((id: string): boolean => typeof id !== 'string'))) throw new Error('invalid_image_rule_producers')
      if (!alias || typeof alias.kind !== 'string' || !Array.isArray(alias.singleModes) || !Array.isArray(alias.stackedModes) ||
        alias.singleModes.concat(alias.stackedModes).some((v: string): boolean => typeof v !== 'string')) throw new Error('invalid_image_rule_alias')
    }
  }
  return pack
}

export function validateImageRuleSnapshot(raw: Object): ImageRuleSnapshot {
  const snapshot = raw as ImageRuleSnapshot
  if (!snapshot || snapshot.schemaVersion !== 1 || !Array.isArray(snapshot.records) || snapshot.records.length > 64)
    throw new Error('invalid_image_rule_snapshot')
  const origins: Set<string> = new Set()
  for (const record of snapshot.records) {
    if (!record || typeof record.origin !== 'string' || origins.has(record.origin) ||
      typeof record.revision !== 'string' || !Array.isArray(record.packs) || record.packs.length > 32)
      throw new Error('invalid_image_rule_record')
    origins.add(record.origin)
    for (const pack of record.packs) validateImageRulePack(pack)
  }
  return snapshot
}

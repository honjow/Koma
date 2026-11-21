import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { writeAppTextFile } from './AppFileTextPersistence'
import { ImagePluginCollection, ImageRuleConfiguration, ImageRulePack, ImageRuleSubscription } from './ImageBannerRules'
import type { ImageProcessingPlugin } from './ImageProcessingPlugins'

export interface ImageRuleDatabaseRow {
  key: string
  order: number
  asset: string
  subscription?: ImageRuleSubscription
  installation?: ImagePluginCollection
}

interface ImageRuleAsset {
  packs: ImageRulePack[]
  plugins?: ImageProcessingPlugin[]
}

function assetDigest(payload: string): string {
  const digest = cryptoFramework.createMd('SHA256')
  digest.updateSync({ data: new util.TextEncoder().encodeInto(payload) })
  return Array.from(digest.digestSync().data).map((value: number): string => value.toString(16).padStart(2, '0')).join('')
}

function stageAsset(directory: string, value: ImageRuleAsset): string {
  const payload = JSON.stringify(value)
  const digest = assetDigest(payload)
  const path = directory + '/' + digest + '.json'
  if (!fs.accessSync(path) || fs.readTextSync(path) !== payload) writeAppTextFile(path, payload)
  return digest
}

function readAsset(directory: string, digest: string): ImageRuleAsset {
  if (!/^[0-9a-f]{64}$/.test(digest)) throw new Error('invalid_image_rule_asset')
  const payload = fs.readTextSync(directory + '/' + digest + '.json')
  if (assetDigest(payload) !== digest) throw new Error('invalid_image_rule_asset')
  return JSON.parse(payload) as ImageRuleAsset
}

// A database commit only publishes references to completely written immutable assets.
export function stageImageRuleFiles(directory: string, payload: string): string {
  if (payload.length > 16 * 1024 * 1024) throw new Error('image_rule_snapshot_too_large')
  if (!fs.accessSync(directory)) fs.mkdirSync(directory, true)
  const config = JSON.parse(payload) as ImageRuleConfiguration
  const rows: ImageRuleDatabaseRow[] = []
  config.subscriptions.forEach((subscription: ImageRuleSubscription, order: number): void => {
    const asset = stageAsset(directory, { packs: subscription.packs, plugins: subscription.catalog })
    subscription.packs = []
    subscription.catalog = undefined
    rows.push({ key: 'subscription/' + subscription.url, order, asset, subscription })
  })
  config.installations.forEach((installation: ImagePluginCollection, order: number): void => {
    const asset = stageAsset(directory, { packs: installation.packs, plugins: installation.plugins })
    installation.packs = []
    installation.plugins = []
    rows.push({ key: 'installation/' + installation.origin, order, asset, installation })
  })
  return JSON.stringify(rows)
}

export function materializeImageRuleFiles(directory: string, payload: string): string {
  const rows = JSON.parse(payload) as ImageRuleDatabaseRow[]
  const config: ImageRuleConfiguration = { schemaVersion: 3, subscriptions: [], installations: [] }
  rows.sort((left: ImageRuleDatabaseRow, right: ImageRuleDatabaseRow): number => left.order - right.order)
  rows.forEach((row: ImageRuleDatabaseRow): void => {
    const asset = readAsset(directory, row.asset)
    if (row.subscription !== undefined) {
      row.subscription.packs = asset.packs
      row.subscription.catalog = asset.plugins
      config.subscriptions.push(row.subscription)
    } else if (row.installation !== undefined) {
      row.installation.packs = asset.packs
      row.installation.plugins = asset.plugins ?? []
      config.installations.push(row.installation)
    }
  })
  return JSON.stringify(config)
}

export function cleanImageRuleFiles(directory: string, retainedDigests: string[]): void {
  if (!fs.accessSync(directory)) return
  const retained = new Set<string>(retainedDigests)
  for (const asset of fs.listFileSync(directory)) {
    if (/^[0-9a-f]{64}\.json$/.test(asset) && !retained.has(asset.substring(0, 64))) fs.unlinkSync(directory + '/' + asset)
  }
}

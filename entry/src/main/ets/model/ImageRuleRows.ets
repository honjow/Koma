import type { relationalStore } from '@kit.ArkData'
import type { ImageRuleDatabaseRow } from './ImageRuleAssetFiles'
import type { ImagePluginCollection, ImageRuleSubscription } from './ImageBannerRules'
import type { SettingsFieldValue, SettingsFieldValues } from './SettingsFormFields'
import { booleanColumn, booleanValue, collectLocalRows, integerColumn, textColumn } from './LocalDataRows'

export function readImageRuleStoreRows(store: relationalStore.RdbStore): ImageRuleDatabaseRow[] | undefined {
  const state = store.querySqlSync('SELECT id FROM image_rule_state WHERE id = 1')
  try {
    if (!state.goToNextRow()) return undefined
  } finally {
    state.close()
  }
  const subscriptions = collectLocalRows(store.querySqlSync('SELECT url, list_order, asset_digest, name, custom_name, ' +
    'description, website, updated_at, revision, last_error, disabled, last_download_at, has_manifest_hashes ' +
    'FROM image_rule_subscriptions ORDER BY list_order'), (row: relationalStore.ResultSet): ImageRuleDatabaseRow => {
    const url = row.getString(0)
    return { key: 'subscription/' + url, order: row.getLong(1), asset: row.getString(2), subscription: {
      url, name: row.getString(3), customName: textColumn(row, 4), description: textColumn(row, 5), website: textColumn(row, 6),
      updatedAt: row.getLong(7), revision: row.getString(8), lastError: textColumn(row, 9), disabled: booleanColumn(row, 10),
      lastDownloadAt: integerColumn(row, 11), manifestHashes: row.getLong(12) === 0 ? undefined : {}, packs: [],
    } }
  })
  const manifestByUrl = new Map<string, Record<string, string>>()
  for (const row of subscriptions) {
    const sub = row.subscription
    if (sub?.manifestHashes !== undefined) manifestByUrl.set(sub.url, sub.manifestHashes)
  }
  const hashes = store.querySqlSync('SELECT url, manifest_id, manifest_hash FROM image_rule_manifest_hashes ORDER BY manifest_order')
  try {
    while (hashes.goToNextRow()) {
      const manifests = manifestByUrl.get(hashes.getString(0))
      if (manifests !== undefined) manifests[hashes.getString(1)] = hashes.getString(2)
    }
  } finally {
    hashes.close()
  }
  const installations = collectLocalRows(store.querySqlSync('SELECT origin, list_order, asset_digest, name, has_conflicts ' +
    'FROM image_rule_installations ORDER BY list_order'), (row: relationalStore.ResultSet): ImageRuleDatabaseRow => {
    const origin = row.getString(0)
    return { key: 'installation/' + origin, order: row.getLong(1), asset: row.getString(2), installation: {
      origin, name: row.getString(3), packs: [], plugins: [], disabledRules: [], pluginSettings: {},
      conflicts: row.getLong(4) === 0 ? undefined : [],
    } }
  })
  const byOrigin = new Map<string, ImagePluginCollection>()
  for (const row of installations) {
    if (row.installation !== undefined) byOrigin.set(row.installation.origin, row.installation)
  }
  const items = store.querySqlSync('SELECT origin, item_kind, rule_id FROM image_rule_installation_items ORDER BY item_order')
  try {
    while (items.goToNextRow()) {
      const row = byOrigin.get(items.getString(0))
      const rules = items.getString(1) === 'disabled' ? row?.disabledRules : row?.conflicts
      rules?.push(items.getString(2))
    }
  } finally {
    items.close()
  }
  readPluginFields(store, byOrigin)
  return subscriptions.concat(installations)
}

function readPluginFields(store: relationalStore.RdbStore, installations: Map<string, ImagePluginCollection>): void {
  const rows = store.querySqlSync('SELECT g.origin, g.plugin_id, f.field_id, f.value_kind, f.value_text, f.value_number, ' +
    'f.value_boolean, i.item_text FROM image_rule_plugin_groups g LEFT JOIN image_rule_plugin_fields f ' +
    'ON g.origin=f.origin AND g.plugin_id=f.plugin_id LEFT JOIN image_rule_plugin_field_items i ' +
    'ON f.origin=i.origin AND f.plugin_id=i.plugin_id AND f.field_id=i.field_id ' +
    'ORDER BY g.origin, g.plugin_order, f.field_order, i.item_order')
  try {
    while (rows.goToNextRow()) {
      const installation = installations.get(rows.getString(0))
      if (installation === undefined) throw new Error('orphan_image_plugin_settings')
      const plugin = rows.getString(1)
      const fields: SettingsFieldValues = installation.pluginSettings[plugin] ?? {}
      installation.pluginSettings[plugin] = fields
      if (rows.isColumnNull(2)) continue
      const field = rows.getString(2)
      const kind = rows.getString(3)
      if (kind === 'string') fields[field] = rows.getString(4)
      else if (kind === 'number') fields[field] = rows.getDouble(5)
      else if (kind === 'boolean') fields[field] = rows.getLong(6) !== 0
      else if (kind === 'list') {
        const previous = fields[field]
        const values = Array.isArray(previous) ? previous as string[] : []
        if (!rows.isColumnNull(7)) values.push(rows.getString(7))
        fields[field] = values
      } else throw new Error('unexpected_image_plugin_setting_type')
    }
  } finally {
    rows.close()
  }
}

export function replaceImageRuleStoreRows(store: relationalStore.RdbStore, rows: ImageRuleDatabaseRow[] | undefined): void {
  for (const table of ['image_rule_plugin_field_items', 'image_rule_plugin_fields', 'image_rule_plugin_groups',
    'image_rule_installation_items', 'image_rule_manifest_hashes', 'image_rule_subscriptions', 'image_rule_installations']) {
    store.executeSync('DELETE FROM ' + table)
  }
  if (rows === undefined) {
    store.executeSync('DELETE FROM image_rule_state')
    return
  }
  for (const row of rows) {
    if (!/^[0-9a-f]{64}$/.test(row.asset)) throw new Error('invalid_image_rule_asset')
    if (row.subscription !== undefined) insertSubscription(store, row, row.subscription)
    else if (row.installation !== undefined) insertInstallation(store, row, row.installation)
    else throw new Error('invalid_image_rule_row')
  }
  store.executeSync('INSERT OR IGNORE INTO image_rule_state (id) VALUES (1)')
}

function insertSubscription(store: relationalStore.RdbStore, row: ImageRuleDatabaseRow, subscription: ImageRuleSubscription): void {
  const hashes = subscription.manifestHashes
  store.executeSync('INSERT INTO image_rule_subscriptions (url, list_order, asset_digest, name, custom_name, description, ' +
    'website, updated_at, revision, last_error, disabled, last_download_at, has_manifest_hashes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [subscription.url, row.order, row.asset, subscription.name, subscription.customName ?? null, subscription.description ?? null,
      subscription.website ?? null, subscription.updatedAt, subscription.revision, subscription.lastError ?? null,
      booleanValue(subscription.disabled), subscription.lastDownloadAt ?? null, hashes === undefined ? 0 : 1])
  if (hashes !== undefined) {
    Object.keys(hashes).forEach((id: string, order: number): void => {
      store.executeSync('INSERT INTO image_rule_manifest_hashes (url, manifest_id, manifest_order, manifest_hash) VALUES (?, ?, ?, ?)',
        [subscription.url, id, order, hashes[id]])
    })
  }
}

function insertInstallation(store: relationalStore.RdbStore, row: ImageRuleDatabaseRow, installation: ImagePluginCollection): void {
  store.executeSync('INSERT INTO image_rule_installations (origin, list_order, asset_digest, name, has_conflicts) VALUES (?, ?, ?, ?, ?)',
    [installation.origin, row.order, row.asset, installation.name, installation.conflicts === undefined ? 0 : 1])
  insertRuleIds(store, installation.origin, 'disabled', installation.disabledRules)
  insertRuleIds(store, installation.origin, 'conflict', installation.conflicts ?? [])
  const settings = installation.pluginSettings
  Object.keys(settings).forEach((plugin: string, order: number): void => {
    store.executeSync('INSERT INTO image_rule_plugin_groups (origin, plugin_id, plugin_order) VALUES (?, ?, ?)',
      [installation.origin, plugin, order])
    const fields = settings[plugin]
    Object.keys(fields).forEach((field: string, index: number): void => {
      insertPluginSetting(store, installation.origin, plugin, field, index, fields[field])
    })
  })
}

function insertRuleIds(store: relationalStore.RdbStore, origin: string, kind: string, ids: string[]): void {
  ids.forEach((id: string, order: number): void => {
    store.executeSync('INSERT INTO image_rule_installation_items (origin, item_kind, item_order, rule_id) VALUES (?, ?, ?, ?)',
      [origin, kind, order, id])
  })
}

function insertPluginSetting(store: relationalStore.RdbStore, origin: string, plugin: string, field: string, order: number,
  value: SettingsFieldValue): void {
  const kind = Array.isArray(value) ? 'list' : typeof value
  if (!['string', 'number', 'boolean', 'list'].includes(kind)) throw new Error('unexpected_image_plugin_setting_type')
  store.executeSync('INSERT INTO image_rule_plugin_fields (origin, plugin_id, field_id, field_order, value_kind, ' +
    'value_text, value_number, value_boolean) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [origin, plugin, field, order, kind, typeof value === 'string' ? value : null,
      typeof value === 'number' ? value : null, typeof value === 'boolean' ? booleanValue(value) : null])
  if (Array.isArray(value)) {
    (value as string[]).forEach((item: string, index: number): void => {
      store.executeSync('INSERT INTO image_rule_plugin_field_items (origin, plugin_id, field_id, item_order, item_text) ' +
        'VALUES (?, ?, ?, ?, ?)', [origin, plugin, field, index, item])
    })
  }
}

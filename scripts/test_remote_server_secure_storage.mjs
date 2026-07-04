import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const remoteServerStore = readFileSync(resolve(root, 'entry/src/main/ets/model/RemoteServerStore.ets'), 'utf8')
const backupService = readFileSync(resolve(root, 'entry/src/main/ets/model/BackupService.ets'), 'utf8')

assert.match(
  remoteServerStore,
  /import \{ asset \} from '@kit\.AssetStoreKit'/,
  'remote server credentials must use HarmonyOS AssetStore',
)

assert.match(
  remoteServerStore,
  /REMOTE_SERVER_CREDENTIAL_ASSET_GROUP_ID[\s\S]*koma-remote-server-credentials[\s\S]*remoteCredentialAssetQuery/,
  'remote server credentials must be scoped to a dedicated AssetStore group and query helper',
)

assert.match(
  remoteServerStore,
  /loadSecureCredentialPayload[\s\S]*KOMGA_CREDENTIAL_KEY[\s\S]*loadSecureCredentialPayload[\s\S]*WEBDAV_CREDENTIAL_KEY[\s\S]*loadSecureCredentialPayload[\s\S]*OPDS_CREDENTIAL_KEY/,
  'Komga, WebDAV, and OPDS loads must use the secure credential loader',
)

assert.match(
  remoteServerStore,
  /saveSecureCredential\(store, KOMGA_CREDENTIAL_KEY, 'komga'[\s\S]*saveSecureCredential\(store, WEBDAV_CREDENTIAL_KEY, 'webdav'[\s\S]*saveSecureCredential\(store, OPDS_CREDENTIAL_KEY, 'opds'/,
  'Komga, WebDAV, and OPDS saves must write credentials through the secure storage path',
)

assert.match(
  remoteServerStore,
  /writeCredentialAsset[\s\S]*asset\.Tag\.SECRET[\s\S]*asset\.add\(attributes\)[\s\S]*readCredentialAsset[\s\S]*asset\.query\(query\)[\s\S]*deleteCredentialAsset[\s\S]*asset\.remove\(remoteCredentialAssetQuery/,
  'remote server secure storage must implement write, read, and delete AssetStore operations',
)

assert.match(
  remoteServerStore,
  /const legacyPayload = await store\.get\(legacyKey, ''\)[\s\S]*writeCredentialAsset\(kind, credentialRef, legacyPayload\)[\s\S]*store\.delete\(legacyKey\)[\s\S]*credential_migrated/,
  'legacy Preferences credentials must migrate into AssetStore on read',
)

for (const key of ['KOMGA_CREDENTIAL_KEY', 'WEBDAV_CREDENTIAL_KEY', 'OPDS_CREDENTIAL_KEY']) {
  const putCredential = new RegExp(`store\\.put\\(${key},\\s*JSON\\.stringify\\(`)
  assert.doesNotMatch(
    remoteServerStore,
    putCredential,
    `${key} must not be written back to plain Preferences`,
  )
}

assert.match(
  backupService,
  /komgaCredential:\s*''[\s\S]*webDavCredential:\s*''[\s\S]*opdsCredential:\s*''/,
  'backup export must continue excluding remote server credentials',
)

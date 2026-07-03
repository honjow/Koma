import assert from 'node:assert/strict'
import { randomBytes, pbkdf2Sync, createCipheriv, createDecipheriv } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const serviceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/BackupEncryptionService.ets'), 'utf8')
const backupServiceSource = readFileSync(resolve(root, 'entry/src/main/ets/model/BackupService.ets'), 'utf8')
const pageSource = readFileSync(resolve(root, 'entry/src/main/ets/pages/BackupManagementPage.ets'), 'utf8')

const KIND = 'koma.backup.encrypted'
const ENVELOPE_VERSION = 1
const CONTENT_SCHEMA_VERSION = 4
const ALGORITHM = 'AES-256-GCM'
const KDF_ID = 'PBKDF2-HMAC-SHA-256'
const ITERATIONS = 600000

function b64u(bytes) {
  return Buffer.from(bytes).toString('base64url')
}

function b64uDecode(value) {
  return Buffer.from(value, 'base64url')
}

function canonical(value) {
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${JSON.stringify(value[key])}`).join(',')}}`
}

function aad() {
  return {
    kind: KIND,
    envelopeVersion: ENVELOPE_VERSION,
    contentSchemaVersion: CONTENT_SCHEMA_VERSION,
    algorithm: ALGORITHM,
    kdfId: KDF_ID,
  }
}

function encrypt(plaintext, passphrase) {
  const salt = randomBytes(32)
  const nonce = randomBytes(12)
  const key = pbkdf2Sync(passphrase, salt, ITERATIONS, 32, 'sha256')
  const associatedData = Buffer.from(canonical(aad()))
  const cipher = createCipheriv('aes-256-gcm', key, nonce)
  cipher.setAAD(associatedData)
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()])
  const tag = cipher.getAuthTag()
  return JSON.stringify({
    kind: KIND,
    envelopeVersion: ENVELOPE_VERSION,
    contentSchemaVersion: CONTENT_SCHEMA_VERSION,
    createdAt: 1760000000000,
    algorithm: ALGORITHM,
    kdf: {
      id: KDF_ID,
      iterations: ITERATIONS,
      salt: b64u(salt),
    },
    nonce: b64u(nonce),
    tag: b64u(tag),
    aad: aad(),
    payload: b64u(ciphertext),
  })
}

function decrypt(envelopeJson, passphrase) {
  const envelope = JSON.parse(envelopeJson)
  assert.equal(envelope.kind, KIND)
  assert.equal(envelope.envelopeVersion, ENVELOPE_VERSION)
  assert.equal(envelope.contentSchemaVersion, CONTENT_SCHEMA_VERSION)
  assert.equal(envelope.algorithm, ALGORITHM)
  assert.equal(envelope.kdf.id, KDF_ID)
  assert.equal(canonical(envelope.aad), canonical(aad()))
  const key = pbkdf2Sync(passphrase, b64uDecode(envelope.kdf.salt), envelope.kdf.iterations, 32, 'sha256')
  const decipher = createDecipheriv('aes-256-gcm', key, b64uDecode(envelope.nonce))
  decipher.setAAD(Buffer.from(canonical(envelope.aad)))
  decipher.setAuthTag(b64uDecode(envelope.tag))
  return Buffer.concat([decipher.update(b64uDecode(envelope.payload)), decipher.final()]).toString('utf8')
}

const passphrase = 'correct horse battery staple'
const plaintext = JSON.stringify({
  schemaVersion: 4,
  exportedAt: 1760000000000,
  encryption: { state: 'unencrypted', algorithm: 'none' },
  libraryStore: JSON.stringify({ schemaVersion: 1, comics: [{ id: 'comic-1', title: 'Private title' }] }),
  readingProgress: JSON.stringify({ schemaVersion: 1, progress: [{ comicId: 'comic-1', chapterId: 'c1' }], modes: [] }),
  remoteServers: { komgaServer: 'https://example.test', komgaCredential: '', webDavServer: '', webDavCredential: '', opdsServer: '', opdsCredential: '' },
  sourcePackages: [],
  sourceSettings: {},
  settings: {},
})
const envelopeJson = encrypt(plaintext, passphrase)
const envelope = JSON.parse(envelopeJson)

assert.equal(decrypt(envelopeJson, passphrase), plaintext, 'encrypted backup must round-trip')
assert.throws(() => decrypt(envelopeJson, 'wrong passphrase'), /Unsupported state|authenticate|bad decrypt|unable to authenticate/i, 'wrong passphrase must fail')

const tamperedPayload = structuredClone(envelope)
tamperedPayload.payload = b64u(Buffer.from('tampered'))
assert.throws(() => decrypt(JSON.stringify(tamperedPayload), passphrase), /Unsupported state|authenticate|bad decrypt|unable to authenticate/i, 'tampered payload must fail')

const tamperedAad = structuredClone(envelope)
tamperedAad.aad.algorithm = 'AES-128-GCM'
assert.throws(() => decrypt(JSON.stringify(tamperedAad), passphrase), /Expected values|strictEqual/, 'tampered aad must fail')

assert.equal(envelope.kind, KIND)
assert.equal(envelope.contentSchemaVersion, CONTENT_SCHEMA_VERSION)
assert.equal(envelope.algorithm, ALGORITHM)
assert.equal(envelope.kdf.id, KDF_ID)
assert.equal(envelope.kdf.iterations, ITERATIONS)
assert.ok(typeof envelope.salt === 'undefined', 'salt must live under kdf metadata')
assert.doesNotMatch(envelopeJson, /correct horse battery staple|Private title|comic-1/, 'public envelope must not contain passphrase or plaintext')

assert.match(serviceSource, /import \{ cryptoFramework \} from '@kit\.CryptoArchitectureKit'/, 'production encryption must use CryptoArchitectureKit')
assert.match(serviceSource, /BACKUP_KDF_NATIVE_NAME:\s*string = 'PBKDF2\|SHA256'[\s\S]*createKdf\(BACKUP_KDF_NATIVE_NAME\)/, 'production must derive keys with PBKDF2-HMAC-SHA-256')
assert.match(serviceSource, /BACKUP_ENCRYPTION_NATIVE_CIPHER:\s*string = 'AES256\|GCM\|PKCS7'[\s\S]*createCipher\(BACKUP_ENCRYPTION_NATIVE_CIPHER\)/, 'production must use AES-256-GCM')
assert.match(serviceSource, /aad:\s*\{\s*data:\s*aad\s*\}/, 'production GCM must bind AAD')
assert.match(backupServiceSource, /exportEncrypted\(passphrase: string\)[\s\S]*BackupEncryptionService\(\)\.encrypt/, 'BackupService must expose encrypted export')
assert.match(backupServiceSource, /decryptPreview\(json: string, passphrase: string\)[\s\S]*BackupEncryptionService\(\)\.decrypt/, 'BackupService must expose encrypted decrypt preview')
assert.match(pageSource, /KomaFormTextField\(\{[\s\S]*value:\s*this\.exportPassphrase[\s\S]*isPassword:\s*true/, 'UI must collect export passphrase as password input')
assert.match(pageSource, /KomaFormTextField\(\{[\s\S]*value:\s*this\.importPassphrase[\s\S]*isPassword:\s*true/, 'UI must collect import passphrase as password input')
assert.doesNotMatch(pageSource, /计划中|尚未启用|enabled\(false\)[\s\S]*加密备份/, 'UI must not leave encryption as placeholder-only')
assert.doesNotMatch(`${serviceSource}\n${backupServiceSource}\n${pageSource}`, /console\.(info|error|warn)\([^)]*(passphrase|payload|ciphertext|uri=)/i, 'logs must not include passphrases, payloads, ciphertext, or raw paths')

for (const version of [1, 2, 3]) {
  assert.match(
    backupServiceSource,
    new RegExp(`isAcceptedPlaintextSchemaVersion[\\s\\S]*schemaVersion === BACKUP_SCHEMA_VERSION${version === 1 ? '_V1' : version === 2 ? '_V2' : ''}`),
    `backup plaintext import must continue accepting v${version}`,
  )
}

assert.match(
  backupServiceSource,
  /import\(json: string\): Promise<void> \{\s*await this\.importDocument\(json, false\)/,
  'raw plaintext import must use the plaintext-only schema gate',
)
assert.match(
  backupServiceSource,
  /preview\(json: string\): BackupImportPreview[\s\S]*this\.previewDocument\(json, false\)/,
  'raw plaintext preview must use the plaintext-only schema gate',
)
assert.match(
  backupServiceSource,
  /function isAcceptedDecryptedSchemaVersion[\s\S]*BACKUP_ENCRYPTED_SCHEMA_VERSION/,
  'schema v4 must only be accepted by decrypted backup content gates',
)
assert.doesNotMatch(
  backupServiceSource,
  /function isAcceptedPlaintextSchemaVersion[^{]*\{[^}]*BACKUP_ENCRYPTED_SCHEMA_VERSION/,
  'standalone unencrypted v4 JSON backups must not be accepted by plaintext gates',
)
assert.match(
  pageSource,
  /selectedBackupPreview\?\.encrypted === true && this\.selectedBackupPreview\?\.decrypted === true[\s\S]*importDecrypted\(this\.selectedBackupPayload\)/,
  'UI restore must preserve decrypted-v4 import path after passphrase authentication',
)

console.log('backup encryption checks PASS')

import { buffer, util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { AppStrings } from '../i18n/AppStrings'

export const BACKUP_ENCRYPTED_KIND: string = 'koma.backup.encrypted'
export const BACKUP_ENCRYPTED_KIND_V1: string = 'koma.backup.encrypted.v1'
export const BACKUP_ENVELOPE_VERSION: number = 1
export const BACKUP_ENCRYPTED_CONTENT_SCHEMA_VERSION: number = 4
export const BACKUP_ENCRYPTION_ALGORITHM: string = 'AES-256-GCM'
export const BACKUP_ENCRYPTION_NATIVE_CIPHER: string = 'AES256|GCM|PKCS7'
export const BACKUP_ENCRYPTION_KEY_ALGORITHM: string = 'AES256'
export const BACKUP_KDF_ID: string = 'PBKDF2-HMAC-SHA-256'
export const BACKUP_KDF_NATIVE_NAME: string = 'PBKDF2|SHA256'
export const BACKUP_KDF_SPEC_NAME: string = 'PBKDF2'
export const BACKUP_KDF_ITERATIONS: number = 600000
export const BACKUP_KDF_SALT_BYTES: number = 32
export const BACKUP_GCM_NONCE_BYTES: number = 12
export const BACKUP_GCM_TAG_BYTES: number = 16
export const BACKUP_PASSPHRASE_MIN_LENGTH: number = 8
export const BACKUP_DECRYPT_FAILURE_CODE: string = 'backup_decrypt_failed'
export const BACKUP_ENVELOPE_FAILURE_CODE: string = 'backup_invalid_encrypted_envelope'

export interface BackupEncryptedAad {
  kind: string
  envelopeVersion: number
  contentSchemaVersion: number
  algorithm: string
  kdfId: string
}

export interface BackupEncryptedKdfMetadata {
  id: string
  iterations: number
  salt: string
}

export interface BackupEncryptedEnvelopeV1 {
  kind: string
  envelopeVersion: number
  contentSchemaVersion: number
  createdAt: number
  algorithm: string
  kdf: BackupEncryptedKdfMetadata
  nonce: string
  tag: string
  aad: BackupEncryptedAad
  payload: string
}

export interface BackupEncryptedPublicPreview {
  kind: string
  envelopeVersion: number
  contentSchemaVersion: number
  exportedAtText: string
  algorithm: string
  kdfId: string
}

function bytesToExactArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const exact = new Uint8Array(bytes.byteLength)
  exact.set(bytes)
  return exact.buffer
}

function utf8Encode(value: string): Uint8Array {
  return new Uint8Array(buffer.from(value, 'utf-8').buffer)
}

function utf8Decode(value: Uint8Array): string {
  return buffer.from(bytesToExactArrayBuffer(value)).toString('utf-8')
}

function base64UrlEncode(bytes: Uint8Array): string {
  const helper = new util.Base64Helper()
  return helper.encodeToStringSync(bytes)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '')
}

function base64UrlDecode(value: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]*$/.test(value)) {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
  let padded = value.replace(/-/g, '+').replace(/_/g, '/')
  while (padded.length % 4 !== 0) {
    padded += '='
  }
  const helper = new util.Base64Helper()
  return helper.decodeSync(padded)
}

export function canonicalBackupJson(value: Object): string {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
  const source = value as Record<string, Object>
  const keys = Object.keys(source).sort()
  const fields: string[] = []
  keys.forEach((key: string) => {
    fields.push(`${JSON.stringify(key)}:${JSON.stringify(source[key])}`)
  })
  return `{${fields.join(',')}}`
}

export function backupEncryptedAad(contentSchemaVersion: number): BackupEncryptedAad {
  return {
    kind: BACKUP_ENCRYPTED_KIND,
    envelopeVersion: BACKUP_ENVELOPE_VERSION,
    contentSchemaVersion,
    algorithm: BACKUP_ENCRYPTION_ALGORITHM,
    kdfId: BACKUP_KDF_ID,
  }
}

function validatePassphrase(passphrase: string): void {
  if (passphrase.length < BACKUP_PASSPHRASE_MIN_LENGTH) {
    throw new Error('backup_passphrase_too_short')
  }
}

function asObject(value: Object): Record<string, Object> {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
  return value as Record<string, Object>
}

function validateEnvelopeShape(envelope: BackupEncryptedEnvelopeV1): void {
  if (envelope.kind !== BACKUP_ENCRYPTED_KIND && envelope.kind !== BACKUP_ENCRYPTED_KIND_V1) {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
  if (envelope.envelopeVersion !== BACKUP_ENVELOPE_VERSION ||
    envelope.contentSchemaVersion !== BACKUP_ENCRYPTED_CONTENT_SCHEMA_VERSION ||
    envelope.algorithm !== BACKUP_ENCRYPTION_ALGORITHM) {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
  if (envelope.kdf === undefined || envelope.kdf.id !== BACKUP_KDF_ID ||
    envelope.kdf.iterations < BACKUP_KDF_ITERATIONS) {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
  if (typeof envelope.kdf.salt !== 'string' || typeof envelope.nonce !== 'string' ||
    typeof envelope.tag !== 'string' || typeof envelope.payload !== 'string') {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
  const expectedAad = backupEncryptedAad(envelope.contentSchemaVersion)
  if (canonicalBackupJson(envelope.aad as Object) !== canonicalBackupJson(expectedAad as Object)) {
    throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
  }
}

export function isEncryptedBackupPayload(json: string): boolean {
  try {
    const parsed = asObject(JSON.parse(json) as Object)
    const kind = parsed['kind']
    return kind === BACKUP_ENCRYPTED_KIND || kind === BACKUP_ENCRYPTED_KIND_V1
  } catch (_err) {
    return false
  }
}

export function previewEncryptedBackupEnvelope(json: string): BackupEncryptedPublicPreview {
  const envelope = JSON.parse(json) as BackupEncryptedEnvelopeV1
  validateEnvelopeShape(envelope)
  return {
    kind: envelope.kind,
    envelopeVersion: envelope.envelopeVersion,
    contentSchemaVersion: envelope.contentSchemaVersion,
    exportedAtText: envelope.createdAt > 0 ? new Date(envelope.createdAt).toLocaleString() : AppStrings.get('backup_preview_not_provided'),
    algorithm: envelope.algorithm,
    kdfId: envelope.kdf.id,
  }
}

export class BackupEncryptionService {
  async encrypt(plaintextBackupJson: string, passphrase: string): Promise<string> {
    validatePassphrase(passphrase)
    const salt = this.randomBytes(BACKUP_KDF_SALT_BYTES)
    const nonce = this.randomBytes(BACKUP_GCM_NONCE_BYTES)
    const key = await this.deriveKey(passphrase, salt, BACKUP_KDF_ITERATIONS)
    const aad = backupEncryptedAad(BACKUP_ENCRYPTED_CONTENT_SCHEMA_VERSION)
    const cipherWithTag = await this.encryptBytes(key, nonce, utf8Encode(canonicalBackupJson(aad as Object)), utf8Encode(plaintextBackupJson))
    const tagOffset = cipherWithTag.length - BACKUP_GCM_TAG_BYTES
    const ciphertext = cipherWithTag.slice(0, tagOffset)
    const tag = cipherWithTag.slice(tagOffset)
    const envelope: BackupEncryptedEnvelopeV1 = {
      kind: BACKUP_ENCRYPTED_KIND,
      envelopeVersion: BACKUP_ENVELOPE_VERSION,
      contentSchemaVersion: BACKUP_ENCRYPTED_CONTENT_SCHEMA_VERSION,
      createdAt: Date.now(),
      algorithm: BACKUP_ENCRYPTION_ALGORITHM,
      kdf: {
        id: BACKUP_KDF_ID,
        iterations: BACKUP_KDF_ITERATIONS,
        salt: base64UrlEncode(salt),
      },
      nonce: base64UrlEncode(nonce),
      tag: base64UrlEncode(tag),
      aad,
      payload: base64UrlEncode(ciphertext),
    }
    console.info('[BackupEncryption] step=encrypt ok=true')
    return JSON.stringify(envelope)
  }

  async decrypt(envelopeJson: string, passphrase: string): Promise<string> {
    validatePassphrase(passphrase)
    let envelope: BackupEncryptedEnvelopeV1
    try {
      envelope = JSON.parse(envelopeJson) as BackupEncryptedEnvelopeV1
      validateEnvelopeShape(envelope)
    } catch (_err) {
      throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
    }
    try {
      const salt = base64UrlDecode(envelope.kdf.salt)
      const nonce = base64UrlDecode(envelope.nonce)
      const tag = base64UrlDecode(envelope.tag)
      const ciphertext = base64UrlDecode(envelope.payload)
      if (salt.length !== BACKUP_KDF_SALT_BYTES || nonce.length !== BACKUP_GCM_NONCE_BYTES ||
        tag.length !== BACKUP_GCM_TAG_BYTES || ciphertext.length === 0) {
        throw new Error(BACKUP_ENVELOPE_FAILURE_CODE)
      }
      const key = await this.deriveKey(passphrase, salt, envelope.kdf.iterations)
      const plaintext = await this.decryptBytes(key, nonce, utf8Encode(canonicalBackupJson(envelope.aad as Object)), ciphertext, tag)
      console.info('[BackupEncryption] step=decrypt ok=true')
      return utf8Decode(plaintext)
    } catch (_err) {
      throw new Error(BACKUP_DECRYPT_FAILURE_CODE)
    }
  }

  private randomBytes(length: number): Uint8Array {
    return cryptoFramework.createRandom().generateRandomSync(length).data
  }

  private async deriveKey(passphrase: string, salt: Uint8Array, iterations: number): Promise<cryptoFramework.SymKey> {
    const kdf = cryptoFramework.createKdf(BACKUP_KDF_NATIVE_NAME)
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: BACKUP_KDF_SPEC_NAME,
      password: passphrase,
      salt,
      iterations,
      keySize: 32,
    }
    const secret = await kdf.generateSecret(spec)
    return await cryptoFramework.createSymKeyGenerator(BACKUP_ENCRYPTION_KEY_ALGORITHM).convertKey({ data: secret.data })
  }

  private async encryptBytes(
    key: cryptoFramework.SymKey,
    nonce: Uint8Array,
    aad: Uint8Array,
    plaintext: Uint8Array,
  ): Promise<Uint8Array> {
    const cipher = cryptoFramework.createCipher(BACKUP_ENCRYPTION_NATIVE_CIPHER)
    const params: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: nonce },
      aad: { data: aad },
      authTag: { data: new Uint8Array(BACKUP_GCM_TAG_BYTES) },
    }
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, params)
    return (await cipher.doFinal({ data: plaintext })).data
  }

  private async decryptBytes(
    key: cryptoFramework.SymKey,
    nonce: Uint8Array,
    aad: Uint8Array,
    ciphertext: Uint8Array,
    tag: Uint8Array,
  ): Promise<Uint8Array> {
    const cipher = cryptoFramework.createCipher(BACKUP_ENCRYPTION_NATIVE_CIPHER)
    const params: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: nonce },
      aad: { data: aad },
      authTag: { data: tag },
    }
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, key, params)
    return (await cipher.doFinal({ data: ciphertext })).data
  }
}

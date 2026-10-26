// Adapted from NextE59a7a679. Koma owns configuration, credentials and files.
import { common } from '@kit.AbilityKit'
import { KomaTranslationSettings } from '../KomaTranslationSettings'

const TORII_CREDENTIAL_VERSION: number = 2
const TORII_LEGACY_CREDENTIAL_VERSION: number = 1
const MAX_TORII_CREDENTIAL_CHARS: number = 16 * 1024
const MAX_TORII_API_KEY_CHARS: number = 8192

class StoredToriiWholePageCredential {
  version: number = TORII_CREDENTIAL_VERSION
  toriiApiKey: string = ''
}

class LegacyStoredToriiWholePageCredential {
  version: number = TORII_LEGACY_CREDENTIAL_VERSION
  toriiApiKey: string = ''
  byokApiKey: string = ''
}

export class ToriiWholePageCredential {
  toriiApiKey: string = ''

  copy(): ToriiWholePageCredential {
    const value: ToriiWholePageCredential = new ToriiWholePageCredential()
    value.toriiApiKey = this.toriiApiKey
    return value
  }

  static parse(rawValue: string): ToriiWholePageCredential {
    const output: ToriiWholePageCredential = new ToriiWholePageCredential()
    if (rawValue.length === 0) {
      return output
    }
    if (rawValue.length > MAX_TORII_CREDENTIAL_CHARS || /[\r\n]/.test(rawValue)) {
      throw new Error('Torii credential is invalid')
    }
    let stored: StoredToriiWholePageCredential
    try {
      stored = JSON.parse(rawValue) as StoredToriiWholePageCredential
    } catch (_error) {
      throw new Error('Torii credential is invalid')
    }
    if (stored === null || typeof stored !== 'object' ||
      (stored.version !== TORII_CREDENTIAL_VERSION &&
        stored.version !== TORII_LEGACY_CREDENTIAL_VERSION) ||
      typeof stored.toriiApiKey !== 'string') {
      throw new Error('Torii credential is invalid')
    }
    if (stored.version === TORII_LEGACY_CREDENTIAL_VERSION) {
      const legacy: LegacyStoredToriiWholePageCredential =
        JSON.parse(rawValue) as LegacyStoredToriiWholePageCredential
      if (typeof legacy.byokApiKey !== 'string') {
        throw new Error('Torii credential is invalid')
      }
    }
    output.toriiApiKey = stored.toriiApiKey
    ToriiWholePageCredential.validate(output)
    return output
  }

  static serialize(value: ToriiWholePageCredential): string {
    ToriiWholePageCredential.validate(value)
    if (value.toriiApiKey.length === 0) {
      return ''
    }
    const stored: StoredToriiWholePageCredential = new StoredToriiWholePageCredential()
    stored.toriiApiKey = value.toriiApiKey
    const raw: string = JSON.stringify(stored)
    if (raw.length <= 0 || raw.length > MAX_TORII_CREDENTIAL_CHARS || /[\r\n]/.test(raw)) {
      throw new Error('Torii credential is invalid')
    }
    return raw
  }

  private static validate(value: ToriiWholePageCredential): void {
    ToriiWholePageCredential.validateKey(value.toriiApiKey)
  }

  private static validateKey(value: string): void {
    if (value.length > MAX_TORII_API_KEY_CHARS || value !== value.trim() ||
      /[\r\n\t]/.test(value) || value.includes('\u0000')) {
      throw new Error('Torii credential is invalid')
    }
  }
}

export class ToriiWholePageSecretStore {
  static async read(context: common.UIAbilityContext, expectedRevision: number = -1): Promise<ToriiWholePageCredential> {
    const settings = await KomaTranslationSettings.load(context)
    KomaTranslationSettings.assertRevision(expectedRevision, settings.revision)
    const value = new ToriiWholePageCredential()
    value.toriiApiKey = settings.toriiApiKey
    return value
  }
}

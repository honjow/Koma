import { LlmSourceProfile } from './model/LlmSourceProfile'
import { LlmSourceProfileCodec } from './services/LlmSourceProfileCodec'
import { CodexOAuthTokenCodec } from './services/CodexOAuthTokenCodec'

/** Credentials stay inside Koma's atomic secure configuration, never in reactive metadata. */
export class KomaTranslationLlmSource {
  profile: LlmSourceProfile = new LlmSourceProfile()
  apiKey: string = ''
  codexTokens: string = ''

  copy(): KomaTranslationLlmSource {
    const value = new KomaTranslationLlmSource()
    value.profile = this.profile.copy()
    value.apiKey = this.apiKey
    value.codexTokens = this.codexTokens
    return value
  }

  static decode(raw: string): KomaTranslationLlmSource[] {
    const values = JSON.parse(raw) as KomaTranslationLlmSource[]
    const profiles = LlmSourceProfileCodec.decode(JSON.stringify(values.map((value: KomaTranslationLlmSource) => value.profile)))
    return profiles.map((profile: LlmSourceProfile, index: number): KomaTranslationLlmSource => {
      const value = new KomaTranslationLlmSource()
      value.profile = profile
      value.apiKey = values[index].apiKey
      const tokens = values[index].codexTokens ?? ''
      if (typeof tokens !== 'string' || (tokens.length > 0 && CodexOAuthTokenCodec.parse(tokens) === null)) {
        throw new Error('reader_translation_configuration_invalid')
      }
      value.codexTokens = tokens
      if (typeof value.apiKey !== 'string' || value.apiKey.length > 16384 || /[\r\n\u0000]/.test(value.apiKey)) {
        throw new Error('reader_translation_configuration_invalid')
      }
      return value
    })
  }
}

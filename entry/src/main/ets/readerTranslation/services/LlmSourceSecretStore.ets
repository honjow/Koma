import { common } from '@kit.AbilityKit'
import { KomaTranslationSettings } from '../KomaTranslationSettings'
import { CodexOAuthTokenSet } from '../model/CodexOAuth'
import { CodexOAuthTokenCodec } from './CodexOAuthTokenCodec'

/** NextE source-secret contract, backed by Koma's single atomic secure writer. */
export class LlmSourceSecretStore {
  static async readCodexTokens(context: common.UIAbilityContext,
    sourceProfileId: string): Promise<CodexOAuthTokenSet | null> {
    const settings = await KomaTranslationSettings.load(context)
    const source = settings.llmSources.find((item) => item.profile.sourceProfileId === sourceProfileId)
    return source === undefined ? null : CodexOAuthTokenCodec.parse(source.codexTokens)
  }

  static saveCodexTokens(context: common.UIAbilityContext, sourceProfileId: string,
    tokens: CodexOAuthTokenSet, previousRefreshToken: string = ''): Promise<void> {
    return KomaTranslationSettings.updateSourceTokens(context, sourceProfileId, tokens, previousRefreshToken)
  }

  static clearCodexTokens(context: common.UIAbilityContext, sourceProfileId: string): Promise<void> {
    return KomaTranslationSettings.updateSourceTokens(context, sourceProfileId, null)
  }
}

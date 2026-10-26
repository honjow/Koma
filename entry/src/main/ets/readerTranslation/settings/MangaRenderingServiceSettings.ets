// Adapted from NextE59a7a679. Koma owns configuration, credentials and files.
import { common } from '@kit.AbilityKit'
import { KomaTranslationSettings } from '../KomaTranslationSettings'
import { MangaTranslatorUiSidecarConfig } from '../services/MangaTranslatorUiSidecarBackend'
import {
  MANGA_TRANSLATOR_UI_DETECTION_BALANCED,
  MANGA_TRANSLATOR_UI_DETECTION_HIGH_RECALL,
  MANGA_TRANSLATOR_UI_INPAINTER_FAST,
  MANGA_TRANSLATOR_UI_INPAINTER_QUALITY,
  MangaTranslatorUiSidecarProfileCatalog,
} from '../services/MangaTranslatorUiSidecarProtocol'

export class MangaRenderingServiceSettingsSnapshot {
  baseUrl: string = ''
  detectionProfile: string = MANGA_TRANSLATOR_UI_DETECTION_HIGH_RECALL
  inpaintingProfile: string = MANGA_TRANSLATOR_UI_INPAINTER_QUALITY

  configured(): boolean {
    return this.baseUrl.length > 0
  }

  copy(): MangaRenderingServiceSettingsSnapshot {
    const value: MangaRenderingServiceSettingsSnapshot =
      new MangaRenderingServiceSettingsSnapshot()
    value.baseUrl = this.baseUrl
    value.detectionProfile = this.detectionProfile
    value.inpaintingProfile = this.inpaintingProfile
    return value
  }

  assertValid(): void {
    MangaTranslatorUiSidecarProfileCatalog.assertOptions(
      this.detectionProfile,
      this.inpaintingProfile,
    )
  }
}

/** Persists non-secret manga rendering service configuration. */
export class MangaRenderingServiceSettings {
  static async load(context: common.UIAbilityContext, expectedRevision: number = -1): Promise<MangaRenderingServiceSettingsSnapshot> {
    const settings = await KomaTranslationSettings.load(context)
    KomaTranslationSettings.assertRevision(expectedRevision, settings.revision)
    const value = new MangaRenderingServiceSettingsSnapshot()
    value.baseUrl = settings.sidecarUrl
    value.detectionProfile = settings.detectionProfile
    value.inpaintingProfile = settings.inpaintingProfile
    value.assertValid()
    return value
  }
}

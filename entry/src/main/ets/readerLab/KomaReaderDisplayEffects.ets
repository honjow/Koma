import { ReaderImageEffects } from '@reader-kit/ui'
import { ReaderDisplaySettings, readerDisplayDimOpacity } from '../model/ReaderDisplaySettings'

export function komaReaderImageEffects(settings: ReaderDisplaySettings): ReaderImageEffects {
  const effects = new ReaderImageEffects()
  effects.grayscale = settings.grayscale
  effects.inverted = settings.inverted
  effects.tint = settings.filterEnabled && settings.alpha > 0
  effects.tintColor = `rgba(${settings.red},${settings.green},${settings.blue},${settings.alpha / 255})`
  effects.blendMode = settings.blendMode === 'multiply' ? BlendMode.MODULATE :
    settings.blendMode === 'screen' ? BlendMode.SCREEN : settings.blendMode === 'overlay' ? BlendMode.OVERLAY :
      settings.blendMode === 'lighten' ? BlendMode.LIGHTEN : settings.blendMode === 'darken' ? BlendMode.DARKEN :
        BlendMode.SRC_OVER
  effects.dimOpacity = readerDisplayDimOpacity(settings)
  return effects
}

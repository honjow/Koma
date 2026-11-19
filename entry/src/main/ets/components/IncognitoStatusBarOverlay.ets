import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectIncognitoState, IncognitoState } from '../state/IncognitoState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { common, ConfigurationConstant } from '@kit.AbilityKit'

const LABEL_SPACING_VP: number = 4

// Incognito status strip: a tinted band across the whole status-bar area with
// a centered label pinned to its bottom edge. Only a cutout in the label's
// horizontal span reduces its size. Rendered above non-reader pages.
@ComponentV2
export struct IncognitoStatusBarOverlay {
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private incognito: IncognitoState = connectIncognitoState()

  // Extend the strip 4vp below the status bar so devices whose camera cutout
  // reaches the status bar's bottom edge still have room for the label.
  private bandHeight(): number {
    return this.safeArea.topAvoidHeight + 4
  }

  // A light, clearly transparent wash: over a white status bar it settles at a
  // soft gray, over a black one at a soft light-gray, and the system
  // blur/gradient underneath still shows through.
  private bandColor(): ResourceColor {
    return '#4F808080'
  }

  private labelColor(): ResourceColor {
    return ThemeConstants.BRAND_PRIMARY
  }

  private isDarkMode(): boolean {
    try {
      const context = getContext(this) as common.UIAbilityContext
      return context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    } catch (_error) {
      return false
    }
  }

  @Computed
  private get labelFontSize(): number {
    const bandHeight = this.bandHeight()
    const normalSize = Math.min(Math.max(bandHeight, 4), 12)
    const cutout = this.safeArea.topCutout
    if (cutout.right <= cutout.left || cutout.bottom <= 0) return normalSize

    const reducedSize = Math.max(4, Math.min(normalSize, bandHeight - cutout.bottom))
    const windowWidth = this.safeArea.windowWidthVp
    if (windowWidth <= 0 || reducedSize === normalSize) return reducedSize

    // Use the normal-size label to decide overlap. Measuring the smaller label
    // would let the fit flip back and forth when a cutout is just off-center.
    const uiContext = this.getUIContext()
    const textWidthPx = uiContext.getMeasureUtils().measureText({
      textContent: AppStrings.get('incognito_mode_label'),
      fontSize: normalSize,
    })
    const labelWidth = uiContext.px2vp(textWidthPx + uiContext.fp2px(normalSize)) + LABEL_SPACING_VP
    const labelLeft = (windowWidth - labelWidth) / 2
    const labelRight = labelLeft + labelWidth
    return cutout.left < labelRight && cutout.right > labelLeft ? reducedSize : normalSize
  }

  build() {
    if (this.incognito.enabled && this.bandHeight() > 0) {
      Stack() {
        Row({ space: LABEL_SPACING_VP }) {
          Text(AppStrings.get('incognito_mode_label'))
            .fontSize(this.labelFontSize)
            .fontColor(this.labelColor())
          SymbolGlyph($r('sys.symbol.eye_slash'))
            .fontSize(this.labelFontSize)
            .fontColor([this.labelColor()])
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        // Nudge the ink down by most of its font descent so the glyph's bottom
        // edge sits just inside the strip's bottom, flush without crossing it.
        .offset({ y: this.labelFontSize * 0.17 })
      }
      .width('100%')
      .height(this.bandHeight())
      .backgroundColor(this.bandColor())
      .alignContent(Alignment.Bottom)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
      .hitTestBehavior(HitTestMode.None)
    }
  }
}

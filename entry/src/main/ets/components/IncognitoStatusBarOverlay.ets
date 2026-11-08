import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectIncognitoState, IncognitoState } from '../state/IncognitoState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { common, ConfigurationConstant } from '@kit.AbilityKit'

// Incognito status strip: a tinted band across the whole status-bar area with
// a small "incognito" label pinned to the band's bottom edge, below the camera
// cutout. Rendered only while incognito mode is on, on top of every page below
// the reader.
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

  // The font is the gap between the cutout's bottom edge and the band's bottom
  // edge, directly: no multiplier, no fixed size. 4vp is the lower bound so a
  // narrow gap still renders a legible label; 12vp caps an abnormally wide one.
  private labelFontSize(): number {
    const gap = this.bandHeight() - this.safeArea.topCutoutHeight
    return Math.min(Math.max(gap, 4), 12)
  }

  build() {
    if (this.incognito.enabled && this.bandHeight() > 0) {
      Stack() {
        // The label container spans the whole band and pins the label to the
        // band's bottom edge, which is the status bar's bottom. A large camera
        // cutout never hides the label: the container simply overlaps the
        // cutout region from the top.
        Row({ space: 4 }) {
          Text(AppStrings.get('incognito_mode_label'))
            .fontSize(this.labelFontSize())
            .fontColor(this.labelColor())
          SymbolGlyph($r('sys.symbol.eye_slash'))
            .fontSize(this.labelFontSize())
            .fontColor([this.labelColor()])
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        // Nudge the ink down by most of its font descent so the glyph's bottom
        // edge sits just inside the strip's bottom, flush without crossing it.
        .offset({ y: this.labelFontSize() * 0.17 })
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

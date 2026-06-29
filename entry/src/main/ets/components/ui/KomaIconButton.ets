import { ThemeConstants } from '../../theme/ThemeConstants'

export type KomaIconButtonKind = 'primary' | 'secondary' | 'danger' | 'ghost'

@ComponentV2
export struct KomaIconButton {
  @Param icon: Resource = $r('sys.symbol.gearshape')
  @Param kind: KomaIconButtonKind = 'ghost'
  @Param isEnabled: boolean = true
  @Param controlSize: number = ThemeConstants.ACTION_CHIP_HEIGHT
  @Param iconSize: number = ThemeConstants.FONT_SIZE_H2
  @Param accentColor: ResourceColor | undefined = undefined
  @Event action: () => void = () => {}

  private buttonForegroundColor(): ResourceColor {
    if (!this.isEnabled) {
      return ThemeConstants.TEXT_TERTIARY
    }
    if (this.kind === 'primary' || this.kind === 'danger') {
      return ThemeConstants.TEXT_ON_BRAND
    }
    return this.accentColor ?? ThemeConstants.TEXT_PRIMARY
  }

  private buttonBackgroundColor(): ResourceColor {
    if (this.kind === 'primary') {
      return this.accentColor ?? ThemeConstants.BRAND_PRIMARY
    }
    if (this.kind === 'danger') {
      return ThemeConstants.DANGER
    }
    if (this.kind === 'secondary') {
      return $r('sys.color.ohos_id_color_button_normal')
    }
    return Color.Transparent
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.icon)
        .fontSize(this.iconSize)
        .fontColor([this.buttonForegroundColor()])
    }
    .width(this.controlSize)
    .height(this.controlSize)
    .backgroundColor(this.buttonBackgroundColor())
    .enabled(this.isEnabled)
    .opacity(this.isEnabled ? 1 : 0.45)
    .onClick(() => {
      this.action()
    })
  }
}

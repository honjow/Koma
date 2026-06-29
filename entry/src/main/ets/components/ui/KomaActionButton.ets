import { ThemeConstants } from '../../theme/ThemeConstants'

export type KomaActionButtonKind = 'primary' | 'secondary' | 'danger' | 'ghost'

@ComponentV2
export struct KomaActionButton {
  @Param label: ResourceStr = ''
  @Param kind: KomaActionButtonKind = 'secondary'
  @Param isEnabled: boolean = true
  @Param fill: boolean = false
  @Param busy: boolean = false
  @Param controlHeight: number = ThemeConstants.BUTTON_HEIGHT
  @Param icon: Resource | undefined = undefined
  @Param accentColor: ResourceColor | undefined = undefined
  @Param compact: boolean = false
  @Event action: () => void = () => {}

  private buttonForegroundColor(): ResourceColor {
    if (!this.isEnabled) {
      return ThemeConstants.TEXT_TERTIARY
    }
    if (this.kind === 'primary' || this.kind === 'danger') {
      return ThemeConstants.TEXT_ON_BRAND
    }
    if (this.kind === 'ghost') {
      return this.accentColor ?? ThemeConstants.BRAND_PRIMARY
    }
    return this.accentColor ?? ThemeConstants.BRAND_PRIMARY
  }

  private buttonBackgroundColor(): ResourceColor {
    if (this.kind === 'primary') {
      return this.accentColor ?? ThemeConstants.BRAND_PRIMARY
    }
    if (this.kind === 'danger') {
      return ThemeConstants.DANGER
    }
    if (this.kind === 'ghost') {
      return Color.Transparent
    }
    return $r('sys.color.ohos_id_color_button_normal')
  }

  private buttonBorderColor(): ResourceColor {
    if (this.kind === 'secondary' || this.kind === 'ghost') {
      return this.accentColor ?? ThemeConstants.BRAND_PRIMARY
    }
    return Color.Transparent
  }

  private buttonHorizontalPadding(): number {
    return this.compact ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_LG
  }

  build() {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        if (this.icon !== undefined) {
          SymbolGlyph(this.icon)
            .fontSize(ThemeConstants.FONT_SIZE_HEADING)
            .fontColor([this.buttonForegroundColor()])
        }
        Text(this.label)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.buttonForegroundColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(this.controlHeight)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .padding({ left: this.buttonHorizontalPadding(), right: this.buttonHorizontalPadding() })
    }
      .height(this.controlHeight)
      .layoutWeight(this.fill ? 1 : 0)
      .backgroundColor(this.buttonBackgroundColor())
      .border({ width: this.kind === 'secondary' || this.kind === 'ghost' ? 1 : 0, color: this.buttonBorderColor() })
      .opacity(this.isEnabled ? 1 : 0.45)
      .enabled(this.isEnabled && !this.busy)
      .onClick(() => {
        this.action()
      })
  }
}

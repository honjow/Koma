import { ThemeConstants } from '../../theme/ThemeConstants'

export type KomaActionButtonKind = 'primary' | 'secondary' | 'danger' | 'ghost'

@ComponentV2
export struct KomaActionButton {
  @Param label: ResourceStr = ''
  @Param kind: KomaActionButtonKind = 'secondary'
  @Param isEnabled: boolean = true
  @Param fill: boolean = false
  @Param fullWidth: boolean = false
  @Param busy: boolean = false
  @Param controlHeight: number = ThemeConstants.BUTTON_HEIGHT
  @Param icon: Resource | undefined = undefined
  @Param accentColor: ResourceColor | undefined = undefined
  @Param contentColor: ResourceColor | undefined = undefined
  @Param fillColor: ResourceColor | undefined = undefined
  @Param strokeColor: ResourceColor | undefined = undefined
  @Param compact: boolean = false
  @Event action: () => void = () => {}

  private buttonForegroundColor(): ResourceColor {
    if (!this.isEnabled) {
      return ThemeConstants.TEXT_TERTIARY
    }
    if (this.contentColor !== undefined) {
      return this.contentColor
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
    if (this.fillColor !== undefined) {
      return this.fillColor
    }
    if (this.kind === 'primary') {
      return this.accentColor ?? ThemeConstants.TEXT_PRIMARY
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
    if (this.strokeColor !== undefined) {
      return this.strokeColor
    }
    return Color.Transparent
  }

  private buttonBorderWidth(): number {
    return this.strokeColor === undefined ? 0 : 1
  }

  private buttonCornerRadius(): number {
    return this.compact ? ThemeConstants.RADIUS_SM : ThemeConstants.RADIUS_CHIP
  }

  private buttonHorizontalPadding(): number {
    return this.compact ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_LG
  }

  @Builder
  private ButtonContent() {
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
    .height(this.controlHeight)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .padding({ left: this.buttonHorizontalPadding(), right: this.buttonHorizontalPadding() })
  }

  build() {
    if (this.fullWidth) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        this.ButtonContent()
      }
        .width('100%')
        .height(this.controlHeight)
        .layoutWeight(this.fill ? 1 : 0)
        .backgroundColor(this.buttonBackgroundColor())
        .border({ width: this.buttonBorderWidth(), color: this.buttonBorderColor() })
        .borderRadius(this.buttonCornerRadius())
        .opacity(this.isEnabled ? 1 : 0.45)
        .enabled(this.isEnabled && !this.busy)
        .onClick(() => {
          this.action()
        })
    } else {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        this.ButtonContent()
      }
        .height(this.controlHeight)
        .layoutWeight(this.fill ? 1 : 0)
        .backgroundColor(this.buttonBackgroundColor())
        .border({ width: this.buttonBorderWidth(), color: this.buttonBorderColor() })
        .borderRadius(this.buttonCornerRadius())
        .opacity(this.isEnabled ? 1 : 0.45)
        .enabled(this.isEnabled && !this.busy)
        .onClick(() => {
          this.action()
        })
    }
  }
}

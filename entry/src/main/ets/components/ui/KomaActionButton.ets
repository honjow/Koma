import { ThemeConstants } from '../../theme/ThemeConstants'

export type KomaActionButtonKind = 'primary' | 'secondary' | 'danger' | 'ghost'

// Native Button stays disabled; its custom content avoids the platform's
// additional disabled alpha being multiplied into our disabled palette.
class KomaDisabledActionContent implements ContentModifier<ButtonConfiguration> {
  label: ResourceStr
  icon: Resource | undefined
  controlHeight: number
  horizontalPadding: number
  expand: boolean
  foreground: ResourceColor
  background: ResourceColor
  borderColor: ResourceColor
  borderWidth: number

  constructor(
    label: ResourceStr, icon: Resource | undefined, controlHeight: number,
    horizontalPadding: number, expand: boolean, foreground: ResourceColor,
    background: ResourceColor, borderColor: ResourceColor, borderWidth: number,
  ) {
    this.label = label
    this.icon = icon
    this.controlHeight = controlHeight
    this.horizontalPadding = horizontalPadding
    this.expand = expand
    this.foreground = foreground
    this.background = background
    this.borderColor = borderColor
    this.borderWidth = borderWidth
  }

  applyContent(): WrappedBuilder<[ButtonConfiguration]> {
    return wrapBuilder(disabledActionContent)
  }
}

@Builder
function disabledActionContent(configuration: ButtonConfiguration) {
  Row({ space: ThemeConstants.SPACE_SM }) {
    if ((configuration.contentModifier as KomaDisabledActionContent).icon !== undefined) {
      SymbolGlyph((configuration.contentModifier as KomaDisabledActionContent).icon)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([(configuration.contentModifier as KomaDisabledActionContent).foreground])
    }
    Text((configuration.contentModifier as KomaDisabledActionContent).label)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontWeight(FontWeight.Medium)
      .fontColor((configuration.contentModifier as KomaDisabledActionContent).foreground)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
  .width((configuration.contentModifier as KomaDisabledActionContent).expand ? '100%' : undefined)
  .height((configuration.contentModifier as KomaDisabledActionContent).controlHeight)
  .justifyContent(FlexAlign.Center)
  .alignItems(VerticalAlign.Center)
  .padding({
    left: (configuration.contentModifier as KomaDisabledActionContent).horizontalPadding,
    right: (configuration.contentModifier as KomaDisabledActionContent).horizontalPadding,
  })
  .backgroundColor((configuration.contentModifier as KomaDisabledActionContent).background)
  .border({
    width: (configuration.contentModifier as KomaDisabledActionContent).borderWidth,
    color: (configuration.contentModifier as KomaDisabledActionContent).borderColor,
  })
  .borderRadius((configuration.contentModifier as KomaDisabledActionContent).controlHeight / 2)
}

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
      return $r('sys.color.font_secondary')
    }
    if (this.contentColor !== undefined) {
      return this.contentColor
    }
    if (this.kind === 'primary' && this.accentColor === undefined && this.fillColor === undefined) {
      return $r('app.color.koma_action_on_accent')
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
    if (!this.isEnabled) {
      return this.kind === 'ghost' ? Color.Transparent : $r('sys.color.ohos_id_color_button_normal')
    }
    if (this.fillColor !== undefined) {
      return this.fillColor
    }
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
    if (this.strokeColor !== undefined) {
      return this.strokeColor
    }
    return Color.Transparent
  }

  private buttonBorderWidth(): number {
    return this.strokeColor === undefined ? 0 : 1
  }

  private buttonCornerRadius(): number {
    return this.controlHeight / 2
  }

  private buttonHorizontalPadding(): number {
    return this.compact ? ThemeConstants.SPACE_MD : ThemeConstants.SPACE_LG
  }

  private disabledContent(): KomaDisabledActionContent | undefined {
    if (this.isEnabled && !this.busy) {
      return undefined
    }
    return new KomaDisabledActionContent(this.label, this.icon, this.controlHeight,
      this.buttonHorizontalPadding(), this.fullWidth || this.fill,
      this.buttonForegroundColor(), this.buttonBackgroundColor(),
      this.buttonBorderColor(), this.buttonBorderWidth())
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
        if (this.isEnabled && !this.busy) {
          this.ButtonContent()
        }
      }
        .width('100%')
        .height(this.controlHeight)
        .layoutWeight(this.fill ? 1 : 0)
        .backgroundColor(this.isEnabled && !this.busy ? this.buttonBackgroundColor() : undefined)
        .border({ width: this.buttonBorderWidth(), color: this.buttonBorderColor() })
        .borderRadius(this.buttonCornerRadius())
        .opacity(1)
        .enabled(this.isEnabled && !this.busy)
        .contentModifier(this.disabledContent())
        .onClick(() => {
          this.action()
        })
    } else {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        if (this.isEnabled && !this.busy) {
          this.ButtonContent()
        }
      }
        .height(this.controlHeight)
        .layoutWeight(this.fill ? 1 : 0)
        .backgroundColor(this.isEnabled && !this.busy ? this.buttonBackgroundColor() : undefined)
        .border({ width: this.buttonBorderWidth(), color: this.buttonBorderColor() })
        .borderRadius(this.buttonCornerRadius())
        .opacity(1)
        .enabled(this.isEnabled && !this.busy)
        .contentModifier(this.disabledContent())
        .onClick(() => {
          this.action()
        })
    }
  }
}

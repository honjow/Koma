import {
  HdsListItemCard,
  PrefixCustomBuilder,
  PrefixImage,
  SuffixCustomBuilder,
  SuffixSwitch,
  SuffixText,
  SuffixTextAndArrow,
} from '@kit.UIDesignKit'
import { ImageModifier, TextModifier } from '@kit.ArkUI'
import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct ConciseListRow {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr = ''
  @Param subtitleMaxLines: number = 2
  @Param trailingText: ResourceStr = ''
  @Param leadingImageUrl: string = ''
  @Param leadingImageSize: number = 0
  @Param leadingImageRadius: number = 0
  @Param leadingIcon: Resource | undefined = undefined
  @Param leadingIconBackgroundColor: ResourceColor | undefined = undefined
  // Source rows use one host-owned identity slot. It is rendered inside this
  // component because HDS invokes PrefixCustomBuilder through NAPI; callers
  // must not construct another component or global builder across that edge.
  @Param hasSourceIdentityPrefix: boolean = false
  @Param sourceIdentityIconUri: string = ''
  @Param sourceIdentityFallbackIcon: Resource = $r('sys.symbol.compass')
  @Param sourceIdentityFallbackColor: ResourceColor = ThemeConstants.SOURCE_WASM_COLOR
  @Param count: number = -1
  @Param destructive: boolean = false
  @Param showChevron: boolean = true
  @Param trailingDropdown: boolean = false
  @Param dropdownMenuEnabled: boolean = false
  @Local private dropdownMenuShown: boolean = false
  @Param hasSwitch: boolean = false
  @Param hasCounter: boolean = false
  @Param counterValue: string = ''
  @Param counterDecreaseEnabled: boolean = true
  @Param counterIncreaseEnabled: boolean = true
  @Param checked: boolean = false
  @Param isEnabled: boolean = true
  @Param primaryColor: ResourceColor | undefined = undefined
  @Param secondaryColor: ResourceColor | undefined = undefined
  @Param suffixPaddingRight: Length = ThemeConstants.SPACE_MD
  // Custom prefixes can opt into the same text alignment as HDS leading
  // icons without changing older custom-prefix consumers (such as covers).
  @Param prefixActsAsLeading: boolean = false
  @Param prefixPaddingLeft: Length = ThemeConstants.SPACE_SM
  @Param prefixPaddingRight: Length = ThemeConstants.SPACE_SM
  // Zero means “take the enclosing GroupedListSection's computed surface”.
  // Standalone rows have no provider and retain LIST_ROW_RADIUS instead.
  @Param surfaceRadius: number = 0
  @Consumer('koma.groupedList.surfaceRadius') private groupedSurfaceRadius: number = ThemeConstants.LIST_ROW_RADIUS
  @Event action?: () => void
  @BuilderParam suffixBuilderParam?: () => void
  @BuilderParam prefixBuilderParam?: () => void
  @BuilderParam dropdownMenuBuilder: (select: (action: () => void) => void) => void =
    this.EmptyDropdownMenu
  @Event switchAction?: (value: boolean) => void
  @Event counterDecreaseAction?: () => void
  @Event counterIncreaseAction?: () => void

  private hasLeading(): boolean {
    return this.leadingImageUrl.length > 0 || this.leadingIcon !== undefined || this.hasSourceIdentityPrefix ||
      this.prefixActsAsLeading
  }

  private primaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(this.hasLeading() ? undefined : ThemeConstants.LIST_ROW_TEXT_INDENT)
      .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Regular)
      .fontColor(this.primaryColor ?? (this.destructive ? Color.Red : $r('sys.color.font_primary')))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private secondaryTextModifier(): TextModifier {
    return new TextModifier()
      .textIndent(this.hasLeading() ? undefined : ThemeConstants.LIST_ROW_TEXT_INDENT)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
      .maxLines(this.subtitleMaxLines)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private trailingTextModifier(): TextModifier {
    return new TextModifier()
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  private normalizeImageUrl(path: string): string {
    if (path.length === 0) {
      return ''
    }
    if (path.startsWith('//')) {
      return `https:${path}`
    }
    return path
  }

  private leadingImageModifier(): ImageModifier {
    const modifier = new ImageModifier().alt($r('sys.media.ohos_app_icon'))
    if (this.leadingImageSize > 0) {
      modifier.width(this.leadingImageSize).height(this.leadingImageSize)
    }
    if (this.leadingImageRadius > 0) {
      modifier.borderRadius(this.leadingImageRadius)
    }
    return modifier
  }

  private resolvedSurfaceRadius(): number {
    return this.surfaceRadius > 0 ? this.surfaceRadius : this.groupedSurfaceRadius
  }

  @Builder
  private WrappedSuffixBuilder() {
    if (this.dropdownMenuEnabled) {
      Row() {
        if (this.suffixBuilderParam) {
          this.suffixBuilderParam()
        }
      }
      .padding({ left: ThemeConstants.SPACE_SM, right: this.suffixPaddingRight })
      .bindMenu(this.dropdownMenuShown, this.BoundDropdownMenu, {
        placement: Placement.BottomRight,
        onDisappear: () => {
          this.dropdownMenuShown = false
        },
      })
    } else {
      Row() {
        if (this.suffixBuilderParam) {
          this.suffixBuilderParam()
        }
      }
      .padding({ left: ThemeConstants.SPACE_SM, right: this.suffixPaddingRight })
    }
  }

  @Builder
  private WrappedPrefixBuilder() {
    Row() {
      if (this.hasSourceIdentityPrefix) {
        this.SourceIdentityPrefix()
      } else if (this.prefixBuilderParam) {
        this.prefixBuilderParam()
      }
    }
    .padding({ left: this.prefixPaddingLeft, right: this.prefixPaddingRight })
  }

  private suffixItem(): SuffixTextAndArrow | SuffixText | SuffixCustomBuilder | SuffixSwitch | undefined {
    if (this.suffixBuilderParam) {
      return new SuffixCustomBuilder(() => {
        this.WrappedSuffixBuilder()
      })
    }

    if (this.hasSwitch) {
      return new SuffixSwitch({
        isCheck: this.checked,
        selectColor: ThemeConstants.BRAND_PRIMARY,
        enable: this.isEnabled,
        onChange: (value: boolean) => {
          if (this.isEnabled && this.switchAction) {
            this.switchAction(value)
          }
        },
      })
    }
    if (this.hasCounter) {
      return new SuffixCustomBuilder(() => {
        this.CounterSuffix()
      })
    }
    if (this.count >= 0) {
      return new SuffixTextAndArrow({ text: `${this.count}` }, { color: Color.Gray })
    }
    if (this.trailingText) {
      if (this.trailingDropdown) {
        return new SuffixCustomBuilder(() => {
          this.DropdownSuffix()
        })
      }
      if (this.showChevron) {
        return new SuffixTextAndArrow({
          text: this.trailingText,
          modifier: this.trailingTextModifier(),
        }, { color: Color.Gray })
      }
      return new SuffixText({
        text: this.trailingText,
        modifier: this.trailingTextModifier(),
      })
    }
    if (this.showChevron) {
      return new SuffixTextAndArrow({ text: '' }, { color: Color.Gray })
    }
    return undefined
  }

  @Builder
  private CounterSuffix() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      this.CounterButton('-', this.counterDecreaseEnabled, () => {
        if (this.counterDecreaseAction) {
          this.counterDecreaseAction()
        }
      })
      Text(this.counterValue)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .width(44)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      this.CounterButton('+', this.counterIncreaseEnabled, () => {
        if (this.counterIncreaseAction) {
          this.counterIncreaseAction()
        }
      })
    }
    .alignItems(VerticalAlign.Center)
    .opacity(this.isEnabled ? 1.0 : 0.45)
    .padding({ right: ThemeConstants.SPACE_MD })
  }

  @Builder
  private CounterButton(label: string, enabled: boolean, action: () => void) {
    Button() {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(enabled ? $r('sys.color.font_primary') : $r('sys.color.font_tertiary'))
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .backgroundColor($r('sys.color.ohos_id_color_button_normal'))
    .borderRadius(ThemeConstants.RADIUS_ROUND)
    .width(32)
    .height(30)
    .enabled(enabled && this.isEnabled)
    .opacity(enabled ? 1.0 : 0.45)
    .onClick(action)
  }

  @Builder
  private EmptyDropdownMenu(_select: (action: () => void) => void) {}

  private selectDropdownItem(action: () => void): void {
    // Finish the MenuItem dispatch before removing the overlay so the same
    // pointer event cannot fall through to the reader-settings row below it.
    setTimeout((): void => {
      this.dropdownMenuShown = false
      action()
    }, 0)
  }

  @Builder
  private BoundDropdownMenu() {
    this.dropdownMenuBuilder((action: () => void) => {
      this.selectDropdownItem(action)
    })
  }

  @Builder
  private DropdownSuffixContent() {
    Text(this.trailingText)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor(this.secondaryColor ?? $r('sys.color.font_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    SymbolGlyph($r('sys.symbol.arrowtriangle_down_fill'))
      .fontSize(ThemeConstants.FONT_SIZE_TITLE)
      .fontColor([$r('sys.color.font_tertiary')])
      .padding({ left: 4, right: 12 })
  }

  @Builder
  private DropdownSuffix() {
    if (this.dropdownMenuEnabled) {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.DropdownSuffixContent()
      }
      .alignItems(VerticalAlign.Center)
      .bindMenu(this.dropdownMenuShown, this.BoundDropdownMenu, {
        placement: Placement.BottomRight,
        onDisappear: () => {
          this.dropdownMenuShown = false
        },
      })
    } else {
      Row({ space: ThemeConstants.SPACE_XS }) {
        this.DropdownSuffixContent()
      }
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private IconPrefix() {
    Row() {
      if (this.leadingIcon !== undefined) {
        if (this.leadingIconBackgroundColor !== undefined) {
          Stack() {
            SymbolGlyph(this.leadingIcon)
              .fontSize(18)
              .fontColor([Color.White])
          }
          .width(30)
          .height(30)
          .borderRadius(7)
          .backgroundColor(this.leadingIconBackgroundColor)
        } else {
          SymbolGlyph(this.leadingIcon)
            .fontSize(22)
            .fontColor([
              this.destructive ? Color.Red : (this.secondaryColor ?? $r('sys.color.font_secondary')),
            ])
        }
      }
    }
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_SM })
  }

  @Builder
  private SourceIdentityPrefix() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.sourceIdentityIconUri.trim().length > 0) {
        Image(this.sourceIdentityIconUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.Medium)
      } else {
        Stack() {
          SymbolGlyph(this.sourceIdentityFallbackIcon)
            .fontSize(18)
            .fontColor([Color.White])
        }
        .width('100%')
        .height('100%')
        .borderRadius(ThemeConstants.SOURCE_LIST_ICON_RADIUS)
        .backgroundColor(this.sourceIdentityFallbackColor)
      }
    }
    .width(ThemeConstants.SOURCE_LIST_ICON_SIZE)
    .height(ThemeConstants.SOURCE_LIST_ICON_SIZE)
    .borderRadius(ThemeConstants.SOURCE_LIST_ICON_RADIUS)
    .clip(true)
  }

  private prefixItem(): PrefixImage | PrefixCustomBuilder | undefined {
    if (this.hasSourceIdentityPrefix || this.prefixBuilderParam) {
      return new PrefixCustomBuilder(() => {
        this.WrappedPrefixBuilder()
      })
    }
    if (this.leadingIcon !== undefined) {
      return new PrefixCustomBuilder(() => {
        this.IconPrefix()
      })
    }

    const imageUrl: string = this.normalizeImageUrl(this.leadingImageUrl)
    if (imageUrl.length > 0) {
      return new PrefixImage({
        image: imageUrl,
        modifier: this.leadingImageModifier(),
      })
    }
    return undefined
  }

  @Builder
  private RowContent() {
    HdsListItemCard({
      textItem: {
        primaryText: {
          text: this.title,
          modifier: this.primaryTextModifier(),
        },
        secondaryText: this.subtitle ? {
          text: this.subtitle,
          modifier: this.secondaryTextModifier(),
        } : undefined,
      },
      cardPrefixMargin: 0,
      cardSuffixMargin: 0,
      prefixItem: this.prefixItem(),
      suffixItem: this.suffixItem(),
      cardBackgroundColor: Color.Transparent,
      cardBorderRadius: this.resolvedSurfaceRadius(),
      hoverBorderRadius: this.resolvedSurfaceRadius(),
      enable: this.hasSwitch ? true : this.isEnabled,
      onClick: () => {
        if (this.isEnabled) {
          if (this.dropdownMenuEnabled) {
            this.dropdownMenuShown = true
          }
          if (this.action) {
            this.action()
          }
        }
      },
    })
  }

  build() {
    Column() {
      this.RowContent()
    }
    .width('100%')
    .opacity(this.isEnabled ? 1.0 : 0.4)
  }
}

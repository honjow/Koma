import { ThemeConstants } from '../../theme/ThemeConstants'

@ComponentV2
export struct SectionHeader {
  @Param title: ResourceStr = ''
  @Param actionLabel: ResourceStr | undefined = undefined
  @Event action: () => void = () => {}

  @Builder
  private TitleContent(weight: number) {
    Text(this.title)
      .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .padding({
        left: ThemeConstants.SPACE_SM,
        right: ThemeConstants.SPACE_SM,
        top: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_XS,
      })
      .width('100%')
      .layoutWeight(weight)
  }

  build() {
    if (this.actionLabel !== undefined) {
      Row() {
        this.TitleContent(1)
        Button(this.actionLabel, {
          controlSize: ControlSize.SMALL,
          buttonStyle: ButtonStyleMode.TEXTUAL,
        })
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
          .onClick(() => { this.action() })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    } else {
      this.TitleContent(0)
    }
  }
}

// A titled section owns its header, optional native action and card as one unit.
// Parent List/Column spacing separates whole sections, never a header from its card.
// Untitled callers retain the original card-only surface.
@ComponentV2
export struct GroupedListSection {
  @BuilderParam content: () => void
  @Param title: ResourceStr | undefined = undefined
  @Param subtitle: ResourceStr | undefined = undefined
  @Param actionLabel: ResourceStr | undefined = undefined
  @Param headerSpacing: number = ThemeConstants.SPACE_XS
  @Event action: () => void = () => {}
  @Param inset: number = ThemeConstants.LIST_SECTION_INSET
  @Param radius: number = ThemeConstants.RADIUS_CARD
  @Provider('koma.groupedList.surfaceRadius') private surfaceRadius: number =
    ThemeConstants.GROUPED_LIST_INNER_RADIUS

  private resolvedSurfaceRadius(): number {
    return Math.max(0, this.radius - this.inset)
  }

  private syncSurfaceRadius(): void {
    this.surfaceRadius = this.resolvedSurfaceRadius()
  }

  aboutToAppear(): void {
    this.syncSurfaceRadius()
  }

  @Monitor('radius')
  private onRadiusChanged(): void {
    this.syncSurfaceRadius()
  }

  @Monitor('inset')
  private onInsetChanged(): void {
    this.syncSurfaceRadius()
  }

  @Builder
  private Surface() {
    Column() {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .borderRadius(this.radius)
    .clip(true)
    .padding(this.inset)
    .backgroundColor(ThemeConstants.CARD)
  }

  build() {
    if (this.title !== undefined) {
      Column({ space: this.headerSpacing }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          SectionHeader({ title: this.title, actionLabel: this.actionLabel, action: this.action })
          if (this.subtitle !== undefined) {
            Text(this.subtitle)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XS })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        this.Surface()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      this.Surface()
    }
  }
}

@ComponentV2
export struct ListDivider {
  @Param leftMargin: Length = ThemeConstants.SPACE_LG
  @Param rightMargin: Length = 0

  build() {
    Divider()
      .strokeWidth(0.5)
      .color(ThemeConstants.DIVIDER)
      .margin({ left: this.leftMargin, right: this.rightMargin })
  }
}

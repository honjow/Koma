import { komaModalCardSurface } from '../../theme/KomaPopupOptions'
import { ThemeConstants } from '../../theme/ThemeConstants'
import { LIST_DISCLOSURE_MS } from './ListDisclosureContent'

@ComponentV2
export struct SectionHeader {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Param actionLabel: ResourceStr | undefined = undefined
  @Param expanded: boolean | undefined = undefined
  @Event action: () => void = () => {}
  @Event onToggle: (headerBottom?: number) => void = () => {}
  private headerBottom?: number

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

  @Builder
  private Title() {
    if (this.expanded !== undefined) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          this.TitleContent(1)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
            .margin({ right: ThemeConstants.SPACE_SM })
            .rotate({ angle: this.expanded ? 180 : 0 })
            .animation({ duration: LIST_DISCLOSURE_MS, curve: Curve.EaseInOut })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .constraintSize({ minHeight: ThemeConstants.TOUCH_TARGET_SM })
      .padding(0)
      .backgroundColor(Color.Transparent)
      .borderRadius(ThemeConstants.RADIUS_MD)
      .clip(true)
      .onClick((): void => {
        const toggle = this.onToggle
        const bottom = this.headerBottom
        // Let the native button event return before the list relayouts.
        setTimeout((): void => { toggle(bottom) }, 0)
      })
    } else if (this.actionLabel !== undefined) {
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

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      this.Title()
      if (this.subtitle !== undefined) {
        Text(this.subtitle)
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XS })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .onAreaChange((_previous: Area, area: Area): void => {
      if (this.expanded !== undefined) this.headerBottom = Number(area.globalPosition.y) + Number(area.height)
    })
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
  @Param surfaceColor?: ResourceColor = undefined
  // Builders may belong to the calling page instead of the sheet component.
  // Sheet-owned content can provide the context once; inline builders must opt in.
  @Param inModal: boolean = false
  @Consumer('koma.modal.groupedCards') private modalGroupedCards: boolean = false
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
    .backgroundColor(this.surfaceColor ?? (this.inModal || this.modalGroupedCards ?
      komaModalCardSurface() : ThemeConstants.CARD))
  }

  build() {
    if (this.title !== undefined) {
      Column({ space: this.headerSpacing }) {
        SectionHeader({ title: this.title, subtitle: this.subtitle, actionLabel: this.actionLabel, action: this.action })
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
export struct GroupedListRowSurface {
  @BuilderParam content: () => void
  @Param first: boolean = false
  @Param last: boolean = false
  @Param surfaceColor: ResourceColor = ThemeConstants.CARD

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding({ left: ThemeConstants.LIST_SECTION_INSET, right: ThemeConstants.LIST_SECTION_INSET,
      top: this.first ? ThemeConstants.LIST_SECTION_INSET : 0,
      bottom: this.last ? ThemeConstants.LIST_SECTION_INSET : 0 })
    .backgroundColor(this.surfaceColor)
    .borderRadius({ topLeft: this.first ? ThemeConstants.RADIUS_CARD : 0,
      topRight: this.first ? ThemeConstants.RADIUS_CARD : 0,
      bottomLeft: this.last ? ThemeConstants.RADIUS_CARD : 0,
      bottomRight: this.last ? ThemeConstants.RADIUS_CARD : 0 })
    .clip(true)
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

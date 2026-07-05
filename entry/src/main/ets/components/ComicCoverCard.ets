import { ThemeConstants } from '../theme/ThemeConstants'

export interface ComicCoverInfo {
  id: string
  title: string
  subtitle: string
  progressText: string
  coverColor: string
  accentColor: string
  pageCount?: number
  coverUri?: string
  categoryLabels?: string[]
}

@ComponentV2
export struct ComicCoverCard {
  @Param comic: ComicCoverInfo = {
    id: '',
    title: '',
    subtitle: '',
    progressText: '',
    coverColor: ThemeConstants.SOURCE_LOCAL_COLOR,
    accentColor: ThemeConstants.SOURCE_OPDS_COLOR
  }
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param progressText: string = ''
  @Param coverColor: string = ''
  @Param accentColor: string = ''
  @Param categoryLabels: string[] = []
  @Param selected: boolean = false

  private displayTitle(): string {
    return this.title.length > 0 ? this.title : this.comic.title
  }

  private displaySubtitle(): string {
    return this.subtitle.length > 0 ? this.subtitle : this.comic.subtitle
  }

  private displayProgressText(): string {
    return this.progressText.length > 0 ? this.progressText : this.comic.progressText
  }

  private displayCoverColor(): string {
    return this.coverColor.length > 0 ? this.coverColor : this.comic.coverColor
  }

  private displayAccentColor(): string {
    return this.accentColor.length > 0 ? this.accentColor : this.comic.accentColor
  }

  private displayCategoryLabels(): string[] {
    return this.categoryLabels.length > 0 ? this.categoryLabels : (this.comic.categoryLabels ?? [])
  }

  private displayCoverUri(): string {
    return this.comic.coverUri ?? ''
  }

  private titleInitial(): string {
    const title = this.displayTitle().trim()
    if (title.length === 0) {
      return 'K'
    }
    return title.substring(0, 1).toLocaleUpperCase()
  }

  @Builder
  private CoverPlaceholder() {
    Column() {
      Text(this.titleInitial())
        .fontSize(42)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .opacity(0.94)
    }
    .width('100%')
    .height('100%')
    .padding(ThemeConstants.SPACE_MD)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.displayCoverColor())
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        this.CoverPlaceholder()

        if (this.displayCoverUri().length > 0) {
          Image(this.displayCoverUri())
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .interpolation(ImageInterpolation.Medium)
        }

        if (this.displayProgressText().length > 0) {
          Row() {
            Text(this.displayProgressText())
              .fontSize(ThemeConstants.FONT_SIZE_TAG)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_ON_BRAND)
              .maxLines(1)
          }
          .height(26)
          .padding({ left: 10, right: 10 })
          .margin({ left: 10, bottom: 10 })
          .borderRadius(13)
          .backgroundColor(this.displayAccentColor())
        }

        if (this.selected) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(ThemeConstants.SELECTED_OVERLAY)

          Stack({ alignContent: Alignment.Center }) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(ThemeConstants.FONT_SIZE_HEADING)
              .fontColor([ThemeConstants.TEXT_ON_BRAND])
          }
          .width(ThemeConstants.FILTER_CHIP_HEIGHT)
          .height(ThemeConstants.FILTER_CHIP_HEIGHT)
          .margin({ top: 10, right: 10 })
          .borderRadius(ThemeConstants.RADIUS_MD)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .border({ width: 2, color: ThemeConstants.TEXT_ON_BRAND })
          .align(Alignment.TopEnd)
        }
      }
      .width('100%')
      .aspectRatio(0.68)
      .borderRadius(ThemeConstants.RADIUS_MD)
      .clip(true)
      .shadow({ radius: 14, color: ThemeConstants.SHADOW_CARD, offsetY: 7 })

      Text(this.displayTitle())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .maxLines(2)
        .lineHeight(18)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.displaySubtitle())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.displayCategoryLabels().length > 0) {
        Row({ space: 6 }) {
          ForEach(this.displayCategoryLabels(), (categoryLabel: string) => {
            Text(categoryLabel)
              .height(20)
              .padding({ left: 8, right: 8 })
              .borderRadius(ThemeConstants.RADIUS_CHIP)
              .fontSize(ThemeConstants.FONT_SIZE_TAG)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
              .backgroundColor(ThemeConstants.SOFT_TINT)
              .maxLines(1)
          }, (categoryLabel: string) => categoryLabel)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

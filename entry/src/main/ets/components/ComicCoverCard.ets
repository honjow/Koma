import { CachedCoverImage, cachedCoverFailureKey } from './CachedCoverImage'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ComicSourceKind } from '../model/ComicModels'

export interface ComicCoverInfo {
  id: string
  title: string
  subtitle: string
  progressText: string
  coverColor: string
  accentColor: string
  pageCount?: number
  coverUri?: string
  sourceRuntimeId?: string
  sourceImageId?: string
  sourceKind?: ComicSourceKind
  remoteServerId?: string
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
  @Local private failedCoverUri: string = ''

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

  private displaySourceRuntimeId(): string {
    return this.comic.sourceRuntimeId ?? ''
  }

  private displaySourceImageId(): string {
    return this.comic.sourceImageId ?? this.comic.id
  }

  private shouldDisplayCoverImage(): boolean {
    const coverUri = this.displayCoverUri()
    return coverUri.length > 0 && this.failedCoverUri !== this.coverFailureKey()
  }

  private coverFailureKey(): string {
    return cachedCoverFailureKey(
      this.displayCoverUri(),
      this.displaySourceRuntimeId(),
      this.displaySourceImageId(),
      this.comic.sourceKind,
      this.comic.remoteServerId,
    )
  }

  @Builder
  private CoverPlaceholder() {
    Column() {
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(42)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
    }
    .width('100%')
    .height('100%')
    .padding(ThemeConstants.SPACE_MD)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    // An absent image is content state, not a themed illustration.  Keep the
    // fallback neutral so a source/local colour never masquerades as a cover.
    .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        this.CoverPlaceholder()

        if (this.shouldDisplayCoverImage()) {
          CachedCoverImage({
            uri: this.displayCoverUri(),
            objectFit: ImageFit.Cover,
            sourceRuntimeId: this.displaySourceRuntimeId(),
            sourceImageId: this.displaySourceImageId(),
            sourceKind: this.comic.sourceKind,
            remoteServerId: this.comic.remoteServerId ?? '',
            onError: () => {
              this.failedCoverUri = this.coverFailureKey()
            },
          })
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
      .borderRadius(ThemeConstants.RADIUS_COVER)
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

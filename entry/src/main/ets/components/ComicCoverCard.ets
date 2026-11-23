import { libraryUnreadBadgeBackdrop, libraryUnreadBadgeOptions } from './LibraryUnreadBadge'
import { CachedCoverImage, cachedCoverFailureKey } from './CachedCoverImage'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ComicCoverInfo } from '../model/ComicModels'
export { ComicCoverInfo } from '../model/ComicModels'

export const COMIC_COVER_ASPECT_RATIO: number = 0.68

@ComponentV2
export struct ComicCoverCard {
  @Param comic: ComicCoverInfo = {
    id: '',
    title: '',
    subtitle: '',
    coverColor: ThemeConstants.SOURCE_LOCAL_COLOR,
    accentColor: ThemeConstants.SOURCE_OPDS_COLOR
  }
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param coverColor: string = ''
  @Param accentColor: string = ''
  @Param categoryLabels: string[] = []
  @Param selected: boolean = false
  @Param unreadBadgeCount: number | undefined = undefined
  @Param reuseAcrossWorks: boolean = false
  @Param coverDecodeMaxEdge: number = 320
  @Local private failedCoverUri: string = ''
  @Local private categoryMarqueeStarted: boolean = false
  private categoryMarqueeStartTimer: number = -1

  aboutToDisappear(): void {
    this.cancelCategoryMarqueeStart()
  }

  private cancelCategoryMarqueeStart(): void {
    if (this.categoryMarqueeStartTimer !== -1) {
      clearTimeout(this.categoryMarqueeStartTimer)
      this.categoryMarqueeStartTimer = -1
    }
    this.categoryMarqueeStarted = false
  }

  private scheduleCategoryMarqueeStart(): void {
    this.cancelCategoryMarqueeStart()
    this.categoryMarqueeStartTimer = setTimeout((): void => {
      this.categoryMarqueeStartTimer = -1
      this.categoryMarqueeStarted = true
    }, 1000)
  }

  private displayTitle(): string {
    return this.title.length > 0 ? this.title : this.comic.title
  }

  private displaySubtitle(): string {
    return this.subtitle.length > 0 ? this.subtitle : this.comic.subtitle
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
      this.comic.sourceMangaUrl,
    )
  }

  @Builder
  private CoverImage() {
    CachedCoverImage({
      uri: this.displayCoverUri(),
      coverOwnerId: this.reuseAcrossWorks ? this.comic.id : '',
      objectFit: ImageFit.Cover,
      decodeMaxEdge: this.coverDecodeMaxEdge,
      extractMainColor: true,
      sourceRuntimeId: this.displaySourceRuntimeId(),
      sourceImageId: this.displaySourceImageId(),
      sourceKind: this.comic.sourceKind,
      remoteServerId: this.comic.remoteServerId ?? '',
      sourceMangaUrl: this.comic.sourceMangaUrl ?? '',
      onError: () => { this.failedCoverUri = this.coverFailureKey() },
    })
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Badge(libraryUnreadBadgeOptions(this.unreadBadgeCount ?? this.comic.unreadChapterCount,
        this.displayAccentColor(), this.coverFailureKey())) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.book'))
            .fontSize(42)
            .fontColor([ThemeConstants.TEXT_TERTIARY])

          if (this.shouldDisplayCoverImage()) {
            this.CoverImage()
          }

          if (this.selected) {
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor(ThemeConstants.SELECTED_OVERLAY)
          }

          libraryUnreadBadgeBackdrop(this.unreadBadgeCount ?? this.comic.unreadChapterCount, this.getUIContext())
        }
        .width('100%')
        .aspectRatio(COMIC_COVER_ASPECT_RATIO)
        // Keep the placeholder in the same surface as the image fade.
        .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
        .borderRadius(ThemeConstants.RADIUS_COVER)
        .clip(true)
        .shadow({ radius: 14, color: ThemeConstants.SHADOW_CARD, offsetY: 7 })
      }
      .width('100%')

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
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .marqueeOptions({ start: this.categoryMarqueeStarted, step: 0.5, loop: -1, delay: 1000, fromStart: true, fadeout: false })
              .onAppear(() => this.scheduleCategoryMarqueeStart())
          }, (categoryLabel: string) => categoryLabel)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

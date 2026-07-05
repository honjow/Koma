import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { MangaDetail, MangaStatus } from '../model/MangaDetailModels'
import { ThemeConstants } from '../theme/ThemeConstants'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct MangaDetailHeader {
  @Param manga: MangaDetail = {
    id: '',
    title: '',
    chapterCount: 0,
    isInLibrary: false,
  }
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private failedCoverUrl: string = ''

  private hasCover(): boolean {
    const coverUrl = this.manga.coverUrl ?? ''
    return coverUrl.length > 0 && this.failedCoverUrl !== coverUrl
  }

  private displayTitle(): string {
    return this.manga.title.length > 0 ? this.manga.title : s('manga_detail_title_fallback')
  }

  private titleInitial(): string {
    const title = this.displayTitle()
    return title.length > 0 ? title.substring(0, 1) : 'K'
  }

  private creatorText(): string {
    const author = this.manga.author === undefined ? '' : this.manga.author
    const artist = this.manga.artist === undefined ? '' : this.manga.artist
    if (author.length > 0 && artist.length > 0 && author !== artist) {
      return `${author} / ${artist}`
    }
    if (author.length > 0) {
      return author
    }
    if (artist.length > 0) {
      return artist
    }
    return s('manga_detail_creator_unknown')
  }

  private statusLabel(): string {
    const status = this.manga.status === undefined ? MangaStatus.UNKNOWN : this.manga.status
    if (status === MangaStatus.ONGOING) {
      return s('manga_status_ongoing')
    }
    if (status === MangaStatus.COMPLETED) {
      return s('manga_status_completed')
    }
    if (status === MangaStatus.HIATUS) {
      return s('manga_status_hiatus')
    }
    if (status === MangaStatus.CANCELLED) {
      return s('manga_status_cancelled')
    }
    return s('manga_status_unknown')
  }

  private statusBackgroundColor(): ResourceColor {
    const status = this.manga.status === undefined ? MangaStatus.UNKNOWN : this.manga.status
    if (status === MangaStatus.ONGOING) {
      return ThemeConstants.STATUS_SUCCESS
    }
    if (status === MangaStatus.COMPLETED) {
      return ThemeConstants.STATUS_INFO
    }
    if (status === MangaStatus.HIATUS) {
      return ThemeConstants.STATUS_MUTED
    }
    if (status === MangaStatus.CANCELLED) {
      return ThemeConstants.STATUS_DANGER
    }
    return ThemeConstants.TEXT_SECONDARY
  }

  @Builder
  private Cover() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.hasCover()) {
        Image(this.manga.coverUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .interpolation(ImageInterpolation.Medium)
          .onError(() => {
            this.failedCoverUrl = this.manga.coverUrl ?? ''
          })
      } else {
        Column() {
          Blank()
          Text(this.titleInitial())
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
          Blank()
        }
        .width('100%')
        .height('100%')
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
      }
    }
    .width(104)
    .height(148)
    .borderRadius(ThemeConstants.RADIUS_THUMB)
    .clip(true)
    .shadow({ radius: 10, color: ThemeConstants.SHADOW_CARD, offsetY: 4 })
  }

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      this.Cover()

      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(this.displayTitle())
          .fontSize(ThemeConstants.FONT_SIZE_H2)
          .lineHeight(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.creatorText())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.statusLabel())
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
            .borderRadius(ThemeConstants.RADIUS_ROUND)
            .backgroundColor(this.statusBackgroundColor())

          if (this.manga.sourceName !== undefined && this.manga.sourceName.length > 0) {
            Text(this.manga.sourceName)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
              .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
              .borderRadius(ThemeConstants.RADIUS_ROUND)
              .backgroundColor(ThemeConstants.SOFT_TINT)
          }
        }
        .width('100%')

        Text(s('manga_detail_chapter_count').replace('%s', `${this.manga.chapterCount}`))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

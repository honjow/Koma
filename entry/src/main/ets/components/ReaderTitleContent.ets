import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

function s(key: string): string { return AppStrings.get(key) }

/** The original Koma reader title, shared by legacy and shared-reader entry.
 * Keep the confirmed title/chapter/page typography and spacing together.
 */
@ComponentV2
export struct ReaderTitleContent {
  @Param title: string = ''
  @Param chapterTitle: string = ''
  @Param pageIndex: number = 0
  @Param pageTotal: number = 0

  private pageText(): string {
    const total = Math.max(this.pageTotal, 0)
    return total <= 0 ? '0 / 0' : `${Math.min(Math.max(this.pageIndex + 1, 1), total)} / ${total}`
  }

  build() {
      Column({ space: 2 }) {
        Text(this.title.length > 0 ? this.title : s('reader_title_default'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineBreakStrategy(LineBreakStrategy.BALANCED)
          .textAlign(TextAlign.Start)
          .width('100%')

        Row({ space: ThemeConstants.SPACE_XS }) {
          if (this.pageTotal > 0) {
            Text(this.pageText())
              .fontSize(11)
              .fontColor('#CCFFFFFF')
              .maxLines(1)
              .flexShrink(0)
            Text('·')
              .fontSize(11)
              .fontColor('#CCFFFFFF')
              .flexShrink(0)
          }
          Text(this.chapterTitle)
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_SM })
      .alignItems(HorizontalAlign.Start)
  }
}

import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct SearchPage {
  @State private queryText: string = ''

  @Builder
  private SearchInput() {
    Row({ space: 8 }) {
      TextInput({ placeholder: '搜索标题、作者、标签...', text: this.queryText })
        .layoutWeight(1)
        .height(42)
        .fontSize(15)
        .fontColor($r('app.color.koma_text_primary'))
        .placeholderColor($r('app.color.koma_text_secondary'))
        .backgroundColor($r('app.color.koma_card'))
        .borderRadius(8)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.queryText = value
        })
    }
    .width('100%')
  }

  @Builder
  private EmptyResults() {
    Column({ space: 10 }) {
      Text(this.queryText.length === 0 ? '输入关键词开始搜索' : '没有匹配结果')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('跨源搜索将在 F4 中实现。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(24)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 18,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        ListItem() {
          this.SearchInput()
        }
        ListItem() {
          this.EmptyResults()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

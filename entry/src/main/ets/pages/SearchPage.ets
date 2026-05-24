import { TabLabel } from '../common/Constants'

@Component
export struct SearchPage {
  @State private queryText: string = ''

  @Builder
  private Header() {
    Column({ space: 4 }) {
      Text(TabLabel.SEARCH)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))
      Text('在已安装的源中搜索')
        .fontSize(14)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

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
    Navigation() {
      Scroll() {
        Column({ space: 18 }) {
          this.Header()
          this.SearchInput()
          this.EmptyResults()
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 28 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .mode(NavigationMode.Stack)
    .title(TabLabel.SEARCH)
    .hideBackButton(true)
    .backgroundColor($r('app.color.koma_background'))
  }
}

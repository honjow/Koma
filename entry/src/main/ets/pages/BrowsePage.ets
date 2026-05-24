import { TabLabel } from '../common/Constants'

interface BrowsePlaceholderRow {
  key: string
  title: string
  subtitle: string
}

const PLACEHOLDER_ROWS: BrowsePlaceholderRow[] = [
  {
    key: 'placeholder-installed',
    title: '已安装的源将显示在这里',
    subtitle: '通过设置 → 数据 → 源管理 添加源包后会显示在此列表。',
  },
]

@Component
export struct BrowsePage {
  @Builder
  private Header() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(TabLabel.BROWSE)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.koma_text_primary'))
        Text('从源获取漫画')
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private PlaceholderRow(row: BrowsePlaceholderRow) {
    Column({ space: 6 }) {
      Text(row.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text(row.subtitle)
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Navigation() {
      Scroll() {
        Column({ space: 18 }) {
          this.Header()

          List({ space: 12 }) {
            ForEach(PLACEHOLDER_ROWS, (row: BrowsePlaceholderRow) => {
              ListItem() {
                this.PlaceholderRow(row)
              }
            }, (row: BrowsePlaceholderRow) => row.key)
          }
          .width('100%')
          .divider({ strokeWidth: 0 })
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
    .title(TabLabel.BROWSE)
    .hideBackButton(true)
    .backgroundColor($r('app.color.koma_background'))
  }
}

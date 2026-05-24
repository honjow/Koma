import { TabLabel } from '../common/Constants'

interface HistoryPlaceholderRow {
  key: string
  title: string
  subtitle: string
}

const PLACEHOLDER_ROWS: HistoryPlaceholderRow[] = [
  {
    key: 'placeholder-empty',
    title: '阅读历史将显示在这里',
    subtitle: '完成或继续阅读漫画后，最近浏览会出现在此时间线。',
  },
]

@Component
export struct HistoryPage {
  @Builder
  private Header() {
    Column({ space: 4 }) {
      Text(TabLabel.HISTORY)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))
      Text('最近阅读')
        .fontSize(14)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private PlaceholderRow(row: HistoryPlaceholderRow) {
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
            ForEach(PLACEHOLDER_ROWS, (row: HistoryPlaceholderRow) => {
              ListItem() {
                this.PlaceholderRow(row)
              }
            }, (row: HistoryPlaceholderRow) => row.key)
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
    .title(TabLabel.HISTORY)
    .hideBackButton(true)
    .backgroundColor($r('app.color.koma_background'))
  }
}

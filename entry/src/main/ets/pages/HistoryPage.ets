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

const TITLE_BAR_HEIGHT: number = 56
const FLOATING_TAB_BAR_PADDING: number = 96

@Component
export struct HistoryPage {
  @StorageProp('topAvoidHeight') topAvoidHeight: number = 0
  @StorageProp('bottomAvoidHeight') bottomAvoidHeight: number = 0

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
    List({ space: 12 }) {
      ForEach(PLACEHOLDER_ROWS, (row: HistoryPlaceholderRow) => {
        ListItem() {
          this.PlaceholderRow(row)
        }
      }, (row: HistoryPlaceholderRow) => row.key)
    }
    .width('100%')
    .height('100%')
    .padding({
      left: 20,
      right: 20,
      top: this.topAvoidHeight + TITLE_BAR_HEIGHT,
      bottom: this.bottomAvoidHeight + FLOATING_TAB_BAR_PADDING,
    })
    .scrollBar(BarState.Off)
    .divider({ strokeWidth: 0 })
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

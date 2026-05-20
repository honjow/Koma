import { LibraryPage } from './LibraryPage'

@Entry
@Component
struct Index {
  @State selectedTab: number = 0

  private tabLabel(index: number): string {
    if (index === 0) { return '书架' }
    if (index === 1) { return '导入' }
    if (index === 2) { return '历史' }
    return '设置'
  }

  @Builder
  private TabItem(index: number) {
    Column() {
      Text(this.tabLabel(index))
        .fontSize(12)
        .fontWeight(this.selectedTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedTab === index ? $r('app.color.koma_accent') : $r('app.color.koma_text_secondary'))
    }
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      Stack() {
        if (this.selectedTab === 0) {
          LibraryPage()
        } else {
          Column({ space: 12 }) {
            Text(this.tabLabel(this.selectedTab))
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
            Text('框架占位页，后续按漫画阅读器路线补齐。')
              .fontSize(15)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .width('100%')
          .padding(24)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .alignContent(Alignment.TopStart)

      Tabs({ index: this.selectedTab }) {
        TabContent() { }.tabBar(this.TabItem(0))
        TabContent() { }.tabBar(this.TabItem(1))
        TabContent() { }.tabBar(this.TabItem(2))
        TabContent() { }.tabBar(this.TabItem(3))
      }
      .height(72)
      .barPosition(BarPosition.End)
      .onChange((index: number) => { this.selectedTab = index })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.koma_background'))
    .padding({ top: 72 })
  }
}

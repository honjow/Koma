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

  @Builder
  private EmptyShelf() {
    Column({ space: 16 }) {
      Text('Koma')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))
      Text('私有漫画书架与本地阅读器')
        .fontSize(16)
        .fontColor($r('app.color.koma_text_secondary'))
      Column({ space: 10 }) {
        Text('首版目标')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
        Text('本地 CBZ/ZIP、图片文件夹、阅读进度、沉浸式阅读器。Komga / OPDS / WebDAV 和 WASM 自定义源作为后续能力验证。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .padding(20)
      .borderRadius(24)
      .backgroundColor($r('app.color.koma_card'))
      Button('导入本地漫画')
        .height(48)
        .borderRadius(24)
        .fontSize(16)
        .backgroundColor($r('app.color.koma_accent'))
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Stack() {
        if (this.selectedTab === 0) {
          this.EmptyShelf()
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
      .alignContent(Alignment.Center)

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

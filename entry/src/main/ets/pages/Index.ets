import { LibraryPage } from './LibraryPage'
import { ReaderPage } from './ReaderPage'

@Entry
@Component
struct Index {
  @State selectedTab: number = 0
  @State private readerOpen: boolean = false

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
    Stack() {
      Column() {
        Stack() {
          if (this.selectedTab === 0) {
            LibraryPage({
              onOpenReader: () => {
                this.readerOpen = true
              }
            })
          } else {
            Column({ space: 12 }) {
              Text(this.tabLabel(this.selectedTab))
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.koma_text_primary'))
              Text(this.selectedTab === 2 ? '阅读历史会显示最近打开的本地漫画。' : '框架占位页，后续按漫画阅读器路线补齐。')
                .fontSize(15)
                .fontColor($r('app.color.koma_text_secondary'))
              if (this.selectedTab === 2) {
                Button('打开阅读器原型')
                  .height(46)
                  .padding({ left: 22, right: 22 })
                  .borderRadius(23)
                  .fontSize(15)
                  .backgroundColor($r('app.color.koma_accent'))
                  .onClick(() => {
                    this.readerOpen = true
                  })
              }
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

      if (this.readerOpen) {
        ReaderPage({
          onClose: () => {
            this.readerOpen = false
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0A09')
  }
}

@Component
export struct MangaTagsSection {
  @Prop tags: string[] = []

  private hasTags(): boolean {
    return this.tags.length > 0
  }

  build() {
    Column({ space: 12 }) {
      Text('标签')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))

      if (this.hasTags()) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tags, (tag: string) => {
            Text(tag)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.koma_accent'))
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(16)
              .backgroundColor('#1A5CC8A8')
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {})
          }, (tag: string) => tag)
        }
        .width('100%')
      } else {
        Text('暂无标签')
          .width('100%')
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

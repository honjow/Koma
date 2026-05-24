@Component
export struct MangaDescriptionSection {
  @Prop description: string = ''
  @State private expanded: boolean = false

  private hasDescription(): boolean {
    return this.description.trim().length > 0
  }

  private toggleLabel(): string {
    return this.expanded ? '收起' : '展开'
  }

  build() {
    Column({ space: 10 }) {
      Text('简介')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))

      Text(this.hasDescription() ? this.description : '暂无简介')
        .width('100%')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(this.hasDescription() ? $r('app.color.koma_text_primary') : $r('app.color.koma_text_secondary'))
        .maxLines(this.expanded || !this.hasDescription() ? 20 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .animation({ duration: 180, curve: Curve.EaseInOut })

      if (this.hasDescription()) {
        Button(this.toggleLabel())
          .height(32)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .fontSize(13)
          .fontColor($r('app.color.koma_accent'))
          .backgroundColor('#00000000')
          .onClick(() => {
            this.expanded = !this.expanded
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

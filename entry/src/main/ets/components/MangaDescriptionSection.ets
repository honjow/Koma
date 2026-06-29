import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct MangaDescriptionSection {
  @Param description: string = ''
  @Local private expanded: boolean = false

  private hasDescription(): boolean {
    return this.description.trim().length > 0
  }

  private toggleLabel(): string {
    return this.expanded ? '收起' : '展开'
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text('简介')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      Text(this.hasDescription() ? this.description : '暂无简介')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
        .fontColor(this.hasDescription() ? ThemeConstants.TEXT_PRIMARY : ThemeConstants.TEXT_SECONDARY)
        .maxLines(this.expanded || !this.hasDescription() ? 20 : 3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .animation({ duration: 180, curve: Curve.EaseInOut })

      if (this.hasDescription()) {
        Button(this.toggleLabel())
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.expanded = !this.expanded
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

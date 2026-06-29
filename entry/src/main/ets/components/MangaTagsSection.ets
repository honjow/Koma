import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct MangaTagsSection {
  @Param tags: string[] = []

  private hasTags(): boolean {
    return this.tags.length > 0
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text('标签')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_H3)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      if (this.hasTags()) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.tags, (tag: string) => {
            Text(tag)
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
              .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: 7, bottom: 7 })
              .borderRadius(ThemeConstants.RADIUS_ROUND)
              .backgroundColor(ThemeConstants.SOFT_TINT)
              .margin({ right: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
              .onClick(() => {})
          }, (tag: string) => tag)
        }
        .width('100%')
      } else {
        Text('暂无标签')
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

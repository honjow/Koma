import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct MangaTagsSection {
  @Param tags: string[] = []
  @Local private languageState: LanguageState = connectLanguageState()
  @Event onTagClick: (tag: string) => void = (_tag: string) => {}

  private hasTags(): boolean {
    return this.tags.length > 0
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(s('common_tags'))
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
              .onClick(() => {
                this.onTagClick(tag)
              })
          }, (tag: string) => tag)
        }
        .width('100%')
      } else {
        Text(s('manga_detail_tags_empty'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

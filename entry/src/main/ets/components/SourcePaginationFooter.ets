import { ThemeConstants } from '../theme/ThemeConstants'

// Match NextE's quiet infinite-scroll footer without adding a load-more button.
@ComponentV2
export struct SourcePaginationFooter {
  @Param isLoading: boolean = false
  @Param hasMore: boolean = true
  @Param isError: boolean = false
  @Event onRetry: () => void = () => {}

  build() {
    Row() {
      if (this.isLoading) {
        LoadingProgress()
          .width(24)
          .height(24)
          .color(ThemeConstants.TEXT_SECONDARY)
        Text($r('app.string.common_loading'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .margin({ left: ThemeConstants.SPACE_SM })
      } else if (this.isError) {
        Text($r('app.string.common_load_failed_tap_retry'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      } else if (!this.hasMore) {
        Text($r('app.string.common_no_more'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(48)
    .onClick(() => {
      if (this.isError && !this.isLoading) {
        this.onRetry()
      }
    })
  }
}

import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct KomaSearchField {
  @Param value: string = ''
  @Param placeholder: ResourceStr = ''
  @Param showSearchButton: boolean = false
  @Param searchButtonText: ResourceStr = ''
  @Event change: (value: string) => void = (_value: string) => {}
  @Event submit: (value: string) => void = (_value: string) => {}

  build() {
    if (this.showSearchButton) {
      Search({ value: this.value, placeholder: this.placeholder })
        .width('100%')
        .height(ThemeConstants.INPUT_HEIGHT)
        .placeholderColor(ThemeConstants.TEXT_SECONDARY)
        .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
        .searchButton(this.searchButtonText, { fontColor: ThemeConstants.BRAND_PRIMARY })
        .onChange((value: string) => {
          this.change(value)
        })
        .onSubmit((value: string) => {
          this.submit(value)
        })
    } else {
      Search({ value: this.value, placeholder: this.placeholder })
        .width('100%')
        .height(ThemeConstants.INPUT_HEIGHT)
        .placeholderColor(ThemeConstants.TEXT_SECONDARY)
        .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
        .onChange((value: string) => {
          this.change(value)
        })
        .onSubmit((value: string) => {
          this.submit(value)
        })
    }
  }
}

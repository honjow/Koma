import { ThemeConstants } from '../theme/ThemeConstants'
import { uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'

let komaSearchFieldSeq: number = 0

@ComponentV2
export struct KomaSearchField {
  @Param value: string = ''
  @Local private fieldText: string = ''
  @Param placeholder: ResourceStr = ''
  @Param autoFocus: boolean = false
  @Param showSearchButton: boolean = false
  @Param searchButtonText: ResourceStr = ''
  @Param useSystemMaterial: boolean = false
  @Event change: (value: string) => void = (_value: string) => {}
  @Event submit: (value: string) => void = (_value: string) => {}
  private fieldId: string = `komaSearchField-${komaSearchFieldSeq++}`

  aboutToAppear(): void {
    this.fieldText = this.value
    if (this.autoFocus) {
      this.requestSearchFocus()
    }
  }

  @Monitor('autoFocus')
  private onAutoFocusChange(): void {
    if (this.autoFocus) {
      this.requestSearchFocus()
    }
  }

  @Monitor('value')
  private onExternalValueChange(): void {
    if (this.value !== this.fieldText) {
      this.fieldText = this.value
    }
  }

  build() {
    if (this.useSystemMaterial && deviceInfo.apiAvailable('26.0.0')) {
      Search({ value: this.fieldText, placeholder: this.placeholder })
        .id(this.fieldId)
        .width('100%')
        .height(ThemeConstants.INPUT_HEIGHT)
        .placeholderColor(ThemeConstants.TEXT_SECONDARY)
        .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
        .backgroundColor(Color.Transparent)
        .systemMaterial(this.searchSystemMaterial())
        .searchButton(this.showSearchButton ? this.searchButtonText : '', { fontColor: ThemeConstants.BRAND_PRIMARY })
        .onChange((value: string) => {
          this.fieldText = value
          this.change(value)
        })
        .onSubmit((value: string) => {
          this.fieldText = value
          this.submit(value)
        })
    } else {
      Search({ value: this.fieldText, placeholder: this.placeholder })
        .id(this.fieldId)
        .width('100%')
        .height(ThemeConstants.INPUT_HEIGHT)
        .placeholderColor(ThemeConstants.TEXT_SECONDARY)
        .textFont({ size: ThemeConstants.FONT_SIZE_BODY, weight: FontWeight.Regular })
        .backgroundColor(ThemeConstants.CARD)
        .searchButton(this.showSearchButton ? this.searchButtonText : '', { fontColor: ThemeConstants.BRAND_PRIMARY })
        .onChange((value: string) => {
          this.fieldText = value
          this.change(value)
        })
        .onSubmit((value: string) => {
          this.fieldText = value
          this.submit(value)
        })
    }
  }

  private searchSystemMaterial() {
    if (deviceInfo.apiAvailable('26.0.0')) {
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        colorInvert: true,
        applyShadow: true,
        interactive: true,
      })
    }
    return undefined
  }

  private requestSearchFocus(): void {
    setTimeout(() => {
      this.getUIContext().getFocusController().requestFocus(this.fieldId)
    }, 80)
  }
}

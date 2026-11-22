import { AppStrings } from '../i18n/AppStrings'
import { APP_ICON_OPTIONS, AppIconOption, AppIconSettings, AppIconState, connectAppIconState } from '../model/AppIconSettings'
import { komaModalCardSurface, komaToastOptions } from '../theme/KomaPopupOptions'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct AppIconPreview {
  @Require @Param option: AppIconOption
  @Param iconSize: number = 76

  build() {
    Stack() {
      Image(this.option.background).width('100%').height('100%').objectFit(ImageFit.Fill)
      Image(this.option.foreground).width('100%').height('100%').objectFit(ImageFit.Fill)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .borderRadius(this.iconSize * 0.24)
    .clip(true)
    .accessibilityLevel('no-hide-descendants')
  }
}

@ComponentV2
struct AppIconTile {
  @Require @Param option: AppIconOption
  @Param checked: boolean = false
  @Param inModal: boolean = false
  @Event onSelect: (name: string) => void = () => {}

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        AppIconPreview({ option: this.option })
        Text(AppStrings.get(this.option.labelKey))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ top: 27, left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_XS,
        bottom: ThemeConstants.SPACE_MD })

      // One hit target controls the choice. The native checkbox mirrors the system's confirmed state.
      Checkbox({ name: this.option.name || 'default' })
        .select(this.checked)
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .unselectedColor(ThemeConstants.TEXT_TERTIARY)
        .width(18)
        .height(18)
        .margin({ top: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM, left: 0, bottom: 0 })
        .hitTestBehavior(HitTestMode.None)
        .focusable(false)
        .accessibilityLevel('no')
    }
    .width('100%')
    .backgroundColor(this.checked ? ThemeConstants.SOFT_TINT : (this.inModal ? komaModalCardSurface() : ThemeConstants.CARD))
    .border({ width: 1, color: this.checked ? ThemeConstants.BRAND_PRIMARY : Color.Transparent,
      radius: ThemeConstants.LIST_ROW_RADIUS })
    .focusable(true)
    .accessibilityGroup(true)
    .accessibilityText(AppStrings.get(this.option.labelKey))
    .accessibilityRole(AccessibilityRoleType.CHECKBOX)
    .accessibilityChecked(this.checked)
    .id('launcher-icon-' + (this.option.name || 'default'))
    .onClick((): void => { this.onSelect(this.option.name) })
  }
}

@ComponentV2
export struct AppIconPicker {
  @Param inModal: boolean = false
  @Local private iconState: AppIconState = connectAppIconState()

  aboutToAppear(): void {
    void AppIconSettings.refresh()
  }

  private async select(name: string): Promise<void> {
    try {
      await AppIconSettings.select(name)
    } catch (_error) {
      this.getUIContext().getPromptAction()
        .showToast(komaToastOptions({ message: AppStrings.get('settings_app_icon_switch_failed') }))
    }
  }

  build() {
    if (this.iconState.activeName !== undefined) {
      GridRow({
        columns: { xs: 2, sm: 3, md: 4, lg: 5, xl: 6, xxl: 6 },
        gutter: 10,
        breakpoints: { value: ['316vp', '500vp', '680vp', '860vp'], reference: BreakpointsReference.ComponentSize },
      }) {
        ForEach(APP_ICON_OPTIONS, (option: AppIconOption) => {
          if (option.name.length === 0 || this.iconState.availableNames.includes(option.name)) {
            GridCol() {
              AppIconTile({
                option,
                checked: option.name === this.iconState.activeName,
                inModal: this.inModal,
                onSelect: (name: string): void => { void this.select(name) },
              })
            }
          }
        }, (option: AppIconOption): string => option.name || 'default')
      }
      .width('100%')
      .enabled(!this.iconState.changing)
    } else {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(AppStrings.get(this.iconState.loadFailed ? 'settings_app_icon_load_failed' : 'common_loading'))
          .fontColor(ThemeConstants.TEXT_SECONDARY)
        if (this.iconState.loadFailed) {
          Button(AppStrings.get('common_retry'))
            .onClick((): void => { void AppIconSettings.refresh() })
        }
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_XL)
    }
  }
}

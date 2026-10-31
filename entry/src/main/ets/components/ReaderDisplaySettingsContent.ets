import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderDisplaySettings, ReaderFilterBlendMode, normalizeReaderDisplaySettings } from '../model/ReaderDisplaySettings'
import { connectReaderDisplayPreview, ReaderDisplayPreviewState } from '../state/ReaderDisplayPreviewState'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'

@ComponentV2
export struct ReaderDisplaySettingsContent {
  @Param settings: ReaderDisplaySettings = new ReaderDisplaySettings()
  @Event onChange: (settings: ReaderDisplaySettings) => void = () => {}
  @Event onClose: () => void = () => {}
  @Local private draft: ReaderDisplaySettings = new ReaderDisplaySettings()
  private preview: ReaderDisplayPreviewState = connectReaderDisplayPreview()

  aboutToAppear(): void { this.draft = normalizeReaderDisplaySettings(this.settings); this.preview.set(this.draft) }
  aboutToDisappear(): void { this.preview.set(null) }

  private change(edit: (settings: ReaderDisplaySettings) => void, commit: boolean = true): void {
    const next = normalizeReaderDisplaySettings(this.draft)
    edit(next)
    this.draft = normalizeReaderDisplaySettings(next)
    this.preview.set(this.draft)
    if (commit) this.onChange(this.draft)
  }

  private setSlider(field: string, value: number, mode: SliderChangeMode): void {
    this.change((next: ReaderDisplaySettings): void => {
      if (field === 'brightness') next.brightness = value
      else if (field === 'red') next.red = value
      else if (field === 'green') next.green = value
      else if (field === 'blue') next.blue = value
      else next.alpha = value
    }, mode === SliderChangeMode.End || mode === SliderChangeMode.Click)
  }

  @Builder
  private BlendMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['default', 'multiply', 'screen', 'overlay', 'lighten', 'darken'], (mode: string) => {
        MenuItem({ content: AppStrings.get('reader_display_blend_' + mode),
          symbolEndIcon: this.draft.blendMode === mode ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
          .onClick((): void => { select((): void => { this.change((next): void => { next.blendMode = mode as ReaderFilterBlendMode }) }) })
      })
    }
  }

  build() {
    KomaModalScaffold({ title: AppStrings.get('reader_display_title'), onClose: (): void => { this.onClose() } }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        GroupedListSection() {
          ConciseListRow({ title: AppStrings.get('reader_display_brightness_enabled'), hasSwitch: true,
            checked: this.draft.brightnessEnabled, showChevron: false,
            switchAction: (value: boolean): void => { this.change((next): void => { next.brightnessEnabled = value }) } })
          if (this.draft.brightnessEnabled) ReaderDisplayValueSlider({ field: 'brightness', value: this.draft.brightness, min: -75, max: 100,
              onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('brightness', value, mode) } })
        }
        GroupedListSection() {
          ConciseListRow({ title: AppStrings.get('reader_display_filter_enabled'), hasSwitch: true,
            checked: this.draft.filterEnabled, showChevron: false,
            switchAction: (value: boolean): void => { this.change((next): void => { next.filterEnabled = value }) } })
          if (this.draft.filterEnabled) {
            ReaderDisplayValueSlider({ field: 'red', value: this.draft.red, min: 0, max: 255,
              onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('red', value, mode) } })
            ReaderDisplayValueSlider({ field: 'green', value: this.draft.green, min: 0, max: 255,
              onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('green', value, mode) } })
            ReaderDisplayValueSlider({ field: 'blue', value: this.draft.blue, min: 0, max: 255,
              onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('blue', value, mode) } })
            ReaderDisplayValueSlider({ field: 'alpha', value: this.draft.alpha, min: 0, max: 255,
              onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('alpha', value, mode) } })
            ConciseListRow({ title: AppStrings.get('reader_display_blend'),
              trailingText: AppStrings.get('reader_display_blend_' + this.draft.blendMode),
              trailingDropdown: true, dropdownMenuEnabled: true,
              dropdownMenuBuilder: (select: (action: () => void) => void) => { this.BlendMenu(select) } })
          }
        }
        GroupedListSection() {
          ConciseListRow({ title: AppStrings.get('reader_display_grayscale'), hasSwitch: true,
            checked: this.draft.grayscale, showChevron: false,
            switchAction: (value: boolean): void => { this.change((next): void => { next.grayscale = value }) } })
          ListDivider()
          ConciseListRow({ title: AppStrings.get('reader_display_inverted'), hasSwitch: true,
            checked: this.draft.inverted, showChevron: false,
            switchAction: (value: boolean): void => { this.change((next): void => { next.inverted = value }) } })
        }
      }.width('100%').padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
    }
  }
}

/** Primitive @Param values keep the displayed value in sync with native slider previews. */
@ComponentV2
struct ReaderDisplayValueSlider {
  @Require @Param field: string
  @Require @Param value: number
  @Param min: number = 0
  @Param max: number = 255
  @Event onChange: (value: number, mode: SliderChangeMode) => void = () => {}

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Row() {
        Text(AppStrings.get('reader_display_' + this.field)).fontColor(ThemeConstants.TEXT_PRIMARY)
        Blank()
        Text(`${this.value}`).fontColor(ThemeConstants.TEXT_SECONDARY)
      }.width('100%')
      Slider({ value: this.value, min: this.min, max: this.max, step: 1 }).width('100%')
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .onChange((value: number, mode: SliderChangeMode): void => { this.onChange(value, mode) })
    }.padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM })
  }
}

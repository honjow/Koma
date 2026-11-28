import { ReaderSettingOption } from './ReaderSettingOption'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { readerHdrBrightnessAvailable } from '@reader-kit/ui'
import { ReaderDisplaySettings, ReaderFilterBlendMode, normalizeReaderDisplaySettings } from '../model/ReaderDisplaySettings'
import { connectReaderDisplayPreview, ReaderDisplayPreviewState } from '../state/ReaderDisplayPreviewState'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'

@ComponentV2
export struct ReaderDisplaySettingsContent {
  @Param favoriteKeys: string[] | undefined = undefined
  @Param onFavorite: ((key: string) => void) | undefined = undefined
  @Param previewActive: boolean = true
  @Param embedded: boolean = false
  @Param settings: ReaderDisplaySettings = new ReaderDisplaySettings()
  @Event onChange: (settings: ReaderDisplaySettings) => void = () => {}
  @Event onClose: () => void = () => {}
  @Local private draft: ReaderDisplaySettings = new ReaderDisplaySettings()
  @Local private hdrAvailable: boolean = false
  private previewOwned: boolean = false
  private preview: ReaderDisplayPreviewState = connectReaderDisplayPreview()

  aboutToAppear(): void {
    this.hdrAvailable = readerHdrBrightnessAvailable(this.getUIContext().getHostContext())
    this.draft = normalizeReaderDisplaySettings(this.settings)
  }

  @Monitor('settings')
  private settingChanged(): void {
    if (!this.previewOwned) this.draft = normalizeReaderDisplaySettings(this.settings)
  }

  @Monitor('previewActive')
  private previewAvailabilityChanged(): void {
    if (!this.previewActive) {
      this.clearPreview()
      this.draft = normalizeReaderDisplaySettings(this.settings)
    }
  }

  aboutToDisappear(): void { this.clearPreview() }

  private clearPreview(): void {
    if (!this.previewOwned) return
    this.previewOwned = false
    this.preview.set(null)
  }

  private change(edit: (settings: ReaderDisplaySettings) => void, commit: boolean = true): void {
    const next = normalizeReaderDisplaySettings(this.draft)
    edit(next)
    this.draft = normalizeReaderDisplaySettings(next)
    if (commit) {
      this.clearPreview()
      this.onChange(this.draft)
    } else if (this.previewActive) {
      this.previewOwned = true
      this.preview.set(this.draft)
    }
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

  private showSetting(key: string): boolean {
    return this.favoriteKeys === undefined || this.favoriteKeys.includes(key)
  }

  @Builder
  private Controls() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      if (this.showSetting('reader_display_brightness_enabled') ||
        (this.hdrAvailable && this.showSetting('reader_display_hdr_brightness'))) {
        GroupedListSection({ inModal: true }) {
          if (this.showSetting('reader_display_brightness_enabled')) {
            ReaderSettingOption({ settingKey: 'reader_display_brightness_enabled', onFavorite: this.onFavorite }) {
              ConciseListRow({ title: AppStrings.get('reader_display_brightness_enabled'), hasSwitch: true,
                checked: this.draft.brightnessEnabled, showChevron: false,
                switchAction: (value: boolean): void => { this.change((next): void => { next.brightnessEnabled = value }) } })
            }
            if (this.draft.brightnessEnabled) {
              ReaderDisplayValueSlider({ field: 'brightness', value: this.draft.brightness, min: -75, max: 100,
                onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider('brightness', value, mode) } })
            }
          }
          if (this.hdrAvailable && this.showSetting('reader_display_hdr_brightness')) {
            if (this.showSetting('reader_display_brightness_enabled')) {
              ListDivider()
            }
            ReaderSettingOption({ settingKey: 'reader_display_hdr_brightness', onFavorite: this.onFavorite }) {
              ConciseListRow({ title: AppStrings.get('reader_display_hdr_brightness'), hasSwitch: true,
                checked: this.draft.hdrBrightnessEnabled, showChevron: false,
                switchAction: (value: boolean): void => { this.change((next): void => { next.hdrBrightnessEnabled = value }) } })
            }
          }
        }
      }
      if (this.showSetting('reader_display_filter_enabled') ||
        (this.favoriteKeys !== undefined && this.showSetting('reader_display_blend'))) {
        GroupedListSection({ inModal: true }) {
          if (this.showSetting('reader_display_filter_enabled')) {
            ReaderSettingOption({ settingKey: 'reader_display_filter_enabled', onFavorite: this.onFavorite }) {
              ConciseListRow({ title: AppStrings.get('reader_display_filter_enabled'), hasSwitch: true,
                checked: this.draft.filterEnabled, showChevron: false,
                switchAction: (value: boolean): void => { this.change((next): void => { next.filterEnabled = value }) } })
            }
            if (this.draft.filterEnabled) {
              ForEach(['red', 'green', 'blue', 'alpha'], (field: string) => {
                ReaderDisplayValueSlider({ field: field, value: this.filterValue(field), min: 0, max: 255,
                  onChange: (value: number, mode: SliderChangeMode): void => { this.setSlider(field, value, mode) } })
              }, (field: string): string => field)
            }
          }
          if ((this.showSetting('reader_display_filter_enabled') && this.draft.filterEnabled) ||
            (this.favoriteKeys !== undefined && this.showSetting('reader_display_blend'))) {
            ReaderSettingOption({ settingKey: 'reader_display_blend', onFavorite: this.onFavorite }) {
              ConciseListRow({ title: AppStrings.get('reader_display_blend'),
                trailingText: AppStrings.get('reader_display_blend_' + this.draft.blendMode),
                trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: this.draft.filterEnabled,
                dropdownMenuBuilder: (select: (action: () => void) => void) => { this.BlendMenu(select) } })
            }
          }
        }
      }
      if (this.showSetting('reader_display_grayscale') || this.showSetting('reader_display_inverted')) {
        GroupedListSection({ inModal: true }) {
          if (this.showSetting('reader_display_grayscale')) {
            ReaderSettingOption({ settingKey: 'reader_display_grayscale', onFavorite: this.onFavorite }) {
              ConciseListRow({ title: AppStrings.get('reader_display_grayscale'), hasSwitch: true,
                checked: this.draft.grayscale, showChevron: false,
                switchAction: (value: boolean): void => { this.change((next): void => { next.grayscale = value }) } })
            }
          }
          if (this.showSetting('reader_display_inverted')) {
            if (this.showSetting('reader_display_grayscale')) {
              ListDivider()
            }
            ReaderSettingOption({ settingKey: 'reader_display_inverted', onFavorite: this.onFavorite }) {
              ConciseListRow({ title: AppStrings.get('reader_display_inverted'), hasSwitch: true,
                checked: this.draft.inverted, showChevron: false,
                switchAction: (value: boolean): void => { this.change((next): void => { next.inverted = value }) } })
            }
          }
        }
      }
    }.width('100%')
  }

  private filterValue(channel: string): number {
    if (channel === 'red') return this.draft.red
    if (channel === 'green') return this.draft.green
    return channel === 'blue' ? this.draft.blue : this.draft.alpha
  }

  build() {
    if (this.embedded) {
      this.Controls()
    } else {
      KomaModalScaffold({ title: AppStrings.get('reader_display_title'), onClose: (): void => { this.onClose() } }) {
        this.Controls()
      }
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
      Slider({ value: this.value, min: this.min, max: this.max, step: 1, style: SliderStyle.InSet }).width('100%')
        .trackColor($r('app.color.koma_reader_filter_slider_track'))
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .onChange((value: number, mode: SliderChangeMode): void => { this.onChange(value, mode) })
    }.padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM })
  }
}

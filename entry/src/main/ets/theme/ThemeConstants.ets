export class ThemeConstants {
  // Koma UI tokens, aligned with the NextE/V2Next HDS rhythm.
  // Keep Koma's own brand color, but avoid scattering raw sizes and colors in pages.
  static readonly BRAND_PRIMARY: ResourceColor = $r('app.color.koma_accent')
  static readonly BRAND_ACCENT: ResourceColor = $r('sys.color.font_secondary')
  static readonly TEXT_ON_BRAND: ResourceColor = $r('app.color.koma_text_on_brand')
  static readonly TEXT_PRIMARY: ResourceColor = $r('app.color.koma_text_primary')
  static readonly TEXT_SECONDARY: ResourceColor = $r('app.color.koma_text_secondary')
  static readonly TEXT_TERTIARY: ResourceColor = $r('sys.color.font_tertiary')
  static readonly BG_PRIMARY: ResourceColor = $r('app.color.koma_background')
  static readonly BG_SUB: ResourceColor = $r('sys.color.ohos_id_color_sub_background')
  static readonly CARD: ResourceColor = $r('app.color.koma_card')
  static readonly DIVIDER: ResourceColor = $r('sys.color.ohos_id_color_list_separator')
  static readonly DANGER: ResourceColor = $r('app.color.koma_danger')
  static readonly COVER_PLACEHOLDER: ResourceColor = $r('app.color.koma_cover_placeholder')
  static readonly SELECTED_OVERLAY: ResourceColor = '#66000000'
  static readonly SOFT_TINT: ResourceColor = '#1F256E5D'
  static readonly SOFT_PRESSED: ResourceColor = '#0F000000'
  static readonly STATUS_SUCCESS: ResourceColor = '#1D7F5A'
  static readonly STATUS_INFO: ResourceColor = '#3268B8'
  static readonly STATUS_MUTED: ResourceColor = '#6C706C'
  static readonly STATUS_DANGER: ResourceColor = '#8B3A34'
  static readonly STATUS_WARNING: ResourceColor = '#8D6A2E'
  static readonly SHADOW_CARD: ResourceColor = '#1A000000'
  static readonly SHADOW_PROMINENT: ResourceColor = '#26000000'

  static readonly READER_BG_DARK: ResourceColor = '#0B0A09'
  static readonly READER_BG_LIGHT: ResourceColor = '#F7F1EC'
  static readonly READER_BG_PAPER: ResourceColor = '#E7D6BE'
  static readonly READER_SURFACE: ResourceColor = '#17130F'
  static readonly READER_PAGE_SURFACE: ResourceColor = '#050505'
  static readonly READER_CONTROL_SURFACE: ResourceColor = '#332C28'
  static readonly READER_CONTROL_OVERLAY: ResourceColor = '#D911100F'
  static readonly READER_TEXT_PRIMARY: ResourceColor = '#F7F1EC'
  static readonly READER_TEXT_SECONDARY: ResourceColor = '#BCAEA7'
  static readonly READER_TEXT_TERTIARY: ResourceColor = '#8F837D'
  static readonly READER_TEXT_DISABLED: ResourceColor = '#81746D'
  static readonly READER_TEXT_ON_LIGHT: ResourceColor = '#17130F'
  static readonly READER_TEXT_UNSELECTED: ResourceColor = '#EDE2DA'
  static readonly READER_ACCENT: ResourceColor = '#E66A3A'
  static readonly READER_ACCENT_LIGHT: ResourceColor = '#FF996F'
  static readonly READER_TAP_ZONE_OVERLAY: ResourceColor = '#33E66A3A'
  static readonly READER_PROGRESS_BG: ResourceColor = '#40332C28'
  static readonly READER_BORDER: ResourceColor = '#4A332C28'
  static readonly READER_SHADOW: ResourceColor = '#33000000'

  static readonly SOURCE_LOCAL_COLOR: string = '#16745F'
  static readonly SOURCE_KOMGA_COLOR: string = '#355F91'
  static readonly SOURCE_KAVITA_COLOR: string = '#6B5B95'
  static readonly SOURCE_OPDS_COLOR: string = '#8A5A2B'
  static readonly SOURCE_WEBDAV_COLOR: string = '#5F5F9F'
  static readonly SOURCE_WASM_COLOR: string = '#7A405D'
  static readonly COVER_PALETTE: string[] = [
    ThemeConstants.SOURCE_LOCAL_COLOR,
    '#D45B3E',
    '#2D5E8B',
    ThemeConstants.SOURCE_OPDS_COLOR,
    '#6E4A86',
    '#4D6B3C',
  ]

  static readonly SPACE_XS: number = 4
  static readonly SPACE_SM: number = 8
  static readonly SPACE_MD: number = 12
  static readonly SPACE_LG: number = 16
  static readonly SPACE_XL: number = 24
  static readonly SPACE_XXL: number = 32

  static readonly FONT_SIZE_TINY: number = 10
  static readonly FONT_SIZE_TAG: number = 11
  static readonly FONT_SIZE_CAPTION: number = 12
  static readonly FONT_SIZE_META: number = 13
  static readonly FONT_SIZE_LIST_ITEM: number = 13
  static readonly FONT_SIZE_BODY: number = 14
  static readonly FONT_SIZE_TITLE: number = 16
  static readonly FONT_SIZE_HEADING: number = 18
  static readonly FONT_SIZE_H3: number = 20
  static readonly FONT_SIZE_H2: number = 22
  static readonly FONT_SIZE_H1: number = 24

  static readonly RADIUS_SM: number = 4
  static readonly RADIUS_CHIP: number = 8
  static readonly RADIUS_THUMB: number = 8
  static readonly RADIUS_MD: number = 22
  static readonly RADIUS_CARD: number = 24
  static readonly RADIUS_ROUND: number = 999
  static readonly LIST_SECTION_INSET: number = 4
  static readonly LIST_ROW_RADIUS: number = 19
  static readonly LIST_ROW_TEXT_INDENT: number = 8

  static readonly TITLE_BAR_HEIGHT: number = 56
  static readonly BUTTON_HEIGHT: number = 46
  static readonly SOURCE_ICON_SIZE: number = 48
  static readonly LIST_COVER_WIDTH: number = 48
  static readonly LIST_COVER_HEIGHT: number = 64
  static readonly FILTER_CHIP_HEIGHT: number = 34
  static readonly ACTION_CHIP_HEIGHT: number = 36
  static readonly TOUCH_TARGET_SM: number = 36
  static readonly LOADING_SIZE_LARGE: number = 36
  static readonly SOURCE_RESULT_GRID_COLUMN_COUNT: number = 2
  static readonly LINE_HEIGHT_TITLE: number = 22
  static readonly LINE_HEIGHT_BODY: number = 20
}

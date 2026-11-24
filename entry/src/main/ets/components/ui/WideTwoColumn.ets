import { ThemeConstants } from '../../theme/ThemeConstants'
import { ListDivider } from './GroupedListSection'

// Settings home introduced the width-gated row pairing: the main window width
// minus the list's symmetric horizontal padding. Browse source entries and the
// source manager lists share this threshold and pair builder so a wide window
// merges rows in the same places. Narrow windows keep the original one-row-per
// item layout; change the threshold only together with the settings home.
export const WIDE_TWO_COLUMN_MIN_WIDTH: number = 560

export function usesWideTwoColumnLayout(windowWidthVp: number): boolean {
  return windowWidthVp - 2 * ThemeConstants.SPACE_MD >= WIDE_TWO_COLUMN_MIN_WIDTH
}

// One merged row: each item owns a half-width column and a center gutter stays
// empty. A missing second item leaves the column blank instead of collapsing.
@ComponentV2
export struct WidePairRow {
  @BuilderParam first: () => void
  @BuilderParam second: () => void

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column() {
        this.first()
      }
      .layoutWeight(1)

      Column() {
        this.second()
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

// The divider between two merged rows follows each column and leaves the
// center gutter untouched.
@ComponentV2
export struct WidePairDivider {
  @Param leftMargin: number = ThemeConstants.SPACE_LG
  @Param rightMargin: number = 0

  build() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      Column() {
        ListDivider({ leftMargin: this.leftMargin, rightMargin: this.rightMargin })
      }
      .layoutWeight(1)

      Column() {
        ListDivider({ leftMargin: this.leftMargin, rightMargin: this.rightMargin })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }
}

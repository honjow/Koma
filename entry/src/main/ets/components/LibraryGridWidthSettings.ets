import { AppStrings } from '../i18n/AppStrings'
import { LibraryCoverGridAdjustment } from '../state/LibraryCoverGridAdjustment'
import { connectLibraryCoverLayout, LibraryCoverLayoutState } from '../state/LibraryCoverLayoutState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { gridFallbackContainerWidth } from '../utils/GridColumns'
import {
  clampLibraryGridColumnWidth, libraryCoverGridColumnCount, libraryCoverGridGap, libraryCoverGridMinimumWidth,
  LIBRARY_GRID_MAX_COLUMN_WIDTH, LIBRARY_GRID_MIN_COLUMN_WIDTH,
} from '../utils/LibraryCoverLayout'

@ComponentV2
export struct LibraryGridWidthSettings {
  @Local private layout: LibraryCoverLayoutState = connectLibraryCoverLayout()
  @Local private adjustment: LibraryCoverGridAdjustment = new LibraryCoverGridAdjustment()
  @Local private previewWidth: number = gridFallbackContainerWidth()
  private readonly covers: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

  private columnWidth(): number {
    return libraryCoverGridMinimumWidth(this.previewWidth,
      this.adjustment.width(this.layout.gridColumnWidth))
  }

  private previewColumns(): string {
    const columns = libraryCoverGridColumnCount(this.previewWidth, this.layout.gridSpacing, this.columnWidth())
    return `repeat(${columns}, 1fr)`
  }

  build() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Grid() {
        ForEach(this.covers, (cover: number) => {
          GridItem() {
            Column()
              .width('100%')
              .aspectRatio(0.72)
              .borderRadius(ThemeConstants.RADIUS_SM)
              .backgroundColor(ThemeConstants.COVER_PLACEHOLDER)
          }
        }, (cover: number): string => cover.toString())
      }
      .columnsTemplate(this.previewColumns())
      .columnsGap(libraryCoverGridGap(this.layout.gridSpacing))
      .rowsGap(libraryCoverGridGap(this.layout.gridSpacing))
      .padding({ left: libraryCoverGridGap(this.layout.gridSpacing), right: libraryCoverGridGap(this.layout.gridSpacing) })
      .height(220)
      .width('100%')
      .enableScrollInteraction(false)
      .scrollBar(BarState.Off)
      .clip(true)
      .onAreaChange((_previous: Area, next: Area): void => {
        const width = Number(next.width)
        if (width > 0) this.previewWidth = width
      })
      .gesture(PinchGesture({ fingers: 2 })
        .onActionStart((): void => {
          this.adjustment.beginPinch(this.previewWidth, this.layout.gridSpacing, this.layout.gridColumnWidth)
        })
        .onActionUpdate((event: GestureEvent): void => { this.adjustment.updatePinch(event.scale, this.getUIContext()) })
        .onActionEnd((): void => { this.adjustment.endPinch(this.getUIContext()) })
        .onActionCancel((): void => { this.adjustment.cancelPinch() }))

      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(AppStrings.get('settings_column_width_hint'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
        Slider({
          value: this.columnWidth(),
          min: LIBRARY_GRID_MIN_COLUMN_WIDTH,
          max: LIBRARY_GRID_MAX_COLUMN_WIDTH,
          step: 1,
          style: SliderStyle.InSet,
        })
          .width('100%')
          .selectedColor(ThemeConstants.BRAND_PRIMARY)
          .onChange((value: number, mode: SliderChangeMode): void => {
            const width = clampLibraryGridColumnWidth(value)
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.adjustment.save(this.getUIContext(), width)
            } else {
              this.adjustment.preview(width)
            }
          })
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
    }
    .width('100%')
  }
}

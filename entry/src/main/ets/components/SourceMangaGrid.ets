import { SourceManga } from '../model/SourceModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { MangaGridItem } from './MangaGridItem'
import { gridFallbackContainerWidth, gridColumnCount } from '../utils/GridColumns'

@ComponentV2
export struct SourceMangaGrid {
  @Param manga: SourceManga[] = []
  // Seeded from the display width so the first frame already uses the same
  // column model as every later frame; onAreaChange keeps it exact.
  @Local private containerWidth: number = gridFallbackContainerWidth()
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private columnCount(): number {
    return gridColumnCount(
      this.containerWidth,
      ThemeConstants.SOURCE_GRID_MIN_COLUMN_WIDTH,
      ThemeConstants.SPACE_MD,
      0,
    )
  }

  private rowCount(): number {
    return Math.ceil(this.manga.length / this.columnCount())
  }

  private rowIndexes(): number[] {
    const rows: number[] = []
    for (let index = 0; index < this.rowCount(); index += 1) {
      rows.push(index)
    }
    return rows
  }

  private rowManga(rowIndex: number): SourceManga[] {
    const start = rowIndex * this.columnCount()
    return this.manga.slice(start, start + this.columnCount())
  }

  private missingCells(row: SourceManga[]): number[] {
    const missing = this.columnCount() - row.length
    const cells: number[] = []
    for (let index = 0; index < missing; index += 1) {
      cells.push(index)
    }
    return cells
  }

  build() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      ForEach(this.rowIndexes(), (rowIndex: number) => {
        Row({ space: ThemeConstants.SPACE_MD }) {
          ForEach(this.rowManga(rowIndex), (item: SourceManga) => {
            Column() {
              MangaGridItem({
                manga: item,
                onMangaTap: (selected: SourceManga) => {
                  this.onMangaTap(selected)
                },
              })
            }
            .layoutWeight(1)
          }, (item: SourceManga) => `${item.sourceId}:${item.id}`)

          ForEach(this.missingCells(this.rowManga(rowIndex)), (index: number) => {
            Blank()
              .layoutWeight(1)
          }, (index: number) => `blank-${rowIndex}-${index}`)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }, (rowIndex: number) => `row-${rowIndex}`)
    }
    .width('100%')
    .onAreaChange((_old: Area, next: Area) => {
      this.containerWidth = next.width as number
    })
  }
}

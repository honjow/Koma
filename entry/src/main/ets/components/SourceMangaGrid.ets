import { SourceManga } from '../model/SourceModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { MangaGridItem } from './MangaGridItem'

@ComponentV2
export struct SourceMangaGrid {
  @Param manga: SourceManga[] = []
  @Param columnCount: number = 0
  @Local private containerWidth: number = 0
  @Event onMangaTap: (manga: SourceManga) => void = (_manga: SourceManga) => {}

  private normalizedColumnCount(): number {
    if (this.columnCount > 0) {
      return Math.max(1, Math.min(12, Math.floor(this.columnCount)))
    }
    if (this.containerWidth <= 0) {
      return 3
    }
    const targetWidth = 135
    const gap = ThemeConstants.SPACE_MD
    const count = Math.floor((this.containerWidth + gap) / (targetWidth + gap))
    return Math.max(2, Math.min(12, count))
  }

  private rowCount(): number {
    const columns = this.normalizedColumnCount()
    return Math.ceil(this.manga.length / columns)
  }

  private rowIndexes(): number[] {
    const rows: number[] = []
    for (let index = 0; index < this.rowCount(); index += 1) {
      rows.push(index)
    }
    return rows
  }

  private rowManga(rowIndex: number): SourceManga[] {
    const columns = this.normalizedColumnCount()
    const start = rowIndex * columns
    return this.manga.slice(start, start + columns)
  }

  private missingCells(row: SourceManga[]): number[] {
    const missing = this.normalizedColumnCount() - row.length
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

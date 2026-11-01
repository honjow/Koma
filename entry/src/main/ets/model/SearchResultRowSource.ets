import { CrossSearchResultItem, CrossSearchSection } from './CrossSearchService'

export interface SearchResultRow {
  key: string
  kind: 'status' | 'header' | 'result' | 'migration'
  section: CrossSearchSection
  item?: CrossSearchResultItem
}

/** A flat List source keeps native creation/cover work limited to visible rows. */
export class SearchResultRowSource implements IDataSource {
  private rows: SearchResultRow[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number { return this.rows.length }
  getData(index: number): SearchResultRow { return this.rows[index] }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) this.listeners.push(listener)
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((value: DataChangeListener): boolean => value !== listener)
  }

  update(sections: CrossSearchSection[], migration: boolean, resultsOnly: boolean = false): void {
    const next: SearchResultRow[] = []
    for (const section of sections) {
      if (section.diagnosticCode === 'configuration_loading') continue
      if (section.state === 'unsupported' && section.diagnosticCode === 'not_configured') continue
      if (resultsOnly && (section.state !== 'ready' || section.items.length === 0)) continue
      if (section.state === 'ready' && section.items.length > 0) {
        next.push({ key: `${section.id}:header`, kind: 'header', section })
        if (migration) next.push({ key: `${section.id}:migration`, kind: 'migration', section })
        else section.items.forEach((item: CrossSearchResultItem): void => {
          next.push({ key: `${section.id}:${item.id}`, kind: 'result', section, item })
        })
      } else {
        next.push({ key: `${section.id}:status`, kind: 'status', section })
      }
    }
    const wanted = new Set<string>(next.map((row: SearchResultRow): string => row.key))
    for (let index = this.rows.length - 1; index >= 0; index--) {
      if (wanted.has(this.rows[index].key)) continue
      this.rows.splice(index, 1)
      this.listeners.forEach((listener: DataChangeListener): void => listener.onDataDelete(index))
    }
    next.forEach((row: SearchResultRow, index: number): void => {
      const previous = this.rows[index]
      if (previous?.key !== row.key) {
        const moved = this.rows.findIndex((value: SearchResultRow): boolean => value.key === row.key)
        if (moved >= 0) {
          this.rows.splice(moved, 1)
          this.listeners.forEach((listener: DataChangeListener): void => listener.onDataDelete(moved))
        }
        this.rows.splice(index, 0, row)
        this.listeners.forEach((listener: DataChangeListener): void => listener.onDataAdd(index))
      } else if (previous.section !== row.section || previous.item !== row.item) {
        this.rows[index] = row
        this.listeners.forEach((listener: DataChangeListener): void => listener.onDataChange(index))
      }
    })
  }
}

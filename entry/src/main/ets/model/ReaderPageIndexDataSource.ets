/**
 * Stable index source for all Reader lazy surfaces.
 *
 * Reader pages, spreads and thumbnail strips must not construct one component
 * per chapter page.  LazyForEach owns the row lifecycle; this source only
 * emits a reload when the chapter or spread geometry changes.
 */
export class ReaderPageIndexDataSource implements IDataSource {
  private indexes: number[] = []
  private listeners: DataChangeListener[] = []

  totalCount(): number {
    return this.indexes.length
  }

  getData(index: number): number {
    return this.indexes[index]
  }

  setIndexes(indexes: number[]): void {
    this.indexes = indexes
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDatasetChange([{ type: DataOperationType.RELOAD }])
    })
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) {
      this.listeners.splice(index, 1)
    }
  }
}

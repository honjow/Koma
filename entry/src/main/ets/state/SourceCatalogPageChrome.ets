export type SourceCatalogPageAction = 'filters' | 'addSubscription' | 'import'

@ObservedV2
export class SourceCatalogPageChrome {
  @Trace requestId: number = 0
  action: SourceCatalogPageAction = 'filters'
  request(action: SourceCatalogPageAction): void {
    this.action = action
    this.requestId += 1
  }
}

export type SourceCatalogPageAction = 'filters' | 'addSubscription' | 'import'

@ObservedV2
export class SourceCatalogPageChrome {
  @Trace section: 'sources' | 'plugins' = 'sources'
  @Trace pluginsVisited: boolean = false
  @Trace requestId: number = 0
  action: SourceCatalogPageAction = 'filters'
  selectSection(section: 'sources' | 'plugins'): void {
    this.section = section
    if (section === 'plugins') this.pluginsVisited = true
  }
  request(action: SourceCatalogPageAction): void {
    this.action = action
    this.requestId += 1
  }
}

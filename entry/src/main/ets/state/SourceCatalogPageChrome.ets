import { SearchRouteChromeState } from './SearchRouteChromeState'

export type SourceCatalogPageAction = 'filters' | 'addSubscription' | 'import'

@ObservedV2
export class SourceCatalogPageChrome {
  readonly scroller: Scroller = new Scroller()
  @Trace section: 'sources' | 'plugins' = 'sources'
  @Trace pluginsVisited: boolean = false
  @Trace requestId: number = 0
  @Trace searchExpanded: boolean = false
  @Trace searchVisible: boolean = false
  @Trace searchHeight: number = 0
  @Trace searchFocus: boolean = false
  @Trace searchAnimating: boolean = false
  readonly search: SearchRouteChromeState = new SearchRouteChromeState(false)
  searchTransitionId: number = 0
  action: SourceCatalogPageAction = 'filters'
  selectSection(section: 'sources' | 'plugins'): void {
    if (section !== 'sources') { this.searchTransitionId += 1; this.closeSearch(); this.searchVisible = false; this.searchHeight = 0; this.searchAnimating = false }
    this.section = section
    if (section === 'plugins') this.pluginsVisited = true
  }
  openSearch(): void { this.searchExpanded = true; this.searchVisible = true }
  closeSearch(): void { this.search.updateQuery(''); this.searchFocus = false; this.searchExpanded = false }
  request(action: SourceCatalogPageAction): void {
    this.action = action
    this.requestId += 1
  }
}

/**
 * Route-local query state for a pushed global search destination.
 *
 * The HDS title-bar input and the result body are mounted separately, so this
 * state belongs to one NavPath parameter rather than a process-wide search bus.
 */
let searchRouteSequence: number = 0

@ObservedV2
export class SearchRouteChromeState {
  readonly autoFocus: boolean
  readonly filterAnchorId: string
  readonly resultModeAnchorId: string
  @Trace resultsOnly: boolean = false
  @Trace visible: boolean = false
  @Trace query: string = ''
  @Trace queryChangeSeq: number = 0
  @Trace querySubmitSeq: number = 0
  @Trace filterRequestSeq: number = 0
  @Trace resultModeRequestSeq: number = 0

  constructor(autoFocus: boolean = true) {
    this.autoFocus = autoFocus
    this.filterAnchorId = `search-results-filter-${++searchRouteSequence}`
    this.resultModeAnchorId = `search-results-mode-${searchRouteSequence}`
  }

  updateQuery(value: string): void {
    // A programmatic recent-query submit is mirrored into native Search. Its
    // onChange echo is not a second edit and must not cancel/restart the run.
    if (value === this.query) return
    this.query = value
    this.queryChangeSeq = this.queryChangeSeq + 1
  }

  submitQuery(value: string): void {
    this.query = value
    this.querySubmitSeq = this.querySubmitSeq + 1
  }

  requestFilters(): void {
    this.filterRequestSeq = this.filterRequestSeq + 1
  }

  requestResultMode(): void {
    this.resultModeRequestSeq += 1
  }
}

/**
 * Route-local query state for a pushed global search destination.
 *
 * The HDS title-bar input and the result body are mounted separately, so this
 * state belongs to one NavPath parameter rather than a process-wide search bus.
 */
@ObservedV2
export class SearchRouteChromeState {
  @Trace query: string = ''
  @Trace queryChangeSeq: number = 0
  @Trace querySubmitSeq: number = 0
  @Trace filterRequestSeq: number = 0

  updateQuery(value: string): void {
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
}

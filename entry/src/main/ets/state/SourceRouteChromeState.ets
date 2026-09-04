/**
 * Route-local command state shared by the root HDS title bar and one source page.
 *
 * Source Browse/Search live under the root HdsNavigation, so their pages cannot
 * configure the destination title bar directly. Keep each route's commands in
 * its NavPath param instead of creating a process-wide command bus.
 */
@ObservedV2
export class SourceBrowseRouteChromeState {
  readonly sourceName: string
  @Trace filtersAvailable: boolean = false
  @Trace filterRequestSeq: number = 0
  @Trace query: string = ''
  @Trace queryChangeSeq: number = 0
  @Trace querySubmitSeq: number = 0

  constructor(sourceName: string = '') {
    this.sourceName = sourceName
  }

  requestFilters(): void {
    this.filterRequestSeq = this.filterRequestSeq + 1
  }

  updateQuery(value: string): void {
    this.query = value
    this.queryChangeSeq = this.queryChangeSeq + 1
  }

  submitQuery(value: string): void {
    this.query = value
    this.querySubmitSeq = this.querySubmitSeq + 1
  }

}

@ObservedV2
export class SourceSearchRouteChromeState {
  readonly sourceName: string
  @Trace filtersAvailable: boolean = false
  @Trace filterRequestSeq: number = 0
  @Trace query: string = ''
  @Trace queryChangeSeq: number = 0
  @Trace querySubmitSeq: number = 0

  constructor(sourceName: string = '') {
    this.sourceName = sourceName
  }

  requestFilters(): void {
    this.filterRequestSeq = this.filterRequestSeq + 1
  }

  updateQuery(value: string): void {
    this.query = value
    this.queryChangeSeq = this.queryChangeSeq + 1
  }

  submitQuery(value: string): void {
    this.query = value
    this.querySubmitSeq = this.querySubmitSeq + 1
  }
}

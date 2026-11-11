export type DownloadsCommand = 'queue' | 'cancelAll' | 'retryAll' | 'clearFailed' | 'deleteDownloaded' | 'rescan' |
  'select' | 'exitSelection' | 'toggleAll' | 'pauseSelected' | 'resumeSelected' | 'cancelSelected' |
  'retrySelected' | 'deleteSelected'

@ObservedV2
export class DownloadsChrome {
  @Trace queueAction: string = ''
  @Trace hasTasks: boolean = false
  @Trace hasRetryable: boolean = false
  @Trace hasFailures: boolean = false
  @Trace hasDownloaded: boolean = false
  @Trace hasVisible: boolean = false
  @Trace selecting: boolean = false
  @Trace selectedCount: number = 0
  @Trace allSelected: boolean = false
  @Trace canPauseSelected: boolean = false
  @Trace canResumeSelected: boolean = false
  @Trace canCancelSelected: boolean = false
  @Trace canRetrySelected: boolean = false
  @Trace canDeleteSelected: boolean = false
  @Trace requestRevision: number = 0
  command: DownloadsCommand = 'queue'

  request(command: DownloadsCommand): void {
    this.command = command
    this.requestRevision += 1
  }
}

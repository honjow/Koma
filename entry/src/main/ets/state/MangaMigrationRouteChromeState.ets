export type MigrationCommand = 'continue' | 'copy' | 'move' | 'finish' | 'sources' | 'retryFailed' | 'resumeConfirmation'

/** The page owns migration state; root title actions are its route-local projection. */
@ObservedV2
export class MangaMigrationRouteChromeState {
  @Trace stage: string = 'sources'
  @Trace canContinue: boolean = false
  @Trace readyCount: number = 0
  @Trace failedCount: number = 0
  @Trace searchingCount: number = 0
  @Trace busy: boolean = false
  @Trace commandSeq: number = 0
  command: MigrationCommand = 'continue'
  previewReturnsToConfirmation: boolean = false

  request(command: MigrationCommand): void {
    this.command = command
    this.commandSeq += 1
  }
}

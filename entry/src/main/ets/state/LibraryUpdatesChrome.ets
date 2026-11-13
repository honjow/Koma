export type LibraryUpdatesAction = 'toggleAll' | 'download' | 'markRead'

@ObservedV2
export class LibraryUpdatesChrome {
  @Trace unreadOnly: boolean = false
  @Trace selecting: boolean = false
  @Trace selectedKeys: Set<string> = new Set<string>()
  @Trace allSelected: boolean = false
  @Trace busy: boolean = false
  @Trace requestRevision: number = 0
  action: LibraryUpdatesAction = 'toggleAll'

  exitSelection(): void {
    this.selecting = false
    this.selectedKeys = new Set<string>()
  }

  request(action: LibraryUpdatesAction): void {
    this.action = action
    this.requestRevision += 1
  }
}

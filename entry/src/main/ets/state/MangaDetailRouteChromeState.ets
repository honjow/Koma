/**
 * Route-local page-management commands for one manga detail destination.
 *
 * The root HdsNavDestination owns its title bar while MangaDetailPage owns
 * the commands. Keep the bridge on this NavPath parameter so one detail route
 * never drives the title bar of another route still retained in the stack.
 */
export enum MangaDetailTitleAction {
  FIND_TRACKER_MAPPING = 'find_tracker_mapping',
  SYNC_TRACKER = 'sync_tracker',
  PULL_TRACKER = 'pull_tracker',
  CHECK_LOCAL_LIBRARY_REFRESH = 'check_local_library_refresh',
  EDIT_LOCAL_METADATA = 'edit_local_metadata',
}

@ObservedV2
export class MangaDetailRouteChromeState {
  @Trace pageActionsAvailable: boolean = false
  @Trace localRefreshAvailable: boolean = false
  @Trace localMetadataAvailable: boolean = false
  @Trace localRefreshBusy: boolean = false
  @Trace trackerMappingBusy: boolean = false
  @Trace trackerSyncBusy: boolean = false
  @Trace requestedAction: MangaDetailTitleAction = MangaDetailTitleAction.FIND_TRACKER_MAPPING
  @Trace actionRequestSeq: number = 0

  requestAction(action: MangaDetailTitleAction): void {
    this.requestedAction = action
    this.actionRequestSeq = this.actionRequestSeq + 1
  }
}

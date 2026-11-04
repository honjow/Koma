import { ChapterListPresentation } from '../components/ChapterListSection'

/**
 * Route-local page-management commands for one manga detail destination.
 *
 * The root HdsNavDestination owns its title bar while MangaDetailPage owns
 * the commands. Keep the bridge on this NavPath parameter so one detail route
 * never drives the title bar of another route still retained in the stack.
 */
export enum MangaDetailTitleAction {
  SELECT_CHAPTERS = 'select_chapters',
  SELECT_ALL_CHAPTERS = 'select_all_chapters',
  DOWNLOAD_INCOMPLETE = 'download_incomplete',
  RETRY_FAILED_DOWNLOADS = 'retry_failed_downloads',
  RELOAD_SOURCE = 'reload_source',
  OPEN_WEBVIEW = 'open_webview',
  SHARE_LINK = 'share_link',
  OPEN_BROWSER = 'open_browser',
  CHECK_LOCAL_LIBRARY_REFRESH = 'check_local_library_refresh',
  EDIT_LOCAL_METADATA = 'edit_local_metadata',
  MIGRATE = 'migrate',
  EDIT_NOTES = 'edit_notes',
  CHANGE_COVER = 'change_cover',
  RESTORE_COVER = 'restore_cover',
}

@ObservedV2
export class MangaDetailRouteChromeState {
  private static nextMenuId: number = 0
  readonly menuAnchorId: string = `manga-detail-more-${MangaDetailRouteChromeState.nextMenuId++}`
  readonly detailScroller: ListScroller = new ListScroller()
  readonly chapterScroller: ListScroller = new ListScroller()
  readonly chapterPresentation: ChapterListPresentation = new ChapterListPresentation()
  @Trace filteredChapterIds: string[] = []
  @Trace chapterDownloadAvailable: boolean = false
  @Trace visible: boolean = false
  @Trace resolvedTitle: string = ''
  @Trace showTitle: boolean = false
  @Trace pageActionsAvailable: boolean = false
  @Trace sourceReloadAvailable: boolean = false
  @Trace webActionsAvailable: boolean = false
  @Trace linkShareBusy: boolean = false
  @Trace localRefreshAvailable: boolean = false
  @Trace localMetadataAvailable: boolean = false
  @Trace migrationAvailable: boolean = false
  @Trace personalDataAvailable: boolean = false
  @Trace coverActionsAvailable: boolean = false
  @Trace customCoverAvailable: boolean = false
  @Trace personalizationBusy: boolean = false
  @Trace localRefreshBusy: boolean = false
  @Trace requestedAction: MangaDetailTitleAction = MangaDetailTitleAction.RELOAD_SOURCE
  @Trace actionRequestSeq: number = 0

  requestAction(action: MangaDetailTitleAction): void {
    this.requestedAction = action
    this.actionRequestSeq = this.actionRequestSeq + 1
  }
}

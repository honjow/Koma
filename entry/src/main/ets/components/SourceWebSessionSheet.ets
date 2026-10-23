import { webview } from '@kit.ArkWeb'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { hasNewSourceClearance } from '../sourceRuntime/SourceWebChallengeGate'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { AppStrings } from '../i18n/AppStrings'
import { mangaHttpUrl } from '../model/MangaWebLink'
import { appSourceWebSessionStore, sourceWebOrigin, SourceWebSessionStatus } from '../sourceRuntime/SourceWebSessionStore'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { MangaWebView } from './MangaWebView'
import { KomaActionButton } from './ui/KomaActionButton'

/** Host begins/cancels the scoped grant and owns sheet dismissal and request retry. */
@ComponentV2
export struct SourceWebSessionSheet {
  @Param params: MangaWebRouteParam = { url: '', title: '' }
  @Param autoRetryOnClearance: boolean = false
  @Event onCompleted: (status: SourceWebSessionStatus) => void = () => {}
  @Event onClose: () => void = () => {}
  @Local private loading: boolean = true
  @Local private controllerReady: boolean = false
  @Local private canBack: boolean = false
  @Local private canForward: boolean = false
  @Local private completing: boolean = false
  @Local private completed: boolean = false
  private clearanceBaseline: string | undefined = undefined
  private autoRetryStarted: boolean = false
  private pageRevision: number = 0
  private pageUrl: string = ''
  private pageFailed: boolean = false
  private active: boolean = false
  private epoch: number = 0
  private controller: webview.WebviewController = new webview.WebviewController()
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()

  aboutToAppear(): void {
    this.active = true
    this.epoch += 1
  }

  aboutToDisappear(): void {
    this.active = false
    this.epoch += 1
    this.controllerReady = false
    this.clearanceBaseline = undefined
  }

  @Monitor('params')
  private sessionChanged(): void {
    this.epoch += 1
    this.completing = false
    this.completed = false
    this.clearanceBaseline = undefined
    this.autoRetryStarted = false
    this.pageUrl = ''
    this.pageFailed = false
    if (this.active && this.controllerReady) this.loadInitialPage()
  }

  private close(): void {
    if (!this.active) return
    // Invalidate before notifying: cookie persistence may still be awaiting.
    this.active = false
    this.epoch += 1
    this.clearanceBaseline = undefined
    this.onClose()
  }

  private isCurrent(epoch: number, sourceId: string, sessionId: string): boolean {
    return this.active && this.epoch === epoch && this.params.sourceSession?.sourceId === sourceId &&
      this.params.sourceSession?.sessionId === sessionId && !this.completed
  }

  private updateNavState(): void {
    if (!this.active || !this.controllerReady) return
    try {
      this.canBack = this.controller.accessBackward()
      this.canForward = this.controller.accessForward()
    } catch (_error) {
      this.canBack = false
      this.canForward = false
    }
  }

  private loadInitialPage(): void {
    if (!this.active) return
    this.controllerReady = true
    const url = mangaHttpUrl(this.params.url)
    if (url === undefined) {
      this.loading = false
      return
    }
    if (this.autoRetryOnClearance && this.clearanceBaseline === undefined) {
      try { this.clearanceBaseline = webview.WebCookieManager.fetchCookieSync(url, false) }
      catch (_error) { /* Missing baseline disables automatic retry; manual completion remains. */ }
    }
    this.loading = true
    try { this.controller.loadUrl(url) }
    catch (_error) { this.loading = false }
  }

  private navigate(action: string): void {
    if (!this.active || !this.controllerReady || this.completing || this.completed) return
    try {
      if (action === 'back' && this.controller.accessBackward()) this.controller.backward()
      else if (action === 'forward' && this.controller.accessForward()) this.controller.forward()
      else if (action === 'refresh') this.controller.refresh()
    } catch (_error) { this.updateNavState() }
  }

  private pageBegan(event?: OnPageBeginEvent): void {
    if (!this.active) return
    this.pageRevision += 1
    this.pageUrl = event?.url ?? ''
    this.pageFailed = false
    this.loading = true
    this.updateNavState()
  }

  private pageEnded(event?: OnPageEndEvent): void {
    if (!this.active) return
    this.loading = false
    this.updateNavState()
    if (!this.autoRetryOnClearance || this.autoRetryStarted || this.pageFailed ||
      this.clearanceBaseline === undefined || event === undefined || event.url !== this.pageUrl || this.params.sourceSession === undefined) return
    try {
      const currentUrl = this.controller.getUrl()
      const origin = sourceWebOrigin(this.params.url)
      if (origin.length === 0 || sourceWebOrigin(currentUrl) !== origin || currentUrl !== event.url) return
      const cookies = webview.WebCookieManager.fetchCookieSync(this.params.url, false)
      if (!hasNewSourceClearance(this.clearanceBaseline, cookies)) return
      // Candidate only: the host consumes its guarded receipt and retries the exact native request once.
      this.autoRetryStarted = true
      DiagnosticLogger.info('source_web_session', 'clearance_candidate', 'action=retry_original_once')
      void this.completeSourceSession(true)
    } catch (_error) { /* Keep the visible challenge and manual control. No cookie values in diagnostics. */ }
  }

  private mainPageFailed(request: WebResourceRequest): void {
    if (!this.active || !request.isMainFrame() || request.getRequestUrl() !== this.pageUrl) return
    this.pageFailed = true
    this.loading = false
    this.updateNavState()
  }

  private async completeSourceSession(automatic: boolean = false): Promise<void> {
    if (!this.active || !this.controllerReady || this.loading || this.completing || this.completed ||
      this.params.sourceSession === undefined || this.params.sourceSession.sessionId.length === 0) return
    const epoch = this.epoch
    const pageRevision = this.pageRevision
    const sourceId = this.params.sourceSession.sourceId
    const sessionId = this.params.sourceSession.sessionId
    this.completing = true
    try {
      try { webview.WebCookieManager.saveCookieSync() }
      catch (_error) { await webview.WebCookieManager.saveCookieAsync() }
      // Neither a close, unmount nor replacement session may complete an old grant.
      if (!this.isCurrent(epoch, sourceId, sessionId) || !this.controllerReady) return
      if (automatic && (this.pageFailed || this.loading || this.pageRevision !== pageRevision)) return
      const customUa = this.controller.getCustomUserAgent()
      const actualUa = customUa.length > 0 ? customUa : this.controller.getUserAgent()
      const status = appSourceWebSessionStore.complete(sourceId, sessionId, this.controller.getUrl(), actualUa)
      if (status.state !== 'available') throw new Error('session_unavailable')
      this.completed = true
      this.onCompleted(status)
    } catch (_error) {
      if (this.isCurrent(epoch, sourceId, sessionId)) {
        this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_web_session_failed') })
      }
    } finally {
      if (this.active && this.epoch === epoch) this.completing = false
    }
  }

  build() {
    KomaModalScaffold({
      title: this.params.title || AppStrings.get('source_web_open'),
      contentOwnsScrolling: true,
      onClose: () => { this.close() },
    }) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          MangaWebView({
            controller: this.controller,
            onControllerAttached: () => { this.loadInitialPage() },
            onPageBegin: (event?: OnPageBeginEvent) => { this.pageBegan(event) },
            onPageEnd: (event?: OnPageEndEvent) => { this.pageEnded(event) },
            onErrorReceive: (event: OnErrorReceiveEvent) => { this.mainPageFailed(event.request) },
            onHttpErrorReceive: (event: OnHttpErrorReceiveEvent) => { this.mainPageFailed(event.request) },
          })
          if (this.loading) {
            LoadingProgress()
              .width(ThemeConstants.LOADING_SIZE_LARGE)
              .height(ThemeConstants.LOADING_SIZE_LARGE)
              .color(ThemeConstants.BRAND_PRIMARY)
          }
        }
        .width('100%')
        .layoutWeight(1)
        Column({ space: ThemeConstants.SPACE_SM }) {
          Row({ space: ThemeConstants.SPACE_SM }) {
            KomaActionButton({
              label: AppStrings.get('web_nav_back'), icon: $r('sys.symbol.chevron_left'),
              compact: true, fill: true, isEnabled: this.canBack && !this.completing && !this.completed,
              action: () => { this.navigate('back') },
            })
            KomaActionButton({
              label: AppStrings.get('web_nav_forward'), icon: $r('sys.symbol.chevron_right'),
              compact: true, fill: true, isEnabled: this.canForward && !this.completing && !this.completed,
              action: () => { this.navigate('forward') },
            })
            KomaActionButton({
              label: AppStrings.get('web_nav_refresh'), icon: $r('sys.symbol.arrow_clockwise'),
              compact: true, fill: true, isEnabled: this.controllerReady && !this.completing && !this.completed,
              action: () => { this.navigate('refresh') },
            })
          }
          .width('100%')
          KomaActionButton({
            label: AppStrings.get('source_web_complete'), icon: $r('sys.symbol.checkmark'),
            kind: 'primary', fullWidth: true, busy: this.completing,
            isEnabled: this.controllerReady && !this.loading && !this.completed && this.params.sourceSession !== undefined,
            action: () => { void this.completeSourceSession() },
          })
        }
        .width('100%')
        .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG,
          top: ThemeConstants.SPACE_SM, bottom: this.layout.bottomAvoidHeight + ThemeConstants.SPACE_MD })
      }
      .width('100%')
      .height('100%')
    }
  }
}

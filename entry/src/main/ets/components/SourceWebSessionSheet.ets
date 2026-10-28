import { webview } from '@kit.ArkWeb'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { hasNewSourceClearance, sourceClearanceCookieState } from '../sourceRuntime/SourceWebChallengeGate'
import { cancelSourceWebProbe, probeSourceWebSession, sourceRejectedRequestUserAgent } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { AppStrings } from '../i18n/AppStrings'
import { mangaHttpUrl } from '../model/MangaWebLink'
import { appSourceWebSessionStore, readSourceWebCookies, sourceWebOrigin, SourceWebSessionStatus } from '../sourceRuntime/SourceWebSessionStore'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { MangaWebView } from './MangaWebView'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaIconButton } from './ui/KomaIconButton'

/** Host begins/cancels the scoped grant and owns sheet dismissal and request retry. */
@ComponentV2
export struct SourceWebSessionSheet {
  @Param params: MangaWebRouteParam = { url: '', title: '' }
  @Param autoRetryOnClearance: boolean = false
  @Event canProbeOriginal: () => boolean = (): boolean => false
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
  private pageHttpStatus: number = 0
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
    const session = this.params.sourceSession
    if (!this.completed && session !== undefined) cancelSourceWebProbe(session.sourceId, session.sessionId)
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
    this.pageHttpStatus = 0
    if (this.active && this.controllerReady) this.loadInitialPage()
  }

  private close(): void {
    if (!this.active) return
    // Invalidate before notifying: cookie persistence may still be awaiting.
    this.active = false
    this.epoch += 1
    this.clearanceBaseline = undefined
    const session = this.params.sourceSession
    if (session !== undefined) cancelSourceWebProbe(session.sourceId, session.sessionId)
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
    const session = this.params.sourceSession
    if (session?.requestHandle !== undefined) {
      const requestUa = sourceRejectedRequestUserAgent(session.sourceId, session.requestHandle, url)
      if (requestUa !== undefined) {
        try { this.controller.setCustomUserAgent(requestUa) }
        catch (_error) {
          // Do not load or complete a session under a different identity.
          this.controllerReady = false
          this.loading = false
          DiagnosticLogger.warn('source_web_session', 'identity_setup_failed', 'stage=set_user_agent')
          this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_web_session_failed') })
          return
        }
      }
    }
    if (this.autoRetryOnClearance && this.clearanceBaseline === undefined) {
      try { this.clearanceBaseline = readSourceWebCookies(url) }
      catch (_error) { /* Missing baseline disables automatic retry; manual completion remains. */ }
    }
    try {
      const nativeUa = this.controller.getUserAgent()
      const customUa = this.controller.getCustomUserAgent()
      DiagnosticLogger.info('source_web_session', 'engine_context',
        'nativeOpenHarmony=' + nativeUa.includes('OpenHarmony') +
        ' nativeAndroid=' + nativeUa.includes('Android') + ' customUaPresent=' + (customUa.length > 0) + ' customUaEqualsNative=' + (customUa === nativeUa))
    } catch (_error) {
      DiagnosticLogger.info('source_web_session', 'engine_context', 'state=unavailable')
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

  private navigationRequested(event: OnLoadInterceptEvent): boolean {
    if (!this.active || !event.data.isMainFrame()) return false
    this.pageRevision += 1
    this.pageUrl = event.data.getRequestUrl()
    this.pageFailed = false
    this.pageHttpStatus = 0
    this.loading = true
    DiagnosticLogger.info('source_web_session', 'navigation_requested', 'revision=' + this.pageRevision)
    this.updateNavState()
    return false
  }

  private pageBegan(event?: OnPageBeginEvent): void {
    if (!this.active) return
    // ArkWeb may report the main HTTP failure before onPageBegin. Only the
    // next main-frame request may reset it, never this later display callback.
    if (this.pageUrl !== (event?.url ?? '')) this.pageRevision += 1
    this.pageUrl = event?.url ?? ''
    this.loading = true
    DiagnosticLogger.info('source_web_session', 'document_begin',
      'revision=' + this.pageRevision + ' sameRequestDocument=' + (this.pageUrl === this.params.url) +
      ' sameRequestOrigin=' + (sourceWebOrigin(this.pageUrl) === sourceWebOrigin(this.params.url)))
    this.updateNavState()
  }

  private pageEnded(event?: OnPageEndEvent): void {
    if (!this.active) return
    this.loading = false
    this.updateNavState()
    // Record gate facts only: URLs, cookie values and session identifiers stay private.
    DiagnosticLogger.info('source_web_session', 'document_end',
      'revision=' + this.pageRevision + ' automatic=' + this.autoRetryOnClearance + ' attempted=' + this.autoRetryStarted +
      ' failed=' + this.pageFailed + ' baselineKnown=' + (this.clearanceBaseline !== undefined) +
      ' matchingDocument=' + (event !== undefined && event.url === this.pageUrl) +
      ' sessionPresent=' + (this.params.sourceSession !== undefined))
    if (!this.autoRetryOnClearance || this.autoRetryStarted ||
      this.clearanceBaseline === undefined || event === undefined || event.url !== this.pageUrl || this.params.sourceSession === undefined) return
    try {
      const currentUrl = this.controller.getUrl()
      const origin = sourceWebOrigin(this.params.url)
      if (origin.length === 0 || sourceWebOrigin(currentUrl) !== origin || currentUrl !== event.url) {
        DiagnosticLogger.info('source_web_session', 'automatic_wait', 'reason=document_origin_mismatch')
        return
      }
      const cookies = readSourceWebCookies(this.params.url)
      try {
        const currentCookies = currentUrl === this.params.url ? cookies :
          readSourceWebCookies(currentUrl)
        DiagnosticLogger.info('source_web_session', 'cookie_context',
          'firstPartyAllowed=' + webview.WebCookieManager.isCookieAllowed() +
          ' thirdPartyAllowed=' + webview.WebCookieManager.isThirdPartyCookieAllowed() +
          ' sameRequestUrl=' + (currentUrl === this.params.url) +
          ' requestCookiePresent=' + (cookies.length > 0) + ' currentCookiePresent=' + (currentCookies.length > 0) +
          ' baselineClearance=' + sourceClearanceCookieState(this.clearanceBaseline) +
          ' requestClearance=' + sourceClearanceCookieState(cookies) +
          ' currentClearance=' + sourceClearanceCookieState(currentCookies))
      } catch (_error) {
        DiagnosticLogger.info('source_web_session', 'cookie_context', 'state=unavailable')
      }
      const changedClearance = hasNewSourceClearance(this.clearanceBaseline, cookies)
      // mh160 may solve CF, then redirect its mobile browser to a broken search
      // landing page (CURRENT_STATUS SOURCE_WEB_SESSION,197599–605). The exact
      // original GET recovered with that session while the landing was404.
      // A same-origin404 is only permission to
      // probe once with a present clearance; it can never grant a session itself.
      const failedLanding = this.pageFailed && this.pageHttpStatus === 404 && currentUrl !== this.params.url &&
        this.canProbeOriginal() && sourceClearanceCookieState(cookies) === 'present'
      if (this.pageFailed && !failedLanding) return
      // A claimed native challenge may open an already-working Web session.
      // No Web403 or cookie change is required to test that original read once;
      // the pending native probe, not this document, must establish success.
      const needsNativeProbe = failedLanding || (!changedClearance && this.canProbeOriginal() && currentUrl === this.params.url &&
        sourceClearanceCookieState(this.clearanceBaseline) === 'missing' && sourceClearanceCookieState(cookies) === 'missing')
      if (!changedClearance && !needsNativeProbe) {
        DiagnosticLogger.info('source_web_session', 'automatic_wait',
          'reason=' + (hasNewSourceClearance('', cookies) ? 'unchanged_clearance' : 'no_clearance'))
        return
      }
      this.autoRetryStarted = true
      DiagnosticLogger.info('source_web_session', needsNativeProbe ? 'native_probe_candidate' : 'clearance_candidate',
        needsNativeProbe ? 'action=validate_original_get_once' : 'action=retry_original_once')
      void this.completeSourceSession(true, needsNativeProbe, failedLanding)
    } catch (_error) { /* Keep the visible challenge and manual control. No cookie values in diagnostics. */ }
  }

  private consoleMessage(event: OnConsoleEvent): boolean {
    if (!this.active) return false
    // Only a standard challenge error code may enter the log, never arbitrary page output.
    const code = /\[Cloudflare Turnstile\] Error: ([0-9]{6})(?![0-9])/.exec(event.message.getMessage())
    if (code !== null) DiagnosticLogger.info('source_web_session', 'challenge_console', 'code=' + code[1])
    return false
  }

  private resourceFailed(request: WebResourceRequest, kind: string, code: number): void {
    if (!this.active) return
    if (request.isMainFrame() && request.getRequestUrl() === this.pageUrl) {
      this.pageHttpStatus = kind === 'http' ? code : 0
    }
    DiagnosticLogger.info('source_web_session', 'resource_failed',
      'revision=' + this.pageRevision + ' kind=' + kind + ' code=' + code + ' mainFrame=' + request.isMainFrame() +
      ' matchingDocument=' + (request.getRequestUrl() === this.pageUrl) +
      ' challengeHost=' + (sourceWebOrigin(request.getRequestUrl()) === 'https://challenges.cloudflare.com'))
    this.mainPageFailed(request)
  }

  private mainPageFailed(request: WebResourceRequest): void {
    if (!this.active || !request.isMainFrame() || request.getRequestUrl() !== this.pageUrl) return
    this.pageFailed = true
    this.loading = false
    this.updateNavState()
  }

  private async completeSourceSession(automatic: boolean = false, needsNativeProbe: boolean = false,
    failedLanding: boolean = false): Promise<void> {
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
      const canProbeFailedLanding = automatic && needsNativeProbe && failedLanding
      if (automatic && ((this.pageFailed && !canProbeFailedLanding) || this.loading || this.pageRevision !== pageRevision)) return
      const customUa = this.controller.getCustomUserAgent()
      const actualUa = customUa.length > 0 ? customUa : this.controller.getUserAgent()
      if (automatic && needsNativeProbe) {
        if (!this.canProbeOriginal()) return
        const current = (): boolean => this.isCurrent(epoch, sourceId, sessionId) && this.canProbeOriginal() &&
          !this.loading && this.pageRevision === pageRevision &&
          (!this.pageFailed || (canProbeFailedLanding && this.pageHttpStatus === 404))
        const ready = await probeSourceWebSession(sourceId, sessionId, this.controller.getUrl(), actualUa, current,
          this.params.sourceSession?.requestHandle)
        if (!ready || !current()) {
          DiagnosticLogger.info('source_web_session', 'automatic_wait', 'reason=native_probe_not_ready')
          return
        }
      }
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
            onLoadIntercept: (event: OnLoadInterceptEvent): boolean => { return this.navigationRequested(event) },
            onPageBegin: (event?: OnPageBeginEvent) => { this.pageBegan(event) },
            onPageEnd: (event?: OnPageEndEvent) => { this.pageEnded(event) },
            onConsole: (event: OnConsoleEvent): boolean => { return this.consoleMessage(event) },
            onErrorReceive: (event: OnErrorReceiveEvent) => {
              this.resourceFailed(event.request, 'transport', event.error.getErrorCode())
            },
            onHttpErrorReceive: (event: OnHttpErrorReceiveEvent) => {
              this.resourceFailed(event.request, 'http', event.response.getResponseCode())
            },
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
        // User rejected the two-row button stack: navigation and completion share
        // one compact toolbar. Keep verification, dismissal and retry ownership above.
        Row({ space: ThemeConstants.SPACE_SM }) {
          KomaIconButton({
            icon: $r('sys.symbol.chevron_left'), controlSize: ThemeConstants.BUTTON_HEIGHT,
            isEnabled: this.canBack && !this.completing && !this.completed,
            action: () => { this.navigate('back') },
          })
          .accessibilityText(AppStrings.get('web_nav_back'))
          KomaIconButton({
            icon: $r('sys.symbol.chevron_right'), controlSize: ThemeConstants.BUTTON_HEIGHT,
            isEnabled: this.canForward && !this.completing && !this.completed,
            action: () => { this.navigate('forward') },
          })
          .accessibilityText(AppStrings.get('web_nav_forward'))
          KomaIconButton({
            icon: $r('sys.symbol.arrow_clockwise'), controlSize: ThemeConstants.BUTTON_HEIGHT,
            isEnabled: this.controllerReady && !this.completing && !this.completed,
            action: () => { this.navigate('refresh') },
          })
          .accessibilityText(AppStrings.get('web_nav_refresh'))
          Blank()
            .layoutWeight(1)
          KomaActionButton({
            label: AppStrings.get('source_web_complete'), icon: $r('sys.symbol.checkmark'),
            kind: 'primary', compact: true, busy: this.completing,
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

import { komaToastOptions } from '../theme/KomaPopupOptions'
import { webview } from '@kit.ArkWeb'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { hasNewSourceClearance, sourceClearanceCookieState } from '../sourceRuntime/SourceWebChallengeGate'
import { cancelSourceWebDocument, cancelSourceWebProbe, probeSourceWebSession, sourceRejectedRequestUserAgent,
  stageSourceWebDocument } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { renderedDocumentFallbackEnabled as sourceRenderedDocumentFallbackEnabled,
  renderedDocumentReadySelector } from '../sourceRuntime/SourceWebsitePolicy'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { AppStrings } from '../i18n/AppStrings'
import { mangaHttpUrl } from '../model/MangaWebLink'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
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
  private autoDocumentAttempt: number = 0
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
    if (!this.completed && session !== undefined) {
      cancelSourceWebProbe(session.sourceId, session.sessionId)
      cancelSourceWebDocument(session.sourceId, session.sessionId)
    }
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
    const session = this.params.sourceSession
    if (session !== undefined) cancelSourceWebDocument(session.sourceId, session.sessionId)
    if (this.active && this.controllerReady) this.loadInitialPage()
  }

  private close(): void {
    if (!this.active) return
    // Invalidate before notifying: cookie persistence may still be awaiting.
    this.active = false
    this.epoch += 1
    this.clearanceBaseline = undefined
    const session = this.params.sourceSession
    if (session !== undefined) {
      cancelSourceWebProbe(session.sourceId, session.sessionId)
      cancelSourceWebDocument(session.sourceId, session.sessionId)
    }
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
    // Cloudflare Turnstile runs in a cross-origin iframe; its cookies must be accepted.
    try {
      webview.WebCookieManager.putAcceptCookieEnabled(true)
      webview.WebCookieManager.putAcceptThirdPartyCookieEnabled(true)
    } catch (_error) {}
    const url = mangaHttpUrl(this.params.url)
    if (url === undefined) {
      this.loading = false
      return
    }
    const session = this.params.sourceSession
    const loginUserAgent = session === undefined ? undefined :
      appSourceWebSessionStore.pendingLoginUserAgent(session.sourceId, session.sessionId)
    const declaredWebUserAgent = session === undefined ? undefined :
      appSourceRuntimeRegistry.lookup(session.sourceId).entry?.websitePolicy?.webSessionUserAgent
    const androidWebAgent = session === undefined ? false :
      appSourceRuntimeRegistry.lookup(session.sourceId).entry?.websitePolicy?.webSessionAndroidAgent === true
    if (androidWebAgent) {
      try {
        const native = this.controller.getUserAgent()
        this.controller.setCustomUserAgent(native.replace(') AppleWebKit', '; Android 10) AppleWebKit'))
      } catch (_error) {
        this.controllerReady = false
        this.loading = false
        DiagnosticLogger.warn('source_web_session', 'identity_setup_failed', 'stage=set_android_user_agent')
        this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_session_failed') }))
        return
      }
    }
    if (declaredWebUserAgent !== undefined && declaredWebUserAgent.length > 0 && !androidWebAgent) {
      try { this.controller.setCustomUserAgent(declaredWebUserAgent) }
      catch (_error) {
        this.controllerReady = false
        this.loading = false
        DiagnosticLogger.warn('source_web_session', 'identity_setup_failed', 'stage=set_declared_user_agent')
        this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_session_failed') }))
        return
      }
    }
    if (loginUserAgent !== undefined) {
      try { this.controller.setCustomUserAgent(loginUserAgent) }
      catch (_error) {
        this.controllerReady = false; this.loading = false
        this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_session_failed') }))
        return
      }
    }
    if (session?.requestHandle !== undefined && declaredWebUserAgent === undefined && !androidWebAgent) {
      const requestUa = sourceRejectedRequestUserAgent(session.sourceId, session.requestHandle, url)
      // Explicitly reset the UA when the verified package declares the system
      // identity for this origin. Unified search can reuse this controller.
      const useEngineIdentity = appSourceRuntimeRegistry.lookup(session.sourceId).entry?.websitePolicy
        ?.systemWebAgentOrigins?.includes(sourceWebOrigin(url)) === true
      if (requestUa !== undefined || useEngineIdentity) {
        try {
          const userAgent = useEngineIdentity ? this.controller.getUserAgent() : requestUa
          if (userAgent !== undefined) this.controller.setCustomUserAgent(userAgent)
        }
        catch (_error) {
          // Do not load or complete a session under a different identity.
          this.controllerReady = false
          this.loading = false
          DiagnosticLogger.warn('source_web_session', 'identity_setup_failed', 'stage=set_user_agent')
          this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_session_failed') }))
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
    const endedSession = this.params.sourceSession
    if (endedSession !== undefined && event !== undefined && event.url === this.pageUrl && !this.pageFailed) {
      void this.autoCompleteRenderedDocument(this.epoch, endedSession.sourceId, endedSession.sessionId)
    }
    // A declared readiness selector owns automatic completion; clearance/probe
    // remains the path for sources that only declare the boolean fallback.
    if (renderedDocumentReadySelector(endedSession === undefined ? undefined :
      appSourceRuntimeRegistry.lookup(endedSession.sourceId).entry?.websitePolicy).length > 0) return
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
      ' matchingDocument=' + (request.getRequestUrl() === this.pageUrl))
    this.mainPageFailed(request)
  }

  private mainPageFailed(request: WebResourceRequest): void {
    if (!this.active || !request.isMainFrame() || request.getRequestUrl() !== this.pageUrl) return
    this.pageFailed = true
    this.loading = false
    this.updateNavState()
  }

  private renderedDocumentFallbackEnabled(sourceId: string): boolean {
    return sourceRenderedDocumentFallbackEnabled(appSourceRuntimeRegistry.lookup(sourceId).entry?.websitePolicy)
  }

  private webFetchBridgeEnabled(sourceId: string): boolean {
    return appSourceRuntimeRegistry.lookup(sourceId).entry?.websitePolicy?.webFetchBridge === true
  }

  /** Probe one same-origin in-page fetch to prove the WebView session can serve reads. */
  private async probeWebViewFetch(sourceId: string): Promise<void> {
    if (!this.webFetchBridgeEnabled(sourceId)) return
    try {
      const started = await this.controller.runJavaScript(
        "(() => { try { const a = document.querySelector('div.grid > div.group a'); if (!a) return 'no-link'; const url = a.href; fetch(url, { credentials: 'include' }).then(async (r) => { const t = await r.text(); window.__komaWebFetch = JSON.stringify({ status: r.status, length: t.length }); }).catch(() => { window.__komaWebFetch = JSON.stringify({ status: -1, length: 0 }); }); return 'started'; } catch (e) { return 'error'; } })()")
      if (this.decodeJavaScriptString(started) !== 'started') {
        DiagnosticLogger.info('source_web_session', 'web_fetch_probe', 'state=' + String(started).slice(0, 16))
        return
      }
      for (let index = 0; index < 20; index += 1) {
        await this.delay(500)
        const rawValue = await this.controller.runJavaScript('window.__komaWebFetch || ""')
        const raw = typeof rawValue === 'string' ? this.decodeJavaScriptString(rawValue) : ''
        if (raw.length > 0) {
          try {
            const parsed = JSON.parse(raw) as Record<string, Object>
            DiagnosticLogger.info('source_web_session', 'web_fetch_probe',
              'status=' + String(parsed['status']) + ' length=' + String(parsed['length']))
          } catch (_error) {}
          return
        }
      }
      DiagnosticLogger.info('source_web_session', 'web_fetch_probe', 'state=timeout')
    } catch (_error) {
      DiagnosticLogger.info('source_web_session', 'web_fetch_probe', 'state=failed')
    }
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void): void => {
      setTimeout((): void => { resolve() }, milliseconds)
    })
  }

  private decodeJavaScriptString(raw: string): string {
    if (!raw.startsWith('"')) return raw
    try { return JSON.parse(raw) as string } catch (_error) { return raw }
  }

  private async renderedDocumentReady(selector: string): Promise<boolean> {
    try {
      const raw = await this.controller.runJavaScript(
        "(() => { try { return document.querySelector(" + JSON.stringify(selector) + ") !== null } catch (e) { return false } })()")
      if (typeof raw !== 'string' || raw.length === 0 || raw.length > 16) return false
      if (raw === 'true' || raw === '"true"') return true
      return JSON.parse(raw) === true
    } catch (_error) {
      return false
    }
  }

  /** Close the verification sheet only after the declared content actually exists. */
  private async autoCompleteRenderedDocument(epoch: number, sourceId: string, sessionId: string): Promise<void> {
    const policy = appSourceRuntimeRegistry.lookup(sourceId).entry?.websitePolicy
    const selector = renderedDocumentReadySelector(policy)
    if (selector.length === 0 || this.autoRetryStarted || this.loading || this.pageFailed || this.completing ||
      this.completed) return
    const attempt = this.autoDocumentAttempt + 1
    this.autoDocumentAttempt = attempt
    for (let index = 0; index < 4; index += 1) {
      if (!this.isCurrent(epoch, sourceId, sessionId) || this.autoRetryStarted || this.loading ||
        this.pageFailed || this.completing || this.autoDocumentAttempt !== attempt) return
      if (await this.renderedDocumentReady(selector)) {
        this.autoRetryStarted = true
        await this.completeSourceSession(true, false, false, true)
        return
      }
      await this.delay(600)
    }
  }

  /** Capture only the visible requested document; no source JS, cookies or other tabs. */
  private async stageRenderedDocument(epoch: number, sourceId: string, sessionId: string): Promise<boolean> {
    const session = this.params.sourceSession
    const requestHandle = session?.requestHandle
    const policyEnabled = this.renderedDocumentFallbackEnabled(sourceId)
    if (requestHandle === undefined || !policyEnabled || this.pageFailed || this.loading) {
      DiagnosticLogger.info('source_web_session', 'document_capture_blocked',
        'reason=' + (requestHandle === undefined ? 'no_request_handle' : !policyEnabled ? 'policy_disabled' :
          this.pageFailed ? 'page_failed' : 'loading') + ' revision=' + this.pageRevision)
      return false
    }
    try {
      const raw = await this.controller.runJavaScript(
        "(() => { try { return JSON.stringify({url: location.href, type: document.contentType || '', ready: document.readyState, html: document.documentElement ? document.documentElement.outerHTML : ''}) } catch (e) { return '' } })()")
      if (!this.isCurrent(epoch, sourceId, sessionId) || typeof raw !== 'string' ||
        raw.length === 0 || raw.length > 4 * 1024 * 1024) {
        DiagnosticLogger.info('source_web_session', 'document_capture_blocked',
          'reason=result_invalid current=' + this.isCurrent(epoch, sourceId, sessionId) +
          ' string=' + (typeof raw === 'string') + ' length=' + (typeof raw === 'string' ? raw.length : -1))
        return false
      }
      // ArkWeb returns the script value as JSON. A script that already returns
      // a JSON string is encoded once more, so decode until a plain object is
      // reached instead of silently reading an empty document.
      let decoded: Object = JSON.parse(raw) as Object
      let nested = false
      if (typeof decoded === 'string') {
        decoded = JSON.parse(decoded as string) as Object
        nested = true
      }
      if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) {
        DiagnosticLogger.info('source_web_session', 'document_capture_blocked',
          'reason=decoded_invalid nested=' + nested + ' rawLength=' + raw.length)
        return false
      }
      const parsed = decoded as Record<string, Object>
      const url = typeof parsed['url'] === 'string' ? parsed['url'] as string : ''
      const type = typeof parsed['type'] === 'string' ? (parsed['type'] as string).toLowerCase() : ''
      const ready = parsed['ready'] === 'complete' || parsed['ready'] === 'interactive'
      const html = typeof parsed['html'] === 'string' ? parsed['html'] as string : ''
      if (!ready || html.length === 0 || html.length > 2 * 1024 * 1024) {
        DiagnosticLogger.info('source_web_session', 'document_capture_blocked',
          'reason=' + (!ready ? 'not_ready' : 'html_size') + ' bytes=' + html.length +
          ' nested=' + nested + ' rawLength=' + raw.length)
        return false
      }
      if (type.length > 0 && !type.includes('text/html') && !type.includes('application/xhtml+xml')) {
        DiagnosticLogger.info('source_web_session', 'document_capture_blocked', 'reason=content_type')
        return false
      }
      const staged = stageSourceWebDocument(sourceId, sessionId, requestHandle, url, html)
      DiagnosticLogger.info('source_web_session', 'document_handoff',
        'state=' + (staged ? 'staged' : 'rejected') + ' bytes=' + html.length +
        ' sameRequest=' + (url === this.params.url))
      if (staged) await this.probeWebViewFetch(sourceId)
      return staged
    } catch (_error) {
      DiagnosticLogger.warn('source_web_session', 'document_capture_failed', 'stage=run_javascript')
      return false
    }
  }

  private async completeSourceSession(automatic: boolean = false, needsNativeProbe: boolean = false,
    failedLanding: boolean = false, documentReady: boolean = false): Promise<void> {
    DiagnosticLogger.info('source_web_session', 'complete_enter',
      'automatic=' + automatic + ' loading=' + this.loading + ' completing=' + this.completing +
      ' completed=' + this.completed + ' controllerReady=' + this.controllerReady +
      ' failed=' + this.pageFailed + ' revision=' + this.pageRevision +
      ' sessionPresent=' + (this.params.sourceSession !== undefined))
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
      let documentStaged = false
      if (this.renderedDocumentFallbackEnabled(sourceId) && (!automatic || documentReady)) {
        const staged = await this.stageRenderedDocument(epoch, sourceId, sessionId)
        documentStaged = staged
        if (!staged && !automatic) {
          if (this.isCurrent(epoch, sourceId, sessionId)) {
            this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_session_failed') }))
          }
          return
        }
      }
      if (automatic && needsNativeProbe && !documentStaged) {
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
      try {
        const completedCookies = readSourceWebCookies(this.controller.getUrl())
        DiagnosticLogger.info('source_web_session', 'clearance_after_complete',
          'state=' + sourceClearanceCookieState(completedCookies) +
          ' cookiePresent=' + (completedCookies.length > 0))
      } catch (_error) {}
      this.completed = true
      this.onCompleted(status)
    } catch (_error) {
      if (this.isCurrent(epoch, sourceId, sessionId)) {
        this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_web_session_failed') }))
      }
    } finally {
      if (this.active && this.epoch === epoch) this.completing = false
    }
  }

  build() {
    KomaModalScaffold({
      title: this.params.title || AppStrings.get('source_web_open'),
      // The website owns its viewport; only the bottom toolbar has an inset.
      contentHorizontalPadding: 0,
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
            action: () => {
              DiagnosticLogger.info('source_web_session', 'complete_pressed',
                'loading=' + this.loading + ' completing=' + this.completing + ' completed=' + this.completed +
                ' controllerReady=' + this.controllerReady + ' sessionPresent=' + (this.params.sourceSession !== undefined))
              void this.completeSourceSession()
            },
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

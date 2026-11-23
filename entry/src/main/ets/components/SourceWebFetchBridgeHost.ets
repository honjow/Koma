import { webview } from '@kit.ArkWeb'
import { SOURCE_WEB_FETCH_BRIDGE_REQUEST_KEY, sourceWebFetchBridge } from '../sourceRuntime/SourceWebFetchBridge'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { appSourceWebSessionStore, SourceWebRequestContext, sourceWebPackageIdentity, sourceWebOrigin } from '../sourceRuntime/SourceWebSessionStore'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

/**
 * One application-scoped hidden WebView for sources that grant webFetchBridge.
 *
 * It lives beside the root navigation instead of inside SourceBrowsePage so a
 * bridged session survives leaving browse. History and shelf reader entries
 * can then prepare the same session before asking the source runtime to read.
 */
@Component
export struct SourceWebFetchBridgeHost {
  @StorageLink(SOURCE_WEB_FETCH_BRIDGE_REQUEST_KEY) @Watch('onRequestChanged') request: string = ''
  private controller: webview.WebviewController = new webview.WebviewController()
  private attached: boolean = false
  private loadingSourceId: string = ''
  private loadedUrl: string = ''
  private handledRequest: string = ''
  private loadedPackageIdentity: string = ''
  private loadedAuthorizationRevision: number = 0
  // TEMP R10 observation only; remove after collection, before release. These
  // counters never participate in bridge readiness, authorization or navigation.
  private diagnosticNavigation: number = 0
  private diagnosticAttempt: number = -1

  onRequestChanged(): void {
    this.loadRequestedPage()
  }

  private requestContext(sourceId: string, url: string): SourceWebRequestContext | undefined {
    const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
    if (entry?.websitePolicy?.webFetchBridge !== true) return undefined
    return appSourceWebSessionStore.requestContext({ sourceId,
      sourceVersion: entry.manifestVersion, packageIdentity: sourceWebPackageIdentity(entry),
      webSessionOrigins: entry.webSessionOrigins ?? [] }, url)
  }

  private loadRequestedPage(): void {
    if (!this.attached || this.request.length === 0 || this.request === this.handledRequest) return
    let parsed: Record<string, Object> | undefined = undefined
    try {
      parsed = JSON.parse(this.request) as Record<string, Object>
    } catch (_error) {
      return
    }
    const sourceId = typeof parsed['sourceId'] === 'string' ? parsed['sourceId'] as string : ''
    const url = typeof parsed['url'] === 'string' ? parsed['url'] as string : ''
    if (sourceId.length === 0 || url.length === 0) return
    this.handledRequest = this.request
    const context = this.requestContext(sourceId, url)
    if (context === undefined) return
    const userAgent = context.userAgent
    const authorizationRevision = context.authorizationRevision
    if (this.loadedUrl === url && sourceWebFetchBridge.availableFor(sourceId, url, userAgent, authorizationRevision)) return
    this.loadingSourceId = sourceId
    const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
    if (entry === undefined) return
    this.loadedPackageIdentity = sourceWebPackageIdentity(entry)
    this.loadedAuthorizationRevision = authorizationRevision
    this.diagnosticNavigation += 1
    sourceWebFetchBridge.attach(this.controller, sourceId, url, userAgent, authorizationRevision)
    this.loadedUrl = url
    try {
      // The visible verifier owns the agent decision. Reuse its exact granted
      // agent before loading; recomputing an ArkWeb default breaks that session.
      this.controller.setCustomUserAgent(userAgent)
      this.controller.loadUrl(url)
    } catch (_error) {
      // A rejected navigation leaves the bridge unavailable; callers fail closed.
    }
  }

  aboutToDisappear(): void {
    this.diagnosticNavigation += 1
    this.attached = false
    sourceWebFetchBridge.detach(this.loadingSourceId)
  }

  private documentVisible(documentUrl: string): void {
    if (!this.attached || this.loadingSourceId.length === 0) return
    try {
      if (documentUrl !== this.controller.getUrl()) return
      const agent = this.controller.getCustomUserAgent()
      const context = this.requestContext(this.loadingSourceId, this.loadedUrl)
      const entry = appSourceRuntimeRegistry.lookup(this.loadingSourceId).entry
      if (context === undefined || entry === undefined ||
        sourceWebPackageIdentity(entry) !== this.loadedPackageIdentity ||
        context.authorizationRevision !== this.loadedAuthorizationRevision) {
        sourceWebFetchBridge.detach(this.loadingSourceId)
        return
      }
      sourceWebFetchBridge.markReady(this.loadingSourceId, documentUrl, agent, context.authorizationRevision)
      DiagnosticLogger.info('source_web_fetch', 'host_document',
        'sameOrigin=' + (sourceWebOrigin(documentUrl) === sourceWebOrigin(this.loadedUrl)) +
        'ready=' + sourceWebFetchBridge.availableFor(this.loadingSourceId, this.loadedUrl, agent, context.authorizationRevision))
      void this.observeContext(documentUrl, context.userAgent)
    } catch (_error) { /* Detached controllers cannot publish readiness. */ }
  }

  /** TEMP R10: one bounded, read-only sample after markReady. Never wait for it
   * to authorize a request; never export raw browser/page/session material.
   */
  private async observeContext(documentUrl: string, grantedAgent: string): Promise<void> {
    const navigation = this.diagnosticNavigation
    if (this.diagnosticAttempt === navigation) return
    this.diagnosticAttempt = navigation
    const sourceId = this.loadingSourceId
    const packageIdentity = this.loadedPackageIdentity
    const authorizationRevision = this.loadedAuthorizationRevision
    const loadedUrl = this.loadedUrl
    const expectedOrigin = sourceWebOrigin(loadedUrl)
    const entry = appSourceRuntimeRegistry.lookup(sourceId).entry
    const selector = entry?.websitePolicy?.webSessionReadySelector ?? ''
    const deadline = Date.now() + 600
    try {
      const script = "(() => { const s=" + JSON.stringify(selector) + "; let selected=false; " +
        "try { selected=!!s && !!document.querySelector(s); } catch(e) {} " +
        "const v=window.visualViewport; return JSON.stringify({ua:navigator.userAgent===" + JSON.stringify(grantedAgent) +
        ",origin:location.origin===" + JSON.stringify(expectedOrigin) +
        ",iw:innerWidth,ih:innerHeight,vw:v?v.width:-1,vh:v?v.height:-1,vs:v?v.scale:-1,dpr:devicePixelRatio," +
        "visibility:document.visibilityState,declared:!!s,selected," +
        "cfDom:!!document.querySelector('#challenge-running,#challenge-stage,#challenge-form,.cf-turnstile,iframe[src*=\"challenges.cloudflare.com\"]')," +
        "cfOpt:typeof window._cf_chl_opt!=='undefined'}); })()"
      const raw = await new Promise<string>((resolve: (value: string) => void): void => {
        let finished = false
        const finish = (value: string): void => {
          if (finished) return
          finished = true
          clearTimeout(timer)
          resolve(value)
        }
        const timer = setTimeout((): void => finish(''), 600)
        try { this.controller.runJavaScript(script).then((value: string): void => finish(value), (): void => finish('')) }
        catch (_error) { finish('') }
      })
      if (Date.now() >= deadline || raw.length === 0 || raw.length > 2048 || !this.attached ||
        navigation !== this.diagnosticNavigation || sourceId !== this.loadingSourceId ||
        packageIdentity !== this.loadedPackageIdentity || loadedUrl !== this.loadedUrl ||
        authorizationRevision !== this.loadedAuthorizationRevision || documentUrl !== this.controller.getUrl()) return
      const current = this.requestContext(sourceId, loadedUrl)
      const currentEntry = appSourceRuntimeRegistry.lookup(sourceId).entry
      if (current === undefined || currentEntry === undefined || sourceWebPackageIdentity(currentEntry) !== packageIdentity ||
        current.authorizationRevision !== authorizationRevision || current.userAgent !== grantedAgent) return
      let decoded: Object = JSON.parse(raw) as Object
      if (typeof decoded === 'string') decoded = JSON.parse(decoded) as Object
      if (decoded === null || typeof decoded !== 'object' || Array.isArray(decoded)) return
      const value = decoded as Record<string, Object>
      const number = (key: string, max: number): number => {
        const item = value[key]
        return typeof item === 'number' && Number.isFinite(item) && item >= 0 && item <= max ? Math.round(item * 100) / 100 : -1
      }
      const visibility = ['visible', 'hidden', 'prerender'].includes(value['visibility'] as string) ? value['visibility'] as string : 'unknown'
      DiagnosticLogger.info('source_web_fetch', 'context_diag', 'n=' + navigation +
        ' ua=' + (value['ua'] === true) + ' org=' + (value['origin'] === true) +
        ' iw=' + number('iw', 100000) + ' ih=' + number('ih', 100000) +
        ' vw=' + number('vw', 100000) + ' vh=' + number('vh', 100000) +
        ' vs=' + number('vs', 20) + ' dpr=' + number('dpr', 20) + ' vis=' + visibility)
      DiagnosticLogger.info('source_web_fetch', 'context_marks', 'n=' + navigation +
        ' declared=' + (value['declared'] === true) + ' selector=' + (value['selected'] === true) +
        ' cfDom=' + (value['cfDom'] === true) + ' cfOpt=' + (value['cfOpt'] === true))
    } catch (_error) { /* Diagnostic timeout/errors cannot change the bridge or surface page material. */ }
  }

  build() {
    // The first request mounts ArkWeb. Keep it mounted thereafter so moving
    // between browse, history and the reader preserves the granted session.
    if (this.request.length > 0) {
      Web({ src: '', controller: this.controller })
        .width(1)
        .height(1)
        .opacity(0)
        .position({ x: 0, y: 0 })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onControllerAttached(() => {
          this.attached = true
          this.loadRequestedPage()
        })
        .onPageBegin(() => {
          this.diagnosticNavigation += 1
          sourceWebFetchBridge.markLoading(this.loadingSourceId)
        })
        // A committed same-origin document is enough to execute fetch. Waiting
        // for third-party ads/images to end can exceed the bridge's own timeout.
        .onPageVisible((event: OnPageVisibleEvent) => { this.documentVisible(event.url) })
        .onPageEnd((event: OnPageEndEvent) => { this.documentVisible(event.url) })
    }
  }
}

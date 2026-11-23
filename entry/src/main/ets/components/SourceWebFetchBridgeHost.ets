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
    this.attached = false
    sourceWebFetchBridge.detach(this.loadingSourceId)
  }

  private documentVisible(documentUrl: string): void {
    if (!this.attached || this.loadingSourceId.length === 0) return
    try {
      if (documentUrl !== this.controller.getUrl()) return
      const agent = this.controller.getCustomUserAgent()
      const context = this.requestContext(this.loadingSourceId, this.loadedUrl)
      if (context === undefined) return
      sourceWebFetchBridge.markReady(this.loadingSourceId, documentUrl, agent, context.authorizationRevision)
      DiagnosticLogger.info('source_web_fetch', 'host_document',
        'sameOrigin=' + (sourceWebOrigin(documentUrl) === sourceWebOrigin(this.loadedUrl)) +
        'ready=' + sourceWebFetchBridge.availableFor(this.loadingSourceId, this.loadedUrl, agent, context.authorizationRevision))
    } catch (_error) { /* Detached controllers cannot publish readiness. */ }
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
        .onPageBegin(() => { sourceWebFetchBridge.markLoading(this.loadingSourceId) })
        // A committed same-origin document is enough to execute fetch. Waiting
        // for third-party ads/images to end can exceed the bridge's own timeout.
        .onPageVisible((event: OnPageVisibleEvent) => { this.documentVisible(event.url) })
        .onPageEnd((event: OnPageEndEvent) => { this.documentVisible(event.url) })
    }
  }
}

import { webview } from '@kit.ArkWeb'
import { SOURCE_WEB_FETCH_BRIDGE_REQUEST_KEY, sourceWebFetchBridge } from '../sourceRuntime/SourceWebFetchBridge'

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
    if (this.loadedUrl === url && sourceWebFetchBridge.availableFor(sourceId)) return
    this.loadingSourceId = sourceId
    sourceWebFetchBridge.attach(this.controller, sourceId)
    this.loadedUrl = url
    try {
      this.controller.loadUrl(url)
    } catch (_error) {
      // A rejected navigation leaves the bridge unavailable; callers fail closed.
    }
  }

  build() {
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
      .onPageEnd(() => {
        if (this.loadingSourceId.length > 0) sourceWebFetchBridge.markReady(this.loadingSourceId)
      })
  }
}

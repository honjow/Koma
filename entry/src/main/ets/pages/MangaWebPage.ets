import { DiagnosticLogger, DiagnosticOperation } from '../diagnostics/DiagnosticLogger'
import { webview } from '@kit.ArkWeb'
import { BlurStrategy, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { MangaWebView } from '../components/MangaWebView'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { MangaWebRouteParam, RouterHelper } from '../common/RouterHelper'
import { appSourceWebSessionStore, sourceWebOrigin } from '../sourceRuntime/SourceWebSessionStore'
import { mangaHttpUrl } from '../model/MangaWebLink'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'

/** NextE GalleryWebPage's generic surface and controls, without EH account/UA hooks. */
@ComponentV2
export struct MangaWebPage {
  @Param params: MangaWebRouteParam = { url: '', title: '' }
  @Local private loading: boolean = true
  @Local private controllerReady: boolean = false
  @Local private pageTitle: string = ''
  @Local private canBack: boolean = false
  @Local private canForward: boolean = false
  private controller: webview.WebviewController = new webview.WebviewController()
  private scroller: Scroller = new Scroller()
  private webDiagnostic: DiagnosticOperation | undefined = undefined
  private documentRevision: number = 0
  private progressBucket: number = -1
  private subresourceFailureRecorded: boolean = false
  private documentEndSeen: boolean = false
  private documentVisibleSeen: boolean = false
  private stageEventCount: number = 0

  private stageDiagnostic(event: string, detail: string, warning: boolean = false): void {
    this.stageEventCount += 1
    if (this.stageEventCount > 48) {
      if (this.stageEventCount === 49) this.webDiagnostic?.info('events_suppressed', 'limit=48')
      return
    }
    if (warning) this.webDiagnostic?.warn(event, detail)
    else this.webDiagnostic?.info(event, detail)
  }

  private documentDiagnosticDetail(url?: string): string {
    let matchingDocument: string = 'unknown'
    if (url !== undefined && this.controllerReady) {
      try { matchingDocument = `${this.controller.getUrl() === url}` }
      catch (_error) {}
    }
    const original = mangaHttpUrl(this.params.url)
    const originalOrigin = sourceWebOrigin(this.params.url)
    const eventOrigin = url === undefined ? '' : sourceWebOrigin(url)
    return 'revision=' + this.documentRevision + ' matchingDocument=' + matchingDocument +
      ' matchesInitialUrl=' + (url === undefined || original === undefined ? 'unknown' : `${url === original}`) +
      ' sameInitialOrigin=' + (originalOrigin.length === 0 || eventOrigin.length === 0 ? 'unknown' :
        `${originalOrigin === eventOrigin}`)
  }

  private pageBegan(event?: OnPageBeginEvent): void {
    this.documentRevision += 1
    this.progressBucket = -1
    this.subresourceFailureRecorded = false
    this.documentEndSeen = false
    this.documentVisibleSeen = false
    this.stageDiagnostic('document_begin', this.documentDiagnosticDetail(event?.url))
    this.loading = true
    this.updateNavState()
  }

  private pageVisible(event?: OnPageVisibleEvent): void {
    if (this.documentVisibleSeen) return
    this.documentVisibleSeen = true
    // ArkWeb says the new document is about to become visible; this is not
    // compositor/frame proof and never changes the existing loading state.
    this.stageDiagnostic('document_visible', this.documentDiagnosticDetail(event?.url))
  }

  private pageEnded(event?: OnPageEndEvent): void {
    this.documentEndSeen = true
    this.stageDiagnostic('document_end', this.documentDiagnosticDetail(event?.url))
    this.loading = false
    this.updateNavState()
  }

  private pageProgress(event?: OnProgressChangeEvent): void {
    if (event === undefined || !Number.isFinite(event.newProgress)) return
    const bucket = Math.floor(Math.min(100, Math.max(0, event.newProgress)) / 25)
    if (bucket <= this.progressBucket) return
    this.progressBucket = bucket
    this.stageDiagnostic('progress', 'revision=' + this.documentRevision + ' percentBucket=' + bucket * 25)
  }

  private resourceFailed(request: WebResourceRequest, kind: string, readCode: () => number): void {
    try {
      const mainFrame = request.isMainFrame()
      if (!mainFrame && this.subresourceFailureRecorded) return
      const code = readCode()
      if (!mainFrame) this.subresourceFailureRecorded = true
      this.stageDiagnostic('resource_failed', 'revision=' + this.documentRevision +
        ' kind=' + kind + ' code=' + (Number.isFinite(code) ? code : 0) + ' mainFrame=' + mainFrame, true)
    } catch (_error) {
      // A failed diagnostic read must not interrupt the existing Web callback.
    }
  }

  private updateNavState(): void {
    if (!this.controllerReady) return
    try {
      this.canBack = this.controller.accessBackward()
      this.canForward = this.controller.accessForward()
    } catch (_error) {
      this.canBack = false
      this.canForward = false
    }
  }

  private webMenu(): Record<string, Object> {
    const back: Record<string, Object> = {
      'label': AppStrings.get('web_nav_back'),
      'icon': $r('sys.symbol.chevron_left'),
      'isEnabled': this.canBack,
      'action': () => {
        if (this.controllerReady && this.controller.accessBackward()) this.controller.backward()
      },
    }
    const forward: Record<string, Object> = {
      'label': AppStrings.get('web_nav_forward'),
      'icon': $r('sys.symbol.chevron_right'),
      'isEnabled': this.canForward,
      'action': () => {
        if (this.controllerReady && this.controller.accessForward()) this.controller.forward()
      },
    }
    const refresh: Record<string, Object> = {
      'label': AppStrings.get('web_nav_refresh'),
      'icon': $r('sys.symbol.arrow_clockwise'),
      'isEnabled': this.controllerReady,
      'action': () => {
        if (this.controllerReady) this.controller.refresh()
      },
    }
    const items: Record<string, Object>[] = [{ 'content': back }, { 'content': forward }, { 'content': refresh }]
    if (this.params.sourceSession !== undefined) {
      const complete: Record<string, Object> = {
        'label': AppStrings.get('source_web_complete'),
        'icon': $r('sys.symbol.checkmark'),
        'isEnabled': this.controllerReady && !this.loading,
        'action': () => { void this.completeSourceSession() },
      }
      items.unshift({ 'content': complete })
    }
    return { 'value': items, 'maxCount': 3 }
  }

  private titleBarOpts(): Record<string, Object> {
    const title = this.pageTitle.length > 0 ? this.pageTitle : (this.params.title || this.params.url)
    const heading: Record<string, Object> = { 'mainTitle': title }
    const content: Record<string, Object> = { 'title': heading, 'menu': this.webMenu() }
    const material: Record<string, Object> = {
      'materialType': hdsMaterial.MaterialType.ADAPTIVE,
      'materialLevel': hdsMaterial.MaterialLevel.ADAPTIVE,
    }
    const scroll: Record<string, Object> = {
      'enableScrollEffect': true, 'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
    }
    const style: Record<string, Object> = {
      'blurStrategy': BlurStrategy.ENABLE, 'systemMaterialEffect': material, 'scrollEffectOpts': scroll,
    }
    return { 'avoidLayoutSafeArea': true, 'enableComponentSafeArea': false, 'content': content, 'style': style }
  }

  private async completeSourceSession(): Promise<void> {
    const session = this.params.sourceSession
    if (session === undefined || !this.controllerReady) return
    try {
      const customUa = this.controller.getCustomUserAgent()
      const actualUa = customUa.length > 0 ? customUa : this.controller.getUserAgent()
      try { webview.WebCookieManager.saveCookieSync() }
      catch (_error) { await webview.WebCookieManager.saveCookieAsync() }
      const status = appSourceWebSessionStore.complete(session.sourceId, session.sessionId,
        this.controller.getUrl(), actualUa)
      if (status.state !== 'available') throw new Error('session_unavailable')
      this.params.onSessionCompleted?.()
      RouterHelper.pop()
    } catch (_error) {
      this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_web_session_failed') })
    }
  }

  aboutToDisappear(): void {
    this.webDiagnostic?.finish(this.loading ? 'partial' : 'closed',
      'revision=' + this.documentRevision + ' loading=' + this.loading +
      ' documentEndSeen=' + this.documentEndSeen + ' documentVisibleEventSeen=' + this.documentVisibleSeen +
      ' stageEvents=' + this.stageEventCount)
    this.webDiagnostic = undefined
    const session = this.params.sourceSession
    if (session !== undefined) appSourceWebSessionStore.cancel(session.sourceId, session.sessionId)
  }

  private loadInitialPage(): void {
    this.controllerReady = true
    const url = mangaHttpUrl(this.params.url)
    if (url === undefined) {
      this.loading = false
      return
    }
    this.webDiagnostic = DiagnosticLogger.begin('web_page', 'navigation',
      'hasSourceSession=' + (this.params.sourceSession !== undefined))
    try {
      this.controller.loadUrl(url)
    } catch (_error) {
      this.webDiagnostic.warn('load_failed', 'reason=controller_load_failed')
      this.loading = false
    }
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        SecondaryListScaffold({
          scroller: this.scroller,
          horizontalPadding: 0,
          bottomPadding: 0,
          listSpace: 0,
        }) {
          ListItem() {
            MangaWebView({
              controller: this.controller,
              onControllerAttached: () => { this.loadInitialPage() },
              onPageBegin: (event?: OnPageBeginEvent) => { this.pageBegan(event) },
              onPageVisible: (event?: OnPageVisibleEvent) => { this.pageVisible(event) },
              onPageEnd: (event?: OnPageEndEvent) => { this.pageEnded(event) },
              onProgressChange: (event?: OnProgressChangeEvent) => { this.pageProgress(event) },
              onErrorReceive: (event: OnErrorReceiveEvent) => {
                this.resourceFailed(event.request, 'transport', (): number => event.error.getErrorCode())
                this.loading = false
                this.updateNavState()
              },
              onHttpErrorReceive: (event: OnHttpErrorReceiveEvent) => {
                this.resourceFailed(event.request, 'http', (): number => event.response.getResponseCode())
              },
              onTitleReceive: (event?: OnTitleReceiveEvent) => {
                if (event !== undefined && event.title.length > 0) this.pageTitle = event.title
              },
            })
          }
          .height('100%')
          .clip(false)
        }
        if (this.loading) {
          LoadingProgress()
            .width(ThemeConstants.LOADING_SIZE_LARGE)
            .height(ThemeConstants.LOADING_SIZE_LARGE)
            .color(ThemeConstants.BRAND_PRIMARY)
        }
      }
      .width('100%')
      .height('100%')
    }
    .titleBar(this.titleBarOpts())
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

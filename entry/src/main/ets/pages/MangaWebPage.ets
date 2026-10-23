import { webview } from '@kit.ArkWeb'
import { BlurStrategy, hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { MangaWebView } from '../components/MangaWebView'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { MangaWebRouteParam, RouterHelper } from '../common/RouterHelper'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
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
    try {
      this.controller.loadUrl(url)
    } catch (_error) {
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
              onPageBegin: () => { this.loading = true; this.updateNavState() },
              onPageEnd: () => { this.loading = false; this.updateNavState() },
              onErrorReceive: () => { this.loading = false; this.updateNavState() },
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

import { webview } from '@kit.ArkWeb'

/** Generic ArkWeb wrapper ported from NextE EhWebView; page owns its navigation controls. */
@ComponentV2
export struct MangaWebView {
  @Param controller: webview.WebviewController = new webview.WebviewController();
  @Event onControllerAttached?: (controller: webview.WebviewController) => void;
  @Event onPageBegin?: (event?: OnPageBeginEvent) => void;
  @Event onPageEnd?: (event?: OnPageEndEvent) => void;
  @Event onLoadFinished?: (event?: OnLoadFinishedEvent) => void;
  @Event onProgressChange?: (event?: OnProgressChangeEvent) => void;
  @Event onErrorReceive?: (event: OnErrorReceiveEvent) => void;
  @Event onHttpErrorReceive?: (event: OnHttpErrorReceiveEvent) => void;
  @Event onTitleReceive?: (event?: OnTitleReceiveEvent) => void;
  @Event onConsole?: (event: OnConsoleEvent) => boolean;

  build() {
    Web({ src: '', controller: this.controller })
      .nestedScroll({
        scrollUp: NestedScrollMode.PARENT_FIRST,
        scrollDown: NestedScrollMode.PARENT_FIRST,
      })
      .overScrollMode(OverScrollMode.NEVER)
      .darkMode(WebDarkMode.Off)
      .backgroundColor(Color.White)
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .onlineImageAccess(true)
      .width('100%')
      .height('100%')
      .onControllerAttached(() => {
        if (this.onControllerAttached) {
          this.onControllerAttached(this.controller)
        }
      })
      .onConsole((event: OnConsoleEvent): boolean => {
        return this.onConsole ? this.onConsole(event) : false
      })
      .onPageBegin((event: OnPageBeginEvent) => {
        if (this.onPageBegin) {
          this.onPageBegin(event)
        }
      })
      .onPageEnd((event: OnPageEndEvent) => {
        if (this.onPageEnd) {
          this.onPageEnd(event)
        }
      })
      .onLoadFinished((event: OnLoadFinishedEvent) => {
        if (this.onLoadFinished) {
          this.onLoadFinished(event)
        }
      })
      .onProgressChange((event: OnProgressChangeEvent) => {
        if (this.onProgressChange) {
          this.onProgressChange(event)
        }
      })
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        if (this.onErrorReceive) {
          this.onErrorReceive(event)
        }
      })
      .onHttpErrorReceive((event: OnHttpErrorReceiveEvent) => {
        if (this.onHttpErrorReceive) {
          this.onHttpErrorReceive(event)
        }
      })
      .onTitleReceive((event: OnTitleReceiveEvent) => {
        if (this.onTitleReceive) {
          this.onTitleReceive(event)
        }
      })
  }
}

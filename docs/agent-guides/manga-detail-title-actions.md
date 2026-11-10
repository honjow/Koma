# 作品详情标题栏动作

所有来源、所有作品共用同一套标题栏动作，由宿主渲染，不由源或页面各自实现。

## 固定顺序

最多三个可见位，从左到右：

1. WebView（地球图标）：在应用内网页打开当前作品页。
2. 分享（系统分享图标）：分享当前作品页链接。
3. 更多（四点）：章节、作品信息和打开方式等分组菜单。

## 显示条件

- 只有 `webActionsAvailable` 为 true（作品有合法的 HTTP(S) `webUrl`）时，WebView 和分享成对出现；不允许只显示其中一个。
- 没有合法作品页地址时，两个都不显示；宿主不得根据作品 ID 猜地址，也不得用源主页代替作品页。
- 更多始终按现有条件显示。分享不得在更多菜单里重复；“在浏览器中打开”只放在更多菜单。
- 标题栏不再有独立的刷新按钮；刷新走下拉刷新和更多菜单。第二个系统图标是 `sys.symbol.share`，不是刷新。

## 源的责任

- `get_manga` 返回 `links: [{kind: "source", url: "公开作品页"}]`，或返回 `url`；宿主据此决定两个按钮是否出现。
- 源只提供公开作品页地址，不新增自己的 WebView/分享按钮，也不要求宿主按源 ID 写特例。
- `websitePolicy.publicWorkUrlDomains` 只限定允许公开的作品域，不生成 URL。
- 缺少作品页链接是源数据缺陷：补一次 `links`，所有宿主入口统一生效。

## 实现依据

- `entry/src/main/ets/pages/Index.ets` 的 `mangaDetailTitleBarOpts`：`webActionsAvailable` 为 true 时先 push WebView，再 push 分享，最后 push 更多，`maxCount: 3`。
- `MangaDetailPage.mangaWebUrl()` 优先读 `manga.webUrl`，否则读 `manga.url`；`shareMangaLink()` 使用同一 URL。
- `model/MangaWebLink.ets` 的 `sourceMangaWebUrl()` 优先取 `links` 中 `kind=source` 的地址。

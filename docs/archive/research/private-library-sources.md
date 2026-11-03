# Koma 私有库接入调研：Komga / OPDS / WebDAV

日期：2026-05-21

本调研只覆盖用户自有私有库接入，不涉及内置漫画源、源市场、APK 插件或公开聚合内容。结论面向 Koma 的本地漫画书架/阅读器路线：优先复用本地 MVP 的 `Comic`、`Chapter`、`Page`、`ReadingProgress`、`LibraryItem` 概念，把远端内容作为可缓存、可按需拉取的私有库条目。

## 总结建议

推荐接入顺序：

1. **Komga**
   - 用户价值最高，目标用户明确，服务端已经把漫画库整理成 library / series / book / page。
   - 与 Koma 阅读器模型最贴近，页面流 URL 明确，最适合先做端到端私有库阅读。
   - 上架风险低：定位为用户自建服务登录与浏览，不提供公共内容目录。
2. **WebDAV**
   - 复用本地 CBZ/ZIP、图片文件夹导入能力最多，可作为“远端文件夹”接入。
   - 协议简单但兼容性风险高：不同 NAS/网盘 WebDAV 的路径编码、认证、目录深度、MIME 和 Range 支持差异大。
   - HarmonyOS API 23 的 HTTP `customMethod` 可发 `PROPFIND`，但需要先做设备 spike。
3. **OPDS**
   - 标准化价值高，可覆盖 Komga、Calibre-Web 等服务暴露的目录。
   - 但 OPDS 1 是 Atom/XML，OPDS 2 是 JSON-LD/Readium 风格；目录、获取、封面、分页语义更偏电子书发行，不天然等于漫画页流。
   - 建议作为第二阶段泛目录能力，不要阻塞 Komga 和 WebDAV。

## 1. Komga

### API 入口

Komga REST API 当前文档版本显示为 1.24.4。认证支持：

- HTTP Basic Auth。
- `X-API-Key` header。
- 成功认证后可复用 `KOMGA-SESSION` cookie；也可通过 `X-Auth-Token` 请求/复用 session。
- `remember-me=true` 可返回 remember-me cookie；移动端首版不建议默认使用，先用 API key / Basic + 本地安全存储。

核心端点：

| 能力 | 端点 | 说明 |
| --- | --- | --- |
| 列出库 | `GET /api/v1/libraries` | 结果按当前用户权限过滤。 |
| 列出系列 | `POST /api/v1/series/list` | 新接口；旧 `GET /api/v1/series` 已废弃。 |
| 系列详情 | `GET /api/v1/series/{seriesId}` | 获取单个 series。 |
| 列出图书/章节 | `POST /api/v1/books/list` | 新接口；旧 `GET /api/v1/series/{seriesId}/books` 已废弃。请求过滤可按 `seriesId`。 |
| 图书详情 | `GET /api/v1/books/{bookId}` | 获取单个 book。 |
| 页列表 | `GET /api/v1/books/{bookId}/pages` | 获取页元数据。 |
| 页面图像 | `GET /api/v1/books/{bookId}/pages/{pageNumber}` | 需要 `PAGE_STREAMING` 角色，支持内容协商。 |
| 原始页面 | `GET /api/v1/books/{bookId}/pages/{pageNumber}/raw` | 需要 `PAGE_STREAMING` 角色，不做内容协商。 |
| 页面缩略图 | `GET /api/v1/books/{bookId}/pages/{pageNumber}/thumbnail` | 最大边 300px，适合缩略图预取。 |
| 下载文件 | `GET /api/v1/books/{bookId}/file` | 可作为离线缓存/导入路径，需谨慎控制存储。 |

分页策略：

- list 类接口采用分页响应模型，客户端应按 `page` / `size` 或请求体分页字段增量加载。
- 首版建议 `size=50`，按 library -> series -> books 逐层加载；不要启动后全量扫库。
- 只缓存当前视图需要的 series/book/page 元数据，页面图像按阅读器邻页预取。

### Koma 模型映射

| Komga | Koma | 映射建议 |
| --- | --- | --- |
| Library | LibraryItem/source account | 一个 Komga 服务下的远端库分组，记录 `sourceType=komga`、`serverId`、`libraryId`。 |
| Series | Comic | `id = komga:{serverId}:series:{seriesId}`；标题、排序标题、状态、作者、标签映射到 Comic 元数据。 |
| Book | Chapter | 对漫画来说 book 通常等同单卷/单话/文件；`id = komga:{serverId}:book:{bookId}`；页数、编号、发布日期映射到 Chapter。 |
| Page | Page | `index = pageNumber`；`imageUrl` 使用 `/pages/{pageNumber}` 或 `/raw`；thumbnail 用 `/thumbnail`。 |
| Read progress | ReadingProgress | 可本地保存；后续再评估同步 Komga read progress，避免首版双向同步冲突。 |

实现重点：

- 远端 `Page` 不必持久化为真实文件路径，使用 `RemotePageRef` 或等价字段表达 `sourceType/serverId/bookId/pageNumber/urlKind`。
- 封面优先使用 Komga poster/thumbnail 或第一页缩略图；阅读页用 `/pages/{pageNumber}`，兼容服务端格式转换。
- 认证信息不写日志，不进入 artifact；请求日志只保留 URL path、状态码、耗时。

### 风险

- API 新旧端点差异：文档明确多个 GET list 端点已废弃，首版应只用 `POST /series/list`、`POST /books/list`。
- 权限：页面图像需要 `PAGE_STREAMING` 角色；登录成功不等于可读页。
- 自签 HTTPS：私有服务常见自签证书，HarmonyOS 侧可配置 CA，但 UI/安全策略需单独设计。
- 离线缓存：下载整本文件可能触发大存储占用，首版先做在线阅读 + 小型图片缓存。

### 下一步 spike

1. 写 `KomgaClient` 最小只读能力：登录检查、列库、列 series、按 series 列 books、列 pages、请求第一页。
2. 用本地 mock server 或开发者自建 Komga 验证 Basic / API key / cookie / `X-Auth-Token`。
3. 验证 HarmonyOS Image 组件或图片加载层是否能携带认证 header；如果不能，页面图像需先通过客户端下载到沙箱缓存再显示。
4. 定义远端模型：`RemoteLibraryAccount`、`RemoteComicRef`、`RemotePageRef`，不要污染本地导入模型。

## 2. OPDS

### 协议入口

OPDS 是出版物目录规范：

- OPDS 1.2 基于 Atom/XML 和 HTTP，目录分为 Navigation Feed 与 Acquisition Feed。
- OPDS 2.0 草案基于 JSON-LD / schema.org / Readium Web Publication Manifest。
- OPDS 1 的 `atom:entry` 通过 `link rel="http://opds-spec.org/acquisition..."` 表示可获取文件，通过 `http://opds-spec.org/image` 和 `/thumbnail` 表示封面。
- OPDS 2 的 publication 使用 `metadata`、`links`、`images`；分页通过 `metadata.numberOfItems/itemsPerPage/currentPage` 和 `links.next/previous/first/last`。

首版支持边界建议：

- 支持 OPDS 1.2 Navigation Feed 与 Acquisition Feed。
- 支持 OPDS 2.0 的基础 `navigation` / `publications` / `groups`。
- acquisition 只接受用户自有服务中直接可下载/可访问的漫画文件类型：`application/zip`、`application/x-cbz`、`application/vnd.comicbook+zip`、常见 `application/octet-stream` 兜底但需扩展名校验。
- 不支持购买、借阅、订阅流程；遇到 `buy/borrow/subscribe` 只展示不可导入状态或跳过。

### Parser 选择

HarmonyOS 侧可用能力：

- JSON：`@ohos.util.json` 提供 `JSON.parse` / `JSON.stringify`，适合 OPDS 2。
- XML：`@ohos.xml` 提供 `XmlPullParser`，`parseXml` 从 API 14 起可用，适合 OPDS 1 和 WebDAV multistatus。
- HTTP：`@ohos.net.http` 支持 GET/POST/HEAD 等常见方法；Koma 当前 target/compatible SDK 为 `6.1.0(23)`，文档中 API 23 支持 `customMethod`。

建议：

- OPDS 1 使用 `XmlPullParser` 做事件式解析，避免 DOM 依赖和大 feed 内存压力。
- OPDS 2 使用 ArkTS JSON 解析后映射到轻量 DTO，不引入 JSON-LD 推理。
- URL 解析必须支持相对链接，所有 `href` 基于当前 feed URL resolve。

### Koma 模型映射

| OPDS | Koma | 映射建议 |
| --- | --- | --- |
| Catalog root / navigation feed | Remote folder / source section | 用作远端目录节点，不直接等于书架漫画。 |
| Acquisition feed / publications | Comic 列表候选 | 每个 entry/publication 可映射为单本漫画或单章节，取决于服务目录层级。 |
| Entry title / metadata.title | Comic/Chapter title | 若上级目录是系列，则 entry 映射 Chapter；否则映射 Comic。 |
| Acquisition link | Chapter file source | 下载 CBZ/ZIP 后走本地导入；若是图片/html/pdf/epub，首版跳过。 |
| Image/thumbnail link | Cover | 优先 thumbnail，再 full image。 |

OPDS 的核心问题是“出版物”不等于“漫画系列”。因此首版不要强行构造完整系列树，建议以目录浏览 + 导入/打开单本为主：

- 用户进入 OPDS 目录。
- 选择一个 acquisition entry。
- 若 acquisition 是 CBZ/ZIP，缓存或导入为 Koma 本地 Comic/Chapter。
- 阅读进度保存在 Koma 本地，不尝试写回 OPDS。

### 风险

- 服务差异：不同服务对漫画类型 MIME、封面 rel、分页 rel 支持不一致。
- OPDS 2 仍是 draft，长期兼容要做能力检测。
- OPDS 常见认证不统一，可能是 Basic、cookie、反代 header；首版只承诺 Basic/API token 风格 header。
- OPDS 不提供标准“页面列表”，更多是文件获取；阅读体验依赖本地 CBZ/ZIP 解析能力。

### 下一步 spike

1. 准备 2 个 fixture：OPDS 1 Atom XML、OPDS 2 JSON，各含目录、分页、封面、acquisition。
2. 写独立 parser 单元测试：输入 feed 字符串，输出 `RemoteCatalogNode[]` 和 `RemotePublication[]`。
3. 验证 acquisition 下载到沙箱后复用 CBZ/ZIP importer。
4. 做服务兼容表：Komga OPDS、Calibre-Web OPDS、Kavita/其他私有库是否符合首版 MIME 白名单。

## 3. WebDAV

### 协议入口

WebDAV 基于 HTTP 扩展，目录枚举核心是 `PROPFIND`：

- 对 collection 发 `PROPFIND`，返回 `207 Multi-Status` XML。
- 常用请求头：`Depth: 0` 获取当前资源属性，`Depth: 1` 枚举直接子项；避免默认递归深扫。
- 常用属性：`DAV:displayname`、`DAV:resourcetype`、`DAV:getcontentlength`、`DAV:getcontenttype`、`DAV:getlastmodified`、`DAV:getetag`。
- 文件内容用 `GET` 读取；首版只读，不做 `PUT/MKCOL/DELETE/MOVE/COPY/LOCK`。

认证：

- 常见是 Basic Auth；RFC 4918 指出 Basic 不应在非安全连接上使用，应要求 HTTPS 或显式风险提示。
- Digest 是 WebDAV 规范要求的互操作能力，但 HarmonyOS `@ohos.net.http` 是否直接处理 Digest 需要设备验证；首版可先支持 Basic over HTTPS。

HarmonyOS 侧关键点：

- `@ohos.net.http` 常规枚举没有 `PROPFIND`，但 API 23 `HttpRequestOptions.customMethod` 可指定自定义方法。当前 Koma target/compatible SDK 是 23，理论上可直接发 `customMethod: 'PROPFIND'`。
- 响应 XML 可用 `XmlPullParser` 解析。
- 大文件下载应优先用流式请求或下载任务，普通 `request` 默认适合小响应；图片页或 CBZ 文件不能全部走内存。

### 读取策略

目录枚举：

1. 登录时只验证根路径 `PROPFIND Depth: 0`。
2. 浏览时每进入一层目录发 `PROPFIND Depth: 1`。
3. 客户端按文件名自然排序，目录优先；不要递归扫描整个库。
4. 识别：
   - `.cbz` / `.zip`：作为单本漫画或章节，下载/缓存后复用 CBZ importer。
   - 图片文件夹：同一目录下连续图片作为一个章节候选；进入目录时按图片扩展名和自然排序生成 page list。
   - 其他文件：隐藏或标记 unsupported。

页面读取：

- CBZ/ZIP：首版建议下载到沙箱临时缓存，再用本地解压读取，避免随机读取远端 zip 的复杂度。
- 图片文件夹：可把每个图片 URL 作为 `RemotePageRef`；如果图片加载无法携带认证 header，则通过客户端带认证下载到缓存再显示。
- 使用 ETag/Last-Modified 做轻量缓存失效判断。

### Koma 模型映射

| WebDAV | Koma | 映射建议 |
| --- | --- | --- |
| 账号/root URL | RemoteLibraryAccount | `sourceType=webdav`，记录 root path、认证方式、只读能力。 |
| Collection | Remote folder / Comic candidate | 顶层目录可作为分组；含图片的目录可作为 Chapter。 |
| `.cbz/.zip` resource | Comic 或 Chapter | 若父目录代表系列，则文件映射 Chapter；否则单文件映射 Comic+Chapter。 |
| Image resource | Page | `href`、文件名、content length、etag 映射到 Page 元数据。 |
| ETag/Last-Modified | Cache validation | 判断封面/page 缓存是否可复用。 |

### 风险

- `PROPFIND` 自定义方法需要真机验证；如果 `customMethod` 行为不稳定，需要 NAPI/libcurl 或服务端兼容端点。
- WebDAV 没有标准分页，大目录会一次返回大量 XML；必须限制每层展示数量和解析超时。
- 路径编码和 Unicode 兼容复杂，必须使用 URL parser/resolver，不能手拼字符串。
- Basic over HTTP 不安全；默认要求 HTTPS，HTTP 仅允许用户显式确认的局域网测试模式。
- 远端 ZIP 随机访问难度高；先下载再读更稳，但要做缓存配额和清理。

### 下一步 spike

1. 在 API 23 设备上验证 `customMethod: 'PROPFIND'` + `Depth: 1`，保存 207 XML fixture。
2. 写 WebDAV multistatus parser：XML -> `DavResource[]`。
3. 验证 Basic over HTTPS、自签 CA、HTTP 局域网三种连接策略。
4. 用一个含 CBZ 和图片目录的 WebDAV fixture，验证目录浏览、自然排序、首图封面、按需下载。

## 排序矩阵

分值 1-5，5 表示更高/更有利；复杂度分数为“实现容易度”。

| 来源 | 开发容易度 | 用户价值 | 上架风险低 | 本地 MVP 复用度 | 综合建议 |
| --- | ---: | ---: | ---: | ---: | --- |
| Komga | 4 | 5 | 5 | 4 | 第一优先；最适合私有漫画库端到端阅读。 |
| WebDAV | 3 | 4 | 5 | 5 | 第二优先；先验证 PROPFIND 和认证图片加载。 |
| OPDS | 3 | 4 | 4 | 3 | 第三优先；适合作为泛目录/导入能力，不先承诺完整漫画页流。 |

## 统一实现边界

- 所有来源都必须由用户手动添加私有服务地址，不内置公共目录。
- 不展示“全网”“免费”“聚合”“插件市场”等文案。
- 首版只做只读浏览与阅读，不做远端删除、重命名、上传、元数据修改。
- 认证信息进入系统安全存储；日志、artifact、截图不得包含密码、API key、cookie、token。
- 远端内容统一映射为 `RemoteLibraryAccount` + `RemoteComicRef` / `RemoteChapterRef` / `RemotePageRef`，本地导入和远端阅读共用阅读器状态机。

## 参考资料

- Komga API Introduction: <https://komga.org/docs/openapi/komga-api/>
- Komga Libraries: <https://komga.org/docs/openapi/libraries/>
- Komga Series: <https://komga.org/docs/openapi/series/>
- Komga Books and Pages: <https://komga.org/docs/openapi/books/>
- OPDS 1.2 Specification: <https://specs.opds.io/opds-1.2.html>
- OPDS 2.0 Draft: <https://drafts.opds.io/opds-2.0.html>
- WebDAV RFC 4918: <https://www.rfc-editor.org/rfc/rfc4918.html>
- HarmonyOS `@ohos.net.http`: `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.net.http (数据请求).md`
- HarmonyOS `@ohos.xml`: `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.xml (XML解析与生成).md`
- HarmonyOS `@ohos.util.json`: `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.util.json (JSON解析与生成).md`

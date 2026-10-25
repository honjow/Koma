# Koma Source Runtime ABI Draft

日期：2026-05-21

本草案面向未来实验能力，不属于 Koma v1 必做。目标是让用户手动导入自有配置或私有服务适配，并把可执行逻辑关在最小 host imports 内。Koma 不复制 Aidoku/Homo 代码或资源，只参考公开 source/runtime 架构思想。

## 设计原则

- **host owns everything dangerous**：网络、缓存、日志、时间、随机数、账号凭据、文件系统都由 Koma host 控制。
- **source is pure adapter**：source 只把 host 返回的 HTML/JSON 映射成 Koma DTO。
- **manifest first**：运行前必须读取 manifest，权限和域名先验可见。
- **deny by default**：未声明能力不可用，跨域、长耗时、大响应、敏感日志默认拒绝。
- **v1 out of scope**：上架版不内置公共源、不做市场、不宣传聚合。

## 包结构

导入加载主路径应支持用户配置的 source index URL：App 拉取远端 `index.json`，展示其中的 source 元数据，再按条目的 `pkg` 下载对应 `.koma` 包并安装。独立源仓库 `/Users/honjow/git/koma-sources/dist/index.json` 是当前索引定义来源；索引项字段包括 `id/name/version/lang/nsfw/author/description/contentRating/pkg/icon/minAppVersion`，`pkg` 为相对索引 URL 的包路径或文件名。

源包 `manifest.json` 与索引项可选声明 `homepage`，作为普通 WebView 的站点导航地址。仅接受不含账号信息的完整 HTTP(S) URL，保留栏目路径、查询和片段；非法或缺失的可选地址不授予任何能力，也不使旧有效包失效。导入、registry 持久化/重载、备份及索引缓存须保留这个字段。它与 `webSessionOrigins` 独立，不能增加源的 Cookie、User-Agent 或网络权限。

普通“在 WebView 中打开”沿用详情页网页控件，不创建 `sourceSession`、不自动重试源请求。旧包缺字段时可从用户当前索引同 ID 的缓存/新元数据取得显式地址，或使用既有声明的会话 origin；不能从 API、图片 CDN、最近失败请求或 source ID 猜测站点。缺少地址时提示检查源更新。可选索引补取只取 JSON，不等待图标或重装包。

本地文件导入仍可作为高级/调试/离线路径。导入文件后缀支持 `.koma`、`.koma-source`、`.koma-source.zip` 和 `.zip`。后缀只用于系统文件选择器过滤与诊断展示；运行前必须按归档内容读取并校验 `manifest.json` 与 `source.wasm`。

```text
koma-source/
  manifest.json
  source.wasm          # 可选，WASM 路线
  rules.yaml           # 可选，声明式路线
  README.md            # 可选，本地说明，不在应用内当市场内容展示
```

同一 source 包只能选择一种执行方式：

- `runtime: "rules-v1"`：声明式 JSON/YAML 规则。
- `runtime: "wasm-v1"`：WASM ABI。
- `runtime: "quickjs-v1"`：保留实验字段，默认不启用。

## Manifest

```json
{
  "schemaVersion": 1,
  "id": "local.example.private",
  "name": "Private Example",
  "version": "0.1.0",
  "runtime": "rules-v1",
  "entry": "rules.yaml",
  "homepage": "https://example.local",
  "description": "User-owned private catalog adapter.",
  "allowedDomains": ["example.local"],
  "capabilities": {
    "network": true,
    "cache": true,
    "cookies": false,
    "credentials": "user-configured",
    "operations": ["search", "get_manga", "get_chapters", "get_pages", "get_home", "get_filters"]
  },
  "limits": {
    "timeoutMs": 8000,
    "connectTimeoutMs": 5000,
    "maxResponseBytes": 2097152,
    "maxImageBytes": 20971520,
    "maxRedirects": 3,
    "cacheTtlSeconds": 3600
  },
  "contentPolicy": {
    "requiresUserOwnedService": true,
    "publicIndex": false,
    "marketplace": false
  }
}
```

Validation rules:

- `id` must be reverse-DNS-like ASCII, max 96 chars.
- `allowedDomains` is required and non-empty; wildcards are rejected in the first version.
- `entry` must be a relative path inside the source package.
- `publicIndex` and `marketplace` must be false for Koma-distributed builds.
- Manifest cannot request direct file, socket, process, dynamic library, clipboard, contacts, location, notification, camera, microphone, or background task access.

### Optional image descriptors

The Reader preserves the cache-first and explicit-reload behavior of the existing image pipeline. A registered `imageRequest` capability remains required: its descriptor or worker failure must not silently fall back to an uncredentialed URL.

Legacy capability lists can be incomplete, so absence from that list alone does not authorize skipping `get_image_request`. For an undeclared operation, a shared, network-disabled `source_info` query may confirm the exact boolean `data.capabilities.imageRequest: false`. Only this explicit negative bypasses the optional descriptor operation and continues the existing direct-URL path; it is not logged as a descriptor failure. Unexpected descriptor absence retains its existing warning. Missing, malformed or failed metadata keeps the legacy attempt. This result is in-memory and keyed by the installed WASM object; concurrent covers share one query and replacement packages are queried independently. No capability guess is persisted, and no HTTP, headers, session, cache identity or UI contract changes.

## Runtime Calls

All calls are request/response and return normalized JSON strings. Native runtimes may expose C ABI functions; ArkTS rules expose equivalent interpreter functions.

```c
// Pseudocode for wasm-v1 exports.
int32_t koma_source_init(uint32_t manifest_ptr, uint32_t manifest_len);
int32_t koma_source_search(uint32_t query_ptr, uint32_t query_len, uint32_t out_ptr);
int32_t koma_source_detail(uint32_t comic_id_ptr, uint32_t comic_id_len, uint32_t out_ptr);
int32_t koma_source_pages(uint32_t chapter_id_ptr, uint32_t chapter_id_len, uint32_t out_ptr);
int32_t koma_source_free(uint32_t ptr, uint32_t len);
```

`out_ptr` points to a host-defined result envelope:

```json
{
  "ok": true,
  "data": {},
  "warnings": [],
  "elapsedMs": 12
}
```

Errors:

```json
{
  "ok": false,
  "error": {
    "code": "TIMEOUT|NETWORK_DENIED|PARSE_ERROR|BAD_MANIFEST|UNSUPPORTED",
    "message": "Redacted message safe for logs"
  }
}
```

## DTOs

### Search Request

```json
{
  "query": "title",
  "page": 1,
  "locale": "zh-CN"
}
```

### Search Result

```json
{
  "items": [
    {
      "id": "series-123",
      "title": "Series Title",
      "subtitle": "Optional",
      "cover": {
        "url": "https://example.local/covers/123.jpg",
        "headersRef": "default"
      }
    }
  ],
  "nextPage": 2
}
```

### Detail Result

```json
{
  "id": "series-123",
  "title": "Series Title",
  "authors": ["Author"],
  "tags": ["private"],
  "summary": "Optional summary",
  "cover": {
    "url": "https://example.local/covers/123.jpg"
  },
  "chapters": [
    {
      "id": "chapter-1",
      "title": "Chapter 1",
      "index": 1,
      "updatedAt": "2026-05-21T00:00:00Z"
    }
  ]
}
```

### Pages Result

```json
{
  "chapterId": "chapter-1",
  "pages": [
    {
      "index": 0,
      "url": "https://example.local/pages/1.jpg",
      "width": 1200,
      "height": 1800,
      "cacheKey": "chapter-1-page-0"
    }
  ]
}
```

## Host Imports

WASM imports are intentionally small:

```c
int32_t host_http_fetch(uint32_t request_json_ptr, uint32_t request_json_len, uint32_t out_ptr);
int32_t host_cache_get(uint32_t key_ptr, uint32_t key_len, uint32_t out_ptr);
int32_t host_cache_put(uint32_t key_ptr, uint32_t key_len, uint32_t value_ptr, uint32_t value_len, uint32_t ttl_seconds);
int32_t host_log(uint32_t level, uint32_t message_ptr, uint32_t message_len);
int64_t host_now_unix_ms(void);
```

`host_http_fetch` request:

```json
{
  "method": "GET",
  "url": "https://example.local/search?q=title",
  "headers": {
    "Accept": "text/html"
  },
  "body": null,
  "timeoutMs": 8000,
  "expect": "text"
}
```

Host enforcement:

- URL scheme only `https` by default. Local HTTP can be allowed only by explicit user setting for LAN/private services.
- Host must match manifest `allowedDomains` after DNS/URL normalization.
- Redirect target must also match the whitelist.
- Header allowlist: `Accept`, `Content-Type`, `User-Agent` profile token, conditional cache headers, and user-configured auth headers by reference.
- `Cookie`, `Authorization`, API keys and passwords are never passed as raw manifest literals; source may request `credentialsRef`, host resolves it.
- Response body is capped by `maxResponseBytes`.

## 已实现的宿主网页会话（2026-10-23）

当前 WASM 源包可选声明 `webSessionOrigins`，例如 `["https://www.example.com"]`；宿主归一化后保存在 `permissions.webSessionOrigins`。只接受无路径、无账号、无通配符的完整 HTTPS origin，旧包不声明时不会取得网页会话。

用户从源浏览/搜索菜单或源包详情打开“网页验证 / 登录”，沿用 App 的带导航控件 WebView。完成后显式选择“完成并重试”，宿主将当前网页的实际 User-Agent 与该源、该版本、该安装身份和精确 origin 绑定，返回原源请求。

已识别挑战的自动弹层会在同 origin 主文档加载无错误、当前 `cf_clearance` 非空且与打开前不同时，自动执行一次相同的完成与原请求重试；凭据只作重试候选，不代表站点已通过。主文档失败、旧导航、关闭、换会话或取消会阻止旧回调完成；没有可靠候选时保留人工验证和“完成并重试”。登录要求（auth_required）及手动打开的登录页不自动退出。

对于明确站点挑战但不产生 `cf_clearance` 的流程，主文档先收到403、随后同一请求地址正常加载时，宿主可在网页仍可见的情况下验证一次原失败的无请求体GET。验证必须同时满足当前已领取挑战收据、查询/筛选/设置、源版本及安装身份、pending会话和精确origin仍有效；普通请求不能使用pending会话。验证失败保留网页和人工完成，不自动循环，不探测POST/HEAD或登录提交。验证成功后才发布会话并完成原重试，成功响应仅按原生源上下文、完整请求JSON及同会话交接一次；不落磁盘，不交接响应头或Cookie。请求、会话或安装身份变化及取消均使交接失效。

主文档失败状态在新的主框架加载请求前初始化；后到的 `onPageBegin` 不得清除已收到的HTTP错误。

打开或取消验证不撤销先前可用会话；网页完成本身不证明站点验证成功，仍以普通源请求结果为准。

宿主 HTTP 成功执行回包保留 `ok/status/bodyText/networkPerformed`，并可选附带 `accessSignal: "challenge_required"`。仅在实际响应头名（不区分大小写）为 `cf-mitigated`、字符串值精确为 `challenge` 时提供；普通403、其他缓解类型、正文关键词和源请求自报均不能产生该信号。原始响应头、Cookie和挑战正文不进入诊断日志。依据：[Cloudflare 挑战响应识别](https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/detect-response/)。

这个可选信号不授予会话。源仍须显式返回挑战错误，并声明对应 HTTPS origin；现有宿主按源身份、安装版本及合法失败地址打开验证。旧源忽略该字段时保持原行为，不能称所有源已具备自动验证。

- Cookie 仅由系统 `WebCookieManager` 保存；宿主逐个完整请求 URL 读取，以保留 path、secure 和过期规则，并在同源响应中逐条接收 `Set-Cookie` 续期。
- 可信源身份从 Registry 经独立 Native 调用上下文送达 HTTP 桥，不读取 WASM 请求 JSON 中自报的身份。Cookie、网页会话和密码不作为 `get_settings` 的普通值交给 WASM，也不进入返回包或日志。
- 带会话的请求禁止自动跟随重定向；每一跳重新核对当前授权和 origin，再读取该 URL 的 Cookie。跨 origin 不携带会话且不发出该跳请求。
- 仅非秘密的按源授权元数据和实际 User-Agent 保存在 App 私有目录；不持久化验证 URL 的查询串。源版本、安装身份或域许可变化、禁用、移除和主动断开会使授权失效；等价的 Registry 重新加载不丢登录。
- 普通源设置仍使用既有按源控件与持久化，来源于 `get_settings` 的安全类型；网页登录是宿主动作，不把密码、令牌或 Cookie 当普通源设置输入。

这里的会话支持不表示所有站点的挑战或账号体系已通过；具体源仍需完成网页验证、返回普通浏览/阅读及重开验收。

## Caching

Cache key namespace:

```text
source:{sourceId}:http:{sha256(method,url,body,headersProfile)}
source:{sourceId}:image:{cacheKey}
source:{sourceId}:metadata:{id}
```

Rules:

- Source may suggest TTL but host clamps it.
- Authenticated responses are separated by account id.
- Cache records store sanitized URL, status, content type, ETag/Last-Modified if available.
- Cached image bytes are managed by Koma page cache quotas, not by source code.

## Logs

Log record:

```json
{
  "sourceId": "local.example.private",
  "level": "info",
  "event": "request",
  "urlHost": "example.local",
  "urlPathHash": "sha256:...",
  "status": 200,
  "elapsedMs": 122
}
```

Redaction:

- Never log query strings in clear text by default.
- Never log passwords, tokens, cookies, authorization headers, request bodies, full page HTML, image URLs with signed parameters, or certificate material.
- Artifact logs may include source id, host, HTTP status, timing, error code, and hash values only.

## Disabled Capabilities

The source runtime must not expose:

- Filesystem read/write except host-managed cache APIs.
- Raw sockets, DNS APIs, Bluetooth, USB, IPC, process spawn, dynamic library loading.
- Reflection into ArkTS objects, UI APIs, clipboard, contacts, media library, location, sensors, notifications.
- Background execution, scheduled jobs, push, remote code auto-update.
- Direct system time mutation, secure storage access, signature material access.
- Eval-like dynamic code loading for rules; QuickJS route must disable host module loading unless explicitly designed later.

## Timeouts and Isolation

Recommended defaults:

- `search`: 8s wall time, 2MB text response, 50 results.
- `detail`: 8s wall time, 2MB text response, 300 chapters.
- `pages`: 8s wall time, 2MB metadata response, 1000 pages.
- image fetch: host-only, 20MB per image default cap.

Runtime behavior:

- One source call should be cancellable from ArkTS.
- Long parsing should be interrupted by fuel/instruction counter where runtime supports it; otherwise run in a worker/native thread with hard wall-clock cancellation and instance disposal.
- Runtime crash marks only that source call failed; it must not corrupt Koma library state.

## v1 / v2 Boundary

v1:

- Local CBZ/ZIP and image folders.
- Private services: Komga / OPDS / WebDAV when implemented.
- No source runtime in primary UI.
- No built-in public adapters or public source catalog.

v2 experimental:

- Hidden/advanced “Custom adapter” entry.
- Manual import from local file only.
- Rules-v1 first, then WAMR/wasm-v1 spike behind developer flag.
- Per-source permission review and delete button.

Not allowed for Koma-distributed builds:

- Public source marketplace.
- Remote source list URL.
- Built-in public web manga adapters.
- Marketing copy implying free/public aggregated comics.

## Minimal Spike Pseudocode

```text
load manifest.json
validate id/runtime/allowedDomains/limits
load rules.yaml or source.wasm
call search("test")
  source asks host_http_fetch("https://allowed.local/search?q=test")
  host checks domain, timeout, response size
  source parses fixture HTML
  source returns normalized SearchResult JSON
assert no token/url query/full HTML appears in logs
```

### Optional package catalog chronology

Source-repo `manifest.json` may declare `chapterOrder` as `newest_first` or `oldest_first`. It describes the complete raw catalog across `get_chapters` pages, not display sorting. The host validates and retains it through the normalized package, registry and backup. Absence retains legacy selection; invalid values reject admission. Only declare a direction after checking the actual source contract. Initial reading selects earliest unread in that direction; saved progress and explicit chapter targets take precedence. The shared first-read implementation and rationale are in `model/ReaderChapterSequence.ets` and WASM_SOURCE_RUNTIME_DIRECTION's source chronology section. No chapter identities or numbers are synthesized.

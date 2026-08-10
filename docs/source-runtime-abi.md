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

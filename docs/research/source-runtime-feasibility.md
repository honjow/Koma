# Koma WASM / Source Runtime Feasibility

日期：2026-05-21

本调研只讨论未来“用户自有配置 / 私有服务适配”的高级能力，不进入 Koma v1 必做范围，不内置公共漫画源，不提供源市场，不复制 Aidoku/Homo 代码或资源；Aidoku/Tachiyomi 只作为公开架构思想参考。

## 结论

推荐路线：

1. **v1：不做可执行 source runtime。** 上架版只保留本地漫画、Komga / OPDS / WebDAV 等用户自有私有库方向，避免被理解为公共聚合漫画客户端。
2. **v2 spike：先做声明式 JSON/YAML 规则。** 规则只允许用户手动导入，必须声明域名白名单、固定入口、字段选择器、分页和图片 URL 提取，不支持任意脚本、不支持市场、不支持远程源索引。
3. **v2+ experimental：WAMR 或 wasm3 二选一做离线 CLI / native module spike。** 优先验证 WAMR 的能力边界和资源控制；若包体/集成成本过高，再退到 wasm3。WASM 只执行纯计算和 HTML/JSON 解析逻辑，网络、缓存、日志、时间、随机数等都由 Koma host imports 代理。
4. **QuickJS 暂不作为首选。** 它的脚本生态和开发体验更好，但“可下发 JS 逻辑 + 网络解析”在审核表述上更接近通用插件/聚合源，且 JS 动态能力需要更强沙箱与脚本治理。

## HarmonyOS 可行性基础

Koma 当前目标是 HarmonyOS NEXT API 23。离线 HarmonyOS 文档证据：

- `@ohos.net.http` 提供 HTTP 请求能力，需要 `ohos.permission.INTERNET`；`readTimeout`、`connectTimeout` 默认 60000ms，可配置。
- `@ohos.net.http` 的普通 `request` 默认适合 5MB 内响应，较大内容应使用 `requestInStream` 或显式 `maxLimit`。
- API 23 `HttpRequestOptions.customMethod` 支持自定义请求方法，并且文档示例明确提到可用于 WebDAV 扩展协议；当与 `method` 同时设置时，`customMethod` 优先。
- `HttpRequestOptions` 支持 `caPath`、`caData`、客户端证书、certificate pinning 等参数，适合私有服务 / 自签证书后续设计。
- Node-API 文档说明 HarmonyOS 重新实现了 Node-API，底层对接 ArkJS 等引擎，并通过 `#include <napi/native_api.h>` 与 `libace_napi.z.so` 引入 native 插件能力。

这些能力足够支撑“ArkTS host + native runtime module”的 spike：ArkTS 负责账号、网络、缓存和 UI，native 只负责运行 wasm/js/规则解释器，不让 source 直接访问系统 API。

## 路线对比

| 路线 | HarmonyOS 可行性 | 审核风险 | 实现复杂度 | 适合 Koma 的位置 |
| --- | --- | --- | --- | --- |
| 声明式 JSON/YAML 规则 | 最高。纯 ArkTS parser + HTTP host，无 native 依赖。 | 低到中。仍要避免“公共规则市场”和内置公开规则。 | 中。选择器、分页、反爬兼容会逐步变复杂。 | v2 首选 spike；用户自有站点/私有服务适配。 |
| WAMR | 高。C runtime 可通过 NDK/Node-API 集成，资源控制和 WASI/host imports 模型完整。 | 中。比脚本更可控，但仍是可执行外部代码。 | 高。构建、ABI、内存、回调、崩溃隔离都要做。 | v2+ advanced experimental。 |
| wasm3 | 中到高。单体 C interpreter 更轻，适合最小嵌入验证。 | 中。解释执行 wasm，风险与 WAMR 类似但能力少。 | 中。集成轻，但长期维护和能力边界需验证。 | 低成本 CLI spike 或 fallback。 |
| QuickJS | 中。C 引擎可通过 NDK 集成，支持内存限制和中断 handler。 | 中到高。动态 JS 容易被审核理解为插件/脚本聚合能力。 | 中到高。要封装模块系统、沙箱、超时、API stub。 | 不推荐作为 Koma source v2 首选。 |

## wasm3

可行点：

- wasm3 是 embeddable WebAssembly interpreter，C 代码集成面小，适合先做“加载 wasm、调用 `search`、返回 JSON”的最小 spike。
- 不依赖 JIT，对移动端审核和平台兼容相对更稳；host imports 可以完全由 Koma 提供。

主要风险：

- 官方仓库最近维护频率需要持续关注，长期安全修复能力弱于更活跃的 runtime。
- interpreter 性能足够处理 source 解析，但不适合重计算；复杂 HTML 解析如果放进 wasm 会放大性能和内存风险。
- 需要自己补齐 fuel/step 限制、内存上限、panic/异常映射、并发实例池等治理。

建议 spike：

- 只做命令行或 isolated native module：`manifest.json + source.wasm + fixture response -> normalized JSON`。
- 不接 Koma 主 UI，不接真实远程源列表。

## WAMR

可行点：

- WAMR 是面向嵌入式/IoT/边缘场景的 WebAssembly Micro Runtime，支持 interpreter、AOT/JIT 等模式，并有较成熟的 sandbox/host native API 设计。
- 对 Koma 来说，interpreter 模式即可，AOT/JIT 不应进入首版高级特性，以减少平台适配和审核解释成本。
- 比 wasm3 更适合长期化 source ABI：module lifecycle、memory、native symbol registration、错误码、WASI 子集等能力更完整。

主要风险：

- 集成复杂度明显高于声明式规则和 wasm3：CMake/ohpm/NDK 构建、ABI 包体、崩溃定位、内存泄露和线程模型都要验证。
- 如果开放 WASI 或过多 host imports，会把能力边界扩大到“通用插件 runtime”，必须默认禁用文件系统、进程、socket、系统时间直通等能力。

建议 spike：

- WAMR interpreter only。
- 每个 source 调用创建短生命周期 instance，设置线性内存上限、调用超时、host import allowlist。
- 所有网络由 host `http_fetch` 代理，强制域名白名单和响应大小上限。

## QuickJS

可行点：

- QuickJS 是可嵌入的 JavaScript 引擎，C API 直接，支持设置 memory limit、最大栈、interrupt handler；source 作者用 JS 开发成本低。
- 对 HTML/JSON 解析、字符串处理更自然，开发体验比 WASM ABI 好。

主要风险：

- 审核和产品表述风险最高：用户导入 JS source 容易被理解为脚本插件或公共聚合能力。
- JS 模块系统、polyfill、Promise/async bridge、异常堆栈、沙箱对象冻结都需要自行设计。
- 脚本生态会自然推动“规则分享 / 源市场”，与 Koma v1 上架边界冲突。

建议：

- 不作为 v2 首选。除非后续声明式规则无法覆盖私有服务适配，才做仅本地文件导入、无市场、无内置 JS API 的实验。

## 声明式 JSON/YAML 规则

可行点：

- 不执行用户代码，只解释固定 schema，审核解释最清楚。
- 可直接复用 HarmonyOS HTTP、XML/JSON、缓存和日志设施。
- 适合覆盖“私有站点页面结构稳定、登录/鉴权由用户配置、搜索/详情/页面 URL 可由选择器提取”的轻量场景。

边界：

- 不支持破解、绕过登录、执行验证码、动态 JS 渲染、任意脚本、加密算法插件。
- 规则能力越强越接近脚本语言，因此 v2 schema 必须故意保持小而硬。

建议首版 schema：

- `manifest`：id、name、version、author、homepage、allowedDomains、entrypoints。
- `request`：method 只允许 GET/POST，headers 只允许安全白名单，body 支持模板变量。
- `parse`：JSONPath / CSS selector 二选一或小集合，不内置复杂 JS evaluator。
- `pagination`：next selector 或 page param template。
- `rateLimit`、`timeoutMs`、`maxResponseBytes`、`cacheTtlSeconds`。

## 审核与产品边界

上架版文案和 UI：

- 可以说“本地漫画”“私有库”“用户自有服务”“高级自定义配置”。
- 避免“全网漫画”“免费漫画”“聚合源”“插件市场”“源仓库”“一键导入热门源”。
- 不内置任何公共网站规则、wasm、JS 或远程索引 URL。
- 不提供榜单、推荐源、分享源、在线源搜索。

高级设置定位：

- 默认关闭，可放在“实验功能 / 自定义适配”下。
- 入口文案强调“仅用于连接你有权访问的私有服务或自有站点配置”。
- 导入时展示 manifest 权限：域名、超时、缓存、是否需要登录、日志字段。
- 每个 source 只能访问 manifest 白名单域名；跨域跳转默认拒绝。

## 后续 spike 清单

1. 定义并验证声明式规则最小 schema：一个 fixture HTML 搜索页、一个详情页、一个 pages JSON。
2. 写 ArkTS-only 规则解释器原型：输入 fixture 字符串，输出 Koma `SearchResult / SourceComic / SourcePage` DTO。
3. 做 WAMR native CLI spike：加载固定 wasm，调用 `source_search(ptr,len)`，host 提供 `http_fetch` stub，从 fixture 返回 JSON。
4. 做 wasm3 对照 spike：同一 ABI 和 fixture，比较包体、崩溃边界、调用性能和构建复杂度。
5. 审核文案 review：确认高级设置不出现在首屏、不暗示公共源和聚合能力。

## 参考资料

- HarmonyOS 离线文档：`@ohos.net.http (数据请求)`，本地路径 `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/modules/ohos/@ohos.net.http (数据请求).md`。
- HarmonyOS 离线文档：`Node-API`，本地路径 `/home/gamer/.codex/skills/harmony-next/references/JsEtsAPIReference/topics/misc/Node-API.md`。
- wasm3 GitHub: <https://github.com/wasm3/wasm3>
- WAMR GitHub: <https://github.com/bytecodealliance/wasm-micro-runtime>
- QuickJS official page: <https://bellard.org/quickjs/>
- Aidoku organization / source architecture reference entry: <https://github.com/Aidoku>
- Tachiyomi Extensions historical reference: <https://github.com/tachiyomiorg/extensions>

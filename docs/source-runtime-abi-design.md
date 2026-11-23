# 书源运行时接口设计评审

目标是让站点协议、数据格式和处理流程可以随书源独立发布。设计对象是书源能调用的操作、调用间可传的数据、App 如何消费结果，以及这些合同如何演进。本文是设计提案，当前能力以 [源包与运行 ABI](source-runtime-abi.md) 为准。

## 源作者面对的 SDK

App 实现受控的宿主 API，源 SDK 把它封装成方便调用的函数。SDK 也可以提供在 WASM 内执行的普通库函数，例如 JSON 解析、URL 处理和编解码。只有底层需要 App 提供新行为时才要同步宿主。调整 SDK 封装、增加纯库函数或改变站点调用顺序，可以编进源包发布。评审每项宿主操作时，应指出源缺少的外部数据或系统操作、明确输入输出和授权，并检查不同站点流程能否直接复用它。用于说明这种关系的单个功能只提供对照依据。

以下用拟议签名列出作者视角。准确的生产名称及旧客户端支持范围见现行 ABI。

| SDK 调用 | 源能做什么 | 实现落点 |
| --- | --- | --- |
| `http.request(request) -> Result<Response, TransportError>` | 发有方法、地址、头、正文和可选会话的请求。按响应状态和内容决定下一步，例如解析目录、更新票据、发送第二次请求。 | App 执行请求，SDK 序列化参数并解析响应。本地 1.6.1 的文本、字节、引用及响应元数据合同见现行 ABI；本表签名仍是作者视角示意。 |
| `response.text(limit) -> Text`、`response.read(buffer) -> Count` | 读文本，或逐块把原始响应读到自己的缓冲区，直接在 WASM 解压和解析。 | 本地构建已有受控 BodyRef 读写与图片产物交接；SDK 封装缓冲区和引用生命周期。实际名称与限额以现行 ABI 为准。 |
| `private_state.begin()`、`commit(lease, value)`、`invalidate(version)` | 开始时读回本源值及版本，或取得独占初始化的认领。写入新票据或使旧版本失效。源决定值的结构和有效期。 | 现有宿主私有会话 RPC。SDK 可包装旧协议。 |
| `web.request(target, resume_data) -> PendingInteraction` | 在流程中提出用户需要参与的网页登录或验证。完成后继续当前源定义的步骤。 | 现有网页会话和重试机制可复用。允许源提交续接位置是候选。调用返回待交互结果，结束当次执行。App 收到用户结果后再启动源，后台任务按原规则处理。 |
| `runtime.now_ms()`、`runtime.random(buffer)`、`runtime.cancelled()`、`runtime.log(level, message)` | 读时间、产生安全随机数、检查是否取消、写诊断。 | 底层导入已有。适合通过 SDK 给出统一包装。 |
| `html.parse(text)`、`document.select(selector)`、`node.text() / attr(name)` | 在源代码里实现网页解析；用完释放节点或文档。JSON 等纯数据解析使用源内库。 | HTML 底层导入已有；SDK 可包装句柄。 |

例如看漫画可以用 `runtime.now_ms()` 判断图片签名时间，再用 `http.request()` 更新原站给该页的地址。将来签名格式变化，源换解析函数和条件即可。App 保持既有原语语义及请求执行边界。[宿主导入表](../entry/src/main/cpp/wasm_runtime_adapter.cpp#L344)

统一 HTTP 数据与字节引用已有本地构建合同；下文早期候选形状不替代现行 ABI，也不代表已经公开发布。通用交互 checkpoint 仍是提案。多输入页图、服务端提前撤销图片票据是检验边界的假设，需要真实需求和可行性证据才能进入实施范围。

## 现有实现哪里绑住了 App

| 已有例子 | App 为什么得更新 | 应归谁 |
| --- | --- | --- |
| 再漫画延迟加载章末吐槽 | `SourceTextPageDescriptor` 只接受一个具名的延迟文字页模板。再有一个站点想延迟加载原生文字页，App 往往要新增识别分支。 | 文字排版、字体度量及页图缓存留在 App。何时请求、如何解析、标题和段落由源返回。适配新站应复用已支持的文字页表现。全新的展示行为由 App 定义。 |
| 正文取图 | 原 URL 描述和单输入处理器不能交付源经多次请求生成的成品。本地 1.6.1 的 BodyRef 图片交付已补充这条通路，其实际验收与发布范围独立记录。 | 取票、选请求、获取多份材料和还原属于源。App 提供有边界的请求、数据传递和最终页图准备。 |
| 设置值的校验 | `SourceSettingsStore` 识别 UUID 列表、正整数等具名规则。增添站点约束可能要求改宿主校验分支。 | 字段类型、草稿、提交事务归 App。站点自己的字段组合约束应由源根据草稿返回字段错误。 |
| 网页会话 | 同源 WebView 请求、用户授权及会话有效性由宿主管理。站点改变取数顺序时，现有验证后重试原请求未必能从实际停下的步骤恢复。 | App 维持原生会话和操作生命周期。源决定何处需要交互、交互后执行哪一步。 |
| 章节目录 | 站点目录位置、原章身份、App 展示顺序和续章相邻关系是不同的信息。混用时，站点的多版本或非标准话数会反复逼出排序修补。 | 源给稳定 ID、已核实的目录顺序和分组。App 统一负责排序选项、开始阅读、阅读进度、同步及旧数据兼容，按[现行章序合同](source-runtime-abi.md#网页会话与章序)处理。 |

源码依据见 [章末文字页描述](../entry/src/main/ets/model/SourceTextPageDescriptor.ets#L12)、[正文请求解析](../entry/src/main/ets/model/ReaderPageSourceAdapter.ets#L937)、[设置预校验](../entry/src/main/ets/sourceRuntime/SourceSettingsStore.ets#L200)、[网站会话](source-runtime-abi.md#网页会话与章序)。

## 职责分界

| 层 | 可以负责什么 |
| --- | --- |
| App 产品层 | 何时加载列表、封面、目录和页图，什么时候允许用户交互。拥有界面、书库、下载、进度、缓存、系统权限及账号授权。接收稳定的作品、章节、页图、设置或错误结果。 |
| 宿主中的书源运行时 | 执行 WASM，并提供受约束的网络、临时数据、源私有状态与已有用户交互。给调用带上源、安装、设置、请求生命周期和授权范围，统一处理限速、取消、重定向及资源回收。运行时随 App 安装。 |
| 书源包与编入包的 SDK | 在运行时之上编排站点流程。可以自己选域、发请求、读二进制、解析、分页、计算、合成页图、判断站点错误和选择降级路径。SDK 是编到包里的代码，新增格式库和共享站点协议库可以随源更新。 |

宿主实现 TLS、连接调度、系统 WebView、凭据和数据隔离。纯站点逻辑优先用 WASM 一次或多次调用已有宿主操作。App 的调用方只关心流程回来了什么结果，不需要知道它发过几次请求或采用哪种拼图算法。

## 候选宿主协议

保留 `search`、`get_manga`、`get_chapters`、`get_pages`、`get_image_request` 等产品入口。每次执行得到调用上下文，返回产品结果、失败，或者有待用户完成的动作。SDK 在原宿主桥里调用有类型和版本的操作。底层可复用现有 `koma_host.http_request` 已用于私有会话 RPC 的类型派发，沿用已有 WASM 导入。以下是拟定形状。

```ts
type Handle = string // 宿主发放，只能在发放它的作用域使用
type Body = { text: string } | { bytes: Handle }

type HostOperation =
  | { op: "http.request"; url: string; method: string; headers?: Record<string, string>;
      body?: Body; session?: Handle; response: "text" | "bytes" }
  | { op: "bytes.read"; ref: Handle; offset: number; limit: number }
  | { op: "bytes.create" }
  | { op: "bytes.append"; ref: Handle; base64: string }
  | { op: "bytes.close"; ref: Handle }

type HostRequest = { type: "source_io"; version: 1; operation: HostOperation }
type HttpResult = { status: number; finalUrl?: string; headers: Record<string, string[]>; body: Body }
type PreparedImage = { kind: "bytes"; ref: Handle }

type SourceResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: { code: string; retryable?: boolean };
      interaction?: { kind: string; target: string; resume: string } }
```

- **取数和传数据。** HTTP 返回状态、最终 URL、允许读取的响应头与正文。正文可以是文本，也可以是可分块读的字节引用。源可对多个输入自行处理，分块写入输出引用，再把它随受支持产品结果交还。临时引用只在当前源和调用内有效，大小及并发有上限；引用不写进设置、页表或日志。宿主在调用结束前认领成功结果中实际引用的成品，其余引用随调用回收。读写失败、超额和取消都显式返回错误。
- **延迟产出图片。** `get_pages` 可声明 `image.kind = "source"`，保留稳定的 `page.id`。页进入准备流程时，沿用 `get_image_request(pageId)`，允许源返回普通远程图片描述，或 `{ kind: "bytes", ref }`。后者表示已准备好的图片字节。App 校验、解码并原子入缓存，现有阅读、预载、下载和分享共用成品。引用无法跨调用保存，缓存沿用页图身份，并核对安装、设置和会话范围；强制重试只重跑该页。旧 URL 路径和单输入处理器继续支持。
- **状态和交互。** 跨普通调用仍使用原有按源隔离的私有会话能力，普通算法无需常驻 WASM。需要交互时，`target` 指当前安装包已授权的站点入口，`kind` 必须是 App 已支持的网页验证或网页登录等动作。前台原操作有权限才出示界面；静默任务返回可处理的状态。结束当前调用，释放临时引用。完成后 App 用同一个产品入口、原参数和交互回执重调，带回小型续接数据。回执绑定源、安装、设置、原操作及对应授权，一次消费。切换、取消、退出或授权失效使其作废。源以完成后的原站结果确认成功；结果不明的写请求有幂等依据才重发。
- **设置与原生结果。** 设置可继续用宿主认识的组件和字段类型。拟允许源对草稿作无网络校验，输出 `{ fieldId, message }`。App 校验字段类型，并在持久化前确认校验对象仍是同一安装和待提交草稿版本。通用文字页让源输出原生表现可消费的标题与段落，并沿同一页图准备流程按需取文本。旧源的版式和行为继续沿用。新增原生交互或新增一种界面结果有独立的消费合同。

## 用一条完整路径检查组合是否成立

假设一个新站每页由多份材料组成，先用 POST 拿本页材料清单，之后取图并用独立的描述数据拼成一页。

1. App 从 `get_pages` 得到页 ID 和 `source` 图片描述。阅读、预载或下载真的需要此页时才执行图片操作。
2. 源发取票请求，再依票据取回材料和描述。每次请求都走原生请求权限和会话范围。源在自身 WASM 内解压、解析与拼图。
3. 源将完成的图片交给 App，App 验证并缓存。阅读和下载都消费同一份成品，离线打开读原有离线数据的合同。失败保留页 ID，使重试对应原页。
4. 同站更换拼图算法，或另一个站点改用不同的包封格式，源更换获取和合成代码，交付仍是一张已知格式的图。两个源使用同一套宿主操作，包内协议可以完全不同。

另一类可用来检验边界的是目录从静态 HTML 改成多步票据加二进制列表。源换获取和解析流程，App 仍收到同样的章节和游标，历史记录用原有 ID 命中。需要原生系统授权或引入一种 App 无法消费的结果时，才出现新的宿主任务。

## 从书源主动调用的接口看扩展能力

App 调用源的现有产品入口，以启动一次读目录、取页图等工作。在该入口内，源主动向宿主请求它需要的通用操作，顺序和条件由源代码决定。两种调用方向承担不同职责。

现有例子是看漫画的图片签名刷新。源调用宿主取时间，发现签名即将过期时再调用宿主 HTTP 获取原章图片列表，选择同一页的新地址。App 照常收到 `{url, headers}`，无需认识看漫画的签名格式。这种扩展只需要源包。

拟议的数据接口延伸了同一个模式。下面是源作者在正常取页时会写的代码，`host` 是向宿主发起调用的 SDK 封装，`site` 是源自己的实现。

```js
const manifestResponse = host.http({ url: site.manifestUrl(pageId), response: "text" })
const manifest = site.parseManifest(manifestResponse)
const parts = manifest.parts.map(url => {
  const response = host.http({ url, response: "bytes" })
  return host.readBytes(response)
})
const png = site.assemblePng(manifest, parts)
const ref = host.writeBytes(png)
return { image: { kind: "bytes", ref } }
```

读取与写入由 SDK 通过上面的字节操作分块实现。App 接收一种通用的图片成品，自此不用认识站点的清单和拼图方式。比如另一站返回加密压缩包，源可替换成一次下载、解密和解包，交付同一张已知格式的图。这些后续适配用冻结的 App 验收。

这个字节交付方式需要含相应实现的宿主，本地构建已有的具体 wire 形状见现行 ABI；不能用旧试点 App 代验。按需章末文字页仍须由宿主支持具体消费合同，不能从数据能力推断任意页面表现也已支持。

## 可行性与代价

现有 WASM 导入已经能让源重复调用并交换小块 JSON。C++ 回写受调用者输出缓冲区容量约束，整张图不能经原结果信封搬运。字节操作须把每次复制限定在小块，较大的中间物料可由宿主在其私有目录暂存，按调用记账，退役时回收。源不接触文件路径。实现可以先采用有界暂存，流式传输有相同的读取合同。高频单 URL 图片继续走现有原生 GET 缓存路径，已有性能开销不加一轮 WASM 拷贝。[宿主响应写入](../entry/src/main/cpp/http_host.cpp#L23) · [当前页图缓存路径](../entry/src/main/ets/model/ReaderPageSourceAdapter.ets#L1258)

这里确实需要一次宿主改造。运行时要能在 WASM 返回后把成功产物的所有权交给页图准备服务，不能仅加几个字节读写方法。页图准备服务须为新描述建立正常的缓存、重试和下载接入。多输入开销、取消后的回收、切源时作废以及渲染与下载共用成品是需要验证的风险。计算仍在源包中，后续纯格式或算法变化无需新增宿主类型。

## 实施顺序与代码落点

实施基线引用唯一 [源包与运行 ABI 的本地 1.6.1 构建合同](source-runtime-abi.md#可组合数据通道-v1本地候选)，不在本文另存一份“当前版本”判断。2026-11-23 本轮 1.6.1 仍仅本地、未推送或发布；巴卡普通路径尚未完整验收，新构建具备通道不等于站点内容、阅读或下载已经可用。237 最早的 MYCOMIC 和哔哩漫画拦截器试点使用 1.5.5，只证明旧 ABI 下的源包兼容，不能作为本轮新能力的宿主依据。宿主验收须核实际构建与对应 feature；App 版本名、可选能力和基础 ABI 分别管理，只有核心路径确实依赖新宿主时才提高源最低版本。

### 已采用的框架范围与第一期

六类能力共同服务于“书源主动组合宿主操作”。App 继续以原产品入口启动源操作；网站协议、算法和流程留在源包。不得把下面的范围再次缩成某个站点的专用服务，也不因本期先实现数据通道而删除其余范围。

| 能力域 | 第一期实际落点 | 后续在同一合同内扩展的边界 |
| --- | --- | --- |
| HTTP | `http::RequestSpec/Response`、原拦截器、公开响应头、真二进制上传、有界正文引用 | 更完整的浏览器与专用传输组合；每次请求和跳转仍受准入 |
| 数据和图片 | `body::BodyRef` 创建、分块读写、关闭、`image_result`；宿主分块落盘，成功产物一次性交给阅读/预载/下载共用缓存 | 更多通用产物消费者；不同源的解压、解密、拼图用源内库实现 |
| 会话和私有状态 | `SessionRef` 选择已有浏览器授权或源 Cookie jar；`PrivateSession` 包装既有 begin/commit/abort/invalidate | 多键事务、存储期限须沿已有安装隔离与并发代际合同扩展，不能另建站点令牌后门 |
| 浏览器执行 | 旧同源 GET 桥接与本地 `source_web_http_v1` 的方法、文本/字节/BodyRef 组合见唯一 ABI；不是已发布能力，也不是通用 DOM/JS 授权 | 共用请求、会话、超时、取消；明确 attempted 后不原生重放。旧 POST 自动换通道与显式原生选择的兼容问题仍单独待处理，不借本地化设计改选路 |
| 可恢复任务和交互 | 保留原搜索续接和一次性原操作认领，尚未扩成通用 checkpoint | 统一交互与定时等待回执；临时 BodyRef 不进入 checkpoint；后台下载不自动弹界面 |
| 环境和能力 | `runtime::Context` 已查询 feature 和资源限制；时钟、随机数和取消包装现有 import。下节的语言快照、SDK 文案及静态 presentation 是提案，尚未实现 | UI 语言、内容语言、站点 HTTP 语言和授权 UA 分开；只按实际通用环境扩展，不从版本号或源 ID 猜测 |

共同数据类型从 `Request/Response`、`BodyRef` 和 `SessionRef` 开始。`Continuation` 的生命周期沿原操作守卫设计，尚未提供跨操作通用实现。源 SDK 维持 no_std、调用方缓冲区和旧 `Request::from_json`；本期不增加原生 import，不改变基础 ABI。新增 hostFeatures 是 App 构建真实具备的能力，不能将同版本号的旧正式包当作具备新合同。

BodyRef 是宿主私有暂存文件的随机引用，不是路径、WASM 指针或持久状态。每次调用独立记账，支持多份材料和有限随机覆写；源内算法分块读取、处理并写入另一 BodyRef。调用失败、取消、trap 和正常返回都清理未交接材料。仅成功 `get_image_request` 的 `image:{kind:"body",ref}` 能交出非空图像；宿主生成一次性交接凭证，消费方核对源包身份后接管，超时未认领自动清理。图片进入既有缓存与解码管线，普通 URL 图片继续原生直连，不被强制串入源 HTTP 队列。

当前 HTTP 引用模式在接收回调中分块落盘，避免完整正文及 Base64 信封同时驻留；同步 WASM import 结束后才允许源读引用。这不是 WASM 在下载尚未结束时并行读取。普通图片下载原有进度及提前尺寸回调保留；未来若需要源内实时消费，须单独定义异步任务和生产者/消费者背压，不能用这个实现冒充。

### 环境域：书源用户文案本地化（实施中，尚未真机验收）

本节保留 2026-11-23 对原仓调用链的设计核对。用户随后同意实施，App、SDK 和 Komiic 试点正在接入；当前真实合同与兼容规则以 [ABI](source-runtime-abi.md) 为准，构建与真实 WASM 执行不代表真机验收或正式发布。它覆盖源提供的用户文案，包括设置和源描述；不修改现有控件、样式或站点行为，也不替代巴卡正在进行的网络与阅读验收。`SOURCE_MULTILINGUAL_CATEGORY` 的 `all` 分类命名已有独立结论，与本节无关。

设计时，源仓 `docs/WRITING_A_SOURCE.md` 的 listInfo 段曾写“显示标签和源文本由源按请求既有locale负责，不另造本地化机制”。当时实际 builder 没有提供这个 locale：Browse、Settings、详情、章节、页表、认证和评论请求只有各自参数、设置与 hostHints；公共 `sourceRequestWithHostFeatures` 加入的是 feature 和资源限额。SDK 的 `runtime::Context` 当时也只有 feature、limit 和取消查询。该句的“既有”已单独更正；下面的现状表记录设计基线，不作为实施后的能力清单。新实现的真实字段、兼容规则及消费方式同步到唯一 ABI 和源制作规范。

#### 已核现状与完整文案范围

| 文案或上下文 | 当前实际实现 | 本提案的职责与缺口 |
| --- | --- | --- |
| App 界面语言 | `LanguageSettings` 发布 `LanguageState.effectiveLocale`；支持跟随系统及现有五种界面语言选择 | 复用实际有效语言，不另设一个源 UI 语言菜单；内容语言设置仍独立 |
| 源名 | `localizedNames` 已贯通 metadata 打包、manifest/index、Importer、Registry、名称解析、搜索和管理页排序 | 保留现有能力，适配到统一静态 presentation；不用英文名或第一项替代旧基名 |
| 源描述、作者等包显示资料 | `SourceInfo` 为静态字符串；build.sh 从 source_info 提取 name/description 等，metadata 只投影已认识字段；Registry 的 package/presentation description 仍是字符串 | 名称、描述及明确的显示资料共用文本资源类型，安装前后与离线展示都须覆盖 |
| source_info | SDK 导出 `koma_source_info()`，Native adapter 真实以零参数调用，不接收请求 JSON | 保留稳定的规范元数据；静态翻译从 manifest/index 解析，不能假装加请求 locale 就能影响此导出 |
| 源设置 | `get_settings` 返回 name/label/title、description、options 的 label；Host 归一化为普通字符串 | SDK 按调用环境生成同样的字符串；说明、选项、分组/提示等已支持的显示位置一起覆盖 |
| 设置校验 | validation.message 是源字符串；non_blank、UUID、正整数、Java regex 等规则由既有校验消费 | 翻译错误说明，保留 kind、规则、草稿、默认值及保存语义；不以本地化新增校验行为 |
| 筛选 | name/label、description、header 与 option label 都是字符串；旧字符串 options 同时充当值，缺 id 时还会以名称回退 | 新接入翻译的源必须显式固定 filter.id 和 option value/id；只翻译显示文字，不能让旧保存值跟着改 |
| 栏目、首页与链接动作 | get_listings.name、get_home.sections.title 由源给出；支持 mangaList/listingLink，缺省栏目由 AppStrings 生成 | 栏目和源自有标题使用同一 SDK 文本库，listingId、kind 和目标不变；Host 自带缺省仍用 AppStrings |
| 原生登录、验证与动作 | 包/运行时认证 descriptor 可有 usernameLabel/passwordLabel；按钮、验证恢复及通用提示主要归 App。未发现任意源 action 执行合同 | 静态显示标签可投影；不能因此增加任意 action、占位控件或脚本入口。原有 action 若只改文案，也不得改行为/目标 |
| 尚未消费的显示声明 | 当前设置 DTO 没有通用 placeholder、单位后缀或任意按钮执行合同；有一段字符串不等于有对应控件 | 公共文本类型可复用，但缺少的显示/动作能力仍须独立定义消费，不把本地化草案写成这些能力已经存在 |
| 错误与警告 | error.message/warnings 是普通源数据；当前 SourceRuntimeError 主要按稳定 code/status 映射 Host 文案，不把任意站点消息直接显示 | 源内生成说明可共用文本库，但不能把诊断消息升级为 UI、改变错误分类或绕过现有提示规则 |
| 列表摘要及源生成文字 | listInfo 的 text/label/tags、源生成的 subtitle/章节模板等是纯文本；SDK 不推断 locale | 通用标签、模板可翻译，数字与站点原文作参数；不增加逐作品请求，不改 listInfo 的顺序及字节限额 |
| 网站内容 | 作品/章节标题、简介、作者/汉化组、题材、评论、文字页 heading/paragraphs、叠字等由源给出，主要按原文消费 | 分清源编写的 UI 模板与网站正文。能力可供源表达真实已有翻译，不自动机翻内容或切换作品版本 |
| 内容语言与传输语言 | 源 language/lang、章节 language/locale 表示内容；HTTP Accept-Language 与验证 UA 分别归原站请求和授权会话 | 三者均不能拿来充当 UI locale，也不因 App 语言变化改内容筛选、HTTP 头、Cookie 或 UA |
| 缓存与语言切换 | 名称解析及管理页有 locale 投影；Browse 首屏缓存按包、设置、认证、会话和筛选隔离，未含 UI locale；设置半模态保留已加载 descriptors；详情快照也没有 UI 语言代次 | 对源生成的显示元数据补语言隔离和迟到结果检查；不把语言切换当全库、图片、页表或账号缓存失效 |

App 依据：[语言设置](../entry/src/main/ets/i18n/LanguageSettings.ets)、[源名解析](../entry/src/main/ets/sourceRuntime/SourceLocalizedNames.ets)、[Browse 请求与缓存](../entry/src/main/ets/viewmodel/BrowseViewModel.ets)、[设置 schema/请求](../entry/src/main/ets/sourceRuntime/SourceSettingsStore.ets)、[筛选标签和值](../entry/src/main/ets/model/SourceModels.ets)、[认证声明及身份比较](../entry/src/main/ets/sourceRuntime/SourceAuthenticationDescriptor.ets)、[错误消费](../entry/src/main/ets/model/SourceRuntimeError.ets)。源仓依据为原仓 `sdk/src/lib.rs` 的 SourceInfo/零参导出、`sdk/src/runtime.rs`、`sdk/src/list_info.rs`、`build.sh` 与 `scripts/read-source-localized-metadata.py`，并非仅据规范推断。

#### 一个通用环境快照，运行时继续返回字符串

拟议仅增加一个通用 feature：`source_localization_v1`。它只协商读取 Host 提供的语言环境，不决定源内 Catalog 是否可以使用作者默认语言；不拆 settings_i18n、description_i18n 等字段级 flag，也不授予任何新网络或 UI 权限。以下为加入原操作信封的设计增量，未省略的原字段仍按旧 ABI：

~~~json
{
  "hostFeatures": ["source_localization_v1"],
  "environment": {
    "version": 1,
    "uiLocale": "zh-Hant-HK",
    "localeFallbacks": ["zh-Hant-HK", "zh-Hant", "zh"]
  }
}
~~~

宿主在入队前从调用侧捕获一次有效 App 语言，经统一装配进入所有有请求参数的源操作；同一调用、其 HTTP 子请求和本次既有交互续接保持这个快照。Worker 只接收序列化值，不能连接 UI 状态，也不在执行中重新查询系统语言。重调原操作时沿其原请求快照；后续新逻辑调用才取得新快照。语言切换不能因此重发旧 POST、取消有效授权或变更原验证因果。

Host 只在实际装配了合法 environment 时声明该 feature；SDK 须同时核 feature、environment.version 和语言标签，才读取其中的 UI 语言。无 feature、缺字段或未知环境版本时，将 Host 语言视为未知：采用新 SDK/Catalog 的源仍先按 Catalog.defaultLocale 查本字段，再退该字段 literal，不猜英语、源内容语言或操作系统语言。Catalog 本身缺失、版本不认识或默认条目不可用时才直接沿 literal；未采用 Catalog 的旧源原样不变。source_info 的零参 ABI 保持原样；它不通过新增 import 偷读全局语言。时区和其他环境信息不借本节一并实现。

推荐复用一套源所有的文本目录及匹配算法，SDK 在 WASM 内选择文案，返回现有 plain strings。SettingsFieldDescriptor、SourceFilter、SourceListingDescriptor、正文与错误消费者不改成 `string | LocalizedObject`。App 不根据源 ID、英文句子或设置 key 硬编码翻译。

#### 可组合文本资源与 SDK 示例

拟议公共文本模型为“literal 回退 + 可选 message key + 参数”；目录按 key 保存各 locale 的模板。它是源内 SDK 数据类型，不是给每个 UI 字段再加一个 locale 方法。metadata 中可维护同一目录，编译进 WASM；构建器只把静态显示所需条目投影进 manifest/index。例如作者资料：

~~~json
{
  "localization": {
    "version": 1,
    "defaultLocale": "zh-Hant",
    "messages": {
      "source.name": {
        "zh-Hant": "示例漫畫",
        "zh-Hans": "示例漫画",
        "en": "Example Comics"
      },
      "source.description": {
        "zh-Hant": "提供本站公開漫畫目錄。",
        "zh-Hans": "提供本站公开漫画目录。",
        "en": "Browse the site's public comics catalogue."
      },
      "settings.quality.label": {
        "zh-Hant": "圖片品質",
        "zh-Hans": "图片质量",
        "en": "Image quality"
      },
      "settings.quality.description": {
        "zh-Hant": "只影響之後請求的圖片。",
        "zh-Hans": "只影响之后请求的图片。",
        "en": "Applies to subsequent image requests."
      },
      "settings.quality.original": {
        "zh-Hant": "原圖",
        "zh-Hans": "原图",
        "en": "Original"
      },
      "settings.exclude.validation": {
        "zh-Hant": "請輸入以逗號分隔的 UUID。",
        "zh-Hans": "请输入以逗号分隔的 UUID。",
        "en": "Enter comma-separated UUIDs."
      },
      "summary.chapter_count": {
        "zh-Hant": "共 {count} 章",
        "zh-Hans": "共 {count} 章",
        "en": "Chapters: {count}"
      }
    }
  }
}
~~~

以下 Rust 名称均为拟议 SDK API，当前不存在，不是已编译示例：

~~~rust
use koma_source_sdk::{localization::Catalog, runtime::Context};

const METADATA: &[u8] = include_bytes!("../metadata.json");
let context = Context::from_request(request);
let catalogue = Catalog::from_metadata(METADATA)?;
let mut label_buf = [0u8; 256];
let label = catalogue.text(
    &context, "settings.quality.label", "Image quality", &mut label_buf,
)?;
// 仍向原 schema 的 name 写 JSON 字符串；真实 id/default/value 保持原值。
append_json_escaped(payload, &mut cursor, label)?;
~~~

本例 defaultLocale 为 zh-Hant，而字段 literal 为 English：新 SDK 在旧 Host 没有 feature/environment 时也会返回「圖片品質」；只有默认语言的这个 key 也缺失或无效时才用「Image quality」。这是作者明确的默认语言，不是取 messages 对象第一项。该规则针对执行了 Catalog 的源代码；旧 App 对静态 name/description 的展示仍只消费其认识的旧字段，不假称它能解析新的 presentation。

说明、选项、校验、栏目、源生成摘要及已有动作的显示名称都调用同一个 text/format helper。参数允许明确的纯文本或数值，转义后写入；完整语序由各语言模板决定，不在 App 拼“已找到”之类片段，也不执行模板中的代码或 HTML。需要复杂语法时源可用源内库产生最终字符串，不在首版自行造完整 ICU 引擎。输出仍服从原字段的 UTF-8、容量和纯文本限制。

例如选中的 UI locale 为 zh-Hant 时，现有 get_settings 响应形状不变：

~~~json
{
  "settings": [
    {
      "id": "image_quality",
      "kind": "select",
      "name": "圖片品質",
      "description": "只影響之後請求的圖片。",
      "default": "original",
      "options": [{"value": "original", "label": "原圖"}]
    }
  ]
}
~~~

源负责翻译资源、模板语义及默认语言。App 负责有效语言、调用快照、通用匹配规范、展示和缓存生命周期。来源品牌、网站作品原文及用户输入保留来源语义；设置 ID、option value、枚举、作品/章节/版本/页 ID、cursor、URL、正则及授权声明不能作为待翻译文本。

#### 静态 name/description 的离线投影

拟议构建器把同一目录中的静态条目生成统一的可选 presentation 扩展；旧 name/description 仍由规范 SourceInfo 产生并保持字符串，供旧宿主和零参 source_info 使用。下面是安装包清单或索引项中的显示增量示意：

~~~json
{
  "name": "Example Comics",
  "description": "Browse the site's public comics catalogue.",
  "localizedNames": {
    "zh-Hant": "示例漫畫",
    "zh-Hans": "示例漫画",
    "en": "Example Comics"
  },
  "presentation": {
    "version": 1,
    "defaultLocale": "zh-Hant",
    "texts": {
      "name": {
        "zh-Hant": "示例漫畫",
        "zh-Hans": "示例漫画",
        "en": "Example Comics"
      },
      "description": {
        "zh-Hant": "提供本站公開漫畫目錄。",
        "zh-Hans": "提供本站公开漫画目录。",
        "en": "Browse the site's public comics catalogue."
      }
    }
  }
}
~~~

`texts` 的值均为同一种 locale→字符串资源，不是每字段一套协议。第一版覆盖 name、description；已有原生认证字段标签也须通过显示投影覆盖，可使用同结构的明确显示角色 `authentication.usernameLabel/passwordLabel`，不修改原 authentication 对象。作者等其他确有翻译的显示资料可沿相同类型接入，机器字段不参与。

作者只维护一份目录：构建器生成旧 localizedNames 和新 presentation 的一致投影，冲突须在打包时明确报告。仅有旧 localizedNames 的源适配成 name 资源，描述沿旧 literal，不假造 defaultLocale。旧宿主继续读取旧字段；新宿主优先使用包内已校验的 presentation。未安装索引用自己的静态投影，不能覆盖已安装包的显示资料或授权声明。

新扩展的未知版本不启用；坏的可选译文按本 key 继续后续语言候选、defaultLocale 和 literal 回退，不因一个坏译文让整源消失。目录 key 完全不存在时显示 literal，不把内部 key 当用户文案。新资源不能把无效值投影进旧 localizedNames，污染原本合法的旧显示资料；旧 localizedNames 原有的必需校验不因新扩展而放宽。

拟议预算沿现有包、索引、WASM 与字段限额执行，不建立绕开原限额的翻译附件：presentation.name 沿旧名称的 128 个 UTF-16 单元及纯文本校验，描述及其他字段沿各自现有界限，格式化后仍核最终输出容量。locale 标签沿现有名称元数据的 63 字符界限；每个 key 的译文 locale 数和 environment.localeFallbacks 数均拟先核原始项数不超过 16，再去重按明确顺序消费，不按目录大小扩张匹配工作。坏 locale/译文只跳过相应可选项，进入默认语言回退时若 defaultLocale 无效，则退 literal；预算不足时不截断成半个 UTF-8 字符或替换身份字段。原整包/索引硬大小、JSON 结构和归档安全检查仍执行，不以按键容错放宽这些边界。

资源中存在一条消息、动作名或说明，不表示它会被显示或执行。尚未有正式消费者的消息/动作继续不消费；只有原合同已允许的位置解析文字，绝不从翻译 key、模板或标签派生按钮、目标、授权或执行入口。

Importer、Registry 重载及所有复制路径都要保留扩展；管理页、浏览、搜索、详情的 sourceName 展示共用一个 resolver，不能只改列表第一处。备份恢复与分享目前从规范化 manifest 重建归档，也须 round-trip 该扩展。切换语言只重建显示投影，不把翻译写回规范 name/description。历史作品保存的源名仍只作缺源时的 literal 回退，不批量改用户书库。

翻译资源只能编入现有 source.wasm 和 manifest.json；索引只带静态显示所需子集。仓内可有编译输入资料，标准归档仍只保留清单、WASM 和身份图标。`SourcePackageImporter.validateArchiveEntries` 会拒绝任意新增 ZIP 成员，不能直接把 locales/*.json 塞进包中当已支持资源目录。

#### fallback、语言切换与缓存

匹配规则须由 SDK 与宿主静态 resolver 共用规格：已知请求 locale 时，精确匹配 → 保留显式脚本的地区/脚本回退 → 语言项 → 源明确的 defaultLocale 及其同规则候选 → 该字段旧 literal。请求 locale 未知时只省略请求语言候选，仍走 defaultLocale → literal。缺翻译、未知 key 或缺省语言不能取对象/目录第一项，不能硬编码英语。旧包没有 Catalog/defaultLocale 时，按其既有精确/脚本/语言规则后退旧 literal；旧源不会被自动赋予新目录。

中文须识别 zh-HK/TW/MO 的 Hant 与 zh-CN/SG 的 Hans，显式脚本优先；zh-HK 的精确条目仍先匹配，随后可用 zh-Hant-HK/zh-Hant/zh，不能误走 zh-Hans。只有明确的源默认语言回退才能进入另一脚本，不能按“zh 都一样”猜测。语言标签大小写规范化、重复项、无效 Unicode 与缺省行为在两端一致。

| 位置 | 拟议缓存/切换处理 | 保留边界 |
| --- | --- | --- |
| 静态 presentation | 原资源随已校验包/索引保存；投影按包身份、资源版本和有效 locale 缓存，切换后本地重算 | 不重下索引/包，不改安装、源设置或会话身份 |
| Settings 与本地栏目 schema | 以 source/package/settings/观察数据及语言快照区分结果；重新打开按当前 locale 取 schema；活动表单可重取显示描述，按原字段 ID 合并 | 不重新套默认值、不清草稿/筛选、不把换语言当保存设置或更改 revision |
| 动态 filters、首页、搜索及列表 | Browse 首屏和 schema 加语言键与显示代次；新读取使用当前快照，迟到旧语言不能覆盖新代次。动态标签数据仍沿原延迟请求和打开时机 | 保留查询、栏目、optionIds、scope、值、内容与原成功游标；不在换语言时逐作品补详情或无界重取 |
| 详情、章节与持久化内容 | 网站原文继续按旧内容身份存储；若源生成的展示模板受 UI locale 影响，其显示快照须单独带语言身份 | 不能改 readingOrder、分组、进度、下载、内容 language 或全库重写 |
| 原生认证/验证 | 展示层翻译标签和 Host 提示；用于声明校验、sourceAuthenticationIdentity、私有会话及授权的原 descriptor 保持规范值 | 现身份计算包含用户名/密码标签，不能把翻译后的对象用于一致性比较，导致登录失效 |
| 图片与文字页 | 普通 URL/成品图片不因 UI 语言失效；源确实生成本地化文字页或叠字时，仅其派生文字产物增加语言身份 | 不清原图/离线缓存，不自动切作品版本，不让语言变化重放图像取票或账号操作 |
| 后台调用、恢复与备份 | 无 UI 的调用从持久 App 语言配置取得同样快照，无法取得时由 Catalog 按 defaultLocale 再退 literal；备份保存资源及原设置值，恢复后按本机语言投影 | 不把设备语言快照当跨设备业务数据，不恢复旧语言到别人的当前会话 |

纯字符串路线有真实代价：已经归一化、只剩最终字符串的缓存不能在无翻译键时即时重译。首版提议静态资料立即离线更新，本地 schema 在安全的 metadata 调用/打开时更新；带网络的源生成摘要按原正常刷新或再次读取更新，失败保留原业务内容，不宣称整页已经换完语言。若产品要求所有已缓存动态摘要零 HTTP 当场重译，须另审同一合同内的受限文本 key/参数旁路；本提案不先把全部字段对象化，也不偷偷增加一个 translate RPC。这个取舍需父审，不能当成用户已经接受的语言切换效果。

旧字符串 filter.options、缺显式 filter.id 或 option.value 的回退尤其要先处理：启用翻译时由源显式发出与旧请求值完全一致的稳定 ID/value，再翻译 label；不能仅翻译旧字符串数组后让 App 保存新文字。这属于采用源的兼容核对，不通过 App 猜译或按标题迁移值。

#### 拟议实施落点、迁移和成本

| 落点 | 必要工作与成本 |
| --- | --- |
| 调用侧环境装配、SourceHostFeatures、WorkerClient/Worker | 在 UI/后台调用所有者捕获一次环境；公共路径透传和验证，再声明一个 feature。覆盖 Browse、Settings、详情、章节、页表、图片、评论和认证，不能只在 Browse builder 填字段；Worker 不读取 LanguageState |
| 源 SDK | 增加统一 locale/Catalog/Text/format helper，维持 no_std、调用方缓冲区和严格顶层读取；无 Host 环境仍先用作者 defaultLocale，再退 literal，未接 Catalog 的旧源不变。旧 RequestSpec/SourceInfo/操作导出不改签名，不新增 Host import |
| 源仓 build.sh 与 read-source-localized-metadata.py | 从同份资料生成 WASM 文案和静态 presentation/旧 localizedNames，核对默认值与版本；索引不复制所有运行时文案，包和 WASM 仍受原限额 |
| SourcePackageImporter/Metadata、SourceIndexMetadata、Registry/Rows | 校验并保留可选扩展，统一字段/locale 文本类型；已有记录缺字段按 literal 兼容，利用现有存储 owner 作有界迁移，不改业务 ID。索引缓存、重载、复制、分享和备份都须覆盖 |
| SourceLocalizedNames、SourceRuntimeAppRegistry、SourcePackageManagerCache 及显示调用方 | 抽出静态 presentation resolver，保留旧源名搜索/排序合同；描述和认证标签也必须实际消费。源资源不进入 AppStrings 的站点翻译表 |
| BrowseViewModel、SourceSettingsSheetHost/Store、详情显示缓存、认证展示 | 增加语言代次与必要缓存键，保留活动草稿及既有错误/认证身份；DTO 字段继续是字符串，不批量改所有控件 |
| 采用本地化的源 | 将自己编写的用户模板接到共同目录；保留 ID/value、原内容语言、网站原文及 HTTP 行为。旧源无需一起重写，翻译范围与缺译仍由各源明确 |
| 唯一 ABI、RUNTIME 方向和源规范 | 实装后才同步实际字段/feature/失效规则，并修正“既有locale”的错误承诺；本提案不代替当前生产合同，也不新建重复工作单 |

成本主要是调用环境全覆盖、静态资料 round-trip 与缓存代次，不是给每个 label 增加对象消费者。资源体积随译文增长；SDK 解析及模板输出有界，Host 静态投影按包/语言复用，不能在绘制比较器里反复解析完整目录。无需翻译服务、额外 ZIP 文件或网站请求，基础 ABI 和旧源可继续工作。可选本地化不单独抬最低 App；依赖新的核心行为仍按原兼容规则处理。

后续实施验证只需真实关键路径：核公共 builder 实际传入快照、新 SDK 在无 feature/环境时选择 defaultLocale、未接 Catalog 的旧源输出不变、HK/Hant/default/literal 及坏译文按键回退、设置/筛选值不变、语言切换时旧回包不覆盖新结果、静态 name/description 在安装前后及备份分享后均一致、认证标签变化不动会话。至少一个采用源和一个旧源沿普通入口核设置、描述、栏目与代表摘要；测试、构建、真机和发布分别报告。本次未运行这些验证，也未修改任何生产代码。

### SDK 对已有宿主调用的封装

在源仓 SDK 中增加类型化的 `Request` 和 `Response`，内部继续走现有 `koma_host.http_request`。默认 GET、现有超时及文本响应。单请求只需传地址；需要时显式设方法、头、正文、会话及响应选项。SDK 返回借用源缓冲区的响应，方法如 `status()`、`text()`、`final_url()`。多个响应需要同时保留时，源使用独立缓冲区或只取需要的数据。旧 API 继续可用，首轮可以只改 SDK 和采用它的源。

```rust
let response = http::send(
    Request::get(trial_url).want_final_url(),
    &mut scratch,
)?;
let document_url = response.final_url()?;
let page = parse_trial(document_url, response.text()?)?;
```

这是源作者看到的候选写法。传输出错和收到 HTTP 错误状态是两种结果。前者返回 SDK 错误，后者留下原状态和可公开的正文供源判断。普通 GET 在旧宿主用已有文本契约。显式请求最终地址时，SDK 根据宿主已声明的能力选择现有协议选项，实际调用由宿主查验授权。宿主能力不足和请求未获授权分别交给源处理。这样 BookWalker 能去掉手写 JSON 和响应字段提取，在现有宿主上仍使用原试读逻辑。私有会话和时间等操作采用同样方式包装已有能力。

### 共用请求描述和宿主执行规则

首个宿主切片为 `responseMetadata`。书源独立选择要读取的响应元数据，验证交接仍由原请求选项及源声明控制。选了 `finalUrl` 的普通网络响应和符合既有条件的一次性文档接续，都回传实际地址。哔哩漫画用它处理精确搜索跳转，即便作品页缺少原来用来推断身份的公开目录链接也可返回作品。旧宿主保留目录链接解析。后续字节传递及交互回执按下文分片接入。 [生产 ABI](source-runtime-abi.md#站点规则声明)

第二个宿主切片是可组合的二进制 HTTP 响应和源内 HTTP Cookie 会话：源在请求中独立选择 `responseKind:"bodyBytes"`、`session:"source"`，并可与 `responseMetadata.finalUrl` 及现有表单 POST 组合。宿主只处理真实网络、字节保真、会话隔离和资源边界，识别算法、隐藏字段、重试次数和成功条件由源决定。首个实际消费者是哔哩漫画：开启上游默认关闭的自动验证码选项后，WASM 取 PNG、按上游字模识别四位数字、提交站点表单，再按原搜索结果或详情解析；没有验证码专用宿主 API。其他源可以复用这两项操作取二进制数据、解析格式并完成自己的多步会话。旧源和旧宿主的既有文本路径继续兼容。此片使用有界 Base64 信封搬运小正文，最大 1 MiB；其后的 BodyRef 分块引用和产物交接已有本地 1.6.1 构建实现，但不能据此反推旧宿主具有大文件通道。确切上限、隔离及未发布范围见 [唯一 ABI](source-runtime-abi.md#可组合数据通道-v1本地候选)。

稳定的 `Request` 同时用于两条入口。源调用 `http::send` 时，结果交回 WASM。源返回远程页图时，App 用同一请求描述直接下载到原有文件准备和缓存通道。App 在 `SourceRuntimeHttpTransport` 与 `ReaderPageSourceAdapter` 之间逐步共用请求的解析、授权、重定向、限速和取消检查，各自保持适合文本与文件的接收方式。Image GET、进度、边下边取尺寸及现有原图缓存沿用原路径。单源与跨源搜索、封面、正文和下载都沿当前入口接入。

新版回包固定区分 HTTP 响应和传输错误。HTTP 响应有真实状态、许可范围内的最终地址和响应头，以及文本或字节正文。原始正文采用上一节的引用读写时，SDK 提供分块封装。宿主限制单块与单次调用的总量，旧回包和它的缓冲区限制保持原语义。源选会话只提供运行时认可的引用，域、授权及调用身份仍由宿主检查。真实请求每次跳转都重核范围，公开响应头和凭据沿不同授权处理。只有已协商的新版才能启用新字段。

迁移先用现有书源跑同路径。BookWalker 的请求保留实际最终地址和现有跳转限制，哔哩漫画与禁漫天堂的声明保留各自限速条件，普通封面和正文保留原缓存及重试。使用新方法获取页图时，源通过明确的页图请求描述指定该方法。宿主区分可自动重试的读取与可能有副作用的请求，保留原声明及重试决定。二进制响应或非 GET 图片请求进入实施时，同时确认生产消费者、限额、取消回收和缓存身份。

### 请求处理采用有序拦截器

源 SDK 可以在类型化请求之外提供可选的 `Client` 和拦截器链。参照 OkHttp，每个拦截器收到同一类型的 `Request`，调用 `next.proceed(request)` 交给下一层，随后收到 `Response`。请求按注册顺序向内，响应按相反顺序返回。没有配置拦截器的普通请求直接交给现有宿主桥。第一版链可随 SDK 编进源包，继续使用现有 WASM 导入。[OkHttp 拦截器设计](https://github.com/square/okhttp/blob/master/docs/features/interceptors.md)

```rust
let client = Client::new(host)
    .with(site_headers)
    .with(refresh_expired_ticket);
let response = client.send(request, &mut scratch)?;
```

这里 `site_headers` 设置该站常用头，`refresh_expired_ticket` 读取响应。它在站点明确报告原票据失效时才重新取票，再通过下游发送更新后的请求。重发释放前一次响应，受原操作的截止时间、重试预算和请求语义约束。重复发送会重新进入下游；外层已经完成的处理保持其原顺序。需要每次重发重算签名的步骤应放在负责重发的拦截器内侧。源只能观察获准提供的响应信息，App 对拦截器生成的每次请求及实际跳转继续检查授权、会话、取消和限速。

阅读器直接下载图片时，源的 SDK 拦截器链已经结束。发前只需要改地址、签名或头时，源可在构造远程页图的 `Request` 时复用同一处理代码，交给 App 走原流式下载。确实要根据实际取图响应切换请求时，候选是在阅读和下载共用的准备入口提供一次有限的响应回调，交回页 ID、状态和获准的响应信息，让源决定是否交付新请求。响应正文的还原仍由已有图片处理器或明确协商的产物接口处理。普通图片继续走原通道，SDK 拦截器的发布不意味着替代宿主内的页图传输。

需要用户参与时由拦截器或源操作向上返回待处理错误，原请求链结束。App 的操作恢复处理打开界面、等待用户、取消和重新进入源操作，之后以新调用继续。

首批 SDK 实现位于独立源仓的 `sdk/src/http.rs`。`Client::new(&[&dyn Interceptor])` 按顺序执行，末端使用原 `koma_host.http_request`。第一版用 `Request::from_json` 接收源已有的请求编码，`Response` 借用调用方原有缓冲区，提供状态码、文本正文和原信封。暂不改变请求编码、响应格式或宿主特性。测试 WASM 实际执行一次注册的拦截器并检查导入表，唯一宿主导入仍为原 HTTP 入口。

版本按变更落点管理。宿主仍加载 `koma-source-abi-v0.1` / `koma-host-v0.1`，调用和 HTTP 信封的 `version` 仍为 `1`。WASM `source_info` 的 `apiVersion: "0.2"` 和 Rust 源 SDK 的 `0.2.0` 各有用途，不能据此推断宿主 ABI 已升版。新增可选宿主信息按现行约定用 `hostFeatures` 协商。拦截器编进源包，可沿用原 ABI 与最低 App 要求；正式交付时步进源包版本。只有需要改变已有导入、导出或信封语义且无法保持兼容时，才为对应协议引入新版本。

历史首次接入把 MYCOMIC 的原响应判断移进源自己的拦截器。链允许源定义错误类型，传输失败可映射为原错误，站点验证及 HTTP 错误沿用源原语义。原包与候选使用相同宿主导入和产品操作导出，受控回放确认已标记的挑战仍携原请求标识，普通 403 和 404 未误报。该次 237 试点的 Koma 1.5.5 通过普通文件入口导入候选且读回 WASM 与本地一致，列表封面、搜索、详情、章节目录已验证；当次未自然触发挑战。此历史证据不证明本地 1.6.1 的新数据或本地化能力。见 [MYCOMIC 工作单](CURRENT_STATUS.md)。

哔哩漫画的文档请求用可选的 `RequireSuccess` 拦截器复用 SDK 的 HTTP 状态映射。成功响应交回源解析正文，搜索收到 HTTP 200 的验证表单时仍保留本次请求标识，沿用原站表单和 App 的原查询重试。其他源需要判断非成功响应里的站点信息时，可以省略 `RequireSuccess` 或在它内侧先处理响应。原包和候选的 WASM 回放核对了相同的请求、普通结果、验证码文档接力和 HTTP 错误，清单与宿主导入保持一致。[哔哩验证记录](CURRENT_STATUS.md)

Keiyoushi 的「自動輸入搜尋驗證碼」在扩展的搜索调用内完成，默认关闭。开启后后台验证成功会直接返回搜索结果，处理失败才提示用户去 WebView。Koma 早期试点曾只验人工验证之后的操作续接，打开带原关键词的表单及回放完成回调仅证明当时那条流程；不能据此否定后续已接入的自动识别或推断本轮新能力已通过。 [上游搜索实现](https://github.com/keiyoushi/extensions-source/blob/1aba299dd03549a98d6f4461f6022d1e9adf04c0/src/zh/bilimanga/src/eu/kanade/tachiyomi/extension/zh/bilimanga/BiliManga.kt#L100)

Cloudflare 挑战的线索由宿主依据实际响应的 `cf-mitigated` 信号提供，源也可通过原信封读取。交互由宿主在同站授权范围内完成，实际触发请求、网页会话与原操作交接沿用现有边界。拦截器可共用响应识别与返回待处理错误，随后把控制权交回现有操作生命周期。对未来的新站，单纯改检测或处理流程可以随源包变更。新增浏览器会话能力或 App 代发请求时的响应回调仍属于相应宿主合同。[宿主响应识别](../entry/src/main/ets/sourceRuntime/SourceRuntimeHttpTransport.ets#L248) · [当前会话协议](source-runtime-abi.md#网页会话与章序)

### 把交互续接做成原调用的生命周期

以当前 `SourceRuntimeOperationGuard`、`SourceWebChallengeGate` 和验证/登录服务为基础。浏览、跨源搜索、详情、阅读仍各自持有页面状态与发布结果的职责。续接扩展原有操作守卫与一次认领机制，统一处理运行、等待交互、恢复及终止。各入口复用这一机制，并提供自己的页面可用性校验和结果回写。

现有两条实际流程分别是哔哩漫画原关键词重搜和 CCC 会员页登录后重开原章节。它们已经有各自的界面、授权及重调逻辑。共同缺口是源发起交互时的处理位置不能返回给后一次源调用。第一片在源内搜索按现有认领规则回传一个短处理标记，复用同一字段承接网页登录和页面验证。哔哩漫画试点保留现有 HTTP 请求和已验证响应匹配规则，完成后由源按标记判断本次恢复。CCC 当前仍沿阅读器原重开逻辑，真实会员登录和阅读场景的接入范围独立验收。 [生产 ABI](source-runtime-abi.md#书源登录)

1. App 启动源操作时，生成并保存操作 ID、安装和设置身份、原始参数、页面可用性及取消状态。刷新或切换查询使旧操作失效。
2. 源需要用户参与时返回现有 `auth_required` 或挑战错误，并为新版宿主附交互类型、已授权入口或宿主记录的原请求标识、源自己的短续接数据。App 核对当前操作及声明。当前 WASM 调用退出，释放执行槽和本次字节引用。旧宿主继续看到原错误及原验证入口。
3. App 复用已有登录或验证界面。交互的成功表示当前用户动作已完成。App 按原有会话服务建立获准的会话，将当前操作的一次性回执和源续接数据带进下一次调用，继续原功能、原参数。源根据实际站点结果确认登录或验证是否有效。
4. 用户取消、离页、换源或改设置时作废回执。迟到响应应被拒绝。后台下载按原交互政策返回可处理状态。带副作用的请求由源按站点状态作恢复决定。失败重试保持在该次操作，使用相同查询或章节，保留其它已成功的部分。

首次迁移选择已有实证的验证后重取搜索和登录后重取受限章节。对两个流程使用同一恢复合同，保留现有的弹窗、关闭、返回与无感继续路径。在输入、切页、取消、会话失效以及旧包上核对结果是否还归属于原操作。用现行版本和迁移候选分别核查相同普通入口。生产协议、SDK 和 App 的最低版本声明在对应实现完成时一起更新。

## 如何演进及确认方案成立

- 用协议版本协商真正可组合的一组操作及它们的语义。现有 `hostFeatures` 继续支持旧包。新增源规则或使用已有接口的组合可以随源变更。仅在旧 App 无法走完整核心路径时，包和订阅索引共同声明最低 App 版本。
- 如果一段适配只需要新增 WASM 代码和已有结果类型，App 发版变化应为零。如果必须改变权限、增加外部系统调用、识别新的产品结果，或修复宿主自己的缺陷，明确负责的服务及对应版本。用源 ID 和网站名列宿主分支会让组合能力退化。
- 验收固定一个 App 构建，替换功能不同的源包，至少覆盖多输入页图、不同形式目录、已有会话切换和设置校验。核对普通浏览、书架续读、预载、下载与离线，以及取消和失败恢复。再运行老源和支持旧宿主的回退版本。能用冻结的 App 跑通独立变化，才证明设计降低了对 App 发版的依赖。

参考 WASI HTTP 对状态、响应头和字节正文生命周期的分离，以及 Extism 对插件请求域和资源上限的声明。[WASI HTTP 类型](https://github.com/WebAssembly/wasi-http/blob/main/wit/types.wit) · [Extism 插件清单](https://extism.org/docs/concepts/manifest/)

# Koma 源包与运行 ABI

本文件描述 App 当前支持的生产 WASM 包和调用边界。字段验证的唯一实现分别在 SourcePackageImporter、SourcePackageMetadata、Registry 与 Native adapter；修改合同须同步这些消费者和本文。当前工作状态见 [CURRENT_STATUS.md](CURRENT_STATUS.md)，职责见 [WASM_SOURCE_RUNTIME_DIRECTION.md](WASM_SOURCE_RUNTIME_DIRECTION.md)。

## 包和索引

- 用户配置 source index URL，索引项提供身份、版本、本地化名称、语言、分级、包/图标地址等元数据。相对地址按索引 URL 解析。
- 生产包使用根 manifest.json、source.wasm 和一个包内身份图标。可接受格式及归档限制以 SourcePackageImporter 和 SourcePackageMetadata 为准；文件后缀不能替代内容校验。
- 仓库包 manifest 由 SourceRepoPackageManifest 解析为宿主 LocalSourcePackageManifest；后者分 package、runtime、permissions、contentPolicy 及 operationCapabilities。宿主保留 sourceId、版本、安装身份、启用状态、合法主页和已核目录方向。
- 源生产校验要求合法 homepage；App 兼容没有该字段的既有包。地址只接受无账号信息的完整 HTTP(S) URL，不从 API、CDN、失败请求或 ID 猜站点。普通网页仅显示已安装或缓存中已有合法地址的入口，不在点击后补取地址或摆空选项。
- homepage 与 webSessionOrigins 分工独立：前者用于普通导航，后者限定验证会话。主页不扩大 Cookie、UA 或网络权限。

## 调用路径和操作

SourceRuntimeService 校验当前源启用/能力、请求、设置及身份，Worker 调用 NativeSourceRuntime.runJsonCallFromBytes，WAMR 按 operation 选择导出。请求/响应为 JSON，当前导出映射来自 wasm_runtime_adapter.cpp 的 ExportForOperation：

| operation | WASM 导出 |
| --- | --- |
| source_info | koma_source_info |
| search | koma_source_search |
| get_manga | koma_source_get_manga |
| get_chapters | koma_source_get_chapters |
| get_pages | koma_source_get_pages |
| get_listings | koma_source_get_listings |
| get_manga_list | koma_source_get_manga_list |
| get_home | koma_source_get_home |
| get_filters | koma_source_get_filters |
| get_settings | koma_source_get_settings |
| get_image_request | koma_source_get_image_request |

`home` 表示源的独立首页内容，不能仅把已有热门、最新等列表的第一页包装成同义首页。只有列表的源声明 `home: false`，由宿主直接进入既有默认列表；为兼容 ABI 保留的 `get_home` 导出返回 `not_implemented`，不为这个空能力再发请求。真实首页及其分区与完整列表的关系仍由源合同决定，宿主不能因为部分卡片相同就隐藏首页。

`get_filters` 的每个筛选项可选 `scope: "browse" | "search"`：按当前查询内容判定，空白查询属于 browse，非空查询属于 search；缺省在两者均有效，兼容旧源。`type: "header"` 只携带源原文的 `name`/`label` 与可选 `description`，不产生请求值、默认值、计数或持久化值。宿主只向源提交当前作用域的值，并保留另一作用域的已保存选择；切换查询不删除选择。仅当请求顶层 `hostFeatures` 包含 `source_filter_scope_header_v1` 时，源才能返回依赖作用域或 Header 的新版 schema；未声明时必须返回该源原有 schema，旧宿主不得误暴露或消费新项。

声明 `source_filter_fetching_v1` 的宿主支持可选动态筛选数据：初次 `get_filters` 返回基础 schema 和 `supportsFilterFetching: true`，不为可选标签数据阻塞目录。实际打开筛选时，宿主以 `args.fetchFilterData: true` 再调用 `get_filters`；成功返回包含基础项的完整 schema，失败保留原目录、基础筛选及已存选择，并允许下次打开时重试。稳定动态字段须在基础 schema 声明其 ID，省略 `options` 表示选项尚未加载，不能用空数组冒充。迟到响应受源包、设置版本和页面生命周期约束，不能覆盖别的源。

`source_filter_tristate_v1` 支持 `type: "tristate"`：一个字段表示一组标签，`options` 使用原站 ID/名称，ID 不能以 `!` 开头。值为字符串数组，`id` 表示包含、`!id` 表示排除、缺省表示忽略；同一 ID 只能有一个状态。宿主复用原生多选菜单循环切换，清除此项移除整组选择。选项未加载时保留已存状态，不能因打开页面先收到基础 schema 而丢掉筛选。源未取得对应 Host 特性时，仍返回原 schema。

是否允许某项操作仍由当前源声明、真实导出和准入共同决定；原生有映射不代表所有源实现。测试专用导出不构成产品能力。响应沿 NativeSourceRuntime 的 ok/operation/data/error/reasonCode/hostHints 合同，由服务及实际 DTO 消费者校验，不凭字段存在冒调用通过。

## 宿主边界

- WASM 只使用受控 host imports；当前原生注册表为 wasm_runtime_adapter.cpp 的 g_komaHostSymbols，HTTP/HTML 行为分别由 http_host 与 html_host 实现。不能从开发 runner 导入推定 App 提供同名能力。
- WAMR 的初始化和内存池由进程内的在途调用共同持有；并发数受原生运行器限制，同一源调用保持串行，缺少宿主源身份的调用独占运行。每次调用使用独立的模块、线程环境、HTTP 身份和 HTML 句柄，结束时释放所属句柄。所有异步源消费者共用 Worker 前的有界调度，并丢弃尚未入 Worker 的过期搜索；排队时间不计入网络期限。封面解析只在同源尚未执行的任务中让位于交互请求，Reader 页图、正文和其他元数据保持前台优先；不同源保持原 FIFO，同源串行和全局并发上限不变。统一搜索进入 Worker 后若已失效，HTTP 限速等待前后阻止新请求；已发出的请求仍可能完成，不把丢弃迟到结果称为网络中断。
- 包、请求及响应大小、执行/网络期限和取消按当前 importer、service 与 native 常量执行，本文不复制易漂移的数值。未声明能力、无效身份和不支持操作不能默认放行。
- 单源搜索允许某一页因语言等既有筛选而没有条目，但仍返回有效的下一页游标。宿主保持已有结果，沿仍有效的同一次查询继续取页，直到增加条目或源明确结束；不依赖没有行变化时不会再次触发的列表到底事件。每个成功游标分别提交，失败及验证只重试随后失败的一页；查询、源包或设置改变后不得继续。重复游标按响应错误处理，不伪造搜索结束，也不改变请求通道的限速、期限或权限。
- 源设置须有真实 schema 及实际消费。schema 空/失败不显示空入口，也不污染已保存设置的全局状态；存储读取失败保留有效入口并报告具体阶段，不使用“设置验证失败”泛化提示。cookies、userId、token 不因存在导出而开放普通明文持久。
- 文本输入设置的 `description` 是源提供的格式说明，表单在输入框下完整显示；已有输入值时仍保留，不用 placeholder 替代。没有说明的字段沿原布局。
- SourceSettingsStore 复用本进程最近提交的私有快照，调用方仅取得副本；单源请求及管理页统计不重复读盘解析全文件。写入成功才发布快照和 revision，失败保留旧值；路径切换、原文件事务回滚及备份回滚由同一 owner 失效，不以缓存掩盖尚未成功读取的错误。
- 图像请求描述进入原有下载/缓存通道；源不直接接管文件、账户、图像处理、Reader 进度或共享 Kit。

### 站点原生 HTTP 兼容

空正文 GET 仅在以下精确源和本跳 origin 使用原生浏览器兼容传输：Simply（`com.simplyhentai.zh.koma`，`https://api.simply-hentai.com`）与漫画屋（`com.manhuawu.koma`，`https://www.mhua5.com`）。URL、请求头、UA、Cookie、权限、限速、取消和重定向仍由现有宿主 HTTP 通道决定；不读取网页正文、不替换源解析、不扩大图像通道或会话域。原生工作异步执行，保留证书及主机名校验；系统代理存在或默认代理/信任目录不可用时沿 NetworkKit 原路径，不绕过代理。回退扣除本跳已消耗的网络预算。

兼容库固定为 curl-impersonate 2.3.2，Simply 采用 Firefox 133 配置，漫画屋采用 Chrome 145 配置并保留已批准的实际 Web UA；均关闭库的默认请求头。依赖由[固定构建配方](../scripts/prepare-source-browser-http.sh)校验并静态链接，隐藏符号，不使用平台私有 curl/SSL。当前 arm64 构建保留 HTTP/2；因 SDK 缺少 HTTP/3 所需的 `recvmmsg` 而关闭 HTTP/3，BoringSSL 使用 C/C++ 实现。第三方版权全文随 App 打包。其它源及未匹配请求保留原传输；新增适用站点必须先有具名请求差异和实际验证依据。

HTTP 诊断关联宿主提供的操作名，并记录原生传输的 DNS、TCP、TLS、首字节和结束累计时间；零值不单独证明对应阶段完成。操作标签不参与会话或私有数据身份，不持久化；日志不包含请求地址、请求头、Cookie 或响应正文。

## 宿主特性

章节可选 `readingOrder` 表示源明确验证的同一阅读序列顺序，独立于展示用 `chapterNumber`／`volumeNumber`。宿主派生自动续读顺序时优先使用有限、非负的 `readingOrder`，并保留既有 `readingGroup`／`continuationEligible` 分组许可；未提供时仍按原卷／话号规则。同组排序位置重复时不能按数组位置决定先后，该组须补齐可区分的序号后才自动续读；有唯一阅读序号的重复话号、无号番外仍可正常续读。不得凭标题猜顺序或伪造卷号。依赖此字段的源仅在 `hostFeatures` 含 `chapter_reading_order_v1` 时输出对应续读合同，旧宿主保留原章节输出。宿主的详情快照、入库、目录更新、持久化和 Reader 会话使用同一字段，缓存页和进度不因预载而写回。

正式源操作的请求顶层由宿主加入 `hostFeatures`，元数据、章节、页表及普通图片/文字页的 `get_image_request` 共用该声明。当前支持 `text_page_image_v1`、`source_rate_limit_v1`、`text_page_image_zaimanhua_comments_v1`、`source_text_page_request_v1`、`source_setting_observations_v1`、`source_chapter_exclusions_v1`、`source_setting_uuid_list_v1`、`mangabz_language_cookie_v1`、`mangabz_mirror_session_v1`、`source_settings_context_v1` 、`source_http_batch_v1` 、`source_filter_scope_header_v1`、`source_filter_fetching_v1`、`source_filter_tristate_v1`、`chapter_reading_order_v1`、`source_private_session_v1`、`source_page_image_processing_v1`、`source_baozi_chapter_identity_v1` 和 `source_java_regex_v1`；源必须按特性声明再展示、消费依赖项，旧 App 没有声明时保持原输出。特性不是网络权限或任意 HTML 执行许可。

`source_page_image_processing_v1` 是正文页派生图片的可选能力。包子源可在 `get_image_request` 响应提供 `imageProcessing: { kind: "baozi_banner", mode: "1" | "2" }`；未存偏好时源默认普通模式，显式禁用或源未声明处理时保留原图。宿主只在正文页消费并核对源身份、图片域、当前安装包和设置，保留原始下载及其摘要；派生图用于阅读、预载和普通保存/分享，不处理封面。

横幅派生缓存按源安装身份和设置指纹区分，设置变更后请求使用新缓存身份；因此不沿用参考源中要求清除已加载图片缓存的提示。

`source_baozi_chapter_identity_v1` 允许包子的 `CHAPTER_ORDER` 在显式启用时以完整标题扩展章节身份；默认关闭，正文仍按原 slot 请求，不改变目录顺序。宿主在详情和书架更新前共用 `SourceChapterIdentity`，仅同作品、slot及完整标题唯一匹配时沿用已有ID，双向切换都保留原进度、页表和下载归属；无法唯一匹配或会合并不同章节时整次更新失败，保留旧目录，不提交部分结果。历史中的标题身份可按同一精确规则恢复；缺少标题的孤立旧ID不猜测映射。旧宿主未声明能力时，源不得展示或消费该设置。

### 源正则执行

`source_java_regex_v1` 复用 `koma_host.http_request` 的本地 RPC：`{type:"java_regex",version:1,op:"validate"|"remove",pattern,text?|texts?}`。校验返回 `data.valid`；替换使用空串并返回对应的 `text` 或 `texts`。仅明确的语法错误返回 `ok:true,valid:false`；资源限制、执行错误或已取消操作返回 `ok:false`，源必须保留原文。该能力不发送网络请求、不新增 WASM import；旧宿主不得展示或消费依赖它的设置。匹配运行有批次预算，复杂表达式失败不冒称不匹配。

执行归宿主独立的原生异步工作，不占用 UI 线程，也不重新排入正在等待 RPC 的源任务池。引擎沿 Android 参考采用 ICU 正则，固定为静态 ICU 74.2；隐藏其符号，不链接平台私有 ICU。源码校验与所需 Unicode 数据由 [构建配方](../scripts/prepare-icu-regex.sh) 和 [数据过滤规则](../scripts/icu-regex-data-filter.json) 固定，CMake 按当前 SDK 自动准备并区分构建缓存。XCOMIC 的 `REMOVE_TITLE_CUSTOM` 沿参考实时校验，输入更新、关闭、清除及设置版本变化均使过期结果失效；不由后台校验回写草稿。

### 源私有会话

`source_private_session_v1` 复用 `koma_host.http_request`，以 `{type:"private_session",version:1,op:...}` 区分本地 RPC；它不发送 HTTP，也不增加 WASM import。网站的游客初始化、请求签名、令牌解析及业务失效处理仍由源实现，Host 只提供不透明私有缓存、安全随机和 RSA 原语。依赖该能力的新源必须同时提高生产包 `minAppVersion`；旧 Host 不得误走新协议。

| op | 请求及响应 |
| --- | --- |
| `begin` | 已有值返回 `state:"ready"`、`value` 和 `versionTag`；尚无值时仅一个调用返回 `state:"owner"`、`lease` 和 48 字节安全随机数的 `randomHex`，其它调用等待该初始化结束。两种结果均提供 `nowMs`、`gts`。 |
| `commit` | 提交同次调用的 `lease` 和字符串 `value`，成功返回新 `versionTag`。 |
| `abort` | 以同次调用的 `lease` 放弃初始化并释放等待者。 |
| `invalidate` | 仅删除与 `versionTag` 相等的一代值；Host 不重发源的业务请求。 |
| `clock` | 返回 `nowMs`、`gts` 和 16 字节安全随机数的 `randomHex`。 |
| `rsa_pkcs1` | 对 X.509 base64 `publicKey` 和 UTF-8 `plaintext` 做 RSA2048/PKCS1 加密，返回 base64 `value`。 |

RPC 成功返回 `ok:true`，失败只返回 `ok:false,error:{code}`。`nowMs` 为毫秒字符串，`gts` 为本地时间 `yyyy-MM-dd+HH:mm:ss`。缓存由可信 Native 调用上下文限定为当前启用的源及安装身份，源不能在请求中指定别源、命名空间或资产别名；探测和无有效调用身份的请求不得访问。UI 侧调用 owner 包住原有 Worker，结束或异常时释放初始化认领；等待不占用本源写队列，不把 Asset 或 UI 模块引入 Worker。

私有值在当前调用内交给本源 WASM 构造请求，持久化只经 Asset 的 1024 字节分块和最后发布的短索引完成；不进入公开设置、备份或诊断。日志只记录操作、固定结果码及 ready/owner 状态，不记录值、随机标识或令牌。替换包的安装身份不同，不能读取旧包私有值；这不是用户配置迁移能力。读写失败保留错误，不以清除所有资产或改用明文文件恢复。

`source_setting_uuid_list_v1` 支持文本设置的 `validation: {kind:"uuid_list", message:"..."}`。沿 MangaDex 参考实现逐个校验逗号分隔并 trim 后的小写 UUID（版本 1–5，variant 8/9/a/b）；空白有效，空项或尾逗号无效。不执行源提供的正则。表单显示已采用的系统输入错误状态并禁用保存；持久化 owner 在写入前再次校验，失败保留原设置及 revision。

`source_detail_chapter_context_v1` 仅由详情页本次 `get_manga` 和随后的目录请求声明。源可在成功详情的 `data.chapterContext` 返回非敏感 JSON 对象，宿主仅在同一仍有效的详情事务中将其原样传入 `get_chapters` 的 `args.chapterContext`，分页共用；不写缓存或日志，不跨刷新、源包或设置变更、其他作品或精确章恢复使用。源须核对上下文的版本和作品身份，缺失或不完整时沿原请求路径处理；旧宿主不声明该特性。

`source_http_challenge_cause_v1` 仅由可追踪生命周期的统一搜索、单源搜索及 `get_manga_list` 请求声明。源在单个 GET 中设置 `wantChallengeRequestId: true` 后，宿主仅为该源允许的网页 origin 上返回 401、403 或 503 的实际请求附加短 `challengeRequestId`。只有源最终由该次响应产生 challenge/auth 错误时，才可将同一个 ID 放在 `error.challengeRequestId`；不得推测其他请求的 ID。宿主按 ID、源和本次页面请求身份匹配原 GET，验证后的响应仅由该次请求的重试消费；多条不同失败 GET 缺乏明确 ID 时不能猜测。精确选中的原 GET 可在内存中将有效 UA 交给同 URL 的验证页，保持验证及原请求身份一致，不改源或全局默认 UA；会话仍保存其实际 Web UA，取消或请求失效清除关联。旧源不使用此字段，保留单个候选的既有兼容行为，旧宿主不声明该特性。

`source_http_batch_v1` 在原 `http_request` import 上支持 `{version:1,requests:[单请求对象]}`，每组1至5个且不能嵌套，只用于彼此独立的请求；存在响应或会话依赖时仍逐个发送。宿主先校验整组基本请求格式，再并行复用原单请求通道；每项保留源身份、会话、限速、重定向及网络超时。响应为 `{ok:true,responses:[单请求响应对象]}`，顺序与输入一致；外层 `ok` 只表示组格式有效，每项仍可能是原HTTP或传输失败，源必须逐项检查。宿主不自动重试、不缓存组结果、不扩大网络权限；未声明此特性的旧Host沿原逐个请求路径，不需要新增WASM导入。

`mangabz_language_cookie_v1` 支持已采用的 MangaBz 简繁设置：源在请求中提供 `mangabz_lang=2`（默认简体）或 `1`（繁体）。只有宿主确认的 `com.mangabz.koma` 身份、实际请求域为 `mangabz.com` 或其子域、且源头包含唯一合法语言项时，该项才能替换同名会话 Cookie；其它 Cookie、验证/登录、UA、源会话及重定向边界保持。每跳重新核域，不写 Web Cookie 仓，也不允许源覆盖其它会话 Cookie；图像描述只有同站地址可带语言项，外域 CDN 不携带。源设置改变沿现有页表设置身份按需重取，不清图片缓存或主动改写书库已有标题；旧空设置页表仍沿原兼容合同保留，不能声称默认切换自动刷新了它。

`source_settings_context_v1` 允许 `get_settings` 的 `args.settingValues` 携带本源当前已保存的公开设置副本，供源在设置键或类型迁移时继承原选择；顶层 `settings` 仍为空，`network:false` 保持。成功读取且未保存时传 `{}`；读取失败则省略该字段，源须保留原 schema，不把缺失当作已读空值。其它源的值及凭据字段不进入该上下文；读取不写文件、不修改 revision、不主动迁移或清设置，表单沿原保存与读取错误处理。源对新 schema 同时核 feature 和上下文；依赖该支持的新设置消费也须核 feature，旧 Host 保留旧设置和请求合同。

`source_setting_observations_v1` 用于由真实目录积累的公开设置候选，例如扫描组名称。成功且仍属于当前安装/设置的 `get_chapters` 可返回 `data.settingObservations: { key: string[] }`；宿主只在该源范围内合并去重，在 `get_settings` 的 `args.settingObservations` 回送，原样保留标签和值、只跳过全空白项，排序及比较时的trim/lowercase语义由源负责。它不写入用户所选设置、不改变设置 revision/页表指纹，也不广播源列表刷新。候选经有界纯字符串校验，由独立 owner 缓存、串行 TaskPool 原子持久；写失败不发布新快照、不影响有效目录。卸载删除本源候选，失败回滚，旧请求不可复活；备份含此公开数据，恢复与原文件共同受检查点保护，旧检查点和不含字段的备份仍兼容。清除已保存设置只清用户选择，已有公开候选保留。不得借此回传凭据、Cookie、HTML 或执行指令。

`source_chapter_exclusions_v1` 用于源主动筛掉章节时的显示语义。成功 `get_chapters` 可返回 `data.excludedChapterIds: string[]`，仅列经过完整身份/权限/元数据校验、确因当前设置被排除的完整章ID。只有完整目录的排除集合才能影响当前显示和同设置快照；失败、取消、缺页或旧身份的结果不能隐藏章节。宿主不再把这些明确排除的本地旧章节补回列表，但保留所有库章节、下载和进度；仅未出现在远端的旧章仍沿原保护显示。全被明确排除是完整成功的空目录，缓存回显不能恢复旧行。旧Host不声明时，源不得提供或消费依赖此能力的筛选。精确章ID续读恢复允许取得被目录筛选隐藏的原章，仍须原作品归属和权限，不改变已有进度。

文字页沿原 `data.pages` 返回 `image: { kind: "text", text: { template, heading?, paragraphs } }`；模板只接受 `webtoon-author-notes`、`dm5-chapter-comments`、`zaimanhua-chapter-comments`。前两种由 `text_page_image_v1` 声明；再漫画模板须同时具有 `text_page_image_zaimanhua_comments_v1`，设置展示与 `get_pages` 实际输出都要核对，不能因旧 App 留有开启设置就输出不支持的模板。ComicFury 作者注释采用同一公共 TextInterceptor 排版，可复用 `webtoon-author-notes`。

需要独立网络请求的章末页用 `image: { kind: "text_request", textRequest: { template: "zaimanhua-chapter-comments" } }`，必须另具 `source_text_page_request_v1`。外层 page.id 是唯一页身份；宿主沿现有 `get_image_request` 发送该 pageId，源成功返回 `data.image: { kind: "text", text: { template, heading?, paragraphs } }`，模板必须与声明相同。`get_pages` 只发布描述，不为该页请求网络或生成图片；Reader 原图准备、预载、缩略图、分享与离线下载共用逐页准备和 PNG 缓存。此页失败走已有页面失败和显式重试，只重试该页原请求，不拒绝整章有效正文、不伪造网络图片地址、不静默略掉失败页。已下载本地页优先且离线缺页不触网。缓存按源安装身份、页、模板和设置摘要区分；旧源/设置的迟到结果不得交回当前页。

源负责 JSON 转义及 HTML 实体解码，字段是普通 Unicode。已包含文字的 `text` 页在章节页表发布前通过 TaskPool 原生字体排版生成本地 PNG；`text_request` 页由逐页准备链请求文字并通过同一 TaskPool 制图，不把其网络请求放进章节页表加载。经过校验的公共文字描述或请求描述随 Page 和会话传递，缓存被清理时由同一准备/预载及离线下载链重建，缓存路径不是唯一内容。Reader、预载和增强消费同一本地图片，不请求虚构图像网址，正常制图接入准备与预载链。宽度、字号、段距及整条评论截断沿所采用的源参考，字形度量由 HarmonyOS 提供。再漫画模板固定标题“章末吐槽：”，按参考跳过放不下的多行评论、遇放不下的单行评论停止，图片高至少等于宽且不超过1920；不沿用 DM5 的截断规则。

漫画柜限速由进程内共同 owner 执行：主站共享滑窗，已知 CDN 集合共享另一滑窗，元数据网络、封面和 Reader 图像缓存未命中均消费相应额度。额度来自请求已有设置快照；网络热路径不再读盘加载设置。其它源、无匹配站点及缓存命中保持原路径，排队后重核会话身份，不沿用排队前 Cookie。

## 网页会话与章序

- 普通导航不创建验证会话、不自动重试源请求。验证/登录沿现有网页控件，绑定源、版本、安装身份、设置/查询及精确 origin。
- 明确挑战按源独立认领并串行展示，其它源继续返回；完成候选不等于站点成功，只有原请求真实成功且无挑战才可回流。关闭、取消、再次挑战、切换请求/设置/源身份或离开页面不得循环弹出及重放旧操作。
- 有效原生响应只由精确原请求消费一次，不落盘交接响应头/Cookie；迟到或不匹配回调不得发布。具体自动完成及兼容边界见当前公共实现旁与执行规则，不在本文复制阶段性收据。
- chapterOrder 保留源已核的 oldest_first/newest_first，未声明时保持宿主兼容准入；完整原源目录没有显式分组/阅读序号时，Host在分页完成后生成 source-catalog 组及 readingOrder，随既有章节元数据保存，不改变目录顺序。旧库合并数组不能作为原源序凭据；保留但已不在新目录的旧章保留原页表和进度，不沿用过期的续读资格。有分组时保留 readingGroup／continuationEligible 的限制；上一章、下一章及跨章预载共用持久阅读序列，已有进度及显式章节优先，不合成章节身份或猜话数。

`mangabz_mirror_session_v1` 扩展 MangaBz 的固定镜像：源仅在宿主声明后显示备用站设置；每站独立保存精确 origin 会话，语言键按域分别为 `mangabz_lang`、`xmanhua_lang`、`yymanhua_lang`，不跨域转移会话或其他 Cookie。旧宿主及未选镜像保原请求与默认。

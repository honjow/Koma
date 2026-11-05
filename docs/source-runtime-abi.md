# Koma 源包与运行 ABI

本文件描述 App 当前支持的生产 WASM 包和调用边界。字段验证的唯一实现分别在 SourcePackageImporter、SourcePackageMetadata、Registry 与 Native adapter；修改合同须同步这些消费者和本文。当前工作状态见 [CURRENT_STATUS.md](CURRENT_STATUS.md)，职责见 [WASM_SOURCE_RUNTIME_DIRECTION.md](WASM_SOURCE_RUNTIME_DIRECTION.md)。

## 包和索引

- 用户配置 source index URL，索引项提供身份、版本、本地化名称、语言、分级、包/图标地址等元数据。相对地址按索引 URL 解析。
- 生产包使用根 manifest.json、source.wasm 和一个包内身份图标。可接受格式及归档限制以 SourcePackageImporter 和 SourcePackageMetadata 为准；文件后缀不能替代内容校验。
- 仓库包 manifest 由 SourceRepoPackageManifest 解析为宿主 LocalSourcePackageManifest；后者分 package、runtime、permissions、contentPolicy 及 operationCapabilities。宿主保留 sourceId、版本、安装身份、启用状态、合法主页和已核目录方向。
- 源生产校验要求合法 homepage；App 兼容没有该字段的既有包。地址只接受无账号信息的完整 HTTP(S) URL，不从 API、CDN、失败请求或 ID 猜站点。普通网页仅显示已安装或缓存中已有合法地址的入口，不在点击后补取地址或摆空选项。
- homepage 与 webSessionOrigins 分工独立：前者用于普通导航，后者限定验证会话。主页不扩大 Cookie、UA 或网络权限。
- 拷贝漫画已安装包声明默认主页时，普通网站入口用点击时已保存的 `domain` 在同一份三个已知 API/网页域对中选站。没有保存值、保存值无效或设置不可读时，仍打开默认声明主页。这个映射只用于普通导航。
- 普通空正文GET若携原站会话后重定向到当前同源包已明确声明的另一HTTPS origin，可在不携原站Cookie、Authorization及其它站点专用头的情况下继续匿名读取；逐跳重核当前包身份、启用及声明范围，目标已有独立会话时仅取目标会话。未声明目标、POST及验证probe仍按原边界拒绝；验证probe只读取Host实际观察到的拒绝GET，结果仍仅供原请求消费一次，不授予跨站会话。

语言代码 `all` 表示“多语言”分类，不是“全部语言”筛选总开关；语言枚举与源身份保持原值，筛选按各语言项独立选择。

源索引与包声明的 `minAppVersion` 使用 `MAJOR.MINOR.PATCH`。宿主按已安装 App 的版本名逐段比较，兼容现有 `-pre` 规则。安装前可按索引拦截，归档解析后仍独立核包声明；安装失败显示实际拦截所需的最低 App 版本。

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
| get_authentication（可选） | koma_source_get_authentication |
| authenticate（可选） | koma_source_authenticate |
| logout（可选） | koma_source_logout |

`home` 表示源的独立首页内容，不能仅把已有热门、最新等列表的第一页包装成同义首页。只有列表的源声明 `home: false`，由宿主直接进入既有默认列表；为兼容 ABI 保留的 `get_home` 导出返回 `not_implemented`，不为这个空能力再发请求。真实首页及其分区与完整列表的关系仍由源合同决定，宿主不能因为部分卡片相同就隐藏首页。

源设置可声明 `visibleWhen: {settingId, values}`，按指定普通单选字段的当前草稿值控制该行是否显示，隐藏后保留用户值。单选项显式声明空字符串并提供标签时，空字符串是可选择的值。文本项可声明 `validation: {kind:"non_blank", message}`，保存前拒绝去除首尾空白后为空的输入。旧宿主按已有字段渲染，源请求仍以当前选项决定实际行为。

列表和搜索结果中的普通公开封面可在 `cover: {kind:"url", url, headers}` 直接提供完整 GET 请求。`headers` 仅允许 `Accept`、`Referer`，无额外头用空对象。封面卡片可并行发起这些请求，沿用原源限速、缓存身份和同图合并。需要票据、认证或其他动态行为的封面仍通过 `get_image_request`，应省略 `cover.headers`。旧宿主忽略此加法字段，源应保留原解析路径。

宿主可在一批调用间短时复用 WAMR 的进程级内存池，空闲后释放。每次调用独立创建模块实例和请求上下文，书源状态应通过 ABI 规定的存储能力传递，不能依赖上一次 WASM 实例。正常列表优先于菜单设置能力探测，后台图片操作在真正获得执行槽后才复制 WASM 输入。

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

正式源操作的请求顶层由宿主加入 `hostFeatures`，元数据、章节、页表及普通图片/文字页的 `get_image_request` 共用该声明。当前支持 `text_page_image_v1`、`source_rate_limit_v1`、`source_rate_limit_buondua_v1`、`text_page_image_zaimanhua_comments_v1`、`source_text_page_request_v1`、`source_setting_observations_v1`、`source_chapter_exclusions_v1`、`source_setting_uuid_list_v1`、`mangabz_language_cookie_v1`、`mangabz_mirror_session_v1`、`source_settings_context_v1` 、`source_http_batch_v1` 、`source_filter_scope_header_v1`、`source_filter_fetching_v1`、`source_filter_tristate_v1`、`chapter_reading_order_v1`、`source_private_session_v1`、`source_page_image_processing_v1` 是正文图片准备的可选声明。现有 `imageProcessing: { kind: "baozi_banner", mode: "1" | "2" }` 由订阅图片规则中的兼容映射消费；普通、强力及关闭语义保持。宿主在“跟随书源”下遵守该声明，在“自动识别”下使用已取得且允许跨源的规则；“关闭”保留原图。处理不再依赖某个源 ID 或图片域名，封面不参与。

`source_rate_limit_buondua_v1` 明确保证 `com.buondua.koma` 对精确主机 `buondua.com` 的请求沿参考共用每秒10次窗口；元数据、封面及 Reader 图片缓存未命中的实际请求由现有 `SourceRequestPolicy` 统一限流。其它 CDN、其它源和缓存命中不使用该窗口。源必须显式检查此能力，旧的 `source_rate_limit_v1` 只保证漫画柜既有规则，不能据此推断 BuonDua 已限流；生产包的 `minAppVersion` 还需对应实际包含该能力的公开 App。窗口按源与规则组隔离，保漫画柜主站配置及双CDN共享限额、排队取消与网络超时预算；该能力不是 Cookie、账号、镜像或新增网络权限。

图片处理内容由用户单独添加订阅，App按清单区分书源与图片插件，不从 `repo.json` 自动发现或添加。协议和控制范围见[图片处理插件订阅](subscription-image-rules.md)，执行接口见[插件 ABI](image-processing-plugin-abi.md)。当前页和预载共用后台图片准备；原始下载、摘要及普通 CBZ 导出不变。下载清单保存公开处理声明及设置／安装摘要，源已移除时仍可离线消费；源仍安装且设置、版本或安装路径已变化时重新解析声明。兼容映射的可选 `sourceIds` 只用于旧缓存缺失声明时补查，不限制新声明及自动识别；其它缓存正文不新增源请求。派生和未命中缓存按原始内容、算法／规则及配置区分，不改原始 HTTP 会话或缓存身份。

`source_baozi_chapter_identity_v1` 允许包子的 `CHAPTER_ORDER` 在显式启用时以完整标题扩展章节身份；默认关闭，正文仍按原 slot 请求，不改变目录顺序。宿主在详情和书架更新前共用 `SourceChapterIdentity`，仅同作品、slot及完整标题唯一匹配时沿用已有ID，双向切换都保留原进度、页表和下载归属；无法唯一匹配或会合并不同章节时整次更新失败，保留旧目录，不提交部分结果。历史中的标题身份可按同一精确规则恢复；缺少标题的孤立旧ID不猜测映射。旧宿主未声明能力时，源不得展示或消费该设置。

### 正文图片气泡

`source_page_text_overlay_v1` 是正文气泡的加法能力：仅在请求顶层 `hostFeatures` 明确声明时，源可在正文页的 `image` 对象中附加 `textOverlay: { version: 1, balloons: [{ text, x, y, width }] }`。`image.kind` 仍为 `url`，原页 ID 和 HTTPS 图片 URL 保持不变；无气泡时不输出该字段。文本为源提取的 Unicode 纯文本，不解析 HTML 或其他资源。每页最多 128 个气泡，单条 UTF-8 文本小于 4096 字节、总文本最多 65536 字节；坐标均为图像像素、有限非负且不超过 65535，width 为 1 至 65535 的整数。任何气泡不能完整解析时，源必须使整次页表失败；旧宿主未声明能力时仍返回 `unsupported_chapter_overlay`，不得退回缺字原图。

DB Multiverse 固定参考将容器 scale 乘到 left、top 和 width，width 向下取整且至少为 1；文字固定黑色 Sans、14 像素、居中，参考 Android StaticLayout 的高质量换行；鸿蒙使用原生 Paragraph HIGH_QUALITY，字体回退及字度量由鸿蒙负责，字体大小不随 scale 缩放。宿主应将描述参与派生图身份、阅读及预载/普通保存分享，并为新离线下载持久保存描述；处理失败不得静默使用无对白的原图。旧下载缺描述的兼容行为需独立处理，不能声称已支持离线气泡。该能力在本地候选中接入，正式交付和具名设备验收仍需单独确认。

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

普通源管理卸载仅清当前entry安装身份的私密索引及其已验证当前代chunks；只由Host传入精确scope，没有WASM任意删除RPC，不扫描其它源/旧安装/孤儿。卸载退役该scope的在途call与旧排队准入，等待现写队列完成取消回滚后再删除；同字节重装不复活旧任务。Asset删除失败不改公开文件，公开提交失败恢复原代chunks再发布原索引并读回；读写/回滚失败明确报错，不清全部Asset或改明文。公开文件快照在Asset等待后、同一同步提交段内取得，保留其它源期间的新设置。禁用/更新及旧无声明包身份保持原合同。

`source_setting_uuid_list_v1` 支持文本设置的 `validation: {kind:"uuid_list", message:"..."}`。沿 MangaDex 参考实现逐个校验逗号分隔并 trim 后的小写 UUID（版本 1–5，variant 8/9/a/b）；空白有效，空项或尾逗号无效。不执行源提供的正则。表单显示已采用的系统输入错误状态并禁用保存；持久化 owner 在写入前再次校验，失败保留原设置及 revision。

`source_setting_positive_integer_v1` 支持文本设置的 `validation: {kind:"positive_integer", message:"..."}`。沿 WNACG 已采用的 Kotlin `toIntOrNull() >= 1` 保存合同：仅值 1–2147483647，允许前导 `+`、前导零和 UTF-16 BMP 十进制数字，不 trim、不接受浮点、空串、零、负数、溢出或补充平面数字。保留原文本；默认值和 getter 的无效值回退仍归源，不以回退代替拒绝保存。沿现表单错误态/禁用保存及持久化写前校验，不修改旧无此声明字段。

`source_dns_pica_channel_v1` 是哔咔默认分流 2 的专属适配。仅实际已安装的 `com.picacomic.koma`、包中凭据登录 URL 的精确 API origin 和已入队的当前网络操作可用本地桥 `{type:"pica_channel_init",version:1,timeoutMs?}`；不接源提供的 URL、headers 或 body。宿主只读该安装当前已提交的 `APP_CHANNEL_URL`（空白用 `http://68.183.234.72/init`），独立发 `GET`，只使用参考的 `User-Agent: okhttp/3.8.1` 和 `Accept-Encoding: gzip`。不借 Web Cookie、账号授权头或请求正文，不放宽原 `credential_input` 和每跳精确 API origin。元数据操作不能发起此准备。关闭自动跳转，最多 20 次手动 HTTP(S) 跳转，保持两头、无 userinfo；取消、安装替换或初始化中的设置 revision 变化不再发后续请求或签发结果。

成功响应沿 HTTP `{ok:true,status,bodyText,networkPerformed:true}`，只在实际 2xx、`status:"ok"` 且 `addresses[0]` 是合法 IP 或 DNS 名称时附 `dnsOverride:{kind:"pica_channel_v1",proof:"…"}`。不尝试后项。初始化流及解压后均限 64 KiB（参考原普通公开体 109 B）；HTTP 拒绝保原 status，不尝试别的线路。proof 属 Host 当前进程和同一安装，不能传任意 DNS 名称/IP，不能写普通设置、备份或日志。源可在本源私密进程缓存中保存并按 `process_scope` 更新；参考已初始化的地址在本进程内沿用，旧设置初始化迟到不发布。

源在原 HTTPS API HTTP 信封和同域图片 `get_image_request.data` 加同一 `dnsOverride`。宿主只对 `picacomic.com` 或其真实子域用该 proof 的首地址，经系统解析取首结果，向 RCP 当前 hop 注入 exact host/port DNS 映射；原 URL、Host/SNI、系统证书验证、系统代理、UA、签名头和 POST 原正文保持。无 CookieRepository、自动跳转或系统 DNS 降级重试。API redirect 仍由原 HTTP owner 处理；跨源不转发 `Authorization`，登录 grant 拒绝跨 origin。其他域的普通图片与分流 1 继续原传输；有 DNS 声明的图片由现 Reader/封面/下载 descriptor 路径消费，不持久化 proof。无此能力的 CLI 不宣 flag，并在联网前明确 `unsupported`，不得丢计划后用普通 DNS 发请求。

`source_http_copymanga_api_v1` 对应拷贝漫画独立 API 客户端。宿主仅从 HarmonyOS API 26 起声明能力，按已安装的 `com.copymanga.koma` 和三个精确 HTTPS API origin（`api.mangacopy.com`、`api.copy3000.com`、`api.copy4000.com`）的 `/api/v3/` 请求选择该路径。只接受无正文、无 Cookie 和授权头的 GET，不打开 Web 会话。RCP 使用系统代理和证书验证，选择 HTTP/1.1，禁止连接复用及缓存。仅跟随响应实际给出的 HTTPS 跳转，每跳使用同样的客户端和总超时预算。HTTP 210 按原状态交给源判断，不触发其它域或 HTTP 客户端的重试。网页与图片继续使用普通路径。

API 23–25 的 RCP 有禁止连接复用的配置，指定 HTTP 版本的配置从 API 26 起提供。NetworkKit 可指定 HTTP/1.1，公开接口没有同等的禁止连接复用配置。宿主继续支持 App 的原最低系统，拷贝的 API 路径在未声明能力时由源在联网前返回 `unsupported`。列表/筛选设置等不依赖该 API 的路径按原合同工作。

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


### 书源登录

有包声明的源明确返回 `auth_required` 时，宿主在打开该源时显示统一的登录提示和登录按钮。源声明登录方式、官方入口和字段标签，宿主负责账号表单或网页跳转、取消和返回。仅在部分作品需要登录的源可在受限操作返回同一状态，公开入口照常工作。无登录声明的旧源保留原网页验证入口。

`source_authentication_v1` 由Host公共入口消费包声明 `authentication`。`kind:"credentials"` 要求精确HTTPS `loginUrl`、`credentialStorage:"private"|"memory"`，可给 `usernameLabel/passwordLabel`。表单复用公共Modal/输入/按钮，显示真实HTTPS域与账号材料保存用途；private表示源依原协议将账号密码与token安全存入本源Asset以续登录，memory表示账号密码仅本次输入。凭据不属于普通settings、备份或诊断。`kind:"web"` 不带原生凭据保存声明，登录origin必须在包明确的 `webSessionOrigins`；复用既有Web会话、实际UA与显式完成授权。

三个可选导出由SDK独立 `koma_source_authentication_exports!` 添加，不改变旧源宏。`get_authentication` 是0网络元数据操作，接收本源settings与公开settingObservations，成功返回 `data:{authentication:descriptor,authenticated:boolean}`。credentials的descriptor须与包完整一致；web可按同设置/安装快照返回当前镜像实际loginUrl，仅接受同kind和包已声明精确HTTPSorigin，未声明新域明确提示更新源/选择支持镜像，不改到默认别站、不以正则扩大授权。`authenticate/logout` 返回 `data.authenticated:true/false`，不得返回token或原私有响应。

显式点击Host表单后，认证事务只将随机grant引用放入可信Native HTTP context，WASM请求args不含账号密码。同次本源/安装/callId经 `private_session` 的 `credential_input` 读取 `{ok:true,credentials:{username,password}}`；只有authenticate可读，探测/普通call/异源/旧包/已取消事务均不能读。HTTP每跳限该grant的精确APIorigin；取消、换包、设置/页面过期后不发新请求、不提交Asset新代、不重试原操作。源沿真实协议处理签名、登录、token与同代401刷新，Host不把任意401/403或challenge推为登录、不自动授权Cookie。成功后在原query/filter/作品/章节仍有效且页面可见时只重试原操作一次，取消保原错误；旧无descriptor包沿原WebChallenge路径。

账号材料与token复用 `SourcePrivateSessionHost` 原Asset分块/版本/发布/回滚职责，不建另一CookieJar或明文账户库。网页会话和private值按安装identity隔离。新descriptor或requiredImageDecodes仅对该声明包追加身份；旧无声明包identity字串保持逐字不变。退出只作用本源本安装私有代，不全局清Cookie/Asset。

`source_private_session_replace_v1` 为原 `begin` 增加可选 `replaceVersionTag`：在同一有效源/安装/call内只认领当前仍匹配的旧代，旧值和索引保留到成功commit；提交前再次核对代际，旧代变化返回stale_version。取消、abort、分块/索引写失败保留旧代。旧无字段begin/invalidate合同不变；显式authenticate不得先invalidate，须以此替换，logout仍可明确invalidate。它不增加账号输入权，也不另建缓存命名空间。

`source_private_session_process_v1` 增加私有RPC `op:"process_scope"`，在同一真实call/current授权下返回 `{ok:true,processTag}`。tag为Host进程随机值，本进程稳定、重启重建，不是设备标识；不读写Asset、不加入原clock响应、不记录tag。源可据它实现参考的per-App-launch镜像刷新；`get_authentication/get_settings` 仍不能借此发网络。

### 必需正文解码

包 `requiredImageDecodes:["jm_stripes_v1"]` 是能力声明，经标准metadata/build/导入/Registry保留，去重且未知kind拒绝。声明源在旧raw缓存sidecar未知时必须重新发现image descriptor，错误不回原乱码；普通旧源cache命中不增加网页依赖，不按sourceId猜需要解码。

`source_required_image_decode_jm_stripes_v1` 支持 `Page.image.requiredImageDecode:{kind:"jm_stripes_v1",rows:N}` 与 `get_image_request` 成功 `data.requiredImageDecode`。N为2至20的偶数；两处都有时必须一致，不可覆写/丢弃冲突。URI/PID保持原样。Host对实际字节先处理gzip，GIF87a/GIF89a魔数透传保动画，其他图按固定参考纵条带还原；不按URL扩展判断。原wire缓存保留，canonical派生按安装/页身份/算法缓存，在气泡、裁边与其它可选插件之前执行，不受“关闭图片处理”控制，封面不参与。下载写canonical并记录已解码标记，离线/导出不能二次解扰。非法hint、解码/格式/资源错误保持失败，不以原乱码冒可读图。

独立限流能力 `source_rate_limit_jm_v1` 沿实际JM Token/Tokenparam签名请求origin归组3次/2秒，每个原HTTP调用仅在首次实际匹配时按该origin入窗，随后重定向不重复扣额；`source_rate_limit_hentaiclub_v1` 对精确www.hentaiclub.net主站2次/秒；`source_rate_limit_wnacg_v1` 沿已核WN镜像共享50次/60秒，每个原HTTP调用的匹配重定向链只入窗一次。准入/取消/队列/超时仍归SourceRequestPolicy和原Transport，不换栈、不扩Cookie权限；其它源和原漫画柜/Buon规则保持。

网页登录可声明 `authentication.userAgent`，仅web类型、1至1024字符且拒HTTP控制字符；动态get_authentication必须原样回送包内值。仅该显式登录begin使用它，WebView实际加载和完成时UA必须一致，后续HTTP沿已授权会话UA。无字段包保原默认路径，不改变全局或普通源请求头。

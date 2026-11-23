# Koma 源包与运行 ABI

本文件描述 App 当前支持的生产 WASM 包和调用边界。字段验证的唯一实现分别在 SourcePackageImporter、SourcePackageMetadata、Registry 与 Native adapter；修改合同须同步这些消费者和本文。当前工作状态见 [CURRENT_STATUS.md](CURRENT_STATUS.md)，职责见 [WASM_SOURCE_RUNTIME_DIRECTION.md](WASM_SOURCE_RUNTIME_DIRECTION.md)。

## 包和索引

- 用户配置 source index URL，索引项提供身份、版本、本地化名称、语言、分级、包/图标地址等元数据。相对地址按索引 URL 解析。
- 生产包使用根 manifest.json、source.wasm 和一个包内身份图标。可接受格式及归档限制以 SourcePackageImporter 和 SourcePackageMetadata 为准；文件后缀不能替代内容校验。
- 仓库包 manifest 由 SourceRepoPackageManifest 解析为宿主 LocalSourcePackageManifest；后者分 package、runtime、permissions、contentPolicy 及 operationCapabilities。宿主保留 sourceId、版本、安装身份、启用状态、合法主页和已核目录方向。
- 宿主按 ABI、包声明与用户授权执行同一套能力和权限校验。禁止按书源名称、标识、站点或某个包版本写白名单、黑名单或授予特殊能力；能力适配应由所有合规包可使用的声明表达。源标识仍用于记录身份及安装实例间的会话、凭据和缓存隔离，完整性校验不授予额外权限。
- 源生产校验要求合法 homepage；App 兼容没有该字段的既有包。地址只接受无账号信息的完整 HTTP(S) URL，不从 API、CDN、失败请求或 ID 猜站点。普通网页仅显示已安装或缓存中已有合法地址的入口，不在点击后补取地址或摆空选项。
- homepage 与 webSessionOrigins 分工独立：前者用于普通导航，后者限定验证会话。主页不扩大 Cookie、UA 或网络权限。
- 拷贝漫画已安装包声明默认主页时，普通网站入口用点击时已保存的 `domain` 在同一份三个已知 API/网页域对中选站。没有保存值、保存值无效或设置不可读时，仍打开默认声明主页。这个映射只用于普通导航。
- 普通空正文 GET 携原站会话后，可跟随到当前源包明确声明的另一 HTTPS origin。逐跳核对包身份、启用状态和目标声明。跨 origin 时只保留通用请求头，目标有独立会话时使用目标会话，其余匿名读取。
- 网页验证跳到同一源包声明的另一 HTTPS origin 后，宿主可在原 origin 重试实际观察到的拒绝 GET。原始请求成功后才完成，授权仍限于原 origin，响应仍只供原请求消费一次。网页登录仍按原 origin 完成。单源搜索的相同提交复用正在执行或等待验证的请求，书源、关键词、筛选或设置变化后发起独立请求。

语言代码 `all` 表示“多语言”分类，不是“全部语言”筛选总开关；语言枚举与源身份保持原值，筛选按各语言项独立选择。

源索引与包声明的 `minAppVersion` 使用 `MAJOR.MINOR.PATCH`。宿主按已安装 App 的版本名逐段比较，兼容现有 `-pre` 规则。安装前可按索引拦截，归档解析后仍独立核包声明；安装失败显示实际拦截所需的最低 App 版本。

## 扩展与兼容

源作者的声明由打包器投影为客户端协议。同一资料只维护一份，发布时分别生成安装包清单和订阅索引。索引提供显示资料、包和图标地址、包摘要及最低版本等发现和安装信息。实际行为读取已安装包以及源操作返回值。

| 扩展内容 | 接入位置 |
| --- | --- |
| 镜像、网络、验证与会话 | 源实现或包内访问声明。请求和授权继续由宿主执行。 |
| 作品、章节及外部标识 | [作品与章节身份](#作品与章节身份)。标识规则和书库中的进度合并分别由源与宿主管理。 |
| 目录、页表和运行时行为 | 现有操作及 SDK 类型优先。需要新版宿主消费的结果，沿用 `hostFeatures` 协商。 |

可选包扩展按职责放在独立字段，定义本扩展的版本、字段语义和缺省行为。宿主跳过无法识别的可选扩展，基础操作沿用现有格式。可选运行时能力使用已有请求信封和能力协商。仅当已有浏览或阅读路径确实依赖新版宿主能力时，才提高 `minAppVersion`。

新增协议先核对包生成、导入、重载及实际消费方。需要兼容旧宿主的字段由打包器从作者声明生成，旧包按原声明解释。发布验证按源的最低支持客户端安装同一份包，并核对使用扩展的新客户端结果。

### 原站评论

源包可声明 `comments: {version: 1, scopes: ["manga", "chapter"]}`，按站点实际支持选择作用域。它独立于旧 `operationCapabilities`。旧宿主忽略该字段，新宿主跳过未知版本。书源可继续沿用原有最低 App 版本和章末文字页。

宿主声明 `source_comments_v1` 并调用 `get_comments` 时，`args` 包含 `scope`、当前源的 `mangaId`、章节作用域下的实际 `chapterId`，以及可选的 `cursor`。第一页省略 cursor。源使用自己的会话和站点访问规则，保留原站评论顺序。

成功响应的 `data` 包含 `items` 和可选 `nextCursor`。每条提供当前列表中稳定的 `id`、纯文本 `author` 和 `content`。可选 `createdAt` 使用 ISO 8601 或原站时间文本。源已明确标为删除的条目可传 `deleted: true`，此时作者和正文均为空。没有评论返回空数组，未提供下一页时省略 cursor。站点拒绝、网络及数据错误按原错误合同返回。

评论独立于 `get_pages`。用户打开面板后才读取，末项可见时加载下一页。关闭面板或源身份、设置变化后，过时响应由宿主丢弃。此扩展只有读取操作。

## 作品与章节身份

书源负责提供稳定的作品和章节标识。身份声明按所属书源、作品及可区分的章节版本解释。外部平台的标识接入复用这一职责，外部备份的解析、书库合并和续读位置由宿主功能处理。

现有旧章规则在作者侧声明为 `metadata.json` 的 `identity.chapter`。打包器仍输出为已发布客户端消费的 `websitePolicy.chapterIdentity`，保留现行匹配语义。按 `workPrefix/workSuffix`、`chapterPrefix/chapterSeparator/chapterSuffix` 拆分作品和章节槽位，再由 `titleSeparator` 或 `encodedLegacy` 处理完整标题或旧编码。旧 ID 匹配继续保护已有页表、下载和阅读进度。缺标题或存在歧义时保留原目录。

作者可在 `identity.mihon` 声明可兼容的 Mihon 来源编号及作品和章节地址规则。打包器将其写入根清单的可选 `mihonImport`。编号按字符串保存。宿主按唯一声明的来源及转换后的作品 ID 关联书架，防止不同语种的版本因同名或共用封面被合并。联网匹配只在已启用的对应书源进行。转换规则可以处理裸 ID、站内路径或固定 HTTPS 前缀，宿主只把转换后的标识交给现有源接口。章节规则默认对照完整 ID，源还可用 `targetIdSegment` 指定按冒号拆分后从 0 开始的稳定标识位置，例如章节 ID 附带可变页数时。只采用同一作品目录内唯一的匹配。只有书源同时声明 `samePageOrder: true` 且章节通过明确规则匹配时才恢复原页。规则随安装包加载，旧安装包及旧客户端继续使用已有接口。

当备份地址有 `/作品/ID/` 和 `/作品/ID/标题` 两种形态时，作品规则可在原 `pathSuffix: "/"` 的基础上声明 `pathTitleAfterId: true`。支持此选项的宿主只使用第一个路径段的作品 ID，旧宿主仍按原前后缀规则处理。可直接确认的作品 ID 和备份数据一起保存，打开该作品时再获取当前目录并迁移章页进度。

备份章地址含有多个路径段时，章节规则可用 `pathIdSegment` 指定去除固定前后缀后按 `/` 拆分的稳定标识位置。`0` 指第一段，`-1` 指最后一段。前缀为空时允许省略开头的斜杠，未声明固定后缀时允许一个结尾斜杠。目标章节仍只在当前作品目录内查找。

备份章地址同时带有作品 ID 和章节 ID 时，章节规则可在固定的 `pathPrefix` 之后用 `pathWorkIdSeparator` 分开两个 ID。前一个 ID 按作品规则的 `idPrefix` 和 `idSuffix` 验证必须属于当前作品，后一个 ID 按章节规则转换，标题片段 `#…` 不参与比较。此规则可和 `targetIdSegment` 一起使用。旧宿主仍按原有规则处理，基础浏览和阅读能力兼容。

宿主独立保存已确认的书源对应关系，便于查询失败后按原地址重试。历史续读优先用已确认书源的地址规则。缺少规则或直查失败时，仅在该源内核对候选身份。确认作品及可用目录后再写入作品关联。

## 调用路径和操作

SourceRuntimeService 校验当前源启用/能力、请求、设置及身份，Worker 调用 NativeSourceRuntime.runJsonCallFromBytes，WAMR 按 operation 选择导出。请求/响应为 JSON，当前导出映射来自 wasm_runtime_adapter.cpp 的 ExportForOperation：

| operation | WASM 导出 |
| --- | --- |
| source_info | koma_source_info |
| search | koma_source_search |
| get_manga | koma_source_get_manga |
| get_chapters | koma_source_get_chapters |
| get_pages | koma_source_get_pages |
| get_comments（可选） | koma_source_get_comments |
| get_listings | koma_source_get_listings |
| get_manga_list | koma_source_get_manga_list |
| get_home | koma_source_get_home |
| get_filters | koma_source_get_filters |
| get_settings | koma_source_get_settings |
| get_image_request | koma_source_get_image_request |
| get_authentication（可选） | koma_source_get_authentication |
| authenticate（可选） | koma_source_authenticate |
| logout（可选） | koma_source_logout |

`get_manga` 的 `data.manga.description` 仍使用字符串。纯文本保留原有换行。简介可使用原生 Markdown 渲染支持的链接、加粗、斜体、列表等格式，折叠预览和展开均支持长按复制。只有用户点击 HTTP(S) 链接时才交给外部浏览器。

`home` 表示源的独立首页内容，不能仅把已有热门、最新等列表的第一页包装成同义首页。只有列表的源声明 `home: false`，由宿主直接进入既有默认列表；为兼容 ABI 保留的 `get_home` 导出返回 `not_implemented`，不为这个空能力再发请求。真实首页及其分区与完整列表的关系仍由源合同决定，宿主不能因为部分卡片相同就隐藏首页。

### 列表卡片摘要

`search`、`get_manga_list` 及首页分区的作品项可在协商
`source_manga_list_info_v1` 后返回可选的有序 `listInfo`，不改变 JSON 信封版本：

```json
{"id":"manga:123","title":"作品名称","listInfo":[
  {"type":"text","label":"更新","text":"第123话"},
  {"type":"text","text":"作者名 · 连载中"},
  {"type":"tags","items":["奇幻","冒险"]}
]}
```

源决定实际信息、文案及顺序；最新章节、更新时间、评分等均用文字项表达，
无需逐项新增宿主字段。每张卡片最多三项；文字不超过512个UTF-8字节，
可选标签不超过96字节；标签数组最多八项，每项不超过96字节。所有内容是
纯文本，不接受 HTML、任意颜色、字号或可执行动作。宿主在列表模式统一排版，
标题最多两行，各摘要项一行，超宽省略；网格与原点击行为保持。

只有列表响应本来取得的信息才用于摘要，不为展示逐本追加详情请求。
缺省时宿主依次利用原有 `subtitle`、作者及已知状态、明确的内容 `tags`；
旧 `sourceTags` 可能只是源名等来源标记，仍保留原数据，但不自动作为题材摘要展示。
没有内容不留空行。显式空数组表示源不要自动摘要。未知类型或坏的可选项
单独忽略，不能让整页作品消失。旧宿主未声明能力时，源保留原输出；
此增强不能使原本可浏览的源提高最低 App 版本。

源设置可声明 `visibleWhen: {settingId, values}`，按指定普通单选字段的当前草稿值控制该行是否显示，隐藏后保留用户值。单选项显式声明空字符串并提供标签时，空字符串是可选择的值。文本项可声明 `validation: {kind:"non_blank", message}`，保存前拒绝去除首尾空白后为空的输入。旧宿主按已有字段渲染，源请求仍以当前选项决定实际行为。

公开封面的 GET 地址和请求头在列表或搜索操作内已知时，应随结果在 `cover: {kind:"url", url, headers}` 一次给出。无额外头用空对象。允许 `Accept`、`Referer`，宿主声明 `source_public_cover_user_agent_v1` 后也可提供原站要求的 `User-Agent`，声明 `source_public_cover_client_headers_v1` 后也可提供公开客户端标记 `Version`、`Webp`、`Platform`。宿主按完整描述并行发起请求，沿用原源限速、缓存身份和同图合并。镜像随生成卡片的列表操作确定。需要票据、认证、Cookie、专用传输或其他动态行为的封面仍通过 `get_image_request`，应省略 `cover.headers`。旧宿主沿原解析路径，书源应保留该路径。

正文需要 `Referer`、`User-Agent` 等请求头时，书源声明 `imageRequest` 能力，并通过 `get_image_request` 返回 `data: {url, headers}`。阅读器从此结果读取正文请求头。页表中的 `image.url` 用来定位图片，封面请求头使用 `cover.headers`。

宿主可在一批调用间短时复用 WAMR 的进程级内存池，空闲后释放。每次调用独立创建模块实例和请求上下文，书源状态应通过 ABI 规定的存储能力传递，不能依赖上一次 WASM 实例。正常列表优先于菜单设置能力探测，后台图片操作在真正获得执行槽后才复制 WASM 输入。

`get_filters` 的每个筛选项可选 `scope: "browse" | "search"`：默认按查询内容区分，空白查询属于 browse，非空查询属于 search；缺省在两者均有效，兼容旧源。`type: "header"` 只携带源原文的 `name`/`label` 与可选 `description`，不产生请求值、默认值、计数或持久化值。宿主只向源提交当前作用域的值，并保留另一作用域的已保存选择；切换查询不删除选择。仅当请求顶层 `hostFeatures` 包含 `source_filter_scope_header_v1` 时，源才能返回依赖作用域或 Header 的新版 schema；未声明时必须返回该源原有 schema，旧宿主不得误暴露或消费新项。

声明 `source_filter_fetching_v1` 的宿主支持可选动态筛选数据：初次 `get_filters` 返回基础 schema 和 `supportsFilterFetching: true`，不为可选标签数据阻塞目录。实际打开筛选时，宿主以 `args.fetchFilterData: true` 再调用 `get_filters`；成功返回包含基础项的完整 schema，失败保留原目录、基础筛选及已存选择，并允许下次打开时重试。稳定动态字段须在基础 schema 声明其 ID，省略 `options` 表示选项尚未加载，不能用空数组冒充。迟到响应受源包、设置版本和页面生命周期约束，不能覆盖别的源。

`source_filter_tristate_v1` 支持 `type: "tristate"`：一个字段表示一组标签，`options` 使用原站 ID/名称，ID 不能以 `!` 开头。值为字符串数组，`id` 表示包含、`!id` 表示排除、缺省表示忽略；同一 ID 只能有一个状态。宿主复用原生多选菜单循环切换，清除此项移除整组选择。选项未加载时保留已存状态，不能因打开页面先收到基础 schema 而丢掉筛选。源未取得对应 Host 特性时，仍返回原 schema。

`source_filter_search_without_query_v1` 允许书源用 `get_filters` 的 `data.useSearchForFilters: true` 将筛选交给 `search`。筛选项声明 `scope: "search"`，基础与延迟 schema 保持同一作用域。用户选择或提交筛选时，宿主可发送 `args.query: ""`，分页、重试和网页验证仍使用同一搜索上下文。普通热门、最近更新等列表继续各用原入口。清空关键词或重置空词筛选时返回未筛选状态。旧宿主没有此声明，源保留原 schema。

`source_listing_filter_scope_v1` 支持 `get_listings` 的栏目声明 `supportsFilters: false`。宿主在该栏目不显示浏览筛选，并发送空 `args.filters`，同时保留已保存的其他栏目筛选。关键词搜索和专用筛选搜索独立生效。省略此属性的栏目沿用原行为。

是否允许某项操作仍由当前源声明、真实导出和准入共同决定；原生有映射不代表所有源实现。测试专用导出不构成产品能力。响应沿 NativeSourceRuntime 的 ok/operation/data/error/reasonCode/hostHints 合同，由服务及实际 DTO 消费者校验，不凭字段存在冒调用通过。

## 宿主边界

- WASM 只使用受控 host imports；当前原生注册表为 wasm_runtime_adapter.cpp 的 g_komaHostSymbols，HTTP/HTML 行为分别由 http_host 与 html_host 实现。不能从开发 runner 导入推定 App 提供同名能力。
- WAMR 的初始化和内存池由进程内的在途调用共同持有；并发数受原生运行器限制，同一源的普通调用保持串行，缺少宿主源身份的调用独占运行。每次调用使用独立的模块、线程环境、HTTP 身份和 HTML 句柄，结束时释放所属句柄。所有异步源消费者共用 Worker 前的有界调度，并丢弃尚未入 Worker 的过期搜索；排队时间不计入网络期限。封面解析只在同源尚未执行的任务中让位于交互请求，Reader 页图、正文和其他元数据保持前台优先；不同源保持原 FIFO，原队列的同源串行和并发上限不变。统一搜索进入 Worker 后若已失效，HTTP 限速等待前后阻止新请求；已发出的请求仍可能完成，不把丢弃迟到结果称为网络中断。
- 旧源的封面 `get_image_request` 可在宿主的独立有界队列中执行，无需更新包或声明新能力。此路径只接受现有可约束的原生导入，覆盖 WASM 初始化和操作；尝试访问 HTTP（含私有会话 RPC）、时钟、随机数，或遇到未知导入及执行异常，便丢弃受限结果，按原同源顺序进入原队列一次。会话、Reader 页图、交互请求、传输、限速和缓存沿用各自原合同。受限执行中的日志仅在该结果被采用时输出。
- 包、请求及响应大小、执行/网络期限和取消按当前 importer、service 与 native 常量执行，本文不复制易漂移的数值。未声明能力、无效身份和不支持操作不能默认放行。
- 单源搜索允许某一页因语言等既有筛选而没有条目，但仍返回有效的下一页游标。宿主保持已有结果，沿仍有效的同一次查询继续取页，直到增加条目或源明确结束；不依赖没有行变化时不会再次触发的列表到底事件。每个成功游标分别提交，失败及验证只重试随后失败的一页；查询、源包或设置改变后不得继续。重复游标按响应错误处理，不伪造搜索结束，也不改变请求通道的限速、期限或权限。
- 源设置须有真实 schema 及实际消费。schema 空/失败不显示空入口，也不污染已保存设置的全局状态；存储读取失败保留有效入口并报告具体阶段，不使用“设置验证失败”泛化提示。cookies、userId、token 不因存在导出而开放普通明文持久。
- 文本输入设置的 `description` 是源提供的格式说明，表单在输入框下完整显示；已有输入值时仍保留，不用 placeholder 替代。没有说明的字段沿原布局。
- SourceSettingsStore 复用本进程最近提交的私有快照，调用方仅取得副本；单源请求及管理页统计不重复读盘解析全文件。写入成功才发布快照和 revision，失败保留旧值；路径切换、原文件事务回滚及备份回滚由同一 owner 失效，不以缓存掩盖尚未成功读取的错误。
- 图像请求描述进入原有下载/缓存通道；源不直接接管文件、账户、图像处理、Reader 进度或共享 Kit。
- 正文图的常规请求保留原期限。站点在同一次响应中明确给出超过 NetworkKit 默认缓冲的内容长度时，允许在更大的有界传输预算内完成。封面使用更短的有界传输期限，对超时及可恢复网络/服务端失败只做一次退避重试；解码失败时先移除本次封面缓存文件，再允许同一次重试。认证、额度、缺失和源合同失败直接保留终态。权限、限速、缓存身份和失败后不写入部分图的行为沿用原路径。

### 站点规则声明

书源根 manifest 可带可选的 `requestLimits` 和 `websitePolicy`，由本源 `metadata.json` 随包生成。导入、注册与重载均校验声明。站点声明只选择已实现的能力，和账号授权、Web会话授权及TLS验证相互独立。

宿主安装和重载时都从已解包的清单读取站点声明。注册表持久化安装位置和状态，运行规则只在内存中保留，旧注册表中的规则副本不参与加载。重载时核对同目录清单、书源身份、版本和 WASM 声明。清单缺失或无效时，保留该安装项以便覆盖修复，并阻止它发起书源请求。相同原包按字节确认后可恢复损坏的安装，沿用原订阅归属、设置和会话身份。备份保留已验证的包规则，恢复时写入对应包目录的清单。

- `requestLimits` 最多8个滑动窗口，每项声明唯一 `group`、`permits` 和 `periodMs`。可用精确 `hosts` 或带 `prefix` 的 `firstLabels` 匹配主机，可要求指定 `requestHeaders` 存在。默认同源包同组共享，`perOrigin` 将HTTPS origin分开计数，`oncePerRequest` 使同一次HTTP调用的匹配重定向只占一次。可选 `setting.key` 覆盖次数，`windowValue` 读取「次数/秒」，`keepUntilRestart` 采用该安装首次读取的值，`maxPermits` 限制设置值。缓存命中不入队，排队可取消且不占网络超时。`source_request_limits_v1` 仅对声明有效窗口的安装包提供。
- `websitePolicy.homepageChoices` 通过 `setting` 和 `options[{value,url}]` 选官网地址，缺省回退包首页。显式映射最多16项，默认站点可只由包首页表达；设置选项仍可包含该默认值。1.6.1起，此类源的手动网页会话使用同一已选／默认主页，不借用旧镜像的失败地址；自动验证优先对应操作的精确失败GET，详情与目录重试沿用该操作句柄。普通网页不获得验证授权，普通手机网页可按精确 `mobileWebAndroidAgentOrigins` 保留站点兼容标识。`publicCookieOverrides[{origin,name,values}]` 仅允许已授权会话在同一精确origin替换唯一合法的公共Cookie项，每跳重新核验。
- 验证页的系统 WebView UA 由宿主从当前 ArkWeb 默认 UA 派生，在 OpenHarmony 平台标记内追加 `; Android 10`，保留原有引擎与移动标识。精确 `systemWebAgentOrigins` 可选择 ArkWeb 原生 UA。旧包的 `webSessionAndroidAgent` 和 `webSessionUserAgent` 字段仍可读取，验证页仅接受宿主派生的 UA。普通 HTTP 请求的 UA 和显式网页登录的 `authentication.userAgent` 各自适用。
- `websitePolicy.webFetchBridge` 是显式 opt-in。根页面在收到首个桥接请求时创建隐藏 WebView，此后由根页面持有，书架和历史直接续读也可使用同一会话。验证完成后，源的同源 GET（无 body）可由页面内 fetch 读取，响应体作为 200 `bodyText` 交给源；不改变阅读界面，也不依赖浏览页存活。隐藏上下文必须使用当前源、包和原点已授权的实际验证 UA，在 `loadUrl` 前设置，并绑定当前授权修订；同 UA 重新授权也会淘汰旧请求，等价注册表重载保留原授权。源、原点或授权不匹配时重新准备，在等待后、发出请求前和收到结果后复核，取消或替换后的旧结果不得返回。没有当前授权时沿原网络路径验证，不在隐藏页另外申请权限。未声明或 bridge 未就绪时回退原网络路径；每个新 URL 都独立 fetch，不能将一次渲染文档回放当作完整桥接。宿主能力名仍为 `source_web_fetch_bridge_v1`。 Browse完成与HTTP prepare可以同时请求同一隐藏文档：仅在完整URL、源、包身份、已授权UA及授权修订均相同时合并在途准备，不因新的投递时间戳重复attach/loadUrl。沿用现有准备预算，不增加等待；主文档失败、同步加载失败或准备预算到期允许后续重新请求，身份变化立即重新准备。真实主frame导航（即使URL相同）仍执行markLoading并淘汰旧请求，不以该合并绕过revision守卫。
- `source_web_http_v1` 在同一 `websitePolicy.webFetchBridge:true` 和精确 origin 网页授权内扩展通用 HTTP 数据通道，不新增 WASM import 或站点专口。该feature尚未随正式1.6.0发布，本节完善本地1.6.1首发合同，不另叠数据专项feature。沿原 HTTP request 的 `url/method/headers/body/timeoutMs`；支持 GET、HEAD、POST、PUT、PATCH、DELETE，GET/HEAD 禁止正文。所有方法均须以可扩展选项 `webFetch:{version:1}` 显式选择本通道；未带该选项的普通POST等方法保留原native路径，旧无正文GET保留原bridge成功/挑战重试与native fallback行为。源须先协商新 feature；未声明 bridge 或没有授权仍走原 native 验证，不为请求自动授予权限。
  - 上传沿原 `body`（UTF-8文本）、`requestBytes`（严格Base64）、`requestBodyRef`（本次调用的引用ID）互斥选择。二进制上传仍仅POST/PUT/PATCH，Web上传三种正文统一最多1 MiB；引用在分配读取前检查大小，文本按UTF-8字节计数，超限在fetch前返回`request_too_large`，不得转native规避预算。引用不扩大网页权限；原native上传引用预算不变。
  - 响应沿原 `responseKind`：缺省/`bodyText`返回`bodyText`（最多4 MiB）；`bodyBytes`返回`bodyBase64`且`bodyText`为空（最多1 MiB）；`bodyRef`返回`bodyRef:{id,length}`且`bodyText`为空。BodyRef复用`source_http_body_v1/source_body_v1`的可用性、当前源/安装/调用作用域及128 MiB单体、256 MiB单调用、512 MiB全局预算。浏览器原始字节按最多65536字节分块，mailbox最多四块并对reader施加背压，宿主有数据时立即继续排空，不将整图转成一个Base64字符串。失败/取消/超时清除partial BodyRef；只有完整且仍有效的响应交付引用。引用可直接沿既有`source_image_body_v1`交给图片缓存、阅读及下载，不要求consumer再GET同一图片。
  - 浏览器可见响应头最多64 KiB。最终URL选项、源私有Cookie session、nativeSession、webToken、游客专用、DNS覆盖及账号凭据仍不混入此通道；显式 `webFetch` 与这些组合返回 `invalid_request`。缺少BodyHost的宿主不声明相应引用能力；旧native路径原有能力不变。
  - 普通 headers 与文本正文由源提供，Cookie、User-Agent、Origin、Host、连接相关和 `Sec-/Proxy-` 等浏览器禁止头由Web引擎生成，不从原生会话手动灌入。源 `Referer` 仅允许同一精确授权 origin，映射到 Fetch `referrer` 及 `referrerPolicy:'same-origin'`，跨 origin 或含控制字符明确拒绝；不静默改成隐藏页地址。依据[Fetch Request构造合同](https://fetch.spec.whatwg.org/#dom-request)。隐藏页只作同源上下文；首次准备导航 origin 根文档，不能以 GET 预取待提交的 POST 地址。
  - fetch 使用 `mode:'same-origin'`、`credentials:'include'` 和 `redirect:'error'`。本版本连同源自动重定向也不跟随：浏览器隐藏手动重定向的状态/Location，不能猜地址或重复提交。实际收到的非重定向响应按真实 `status`、`headers`（仅浏览器可见且排除 Set-Cookie）和所选正文类型返回；空正文、HEAD/204及HTTP错误均是有效响应，不自动换native或重发。重定向、网络、超时及大小限制错误如实返回失败，不伪造状态或正文。
  - 只有明确发送前 unavailable 才可继续原 native 路径。提交JS后的状态有歧义也按 attempted 处理；所有通用请求仅一次 fetch，不因HTTP错误、空正文、超时、取消而双attempt或native重放，失败 `retryable:false`。限速、源包、原操作guard、实际UA及授权修订在准备、发送与回包时核对。JS有界期限与宿主回调期限独立，AbortController覆盖取消/超时；先使job失活再abort并删除mailbox，迟到成功/失败不能重建缓存。宿主日志只记attempted/终态，不记URL、头、正文或凭据。
  - WebHTTP响应沿原native规则登记实际拒绝URL及操作内GET因果ID；仅浏览器可见的精确`cf-mitigated: challenge`生成`accessSignal:"challenge_required"`，普通403不猜CF。匹配的已验证文本GET／可见文档一次性交接在再次Web发送前消费，仍按原请求、源包、guard及会话隔离；BodyRef不进入跨调用文本重放，POST不伪造GET探测。字节通道可用不代表站点GET访问已恢复，须按同一真实网页授权身份另验。
- `websitePolicy.renderedDocumentFallback` 是显式 opt-in，可声明 `true`（手动完成）或 `{"readySelector":"..."}`（就绪后自动完成）。仅该安装包声明且用户已在验证半模态打开站点时，宿主读取当前可见文档，并与原 GET 的源、操作 guard 和请求文本绑定；声明 `readySelector` 时，主文档可见后在有界的同一文档任务内检查已解析状态（interactive/complete）和该选择器，满足才暂存文档、关闭验证半模态并重试原 GET，无需等待第三方图片或广告全部完成。跳转、关闭或主文档失败使旧检查失效；未满足则保持验证页。文档以一次性 200 `bodyText`（`networkPerformed=false`）交给源解析。不新增 WASM ABI，不后台自动打开 WebView，也不扩大 Cookie、UA 或网络权限；未声明的源保持原路径。宿主能力名 `source_web_document_handoff_v1`。
- `httpProfiles[{origin,pathPrefix?,profile}]` 对当前包的精确HTTPS origin选择现有 `firefox133`、`chrome145`、`chrome116`、`chrome131_android` 或 `fresh_http11`。前四者是空正文GET的传输兼容配置，不是验证页UA；实际请求继续复用宿主授权的UA/Cookie，并保留系统代理和TLS校验。系统代理存在或原生依赖不可用时按原网络预算回退。兼容库的版本与构建见[固定构建配方](../scripts/prepare-source-browser-http.sh)。`source_http_profiles_v1` 表示系统支持 `fresh_http11`（API 26起），该模式要求无正文、Cookie及授权头的GET，使用系统代理、证书验证和HTTP/1.1，禁止连接复用及缓存，仅跟随合法HTTPS重定向，继续使用同传输限制。
- `source_anonymous_http_v1` 使用 `websitePolicy.guestHttp` 和 `guestSearch:true`。仅该精确HTTPS origin可访问声明的 `exactPaths`、`numberedPaths` 或只允许重定向的 `redirectNumberedPaths`。数字路径声明 `prefix`、`suffix` 及可选 `numberSeparator`，数字必须为正整数。该模式只发送声明的公共Cookie，不使用账号头或系统Web会话。仅声明的响应路径可通过 `guestSearchCookie` 回传指定的公共Cookie，`guestSearchUrl` 返回实际到达地址。
- `source_http_response_url_v1` 供试读等需要最终有效地址的入口使用。书源在 `websitePolicy.responseUrlOrigins` 声明 1–8 个精确 HTTPS origin，并在无正文 GET 中设置 `includeResponseUrl:true`。宿主逐跳校验，沿用网络期限、限速及取消，成功信封的 `responseUrl` 保留最终地址的查询串。已授权的网页会话只用于初始 origin，其他 origin 只收到公开请求头。该请求使用实际网络响应或绑定同一请求的网络回放。普通请求及未改版书源保持原合同。
- `source_http_response_metadata_v1` 使请求可独立选择要读取的响应信息。`responseMetadata.finalUrl:true` 返回 `responseUrl`，沿用上条的来源声明、权限与跳转检查，也支持源自行提交表单后读取最终地址；旧 `includeResponseUrl:true` 仍限无正文 GET。它可与 `wantChallengeRequestId` 一起使用。若原路径采用已声明的一次性文档接续，且可见文档通过源、会话、操作及原请求校验，回包仍返回该文档的实际地址。旧宿主可继续使用先前的请求选项和解析方式。
- `source_http_bytes_v1` 在原 `http_request` 上接受 `responseKind:"bodyBytes"`。真实网络响应按原始字节接收，成功信封保留真实 `status`，以 `bodyBase64` 携带正文，`bodyText` 为空。单次最多 1 MiB，源的输出缓冲区还须容纳 Base64 信封；SDK 的 `Response::body_bytes_into` 解码到源提供的缓冲区。缺省沿原native字节传输及当前身份，不走旧文本GET bridge或浏览器配置传输；本地`source_web_http_v1`可用时，显式`webFetch:{version:1}`按上文同源数据合同读取。原有图片阅读及下载路径不变。
- `source_http_cookie_session_v1` 接受 `session:"source"`，宿主在内存中保存并复用本源实际 HTTP 响应设置的 Cookie。按书源、安装包身份、精确 HTTPS origin 隔离，遵守 Path、过期、删除和 Secure 前缀；不把 Domain 扩散到兄弟域或子域，不读取系统 WebView 或账号授权 Cookie。显式请求 Cookie 同名时优先。单 origin 最多 64 项、每项最多 4096 字符，最多 128 个 origin；无过期属性的 Cookie 最长保存 24 小时，进程退出即失效。逐跳手动处理重定向，跨 origin 去除敏感头，再匹配目标独立会话；普通原生请求保留源显式完整 Referer、缓存控制及合法浏览器公共头，不转发 Cookie、Authorization 或 Proxy-Authorization。源的显式 Referer 不是宿主授权凭据；Web grant、待完成验证及读取最终地址的请求仍沿原 Accept/Accept-Language/User-Agent 三项过滤。沿用请求总期限、限速、取消及当前源包校验。二进制与此会话可独立或组合使用，仅限当前已启用的真实安装身份，不能与账号凭据、`nativeSession`、网页令牌、游客专用、DNS 覆盖或验证探针混用。两项能力都不新增 WASM 导入；旧源保持原行为，新源先按 `hostFeatures` 判断再使用。
- `source_dns_bootstrap_v1` 仅能由具备凭据声明的已安装包在网络操作中使用。按 `websitePolicy.dnsBootstrap` 选择域名、已提交的模式/地址设置、默认URL、公共UA和响应字段。独立请求 `{type:"source_dns_bootstrap",version:1,timeoutMs?}` 不接收源提供的任意URL、头、正文或账号材料。最多20次重定向，响应限64 KiB，取消、包替换、设置变化或精确凭据授权失效时停止。成功返回进程内 `dnsOverride:{kind:"dns_bootstrap_v1",proof:"…"}`。API和图片只可用同安装的有效proof为声明的HTTPS域及子域选首地址，保留原URL、SNI、系统证书验证和代理。不同安装不能复用proof。proof不写普通设置、备份或日志。
- `preserveRouteCover` 允许详情沿用进入时的有效封面，`routeCoverPlaceholderSuffix` 排除占位图。`publicWorkUrlDomains` 仅用于下载记录公开来源地址，继续过滤账号信息、查询和片段。

生产App按声明执行站点规则。缺少所需宿主能力时，源可返回 `host_feature_required`，宿主统一提示在书源管理检查更新。普通的 `unsupported` 继续表示当前操作不受支持。

HTTP 诊断关联宿主提供的操作名，并记录原生传输的 DNS、TCP、TLS、首字节和结束累计时间；零值不单独证明对应阶段完成。操作标签不参与会话或私有数据身份，不持久化；日志不包含请求地址、请求头、Cookie 或响应正文。

JSON POST 使用 HTTP 信封的 `body` 字段传入已经序列化的正文字符串。历史字段 `bodyBase64` 优先取值，宿主也会原样发送这个字符串。源的本地回放必须使用同样的原样正文，不自行解码或重写请求。

## 宿主特性

### 书源界面语言

本节为本地 App 1.6.1 构建合同，尚未随正式 App 发布。公共调用侧在入队前从已恢复的 `LanguageState` 内存捕获一次环境，Worker 只消费快照。所有有请求参数的源操作共用下列顶层字段；零参 `source_info` 保持原签名和规范值：

```json
{
  "hostFeatures": ["source_localization_v1"],
  "environment": {"version": 1, "uiLocale": "zh-Hant-HK", "localeFallbacks": ["zh-Hant-HK", "zh-Hant", "zh"]}
}
```

只有有效的 v1 环境才协商 `source_localization_v1`。`localeFallbacks` 先核原始项数最多16，规范化后必须逐项等于 `uiLocale` 生成的完整候选链，拒绝额外项、重复项及换序，不先去重后放行。此能力只提供 UI 语言，不改变作品内容语言、HTTP `Accept-Language`、Cookie、UA 或权限。源 SDK 按环境选择文案，继续返回现有 plain strings；设置 key/default/value、筛选 ID/option value、作品/章节 ID 及顺序不能随翻译改变。未接入 Catalog 的旧源保持原文；接入者没有可用 Host 环境时仍取作者明确的 `defaultLocale`，最后退该字段 literal。

静态离线展示可在 manifest/index 使用可选 `presentation: { version: 1, defaultLocale, texts }`。`texts` 按文本角色收集 locale→字符串，目前消费 `name`、`description`、`author`、`authentication.usernameLabel`、`authentication.passwordLabel`；旧 `localizedNames` 继续兼容。Importer、注册表、备份恢复及包分享保留资源，只在显示时解析，不改规范 name/description 或认证 descriptor。解析顺序是请求 locale 精确项→地区/显式脚本及语言→源 `defaultLocale` 同规则候选→旧 literal；zh-HK/TW/MO 推导 Hant，zh-CN/SG 推导 Hans，显式脚本优先，不取对象第一项。locale 最长63字符，每角色最多16个原始 locale 项；名称/作者/认证标签沿128字符限制，描述沿已有包/字段总预算。坏的可选译文按字段回退，不拒绝整个旧源；不增加 ZIP 成员或执行动作。

语言切换只推进本机 UI 代次。重新打开按当前语言取设置、栏目与筛选；安全的本地 schema 刷新禁用网络，按原字段/选项 ID 仅合并显示文案，保留草稿、控件语义、完整动态选项、栏目顺序及已加载状态，不把基础/空 schema 当作新的完整数据覆盖。旧语言迟到回包不得覆盖新代次。需网络的动态摘要沿原刷新时机更新，失败保留已有内容，不承诺缓存纯字符串能离线重译。语言代次不进入包注册、BrowserGrant、页表、原图、阅读或下载身份。无前台启动的后台维护仅在内存语言尚未恢复时复用原 `LanguageSettings` 加载一次，不在逐页请求中读取偏好。

`source_image_response_errors_v1` 允许正文的 `get_image_request` 在 `data.responseErrors`
声明实际原图 GET 的状态含义。例如 `{"402":"image_quota_exhausted","429":"rate_limited"}`。
宿主仅消费 401 的 `auth_required`、403 的 `permission_denied`、429 的 `rate_limited`，
以及 402、403、429 上明确声明的 `image_quota_exhausted`。未知映射忽略。声明只属于这份正文请求，
不进入缓存或封面，不从响应正文猜原因，也不预请求一次图片。宿主负责实际 GET、错误本地化和
安全诊断。书源自己发出的 API 请求仍由书源解释业务失败，可直接返回结构化错误。
未声明此能力的宿主按既有行为加载，源可为新增业务错误提供旧宿主认识的降级原因。

章节可选 `readingOrder` 表示同一阅读序列中的位置，独立于展示用 `chapterNumber`／`volumeNumber`。源提供有限、非负的 `readingOrder` 时优先使用该值，并保留 `readingGroup`／`continuationEligible` 分组许可。同组显式阅读位置重复须由源区分，或按源声明的替代版本处理。未提供阅读位置的旧目录按[原源目录兼容规则](#网页会话与章序)处理。依赖此字段的源仅在 `hostFeatures` 含 `chapter_reading_order_v1` 时输出对应续读合同，旧宿主保留原章节输出。协商后明确的 `ManualOnly` 必须输出 `continuationEligible:false`，不能省略后混入旧目录推序；普通单章和未协商的旧输出保持原合同。宿主的详情快照、入库、目录更新、持久化和 Reader 会话使用同一字段。

`chapter_reading_variants_v1` 支持源以 `readingVariantGroup` 声明同一话的多个可读版本。每组必须使用同一阅读序列和显式 `readingOrder`，且组名在该序列中只对应一个位置。可选 `readingVariantSequence` 指定可跨译本续读的序列，此时 `readingGroup` 继续标识原译本组，阅读器优先选同组。缺省时，序列仍由 `readingGroup` 标识，阅读器在替代版本中优先匹配 `scanlator`。自动前后章和预载保留当前手选版本，其他位置无同组时按稳定章节 ID 选取。所有版本保有独立章节 ID、阅读记录和手动入口，批量已读和导出仍按原组处理。源在宿主未声明能力时只发原有的章节顺序和分组。

正式源操作的请求顶层由宿主加入 `hostFeatures`，元数据、章节、页表及普通图片/文字页的 `get_image_request` 共用该声明。当前支持 `text_page_image_v1`、`text_page_image_zaimanhua_comments_v1`、`source_text_page_request_v1`、`source_setting_observations_v1`、`source_chapter_exclusions_v1`、`source_setting_uuid_list_v1`、`source_public_cookie_override_v1`、`source_homepage_choices_v1`、`source_settings_context_v1` 、`source_http_batch_v1` 、`source_filter_scope_header_v1`、`source_filter_fetching_v1`、`source_filter_tristate_v1`、`chapter_reading_order_v1`、`source_private_session_v1`、`source_page_image_processing_v1` 是正文图片准备的可选声明。现有 `imageProcessing: { kind: "baozi_banner", mode: "1" | "2" }` 由订阅图片规则中的兼容映射消费；普通、强力及关闭语义保持。宿主在“跟随书源”下遵守该声明，在“自动识别”下使用已取得且允许跨源的规则；“关闭”保留原图。处理不再依赖某个源 ID 或图片域名，封面不参与。

`source_related_manga_v1` 允许 `get_manga` 在 `data.manga.relatedManga` 返回可选的同源作品卡片数组，使用现有列表卡片的身份、标题、封面及公开图片请求字段。宿主保留原顺序，跳过本作、重复和无效条目，最多读取前 100 项。详情仅在有有效条目时通过现有更多菜单显示「相关作品」，用同一书源的普通详情入口打开卡片。缺省或空数组不改变现有详情与阅读，宿主不会为此发起额外的源调用。

图片处理内容由用户单独添加订阅，App按清单区分书源与图片插件，不从 `repo.json` 自动发现或添加。协议和控制范围见[图片处理插件订阅](subscription-image-rules.md)，执行接口见[插件 ABI](image-processing-plugin-abi.md)。当前页和预载共用后台图片准备；原始下载、摘要及普通 CBZ 导出不变。下载清单保存公开处理声明及设置／安装摘要，源已移除时仍可离线消费；源仍安装且设置、版本或安装路径已变化时重新解析声明。兼容映射的可选 `sourceIds` 只用于旧缓存缺失声明时补查，不限制新声明及自动识别；其它缓存正文不新增源请求。派生和未命中缓存按原始内容、算法／规则及配置区分，不改原始 HTTP 会话或缓存身份。

`source_chapter_identity_v1` 允许包子的 `CHAPTER_ORDER` 在显式启用时以完整标题扩展章节身份；默认关闭，正文仍按原 slot 请求，不改变目录顺序。宿主在详情和书架更新前共用 `SourceChapterIdentity`，仅同作品、slot及完整标题唯一匹配时沿用已有ID，双向切换都保留原进度、页表和下载归属；无法唯一匹配或会合并不同章节时整次更新失败，保留旧目录，不提交部分结果。历史中的标题身份可按同一精确规则恢复；缺少标题的孤立旧ID不猜测映射。旧宿主未声明能力时，源不得展示或消费该设置。

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

私有值在当前调用内交给本源 WASM 构造请求，持久化只经 Asset 的 1024 字节分块和最后发布的短索引完成，不进入公开设置、备份或诊断。日志只记录操作、固定结果码及 ready/owner 状态。Host 分开记录当前包的执行身份和书源会话的存储身份。正常更新沿用同包名的既有会话，条件是已绑定并启用的 HTTPS 订阅认可实际下载的整包 SHA-256，且登录地址、授权域、Cookie 名称及凭据策略一致。镜像可用同一份已核对的包。包清单不能声明存储身份，备份不携带它。同版本同字节的本地包重复导入直接沿用原安装。来源或授权范围改变后使用独立会话。新版本只在安装记录提交后接续，旧包在途调用作废。读写失败保留错误，不以清除所有资产或改用明文文件恢复。

普通源管理卸载仅清当前entry安装身份的私密索引及其已验证当前代chunks；只由Host传入精确scope，没有WASM任意删除RPC，不扫描其它源/旧安装/孤儿。卸载退役该scope的在途call与旧排队准入，等待现写队列完成取消回滚后再删除；同字节重装不复活旧任务。Asset删除失败不改公开文件，公开提交失败恢复原代chunks再发布原索引并读回；读写/回滚失败明确报错，不清全部Asset或改明文。公开文件快照在Asset等待后、同一同步提交段内取得，保留其它源期间的新设置。禁用/更新及旧无声明包身份保持原合同。

`source_setting_uuid_list_v1` 支持文本设置的 `validation: {kind:"uuid_list", message:"..."}`。沿 MangaDex 参考实现逐个校验逗号分隔并 trim 后的小写 UUID（版本 1–5，variant 8/9/a/b）；空白有效，空项或尾逗号无效。不执行源提供的正则。表单显示已采用的系统输入错误状态并禁用保存；持久化 owner 在写入前再次校验，失败保留原设置及 revision。

`source_setting_positive_integer_v1` 支持文本设置的 `validation: {kind:"positive_integer", message:"..."}`。沿 WNACG 已采用的 Kotlin `toIntOrNull() >= 1` 保存合同：仅值 1–2147483647，允许前导 `+`、前导零和 UTF-16 BMP 十进制数字，不 trim、不接受浮点、空串、零、负数、溢出或补充平面数字。保留原文本；默认值和 getter 的无效值回退仍归源，不以回退代替拒绝保存。沿现表单错误态/禁用保存及持久化写前校验，不修改旧无此声明字段。

`source_detail_chapter_context_v1` 仅由详情页本次 `get_manga` 和随后的目录请求声明。源可在成功详情的 `data.chapterContext` 返回非敏感 JSON 对象，宿主仅在同一仍有效的详情事务中将其原样传入 `get_chapters` 的 `args.chapterContext`，分页共用；不写缓存或日志，不跨刷新、源包或设置变更、其他作品或精确章恢复使用。源须核对上下文的版本和作品身份，缺失或不完整时沿原请求路径处理；旧宿主不声明该特性。

`source_http_challenge_cause_v1` 由宿主为带操作生命周期的读请求声明，包括受跟踪的统一搜索、单源搜索、浏览、详情及阅读页表。源在单个 GET 中设置 `wantChallengeRequestId: true` 后，宿主仅为该源允许的网页 origin 上返回 401、403 或 503 的实际请求附加短 `challengeRequestId`。只有源最终由该次响应产生 challenge/auth 错误时，才可将同一个 ID 放在 `error.challengeRequestId`；不得推测其他请求的 ID。宿主按 ID、源和本次页面请求身份匹配原 GET，验证后的响应仅由该次请求的重试消费；多条不同失败 GET 缺乏明确 ID 时不能猜测。验证页在加载前选择系统 WebView UA。成功后会话保存实际 Web UA，后续获准的同源原生请求随 Cookie 一起复用该 UA。取消或请求失效清除关联。旧源不使用此字段，保留单个候选的既有兼容行为，旧宿主不声明该特性。

站点的验证文档可能以不同 HTTP 状态返回。书源对可能呈现验证文档的 GET 设置 `wantChallengeRequestId: "document"`，宿主为实际收到的响应附加短 ID，不按状态码判断验证。书源识别表单后才把同一个 ID 附加到挑战错误，宿主校验本源声明的网页域和当前操作后，以该次实际请求地址打开网页。源可在 `websitePolicy.webSessionReadySelector` 声明验证成功页面的 CSS 选择器。宿主在当前仍有效的同源主文档匹配选择器后，保存会话、关闭半模态并发出原请求。选择器只判断是否就绪，重试仍由原生网络执行。缺少标志时继续保留网页和手动完成入口。普通请求继续使用原策略。旧宿主忽略新增声明，保留原网页入口。

本地1.6.1也可将同一`webSessionReadySelector`用于允许自动重试的普通challenge会话（包括没有GET因果ID的POST）：仅在不属于上述文档验证、且没有既有`renderedDocumentFallback.readySelector`时，用它判断当前授权页是否已有源声明的真实成功内容。R5真实主页已就绪但clearance未变化、仍需手动完成，是本轮依据；Cookie存在或未变化本身不是内容就绪证明。该分支只读readyState/querySelector布尔结果，同params.url精确origin及epoch/source/session/文档URL/revision必须在异步读取和Cookie保存前后持续有效，才沿原完成流程保存实际UA的会话并重试原操作一次。它不读取/交接HTML、不启用DOMfallback、不伪造GET探测、不清Cookie，也不代表原请求或正文已成功。`autoRetryOnClearance:false`的账号登录及webToken入口不适用。既有文档验证、renderedFallback selector优先、跨origin/native probe及手动完成行为保留；缺selector、标志未匹配或上下文失效不新增授权。旧宿主在普通challenge中不消费该声明，保留原clearance/probe/手动路径；无需新API或feature，源须等待含该消费分支的实际宿主验收。

`source_http_batch_v1` 在原 `http_request` import 上支持 `{version:1,requests:[单请求对象]}`，每组1至5个且不能嵌套，只用于彼此独立的请求；存在响应或会话依赖时仍逐个发送。宿主先校验整组基本请求格式，再并行复用原单请求通道；每项保留源身份、会话、限速、重定向及网络超时。响应为 `{ok:true,responses:[单请求响应对象]}`，顺序与输入一致；外层 `ok` 只表示组格式有效，每项仍可能是原HTTP或传输失败，源必须逐项检查。宿主不自动重试、不缓存组结果、不扩大网络权限；未声明此特性的旧Host沿原逐个请求路径，不需要新增WASM导入。

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
- 新作品默认按图源倒序展示；已有作品沿用已保存的图源目录展示方向；菜单的「正序／倒序」表示阅读时间方向，不能把网站原数组一律称为正序。源声明 `newest_first`（或完整阅读位置递减）时，原数组展示是倒序，正序展示需反转；旧保存的 `forward/reverse` 仍代表原数组方向，只换算菜单含义，不翻转用户已保存的列表。方向来源只使用源声明或同组阅读位置，不能用章节号或名称给显示方向下结论。章节编号、上传日期、名称排序分别使用源提供的 `chapterNumber`、`publishedAt` 或兼容的 `dateUpload`、`title`。缺少编号或日期时保留缺失语义。选用其它依据时，开始阅读和同一已核实阅读组内的上下章也使用该依据的正向顺序。同值保留原有阅读关系，列表的正反序只改变显示。章节 ID、读态、版本分组以及手选限制继续沿用。
- 完整原源目录到齐后，宿主按目录位置为无显式阅读位置的普通目录和旧分组生成 `readingOrder`。声明了 `chapterOrder` 就用该方向。旧源未声明时，同组有效卷／话号的相邻变化只用于识别目录整体正反向，平局或没有证据时沿用源返回方向。每章保留在目录里的相对位置，话号缺失、重复或个别跳号均不会重排章节。已有显式阅读位置、替代版本或明确排除的条目遵守源合同。旧库合并数组、详情显示顺序和未完成的分页都不用于生成位置，已从新目录消失的旧章保留原页表和进度。
- 从作品入口开始阅读时，先恢复有效进度。没有进度时，单一阅读组已给出完整且不重复的位置，就按这些位置取第一个未读章节。多组、替代版本或缺少位置时沿既有来源方向及兼容规则选择，目录的显示排序不参与。

`source_homepage_choices_v1` 扩展 MangaBz 的固定镜像：源仅在宿主声明后显示备用站设置；每站独立保存精确 origin 会话，语言键按域分别为 `mangabz_lang`、`xmanhua_lang`、`yymanhua_lang`，不跨域转移会话或其他 Cookie。旧宿主及未选镜像保原请求与默认。

### 书源登录

有包声明的源明确返回 `auth_required` 时，宿主在打开该源时显示统一的登录提示和登录按钮。源声明登录方式、官方入口和字段标签，宿主负责账号表单或网页跳转、取消和返回。仅在部分作品需要登录的源可在受限操作返回同一状态，公开入口照常工作。无登录声明的旧源保留原网页验证入口。

`source_authentication_v1` 由Host公共入口消费包声明 `authentication`。`kind:"credentials"` 要求精确HTTPS `loginUrl`、`credentialStorage:"private"|"memory"`，可给 `usernameLabel/passwordLabel`。表单复用公共Modal/输入/按钮，显示真实HTTPS域与账号材料保存用途；private表示源依原协议将账号密码与token安全存入本源Asset以续登录，memory表示账号密码仅本次输入。凭据不属于普通settings、备份或诊断。`kind:"web"` 不带原生凭据保存声明，登录origin必须在包明确的 `webSessionOrigins`；复用既有Web会话、实际UA与显式完成授权。

三个可选导出由SDK独立 `koma_source_authentication_exports!` 添加，不改变旧源宏。`get_authentication` 是0网络元数据操作，接收本源settings与公开settingObservations，成功返回 `data:{authentication:descriptor,authenticated:boolean}`。credentials的descriptor须与包完整一致；web可按同设置/安装快照返回当前镜像实际loginUrl，仅接受同kind和包已声明精确HTTPSorigin，未声明新域明确提示更新源/选择支持镜像，不改到默认别站、不以正则扩大授权。`authenticate/logout` 返回 `data.authenticated:true/false`，不得返回token或原私有响应。

`source_web_token_v1` 供登录后由官网网页存放访问令牌的书源显式使用。包的 `authentication.webToken` 声明 `version:1`、单个 `storageKey`、精确 `apiOrigin`、只读 `verifyPath` 和 `verifyIdentityPath`。用户在原网页登录入口点完成后，宿主只从已声明的 HTTPS 顶层页面读取该键，通过同站 API 确认账户及令牌有效期，然后提交到本源私密会话。允许同一 origin 或同域的 `www` 与 `api` 配对。

当前源调用使用私有 RPC `op:"web_token"` 获取会话状态和当前代标识；空会话或过期仍可按源的游客路径处理。无正文 GET 可用 `webTokenGeneration` 请求宿主仅向声明的 API origin 注入 Bearer，禁止重定向；401 只撤销实际发出该请求的一代，403 保留为服务端的权限结果。会话替换或断开后不得发布旧代的成功结果。可选的 `imageKeyDerivation:"sha512_cbc"` 仅向本次 `get_image_request` 提供 SHA-512 派生的解包参数，作品页表、图片 URL、普通设置、备份和日志均不携带原始令牌。

`source_native_cookie_session_v1` 允许原生表单和账号请求使用所选站点的私有 Cookie。凭据声明可同时增加 `loginUrls`（最多 8 个精确 HTTPS URL，每个 origin 一项，包含包内默认 `loginUrl`）和 `sessionCookieNames`（最多 16 个 ASCII 名称）。`get_authentication` 可从该列表选当前 `loginUrl`，其余声明逐项相同。Host 在读取状态后显示实际域，并只给所选 origin 发放此次凭据授权；设置变化或取消仍使原授权失效。旧凭据声明与网页会话沿用原合同。

源在相关 HTTP 请求传 `nativeSession:true`。Host 要求已安装包、当前调用、声明的精确 HTTPS origin 和白名单内的请求 Cookie，每次只发一跳。此请求不读写网页 Cookie，也不进入网页验证结果交接。正常 HTTP 响应附 `sessionSetCookies` 数组，只返回声明名称的同域或 host-only `Set-Cookie`，保留每条的 Path、Expires 等属性，不按逗号拆分。取消、安装变化和跳转不交付 Cookie。源负责遵守有效期及路径，按 origin 隔离会话，官网确认身份后才通过私有 Asset 提交新代；账号材料、会话和 CDN 图片凭证不得混入公开结果。依赖此能力的包最低 App 版本为 1.2.1。

该能力同时提供同源安装范围的私有 RPC `op:"peek"`。返回当前已提交的 `{ok:true,state:"ready",value,versionTag,nowMs}`，无值返回 `{ok:true,state:"empty"}`。它不认领初始化、不等待登录或续期提交，游客和已登录的普通图片请求都可以直接读取当前代。只有实际登录、续期和退出需要认领写入。

显式点击Host表单后，认证事务只将随机grant引用放入可信Native HTTP context，WASM请求args不含账号密码。同次本源/安装/callId经 `private_session` 的 `credential_input` 读取 `{ok:true,credentials:{username,password}}`；只有authenticate可读，探测/普通call/异源/旧包/已取消事务均不能读。HTTP每跳限该grant的精确APIorigin；取消、换包、设置/页面过期后不发新请求、不提交Asset新代、不重试原操作。源沿真实协议处理签名、登录、token与同代401刷新，Host不把任意401/403或challenge推为登录、不自动授权Cookie。成功后在原query/filter/作品/章节仍有效且页面可见时只重试原操作一次，取消保原错误；旧无descriptor包沿原WebChallenge路径。

鸿蒙密码保险箱覆盖书源页时保留原半模态和输入，离开书源路由时关闭。API 26 起，空白表单首次聚焦向系统提供当前登录 origin 和两个字段，同一输入只发一次请求。只将系统确认的结果填回仍有效的空白表单。仅书源确认登录成功后向系统请求保存本次提交的账号密码；显式保存回执到达后再清空表单。密码保险箱负责回填和保存确认，和源的私有会话独立。

支持 `source_interaction_resume_v1` 的前台源内搜索可以在 `auth_required` 或 `challenge_required` 的 `error.interactionState` 提供一个 1–128 字符的源内处理标记，字符限字母、数字、下划线、点、冒号和连字符。App 在现有登录或验证流程确认完成后，原查询、原筛选和原搜索页的重调收到 `hostHints.interactionResume:{kind,state}`。宿主根据原交互填入 `kind`（`authentication` 或 `verification`），原样带回 `state`。标记只随这次重调，后续分页、取消、切换来源、安装或设置变更都不能收到它。标记从不被当作会话凭据，源按当前会话和网站响应判断是否能继续。旧宿主沿用原操作重试，未声明该特性的入口仍按原合同。

账号材料与 token 复用 `SourcePrivateSessionHost` 原 Asset 分块、版本、发布与回滚职责。网页授权和私有值沿用上文的存储身份，所有 HTTP、登录授权和验证完成仍核对当前安装身份。已有包的旧存储身份可直接接续，避免重新写入凭据。退出只作用本源当前会话，不全局清 Cookie 或 Asset。

`source_private_session_replace_v1` 为原 `begin` 增加可选 `replaceVersionTag`：在同一有效源/安装/call内只认领当前仍匹配的旧代，旧值和索引保留到成功commit；提交前再次核对代际，旧代变化返回stale_version。取消、abort、分块/索引写失败保留旧代。旧无字段begin/invalidate合同不变；显式authenticate不得先invalidate，须以此替换，logout仍可明确invalidate。它不增加账号输入权，也不另建缓存命名空间。

`source_private_session_process_v1` 增加私有RPC `op:"process_scope"`，在同一真实call/current授权下返回 `{ok:true,processTag}`。tag为Host进程随机值，本进程稳定、重启重建，不是设备标识；不读写Asset、不加入原clock响应、不记录tag。源可据它实现参考的per-App-launch镜像刷新；`get_authentication/get_settings` 仍不能借此发网络。

### 必需正文解码

包 `requiredImageDecodes:["jm_stripes_v1"]` 是能力声明，经标准metadata/build/导入/Registry保留，去重且未知kind拒绝。声明源在旧raw缓存sidecar未知时必须重新发现image descriptor，错误不回原乱码；普通旧源cache命中不增加网页依赖，不按sourceId猜需要解码。

`source_required_image_decode_jm_stripes_v1` 支持 `Page.image.requiredImageDecode:{kind:"jm_stripes_v1",rows:N}` 与 `get_image_request` 成功 `data.requiredImageDecode`。N为2至20的偶数；两处都有时必须一致，不可覆写/丢弃冲突。URI/PID保持原样。Host对实际字节先处理gzip，GIF87a/GIF89a魔数透传保动画，其他图按固定参考纵条带还原；不按URL扩展判断。原wire缓存保留，canonical派生按安装/页身份/算法缓存，在气泡、裁边与其它可选插件之前执行，不受“关闭图片处理”控制，封面不参与。下载写canonical并记录已解码标记，离线/导出不能二次解扰。非法hint、解码/格式/资源错误保持失败，不以原乱码冒可读图。

### 书源随包图片还原 v1

源包声明 `requiredImageDecodes: ["wasm_image_v1"]`、支持该能力的 `minAppVersion` 和完整 `wasmSha256`。在 `source.wasm` 中增加唯一的 `koma.image-processor.v1` 自定义段，段内容为独立处理器的完整 WASM。整份 `source.wasm` 由现有安装、分享和备份恢复流程验证并保留。一个声明使用一种还原合同，已发布的 `jm_stripes_v1` 包可继续使用原字段和缓存。

仅当请求的 `hostFeatures` 含 `source_required_image_decode_wasm_v1` 时，源在 `get_image_request` 对需要还原的正文或封面输出 `data.requiredImageDecode`。例如 `{"kind":"wasm_image_v1","bytes":"{}","pixels":"{\"order\":[1,0]}"}`。`bytes` 与 `pixels` 二者择一或同时提供，分别在解码前与解码后执行。每项是非空、最多 64 KiB 的 UTF-8 配置，宿主原样传入 `config_read`。省略的阶段跳过，普通图片返回原请求描述。配置只携带还原参数，放在实际图片请求中，避免把逐图材料写入章页快照。缺少能力时，源返回不兼容错误。此能力要求源为封面和正文提供完整的 `get_image_request` 请求描述，包含相应 HTTP 请求头。

执行沿用 [图片插件 ABI](image-processing-plugin-abi.md) 的导出、像素格式、沙箱和执行限制。字节阶段 `width()` 与 `height()` 均返回 0，允许使用 `bytes_len() -> i32`、`bytes_read(offset, ptr, length) -> i32`、`bytes_output_create(length) -> i32`、`bytes_output_write(ptr, length) -> i32`。输入按偏移只读，输出先声明总长，再按顺序写入。成功创建返回 0，读写返回字节数，失败返回 -1。字节输入与输出各限 128 MiB。像素阶段仅接受单帧图片，以无损 PNG 编码完整输出。两个阶段都必须返回 1 且写完输出。宿主验证实际图片格式并解码检查尺寸。字节阶段的有效编码直接保留，动画由原格式继续承载。

还原优先于气泡、裁切和可选插件。阅读、预载和封面共享当前安装与设置下的还原缓存，手动刷新重新请求描述和原响应，成功后才发布缓存。下载调用相同还原服务并保存已还原图片，离线和导出不再运行处理器。处理器仅访问当前输入和配置，输出不完整、格式无效、超时或源安装发生变化时本次加载失败。

网页登录可声明 `authentication.userAgent`，仅web类型、1至1024字符且拒HTTP控制字符；动态get_authentication必须原样回送包内值。仅该显式登录begin使用它，WebView实际加载和完成时UA必须一致，后续HTTP沿已授权会话UA。无字段包保原默认路径，不改变全局或普通源请求头。


## 可组合数据通道 v1（本地候选）

本节是包含本期实现的构建合同，未随已发布 App 自动生效。基础 import、源操作信封和 ABI 不变；源逐项查询 `hostFeatures`，可选增强缺能力时走旧路径。核心路径依赖新能力的包须等相应 App 正式版本明确后再声明最低版本和发布。

- `source_http_headers_v1`：请求 `responseMetadata.headers:true`，返回 `headers`，名称小写、值为字符串数组，保留多值，不把 Set-Cookie 交给源。它仍由原授权会话或源 Cookie jar 接收。头部总字符数最多 65536。
- `source_http_request_bytes_v1`：`requestBytes` 为严格 Base64，解码后最多 1 MiB，作为 POST/PUT/PATCH 的真实二进制正文发出，不能同时带旧正文。也可用 requestBodyRef 引用本次调用的 BodyRef（native最大128 MiB，WebHTTP上传统一最多1 MiB），宿主在发送阶段读取为二进制；这不是流式上传，两种形式互斥。旧 `bodyBase64` 字段的历史文本语义保持不变。跳转受原准入，二进制请求额外拒绝跨 origin 跳转；303 及 POST 301/302 转 GET 时清掉正文。
- `source_http_body_v1`：`responseKind:"bodyRef"` 返回 `bodyRef:{id,length}`，取代内联 bodyBase64。成功和 HTTP 错误正文都可读取，HTTP 状态不自动变成传输失败。使用原请求/限速/会话/跳转/取消检查，普通二进制请求已有的不兼容传输组合仍拒绝。
- `source_body_v1`：复用 `http_request` 调本地 RPC：`{type:"source_body",version:1,op,...}`。create 返回 bodyRef；read 使用 id/offset/length，返回 base64；write 使用 id/offset/base64，返回 ok；close 使用 id。读块最大 65536 字节，写块同限；offset 是文件中的字节位置，允许在已存在范围内覆盖或在末尾追加，禁止空洞。
- 数据限制由调用的 `hostCapabilities:{version:1,body:{chunkBytes,maxBytes,callBytes,callObjects},http:{inlineBytes,requestBytes}}` 告知，缺失表示未知，不能推断支持。当前单体 128 MiB、单调用 256 MiB/16 项、进程 512 MiB/64 项。引用仅属于创建它的源/安装/调用，不可序列化保存给后一次调用。进程启动复用专属目录并清理上次遗留的暂存文件；初始化失败时保持普通 App 路径可用，并从该次 Worker 的能力中省略数据和图片引用能力。
- `source_image_body_v1`：成功 `get_image_request` 可返回 `data:{image:{kind:"body",ref:id}}`，内容必须是已完成处理的标准可解码图片。不能和 requiredImageDecode 同用。宿主在调用退役前交接所有权，消费方只能认领一次，且核对当前安装身份；未认领 60 秒自动删除。源产物缓存绑定实际包和设置身份，阅读、预载、封面和下载复用现有图片缓存/解码/离线路径。旧 URL 描述及必需还原处理器继续按原合同执行。

源 SDK：`http::RequestSpec::get(url).encode(buffer)` 生成原拦截器可接收的 Request；设置 method/headers/body/response/session 后仍走 `Client.send`。`Response.body_ref()` 返回不含路径的 BodyRef；其 read/write/close 接受调用方缓冲，`image_result` 生成图片 data。`runtime::Context::from_request` 查询 feature/limit；`session::PrivateSession` 封装既有私有会话事务。加解密、压缩、签名与格式解释由源内库实现，宿主不增加站点分支。

验证用哔哩漫画编译特性 `host-body-example` 显式把真实页图经 HTTP 引用、源内分块复制、输出引用交给普通图片消费者；默认公开构建关闭该特性，保留普通图片直连。验证码增强优先使用引用通道，缺能力保留已发布的小字节正文路径。

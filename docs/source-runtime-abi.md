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

是否允许某项操作仍由当前源声明、真实导出和准入共同决定；原生有映射不代表所有源实现。测试专用导出不构成产品能力。响应沿 NativeSourceRuntime 的 ok/operation/data/error/reasonCode/hostHints 合同，由服务及实际 DTO 消费者校验，不凭字段存在冒调用通过。

## 宿主边界

- WASM 只使用受控 host imports；当前原生注册表为 wasm_runtime_adapter.cpp 的 g_komaHostSymbols，HTTP/HTML 行为分别由 http_host 与 html_host 实现。不能从开发 runner 导入推定 App 提供同名能力。
- 包、请求及响应大小、执行/网络期限和取消按当前 importer、service 与 native 常量执行，本文不复制易漂移的数值。未声明能力、无效身份和不支持操作不能默认放行。
- 源设置须有真实 schema 及实际消费。schema 空/失败不显示空入口，也不污染已保存设置的全局状态；存储读取失败保留有效入口并报告具体阶段，不使用“设置验证失败”泛化提示。cookies、userId、token 不因存在导出而开放普通明文持久。
- SourceSettingsStore 复用本进程最近提交的私有快照，调用方仅取得副本；单源请求及管理页统计不重复读盘解析全文件。写入成功才发布快照和 revision，失败保留旧值；路径切换、原文件事务回滚及备份回滚由同一 owner 失效，不以缓存掩盖尚未成功读取的错误。
- 图像请求描述进入原有下载/缓存通道；源不直接接管文件、账户、图像处理、Reader 进度或共享 Kit。

## 宿主特性

`get_settings`、`get_chapters` 与 `get_pages` 请求顶层由宿主加入 `hostFeatures`；文字页的 `get_image_request` 同样携带声明。当前支持 `text_page_image_v1`、`source_rate_limit_v1`、`text_page_image_zaimanhua_comments_v1`、`source_text_page_request_v1`、`source_setting_observations_v1` 和 `source_chapter_exclusions_v1`；源必须按特性声明再展示、消费依赖项，旧 App 没有声明时保持原输出。特性不是网络权限或任意 HTML 执行许可。

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
- chapterOrder 保留源已核的 oldest_first/newest_first，未声明时保持宿主兼容准入；ReaderChapterSequence 负责最早未读选择，已有进度及显式章节优先。不得合成章节身份或猜话数改变顺序。

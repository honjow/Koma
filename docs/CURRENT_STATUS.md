# Koma 当前状态、缺口与执行基线

## 本轮反馈登记与稳定修复顺序（2026-10-23 / feedback_registry）

- 沿用现有 `docs/qa/koma-production-progress.html`、`scripts/serve-reader-progress.py` 和本文件唯一 snapshot，未另建网页或清单。用户每次新报问题先由 feedback_registry 登记：缺陷、用户验证观察与原因推测分开；登记不抢占Root正在处理的修复。
- 本批14项已按原会话JSONL核首报时间；当前最高优先队列包含连续滚动性能、全屏共同生命周期与阅读正确性；P1还包含设置/模糊串态/源失败，P2为渐进加载/标题/章节选择器。Root按可行依赖推进当前主线：全屏native完成事件未明确时先修独立的连续滚动黑条/方向/章选择器，登记owner仅在新报告具有已证前置依赖或更高严重性时提出调整；无依赖按严重性及原排队顺序推进。
- 开始处理时间/实际工时没有可核分段记录的项写null，页面明确未知；绝不把从提出到现在的经过时间当工时。设置与预设仅登记已有具名197验收，其余保留待审/待实机；旧验收与新反例分别保留，不全局盖章。
- NextE新版不流畅、旧阅读器顺滑为用户验证反馈；“每帧重绘/后台计算”“Koma章节工作叠加”“同底层原因”为待证推测，不写成根因。下一未完成动作及owner见原snapshot各项，不依赖自动唤醒提示词重新猜任务。

## 根Tab标题栏模糊串态（2026-10-23 / Root，本轮新反馈）

- 用户实际反馈：书架中段有渐变模糊→设置回顶部透明→切回书架继承透明。只恢复各Tab对应实际滚动位置的原HDS渐变状态，不换模糊/材料效果。已追NextE原主仓4aada3bf中homeTabScrollers/titleScroller和NextN当前rootTabScrollers绑定；Koma原根Navigation无bindToScrollable，各页Scroller又被私有持有，切Tab未切换标题滚动owner。当前Index已有首次章/搜索标题WIP保留。
- 限定5文件接线：根持有四个独立Scroller并传入各页原List/Grid；切Tab（含程序切换）绑定对应Scroller，页面和位置保持，secondary默认自有Scroller不变。修改前197连续原片root-tab-titlebar197-before-001已执行；本轮实现待构建/改后同场景及其他Tab交叉验证，不能据源码绑定宣布通过。
- 执行优先级按最新人类澄清：眼前已报缺陷先修完；系统测试方式整改用于后续验收，不抢占本批修复。全屏时机共同问题仍为第一优先，临时探针不进正式提交；不复活已关闭图标或PARKED_USER私库。

## 三App五入口窗口生命周期回归（2026-10-23 / Root，最高优先级）

- 用户本轮明确报告Koma普通入场及NextN系统默认入场仍先切全屏/状态栏再动画，要求共同管理五种入口，已修的NextE两路径及NextN新转场保持；这是最新最高优先事项，其他用户缺陷队列未取消。
- 已核共同ReaderSystemBarController只串行窗口调用，admitted由宿主提供；NextN 35867272为修重复进入初始化取消，在openReaderOverlay挂载前即设置readerDestinationVisible=true，同标志又参与readerWindowRootSettled/recordReaderPresentation放行，无自定义entry时缺真实入场完成约束。Koma uses routeActive/onShown gating；它是否覆盖实际native入场完成仍需原片核验，不据回调名字断言通过。
- Root已保留197 Koma当前8366071B/code3修复前普通Library继续Chibi2/8→Back连续录像：diagnostics/native-reader-entry197-before-001，尚待逐帧审实际时机。下一动作：核共同窗口准入/真实native完成信号，修共同边界及各宿主接线，不改入场几何/动画/返回设计、不用延时凑时机。NextN原禁止方案REJ-READER-001/002/004已核，返回先恢复源窗口的原职责保持。
- 当前Root占197有效租约ea36d31a，源owner占237；其他App禁止自行占用197。源漫画社017已亲审，由原owner继续237及精确CI。禁止哈希/工作树/清数据/私库复活保持。

## 全局搜索进入详情标题错误（2026-10-23 / Root，最新反馈）

- 用户实际报告从全局搜索进入漫画页标题栏显示“未命名漫画”，允许没有名称时去掉该占位。本轮范围：带入搜索结果已有title/cover/url；根标题优先详情加载后的同一路由真实名称，名称未知时留空，不改标题栏/菜单几何。
- 已追SearchPage.openResult现有WASM分支仅传ID/source；Index.mangaDetailTitle优先initialManga或本地书架，找不到直接fallback，异步详情名称也没有发布到根标题。对照现有Browse/书架路由和56f1bd0e的route-local chrome，不另建路由或跨页全局标题。修复前保留当前197设置验证状态，后继构建一起验证普通搜索→详情→返回与两个不同作品不串标题。

## 作品设置固定菜单（2026-10-23 / Root，最新人类纠正优先）

- 用户本轮明确要求：菜单选项保持固定；用说明提示与全局设置的差异；增加独立“恢复为全局设置”入口；纵向模式置灰动画选项；修改预设不收起半模态。此前摘要中的“全局/本书作用域切换、扩展所有偏好覆盖”方案撤销，不实施。
- 已追4e9e16b0引入的动态本书后缀/恢复菜单及ce627f4c设置父树。允许差异：模式/方向菜单恒为原4项/3项；去本书后缀；双页布局/配对、动画、宽图行恒在原顺序，仅按适用模式置灰；独立恢复行恒在，使用固定高度的说明显示模式/方向与全局一致或不同，没有差异时不可点。保留原窄覆盖（仅模式/方向）与会话列配对、其他偏好原语义，不迁移用户数据、不增加全局/本书选择。
- ReaderSettingsContent与三语已实施并构建，8373891B/code3 Release明确覆盖197；普通继续Chibi2/8连续四模式/独立恢复录像299帧与3sheet已亲看，固定行和四菜单保持，纵向动画真实Toggle disabled；恢复原全局纵向/从左到右，无本书覆盖。预设左右分区→Kindle→左右分区菜单保持四项、半模态未收起，关闭菜单后的行坐标均left91/top1296相同，三张原图已亲看。最初过早比较在菜单退出中断言失败，原JSON保留；修正等待MenuItem消失后记录，不据工具失败改产品。证据fixedsettings197-{installed,interaction,recording}-001；初次坐标精确比较另有1px物理取整差异，未当作整页重建。当前仍待本轮完整反馈提交，禁自行关闭整体队列。

## 目录排序与阅读设置跳变（2026-10-23 / Root，执行中）

- 最新人类又明确报告章节排序菜单完全无作用；阅读设置一次修改后整页重建、选项和位置跳变。此二项未完成，不能以先前局部结果盖过当前反例。当前197以用户最新描述核普通详情真实升降序与菜单条目动作，随后核共享设置一项选择→当前值/同页位置/异步保存；不擅自重设计菜单。
- 已读ChapterListSection、19ad9143（未知chapterNumber不得伪造）、ReaderSettingsContent/ConciseListRow与KomaReaderLabPage/偏好桥的完整相关父树。目录未知话数统一-1会使比较全0；编号有效目录需另看Native结果。设置仍在查实际重建边界，尚未写外观/交互候选；原样式限制保持，用户当前要求修正页面跳变及选择不稳定。

## 无历史的书架首次阅读选错最新话（2026-10-23 / Root，执行中）

- 最新人类实际反馈：只从源添加书架、未阅读，之后书架开始阅读会开最新一话。语义明确为无记录选第一话、已有进度续读、显式选章保选择，不改目录显示顺序或已有记录。
- 已查99683bdc在详情按最小chapterNumber/最早dateUpload选首章，但Root readerChapterIdForOpen仍sortedReaderChapters仅按保存的index，createReaderSessionConfigFromComic和Kit适配无章fallback也取chapters[0]。源原返回往往新到旧，保存index是原数组位置，并非章节时间；正沿全部真实入口及原续章合同核对，不能直接反转全部目录。具体用户源/书已留可选提问，不阻断通用修查；现有索引与错误信息WIP保留、继续合并验证。

## 包子漫画实际失败与错误信息（2026-10-23 / Root + 源owner，执行中）

- 最新人类反馈安装包子后普通Browse立即源运行失败source_runtime、重试无效，并明确要求优化错误信息；此答复授权对应错误说明，不改排布/样式。源owner先安全保存已开始的綜合口味，再查包子现013与原失败回执，不盲重试旧403。
- 原因已查BrowseViewModel.runtimeErrorMessage将真实error.code包成中文Error，再被safeSearchDiagnostic只按“源/runtime”粗化成source_runtime；原2edb554a/42a56efa日志又只留代码并在通用errorSummary把permission_denied等降成unclassified。当前修复保留结构化错误至Browse/源内搜索/全局搜索消费者，白名单分类映射为可读原因，仅提取可信HTTP状态，不原样显示服务端消息；日志保留操作、reason/error/status/kind与原起止关联。原请求/重试/超时/源业务保持，不把改善提示当包子可用性修复。
- 与索引两文件一并做针对性检查、Release构建和197验收；实际包子根因以原回执和源owner核查为准。

## 首次索引渐进显示（2026-10-23 / Root，执行中）

- 最新人类反馈首次设置远端源地址加载更新太久，明确要求异步逐个刷新出现，避免长空白；这项优先于197普通Shared自动/音量补验，源owner继续237具名源正文。
- 已查096730b1原图标身份/校验及7ace468b每批四并发决定：后者仍在fetchIndex内等待所有图标才返回，页面await后才赋indexEntries，因此一张慢图拖住全表。原理由（必需图标声明/路径校验、按ID/版本缓存、图片校验、失败占位）均保留；本次只拆JSON与图标等待，列表一经有效即显示且可操作，后台最多四路逐图补入、保持名称排序，检查更新不等待图标。地址变化/离页作废旧回写，不清缓存或重开图标素材任务，尺寸/圆角/文字/持久格式保持。
- 正在修改SourceIndexService与SourcePackageManagerPage两个文件；下一动作是实际生产方法异步次序/失败/并发/过期回调检查，Release构建、197普通入口验证及范围提交同步。现有237 PGR677已返正文和自然返回证据，Root亲审中；后继綜合口味由原owner续验。

## 预发布后功能与源双线推进（2026-10-23 / Root）

- 最新人类明确允许继续功能测试、源开发和测试，并会在实际使用中不定期反馈；本轮恢复双线执行，不把上一轮“发布完成/当前条件依赖”当作整个后续开发停止。App Root使用197，原source_delivery_cleanup使用237；原私库PARKED_USER、禁哈希、禁工作树/源码副本和未经批准禁样式变更继续有效。
- App下一动作：构建并197覆盖安装0.1.2-pre/code3签名Release，保原用户数据，验刚改宿主版本比较的真实重载/普通源入口与远程索引消费者。此项重开依据为4bf22c66修改最低版本检查及发布元数据，既有0.1.1设备结果不能替代；不从零重跑全App或源正文。根源码无新改动，沿既有diagnostics197场景manifest与原设备签名，不跑会计算产物哈希的包装。
- 源下一动作/owner：原source_delivery_cleanup先从既有记录选一个尚未完成普通正文验证、可安全匿名访问的既有生产源，回报具体边界后接目录→首张真实叙事正文→自然返回/进度；发现真故障再原仓修复。源README按该源就地记录，Koma工作单仅Root写。旧拒绝端点/账户/缓存和已冻结样本保持，不复活图标或私库、不从85源起新全量矩阵。

## 0.1.2-pre：预发布已完成（2026-10-23 / Root）

- 当前人类已明确接受删除开场句后的两条功能概述及测试不足说明，并授权“提交推送并打 v0.1.2-pre tag，然后跟进 CI 和预发布结果”。日志确认门槛已满足；本轮已按该精确版本提交/推送/打tag并核CI与Release，正文保持已确认原文。
- 源码版本入口AppScope/root/entry同步0.1.2-pre，versionCode由2递增3；已确认正文为`changelog/v0.1.2.md`。原0.1.1未发布草稿保持，日志索引已指向本次正文。新版CI Release已构建并发布；设备仍是前一轮0.1.1/code2包，不能称新版已实机安装。
- 版本相关必要兼容：096730b1引入的宿主最低版本检查只认纯数字，直接改-pre会误拒源包安装/恢复/冷重载/索引安装。仅在共用宿主检查中识别当前-pre后缀；按版本先后允许满足较低数字最低版本，不满足同数字正式版或更高最低版本。源包最低版本字段仍严格三段数字，不放宽原格式、不改源/UI/缓存/持久合同。生产方法24例检查通过，覆盖旧缺陷复现、预发布/正式版本先后、非法值与bundle读取失败；源包最低版本格式保持不变，未新增脚本。
- `python3 scripts/check_release_notes.py --tag v0.1.2-pre`及diff检查通过，7文件范围已审并提交4bf22c66b7a00d5dfa804fa7c4fdd1a64ff34903，master推送成功。本笔分支CI39828487326与tag CI39829003869均completed/success，后者Release构建及Publish tagged Release两job均通过。注释tag v0.1.2-pre已推送，远端peeled目标实读同一4bf22c66。GitHub https://github.com/honjow/Koma/releases/tag/v0.1.2-pre 实读prerelease=true/draft=false，发布时间2026-10-23 02:13:41（Asia/Shanghai），body与批准日志全文一致。


- 两公开附件均HTTP200且uploaded：`Koma_0.1.2-pre_ohos-release-unsigned.hap` 8252181B、`build-manifest.json` 327B。Root在内存读取manifest与HAP module.json，确认commit4bf22c66、0.1.2-pre/code3/com.honjow.koma/release/debug=false、signed=false及两必需arm64库存在；未计算哈希、未落下载副本。当前发布任务已完成，tag未移动；owner Root只收尾这份记录及远端同步，不把CI或包检查扩大为新版设备验收。四私库搁置与其余具体条件项保持。

## 自研 K 应用图标与首屏 Logo（2026-10-23 / Root）

- 本轮原始用户要求：采用已选方案替换原 V；范围包含应用图标与首屏 Logo。允许差异为已选 B 比例的三层翻页式 K、水平收口、中央细连接，以及浅色首屏提亮至 `#37A48B`；深色首屏采用 `#5CC8A8`。不增加磨砂，不改原 emerald 背景渐变或启动底色。
- 原入口仍为 `app_icon_layered` / `startup_foreground`。替换 base 图标前景与首屏 PNG，并用同名 `dark/media` 资源接入深色首屏；可编辑 SVG 母版保存在 `assets/branding/`。研究与原件保留于忽略目录 `.hermes-artifacts/20261022-k-icon-study/`。
- 首轮197实机冷启动显示了K，用户指出首屏过小，原0.60缩放不再沿用。该值来自研究稿对旧V可见高度的匹配，并非本次实机认可；按当前反馈只把浅深启动资源缩放改为1.00（主体约原1.67倍），路径、颜色、中心和桌面图标均保持。
- 量化对照：原V在1024画布内约354×315，首轮K为232×316；只对齐高度使宽度小了约三分之一。当前K为386×524。修改的是资源内主体占比，`startWindowIcon`及窗口显示参数未改。
- 放大版Release构建成功，0.1.1/code2/debug=false，固定包`build-startup-large/0.1.1-2-d54fbc42/Koma-0.1.1-2-d54fbc42-default-release-signed.hap`为8354908B，197明确覆盖安装成功。桌面K原图已亲看；普通图标冷启动连续录像136帧/4张联系表及第60帧原图已亲看，浅色首屏为放大K。最终普通书架与Chibi第2页25%保持。浅深资源同步同尺寸并已编译，深色启动未做实机切换，不冒称通过。
- 原emerald背景和分层引用逐字节保持。原系统120000ms/无override已恢复并读回AWAKE，本轮scratch清理、租约2c024806已释放。原件、结果及固定包沿上述忽略目录；本轮资源已范围提交051f3b17并随efacb2f1同步master；精确CI39819554203/head=efacb2f15121cdaa510dd887448c1fd9e49b289e已completed/success，固定Kit、版本日志/三语检查、Release编译、HAP检查及上传通过，tag发布任务skipped。图标阶段签名包固定在`.hermes-artifacts/20261022-k-icon-study/build-startup-large/0.1.1-2-d54fbc42/Koma-0.1.1-2-d54fbc42-default-release-signed.hap`，当前日用包以后继响应诊断段为准；本轮只读包内module.json复核com.honjow.koma/0.1.1/code2/debug=false及8354908B，不重建、不重装、不重新计算摘要。

## SciTechVista237首图与响应诊断：具名范围已交付（2026-10-23 / Root）

- 原source owner已普通导入011，61→62仅新增本源；首屏5作及首篇1章成立，正文约61秒后ReaderImage报2300028并显示失败/重试，未点击重试。Root亲看终态、读回原始错误及恢复回执；CMYK解码/颜色、实际平台容量仍未证。HEAD在本机仅证200/28793918B/1.56s响应，不代替237正文；四私库及旧受限端点不重取。
- 修改依据：本次失败缺“是否收到响应头/声明长度”。42a56efa的终态日志只保平台码；09cc9e2f以来普通request/60000ms读取/30000ms连接保持。官方API23说明50MB与参数表5MiB存在差异，不能据旧表断定本设备容量问题；官方普通request不发送流式接收进度，不假记0。Root只给ReaderPageSourceAdapter.downloadReaderRemoteBytes的现有日志补响应到达/声明长度，成功保实际字节、失败写unknown，原请求/缓存/期限/容量/UI保持。9项诊断检查通过，范围提交3a75c9a9已同步master；精确CI39824362291/head=3a75c9a969674dac6de42248e5f16fb810ccc48f为completed/success。


- 后继237同首篇普通历史重开一次：同一操作日志01:39:12.994开始，响应声明28793918B，17.145秒后HTTP200且实收28793918B；Root亲看完整四格繁中正文1/1，无加载层。自然Back后同作品pageIndex=0/totalPages=1/completed=true。只关闭此28.8MB首图普通传输/Native显示/返回保存缺口，不外推色彩校准、其余作品、下载/cold或首轮超时原因已修复。237已恢复原Browse喵趣组、62项登记、10000ms/AWAKE，scratch清理且释租。原件沿`category-membership/scitech011-headerdiag237-{terminal,return,final-restored,anchor-restored}-001`；源README后继记录fb5245d已SSH同步，源仓干净。
- 197已明确覆盖安装同代码签名Release0.1.1/code2/debug=false/8361988B并启动，bm版本读回相符；Root亲看原书架Chibi第2页25%及原首三书。装机前后library与reader完整JSON内容一致，未开章/升级源。原OverrideTimeout10000ms与AWAKE已读回，性能模式未动，两本人scratch已核不存在，9c4de24d租约已released。原件沿197 `diagnostics/image-response197-{gate,unlock,installed,restored}-001`；收尾manifest首轮含不支持的allowFailure键，被校验拒绝且未执行设备动作，移除该键后正常校验/执行。所有回执哈希关闭。
- 当前固定日用签名包为`.hermes-artifacts/release/0.1.1-2-3a75c9a9/Koma-0.1.1-2-3a75c9a9-default-release-signed.hap`，8361988B。直接固定已安装产物、核包内版本/buildMode/debug，未重建或计算摘要；取代旧图标阶段固定包作为当前交付入口。本轮没有打tag或正式发布Release。

## Protectors237首篇普通正文：具名路径通过（2026-10-23 / 源owner + Root）

- 现装0.1.0普通Browse→《具现灵小课堂》（moment185451606127414743）→开始阅读，完整中文四格原图1/1及自然返回详情的继续第1/1页均由Root亲看；reader.json精确绑定该作品/章/pageIndex0/totalPages1/completed=true。只闭首篇Native读图与返回，原日志列表阶段664126B命中不能冒正文缓存命中或首次网络成功；下载/cold及其余四篇保持未验。
- 原件沿237的`category-membership/protectors010-first-body237-{reader,return,restore-browse,final-restored}-001`。最终Browse喵趣组整图已亲看，回执completed/哈希关闭、AWAKE/原10000ms及两本人scratch不存在均已独立核；源owner已释放caec12fe。无App/源代码、资源或包更新；本轮正常新增读态保留，不冒全库逐项不变。

## 漫画屋197详情及网页入口：当前具名路径通过（2026-10-23 / Root）

- 沿原书架搜索→漫画屋《斗破苍穹》仅请求一次，现装013的get_manga/get_chapters均HTTP200，业务终态completed（1236ms/401ms）；真实完整封面、670/670章及原第4/36页已亲看。旧197失败没有同步原码，仍不能倒推历史原因；本轮没有猜改源码或重新验证237成功路径。
- 原WebView入口显示同一作品封面、作者及章节区；Back仍670章/4页。外部浏览器前台由原始布局绑定com.huawei.hmos.browser，同站同作品可见；只用系统QuickBack返回原详情，未点风险提示或广告。仅接受这两个入口与返回，不冒源正文/全站可用。
- 清空本次查询、保留实际原书架搜索范围；稳定书架Chibi第2页25%/最近阅读已亲看。安装前后及最终library与reader两整份文件逐字相同；本轮首次读回的原OverrideTimeout为10000ms，已恢复并读回AWAKE，性能模式未动、本人scratch已清，c140ef36租约已释放。原件沿`diagnostics/manhuawu-detail197-{gate,unlock,result,restored}-001`；首返回书架帧仍在转场，以restored稳定整图为准。哈希关闭。

## 书架过期封面限定修复：已交付（2026-10-23 / Root）

- 日志暴露的《猎行者》410反例已定位：197书架保留10月12日到期的封面签名；普通get_manga已返回新地址，原详情实现只展示、不回写非空旧封面。237同路径缓存成功只作对照，不冒197旧410日志已绑定完整URL。
- 两文件限定修复：只在新get_manga成功且请求仍有效时，对同源同书的既有收藏回写非空HTTP(S)封面；克隆当前owner，仅变coverUri，沿既有事务保存及失败回灌。章节、进度、分类、updatedAt、排序、UI和请求合同保持。3项生产方法检查通过，含错误身份/空地址拒写及保存失败回灌；Release构建成功，0.1.1/code2/debug=false，已安装197的签名产物为`entry/build/default/outputs/default/entry-default-signed.hap`，8395781B。
- 197普通详情显示完整封面、458章、继续第一话第2/16页；自然Back书架封面正常。Home→force-stop→普通启动，PID60343→空→63455，封面仍正常、Chibi第2页25%保持。起末library仅`comics[52].coverUri`变化，冷启动后与详情保存结果逐字一致，reader整份内容与安装前相同。Root亲看详情、返回书架及cold三原图；只关闭这条具名路径，不外推其他作品/源。
- 原件沿`diagnostics/hunter-cover197-{detail,shelf,cold,restored}-001`。恢复无override/系统120000ms且AWAKE读回，性能模式未动，设备scratch已清；租约20261022-161510-2c2aec94已释放。接续第一条PowerManager命令只返回帮助，已保留并以正确-s读回补正后才操作；全程哈希关闭。五文件已审并范围提交1cc7b020、SSH同步master；精确CI39814009255/head=1cc7b0204aca6757142d2822accbc56064495e1f已completed/success，固定Kit、版本日志/三语检查、Release编译、产物检查/上传均通过。分支事件的tag发布任务skipped，没有打tag。

## 业务日志补齐与版本发布日志：已交付（2026-10-22 / Root）

- 已完成实现：原42文件/258处console warning/error接入脱敏持久日志；源、搜索、图片、下载和持久化补操作号、起止/耗时/终态、数量、真实平台码及脱敏代码栈。操作号含本次运行临时前缀，失败终态自身保留上下文；不记录书名、正文、凭据或书章ID，不计算哈希，不改UI。
- 普通入口补漏：197首轮只看到HTTP日志，核实注册请求服务并非所有业务消费者。已在调用方runtime接入普通Browse/搜索、详情、章节目录/页列表和图片描述的既有TaskPool派发；原任务、参数、返回及异常对象保持。终态已实测DM5 get_manga/get_chapters和漫画1234 get_image_request起止落盘，原并发/超时策略保持。
- 197最终签名Release0.1.1/code2/8396778B/debug=false已覆盖安装。启动版本/型号/API及真实图片HTTP410、平台码2300007被记录；分享面板实际显示TXT，读回3285B/26行，包含上述起止与耗时、不含书名/地址/请求内容。证据沿既有diagnostics/coverage-{final-installed,ordinary-final,share,restored}-001；Root亲看恢复书架，Chibi第2页25%保持。系统120000ms/无override已读回，性能模式未动，499eeb17已释租。Kavita码来自既有启动同步，不是重启私库验收；四私库仍PARKED_USER。
- 验证：8项针对性日志/分类检查、Release编译、三语、diff检查通过。版本检查8组正反例及真实YAML解析通过。未制造磁盘满或批量新下载的实机故障，不把主机替身检查冒作全部原生故障验收。现存《猎行者》封面请求410已被日志准确暴露，本批不擅改源或清缓存。
- 版本日志：首份changelog/v0.1.1.md及维护说明已完成；根/entry包元数据对齐AppScope。CI核对tag/版本/产物元数据与对应日志，Release使用bodyFile正文；pre结尾仍为prerelease且不占latest。本轮不打tag，故不冒实际tag发布通过。
- 日志代码42a56efa与版本日志/发布校验4ce9ce2a已SSH同步master（22端口连续关闭后，经同一身份443成功；未改永久配置）。精确CI39807295416/head=4ce9ce2a已completed/success，版本说明校验、固定Kit检出、Release编译、HAP检查与上传均通过；分支事件的发布任务skipped，未打tag。当前两项交付关闭；设备已恢复并释租，无源代理在执行。四私库仍按人类决定搁置，不自主复活旧测试。

## 日志与预发布 CI：已交付（2026-10-22 / Root）

- 按当前人类要求参考NextE：统一脱敏后写HiLog/500条内存缓冲/持久文件；本地最多12份、14天、总2MB，单份512KB轮转；磁盘失败回退内存。关键生命周期、源请求、下载、备份恢复和阅读故障已接入，不记录书名、请求正文、凭据、私有地址或书/章ID，不引入哈希。
- 普通入口为“设置→关于→诊断日志”：开关和级别持久化、时间标记、历史日志、分享及保存TXT；沿用原设置父树/行组件，三语已齐。代码eb160c0a已SSH推送master，精确CI39801582422为success；Release构建、HAP检查与上传均通过。
- CI增加所有tag触发；仅endsWith(ref_name, 'pre')标记prerelease且不占latest，其他tag正式发布。真实workflow解析及5组后缀用例通过；本次为分支事件，发布任务实际skipped，没有打tag或实际发布新版本。
- 5项针对性运行检查、三语及diff检查通过。原return_to_detail测试曾引用已删除的readerHostActions并实际0/2失败；2026-10-23已按7cb4d41c迁移记录改用当前固定Kit真实ReaderHostActions，现4项通过（有效位置分发、过期/异章/错动作拒绝、loading/null会话拒绝、普通入口与Lab宿主路由边界）。仅修既有检查，不改产品迁就测试，不新增设备通过结论。
- 最终签名Release为0.1.1/code2/8375382B/debug=false，197明确覆盖安装并force-stop冷启动；关闭/WARN保持、启动0条及历史日志保留已亲看，之后恢复开启/INFO。持久原日志432B含标记与保存成功事件；系统分享实际TXT已接收159B，含新标记。系统URI保存已执行，但两条shell下载路径未读到目标，不能冒称外部保存文件已直接读回。原件在忽略目录`user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/`。
- 最终书架Chibi第2页25%保持；按本轮首次实时读回恢复无override/系统120000ms，性能模式保持，自有截图scratch已清，535f0199已释租。两项已关闭；四私库仍PARKED_USER，旧具名通过路径不重跑。

## 实时执行位置（2026-10-21，当前唯一接续入口）

最后接续核对：2026-10-23，Root；最新人类决定：Komga/Kavita/OPDS/WebDAV 实际验收全部搁置，待用户日后明确重新提出；不得自主重启这些测试。用户最新目标为尽快交付初步日常可用版本：全部生产源远端自动编译、远程固定索引下载/更新、快速解决致命交付缺口并整理用户README。最新人类已明确图标任务完成并要求继续；恢复既有源可用性工作，不从旧图标OPEN另开检查矩阵拖住首版。

本轮同步边界：HComic012/漫画社015/漫画160012源3fda006、NN012固定白底源b1b8eb5均已同步master，精确CI39722753351/39724146846全85源构建/封包/原子发布success；固定latest/index85项及四源新包/图标已实际HTTP200。Koma配套尺寸兼容与本轮白底许可e9083692已同步master，CI39724219060成功。237浅深图标及197Release更新恢复见下；不以此宣称所有源正文可用。

| 执行线 / Owner | 当前事实与状态 | 下一未验证动作 / 恢复义务 |
| --- | --- | --- |
| App / Root / 197 | 普通Shared入口、日志/发布日志、封面与K图标按具名范围已交付；最新签名Release为3a75c9a9/0.1.1/code2/8361988B/debug=false，197已明确覆盖安装并启动，原书架Chibi第2页25%保持，library/reader装机前后内容一致。固定包见顶部响应诊断段。 | 精确CI39824362291/head=3a75c9a9已completed/success。197原10000ms/AWAKE、本人scratch清理及9c4de24d释租已核；性能模式保留。当前无App设备动作在运行；四私库PARKED_USER，自然失败/新增章/授权失效/首次全未命中与Tracker按实际条件保留，不造状态。 |
| 源 / source_delivery_cleanup + Root / 237 | 图标按最新人类决定关闭；85源远端编译/固定索引交付沿原精确CI结果冻结。Protectors首篇和SciTechVista011同首篇Native显示/自然返回均已Root亲审；仅具名范围通过，不冒全85源正文可用。 | 后继材料fb5245d已SSH同步，源仓干净；237已恢复Browse/原10000ms/AWAKE、scratch清理并释租，现有源owner本轮工作已结束。旧403/5xx/TLS/账户/在线缓存条件见当前队列；没有新增请求、测试矩阵或图标任务。 |

- **图标候选批准与Terra后继纠正（2026-10-22，三源实机及远端交付完成）：** 人类先批准`source-icons-four-proposals.png`四项，后明确Terra固定白底保原黑色，取代中灰/透明/描边候选；Terra原512px白底黑字017保持，237深色管理/Browse两原图Root已亲看清楚。HComic012完整原鲨鱼去英文、漫画社015黄漫/棕气泡独立几何标、漫画160012原红字上下两行均已普通picker安装/更新；三源浅色管理/Browse整图Root已亲看，App槽/圆角/顺序及业务请求未改。原件`category-membership/three-icons-package237-001`。真实registry59→60，仅新增HComic，原相对顺序及其他完整entry保持；漫画社014→015与160011→012仅预期包引用/版本字段变化。最终恢复原跟随系统及喵趣漫画Browse组，仅删除本轮三份本人传包并确认ABSENT；`three-icons-final-restored237-001`读回10000ms/AWAKE/koma0焦点208，049f4940租约已释放，所有产物哈希关闭。首深色选择因MenuItem/子Text同名、恢复原组时误用“喵趣”而非“喵趣漫画”的导航失败保留，未据其改产品。三源19文件3fda006已范围提交并同步源master，CI39722753351全部编译/metadata/封包/原子发布success。公开latest/index85项，HComic012/漫画社015/160012包及独立图标均HTTP200，三成员及精确ID/版本成立；本机首次把相对pkg当完整URL的解析失败后按实际合同修正，未据此改产品。原漫画社ASSET_SOURCES及喵趣NOTICE两WIP不纳入。
- **黑色主体固定白底（最新人类允许，源owner接续）：** 本轮当前用户明确允许黑色透明主体在深色界面难辨时固定白底，保原形/原黑色，不改写为全量强制换底。具体新反例为上述Terra深色两原图同屏“鸟鸟韩漫”黑线稿几乎不可见；不得以Terra通过冒其他图标完成。既有源owner已按最新固定白底许可生成NN012候选：同512画布alpha-over纯白；Root逐像素验证与该合成结果相同，原黑线/位置/几何保持且旧透明原件保留。源仅资源、版本与出处，离线info/三成员包通过；其他黑标ComicFury/xkcd当前已有不透明官方底图，不据旧资源重开。Root已追f1fc2857与管理/索引/Browse全部消费者，当前NN011=1.30；只给同几何NN012延续1.30，不改槽/圆角/数值/其他源。先前复合编辑+构建遭自动审批拒绝；补充实际候选逐像素几何证据后，单行保留性修改已获准并实施，未绕过。原主仓Debug16317325B已237安装明确成功，普通导入NN012后管理/Browse浅深四图亲审，均可辨且原占比保持；60项仅NN预期包引用与版本变化，主题/Browse/原10000ms/AWAKE/焦点209和本人传包清理均读回恢复、2d460006释租，原件`nn012-white-{debug-installed,final-restored}237-001`。原Release构建成功但安装被设备拒绝不受信任源；脚本的共享签名目录实际不存在、直接读取本地build-profile签名口令也不可作明文，两条尝试未改材料。237最终沿原生default/debug签名流程成功。197保持Release模式：发行签名同样被设备拒绝后，仅在原本地build-profile中临时让release产品选用既有debug设备签名；Hvigor构建完finally逐字恢复原配置，未改证书/profile/口令或关闭验签。8295117B、debug=false Release已明确覆盖安装成功。更新前后原书架/Chibi第2页25%/最近阅读/首三书均亲看保留，未开章/升级197源。原件`nn012-optical197-{unlock,release-installed,device-profile-installed,final-restored}-001`；最后10000ms/AWAKE/焦点87及3f1ffa16释租成立。系统picker根位置/下载父子同名的导航失败原图保留，不计产品失败。源b1b8eb5与App e9083692已同步，精确CI39724146846/39724219060均success；公开固定索引85项、NN012三成员包及白底图均HTTP200。本轮图标交付关闭；不重跑既有源正文验收。

- **ASM011获批字标交付（2026-10-22，Root/源owner）：** 采用用户明确接受的744×597透明AH灰渐变/白描边候选，省去人物；旧49px原图及可维护SVG保留，不称官方高清原件。八文件4174a62只含本源资源/出处及Cargo/src/lock010→011，业务请求、App槽/圆角/排序保持；离线构建/info011及39570B三成员包成立。237实时VDE-AL00展开1320×2120原未装ASM，经普通picker首次安装011；Root亲看`asm011-ah-package237-001/{manager-asm011-ah.png,browse-asm011-ah.png}`完整原图。原58项注册完整内容/相对顺序均保持，仅新增已启用ASM=59。首管理定位因扫描方向错误失败，实际导入已成功；保存`asm011-ah-manager-position237-001`真实页面后纠正导航，未重导包或改产品。`restored-browse.png`及`asm011-ah-restored237-001`证明返回原喵趣组、只清本人传包并核不存在、10000ms/AWAKE及koma0焦点208恢复，7e56035e已release；所有回执关闭哈希，197及源正文未操作。源4174a62已正常推送，CI39714545222全85源编译/封包/原子发布success；固定latest/index实际HTTP200/85项，ASM011公开包HTTP200/39678B，准确ID/版本/nsfw和三成员成立，内嵌及独立图标HTTP200/744×597RGBA/22488B。本地包39570B与公开压缩包尺寸不同，不称字节相同；未计算摘要。第一次公开读取仅本地解析GitHub最终重定向URL的假设失败，后按实际pkg/icon合同读取成功，未据此改产品。

**本轮初步日用版交付（2026-10-22）**

- 固定索引为 `https://github.com/honjow/koma-sources/releases/latest/download/index.json`。源库已将原main监听改为实际master，补齐21个生产源登记和9个必需图标；IKMMH/HentaiHand/Happy/92按本会话明确批准使用透明名称字标，不称官方Logo。Root已审6321776实际CI/build差异并独立读回成功run；源owner已对四包、85索引及85包/85图标资产作公开读取核对。
- 197普通入口从原LAN索引切到公开latest并保存，真实显示“已加载85个源”；首次加载约97秒（逐个图标请求，仍属待改善性能，不伪称快速）。实际更新爱看漫010→011、安装92漫画011；普通返回后不清数据cold，PID59199→NOT_RUNNING→64210，Browse仍80启用且两源011，管理页公开URL仍在。普通检查更新Native于04:49:09开始、04:49:14完成：update19/latest61/missing0/failed_indexes3；三个原保存索引失败不扩大为当前公开索引失败，旧地址未删除。没有批量升级其余19源、没有源站正文重验。
- 最终普通返回书架Chibi第2页25%/最近阅读已亲看，原10000ms/AWAKE已读回、7e5806e2已释租；公开索引、IKM011及92新装源作为本轮正常使用结果保留。原图/布局沿既有reader-failure-retry下 `daily-release197-public-gate-001`、`daily-release197-public-cold-001`、`daily-release197-session-restored-001`；有界计数日志在 `daily-release197-update-check-001`。首更新脚本误等只在索引弹层显示的“已更新”而超时，实际主列表已为011；另一次冷启动导航未等Browse就点工具栏，URL断言失败。两次失败保留，后按真实页面接续；没有据测试脚本错误改产品或把控件离屏冒成检查完成。
- 用户README已说明安装条件、普通添加/更新路径、源库及固定索引、备份恢复覆盖边界与问题反馈。当前197签名日用产物为`.hermes-artifacts/release/0.1.1-2-3a75c9a9/Koma-0.1.1-2-3a75c9a9-default-release-signed.hap`（8361988B），bundle `com.honjow.koma`，0.1.1/code2、buildMode=release、debug=false；它取代旧Shared/封面/图标阶段固定包，装机与恢复证据见顶部响应诊断段。App公开CI仍为未签名Release；未创建新tag。源资源交付及其出处边界依各自后继记录，不由旧OPEN重开已关闭图标；私库按用户决定搁置，不冒全能力通过。

- **喵趣012去白板/灰影限定交付（Root/源owner，2026-10-22）：** 192px固定扩展原件与喵趣名称/原域绑定，未取得新官方高清资源。图像生成稿因黄色杂边/孔洞残点被Root否决，未进源包；采用原104×104橙色字形的白底色度分离/边缘alpha恢复，120×120透明PNG、8px安全边，不放大、不描轮廓；主体橙色取原众数240/160/110，不称高清重绘。只改本源PNG及Cargo/src/lock版本011→012、README，App30vp槽/7vp圆角/排序和业务请求保持。237普通010→012导入成功；Root亲看管理/Browse两完整原图，无原白板/灰边，字形保留。56项sourceId/enabled逐项同序；只清本人传包、原10000ms/AWAKE读回且c646bab7释放。五文件2d4e035已同步，CI39679046650全85构建/封包/发布成功；Root实际GET固定latest/index85项及miaoqu012.koma均HTTP200，准确manifest、120² RGBA图和三成员合同成立。只关闭这次图标两消费者，不冒新正文/高清资源/其他图标通过；未操作197。原件沿237 category-membership/miaoqu012-icon-import237-001及miaoqu012-icon-restored237-001。下一原有低清项由既有源owner只读调查微漫画/ASM，Root不同时编辑。

- **XComic简繁去白板交付（Root/源owner，2026-10-22）：** 两源沿eb1b49b/6321776固定扩展双色X；本会话用户要求处理剩余素材板影，重开的是原192px白圆角板/灰影。011保留主体渐变和原尺寸、恢复边缘alpha，不放大/重绘，不改App30vp槽/7vp圆角、ID/语言/业务。Root亲看原PNG、96px浅深底及237管理/Browse两完整原图，无白框灰影；两实体原均未装，本轮普通picker新装011，56→58仅新增简繁两ID，原56相对顺序/enabled逐项同序。两包均恰manifest/source.wasm/icon，nsfw=true，简/繁最低App版本分别011/010。只移除自传两包、普通恢复Browse喵趣组，最终10000ms/AWAKE、8e887b02释租已核，未请求源内容或正文。原件为237 category-membership/xcomic011-icon-awake237-001/{manager-xcomic011.png,browse-xcomic011.png}、xcomic011-icon-restored237-001及xcomic011-position-awake237-001、xcomic011-icon-final-power237-001，回执哈希关闭。12文件bf45d24已正常同步源master（含本轮ASM/MPC/mh160现有资料，不含原漫画社ASSET/喵趣NOTICE）；CI39683540713全部85源编译/封包/发布success，固定latest/index实际GET200且85项，两XComic011包实际GET200（52482/52339B）、manifest/三成员及6077B透明图成立。初次下载检查程序误找url而实际字段为pkg，在发包请求前失败；按真实合同纠正后成功，未改产品。只关闭这两源图标消费者，不冒官网批准/高清原件或正文通过。Terra017保留：黑字透明在深底不适用、官方白字横标在浅底不适用，不截标识/反色替换；ASM的JPEG去黑稿有不可恢复彩边，創漫16px无内嵌大图，MPC/漫画160等缺独立合格原件，各自资源缺口仍OPEN，已否决路线不重复。

- **創漫W高清重建交付（Root/源owner，2026-10-22）：** 原同站16px蓝底白衬线W/短横低清；季节横幅字形不同、YouTube头像为活动牌，均未采用。按本会话低清2D重建授权，采用Times New Roman Regular平滑轮廓、原蓝RGB21/131/255及近似比例的512px稿；不描像素锯齿、不加阴影/遮罩，不称官方高清原件或原字体精确复原。原ICO原字节保留；7文件仅资源/出处/交付版本，Cargo/lock010与SOURCE_INFO011统一012，App30vp/R7及业务保持。237普通010→012更新后，Root亲看`weicomic012-icon-awake237-001`管理/Browse两完整原图，W清晰且圆角保持；58项ID/enabled逐项同序。`weicomic012-icon-restored237-001`及最终恢复图证明原Browse喵趣组、自传包清理、10000ms/AWAKE/Koma焦点，源owner已释放3708ec0b。51f73c0已同步，CI39690242553全85源编译/封包/发布success；固定latest/index实际200/85项，公开012包200/30240B、准确manifest/三成员、512²图成立（本地验收包30285B，不称远端字节相同）。检查程序首次将pkg相对路径当完整URL，未发请求即失败；按真实合同纠正后成功，未改产品。仅关闭本源图标两消费者；下一MangaBZ候选由同一owner继续。

- **MangaBZ低清重建交付（Root/源owner，2026-10-22）：** 原172e94f采用官网header的76px独立BZ，自动描边/生成改变几何的旧稿仍拒绝；当前低清未闭及本会话2D重建授权是重开依据。Root已亲看原图、512稿与96浅深对照，首稿外形过于规整未采用；修正稿用连续贝塞尔曲线保留不对称红轮廓、特殊连写白BZ及原平滑红渐变，透明边缘无新增板/影/遮罩，不称官方高清原件或逐轮廓精确复原。8文件仅本源PNG、保留原件/可维护SVG、README/ASSET及Cargo/src/lock016→017，业务代码只version；App30vp/R7/排序保持。离线Info017及52293B三成员包后，237普通016→017更新成功，Root亲看`mangabz017-icon-awake237-001`管理/Browse完整原图，红形/白BZ完整清楚；58项ID/enabled逐项同序，本源017。原Browse喵趣组恢复图及`mangabz017-icon-restored237-001`回执已核，completed/无哈希、只清自传包并核不存在、10000ms/AWAKE，源owner已释放b52e26d8。aae6aa8已推送，CI39692235190全85源构建/封包/发布success；固定latest/index实际200且85项，公开017包200/52353B、准确manifest及三成员、512²/33182B图像成立（本地验收包52293B，不称远端字节相同）。仅接受这次图标两消费者，不重新计算旧正文通过范围。

- **漫画160主字标限定交付（Root/源owner，2026-10-22）：** 原2f577e4采用官网header280×95完整PNG，主标与辅助域名共同占槽，实际字标偏小。Root已读ASSET/history、亲看原图及同90px槽浅深对照；红色整行“漫画160”与下方黑色域名无共享笔画。按本会话全线原资源/偏小图标处理授权，仅用原像素裁框[44,3]–[234,54]保留全部红主标及8px透明边，排除辅助域名，不截单字、不改字形/重排/放大/加板影遮罩。候选190×51在原30vp槽更可辨，但仍横长细笔画，不称独立方标或全部质量关闭。7文件仅本源PNG、原件保留/出处及Cargo/src/lock010→011，业务源码只version；App30vp/R7/排序保持。237普通010→011更新后，Root亲看`mh160011-icon-awake237-001`管理/Browse及原Browse喵趣组恢复图：整行红字完整，原58项ID/enabled逐项同序。实际capabilities仅枚举顺序变化、集合相同；minApp010→011符合既有build登记。`mh160011-icon-restored237-001`回执completed/无哈希、只清本人传包并核不存在、原10000ms/AWAKE读回，源owner已释放6c7af635。d4bb515已推送，CI39694475328全85源编译/封包/发布success；固定latest/index200/85项，公开011包200/22609B、准确manifest及三成员、190×51/3570B图成立（本地验收包22690B）。仅接受这次可辨性改善，不称横长细笔画全部解决或正文通过。漫画社现原件左部是风格化“漫”字，先前源owner称猴缺依据，已撤回；原ASSET WIP保持。

- **剩余图标新增原件父链调查（源owner回传，2026-10-22）：** 三个精准公开查询仅得到账号与品牌指南线索；原生`https://x.com/MangaPlus_C`一次正常open为403，`https://medibang.com/guide/?locale=ja`为真人/JavaScript验证页，均停止，未换方式或取得可核的官网回链/头像URI，不把搜索中的创作者账号当平台账号。旧about/503脚本/Link-U/PR原图未重请求；MPC完整横标的小槽限制保持。ASM另三条精确查询仅域名统计、第三方支持列表/脚本等，未发现带官方声明/官网反链的账号或新图；49px原PNG、192扩展参考及256×183有损JPEG与旧否决稿保持，不证明新原件不存在；仅旧否决稿不复用、旧去黑路线不重试，既有低清2D重建授权保持。ASM标准同源`https://asmhentai.com/favicon.ico`未找到既往准确请求记录，本轮唯一匿名GET实际403，无图体/身份声明，停止该准确端点。漫画社两条正确域名限定查询无新官方图；Terra新微博`https://www.weibo.com/u/7499841383`原生页自述官方并明确回链Terra漫画站，账号绑定成立；Host匿名转Sina Visitor System后停止，成功web结果未给头像src，额外一条账号限定图片查询仅作品封面命中，不当Logo；未取新图或绕过访客流程。其余具体条件保持，低清处理不因本次检索失败一概冻结。

- **MPC资源身份澄清与高清几何重建（Root/源owner，2026-10-22）：** MPC浏览器约定`https://mangaplus-creators.jp/favicon.ico`一次匿名GET200/5430B，含16/32px，未见head声明。原32像素是蓝圆盘/白C/深细边，现SVG首字是蓝渐变C，前景/负空间不同；Root与源owner撤回先前“同形可直接复用SVG”判断，不拼造高清稿或采用该待核图。原件在既有audit/mpc-default-favicon-original.ico。ASM低清2D重建授权保持；新方法限定一份分层候选，AH直线/斜边/镂空用原拓扑平滑几何，人物若使用图像接口仅生成原身份的成年青发/护目镜/黄衣透明角色层，不含文字、不强调身体/改变衣着；旧失败整图不复用。若身份不能保留则报告冲突，不硬造。本轮Root已亲看原256×183 JPEG及人物层：发梢青点、衣摆黄红残点、右臂/躯干补造和整体比例偏移，不合格，不合成AH、不采用。人物原件为既有generated_images/01a15e87-884f-7d60-b12b-3cb5d2cfbd2c/exec-24bd3def-3a50-4a7a-ad04-1c2410947e19.png；未动生产或设备。MPC后继只读重评表明官方origin准确favicon请求200/image/x-icon且无重定向，成功父页title/og明确MPC；没有归属别产品或默认框架的具体证据。用户本会话明确允许不同的官方认可标识，故原图与横标不同不再作为身份否决。原32帧的蓝盘/白C/深细边可作完整识别符，Root已亲看；仍有高密度放大清晰度限制。原32帧版013实际在237管理页完整C可辨，但黑白边/蓝盘明显柔糊；Root据实际反例否决这份质量结果。首Browse目标被底部浮栏遮挡，不能作完整终点，源owner已另补full图；原012正式包普通重导已成功，恢复原横标。随后图像接口生成高清C仍在圆外留白碎点，亦否决，原生成文件保留且未入生产。Root沿当前人类2D重建许可制作新的数学几何稿：512px透明PNG及同参数SVG，仅理想圆、圆弧、圆端和近似原蓝渐变，不描原像素轮廓、不加板影遮罩；明确为几何近似重建，非官方高清原件/原字体精确复原。现有audit/mpc-browser-c-geometric-candidate.{svg,png}经Root亲看及源owner对照后接入013；原官方ICO及完整横标SVG保留，新增可维护重建SVG。App30vp槽/7vp圆角/排序及业务保持。237普通012→013成功，Root已亲看mpc013-geometric-awake237-001/{manager-mpc013-geometric.png,browse-mpc013-geometric-full.png}两张完整原图：C/蓝盘及内外边界清楚，无原32柔糊或生成碎点。首Browse目标落顶部模糊区，另补full后才接受，不以失败取景作通过。原58项sourceId/enabled逐项同序，只有MPC交付路径及版本变化；原喵趣组恢复原图已亲看。mpc013-geometric-restored237-001回执completed/无哈希，只删本人传包并核ABSENT，原10000ms/AWAKE及koma0/焦点208读回，e015ad5d已release。末尾本地错误按bundle名匹配窗口名的断言失败，只读实际原窗口回执后澄清，未作产品故障或新增设备动作。8文件源提交f6d7cc7已推送，正式三成员包82441B、WASM80975B、512pxPNG58235B；远端CI39698869757已全85源编译/封包/发布success；Root实际GET固定latest/index返回200/85项，MPC013公开包200/82593B、准确ID/版本及三成员合同，内嵌512px图58235B；独立索引icon链接亦200/512px/58235B。公开包与本地包的压缩尺寸不同，不称字节相同，未计算摘要。仅闭本次两图标消费者，不冒官网高清原件/正文或所有源质量完成；既有源owner已完成原分层方案的AH数学几何层，Root亲看audit/asm-ah-geometric-candidate.{svg,png}：完整连通AH、A孔、H上下开口、灰渐变和白描边成立，仅作近似重建，不冒官方精确矢量。完整人物层仍不成立；Root已提交具体选择，推荐只用完整高清AH字标、清楚说明人物会去掉，另一选项保留原完整低清图。此前资源高清化授权不自动替代这项省去人物的决定，答复前不改生产/版本/设备；MPC和既有日用包交付不受该等待影响。

**当前接续队列（2026-10-23续接核对；逐项以当前状态接续，下方旧段落是结果索引）**

- **2026-10-23交付收尾 / Root：** 日志、版本日志/预发布CI、封面、K图标及普通Shared具名入口已交付；10cddc79检查4/4通过。最新响应诊断3a75c9a9精确CI39824362291成功，签名日用包已固定并197装机/恢复完成，见顶部。源owner核旧失败后继后，本轮Protectors首篇与SciTechVista同首篇已具名闭合，材料fb5245d已同步；MPC已由011正文/下载/cold取代，不重跑。当前没有设备或源执行者在运行；余项逐项核对为条件依赖，详见下一条，不能据此称全App/全源通过，也不从85源从零测或开发新源。

- **条件性剩余项 / Root + 原源owner：** MH160旧404绑定不足、同章后继403，包子原403/5xx，Happy原TLS/API拒绝均缺可信成功原响应，不重试拒绝端点或猜改映射；Noy013明确auth_required，需真实账户及获准接入方式；GlobalComix侯门在线P2仍未闭，原章已下载且无安全强制在线入口，不删下载/缓存造首取。Six既有下架/两图后继范围保持，014只补网页字段，不补造全正文通过。App自然保存失败、新增章、真实外部授权失效、首次图标全未命中耗时、Tracker账户仍各依赖实际场景；四私库PARKED_USER只待人类重提。以上只限制对应项；本次有界读回未发现其余可立即执行的既有修复动作，非所有能力完成。新反馈/真实条件变化仅重开对应项。

- **App / Root / 197：公开索引图标限并发已部署、同步且CI成功。** 既有197原记录为85源首次约97秒；本轮读当前SourceIndexService.fetchIndex及096730b1原引入，确认每项await cachedIconUriFor之后才开始下一图标，管理页加载和更新检查共用它。原理由是缓存按源ID/版本隔离并验证图片，不撤销这些职责。当前拟改仅批量最多4项并行读取，仍按原索引位置组装结果，全部保留缺图/非法路径拒绝、图像检验、缓存身份和网络失败回退；页面文字/几何/排序、安装合同和偏好写入不改。限定实现已完成。实际生产方法配内存HTTP/cache端口验证85项逆序完成仍原序、并发峰值4、4种图标失败条目保留、缓存仅重试失败、缺图/非法路径在图标请求前拒绝；未写文件或计算摘要。首测试仅校验次数预期83写错，实际82（HTTP失败/网络异常/空体三项在字节校验前返回），改测试预期后通过；未据此改生产。Release 8294930B/0.1.1/code2/buildMode release/debug false已构建并197明确覆盖安装成功，本地release产品临时选既有debug设备签名，finally逐字恢复配置。197原公开latest普通读取真实“已加载 85 个源”，有缓存重载4.894秒（含语义点击/等待开销），不清缓存、不升级包；不能将它与历史首次97秒当同条件提速对比。Root亲看结果及最终书架整图：本轮实际基线为Chibi/书虫/猎行者，Chibi第2页25%及原可见卡片保持，猎行者原封面占位仍在，不冒全库数据逐字段保持或封面已修。先前过早坐标未进管理、文案断言漏空格、末端书名预期1而实际卡片与网格共2，失败全部保留；后继原图/布局证实已返回原书架，未改App迎合断言。原10000ms/AWAKE/焦点88读回且b9667b96释租；具名原件index-bounded197-{gate,installed,current,restored}-001与installed内ordinary-index-*-actions.json，回执哈希关闭。7ace468b已范围提交并同步，精确CI39748030006已success，未签名Release构建/检查/上传及固定Kit检出均成功。第二消费者也已具名通过：普通检查更新真实完成“检查完成：可更新 27，最新 53，未找到 0”，Root本轮亲看completed-result.png及返回书架completed-original-shelf.png。最初20秒客户端接收期限在scrollSearch绑定返回前超时，保留JSONDecodeError及原失败回执；随后只按官方On.text前缀匹配/scrollSearch读回同一结果，60秒接收期限完成，没有再发起检查。原件index-updatecheck197-{gate,resume-gate,result-position,log,restored,final-restored}-001及gate内update-check-result-recovered-actions.json；final-restored回执completed、哈希关闭、自有scratch已清、原10000ms/AWAKE/焦点88恢复，租约20261022-084118-32025cf6已释放并读回released。当前限定调度修复的加载/更新检查两个消费者均已关闭；首次新图标全未命中的Native耗时保留待自然场景，不为此清缓存或从零重跑源正文。
- **MyComic/漫画1234官方原件调查的历史边界（现图标修正由ddf7fae及本轮237验收取代）：** 它们已有可发布图标，区别于缺文件或构建失败；本轮source owner有限核对：MyComic仍缺成功官方身份父页；漫画1234既存成功详情HTML新核出的mint-logo准确PNG唯一匿名内存GET实际403，已停该端点。最初图像/JSON落盘组合被自动审批拒绝且未发GET，后继只读取内存获准，不能把两者混作网络失败；未新增文件/代码/设备动作。当时未获可采用新原件；现按已有2D重建允许完成素材修正，仍不声称官方高清原件、不重试403/挑战。本批已交付图标不重跑，临时名称字标不称官方。根README过时的喵趣/HComic/XComic待处理说法及固定白底许可冲突已就地纠正，单文件afc937c已同步master，未重跑85源构建；两份原材料WIP后继已由3e8b549/05924d5收尾并按人类授权同步，精确CI39762999539成功；源工作区干净。
- **当前执行 / Root：** 以可交付App为目标；最新人类明确“后续的代码提交推送不用再问我”，本任务授权范围内审查后直接范围提交、推送并跟进精确CI，不再逐笔设置批准门。提问只挂起确实依赖答复的单项，其他已授权动作继续；整体未完成不得自主停工，单项受阻不停止其余队列。此前“先整顿工作方式”暂停已被取代。
- **私库验收 / Root：PARKED_USER。** 2026-10-22本轮197普通设置实际读回Komga/OPDS/WebDAV地址为空；Kavita已有地址的本机端口无监听，两个现有私库容器exited。仅核配置存在性，未点保存或测试连接、未输出凭据；原件`reader-failure-retry/privateconditions197-gate-001/private-service-conditions.json`。人类对call_0c3fdf62f5454ff6bbce1635df93a927明确答复“将这几项标记为搁置，待我后续实际验证测试再重新提起。后续不要再自主复活他们的测试”。Komga、Kavita、OPDS、WebDAV及依赖其服务的浏览→详情→正文/返回/私库历史验收均搁置，不能由heartbeat、旧下一步或交接重新派工；仅用户再次明确提出时恢复。首次新图标全未命中、自然保存失败/新增章、真实外部目录授权失效等仍依赖自然场景，不清缓存、造状态或撤销授权。
- **确有原问题待答 / Root：** 普通Shared入口旧待答门已被当前人类call_dd9f58c2a27a42ec8d42e1c5f21e5507明确取代，当前必须完成该入口后才可交付；不得再标为等待。其余旧下载说明/菜单文字/本书标记三个候选，已由当前人类对call_8591880144e44b569f5a77caa89864a0的明确批准统一取代并完成下述限定验收，不再列等待、不重复提问。

- **日用版三项限定修正 / Root / 已授权实施（2026-10-22）：** 当前人类对call_8591880144e44b569f5a77caa89864a0选择“本轮修正这三项”。替代旧下载说明、阅读菜单文字、本书标记刷新三个待答门；普通Shared入口原单独批准门保持。对象/历史：b6eb587f把失败下载说明写成自动重试，但SettingsPage消费者只打开管理；ReaderChrome失败菜单复用状态句作为动作名；4e9e16b0仅loadPreferences读取seriesOverrideActive，保存时a85b3e35的串行saveChangesForComic已返回提交结果，却未刷新这一本书的标记。原窄覆盖只管mode/direction并保护全局的理由保持。允许差异：三语下载说明改为查看并重试失败任务；已有失败菜单动作改“重试”；仅保存成功后按已有串行store读回当前书override，刷新既有本书标记/恢复默认入口，拒绝离开该会话后的回写；不改尺寸/布局/操作/全局默认/持久格式。已完成三语键集检查、实际生产保存方法的异步边界内存检查（成功后刷新/切会话拒旧/关闭拒旧/保存失败保留/清override），未新增测试文件；Release构建成功，使用既有197设备签名且finally恢复本地build-profile，8295344B/0.1.1/code2/debug=false。197明确覆盖安装成功。普通下载页真实说明正确且点击仍到下载管理；当前成功正文的菜单显示重试并仍禁用；原Chibi首次无override，临时改单页后同一设置页立即出现单页·本书/从左到右·本书、菜单有恢复默认，选择恢复默认后立即回纵向分页/从左到右/无本书标记，普通返回书架仍第2页25%。Root亲看全部相关原图；未改全局模式、升级源包、重测旧失败重试行为或触私库。原件`reader-failure-retry/daily-three197-installed-001`内download-settings-corrected、reader-menu-retry-corrected、book-mode-first-save-badge、book-mode-reset-now-visible、book-mode-original-restored与three-fixes-original-shelf及语义记录。最初设置标题/底栏同名导致唯一选择被拦；另一断言误用“翻页模式”，实际设置页已打开且标题是“模式”；两次工具预期错误保留，未据此改产品。最终daily-three197-restored-001读回10000ms/AWAKE/当前Koma焦点89，无哈希，4f1570f2已释租。后继e2f1a411已按人类授权同步，精确CI39762991218成功，不再列本地未同步。

- **源材料收尾 / source_delivery_cleanup + Root（2026-10-22）：** 只整理既有漫画社ASSET_SOURCES与喵趣NOTICE两份WIP。漫画社3e8b549明确015获批几何图标已取代旧横标OPEN，保原HTML/CSS/JSON调查出处；喵趣05924d5完整保留旧403笔记并标成未核实历史，原命令/回执尚未定位，README仅间接支持，撤销其作为当前缺图描述的效力。Root已审两笔精确diff；无源码/资源/设备/网络动作，源仓当前工作区干净；两笔材料的同步后继见本条末尾。两现有素材品质条件MyComic/漫画1234保留，不由旧记录重开已交付图标。后继已按call_25a020fd1ca9400594046e46cb7716a6授权同步源master，精确CI39762999539成功；不再列未推送。

- **本版普通共享阅读器 / Root / 当前具名范围已交付（2026-10-22）：** 人类对call_dd9f58c2a27a42ec8d42e1c5f21e5507明确选择“这版须接入共享阅读器后再交付”，取代普通Shared入口旧待答门；接入前的签名包不能作为最终交付；现普通入口已由44a86da1接通并完成下述具名验收。允许范围为普通书架/详情/历史开书真实采用reader-kit及宿主进度、切章、按书设置、媒体动作和返回闭包，保留旧版实现，不改变无关UI/源业务或私库搁置决定。实施先追c670b249/93771857/a85b3e35普通路由边界及现Lab宿主，统一复用当前Kit/宿主适配，禁止只换Builder或复制旧整页。接入前发现的Lab全局load/save、根/Lab重复请求与Debug guard边界已在当前宿主实现中处理；Release构建、197普通在线源/既有本地/历史、进度重开、章节、按书设置与关闭返回结果见下，不再将已完成实现列为下一动作。Kit若改公共API须检查N/E受影响消费者。未完成不得以三项修正或CI通过结束整体任务。前一批App e2f1a411精确CI39762991218、源05924d5精确CI39762999539均已success。本次44a86da1已按当前明确批准同步honjow/Koma master，远端指针读回相符，精确push CI39789257199已success：固定Kit检出、公共配置/i18n/OHPM/Release编译/HAP检查/上传均通过。两仓当前同步已完成；使用既有SSH443通道，未改远端/全局配置。

- **普通Shared接入197具名验收 / Root（2026-10-22）：** 普通继续阅读Chibi2/8→3/8→返回重开3/8→自然恢复2/8；xkcd前后章及按书双页保存/恢复默认；历史开书；本地Nemo2/3→3/3重开→恢复2/3；未收藏樱花追忆篇1/15→2/15返回重开，均有ordinary-shared-progress/chapter/history-local/source197-001原件。它们是本轮普通入口证据，不冒私库、全部源或全模式组合；ComicFury定位两次失败，未重试或记通过。两段录像和本地135帧此前黑帧未复现，未扩大为所有转场无黑帧。
- **详情重入崩溃已修复：** 更多→返回详情→继续阅读时PID54532实际退出；reentry-failure-full-tail.log明确ReaderSurface.onCropPolicyChanged访问null session导致JS_ERROR。宿主清空session时让仍挂载Surface收到null，违反Kit固定会话生命周期；现只在Koma以固定session/unit/initialIndex条目挂载，每次新阅读请求替换条目，同会话翻页/切章key不变。Kit保持3a7b56d/干净，未改公共API或N/E。第一次构造器字段简写被ArkTS编译拒绝，改显式字段后Release构建成功；配置finally恢复，8307106B包197明确覆盖安装。修复后同一樱花路径真实2/15图、Nemo同路径真实2/3图均亲看，PID61821保持。Chibi普通详情仍真实2/8；图片信息实际显示JPEG/428.0KB/800×800（来源当前未知仍如实保留），关闭后经详情回原书架，卡片第2页25%和最近阅读亲看。未发送/保存图片、清用户数据或缓存。回执及原图在ordinary-shared197-reentry-installed-001；标题断言误用“图片信息”而非“图片信息·第2页”、一次Back字符串类型错误和一次多余Back退出App均是工具错误，保留失败且已自然恢复，没有据此改产品。
- **设备电源待答已关闭：** Root在20:33及首次收尾误用power-shell setmode602代替timeout；这条命令没有改变当时既有86400000ms超时，不能冒正确命令。后以既有timeout -o 10000恢复原超时，ordinary-shared197-final-restored-002已读回10000ms。切前模式当时无日志证据；最新人类对call_f91bfd4f明确答复“原来就是性能模式，保留”，这是当前恢复依据，不能冒作日志独立核实。现保留602，未再设置电源模式；原租约20261022-114619-cae4bf64已释放且文件读回released，不再列等待或占用设备。

**近期具名结果与条件记录（后继已完成项不重新派工）**

- **搜索结果卡片与更新入口修正（Root/197，2026-10-22，已获当前人类批准）：** 修改对象为SearchPage.ResultRow和SettingsPage.rowDetail的library-update分支。当前原图local-file-result.png显示封面占比偏小；d17f3fe5最初48×64，3bdcc0d9改公共常量并将卡片padding12改16，原具体尺寸理由未知。用户本轮明确批准封面64×88、padding12、封面R12/外卡R24；只改本ResultRow，不动全局常量、文字、路由或检索。更新行原3c5b84435/d4e4e7bc把完整统计与时间拼入尾部，当前library-settings-before.png已显示拥挤换行；用户本轮明确批准尾部仅检查中/上次检查HH:mm/尚未检查，完整结果仍由原更新结果页承载。原自动更新/通知/下次检查消费者保持。两页此前无未提交源码差异；已限定实现并构建；04:00:30/16317373B签名包197覆盖安装明确成功。Root亲看普通书架搜索Nemo、Chibi长标题、三条斗破苍穹来源整图，原文字/匹配提示/来源保持；Nemo真实封面156×208px→208×286px，卡片左/上/下留白52/53/52px→39/39/39px，与64×88/p12一致。卡片原R24、封面R12实图无可见不协调裁角。更新入口真实显示“上次检查23:57”，无拥挤换行；普通更新结果页保留75/0/72/1/2和0新章及完整日期。未触发新检查，不冒检查中/从未检查分支的当前实机结果。原空查询/全部来源、Chibi第2页25%/最近阅读/首三书、10000ms/AWAKE已恢复，0641560d已释放。唯一菜单定位失败原件保留，未据工具错误改产品。证据reader-failure-retry/search-card197-installed-001与search-card197-session-restored-001。源线按用户最新要求仅图标，暂停可用性/新源验收。

- **Laya封面/漫画屋网页后继（Root/源worker，2026-10-22）：** Laya012当前首六与旧图同序，第三排左现为《不專業演員》ch-0007.jpg；237普通列表滚入题名及封面完整可见，只闭该当前槽，不猜旧占位错误原因。漫画屋013在237普通书架来源进入斗破苍穹，同步get_manga/get_chapters均200/operation_ok，真实网页标题/封面/作者/简介及章节网格可见，自然Back原670/670；初始白屏及仍转动的绿色加载标记保留，不称全部子资源已完成。Root亲看webview-current/native-return两整图；原All sources/Browse55、10000ms及租约恢复。源README两份已范围提交8f04038并同步，原喵趣NOTICE不纳入。原件category-membership/laya012-cover7-slot237-001及manhuawu013-webview237-001-gate与对应restored回执。

- **ComicABC010旧9154首章解析反例续验（Root/源worker，2026-10-22）：** 当前实际WASM sourceInfo0.1.10，对旧失败comicabc:chapter:9154:1单次Host页计划返回71页；同实体get_manga真实题名《終結的熾天使》。237普通准确源内搜索→159/159目录，普通选1話实际恢复已有P2/71彩色题图，前页P1/71为繁中三格叙事正文，Root亲看原图；Back详情1話1/71。日志仅保到图片请求/display_ready/complete及cache hit，Native新在线页计划未证；不以缓存读图冒首取。随后普通重置默认降序、仅恢复原159话2/29且不翻页，详情/历史均读回原位置；Browse55、完整registry保持、10000ms/AWAKE并release dfc078d6。未清缓存/下载/写回私有状态。原件237 category-membership/comicabc010-9154-{body,current-log,restored}237-001及Host原件；源README已范围提交，原喵趣NOTICE保持。后继原回执核对：现存recovery-20261019/comicabc-six-historical-parents-2-nested-full-tree-preserved.tar.gz中的tree/native-receipt.json与result.json（Root仅读两个member、不解包）明确0.1.4时两首章P1/P2已有PASS_FINITE_ROOT_REVIEWED，16264/ch1还20/20下载及不清数据cold重开P2；原README更早OPEN已被取代。本轮9154记录只算当前010缓存图片补证，不称首次修复；16264本轮零网络/设备动作，不再派同路径。现有owner继续其他真实未闭源项前先核该源后继回执，不扩全章矩阵。

- **喵趣缺图资源接续（Root，2026-10-22，未采用）：** 仅沿NOTICE已引用的Keiyoushi固定1319949资源取到96px与192px“喵”图，原build.gradle同目录明确绑定www.miaoqumh.org；该第三方来源不能冒官网认可，既有排除决定保持。复用已有成功手机版详情HTML，发现.logo节点及其声明CSS index.css；该CSS本轮正常取回并明确background:url(../img/logo.png)，准确图像URL一次读取实际HTTP404，无图件。原favicon404、www首页403均未重试，没有改图/放大/重绘或封包；当时官方原件仍未取得；后继喵趣012素材交付见顶部，本调查不再派工或重试。原件位于现有user-flow-audit/miaoqu-{upstream-fixed-*,declared-index.css}；不改原NOTICE WIP。

- **搜索书架同名结果来源不可辨（Root，2026-10-22，已实现并197限定验收）：** 原图source-web197-baseline-001/search-failure.png实际是“书架”筛选下三条斗破苍穹；当前保存library的真实sourceRuntimeId依次为CManhua、漫画屋、喵趣，后两条连作者和封面也同，界面无来源名。交接摘要把其中两项说成GlobalComix/CManhua有误，本轮按原图/实际字段纠正。d17f3fe5原本地结果仅作者/章页，f1519216增加命中章名，31d7b164增加独立匹配质量第三行，31c8ee5a只接源结果中文名；没有发现故意让同名不同源不可区分的决定。ResultRow完整父树为各Section下独立卡片，副行单行，第三行匹配质量；调查前两文件无其他WIP。建议仅SearchPage.resultSubtitle对localComicId对应且sourceRuntimeId存在的书架项，在现有副行前放现有本地化源名，如“漫画屋 · 知音漫客 任翔”“喵趣 · 知音漫客 任翔”；保留作者/命中章名、第三行、排序/检索/路由及全部几何，源缺失时保留现有副行，真正本地/私库/远端结果不改。只从LibraryStore读既有身份，不把来源字串写入检索字段或排名。本轮用户已明确选择“显示来源名”，仅上述副行前缀已实施。签名构建03:05:02/16316554B并197覆盖安装成功；书架筛选斗破苍穹的三条真实副行分别为“CManhua · 知音漫客”“漫画屋 · 知音漫客 任翔”“喵趣漫画 · 知音漫客 任翔”，语义断言及整图已亲审。作者/匹配质量行保留，未改排名/查询。原件search-origin-resume197-installed-001/source-origin-result.{png,json}及source-origin-actions.json。普通清词/取消书架筛选后返回书架；两次Back先后收键盘/退出搜索分别观察，未把中间搜索截图当书架。 后继同包197补验：真正本地Nemo仍“2 章 / 4 页”，无源前缀；查询“爱的故事”命中书虫，现有单行副行保留原章名并前缀DM5，匹配质量行保持。Root亲看两整图，未开作品或更改读态；最终空查询/全部来源/书架和10000ms/AWAKE恢复、releasedb3fe356。原件search-subtitle-preserved197-unlock-001内local-file-result/matched-chapter-result/final-library及preservation-actions.json，原顶栏双按钮/双Menu定位失败保留，不冒产品失败。

- **CManhua013两线限定验收（Root/源worker，2026-10-22）：** 197现有012→013普通更新，准确书架来源筛选进入斗破苍穹，WebView真实作品页→Back原664/664及继续第3/36页，Root亲看原图；旧摘要第2/36描述按实际原图纠正。237首次导入54→55并保持原54有序ID/enabled，两网页菜单真实存在，WebView→Back保持664/664；正文P1/P2是不同扉图，后继普通历史P2→P3/36真实三格星空叙事，Back历史真实3/36，Root亲看两原图。未冒P4/其他章/新下载或全源通过。两台传包清理、10000ms/AWAKE和租约释放均有回执。原件197 cmanhua013-library197-{baseline,final}-001；237 cmanhua013-{body237,story237,story-restored237}-001。源README已审范围提交6e756ff；首次SSH22连接关闭，后继HTTPS正常推送被自动审批因目的地及载荷授权不足拒绝，未绕过，已向用户呈现确切范围；原喵趣NOTICE未提交。 漫画屋013错误证据后继：197实时唯一Connected，e9bd815d租约下沿原中性手势解锁，AWAKE/86400000及Koma焦点83均读回；仅对现存PID40091有界筛选SourceHttpTransport/source-detail安全标签，返回0条，不能据此认定没有错误或归因。未点击作品/重发请求/读取业务正文；原10000ms/AWAKE恢复后释租。原件manhuawu013-existing-log197-{wake,unlock,read}-001；哈希关闭。

- **Six014本地封包分级纠正（Root/源worker，2026-10-22）：** 交接复核发现本轮手动封包把manifest.nsfw误写为false，与build.sh登记true及contentRating=nsfw冲突；Root负责编包错误。现有包已就地改为true（197542B），逐字段核对其余manifest、WASM/icon内容不变，未计算摘要；同批漫画屋/GlobalComix/繁中WEBTOON分级均符合登记。237和197均已普通picker同版重导，实际已装manifest均为true/nsfw；两台原54/79项ID顺序/enabled分别保持。197 library/reader完整内容在重导前后及本轮路由返回后全等；原件sixmh014-classification197-{baseline,result,verified}-001及source-routes197-final-preserved-001。

- **搜索书架结果遗漏书源详情路由（Root，2026-10-22，实施前）：** 237与197的漫画屋013均普通导入成功，但仅书架搜索打开斗破苍穹时仍只有Tracker菜单，不能验收网页入口；197原图source-web197-baseline-001/detail-menu.png。已追d17f3fe5：SearchPage.openResult的local分支仅传本地comicId，MangaDetailPage.loadMangaDetail因此只走旧本地快照，未调用get_manga；这条路由原本适用于本地作品。a2dbd6bc后，普通书架封面已通过Index.openLibraryMangaDetail按真实sourceRuntimeId/remoteResourceId打开书源详情。当前人类已要求漫画详情提供WebView和浏览器入口，新反例重开的是两种同书入口的职责差异，不改原搜索来源选择。允许差异仅SearchPage本地结果委托Index同一现存开书函数，真正本地作品仍由该函数保留本地路由；不改查询、筛选、排序、请求合同、布局/文案/按钮或进度。两文件委托接线及同资产比例一行已构建成功（01:23:08/16317008B）并197覆盖安装。漫画屋确进入书源流程，实际显示源详情加载失败、旧670/670和原4/36保留，失败码未明，不重试或当网页通过。GlobalComix旧书架搜索结果实际出现两菜单，WebView终态显示同作品封面与英文标题，原生Back仍1/1及原Episode1第2/2页，再Back原查询保持；Root已亲看整图。初阶段只闭GlobalComix搜索→WebView→返回，未冒首次阅读或其他源通过；后继本轮197已普通选择外部浏览器，前台原件bundle明确com.huawei.hmos.browser，真实同作封面/英文标题及完整URL https://globalcomix.com/c/the-marquis-s-cherished-one已亲核，系统QuickBack返回com.honjow.koma仍1/1及原2/2，查询保持。另真实本地Nemo普通书架搜索仍2/2与原Nemo2/3继续入口；未开正文。最终查询清空/全部来源/原书架恢复，library/reader整内容与重导前全等。选择器起始位置、Search父节点清文字无效、重复Text匹配及键盘返回判断失败均保留，不作产品缺陷；按真实子SearchField和当前页条件恢复。原件位于sixmh014-classification197-baseline-001内local-Nemo-detail、external-browser-{initial,terminal,exact-url,native-return,original-shelf}及对应语义记录；不把浏览器初始白页或站点推荐App层当稳定终态通过。三份本地包按build.sh的同一三成员/完整metadata合同就地生成，原ICO保留；避开已被自动审批拒绝的全dist删除及index摘要生成，不运行该拒绝操作。197普通更新漫画屋011→013、Six012→014、Global011→012、繁中WEBTOON012→013后，原79项sourceId顺序/enabled逐项相同，library与reader完整JSON内容均与本轮基线相同，未开正文/下载。原查询已清、全部来源及原书架/Chibi25%恢复；最后书架截图接近返回过渡，不作整页动画/几何通过。四个自传包ABSENT及10000ms/AWAKE读回，e19b6b2e已释放。原件source-web197-{baseline,route-installed,final-state,session-restored}-001；错误文件物理路径、驱动字符串返回键、动态ID/结果数量断言与全日志UTF8解码失败均保留，未据工具错误修产品。

- **六漫画014同资产比例延续（Root，2026-10-22，实施前）：** 源8edd4d3仅加作品网页字段并升013→014；icon与metadata均未改。f1fc2857原偏小图标批准采用1.05，0eee60a6在013已按同资产延续。仅给ConciseListRow.sourceIdentityOpticalScale新增014同值匹配，保留012/013与30vp槽/7vp圆角及所有其他源；不因源版本更新撤掉已验外观。已与本次App构建集成；197普通更新014，Root已亲看237管理/Browse两处同组原图，014保持1.05呈现；分级重导独立接续，不冒网页或正文通过。

- **漫画社014网页与同版本名称刷新边界（Root/源worker，2026-10-21）：** 014只补get_manga真实BASE+mp作品页，Host同实体013/014除links外字段/请求相同，Root已亲核；237普通012→014后实际《一人之下》网页显示封面/评分9.9/人气171740，原生Back仍800/800章及766反杀2/17，Root亲看manhuashe014-webview237-004四图，未开正文或浏览器外跳。首开发包漏带metadata.json现有两中文名，已纠正正式29732B包并普通重导同014；原raw包不作命名通过。同版本补元数据后详情badge正确“漫画社”、Browse旧行仍“漫画社 (Manhuashe)”；一次不清数据cold（8283→stop后空→37211）后恢复准确“漫画社”v0.1.4，54启用保持，Root亲看name-cold237-003/browse-name及001/enabled54原图。SourceListItem.displayTitle依global registry读取、Browse retained行key仅sourceId/version；3038272b恢复的是版本变化失效，31c8ee5a恢复的是中文名读取，尚未覆盖同版本metadata变化。该反例保持OPEN，不把cold正确称同进程即时刷新通过。Root本轮已追原350073bc/恢复3038272b的版本key决定及31c8ee5a的localized-name消费者；注册导入已保存新metadata并notifyChanged，父级已loadInstalledSources，但保留行key未包含实际显示名称，ForEach继续复用旧子树。官方知识MCP传输失败，Bundled ForEach合同确认按key识别变更，不改平台或同步机制。允许差异仅把既有resolved显示名纳入原sourceId/version行key，使已采用的同版本包名称可刷新；不重命名源、不改排序/启用/容器/图标/文案/私库或请求。该显示名key候选已构建并明确覆盖安装197。原漏metadata的raw014已被同路径纠正包覆盖，没有独立原包，不重造坏包；因此同版本metadata旧名→新名精确Native仍OPEN。197普通语言切换又取得实际反例：英文Browse标题/来源组已切换，Kavita行仍中文说明与私库标签，而en_US资源已是Browse Kavita libraries/Private library；原图browse-name197-installed-001/english-browse.png，原语言已普通恢复跟随系统。已追9541bfed及原e8704217/423bd69e：PrivateSourceListItems同样仅entry.key，组件参数为当时已解析字符串。重开边界只让这四种既有私库行key包含现有title/detail/badge的呈现值，恢复同进程语言切换，颜色/几何/动作/配置/译文及源排序不改。此前名为chinese-browse的首截图实际仍书架，未作Browse通过；English及后续Chinese必须分别按当前heading/79计数等待终态。 最终两处ForEach范围Diff已审，Debug构建9.3s成功并明确覆盖安装；197普通中文→English时，Kavita行真实显示Browse Kavita libraries/Private library，3Hentai名称为现有英文，切回跟随系统后恢复中文与79启用，Root亲看原图。原主题/强调色保持。原件browse-name-private197-installed-001/{english-browse,chinese-browse-restored,appearance-restored,original-shelf-restored}.png及language-roundtrip-actions.json。只闭当前Kavita/语言往返，不冒其余3个未配置私库或缺原包的metadata导入反例。源014四文件279c601已正常推送，仅网页字段/版本/README与对应锁块，喵趣NOTICE WIP保留；源仓无Actions工作流，不冒CI通过。漫画1234身份修复已按独立人类批准完成，见对应项。

- **漫画1234章节身份迁移反例（Root/源worker，2026-10-21，限定修复已获批准）：** 本轮197按原入口仅触发一次书架更新22:43:44，完成报告75书/2更新/70未变/1跳过/2失败/459新章。真实前后library比较：DM5坂本DAYS新增第279话1ID；猎行者/comic/9330.html旧458章为/go/base64，现012返回458个/comic/9330/<chapter>.html，保旧合并后916，新增ID数458但并非新增内容。Root对458个旧标识仅解码其原漫画/章节号，与新路径一一对应、无歧义且标题亦同；不按标题或章号猜合并，未计算哈希。旧75本ID、旧章节/页面保留，reader整份及分类策略内容同前；没有手工删除或回灌业务文件。现有9a55a47a保留缺席旧章是为避免丢进度的有效决定，不能粗暴撤回。 原源011归档README要求保留网页真实/go标识，源6ffeaea恢复012仍直接输出当前href，并非本轮源代码把/go改成/comic；上游两种真实路径同存是本次重开依据，第三段10hex含义仍未知，不外推全源归一化。LibraryUpdateService.mergeSourceChapters/新增计数和MangaDetailPage.applySourceMangaDetail两处按原ID拼合共同受影响，原始数据在librarycount197-current-{baseline,result}-001/library.json，原报告及等候窗未结束记录在baseline目录；40秒观察超时只是任务仍运行，不作产品失败。本轮计数按ID的机制取得Native结果，但459不能验收为真实新章，修正和现有916条安全收敛须先完成源身份与全消费者追溯。 限定建议：仅com.mh1234.koma，在同作品内旧go严格解码形态/漫画号/章节号与当前真实comic路径精确一对一且无碰撞时关联；不生成访问URL，不改源输出，不按标题或章号猜同章。保留旧主ID、原进度/页资源/已读/下载引用；只有经全部使用者确认无独有状态的重复空记录可收敛，冲突保留不删。书架更新合并与计数、详情目录投影和普通重开共用身份结果；原459历史报告不回写，DM5真实新增1保留。现Root已查LibraryUpdateService、SourceChapterListResolver/MangaDetailModels、MangaDetailPage、SourceChapterPageHydrator及ReaderSessionStore/OfflineDownloadQueueStore的ID所有者，原调查后已按本轮明确批准接入实现。该项改变已有章节关系与可见分母，超出此前仅统计两文件批准；用户现已明确选择“实施限定身份修复”，Root按该候选实施，原报告不回写。新增共同纯身份解析、引用保护读取及下载清单元数据读取（不读图片/计算摘要）；更新计数与详情共用映射，重开仅回找精确别名，不生成请求URL。无法读取全部引用时保留重复项。受控真实916条15项/引用6项/生产服务与保存回滚检查通过，Debug签名构建成功并明确覆盖安装。197单次普通更新23:57→00:01:08完成75/0更新/72未变/1跳过/2失败/0新章；真实library仅猎行者chapters/chapterCount/updatedAt改变，916→458，原458个go章节对象逐项完整，18页资源保持；其他74本全对象、75书ID、分类策略、reader整份及88条下载队列与基线相同，DM5第279话保留。普通详情458/458与原第一话第2/16页继续入口亲看。真实cold1976→force-stop后空→9314，普通书架再开详情仍458/458/同入口；返回原Chibi第2页25%/最近阅读/首三书，Root亲看两整图。最终library/reader/queue与更新后内容相同，10000ms/AWAKE恢复并release138d7cdb；此阶段未开正文/下载/标读，不冒新正文或全部源通过。后继在Browse最终候选包上，经普通书架详情的既有继续阅读按钮，原go第一话真实第2/16页完整夜景/张百合中文正文已Root亲看；再普通返回、重开原Chibi第2/8页恢复最近阅读，未翻页/标读/下载。最终75本全部对象与更新后相同，reader仅这两本progress/chapter position内updatedAt自然变化，原go ID/pageId/pageIndex/总页数/ratio/columnMode/completed均保持，其他reader对象及88队列完全相同；原10000ms/AWAKE并release eae076b4。原件browse-name-private197-installed-001/mh1234-original-p2-reader.png与browse-name-private197-session-restored-001/。证据沿reader-failure-retry/mh1234-identity197-{baseline,result,cold,session-restored}-001；工具错误标签、ComponentData属性/底栏遮挡误点及manifest未知键均保留失败回执，未据此修改产品。原10000ms/AWAKE、原书架/最近阅读/Chibi25%已恢复并释放bcdad178，身份调查继续，无数据手动回灌。

- **咚漫015交付的既定图标比例延续（Root，2026-10-21已交付；2026-10-22纠正过期实施前状态）：** 9c03164c已只给ConciseListRow.sourceIdentityOpticalScale增加cn.dongmanmanhua.koma@0.1.5→1.08，延续f1fc2857的已审呈现；014、其他版本、30vp槽/7vp圆角/Contain及三消费者保持。源fed32c5仅补详情来源链接与014→015，当前源owner以git show直接字节比较证实icon3558B/metadata106B均与014相同，未计算摘要。既有237签名Debug16289681B覆盖安装和015普通导入回执completed；Root本轮重看dongman015-detail237-001/manager-icon.png及browse-icon54.png，紫色原图主体完整，两个列表的既有呈现成立。原webview-postflight237-001回执completed/无哈希、本人传包已清且ABSENT、原10000ms/AWAKE恢复；本轮未重构建、导入、操作设备或声称新增正文验收。该行原“实施前”已被真实提交/原件取代，不再派工重做。

- **详情网页字段静态缺口（source worker/Root，2026-10-21）：** 复用197现有79与237现有54源ID账，并集80（237独有漫画人）；197为62个links、7个顶层manga.url、10个缺失，237为43/4/7，其中漫画人首source链接为API而非作品网页，不能计合格网页。10项缺失为mycomic011、globalcomix011、manhuawu012、ikmmh010、webtoons_zh_hant011、miaoqu010、cmanhua010、dongmanmanhua014、mh160010、sixmh013；已有顶层url的HentaiHand、SimplyHentai、3Hentai、MPC、爱奇艺及Nami简/繁不误列缺口。只核实际get_manga调用输出，不联网/改包，不冒Native可用。下一包咚漫复用已有准确1954作品页父链与原fetch(path)，漫画人需原资料证明实际网页合同；403源/挑战不重取，喵趣NOTICE WIP保持。

- **图标官方大图受限项本轮核对（source worker，2026-10-21）：** ASM未发现有官方归属链的新高清原件，原49×35/扩展192及两失败生成稿不重用，官网403不重试；漫画社311s父页旧临时原件当前不存在、同名站不能证明归属；MPC仍只有既有横标，漫画160已留桌面/手机版横标且CSS403，創漫官方Facebook临时阻止/主页403，Terra既有白色字标不冒新的深色候选。这组保持OPEN，不修改资源/样式/版本，不将其作为全源停止理由；下一worker接本轮网页声明的具体业务缺口。

- **GoDa012/HKO012的237新具名正文（Root亲审，2026-10-21）：** GoDa旧011夺酒invalid_image_url后继现012，准确get_pages单次HTTP200返回70页；现装普通继续阅读真实第2/70页人物眼部/飞船原图已Root亲看，普通返回仍2/70，不冒无缓存首取、全70页或语言通过。HKO012首次普通导入53→54启用，只验第81期带空格括号URI：初始P1/P2均解码中原等待画面保留，后继两不同完整繁中彩色原图1/11太阳紫色角色、2/11新增白云均Root亲看；正常2→1→2并返回继续阅读，不冒其余9图/下载/cold。两次独立回执均AWAKE/原10000ms并release，HKO唯一传包已删除；原件category-membership/goda012-entry237-001及hko012-import237-001，哈希关闭。源README对应提交080070a已同步，原喵趣NOTICE WIP保留。

- **继续阅读卡长章名遮蔽进度（Root，2026-10-21，限定路径已验收）：** 最终sourceorder-web197-final-cold-001/final-original-shelf.png实际副行只剩“继续阅读 Chibi…”；第2页/25%被同一行Ellipsis挤掉。这也是既有未闭条目，不把原书架状态恢复当整页视觉通过。已追初始ac7e3469将章名排页码前、773b8187改三语键、7cdb3f6e只为技术章名保留page-only，未查到刻意让长章名优先于进度的直接人类决定。4c7fa41d批准的卡片几何/边距保持。全部消费者：生产createLibraryViewModelFromComics→formatContinueDetail→LibraryPage内ContinueReadingShelfCard（网格/列表共用）；同键的旧formatContinueReadingDetail也需保持参数顺序，当前未查到生产调用。推荐仅将三语library_progress_continue_page改为中文“第 %s 页 · %s% · %s”/英文“Page %s · %s% · %s”，两处既有替换链按page/percent/chapter顺序；无进度、技术章名page-only及其他格式不改，字体/单行/省略号/卡片/封面/内外边距/进度算法保持。示例改前“继续阅读 Chibi…”→改后“第 2 页 · 25% · Chibi…”。用户已明确选择“进度放前面”。两处换参及三语键已实施，i18n三语键集/重复检查通过，Debug构建成功；22:29:30签名16289728B已197明确覆盖安装成功。原书架网格与临时列表均实际显示“第 2 页 · 25% · Chibi Son Bra did her best!”：Root亲看两张整图，页码/百分比完整、章名末尾省略，原卡片/封面/首三书/最近阅读保持，列表检查后恢复原网格。未打开章节或导出私有状态，不冒全库逐字段相同。原件continue-progress197-installed-001内ordinary-card-actions、layout-consumer-actions及具名整图。后继英文实际显示“Page 2 · 25% · …”，Root亲看整图，原语言跟随系统已恢复并读回；初次驱动导入名错误在设备前退出、随后设置首页Library同名歧义停在断言，后按唯一底栏边界续接成功，未据工具错误改产品。范围提交cd669237已同步master，CI39618267262已completed/success。后继单次更新反例见本节；197原10000ms/AWAKE已恢复且bcdad178已释放。

- **源列表名称顺序与详情网页入口（Root，2026-10-21，具名路径已验收）：** 本轮用户明确要求源列表固定顺序（名称或可选排序），漫画详情右上角新增WebView与浏览器入口，并移植NextE带控件的WebView。当前Browse.enabledRuntimeSources自9541bfed、Manager.reload自668d5ea沿注册顺序；未查到名称顺序的既定要求，原更新保位是注册存储语义，保持不改。允许差异：两处安装源及可用索引展示共用名称比较、同名ID固定次序，只改展示投影；私库分组/启用/包更新持久顺序不变。本次采用用户给出的固定名称方案，不增加偏好项。详情菜单沿56f1bd0e的根HdsNavDestination/route-local chrome桥；新增两个网页动作，源提供有效HTTP(S)网页时启用，不拼内部ID。NextE EhWebView及GalleryWebPage完整父树已核，保留通用Web封装、List滚动所有者及标题栏后退/前进/刷新，去除EH账户/UA专用行为。独立网页链接保留在元数据/当前进程快照，不改变原请求url用途。官方知识MCP本次传输失败，平台接口以本地API参考及NextE当前实现核实。 最终实现为共用名称比较器、同名ID保序，两处安装源及已加载索引只排序副本；请求url不改，独立webUrl消费links.kind=source并经列表/详情/快照保留，私库feed/download路径不据此当作品网页。受控执行实际生产解析/快照/比较器覆盖缺失/非法/来源优先/无输入突变，详情实际方法覆盖私库排除，原route title检查与三语parity通过；最终Debug构建成功，22:05:25签名16289732B已197明确安装成功。Chibi普通详情两菜单真实显示，WebView作品页→封面页内跳转→后退/前进/刷新→原生详情仍2/8，菜单可重开；系统浏览器实际前台window36/browser0并显示同作品页，首截图白页后等待真实DOM再取终态，原图均保留。浏览器自身Back先回其首页，不冒直接返回Koma；普通App切回仍Chibi2/8。xkcd现014缺链接由源015补声明https://xkcd.tw/中文集合首页（非作者官网/单篇），197普通014→015后两菜单出现，最终App实际显示「首頁 - xkcd 中文翻譯」并自然返回原2937/1/1。最终不清数据cold28469→空→32991，Browse/Manager首8同序及79启用、xkcd菜单持久；原最近阅读/Chibi25%/原首三书恢复，Root亲看原图。首次选择器误把「已安装阅读源」写成「已安装源包」，以及原生菜单/系统picker父子重复文本、picker需完成确认，均保留失败原件，未据这些工具错误改产品。只关闭具名路径；其他无网页字段源、索引下载/全79正文/全App不据此通过。原件sourceorder-web197-{installed,final-installed,final-cold,session-restored}-001，全部产物哈希关闭；只移除本轮唯一xkcd015传包，原10000ms/AWAKE已读回。该提交53cbc39a已同步master，精确CI39616247862已completed/success。继续阅读卡后继批准与结果见上条；worker接更多真实网页元数据。



- **SixMH013图标呈现保留：** 013与012为同一原图资源，本轮仅给com.sixmh.koma@0.1.3延续原1.05缩放，槽/圆角/其他源不改。最终16230370B包已237覆盖安装，Root亲看sixmh013-final-icon-{browse,manager}237-001两原图，完整标识可辨，无可见裁切/彩边；最终Browse/10000ms/AWAKE并释放ce678c61。不冒197对应列表或源全正文通过。

- **197当前快照真实恢复修复（Root，2026-10-21）：** 本轮1792584275735预览75书/86进度、88下载、79源包、50设置、新增0；用户明确允许后执行整份恢复。原进程19357在prepared→committed/import_json后退出，系统THREAD_BLOCK_3S；不清数据重开后原消费者存在，但成功提示未出现，原失败保留。临时计时定位文档解析202ms、79源包验证8702ms；原base64ToBytes自bfd55621逐字节访问原生Buffer。整块Buffer复制的Host检查虽过，实机报backup_import_failed，该候选已撤回。最终仅改用util.Base64Helper.decodeSync，字节数/图标/清单/身份及恢复事务验证保持；实机同快照验证262ms，约4秒出现“备份已导入”，进程53185存活。5行临时计时全部移除，最终Debug16230370B/20:36:24安装明确成功，进程55912；普通书架原Chibi25%/最近阅读/首三书、历史Chibi2/8与xkcd2937、下载88章2297/2297均亲看。仅经准确名称确认删除本轮1792584275735，原四备份1792170707289/1792170162766/1792166507105/1792011739954逐名保留。原10000ms/AWAKE读回并release3c78a12e，哈希关闭；原件backupfresh197-{import-exit-diagnostic,import-exit-cause,reopen,diagnostic-installed,bulkcopy-installed,bulkcopy-log,nativebase64-installed,nativebase64-log,clean-installed,session-restored}-001。只闭该快照成功恢复与具名消费者；失败回滚、其他备份/跨设备未因此通过。后继真实cold55912→空→887，普通历史原Chibi2/8与xkcd2937、下载88章2297/2297、服务79源包及管理首屏图标读回，Root亲看原图，最终原书架/最近阅读恢复；10000ms/AWAKE并release2a5bae4c。原件backupfresh197-cold-{wake,unlock,reopen,session-restored}-001，重开目录内ordinary-consumer-resumed-actions.json。首次误把完整“排序 最近阅读”写作“最近阅读”导致选择器超时，原失败图实际排序正确，未据此改产品。修复cdca787及图标兼容0eee60a已正常同步master，精确CI39603410133 success。

- **ASM高清候选本轮未采用（Root，2026-10-21）：** 官网原49×35与既有扩展192参考已亲看，原两稿因字形/透明脏边拒绝保持。本轮按现有资源重建授权再取得一稿及其限定alpha修订，两稿的AH空隙/轮廓仍有白色杂点，均失败；未写入源资源/版本/产品包，不把生成动作当修好。自动原件留在/Users/honjow/.codex/generated_images/01a11fb1-9f44-7123-8590-b6e849190eab/exec-efd43010-261b-4eb3-ac0a-861e6a56aa54.png及exec-2b2faa9f-06b7-4857-8b27-d102523d068f.png，不新建归档/脚本。官网403不重取，App槽/圆角/顺序保持；此处旧失败稿仅作历史拒稿；已被用户后继批准的ASM011字标交付取代，不再调度重建或重试同类缺陷稿。

- **Laya012首正文与首6封面（237，Root亲审）：** 原237未装，沿现有正式85580B包普通选择器首次导入成功；GUI52→53、新增末项在老夫子后，未切其他源启用，未私有导出，不冒原52持久对象逐项相同。精選漫畫首项最常被問/ch-0001.jpg→一章一页→开始阅读，真实繁中彩色四格1/1、21:17:36 display_ready/display_complete已亲看；自然Back详情为继续阅读。21:15原首6占位至21:19自然返回同屏6封面真实显示，未点击重试；下缘第3排左侧仍占位，不冒12张/全80项或稳定性通过。较早2300028/2300055无准确图像关联，末次有界CachedCoverImage日志为空，旧010500原因不猜。App现有CachedCoverImage→SourceAdapter解析imageRequest.headers→NetworkKit header原链已核，没有静态丢UA/Referer证据，不据此改App。原件category-membership/laya012-picker-entry237-001/{first-reader-after6s,natural-return-gallery,natural-return-detail,browse-count53,final-browse-restored}.png及具名actions；日志laya012-reader-log-restored237-001。正确传包已单独删除/test不存在；原10000ms收尾日志跨超时自然SLEEP后，最后laya012-final-awake-restored237-001重新完整门禁读回AWAKE/10000并释放，b7f3ed3e与678cfe5d都已release。只闭具名首篇/6封面/普通返回；无下载/cold/额外源请求，源码/图标/版本不改。

- **197手动单章读态联动有限结果（Root，2026-10-21）：** xkcd2977原在已读5/676，普通长按标未读后就地移出、已读4/676；切未读后672/676且准确该章黑字可见，再普通标已读后移出、未读671/676；切已读恢复5/676与该章灰字。原全部676/676、降序恢复，未开章/下载，详情继续原2937第1/1页；普通历史仍Chibi2/8及xkcd2937，书架仍原Chibi25%/最近阅读/首三书。Root已亲看三张原图及历史；未导出私有文件，不宣称全库内容相同或cold/失败回滚通过。原件chapterread197-wake-001内manual-read-actions.json及具名图/布局。最初精确匹配遗漏“章节 (...)”完整文本而超时，后实际页已加载；未据该脚本错误改产品。

- **197恢复确认取消有限结果（Root，2026-10-21）：** 原四个本地文件保留，普通打开准确1792170707289（v3/未加密/74书/76进度）后，确认弹窗明确新增0书、覆盖74书、新增0进度、覆盖76进度，并说明整份替换、不逐项合并。仅点“取消”，未触红色恢复动作；Back后四原文件1792170707289/1792170162766/1792166507105/1792011739954逐名仍在，再回原Chibi第2页25%/最近阅读/首三书。Root亲看确认与最终书架原图；本轮没有创建/删除备份、执行恢复或导出私有数据，不能宣称整份数据相同或恢复写入/回滚通过。原10000ms/AWAKE读回，49882772已release，哈希关闭；原件backuprestore197-wake-001内existing-preview/restore-confirmation/four-files-after-cancel/original-shelf-after-cancel及backuprestore197-session-restored-001。导航误把备份设置子页当管理页、重复标题断言及设置行/底栏同名书架选择歧义均停在断言处，后按当前真实层级/唯一底栏恢复；未误称产品故障或首批全程通过。

- **197方向与显示消费者有限结果（Root，2026-10-21）：** 原Chibi第2/8页、纵向分页/左右分区/水平翻转不变，仅经原菜单临时选从右到左；右侧点2→3、左侧点3→2，Root亲看对应不同正文及页位。普通返回再重开，原菜单“恢复默认”清除此书临时覆盖，画面恢复从左到右且无本书标记。随后原“显示页码/全屏”均true临时关false，收起chrome后实图无页码、系统状态栏保留；再原入口恢复两项true，实图显示2/8且状态栏隐藏，普通Back回原第2页25%/最近阅读/首三书。原10000ms/AWAKE读回并release0ffa98fd，哈希关闭。首文字选择器因MenuItem及子Text均叫从右到左得到2匹配而停止，未改偏好；按当前唯一可见MenuItem边界恢复执行，失败JSON保留。仅此具名路径，不冒其他模式、方向cold或全库持久相同；本轮无私有数据导出。原件reader-direction197-wake-001、reader-direction197-menu-discovery-001内方向/显示原图与actions JSON、reader-direction197-session-restored-001。

- **237 BNS011两单元有限结果（Root亲审）：** 《慟哭的星》第1集comic2为1/23、2/23真实繁中彩色正文，第2集comic3为1/35、2/35真实繁中彩色正文；各自然Back详情仍显示本集第2页。原件沿category-membership/bns011-comic2-*及bns011-comic3-*；长条在当前模式居中呈窄栏，未外推完整阅读体验、其余页、下载或cold。两会话恢复Browse/10000ms后release；私有文件导出被自动审批拒绝且未执行/绕过，没有全库内容不变实读证明。导航误入包子的source_runtime失败另保留，不判BNS失败、不重试。两段README已范围提交a4ca19e并正常同步源master，喵趣NOTICE原WIP保留。

- **197保存/分享取消有限结果（Root，2026-10-21）：** 普通阅读菜单保存当前Chibi2/8，系统展示“允许Koma保存1张图片”及真实当前页预览，仅点“禁止”；随后分享预览显示同页438.24KB，未选收件App，普通Back取消，最终Back回原书架。Root已亲看save-dialog/share-preview/share-cancel/session-restored整图。share-cancel原图底部仍有面板退出边缘，不能冒完整动画无异常；最终原书架Chibi25%/最近阅读/首三书可见。未保存相册、未对外发送；本轮未导出library/reader，不能宣称全库持久内容不变。原10000ms/AWAKE已读回、83b476ac已release，哈希关闭；原件沿reader-failure-retry/reader-systemimage197-{wake,chrome,more-menu,save-dialog,save-cancel-menu,share-preview,share-cancel,session-restored}-001。

- **197原生捏合有限结果（Root，2026-10-21）：** 普通继续阅读Chibi2/8，既有全局纵向分页/原比例保持。首用全屏reader_key_surface的Component.pinchOut(2)可放大，但pinchIn(0.5)返回书架，最终页码断言失败，原三图/失败JSON保留，未据此改App。上游GenericPinch源码表明收拢从组件左右边界内40px起步，当前全屏即x40/1220；与系统侧边返回的关系是有依据的解释，未取本机原生注入轨迹，不冒精确系统因果已证。改用同一官方PointerMatrix API，在内容内x330..930/y1360、双指起距300→600→300执行原生张合，Root亲看放大与还原原图，最后同一2/8仍在。仅此当前模式/页面中央两指功能闭合，不冒边缘、所有模式或动画全帧。语义适配器前后台资源均完成清理，无新脚本、无产品/技能代码修改。普通Back后原Chibi25%/最近阅读/首三书保持，library内容相同，86progress/142chapter记录仅该书updatedAt自然变化，原页ID/页码/比例/columnMode均不变，其他对象保持；AWAKE/原10000ms读回并release a53f9ced。原件reader-pinch197-{original-page,reopen-original,session-restored}-001，其中native-actions.json保留首失败、native-inner-actions.json保留完整两指坐标，哈希关闭。

- **237本轮源边界（Root亲审，2026-10-21）：** 漫画人011热门HTTP200后permission_denied，现源码code40011单独映射匿名会话要求；独立“一拳超人”搜索HTTP200与至少六个可见标题/封面已Root亲看，详情/目录/正文匿名建号POST未执行。老夫子010普通新增后52源，25本目录但#2518详情14:49:31实HTTP403，失败图/原码已亲审，未重试；图标/目录不冒正文。BH3012《逃离长空篇》7/7章，第一话bh3ch:1001:2 P1/27扉页、P2/27“香港中环/好美的夜景”正文亲看，Back后真实pageIndex1/27自然落盘；原reader43progress/17sourceHistory/54chapter对象全部保持，仅新增本书progress/chapter各1，52源完整内容同原。具名恢复回执manhuaren011-search-session-restored237-001、oldmasterq010-session-restored237-001、bh3012-session-restored237-001均10000ms/AWAKE且租约释放，哈希关闭；四源README本轮83fcc98，喵趣NOTICE原WIP保留。现图标表本轮未取得可采用新官方资产，XComic官网单次403新增边界不外推其独立API；其余具体限制依原表，不冒全量图标完成。

- **197手动更新的新章少计反例（Root，2026-10-21，修正已获本轮明确批准）：** 普通设置手动触发14:44:07.903→14:46:59.959，75本/4更新/69未变/1跳过/1失败，当前报告9新章。前后真实library按章节ID集合对比，WEBTOON Meme Girls新增1、DM5恶女新增7、Komiic1936新增1、漫画160风起苍岚新增1，共10；后者原782行含2个重复ID，本轮去重并加1后781行，净条数-1被现算法计为0。75本ID、各本原有唯一章节ID及原pages/pageCount/sourcePath/createdAt均保留，reader整份内容相同；原书属性/分类及根设置保持。唯一失败Kavita network_error，与原服务缺失条件相符，不判全源失败。原图/回执沿reader-failure-retry/libraryupdate197-{baseline-settings,manual-start,request-progress,result-report}-001。 后继真实cold63596→空→59383，经普通设置重开仍为2026-10-21 14:44及75/4/69/1/1/9；更新后的library与reader均持久保持。当前完整书架原Chibi25%/最近阅读/原首三书与10000ms/AWAKE已亲看恢复，9ec已release；新增实际章节保留，不回滚正常更新。 后继普通详情实际783/783且新353话可见，保存目录仍781个唯一ID；两组相同path标题各不同（306/305及35/34），不能猜同实体或删项。源调查现原路径身份/保序来自bcfb926，单次公开Host详情403已停，暂无成功原HTML可绑定实体，源输出不改；与本轮纯计数修正分开。定位前一次滚动未稳误入魔法纪录，未阅读并已普通返回；最终75本对象与reader原内容保持，临时标题排序恢复最近阅读，10000ms/AWAKE恢复并release e497。
- **计数修正追溯与本轮批准范围：** ed4eb576引入按总数差计算新章；cc7d482e扩到来源摘要；9a55a47a明确保留缺席旧章并对远端ID去重，后续恢复未改该计数。当前两拟改生产文件无WIP。新实际反例重开的是新增计数，不撤销原保留旧章/去重规则。建议仅在LibraryUpdateService源结果增加可选addedChapterCount=本轮新增唯一章节ID数；统一计数方法供总数/来源/现有通知/偏好共用。LibraryUpdateResultStore的clone/序列化/读回复用这一可选数；旧报告缺字段仍按原差值读取，不猜修历史。原previous/new总章节数、章节合并、行内前后数、文案/布局/尺寸/通知偏好均不变；本轮实例新报告应计10，160来源计1。用户当前原文答复“修正新章计数（推荐）：按实际新增章节计算”，两文件现已实施。Host实际生产Service用本轮原始前后数据回放4本，10新ID/160来源1、通知/clone/序列化读回均10，旧无字段结果仍9；原ID/页面资源保持。原结果outcome与coordinator两既有检查通过，Debug构建退出0，签名包16230238B/15:48:38。首次Host通知替身缺format失败后只补替身，未据其改生产；后续整套通过。197已实际覆盖安装成功，经普通设置→书架→更新报告重开，旧2026-10-21 14:44报告仍为75/4/69/1/1/9；本轮安装前后及最终恢复的library/reader内容均相同。Root亲看legacy-report与session-restored整图，原最近阅读/Chibi25%/首三书和10000ms/AWAKE恢复，旧596bd0c9与接续163181d0均已释放。原件libraryupdate197-count-repair-{wake,installed,legacy-report,resume-wake,session-restored}-001，哈希关闭；源码两文件已范围提交1150724。原摘要误将15:43恢复当作15:57安装后恢复，当前以16:31新回执替代；不能把Host回放冒Native自然新增章验收。

- **本轮197图标集成有限结果（Root，2026-10-21）：** HentaiFox011现包1.04比例在普通Browse/管理均亲看完整；原书架与reader JSON内容逐项相同，原10000ms/AWAKE恢复。随后漫画柜从原第10项013普通系统picker更新014，管理/Browse头像由原30vp/7vp容器定义边界，79项sourceId/enabled顺序逐项相同；未打开正文，书架/reader JSON内容仍逐项相同。唯一自传014文件已移除并断言不存在，10000ms/AWAKE恢复，20f9f9c5/37346c68两租约均release。原件reader-failure-retry/icon-optical197-{hentaifox-browse,manager-seek,session-restored}-001与manhuagui014-integration197-{before,import,manager,browse,restored}-001；无产品源码变化。分类滚动50c8bf73的CI39547134056已completed/success，不冒首版整体通过。

- **本轮实际接续结果（Root，2026-10-21）：** 漫小肆197从011普通更新013，原第27项及79项sourceId/enabled顺序保持；同进程普通热门真实10本及封面已亲看，无需冷启才生效。后继源内“美麗新世界”搜索返回准确作品及封面，详情高孙志/262章，Back保留原查询/结果；原reader/library内容保持、10000ms恢复并释放2fca86ac。证据mxs013-search197-{query,detail-ready,return-query,restored}-001，源记录已随863cf46同步。本轮未开正文/下载，返回后书架及reader JSON内容逐项相同，唯一自传包移除断言及10000ms/AWAKE通过，c4ad0428已release。证据reader-failure-retry/mxs013-integration197-{downloads,import,browse,popular-ready,restored}-001。Terra017的7746/8623第2/58黑白中文正文及回1/58已亲审，完整50项registry与globalcomix011-titan-session-restored237-001内容相同，原超时/页位恢复。ComicABC现装**0.1.10**（由registry实际读回，不用010文件名前缀猜为0.1.0）的30513第4话2/27原图已亲审；源owner429前已普通恢复原第5话1/24，Root接管重新门禁后返回原Browse末端，50项完整registry保持、10000ms/AWAKE恢复并release cdda07c3；不冒在线首取/全章/下载通过。证据category-membership/comicabc010-{ch04page2-30513237-004,restored30513237-004,root-session-restored237-004}。另亲审现存NamiComi011“我是 赛拉”唯一作品/真实封面原图namicomi-hans-search-result237-001，取代旧笼统“搜索未过”，旧197失败原因仍未知，不重跑。

- **详情首次阅读返回刷新（Root，2026-10-22，已实现并197限定验收）：** 237前置majsoul011-session-restored读档无蔚蓝进度，bluearchive010读第15话后实际会话已有1/1，但natural-return按钮只有“继续阅读”、无章页；197原书架蔚蓝已有第14话进度，普通详情立即显示该章及第1/1页，反例不是所有详情均失败。原2d117583提供章页文字、254052c1保持紧凑同按钮排布；c99cc360当前currentReadingProgress读取非观察Store但不读取readerProgressRevision，首次无进度会提前返回，不订阅chapters；e197d63e的revision只在monitor刷新章列表。LibraryPage.gridProjection在de959210已用void this.readerProgressRevision显式订阅同一普通Store。限定候选仅在MangaDetailPage.currentReadingProgress入口加同样一行依赖，使原按钮在已有revision变更后重读当前进度，所有源/本地共用，不写数据、不改样式属性、不改原章节选择规则。本轮用户已明确选择“修复即时刷新”，上述一行已实施并随同签名包覆盖安装197。普通书架搜索书虫（原无进度）→详情“开始阅读”→第1话爱的故事真实黑白叙事P1/49→自然Back，原同一按钮立即显示“继续阅读 · 第1话 爱的故事（49P） · 第1/49页”，没有退出详情重进，Root亲看前后及正文原图。原Chibi继续仍2/8；普通重开未翻页再返回后书架继续卡为原25%，最近阅读排序保持，书虫新增1/49读态与搜索词作为本轮真实操作结果保留，不能称原首三顺序或全部业务内容相同。只闭这条首次阅读返回显示路径，不冒所有宿主/源通过。原件search-origin-resume197-installed-001内上述具名PNG、实际已保存的对应布局及first-read-natural-return-actions.json；最初标题与搜索输入同名造成重复选择器停步已保留，不作产品故障。最终search-origin-resume197-session-restored-001读回AWAKE/10000ms，release53d570b3；未清数据、未导出或写回私有业务JSON，哈希关闭。

- **长分类名滚动已实施并限定验收（Root/197，2026-10-21）：** 用户明确选择滚动取代未提交Ellipsis。沿0790b3b4原分类Text与唯一网格消费者，仅加原生MARQUEE/step0.5/loop-1/delay1000/fromStart/fadeout false及可取消的1000ms初次启动等待；原20vp高/左右8vp/字体/颜色/圆角保持。初版25秒原片category-marquee197-recording-001已见全名及再次进入、短名收藏静止，但初停只有约0.4秒；补修当前Debug16226877B/12:06:09后，category-marquee197-initial-recording-002的410原帧/PTS显示约0.64秒出现、约2.1秒开始移动，可见初停约1.4秒，短名始终静止。第一次补验启动导航落电话页为失败且书架完全未变；单独确认Koma前台后才继续。两轮测试归属/唯一空分类已准确清理，75本业务字段逐项恢复，仅两本updatedAt正常保存变化；AWAKE/原10000ms恢复，租约94fc2fdf已release。源码和本条已随50c8bf73范围提交同步，CI39547134056成功；非首版整体通过。

- **当前反馈图标比例结果（Root，2026-10-21）：** 用户明确授权漫画柜及偏小图标适当调整。f1fc285仅对源ID@版本绑定Image.scale：漫画柜013 1.10、鸟鸟011 1.30、瓜子013 1.20、雀魂011 1.15、咚漫014 1.08、HentaiFox011 1.04、六漫画012 1.05；未来版本/其他源默认1，三消费者共用，30vp槽/7vp圆角不动。e0d797d7/ecbfeac8原槽与圆角历史已查，72d7e0f4撤圆角仍为拒绝方向；MangaBall横标不为填高裁两侧。漫画柜用户后继明确要求改掉后采用512px满幅头像，源014/73ecf4b已同步并由Root亲审237管理/Browse；014默认比例1，不额外加底色。鸟鸟011及四现装（瓜子/雀魂/咚漫/六漫画）管理/Browse原图Root已亲审主体完整，原件optical-four237-*；50项sourceId/enabled顺序保持。237未装HentaiFox，不为此新增导包；HentaiFox011在197当前包的1.04比例已补验两消费者，见本轮结果；其余既有缺图/低清/横标项目仍按原表OPEN，不冒全量图标完成。素材本身未新增板/影/遮罩，鸟鸟生成候选未采用。


- App已授权下一动作（Root/197）：通知发布/点击已闭，见本轮结果；多书分类及移动替换已闭，不再把旧下一项当待执行；双击缩放的本次具名路径已闭，不重跑；跨书零新增确认本轮已闭。本地根重选保留未验：实际仅Nemo公共根与旧Local Folder Smoke私有根，原1需重选样本对应后者，系统picker不能选择App私有目录；目录本身仍存在，不能冒缺失，也不盲选Nemo或制造新授权失效夹具。私库浏览→详情→阅读/返回仍未闭，Kavita原25610无监听且旧bind目录缺失的具体条件保留，不能只因轮到它就反复重试或停止全线。分类、语言、下载筛选等具名已通过路径冻结。
- 源已授权：ComicABC30513第4話在线1/27已具名补验；全量图标未闭项、既有源阅读失败及中文新源质量继续保留；原成功只绑定原版本/作品/章节，图标/列表成功不计正文通过。当前图标表中的MangaBall24px已被011交付取代，其余缺图、横标小槽及受限父链依各自条目保持。
- 旧待答调度已被后继人类决定取代：本书模式即时刷新与下载/重试文字已由e2f1a411具名关闭，普通Shared已由44a86da1及197入口验收关闭，HComic提取已由012/3fda006及237验收关闭；不再等待原答复或重派这些项。
- 初步日用交付链：当前8307106B签名Release已接普通Shared，具名197普通入口/返回已有结果，源库全部85项远端构建及固定索引发布成立，本轮两新包下载已独立复核，用户README已包含源库和固定索引。本轮交付链闭合；下表自然失败、外部授权、系统调度及Tracker条件仍按原范围未验，四私库由用户搁置，不将本轮结果扩大成全部功能/全源正文或正式上架保证。
- **本轮缩放有限结果（Root/197）：** 原继续阅读Chibi第2/8页，双击实际放大、再次双击恢复同幅原比例，三份布局页码均2/8，完整原图已亲看；Back回Chibi25%原书架。未改偏好/模式、未翻页，不冒pinch/动画全帧或其他模式。证据reader-zoom197-{original-page,double-tap,double-tap-reset,restored-library-session}-001；最后AWAKE/原OverrideTimeout10000ms读回并release原租约。
- **本轮新增有限结果：** 197跨书多选的实际Checkbox为Chibi/虫笼，下载全部提示2书/2章/新增0/已下载2跳过；仅点零目标提示的确定并退出选择，未触入队、下载或目录刷新。Root亲看整图，证据library-batch197-{two-selected,existing-download-confirm,dismissed-original-shelf}-001；不冒存在新任务时的取消/入队及失败回滚。当前本地目录只读快照为local-folder-reselect197-root-snapshot-001/library.json；原两次grep因设备shell二次解析失败，不算读取成功。仅保留此有限身份调查，不改原根或删除旧记录。
- **当前证据与失误结论：** 用户19257.png是实际反例。原197 single-failed的Text和Button边界都为[588,1373][673,1423]；bc122397初始自定义Button/Text没有内边距，f55a18e0搬移时照搬。此前验证只覆盖停圈/失败文字下方/实际重试，漏看文字贴边；该按钮外观通过结论撤回。Root把这次明确缺陷又变成额外确认、随后转到源线，导致App动作搁置；源代理异常不再触发Root换线。验收必须先完整看实际原图中所有可见问题，再核行为；命令成功或存在一张图不等于视觉通过。
- **漫小肆013有限验收已闭并同步3daaac6：** 当前总榜/旧人气榜及jjmhw10/旧9原URL兼容，归属/遍历校验保持；237热门10本封面、281美麗新世界262/262章、9821第1話P1/P2及返回2/60、单章downloaded60/60，PID52557→空→3307后仍P2/60。Root已亲审原图及回执；长条原图在现有阅读模式下呈窄栏，不把两页能解码冒成所有屏幕/模式阅读体验通过。48源ID顺序/启用保持，只清自传013包、恢复原10000ms并release。原011/012热门及013发送不存在文件的失败记录保留。证据为category-membership/mxs013-*237-002，源README留具名边界；正文/搜索/全站不外推。
- **已完成并冻结的本轮结果：** MangaBall011源8f811bd已同步，237管理/Browse两原图已亲审；197六漫画012/NH.xxx012/优酷013/NN011/漫小肆011/MangaBall011普通导入及两消费者已亲看，原79项sourceId顺序和enabled逐项保持，六个自传Download包已清，原书架Chibi第2页25%/最近阅读/首三书与10000ms超时已恢复，5a9ecb4e已release。仅这些图标消费者关闭，其他缺图/低清/小槽继续下方既有表，不重跑已通过路径。
- **NN011新增具名结果已归档到原README并同步f3a3d09：** 237热门100/Setup唯一搜索/117章，首章68359 P1→P2/54，普通下载54/54；Root接429后未重复下载，亲看原件并取得38232→空→52557，不清数据Library继续仍真实P2/54。正常样本下载/收藏/进度保留，原10000ms恢复并release9ac。只闭这个标题/章及cold，不冒全54张逐页视觉、其他书或禁网离线。
- **旧按钮阶段的待决定项已收口：** 本书标记/恢复默认入口、普通Shared、HComic及下载/菜单文字的后继允许与完成情况见顶部和上述收口行。这里不再形成待答队列；按钮f4afaf3d及旧CI事实保持，不由这些旧标签中断当前交付。

- **197本轮通知闭环：** 原通知关闭，普通系统请求临时允许；详情“下载章节”实际下载最早章xkcd《1: 桶子之一》（不是2977选择器），完成1/1。Home后通知栏真实显示完成/标题/页数；点击进入下载管理89章2298/2298页，Root亲看完整两图。仅经该章准确名称确认移除后恢复88章2297/2297页。仅Koma系统通知恢复false，App再实读关闭；普通返回原Chibi2/8书架。首次关开关仅收起系统说明浮层，读回true后重试才false，未冒首次成功。原图/布局沿reader-failure-retry的notification197-published-001、click-downloads-001、original-downloads-restored-001、permission-restored-002、app-status-restored-001、library-restored-001（全部带notification197-前缀），回执哈希关闭。不冒cold通知/后台执行/全队列通过。

- **197两书分类有限闭环：** 唯一本轮Koma-QA-Batch-1021空分类创建后，多选Chibi/虫笼只加入此新ID，两处标签更新，普通分类筛选仅两本。Home→force-stop得到38924→空→4949，不清数据普通启动仍为同两本/同标签。再多选仅移出该新ID，筛选实为空；准确名称确认删除0本测试分类后“暂无自定义分类”读回。原筛选全部、最近阅读、Chibi2/8及首三书Chibi/xkcd/虫笼实际恢复；原10000ms/AWAKE读回并release。只关闭两书增删新分类/筛选/cold，不冒替换原分类或自然保存失败回滚。表单输入使页面滚动，首下创建坐标未命中；当前按钮再保存才创建，未误报首下成功。首次清理读回排序仍最近加入，被拦下后恢复最近阅读，未以该帧当原状态。原件为reader-failure-retry/categories197-{created-002,two-selected-menu-001,two-visible-001,cold-001,empty-after-remove-001,own-deleted-001,final-original-state-001}。整图当时另发现长标签截断；此处Ellipsis旧计划已被用户后继批准的滚动显示取代，50c8bf73及本页“长分类名滚动已实施”记录为当前结果，不再从本行调度省略号或重测。

- **本轮跨书入队与有限后台事实（Root/197，完成限定路径）：** 当前队列88条基线无排队，普通选择序言组曲0694及Nami繁中73hLs8EN，确认2书/6章/新增4/跳过2，实际92条中仅新增01呼吸、02心跳、Ch.2、Ch.3。首次Home写成HOME被平台Invalid parameters拒绝，原图仍App前台，不能当后台通过；后沿已验证Home取得真实桌面，12秒后台只读队列01呼吸由4/43到6/43，返回App继续8/43，Nami两章已15/15及20/20。原件crossbook197-{queue-baseline,new-target-confirm,new-queue,background-progress-001,background-progress-002}，哈希均关闭。下载管理标题页数被省略、未知页数排队章0/0仍属未改善呈现，不冒整页视觉通过；四新章最终02心跳50/50、01呼吸43/43、Ch.3 20/20、Ch.2 15/15，共128页；总92章2425/2425。逐章菜单核准确名称后只删除四新增，原88条全部字段及偏好按内容比较相同，恢复2297/2297；原网格、最近阅读及首三书已亲看。完成/逐项删除/恢复原件沿crossbook197-completion-observe-001、own-*-delete-confirm-001、restored-original-queue-001、shelf-restored-001。不把下载完成冒四章正文目视通过或全部后台存活。

- **本轮多书分类替换（Root/197）：** 精确Chibi/虫笼原分类均无；普通加入favorite和read_later后两书均有两标签、持久文件均同二ID。再普通“移动到收藏”，两书只余favorite，read_later实际移除；最后仅对这两书清除本轮归属，现有全部作品分类字段逐项恢复原值，原进度/网格/最近阅读及首三书亲看保持。10000ms/AWAKE读回并release。首次把加入后快速重选当连续路径，实际误入虫笼详情，未冒加入稍后成功；Back后按真实UI/文件确认仅favorite，再完成上述路径，失败原件保留。本条接受替换与持久文件结果，未重跑cold或注入失败。原件categorymove197-{two-memberships-001,recover-current-state-001,two-memberships-002,replaced-favorite-001,original-restored-001}。

- **Noy012失败原码历史定位（当前已由013后继取代）：** 原App只保留泛化source_runtime，本轮两文件仅增加安全token、HTTP状态和数值平台码日志；没有URL/正文/异常原文。实际transport回调离线执行确认200/403/network_error封套保持、非法请求不联网且日志无敏感标记；Debug构建成功，Hvigor自动签名HAP16223299B/06:04:34。旧sign.py仅签名尝试因旧材料路径缺失退出，未改安全/签名材料，未使用它安装；实际237安装的是上述当前自动签名包，明确成功。一次普通Noy入口06:08:05 get_listings→06:08:06.783 HTTP405→06:08:06.888 error=client_error，Root亲审noy012-diagnostic-single-entry237-001/run-metadata.json。首编译因局部errorCode同名失败，改局部变量名后通过；失败未触设备。不把日志修补或HTTP非403当源可用。本条012停点已被源master5360c4b/当前013取代：Root核当前README及原提交，普通237于06:18:42 get_manga_list HTTP200后auth_required，仅精确status=login映射；当前是账户边界，不能继续按405派修，具名原件noy013-popular-{entry,auth}237-001。

- **自动备份自然到期前台闭环（Root/197）：** 原关闭/每天/保留5，原四文件保留。普通开启后Home再返回App，日志auto_started reason=due→export_json→local_export→auto_export，生成1792537900263，管理显示20MB/未加密与新运行时间。恢复关闭，仅准确文件确认删除本轮生成物，原四文件名逐项相同；10000ms/AWAKE并release。页面返回计数短暂5后稳定4，现存onShown刷新有效，曾过早猜测刷新缺陷已撤回，未打补丁。证据沿reader-failure-retry/autobackup197-{foreground-due,due-result,files-and-setting-restored,return-settled,session-restored}-001。只闭自然到期前台生成，不冒恢复写入/全后台调度。

- **漫画柜首卡占位诊断（Root/237）：** 原manhuagui013-popular237-001首卡占位保留；同合同单次Host准确URI200/13888B仅证明该宿主请求成功。07:27普通Browse再入现装013，热门42本首屏六张含鬼灭均可见，当前有界日志仅列表HTTP200，未捕获首次HTTP/解码失败码。原因未定、未改代码/素材/缓存，不由Host成功认定App缺陷，也不把重进成功称修复。原图manhuagui-cover237-terminal-001，已返回原Browse末端并读回10000ms/AWAKE释放9bd7807e。

- **下载暂停/恢复限定闭环（Root/197）：** 原88条全downloaded/2297页、并发1/isPaused=false/wifiOnly=false。原序言组曲只将01呼吸/02心跳两章入队，启动实际1/43及0/50；普通暂停后在途页完成至34/43、partial/paused，后续约50秒仍34/43且第二章0/50未起。普通继续后先43/43、再第二章50/50，最终90章2390/2390。只经两个准确章节名称确认框删除本轮两项，原88条全部字段及偏好按内容比较相同；原网格/最近阅读/继续阅读卡恢复，10000ms/AWAKE读回并release c33aa70b。证据沿reader-failure-retry/downloadpause197-{queued,started,paused,paused-stable,resumed,completion,completed,own-heartbeat-delete-confirm,own-breath-delete-confirm,original-queue-restored,original-shelf-restored}-001。恢复瞬间持久队列曾0/0，随即布局仅转场空树，未取得对应可见归零，不能据此判UI缺陷或擅改；首次错误文件名/第二次cat截断与两次过早读未完成回执均保留，后使用原已验证cp/file-recv取得完整JSON，不计算哈希。只闭这两章的当前前台暂停/恢复/清理，不冒暂停跨cold或逐页不重取证据。

- **自动翻页当前普通路径（Root/197）：** 原继续阅读Chibi2/8，实际阅读设置显示3s/预载2、纵向分页、从左到右、左右分区/水平翻转。未改设置；关闭设置后点击现有时钟，跨一个配置周期4200ms再点同按钮停止，实图显示另一幅第3/8页且时钟回白；后续读回仍3/8，再普通右点击回2/8原图。普通Back后书架继续阅读明确第2页25%/最近阅读/首三书保持，原10000ms/AWAKE读回并release038843aa。证据reader-failure-retry/autopage197-{original-reader,current-settings,interval-readback,start-stop,stopped-restored-page,session-restored}-001。只闭当前旧版纵向分页普通启动/手动停止；未冒连续模式、后台恢复、长时、缺图等待或Shared通过。当前11项阅读设置均有ReaderPage符号引用的静态检查只作消费者线索，不冒运行验收。

- **音量键普通消费者补记（Root/197，原件本轮已复核）：** 原开关false/下键下一页，普通开启后keyEvent17使Chibi2/8→3/8，16回2/8；普通关闭后17未翻页，系统MUSIC4→3；16恢复MUSIC4，Back回原Chibi第2页25%书架。原开关false、方向、页位及10000ms/AWAKE均恢复，旧64a94beb已释放。原AudioPolicyServer不支持查询保留，后使用实际AudioPolicyService；未改产品。原件volume197-{original-reader-settings,enabled,down-next,up-previous-settings,original-off-restored,disabled-down,session-restored}-001，哈希关闭；不冒方向反转、其他模式或Shared通过。

- **私库官方demo当前条件（Root，2026-10-21）：** 官方Komga文档及其原始introduction.md确认公开演示地址与演示凭据。首次带公开Basic凭据的Host只读API请求被自动审批拒绝，未执行；转为不带凭据的公开GET，实际HTTP403/0.58s。没有继续认证/重试/绕过，也没有修改App私库配置；不把该失败判成Koma客户端缺陷。原Kavita缺有效服务/数据条件不变，该分支未闭，其他安全App动作继续。

- **xkcd完整手动目录当前有限路径（Root/197）：** 普通书架详情正常取回676/676章，原降序首2978，普通升序首1/11/20/22，已下载筛选1/676且仅原2978；Root已亲看完整原图。普通重置后回原书架，没有开章、标读或触发新下载，不冒全676逐行目视、正文或全部筛选。原件catalog197-{xkcd-ready,ascending-oldest,downloaded-one,reset-original-shelf}-001。

- **Nemo同根重导入（Root/197）：** 从普通书架导入→文件夹，系统选择器精确选原file://docs/.../Koma-QA-Folder-20261009父根（不是Nemo子目录）。当前原生日志09:28:57确认folder_access activated、folder_rescan_persisted added/changed/metadata_changed/missing均0、rejected3、upserted0。导入前后75本及整份library JSON内容相同，reader JSON内容相同，无新增/丢失ID；普通本地筛选仍仅Nemo和原Smoke，Nemo详情2/2章、继续第2/3页亲看保持。未修改外部文件或制造授权失效样本，不冒内容变更/缺失/失败回滚通过。原件folderreimport197-{baseline-menu,before-confirm,result,native-log-002,local-results,nemo-detail}；首日志括号被设备shell解析拒绝保留，后只读简单folder_过滤成功，未重复导入。
- **本轮恢复反例保留：** 首批量恢复使用旧展开菜单位置，实际选成另一来源，读回仍“筛选·1”被拦下，不能作恢复通过；虽提前release5e6a68cb，随后立刻重取560a29b4并完整醒屏门禁，按当前菜单“全部”真实坐标214而非旧529纠正。最终all-sources-restored-002原图/布局明确原首三书Chibi/xkcd/虫笼、最近阅读、无筛选计数及原Chibi第2页25%，10000ms/AWAKE读回后才release560a29b4。未改产品源码。
- **既有私库服务当前核对（Root，09:36）：** Docker实际Komga与Kavita均exited；仅按两现存容器inspect给出的四条bind源作exists检查，/config、/data、/kavita/config、/manga对应宿主来源全部不存在。没有启动/重建容器、遍历TMP、复制/补造目录或改凭据。真实私库正文仍未闭，需要有效服务/数据条件；官方demo403不再请求。

- **MangaBz016当前正文有限闭环（237/源owner，Root亲审）：** 现装0.1.6普通热门12本，鬼滅之刃235/235章；第1話殘酷54P显示真实1/54封面，正确右侧下一页后真实繁中正文2/54。自然Back完整reader JSON独立绑定com.mangabz.koma:manga:73bz / chapter:73bz:10344:54 / pageIndex1 / totalPages54。原左点回执虽误命名ordinary-next-page，真实单页/从左到右/左右分区/不翻转合同下它是前页，1/54不变不构成取页或手势故障，未改产品。普通重开原第1卷271587:190后P2/190、自然Back和详情均确认恢复原继续阅读；新章P2记录作为正常阅读结果保留，未编辑/删除持久记录。原全部/降序、Browse末端、AWAKE/10000ms均读回。Root已亲看first-page、correct-next、original-progress-restored、session-restored原图及元数据；仅闭这两页与普通返回，不冒54页全部/下载/cold/全源。证据沿原category-membership/mangabz016-*237-001，哈希关闭；源README版本标题已校正016并记录完整边界，单文件提交01ee23f。

- **本轮图标实际交付（Root/237）：** 主仓Debug10:34构建/覆盖安装成功；NN011主体按1.30放大后管理/Browse原图完整。漫画柜013的1.10显示调整后，用户明确要求替换头像，采用生成的无书脊/边框512px满幅图，014默认比例1；普通系统picker导入明确成功。Root已亲看manhuagui014-manager-visible237-001与browse-restored237-001完整原图，仍由原30vp/7vp容器定义边界；它是原官方桌面身份的派生头像，不冒官方高清原件。50项sourceId/enabled逐项顺序相同，本源仍第50项014；只清本次014上传包，AWAKE/10000ms读回后releasefd787030。其余四现装比例由源替补接续观察，HentaiFox在237未装，不以其他源替代通过；MangaBall宽形标识未强行裁掉两侧文字。Appf1fc285、源73ecf4b已提交；源旧01ee23f已SSH同步。
- **瓜子013本轮具名正文有限闭环（源owner/237，Root亲审）：** 普通更新成功，50项sourceId/enabled顺序保持；14109/1633768（334鬼梦貘）1/3为作品署名页，下一页2/3为彩色正文并可见城户南，Root已亲看两完整原图。自然reader记录pageIndex1/total3，未直接编辑持久记录；Browse末端、10000ms/AWAKE已恢复，唯一自传包已删、fd2cc4e7已release。只接受具名两页与返回；长条图在单页模式内呈窄栏，不冒全图/全模式/下载/cold。原件guazi013-{reader334,reader334-page2,session-restored}237-001。

- **普通下载管理Shared入口补验（Root/197，2026-10-22）：** 在现装44a86da1 Release上，从下载管理已完成Chibi章的“8/8页”普通点击打开，实际rkit-reading-surface唯一节点出现，原图为真实正文第2/8页；Back后共享节点消失并返回原下载列表。Root亲看正文/返回完整原图；自然返回原书架，继续阅读仍第2页25%、最近阅读。未改偏好、下载或目录，未新翻页；不把静态端点冒转场黑帧/全离线通过。原件为reader-failure-retry/ordinary-shared-downloads197-resume-002；最终ordinary-shared-downloads197-final-restored-003读回原OverrideTimeout10000ms，产物哈希关闭，46163ca8租约已释放。
- **本轮两源图标验收（Root/237）：** MyComic012首次普通导入，漫画1234由012更新013；管理/Browse四完整原图Root亲看，旧底板和影已去、主体可辨，App槽/圆角/主题未改。注册60→61仅新增com.mycomic.koma，原60相对顺序及enabled逐项保持；除mh1234版本、包引用和wasmByteCount外原59完整entry相同。原Browse喵趣漫画锚点、10000ms超时已恢复，两本人传包核ABSENT，e2f3b60f已释租；原件为category-membership/mycomic012-mh1234013-icons237-gate-001及mycomic012-mh1234013-final-restored237-003，回执哈希关闭。源ddf7fae已SSH同步；CI39793217139 attempt1在未编译/发布阶段取消并确认终态后，仅重跑attempt2。14:30:19Z实际仍queued/无runner；后查GitHub官方q29p76qtnkyk已声明工作流/步骤结果处理延迟，当前不能据旧安装步骤或无法取log归因APT。后继14:36:43Z后REST确认attempt2 completed/success（head ddf7fae），Root独立复核同一精确run及固定latest/index HTTP200/85项、MyComic012包91878B和mh1234 013包143466B均200且准确ID/version/三成员。两新资源、237两消费者及远端发布链已闭；两README限定验收句5e4a597已[skip ci]同步，源工作区干净。不按延迟queued子任务重跑或修改CI。不冒正文、深色实机或全源通过。四私库/自然失败/授权失效/系统调度及黑帧原证据边界保持，不复活旧通过路径。

## 当前能力的证据边界（2026-10-21）

下表依据本页现有具名结果及当前代码对账，不是新测试矩阵。标“既有记录”的结果本轮没有重跑；未知保持未知，旧版本成功不升级为现包全通过。下一动作只由顶部执行行调度。

| 能力 | 已有可追溯结果 | 当前未闭部分 |
| --- | --- | --- |
| 书架 / 分类 / 筛选 | 既有记录：分类创建/改名/删除、237单书加入/移出与cold；本轮197两书新分类加入/筛选/cold/移出/清理；197下载筛选冻结及分类策略覆盖反例已修并cold。 | 本轮两书移动替换已实际UI/持久文件读回；自然保存失败回滚仍未取得Native结果；不重跑已闭具名路径。 |
| 源内 / 全局搜索 | 既有197记录：去掉5/10秒外层截止后晚返回被接收、换词拒旧结果；CF013空/非空搜索及详情返回。 | 不等于全部源搜索或正文可用；源逐包接原README失败与版本。 |
| 普通旧版阅读 | 既有四模式失败呈现/真实重试、按书模式保存与全局隔离/cold；本轮按钮留白f4afaf3d、2937在线重试、Chibi2/8双击/中央捏合放大→还原、方向左右翻页及页码/全屏消费者已亲看。 | 本轮首次保存后本书标记/恢复默认入口刷新已具名通过并恢复原状态；其他模式组合未因此通过。 |
| Koma普通Shared入口 | 本版接入已获人类明确批准；普通路由已有197继续阅读/历史/本地/未收藏源、进度、前后章、按书设置及详情重入具名结果，见顶部本轮记录。Legacy保留。 | 当前Release已安装；44a86da1已同步，精确CI39789257199成功，私库按人类决定搁置；未宣称全部宿主/媒体/全模式或全部源通过。 |
| 下载 / 离线 | 既有197 DM5 16/16及cold、两章多选/删除；237菇菇限定禁WLAN cold、NN54/54、漫小肆013 60/60及cold。本轮跨书两已下载章被跳过，新增0。 | 本轮跨书4新增/128页完成，正确Home真实后台12秒进度增加；仅有限短后台，不冒系统保活或进程死亡；单章完成通知点击到管理已具名通过；不能外推全离线或全源。 |
| 本地导入 / 重扫 | 既有197 1700页CBZ及cold/移出、两图片导入与重开、Nemo单根重扫；当前API26系统目录选择器确实可用。 | 当前1需重选样本是App私有旧Smoke根（目录仍在），不能在系统picker选；真实外部授权失效重选、内容变化/缺失后的Native结果仍未闭，不造夹具/撤销授权。 |
| 历史 / 远程进度 | r5远程历史已归回c8813948；既有WEBTOON具名历史重开/cold记录；当前24vp历史移除按钮保留。 | 真实私库历史验收已按人类决定搁置，不自主重开；自然保存失败仍仅待自然场景，不造状态，Host不冒Native。 |
| Komga / Kavita / OPDS / WebDAV | 原目录遍历、搜索、封面、历史消费者已具名恢复；四配置入口既有197能打开/返回。 | PARKED_USER：2026-10-22人类明确搁置四私库实际验收，待其后续实际验证再提出；不得自主复活测试。不因此停止其余交付工作。 |
| 外观 / 语言 / 设置 / 关于 | 既有197主题/强调色/语言实际消费者，英文chapter/chapters与中文话已验；完整WAMR/Lexbor许可中文弹窗已滚到末尾。 | 未宣称全部页面、语言或许可审计通过；本轮下载说明与重试菜单文字已获批、实施并197具名通过；未外推全部语言运行状态。 |
| 备份 / 恢复 | 既有创建/预览/取消；本轮获准当前快照1792584275735已真实恢复成功，解码阻塞修复、具名书架/历史/下载消费者及原四备份保留已亲审。 | 本轮当前快照真实cold已补；自然失败回滚、其他备份/跨设备仍未验，不清数据制造样本。 |
| 更新 / Tracker | 既有197上次更新报告计数、两条结果跳转及cold；当前Tracker未连接。 | 本轮普通手动全库更新及旧报告cold已有具名结果；修复后自然新增报告、更新通知/系统调度仍未验。Tracker缺账户/client只限制该分支。 |
| 源图标 / 源正文 | 当前缺图与低清/小槽各有原表条件；漫小肆013已同步3daaac6并有限正文/下载/cold通过；原至少14身份的历史正文下界另见本页。 | ComicABC30513第4話在线首图1/27已闭，第01話只证下载正文；素材403/拒稿/待选择分别保留，不从86源从零跑，不把图标或目录当正文。 |
| 构建 / 同步 / 分发 | Koma计数修复1150724已197覆盖安装且CI39570169204 success；源mastera4ca19e已同步。Kit原SSH身份/固定依赖CI故障已闭。 | 当前44a86da1普通Shared签名日用包与ddf7fae两源资源发布链已闭，源精确CI39793217139 attempt2及固定索引85项由Root复核；不作为全部功能/源正文或正式上架结论。 |

## 已记录事实与专项边界（以下作为证据索引，不以旧“下一步”派工）

## 当前接续：CI依赖同步故障与237验收（2026-10-20，Root）

- CI原反例：run39406667795及39335215874均在Checkout pinned reader-kit sibling报not our ref 103ef18，编译未开始。按用户本轮纠正核 ~/.ssh/config，发现独立github-3003h别名（ssh.github.com:443、独立密钥）；该身份对原erosTeam/reader-kit/main的dry-run及实际正常快进均成功。origin已改为git@github-3003h:erosTeam/reader-kit.git，远端main现为3a7b56d，主仓已同步且干净。此前honjow的HTTPS/默认SSH/连接器无写权是对应身份的事实，但据此要求用户恢复写权限并停止同步的全局结论错误，现撤回；原仓无需额外授权或换地址。当前CI只将固定依赖更新到本机已构建/具名验收的3a7b56d，并移除自定义产物SHA计算及对应README描述，保留HAP结构/包名/Release/必需SO检查；精确提交f4b11db8的新run39412294482已实际全部成功：依赖检出/公共配置/国际化/OHPM/Release编译/HAP检查/上传均通过，整个job2m54s，编译50s296ms。清单实际readerKitCommit=3a7b56d，HAP为Koma_0.1.1_ohos-release-unsigned.hap、8142481B；ohos-hap-unsigned产物2984132B且未过期。仅关闭此CI故障，不冒签名安装/首版可发布。
- 237普通分类归属现已实际验收：实时VDE-AL00展开竖屏1320×2120，解锁后AWAKE/OverrideTimeout86400000，主仓当前Debug覆盖安装成功，未清数据。原本无自定义分类；普通创建Koma-QA-237-1020，经原书架长按菇菇四格漫畫→加入该分类，分类标签与普通筛选的一本书实际显示。Home→force-stop后PID10019→空→10376，冷启动仍为同一分类/同一书；随后仅移出本轮分类，筛选实际变空，准确名称确认删除测试分类；再次Home→停止PID10376→空→10897，原全分类/最近阅读、首三书及原继续阅读第2页恢复，测试标签消失。仅接受这一本书的加入/移出/筛选/两次不清数据cold，不扩大到移动替换、多书或失败回滚。原图已亲看，原件沿user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership保留；全部回执artifactHashesEnabled=false，197未操作。
- 验收偏离原件保留：首次inputText误落在字段标签，Back退到上页，下一点击触发原手动检查更新；没有把此批次当创建成功，后按真实TextInput边界填入准确名称。首次前台force-stop后立即读到新PID，未冒称停止后为空，后改用已存在Home→停止→读空→启动顺序取得上述真实边界。没有产品源码改动或以工具成功替代验收。
- 237短章下载本轮结果：菇菇2026.01.30原行内为下载箭头，本轮点单章下载后实际显示已下载；普通下载管理9章243/243页，该任务2/2页。正文原图已亲看；Home→force-stop后PID10897→空→16534，新进程经普通设置→下载→下载管理点同任务，再次亲看相同真实第2/2页。准确名称确认仅删除本轮2026.01.30下载后为8章241/241页；随后普通目录重开原2026.01.26第2/2页，再回书架，原继续阅读位置、最近阅读排序及首三作品已读回。未清缓存或用户数据；网络保持连接，仅接受下载/完成任务持久重开/本轮下载删除，不冒物理断网通过。原图与具名download-*回执沿同一237场景证据区保留。
- 本轮237设备会话已恢复进入时实际OverrideTimeout10000ms（系统原Timeout120000ms），读回AWAKE后释放租约；所有回执哈希关闭。当前两个检查点仅含工作单结果，本轮产品源码无差异。CI已按上方精确run闭环。本项后继的限定联网重开结果见下方，原待核条件已解除。下一未验证动作/owner：Root追下载设置的真实调度/网络消费者，先明确未验状态再运行下一普通路径；现存source_icons接续未被拒绝或阻断的低清素材官方父链，不重复已关闭呈现路径。源图标既有未闭项、普通Shared入口与需外部服务的分支继续按各自具体条件OPEN，不以本轮具名路径通过宣告首版可发布。

- 源仓错误说明补正：32b1dfd把README/SKILL原本明确保留的App圆角改成禁止App圆角；WEBTOON资产说明也残留同义错误。依据本会话人类明确区分素材与列表容器的原文，只恢复三份已有说明，素材与App源码未动。源master fab24d0已实际同步；同类明确错误文字的当前源文档检索已无命中，不以文档修复冒资源质量整线完成。

- 237限定联网下载重开已完成：系统应用联网→WLAN仅将Koma由true临时关闭为false，整机Wi-Fi/HDC保留；随后Home→force-stop的PID16534→空→38232，经普通设置→下载→下载管理重开本轮新增的菇菇2026.01.26。Root亲看第2/2页真实正文，图片信息实读1173×3487、来源“设备文件”。只接受该已下载章节在Koma WLAN被禁时的冷启动重开，不冒全离线、蜂窝禁用、所有章节或Shared路径通过。接续后已恢复Koma WLAN=true并读回；准确章节确认框仅删除本轮2026.01.26下载，恢复原8章241/241页，书架原继续阅读2026.01.26第2页及最近阅读首三作品保持。最终AWAKE/OverrideTimeout10000ms读回并释放原租约。证据沿同237场景的offline-{wlan-denied,koma-cold,downloaded-reader,image-local-source,wlan-restored,own-download-cleanup,final-original-shelf,session-restored}-001；回执哈希均关闭，未操作197。预检中一次PowerManager查询仅返回help、一次全量输出截断及一次-t参数被manifest拒绝均未用作通过；后以受支持的状态查询取得AWAKE/86400000ms才继续普通输入。
- 237未下载章节限域结果：目录2026.01.19未创建下载任务，Koma WLAN临时关闭，系统弹出的无线数据请求选择“不允许”；实际进入旧版失败页。普通Back返回书架后仍是原2026.01.26第2页和原首三书，未把失败占位发布为进度，未新增下载。已恢复WLAN=true、原OverrideTimeout10000ms并释放租约。失败原图暴露重试按钮叠在加载圈上、底部假1/1；据此候选后获本会话批准，197修正后结果见下条，本条保留237原始反例。根因已追到bc122397的ReaderImageSurface.LoadingContent在failed时仍放LoadingProgress，ReaderPageSlot又在同一Stack中心放重试按钮；670f66bb只恢复本会话已批准的真实章节重试与unsupported文案，明确保留旧按钮几何，未改这两处布局。当时仅调查、无产品源码改动；后续批准及实施范围见下条。证据沿同237场景offline-undownloaded-{catalogue,network-deny,return-progress,wlan-restored,session-restored}-001。
- 当前设备已按用户最新指令切回197：实时Connected，切回时截图74%且充电中，ALN-AL80竖屏1260×2720；解锁后AWAKE/86400000ms，进入时OverrideTimeout10000ms。当前租约20261020-115456-e5b324ad，197旧低电量记录不代表当前状态。
- 197本轮设备偏离：首次把切WLAN、字母K定位和开关点击合在一批，列表重建使K定位未生效，末次点击误落在“全部”WLAN开关。原图实读全部及可见各项false，立即只反向撤回该开关；恢复后全部和可见各项true。随后单独定位K并读回准确Koma行true后，才单独关闭该行；后件证明只有Koma=false、可见邻项全true。该误触不计产品验收，也不把反向撤回说成逐项核过原先不可见全部应用。系统“不允许”联网提示另把Koma移动数据改为false，按此前独立保存的true恢复；当前Koma WLAN、移动数据都已读回原true。
- 已批准失败呈现的197具名验收已完成：ALN-AL80竖屏1260×2720，主仓Debug签名包2026-10-20 20:46:49覆盖安装成功，增量assembleHap退出0，未清数据。受限联网的xkcd2976/2975实际失败，Root亲看单页、双页、纵向分页、连续滚动四种失败画面：无加载圈、原13vp同色按钮在文字下方、无假页分数/滑块；连续滚动按自身页面几何放置同一组件。纵向分页2976与双页2975在WLAN/移动数据恢复true后直接点按钮，均实际重新取页并显示对应真实正文；其余两模式只验失败呈现，不冒独立重试成功。按钮外普通点击仍可呼出控件。原件为reader-failure197-{repair-uncached-chapter,single-failed,dual-failed,continuous-failed,repair-normal-chrome,dual-retry-terminal}-001；两段完整录像沿device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-failure-retry/{retry-hit-region-002,retry-dual-003}保留，Root顺序查看全部169/176帧联系表及原尺寸交接帧125/126、139/140，加载先退出才出现正文。视频首帧已为加载，失败源态由同次先行截图/layout证明，不把录制启动成功当完整源态录像。旧菜单重试终态也已亲看2977真实正文；2977已缓存，故后续改选相邻未下载章，未清缓存制造失败。
- 197重试输入反例及修复：原两份联系表71帧和直接点击均只切chrome，现有菜单同一retryCurrentPage能进入加载；已排除录屏缩放/坐标偏移。华为多层级手势文档确认Transparent仍让上层点击手势优先；现保原翻页手势组，仅在实际失败按钮窗口矩形内返回HitTestMode.None，其余保持Transparent。矩形由组件Area提供，按唯一ID清理、会话更换/卸载清空，接全部ImageSurface/Spread消费者；本轮纵向与双页直接重试均已实际通过，不新增可见方案。原四模式呈现及该输入修正只在ReaderPage/ReaderChrome两文件，不修改共享Kit、NextN或NextE。
- 上述失败呈现的两文件候选已获本会话当前人类答复“实施这份限定修正（推荐）”，并已精确应用：ReaderImageSurface失败时停止加载圈，把现有13vp同色胶囊重试移入同一纵向列、位于原失败文字下方；普通单页/纵向/连续和双页都回调现有retryCurrentPage，双页只在失败时允许该按钮命中。source-placeholder交给ReaderChrome的实际可显示页数为0，收起假页码/滑块并保留控件原占位高度，真实图片的页码不改。全部两处ImageSurface、唯一Spread消费者及唯一Chrome消费者已核。原LoadingContent和覆盖按钮来自bc122397；670f66bb明确保旧几何，原人类只批准真实重试/限定unsupported文案，不覆盖本次新排布。现据237真实重叠反例及本次明确批准实施，没有用默认尺寸或小diff作依据。原主仓Debug构建返回成功并生成当前签名HAP，197覆盖安装明确成功；四模式失败呈现及纵向/双页直接重试结果见上条。197系统应用联网中的Koma移动数据、WLAN已分别恢复并读回true；原纵向分页恢复，阅读方向从左到右与既有local-import-reader-settings原件及当前设置读回一致。当前租约仍有效，原OverrideTimeout10000ms在会话结束时恢复。

- 下载消费者与既有受阻任务197接续：Settings原并发1、仅Wi-Fi=false、通知关闭已实际读回；静态追到OfflineDownloadService使用同一queueStore偏好、Runtime.acquireSlot按当前并发放行，网络判定读取默认Wi-Fi承载。管理原88章2281/2281页、1项DM5虫笼受阻；从该项进入普通详情并开章后当前源取得16页及真实首图。只重试此既有任务，实际完成16/16，合计仍88章但2297/2297页，受阻提示消失；未批量重试、清理或删除原任务。暂停动作到达前已完成，未取得暂停/恢复证据，不计通过且不反复抢窗口。图片信息实读600×600、来源设备文件；Home→force-stop PID43747→空→54198，不清数据新进程经设置/下载管理重开，首图及第16页不同正文均亲看，页位置随后回1。保留本次原任务成功下载与阅读历史，不冒全部16页逐张解码、物理断网或整个队列通过。原件沿user-flow-audit的downloads197-{preferences-original,attention-task,dm5-reader-terminal,dm5-retry-start,pause-existing-retry,dm5-device-file-info,dm5-cold-root,dm5-cold-reader,dm5-last-page,dm5-return-original-page,original-preferences-restored}-001。最终并发1/仅Wi-Fi=false读回，AWAKE/原OverrideTimeout10000ms读回；后继设备阶段须重新建立当前醒屏条件。

- 新实机菜单文案反例（未修改、待决定）：197下载后正文更多菜单最后一项显示“无法加载页面”，实际在pageFailed时调用onReloadPage。当前ReaderChrome:202及git blame/show均定位到bc122397原迁移；只找到实施，未找到故意用失败状态句命名动作的原始人类理由，写未知。本次依据为downloads197-dm5-completed-reader-001实际菜单，不按默认值改样式。建议允许差异仅将该项content由s(reader_page_load_failed)改为现有s(common_retry)，其enabled条件/回调/菜单顺序/尺寸/颜色保持；已批准失败按钮排布不覆盖此新文字候选，尚未应用。

- 197源筛选接续：沿同一MangaDex普通热门列表快速选择Completed再Ongoing，现存连续录像pending-change-001的127帧/四联系表已顺序审完；最终为Kage no Jitsuryokusha、Tensei Slime、One Punch-Man等Ongoing列表，重开筛选读回Status=Ongoing。旧内容在请求期间保留，未见空白或失败层，终态没有被旧结果回盖；但无网络起止记录，不把该录像扩大为穷尽乱序响应。随后Status恢复原All，Content Rating/Demographic仍All、Order By仍Relevance，原Solo Leveling等列表读回。证据source-filter197-{ongoing-values,restored-all,final-values}-001及device197__ALN-AL80/not-applicable/portrait-1260x2720/source-filters/pending-change-001；自然失败重试仍未验，不人为制造站点失败。Root继而接续外观设置已有消费者，未新增产品改动。

- 197外观消费者具名验收：普通设置原值为主题跟随系统/强调色翠绿/语言跟随系统。经现有菜单切深色与海蓝，亲看外观页和普通书架的背景、文字、继续阅读进度及底部选中色生效；再选English，外观页实际改为英文。Home→force-stop PID54198→空→63980，不清数据后普通书架仍深色/海蓝且标题、排序、筛选、底栏为英文，重开外观读回Dark/Ocean/English。随后三项全经原菜单恢复跟随系统/翠绿/跟随系统，外观及书架实际恢复中文浅色；首三作品和虫笼第1页保持。结束读回AWAKE/原OverrideTimeout10000ms并释放租约。只接受这三个值与具名消费者，不扩大全部语言、页面或系统语言跟随变化。原件appearance197-{original-values,dark-terminal,dark-ocean-library,english-values,cold-library,cold-values,original-restored,session-restored}-001，回执哈希均关闭。
- 新发现待决定的文字缺口：英文书架数量仍为“1 话/676 话”，197冷启动原图可见。当前MockLibraryData.formatSourceSubtitle:293硬编码由8c8e92fc引入（2026-09-04），git log -S/-G及show已定位；当前无该文件WIP。所有消费者为createFallbackPresentation与createLibraryViewModelFromComics，LibraryPage网格/列表共同投影，gridProjection已监听effectiveLocale。未定位有意在英文中保留中文单位的人类决定；不猜理由。候选仅将此自动数量接到新单数/复数语言键，中文保持“%s 话”，英文“1 chapter/%s chapters”；原问题中“1 chapters”示例已明确更正。短源副标题/作者等其他分支、数量、布局与几何保持。四文件候选尚未应用，异步问题accepted:true不算批准，等待真实答复后才实施。

- 197书架更新记录普通路径已核：现有2026-10-16 18:37记录为74本/7更新/65未变化/1跳过/1失败/9新章；设置摘要与详情卡一致。失败KAV001条目实际打开本地3章详情及原第3/3页续读，返回保留原结果位置；更新Meme Girls条目285→287与普通详情287章、原已下载标记一致，未开始阅读。Home→停止PID63980→空→19476，不清数据后经普通设置重开仍是同一时间/全部计数及Kavita失败摘要。Root亲看原图，证据library-update197-{library-settings,results,failed-row,failed-detail,updated-detail,cold-root,cold-results}-001。仅关闭既存记录展示/两条结果身份跳转/持久重开，未执行新的全书架更新、验证历史检查本身或改更新偏好；当前服务无单本检查入口，不为验收新增功能。章节多选下载后继见下一条。

- 197两章多选下载实际闭环：普通xkcd目录进入选择，仅勾2977/2976，确认框实读2章/跳过0/待处理2；自然完成后两行均已下载，管理90章2299/2299页、xkcd3章3/3页（含原2978）。分别经准确章节名确认只移除本轮2976、2977，管理恢复88章2297/2297页；定向queue读回xkcd仅2978保留。Root亲看确认/完成/管理/清理及恢复原书架图，继续阅读虫笼第1页、最近阅读与原首三作品保持。本轮没有阅读、标读或更改下载偏好，没有测试暂停窗口、断网或批量失败，不外推并发/恢复通过。证据chapter-batch197-{confirm,terminal,download-manager,cleanup,original-state}-001及独立准确名称确认回执，哈希关闭。原OverrideTimeout10000ms已读回；下一未验证动作/Root：ComicFury尚未接受的普通源内搜索→详情实际路径，原Reader/下载已验路径不重跑。

- ComicFury源内搜索新反例及实施边界：197当前0.1.2热门实际12本，内联“毛兒”搜索终态为source_runtime失败。source_icons对同构造URL唯一普通Host GET取得HTTP200/26839B、标题Search - Comic Fury Webcomic Hosting，query input确为毛兒；唯一form.search-wrap内search-results的直接search-error明确“There were no results for your search!”。Root已审原响应精简HTML和父树偏移、App args.query/page消费者、6bbee70原list无条件empty listing及唯一search/list两调用；该正常无结果被源抛失败，不是图标提交改变解析。允许差异仅search=true、零卡片且唯一精确无结果标记时返回现有空items/null游标/hasMore=false合同；popular/latest、其他错误/缺失结构、非空解析/分页及App呈现保持。现有CLI无离线响应注入，不为此新增Host或脚本；Root实施0.1.3后按197真实同词空结果及有效搜索/详情验证。此前两次把内联提交误当另页入口、一次多余Back退出、带管道的日志取法失败及hilog-t被原guard拒绝原件保留，均不作产品反例或通过。

- ComicFury0.1.3已交付（Root，2026-10-21）：离线构建并读回WASM版本后，197普通本地导入明确成功；同词“毛兒”终态为现有“没有找到结果”，Maor返回“毛兒傳 (Maor)”且无下一页。普通进入详情实际显示封面、Allen T及67/67章；Back后Maor和同一结果保留，Root已亲看两张原图。只接受这两词的空/非空搜索及详情返回，不扩大到全文搜索或正文/下载。源master四文件7245a50已正常同步；修复保持其他错误列表失败、原非空解析/分页/请求及App呈现。证据comicfury-search197-{empty-repaired,empty-terminal,positive-query,positive-terminal,detail-ready,back-results}-001及原反例日志保留，哈希关闭。197继续同一有效租约，当前AWAKE/OverrideTimeout86400000ms；会话结束恢复原10000ms。下一未验证动作/Root：核对当前普通私库服务入口及实际可用连接，接续尚未验的浏览→详情→阅读/返回路径；source_icons已恢复全量未闭资源官方父链工作，不重试受限URL。

- 197书架下载筛选新反例（Root，2026-10-21，修复前记录）：原最近阅读/全部筛选及88章2297页下载保留；普通筛选→下载状态→已下载后主线程冻结，系统00:21:35记录THREAD_BLOCK_6S，PID19476随后消失。原故障堆栈明确为createOfflineDownloadStableByteHash→validateDownloadedChapter→QueueStore.loadReconciledSnapshot→LibraryPage.downloadedComicAvailability/setAvailabilityFilter，不把菜单点击/Back或输出截断误作根因。2abef1c2引入只读清单投影以避免筛选改写下载；64fad10e已让详情摘要跳过图片正文重算，4f4bd846给队列初始化加入同一选项，却未覆盖唯一书架snapshot调用。原特定人类批准未定位，写未知；本次重开依据是当前真实系统故障，不改UI/筛选含义。允许差异只给loadReconciledSnapshot的现有只读验证传validateContentHash=false，保留清单/身份/路径/文件存在及大小验证，其他显式校验和下载读写不动。原件library-availability197-{original,filter-controls,availability-menu,downloaded,exit-evidence,freeze-log}-001，faultlogger原log已接收。Root下一动作：原主仓限定修复→Debug构建/覆盖安装→同88章普通筛选、目录和不清数据重开；未通过前保持OPEN。

- 上述下载筛选冻结已具名验收（Root，2026-10-21）：唯一QueueStore生产差异为只读snapshot传validateContentHash=false，Debug assembleHap退出0，197覆盖安装明确成功。原88章2297页下已下载/部分/完整三种普通选择均完成，进程40646持续存活；部分下载真实cold为40646→空→41035，恢复相同筛选。xkcd目录676/676、2978唯一已下载，与部分下载对应；Chibi目录1/1且已下载，与完整下载对应。未进正文、创建/删除下载或标读；原可用性已恢复全部，再次cold41035→空→42859，原虫笼第1页/原首三书/最近阅读显示恢复，定向只读队列仍88章2297页。Root亲看原图，证据library-availability197-{downloaded-repaired,downloaded-settled,partial-cold,partial-detail-ready,full-detail-ready,original-restored,original-queue}-001；不扩大为所有下载状态或性能预算通过。两次带引号grep被设备shell吃引号、一次cat受回执8000字符尾截断，均未当数据损坏；后用不含引号的定向页数表达式读回。哈希关闭。

- 书架无关筛选覆盖分类投影（Root，2026-10-21，实施前）：同次197筛选前为最近阅读，保存下载状态后变最近加入，cold又回最近阅读。已追cdb3fb22恢复的saveFilterPreferences回执及applyCategoryDisplayStrategy：进入页先应用当前分类的sort/readState，局部字段保存返回全局Preferences快照却以false跳过分类投影，旧全局值回盖当前有效值。只读检查无其他LibraryPage WIP；原具体人类批准仍未知。实际生产save/apply方法在内存Preferences适配下复现同一added覆盖lastRead，非源文本断言。允许差异仅有分类显示策略时，无关字段回执保留当前有效sort/readState；显式排序、阅读状态、重置仍按其字段意图提交，未设策略时仍接收全局合并快照，旧epoch/revision拒绝规则保留。不改分类策略、存储字段、布局或文案；下一Root限定修复→同方法边界检查→197同下载筛选及返回/cold。

- 上述分类投影覆盖已具名验收（Root，2026-10-21）：LibraryPage唯一8行实现差异，实际生产save/apply方法在内存Preferences适配下原反例先失败，修复后6项通过（分类无关字段、无策略全局合并、显式排序/阅读状态、重置、过期回执），存储写入仍只有原changes字段；不冒Native。当前主仓Debug构建退出0，197覆盖安装明确成功。相同下载筛选后最近阅读/全部阅读状态/原首三书保持，不再回跳最近加入；真实cold为46649→空→46953，筛选与排序仍在。最后只把本轮availability恢复all，原继续阅读虫笼第1页、原首三书与最近阅读保持，Root已亲看原图。证据library-filter197-{repair-installed,order-retained,order-cold,restore-all,restored-root}-001，哈希关闭。只关闭这个回执反例，不冒所有分类策略或显式排序的设备验收。Root下一未验证动作：追当前按书阅读模式与全局设置的实际消费者，再核普通阅读入口的设置作用域/恢复；Shared普通路由仍等待真实人类答复，不借此实施。


- 英文书架数量单位已按本会话人类明确答复实施（Root，2026-10-21）：仅MockLibraryData.formatSourceSubtitle自动数量表达式及三份资源，单章/多章分别读语言键；中文保持“%s 话”，英文“%s chapter/%s chapters”。原短副标题/作者优先级、数量、布局和尺寸保持。三语言键一致/无重复检查通过，当前主仓Debug assembleHap退出0，197明确覆盖安装成功（01:10:37，16224380B），未清数据。Root亲看普通中文书架1话/676话、切English后1chapter/676chapters及原源副标题；随后原菜单读回跟随系统/翠绿/跟随系统，回中文书架原Chibi第2页25%、最近阅读及首三书保持。原件沿user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-language/{installed-001,chinese-and-appearance-001,english-shelf-001,follow-system-restored-001,original-shelf-restored-001}，回执哈希关闭。仅接受普通网格具名文字，不冒全部页面/列表或新cold验收。
- 双线与历史阅读记录口径（2026-10-21，用户追问后接续核对）：237本轮新增正文复验0不等于历史0。当前工作单/各源README至少保留15个源身份的具名Native正文成功（含本轮MangaBz016）：菇菇（237两页/下载/禁Koma-WLAN后cold）、WEBTOON繁中012（197第2季65話前两页/106及cold）、xkcd（1972975/2976按钮重试正文、2977菜单重试，版本未记明）、DM5（197虫笼16/16下载/首尾正文/cold，版本未记明）、ComicABC（旧010首1/44+44下载/cold；019旧包159/159目录/P2/29）、mh1234（旧012于237第538話P1/11，非197011第700話失败）、六漫画（旧010第1話54下载/cold；当前标准TLS失败仍OPEN）、Komiic（014 ONEPIECE1194/12页下载/cold）、MangaDex简/繁（010分别33/49页下载与cold，非英文实体）、MangaBall（010 Knight第1話197下载/cold，封面未过）、GoDa（旧010扫地小厮17页下载/cold）、NamiComi简（旧010我是赛拉前2/20页及20下载持久；011具名查询后继已亲审，见本轮结果）、ComicFury（旧1268101正文1/1下载/cold；新013只闭搜索/详情）。此为历史具名下界，不是全历史累计或当前15包全通过；MangaBz旧README有限Native线索原未定位具体章页；本轮016的10344:54第1/2页及普通返回已取得独立新原件，不以54页Host冒全章Native。后继标准编译、图标安装、目录或HTTP成功均不增加正文通过数；旧通过与新失败并存，按源/版本/章节继续，不从86源从零跑矩阵。
- 用户最新再次指出剩余图标未闭，源线现存source_icons立即回图标质量，ComicABC237已读回现装0.1.10（019 parser的图标版本后继），旧30513样本尚未打开正文，不计通过。Root已交付本项语言修正后接续197的资源呈现/普通包交付；source_icons接续Terra/Noy及横标的官方独立标识。缺图、低清、小槽和受限父链继续按现有未闭表，不以个别素材受限、文档补记或局部交付收尾；App容器圆角/槽尺寸/顺序冻结。


- HentaiFox资源重开/允许差异（Root，2026-10-21，交付前）：552b9c3保留的官网16px图只解决素材回归，低清一直OPEN。当前用户再次要求处理全线未闭图标；本会话此前明确允许低清时生成/2D还原、优先原资源且禁止描像素锯齿，构成本次资源处理依据。官网Twitter无图URI及Discord拒绝保持；未重取它们。正常公开Keiyoushi当前all/hentaifox最高密度192图与官网16图同为金H/白环/狐尾，但第三方黄底板/长阴影不可采用。依据两原参考生成的高清隔离标识已由Root及原source_icons亲看：身份成立、曲线流畅，无外底板/长投影，轻微质感仍存在，不冒官方高清原件/纯矢量或逐轮廓等同。允许差异仅本源icon与出处记录、版本010→011用于普通交付缓存刷新，App槽/圆角/顺序/业务不动。因产物像素上限按正常512等比输出，不改校验或算法。仅在197管理/Browse小槽实际可辨后关闭此低清项；未验前OPEN。ASM两份生成候选字形/透明脏边不合格，已否决，未进源码；MPC另一about原SVG仍横标而非独立方标，未替换。

- HentaiFox0.1.1资源交付已闭（Root，2026-10-21）：实际离线WASM版本与三成员包读回后，197经普通本地导入成功；Root亲看管理及Browse两原图，新H/狐尾可辨、轮廓流畅，79启用及同组H-Comic→HentaiFox→NH.xxx顺序保持。只闭这两处低清图标，不冒正文/下载或全线图标通过；证据source-icons/hentaifox011-manager-and-browse-001/manager.png与hentaifox011-browse-visible-003/browse.png。源master的4967900已提交并正常同步origin/master，仅本源图标/出处/版本及锁文件对应块；六漫画012/NH.xxx011由现存source_icons在237普通导入验收，其他缺图/小槽项继续OPEN。Root随后回App按书阅读偏好与全局消费者普通路径，不重跑已冻结项。

- 按书模式/全局消费者本轮197证据（Root，2026-10-21）：a85b3e35恢复序列化保存后，用普通继续阅读进入原Chibi第2/8页，原全局vertical_page/left_to_right、既有Komiic1936双页覆盖先读回。仅经现有阅读设置将Chibi改single_page，实际保存只新增该书的两字段窄覆盖，全局保持；真实进程55475→停止后空→6497，普通继续阅读/设置重开仍为单页·本书。最后经既有恢复默认只清本轮Chibi覆盖，Preferences全部键值恢复原基线，原Komiic覆盖不变；未翻页、删书或改源。原图及回执位于user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-preferences/book-mode-*，哈希关闭。仅闭本次保存/全局隔离/真实cold与GUI恢复，不冒全部偏好或Shared入口。
- 新实际UI缺口OPEN：首次保存单页成功后，本面板无“本书”标记和恢复默认入口；真实cold重开才出现。原4e9e16b0及当前ReaderPage的seriesOverrideActive都仅loadPreferences读取/reset时清false，persistPreferences未在成功保存后刷新；ReaderSettingsContent的两行徽标/两个菜单共用该值，ReaderChrome透传，独立Lab另一消费者不在本候选内。不是本次测试造成的源码修改。建议仅在当前书保存成功后重读真实覆盖并更新该标记，保留旧存储/字段/布局/文案/尺寸；校验回调仍属同一Store/同一书/未关闭，失败不发布新标记。此可见行为候选尚未应用，待人类决定；源worker继续237图标，不以此停止双线。

- 六漫画012、NH.xxx012图标交付（2026-10-21，source_icons执行/Root审）：237当前VDE-AL00展开1320×2120，six为已装011普通更新，NH为首次新增后再更新；44→45只新增NH，原44相对顺序及启用状态保留。Root已亲看source-icons-manager-middle237-001与source-icons-browse237-001中的六漫画6/松鼠；NH透明011因白n融入浅卡判失败，不提交。核官网原32图自身#223445画布后，012仅保留原深蓝画布和已审白n/红翼，未加第三方板/影/遮罩；Root亲看nhxxx012-manager237-001及nhxxx012-browse237-001两处完整标识可辨。原图位于user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/。两源分别378e1cd/64d89dc已同步源master，源仓clean；只闭这两处图标，不冒正文。source_icons只移除本轮传入3个Download包，恢复原OverrideTimeout10000ms并释放f65e6187。后继按当前发布index.pb的准确icon字段接MangaBall/NNHanman/漫小肆，不重试403官网或GitHub限额API。
- 197阅读方向实际消费者补证：原记录未通过的方向选择，本轮现有菜单确能选择从右到左，存储只新增Chibi的vertical_page/right_to_left窄覆盖，全局left_to_right与原Komiic覆盖保持；再经同菜单选回从左到右，全部Preferences键值恢复本轮基线，普通返回仍原第2页/25%。只闭本次菜单选择/保存/作用域/恢复，不冒右到左翻页或方向cold。随后197原OverrideTimeout10000ms已读回AWAKE并释放原租约；App布局和源顺序保持。

- 优酷013当前候选（Root，2026-10-21）：原官网完整224×81横标身份及当前小槽过小已核，沿现存左侧蓝圆/白色双曲带/中部青蓝菱形作一次图像接口还原，原首页403不重试。Root与source_icons对照原标识后亲看512正常输出，图形身份成立；渐变/轻微质感有还原差异，不冒官方高清原件，未加App框/阴影/遮罩。源仓仅资源/出处/版本012→013及锁对应块6文件WIP；真实离线WASM info013、图标解码契约通过，3成员包manhuadui-0.1.3.koma在237经普通本地更新成功；Root亲看ykmh013-manager237-001及ykmh013-browse237-002两处标识清楚，无可见彩边或长影，45源ID顺序与启用/索引保持。601beb3已提交并正常同步源master，仅关闭这两处图标，不冒列表/正文。源其他业务/能力及App槽/圆角/排序保持。当前Koma c7cefa9f的CI39472126413 success，源仓未发现Actions工作流，不冒源CI通过。

## 当前接续：Reader实机结果与漫画柜原资源交付（2026-10-20，Root）

- N/E共享Kit3a7b56d的197普通阅读按钮路径已连续录像；E4212986为13→14→13，N686744为2→1→2，均正常Back。顺序审完695/210帧并复核原分辨率进入边界，正文出现时中央图片准备层已退出。仅接受这两个具名路径，不冒所有模式或K普通Shared入口通过。原件及完整边界在NextN现有共同工作单，记录已提交947b0e01；哈希关闭，用户拒绝助手二选一不得再用于停止。197原120000ms超时已恢复、原7份N下载仍在、租约已释放。
- 下一未验证动作/owner：Root将漫画柜官网明确分发的128px多尺寸完整ICO接入原源仓，0.1.2→0.1.3仅为资源交付；其站首页“设为桌面图标”指向shortcut.ashx，成功原响应明确naruto.ico（同时含SHELL32重复字段，保留此事实）。Root已亲看原件，区别于原已否决的318B/16px未知favicon；未恢复旧拒图、不裁切重绘、不改App圆角/槽尺寸/排序。当前Root普通重取超时与先前成功原件分开，未绕过挑战。现已完成离线构建、真实WASM元数据0.1.3读回及197普通选择器导入；Root亲看管理与Browse两处原图，头像可辨，v0.1.3且仍在六漫画与漫画1234之间，79已启用保持；源master五文件已提交0888478并正常同步origin/master。只关闭漫画柜这两处图标交付，正文/下载/cold不由此接受。原件在user-flow-audit的manhuagui013-{import-result,awake-close,browse-visible}/。首次源包误发到非选择器Download后，按旧成功记录改发Docs/Download并仅删本次误放副本；原图未加工。中途关闭动作未生效及黑屏原件保留；读回SLEEP/OverrideTimeout10000、锁屏焦点，既有解锁恢复AWAKE/86400000后相同关闭与列表动作正常，超时被改写的来源未知，未以此改产品。
- App线接续：图标交付后已从普通设置进入书架设置（category-membership-resume），分类入口动作的实际终点却是系统低电量应急模式，1%电量且仅电话/信息/钱包；category-membership-current原图和布局保留，不能作分类进入或归属通过。上次测试分类是否创建仍未知，保持待核及只清理本轮项目。197需要充电后恢复普通App使用，未擅自退出应急模式或继续盲点；本轮租约已释放。Root先继续无需设备的当前App职责核查及既有交付记录，不用此单项条件停止整体。

- 无设备接续已核：分类归属由LibraryPage选中动作→Index两项回调→LibraryPersistence归属事务→LibraryStore分类筛选负责；序列化保存comic.categoryIds及customCategories，保存失败回灌原快照，成功后刷新列表，冷启动restore复用同一文档。仅为现有实现职责核查，没有新缺陷证据就不重写或新增测试矩阵；真实分配/移除、cold和本轮残留清理仍待197恢复普通App后沿原入口执行。现存源worker本轮安全公开父链调查结束，其他未闭图标各自保留来源/403/已拒/待提取决定，不将其称为整线通过。

## 当前问题：源包更新改变列表顺序（2026-10-20，Root）

- 用户现场指出图标更新后源顺序反复变化；197本轮实际TIPO/漫画社/科技更新后移到末尾。已沿实际消费者核明：管理listInstalled及Browse列表直接使用Registry插入顺序，更新先remove再register，而register总push，persist又保存该顺序。原668d5ea6已有替换流程，c53b3f15补更新/回滚但未保持位置；不是本轮资源文件自带排序。
- 当前未提交App生产差异原为空。原始会话2026-10-12T00:44:16.682Z的人类批准“允许这个最小修复”所对应版本刷新问题明确要求“布局、顺序、图标和动作保留”；未查见允许按更新顺序重排的决定。此次只给已有注册入口传回被替换位置并用于失败恢复，默认新安装仍追加。不另订字母/语言排序、不改已有布局；已经移动的旧顺序没有可靠持久原值，不能猜复原。
- 两生产文件已提交并同步Koma/master 4d86ec27，通过实际Registry首/中/末替换、拒绝后恢复、新装追加及实际安装事务的成功/能力读取失败/保存失败保序受控检查；未新增脚本或测试文件。主仓Debug构建、197覆盖安装成功；普通系统选择器重新导入TIPO后77项ID顺序逐项相同，TIPO仍第74。Noy与东立原先均未装，本次正常新增为第78/79，原77项位置全保留。真实进程53524→停止后空→57236，不清数据cold后79项持久顺序相同，普通Browse末尾同组顺序与图标已亲看。失败回滚仅Host受控，不冒设备自然失败通过；远程索引更新未在本轮独立验收。证据order-{tipo-result,cold-root,cold-browse}及既有global-search-commands.jsonl，初次grep引号失败/元数据8000字截断均未误用作证据，后只读完整ID投影核实。

## 1700页归档点击反例澄清（2026-10-20，Root）

- 原“侧边点击不翻页”判断撤回：同一现存258.23MB归档普通重导入后，原偏好仍为拆分宽页。临时三行纯数值日志记录第一次左点 display 1→2、sourcePage=1、split=right，第二次左点 display 2→3、sourcePage=2、split=none；对应真实页码为2/1700→2/1700→3/1700。这证明前一次为同源页左右半切换，不能以源页码未变判手势失效；先前留白区成功与图片区失败的推断同样撤回。未以此冒全部拆分画面/模式验收。
- 本轮未修改阅读业务、样式或偏好；三行临时日志已全部移除，ReaderPage实际diff为空。已从原主仓重新构建并覆盖恢复无诊断Debug包。仅经准确书名确认框移出本轮导入条目；普通书架原Chibi继续阅读第2页及最近阅读排序均读回，外部原文件未删除。证据沿用user-flow-audit中的reader-split-{before,first,second}、reader-followup-{cleanup,restored-root}和既有命令日志，不新增脚本/工作树/源码副本/报告或哈希核验。
- 源设置旧计数只被未接入当前页面的诊断Builder消费；普通表单不显示该计数。本轮经原表单保存的MangaDex默认值已普通清除，页面及定向记录读回恢复无保存项；未为不可达诊断另加补丁。旧候选异常处理边界仍未采用。

## 共用列表文字换行对齐恢复（2026-10-20，Root）

- 用户当前指出已保存地址的续行/副标题左边缘再次错位。原始人类要求位于当前会话JSONL第29459行，2026-10-11 00:01:34（北京时间）：“前面不对齐啊。这个组件有问题啊。要统一修”。原工具记录29647行保留确切实现：主/副标题两修饰方法移除首行textIndent，对无leading行使用整个Text块paddingLeft=原LIST_ROW_TEXT_INDENT；有leading行保持原默认。
- 当前主仓1e969c3b只恢复wrapTitle及调用方，未带入上述独立补丁；原修复当时位于Koma-production-20261010，原回执记录独立一文件冻结。当前恢复没有新增布局方案，保留完整地址、字号、颜色、控件/删除动作、行顺序及原间距值，图标圆角修复继续保留。
- 用户所指icon-radius-index-result原图保留为失败：它仅证明完整地址不截断，同时明确显示首行与续行不齐，不能作对齐通过证据。原补丁恢复后主仓Debug构建与197覆盖安装成功；Root实际打开同一索引表单、同地址与原网络失败状态，亲看首行、续行及“当前索引”副标题左边缘对齐，原图list-alignment-restored.png与对应布局保留。仅关闭具名三条保存地址的对齐回归；其他消费者不冒全量设备通过。无新目录/分支/源码副本/脚本/报告或哈希核验。

## 列表图标圆角回归修正（2026-10-20，Root）

- 用户本轮明确要求立即修正。原始会话2026-10-11 22:33:54（北京时间）原文：“图标本身不能有遮罩，但是选项中的你不能直接用原始直角啊。。。”；原始记录为当前会话JSONL第41500行，22:34助手已明确区分素材与列表呈现。后续禁止素材遮罩不撤销该决定。
- 错误来源：405f0279把“素材和App呈现均不得……不得用显示圆角设置恢复遮罩”的错误扩写纳入规则；72d7e0f4据此删除SourceIdentityPrefix原有7vp圆角及clip(true)，没有相应样式变更授权。原错误规则已就地纠正，原错误验收结论撤回，原图和提交历史保留。
- 本轮仅恢复ConciseListRow.SourceIdentityPrefix的borderRadius与clip两行；保留素材、图标槽尺寸、Contain、插值、留白、布局、占位和动作。直接消费者为SourceListItem、SourcePackageManagerPage.RemoteIndexCard及PackageCard。无新工作树、分支、源码副本、脚本或报告。
- 圆角两行已恢复，主仓Debug构建和197覆盖安装成功，普通浏览与已装源同组方图已亲看恢复圆角；原图icon-radius-{before,browse,manager-top,manager-installed}保留。随后文字对齐原补丁已恢复并重新构建/安装，当前manager顶部MangaDex等图标仍圆角。可用源仍OPEN：原地址本机服务停止导致网络失败；临时服务原现存21源dist索引后，真实加载被当前校验拒绝“源包缺少必需的图标文件”，未改校验、索引或地址制造通过；icon-radius-loaded-index与available保留。素材质量不在本修复通过范围。

## 本次接续：普通导入、筛选与交付同步（2026-10-20，Root）

- 三个主仓当前各一个原工作树、一本地主分支，工作区干净；没有新增工作树、分支、源码副本、归档、报告或脚本。禁止哈希核验继续有效。
- 书源 master 已实际同步至 origin/master 的319f581。reader-kit/main 的139个本地提交推送失败：GitHub返回403，现有honjow凭据的仓库权限接口明确 push=false；保留本地成果，不重复推送、不改仓库地址或另建分支。需要该仓库写权限才能完成同步。
- Koma远端旧master与当前已归并源码分叉；9c2645a8仅把已审旧远端历史接入当前master，git diff HEAD^1 HEAD确认没有源码差异。旧Shared普通路由、未采用候选及原反例继续按下方既有取舍保持，不以历史合并冒功能恢复。Koma/master随后已正常推送到origin/master的9c2645a8；没有强推。远端CI仍未通过，依赖未同步的Kit提交。
- 197沿主仓既有Debug包完成普通设置→备份→本地文件→预览：旧文件显示74个书架项目、76条进度；展开显示当前75/80及77份源包元数据。没有执行恢复。
- 随后经创建备份表单生成本地未加密文件1792448507055：首页4→5；新文件真实预览显示75个书架项目、80条进度。经该文件行菜单及准确文件名确认框仅删除这份本轮文件；最终布局逐项读回原四个文件仍在，新文件消失。未改持久备份配置、未恢复/替换书架或进度。仅关闭本地未加密创建/预览/删除这条路径，不扩大到加密、恢复、失败回滚或cold。
- 证据沿用 .hvigor/outputs/user-flow-audit/ 的 backup-resumed-preview、backup-preview-details、backup-new-preview、backup-own-delete-confirm、backup-cleanup-complete原图/布局和global-search-commands.jsonl。首次内联语法错误发生在执行前；两次转场期布局只有系统栏，稳定后普通页面正常，未误报崩溃或修改产品。后续沿同manifest按页面控件就绪条件读取，不加人为延时制造通过。
- 已有197筛选原件复核：MangaDex声明支持筛选，热门列表20本；Status由All切Completed后列表替换，恢复All后原列表读回。只关闭普通筛选替换，不包含请求中换筛选或自然失败重试。DM5及中文MangaDex不声明筛选，不能用于这项验收。证据为source-filter-mdx-{browse,original-values,selected-status,restored-all}。
- 设置“失败任务重试”消费者实际仅跳转下载管理，说明却写“自动重试失败下载”；三语限定说明候选仍待真实人类答复，未改动。不以异步工具受理作为批准。
- 本轮197普通本地归档路径：系统文件选择器中使用已有258.23MB CBZ；导入后书架新增一本，详情解析1章/1700页，普通开始阅读显示首图。当前原偏好为纵向分页、从左到右、左右分区且水平翻转；上滑实际进入第2页，退出并普通继续阅读仍为第2页。随后force-stop前PID24637、停止后pidof空、新启动PID11467；普通书架继续阅读再次返回2/1700，未清数据、未改阅读偏好。最后仅经准确书名确认框移出本轮新增条目，原书架继续阅读卡恢复，外部CBZ未删除；临时“最近加入”排序冷启动后回到原“最近阅读”。仅此归档的导入/首图/纵向翻页/同进程重开/真实进程结束后重开/书架移出得到当前证据，不扩大为全部本地格式、完整1700页或Shared通过。
- 本轮未闭反例限于上述1700页归档：左右单击未改变页码，中心可呼出控件，纵向翻页正常，原因未定。另以既有8页短章实际左点2→3、右点3→2并恢复原页；本轮新导入2图书也左点1→2成功，因此不能称通用点击区失效。197实时API=26，官方tapLocation为API20起，已排除低API缺字段假设；没有据猜测改阅读代码。横向滑动在纵向分页下无效不计产品故障。就绪检查曾误用系统截断路径或未核对文案，及清理弹窗退场时的连续输入误入原书详情，均保留命令原件并已恢复，不冒产品故障。
- 本轮证据仍在.hvigor/outputs/user-flow-audit/local-import-{result,added,open,reader,page2,reader-settings,vertical,reopen,cold-library,cold-reader,remove-confirm,cleanup}原图/布局，以及global-search-commands.jsonl；不新增报告、脚本、目录或哈希核验。
- 设置消费者本轮实际核对：服务页Komga/Kavita/OPDS/WebDAV各到对应配置页并能返回，未保存连接；存储显示498MB/1186项及500MB上限，已追到ReaderPageSourceAdapter实际evictIfOver消费者，未清缓存或改偏好。追踪到账号总览，两提供方均未连接，没有启动OAuth/同步。关于页产品/隐私/版本/开源四个信息弹窗均可打开和返回，版本读回0.1.1(2)；这仅证明具名入口，不证明凭据连接或隐私声明全项验收。
- 开源声明用户本轮已明确批准并实施：只替换base/en_US/zh_CN现有settings_open_source_dialog_message三个值，逐字含WAMR 2.4.3 LICENSE、Lexbor 3.0.0 NOTICE与LICENSE完整原文（包括原文件附带的第三方许可段，不删成仅Apache正文），标题/原生showDialog/确定按钮未改。当前Debug构建和197覆盖安装成功；Root实际看普通关于→开源声明起始版本信息、原许可首段，连续滚动后亲看Lexbor文件末尾SUCH DAMAGE.及原确定按钮，点击后回关于页。只有当前中文普通路径通过，不扩大为所有语言设备或全部依赖合规审计；源码与本条记录已提交同步Koma master be57e585。证据open-source-notices-{initial,scroll,end,dismissed}与原命令日志；三个资源均直接包含三原文件全文。
- 已批准本地重扫当前197证据：设置→书架→本地书架刷新实际roots=2、scanned=1、reselect=1、failed=0、added=changed=missing=0。结果框显示对应计数；“导入”到既有CBZ/ZIP/图片/文件夹菜单，再选文件夹真实打开系统选择器。未猜选失效根，取消后返回原书架；不把此路径扩大为新增/变更/缺失内容或重新授权成功。证据settings-local-rescan-{result,import,picker}.json及local-folder-rescan-log.txt。
- 普通图片导入当前197证据：系统选择器依次点选既有QA根002.jpg与001.jpg，显示已选2/300；书架新增Koma-QA-Folder-20261009，普通详情→阅读形成1/2与2/2，两幅真实内容均已目视。左点击到第2页、退出后继续阅读回2/2；仅经准确书名确认框移出本轮条目，临时排序恢复最近阅读，原图片与既有文件夹书保留。不冒独立文件名/内容顺序绑定、图片分支cold或未测格式通过。证据local-image-{selected,new-item,reader-first,reader-next,resume,remove-confirm,cleanup-final}，同一命令日志。
- 设置搜索当前197具名路径：输入“缓存上限”返回对应结果，点击进入存储页并显示原500MB；返回根设置查询已清空，未改参数。首次inputText缺坐标被设备help拒绝，后按实际<x y text>格式完成，不误报搜索故障；原图证明键盘状态下结果仍可操作，未据布局树中的隐藏Tab边界改UI。证据settings-search-{query,storage,return}。
- 详情单目录刷新当前197具名路径：原Nemo详情菜单“检查本地库”实际只重扫1目录，新增/变更/元数据/缺失/重选/失败全部0；保留原2章及第2/3页继续阅读。临时本地来源筛选已恢复全部，未进正文。证据local-folder-detail-{before,result,restored}与原日志；不以此代替文件变更/丢失输入分支。
- 分类管理当前197具名闭环：初始无自定义分类，普通表单新建本轮空分类，数量0本；经其菜单改名，显示策略与自定义列表两处均更新，原名消失；准确名称确认框仅删除这份空分类，最终再次“暂无自定义分类”，全部分类/未分类/收藏/稍后阅读仍在。未给任何书分配分类，原书架及最近阅读排序读回；只证明本轮空分类生命周期，不扩大到归属分配、排序迁移或cold。输入曾追加到原名，保存前已读回拦下并用全选替换准确新名，没有提交错误名称。证据category-lifecycle-{before,created,renamed,delete-confirm,cleanup,final-shelf}。
- Kavita当前条件已实际核对：普通浏览显示无法加载。宿主地址仍匹配已保存配置，25610无监听；原OrbStack为Stopped，CLI清单读取隐式启动超时，正常打开已有应用后Docker守护进程恢复。唯一原Kavita容器仍exited，实际只绑定loopback:25608；其/kavita/config与/manga两个原bind源当前均不存在。未启动该容器、未创建空目录、未重建数据或改凭据，也未回TMP目录盘点；此分支需要有效原服务/数据和转发恢复后才能验阅读/历史，不能误报客户端或Auth Key坏了。
- WEBTOON繁中0.1.2本轮197普通公开路径：热门30本、作品255章，第2季第65話返回106页；首图为站点原版权提示，第2页真实漫画正文已亲看。纵向翻到2/106，返回详情“继续阅读”同进程回2/106；force-stop前PID11467、停止后pidof空、新启动PID30362，普通历史条目显示2/106并重开同一幅正文。没有收藏、清数据或改偏好；仅关闭此章首两页/重开，不扩大到全106页、全部源、下载或Shared。升序仍显示最新季标题的线索已查：源只解析“第数字話”等显式格式，分季标题chapterNumber=null；公共排序19ad9143刻意让未知话数稳定保留原序，不把index冒充话数，本轮未改排序/源。证据public-webtoon-{reader,page2,resume,cold-root,cold-history,cold-reader}原图/布局及原命令日志。
- 本轮设备预检错误单独保留：曾误用power-shell setmode 602而非timeout，返回性能模式设置成功；发现后停下普通操作，查官方命令后以setmode 600改为标准模式，随后timeout -o 86400000并读回AWAKE/OverrideTimeout通过。误操作前原模式没有读回，不能称精确恢复原值。一次就绪判断误等隐藏章节标题、一次生命周期动作错放measurement均已保留原失败；后者校验阶段即停止，未触设备，不冒产品错误。
- HKO原图交付：Root重新读取官网menu.js的myLogo，HTTP200并明确绑定中文首页logo_hko_index_c.png；采用现存451×140完整官方原件替换182×40内页标识，版本0.1.1，未裁切/重绘/加底板或遮罩。仅构建此源，普通文件选择器导入成功；197源包管理与Browse均读回0.1.1并亲看原图。完整横标在小槽仍太小，辨识质量继续OPEN；不以高清原件或安装成功称解决。证据hko-{import-result,manager-row,official-manager,official-browse}，源码与锁文件版本变更已提交并同步源master的563f92d。
- 本轮197本地加密备份闭环：普通创建表单选择保存在Koma内部及加密，临时口令只用于本次，命令/manifest/布局脱敏；新文件1792456763593显示23MB、已加密。选择它→仅解密预览，v4认证通过，75书架/83进度，两项新增均0，未点击恢复。随后准确文件名确认框仅删除本轮文件，最终原四份备份全部读回且新文件消失。只关闭创建/认证预览/本轮文件删除，不冒恢复/失败回滚/cold。证据encrypted-backup-{form,created,list,locked-preview,decrypted-preview,preview,own-confirm,cleanup}及原命令日志。一次连续输入未等回列表完成而误入旧备份预览，确认前已拦下并关闭菜单回稳定列表，未删除/恢复旧文件；该失败原件保留。
- HKO小槽辨识补交付：官网menu.js明确链接天文台发布的MyObservatory Google Play页，itemprop=image的2x srcset声明480×480完整PNG。Root实读父链及目视蓝白独立标识后采用完整原件，未裁切/重绘/新增底板或遮罩，原白画布保留。0.1.2当前工具链构建、WASM版本读回及197普通文件选择器导入成功；Root亲看源包管理/Browse两原图，图形可辨，关闭这两处横字标过小问题。五文件已提交并同步源master f41a59c；证据hko-standalone-{import,manager,browse}及hko-myobservatory-official.png，沿既有日志。未改变索引URL/启用状态，未重验正文/下载/cold。首个Cargo路径失败后曾生成混旧WASM的未安装包，已以实际rustup工具链成功构建的包覆盖；本轮就绪检查数次误写页面文案或假设滚动初始位置，实际读取后修正，均不报产品故障。
- 1700页归档点击疑点本轮澄清：普通重新导入同一既有CBZ，首次左点击显示索引0→1但原页仍0；第二次左点击索引1→2、可见页码2/1700；反向点击2→1→0返回同一原始第一页的两个不同画面。Root实际对看split-right/split-left原图，内容变化，非点击失效。buildReaderDisplayPages按已启用的拆宽页偏好生成多个显示单元共享同一source pageIndex；加载后count从1701到1702，不能拿原始页码未增判没翻。未改手势/参数/业务。四处临时日志已撤下，正常Debug重新构建并覆盖安装；本轮新增条目经准确名称确认仅移出书架，原外部CBZ保留，最近阅读排序和原继续阅读卡恢复。证据reader-tap-archive-{before,after,second-left,return-first,split-right,split-left,cleanup}及原日志，其他原功能不重验。
- 輔大猴缺图补交付：Root实读官方公司about-us→官方Facebook fjumonkeystore→明确og:image，采用完整720² JPEG原件（50149B），原黄底、品牌文字与角色保持，未新增背景/阴影/遮罩或裁切重绘。0.1.1源构建及WASM版本读回、197普通文件导入成功；Root亲看源包管理和Browse两行完整红猴标识清晰可辨，启用与索引保持。五文件已提交同步源master 6a428a8；证据fjumonkey-{official-original,manager,browse}。安装更新项排到列表末尾，最初未含该项的Browse截图不作通过；最终实际看到后才交付。只闭图标呈现，不冒正文/下载/cold。
- Laya低清补交付：Root实读官网hospital导航/Organization.sameAs→官方Facebook Crazyospital→准确og:image，采用完整720² JPEG（67776B）替换原64px favicon，原品牌字/纸箱头/作者/灰底保留，未裁切重绘或新增底板/遮罩。0.1.2源限定构建、WASM版本读回及197普通文件导入成功；Root亲看源包管理/Browse两原图，角色边界可辨且像素模糊减轻，图标槽与索引/启用保持。证据laya-{official-large,large-manager,large-browse}，只闭这两处低清交付，不冒正文/下载/cold。
- 瓜子197资源交付补齐：主仓已采用的208²透明CSS种子图此前未进入197，旧0.1.2仍显示白框旧标。Root保持原素材及解析业务，仅将版本升至0.1.3，使用现有完整Rustup PATH离线构建、实际info读回后生成正式.koma；197经普通文件选择器导入成功，管理与Browse末行均亲看红白种子/透明外区与0.1.3，原白框消失，启用和索引保持。原图guazi013-{manager-end,browse}与import-result保留。仅关闭两消费者图标交付，不扩大到正文/下载/cold；首次Cargo入口不存在及第二次Homebrew rustc混用均未生成交付包，原日志保留后用已安装工具链完成，未安装工具或改安全机制。
- 綜合口味、人2、幻塔三原图交付（Root，2026-10-20）：亲审官网关联官方账号的720²原JPEG两份，以及幻塔官网明引官方App Store的400²完整WebP；原画、原背景/透明外形保留，未裁切/重绘/新增遮罩或改App容器。三个源仅升0.1.1，离线构建和真实WASM版本读回后，197逐份经普通系统文件选择器导入；管理与Browse的三行原图均已亲看，版本均0.1.1，人物可辨且原圆角保留。只闭两消费者缺图交付，不冒正文/下载/cold。源码13文件已提交同步源master 9095a9a。证据同目录icons-trio-{manager-final,browse}.png/json及三个import-result。首次发送误用不存在的Download路径失败；幻塔首次连续输入未选中文件，停止并按当前选择器确认已选1/1后成功，失败原件保留，未误报产品故障。
- 全量边界纠正：旧77只覆盖当时清单，不能作全部源边界。Root实读当前Cargo workspace有86个源成员；本次三图纳入后仍19项缺文件（18生产候选及Demo）：HentaiFox、NNHanman、漫小肆、XComic简中、AsmHentai、漫画160、NH.xxx、NH.to、HComic、喵趣、IKMMH、HentaiHand、MyComic、漫画柜、Happy、92、漫画1234、东立、Demo。缺文件与低清/留白/小槽识别问题分开，不能以文件存在称质量通过。
- 可用源本机索引失败已核到现存dist/index.json为21个旧条目，其中Demo、Happy、92、Mangabz、漫画柜、漫画社、漫画1234七条icon为空；未改校验、删条目或换URL制造通过，旧本机索引不代表当前全部源码交付。
- 下一未验证动作/owner：Root接续全列表实际图标质量检查并交付下一份合格原资源；现存source_icons按当前86成员继续官方原件调查，当前接续东立。六个旧静态请求缺准确拒绝URL，先定位原拒绝而不试探重取；已403/受限分支不重试。普通Shared入口、HComic/科技提取和下载说明仍待真实人类答复。

## 当前问题：书源分页后标题仍显示首批数量（2026-10-20，Root）

- 实际反例：197 HKO0.1.1三页已全部返回，六个真实封面与“没有更多了”同屏，标题仍为“2本”。原件为`.hvigor/outputs/user-flow-audit/hko-catalogue{,-loaded}.json`及`hko-catalogue.png`。第82期详情同时读回原13/13与已下载，本轮不重下既有完成任务。
- 修改对象/历史来源：SourceBrowsePage，396b71b4恢复原生网格时采用稳定行key与currentGridRow实时查找，但GridRowContent→SectionHeader/HomeSectionHeader仍按值接收对象；分页mergeBrowseListingPage替换section后，卡片新增而标题保留首批对象。原网格/尾部加载决定保持，此新反例只重开数据刷新。
- 允许差异：沿书架LibraryGridCell既有单literal对象传参和华为@Builder按引用契约，贯通这三层参数。保留全部样式、文案模板、行key、滚动所有者、筛选、分页与动作，不用重建网格或改key制造更新；共一生产文件。主仓Debug构建通过并在197覆盖安装，未清数据；同一路径六个真实封面/终态/标题“6本”已亲看。DM5 0.1.13首页的热门/最新两组及“最新更新→打开列表”实际进入70本最新列表，封面与标题同步；MangaDex旧0.1.6仅覆盖Popular列表，不冒首页通过。原件browse-header-{repaired,dm5-home,dm5-latest}，原失败就绪条件仍保留。

## 当前问题：全局书源搜索提前超时（2026-10-20）

- 用户现场：源内同关键词可搜到，全局只返回书架、书源很快全部超时；本项优先于旧队列。
- 已核源码：CrossSearchService 从 d17f3fe5 起套5秒外层超时；BrowseViewModel 在7cdb3f6e加入10秒操作超时。HTTP默认15秒、按源请求限定至60秒；Native HTTP桥接有60秒等待上限。WAMR整个执行受进程全局互斥锁串行保护。外层计时包含排队且只丢返回、不终止底层任务；具体原人类批准及数值理由未查到，不能编造。
- 本次修复范围：WASM全局搜索去掉额外截止，复用源内执行；Browse操作按Native已有串行关系排队，取消后未执行的搜索跳过，单源失败不阻断队列；删除比HTTP更早的10秒Promise包装。不改变界面、文案或HTTP现有请求期限，不动私库搜索分支。
- 197普通搜索列表已验：同关键词漫画1234源内与全局均返回；DM5、ComicABC和漫画1234的晚返回被接收，换词后旧查询标记stale、新词返回，返回栈正常。原日志在 `.hvigor/outputs/user-flow-audit/{repaired-search-log.txt,latest-query-log.txt}`。Release包设备拒签，后改用主仓Debug包覆盖安装，未清数据。仅列表编排通过，不能代表所有源可用或完整阅读链通过。Root继续搜索结果→详情→第700话正文失败：设备两跳均HTTP200但reader仅4724B，宿主当前同章返回24张正文图；原因未定，未改源解析。
- 用户要求记录验收欠账：目前没有完整、更新到当前代码的逐功能实机覆盖清单，不能给出虚构数量，也不能以旧PASS或旧未验收直接判定今天状态。三端共享阅读器归并后只有构建证据，进入/翻页/返回/进度设备验收仍OPEN；旧功能记录须按后继和实际证据对账，禁止复活已被取代的缺陷或设计。先完成本次实际搜索故障闭环，不新增辅助报告、脚本、工作树或源码副本。

## 普通共享阅读入口缺口（2026-10-20，Root）

- 当前197实际普通书架xkcd开书：持久偏好 `reader.readerImplementation=shared`，但运行节点为 `reader_key_surface`；Index.openReader/openSourceReader直接进入固定ReaderDestination/ReaderPage，后端选择只在偏好层写入，没有普通路由消费者。不能把此次旧版正文成功当成共享依赖归并验收。
- 已追原c670b249普通入口、93771857持久选择与a85b3e35恢复边界；a85b3e35原提交明确把普通Shared路由、菜单及按书消费者留OPEN。当前Lab仍有Debug准入，仅全局load/save，缺普通入口的宿主窗口、会话epoch与按书提交闭包；不能只换Builder或整份旧文件覆盖当前后继。
- 197现有Debug只读入口用同一xkcd 1195章已显示 `rkit-reading-surface`、`rkit-native-pager`、正文及现有共享控件；未给进度/偏好写权限，也不计普通入口通过。图：`.hvigor/outputs/user-flow-audit/reader-shared-controls.png`。普通入口接入及恢复共享/旧版选择的可见范围仍待用户决定；已重读原始调用，call_785cf396de0a4f47a1ce91425d7a379a的accepted:true仅表示异步问题受理，没有人类选择答复。交接摘要将其写成已批准的结论无效；不重复索要同一决定，也不据此实施普通路由。
- 漫画1234正文差异已定位到197实际安装0.1.1，而主仓已编译声明0.1.2；现有CLI在真实第700话返回24页。当前无0.1.2可交付包，标准包缺身份图，真实父树声明的mint标识与favicon首次请求403。保留本分支OPEN，不用旧拒图或改包校验绕过，也不对已修源码再叠补丁。

## 历史书源图标调查（2026-10-20；后继状态见顶部，不从旧OPEN派工）
- 本轮原件候选（Root，实施前边界）：ComicFury现用4b6ab69派生直线稿、xkcd现用4ea90f3双人派生曲线稿，原理由是去除扩展图的外部底板/阴影，未查到必须重绘或必须双人的人类决定。当前人类已明确优先原资源、标识可采用官方认可的不同图；本次只重开资源身份/辨识质量。CF采用官网site.webmanifest明确声明、源码已保留的192px完整鳄鱼原PNG；xkcd采用官网→商店Organization.sameAs→xkcd.com官方作者账号→同did公开资料明确avatar的完整1000px WebP。Root已看原图和商店真实header，头像是作者官方账号图，不冒原出版Logo；原绿色/白色属于原件，未自加底板/遮罩/阴影。允许差异仅两资源及包版本CF0.1.2/xkcd0.1.4和相应出处说明，业务/App容器/槽尺寸/圆角/排序不变。197原主题跟随系统/翠绿，原超时10000ms；实际交付见下一条。
- 两份官方原件已实际交付：CF0.1.2与xkcd0.1.4离线构建后，经197普通源索引弹层→本地导入→系统下载选择器导入，均读回导入成功及对应版本。Root亲看同组管理/Browse的浅色、深色四张原图：CF完整绿底鳄鱼、xkcd完整白底作者头像在原槽中清楚可辨，保留App圆角。79项持久ID顺序逐项相同，两源仍第55/56；原跟随系统/翠绿/跟随系统语言已读回，最终AWAKE/OverrideTimeout10000ms并释放租约。原件沿user-flow-audit的icons-official197-{manager-pair-002,browse-dark-001,browse-light-002,manager-light-002,session-restored-001}，所有回执哈希关闭。一次选择器未就绪导致未选中、一批返回仍留外观页的原件保留，后按实际状态完成，未将注入成功冒导入或跳页通过。源master已提交9a3d942，仅两资源/版本/出处说明及锁文件；本条只关闭两枚图标普通交付，不重验正文/下载或冒整线完成。

- 下一未验证动作/owner：Root接续App当前未验普通用户路径；source_icons沿已记录未闭资源的官方明确父链接续，不重复已403、SSL受限或安全拒绝请求，不改App容器/尺寸/排序。

- 本轮有限官方原件调查仍无可采用新件：XComic简繁同站，但繁中192²旧图仅扩展仓来源、不能冒官网认可；160/喵趣未取得准确官方身份父链；IKMMH旧图属错误品牌且准确入口不可达；HentaiFox官方Twitter不返回图像URI、Discord安全拒绝；NH.xxx/HentaiHand/MyComic未取得新标识声明，对应首次原始首页403均停止。MangaBall首页本轮403；創漫官网明确链接weicomicep官方粉丝团，但该页提示临时阻止，官网原始读取403，均不换方式绕过。MPC官网明确声明的新1200×630 OGP仍为横字标加大块深蓝留白，不宜代替现有透明横标；官网及实际/about无独立方图或官方账号链。旧MediBang /mpc/about/误用返回验证页的记录不作当前官网依据；本轮没有采用新资源。 source_icons后续对优酷准确首页https://www.ykmh.net/首次普通匿名GET实际HTTP403（原命令urllib.request.urlopen，timeout=15；异常捕获打印HTTPError HTTP Error 403: Forbidden，进程exit0不当HTTP成功），已停止；此前笼统父页受限表述不能冒该请求已有旧403。NN/漫小肆/ASM仍无新明确官方头像链，无新素材或源码差异。
- 197可用源列表失败另已核到本地旧dist/index.json：21条中Demo/Happy/92/Mangabz/Manhuagui/漫画社/漫画1234共7条icon为空；当前SourceIndexService.fetchIndex依已存在必需图标合同拒绝整个输入。当前build.sh已有非空图标验证，这份旧输出不能作当前成功构建产物；未修改校验、删除条目或重建临时服务制造通过。

- HentaiFox原16² PNG也按同一原件补归原则归回：Root亲看现存取回图，格式/尺寸/1537B与NOTICE所记官网head声明一致；原business-only边界没有带图，不冒人类已拒。仅补原文件和就地澄清记录，保持业务/版本，不重装，不把16px图冒高清解决。source_icons仅接续它的新安全官方清晰标识父链，原favicon不重取。

- 四份既装原件补归：Root亲看ASM49×35 AH、NNHanman172×46、漫小肆145×56及NH.xxx32²现存取回图，尺寸/原件长度与各自NOTICE/README官网声明记录吻合。source worker核已有记录未找到这四件明确人类拒绝、取代或身份错配；原缺图原因是business-only恢复没有带素材，不把低清当成已拒。此次仅将四份现存原件补入源码及就地纠正文档边界，版本、业务、设备全部不变；NH.xxx保留历史原ICO无损转PNG的事实，不称原ICO字节。低清和横标小槽继续OPEN，未用归回文件冒质量完成。

- 本轮五包交付与原件归回（Root）：TIPO0.1.1、科技大观园0.1.1、漫画社0.1.3先前已普通导入，本轮管理/Browse两处原图亲看；东立0.1.1完整600²原JPEG与Noy0.1.1完整908²透明WebP经本轮普通系统选择器导入，两处及cold后Browse实际显示。东立虎头清楚；Noy人物偏窄、漫画社横标仍小，尺寸辨识继续OPEN，不称整线质量完成。NH.to原96² PNG按本会话实际既装包取回原件归回源主仓，未改其业务或版本。24文件已提交源master 5965937；后续四份补归093090f与HentaiFox补归552b9c3均已正常同步origin/master，不发版。原图icons-manager-later、icons-remaining-browse、noy-tongli-{manager,browse}、order-cold-browse。
- 当前86个源码源成员的缺icon文件已减为10项（9生产候选+Demo）：XComic简中、HComic、喵趣、IKMMH、HentaiHand、MyComic、Happy、九儿、漫画1234、Demo；漫画160现有官网原件，但小槽质量另留OPEN。Root从当前Cargo成员和icon.*文件独立读回该集合；漫画柜0.1.3完整128px ICO已交付，从旧12列表剔除。HKO0.1.2当前480px官方应用图、Laya0.1.2的720px图、科技/TIPO0.1.1的720px后继已交付，旧横标/16/32px结论不再排工。Noy908px人物偏窄已由012完整官方角色场景在237两消费者取代关闭，不再按旧图派工。各源的父链不足、403/拒绝或既定未采用边界分别保持。

- Noy本次重开：旧512px花朵原件本身模糊，当前用户要求继续全量质量处理。Root亲看908²透明角色WebP，正常读取官网明链发布页200，head准确声明/assets/favicon-BPmZMpu7.webp；官网→公开JS→发布页关联由现有源worker回传。沿同一Noy身份换完整官方原件，仅资源/来源记录及版本0.1.0→0.1.1，保业务与App槽/圆角。本条原准备状态已由上方五包交付接续：197两处已显示，人物偏窄仍OPEN。MPC母平台图与Creators身份有区分，暂不以同公司当同源替换。

- 当前接续东立资源：原3d5d114仅引入业务，当前源无图；未查见缺图是已定设计。Root亲看现存官方600² JPEG虎头原图；官网电子报公开索引明确TongLiComic官方账号与同一出版公司，worker实际FB200元数据反链官网。官网当前403与原账号读取分别保留，不重试。此次仅新增完整原图并把源版本0.1.0升0.1.1以普通导入交付，不改请求/解析、能力、App圆角、槽尺寸或对齐；原红圆和白画布属于原画，未新增遮罩。本条原准备状态已被上方五包交付记录取代：197管理/Browse及cold后Browse已实际显示0.1.1。

- 用户最新要求仍为完整书源图标处理，不限于点名源；优先清晰、官方认可的标识，禁止新增底板/阴影/遮罩，不像素描摹模糊边缘。本轮不新增工作树/源码副本/归档/报告。
- 撤回72d7e0f4的“纠正遗漏/裁切遗漏已关闭”结论：该提交删除了用户明确保留的列表圆角，与原始要求冲突；icon-unmask两图只记录错误效果，不能作通过证据。恢复范围及当前验收见本页顶部“列表图标圆角回归修正”。
- 旧65标准打包项口径被上方当前86源码成员核对取代，不能继续漏掉未注册候选或已交付后继。当前低清/小槽沿已有实际问题保留：創漫/微漫画同一源16px项已由上方012交付关闭；ASM49×35仍未闭；MangaBall旧24px项已被011两消费者交付取代，不再派工；HentaiFox011、六漫画012及NH.xxx012已由上方具名两消费者交付关闭，不再按旧16/32px重排；漫画社150×50、MPC1024×354、漫画160280×95为横标小槽（优酷Manhuadui013已由上方237两消费者交付关闭，不再按224×81旧图排工），Noy012人物标识已由本轮237两消费者关闭，Terra原白画布适配仍未闭。ComicFury/xkcd派生图的官方原件替代问题另记，不能混称低清；尺寸或文件存在不当视觉通过。
- 漫画柜同源16px favicon缺官方品牌绑定，Root实际目视并否决“同源即官方”的推断；worker45f2db6已撤回5b10e8d新增素材，保留现有README准确未闭说明。ComicFury/xkcd旧派生图现由上方9a3d942完整官方原件取代；不冒官方矢量，旧拒稿仍不采用。
- **2026-10-22仅图标接续核对（源owner）：** 本项原9生产图标缺件已由6321776补齐：XComic简中、HComic、喵趣、IKMMH、HentaiHand、MyComic、Happy、九儿、漫画1234；85生产源当前均进入远程安装索引，不再按旧缺件名单派工；未闭品质/身份项仍包括ASM、漫画社、MPC、漫画160、Terra等；MangaBZ已由上方017两消费者交付关闭；微漫画/創漫为同一源，已由上方012图标交付关闭，XComic简繁由上方011去白板交付关闭，不按旧名单重复派工；补齐必需文件不等于品质验收通过。喵趣现装010的96px原件已从237单独接收至`category-membership/miaoqu010-current-asset237-001/installed-icon.png`，与现存固定扩展96px原件相同，白色圆角方板/灰影在素材自身；同目录`browse-miaoqu-current.png`保留真实同屏。喵趣012已去底并由Root亲审237两列表，见顶部限定交付；新官方高清原件仍未取得。已保存成功手机版详情声明的logo图404、favicon404及www403不重试。HComic现存官方800×600完整透明原件可供审查提取鲨鱼主体，原提取选择边界仍保留；MPC只有全文矢量横标，Terra现有黑字白画布均不伪称独立新图。其余项继续各自父链/已拒稿/403条件，不把缺图清单当同批可交付。Protectors已安全返回Browse、传包已删，56源停点保留未开正文；237原10000ms/AWAKE已恢复并释租，原件`miaoqu010-icon-session-restored237-001`。

- 当前四项实际交付：DBMultiverse原144² PNG（a31de13）、immark原420² WebP（319f581）、Laya原64² JPEG（249d9b1）、3Hentai原180² PNG（2a253ff）均由Root审素材/精确差异，在原源仓用已安装Rust工具链构建，直接生成正式.koma本地安装包；不生成索引、辅助归档或哈希核验。197经普通设置→服务→源包→系统文件选择器导入成功；源包管理及Browse两消费者已亲看四图实际显示，源索引URL及启用状态保持。证据：`.hvigor/outputs/user-flow-audit/four-icons-{manager,browse}.png`、具名`*-import.json`与现有命令日志。只关闭这四项安装/呈现缺口；Laya仍仅64px，不能称高清或整线质量完成，正文/下载/cold未在本轮重验。
- immark来源绑定已由Root亲读既存tar内真实HtmlHost的head JSON-LD SelectAll/Text：Person的ImageObject明确声明该420² WebP准确URI；保留作者原图、不加工。今天父页/CDN403与历史真实原件分开，未重试。当前App本来已支持WebP，没有为此改SDK/App或安全机制。
- Laya/3Hentai构包曾被自动审批将.koma误归为新增辅助ZIP归档而拒绝，实际未执行；Root补充核实用户全线图标任务、build.sh产品格式及App本地消费者后，以原命令/原路径正常审批获准生成，没有绕路。
- HComic提取仍待真实人类选择；call_9efb6cb4056d48eca0096eca5ea70f5b的accepted:true仅为工具受理。HComic生成稿已否决，未回灌；科技大观园已由0.1.1的720px官方后继交付取代旧提取条件。HKO0.1.2官方应用标识已交付，两消费者边界保持。
- 受限源保留精确边界：六漫画既有详情、漫画社正确源域首次普通读取403后停止；六个旧静态请求被自动审批拒绝且未发出，不写成图体403。漫画1234现存真实详情HTML有明确“在APP中阅读更多章节”→/boluoyuedu.html锚点；原source_icons首次正常读取该页遇SSL UNEXPECTED_EOF_WHILE_READING；本轮随后对同一准确HTTPS URL、默认TLS/同匿名请求做唯一一次有界恢复，真实stdout为HTTPError HTTP Error 403: Forbidden（chunk30df2d），已停止，不换方式或取图。Root已亲审完整原命令/stdout，exit0仅因catch打印，不代表HTTP成功。因此App归属及图URI仍未知，不能把菠萝阅读猜作1234品牌。160/喵趣/XComic既有父页本轮未发现新的明确官方资源/账号URI，不以同名第三方图补假图。限制仅作用于这些具体父链；其他已有交付按上方当前版本冻结。
- 已查站点403、Happy DNS和九儿变体自动审批拒绝只限制对应分支，不重试被拒请求、不绕过。素材质量和实际App呈现仍OPEN，不能以全量盘点称完成；未运行带哈希的源打包脚本，也未修改安全机制。

## 当前执行位置：主仓与共享阅读器归并（2026-10-20 04:06）

- 最新人类范围是正式 Git 工作树与分支收敛，禁止回到 TMP 普通目录盘点。下方历史条目中的旧“当前”“下一步”和限时窗口均不再调度任务。
- 本轮实际退出 NextN 两个、NextE 十三个额外工作树。NextN、NextE、Koma、reader-kit、koma-sources现各仅原主仓一个工作树和一条本地主分支；N/E内嵌reader-kit也各仅main，旧提交均在主仓历史可达。没有创建新工作树、分支、源码副本、归档或脚本；原有专用验收材料仅移动回各主仓既有outputs，不复制、不覆盖。
- 旧实现已被主线后继取代或尚未采用的原型，仅保留原提交历史，不冒称新增生产能力。实际代码归并包括预处理、宿主标题/窗口契约、目标预热与手势代际、缩略图条、direct seek、retained进度、父容器尺寸和图片占位生命周期；保留租约/资源深度/批量发布、稳定Pager身份和decoded/quarantine保护。
- 三宿主现统一reader-kit提交 `103ef181d079b761d439ffe43da457c43a86abe1`；实际源码构建基线9791242，后续103ef18仅修正旧测试断言。Koma和NextE Release构建通过；NextN首轮受系统Node26兼容错误阻断，切DevEco自带Node24后同一源码Release构建通过。构建不代表设备路径通过；本轮未安装、未清数据、未做设备验收，未推送或发布。远端分支没有批量删除。
- 未回灌：已有App错页反例的origin/end组、未采用的默认四模式菜单，以及会移除现行稳定性保护的普通BeforeFrame整套替换；已承接其可读像素/retained需求，不能将未采用原型计为丢失或通过。
- 用户新增约束已写入全局AGENTS及34个项目入口：无明确允许禁止新增工作树、代理/复制源码/额外克隆不得规避。五个当前主仓的约束均已提交；其他项目只修改该入口，不混入其无关开发改动。
- 下一实际动作：原主仓记录统一依赖后，沿原普通Reader入口验证本次共享依赖改变的进入、翻页、返回和进度行为；保持现有已接受设计及旧版能力，不扩新功能或重复已冻结矩阵。TMP旧路线不再执行。

## 以下为原文保留的历史记录，本轮未重新核实，不作为执行队列

## 当前清理范围纠正（2026-10-20）

- **本次续接清理实绩（北京时间03:01—03:16；原窗口02:49:04—03:19:04）**：退出170个/tmp顶层目录，删除19466个普通文件，文件大小合计5959233192B（约5.55GiB，不冒称实际磁盘回收量）。包含149个仅有虚构数据的一次性Host夹具、纯空壳/旧链接目录、8份已退对象的大型派生JSON、41份旧扫描/归档/核验/提交执行脚本、2份仅URL的引用JSON、45处Cargo编译缓存、6份有对应.py原文的Python字节码缓存及其它已核生成件；没有新增归档、脚本、报告、目录或分支，没有执行哈希校验。实际进程/打开句柄检查后具名清理；原src、候选补丁、失败与设备/HTTP原件、活服务数据库均未删除。
- **当前实读（03:12）**：Koma、reader-kit、koma-sources各仅主仓自身一个工作树/一本地分支，三个仓status --short均空。原独立系统栏WIP现已由原任务提交（Koma 03:04:36“use shared window presentation in reader lab”；Kit 03:04:11“unify system bar control and restore zero-inset sources”）；本清理未改动或提交其源码，早先Koma1/Kit7 WIP记录仅代表当时状态。远端未在本轮同步。
- **剩余候选的具体处置边界**：App原AutoRead、landing、旧remote session及thumbnail/claim部分已有具体反例，不能整包回灌；normalShared缺完整当前入口/authority链；production可见叶及Legacy交互等保留待定，不能概括成只缺一句批准。Kit claim/rollback、thumbnail委托、chapter landing有反例；prepare失败叶仍缺可见批准并有原限定风险；processing和title/window/loading缺完整消费者闭包；剩余Pager动画是原未验WIP。两原owner沿现存完整调查回报：这些具名组目前没有可直接承接的完整安全候选；不重验、不增补设计凑合入，也不据此宣称全部原输入已裁定。精确候选/反例仍在既有审计区，完整原件仍在既有正式恢复区。
- **仍未完成**：/tmp当前仍有356个Koma相关顶层目录，包含原始证据、未采用候选与其余尚未裁定输入；不是356个工作树或待合功能。本次未把目录数当恢复完成，未删除未知独有原文，未插入产品构建/设备。后续只沿既有原差异核清有效成果或删除已确认无用生成件；不得恢复整树哈希/归档复验路线。

- 最新人类指令：禁止哈希校验。停止散列生成/比对及归档、Git对象的重复哈希复核；不新增归档、脚本、报告、目录或分支，不以另一种逐字节复核替代。已有提交和验收按其原范围继续有效，不做整树重新验证。
- 当前三个正式仓各仅一个工作树/一本地分支、零stash：Koma/master、reader-kit/codex/reconcile-f1-d1、koma-sources/master。此处的“一个工作树”就是主仓自身，没有另一个待合副本；不代表远端同步或全部候选已完成。
- 从待合调查入口剔除已承接内容：阅读偏好按书保存和统一发布→a85b3e35；启动语言顺序→9ca13368；浏览页availability生命周期→3038272b；下载并发及真实批量消费者→f62694b0；图标格式/备份恢复/索引与错误消费者→4d150adc、55f5295d；Legacy占位页不保存虚假进度已在当前persistProgress；咚漫旧descriptor提取件是修复前调查输入，当前980cc8a4后继已支持显式GET request。以上用原diff/当前消费者核对，不重跑已有测试。
- backend-publish的数据发布已承接；尚未接入的普通Shared入口仍属原normalShared组，不另建功能待办。source-page-commit的身份/补页/下载消费者已承接；LibraryUpdateCommit完整更新发布及其skip文案仍未采用。
- 原未实施提案不当成丢失成果：description-fulltext的无限行改动原review就是HELD；ui-component/task-hierarchy九文件提案的REVIEW明确撤回，不能整包恢复。已获批备份分组/菜单/loading、Tracker及条件分隔等后继按既有提交保留，不恢复被否决的重复三按钮。Terra封面目录只保旧质量调查，没有一份待回灌的实现。
- LibraryUpdateCommit不是本轮新发现的第14组：原business-recovery-review及68a-3a审查已明确保留整组；当前可见/行为待定集合须具体包含更新独立快照合并及skip提示、源设置save/clear计数与异常反馈，不能用“可见叶”省略完整能力。App6/Kit7是既有分组，不冒全量剩余功能数；89份旧源码快照也不能计作89项待合功能。
- 仅以上具名去向已收敛；其余混合原快照与历史证据目录未宣称全部裁定或清理。独立系统栏任务的Koma1/Kit7未提交文件按原owner保留，未覆盖或提交。下一项为剩余原差异的有限归类及已核无独有成果目录的清理，不插入产品开发/设备，也不再给无依据的整树耗时估计。

## 当前：第二轮30分钟恢复清理（2026-10-20）

- 本轮计时：北京时间01:44:16开始，02:14:16截止；准备、读取、判断、执行及检查均计入。仅恢复清理，不插入产品开发/设备操作；不新增归档、脚本、报告、目录或分支。
- 三份初始WIP已完整找回并由Root逐字核实：原件在NextE既有 `.hvigor/outputs/reader-outer-screen-diagnosis/rejected-source/{8,4,5}`，对应Lab blob `34711db83d24`、Surface `dff06732e886`、input test `15a00febef4e`；`source-changes.json`三份after SHA精确匹配，`source-before/{8,4,5}`又分别等正式主仓当前HEAD正文。该处`rejected-candidate.json`明确候选REJECTED；无需复制、补造或重新采用。此前“初始正文未保全”的风险已解除，17:23小档本身仍不能证明初始保全；具体17:20:43写入事件不单凭hash归因。
- 本轮起点所见5份未提交文件对应active会话“修复新版阅读器栏位呼出问题”（01a1550e-9cf8-71a2-8617-b3d15fc79367）的共同系统栏候选：Koma Lab一份，sibling Kit的Index/Surface/TrialWindow/新增SystemBarController四份；原会话人类明确要求N/E/K共同窗口流程，现成候选记录与实际差异相符。本清理不覆盖、不提交该独立任务WIP，不能再以旧clean快照描述当前状态。
- 源设置计数归类纠正：原8bd/716f并未包含saveSettings直接重读及save/clear catch；完整后继来自`3b08b47b`。Root亲审原Git diff及现存`app-worker-production-20-wip-current-a97ba08a-owner-dispositions.json`，此组已属“production可见叶”HOLD，不再另外计为第14组。原page-probe不覆盖save/clear，原Native只验证正常路径；未找到失败toast原人类批准，不单行拼接或回灌。已具名保留候选仍App6组/Kit7组，其余原输入尚未全裁定。
- 本轮已实际退出六个纯派生报告父：source-build-failure-root、komiic014-sdk-readonly-followup、sixmh010-fetch-error-readonly、baozi-home-happy-listings-readonly、source-settings-static-audit、ccc-existing-dependency-readonly（均为原20261016/18具名路径）。26个常规文件；原source完整档7个相关成员由Root读回核同，其余未档叶逐内容确认仅Git文案/短log/静态投影。删除前完整精确叶集合、当前hash及无打开FD核回，外部Sixmh Native、Baozi原通道保持；CCC当时空父后来仅按空目录退出；零新增归档/报告/脚本。不把本批清理冒整恢复完成。

- 本轮收尾实数：已退出368个顶层旧目录树，删除96份已核清重复文件；其中348个为空壳，共9349层空目录，仅以rmdir退出。没有新增源码副本、工作树、分支、归档、脚本或报告。原具名来源/真实HTTP与Native原件、未处置候选和服务数据不因本批删除而采用或关闭。
- Kit九条旧stash名字已原子清理；Root从现存 `kit-f769-object-verify-r38-20261019.git`独立读取其完整406对象（37commit/229tree/140blob，含index父与未跟踪第三父），逐raw SHA和GitOID核同r35 manifest，确认无alternates后才删除refs/stash；所有原代码仍在该已有载体，不称已归并或已获批准。本轮未新增reflog归档。当前三主仓均无stash、各一工作树/一本地分支。
- 原89正文绑定中唯一missing的SourceMangaGrid候选也已找到精确现存载体：审计区`app-worker-exact-record-recovered-171fbe7bfd9bc8a3-koma-source-grid-candidate-20261015.py`的scaffold字面量，3506B/SHA256`1b519ed0430df52f91d031f264214e5a5d43e1af1ebcef32a24e9fe5f9065ded`/blob`11bcaaf706d72a513eea0c5eed0107ef0bc67085`均核同；仅ast读取，未执行脚本、未重建缺失路径、未覆盖当前后继。
- 尚未完成：App6/Kit7组候选的最终采用/取代及其余原输入语义，真实证据父与MDX未知输入仍保留；13是已具名分组，不能冒全部剩余总数。普通产品开发、构建与设备未在本计时窗执行。18:10:49 UTC实读当前独立系统栏任务WIP为Koma1文件、sibling Kit7文件（含其正在增加的测试），按原owner保留。本轮起点917个/tmp相关顶层目录现549个；原登记证据父当前197个仍存在，目录数不换算未合功能数。

## 上一轮30分钟记录（保留当时事实与后续纠正）

- **最终状态纠正（17:26 UTC实读）**：三个仓当前Git状态均干净；早先观察到差异的Lab/Surface/test三文件现已与HEAD及index逐字相同，flags=0。其mtime在17:20:43 UTC发生变化，写回者与原因未核实，本续接未执行对这三文件的写入或回滚。17:23保存的小档实际只保当时已回到HEAD的正文，不能证明初始WIP已保全；早先Lab34711db8、Surface dff0673当前Git对象不可读，第三文件初始完整diff也未保存。此前“当前三份未提交WIP/精确保全早期WIP”的表述撤回，原记录和纠正分别保留。此缺口列为恢复OPEN，不能据最终干净状态说已交付。

- 最新期限：本轮从2026-10-19 16:58:03 UTC起计30分钟，截止17:28:03 UTC。每项实际操作及剩余时间见恢复区`root-cleanup-user-30min-20261020.json`；未捕获起点的准备操作明确记为未知，不补造耗时。产品开发与设备验收仍暂停。
- 已实际退出原`koma-checkpoint-review-20261018`审查父目录。完整原件保留在`app-checkpoint-preferences-whole-host-input-c6bb8602.tar.gz`；退出回执`root-checkpoint-parent-final-retirement-20261020.json`核正式源码/index/flags/refs不变。此前的原preferences fixture、小Kit目录和三个旧检查点分支不再待执行。
- 本轮进一步清理五组已批准修改的旧审查目录、两份对应实现旁件，以及History旧32vp提案和源地址Sheet旧检查点。每批先完整保全源码前后件、原补丁、失败、截图、HAP及原路径、正文和类型/权限/时间/扩展属性记录，独立全档读回，再核无FD/argv/容器挂载后退出。原件与旧路径映射分别在`approved-five-original-reviews-r2-20261020-{manifest.json,retirement.json}`、`approved-two-implementation-sidecars-20261020-{manifest.json,retirement.json}`、`resolved-design-review-originals-20261020-{manifest.json,retirement.json}`和同名前缀tar.gz中。第一次Python缺xattr接口在任何删除前停止，失败与修正版分别保留。
- 三个正式仓实时各只有一个登记工作树和一条本地分支：Koma/master、koma-sources/master、reader-kit/codex/reconcile-f1-d1。按原源开发副本全集逐路径核对，仅正式源仓仍在；这不等于所有历史证据目录都已清理。physical05的活服务数据、MDX两个外部证据父、唯一审计与完整归档区继续保留；MDX未定位正文是HTTP证据，不是尚未归回的源业务代码。
- 本轮原候选与当前源码核回：备份加载/失败保旧列表/重试、OPDS真实页数、明确unsupported文案、Shared/旧版真实章节重试、浏览错误上下文均保留。另核源索引完整URL换行及可滚动父树、History移除按钮24vp、Library已批准边距/padding和未缩减封面均保持。没有新产品差异、构建或设备验收；源码保留不冒运行通过。
- 恢复尚未整体完成：App普通Shared入口、AutoRead、旧远端session、章节landing、production可见叶、f769宿主变体，以及Kit的claim/rollback、thumbnail委托、chapter landing、prepare失败叶、processing队列、title/window/loading和Pager动画候选继续档内保留，不能把真实反例、缺完整消费者或未定位批准的候选直接回灌。另有原输入未完成逐行为裁定，不可统称这几组或称全被取代；具体索引为审计区`app-worker-unmapped-app-source-member-binding-r2-c6bb8602.json`和原全量覆盖表，Kit路由为`kit-current-finite-owner-and-responsibility-queue-r161-20261019.json`，其中旧可删项已经退出，以本轮回执为准。
- 初始阶段曾观察到三份未提交工作文件（最终状态及保全边界以上方纠正为准）：App `KomaReaderLabPage.ets`；Kit `ReaderSurface.ets`及`reader-surface-input.test.cjs`。本续接未修改、未覆盖、未提交这些差异，来源归属未查证；不把它们冒称清理已采纳。Kit stash继续保留。远端未由本轮同步，不发布。
- 下一项仍是恢复清理：Root对现存原输入中未完成的行为差异继续作有限裁定，先用现成原候选/后继/反例，不能以归档代替采用，也不重开已闭源码组或插入产品测试。现有App、Kit、源owner均已回报其直接可退队列为空；历史证据父仍未全部退出。

- 当前原下载初始化恢复依据：对象为Settings两个下载偏好保存方法与Index移书下载清理；来源为`koma-download-initialization-owner-20261017/proposed.diff`原完整五hunk及原有限197/Host记录。原理由是后台初始化会用旧队列覆盖同步写；本次原候选/当前真实三个消费者比对确认五hunk未归，且现Service仍提供同一Promise API。按本次有效成果恢复授权，仅接回两import、两方法await和清理Promise前置，保现有catch/文案/Builder与其它WIP；当前构建和设备验收未做。设置计数独立未归候选继续保原父，不随此组回灌。

- 四个已核数据Owner原父已完整归档读回后退出，回执`four-retained-data-owner-originals-20261020-retirement.json`；另定位到下载初始化原完整五hunk未归，已仅在Index/Settings接回原等待顺序。`download-init-recovery-current-consumer-result.json`复用原提取器在当前三个实际方法验证等待前不写/不删、初始化拒绝沿原catch；依赖为内存端口，非真实TaskPool/IO、构建或Native。源设置计数另有具体未归行：saveSettings先取旧savedSettingCounts，再reload仅保留既有ValidationStatus.savedCount；摘要/验证诊断可读旧值，计数诊断读新缓存。原重新load行在try内，当前无try；原716f未纳理由未知，保原settings父，不作不安全单行回灌。

- 本轮实际结算：原检查点审查父及19个已核清的原审查/实现父已退出，所有源码前后件、原补丁、原失败和原取证仍在上述完整档；新增下载六父对应`six-retained-download-owner-originals-20261020-{manifest.json,retirement.json}`及同名前缀tar.gz。下载初始化遗漏已在正式主仓`e280902b`恢复（两生产文件原五hunk），仅三个实际方法的初始化顺序/拒绝受控检查通过；当前ArkTS构建、真实TaskPool/IO及设备未验，不冒全量恢复完成。
- 未完成项保持具体：源设置保存计数的原读取行及其异常处理完整边界未归，原`koma-source-settings-read-integrity-20261017`父仍原位；此前App/Kit保留职责、其它档内原输入语义、剩余历史证据父尚未全部核清。17:23当时三文件及两仓diff曾另以`current-three-unsubmitted-original-bytes-20261020.tar.gz`逐字保全，回执明确不采纳、不替代提交或完整仓元数据。本续接清理代码未对这三文件执行写入；期间变化的来源仍未核。下一具体未核动作是源设置计数完整原候选与未定位取舍的安全裁定，不再以笼统剩余桶冒已核完。

## 恢复审计记录（2026-10-19）

- 2026-10-20 Root已实际收敛清理：咚漫五父由r3原件/9档/16独有Git正文完整保全后退出，Root逐5554旧路径成员独立读回；r2循环变量复用风险保留，未运行旧候选。四份非Koma命名旧源码已核后继并全档读回后精确退出，生产源码未变化。Kit旧小审查目录14原文件复用r154完整原档、补保存原目录元数据与路径图后退出；停止r160过宽全局扫描路线，未运行其删除模式。证据：`root-dongman-five-r3-independent-postcheck-20261020.json`、`app-four-nonkoma-original-inputs-retirement-20261020-result.json`、`root-kit-small-checkpoint-exact-retirement-20261020.json`。
- 已退出工作树对应的b744/c585两条NextN检查点及eceb一条NextE检查点名字已精确CAS删除：完整无前提Git bundle、原ref/reflog保全，strict pack及全部可达OID/type核对通过，其他ref/worktree/config保持。bundle保存不等于原候选已采用；Reader冲突、未采与未知材料继续保留。证据：`root-nextn-two-checkpoint-ref-retirement-20261020.json`、`root-nexte-eceb-ref-retirement-20261020.json`。原首次pack delta长度与逻辑长度比较错误保留，未把该失败追认为通过。
- 当前获批三项源行为已在正式主仓提交8c0a8d25，详情标签换行已提交a32c16d0；签名包构建成功。197已实际看到DM5原首页两条导航；点击最新列表后的证据已保存但未完成本轮判读，pending筛选替换与声明元数据失败/重试仍无本轮Native证明；随后按当前清理优先恢复Home/10000ms、书架/会话哈希不变并释放租约。产品开发与设备验收暂停，不再插入清理主线。尚无可靠全量未合入能力总数，不能把文件或目录数换算成功能数。
- b744旧父与专属管理目录已实际退出：Root亲审r147/后继r149全部固定输入，原90GB完整档/164767原路径及三原raw图由既有独立全读证明承载，不重档。r147在首删前发现NextE Enhancement旧`--debug` cached ctime与其较晚common index/physical观测不一致，原FAILED/deletedRoots=[]保留；Root另独立证明当前10097B index全文/身份本就等r145 common原件，74条mode/OID/stage/flags同，writer仍UNKNOWN。r149只精确重绑该完整观测及DM5实际35新增集合后，两轮全target metadata/全部正式工作字节与commonDB/原两父保护、fresh argv/FD/cwd/plist/控制引用通过，实际移除两固定根并全保护postcheck。Root另独立核2根不存在、12外body与nlink2→1、两父精确child/metadata自然变化、四formal GitMeta和checkpoint原tip；两服务及两Running容器四bind前后精确。原失败与完整小型审计packet已逐member保全到正式恢复区，原90GB档未重复。证据：`kit-b744-joint-exact-retirement-r149-20261019.result.json`、`root-b744-r149-independent-postcheck.json`、`b744-r149-complete-audit-preservation-result.json`；b744 checkpoint名字、所有原有效/反例/未采候选及其它owner继续保留，不冒整恢复或Native通过。
- DM5三组十历史父已完整保全后精确清理：六合同父699旧路径/6档/18参考、两standard父1287旧路径（含实际既有child756）/4档/30参考、两live合同父6884旧路径/2档/8参考均由Root独立全档/type/mode/body/旧地址核回。七历史与八standard补丁严格重建，当前017 lib/Cargo/README保持；live的40原输入与56生成件从实际档核回，4个Cargo仅原包名替换，2HTTP adapter由三条原patch严格重建，原73e57基底明确为严格重建参考；4broken link原payload与ComicABC→BNS真实原档路由、另份完整c8 alias分开保留。旧015不降级、streaming HOLD、原third-callback assert-stop/旧014原因UNKNOWN均不改，不请求网站/设备或采用新产品。三正式仓HEAD/工作字节/index/flags/refs精确保持。证据：恢复区`dm5-{six-contract,two-standard,two-live-contract}-parents-cleanup-result.json`与对应`root-dm5-*-independent-postcheck.json`。
- Komiic四父、GoDa三父、GlobalComix两父已分别完整保全后精确清理：Root独立核3188／898／4718新旧路径、共24档和7／3／26原参考。Komiic七原源码及四patch链对应真实014→015，未采用d511 ticket WIP完整保参考且缺原ticket输入仍UNKNOWN；GoDa三原源码/两patch链与f048完整012同，原011失败、controlled错误ID和原review矛盾Native字段不冒通过；GlobalComix原19runner输入中17等244、host严格由原离线适配patch重建、lock是原局部resolution，36原dist及28生成/复制依赖源码和完整target均保全，不把离线200/headers:null当真实HTTP。三正式仓源码/官方图标/HEAD/index/flags/refs均精确；无新产品/网站/设备动作。实际回执：恢复区`{komiic-four,goda-three,globalcomix-two}-evidence-parents-cleanup-result.json`；Root独立pre/postcheck在审计区同名`root-*-independent-*.json`。
- 原25610只读代理已从旧开发路径接回正式Koma三原资产：Root亲读r2全部identity/assets/HTTP/switch合同，旧30227两原GET成功并保存摘要后仅TERM；新PID34310在前台tool session69242以同CLT Python/-u/cwd与同地址端口/allowlist/上游exec原脚本。两原GET的status、content-type、长度和bodySHA逐一完全相同；Root另独立核新完整身份、原三资产及正式main全签名，两原容器仍Running、四bind逐项同原。未导出header/正文或请求设备，旧内存是否等原归档仍UNKNOWN；physical05活服务数据保持保护。证据：恢复区`app-proxy25610-{original-http-before-r2,controlled-old-stop-r2,controlled-canonical-launch-r2,original-http-after-r2}-result.json`与`app-proxy25610-root-independent-postcheck.json`。
- 历史r140服务恢复记录（后继代理迁移与b744退出见顶部）：原进度页503回归已限定修复并通过真实验收：Root亲审r140全差异，先完整保全ORDER/index/状态三成员并逐字读回，再仅应用原HTML、正式路径server和唯一snapshot。fresh核旧PID65874/start/argv及唯一loopback8766，保存根页200/API与全文503基线后只TERM该进程；新PID18551从正式Koma路径运行。冻结verifier实际核原9876B HTML、正式工作单全文、两次API/真同级Kit6c、三证据全body与Range及未知404，浏览器实际展开版本/四组、回执与全文链接及自动刷新连接时间；原HTML外观不改。首次前件读取误将lexbor gitlink当普通文件，在任何写入前停止，原读取器保留，r2仅补真实gitlink HEAD/状态核对。原两容器和30227未动、b744尚未退休。证据：恢复区`progress-service-r140-{root-apply,restart,live-verifier}-result.json`、完整before档与审计区浏览器原图/AX；不冒整体恢复或Reader通过。
- 当前用户卡片内边距增量已在正式主仓实现并做197限域实测：本会话明确要求内边距也处理、看到最终画面并核内外圆角；只将`LibraryList`外层Row上下padding从4改8vp。既有卡片R20、封面R12和全部封面42×60/48×68/56×78、继续阅读76×102保持；Continue卡原R24/p12/R12保持，不重开缩封面方案或公共HDS样式。180b80f5主仓基线与本单行候选分别真实签名构建/安装，Root实际看同数据ALN-AL80/1260×2720竖屏原图：标准封面156×221px不变，留白左/上/下由26/13/13变26/26/26px；宽松为26/26/25px（像素取整），紧凑因HDS文字区最小高度为26/32/33px，不能称三档完全等距。标准单项选择、取消、普通回网格已实际看图，书架/阅读进度仅设备端SHA核对始终同原；原标准密度、网格、桌面Focus11与10000ms覆盖均恢复并释放租约。没有横屏、系统字号改变或Reader正文验收；其他产品新增/源设备仍暂停。证据：恢复区`library-card-padding-current-user-{review.md,native-result.json}`及同一`device197__ALN-AL80/not-applicable/portrait-1260x2720/library-card-padding/`原图/manifest；前件完整档与此前缩封面候选原件均保留。
- 本次真实主仓基线构建暴露两处先前恢复漏依赖，已精确修复并范围提交：App`180b80f5`将缺失`readerPreparationCurrent`调用投影回当前Legacy已有epoch/open/closing三条件，保目录resolver取消参数与最终发布门；Kit`6c289f2`补回原Snapshot `visualRevision=0`及copy两span，保当前assetRequestId所有真实writer，不回灌HOLD claim/rollback/Shared/AutoRead。原Host分别注入永真helper/非零revision fixture而漏查生产合同，原完整性确定结论据实际构建反例收窄。Root亲核原blob、生产者/五消费者和精确暂存，App四实际方法场景、Kit四原测试文件37项通过；同一正式Koma构建随后成功。这不证明Reader原生或其它宿主验收完成。证据：恢复区`library-build-original-contracts-{staged,commit}-result.json`及完整8成员前件档、两原失败/成功构建日志，审计区原owner追溯材料。
- 当前人类界面取舍（原文来自本会话当前消息，非历史记忆）：看到原列表前后实机图后，用户表示“右边可以选”，但封面高度缩减过多，“边距的处理可以保留”。因此旧完整缩封面候选不整组应用；Root 已按本次边距/封面取舍归回限定子集并提交 `4c7fa41d`（单文件11增8删）：只接原外部边距/行及 section 间距/文字对齐，三档列表封面42×60、48×68、56×78与继续阅读76×102均保持，内部文字纵距、Grid、字体和颜色不改；不冒原具体尺寸已获历史批准。Root 原件读取两次因通用 padding 重复及方法片段与整行的边界假设在应用前停下，原失败保留，随后用真实 Git 的精确原行及已记录空格/LF边界核清，未改候选或产品断言。证据：`root-approved-library-margin-subset-{staged,commit}-result.json`、对应 before 完整档及两份原 prereview failure。原图均为 197/ALN-AL80 1260×2720 竖屏旧包，缺当前主仓精确候选截图，不能当本轮实机验收。后续选项须给推荐做法、现在→选择后的实际差异，并区分仅提交现有工作与改变产品界面。
- 已批准三组接续结果：appearance 四文件旧隐藏差异已完整保全后撤下，主题/强调色/语言入口与原“外观”标题保留，旧断言脚本原件保全后移出 scripts；Root 独立读回全部 15 成员与四个当前输出。文件夹重扫现有完整 WIP 已精确提交 `77b3c316`（9 文件、原 41 span，305 增 22 删）；所有工作文件与其他 WIP 提交前后逐字节不变，12 个实际完整方法受控 IO 场景与原模型套件通过。ce293 完整手动目录已按当前批准提交 `2aed5b01`（单文件4增2删），原方法来自真实 Git blob，实际暂存三项原检查通过；自动邻章筛选和从首格开章行为保持，不包含保存进度重开/AutoRead。三组都没有本轮构建或设备验收，未推送。证据：审计区 `root-approved-appearance-9254b1d8-result.json`、`root-approved-folder-rescan-{9254b1d8-staged,commit}-result.json`、`root-approved-manual-catalog-{staged,commit}-result.json`，及主仓恢复区对应 before 完整归档。
- App 两 archival recovery ref 名字已在 `2aed5b01` fresh 边界核清后按固定旧OID单事务移除：Root重核93份原完整文件版本、既有11451raw/11463member全档与原独立读回回执，并核现存配置/HEAD/hooks/代码无名字消费者；只删a358/263f两名称，原档、所有未知旧方案、实际working/index/flags、其余refs和worktrees精确保持，不宣称旧方案都已采用。证据：`root-two-archival-ref-names-2aed5b01-{prereview,postcheck}.json`及原事务log。
- 源三个纯历史条件登记 parent 与 Happy first-error/static-triage 两 parent 已分别完整保全后精确清理，Root独立读回11＋108旧地址成员；前组9原绑定与10当前后继核明，后组51原输入（47 live/4真实旧档）、旧单hunk严格重建到现6b完整源、原SDK/Cargo/四份受控输出及2WASM参考核回。源主仓7af0/clean及所有refs/flags保持；原静态OPEN和无网站/Native结论保留。Root读取器的原route schema键错误与删除后错读live oldpath失败均保留，后改读实际archive member，不重新生成输入或重跑清理。证据：恢复区 `three-historical-condition-parents-cleanup-result.json`、`happy-firsterror-triage-two-parents-cleanup-result.json`及审计区对应 Root independent-prereview/postcheck。
- 本会话已批准完整副标题并已落实：三语`settings_pane_library_detail`现为“分类、更新、本地刷新”/“Categories, updates, local refresh”，工作文件与原已提交版本逐字节相同；仅撤下未提交短句，原短句完整12成员归档并核回，不需要新增产品提交。证据：`root-approved-library-settings-full-subtitle-result.json`及主仓`approved-library-settings-full-subtitle-8e100bbd-before.tar.gz`；没有当前构建/设备验收。
- App两份机械源码WIP已完整12成员保全后退出，Root独立核工作文件与提交字节相同；不将规范化emit相同说成严格JS行为等价。R1三条原源码技术分析以`8e100bbd`追加提交，不带未核人类引述/许可/Native关闭声明。四docs其余16 span已完整保全working/index/HEAD/diff与来源共30成员，Root独立逐body/mode/uid/gid/mtime/GitOID核回后退出未采用working差异，已提交R1三条及其余源码/索引/flags均保持；原未知/旧规范不冒无效或新批准。实际`root-four-docs-preserved-working-exit-result.json`，完整档`app-four-docs-unadopted-wip-r2-7d9da7fb.tar.gz`；当时主仓7d9/CLEAN，未推送。
- Happy UA-R2整父已完整保全后精确清理：Root独立读回71个旧地址成员和3份原reference实物；源主仓7af0/clean及原refs保持。原POST误报与纠正均保全，未采用的Komiic版本WIP不应用；两例图片是描述符且无HTTP trace，不冒网站验证。证据：`root-happy-ua-r2-parent-independent-{prereview,postcheck}.json`及主仓恢复区对应完整档/cleanup结果。
- production10旧开发副本已实际退休：原唯一完整档110701成员/14723 raw由Root先前独立读回，首删前再次核原95519源成员、own App admin9、两provider307/52、原档SHA、7815路径incoming0与四根宿主lsof空；保留两条外域Linux skill解析错误，不冒全盘无引用。仅删production10实体、两专属nested admin、own App admin及固定1e4本地ref CAS，保护production05活服务/provider/self/baseline。独立后检核主仓working/index/flags/其余refs、provider余298/44成员及原档全部精确，未采normal/旧session/fa45/AutoRead反例与可见叶仍完整保档，不称采用。实际`app-production10-exact-owner-retirement-7d9da7fb-result.json`及审计区独立postcheck；未构建/设备/远端同步。
- 源四组历史目录接续实际退出：Happy integrity整父309成员+3原包参考、POST纠证/nav两父437新旧成员+原087源码/WASM两独立参考、metadata/ComicABC两父88成员（含两条原symlink）、最后两份纯合同报告父8成员+3独立参考均完整保全后由Root独立全档核回。nav087仍为未采用/非被拒/非已取代的完整功能候选；ComicABC29057B源码明确严格重建参考，不冒保留原文件。两symlink的旧清单少payload长度/hash使原candidate在首删前停，原失败包保留，r2逐原字段和真实UTF8 payload证明后执行；Root只读读取器对receipt/diff及后继版本的错误假设均保留，均未改产品断言。源主仓7af0/clean保持；原HTTP误报/纠正与外部缺HTML/WASM/MDX原体继续OPEN，无新网络/Native。证据：四组`*-cleanup-result.json`、对应旧地址索引与`root-*-independent-postcheck.json`。
- production05 残留Git管理项已实际退休：379成员原档与15成员扩展元数据补档均由Root完整独立读回，13730原对象对应原14723独立档；361路径的flags/dev/inode按实际stat核回，360个原始xattr值另经系统xattr CLI交叉读回。fresh控制路径7713件核incoming0，两个原外域Linux skill解析错误保留；只移除完整App05 admin（含两个已保全provider）与固定156基线ref CAS，不操作physical05任何路径。独立postcheck证明主仓working/index/flags/其它refs精确、130个原服务/空目录身份、两个运行容器四bind及30227只读代理argv/cwd/start/listener保持。当前Koma仅正式主仓worktree与master；原physical05是仍活服务数据残留，不是开发副本，不因Git退休而可删。证据：恢复区`app-production05-exact-admin-retirement-2958a016-result.json`、379/15完整档，审计区两份Root独立readback与`app-worker-production05-independent-admin-postcheck-r2-2958a016-result.json`。
- ComicABC六历史验证父与四合同父已完整归档并精确清理：Root独立读回1451（含此前400 child）＋144个旧地址成员，44＋10份原reference及111＋21份外层证据保持。原50代码输入、五＋三补丁链、后加479B历史说明、737→740文字纠正分开保留；两份缺失HTML从原受控输入严格反变换至原抓取回执完整SHA，明确为重建参考而非原文件/新HTTP。当前源7af0的代码、官方图标、index/flags/refs/worktree不变，无新Native/正文通过。证据：`comicabc-{six-historical,four-contract}-parents-cleanup-result.json`与`root-comicabc-{six,four}-parents-independent-postcheck.json`；另11证据父973成员已完整归档并精确清理，Root独立全读回；三份旧shared NOT_REPROVEN已由Root逐字连到六父第5实际归档，不冒重用旧基线。
- 历史r135门禁记录（后继r149已解除该退休HOLD）：Kit b744完整保全已由Root独立读回141031成员/164767旧路径及App21345、Kit3219、Enhancement106原对象，SHA与真实r134回执相同；r135只读就绪门也已实际通过。其结论仅限字节/metadata/当时open-fd，不证明无argv/延迟读文件消费者。fresh宿主发现65874进度页仍按旧b744 PAGE及production10 ORDER读文件；根页200但`/api/progress`、`/work-order`因production10路径已退休而503。这是原清理控制路径/fd扫描漏掉活进程argv造成的实际回归，旧独立postcheck不能覆盖它，b744退休继续HOLD。30227代理则只在启动读取旧脚本旁两个sidecar，当前HTTP无A/provider依赖；原三启动资产已归回正式忽略区并由Root独立核回；原30227尚未切新脚本，受控重启与HTTP验收仍OPEN。
- 当前下一未验证动作：Root只接续目录/分支恢复清理，先将既有App两个残余桶与源未裁定原件按当前消费者形成有限处置，已证实无独有待归成果的历史证据父批量保全退出；不重审已闭合组、不增加产品测试。完整能力冲突/可见未知单独保留，不扩成全局停止；physical05活服务数据和MDX外部UNKNOWN保持。清理整体仍OPEN，当前不宣称全量有效成果已归。

- DBMultiverse 三处与 IQIYI 两处历史 parent 已分别完整保全后精确清理：229＋3732＝3961、100＋772＝872 个新旧成员均由 Root 独立逐 type/mode/body/oldpath 读回，8＋11 份原包/WASM/index 独立保留。DBM 七原生产文件与 fe2190/current 全文同，七 App 文件是 freeze.py 只读捕获的历史输入；IQIYI 14 路 patch 严格内存重建、六业务文件等 1f01644，旧 CLI 1c49 从另一真实旧路径归档读回 14577200B，不拿新 CLI 代原输入。原69缺件、116 unsupported、0HTTP/空包失败均保，不新请求/构建/Native。源主仓源码、index/flags、refs/worktrees 保持 7af0。证据：恢复区 `dbm-three-whole-parents-cleanup-result.json`、`iqiyi-two-whole-parents-cleanup-result.json` 及审计区对应 Root independent-prereview/postcheck。
- production05 六条旧构建链接已完整保全后解除：7 member 档包括六个原 link payload/mode/uid/gid 与 manifest，Root 独立全读回并保全部父目录；只 unlink 六条，活 Docker 服务/数据和旧 GitDB 均未操作。三主仓 index/flags/refs/worktrees 精确。当时整个 production05 仍受真实服务 bind 与 production10 两 module gitdir 引用约束；后者已由本轮production10退休解除，当前服务数据/provider去向仍待核，不因链接清理称父已退休。证据：`production05-six-build-links-{full-preserved.tar.gz,cleanup-result.json,oldpath-index.json}`、`root-production05-six-links-independent-postcheck.json`。
- AutoRead 原两模块六 span 完整候选继续 HOLD：实际 OfflineConfig→Factory→候选 Adapter→Core 的受控链路证明，三页 PARTIAL 仅第一页可读时，后两页 reader-offline-missing 仍被标 local/ready，零邻页 window 下 source gate 允许一次 next。CORRUPT 只证明错误 ready，未伪造可读当前页或推进。Root 已核六原 span/全输入及实际日志；75 个 Core PASS 不抵消 App 反例。更正旧“离线缺页都会变 URI_PLACEHOLDER”的宽结论；无新 guard 或主仓候选应用，不冒 Native/人类拒绝。证据：`root-autoread-original-source-actual-counterexample-disposition.json`、`app-worker-autoread-offline-real-chain-r2-c7d9151c-*`。
- ce293 完整手动目录已查明独立于 d129/fa45 保存进度：当前 picker 最终 session.open(target) 默认从0开，目录投影不读保存进度，不触 a27 临时 config。Root 查原 Git 与真实消费者后，原完整单方法候选随后已获本次明确批准并提交2aed，详见顶部；不再把另一分支反例泛化为阻塞它。Library/rescan/appearance 后续决定、两 recovery refs 的核清与名称退休同见顶部，不继续沿用旧待决状态。
- 历史r130/r134保全阶段记录（实际全读与退出以后继r149为准）：Kit b744 r130唯一计数已实际结束（原session77529 exit0）：physical 164190成员压缩流107212991491B，admin 577成员6804002B，合计107219795493B；未写archive，原源码/完整GitMetadata前后精确。Root随后宿主执行已审r133，完整management pointer/config与GitMetadata保持，lsof无b744/NextN2打开消费者，daemon仍仅0B锁与socket，dynamicConsumerGatePassed=true；旧会话活跃性仍未知，不由missing rollout推成不存在。当时df可用106059591680B，连实际流本体尚差1160203813B，故当时不能按旧格式开写完整档；原r129执行前保守空间不足与r126 FAILED均保留，不改原期望。原owner继续核既有载体/可用保全方式，计数和动态核验不替代父physical/admin完整档逐member读回或退休。证据：`kit-b744-parent-count-compressed-r130-20261019.result.json`、`kit-b744-after-counting-host-verifier-r133-20261019.result.json`；r132的NextE非UI候选仅保留，不恢复N/E产品。 后继r134已由Root审最终104输入、原164767路径/全部GitMetadata与24670 raw绑定，独立内容pool/PAX tar精确90491279360B，含2GiB+64MiB保留量需92705871872B，写入前实时空间满足；唯一宿主保全session72856已exit0、真实receipt生成：141031档成员/140926唯一payload、全部原路径与App21345/Kit3219/Enhancement106 raw OID及写前后原件核同，archiveSHA3ef9dbc79a228fa66691b7bc784cf5b4983b3f317a25986eacf2a15afc42dd9f。Root另启独立source-free全档读回session48878（`root-kit-r134-independent-readback.json/.stderr`），本状态尚未取得该结果，未退休。原两setdefault预建Git进程风险在执行前修正并明确保存重建的旧prepared文本；最终script显式单repo批处理并flush/fsync。完整原path元数据/xattrs/997symlink/22内部hardlink及12外部链接关系均按manifest保留，不按同SHA改变恢复inode语义。r135仅冻结后续固定scope，须等本次真实receipt及Root独立全档证明，不自行执行。
- 两份旧App合同输入已从production10原完整档精确member找回并保存小型原文副本（46203B/5ca694c2、3622B/f2e4fa93），只解除原载体未知，不冒当前consumer。ComicABC candidate f3/29057B已按明确单token规则从真实原档输入严格重建并保完整base64/来源，标记重建而非保留原文件。MDX LoveBullet body5bb12615/27289B仍未定位，不能称已丢失或当前功能缺失；对应外部parent与缺件OPEN，两份纯报告现已在全量保全现存材料后退出，原缺件继续OPEN，不碰未知外部原件。源原220为289子集的已有去向已由Root逐当前路径及81实际回执核（SOC按原precheck→result明确连接，原文字面假设失败保留）：仅主仓仍在，其余288已无实体且有实际/既有清理映射；只闭该source-tree集合，不覆盖尚存调查/媒体parent。

- 包子013六处历史 parent 已完整保全后精确清理：411 文件/510 当前成员，加既有 child 366 成员，共 876 唯一旧地址均由 Root 独立逐 type/mode/body/映射读回。31 份原 WASM/ZIP/index 参考独立保留；Root 从实际原档读取 54 份源码并严格内存重建 17 路 patch，原非线性章节组合及 language 省略与当前 3d12 全文相同。源主仓 7af0d9d8 的源码、index/flags、refs/worktrees 全保持。Root 两次只读校验漏原输入/单文件 header 的失败均在任何归档和删除前保留，后补真实载体与读取器，不改产品或断言。证据：恢复区 `baozi013-six-whole-parents-cleanup-result.json`、审计区 `root-baozi-six-independent-{prereview,postcheck}.json`。无新构建、网络或 Native。
- 旧 smoke 删除显式用户选择的两处 WIP 已逐完整原件保全后撤下：7 member 档含完整 working/index/HEAD、原 diff 与原调查，全部逐字节/mode 核验；工作脚本恢复已提交的 `KOMA_SMOKE_USER_ID` 和 foreground `aa start -u`，index/refs 及其他源码不改，bash 仅语法检查通过。删除理由仍 UNKNOWN，未冒称人类拒绝；原候选保在 `main-smoke-user-selector-original-wip-a97ba08a-before.tar.gz`，未执行 HDC。当前剩余 13 tracked WIP 与 appearance 原脚本保留。
- 先前待决三组的后继决定与实际执行见本节顶部：文件夹重扫已批准并提交，appearance 已按批准撤下旧差异，Library 按当前边距/封面反馈收窄，不沿用旧完整候选。旧 worker 的 Authorized 不冒人类批准。Kit r127 保留 r126 原 FAILED 与实际完整 delta，不重跑/追认；原 owner 继续准备 b744 父完整 physical/ignored 和 NextN2 全 admin 的保全及真实外部引用闭包。源原 owner 接续有限剩余队列，App 原 owner 继续 normalShared/AutoRead/旧 session 完整消费者与原反例分账。产品新增与设备仍暂停；整体恢复及远端同步 OPEN。

- History 原批准完整组已归回主仓 `dab51d4e`：d0 真实章节标题、d9 完整行及后续关联封面角，保留小按钮 24vp/18vp 和完整换行；13 份原始行 SHA（含 LF）及原完整 row 三快照核回，未取 32vp 反向提案。16 成员 before 档及实际 stage SHA 核同，其他 14 tracked WIP 与 appearance 脚本保持。无当前构建/Native，证据：审计区 `root-history-r2-{prereview,actual-staged-readback}.json`。
- 又五个源调查 parent 已完整保全后精确清理：FGO011/原神/魔法纪录早期三处、图片描述符、共同交付调查，共 275 当前物理成员及 201 既有 child 成员。Root 独立全档读回 476 旧路径，核三原 before 与实际归档 member、三当前后继、27 描述符快照及五原输出、共同 17 快照/31 重建原 blob 与两条登记后继；源主仓 working/index/flags/refs/worktrees 全保持。无新源/网络/Native。证据：`root-array66-descriptor33-independent-postcheck.json`、`root-source-common-parent-independent-postcheck.json`，以及恢复区三份 cleanup-result。
- 三作者、十五源登记审计、FGO/原神/魔法纪录后三 parent 也已完整保全后精确清理，Root 分别独立读回 25299/10632/4049 成员。至此原冻结 12 parent 全部清理：3133 当前成员与既有 child 合并共 40456 唯一旧路径，源主仓全部 working/index/flags/refs/worktrees 精确。三作者 9 业务文件已归、旧生成器/未采素材只保参考；15 个实际提交及 95 原路径均核回，快看旧 ICO 在 a748 被当前 PNG 取代，未回灌。official 的九条旧外部记录按实际归档 member 继续校验，不重建已删目录。证据：`root-author-registry-independent-postcheck.json`、`root-official-array-three-parents-independent-postcheck.json`；Root 读取器的 None/字段失败均在任何对应删除前保留并核真实结构后纠正，未删断言。
- Kit r126 唯一 e2 side-ref CAS 已执行，原后检 **FAILED** 保留：只少目标 41B ref 和自身 275B reflog、无目录增删；两个 codex 目录 nlink 均 6→5、bytes 192→160，超出原“nlink 不变”假设。Root 独立核剩余全部 file bytes/metadata、两 Kit 436 physical、其余 Git metadata 与 b744 admin 精确，2946 raw 对象及 e2 全 2719 图前后均完整；r106 原 263 成员 admin 档核回。三个目录的完整实际差异已记录，原脚本未留 CAS 精确区间，不冒时间屏障通过或观察到根时间变化原因。未重跑/回滚/改 expected/追认 SUCCESS。证据：`root-kit-r126-{original-failure-and-full-actual-delta,independent-actual-postcheck}.json`；provider 及其余四 heads/两旧父保持。

- remoteHistory 完整 r5 已按本次用户答复“恢复这份完整候选”归回主仓 `c8813948`：15 生产路径及 2 迁移材料，Kavita 不自动入库、原失败反馈及全部原重开/身份/事务消费者配套。162 原 span 与 working/index 双输入输出 SHA 核同，History 与已归 r2 组合为 e87e8ca4…，原 WIP payload 保持；七套原 Host 在实际 index 通过，26 owner case 和 18 事务 case 原断言不改。首结果聚合误把带 after 的 dict 当平面列表而失败，原失败保留，读实际结构后只改报告读取；policy log 固定旧标签及原 fixture 的 Native 文本不当本轮事实。无新构建、网络或设备，旧 Shared Kavita line183 失败边界仍 OPEN。证据：审计区 `root-remote-r5-{dab51d4e-prestage-review,actual-index-host-result}.json` 与七份 actual-index log；82 成员 before 档逐件读回。
- Dota2/阴阳师两个纯负反例审查 parent 已完整保全后精确清理：5 文件/7 成员及全部旧地址映射，Root 亲读原 disposition/源码摘录、核当前完整源码 SHA 与唯一包含关系，宿主 ps/lsof 无占用；执行首删前双档屏障后独立全档读回。源主仓 working/index/flags/refs/worktrees 精确，未新增源码、网络或 Native 结论。证据：恢复区 `two-array-counterreview-parents-cleanup-result.json`，审计区 `root-two-array-parent-{pre,post}review.json`。
- App 四特殊引用已独立保全 11451 对象及全部路径/metadata，Root 全档读回后仅清理冗余 0cbb 和 local/master；真实 WIP 恢复引用 a358/263f 继续保留待逐职责闭合，不依赖 production10 对象集冒保全。Kit r118 的 d958 原职责属于正式 NextE，仅保精确候选，不扩大恢复为 N/E 产品修改。证据：审计区 `root-app-{four-special-refs-independent-readback,two-special-refs-postcheck}.json`。

- production10完整保全现已完成并由Root独立全档读回：110701成员、15535542613B，SHA256 3af5679f19e18815ee819d6ff7d81650ed3f7c4636a1d2b4b6d33892b25a305a；95519物理子成员、自有admin9、两个原provider含根308/53、14723原App raw对象均逐件核验并重算OID。没有删production10。Root明确先归并18e/e22/f5/c25有效未归的15生产路径，归档不能代替整合；原反例HOLD及未知来源叶保持。证据：恢复区app-production10-full-owner-a770e1d8-preservation-result.json、审计区root-production10-full-independent-readback.json。
- Kit c585/eceb父四份完整physical/admin档已完成，Root独立核验39052成员的集合/类型/mode/uid/gid/mtime/xattr/bytes/link及原现场全物理和Git元数据保持。两父尚未清理，b744 Kit origin的对象/heads差异及未归职责仍逐项处理。保全不是采用决定；原NextN/NextE职责取代与未归分账在r109–r111，不能回灌被正式后继撤下的等待层。证据：恢复区kit-shared-parent-preservation-r106-20261019.receipt.json及审计区root-kit-r106-independent-readback.json。
- BNS original残留787、final整parent、reading整parent已分别完整保全后清理；对应1583、4029、2499旧地址成员索引及各原archive已独立核回，外层原件/历史link payload及主仓保持。共同CLI/description两个纯证据parent也已全档核验后清理，64现文件/73成员加两原child共8924旧地址；原20/42冻结材料、三个原包及实际CLI/description正式后继保持。Root首次流式读取CLI原tar硬链接报StreamError，清理前停下；原失败保留，r2对regular payload顺序验SHA，再逐硬链接解析到实证相同长度/SHA，不改变标准或原档。证据：恢复区四组实际cleanup-result及对应Root postcheck。
- 三页现存12vp外边距成果已按原实施范围提交 `ff922fa0`：Import/Settings/MangaDetail各移除一行24vp覆盖，工作文件、卡片内部/主题/重扫及其他WIP均不改。Root实读09/05 guardian归档line11中的[40]问题/[48]限定提案/[57]答复/[63]/[66]真实实施，三页在原20路径内；这是原会话复制记录，parent主原件未定位，不冒称独立找到direct-human primary。两附件同原行SHA差异已核仅因LF，原错标与纠正分别保留。未新构建/设备验收。三working+三index及附件先完整tar核回；首stage后校验误用guard字段名失败，后按原a770全workingMembers/flags及实际三index blob核回，未reset或重套。证据：恢复区main-three-retained-list-margins-a770e1d8-before.tar.gz、审计区root-three-retained-list-margins-stage-result.json。

- f769父App与内嵌Kit已联合完整保全并实际退休：8783物理成员、11自有admin、17230原Git对象及metadata/85证据等共26120归档成员，Root独立全读回并重算Git OID；10个历史external目标的三原独立载体也核回。8800旧地址先映射归档，再经实时7903配置检查（incoming0；两条无关V2Next→Linux技能链接仍明确未解析）及宿主lsof，仅移除该父工作树、自有admin和`codex/koma-shared-host-103`。主仓全部working/index/flags、其他refs/worktrees独立后检精确。原未采thumbnail/章节身份/prepare等候选及失败均保原，未回灌。首保全读回因根目录类型位16877与权限493误比失败；原完整tar不重打不覆盖，经r3严格同档全读回及Root独立复查，仅明确纠正两根比较。证据：恢复区`app-f769-joint-full-owner-bcfe845e-preservation-r3-result.json`、`app-f769-joint-exact-owner-retirement-result.json`，审计区`root-f769-{joint-full-owner-bcfe845e-independent-readback,old-address-member-index-prereview,retirement-postcheck}.json`。
- BNS final两个离线组件已完整保全后清理：2780文件/3333成员，23原冻结源码、Host patch往返、26原生成件及thiserror指纹已核明，22外层原件和2二进制参考保留；Root全部成员独立读回，源主仓7af0全working/index/flags/refs/worktrees保持。BNS reading三个原stage的104文件/171成员也已全档读回后清理，原最终297009d业务后继与19外层/6参考保持；两组都未运行旧构建、网络或设备。证据：恢复区`bns-{final-runner-two2780,reading-three104}-cleanup-result.json`及审计区对应Root pre/postcheck。
- 三个作者源的六个旧离线工具/编译目录已完整保全后清理：16971文件/20343成员独立全读回，24个原自身/复制旧binary另存参考。69原Host源码逐原provenance核同，九份当前源业务对原恢复绑定精确；156生成文件对实际BNS归档member核明，其中六个ISLE文件仅各153处生成输入路径注释不同；三份借用Lexbor的3171原输入含.git别名均对真实旧档核同。38外层原件及三个parent保留，未把早期bootstrap、缺图标旧build注册或Host候选回灌生产。证据：恢复区`three-author-six16971-cleanup-result.json`及审计区`root-three-author-six16971-{prereview,postcheck}.json`。

- preload 整App旧owner已实际退休：8435物理成员＋55自有admin、13479原App raw及metadata/证据共21995归档成员完整保全，21个历史external目标与原Lexbor11869对象的既有独立载体均核回。现场依赖重新检查8018文件，incoming0/errors0；首沙盒扫描对无关daemon目录读失败的记录保留，宿主同脚本重查通过后才执行。8496旧路径映射先落盘，再仅移除`Koma-reader-preload-verify`、其自有admin与实际own ref `codex/koma-reader-refactor`；Root独立后检主仓全部working/index/flags、其他refs及4条其余worktree记录精确。normal/window等原未采WIP保在完整档，不冒产品已采用。证据：恢复区`app-preload-exact-owner-retirement-result.json`、`app-preload-owner-old-path-to-archive-member.json`，审计区`root-preload-retirement-postcheck.json`。
- Komiic014/015两个原标准打包tree已完整保全后精确清理：530文件、752归档成员全读回；468原233a基线、8原四路径patch往返、原014→015实际后继及文档纠正分别核明。6原包/WASM/index另存、76外层原件保持，Cargo物理0644与旧canonical0600来源边界分开保留，不改主仓mode。当前015业务及原图标保持，未回灌旧d511 ticket WIP。证据：恢复区`komiic-standard-two530-cleanup-result.json`及审计区`root-komiic-two530-{prereview,postcheck}.json`。
- 再漫画官方016与漫画柜012兼容编译两个旧tree已分别完整归档后精确清理：312/267原文件、432/375归档成员分别独立全读回；官方五项delivery及漫画柜原八路径往返/七项当前业务核明。4原包/WASM/index参考另存，72/33外层原件保持，源主仓7af0的全部working/index/flags/refs/worktrees精确；不回灌已撤回重绘、不把兼容编译冒包或Native验收。证据：恢复区`{zai-official016-standard312,manhuagui-compat267}-cleanup-result.json`及审计区对应Root pre/postreview。
- 当前下一项由本节顶部记录接续；包子013六 parent 已实际清理，rescan/appearance 已按本次批准处理，Library 以本次原图反馈为准；App/Kit/源既有 owner 按各自未闭职责继续。三主仓之外的未核实体和原反例保持；归档不代替整合，未恢复产品新增或设备工作。

- current-kit 整App旧owner已实际退休：`Koma-current-kit-verify`物理6438成员、admin10成员、原选定metadata与证据及13464原App raw对象同一0600 tar完整保全；Root独立读回全部19931成员，并核904显式根和所有commit/tree子对象。全祖先20个external gitlink已核在三个既有无alternate载体；首两库未读到的c0ad最终在原Reader Kit r54载体实读，不能把本branch12 pin当全祖先闭包。6454旧地址完整映射后才移除唯一物理/admin及own ref，主仓所有working/index/flags/其他refs/其他worktree实测精确。原67ab、normal/window未采WIP、私有profile S标记及所有原证据均保全，不当产品已采用。首删前Root误要求hooksPath未配置，被原`.githooks`挡下；r2只改审计为实际effective hooks路径检查，原hooks/config未改。证据：恢复区`app-current-kit-exact-owner-retirement-result.json`、`app-current-kit-owner-old-path-to-archive-member.json`与`root-current-kit-retirement-postcheck.json`。
- ComicABC019两快照已完整归档后精确清理：281文件/400成员，13原patch全文/原8f604d对象、225实际CF归档member、DM5三个原patch和原包/WASM绑定均Root独立核回；Cargo/lib当前0110与官方图标后继保持，292外层原件及3reference保全。Root首前检误假定Cargo版本不变，在归档前停止；r2核明真实8958版本后继，不为断言改产品。证据：`root-comicabc-two281-prereview-r2.json`、`root-comicabc-two281-postcheck.json`及恢复区`comicabc-two281-cleanup-result.json`。
- GlobalComix兼容期三快照已完整归档后精确清理：311文件/431成员，256原244d baseline、4项本源业务/许可元数据在三份快照中均一致、三shared精确原档member及旧图/文档原owner member全核。现官方ICO保持，旧黑底PNG仅保参考；原613a WASM另存，2843外层记录保持，无新Host/网站/Native。证据：`root-globalcomix-compat-three311-{prereview,postcheck}.json`及恢复区`globalcomix-compat-three311-cleanup-result.json`。
- Weicomic两个受控tree已完整归档后精确清理：90文件/142成员，原dynamic→fetch分类patch、两README单段差异严格内存重建到原6669，旧SDK/两crate局部registry及原包成员分别归属，不回灌旧shared或图。6原WASM/ZIP/index参考及642外层原件保持；素材/内容Native未由本组重新接受。证据：`root-weicomic-two90-{prereview,postcheck}.json`及恢复区`weicomic-two90-cleanup-result.json`。
- Happy导航候选单tree已完整归档后精确清理：264文件/372成员，235基线各按现有或真实samepath历史对象核明，四path原继承往返及导航patch从当前完整012重建原087全同。原恢复明确`No navigation087`，所以087 lib/a91a WASM独立保为UNADOPTED_REFERENCE，不冒业务恢复或人类拒绝；25编译件/外层0HTTP及patch-rebuild保持。Root首前检误用另一报告的编译件disposition文字，r2只修审计映射。证据：`root-happy-navigation264-prereview-r2.json`、`root-happy-navigation264-postcheck.json`及恢复区`happy-navigation264-cleanup-result.json`。
- DM5原015/017两个标准tree已完整归档后精确清理：528文件/756成员，原四path patch各反向beforeSHA→正向全文、015→017真实原patch及CF实际归档中的原shared/WIP逐member核回；注册差异仅原后加CF/ABC自有行。当前017保持，50编译件、原ZIP成员/单源index分别核明，6reference和407外层证据保持；未重跑网站/构建/设备。证据：`root-dm5-standard-two528-{prereview,postcheck}.json`及恢复区`dm5-standard-two528-cleanup-result.json`。
- Kit f769两旧origin tracking名称已按r96单事务解除：原51完整admin成员及174B origin/HEAD完整reflog先保全全核；2648原raw、2578独立原件、借入70的68/2去向及D1全部1871历史前后核同。仅原symref/其log/packed D1行和具名空父目录解除，detached HEAD、31WIP、正式默认branch/stash及其余管理库/parents保持。r95缺no-deref被Git在start后拒绝，Root核全件未变；r96只给下一symref命令补文档要求的option no-deref并复用原档，不覆盖失败或放宽保护。证据：恢复区`kit-f769-stale-origin-cleanup-r96-20261019.result.json`、`root-kit-r96-postcheck.json`。

- 八份独有App原suite/tool已实际保全：8 working＋7 index＋7 HEAD＋manifest共23 member同一tar逐全文/mode读回，并重算working GitOID；七不可达working blob与一个Git无原件的locale工具不再只靠refs保存。原checkout HEAD/working、主仓全部tracked字节模式/index flags/refs保持；未应用原assert、未把此局部档案当whole-owner退休许可。证据：恢复区`app-eight-unique-original-regressions-preservation-result.json`。
- ComicFury两个11-file patch快照和277-file完整树已分别完整归档后清理：22/30与277/394 file/member；Root亲核两原patch往返、三共享root beforeSHA、6bbee全文、唯一ASSET措辞后继及当前官方图标独立取代。277树的184current exact、47真实历史路径/当前后继、咚漫三patch链、MDX原017 WIP到完整0110、D511两未采WIP及XKCD旧图reference均分开；实际原WASM/ZIP/index另存3reference。Root初MDX补检错误假定WIP等e415父提交，在任何归档删前停止；后对实际sdk-mdx原完整档精确member及原rootReview/standard SHA核回，失败/补件保持。证据：`root-comicfury{,-two-patch}-*`、`root-comicfury277-prereview-r2-variant.json`及恢复区两实际cleanup-result；当前源/图未回退。
- 幻塔与Laya三个历史整parent已按依赖顺序完整保全后清理：幻塔409file/428member，Laya两parent2335file/2356member双档全部核回后才首删；原六/七child档案分别3988/6790旧文件、4774/8138成员路径Root顺序读回，整parent索引保留全部旧地址。Laya执行精确绑定已实际完成的幻塔receipt/archive/5201旧路径index；原Huanta67及Laya447＋011仅3回放只读取既存输出，不重跑、不冒Native或全正文通过；原public25/额外logo6、12→9外部历史consumer原文保持。Huanta首只读校验因gzip随机seek主动停自身进程143，原脚本保留，r2仅改顺序读取、原断言不变。原PNG未采与Laya500原因未知继续保留。证据：`root-huanta-whole-parent-prereview-r2.json`、`root-laya-two-whole-parents-prereview.json`及恢复区两个whole-parent实际回执/索引。
- Kit四个非默认Nexte本地tracking引用已按r93精确解除：两DB完整admin205/308 member先归档全核，每DB独立一笔双ref CAS，仅packed各少2行；2946/2493全部原raw与目标1987历史前后核同，默认/symref/config/HEAD/index/log、四physical及五parent保持，无远端或产品改变。Root执行前拦下r92用待删ref名做后检的缺陷，r93仅改固定OID，原packet保留。Root首次独立读回误期望非quiet show-ref缺失返回1，实际128已留诊断；r2以完整allrefs/packed精确差异核实，未再写源。证据：恢复区`kit-four-nexte-tracking-cleanup-r93-20261019.result.json`及Root pre/postcheck。
- Onmyoji两残壳已与此前实际清理对账，未重复删除或新建目录：Root另读回891/844归档member，原47file与两844目录全type/mode/bytes相等；原843口径只算子目录。证据：`root-onmyoji-already-cleaned-archive-recheck.json`与原six-source-residuals回执。App current-kit借preload的Lexbor11869原对象保全及整owner退休已由本节最新记录覆盖；原provider与既有独立载体仍保持。

- Laya五个原工具/编译组件已完整保全后精确清理：5608物理文件、6741 tar成员，五档全部逐member读回后才首删；原010运行器确为011三操作回放依赖，已连两版WASM和static独立保留4reference。Root亲核16原工具基线＋7适配、45生成件到实际幻塔归档member及5个ISLE原输入/声明，只有aarch64/opt有原compiler dep；2318项根外原材料、源7af0 refs/worktrees/tracked字节模式均保持。不执行旧回放/构建/设备。证据：`root-laya-offline-five-{prereview,live-gate}.json`及恢复区`laya-offline-five-components-cleanup-result.json`。
- GlobalComix原baseline-originals单根已完整归档清理：295文件/412成员逐原before核回，259项直接对244d完整Git tree、36项对当前ignored原dist；Cargo原0600模式保全。外层原提案/构建/包/素材保持，不把旧baseline或图标回灌当前。源主仓与refs保持。证据：`root-globalcomix-baseline295-{prereview,live-gate}.json`及恢复区`globalcomix-baseline295-cleanup-result.json`。
- TIPO两诊断重建树＋target已完整保全后精确清理：133＋27文件、203＋44成员，原完整七路径patch与R2到诊断patch分别严格内存重建；正式R2原件保持，诊断WASM另存reference。原freeze把自身stdout先捕为空的差异单列，Root按末次print精确重建1332字节，不冒17项全frozen-exact。原Native一次403在decode前返回、早次原因未知，保留原失败/包/外层33材料，不恢复插桩/不重发请求。证据：`root-tipo-diagnostic-three-prereview.json`、两live-gate及恢复区`tipo-diagnostic-{two-reconstructions,target27}-cleanup-result.json`。
- Kit r88 prepare失败完整七文件候选继续HOLD：Root已读r88/r90、原采用输入边界与原调查；原104vp紧凑提示仅有指定窄页有限观察，全幅遮挡/非注入失败/重试/三端仍未验，具体人类UI批准未定位。App accent两确认按钮候选同样缺具体原批准，原已实施件完整保留，不借恢复之名新增可见决定。App八件独有旧suite/tool须按原全文member保全：七个working blob虽可读却不在all-refs可达集，locale工具无原Git blob，不能只bundle refs就认已保全。证据：`kit-prepare-failure-human-source-and-successor-r90-20261019.md`、App accent完整review及`app-worker-eight-unique-regression-git-closure-faa3e11a.json`。

- 已找回明确原批准的书架首屏width seed并提交 `349ef591`：Root直接读取primary81455实际问题与81470人类答复、原完整提案e3bd2bb0及有限6b927d5c回执；核cdb3/c68已归同步九字段和首次projection全链后，仅补回原`containerWidth=gridFallbackContainerWidth()`一行。真实窗口宽优先、Grid/间距/按钮/动作保持，原working/index全文先tar读回核验，其余tracked/untracked字节模式与index flags保持。没有新构建/Native，原包有限证据不冒当前验收。证据：`root-approved-library-seed-{stage-review,commit-result}.json`及App worker完整原五hunk/原call附件。
- SDK HTTP状态历史parent已完整保全后清理：269文件/360member全档逐件读回，445旧文件路径映射涵盖原Happy子树及两个原clone引用；六consumer审查快照逐原archive/member或真实Git对象核回，SDK a36与文档后继在主仓，未回灌旧源或重跑28探针。Root首次误认source snapshot必为stored Git对象、第二次误用suffix匹配到两份旧源文件，均只读失败，原脚本/失败保留；改为精确原root/member后才执行。41外部历史引用保持，源7af0全部refs/worktrees/tracked保持。证据：`root-sdk-status-parent-review-r2.json`与恢复区`sdk-status-whole-parent-{cleanup-result,old-path-map}.json`。
- 幻塔126文件重建树和四份旧工具/编译树已分组实际清理：前者119原d5基线＋7原WIP全文/patch核回，126文件/192member全档；后者2805文件/3375member四档全部读回后才首删，原Host binary/WASM/static另存3reference。Root亲核16原工具基线＋7适配、20生成件与原GoDa档同bytes及5原ISLE生成职责；仅aarch64/opt有原compiler dep，不称另3架构已编译或与当前缓存相等。原业务在主仓、PNG仍明确UNADOPTED_REFERENCE、原425项freeze材料已分档保留，根外400项与parent回放/响应保持，未新增HTTP/构建/设备。证据：`root-huanta-{diff-reconstruction,offline-four}-prereview.json`及恢复区两组实际cleanup-result。
- 章节落点 App A/B＋Kit r85 配对候选保持未应用：Root用原a27插页夹具、当前实际Store/Index方法和原fa45方法独立复核，同一已保存pageId当前落索引2，候选count-only落索引1错图。原numeric picker套件未覆盖此身份不变量；不以旧套件通过解除HOLD，不新造字段/guard补救。原候选、原失败和原fixture保持。证据：`root-chapter-pageid-counterexample-706c88c9.json`及原App worker同名runner/result；没有产品/fixture写入或Native结论。
- GoDa011完整历史parent已归档并清理：Root亲核77现文件、此前3578子树文件及6原公开body的原归档/member；确认当前012业务、原素材及11路径原提交后继。77文件/80member完整归档逐件读回后才删除该单一parent，3661旧文件地址已映射到唯一恢复区原archive/member；55份外部历史引用原文保持，不造源码别名。当前宿主ps与lsof均无使用者，源7af0全部refs/worktrees/tracked字节模式保持。明确chapters先detailHTML后API，未把原HTMLGuestExactfalse改成通过；首候选恒真检查已在执行前拦下，r2改为真实原body/member比较并固定SHA。证据：`root-goda011-whole-parent-prereview.json`、`root-goda011-whole-parent-live-gate.json`及恢复区`goda011-whole-parent-{cleanup-result,old-path-map}.json`。
- 上轮已执行的GoDa011三patch快照、offline-runner/target与包子013 combined tree清理补记：分别25/3272/252物理文件完整归档校验后删除，原包/WASM/index及失败证据独立保留；本轮未重复运行旧构建或回放。实际回执：恢复区`goda011-three-patch-snapshots-cleanup-result.json`、`goda011-offline-pair-cleanup-result.json`、`baozi013-combined-tree-cleanup-result.json`；各Root原prereview和失败边界保持。
- 本轮原WebDAV搜索单图身份已归回 App `47099332`：原af437三段数据改动逐原Git span核同，保当前811远端字段与23c请求归属；单图使用child URL的image键域，目录身份/config保持。原working/index两份全文tar逐member核回后精确提交；实际暂存的open→handoff→persist消费链内存审计显示目录与两单图由互覆1项变为独立3项。未恢复e22远端History/reopen或WebDAV单图Row，不推测旧混合进度归属；无新ArkTS/Native。证据：`root-af437-single-image-{stage-review,commit-result}.json`及`app-worker-af437-existing-progress-consumers-actual-index-9cd6848e-result.json`。
- 三份原测试WIP已归回 `18652cda`：Kavita原25项完整结果断言、Tracker原账户签名/偏好并发与回滚断言，三份全文与production原working精确。九份完整working/index/source-after原件先tar核验；实际暂存suite及源码完整运行，未改原断言/fixture。仅恢复原回归材料，不当产品新增或真实账户/NetworkKit验收。主仓旧`test_source_sheet_state.cjs`仍要求已被0d4明确取代的无参Builder，Root亲读两份完整tar中8036B/0644原member后只移除该untracked副本，原证据双载体保持；appearance另一原WIP测试未动。证据：`root-original-three-suites-{stage-review,commit-result}.json`及恢复区`source-sheet-superseded-fixture-cleanup-result.json`。
- Sono0110单tree及独立patch-work已分别完整保全核验后精确清理：tree278文件/395member、6包/WASM/index原reference，Root重建原四项patch、核59项原已审archive同member及331相同+18明确后继锁实体；外层241具名记录保留。patch-work36物理文件含完整admin另档；原9对象以Git pack/index并在现有无alternate载体逐type/real-size/rawSHA/GitOID核同后才删除，原index/reflog/合成baseline亦完整保全。未新建clone/worktree；前一验证载体两pack副本仅在其永久原件逐bytes核同后轮换。源7af0 refs/worktrees/tracked/模式保持，parent和原失败材料保留。证据：`root-sono0110-prereview.json`、`root-sono0110-patchwork-prereview.json`及恢复区`sono0110-{canonical-tree,patchwork-independent}-cleanup-result.json`。
- 原神011 `delivery/frozen-source`七文件/11member已完整归档核验后精确清理：三根文件由原d5 Git基线与原clone rawRootDiff内存重建，四源文件另与旧完整clone归档逐member核同，原source-only patch精确重建当前012；原011ZIP/WASM/index/icon另存4reference，57外层证据/parent保持。Root首只读前检误把full-base-diff当原clone rawRootDiff，断言在归档/删除前停止；首脚本/失败保留，r2查清原来源后继续，未改产品/断言。证据：`root-genshin011-frozen-prereview-r2.json`及恢复区`genshin011-frozen-source-cleanup-result.json`。
- Kit f769旧F1 tracking与旧local D1冗余引用已分别按r79/r83精确解除，local D1原唯一配置节同组清理，r83当时remote D1与origin/HEAD保持；这两旧tracking名现已由本节r96记录覆盖。D1全部1871历史raw对象仍在正式Kit，源2648=原2578+借入70，68可达与2已有独立载体分别核同；原full admin/ref/reflog均保全。r80首次执行因父App共享master从5a→4709而在任何写入前停止；Root独立深比较唯一该ref差异，新r83仅重绑定该事实，不放宽parent门禁。证据：恢复区`kit-f769-tracking-f1-ref-cleanup-r79-20261019.result.json`、`kit-f769-local-d1-ref-cleanup-r83-20261019.result.json`及`root-kit-r80-execute-output.json`。
- 上轮补记：WEBTOON014五旧树887文件/1285完整member及9项原包/WASM/index已保全后清理，27项原annex亲核；R2日期/描边事实由App `5a0899fb`归回，两张原白底图已查看，不含用户引述。证据：`root-webtoon014-five-prereview.json`、恢复区`webtoon014-five-trees-cleanup-result.json`和`root-document-r2-{stage-review,commit-result}.json`。
- 当前未验证动作及owner：Root接续preload整App owner当前引用、完整physical/admin/ignored和897根/13479 raw闭包亲审；current-kit已实际退休，preload原两incoming须据当次重核，不能按计划写零。App原owner继续该包、production10全物理只读库存及remote15事务/旧session安全接线/文档原事实；已核可见/章节身份HOLD保原。源原owner接续仍实存图标/标准索引树和parent映射，Root亲审ComicFury官方011/XKCD透明013、MPC/PGR/Terra既有packet；已清分组不重复。Kit两live与c585/eceb真实消费者仍在，不prune或迁admin。产品新增和设备继续暂停；整体恢复及远端同步未完成，本批为本地检查点。

- 11个Lexbor复制别名已逐份完整归档后清理：Root独立核11627原文件，所有1056份c8 Git tree blob/mode及各原1057-file copied-map全同，无独有源码/额外WIP；fresh宿主parent进程匹配为空，逐copy lsof门禁通过。11份完整tar共13343成员先全部核回再首删，11个原.git文本独立保留；62外层原Host/freeze/prepare/回放材料及所有parent保留，未运行旧脚本。源7af0及共享Lexbor refs/index/admin/worktrees保持，不建立recovery-admin，不把alias当登记worktree移除。证据：`root-eleven-lexbor-prereview.json`、`root-eleven-lexbor-live-gate.json`及恢复区`eleven-lexbor-alias-cleanup-result.json`。源原owner继续WEBTOON014五旧树。
- Kit四个冗余local ref已精确解除：831、1e97、4d499、1afe的全部历史均仍由现e2保留，原72-member管理档、完整ref/reflog及2946个源/独立raw对象全核；r75/r76各单CAS，r77两ref同事务CAS，只有四ref及各完整已保reflog消失，其他admin/physical/父App与正式Kit签名保持。原未采用两seek优化、diagnostic日志、thumbnail/首mount候选仍保原对象/档，不因删重复标签当产品已采。r75首次脚本读取后曾新增binding/证据复制，Root执行后核最终保全script只增加原范围内保全和SHA门禁、唯一CAS范围不变；已要求发布packet冻结，r76/r77逐最终固定SHA执行。原三语五既有key的working排布另以`9cd6848e`收束，15key/value映射全等且work文件未写，不冒产品进展。证据：恢复区`kit-redundant-{831,1e97}-ref-cleanup-r7{5,6}-20261019.result.json`、`kit-redundant-two-hostrefs-ref-cleanup-r77-20261019.result.json`及`root-five-existing-resource-order-{stage-review,commit-result}.json`。

- 私库原请求归属完整组已归回 App `c7138ff7`：Komga/Kavita/WebDAV三页159增35删，90原Git span逐原blob/行hash与当前双端口核回；六份原working/index全文tar核验后精确暂存。所有当前Builder、Kavita原auto-upsert与Reader发布、显式收藏对象保持；缺失e22 resume/history与单图动作不夹带。真实暂存输入的原Komga10/Kavita10行为断言通过，WebDAV现有5/6通过；原完整第4远端resume仍pending，原失败与排除原文完整保留，不冒整套或账号身份fence通过。其余working字节/模式、index flags保持；无当前ArkTS/Native。证据：`root-817-request-owner-{stage-review,commit-result}.json`、`app-worker-817-existing-request-owners-22f4fb11-review.md`。
- 漫画屋012/咚漫011/DBM011三标准快照已精确清理：759原文件、1093完整tar成员先三档逐件核回再删；6原WASM物理路径+3原ZIP+3index共12reference保原mode。Root独立核原23change、34ignored物理副本、55原Git或computed-only WIP身份、29后继去向、锁完整实体以及咚漫011→012→013→014三原patch纯内存重建；无旧图/SDK/registry回灌。三次只读前检分别在本地crate连字符、原ICO删除后继、computed-only WIP非stored blob处停止，失败原件保留，查清类型/原提交后才归档删。96外层原403/overlay/失败/回放材料保持，源7af0 HEAD/refs/worktree/tracked字节模式保持。证据：`root-three759-prereview.json`及恢复区`manhuawu-dongman011-dbm-three-trees-cleanup-result.json`。
- Kit r74发现旧Lexbor nested admin另有11个源实现目录的lexbor-copy实际.git引用；它们共用原index/admin，不能只改两live后删父库。Root已读r74全部边界，决定本阶段不新增recovery-admin长期管理形态、不迁库：先由源owner逐项核11实体成果，App原owner继续余WIP，消费目录安全清理后再解原admin。原2493/12068对象及六档完整member复核保全；Kit owner继续f769/c585/eceb原职责/冗余ref核定。整体恢复OPEN，产品新增和设备仍暂停。

- MyComic011/漫画堆012/漫画社012五兼容与标准树已精确清理：1359原文件、1907完整tar成员先五档全核回再删，10个WASM物理路径+2原ZIP+2index各保原mode共14reference；五业务lib全bytes等当前，另5个provider lib仅一次sourceInfo.version后继，27原shared/asset/notice去向逐项核。MyComic缺可信icon的原fcea no-pack继续保留，未回灌旧build注册；403重建信封、漫画社缺3HTML及两横标视觉边界保持。Root首读误假定原changes只有structured after，读前检KeyError即停、未归档删；r2显式核structured/flat两种原SHA结构后继续。源7af0 refs/worktree/tracked保持，无新网络/构建/Host/Native。证据：`root-five-compat-standard-prereview-r2.json`、恢复区`mycomic-manhuadui-manhuashe-five-trees-cleanup-result.json`。
- 原thumbnail完整r72候选暂不应用：Root亲读原source-design/review/first-chrome incident与现Rail/Surface；现Rail卸载设alive=false并以自身snapshot交key/nav，原1afe/r3及r72host只交index后读取Surface当前key/nav。若旧A回调在B ready交付，会被改标为B请求并绕过现retired栏拒绝门；这是源码合同反例，未冒Native已观察。原有限r3/另一d3包验收不覆盖它；r72原件与r73证据保留，不新造guard/测试迎合。ReaderPage拟抽取所有旧scroller/Tile调用残余已核，但不因此拆裸port应用。证据：`kit-thumbnail-guard-and-readerpage-residual-audit-r73-20261019.json`。Kit原owner继续两live模块admin去向；App原owner接原remoteHistory13文件完整请求/历史消费者组，源原owner续余实体及纯证据parent最终归档映射。整体恢复OPEN。

- six共同组三快照已精确清理：302原文件、427完整tar成员先三档全核回再删；17份ignored按真实物理字节/模式及fresh check-ignore核，12个原compilerWASM路径与6个原ZIP分别保全18reference，外层actual-canonical-build/standard-packages/replay/失败/Root原件保持。Root亲核原8→after补丁重建、46后件去向、metadata/icon fixture全bytes等f7、CI等3faa，build除registry外等原f7，锁依赖以name/version/source全实体核，旧Terra010由原完整016→017保留。无新构建/Host/Native，不回灌旧源/图。证据：`root-six-common-three-prereview.json`、恢复区`six-common-three-trees-cleanup-result.json`。

- 腾讯/BH3四203快照及Terra016三快照已完成精确清理：1013原文件、1466完整tar成员先七档全核回再首删；Terra原646b ZIP/compilerWASM/index另存3份reference，父目录全部平级原件保留。Root核三after快照四资产逐bytes等当前、Terra四路径原patch内存重建且完整016业务到017仅version变化；锁依赖按name/version/source逐完整实体核（无同名覆盖），仅旧本地源版本后继及koma-source-dev原getrandom新增，根注册/构建全diff另存，不回灌旧资产或旧parser。源7af0 refs/worktree/tracked字节模式保持。证据：`root-tencent-bh3-terra-seven-prereview.json`、恢复区`tencent-bh3-terra-seven-trees-cleanup-result.json`。两旧审计文档仅将原WIP历史marker归入提交，其他旧quote/Native/架构断言不采纳；整体恢复仍OPEN。

- 原mode host委托完整组已归回：Kit `d79a258c`、App `91c2da70`。Root直接核原1afe/829 Git raw、完整叶子及HostModeControl，明确选829仅进入continuous时ltr，不混用较早f769离开时也重置的WIP。六existing working/index原件先完整tar12member核回，分别精确stage；其余tracked/untracked字节模式及index flags保持，提交后index空。原Kit三份完整检查27/27，App mutation-owner通过；未改bridge前后均在旧hostSettingsAvailable形状断言失败，原失败保留。原mode包仅菜单有限接受且handoff黑屏/页位仍Rejected，本次无ArkTS/Native、不冒已解决交接。证据：`root-mode-r71-{stage-review,commit-result}.json`及原检查日志。
- FGO012/原神012/魔纪011七旧树已精确清理：1406原文件、2081完整tar成员，先七档逐member全部核回再首删；21份原ZIP/compilerWASM/index另存具名reference，外层原patch/Root/HTML/失败/Native不删。Root独立纯内存重建三原source-only补丁到当前，核旧README/锁版本/注册后继及55旧foreign+10非线性决定去向；首轮误把computed-only WIP OID当stored Git blob，read-only前检失败，任何归档/删除前停止并保留；r2按真实Git/raw WIP分端口核验后继续。源7af0全部refs/worktree/tracked字节模式保持，不回灌旧图/旧票据/旧episode号。证据：`root-official-array-seven-trees-prereview-r2.json`、恢复区`official-array-seven-trees-cleanup-result.json`。
- 进行中与owner：Root亲审原thumbnail完整候选的当前导航/preview守卫适配及源剩余组；源原owner核MyComic/漫画堆/漫画社旧兼容/标准树，Kit原owner核claim/layout/host和production两module live引用，App原owner继续原WIP去向。production05实体仅41服务file+6旧build链接，普通源码0、index921等原tree；4bind保原位可与源码/admin分开，不能因迁服务需要停止而阻止其余清理。Komga宿主/data与容器/data均缺，未造缺目录、未停服务/迁数据；父admin因两live引用继续保留。rescan可见范围与新远端session时序保HOLD，不造新实现。整体恢复OPEN，产品新增/设备仍暂停；上述本地提交未推送。

- 两批源旧树已实际清理：咚漫012/013/014三树846文件、1197归档成员，逐原四路径补丁内存重建及9类foreign锁版本去向核后，先完整归档逐member再删；17份canonical ignored证据单独核真实字节/模式/check-ignore，不冒Git blobs。Root首次误按Git输入核它们，在任何归档/删除前停止，原失败保留。六漫画011两树770文件、1034成员同样完整屏障后删；实际部署545b ZIP、870f编译WASM及原index已另存，不以另一同成员ZIP替代。外层原HTML/图/包/失败/Native保持，源主仓7af0的HEAD/refs/worktree及tracked字节模式全保持。证据：`dongman-three-trees-cleanup-result.json`、`sixmh011-two-trees-cleanup-result.json`。
- Kit current-verify 独立子module已由Root执行r68精确清理：完整admin328、physical529成员及独立2555原raw对象删除前重核；源另见9个canonical alternate新对象逐raw核回。删除后r61独立2555仍可读。父App该路径status由M→D如实记录，父其它源码/index/HEAD/refs/privateAdmin/ignored与六其它owner全保持；仅删该Kit，父App保留。两stash及b2/4f具名未验原候选完整保全，不回灌、不冒已接受；f769/c585/eceb及production live引用另审。r67未执行，Root工作单提交仅master前移后按r68重新冻结；两无关V2Next path-reference消失原因未知单列，不冒本任务修改。证据：`kit-current-verify-cleanup-r68-20261019.result.json`及完整r61载体。
- CI恢复提交 `034a4d64`：原959的workflow/README按当前正式同级Kit路径整合，pin已提交clean84237f7；只两文件，实际index YAML解析及内嵌Python编译通过。首次前检误以index hash核私有working build-profile，在写前停止；后按双端口核验并保原working/S flags，未覆盖配置。Kit本地无origin，远端该SHA可取与跨库凭据均未验证；未运行CI/构建/推送。证据：`root-ci-formal-sibling-stage-review.json`。
- History/书架既有Exact-ID WIP提交 `31f2bca5`：三文件完整恢复UUID→Index→描述符查询→原事务持久化→取页链；三方接现URL/current guard、sameComicIdentity与最新全字段clone。原三working完整tar逐件核后才改，两数据文件仅适配当前合同，Index其它WIP保持。实际index九场景覆盖opaque翻页/wrongID/回滚/epoch/身份/设置失效及真实History调用保原会话；无新Native。Detail缺UUID消费者原实现未定位，未按计划补造。证据：`root-exactid-current-contract-stage-review.json`及原实际方法结果。下一owner：Root继续亲审原有效组与余实体；App worker追source-settings远端session消费者/Settings真实外观Owner冲突；Kit worker审mode完整三方闭包及原claim/layout；源worker审六漫画010大树。产品新增/设备仍暂停，整体恢复OPEN，以上本地提交未推送。

- 原主仓文件夹阅读 WIP 已作范围提交 `6b62491a`：仅 Index 四处已有 span（root helper/单根激活导入、prepareReaderSession 等待授权、LOCAL_FOLDER 准入现有 loading），工作区源码字节未变；实际暂存两个完整方法的八项受控 grant/epoch/close/offline 场景通过。相对旧 index 存在现有加载层时序差异，无新文案、控件或当前构建/设备结论。原 Sep12 Adapter 记录仅作职责来源，不冒当前 Native。证据：`root-folder-reader-readiness-*`、`root-6b62491a-readiness-commit.json`。
- 被 7f8/a987 失败硬门控取代的旧授权警告 WIP 已核清并移出工作区：Root 亲读原 baseline 的 success/accessStatus 与真实后继，当前 succeeded 只可能 persisted/activated；两完整消费者的14项可达 trace 前后相同。六 working 原件先完整 tar 并逐件字节/模式读回，再应用 `545e8e8a` 精确清理；index 无此旧组、保持不变，其余 tracked/untracked 字节和模式保持。原警告原件及差异保留，不放松授权门控、不新增可见反馈。证据：`root-superseded-folder-warning-*`。当前其余16 tracked WIP/2 untracked、Kit 已采用但有失败反例的组和源旧实体仍继续核实；产品新增与设备操作仍暂停，整体恢复 OPEN。

- 本轮原主仓WIP恢复：App `59a885c7` 仅归回 `scanPickedFolderUri` 原失败catch，stat错误不再伪装 `exists:false` 发布缩减页表，改走既有 `folder_scan_failed`/failed且无scanResult；Root亲核完整picker、Contract、summary、持久化与Index/ImportPage成功准入。实际index本轮before/after方法检查及原20260905三个完整stat/list/正常用例通过，仅补FileUri端口，不变原断言；全部tracked工作字节/模式及3untracked保持。无新文字、样式、权限放宽、构建或Native结论。原逐字人类来源未定位，不冒历史批准。证据：`root-folder-stat-failure-stage-review.json`、`root-59a885c7-*`。
- 十八旧六图标打包夹具已精确清理：r0/r1/r2共361原文件、595完整tar成员先全部归档逐件核后才首删。Root亲核原采纳Git blobs、f7共同工具差异、受取代的r0新模式/r1白名单、四陈旧素材说明的4209/539后继、腾讯首次失败/不同flags标准WASM与原包成员。外层素材/原包/REPORT/原拒方案保留，未回灌旧图或改当前图标，源主仓7af0及所有refs/worktree/源码字节保持。证据：`six-icon-eighteen-fixtures-cleanup-result.json`及三份完整原审附件。
- 旧master-integration残壳已清理：三个符号链接及全部私有admin/index/log先完整归档逐member核，13164个App原对象独立pack逐type/rawbytes/SHA/GitOID重读；两个160000外部pin分别在r54独立Kit/Lexbor载体核同。69af→156→1e4原提交闭包仍由保留production继承，69af的CMake单文件当前精确；这不冒所有108职责均已归并。只删 `/private/tmp/koma-master-integration-20261005` 与其私有admin；主仓全部WIP/refs保持。首审计脚本误用仓根CMake路径，在任何归档/删除前停止，按真实 `entry/src/main/cpp/CMakeLists.txt` 修正，原失败保留。证据：`master-integration-residual-{preservation,cleanup-result}.json`。
- 两个production旧模块库已完整独立保全：r54实际执行ReaderKit2493与Lexbor12068全raw对象（包括不可达/旧refs）、所有显式根、完整admin含objects/nested、self/live两份physical与两index；每个tar成员及无alternate载体逐对象核同，源metadata/物理/对象前后稳定。此项解除cb4f原pin仅在旧现场的风险，不称26/935独有历史职责已归并，live gitfile仍指旧nested，因此production父admin继续保留。两个旧Docker仍运行且bind旧production的Kavita/Komga数据，不按prunable删活目录。下一owner：Root审Kit126/88b完整输入原组及剩余可清理源树；App原owner继续17WIP逐职责、CI同级适配和缺失Detail消费者；Kit原owner继续余原组/引用去向；源原owner继续全实体与外部证据去向。产品新增/设备仍暂停，整体恢复OPEN，所有本轮提交未推送。

最新人类任务是逐项核清相关目录、分支与未提交差异，找回遗漏的有效成果，归并至原主仓。App 目标为 `/Users/honjow/git/Koma`，源目标为 `/Users/honjow/git/koma-sources`；`Koma-production-20261010` 及其他工作树是待核材料，不能自行升格为正式目录。产品新增开发与设备操作仍暂停。用户随后明确要求：所有相关工作树和分支逐项核实、归并、确认后清理，完成后再回到原先开发。清理不是永久搁置项；每个待删对象必须先解决其独有提交、tracked/untracked/ignored内容及必要证据的去向。未核清对象不得提前删除或整体覆盖。下方旧开发队列不用于覆盖本次任务。

- 现有Reader事件归回检查点：App `22cdf373` 接原0c1的Legacy实际save→observe、Index真实准入begin/观察/关闭commit布尔/restore reset及Lab事件消费者；当前Kavita真实先upsert Library再onOpenReader，故明确三方用现LibraryStore身份，不伪造未来transient helper。原Index代码块及ReaderPage全部原span亲核，19块WIP changed payload与其他tracked/untracked保持。实际index原producers整套和明确标注为本轮补充的五方法admission检查通过；normal Shared epoch/18e transient/原新增失败toast仍OPEN，无新账号/网络/设备结论。证据：`tracker-0c1-reader-*`。
- 失败候选保留：Kit r45的原crop/variant完整候选在Root重建原实际生产Core/Surface输入、核11span后临时应用；实际两原测试文件31/32通过，crop释放case预期left0.1实0。已严格反向撤回本轮四文件到clean `854a4df`，未提交该候选，完整失败/原patch保存。worker已定位原case遗漏asset.crop fixture生产者，尚在核真实slot/request前置，不能按当前缺桩改产品或删除断言，也不冒全组已归。ignored26件已从r41独立物理档逐member读回，其中18仍同现场、preload8已按r43清；ignored保全不再OPEN，余源产品组仍待核。证据：`kit-r45-*`及原`kit-ignored-independent-full-member-receipt-r45-20261019.json`。

- 继续恢复检查点：App `83dcd3d8` 归回原800→b380→684的协议、按filesDir串行偏好Owner及全部六消费者；逐原Git span分别重建working/index全核，其他tracked字节/模式及untracked保持。五套原grant/owner/read/member/oauth在实际index完成并等待原Promise通过。Settings保原乐观赋值/Builder/反馈，原684在当前epoch保存失败后回读committed值，明确这会改变失败后显示值；specific原人类话语未定位，不冒历史批准或零UI差异。随后 `257350f7` 接回原0c1完整Service/Detail职责与原ReadingProgress全文，显式ordinal/null、自动不倒退、队列count/origin及全部现push/retry/pull消费者保留。原events/provider整套及原producers完整Detail段在实际index完成通过；Reader全部开始/观察/关闭/restore生产者与normal Shared路由仍OPEN，无新账号/平台IO/ArkTS/Native结论。证据：`tracker-684-*`、`tracker-0c1-*`。
- 继续归并与清理：Kit `854a4df` 归回ccf原物理像素舍入几何叶子及原两个case；Root逐span/原HAP与ledger核SHA，并从854+原core.patch在内存还原完整ccf Viewport相等。实际两份相关原测试23项通过；当前Koma没有entry producer，不称入场链/完整crop或layout retention已生效。源17旧registry/eight校验目录先完整11,510成员及各树合计7,894对象记录独立raw核验后清理；Komiic六旧校验目录先完整2,306成员及各树合计12,374对象记录独立raw核验后清理，014旧README原件保留。两批都在首删前完成全部physical/admin/pack屏障，源主仓HEAD/refs/worktree/字节模式保持。首17脚本误选系统Python缺tomllib于导入处终止，原失败保留，换当前有模块Python执行同脚本成功。各对象数含跨树重复，不冒unique总数。所有本轮提交均未推送。证据：`kit-r44-*`、`registry17-*`、`komiic-six-*`。

- 本轮恢复检查点：App `c7fe6a3f` 归回原 bd9/088 成功同章快照复用、失败跨章交接拒绝及 721 必要 placeholder 排除/稳定历史补齐；实际 index 运行原 088 三个完整行为用例通过，Index 原 19 块 WIP 保留。随后 `98ac15f6` 接回原 9d 分类器及 721 明确 unsupported 原因的 Index→Adapter→Page 消费者，六文件限定归并；原 classifier 全断言及 Adapter 原原因/清空/取消段通过，未知错误保持原 fallback。Kit `e39f5f8` 恢复原 99f 两处 catalogFailureText 端口，布局/重试控件不变。初次失败只消费一次、普通 Shared epoch/关闭晚回调及完整重试仍 OPEN；旧 preference bridge 整套的 hostSettingsAvailable 前置仍缺，不冒全套通过。无新构建/Native，上述提交未推送。Root 首次 WIP 比较误用字符切片、提交后误比 MM/M 状态均保留原失败；按精确双输出/原输入反向内存重建核回后续接，没有为审计断言改产品。证据：`source-catalog-snapshot-recovery-*`、`source-failure-copy-recovery-*`、`kit-catalog-failure-text-recovery-*`。
- 已实际清理 DM5 十二旧目录与包子设置/原神旧版/幻塔三个目录：全部先完整归档逐 member 校验，再按精确路径移除；源主仓 `7af0d9d8` 的 tracked 字节/模式、HEAD/refs/worktree 保持。DM5 2,062 个完整对象在无 alternate 裸载体逐原始 body、真实 size、SHA 与 Git OID 重建核同；首次 r4 错把 verify-pack delta 表示长度当 raw 长度，在删除前拦下，原包及失败记录保留，后继复用原包独立重建后才清理。幻塔原官方 PNG 另存未采纳参考，不冒采纳/拒绝。证据：`dm5-twelve-*`、`dm5-independent-allobjects-raw-validation.json`、`baozi-genshin-huanta-three-batch-cleanup-result.json`。
- Kit 原件保全已执行：r38 独立验证 f769 的 2,578 对象及 c585/eceb 共享库 2,946 对象，原 admin 逐成员核回；r41 再保四个现场全部物理内容、各自 index/WIP 与 26 个 ignored 路径，tar3/tar4 完整独立副本转存主仓恢复区。preload 另有完整自有 admin 和 1,871 对象与 canonical 真 raw 核同。保全不代表这些现场产品残余已归并；f769/c585/eceb 及 claim 失败组继续 OPEN，不能据 archive 或 clean 删原库。证据：`kit-r38-root-preservation-execution.json`、`kit-r41-root-preservation-execution.json`、`kit-physical-complete-r41-20261019.receipt.json`。
- 下一动作与 owner：Root亲审Kit r45完整crop/variant子组及源Happy/ComicABC/ComicFury旧工具树保全清理；App worker继续0c1全部Reader生产者、c670原入口/Exact-ID完整Detail与History职责及CI原布局决策；Kit worker继续ignored独立保全和其余原职责组；源worker继续所有残留实体与外部证据去向。description-null/CLI、IQIYI及五个reviewed nested checkpoints、preload唯一子模块已按各完整回执清理，外层证据保持。Exact-ID当前WIP仍不能覆盖Detail缺章继续阅读，不按History显式ID单路径称完整恢复。产品新增与设备仍暂停；整体恢复继续OPEN。

- 已有材料保持：未删除、未整体覆盖或整体合并任何未核清目录/分支。App 五份与 Kit 四份原 WIP 的字节快照、原 patch 和归档路径见 `.hermes-artifacts/recovery-20261019/` 及 `/private/tmp/koma-ui-delivery-regression-20261019/`。
- App 恢复检查点：`e3cadc5a` 保存已接受的十五页外边距；`1e969c3b` 恢复原已批准的源索引完整地址换行两文件；`a813b8bd` 保存既有更新结果分类、失败摘要持久化/退避两模型；`bde6ef19` 保存原主仓有效 WIP 的更新协调器、首页/设置消费者、结果页实时刷新及名称投影，含详情页同一名称消费者和三语有限资源。实际暂存源码的协调器/生命周期/名称消费者检查通过，未建立另一源码或构建目录。旧生命周期 Host 桩补齐现有 Reader Lab 无关回调与 context，产品生命周期未改；原失败保留。此项只是已核 WIP 检查点，后继备份写入门控已按原 aacab13f/4066a692 合入 `39a89316`，保留主仓分类；实际恢复类/协调器互斥与退出检查通过。其余备份参与者、Settings epoch/manual消费者保护仍待分别归并，不能称全部更新链恢复、完整备份安全或当前安装包通过。源详情弹层按已接受 a6f/41584 后继恢复为 `0d4dcc47`，原主仓早期实现另存；四个方法/渲染参数绑定原件，未添加新 Native 结论。
- 源恢复检查点：`78f17f2` 找回阴阳师；`32d1fc3` 找回雀魂已接受 r1；`91170d7` 找回 Dota2 已审 R3；`5add675` 找回蓝档已审 metadata R2；`eb1b49b` 找回 XComic 繁中原绑定七源文件；`7d3dbe7` 找回 MangaBall 原绑定七源文件。两包仅追加各自三处注册，当前 SDK8506/rustup 离线锁定构建与无网络 source_info 通过，其他 tracked 字节保留。XComic 首次误用 PATH Homebrew rustc 的目标失败日志保留，改用已安装 rustup 后成功，未下载工具。MangaBall 原临时 final-review 缺件没有补造；可用原 precommit 绑定及原 Native 回执分别保留。均直接进入源主仓，保留当前 SDK；当前 SDK8506 离线锁定构建与 source_info 已通过，无新 Native/HTTP 结论。雀魂原 README 仍有0.1.0/固定150的陈旧描述，原字节保留，不能据此降级 r1。原生成辅助脚本保留于原目录/归档，未当成 r1 生产工具复制。
- 本地导入完整组恢复检查点：`c99cc360` 将c851原13生产文件的持久内容/来源身份/有序内容比较、提交所有者和首页/导入/书架/详情进度消费者归并原主仓，并带入aacab原导入写入门控、cf991中文默认标题后继。原LOC001B13源码及TITLE001源码绑定全核；不把原命名Native扩大为当前验收。实际暂存完整模型/Store/持久化/提交类Host覆盖相同字节身份及进度保持、变化后章身份失效、标题/选定封面保留、同名不同来源、持久化失败真实回滚helper、备份互斥与标题边界；平台hash/文件/落盘IO被mock。9非UI模块解析转译通过，无当前ArkTS包/Native。首次Host样本缺必填计数、首次新文件暂存缺--add均保留失败并按实际接口/部分状态修正，未改产品逻辑迎合测试。各页无关原WIP保留且排除于提交。证据：`.hermes-artifacts/recovery-20261019/local-import-recovery-*`。
- 备份预校验前置恢复检查点：`9594a1b4` 找回bd8原两文件的写前载荷校验、源包prepare/commit/discard及两个普通picker入口共用的授权URI读法。原BAK001A回执两源码hash与Git原blob全匹配；主仓未核Reader实现字段暂保留现状，未当永久拒绝。实际暂存import方法Host证明坏外层字段/源预备失败不触达活数据消费者，正常plan执行提交/丢弃；两模块解析/转译通过。仅Host阶段顺序（模型/IO被mock），无新ArkTS构建或Native。此为aacab依赖前置，跨域I/O回滚、启动恢复、便携设置c971等仍OPEN，不能称整个备份安全完成。证据：`.hermes-artifacts/recovery-20261019/backup-prepare-*`。
- 设置更新状态恢复检查点：`ca1b8af9` 归并4066/c628的过期回调保护、手动请求去重/释放及原十二键存储回滚；保留主仓保存成功后才显示的行为、既有结果分类/提示/退避/刷新，以及Settings显式操作与Index前台门控的原边界。旧后继的乐观显示与本次r1候选未应用。原Host检查覆盖保存和重读同时失败；实际暂存源码的协调器、生命周期、分类、原c628回滚/当前epoch消费者、手动方法检查通过。首次协调器平台桩缺has/delete失败保留，补真实平台API后通过；未用产品逻辑迎合桩。Builder/文案/尺寸不变，设置页无关WIP保留且未入本次提交。未构建或新增设备验收。证据：`.hermes-artifacts/recovery-20261019/settings-update-recovery-*`。
- 漫画1234业务恢复检查点：`6ffeaea` 将原有限 Native 接受的完整0.1.2源码（lib049e6301）、Cargo版本及原localizedNames恢复到源主仓，只改本crate lock块。旧候选README末段纠正为不引图标，96底板/1254棋盘/已拒生成稿均排除。115份原Native绑定全精确；shared75绑定仅当前WRITING_A_SOURCE说明已变，未冒称全精确。当前SDK8506离线锁定WASM及无网络source_info通过，未打包、未新增HTTP/Native验收，图标质量保持OPEN。首次工具路径不存在、未进入编译的失败另存；随后按实时rustup路径编译成功。证据：`.hermes-artifacts/recovery-20261019/mh1234-*`。
- Pixiv018恢复检查点：`9fea2f1` 将原26ae0f5七个生产文件原字节及三处注册归回源主仓；旧SDK绑定打包helper留原目录/原提交，不接入生产。当前SDK8506离线锁定构建及无网络source_info通过，生成WASM86f814d8与原018已审产物全字节一致。原018普通搜索第一页至第二页有限Native与015阅读/下载/cold证据分开；无新HTTP/打包/设备验收，图标质量及整体恢复OPEN。证据：`.hermes-artifacts/recovery-20261019/pixiv018-*`。
- 本地刷新URI恢复检查点：`73715053` 将a55d6cae原单文件转换原字节归回主仓index；`file://docs/`误判缺失的生产方法Host在真实index/blob复跑通过，旧路径/实际缺失/畸形URI保留。当前同文件独立重扫WIP原内容及其他tracked工作字节精确保留、排除于提交；无新构建/设备/权限验收，原437 Nemo有限Native仍绑定原HAP。证据：`.hermes-artifacts/recovery-20261019/local-refresh-uri-*`。
- 瓜子012恢复检查点：`8349f50` 将原8个provider/来源文件及三处注册归回源主仓；业务相对011仅版本字段变更，CSS/图标原字节保持。NOTICE过期无图标声明及ASSET未部署状态按后续原g08回执限定纠正，原文保留。当前SDK8506离线锁定构建与无网络source_info通过，新WASMbc876bb5与原012不同，不冒当前正文等价或Native验收；原g08只接受具名32vp图标，011业务原绑定仍OPEN。证据：`.hermes-artifacts/recovery-20261019/guazi012-*`。
- Reader实现数据依赖恢复检查点：`d15e4347` 仅归回faa9合入时的27行字段与4处拷贝/备份消费者；4个文件与原merge全字节一致，BackupService保留bd8预校验。实际index的Store/备份方法Host证明持久legacy、单书窄覆盖与备份显式字段保持，IO/runtime发布被mock；无菜单/路由/几何修改，无当前构建/Native。0ffb串行Owner、1650主题/后端发布、完整Shared入口及aacab/c971后继仍OPEN。证据：`.hermes-artifacts/recovery-20261019/reader-implementation-data-*`。
- 共同文本写入依赖恢复检查点：`850621fc` 找回原9a4a8bd3共同writer及书架/备份/下载清单消费者，保留c851导入模型、外部picker及其他WIP。helper/OfflineStore原字节精确；实际index helper与Library adapter在内存fileIo下覆盖短写/fsync/rename失败保原字节、只清本次同目录sibling，正常完整UTF8同步后替换。未新建测试目录，无当前构建/Native/断电承诺。aacab候选r2保留未应用，后继r3/r4已带入本依赖并按上述检查点归回；其余持久Owner与整体恢复OPEN。证据：`.hermes-artifacts/recovery-20261019/app-text-persistence-*`。
- 备份参与者恢复检查点：`dc5872c5` 接回原aacab的日志/写入参与者及启动恢复；11个数据文件原字节精确，Backup保留850共同writer，Entry逐块保原窗口/方向，Index只暂存原3处守卫且自身WIP精确保留。原30检查点场景以内存fs/Prefs复跑、61真实方法恢复期拒写及实际Entry成功/失败顺序通过；无新测试目录/设备/真实进程死亡承诺。首次门控检查发现此前将LibraryUpdateService服务门控视为已恢复的登记不准确（39仅Coordinator）；原失败保留，按原aacab补齐服务且保主仓分类，未冒新App绕过。c971/0ffb/1650/Shared及其余后继仍OPEN。证据：`.hermes-artifacts/recovery-20261019/backup-aacab-*`。
- 串行偏好/主题数据与消费者恢复检查点：`a85b3e35` 找回0ffb+1650的提交Owner，Store/后端State/原测试与1650精确，Bridge与0ffb精确；Legacy只带原13行增量保存，原系统栏/几何保留。Entry在成功loadContent后绑定/加载主题，销毁解绑，保aacab启动恢复及主仓窗口代码；Settings只暂存原主题保存/reset两方法与导入，其余WIP精确保留。原测试在index等字节输入通过；实际Entry5/Settings3受控Host通过。首次缺backendState失败及准备阶段两错误保留记录，未删断言/迎合产品；无新包/设备/整体验收。Shared嵌入/58a单书消费者与后端菜单路由、c971仍OPEN。证据：`.hermes-artifacts/recovery-20261019/reader-serialized-*`。
- Shared目录数据前置恢复检查点：`a5a633dd` 归回原381的配置拷贝helper及548的目录接口（原字节精确），未改页面/路由/默认/构建依赖。原548具名目录/拷贝Host场景在实际index输入通过，其余Adapter/Index/UI检查未复跑；无I/O/新包/设备结论。全部其他tracked工作字节保留。Shared消费者及后继请求身份/失败字段仍OPEN，不能把本前置当成完整接入。证据：`.hermes-artifacts/recovery-20261019/shared-catalog-prerequisite-*`。
- 书架偏好所有者与消费者恢复检查点：`cdb3fb22` 归回原c971共同字段提交Store、两页消费者，并接原557分类保存→Index→当前分类消费者及c68首次同步读。Store与原c971精确；现存所有未暂存编辑内容及其他tracked工作字节保持。原字段owner和分类方法Host通过；实际index Store/首次方法证明9字段先于投影，读失败保现状回原异步恢复。仅受控内存Preferences，无新ArkTS/设备/Monitor派发结论；不带原新增失败toast、不改Builder/文案/几何。完整c971便携备份/runtime及Shared、清理仍OPEN。证据：`.hermes-artifacts/recovery-20261019/library-filter-*`。
- Nami简繁011恢复检查点：源主仓`e6bff87d` 归回两套各7生产文件及三处独立注册；原源码/许可证/metadata/011透明PNG保持，只限定纠正4份陈旧README/NOTICE。Root实读完整简体源码、繁体完整身份/语言差异及原010/011绑定；旧tmp出处别名缺失，Root归档官网HTML的唯一内联SVG与原SVG逐字节精确。当前SDK8506锁定离线构建及无网络info通过，两WASM与原011设备绑定逐字节相同。无新包/设备/HTTP结论；Hans搜索失败、Hant未验分页等原边界保留；旧radius观察不覆盖当前禁止遮罩，图标整线仍OPEN。其余tracked/SDK/原dist保持，owner的ignored/历史/证据未处置不得清理。证据：`.hermes-artifacts/recovery-20261019/namicomi011-*`。
- SOC010恢复检查点：源主仓`6808670a` 归回原4生产文件及三处注册，原字节全匹配，其他tracked保持；首屏10篇有限公开契约保留。当前SDK8506锁定离线WASM构建与无网络source_info通过，无新包/HTTP/Native结论。原Root及命名Native回执分别保留；owner历史、ignored及外部原证据去向未闭环，不得清理。证据：`.hermes-artifacts/recovery-20261019/soc010-*`。
- 三个原具名源恢复检查点：源主仓`5f059021` 归回Protectors textR2、科技大觀園010、天氣家族010各4原生产文件及各自注册；与原frozen绑定逐字节相同，其他tracked及dist保持。复用原完整Root审查和具名Native回执，当前仅重新核SDK解码前HTTP边界、注册、原字节及离线编译/info兼容；不冒新全源码/HTTP/Native结论。首次info参数错误原日志保留，读真实CLI后位置参数通过，未改源代码迎合。科技16px favicon及天文台横标当前质量仍OPEN；目录/refs去向分别核。证据：`.hermes-artifacts/recovery-20261019/three-official-providers-*`。
- 已实际清理一份核清工作树：`/private/tmp/Koma-sources-soc-zh-20261015` 删除前由Root重核4未跟踪文件与主仓6808670不可变blob/当前字节和模式全同，3注册WIP patch原件已留主仓审计，ignored为0、detached HEAD为主仓祖先、外部4份原回执/绑定/完整diff仍在。通过`git worktree remove --force`仅移除此checkout；前后全部refs、主仓HEAD和工作状态精确保持。其他目录/分支继续逐项核，不扩大为清理完成。证据：`.hermes-artifacts/recovery-20261019/soc010-cleanup-*`。
- Reader缓存目录消费者恢复检查点：`524c5cdf` 仅归回c20d及原cache-owner方案已有的两行，Legacy/Shared配置参数重新读取cacheDir，下载根及UI不动；当前文件/符号历史和原proposal已对应，其他tracked/WIP保持。仅原两行对应及字节核对，无新构建/Native/缓存迁移结论。完整缓存策略/备份runtime前置及Shared整体仍OPEN。证据：`.hermes-artifacts/recovery-20261019/reader-cache-consumers-*`。
- 又实际清理3份已归并旧目录：Protectors textR2通过Git工作树入口移除；HKO/科技各自独立clone在26件本地Git元数据逐文件归档重核后移除。删除前12生产文件与主仓5f05902不可变blob/模式全同，三份注册patch已留主仓审计，ignored0、所有owner对象在主仓可读、各ref tip有现存主仓ref包含；原验收在目录外继续保留。前后主仓refs/HEAD/工作状态保持，累计本轮4份旧checkout已清理，其余目录/分支仍OPEN。证据：`.hermes-artifacts/recovery-20261019/three-official-providers-cleanup-*`及两份`*-removed-clone-git-metadata.tar.gz`。
- 四源保留成果恢复检查点：`d0422d56` 将Cartoon18-zh、SimplyHentai-zh、WEBTOON繁中及TIPO metadataR2共28份原provider文件和3处注册归回源主仓，原绑定/权限全核且其余tracked与dist原字节保持。当前SDK8506离线锁定WASM和无网络source_info通过。Cartoon18内容未验收、Simply有限元数据、WEBTOON012图标/安装及TIPO403原失败分别保留，不冒当前内容/HTTP/打包/设备通过；图标质量及逐目录清理仍OPEN。证据：`.hermes-artifacts/recovery-20261019/four-retained-providers-*`。
- 缓存策略主链恢复检查点：`6398d2fe` 找回原13162538四文件139增31删；RemoteImageCacheStore与原提交精确，Entry仅在备份启动恢复后、普通消费者前接原await，原窗口/语言/主题代码保持，Settings全部原未暂存编辑精确保留。实际暂存完整Adapter/Store/BackupRestoreActivity复跑原Host场景，启动/设置消费者方法另核通过；平台IO/HTTP/TaskPool为mock，无新目录/包/Native。原Shared首次miss失败边界保留，c971便携设置runtime reload仍待恢复；其余App/Kit/目录分支审计OPEN。证据：`.hermes-artifacts/recovery-20261019/cache-policy-*`。
- 便携设置及原语言/强调色消费者恢复检查点：`9ca13368` 归回c971剩余备份白名单/预览/写入/回滚v2兼容v1/runtime及Index/Settings消费者，接原2e644语言、fa575强调色与90769下载队列必要前置，12文件340增121删。8份文件与原blob精确，Index/Settings原WIP逐编辑精确保留。原完整备份、平台语言、提交顺序、强调色Host在实际index输入通过；Entry/Settings/Index实际方法直接调用通过，平台/IO/Monitor为mock，无新目录/ArkTS包/设备。原菜单/文案/几何/调色板保持，原具名Native只绑定原HAP；Shared/其他App与Kit恢复、源共同交付及清理仍OPEN。证据：`.hermes-artifacts/recovery-20261019/portable-settings-*`。
- 四源检查点后续实际清理：Cartoon18及Simply Hentai两managed工作树、TIPO metadataR2独立clone已移除；28生产原文件先前归回d042，全部tracked逐字节排除隐藏差异，3注册WIP原patch另存，全部untracked在原归档或主仓精确，115件ignored和38件本地Git元数据已逐member保全核同。两条Cartoon/Simply冗余分支删除前确认tip仍被其他15条原ref精确保留；其他refs及主仓HEAD/工作状态保持。累计本轮7份旧checkout已清理，分支/其他目录仍OPEN；Nami及繁中WEBTOON共同交付缺口未核毕，不提前删除。证据：`.hermes-artifacts/recovery-20261019/three-retained-providers-cleanup-*`及三源`*-removed-*tar.gz`。
- 下载队列原消费者补齐检查点：`278a28c4` 原90769两方法patch精确归回DownloadsPage，与前述队列所有者配套；实际方法Host核读失败保两份旧投影、提交失败不发布成功、成功路径保持。Builder/布局/水合/移除所有权不变，无新包/Native，不能外推整个下载流程通过。证据：`.hermes-artifacts/recovery-20261019/download-queue-consumer-*`。
- 源共同交付恢复检查点：`272ed986` 归回许可证侧车/delivery ZIP、最终.koma摘要及release消费者，两文件62增9删。原a381与原checksum生产函数证据逐项对应；必要当前适配为NOTICE.md与六处副作用失败显式返回。保已采用快看014的1MiB普通布局，仅CManhua保原256KiB预算，不新增源注册；当前metadata helper、图标、SDK、.koma成员不变。Root实际暂存块核7侧车场景/2分组管道场景及原冻结实体摘要；仅shell mock/真实hash，不冒完整standard重打包/新WASM/Native。Nami和繁中WEBTOON继续先做逐对象保全/当前refs复核后再清理；整体恢复OPEN。证据：`.hermes-artifacts/recovery-20261019/source-common-delivery-*`。
- 逐项取舍：雀魂被拒 r0 不恢复；老夫子诊断011不能取代原记录要求恢复的010。源 worker 还在核其余变体，Root 尚未亲审并恢复的条目不计入已找回成果。
- App 三方预览21文件/52冲突块已定位；设置页、源管理页、首页与其余代码冲突已读，仍需把原决定、后继实现与消费者逐项对应后才写入。Kit49个现存 WIP 文件的字节级比较只提供线索，冲突/新增文字/缺文件不自动等于有效遗漏。另实查到 f769 的两条删除（ReaderPositionHandoff 及对应测试），已补入核查；原 HEAD 字节可恢复，未删除任何原材料。四个现存 Kit GitDB 的逐文件原始 blob 历史已查，18个现存文件能定位精确原提交，其余仍按行为/拒绝记录审，不能按文件数结案。报告：`all-existing-wip-textual-inclusion-20261019.json`。
- 实时目录范围：git根51个、tmp根82个 `Koma-sources-*` 目录，共133个，du分配块约16.62GiB；tmp根名称含Koma的1144个目录还包括验证产物，不当作源码副本数。数量与占用是定位信息，不是恢复完成依据。
- 构建依赖纠正：原主仓当前 `entry/oh-package.json5` 与 `build-profile.json5` 仍读取同级 `/Users/honjow/git/reader-kit`（存在、干净、bd392c0）；embedded `third_party/reader-kit` gitlink99f504a 只在后续生产分支。此前交接把缺 embedded 路径当作主仓缺构建依赖的判断撤回；没有据此新建/复制 Kit。先核既有依赖迁移原决定，再恢复最终依赖关系。
- Nami双语及繁中WEBTOON实际清理：2026-10-19 Root对三份owner全部tracked/untracked/ignored逐SHA/字节/模式及集合再核，保全1,652件ignored和18件Git admin，另将原WIP patch与untracked归档复制至主仓恢复区逐member核同。三目录及其三条冗余分支已移除，删除时每条tip仍有其他精确ref保留，源主仓272ed98/clean和其余refs保持。只关闭这三对象；其他目录/分支仍OPEN。证据：`.hermes-artifacts/recovery-20261019/nami-webtoon-root-preservation-result.json`、`nami-webtoon-root-cleanup-result.json`。
- 文件夹授权/冷封面恢复检查点：`a9876860` 将7f8ad4e6原三文件64增10删精确归回；四份原源码与FOLDER-001原回执hash核同。主仓Index已有恢复调用与完成日志保留；LocalImportCoordinator重扫WIP另存保全，工作区补回原授权失败阻止导入分支。真实暂存模块Host证明persist/activate先于scan、已有授权激活、拒绝/unsupported不扫描、FileUri系统路径及恢复promise等待，平台IO/扫描模型mock，无当前ArkTS构建或Native/cold新验收。首轮Host桩缺括号失败保留，产品未迎合桩。证据：`.hermes-artifacts/recovery-20261019/folder-access-recovery-*`。
- Pixiv018旧工作树实际清理：七生产文件对主仓272ed98精确，144 tracked逐原blob、0 untracked、307 ignored及7件私有Git admin逐文件/逐tar member核同后，`/Users/honjow/git/Koma-sources-pixiv-zh-20261012` 已移除。唯一历史分支`codex/pixiv-zh-source-20261012`继续保留，不能当冗余ref删；主仓和全部refs保持。证据：`.hermes-artifacts/recovery-20261019/pixiv018-root-cleanup-result.json`。
- 本轮继续归并与清理：源主仓`c719824`找回Guazi localizedNames schema和最终archive摘要文档，当前extractor事实适配保留空map/忽略未知字段，不恢复旧strict helper。Root全量核139 tracked原字节/4 untracked/2,960 ignored/7 Git admin保全后已清理Guazi目录及冗余ref。XComic繁中/MangaBall两目录及两冗余refs也已实际清理，十四生产文件仍在主仓；错误初稿借用3hentai owner已明确INVALID，3hentai未动。证据：`guazi-root-cleanup-result.json`、`xcomic-mangaball-root-cleanup-result.json`（均在恢复区）。
- 筛选偏好恢复检查点：App`6cc3d2cc`归回340e4c5d/fe3d3999三文件原完整性链42增32删：实际最终Store、remove前export可读性校验、四处保存后发布消费者。真实暂存Store/共同writer的20坏读取/损坏路径、202字值/他源保持/partial-write与四实际AST消费者失败不发布Host通过，内存IO/mock依赖；Registry守卫只源码审查，无当前ArkTS/Native。其余async registry/界面WIP不混入。证据：`filter-integrity-recovery-*`。

本次审计材料与原始证据均继续保留。源码恢复、提交、编译、原验收和当前构建验收分别记录；未核清的不入交付构建，不以目录盘点或本节更新结束任务。

- 私库目录/封面恢复检查点：`d0380f93` 归回082c完整Komga请求/跨页目录及三个消费点、614f OPDS publication MIME/self身份/readingOrder与同作品异步提交；clients全原字节、页面限定方法精确，保已接受外边距，历史链另组。`0b415efd` 归回d3d3 Kavita封面endpoint/revision与详情→Header→CachedCoverImage参数。实际暂存模块/方法Host验证103本跨页/去重/无进展拒绝、正文不混封面/过期作品不覆盖、鉴权封面与revision/外域不带凭据；主仓无关WIP原工作字节保持。首次来源断言错误把整页/含blobID的WIP patch当等价，原失败保留后按真实方法与完整工作SHA纠正，产品未为断言改动。无当前ArkTS构建或Native验收；私库历史、请求owner、完整Shared及其余目录/分支仍OPEN。证据：`.hermes-artifacts/recovery-20261019/private-catalog-recovery-*`、`kavita-cover-recovery-*`。

- 源导入目录所有者恢复检查点：`58020e72` 仅归回71cad两处原差异，picker已建目录交给共用注册，bytes入口保持自建；原六场景在实际暂存三函数上通过，文件系统改用内存适配，没有新建临时测试目录。首次适配变量重名为审计脚本语法错误，保留原失败并只修脚本。未扫删旧孤儿目录，无当前构建/Native；素材身份合同与其余恢复继续OPEN。证据：`.hermes-artifacts/recovery-20261019/source-staging-recovery-*`。

- 五个已归并Dota/蓝档残留目录已实际清理：100现存文件与全部Git admin逐成员归档复核，最终源码与原56/52保全件/主仓全字节一致；缺.git指针使普通Git移除拒绝，保留原错误后仅按精确路径移除五个residue/admin；两条bluearchive冗余ref的tip为主仓祖先，删除后主仓与其他refs精确不变。没有宽泛prune。首次保全符号HEAD核对错误只影响审计，三份先成归档已重验且未覆盖。证据：`.hermes-artifacts/recovery-20261019/dota-bluearchive-residual-root-*`。
- MangaDex简繁恢复检查点：源主仓`3d8cf49c` 归回各七原生产文件与各三处注册，两个稳定ID独立于英文源；原native040/native041回执不扩展为当前通过。当前SDK8506离线锁定构建与无网络source_info均通过，原180px官方PWA图f1b6671a精确保留，不称高清/视觉通过，未引旧打包helper、dist或旧SDK。首次注册准备误用build.sh标记而中止，按实际SOURCE_ENTRIES续完，全部其他tracked字节与共享原数据保持。原owner继续保留，其它provider与shared材料未核清不得删。证据：`.hermes-artifacts/recovery-20261019/mangadex-zh-pair-*`。
- 清理资格纠正：源worker发现包子/MangaBZ旧owner继承HEAD还含主仓缺失的CManhua；先前仅核WIP的“可直接清理”结论撤回，两owner继续HOLD，须归并完整012或有原证据说明处置后再清理。不能把Git refs可读当有效功能已归并。当前已交23provider闭包并不等于已应用；Root下一项为核清CManhua012原有效成果/资产后继并归并，App素材身份合同及Shared完整组仍由Root接续。

- 源身份素材合同恢复检查点：`4d150adc` 归回6b461174原五文件完整Importer→Index→Registry→AppRegistry备份/prepare/reload合同及LocalizedNames，保原PNG/JPEG/GIF/WebP/ICO编码与原bytes，不改素材/遮罩/几何；非PNG备份带版本化文件名，旧PNG备份兼容。实际index与工作文件字节全同，原metadata消费者检查和十项实际Importer/备份icon检查通过，内存ZIP/文件+Pillow完整解码无新增临时测试目录。历史GIF夹具路径缺失在导入执行前失败，保原失败后改读主仓官方GIF原件。无新ArkTS/ImageKit/六格式Native/物理备份恢复结论；显示名称叶子与全部图标质量仍OPEN。证据：`.hermes-artifacts/recovery-20261019/source-assets-recovery-*`。

- CManhua012恢复检查点：源主仓`5ef90a7b` 归回a77fdcc六个原生产文件与三处自有注册，runtime012/Cargo010按原件，217px620a透明外边裁切的原人工批准已由Root亲读原user消息行53662（10/12），没有新裁图/绘图/遮罩；10/18点名创漫在后，不能把它冒称晚于纠正的批准，也不能在未核ID时混为同源拒绝。当前SDK8506按主仓现存CManhua专用256KiB构建profile离线锁定编译及无网络info通过，其余tracked/共享原数据保持；原回执仅更新/版本/图标/cold，不扩展正文通过，当前SDK直接decoder错误分类保留不冒等价。待删owner仍须全部内容/ignored/admin前置，不因本组提交自动清理。另纠正此前WEBTOON繁中/Pixiv/Guazi已删owner继承HEAD覆盖登记：CManhua已在本提交归并，WEBTOON繁中的MyComic仍在既有23候选中未归并，原提交/保全归档可恢复，不把“已保全”说成“已集成”。Root接续MyComic原有效业务/资产处置及剩余队列；App素材合同已归并，其他Shared/文档/分支仍OPEN。证据：`.hermes-artifacts/recovery-20261019/cmanhua012-*`与原source-worker清理纠正附件。

- MyComic011业务成果恢复检查点：源主仓`fcea766a` 归回四个原文件与workspace/本crate lock，保全为诊断候选；可信图标确实缺件，现build.sh默认会先验图标，故不加入打包registry、不造图、不接旧临时工具。实际当前SDK8506离线锁定标准WASM构建和无网络info通过，全部其余tracked/共享数据保持。原011诊断最终回执已找到，纠正旧表仅引010失败：它只接受普通更新/实体/cold与HTTP403错误分类，绝无内容可用接受；受拒请求未重试。原候选多余EOF空行使diff-check失败，保原patch后只去空行；无新包/Native/内容结论。此前已删owner已知继承缺件CManhua/MyComic已分别归回主仓；这不替代其余23队列/资产/目录/refs逐项审计。证据：`.hermes-artifacts/recovery-20261019/mycomic011-*`。

- Kavita服务搜索恢复检查点：`d2943a1b` 归回ebb原四生产文件及原Host检查，服务搜索候选→按ID水合真实可访问series→结果server身份→SearchPage鉴权封面消费闭合，client/model/test与原提交全字节精确，页面几何保持。原实际Client/section检查覆盖跨库结果/身份、空/删除/401/403/坏JSON、query编码与原浏览请求，当前Host通过。无新构建/Native；全服务结果遍历4d、历史/异步guards及其余恢复仍OPEN。证据：`.hermes-artifacts/recovery-20261019/kavita-search-recovery-*`。

- 源非lib遗漏补回：`ec7b879d` 恢复Kuaikan原a381 Apache LICENSE与NOTICE，原NOTICE无图标陈述已过时，仅按主仓现有官方128px b963素材事实改成引用ASSET_SOURCES，原NOTICE/License字节另保。现build.sh许可sidecar消费者可纳入两件，无代码/素材/包变更，无需把纯文档恢复冒编译/Native。此问题表明23个缺lib清单不能充当全部成果范围；源worker正逐路径核全部已知tip/原保全中的非lib与root shared遗漏，两旧owner继续HOLD。证据：`.hermes-artifacts/recovery-20261019/kuaikan-license-*`。

- 源设置/索引/移除事务恢复检查点：`716f0639` 精确整合8bd完整设置读取/计数/草稿保护、d719按filesDir串行与两键presence/value回滚及备份同读Owner、53f先提交设置/filter/registry再发布runtime移除与enable失败回滚。五文件目标SHA与原分段候选一致，Manager全部Builder尾段/完整URL/源详情sheet及所有无关tracked工作字节精确保留，picker/素材合同未回退。实际当前五文件复跑原28设置故障、页面恢复、8最终生命周期、8索引偏好、4页面/备份消费者检查均通过，内存文件/Prefs无新增测试目录。没有套用被53f取代的旧8bd“先移runtime”断言。无新ArkTS/Native/进程死亡/二次回滚I/O故障或完整备份保证；f01异步/revision、Shared/历史及剩余源/分支仍OPEN。证据：`.hermes-artifacts/recovery-20261019/source-state-transactions-*`。

- 源许可/归属恢复检查点：`859d8d8e` 恢复漫画1234原Apache LICENSE-APACHE-2.0与代码合同NOTICE首段，原含62d00b22已拒图的后段只保审计不回灌；恢复WEBTOON原dcba NOTICE代码参考/Apache说明，仅把陈旧“无身份画面”改为引用现有ASSET；该ASSET中“App圆角裁切”陈述按有效禁止遮罩要求改为不得加mask，实际图像bytes/代码未改。完整原文与精确差异保留，无新构建/包/Native主张。源全tip非lib/后继审计仍OPEN，不能因这些sidecar补齐称所有成果清完。证据：`.hermes-artifacts/recovery-20261019/source-license-sidecars-*`。

- 包子/MangaBZ旧owner实际清理检查点：两处原checkout和对应worktree admin已通过Git入口移除；删除前Root再次核7154个归档member、完整WIP、94继承源文件/27provider去向及其他ref保留tip。主源仓859d8d8、工作字节和全部refs精确保持。完整owner/admin归档和原patch留主仓审计；未把tip称为master祖先，其他未核目录/分支继续OPEN。证据：`.hermes-artifacts/recovery-20261019/baozi-mangabz-cleanup-result.json`。
- 源管理异步组恢复检查点：`c43cf027`接回f01原四文件及全部Manager消费者，RuntimeService与原提交全字节一致，保716设置事务与0d当前弹层。Manager完整Builder尾段和其他tracked工作字节精确保留；原七项runtime/Manager检查在实际暂存blob以内存适配器通过，只证明admission兼容、异步让出/字节快照及过期回调拒绝。无新ArkTS包/设备/WAMR争用结论；3b revision/cache及失败提示尚未应用，原文案授权追溯继续，不能把归档/提交存在当作批准。证据：`.hermes-artifacts/recovery-20261019/source-async-*`。

- 两官方繁中源恢复检查点：源主仓`e3eacfd6`将菇菇640行/老夫子754行原完整010实现、README和两官方原PNG及各三接线归回，八源文件与原tar精确。Root实读完整源码/原Root回执/原有限Native边界并看原PNG；不恢复老夫子011诊断，不掩盖菇菇黑底题图FAIL，不声称图标高清或当前小槽通过。当前SDK8506离线锁定WASM及无网络info通过；工具路径启动失败与info信封检查字段错误均保留且未改源迎合。无新包/HTTP/设备；根LICENSE不存在不能称许可已齐。其余tracked精确保留。证据：`.hermes-artifacts/recovery-20261019/official-pair-*`。
- 全量搜索恢复检查点：App主仓`405b0e2d`接回4d62原三文件组及当前Library消费者；全部Search Builder/当前Kavita消费者和其他tracked工作字节保持，未夹带OPDS页数/历史后继。原四组检查直接运行实际暂存blob，通过Komga25/两页、OPDS30/两feed/循环失败、WebDAV21目录/深层/子失败保结果/超时及取消不续请求、本地31完整结果、页面旧回调/同查询刷新所有权。平台网络/计时器为受控适配，无新包/Native/全provider验收。证据：`.hermes-artifacts/recovery-20261019/search-traversal-*`。

- 源设置数据有效性恢复检查点：`81ba028a`仅归回3b原Store/revision、Cache/entry与revision/可选URL、Detail全部回调及两处cache写入消费者。working/index分别应用，原Detail八块WIP编辑签名、完整Builder、Manager与三资源全字节保留。实际暂存源码复跑原Store/Cache/Detail数据断言通过，内存fs无新目录；失败提交不推进revision/不丢旧cache、成功提交和同版本entry替换拒旧回调。没有执行Manager新Toast断言，原可见批准仍未知，不能称整个3b或其UI错误处理通过；无新包/设备。证据：`.hermes-artifacts/recovery-20261019/source-validity-*`。

- 已批准OPDS页数修正恢复检查点：`1c530163`接回a6原三文件10增2删；依据当前可见call_62e9e851明确“实施这份修正”，只改声明numberOfPages、未知OPDS、作者优先。原真实20条响应在实际HEAD/暂存输入复跑通过，其他全部结果字段精确，4d全遍历保持；没有启动服务/设备，原Native不扩成当前通过。证据：`.hermes-artifacts/recovery-20261019/opds-declared-count-*`。
- 包子/MangaBZ两条旧分支别名实际清理：已先移除并保全核清的两个owner所指codex/baozimh-source-20261010、codex/mangabz-source-20261010均为a381相同tip。删除前仍有16条其他ref保留完整祖先历史，按expected SHA compare-delete后其他refs/源主仓e3eacfd和clean精确保持，原ref映射及归档不删。此项只关闭两个别名，不扩大为全分支清完。证据：`.hermes-artifacts/recovery-20261019/baozi-mangabz-redundant-ref-cleanup.json`。

- Shared Adapter目录业务恢复检查点：`63e15b49`仅归回原381五hunk与548两hunk；Host Catalog实际prepare→身份/页数/URI数校验→原maps安装→clone查询全分支接回，原二参Lab调用继续，524 cacheDir保持。原Reader/CatalogHost类与实际暂存Adapter复跑五类内存Host通过，全部其他tracked/WIP字节保留；没有改UI、Reader默认/普通路由或三语文案。无新包/设备/权限/真实IO保证，完整Shared消费者/Kit后继及旧8组rollback/handoff仍OPEN。证据：`.hermes-artifacts/recovery-20261019/shared-adapter-catalog-*`。

- 章节页计划发布恢复检查点：`f71bf89b`归回c9a原两文件40增17删；只在当前comic/chapter身份与原页计划仍有效时提交脱离副本，保新元数据/移除/重导入/较新计划，落盘失败不先改活数据。working/index分开保原Exact-ID描述符WIP全部编辑字节，旧错误结果/其他tracked保持。实际暂存完整模型/Store/持久化helper及Hydrator方法的原七场景通过；只源请求Promise为mock，无真实IO/新包/设备或721错误文案接受。证据：`.hermes-artifacts/recovery-20261019/chapter-hydration-owner-*`。

- 完整章节目录请求恢复检查点：`f626fdd0`接回942原resolver/LibraryUpdate完整fetch与元数据职责，两文件59增157删，去重复20页截断/自造cursor。3b已提供revision，原页游标/缺失重复失败/取消/URL及未知语言和序列所有权保持；working Exact-ID原export、请求chapterId和命中早退字节保留，仅公共wrapper按必要新URL/current参数转发，适配已明录。暂存与工作两真实输入分别复跑原resolver全组通过，原language/metadata检查通过。LibraryUpdateCommit/publication和新skip文案未带，checkLibraryUpdates原方法保持，不能称整个942或更新发布事务通过；无新包/设备。证据：`.hermes-artifacts/recovery-20261019/chapter-catalog-owner-*`。
- Root 当前未验证动作：App主仓`f626fdd0`、源主仓`e3eacfd`。Root亲审Kit已交的Index/Lab原381/548目录消费者完整业务组（保Legacy/Debug gate/default与Index原WIP），其后接811完整URL/封面身份和efdb/e954必要前置。源worker继续nonlib/no-pack有效成果，原未批准Toast/skip/937默认/thumbnail可见差异仍HOLD；产品新增和设备继续暂缓。

- Shared目录App消费者恢复检查点：`0a0eeafb` 归回原381/548的Index目录prepare/commit及Lab有效观察消费者，两文件88增29删。Root逐原13hunk核对，index/working分别应用，Index原19组WIP逐编辑精确保留；Debug gate、普通路由、默认及布局不变。原548四项Host和实际index/working六组方法检查通过，平台/IO/provider为mock，无新ArkTS包/Native。后继721真实失败/重试、efdb请求身份及Shared完整入口继续OPEN，不能把本组当普通Shared完成。证据：`.hermes-artifacts/recovery-20261019/shared-catalog-consumers-*`。

- 三个作者部落格业务恢复检查点：源主仓`e38bb7df` 将輔大猴、我是馬克、綜合口味各3份原文件归回，并仅接各自workspace/lock。9生产文件与原owner、frozen完整diff及原Root归档逐字节/模式相同；原完整绑定source/evidence/artifact映射重核。当前SDK8506离线锁定WASM与无网络source_info通过，WASM均与旧产物不同，不冒正文/Native等价。现打包集合、SDK及原dist保持，缺图标/标准包交付仍OPEN，未接旧无icon打包方式。原README历史字节保留，当前边界以此为准；准备阶段归档平铺路径误判、info核验器信封字段错误保留，均未改产品迎合。其余源与所有owner清理资格分别核。证据：`.hermes-artifacts/recovery-20261019/three-blog-business-*`。

- Legacy失败/真实重试恢复检查点：`670f66bb` 归回原721七文件60增18删，结构化unsupported分类→route-local config→原失败位置限定文字，并接真实章节请求、同失败config去重/新失败可再试、普通点击页reload及假页不写进度。两项当前可见原人类批准、原提交与精确diff已核，按钮/尺寸/布局保持；Hydrator2/Index19/资源各8组原WIP逐编辑精确保留。实际index/working Host分类/失败不发布Library/Legacy重试/进度及真实RenderFactory+文案表达式通过（placeholder实际kind=local_file_image），IO/taskpool为mock。无新ArkTS包/Native；Shared的bd9/088/c670/9d0/99f配套、首次失败pending及同章history后继仍OPEN，不能称整个721恢复。证据：`.hermes-artifacts/recovery-20261019/legacy-source-failure-*`。

- 三个已归并作者源owner实际清理：輔大猴、我是馬克、綜合口味三个独立clone已精确移除。删除前各1457个完整归档member（含全部.git）逐项核字节/模式/类型、原9生产文件与主仓精确、各977个Git对象在主仓可读及16个ref tip保留关系均重核；原9行注册WIP另存，缺图标buildrow继续保留为待处理原件而不部署。外置原Host/Native证据保持，主仓全部tracked/HEAD/refs/clean状态不变；其余目录和分支审计继续OPEN。证据：`.hermes-artifacts/recovery-20261019/three-blog-owner-cleanup-result.json`和三份`*-complete-preservation-e38bb7df-20261019.tar.gz`。

- 私库端点/凭据Owner恢复检查点：`d460b3ca` 接原9f端点摘要身份/进度同步guard、d7合法Asset声明及b1四协议配置/凭据串行提交与备份同读消费者，5文件。Store与b1、Sync与9f原blob精确；备份预校验/便携设置/恢复后继及其余tracked/WIP字节保留，界面未改。原四协议实际完整类Host覆盖保存/clear失败回滚、Asset/Prefs逐步失败、读/export等待提交、legacy迁移与二次回滚失败，通过；仅内存端口，无新Native/真实凭据故障/进程死亡原子性。原raw URL身份表被拒不恢复；图片same-server guard及完整URL/图像消费者是下一依赖组，不能提前称全端点隔离恢复。证据：`.hermes-artifacts/recovery-20261019/remote-endpoint-owner-*`。

- 图像请求身份/作品URL消费者完整恢复检查点：`980cc8a4` 归回efdb十六消费者、e954完整Cache后继、548两History身份方法/ForEach和811十消费者，合计24文件343增219删；ReaderAdapter与efdb、Cache与e954原blob精确。全部WIP逐编辑保持，已批准721失败/重试及页面布局/默认/按钮保持。实际index原context私库并发/公开及CDN不带凭据/错server拒绝、5真实源GET描述符15次受控transport/非法required拒绝、811完整投影/下载→详情URL/失败身份、548两Host通过；原coalescing及e954四写入场景以Map文件端口通过，短写不发布/旧图保留/失败可重试。首次旧fixture缺路径改读既存归档原输入，内存端口跨VM数组错误保留并仅修端口，未改产品或断言。无新ArkTS/Native；fd741章节页请求URL消费者、Shared完整失败/初次请求及其他分支/目录仍OPEN。证据：`.hermes-artifacts/recovery-20261019/request-url-consumers-*`。

- 菇菇/老夫子残留实际清理：两owner各20现存文件及各6 Git admin已逐SHA/模式/成员完整归档重核后移除，Git因缺.git拒绝的原错误保留，仅清理报告绑定的两组精确路径；Namepara冗余ref删除前确认tip为主仓祖先且无独有提交，其他refs/HEAD/工作字节全同。证据：`.hermes-artifacts/recovery-20261019/official-pair-residue-cleanup-result.json`及四份residual/admin归档。
- 三个无可信图标源的原业务检查点：源主仓`e877eed8`人2、`5b8afada`医院也疯狂011、`e75feb7d`HentaiHand，13原生产文件（3/3/7）与原冻结绑定逐字节/模式一致；每组仅增加workspace与自有lock，保持当前SDK8506、打包registry、dist和其他tracked。当前离线锁定WASM及无网络source_info分别通过；原Root完整审查/有限Native边界保留，不称本轮新HTTP/包/设备通过。三份原业务README照原保全，旧阶段描述不覆盖后来的有限证据；缺可信图标不造图，也不把源码归并冒称可发布。原多余lock EOF空行未带入，原patch保留。owner全部内容/历史/ignored与refs仍须逐项核清后清理；其余恢复OPEN。证据：`.hermes-artifacts/recovery-20261019/{people2-marked-zh-hant,laya-zh-hant,hentaihand-zh}-business-recovery-*`。

- 章节URL原消费者恢复检查点：App`e694d2c7`归回fd741三文件16增1删，全部新增hunk与原blob精确，现存Index/Detail/Hydrator WIP逐编辑保留。原完整Host在实际暂存输入先遇审计VM缺global、旧fixture未设置当前Index打开状态，两失败原样保留；补标准global/真实打开状态后初章目录/页URL及history断言通过，整套仍在3!==2同章snapshot复用失败。该短路属于原0887488f及721placeholder保护的未恢复Shared后继，不能删断言/单补短路冒通过；后续Shared闭包归回后须原套复跑。source://旧locator过滤及Exact-ID URL边界原来未覆盖仍OPEN，无新ArkTS/Native。证据：`.hermes-artifacts/recovery-20261019/chapter-page-context-*`。
- 搜索历史完整Owner恢复检查点：App`c4e75bf0`归回998两文件81增35删，Store同filesDir串行/坏数据拒写/键存在性和值回滚与Page当前route失败重读完整配套，全部现Builder和其他WIP保持。原21 Store/Page场景在实际暂存代码、内存Preferences上通过；不新建测试目录，原断言不变，仅候选读取映射到真实index及当前before Builder。无新ArkTS/Native；Shared/剩余App与Kit/源/目录分支仍OPEN。证据：`.hermes-artifacts/recovery-20261019/search-history-owner-*`。

- 再实际清理六个已核owner：MH1234/CManhua两工作树、People2独立clone、Laya010/011两clone、HentaiHand工作树，所有tracked/untracked/ignored及实际Git admin完整归档并逐member SHA/模式/类型/集合重核。三clone全部原对象与ref tip仍在主仓；只删除MH1234无独有提交ref，CManhua/HentaiHand独有refs保留待单独历史审计。主源仓e75feb7d/clean与其他refs/字节保持，外部原验收材料未删。证据：`mh1234-cmanhua-owner-cleanup-result.json`、`people2-laya-hentaihand-owner-cleanup-result.json`及各完整归档（恢复区）。
- 进度提交与启动同步恢复检查点：App`8afb9c01`接回原68a完整pending/迁移/reload/布尔flush及3a私库bootstrap真实消费者，2文件81增64删；原68a双方restoreSnapshot仅排除尚未恢复e22 remoteHistory，当前v3/URL/721字段及其他工作字节保持。原完整断言在实际暂存源码、Map文件端口上通过：短写/fsync/rename失败保原文档、pending普通重试、迁移失败可读与坏load/reload拒绝；before在失败flush后仍synced2/updated2，after保失败1、不标成功/cooldown，普通retry可提交。无新目录/包/Native/真实断电保证。Backup两boolean消费者由原14cd后继配套，其他显式事务/远端history及Shared仍OPEN。通用审计helper的逐hunk标签不适用于本组转换schema，已在after-stage更正为原blob核对及明确适配边界，不冒原全文件精确。证据：`.hermes-artifacts/recovery-20261019/reader-progress-commit-*`。

- 再三源完整业务恢复：源主仓`e7beab44`爱看漫/Ikmmh、`3ae9226d`喵趣、`cb69e883`HComic R5，共18生产文件逐候选SHA/模式核同；lib/Cargo/许可/metadata原字节保留，六README/NOTICE仅按当前事实限定适配且原文另存。Ikmmh错误DM5品牌、喵趣旧0444、HComic原白字/小鲨Native FAIL均未引图标，未加打包registry或旧候选工具；当前SDK8506离线锁定WASM及无网络info通过，非新HTTP/包/Native验收。原HComic R5独立Root业务继承/65输出已定位，不沿旧缺审查结论；喵趣有限原章Native不扩到封面/搜索。喵趣候选无EOF标记使后续diff头粘入README，逐文件SHA在提交前拦截；原patch与失败保留，查清后只恢复已绑定afterText精确字节并核六文件，未改业务或放宽断言。其余tracked/SDK/dist保持，三个owner全部闭包清理待核。证据：`.hermes-artifacts/recovery-20261019/{ikmmh-zh,miaoqu,hcomic-zh}-business-recovery-*`。

- 备份导出/预览数据恢复检查点：App`70fb0d0d`归回14cd除自动偏好rollback外的完整九原span：两flush拒绝门、plain/encrypted picker UTF8完整写+fsync、导出及备份/当前双侧库校验。全部当前其他方法/WIP保持。原报告把排除automatic方法后的坐标标为raw，Root在apply前逐原Git校验拦截，已保失败报告；修正只改来源坐标不改patch，再核九span原字节通过。两整套原file/library断言在实际暂存源码+Map端口通过，无新目录/ArkTS/Native/真实进程死亡保证；两个flush门源码已接，full-service自动owner仍待008/后继配套，不能称整14cd完成。另Root独立核68a纠正附件42对raw span及多段拼接hash通过，不用Host通过掩盖来源坐标错误。证据：`.hermes-artifacts/recovery-20261019/backup-export-admission-raw-*`、`backup-export-admission-first-provenance-mismatch.json`、`reader-progress-commit-raw-segment-recheck.json`。

- Ikmmh/喵趣/HComic三个owner实际清理：各全部204/272/522物理文件及对应6件admin均完整归档逐member核验，18个主仓生产文件仍精确；每个非主仓历史提交在其他原ref中仍保留，三checkout及三冗余ref已精确移除，其他refs/HEAD cb69e883/clean/工作字节保持。排除旧资产/strict helper/固定SDK候选脚本均保存在完整archive，外部原HTTP/Host/Native记录未删除。证据：`.hermes-artifacts/recovery-20261019/three-more-source-owner-cleanup-result.json`及六份完整owner/admin归档。其余provider/独有refs/App/Kit/文档恢复继续OPEN。

- 执行规则恢复检查点：App`405f0279`将原97bf两份合并规则归回主仓，原件/当前暂存SHA及完整patch均已亲核；仅适配真实sibling Kit链接、素材与App均禁遮罩、按当前有效授权分组提交/同步三处。其余tracked工作字节保持，未推送/发版/操作设备。3f完整备份偏好组因页面由保存成功后显示改为乐观显示、尚缺相应原人类许可继续HOLD，不拆Store充作完整恢复；Root转核Kit线性后继与其他完整数据组。证据：`.hermes-artifacts/recovery-20261019/execution-rules-*`及原3f追溯报告。

- 再三源原业务归并检查点：源主仓`bef42868` NHentai.to R4、`441d1284` NHentai.xxx、`bcfb9261`漫画160，16原生产文件的lib/Cargo/metadata/现有许可逐字节及模式核同；五份文档仅适配原具名有限证据与当前恢复边界，原文另存。当前SDK8506离线锁定WASM与无网络source_info分别通过，其他tracked/SDK/build registry/dist保持；无新HTTP/包/Native结论。旧96/32图标不随本组归回，漫画160缺源级LICENSE实物不补造。三个owner及其继承历史/ignored/admin清理仍待逐项核定，不把归并等同可删。证据：`.hermes-artifacts/recovery-20261019/{nhentaito-zh,nhentaixxx-zh,mh160}-business-recovery-*`。

- 原已批准章号/排序完整组恢复检查点：App`19ad9143`归回329/5ce/0c中四文件4增7删；Root亲读原rollout行17665/21469/22400，选定数值未知-1随升降、同号相等，同时停止用源序号冒充话号，不恢复最早无号恒末尾方案。原四hunk前后raw Git span及working/index SHA全核，详情页原WIP编辑签名与其余tracked字节保持；未带Tracker接口，不改Builder/菜单/尺寸。两套原完整Host在实际暂存输入通过（7/11/676真实章样本），内存结果端口无新测试目录；无当前ArkTS/Native/旧落盘章号迁移保证。Root继续Kit26后继与其余App/源/目录refs清理，3f/008可见时序及817缺前置仍OPEN。证据：`.hermes-artifacts/recovery-20261019/approved-chapter-sort-*`。

- NH.to/NH.xxx两个owner实际清理：两目录全部207/163物理文件及各6件Git admin完整归档，逐member SHA/模式/类型/集合与现场复核后精确移除，两冗余ref亦移除。继承的MangaDex简繁/MangaBall三提交各七生产文件和三处注册已与当前主仓原字节核同，三个旧固定SDK打包helper保在Git/完整归档，不混入当前构建；未归主仓的三原提交仍由其他原refs可达。当前主仓bcfb9261/clean/其他refs与tracked字节保持。证据：`nh-pair-owner-cleanup-result.json`及两组full/admin归档。漫画160所在Manhuagui owner尚有自身未核WIP，不随本组删除。

- Kit后继准入实查：Root已读26后继生产精确差异，原三文件29d几何/运动只是WIP检查点，不能冒Native通过。当前原Kit仍bd392c0/clean、App仍sibling依赖；Lab真实调用ReaderTrialWindow二参及两个无current回调方法，而99f后继要求四参/显式current，直接FF会接口不兼容。该组暂HOLD到原App窗口/entry完整消费者一起核回，不加伪闭包/省guard迎合；c670/937/58a原可见入口授权缺件边界继续保全。无Kit源码/refs/设备改动，其余已授权恢复继续。证据：`kit-successor-current-app-window-incompatibility.json`及原Kit各完整组报告。

- 再五源原业务归并：源主仓`1e4bfb1d` AsmHentai、`ac677aba` XCOMIC简中、`979384a7`幻塔、`aa1fda14`漫小肆、`300a3583` NNHanman R2，共27原业务/元数据/既有许可文件，原scope/Root绑定与源文件SHA模式全核；README只追加当前恢复边界，旧原文保全。当前SDK8506离线锁定WASM与无网络info分别通过，XCOMIC简中新WASM与原已接受d3981bf7全字节相同；其稳定ID独立于已恢复繁中，未按品牌名排除。图标、旧候选helper、dist、build registry与其他tracked保持，无新HTTP/包/Native。Asm/漫小肆/NN三owner全部201/204/227物理文件及各6件admin完整归档逐member核后已精确移除，三冗余refs亦移除；继承MD简繁/MangaBall生产闭包精确，其他refs保三原提交。证据：各`*-business-recovery-*`、`asm-mxs-nn-owner-cleanup-result.json`。

- 3Hentai业务恢复：源主仓`b2d67bde`归回六原文件；Root本轮逐段实读1034行Rust及固定Hentai3主实现，独立比对留存全部25条身份/标题/URL/封面顺序及236页描述符、13原输出hash。未找到原完整Root源码审查，不冒认历史通过；本轮仅源码/留存一致性审查。旧外部runner/readonly路径已不存在，owner中原始primary/HTML/输出仍在，未冒称重新生产回放。当前SDK离线WASM/info通过，无新HTTP/Native；原封面异目录信任边界及只首图HTML曾观察的限制保留。全部312物理文件/6admin归档逐member核后精确移除owner和冗余ref。证据：`3hentai-zh-business-recovery-*`、`3h-owner-cleanup-result.json`与原完整archive。

- HentaiFox剩余实查：Root已读完整原源码及与3H完全相同的共同JSON/容量helper；imgattr在每个可选属性直接调用SDK html_attr并map_err退出，而实际App html_host.cpp缺属性返回-1，SDK将其转Err，故首缺属性就无法执行既有回退。固定Keiyoushi HentaiFox/GalleryAdultsUtils源码已从公开GitHub取回并与原记录两SHA精确，原helper明确先hasAttr再读取；不是从记忆补造理由。当前无源站/图片/设备请求，缺原HTML/runner的新执行证据，未称已重现具名Native失败。原owner及全部WIP继续保留，先核兼容处理/真实消费者，不为消除目录而把候选当已通过归并。

- 原生具名源依赖恢复检查点：App`337ed329`归回915原34行时间/OS熵及69af原CMake xxd兼容两文件37增2删。当前源主仓Iqiyi真实extern仍需两导入；原10/12 proposed.diff新增34行逐行与Git后继全同，未带旧AppScope步进。App原主仓现有.cxx原生target实际编译/链接exit0，生成fixture头逐字节等于原WASM，实际.so含两Host函数及系统clock_gettime/getentropy导入；其余tracked模式/字节保持。原真实WAMR harness/012源WASM仍缺，不把旧日志或编译冒当前调用/Native通过。未新建源码/构建树、未产新HAP/签名/设备/权限或SDK变更；原版本、Kit/HFox及其他恢复继续OPEN。证据：`native-dependencies-*`。

- MangaDex简繁两个原owner实际清理：本轮重核两目录均无tracked WIP或untracked候选；其独有历史仅三项MangaDex简繁/MangaBall，全部生产文件和三处注册与主仓原字节一致，旧固定SDK打包helper保在原Git/完整归档。两目录全部245/217物理文件及各7件admin完整归档，逐member SHA/模式/类型/集合核验、所有ignored逐文件归类且无运行占用后，精确移除两checkout与两冗余ref。主仓b2d67bde/clean、其他refs和tracked字节保持。剩余目录/分支、App/Kit/文档及HentaiFox继续OPEN；未恢复产品或设备工作。证据：`md-pair-owner-cleanup-result.json`及两组full/admin归档。

- 分类快照原最终修复恢复检查点：App`a0bbe9a7`归回e12cb3d2单文件三hunk（两列表快照key及移动成功清已消费菜单状态），精确原diff与root-binding全部九输入/输出hash已独立核对，并亲看c69改名/c70上移/c72下移原图。保留主仓已恢复12vp边距及其余全部tracked/WIP；原失败Repeat/引用Builder和密度候选未应用。只有原具名e79 HAP/同进程改名排序重开有限证据，无当前构建或Native结论，不靠Host/UI正则冒视觉通过。源目录与App/Kit其余恢复仍OPEN。证据：`category-final-recovery-*`。

- 浏览可用性/版本原完整消费者恢复检查点：App`3038272b`归回350版本渲染身份及901激活/epoch两文件，原全部raw Git span独立核同，Browse与原最终源码除已接受边距外精确，Index原WIP逐编辑及其余tracked保持。原生产方法Host在真实index/working输入通过激活后重新读取、旧成功/失败不覆盖最新、离开后不发布、inactive不读及当前refresh错误保留，平台Store受控。首次index runner的execFileSync options写错仅修包装，不改产品/断言；失败保留。没有新包/Native或私库完整流程结论，其他App/Kit/源目录分支恢复仍OPEN。证据：`browse-availability-recovery-*`。

- ComicFury/DBM/咚漫三个owner实际清理：Root重核当前接受后继、全部原raw WIP/继承HEAD与主仓祖先关系及共同metadata/sidecar/stack取代，210/225/626物理文件和各6件admin全归档逐member核后精确移除三个checkout与冗余refs。保留当前主仓原parser/图标后继，不回灌旧validator、无guard打包器或MyComic无图标注册。两次前置校验分别拦在untracked目录折叠显示差异、咚漫自身tracked011候选；实核原始同一status选项及014完整后继后才接续，未忽略文件变化。源主仓b2d67bde/clean及其他refs/字节保持。XComic简中原192白圆角底资产无明确拒绝/后继，NOTICE已复制陈述与当前缺件矛盾，owner继续HOLD，不把归档作资产交付。证据：`cf-dbm-dong-owner-cleanup-result.json`、全部full/admin归档及source-worker两资产报告。

- 原验证调度隔离完整闭包恢复检查点：App`26a80319`归回33ce/0394原20行模块、Entry两Want生产者与startup/foreground、Index前台更新/启动调度全部原消费者，八原raw span和模块blob亲核，Index原WIP与所有无关tracked保持。实际staged模块/方法Host覆盖strict布尔Debug、每Want重置、普通/Release调度、ready/foreground守卫及主题通知；无落偏好、无新目录、未在设备启用参数或新增Native。只证明原调度准入，不承诺已排队任务取消/所有背景副作用绝对隔离。008自动备份整组乐观显示/feedback许可仍未知、未带入，fd741整套仍等Shared snapshot；其余恢复审计OPEN。证据：`verification-isolation-recovery-*`。

- XComic简中资产记录纠正：源主仓`dbd66299`仅改NOTICE一条不实的“已复制官方图标”陈述，保原Keiyoushi参考路径/Git blob/SHA，明确历史候选带图、当前business-only树缺图及标准打包未开放，官网认可/当前适用性未独立证实。Root复核原icon与繁中同337a字节、计算原blob7e702一致，但繁中不是更高清后继；未复制素材、未称具体拒绝、未加注册。原owner及资产原件继续HOLD；其他tracked/SDK/build不变，恢复审计OPEN。证据：`xcomic-zh-notice-correction-*`及source-worker原资产调查。

- 当前恢复工作单及原主仓八处历史文档导引纳入Git跟踪检查点：只保存既有唯一工作单/历史边界提示，不把旧计划重新立项，不带其余UI审计/Reader标准/源码WIP。全部恢复与清理仍按顶部范围OPEN，下一项为Root核WebDAV打开Owner、源worker核GlobalComix/GoDa/xkcd/Manhuagui-v011，Kit可见前缀/窗口与旧WIP保持具体待审边界；不能以本次文档提交作为任务完成。

- GlobalComix/GoDa/xkcd三个owner实际清理：Root已读自有parser/版本精确差异及原Root回执，确认当前011业务+官网ICO、GoDa012根相对API图路径、xkcd012正文角色+013图标后继承接原成果；共同旧打包WIP按已归并后继处理。283/324/237物理文件及各6admin全部归档逐member核后精确移除三个checkout与冗余refs，主仓dbd66299/clean与其他refs/字节保持。漫画柜012/资产仍HOLD，不因其继承HEAD可保全而丢弃独有业务。证据：`three-canonical-owner-cleanup-result.json`及对应full/admin原档。

- Terra继承文档恢复：源主仓`735ebc06`找回662b原README blob3c6137/5077a9全文，历史11行逐字保留并前置当前017、016业务/017资产后继和原具名有限证据边界。明确旧011/黑底/197调度不是当前事实或授权；没有编造原文不存在的build命令，没有覆盖当前源码/资产/SDK/registry。补回此路径不解除漫画柜012自身HOLD。其余App/Kit/源目录/refs审计继续OPEN。证据：`terra-readme-recovery-*`及原source-worker补件报告。

- WebDAV异步打开原独立闭包恢复检查点：App`23c69e8d`归回f5两文件八raw span，Service请求前/后当前server/root及三次ownsOpen、Search唯一caller的route/query/open serial全配套；4d原DTO及b1端点前置现已在主仓。Root核所有raw Git blob/行hash和真实index/working目标hash，保当前文案/Builder/其他WIP。原全部WebDAV Service/caller断言在实际index通过，IO/网络/路由mock；原另三私库expectedServerId block仍保留于--full且OPEN，不冒整套通过。未带e22/af远程history/channel/v4或可信旧OPDS身份，不加新错误文字；无新包/Native。其余恢复审计继续OPEN。证据：`webdav-open-owner-recovery-*`及原worker完整边界。

- Kit独立资源寿命闭包恢复检查点：原reader-kit现有codex/reconcile-f1-d1上提交`089cbd13`，在真实bd392基线归回557原Core资源保留/观察后释放/失效闭包及三个原测试。保原spread算法、onVisible/reportVisible、窗口二参接口、UI/菜单/路由/默认；continuous不扩大outgoing需求。Root亲审原完整diff及当前适配，实际当前Core的PagedSession/Session/AutoRead三套Host86/86通过，其他tracked原字节与clean状态保持。只恢复内部资源寿命，最多多保一既有paged item；原557人类批准未定位，不冒历史许可或Native视觉等价。无FF/embedded迁移/新目录/包/设备，OFF旧投影、可见prefix/window、31WIP和整个Shared仍OPEN。证据：`kit557-bd-recovery-*`及原r12来源/消费者绑定。

- Kit原有冗余refs实际清理：原reader-kit两个f1/d1分支tip及全部13条reflog中的每个对象、遗留f1 admin的HEAD/ORIG/日志/refs均为当前089cbd1祖先；旧checkout已不存在，其index相对原tip无差异。完整7管理文件/10member归档逐项SHA/模式核后，只移除该精确stale admin与两冗余本地ref；主仓代码/当前分支/其他refs/stash不变，不GC。原对象仍由当前分支可达，原ref/reflog原文与index保在审计。其余Kit生产GitDB/f769 WIP与App/源恢复继续OPEN。证据：`kit-ancestral-refs-cleanup-*`。

- 自动备份完整数据Owner三方恢复检查点：App`35390e24`接回008任务/偏好串行owner、2db严格列表与已导出后清理失败记录、14cd剩余五键回滚，并接全部三字段producer、页面重读/完成与Index前台消费者。保主仓保存成功后才显示、原latest-load DEFAULT、原manual失败文字、Builder及local-folder ready/finally；原乐观显示/新busy反馈仍HOLD，不冒原样历史批准。Root核原Git blobs/全部raw span、双port hash及Index十九对原WIP编辑保持，三文件169增68删；实际index service/rollback/consumers及2db列表/IO/retention/导出失败Host通过，文件与Preferences仅内存适配，无新测试目录。启动原250ms若ready未成仍跳过，等下一真实foreground，不新增触发器或延时；无真实删除/新ArkTS包/Native/进程死亡结论。其余恢复与清理继续OPEN。证据：`automatic-backup-threeway-recovery-*`。

- App原有冗余本地refs实际清理：203个本地分支逐对象核查，168个未被工作树占用且tip及全部reflog旧/新对象均为当前35390e24祖先。每ref原名称/tip/loose内容与模式、reflog原文/模式/SHA、配置及全refs已保全后，使用Git删除这168个本地分支。主仓源码、所有tracked/普通untracked字节、WIP/status、HEAD、工作树列表与远端refs精确不变，不GC、不新增分支。剩35个（六个占用owner含master、29个非祖先旧feature/lane）继续逐提交审，不据此声称目录或有效成果已全核毕。证据：`app-ancestral-refs-cleanup-review.json`及`app-ancestral-refs-cleanup-result.json`。

- BH3当前归属文档纠正：源主仓`31f2f16e`仅纠正NOTICE把旧Keiyoushi b4fba图标称为当前包图标的不实陈述，保原路径/blob/许可并说明已选119px官网原PNG010b及原ASSET声明链。实际当前PNG签名/尺寸/hash和全部原引用核同，源码/素材/SDK/打包字节不变，无新网络/构建/Native结论。其旧owner内历史素材池与PNG补包工具逐件保全、当前标准六格式/manifest.icon职责后继已经对应，四owner完整归档校验仍在进行，未提前删除。证据：`bh3-notice-correction-*`及原source-worker精确工具/素材报告。

- 又实际清理四个已归并旧源owner：BH3/ComicABC/Manhuadui/Terra共11988物理文件及26件admin逐member SHA/size/mode核档，完整原历史bundle无前置verify+unbundle通过后精确删除四checkout及refs。随后IQIYI/MPC/Tencent/Zai共9193物理文件及24admin同样完整核档并删除，source HEAD31f2f16/clean、所有tracked字节和其余refs保持。业务/资产当前接受后继逐项保留，原PNG补包器/素材池/真实请求与有限Native证据均保在完整原档；无源内容新验收。Manhuaren011与Manhuagui012及其他未核对象仍保留，不能把已清理八个当全线结束。证据：`four-inherited-owner-*`、`next-four-owner-*`。

- App其余29个旧非codex本地ref实际清理：30个独有commit中28个stable binary patch-id等价，另两件因create/replace父占位差异而hash不同但全部7/6路径after blob/mode精确；Root再次核全部改变路径及SDK两真实迁移blob。完整29ref无前置原对象bundle验证并unbundle、原空reflog/refs保全后按预期tip事务删除。源码/WIP/所有原working文件、HEAD、工作树及远端保持；三个原feature跟踪配置段另核原已归档值后精确移除。保全脚本首轮仅写记录时Path类型错误，未删ref；修正包装后重核原档，未覆盖bundle。App从203本地分支减至6（master+五个待核owner），其五份checkout及原WIP仍OPEN。证据：`app-equivalent-refs-*`、`app-original-29-equivalent-refs.bundle`。

- Kit原f769数据闭包恢复检查点：原reader-kit现分支提交`8201b4e6`，归回DisplayMap原metadata稳定身份/updatePage及PagedSession两实际生产者/消费者、原resolvePosition与idle/request0构造回声去重，两文件54增11删。Root实读原WIP和真实subscribe/reconcile顺序，核16输入及8原方法全字节保持，保089已恢复资源寿命、窗口/continuous/导航/close/UI/默认。实际当前Map/PagedSession/Session/AutoRead四套104/104通过；无新ArkTS/Native/优化收益或逐帧等价结论。31WIP剩余资源窗口/visual claim/Viewport等明确原消费者仍待审，不以纯helper闲置当恢复；原可见prefix与两删除保持具体OPEN/HOLD。证据：`kit-metadata-recovery-*`及r14逐职责报告。


- 本轮原已批准备份呈现恢复检查点：App `dee6bc93` 归回原批准五pane分组、纠正后文件行/More菜单、loading/失败重试保旧结果、Reader条件divider与设置有限摘要行数；连原408预览DTO/已验证envelope算法KDF前置。Root重新读154476/155218/155238/155266/170443实际人类原文、全部原Git span与双port输入输出hash，原16业务方法及Settings十五对/三语各八对WIP保持；实际index原loading/metadata Host通过，无新构建/Native/视觉结论。全局行缩进、source fallback及3f新refresh/乐观时序继续具名HOLD，不把本组当整个备份恢复。证据：`backup-approved-ui-recovery-*`。

- 本地目录身份原完整闭包恢复检查点：App `5bd9f971` 归回acb三生产文件的同root路径身份复用、新origin唯一书章ID与页身份保留；首次导入、rescan-before-summary和无persistence回退全部接齐。Root核原blob/原raw范围与三端消费者、十九对Index原WIP及无关文件；实际index原Host断言通过不同root不alias、同root重选/legacy重扫保持和前插页不撞ID。历史具名人类批准未定位，明确按当前找回有效成果授权审本数据安全修复，不冒旧许可；无当前ArkTS/Native/数据迁移或历史被覆盖书恢复结论。证据：`folder-identity-recovery-*`。

- 又完成八个精确旧源目录清理：漫画社/漫画屋/MyComic/六漫画/MH160/CManhua/快看七owner全部17859物理文件与各自admin完整归档逐member核后删除工作树与七refs；Protectors原detached owner127物理文件和六admin另完整保全核档后删除，不混同此前textR2 owner。所有有效业务与接受后继已在主仓，原素材/fixture/工具/ignored和原历史仍保在原档，清理前后源HEAD/clean/其他refs及全部tracked字节精确保持。Protectors包装首次字段名/归档依赖错误均在删除前拦下并改正，未以失败跳过内容核验。证据：`seven-successor-owner-*`、`protectors-original-owner-*`。其余有实体残留的prunable目录继续逐项审，不能批量prune。

- 漫画柜012原业务恢复检查点：源主仓 `4b80b9ba` 归回原七源件与仅ownlock0.1.2，原43路径重建及284兼容材料重新核同；当前SDK8506/原标准WASM flags离线锁定编译与无网络source_info通过，WASM e6ae5852与原SDK8506兼容产物全字节同。现有SDK/build registry及其他tracked保持，未选图标、未打包/联网/设备，正文和资产继续OPEN。证据：`manhuagui012-recovery-*`。

- 源筛选条件divider原批准恢复检查点：App `46a5ece8` 从154476明确批准的whole-app原提案仅应用SourceFilterControls完整section，原before应用所得全字节等ab64 after；保可见条件、已有控件/参数、菜单和两源页WIP，不带同commit其他界面。Root发现代理此前把difflib重建与Git raw hunk混称逐字同，已撤回：Git行对齐确有差异，两次检查均在任何修改前停止，最后按原完整输入/输出证明恢复，不称raw hunk同。无新同构测试/构建/Native；其他App/Kit/源目录分支审计继续OPEN。证据：`source-filter-approved-recovery-*`。


- 下载完整消费者恢复检查点：App `45d3c01d` 归回af903两文件19原raw span，四入口水合后复读当前漫画/章并核sameComicIdentity，队列缺目标不重造旧项、详情失败走既有文字出口，batch等待原workers全部settle后释放busy。原顺序循环/现URL/context/Builder全部尾段与详情八对WIP保持；实际index原12身份场景和失败套件通过，blockUnavailableEntry latestrow只有源码/调用审查、不冒Host覆盖。历史逐项人类原话未定位，按当前数据安全恢复授权审；无新runtime batch/style/当前ArkTS/Native。证据：`download-consumers-recovery-*`。

- 原Tracker分组WIP恢复检查点：App `1fa8e153` 仅接154476精确批准的三个hunk，原before应用批准完整section后全文件等production原WIP；三方保主仓已接受外边距及全部账号业务，不把未提交当无效。明确有原批准surface/inset/divider变化，无新设计/默认/账户能力/Native。证据：`tracker-approved-group-recovery-*`。

- 八个真实有文件的prunable残留及三个真正缺checkout的admin已逐对象清理：八目录原165实体文件和完整admin逐member SHA/类型/模式核档，原全部观察对象独立pack/index严格验证、完整原历史bundle无前置验证后，仅移除八实体与各admin；三缺checkout另完整核档并保全可恢复index/日志所有对象后只删admin。空intent-to-add不冒已找回缺失文件原内容，所有refs另保。三admin首次错误地拿bundle全部heads与普通refs全等比较被拦，已据实保额外HEAD/worktree伪引用并重核原档接续，未覆盖原档。证据：`eight-residual-*`、`three-absent-admin-*`。源五个仍有待核资产/独有原件的owner继续保留。

- HentaiFox原业务恢复检查点：源 `a60eec80` 归回六原业务/许可/metadata/文档及自身workspace/lock，四业务原字节、两文档原全文后缀均保，前置准确说明当前no-pack与原有限安装/cold边界。当前SDK8506离线锁定WASM与无网info通过，无build row/图标/旧packager/HTTP/Native正文恢复，原16px资产尚未定、未称已拒。漫画人原011完整四路径续归回 `043a3ddf`：原cursor/listing ABI/HTTP分类/去API日志/能力与评级/metadata完整接齐；原50函数42个（含auth/签名/POST/保护目录正文）逐字不变、只8函数变，不能让原010已有auth缺口挡公共search有效成果。原20+20不同ID输出/GET日志及原包绑定核同；当前离线锁定WASM为原1f1b257d、无网info通过，未触发匿名POST、未增新网络/打包/Native。证据：`hentaifox-business-recovery-*`、`manhuaren011-recovery-*`。

- 源根README三行遗漏已恢复 `d26facd1`：只补Guazi/Kuaikan/CManhua当前SourceInfo版本与有限事实，原三行逐字存审计/完整Git历史，不在当前README重复过时pending声明。首次错误以Cargo版本验证CManhua被拦在修改前，现明确Cargo010与SourceInfo012独立，未改版本。随后12个未占用本地ref逐tip/reflog/全部独有提交与有效后继审，原refs/log/config及完整原对象闭包pack/index核后用预期tip事务精确移除；d511明确未采纳的旧Komiic变体完整保全，票据能力本就在可信014/015，不回灌旧page:kid兼容退化。主仓、五个绑定owner、全部远端/配置/工作树与所有tracked保持；源本地分支18→6。这不证明非Git候选树或App/Kit恢复完成。证据：`source-readme-three-rows-*`、`twelve-source-refs-*`。

- Kit数据与资源完整组续归回：原唯一分支上 `0f95bc3` 恢复f769原reconcileDepth/emit guard/完整try-finally wrapper，原reconcile主体/资源/异步progress保持，只更正旧idle注释；PagedSession+AutoRead实际68/68通过。`f260c8a` 随后恢复c76→fd76→8dc→e2的已保存preload深度→真实Core窗口→分页/连续native缓存及最多一个已租回翻edge完整四生产文件，原e2五项测试全文恢复后实际73/73。Root在c585真实原GitDB核全部13span（第8两个方法各全文同，仅中间原注释未入候选），保557/metadata/batch/reportVisible/seek/close；Pager保cachedCount第二参true，Continuous保原单参，不带slider/默认/mode/late renderState。未新构建/Native，不扩原具名有限运行证据。claim完整8消费者按原采纳证据续审，旧projection两删除已由c76/831源码取代、不回灌，晚期未验候选仍保原件。证据：`kit-reconcile-batch-recovery-*`、`kit-resource-depth-recovery-*`、原r17/r19。

- 全目录范围补漏继续OPEN：除五现存App checkout、源五owner与Kit独立GitDB/WIP外，`/Users/honjow/git/koma-worktrees/source-settings` 是无.git指针但仍含App源码/证据的实体副本，不在Git worktree清单仍必须核。App worker已读2366件，非生成1764件中1762有可达原内容映射，旧ReaderChrome/ReaderPage两件继续逐行为找后继，未删该目录。`/private/tmp`原盘点1144顶层目录/220源树，当前仍有1117个Koma相关目录；源worker继续非Git候选树逐内容去向，不能把分支或工作树数量减少当本任务完成。普通产品与设备仍暂停；下一owner：Root亲审claim/剩余owner可清理闭包，App worker核无Git副本/CI依赖/文档，source worker核剩余实体和非Git树。


- 无Git的source-settings实体已核清并清理：Root独立核708个App文件逐路径/mode/blob精确等原0312完整tree、1056个Lexbor等原c8f pin，原12条settings after与主仓祖先3743全同，旧Reader基线不回灌。全部2366文件/150421450字节（含602构建/证据项与唯一fixture原回执）完整归档，2835个tar成员逐件核mode/字节，App原历史2929对象与Lexbor完整上游11200对象均pack/index严格验证。首次Lexbor浅仓缺父对象使index-pack严格失败，在删除前停止；失败包/记录保留，后从本地现存非浅对象库补齐，无网络/新源码目录。限定移除`/Users/honjow/git/koma-worktrees/source-settings`，主仓全部tracked/WIP/refs/HEAD前后精确保留。证据：`source-settings-complete-cleanup-*`、`source-settings-original-*-closure*`及原App worker完整实体报告。其余实体/历史审计继续OPEN。
- 可选多语言名称完整消费者已归回：App`31c8ee5a`恢复原1bb的11路径producer/consumer。Root亲读原同会话9666/9691 actual对话并核行hash，原可选名称/旧name fallback/固定ID和收藏不变授权成立；172项双port原raw span亲核，结果页仅将现bde map的名称producer接解析helper，保live revision、opaque sourceKey join、当前job复读与`>`比较。Index19/Library3/Detail8块原WIP逐字保持，其他tracked保持。实际index原metadata/presentation全部Host断言通过，无新构建/Native/各页实时语言刷新结论。证据：`localized-name-consumers-recovery-*`及原1bb完整追溯。
- Kit原独立职责继续归回：`39c93a8`仅将原f7的两行loading根Transparent注释/修复适配到现Column，保四现有consumer与全部几何/文案/门禁，不加responseRegion，原Stack与当前Column区别明列，不能把原fresh57命中链进展当当前waiting菜单接受。`a03ca79`归回原854的66行native identity map、完整RenderItem/DataSource→真实LazyForEach/key/snapshot消费者及原五项语义测试，16 after span与原854精确、原8a427 HAP/patch/具名录像绑定亲核，实际五项通过；当前command/queueSelection/boundary/active、f260深度/true和所有Core保留。`32b297d`恢复原304的排队prepare单行及完整原测试case，当前Koma先open→current检查→prepare→current检查→真实layout wait消费者已核，实际Window整套36/36。无新ArkTS/Native，原具名有限运行不扩大。证据：`kit-loading-input-recovery-*`、`kit-native-identity-recovery-*`、`kit-window-queue-recovery-*`。
- claim/rollback组具体HOLD：Root已在真实原GitDB独立核r20的原方法与消费者。原854/f769 continuous在displayed+failure态没有对应重试入口，总error也不聚合slot failure；整组回灌会把当前failed面板重试变成无入口。原29ca/38216成功替换运行不覆盖这条失败。故原已有采纳成果/原包继续保全，不冒“完整8消费者失败闭环”，也不造success-only生命周期或新连续按钮绕过恢复范围。其余非依赖原组照常审。下一owner：Root亲审源八阶段非Git树的共享WIP/后继及完整保全清理；App worker接原682网格完整授权/三方WIP依赖，源worker补非Git全physical和真正独有WIP，Kit worker收口剩余31对象与ignored内容。产品新增与设备仍暂停，整体恢复OPEN。


- 原生网格完整组已归回App `396b71b4`：原682七生产文件及原89def尾部继续加载所有者完整归并；前轮亲核原人类100297/102177/102189原文及256条双port span。当前geometry WIP保持，不重定间距。原tail Host在实际index通过，无当前构建/Native。证据：`native-grid-recovery-*`。
- Kit五组原职责已归回：`0f0dcf71`原473 terminal及88b必要父frame gate，原continuous-entry11/11；`c4b50245`原829 hide-before-light/close竞态，Window38/38；`da3c6adf`原f2bf→a433完整dominant/fromViewport及原测试27/27；`e8c8027c`原281 attested preview几何及原case12/12；`eaa9a1c3`原cb→068 source色/fallback/继续visibility与复合错误及完整原test diff39/39。Root逐精确patch/原Git/真实caller亲审，其余tracked保持，Window全文精确等原a433/f769。Koma当前不赋preview字段且close不传callback，未造consumer/即时收益；claim失败retry具体HOLD、native decoded及source lifetime各组仍OPEN。无新ArkTS/设备，五提交未推送。证据：`kit-{continuous-terminal,window-hide-first,dominant-close,preview-geometry,window-close-fallback}-recovery-*`。
- 最后五个源Git工作树和五冗余refs已精确清理：HentaiFox/漫画柜旧011/漫画柜012/漫画人/XComic简中共9278原文件及全部admin完整tar逐member核SHA/类型/模式，全部可观察Git对象（含不可达/index/reflog）独立pack/index严格验证；原WIP及未采纳素材asset index另存后移除。源主仓由6本地分支到仅master，唯一worktree为原主仓，源码/HEAD/clean/其他refs保持043a不变。上次自动审批拒绝所指共享WIP/资产经Root逐条核后才获执行。处置draft误称MyComic已注册被实际断言拦下；按原fcea缺图边界改为不注册，未改源码或绕过断言。图标官方身份/高清适用性仍OPEN，未采纳不冒拒绝。证据：`last-five-source-owners-*`、`root-five-source-owner-exact-disposition-review.json`和五份完整physical/admin档；非Git/App/Kit其余实体仍OPEN。
- 下载短写原成果已归回App `30bc3bb4`：原07049精确一文件5增2删，write计数/落盘size不等输入时在recordPage之前进入既有failed/partial；本地copy/复用、队列/通知、轻量最终校验/UI保持。实际index用Map端口跑完整4原场景/断言通过，其余17tracked WIP与3untracked精确保持。无新测试目录/真实磁盘故障/当前Native结论。证据：`download-page-write-recovery-*`。
- Happy012完整业务已归回源 `7af0d9d8`：UA R2→目录完整性→firstFetchError四路径完整保留，Cargo/lib原字节、原README全文附准确边界、仅ownlock版本。Root亲审完整diff/原两Root记录，348原frozen成员SHA重核；现SDK8506离线锁定WASM及无网络info通过，其余tracked保持。首wrapper把264原list当dict在写前停止，按两原schema修正后全核，不减少绑定。导航087/图标/新registry/SDK/CLI不带；现有registry缺图门禁照实保持。新WASMc507不冒旧运行等价，无HTTP/包/Native；Happy五实体仍待全member清理前置。证据：`happy012-business-recovery-*`。
- 下载/Tracker原完整组续归回App：`2e927a88`保留完整下载内容，原12+8场景通过；`f62694b0`恢复同章join/全局准入/移除等待所有者完整四文件，原四suite通过；`f73d05ec`恢复章节计数与作品状态分离，原125行service/client检查通过。各组原diff/消费者与无关WIP均核，Host不冒Native。证据：`download-*recovery-*`、`tracker-*recovery-*`。
- Kit解码及布局回执原完整组归回 `f340474f`：恢复原854 native leaf、四site真实producer与原0e连续加载反馈，保五个当前RDR005方法、失败/重试、当前Core和样式；原512测试后继及原continuous三case随组恢复。真实index原7+3全部10完成且通过，相关既有10文件133/133；不以旧节点名源码正则替代视觉。claim/source lifetime/host端口仍各自OPEN，无新ArkTS/设备，未推送。证据：`kit-native-decoded-recovery-*`。
- Tracker待同步队列原完整数据Owner归回App `c16b8a5a`：全文等原0c1 after824f0b87，跨实例串行、完整opaqueID/101+记录、坏数据拒覆盖与put/flush回滚保留。Root真实index等待原pending和当前service原suite完整Promise结束通过，全部17无关tracked WIP和3untracked字节/status保持；不含Reader事件/close新反馈或真实账户/平台IO验收。证据：`tracker-pending-recovery-*`。
- 必需图标四显示消费者归回App `55f5295d`：Root核原actual-user154532/154543/154620原记录SHA及原production WIP，仅Manager missing_icon分支与三语原missing/invalid标量；无地址、几何、颜色、裁剪、素材或脱敏allowlist变化。现有资源WIP各payload原样，JSON无重复键；普通失败文字Native待验。素材外部遮罩与App裁剪的原话/当前规则层级冲突保留待核，不据泛称反向改样式。证据：`icon-required-consumers-recovery-*`。
- 旧阶段目录继续精确清理：Terra两份、MangaBZ/再漫画四份、雀魂r0/r1及MangaDex诊断/Happy残留均已完整归档逐member核后移除，原外部证据保留。随后两TIPO clone共304文件全档核后清理；其objects仅alternates借用主仓，未误删主对象。再清王者/LOL/PGR/阴阳师两份/雀魂原残壳六实体共607文件，PGR136 loose对象实际解压SHA1/type/rawbytes与主仓核同、原index等d5；其余生产残件有明确后继或全原ASSET前缀保持。首轮validator diff格式不同比较在归档/删除前停止，原失败留存后按Git原diff复核。所有主源代码/HEAD/refs/clean保持7af0；旧素材不回灌新图。证据：各`*stage-cleanup-result.json`、`tipo-two-clone-cleanup-result.json`、`six-source-residuals-cleanup-result.json`。
- 下一动作与owner：Root亲审SDK clone/MDX017与019/Happy三阶段的原决定、独有WIP及完整Git对象闭包后精确清理；App原owner继续已批准browse单行、684完整消费者可见值边界、AutoRead及五checkout剩余有限组；Kit原owner逐f769/c585/eceb独有历史与ignored/删除前件收口，原alternate依赖未解前不删GitDB。源原owner接Baozi/Genshin/Huanta及全实体覆盖。盘点、归档或提交不算整体完成；归并和核清清理全部完成后接原开发，当前产品新增与设备不执行。

---

以下保留原主仓开发记录全文，其历史状态不得覆盖上方当前恢复任务。


> **当前唯一状态入口。** 本文回答“现在有什么、缺什么、下一步做什么”。其他路线图、对标表和审计文档保留为方向或历史证据；当其状态与本文冲突时，以当前代码、当次验证证据和本文为准。

- 快照日期：2026-09-08（续接 2026-09-05/06 审查）
- 最新核对基线：`master` / `b486da30`，源仓`0018287` + 当前未提交工作树。书架/源网格间距、20 页列表外边距、本地目录能力门控、源弹层状态、应用级前台更新、结果展示、语言入口及相关模型/资源/检查是既有 WIP；已提交切片及各自证据边界详见第13–43节及第24节。下文历史记录仅覆盖其当时构建与场景，不能扩大为当前整页或整个领域通过。
- 指定验证设备：`192.168.50.197:12345`
- 当前阶段：**App主枝已含9a55a47a（MangaDex跨语言章节身份App侧，197 v2限域验收，不推送）；源仓d5ee46d（0.1.6）对应提交。详情下载孤立行3c8d8548及RDR004-A章序/历史目录均197限域验证并独立提交，见第24节；**RDR-004-B章末自动衔接已限域验收并独立提交e8817da5（单页/双页/纵向分页/连续滚动四模式×前后两方向均197通过，含一个设备上发现并修复的连续模式落点缺陷），见第44节；**RDR-005单本模式/方向覆盖已限域验收并独立提交4e9e16b0（新增只承载 pageMode/readingDirection 的窄覆盖键 `reader.seriesModeOverrides.v1`，全局默认不被带跑；host 检查抓到并修掉一处「改一本顺手带跑全局」的真实缺陷；197 录屏＋偏好文件双重取证），见第45节；**OPM孤儿进度ch:5caba1e0精确ID恢复仅设计（`20260908-mangadex-chapter-identity/implementation/orphan-resume-design.md`）未实施。宣传图首次重开失败仍未归因，不宣称已修复。DL004正常暂停、DL001/CHP001批量入队、LIB012网格旧快照、LIB011误计数、初始化等待优化分别已提交，证据见第38–43节。虫笼取页报错、继续阅读卡长章节名可读性仍未闭合。用户已允许内容策略与源仓修正范围，后续同程度少量无损验证自行推进并报告，不再逐章请示。** 用户反馈不代表结束任务，每批197验收后独立提交并继续、不推送，不外推全项目通过。

<!-- koma-progress-snapshot
{
  "schemaVersion": 1,
  "title": "Koma 首版开发与普通路径验收",
  "state": "用户反馈缺陷修复与源开发并行",
  "outcome": "v0.1.2-pre发布已完成；发布后用户普通使用反馈已登记。当前存在全屏时机、连续滚动、选章/排序等未闭缺陷，不以旧验收或发布成功抵消。",
  "updatedAt": "2026-10-24T19:52:31.227399+00:00",
  "target": "/Users/honjow/git/Koma；同级reader-kit与koma-sources为原主仓",
  "activeId": "CONTINUOUS_PERFORMANCE",
  "activity": "Root：237真实末项安装已验分隔线与保留行；提交此限定修复后接回N068跳页相邻解码空缺。",
  "nextAction": "提交同步源列表末项key修复，跟进精确CI；定位N068跳页后的文件命中、原生解码和呈现交接，不重跑已冻结路径。",
  "proof": [
    {
      "label": "正式主仓",
      "state": "各一工作树/分支",
      "kind": "accepted",
      "detail": "Koma/master、reader-kit/main、koma-sources/master；没有新增副本。"
    },
    {
      "label": "本地未加密备份",
      "state": "具名路径通过",
      "kind": "accepted",
      "detail": "具名当前快照恢复成功及真实cold后的书架/历史/下载/79源包消费者已亲审，原四备份保留；不含其他快照/跨设备/自然失败回滚。"
    },
    {
      "label": "远端同步",
      "state": "具名修复精确CI成功",
      "kind": "accepted",
      "detail": "fd807cf1与1e163c3e精确CI成功；漫画柜016公开85源索引与包三成员已核。"
    },
    {
      "label": "共享阅读器",
      "state": "普通入口具名通过",
      "kind": "accepted",
      "detail": "44a86da1普通入口已接入并完成源/本地/进度/前后章/按书设置/返回及下载管理具名路径，详见当前队列。"
    },
    {
      "label": "图标全范围",
      "state": "用户已确认完成",
      "kind": "accepted",
      "detail": "按本会话最新人类决定关闭；后继K应用图标也已安装交付，不从旧OPEN重开图标矩阵。"
    },
    {
      "label": "本地CBZ普通路径",
      "state": "具名路径通过",
      "kind": "accepted",
      "detail": "原导入/纵向翻页/进程结束后重开证据保留；本轮核清2/1700同页左右半后进3/1700，非侧边点击失效。测试条目已移出，外部文件保留。"
    }
  ],
  "hosts": [
    {
      "name": "Koma",
      "checkout": "/Users/honjow/git/Koma",
      "appHead": "f6f1c1a已push，CI40123012297成功；末项key限定修复已构建/237113验证，待范围提交。",
      "hap": "237 source-terminal-row-release-signed.hap8547220B，0.1.2-pre/code3/Kit9b94e98；113正常安装源后69项，库/阅读记录同111。"
    },
    {
      "name": "NextE",
      "checkout": "/Users/honjow/git/NextE",
      "appHead": "e29133b3采用Kit9b94e98已push，CI40120958754成功。",
      "hap": "本轮新材质包仅构建，未安装。197保38181768B稳定包；原下载与LTR13/19已恢复。"
    },
    {
      "name": "NextN",
      "checkout": "/Users/honjow/git/NextN",
      "appHead": "9f47c185采用Kit9b94e98已push，CI40120959939成功。",
      "hap": "本轮新材质包仅构建，未安装。197保38205248B稳定包；原7项下载、LTR1/34和2/2已恢复。共用入场候选未采用，源码已撤。"
    }
  ],
  "scope": "Koma首个生产版本和中文源质量；当前人类纠正、既定设计和原WIP边界继续有效。",
  "items": [
    {
      "id": "READER_THUMBNAIL_LOADING_REGRESSION",
      "title": "NextE/NextN缩略图进入阅读时加载指示器消失",
      "status": "N/E具名路径与两笔精确CI完成",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "共同4bf42eb已push；N a0211fa7、E26a447c2均采用并push。197实际N032 Non-H686734全269帧/8表、E0274277955全151帧/5表顺序亲审及原91/92：最后低清仍有加载面板，首清晰图时面板退出；普通返同缩略图。旧E022第120帧反例和误判撤回永久保留。N033原下载/6867442/2保持，034回E画廊/K书架。 N CI40092801190和E CI40092801362均completed/success；无新tag/发布。",
      "remaining": "本次N/E两个真实缩略图→原图→返回范围冻结；其他布局、Legacy、自然异常未扩大。",
      "reportedAt": null,
      "reportedAtSource": "当前可见人类反馈；未取得原始消息时间，不能猜报时。",
      "firstEvidenceAt": "2026-10-24T10:23:04+00:00",
      "firstHandlingAt": "2026-10-24T10:23:04+00:00",
      "handling": "根据当前人类反例重开",
      "closedAt": "2026-10-24T12:19:29.702818+00:00",
      "evidencePoints": [
        "当前真实ReaderImagePlaceholder.ets：previewVisible将awaitingPixels改成preview；原图尚未可读却loading=false。",
        "reader-continuous-loading.test.cjs明确要求preview.loading=false；本次撤回这条错误预期的正确性结论。",
        "009普通Non-H688588旧包asset18:39:28.680、decoding29.329、原图presented29.428；期间保留缩略图却无加载反馈。",
        "最新人类直接指出E022/frame_000120.png仍是低清图但进度已消失；本帧否决刚才通过结论。",
        "E027普通Non-H4277955，151帧；原91低清+进度、92清晰且退出，无揭示前空档。仅该E路径。"
      ],
      "remainingActions": [
        "本次N/E两个真实缩略图→原图→返回范围冻结；其他布局、Legacy、自然异常未扩大。"
      ],
      "boundaries": [
        "不改变原指示器样式/尺寸/转场/全屏时机，不新增宿主遮罩，不清缓存或造延时。",
        "不改变MH160与原其余队列；本次局部完成后由Root接续源错误契约及普通远端更新。"
      ],
      "evidence": [
        "NextN .hvigor/outputs/reader-loading-background-20261011/.../shared-mutual/thumbnail-loading-*：N014原60/82，E022原85/118/120；024原7下载及686744 2/2，Koma原书架恢复。023错误N包名未作为N恢复证据。",
        "Kit536项通过；旧N688588/009与E4277842/019无反馈反例保留。新N014全255帧/E022全189帧按序亲审，实际E4277864取代manifest预期4277811，不修改原回执。",
        "197原N686744 2/2与7项下载在024确认，Koma原书架恢复；N无关两脚本WIP保留，E原4212986未操作，无偏好/缓存改动，无新tag。"
      ]
    },
    {
      "id": "READER_WINDOW_LIFECYCLE",
      "title": "三App五入口全屏/状态栏早于转场完成",
      "status": "共用候选待选择；用户所问右侧黑区已核源图固有",
      "kind": "open",
      "priority": "P1",
      "owner": "Root：共用候选实现及双设备原片",
      "dependencies": [],
      "result": "共享真实animation.onFinish＋native.onTransitionEnd双完成门，300ms水平进入。549项检查、N/K签名构建完成；N07472帧/2表、K237073108帧/3表均完整顺序亲审，进入与普通返回成立。K日志animation_started→finished301ms，再native_finished4ms；N晚取日志已空，未冒称同等日志时序证明。",
      "remaining": "用户尚未采用动效。候选源码已撤，四份精确patch及HAP保存在NextN .hvigor/outputs/reader-route-candidate-20261025；采用后恢复并验证取消/重入及N缺失的事件日志。两设备已恢复稳定版，N临时HD已恢复并返回原7项下载。",
      "reportedAt": "2026-10-22T19:12:58.799Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:12:58.799Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "evidencePoints": [
        "官方Navigation FAQ及SDK均未承诺onShown/onActive/didShow发生在默认转场结束后。",
        "OpenHarmony navigation_pattern.cpp中，生命周期与HideSystemBarIfNeeded均早于转场；临时探针已撤。",
        "2026-10-24官方HDS systemBarStyle明确“页面转场开始时生效”；NavDestination guide仅保证onShown布局完成。官方Navigation转场指南说明默认弹簧时长不可控，监听结束建议自定义转场；未把onShown/onActive误写为官方结束事件，现有样式/动画边界继续。",
        "当前人类已明确允许制作共用转场候选、先看录屏；旧等待批准状态失效，尚未实现或采用。",
        "N候选38209576B/1.0.7code10，从073实际686744下载阅读列进入2/2；074全72帧与返回已审。075布局为原7下载；075接收截图误写到072路径覆盖其截图，该截图不作原安装前置证据，074原片及布局仍独立保留。",
        "K候选8532590B/defaultRelease0.1.2-precode3，070安装三域同069；072普通Download详情→073继续6/10→正常Back；全108帧/3表顺序亲审。日志armed1792857971896、animation_started1990、animation_finished2291、native_finished2295；074正常回原书架，数据对比待补。",
        "用户问N图右侧黑区及是否关闭缩放：074为普通下载阅读列直接进入，不经过缩略图缩放，未改缩放开关。076已恢复稳定cdb38205248B；077同页仍有黑区，节点全1260px。079增强JPEG5120x7172；080临时关闭本会话HD，085确认实际源WEBP1280x1793，黑区同。下载RDB精确media4230305/page2，CDN一次HTTP200175362B，原图全高右侧135列近黑（RGB通道≤8）；本机公共文件接收权限拒绝未绕过，未冒称字节相同。087保留cdn-source-page2.webp和像素事实。",
        "候选未混入后续构建：Kit/N消费/两宿主候选diff均经reverse check精确撤下；N089正常返回原7项下载、HD已恢复。4patch与candidate-state.json留忽略产物目录。"
      ],
      "remainingActions": [
        "用户尚未采用动效。候选源码已撤，四份精确patch及HAP保存在NextN .hvigor/outputs/reader-route-candidate-20261025；采用后恢复并验证取消/重入及N缺失的事件日志。两设备已恢复稳定版，N临时HD已恢复并返回原7项下载。"
      ],
      "boundaries": [
        "不能用didShow、enableStatusBar、布局坐标冒充动画结束；不用延时或改变已定转场效果绕过。"
      ]
    },
    {
      "id": "CONTINUOUS_PERFORMANCE",
      "title": "连续滚动卡顿与新版/旧版性能差异",
      "status": "投影修复三端CI成功；总体性能仍OPEN",
      "kind": "open",
      "priority": "P0（最高）",
      "owner": "Root：跳页相邻请求/解码/呈现因果定位",
      "dependencies": [],
      "result": "061→067同686734/34页第12页六组8000反向，Cell808→85，Zoom更新71；主线程frame_slice均值5.877→4.047ms、最大38.032→20.362ms、>16.67ms61→2、>33.34ms2→0。顺序暖缓存样本，不是clean AB/显示FPS；共同Kit已推送，性能仍OPEN。",
      "remaining": "N068跳页相邻短空缺240→247/约116ms仍待定位。23:19:00.537 seek后.539–.552有两组文件cache hit，.553–.573既有增强结果ready；原生JPEG解码发生至.983，但缺逐slot对齐，不能据此断言空缺唯一成因。下一核资源需求/解码/可见范围交接，保原图加载反馈与所有宿主旧路径。",
      "reportedAt": "2026-10-22T19:43:05.108Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:43:05.108Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "firstHandlingAtSource": "本次收到实现结果，未倒猜该实现的开始时间。",
      "evidencePaths": [
        "/Users/honjow/git/Koma/.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/continuous-perf197-before-001/parsed-cwd/summary.json",
        "/Users/honjow/git/Koma/.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/continuous-perf197-after-001/parsed-cwd/summary.json",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/continuous-trace-007/parsed-cwd/nexte-host-frame-stats.json",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/continuous-motion-008",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/restore-ltr-009",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/restore-verified-010",
        "/Users/honjow/git/Koma/.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/continuous-fast197-trace-007/parsed-cwd/trace.db"
      ],
      "latestCounterexampleAt": "2026-10-23T04:57:37.180Z",
      "evidencePoints": [
        "Koma同场景快滚最大主线程帧耗时216.6→19.1ms；NextE均值9.82→6.35ms。两者完整运动、缩放与返回进度已审，未称满帧。",
        "原件：diagnostics/continuous-fast197-trace-007及后继106/107；NextE fast-trace-013与030/031。旧签名拒绝、错误前置样本均保留并排除。",
        "共享Kit42e8713、Koma05e788e5、NextE45e0b056及NextNb27dcab5的CI成功。NextN现成样本仅2页，只证缩放/返回功能。",
        "042最慢帧51.843ms中FlushDirtyNodeUpdate41.657ms；整个窗口隐藏的Rail更新93次/89.016ms、Tile304次/229.485ms。原7587让snapshot变化始终scrollToIndex，8918只用高度0隐藏却保活，隐藏期间仍取后续缩略图；保留挂载的原理由是已解码资源与滚动实例不能被销毁。",
        "Kit c9494dd，537项检查、N/E/K签名Release均构建成功。N046明确安装38201434B；050中隐藏Rail/Tile更新均0，旧042 Rail93/Tile304。051完整424帧/12联系表已按序亲审，未见整屏白空或额外页间黑隔条；未据录像声称满帧。",
        "N053第10页打开Rail，054选12，055滑块17后隐藏再开正确17；056原LTR1/34亲核，057原7项下载及6867442/2保持。",
        "E046明确安装38178001B；048连续第13页开Rail、049选14；050全252帧/7联系表顺序亲审。录像末次计划重开未发生，052在稳定控件上实际重开第13页并保原解码节点；053原LTR13/19勾选已亲看，054原2项完成下载保持。",
        "K237042明确安装8524605B，049连续第6页开条、050选7、051全298帧/9联系表顺序亲审；053重新打开选中6，054原LTR6/10已亲核，055普通返回书架。library/registry与042逐字同，reader仅该书3处updatedAt正常改变，页码及其余字段同。",
        "bb2a80d仅提前无入场/入场已结束的既有判断；旧2ce53ee原有资格门在后继帧后测量移入measure，而publish仍逐次排队。真实方法测试先30过1失败、修后31过，共享538项及三宿主签名构建完成。",
        "197 N058明确覆盖38201451B，059全95帧/3表普通缓存原图进入返回已审；06012/34及061同六组反向。Area回调总时860.548→825.912ms，可见Cell更新833→808，仍不能归为唯一根因。062原LTR1/34、0637下载保持。",
        "E055明确覆盖38178149B，058全217帧/7表及156/157原图亲审：156低清+100%反馈，157清晰原图与反馈同退，正常返回；0592项完成下载保持。K056签名拒绝未安装，057用原default信任8524725B成功；058早tap未进详情，059按当前卡片进入，060连续原图6/10、061原LTR6/10、062回书架；库/注册逐字同057，reader仅本地书3处updatedAt。",
        "cdb9c22：N067同34页/12起点六组8000往返，Cell808→85、主线程最大38.032→20.362ms。N068全284帧/8联系表顺序亲审，快速往返无整屏空白或错页；滑块17后正文/原生条同17。跳页相邻页240–247附近短暂空缺保留待查，不能称整项通过。070亲核原LTR1/34，071原7下载保持。",
        "K237 cdb9c22明确安装8528865B；066原生条实选7/10，067全222帧/7联系表已按序亲审，正文持续显示。068原LTR勾选6/10亲核；069正常回书架，库/注册与063逐字同，reader仅同本地书3处updatedAt1792853526148→1792855345873，页码与其他字段同。",
        "E cdb9c22明确安装38181768B；061原下载4212986的13/19，063原生条实选14且正文/选中一致。064全294帧/9联系表顺序亲审，三组快速往返正文连续，无整屏空白/错页；065原LTR勾选13/19亲核，066原2项完成下载保持。E现有CI preflight通过。"
      ],
      "remainingActions": [
        "现有N068跳页相邻页短空缺约116ms（240→247原PTS4.614667→4.730522）待核请求/解码/定位；非整屏空白，不据此推断单因。三端本轮CI已成功，下一当前处理项为已批准全屏入场候选。"
      ],
      "boundaries": [
        "这些是host主线程切片及三宿主具名运动/缩略条行为，不等同显示FPS、满帧或全内容通过。NextN050是34页真实样本，旧两页证据不能替代它。设置位置与全屏时机仍独立。"
      ],
      "modificationBasis": {
        "object": "ReaderContinuousCell输入投影，ReaderContinuousList现有按key挂载",
        "history": "c87f1e3起cell直接收到snapshot.forItem(key)，每次全量emit复制全局anchor/policy和frame；当前cell仅消费frames/navigationRevision/displayIndex。4bf42eb原图交接、42e8713图像状态保留及543cbda显式定位均保留。",
        "originalReason": "按稳定page key复用native List及单元；Core负责资源状态和请求身份，UI不能另建选章/进度owner。",
        "reopenEvidence": "061两个最慢FlushDirtyNode窗口均更新约13个连续单元；64次全局快照附近，多个稳定单元各61次更新，全窗口Cell808次/577.385ms。forItem生成新对象，单页无变化也改变Param引用。",
        "allowedDifference": "仅连续单元使用最小渲染投影；稳定displayed original且无新请求/retained/失败/notice/cropPending时，按完整页元数据、slot/request/URI/variant/visual/crop及navigation比较复用；加载/替换/失败仍逐次接新frame。保全局Core快照/进度、native key、图片与缩略条实例、几何、样式、转场。缓存仅现有窗口，离开/拓扑变化丢弃。"
      }
    },
    {
      "id": "FIRST_CHAPTER_SELECTION",
      "title": "无历史书架首次阅读误开最新一话",
      "status": "漫画160当前784章仍全unknown；原生详情200与Mac403分别保留",
      "kind": "open",
      "priority": "P1",
      "owner": "Root：未知目录边界；源具名网络分支待条件",
      "dependencies": [],
      "result": "详情完整成功目录可同步同ID顺序信息到书架；未知跨季目录仍不猜序。",
      "remaining": "漫画160跨季结构仍缺可用原HTML；原生784目录不能据标题首数或全reverse修。元尊同号分话及漫画柜metadata继续原项。",
      "reportedAt": "2026-10-22T18:44:10.746Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:44:10.746Z",
      "firstHandlingAt": null,
      "handling": {
        "measurement": "本轮实现时段经过（含构建/设备等待，非纯工时）",
        "recordedSeconds": 1230,
        "activeSince": null,
        "activeUntil": null,
        "note": "仅从本轮实现开始记录；此前调查与处理工时未知。"
      },
      "closedAt": null,
      "evidencePoints": [
        "详情旧34ab280d仅投影；沿b486da30的同ID规则补持久化，34项行为检查及签名Release构建通过。",
        "197158–162：仅Super Lovers三条番外的旧章号/排序字段更新，76章ID/页缓存及全部reader数据保持，重入库内容全同。",
        "漫画柜016原HTML235条Root独立复跑通过；237更新已装但目录/页面均network_error/http0；公开索引85条已含016。",
        "472普通返回漫画屋27.439秒未出现元尊，473为原生403；未走到排序/开书，无排序更改或恢复义务，不据此判首章规则。",
        "485元尊1270章升序：8个unknown公告/最终话在前，随后第1话（下）→（上）、第2话下→（上）。首次阅读另取最小已知号且同号保原首项；不能把483 unknown顶部当459实际目标。486已恢复降序/自然回RootBrowse，无开书或加书。",
        "545/547当前197普通漫画160→风起苍岚：列表788ms/200，详情1611ms/200、目录209ms/200，784条全部unknown。旧781增为784，未开书/改排序。当前Mac默认匿名准确详情GET仍403/无新body，不改UA/客户端/域重试。",
        "544→547 library/reader/registry全部逐字同；784为本次返回的站点目录，保存书库原781并未新增/覆盖。不得把目录显示变多误记为书架更新3章。"
      ],
      "remainingActions": [
        "漫画柜016已推且公开索引确认；237网络失败分支仅待有效响应。",
        "漫画160跨季缺metadata，仍查原始依据，不猜标题首数或全reverse。",
        "元尊第1/2话同号下→上已见，继续核准确chapterId及原目录上下关系；不合成小数编号、标题泛排序或复活unknown恒末尾。"
      ],
      "boundaries": [
        "197只验同ID信息保存和原Extra2进度保持；没有清历史伪造首次阅读，不称全源首章/排序已完成。",
        "漫画160本轮仍缺成功详情HTML；781章混季反证与唯一403原件已复核，不猜标题首数或倒序。"
      ]
    },
    {
      "id": "CHAPTER_SORT_MENU",
      "title": "章节排序菜单无作用",
      "status": "本轮限定修复已推送，三宿主构建与精确CI成功",
      "kind": "done",
      "priority": "P0（人类再次复现：通用排序及菜单状态）",
      "owner": "Root：包子012具名范围冻结；未知metadata继续原项",
      "dependencies": [],
      "result": "237784章全unknown的源原序/整表反序、独立依据/方向对勾、同项禁重选均成立；最终109反序后实际重置回源目录正序，无重置按钮，首行恢复第2季354。64相关检查通过。",
      "remaining": "已具名路径冻结；只按新反馈或相关依赖变化重开。Reader跨季年代、旧系统/暗色及未打开菜单分支未外推。",
      "reportedAt": "2026-10-22T18:49:32.812Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:49:32.812Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": "2026-10-24T19:25:24.086002+00:00",
      "evidencePoints": [
        "历史5e7854a7/3b2713ef/19ad9143：四种排序裁为两个选项后保留隐藏默认值；缺号/同号比较相等，原方向未整表互逆。当前用户明确批准默认源目录顺序、依据/方向独立，允许原生对勾。",
        "Mihon ChapterSort/SyncChaptersWithSource 与 Aidoku ceee58b源目录默认/方向源码已实际对照；源位置独立于可选话数，不再逐作品补正则处理菜单反序。",
        "237风起苍岚784章全部unknown：088原序第2季354→353，090/094反序第1话→2话；095切话数保反序，对勾为话数+反序。093小号常规分组标题/材质已亲看；原089大粗标题/白底保留为失败。",
        "已接受的包子012目录metadata及具名阅读范围保持冻结；旧源反例/发布/原片保留在原目录与Git材料中，不外推为跨季年代或所有首次选章通过。",
        "Koma f6f1c1aa，CI40123012297成功，包含70a36f0阶段诊断；Kit9b94e98已推。N9f47c185/CI40120959939、Ee29133b3/CI40120958754成功。K最终106→110三业务域逐字同，已正常返回书架。"
      ],
      "remainingActions": [
        "已具名路径冻结；只按新反馈或相关依赖变化重开。Reader跨季年代、旧系统/暗色及未打开菜单分支未外推。"
      ],
      "boundaries": [
        "本次新反馈明确重开通用展示反序与菜单状态，不继续按源补章号来掩盖菜单缺陷。",
        "原始章节对象/ID/源返回顺序、持久阅读数据和Reader自动邻章语义保持；跨季年代不能由显示反序推定。",
        "允许差异为升降序真正互逆、默认降序单一状态、原生选中对勾和同项选择无变更；不改控件尺寸/排布/字体。"
      ],
      "modificationBasis": {
        "object": "ChapterListSection展示排序和MangaDetailModels排序状态；原章节对象/ID不变",
        "history": "5e7854a7→3b2713ef→19ad9143；当前未提交两维方案及237089视觉反例",
        "originalReason": "话数语义比较保留；源目录和可选数值不能混为同一排序输入。旧二项菜单未同步默认状态。",
        "reopenEvidence": "用户再次实际复现多作品反序无效/当前项不明，并批准两维默认源目录方案；又明确要求小号分组标题及新材质。",
        "allowedDifference": "SOURCE_ORDER/CHAPTER_NUMBER与FORWARD/REVERSE独立，整表反转；原生选中标记、当前项无重选；排序分组小号常规字及公共材质。保其他布局、ID、读态和Reader邻章语义。"
      }
    },
    {
      "id": "APP_POPUP_SYSTEM_MATERIAL",
      "title": "菜单与半模态漏接系统新材质",
      "kind": "done",
      "priority": "P1（当前人类连续反馈）",
      "owner": "Root",
      "dependencies": [],
      "reportedAt": "2026-10-24T18:01:49.053271+00:00",
      "reportedAtSource": "本轮登记时间；原始提出时间未作推算。",
      "firstHandlingAt": "2026-10-24T18:01:49.053271+00:00",
      "closedAt": "2026-10-24T19:25:24.086002+00:00",
      "evidencePoints": [
        "8545858B签名defaultRelease0.1.2-pre/code3已装237，64相关检查和三语资源parity通过。",
        "SourceSettings104从稳定原生菜单直接打开，105不保存关闭并返回；101自然403自动Web验证后列表恢复，不扩成正文通过。",
        "shared reader-ui/ReaderChrome五处菜单有三处自d303c6b等已用THICK，两处RuntimeMenu缺失；这次统一调用同一内部材质解析，无新增动作或参数。",
        "最终1098547952B具名菜单：小号常规标题、原生勾选及材质可见；106三业务域相对105逐字相同。旧087→105缓存/源版本及读态时间戳不同，不写逐字保持或覆盖恢复。",
        "Koma f6f1c1aa，CI40123012297成功，包含70a36f0阶段诊断；Kit9b94e98已推。N9f47c185/CI40120959939、Ee29133b3/CI40120958754成功。K最终106→110三业务域逐字同，已正常返回书架。"
      ],
      "status": "本轮限定修复已推送，三宿主构建与精确CI成功",
      "result": "237 API26：093排序菜单透出模糊目录/小号常规分组标题；096书架筛选、099索引表单、104包子源设置均呈现原生半模态材质。097完整往返219帧顺序审阅，并看054/076/112/125/185原帧。 最终8547952B包/Kit9b94e98已装237；105→106书库/Reader/源注册表逐字相同。",
      "remaining": "本次237已打开菜单/筛选与源设置半模态具名范围冻结；旧系统、暗色和未打开菜单未扩认。N/E新增RuntimeMenu仅构建/精确CI成功，未安装实机验收。",
      "modificationBasis": {
        "object": "宿主原生菜单/半模态选项及KomaModalScaffold背景；ChapterListSection排序分组标题",
        "history": "37539a94引入统一ModalScaffold整面BG_SUB，296c7b34直接源设置复用bindSheet；本轮两维排序WIP使用原生MenuItemGroup字符串标题。",
        "originalReason": "已有公共模态导航/关闭/滚动结构保留；未找到排除新材质的决定，不把未找到当旧授权。",
        "reopenEvidence": "当前用户明确指出所有菜单和半模态没用新材质及分类粗大；237089原图已见大粗标题/白底。官方API26 MenuOptions/SheetOptions均有systemMaterial，默认undefined。",
        "allowedDifference": "仅补官方沉浸材质、支持版本的模态内容透明和排序分组小号常规字；旧系统保原底色。保动作/尺寸/位置/展开档位/键盘/生命周期/选中状态。"
      },
      "remainingActions": [
        "本次237已打开菜单/筛选与源设置半模态具名范围冻结；旧系统、暗色和未打开菜单未扩认。N/E新增RuntimeMenu仅构建/精确CI成功，未安装实机验收。"
      ],
      "boundaries": [
        "宿主40处弹层仅增加材质；HDS导航溢出菜单103原生材质已存在，不替换其实现。",
        "共享层沿用另外三个菜单已使用的THICK及API26检测，只补漏项；不变Reader偏好/控件选项/窗口生命周期。"
      ]
    },
    {
      "id": "READER_SETTINGS_STABILITY",
      "title": "阅读设置菜单跳变及动态本书后缀",
      "status": "共享暂停目标修复K/E/N具名设置开关及模式往返成立",
      "kind": "open",
      "priority": "P1（阅读设置正确性）",
      "owner": "Root：具名结果冻结；未覆盖范围保留",
      "dependencies": [],
      "result": "固定菜单与生效方向已修；共享暂停目标修复在Koma/NextE/NextN的具名设置开关、模式往返和恢复中成立。",
      "remaining": "具名设置暂停/模式往返范围冻结，接续其他未闭事项。",
      "reportedAt": "2026-10-22T18:52:07.192Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:52:07.192Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reopenedAt": "2026-10-23T04:52:35.917Z",
      "reopenedAtSource": "原始会话JSONL response_item/user核得新反例首报，非当前登记时间。",
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET"
      ],
      "evidencePoints": [
        "固定菜单、从上到下回显和恢复全局已修；共享Kit d8b568d保短暂暂停时的显式末页目标，真实滚动仍能接管。",
        "Koma123/124/130、NextE041–045、NextN020–024：设置开关与模式往返保位，随后恢复原模式/进度并返回；N仅2页。",
        "三宿主精确CI均成功；N材料a3ae6d81/CI39964150108成功。原121的16→15反例、125/127未达预期点击原件仍保留。"
      ],
      "remainingActions": [
        "具名设置暂停/模式往返范围冻结，接续其他未闭事项。"
      ],
      "boundaries": [
        "不外推Legacy、全局设置页、Slider边框点击、真实进程死亡；NextN样本仅2页。保固定行/位置，不恢复动态“本书”后缀，不迁移休眠持久方向。"
      ]
    },
    {
      "id": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "title": "自动跨章回退误落首图，应落上一章末页",
      "priority": "P1（阅读正确性）",
      "owner": "Root：Koma具名落点冻结；其他宿主不外推",
      "dependencies": [],
      "relatedItems": [
        "READER_SETTINGS_STABILITY",
        "NEXT_CHAPTER_PREFETCH_REUSE"
      ],
      "status": "197自然跨章末页与返回重开已验；精确CI成功",
      "kind": "open",
      "result": "Koma自然跨章回退已落上一章完整末页，正常返回重开保持；其他宿主范围未扩认。",
      "remaining": "当前Koma具名路径冻结；其他宿主及性能按各自独立项接续。",
      "reportedAt": "2026-10-23T04:55:39.469Z",
      "reportedAtSource": "原始会话JSONL response_item/user实际首报时间，不由当前登记时间猜测。",
      "firstEvidenceAt": "2026-10-23T04:55:39.469Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "evidencePoints": [
        "197079自然进下一章1/10、退回上一章16/16；080完整末图已审，正常返回书架重开保位。",
        "Kit543cbda与Koma5d8de36e已推，CI39921727505成功；用户接管会取消旧定位，next/手选仍首图。",
        "旧047/070/072失败不抹去：连续定位候选见.hvigor/outputs/continuous-position-rejected-072.patch。"
      ],
      "remainingActions": [
        "当前Koma具名路径冻结；其他宿主及性能按各自独立项接续。"
      ],
      "boundaries": [
        "保显式选章与既有续读语义；不以isAtEnd强改页码、不延时抢滚动。不能从本路径宣称全部Reader通过。"
      ]
    },
    {
      "id": "NEXT_CHAPTER_PREFETCH_REUSE",
      "title": "接近章末预加载下一章及跨章请求复用",
      "priority": "P2（当前P0后，与跨章联动核查）",
      "owner": "Root：鲜网络/ready采用范围冻结；仅自然inflight join边界待验",
      "dependencies": [],
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET",
        "CONTINUOUS_PERFORMANCE"
      ],
      "status": "预取505651f已推且CI成功；原14恢复完成，join边界开放",
      "kind": "open",
      "result": "d3187726含505651f精确CI40021847034 success；274已恢复原14（原2/15）并close成功。鲜网络/ready采用具名范围保留，inflight join仍未自然命中。",
      "remaining": "保fresh/ready有界结果冻结；inflight join待真实自然样本，不造并发/清缓存取证。",
      "reportedAt": "2026-10-23T05:33:34.382Z",
      "reportedAtSource": "原始会话JSONL response_item/user实值首报时间；疑重复请求是用户观察待验证。",
      "firstEvidenceAt": "2026-10-23T05:33:34.382Z",
      "firstHandlingAt": "2026-10-23T18:06:01.504859+00:00",
      "handling": {
        "measurement": "本轮已登记执行窗口，含分析/构建等待，不等同纯编码工时",
        "recordedSeconds": 1746.994985,
        "activeSince": "2026-10-23T18:40:19.657493+00:00",
        "activeUntil": "2026-10-23T18:55:19.657493+00:00",
        "note": "仅累计明确登记窗口；当前窗口从真实续接时刻起，空档不倒填。含构建/设备等待，非纯编码工时。"
      },
      "closedAt": null,
      "evidencePoints": [
        "265 fresh8/9下载与仅8读态、270章9 ready采用范围保持；274原14恢复为2/15并close成功。",
        "505651f已推且包含它的CI40021847034成功；不因提交/恢复关闭未自然命中的inflight join。"
      ],
      "remainingActions": [
        "保fresh/ready有界结果冻结；inflight join待真实自然样本，不造并发/清缓存取证。"
      ],
      "boundaries": [
        "只预取严格continuation的下一章，不用完整手选目录回退；至多一章、顺序暖不超过既有预加载页数。",
        "准备可以沿既有源页缓存落元数据，但不得提交当前章/阅读位置/历史；只在实际观测后按原路径提交读态。",
        "N/E不实现可选相邻单元预取则无新增网络；保Legacy及现有页内预加载，先查历史再改。"
      ]
    },
    {
      "id": "READER_PRESET_SHEET",
      "title": "点击预设后设置半模态被自行收起",
      "status": "具名实机通过，已随f7a6a7d提交推送并冻结",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [
        "READER_SETTINGS_STABILITY"
      ],
      "result": "具名实机通过，已随f7a6a7d提交推送并冻结",
      "remaining": "原具名验收范围冻结，不重复操作；未覆盖设置分支仅保边界，不以此自行扩成新矩阵。",
      "reportedAt": "2026-10-22T18:56:37.543Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:56:37.543Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "evidencePoints": [
        "197原预设切换录像已审：四菜单与位置保持，半模态不收起。f7a6a7d已推，CI39883471325成功。"
      ],
      "remainingActions": [
        "原具名验收范围冻结，不重复操作；未覆盖设置分支仅保边界，不以此自行扩成新矩阵。"
      ],
      "boundaries": []
    },
    {
      "id": "CONTINUOUS_PAGE_GAPS",
      "title": "连续滚动页间黑条",
      "status": "Chibi具名接缝通过，已提交推送并冻结",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "Chibi具名接缝通过，已提交推送并冻结",
      "remaining": "仅Chibi已审接缝冻结；其他内容范围未知不等于既有路径需重跑；性能另见独立项。",
      "reportedAt": "2026-10-22T19:43:05.108Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:43:05.108Z",
      "firstHandlingAt": "2026-10-22T20:00:18.424763+00:00",
      "handling": {
        "recordedSeconds": 521.015759,
        "activeSince": null,
        "activeUntil": null,
        "measurement": "本轮处理时段经过（含构建/设备等待，非纯工时）",
        "sharedSegment": "reader-three-fixes-20261022T200018",
        "note": "此段在具名结果登记后停止；三项共用时段不能相加，含构建/设备等待，纯处理工时未知。"
      },
      "closedAt": null,
      "firstHandlingAtSource": "Root实际开始消息后首次可核分段登记；更早处理起点未知。",
      "evidencePoints": [
        "Chibi连续模式2/3/4页接缝无额外黑条，返回链成功；原图reader-controls197-interaction-002/continuous-before.png。",
        "f7a6a7d已推，CI39883471325成功。仅该内容接缝冻结，性能另项维护。"
      ],
      "remainingActions": [
        "仅Chibi已审接缝冻结；其他内容范围未知不等于既有路径需重跑；性能另见独立项。"
      ],
      "boundaries": []
    },
    {
      "id": "READER_DIRECTION_MENU",
      "title": "阅读方向菜单混入单页/双页且重复布局入口",
      "status": "方向/独立单双页具名通过，f7a6a7d已推，CI成功",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "方向/独立单双页具名通过，f7a6a7d已推，CI成功",
      "remaining": "已具名动作/PNG冻结，不重跑；Legacy未改、运动区间未扩大。f7a6a7d精确CI39883471325已success，不等同后续WIP实机通过。",
      "reportedAt": "2026-10-22T19:43:05.108Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:43:05.108Z",
      "firstHandlingAt": "2026-10-22T20:00:18.424763+00:00",
      "handling": {
        "recordedSeconds": 521.015759,
        "activeSince": null,
        "activeUntil": null,
        "measurement": "本轮处理时段经过（含构建/设备等待，非纯工时）",
        "sharedSegment": "reader-three-fixes-20261022T200018",
        "note": "此段在具名结果登记后停止；三项共用时段不能相加，含构建/设备等待，纯处理工时未知。"
      },
      "closedAt": null,
      "firstHandlingAtSource": "Root实际开始消息后首次可核分段登记；更早处理起点未知。",
      "evidencePoints": [
        "LTR/RTL及独立单双页动作与原图已核，无该场景录像；原件diagnostics/reader-direction197-ltr-rtl-spread-003。",
        "f7a6a7d已推，CI39883471325成功；Legacy未改，运动范围未扩认。"
      ],
      "remainingActions": [
        "已具名动作/PNG冻结，不重跑；Legacy未改、运动区间未扩大。f7a6a7d精确CI39883471325已success，不等同后续WIP实机通过。"
      ],
      "boundaries": []
    },
    {
      "id": "TAB_HEADER_SCROLL_OWNER",
      "title": "根Tab标题栏模糊继承另一页状态",
      "status": "Library/Settings具名通过，a4ec2eb已提交冻结",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "Library/Settings具名通过，a4ec2eb已提交冻结",
      "remaining": "只冻结Library/Settings已审范围；其他Tab未覆盖，不从这项自动生成重复验收。",
      "reportedAt": "2026-10-22T19:36:59.975Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:36:59.975Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "evidencePoints": [
        "after-001全部442帧已审：滚动书架有模糊→设置顶部透明→切回书架恢复模糊；a4ec2eb限定修复已提交。"
      ],
      "remainingActions": [
        "只冻结Library/Settings已审范围；其他Tab未覆盖，不从这项自动生成重复验收。"
      ],
      "boundaries": []
    },
    {
      "id": "BAOZIMH_BROWSE_FAILURE",
      "title": "包子漫画安装后源浏览失败/重试无效",
      "status": "两书具名恢复/已推7b3f196，精确CI成功",
      "kind": "accepted",
      "priority": "P1",
      "owner": "Root：7b3f196实际push/精确CI；已过样本冻结",
      "dependencies": [
        "SOURCE_WEB_SESSION"
      ],
      "result": "包子两书详情、强刷与一书正文已恢复；挑战会话稳定性与自动成功回流仍由WEB项继续。",
      "remaining": "继续WEB项的会话revision、自动确认成功回流及自然失败恢复；重复章与排序分别维护。",
      "reportedAt": "2026-10-22T18:40:36.532Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:40:36.532Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reopenedAt": "2026-10-23T05:31:18.350Z",
      "latestCounterexampleAt": "2026-10-23T05:37:16.993Z",
      "feedbackReports": [
        {
          "reportedAt": "2026-10-23T05:37:16.993Z",
          "source": "原JSONL response_item/user",
          "summary": "网页完成后列表恢复、多详情失败部分有章、重入不恢复，缺不带缓存刷新；缓存根因未证。"
        }
      ],
      "evidencePoints": [
        "197034–038两书详情与强刷HTTP200，一书首图1/50及自然返回成立；原029–031重定向失败证据保留。",
        "7b3f196修session首跳拦截，保逐跳origin/cookie权限与failclosed；CI39910437371成功。书架无该书，不猜缓存fallback。"
      ],
      "remainingActions": [
        "继续WEB项的会话revision、自动确认成功回流及自然失败恢复；重复章与排序分别维护。"
      ],
      "boundaries": [
        "仅033–038两书与一书正文/返回冻结，不泛化所有书/源，不把所有403当CF或失败缓存。"
      ]
    },
    {
      "id": "SOURCE_RUNTIME_ERRORS",
      "title": "源错误只显示source_runtime且日志不可诊断",
      "status": "明确unsupported/限流别名已推且精确CI成功",
      "kind": "open",
      "priority": "P1",
      "owner": "Root：MH160014远端发布与普通更新；其他自然错误边界保留",
      "dependencies": [],
      "result": "保原237自然超时与abed388b范围；本次只补三个源既有错误码。95项Host/Release通过，554已安装且三业务域逐字同，556真实漫画160 get_image_request179字节响应诊断为not_implemented/unsupported。",
      "remaining": "rate_limit用户提示仅Host通过，未造限流；图片403、全局搜索自然失败及3H业务恢复仍按原边界。",
      "reportedAt": "2026-10-22T18:40:36.532Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:40:36.532Z",
      "firstHandlingAt": "2026-10-23T15:43:46.545761+00:00",
      "handling": {
        "measurement": "本次取页错误链处理时段，含等待，非纯工时",
        "recordedSeconds": 985.992951,
        "activeSince": null,
        "activeUntil": null,
        "note": "早期处理工时未知，不倒填。"
      },
      "closedAt": null,
      "relatedItems": [
        "SOURCE_WEB_SESSION"
      ],
      "evidencePoints": [
        "原005平台2300028与官方HTTP文档已亲核；仅此码返回timeout，未知码维持network_error。",
        "237004原图/日志已亲审：目录15149ms、取页15064ms均reason/error/kind=timeout、HTTP0，重试未点击。",
        "abed388b已推，CI39999131726成功；16项HTTP与22项分类测试通过。237原P3/230/History及10000ms恢复、租约已释放。",
        "3Hentai011的4d63235已推，CI40020264346 success；公开85索引011/三成员包Root读回执，Host边界保留，Native仍待。",
        "547真实漫画160 get_image_request 179字节结果被记为reason=unknown/error=unknown/kind=runtime；现源run_get_image_request明确返回not_implemented。mh160/manhuawu限流返回rate_limit，现白名单只接受rate_limited；SourceSettingsStore已接受not_implemented/not_supported。",
        "source-failure-alias两组29+66=95检查通过；8529046B签名Release/0.1.2-pre code3安装明确成功。556当前日志reason=not_implemented/error=not_implemented/kind=unsupported；未知私密code/message仍脱敏。",
        "560普通返回原详情784→源→书架；561 library/reader/registry与554安装后全部逐字同，无开书或手动重试。",
        "6ca1b69477a2bb9812b75b9c9b8fbc26e29d5ea0已push，精确CI40080793887 completed/success；无新tag/发布。",
        "572具名新反例：漫画160搜索底层HTTP403/5839chars且明确access_signal=challenge_required；源将其降成permission_denied/http0，manifest无webSessionOrigins，所以原生仅普通拒绝提示、未自动验证。571文本断言只命中SearchField，纠正文件保留。",
        "MH160014公开包22572B三成员与两个origin成立，579“已更新 漫画160”原图亲审；025按真实底栏恢复原Koma书架，581因同名“书架”两节点未点击，不当恢复证据。"
      ],
      "remainingActions": [
        "rate_limit用户提示仅Host通过，未造限流；图片403、全局搜索自然失败及3H业务恢复仍按原边界。",
        "MH160014/0a6ff4a已公开并正常更新；583一次普通元尊搜索保留HTTP403/明确challenge并自动弹出Web验证。584网页后来实际到/statics/search.aspx主框架404，尚不能接受搜索成功；587回书架，588三域与580逐字同。"
      ],
      "boundaries": [
        "首页/首搜/两书详情具名范围冻结；正常空结果、所有错误未扩认。漫画柜不能归因parser/CF；包子403性质按日志区分，不能仅HTTP即挑战。"
      ],
      "modificationBasis": {
        "object": "SourceRuntimeError已知错误白名单及类别分支",
        "history": "34ab280d引入结构化分类和保密白名单；SourceSettingsStore已接受两个unsupported别名。",
        "originalReason": "保留明确原因且不将源任意message/code泄露给用户或日志，HTTP明确状态优先。",
        "reopenEvidence": "547当前179字节not_implemented被落为unknown；现两个源rate_limit亦未被识别，和真实契约不一致。",
        "allowedDifference": "只补not_implemented/not_supported/rate_limit三个明确既有代码的对应类别，保原代码诊断、HTTP优先级、未知脱敏、UI布局及原有翻译。不得据此声称图片403或全源错误已修复。",
        "mh160Challenge": {
          "object": "mh160 fetch→detail/list/chapters/pages→execute的错误契约及源web-session-origins声明",
          "history": "bcfb9261引入源时以静态字符串丢弃HTTP状态；62a1d18只补URL，不改错误。现漫画屋已有类型化Http/Challenge传播，包子亦单独保明确访问信号。",
          "originalReason": "HTML解析错误与网络失败分开；403本身不推断CF，只有Host标准化挑战信号可触发。",
          "reopenEvidence": "572搜索Host原GET403/5839chars且access_signal=challenge_required，源operation却permission_denied/http0；源无webSessionOrigins。",
          "allowedDifference": "将真实HTTP状态与Host顶层明确challenge_required按类型传到既有错误envelope，并声明仅已使用的www.mh160mh.com/m.mh160mh.com两个HTTPS源origin。保URL、请求方法/次数/UA、站点选择、成功解析、章节身份/排序、图标及App版本；不把任意403或正文标记识别成CF。源小版本步进供正常远端更新。"
        }
      }
    },
    {
      "id": "SOURCE_WEB_SESSION",
      "title": "源网页挑战会话回流、源内设置及登录入口",
      "priority": "P1（明确必须做，原队列保留）",
      "owner": "Root：普通Web白屏有限阶段诊断；自动验证具名范围冻结",
      "dependencies": [],
      "status": "普通Web跨origin重复导航已实录；自动验证具名冻结",
      "kind": "open",
      "result": "537/538自动会话回流冻结。568/569漫画160普通Web一次初始调用后，原网址与另一个origin交替；18.662秒58个文档，前48条阶段未见资源错误；后续仅计数。48条阶段上限实录生效；正常返回且三业务域保持。白屏未修。",
      "remaining": "漫画160跨origin跳转具体站点链仍未知；源搜索挑战信号丢失按SOURCE_RUNTIME_ERRORS独立处理。其余CF人工验证/登录按自然样本保留，不无依据重复网页请求。",
      "reportedAt": "2026-10-23T01:44:08.576Z",
      "reportedAtSource": "原始会话JSONL response_item/user；明确必须做时间2026-10-23T01:46:03.842Z。",
      "requestedAt": "2026-10-23T01:46:03.842Z",
      "firstEvidenceAt": "2026-10-23T01:44:08.576Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reopenedAt": "2026-10-23T05:31:18.350Z",
      "feedbackReports": [
        {
          "reportedAt": "2026-10-23T05:31:18.350Z",
          "source": "原JSONL response_item/user",
          "summary": "包子仍403，自动半模态验证/人工勾选，手动菜单不成熟；隐藏WebView仅提议。"
        }
      ],
      "relatedItems": [
        "SOURCE_SETTINGS_DIRECT_ENTRY"
      ],
      "evidencePoints": [
        "476实机先主HTTP403后pageBegin清失败导致提前完成；clearance在Web/Native均present，未归因TLS。",
        "477同版本Release8528275B已装，75项Host检查通过；478/479前两失败文档保留，第三正常文档13:37:26.847自动完成，Native get_manga_list3703ms/HTTP200/49557chars、真实30本。",
        "原462/463包子自动no_clearance、464/465人工恢复200各自保留，不能用漫画屋成功关闭包子问题。",
        "021e1710已push；487终点library/reader/registry与477逐字同，486排序恢复完毕。精确CI40067742930 completed/success。",
        "488/489原生附会话但HTTP403/98chars；Web主框架revision1失败、revision2正常，baseline/request/current clearance均missing；未人工完成。",
        "491/492既有包子会话Native home/list五请求HTTP200，12本真实；clearance missing但没有触发挑战，不能算新自动探测分支验收。",
        "493/494/495最终候选普通包子首页及大奉详情/章节均200，真实696/696、原001第3/24页保持；493至495三业务域逐字同。未触发挑战，原GET验证分支仍不能写Native通过。",
        "496自然返回RootBrowse，无开书/人工完成/重试；497 library/reader/registry与493逐字同，AWAKE/override86400000。",
        "新重开依据534：15:46:16原生identity=native/session=none403，Web15:46:19 firstParty Cookie存在/无clearance且正常document结束，未触probe；534原图已亲看。尚未点完成/重试/清Cookie。",
        "改动依据218dd6ce原理由是额外Web失败证据；已有原GET probe会实测返回2xx且无challenge信号，并按源/包/设置/路由/原claim守卫，成功前不发grant，失败保手动/不循环。该真实反例不需Web再失败才测试原请求。",
        "535明确覆盖安装成功，Release8529158B/0.1.2-pre code3；挑战+会话93项与sheet9项Host通过，构建配置已恢复。",
        "537首次Native936ms/403，Web正常document且clearance missing；15:56:42原GET probe446ms/200，verification_response_reused used_once，get_home1974ms、get_manga_list621ms完成。535→538及544三业务域逐字同。",
        "922d153fcb7ae92a381e2607b86d35ae900a5e77已push，精确CI40077208291 completed/success；无tag/发布。",
        "当前新分支：557正确源URL打开WebView，558 Webbounds有效/站点标题存在但白屏；559等待31.290s加载指示仍在。没有DevTools socket，不启调试或换客户端。原MangaWebPage无持久阶段诊断，根因未知，不将入口成功冒网站可用。",
        "562 Release8540066B明确安装成功，首版11项Host通过；564原图白屏/真实Web几何且业务三域与562同。日志17:21:48.881一次start，至17:23:23.436为261begin/260end/65visible；无主/子resource_failed，标题已有站点名。565普通返回详情784→原书架。",
        "567 Release8539452B/0.1.2-pre code3明确安装，三域前后同；12项Host通过。569原始日志：revision奇数matchesInitialUrl/sameInitialOrigin均true，偶数均false；一次start，18.662s/58doc，48阶段+抑制标志+结束总51条。568普通Back到详情784再原书架，569三业务域与567逐字同。",
        "7b06ad5226b4ab0f96b020051036161f7170c290已push，精确CI40082499024 completed/success，无tag。",
        "583漫画160014普通搜索自动Web已实机出现，原生正确HTTP403与挑战提示；584原图网站/statics/search.aspx404，588日志主框架404及不同原请求origin/文档，未触原GET probe/未自动完成。未按完成重试；587正常回书架，588三域全同580。"
      ],
      "remainingActions": [
        "漫画160跨origin跳转具体站点链仍未知；源搜索挑战信号丢失按SOURCE_RUNTIME_ERRORS独立处理。其余CF人工验证/登录按自然样本保留，不无依据重复网页请求。",
        "漫画160本次自动弹出只接受触发；站点跳转到404原因、原搜索URL与实际网站路由继续核，不能称CF或搜索恢复。"
      ],
      "boundaries": [
        "漫画屋478/479与包子537/538自动回流分别具名成立；不外推全部CF、人工挑战、登录或正文。",
        "未改UI/UA/第三方Cookie策略；未清会话。原请求失败仍保人工入口且不循环；包/设置/路由/claim失效与离开回调守卫保持。",
        "document_visible仅官方“即将可见”事件，不是绘制证明；closed/partial只是网页离开状态，不作为站点成功。阶段诊断不记录URL、标题、HTML、headers或body。"
      ],
      "modificationBasis": {
        "object": "SourceWebSessionSheet与SourceRuntimeHttpTransport/SourceWebSessionStore的受限原请求验证",
        "history": "e839ec87仅识别标准cf_clearance；021e1710修正主文档错误时序，漫画屋已具名恢复。包子source access_signal只认顶层明确challenge_required/auth_required，不把403当CF",
        "originalReason": "不能凭网页内容或任意Cookie宣称通过；只能使用当前源明确授权origin与真实原失败请求",
        "reopenEvidence": "534真实正常Web已持站点会话但无CF Cookie，额外Web403前置使原GET验证不启动；与489先Web403的样本不同。",
        "allowedDifference": "只移除Web曾403前置；仍需当前有效原Native claim、同原URL/成功当前文档、已知Cookie基线且两侧无CF。成功必须由现有原GET验证2xx/非challenge证实，响应仅一次复用；UI、UA及数据格式保持。102项Host/Release与537/538具名实机已完成。",
        "webPageDiagnostics": {
          "object": "MangaWebPage标准ArkWeb回调及MangaWebView可选onPageVisible事件转发",
          "history": "53cbc39a沿NextE GalleryWebPage/EhWebView的完整Scaffold/List/Web与导航控件；当前onPageBegin/End/Error只更新原loading，没有持久阶段事实。",
          "originalReason": "保NextE原页面层次、加载和导航行为，不引入EH登录/UA逻辑；网页内容不写诊断。",
          "reopenEvidence": "558/559白屏31秒仍加载；564阶段日志进一步证实单次初始调用后重复文档导航。",
          "allowedDifference": "仅官方回调、初始URL/origin相等布尔、数值与临时操作号；25%桶、首子资源、单次操作最多48条阶段加抑制标志/结束汇总。保所有UI、loading、Web请求/UA/Cookie/权限；不抓网页内容或URL。"
        }
      }
    },
    {
      "id": "SOURCE_SETTINGS_ACTION_ALIGNMENT",
      "title": "源设置底部清除/保存按钮突兀且不齐",
      "priority": "P2（本sheet限定修正，不取消原队列）",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "status": "已验收+已推送，CI成功（冻结）",
      "kind": "accepted",
      "result": "源设置两动作的对齐、层级与保存退出已在237具名通过，提交及CI完成。",
      "remaining": "具名sheet范围冻结；后续仅实际新反例重开。",
      "reportedAt": "2026-10-23T02:58:58.381Z",
      "reportedAtSource": "原始会话JSONL response_item/user图反馈原文实际时间戳。",
      "firstEvidenceAt": "2026-10-23T02:58:58.381Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": "2026-10-23T03:38:15.620424+00:00",
      "evidencePoints": [
        "237保存绿按钮与卡片左右对齐，清除为居中红字；原图source-settings-buttons/sheet-after237-001，保存退出见sheet-save237-001。",
        "991309a已推，CI39895213060成功；仅本sheet的具名视觉与保存范围冻结。"
      ],
      "remainingActions": [
        "具名sheet范围冻结；后续仅实际新反例重开。"
      ],
      "boundaries": [
        "不外推其他页面或未验字段，不因旧“候选未应用/安装中”总述重开。"
      ]
    },
    {
      "id": "SOURCE_SETTINGS_DIRECT_ENTRY",
      "title": "当前源页应直接弹源设置，避免绕管理路由",
      "priority": "P2（入口行为，保P0优先）",
      "owner": "Root：三入口具名路径与精确CI已完成，未覆盖边界保留",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_WEB_SESSION",
        "SOURCE_SETTINGS_ACTION_ALIGNMENT"
      ],
      "status": "三入口限定验收完成，精确CI成功",
      "kind": "accepted",
      "result": "源浏览与独立源搜索直接弹出原设置表单；原管理入口保持。197保存刷新、关闭返回及测试设置恢复已核。",
      "remaining": "本次三入口具名范围冻结；非空查询保存、其他源字段类型未扩认。",
      "reportedAt": "2026-10-23T05:31:55.042Z",
      "reportedAtSource": "原始会话JSONL response_item/user口语原文时间；“源设置/源包管理”是结合上下文的当前暂解，待源码确认。",
      "firstEvidenceAt": "2026-10-23T05:31:55.042Z",
      "firstHandlingAt": "2026-10-23T13:32:30.338132+00:00",
      "handling": null,
      "closedAt": "2026-10-23T14:17:47.457815+00:00",
      "evidencePoints": [
        "197138源浏览直弹，140保存后仍原源页并刷新；143正常确认清除，144设置JSON与139原空sources完全一致。",
        "146原管理设置开关返回原源详情；149独立源搜索开关设置，NavDestination恒1。151正常返回书架，猎行者15页94%保持。",
        "38项相关检查与8组生产方法行为检查通过；197已安装验收。296c7b3及进度页4efd4bdc已推，CI39968459689成功。"
      ],
      "remainingActions": [
        "本次三入口具名范围冻结；非空查询保存、其他源字段类型未扩认。"
      ],
      "boundaries": [
        "原按钮991309a几何与样式冻结，只取消管理页中转。离页/晚回调作废；不回灌设置、不清用户数据，不把138取消后的403当自动弹失败。",
        "144内容恢复不证明自动完成Web会话：当时未点完成并重试，也未实现自动判断；不能当作新候选的自然挑战验收。"
      ]
    },
    {
      "id": "SOURCE_INDEX_PROGRESSIVE",
      "title": "首次远端索引长空白，需逐项异步显示",
      "status": "r3具名通过，4b878926已推且精确CI成功",
      "kind": "accepted",
      "priority": "P2",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "现有profile的远端列表先出现、图标渐进补齐且文字稳定；普通源包更新通过。",
      "remaining": "当前普通latest范围冻结；仅后续真实新反馈或自然失败补验证。",
      "reportedAt": "2026-10-22T18:37:17.168Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:37:17.168Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "references": [
        "https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-foreach"
      ],
      "evidencePoints": [
        "197 r3完整131帧已审：列表/部分图先出，其余图标随后补齐，未再位移或裁字；原件public-load-prefix-recording197-003。",
        "普通latest包子0.1.2→0.1.4更新成功。4b878926已推、CI39898097341成功，无新tag。",
        "r2裁切反例保留于public-load-fixed-recording197-001；不能用当前profile通过代替全新无缓存/慢/失败/换URL边界。"
      ],
      "remainingActions": [
        "当前普通latest范围冻结；仅后续真实新反馈或自然失败补验证。"
      ],
      "boundaries": [
        "首次全新无缓存、慢/失败/换URL未作实机扩大，4行为检查仅证方法边界。不清缓存或造故障重跑。"
      ]
    },
    {
      "id": "SEARCH_DETAIL_TITLE",
      "title": "全局搜索进详情显示未命名漫画",
      "status": "两作品标题/返回具名通过，868dbb38 CI成功",
      "kind": "accepted",
      "priority": "P2",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "两作品标题/返回具名通过，868dbb38 CI成功",
      "remaining": "两作品/当前普通入口标题与返回范围冻结，868dbb38精确CI39885312214/head868dbb38已success；不重复跟已完成CI，不扩大所有源/作品。",
      "reportedAt": "2026-10-22T19:05:54.248Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:05:54.248Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "evidencePoints": [
        "197两作品详情标题和自然返回不串已审，原图global-title197-detail-002/detail.png；868dbb38及CI39885312214成功。"
      ],
      "remainingActions": [
        "两作品/当前普通入口标题与返回范围冻结，868dbb38精确CI39885312214/head868dbb38已success；不重复跟已完成CI，不扩大所有源/作品。"
      ],
      "boundaries": []
    },
    {
      "id": "CHAPTER_PICKER_POSITION",
      "title": "阅读器章节选择器每次从顶部动画滚到当前章",
      "status": "197首开/手动保位通过，1e163c3e精确CI成功",
      "kind": "accepted",
      "priority": "P2",
      "owner": "冻结路径：无当前执行者",
      "dependencies": [],
      "result": "已补打开期间实际布局校正；Extra2首开可见，手动Booklet3关开位置相同，原章页保持。",
      "remaining": "197具名范围冻结；不外推旋转、字号或档位拖动。",
      "reportedAt": "2026-10-22T19:45:43.075Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:45:43.075Z",
      "firstHandlingAt": "2026-10-22T20:00:18.424763+00:00",
      "handling": {
        "recordedSeconds": 3978.374463,
        "activeSince": null,
        "activeUntil": null,
        "measurement": "本轮处理时段经过（含构建/设备等待，非纯工时）",
        "sharedSegment": "reader-three-fixes-20261022T200018",
        "note": "本段在具名保位结果登记后停止；有效窗之外未补计，含构建/设备等待非纯工时。"
      },
      "closedAt": "2026-10-23T15:43:46.545761+00:00",
      "firstHandlingAtSource": "Root实际开始消息后首次可核分段登记；更早处理起点未知。",
      "reopenedAt": "2026-10-23T04:56:52.153Z",
      "reopenedAtSource": "原始会话JSONL response_item/user当前定位反例首报实值。",
      "evidencePoints": [
        "旧f7a6a7dc仅initialIndex；163/164复现末段不可见。1e163c3e已推，CI39979645515成功。",
        "166–169：签名Release已装；104编码帧按序及关键原尺寸帧已审，Extra2首开可见，无从顶部追章动画。",
        "169手动Booklet3关开均1664–1725px；170整库全同，reader仅正常updatedAt变化，章页/已读/缓存保持。"
      ],
      "remainingActions": [
        "仅真实新反例或相关依赖变化重开。"
      ],
      "boundaries": [
        "仅197/1260×2720/76章末段与手动位置；未扩认旋转、字号或档位拖动，不改原样式/目录/阅读规则。"
      ]
    },
    {
      "id": "SOURCE_FILTERS",
      "title": "已批准源筛选行为的当前设备路径",
      "status": "已过切换路径冻结，自然失败分支待条件",
      "kind": "open",
      "result": "已过切换路径冻结，自然失败分支待条件",
      "remaining": "普通/快速切换已过不重跑；自然失败重试仅待实际样本，不为获取样本清数据/造故障或重复请求。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "Root / 197（等待自然失败样本）",
      "evidencePoints": [
        "197 MangaDex连续切换All→Completed→Ongoing，最终值与列表一致；127帧已审，原全部筛选与Relevance排序已恢复。"
      ],
      "remainingActions": [
        "普通/快速切换已过不重跑；自然失败重试仅待实际样本，不为获取样本清数据/造故障或重复请求。"
      ],
      "boundaries": []
    },
    {
      "id": "SHARED_ROUTE",
      "title": "普通共享阅读入口",
      "status": "普通入口具名通过",
      "kind": "accepted",
      "result": "普通入口具名通过",
      "remaining": "不扩大到四私库或所有内容；四私库PARKED_USER。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "44a86da1已接普通Shared，源/本地/历史/进度/切章/按书设置/返回及下载管理具名通过。"
      ],
      "remainingActions": [
        "不扩大到四私库或所有内容；四私库PARKED_USER。"
      ],
      "boundaries": []
    },
    {
      "id": "ICONS",
      "title": "完整书源图标质量",
      "status": "用户确认完成",
      "kind": "accepted",
      "result": "用户确认完成",
      "remaining": "不自主重开已关闭图标；官方高清原件的出处限制仍如实保留。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "用户明确图标任务已完成；源后继图标及K应用图标按顶部具名结果交付。"
      ],
      "remainingActions": [
        "不自主重开已关闭图标；官方高清原件的出处限制仍如实保留。"
      ],
      "boundaries": []
    },
    {
      "id": "SYNC",
      "title": "现有主分支远端同步",
      "status": "版本/tag/CI/预发布均已完成",
      "kind": "accepted",
      "result": "版本/tag/CI/预发布均已完成",
      "remaining": "v0.1.2-pre发布任务冻结；后续197已安装0.1.2-pre/code3见本轮条目，旧“新版未安装”已不适用，不把后续修复自动视为已发布。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": "2026-10-20T13:40:29.817024+00:00",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "4bf22c66分支CI39828487326及tag CI39829003869均success；v0.1.2-pre为非草稿预发布，两附件公开可读且正文相同。"
      ],
      "remainingActions": [
        "v0.1.2-pre发布任务冻结；后续197已安装0.1.2-pre/code3见本轮条目，旧“新版未安装”已不适用，不把后续修复自动视为已发布。"
      ],
      "boundaries": []
    },
    {
      "id": "BACKUP_LOCAL",
      "title": "本地未加密备份创建与预览",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "自然失败回滚、其他备份与跨设备仍未验；不外推全库所有字段相同。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": "2026-10-19T22:26:49Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "197获准快照真实恢复及不清数据冷启动后，书架/历史/下载/79源包已读回；原四备份保留，仅本轮快照清理。"
      ],
      "remainingActions": [
        "自然失败回滚、其他备份与跨设备仍未验；不外推全库所有字段相同。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_READER_TAPS",
      "title": "1700页归档点击未翻页",
      "status": "原误报已澄清",
      "kind": "accepted",
      "result": "原误报已澄清",
      "remaining": "不扩大到其他模式完整验收。",
      "reportedAt": null,
      "reportedAtSource": "本轮普通路径实际观察，不猜原始出现时间。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "当前拆宽页偏好下显示单元切换而源页码可不变；两次点击真实进入下一源页，临时日志与测试条目已清。"
      ],
      "remainingActions": [
        "不扩大到其他模式完整验收。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_ARCHIVE",
      "title": "本地CBZ导入与进度重开",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不扩大为ZIP/其它格式、全部内容或Shared；两侧点击原误报已由同页宽图左右半原件澄清。",
      "reportedAt": null,
      "reportedAtSource": "本轮普通路径实际观察。",
      "firstEvidenceAt": null,
      "closedAt": "2026-10-19T23:20:11Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "导入、首图、纵向翻页、同进程及真实冷启动后第2页重开均实际观察；本轮条目已移出。"
      ],
      "remainingActions": [
        "不扩大为ZIP/其它格式、全部内容或Shared；两侧点击原误报已由同页宽图左右半原件澄清。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_IMAGES",
      "title": "两张既有图片普通导入",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不冒独立顺序绑定、图片分支cold或全部格式通过。",
      "closedAt": "2026-10-19T23:39:24Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "两页真实内容、左侧点击翻页、同进程重开及仅本轮书架条目移出已观察，原排序已恢复。"
      ],
      "remainingActions": [
        "不冒独立顺序绑定、图片分支cold或全部格式通过。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_RESCAN",
      "title": "本地重扫与自然重选分支",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "自然失效根仍为不可经系统选择器选取的旧私有Smoke根；新增/变更/缺失输入未有当前样本，不造夹具。",
      "closedAt": "2026-10-19T23:39:24Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "原两根一重扫一需重选；取消系统选择器后原书与进度保持。Nemo单根重扫计数均0、原2章和第2页保持。",
        "后继重选同一公共根：0新增/变更/缺失、跳过3、无重复；75本与进度内容相同，Nemo继续2/3页保持。"
      ],
      "remainingActions": [
        "自然失效根仍为不可经系统选择器选取的旧私有Smoke根；新增/变更/缺失输入未有当前样本，不造夹具。"
      ],
      "boundaries": []
    },
    {
      "id": "SETTINGS_SEARCH",
      "title": "设置搜索的实际消费者",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "仅中文该查询/目的页，不冒全部语言或设置生效。",
      "closedAt": "2026-10-19T23:45:59Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "缓存上限查询返回、进入存储显示原500MB、返回查询清空已观察。"
      ],
      "remainingActions": [
        "仅中文该查询/目的页，不冒全部语言或设置生效。"
      ],
      "boundaries": []
    },
    {
      "id": "OPEN_SOURCE_NOTICE",
      "title": "开源声明占位内容",
      "status": "已批准并具名验收",
      "kind": "accepted",
      "result": "已批准并具名验收",
      "remaining": "不冒所有语言设备或全部许可合规审计。",
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "be57e585已替换三语占位为实际依赖及完整原许可；197中文普通弹窗滚动到Lexbor末尾并返回。"
      ],
      "remainingActions": [
        "不冒所有语言设备或全部许可合规审计。"
      ],
      "boundaries": []
    },
    {
      "id": "CATEGORY_LIFECYCLE",
      "title": "分类管理普通操作",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不扩大到多书替换、迁移或失败回滚。",
      "closedAt": "2026-10-19T23:55:31Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "本轮0本书空分类已创建、改名并经准确名称确认删除，两处名称同步；四个原内置分类和原书架保持。 后续237普通单书加入/移出/筛选、两次不清数据cold及测试分类清理已具名通过。"
      ],
      "remainingActions": [
        "不扩大到多书替换、迁移或失败回滚。"
      ],
      "boundaries": []
    },
    {
      "id": "KAVITA_HISTORY",
      "title": "已配置Kavita普通阅读与历史重开",
      "status": "PARKED_USER：只待用户明确重提",
      "kind": "parked",
      "result": "PARKED_USER：只待用户明确重提",
      "remaining": "四私库实际验收已被人类明确搁置；不由heartbeat、旧记录或交接自主复活。",
      "closedAt": null,
      "owner": "PARKED_USER：等待用户重提",
      "evidencePoints": [
        "普通浏览无法加载；原Kavita容器exited且两原bind源不存在，25610转发无监听；Docker守护进程已恢复，未启动空数据容器或改凭据。"
      ],
      "remainingActions": [
        "四私库实际验收已被人类明确搁置；不由heartbeat、旧记录或交接自主复活。"
      ],
      "boundaries": []
    },
    {
      "id": "WEBTOON_READING",
      "title": "WEBTOON繁中普通公开阅读",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "全章、下载与Shared不在本次通过范围；分季标题未解析话数，稳定原序保持。",
      "closedAt": "2026-10-20T00:20:25Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "热门30本、目录255章；第2季第65話106页的原首图和第2页正文、同进程继续阅读及PID11467→空→30362后历史2/106重开。"
      ],
      "remainingActions": [
        "全章、下载与Shared不在本次通过范围；分季标题未解析话数，稳定原序保持。"
      ],
      "boundaries": []
    },
    {
      "id": "BROWSE_HEADER_REFRESH",
      "title": "书源分页后的当前数据刷新",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不扩大为所有源与全部失败状态。",
      "closedAt": "2026-10-20T00:35:00Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "HKO六本标题由旧2修正为6；DM5首页分组及最新导航70本正常。样式、文案模板、行key和网格保持。"
      ],
      "remainingActions": [
        "不扩大为所有源与全部失败状态。"
      ],
      "boundaries": []
    },
    {
      "id": "BACKUP_ENCRYPTED",
      "title": "本地加密备份创建与预览",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "恢复、失败回滚与cold不在本次通过范围。",
      "closedAt": "2026-10-20T00:44:00Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "197本地加密文件创建，认证预览75书架/83进度，未执行恢复；仅删本轮1792456763593并读回四原备份。"
      ],
      "remainingActions": [
        "恢复、失败回滚与cold不在本次通过范围。"
      ],
      "boundaries": []
    },
    {
      "id": "APPEARANCE_CONSUMERS",
      "title": "主题、强调色和语言实际消费者",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不扩大全部主题色、语言、页面或系统语言变化；自动章数后继已按批准接入语言资源并具名验收。",
      "reportedAt": null,
      "reportedAtSource": "本轮普通路径实际观察。",
      "firstEvidenceAt": "2026-10-20T14:31:54.915842+00:00",
      "closedAt": "2026-10-20T14:31:54.915842+00:00",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "197普通菜单深色/海蓝/English实际影响外观与书架，PID54198→空→63980后保持；原跟随系统/翠绿/跟随系统及设备超时已恢复。"
      ],
      "remainingActions": [
        "不扩大全部主题色、语言、页面或系统语言变化；自动章数后继已按批准接入语言资源并具名验收。"
      ],
      "boundaries": []
    },
    {
      "id": "LIBRARY_COUNT_I18N",
      "title": "英文书架自动章节数量单位",
      "status": "已按人类批准实施并具名验收（既有记录）",
      "kind": "accepted",
      "result": "已按人类批准实施并具名验收（既有记录）",
      "remaining": "不外推所有页面/语言/源自带副标题。",
      "reportedAt": null,
      "reportedAtSource": "本轮实机新反例，不猜原提出时间。",
      "firstEvidenceAt": "2026-10-20T14:31:54.915842+00:00",
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "当前会话已有明确批准；工作单既有197记录中文话与英文chapter/chapters实际消费者通过，本轮不重跑。"
      ],
      "remainingActions": [
        "不外推所有页面/语言/源自带副标题。"
      ],
      "boundaries": []
    },
    {
      "id": "CATALOG197",
      "title": "完整手动章节目录当前路径",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "仅当前版本/样本，不外推未验分支。",
      "closedAt": "2026-10-21T01:43:46.574409+00:00",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "676/676章、降序2978/升序1、已下载仅原2978；未开章/下载/标读，原书架保持。"
      ],
      "remainingActions": [
        "仅当前版本/样本，不外推未验分支。"
      ],
      "boundaries": []
    },
    {
      "id": "FOLDER_REIMPORT197",
      "title": "既有公共根重复导入",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "仅当前版本/样本，不外推未验分支。",
      "closedAt": "2026-10-21T01:43:46.574409+00:00",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "Native实际重扫，0新增/变更/缺失，跳过3，无重复，原75本及进度内容相同；Nemo2章/2页保持。"
      ],
      "remainingActions": [
        "仅当前版本/样本，不外推未验分支。"
      ],
      "boundaries": []
    },
    {
      "id": "MONITOR_AVAILABILITY",
      "title": "原工作监控页8766服务无法打开",
      "priority": "P2（工具可达性，不抢产品主线）",
      "owner": "feedback_registry",
      "dependencies": [],
      "status": "原服务已恢复，本机HTTP及原浏览器通过",
      "kind": "accepted",
      "result": "原8766页面及/api/progress均HTTP200；本轮重新逐字段核对，页面实际返回与唯一snapshot的65项完全一致。反馈项未发现缺失，顶部HAP和源摘要的旧状态已纠正。",
      "remaining": "随实际结果同步条目、主页摘要、当前包和下一动作；原已验证页面结构保持。",
      "reportedAt": null,
      "reportedAtSource": "Root转交用户当前无法打开反馈；原始人类提出的精确时间未核实，不猜填。",
      "firstEvidenceAt": "2026-10-23T00:53:09.114846+00:00",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": "2026-10-23T00:53:09.114846+00:00",
      "evidencePoints": [
        "原进度页沿用8766，服务每次请求读取CURRENT_STATUS，页面3秒轮询且no-store。",
        "本轮本机HTTP根页/API均200，API与磁盘snapshot每个字段完全一致，65项ID保持。",
        "发现并纠正主页“455结果未知”和旧漫画屋403摘要；未把列表/详情恢复扩成正文或fresh自动验证通过。"
      ],
      "remainingActions": [
        "随实际结果同步条目、主页摘要、当前包和下一动作；原已验证页面结构保持。"
      ],
      "boundaries": [
        "8766仅本机访问；服务恢复不等同系统自启动或崩溃自动重启，当前退出原因未知。"
      ]
    },
    {
      "id": "CBZ_IMAGE_ORIENTATION",
      "title": "导入CBZ部分图片颠倒的第三方反馈",
      "priority": "P3（用户明确低优先级）",
      "owner": "Root：后继只读分析，真实样本待提供",
      "dependencies": [],
      "status": "P3只读分析完成，实际样本未验",
      "kind": "open",
      "result": "缺实际CBZ，未复现；已发现EXIF方向处理不一致的条件风险，仍为P3只读结论。",
      "remaining": "等待真实样本再确认本次反馈原因；后继实施需共同处理正文/尺寸/裁切/缩略图。",
      "reportedAt": "2026-10-23T01:59:16.553Z",
      "reportedAtSource": "原始会话JSONL response_item/user实际时间戳；第三方用户反馈由当前用户转述。",
      "firstEvidenceAt": "2026-10-23T01:59:16.553Z",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "references": [
        "https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-image#orientation14"
      ],
      "evidencePoints": [
        "无实际CBZ，尚未复现。正文、尺寸、裁切、缩略图当前未统一EXIF方向，只读发现条件风险，未改源码。",
        "官方Image文档orientation14：默认UP按像素，AUTO读取EXIF及镜像；不能据此认定用户样本根因。"
      ],
      "remainingActions": [
        "等待真实样本再确认本次反馈原因；后继实施需共同处理正文/尺寸/裁切/缩略图。"
      ],
      "boundaries": [
        "源码未改，不把条件风险称用户根因；不造合成样本冒实机复现、不全局转180度、不抢当前高优先事项。"
      ]
    },
    {
      "id": "SOURCE_README_USER_GUIDE",
      "title": "重新整理koma-sources用户README",
      "priority": "待分配（本次未指定）",
      "owner": "/root/koma_sources_readme（已完成）",
      "dependencies": [],
      "status": "已完成，9243deb CI通过",
      "kind": "accepted",
      "result": "已完成，9243deb CI通过",
      "remaining": "本轮README整理范围已完成并冻结；后续仅随真实源发布/用户反馈按需更新，不重开已完成整理。",
      "reportedAt": null,
      "reportedDate": "2026-10-23",
      "reportedAtSource": "本次人类消息；提出日期为2026-10-23，未提供精确时分秒，不猜填。",
      "firstEvidenceAt": "2026-10-23T03:16:03.446263+00:00",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "evidencePoints": [
        "README面向用户整理为86行，85源核实；9243deb已提交，CI39894595111成功。"
      ],
      "remainingActions": [
        "本轮README整理范围已完成并冻结；后续仅随真实源发布/用户反馈按需更新，不重开已完成整理。"
      ],
      "boundaries": []
    },
    {
      "id": "SOURCE_PACKAGE_INSTALL_LIST_UI",
      "title": "源包管理按软件安装列表整理版本、动作、分组及标记",
      "priority": "P2（保当前P0不抢占）",
      "owner": "Root：已验列表范围同步；具体筛选方案后继",
      "dependencies": [],
      "status": "公共组件/有效修复已推，本笔精确CI成功",
      "kind": "open",
      "result": "公共2c05ea6c、源更新f4caffaa与65项工作单876b435f已推；精确CI40033988416/head876b435f成功，unsigned Release成功，tag发布跳过，无新发版。",
      "remaining": "未验迁移页面/其他缺陷继续原项；本笔CI已完，不因构建成功关闭未验边界。",
      "reportedAt": "2026-10-23T05:28:39.778Z",
      "reportedAtSource": "原始会话JSONL response_item/user实际时间戳；方向原文已核，不猜开始时间/耗时。",
      "firstEvidenceAt": "2026-10-23T05:28:39.778Z",
      "firstHandlingAt": "2026-10-23T16:00:12.538712+00:00",
      "handling": {
        "measurement": "本轮共享验证经过，含构建/设备等待，两个并行条目时段不可相加为纯工时",
        "recordedSeconds": 4956.592758,
        "activeSince": null,
        "activeUntil": null,
        "note": "只计已登记窗口，工具/上下文空档不倒填。"
      },
      "closedAt": null,
      "evidencePoints": [
        "283最终图可更新/未安装/已安装分组均核，281→283库/reader/registry字节相同；不是拿280旧候选代最终。",
        "284正常全部更新后285仍80源、仅com.hentai3变011/70388B/enabledtrue，library/reader同值；未声称3H正文可用。",
        "286书架设置、288分类三组全图已审；共同9源码2c05ea6c当时本地，现已随876b435f推送，其他迁移路径未扩大。"
      ],
      "remainingActions": [
        "未验迁移页面/其他缺陷继续原项；本笔CI已完，不因构建成功关闭未验边界。"
      ],
      "boundaries": [
        "失败候选及脚本错误原件保留：191副行不可见、193字号偏小均已撤；199错误选择器与202未滚入安装组的等待不冒产品故障。",
        "HDS拥有卡片、图标、后缀按钮和点击；只用官方B区Text/Span扩展，不覆盖像素，不改其他普通行或素材。",
        "全部更新只触发各源任务；等待中/更新中/完成由各源维护，不使用全局批量busy禁用其他行。",
        "按钮使用已批准绿色与既有字号/边距；任务文案固定及各源独立状态/串行lane保持。",
        "当前新增授权允许源管理三组header+对应卡片同一ListItem/Column，组内4、组间12；不以旧局部范围阻挡本次明确新增授权。",
        "保既有SectionHeader字号/左右及原生绿Button，不改其他页面、卡片/行或队列行为。",
        "当前用户公共封装要求允许普通分组统一至共同组件；不继续页面临拼，保原几何和业务状态。",
        "特殊搜索结果标题、章节ListItemGroup、源首页及备份多段说明不强套普通卡片；方法/build不替代可见验收，不宣称全App通过。"
      ]
    },
    {
      "id": "SOURCE_CHAPTER_DUPLICATE_TITLE_REVIEW",
      "title": "两书目录顶部同标题章节重复现象调查",
      "priority": "P2（目录身份只读核查）",
      "owner": "source_unknown_metadata：parser精确重复/冲突保留；Root：实机与诊断提交",
      "dependencies": [],
      "relatedItems": [
        "FIRST_CHAPTER_SELECTION",
        "CHAPTER_SORT_MENU"
      ],
      "status": "015精确重复合并197已验，远端CI发布完成",
      "kind": "done",
      "result": "包子015精确重复合并后197目录206/206且旧阅读位置保留；输出ID冲突不等于真实同章。",
      "remaining": "本具名精确重复范围冻结；仅新的输出身份冲突反例重开。",
      "reportedAt": null,
      "reportedAtSource": "Root本轮调查回传，未给原始提出精确时间，不猜填。",
      "firstEvidenceAt": "2026-10-23T06:17:05.337142+00:00",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "evidencePoints": [
        "原输出ID重复24不证明真实同章；只合并slot+原href+标题及输出字段全同的精确重复，身份冲突保留。",
        "197 baozi015-session197-detail-061：206章/唯一ID206/重复0，原1/50进度保持；54d04dc7与CI39914449810成功。"
      ],
      "remainingActions": [
        "本具名精确重复范围冻结；仅新的输出身份冲突反例重开。"
      ],
      "boundaries": [
        "不得按标题、仅输出ID或统计24直接删除条目；href/title或输出字段冲突必须保留。"
      ]
    },
    {
      "id": "MANGA_DETAIL_PULL_REFRESH",
      "title": "漫画详情页接入下拉刷新",
      "priority": "P2（当前P0后，与源详情失败恢复关联）",
      "owner": "Root：源样本范围冻结；自然失败/挑战按原项保留",
      "kind": "open",
      "status": "源详情具名下拉/保内容/进度197通过；其余自然分支待",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS",
        "SOURCE_WEB_SESSION"
      ],
      "result": "漫画1234已有详情下拉强刷、内容连续显示与原阅读进度在197具名通过；其余自然分支未扩认。",
      "remaining": "该源样本强刷范围冻结；本地检查、自然失败/挑战分支待自然条件。",
      "reportedAt": null,
      "reportedDate": "2026-10-23",
      "reportedAtSource": "最新人类消息原文；未提供精确时间，不猜填。",
      "firstEvidenceAt": null,
      "firstHandlingAt": "2026-10-23T11:26:44.075783+00:00",
      "closedAt": null,
      "evidencePoints": [
        "197114完整217帧已审：详情/目录持续可见，仅单一刷新位移；真实详情与章节各请求一次200，458章保持。",
        "113原15/16与117书架15页94%均保持；746e3b8e已推，CI39950964499成功。沿原唯一List/Scroller，未清内容或缓存。"
      ],
      "remainingActions": [
        "该源样本强刷范围冻结；本地检查、自然失败/挑战分支待自然条件。"
      ],
      "boundaries": [
        "不造故障或清Cookie取样；本地归档不冒重解压，私库不新增请求或复活验收。保原父树/裁切/间距/内容及进度。"
      ]
    },
    {
      "id": "LIST_EDGE_SCROLL_FEEL",
      "title": "普通列表头尾回弹及短列表始终允许滚动",
      "priority": "P2（当前连续性能P0后）",
      "owner": "Root：普通List/Grid具名范围冻结；Modal内部边界保留",
      "kind": "open",
      "status": "长短普通List与书架Grid具名运动通过；Modal嵌套证据有边界",
      "dependencies": [],
      "relatedItems": [
        "MANGA_DETAIL_PULL_REFRESH"
      ],
      "reportedAt": null,
      "reportedDate": "2026-10-23",
      "reportedAtSource": "最新用户原文，无精确提出时间，不猜填。",
      "firstEvidenceAt": null,
      "firstHandlingAt": "2026-10-23T10:54:45.461347+00:00",
      "closedAt": null,
      "result": "普通长短List及书架Grid顶部的回弹具名成立；Modal录像仅证明系统sheet接管，未证明内部短List。",
      "remaining": "普通具名范围冻结；后继仅有真实需要时核Modal内部短列表和Grid底部。",
      "evidencePoints": [
        "197116长List、117三行短List、118书架Grid顶部的完整运动已审，标题/底栏及偏好保持；746e3b8e CI成功。",
        "119只证明系统sheet接管缩放，不能当内部短List回弹通过；误开菜单后120正常Back恢复，原录像保留。",
        "普通列表spring+alwaysEnabled，PullRefresh内保None避免双位移；阅读器正文和专门手势未改。"
      ],
      "remainingActions": [
        "普通具名范围冻结；后继仅有真实需要时核Modal内部短列表和Grid底部。"
      ],
      "boundaries": [
        "不外推每页、私库或阅读器正文，不为凑矩阵重复测试。保几何/方向/位置；自定义PullRefresh是唯一边缘位移owner。"
      ]
    },
    {
      "id": "TAB_ICON_SELECTION_FEEDBACK",
      "title": "主页Tab选中填充图标与点击弹跳",
      "priority": "P1（Tab切换动效新反例）",
      "owner": "Root：跨Tab动效具名完成并冻结；后继只按新反例重开",
      "kind": "open",
      "status": "跨Tab具名动效已推，精确CI成功",
      "result": "b8a50cf已push，精确CI40015663006 success；243完整539PTS四跨选形变/回稳具名成立，原重复段与底栏范围保持。",
      "remaining": "本具名动效范围冻结；不外推所有输入或显示FPS。",
      "reportedAt": null,
      "reportedDate": "2026-10-24",
      "reportedAtSource": "最新两条人类消息；无精确提出时分秒，不猜填。",
      "firstEvidenceAt": "2026-10-23T16:08:13.970445+00:00",
      "firstHandlingAt": "2026-10-23T16:16:13.824783+00:00",
      "handling": {
        "measurement": "本轮共享验证经过，含构建/设备等待，两个并行条目时段不可相加为纯工时",
        "recordedSeconds": 2572.793558,
        "activeSince": null,
        "activeUntil": null,
        "note": "只计已登记窗口，工具/上下文空档不倒填。"
      },
      "closedAt": null,
      "evidencePoints": [
        "library约0.18–0.5秒、history3.84–4.2秒、settings7.17–7.6秒、browse10.8–11.2秒均见选中symbol形变/回稳。",
        "243完整539原PTS与10张底栏全帧联系表Root已顺审；重复当前Tab段单独保留，不混成跨Tab证据。"
      ],
      "remainingActions": [
        "本具名动效范围冻结；不外推所有输入或显示FPS。"
      ],
      "boundaries": [
        "只重开跨Tab弹跳动效，不重开填充或普通源图标已验范围；底栏结构、文字、尺寸、颜色及根导航/滚动所有权保持。",
        "箭头/语言、安装安全队列、无设置入口、预加载与Browse原队列均保留。"
      ],
      "firstHandlingAtSource": "当前实现/构建结果首次登记，非精确编码开始时间；此前时段未知。",
      "priorAcceptedScope": {
        "status": "197具名验收完成并已推，精确CI成功",
        "closedAt": "2026-10-23T17:28:46.334448+00:00",
        "scope": "填充切换、同Tab重复点击及原具名普通导航范围；新跨Tab动效反例独立重开。"
      },
      "reopenedAt": null,
      "reopenedDate": "2026-10-24",
      "reopenedAtSource": "最新人类实测反例，无可信原始UTC精确时刻，不以登记时刻冒充。",
      "feedbackReports": [
        {
          "reportedAt": null,
          "reportedDate": "2026-10-24",
          "source": "最新人类实测，无可信精确UTC",
          "summary": "底栏切至其他Tab无弹跳，仅重复点已选Tab有。"
        }
      ]
    },
    {
      "id": "CMANHUA_ZH_ICON_REGRESSION",
      "title": "創漫繁中图标回退为默认菱形",
      "priority": "P1（已交付图标的新具名回退）",
      "owner": "Root：197普通更新与采用验收；源owner只读发布侧核查已完成",
      "dependencies": [],
      "relatedItems": [
        "ICONS",
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "accepted",
      "status": "197旧包缺图经正常更新恢复，具名范围冻结",
      "result": "197旧010安装包缺图，正常更新012后浏览显示既定蓝白W；未证实远端资源曾回退。",
      "evidencePoints": [
        "207实时registry：exact源仍010/backup-47且无packageIconPath；远端012包/索引正确，源owner核51f73c0素材无撤销。",
        "210只执行一次正常更新；211为012且iconPath存在，212浏览蓝白W已亲审；213已装图标字节同远端，库/reader完整JSON同207。",
        "210脚本误用全局副标题而超时，更新实际成功且未重试。213 AWAKE/OverrideTimeout120000已读回，197租约已释放。"
      ],
      "remainingActions": [],
      "remaining": "仅197旧包缺图、普通更新与浏览采用范围冻结；新具名反例再开。",
      "boundaries": [
        "本次没有证明真正的资源回退；不外推全设备/所有源，也不重开ICONS素材矩阵。",
        "210工具超时原件保留，不误判更新失败；未清用户数据，库和reader完整内容保持。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类原文“创漫繁中的图标怎么又变成默认了？”；当前无可信原始UTC时刻，精确时间留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T18:12:56.863520+00:00",
      "firstEvidenceAtSource": "本次登记时刻；Root已亲审具名原图，不作为用户精确首报时间。",
      "firstHandlingAt": "2026-10-23T18:21:28.577481+00:00",
      "handling": {
        "measurement": "本轮登记窗口，不倒填此前调查时间",
        "recordedSeconds": 284.085027,
        "activeSince": null,
        "activeUntil": null,
        "note": "只累计此前已登记且未过期的执行窗口；窗口到期后的空档不倒填，含构建/设备等待，不是纯工时。"
      },
      "closedAt": "2026-10-23T18:26:12.662508+00:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "BROWSE_PULL_REFRESH_STALL",
      "title": "浏览页下拉刷新停住数秒才收回",
      "priority": "P1（交互阻塞新反例）",
      "owner": "Root：根Browse具名范围冻结；其他消费者不外推",
      "dependencies": [],
      "relatedItems": [
        "LIST_EDGE_SCROLL_FEEL",
        "SOURCE_INDEX_PROGRESSIVE"
      ],
      "kind": "open",
      "status": "根Browse回缩/数据保持具名成立；包含本范围CI成功",
      "result": "233完整回缩、匹配trace与数据保持成立；该派生修复已含876b435f，精确CI40033988416 success。原80源根Browse范围冻结。",
      "evidencePoints": [
        "229→232主线程最长1604.765→8.76ms、dirty1600.618→5.547ms；前24行文字/bounds保持。",
        "233全部117原PTS帧/4联系表回缩已审；230→234前三域JSON逐份相等，未以trace代视觉。"
      ],
      "remainingActions": [
        "本笔已含范围CI完成；单源页面/FPS未扩认，不重跑具名根Browse。"
      ],
      "remaining": "本笔已含范围CI完成；单源页面/FPS未扩认，不重跑具名根Browse。",
      "boundaries": [
        "修改对象仅BrowsePage重复派生列表：按53cbc39a历史保名称排序，允许差异仅缓存同一响应式派生值。",
        "行结构、计数、分隔线、样式、动画及私库请求行为保持；不凭credential线索擅改，不复活私库验收。",
        "预加载225/227缓存命中有限结果和App/三仓WIP继续保留，不取消或当作已交付。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类原文；无可信原始UTC精确时刻，reportedAt留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T18:45:24.863746+00:00",
      "firstEvidenceAtSource": "本次登记时刻，不冒充用户精确首报。",
      "firstHandlingAt": "2026-10-23T18:53:36.630490+00:00",
      "handling": {
        "measurement": "本次已登记窗口，含构建/设备等待，非纯编码工时",
        "recordedSeconds": 0,
        "activeSince": "2026-10-23T18:53:36.630490+00:00",
        "activeUntil": "2026-10-23T19:08:36.630490+00:00",
        "note": "仅从当前真实登记时刻起计，不补此前取证或空档。"
      },
      "closedAt": null,
      "firstHandlingAtSource": "本次真实执行登记起点，早先分析与取证未分段，不倒填。",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_ROW_NATIVE_ARROW",
      "title": "源列表右箭头应采用设置同款原生尾部",
      "priority": "P1（UI一致性与准确性）",
      "owner": "Root：源尾部具名范围冻结；同类批准未知边界保留",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "open",
      "status": "原生箭头视觉/点击成立；已含范围CI成功",
      "result": "235箭头与设置一致，253普通源行实际进入3Hentai源页；Root亲审，尾部/点击范围成立，源正文失败另留。",
      "evidencePoints": [
        "253原图确认普通源行点击到3Hentai，右上无空设置；3Hentai0.1.0正文runtime失败，不是箭头点击失败，也不称源可用。",
        "源尾部0de9d3d已含876b435f，CI40033988416成功；已批准卡片/原生槽扩展和私库PARKED审计边界保持。"
      ],
      "remainingActions": [
        "源尾部已含876b435f且CI40033988416成功；保同类批准未知/私库PARKED，不重跑已验尾部点击。"
      ],
      "remaining": "源尾部已含876b435f且CI40033988416成功；保同类批准未知/私库PARKED，不重跑已验尾部点击。",
      "boundaries": [
        "具体实施授权仍限定源行尾部，保图标、行高、动作；同类审计不等于全局重做授权。",
        "不擅改已批准定制或冻结界面，不重开ICONS矩阵；预加载及其他WIP保留。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类箭头反馈原文；无可信原始UTC时刻，精确首报留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T19:01:03.959368+00:00",
      "firstEvidenceAtSource": "本次登记，Root已查源码；不冒充用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_LANGUAGE_DISPLAY_CONSISTENCY",
      "title": "源语言展示统一格式化入口",
      "priority": "P1（跨页面展示一致性）",
      "owner": "Root：源列表与源包管理语言展示消费者",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_ROW_NATIVE_ARROW",
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "open",
      "status": "已安装/未安装两组语言名称与红18+具名可见",
      "result": "259原生终图已显示已安装与未安装两组的语言名称/红18+；两页既有范围保留，未知标签不外推。",
      "evidencePoints": [
        "245两页已安装源语言/标记已审；259已安装/未安装两组均实际可见，metadata原值不变。",
        "0de9d3d所在Koma精确CI40015663006已成功；后续全部更新摘要另在260安装，88d6fb5/CI40018530912成功，不混同语言消费者验收。"
      ],
      "remainingActions": [
        "未知语言等未覆盖边界仅待实际样本；不重跑已审语言与标记范围。"
      ],
      "remaining": "未知语言等未覆盖边界仅待实际样本；不重跑已审语言与标记范围。",
      "boundaries": [
        "当前有效决定是实际语言名称（语言自称）与红18+，不再按raw代码安排。",
        "只改展示语言/标记文案，原metadata/身份/筛选语义保持；18+仍在语言后，不扩大布局或样式重做。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈；无可信原始UTC精确时刻，reportedAt留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T19:07:50.969774+00:00",
      "firstEvidenceAtSource": "本次登记时刻，不冒充用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_INSTALL_GLOBAL_DISABLE",
      "title": "单源安装或更新导致其他源按钮全部禁用",
      "priority": "P1（安装交互阻塞）",
      "owner": "Root：按源运行/等待/排空具名完成；其他自然失败边界待验",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "open",
      "status": "一次全部更新运行/等待/排空具名通过",
      "result": "258一次触发形成1运行+7等待，随后排空；259实际23项升级、80源身份与enabled保持，library/reader同值，安全队列具名成立。",
      "evidencePoints": [
        "258 pending与259终图Root亲审；257→259 registry80→80同ID、23 manifestVersion升级且enabled全保持，library/reader逐字节相等。",
        "顶部任务摘要候选已在260明确安装成功；88d6fb5已提交，精确CI40018530912成功。队列通过不扩大为所有错误/并发状态。"
      ],
      "remainingActions": [
        "保具名队列与摘要采用范围；失败、取消和重复提交等其他自然边界未扩认。"
      ],
      "remaining": "保具名队列与摘要采用范围；失败、取消和重复提交等其他自然边界未扩认。",
      "boundaries": [
        "安全排队仍由各包状态和registry串行写入共同负责，不能只删disabled后裸并发；箭头和语言已有各自具名结果。",
        "浏览卡顿具名范围和跨章预加载WIP保留，不因新项抛掉原队列。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈，无可信精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T19:08:16.947392+00:00",
      "firstEvidenceAtSource": "本次登记，源码链由Root核实；非用户精确首报时间。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_EMPTY_SETTINGS_ENTRY",
      "title": "无设置描述符的源仍显示可点击设置入口",
      "priority": "P1（无效操作入口）",
      "owner": "Root：manager/Browse/独立Search具名完成；未知或失败描述符边界保留",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_DIRECT_ENTRY"
      ],
      "kind": "accepted",
      "status": "manager/Browse及独立Search空设置入口具名验收通过",
      "result": "446爱奇艺叭嗒独立Search标题正确、无query，右上仅原生house，无gear或空设置；manager/Browse既有通过范围保留。仅原空设置入口缺陷收口，未知/失败描述符不扩认。",
      "evidencePoints": [
        "245 manager无项、247包子有两控件、253 Browse无空设置入口及311漫小肆manager范围保持。",
        "445/446普通Manager→Details→独立Search，Search=1且标题正确；get_settings=com.iqiyi.koma/not_supported23ms（11:32:12.766–12.789），三域与442精确同。",
        "443/444错选无search能力的3Hentai011，原图禁用/暂不支持是正确行为，不记导航Bug，原失败留存。34da2ea9精确CI40058325930成功。"
      ],
      "remainingActions": [],
      "remaining": "原空入口缺陷具名范围已验收；未知/失败描述符未扩认，后继真实新反例按原规则登记。",
      "boundaries": [
        "只收口manager/Browse/独立Search已有具名空设置入口；未知或失败不能误当无设置，不称所有源描述符已验。",
        "保设置直接弹出、保存/清除和关闭返回范围；3Hentai无search能力不构成新导航缺陷。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈；无可信精确UTC首报，reportedAt留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T19:11:07.767687+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": "2026-10-24T03:35:01.638296+00:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_PACKAGE_ICON_INVALIDATION",
      "title": "安装或检查更新导致源图标闪烁",
      "priority": "P1（当前源性能主线）",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_INDEX_PROGRESSIVE",
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "open",
      "status": "503新装再现本行瞬空；同索引检查保持范围不变",
      "result": "503真实HANMAN18安装复现：第9帧0.197422s图标瞬空，第10帧0.215244s恢复；其他可见图标保持。504仅新增该源，原84项全字段/顺序及书架读态不变。",
      "evidencePoints": [
        "418完整114帧已审：第8帧0.146778秒本行图标瞬空，第9帧恢复；419仅漫画屋014更新，用户数据保持。",
        "434 trace显示旧图标重解码早于SourcePackageListItem销毁约1.439秒；仅定位到原生行内部更新线索，不宣称已证HDS根因。",
        "470完整95PTS/6全页表及6图标表顺审，37–39原帧复核；471与469的8个源Image hashcode/bounds一致，三业务域逐字同。",
        "503/504真实远端新装：115编码帧、4全页表和8/9/10原帧亲审；当行按钮从安装变安装中时图标空1帧，不能用已缓存PrefixCustomBuilder对象宣称完全解决。录像890x1920，设备1260x2720。",
        "531真实011→012更新118帧四联系表已亲看；原帧5图标正常，6(PTS0.099656s)本行图标瞬空，7(0.116111s)恢复，其他原可见源图标保持；问题仍open，不以Native按钮更新正常当已修。",
        "本轮SDK声明仅CommonMethod，未发现按区域更新setter；预览HdsComponent.hsp解读明确标为mocked implementation，不作实机因果。434实际主线程最长回调29.616ms/一次23.406msUIVsync保有界，不能抵消531一帧瞬空。",
        "官方HdsListItemCard文档已核：A/B/C仅在整卡Options中配置，公开通用属性不可单独修改内部区域；SuffixButton.options可写，但文档未承诺复用对象即可局部更新。未据此认定平台根因，未改原生样式或重复安装。"
      ],
      "remainingActions": [
        "本行按钮改变仍有图标瞬空；待实机HDS A区/C区更新边界的有效实现依据，保原生卡片及已定30vp/R7。不用预览mock或重复造安装验证。"
      ],
      "remaining": "本行按钮改变仍有图标瞬空；待实机HDS A区/C区更新边界的有效实现依据，保原生卡片及已定30vp/R7。不用预览mock或重复造安装验证。",
      "boundaries": [
        "新反馈不替换原队列；Reader未完、3HNative及已批准/冻结范围继续保留。",
        "源码线索不等实测根因；不清缓存或批量重做界面制造通过。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈，无可信精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:12:10.554202+00:00",
      "firstEvidenceAtSource": "本次记录时刻，不冒充用户首报。",
      "firstHandlingAt": "2026-10-23T21:12:10.554202+00:00",
      "handling": null,
      "closedAt": null,
      "firstHandlingAtSource": "源码调查已由Root进行；仅本次可核登记起点，更早未分段不倒填。",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "title": "源安装期间主线程UI阻塞",
      "priority": "P1（当前源性能主线）",
      "owner": "Root：限定key修复已实机验证，整体安装主线程工作继续定位",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_INSTALL_GLOBAL_DISABLE",
        "SOURCE_PACKAGE_ICON_INVALIDATION"
      ],
      "kind": "open",
      "status": "相邻行重建限定修复已验，持久化与整体UI耗时继续OPEN",
      "result": "237候选8547220B普通Zerobyw首次安装成功，missing17→16、installed68→69；原前一项Simply Hentai末尾分隔线正确收回。113 trace仅移除目标ConciseListRow，ForEach additionalChildComps=0，相邻行未因末项位置变化重建。library/reader逐字同111，registry只新增Zerobyw，原68项逐项相同。",
      "evidencePoints": [
        "3778510277B安装三域同；379 main23468 rmdir17.389/event15.932ms，对照36483.566/67.433/42.145与37632.194/16.235/60.948，不能外推FPS或全App。",
        "434注册84IDs/顺序保持，仅漫画屋015/WASM54808/单域变化，其他83及library/reader逐字同；与379本地导入为不同具名路径，不作严格A/B。",
        "main63980既有12秒安装trace读回：depth0最长29.616ms、rmdir22.115ms，12实际帧max23.439ms/均3.622ms；本次没有录像，不判断418视觉反例通过。",
        "19检查通过、临时HiTrace/CPU/timer全撤；6文件已同步41e753dd20078e7f4cf7ab87e0ec0e7cdfb6d191，CI40046505483 completed/success，Release成功/tag发布skipped，无新tag。",
        "434 trace.db事件5986/5987：execute 0.288ms在callid369；complete 22.115ms在主callid262，仅3个子span（序列化两次/提示），无细分JS栈。官方TaskPool指南说明NAPI complete计入后续微任务；目前无法把22ms归给rmdir本身。",
        "237诊断Release8535161B明确安装；079真实漫画屋013→015，68条仅该源变化，library/reader逐字同。新日志persistSyncMs12、cleanupAwaitMs3、publishSyncMs0、row_projection5；trace主回调29.223ms/UIVsync38.379ms、FlushDirtyNodeUpdate29.459ms，不能称安装全程流畅。"
      ],
      "remainingActions": [
        "本轮只关闭位置布尔key导致的相邻行重建；整体stall仍OPEN：113 import持久化同步32ms、row projection5ms、最长FlushDirty26.263ms。与079不同源/更新动作，不作耗时AB。后继定位同步持久化与剩余UI工作；本行图标仍独立项。"
      ],
      "remaining": "本轮只关闭位置布尔key导致的相邻行重建；整体stall仍OPEN：113 import持久化同步32ms、row projection5ms、最长FlushDirty26.263ms。与079不同源/更新动作，不作耗时AB。后继定位同步持久化与剩余UI工作；本行图标仍独立项。",
      "boundaries": [
        "434 fs.rmdir工作线程execute0.288ms，main complete22.115ms含Promise微任务，不当成主线程目录删除。",
        "237079 trace完成后才加入持久化/发布/投影分段，不以诊断日志代替性能修复；本行prefix瞬空另项保留。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈，无可信精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:12:10.554202+00:00",
      "firstEvidenceAtSource": "本次记录时刻，不冒充用户首报。",
      "firstHandlingAt": "2026-10-23T21:12:10.554202+00:00",
      "handling": null,
      "closedAt": null,
      "firstHandlingAtSource": "源码调查已由Root进行；仅本次可核登记起点，更早未分段不倒填。",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "modificationBasis": {
        "object": "SourcePackageManagerPage三组末项分隔线状态与ForEach key",
        "history": "f4caffaa为修末项分隔线失效，把是否末项纳入key；版本/源metadata key另用于保持行输入更新。",
        "originalReason": "ForEach保留已有key的构造闭包，旧groups快照不随末项变化更新分隔线；原处理通过重建末项解决。",
        "reopenEvidence": "237079 ForEach preIds3→2销毁两个SourcePackageListItem，保留相邻项也因末项key改变重建；这属于用户明确要求消除的小状态带动无关元素重建。",
        "allowedDifference": "末项ID改由三个独立Computed字符串提供，分隔线直接观察当前末项；仅从key移除位置布尔值。保原生HDS、几何、顺序、动作及实际metadata更新规则；不冒整个卡顿/本行图标已修。"
      },
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-terminal237-missing-tail-112",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-terminal237-zerobyw-install-trace-113"
      ]
    },
    {
      "id": "MANGA_DETAIL_REFRESH_BACKGROUND",
      "title": "详情下拉刷新顶部露底颜色不一致",
      "priority": "P1（源性能后接续的UI缺陷）",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "MANGA_DETAIL_PULL_REFRESH",
        "LIST_EDGE_SCROLL_FEEL"
      ],
      "kind": "accepted",
      "status": "197原详情同手势168帧已审，露出区域同色",
      "result": "仅固定外Stack补BG_SUB。527沿114同一猎行者458章详情/同手势连续录像168帧已亲审，最大下拉/回弹/终态背景同色，原内容保持；528原第一话15/16与读态保持。",
      "evidencePoints": [
        "背景根因来自746e3b8e父树中灰底随PullRefresh内容移动，固定Stack无底色；本次只补这一行，不动公共Scaffold/布局/动画/标题栏。",
        "527五张联系表0–167及关键原帧62/146/167已亲看：无旧白灰分界；原猎行者458章、第一话第15/16页及既有正文/封面保持。",
        "526→528书库/reader/registry逐字节相同；521→526仅Hunter封面URI由正常详情加载更新，原章节与阅读不变，不写整库零变化。"
      ],
      "remainingActions": [
        "本次浅色普通详情具名范围冻结；未以此扩认深色/全部源/全部刷新失败状态。其他队列继续。"
      ],
      "remaining": "本次浅色普通详情具名范围冻结；未以此扩认深色/全部源/全部刷新失败状态。其他队列继续。",
      "boundaries": [
        "用户本次明确批准该露出区域同色修正；此许可不扩大为布局/刷新组件改造。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈，无可信精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:12:10.554202+00:00",
      "firstEvidenceAtSource": "本次记录时刻，不冒充用户首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": "2026-10-24T07:39:41.166476+00:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "firstHandlingAtSource": "本轮已开始只读调查，但精确起点未单独记录；不从登记时刻反推实际开始。"
    },
    {
      "id": "REFRESH_RETAIN_EXISTING_CONTENT",
      "title": "刷新与首次加载分离，保已有内容与图标",
      "priority": "P1（当前源闪烁主线关联要求）",
      "owner": "Root：SourceBrowse内搜索与独立SourceSearch同查询重试/失败保内容写入链",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_PACKAGE_ICON_INVALIDATION",
        "SOURCE_INDEX_PROGRESSIVE",
        "MANGA_DETAIL_PULL_REFRESH"
      ],
      "kind": "open",
      "status": "同查询刷新保留已推4d806fa；精确CI40084821198成功",
      "result": "生产方法Host先复现失败清空，修复后94相关检查通过。570安装Release8537665B，576包子真实内容Text卡成立；两次搜索HTTP200/368ms与356ms，同卡几何保持，577三域与570逐字同。",
      "evidencePoints": [
        "306转场0.597秒已见缓存列表，3.469秒check结束；重新入页图标1.005秒全真图，不当原有内容刷新清空。",
        "302/303及305业务域保持已核；不把源管理具名结果写成全App状态检查完成。",
        "search-refresh-retention-before.txt：53项52过/1真实失败，已有p1/p2被清空；修改后消费者94/94。同源/包/entry/设置/查询/筛选严格归属，首屏失败footer回第一页，分页仍原cursor。",
        "576包子初始首页自然403后现有自动会话恢复原GET200/385ms；无人工完成。查询大奉打更人真实Text在[39,1080,407,1139]，与输入框分开，两次search响应506字节/HTTP200；原Library恢复，577三域保持。571误匹配与574源定位失败原件保留，不作通过。"
      ],
      "remainingActions": [
        "真实同查询失败保留与原因footer布局、独立SourceSearch普通入口仍待自然样本；576普通正常重搜已具名通过，不重跑。"
      ],
      "remaining": "真实同查询失败保留与原因footer布局、独立SourceSearch普通入口仍待自然样本；576普通正常重搜已具名通过，不重跑。",
      "boundaries": [
        "当前源图标闪烁/安装阻塞仍主线，新反馈不替换旧顺序。",
        "不得把单处源码线索或用户观察写为全App已查/已复现，保原内容与用户阅读数据。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类原文，无精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:16:09.194667+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "modificationBasis": {
        "object": "BrowseViewModel.runSearch/clearSearch/retrySearchPage与SourceSearchPage现有footer调用",
        "history": "113918872实源搜索引入失败无条件清空；3882d9e86加请求号守卫，f831e16f4加入cursor；3b662bd6b恢复原请求挑战。",
        "originalReason": "初始搜索失败展示空错误，分页失败保已成功行并重试原页；当前实现未分已有同查询的重新搜索失败。",
        "reopenEvidence": "本次完整刷新写入链审查发现runSearch catch无条件searchResults=[]，开始即page=1/cursor空；原生源搜索菜单验证返回会retrySearch同query。",
        "allowedDifference": "只对同sourceId/版本/字节数、同registry entry、同settings revision、同query和filters的已成功结果保留；失败仍走已有footer，重试明确回第一页。保留原safe错误原因到现有footer文字，尺寸/排布/字号/颜色保持，未给消息的Browse footer保持原样。新查询/换源/换包/设置/筛选变化不继承旧归属。保UI/翻译/排序/请求次数和挑战守卫，无失败注入到设备。"
      }
    },
    {
      "id": "LIBRARY_READING_PROGRESS_SEMANTICS",
      "title": "误开末话后书架进度长期显示100%",
      "priority": "P1（阅读进度语义正确性）",
      "owner": "Root：本次网格/列表显示范围冻结",
      "dependencies": [],
      "relatedItems": [
        "FIRST_CHAPTER_SELECTION",
        "SHARED_ROUTE"
      ],
      "kind": "accepted",
      "status": "197网格/列表未读角标已验，继续阅读与原数据保持",
      "result": "8536845B Release已覆盖197。522网格/524列表实际左上7、457、76、1、669与当前逐章已读数据一致，Nemo零未读隐藏；继续阅读仍为原章第1页100%。原卡片章内百分比已移除。",
      "evidencePoints": [
        "生产ReaderSessionStore按当前去重目录和isChapterRead统一统计；目录空/已知不完整不猜数量。六项方法回归覆盖末章100%、手动读态、孤立章/他书、缺目录、696大计数、新章及单章继续阅读保持。",
        "521原图、522网格、524列表已亲看；封面frame/标题/分类与稳定ID保持，原生Badge参数共用，不截99+。522/524三业务文件均与521逐字节相同。",
        "原生同ID手动已读操作未另造状态；其UI回显未在此新增声明。525初次等下载章节失败，实际为已下载的重新下载，526原件证明正常详情，非产品失败。"
      ],
      "remainingActions": [
        "本次两种书架展示和Host统计范围冻结；未扩认所有字号、主题或Native手动读态操作。其他队列继续。"
      ],
      "remaining": "本次两种书架展示和Host统计范围冻结；未扩认所有字号、主题或Native手动读态操作。其他队列继续。",
      "boundaries": [
        "源图标本行瞬空等独立未闭项保留；已验安装性能具名范围不重跑，也不因本项丢弃其他反馈。",
        "不得把单处源码线索或用户观察写为全App已查/已复现，保原内容与用户阅读数据。",
        "最新答复明确选择左上未读角标，取代原多章已读N/M文案；不将继续阅读章内百分比一并重做。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类原文，无精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:16:09.194667+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": "2026-10-24T07:39:41.166025+00:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "firstHandlingAtSource": "本轮已开始只读调查，但精确起点未单独记录；不从登记时刻反推实际开始。"
    },
    {
      "id": "BAOZIMH_DAFENG_PAGE_LOAD_FAILURE",
      "title": "包子《大奉打更人》正文无法加载",
      "priority": "P1（具名正文不可读）",
      "owner": "Root：精确远端首话及读态保持具名完成；排序问题归独立项",
      "dependencies": [],
      "relatedItems": [
        "BAOZIMH_BROWSE_FAILURE",
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "open",
      "status": "限定首话恢复与精确远端发布完成；未扩大cold/整书",
      "result": "精确远端包普通搜索/695详情/首话继续3/24及读态保持已核，本轮限定恢复与发布范围完成；cold/整书/排序仍未扩认，不阻本轮收口。",
      "evidencePoints": [
        "353真实远端3/24图与三次HEAD fallback日志已审；registry84顺序保持仅包子WASM变119798B，library同349。",
        "reader逐字段仅同书同章正常updatedAt/position.updatedAt变化，原page3/24和其余记录保持；不再待reader核查。",
        "App/源精确CI成功与公开真实远端包13回放/Native范围均保留，原325失败不抹去。"
      ],
      "remainingActions": [
        "冻结本轮限定恢复/发布；cold/整书/排序不外推，后继只按真实新样本或独立排序项推进。"
      ],
      "remaining": "冻结本轮限定恢复/发布；cold/整书/排序不外推，后继只按真实新样本或独立排序项推进。",
      "boundaries": [
        "允许差异仅source图片选路与Host请求方法；保ID/章节/页数/进度，Reader布局不动。",
        "不写死rsa、不绕TLS、不新增UI或Cookie权限；五CDN仅按站点声明有界选择，每章一次，不盲目多路下载。",
        "Mac匿名样本不称Native通过，原325失败保留，其他请求method/会话边界保持。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类具名反馈，无可信UTC精确时刻，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:17:42.386549+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_BROWSE_HOME_STRUCTURE",
      "title": "源浏览分类下拉与首页分区结构待整理",
      "priority": "P2（设计结构调查）",
      "owner": "Root：追首页/listing用途、历史及设计边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_FILTERS",
        "BROWSE_HEADER_REFRESH"
      ],
      "kind": "open",
      "status": "用户质疑已登记，历史与允许差异待核",
      "result": "用户质疑部分源用左上分类下拉、部分首页为纵向长分区；当前代码差异已读，历史依据与应采用结构尚未核。",
      "evidencePoints": [
        "SourceBrowsePage.SectionHeader仅listings>1显示menu，homeSections按序append；BrowseVM.loadBrowseHome可同时装首页分区与default listing。"
      ],
      "remainingActions": [
        "追各能力/listing/homeSections契约及历史设计，再整理选项与允许差异；未批准前保首页结构。"
      ],
      "remaining": "调查能力差异及原设计依据后提出具体方案，不自改首页结构。",
      "boundaries": [
        "当前代码不证明原设计无历史依据；允许差异待定，未授权自作主张重构首页。",
        "保当前源UI/性能与包子正文主线，新设计调查不替换旧队列。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类质疑，无可信UTC精确首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:19:47.404038+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "MANHUAWU_SOURCE_UNAVAILABLE",
      "title": "漫画屋列表403与错误状态丢失",
      "priority": "P1（具名源不可用）",
      "owner": "Root：普通Native取证/远端跟进；源owner：OperationError诊断修复",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "open",
      "status": "自动验证后列表200；元尊正文仍待",
      "result": "478/479普通自动Web在真正正常文档后回流，Native列表200/30本；473/476失败保留。原460正文get_pages2300028未扩认恢复。",
      "evidencePoints": [
        "473日志13:19:38原请求附会话/Cookie/WebViewUA，HTTP403/5727chars；13:20:10.855 clearance_candidate触发retry_original_once，随后原生161仍403/5727chars/186ms。",
        "473与471的library/reader/registry逐字比较均相同；没有再次点击重试。原件diagnostics/manhuawu015-firstgroup197-failure-473。",
        "455–458既有会话列表/详情200及460正文页表超时不抹去；472在27.439秒未见元尊，未进入排序或开书。",
        "478/479原生列表get_manga_list HTTP200，30本封面/标题已显示；没有人工完成或再次点重试。"
      ],
      "remainingActions": [
        "继续元尊目录顺序与原页表超时，不据列表成功声明整源可读。"
      ],
      "remaining": "继续元尊目录顺序与原页表超时，不据列表成功声明整源可读。",
      "boundaries": [
        "仅漫画屋015列表/元尊详情恢复；无页表或正文，不扩整源可用。",
        "页表Cookie present与2300028超时是本次事实，不足以推断网络具体阶段或否定分区读取修复。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类具名反馈，无可信UTC精确时刻，留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:26:41.632173+00:00",
      "firstEvidenceAtSource": "本次登记，非用户首报精确时间。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "modificationBasis": {
        "object": "SourceRuntimeHttpTransport HTTP envelope与漫画屋fetch/单域会话声明",
        "history": "34ab280d现有受限会话；745856a保HTTP状态；Host原样转JSON，未传响应头信号",
        "originalReason": "不向源暴露Cookie/任意响应头，不把全部403认挑战",
        "reopenEvidence": "427官网分类出现安全验证，428自然通过；官方cf-mitigated=challenge为可靠信号，Native423正文/响应头仍未知",
        "allowedDifference": "仅将精确标准响应头转可选accessSignal常量；保status/body/原错误；源仅对受支持状态消费并声明www.mhua5.com，保现有半模态/UI/权限边界"
      }
    },
    {
      "id": "MANHUAGUI_RUNTIME_TIMEOUT",
      "title": "漫画柜0.1.6列表请求超时",
      "priority": "P1（具名源运行失败）",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS",
        "FIRST_CHAPTER_SELECTION"
      ],
      "kind": "open",
      "status": "237081当前列表HTTP200；旧197超时未据此撤销",
      "result": "197漫画柜0.1.6 get_manga_list15038ms返回timeout/HTTP0，原生显示连接超时；具体网络阶段未明，不能归为旧237相同根因。",
      "evidencePoints": [
        "413实际列表请求15038ms超时；get_settings未实现是独立能力，不是该列表超时原因。",
        "415完整原图已亲审：manhuagui.com加载指示消失后仍白页，仅Web节点/原生导航，无正文或挑战UI；三域同406，AWAKE/override86400000。",
        "237081同普通Browse→漫画柜016，本次HTTP200/27920chars；头1599ms、总1609ms，官方累计dns6.557/tcp9.382/tls1194.953/首字节1593.163/完成1595.842ms。新阶段日志已实机可用；不反推旧197超时原因或整源正文可读。"
      ],
      "remainingActions": [
        "保留Native超时与普通Web白页两个有限观察，待定位具体网络阶段，不再盲重试或推断官网成功。"
      ],
      "remaining": "保留Native超时与普通Web白页两个有限观察，待定位具体网络阶段，不再盲重试或推断官网成功。",
      "boundaries": [
        "保当前源UI/安装性能主线；旧证据不冒本次复现，不盲重试或清缓存。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "本会话最新人类原文，无精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:28:34.289082+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_BROWSE_ALWAYS_WEB_ENTRY",
      "title": "源浏览菜单常驻使用WebView打开",
      "priority": "P1（明确授权的失败恢复入口）",
      "owner": "Root：漫画160源URL限定补齐及197普通更新",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_WEB_SESSION",
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "open",
      "status": "五处网页动作已改官方website符号；原生溢出菜单文本仍由HDS持有",
      "result": "源62a1d185精确CI40079042677成功，08:43:50Z公开非draft/pre，原latest85条/MH1600.1.3。553唯一普通远端更新成功；554源85→85仅MH160变且原顺序/书库/reader保持。556两原网页MenuItem均enabled/clickable，557实际WebView已打开；558只有站点标题/加载指示，未证明正文可见。",
      "evidencePoints": [
        "App c5ad7b8074c04adcbc09ef5a01284cd735c4211b精确CI40049912720已completed/success；399最终8514625B包保持。",
        "本App39909的402 source_index fetch_ok count85写缓存；另配置repo CURL7/404为独立请求，393旧2300999原因仍未知。",
        "旧Weicomic无packageHomepage/origins，采用402新缓存打开www.weicomic.com，404首页与原生控件亲审；405自然返回成功，406完成：三域与404/399/382逐字同，AWAKE/override86400000、根Browse84源。",
        "415漫画柜普通Web入口可打开原生Web页，但加载指示消失后仍白页、无正文/挑战；三域同406，不当官网成功或判断超时原因。",
        "549原菜单及547详情整图已亲看；实际源get_manga/chapters200但章节metadata未知，URL缺口与排序/封面403分别维护。",
        "mh160仅Cargo/lock/lib/README四文件23增3删；生产单源编译48786B及实际source_info0.1.3通过，62a1d18已同步master，远端/Native待后继。",
        "555断言把MenuItem及子Text同名两节点当1而停，原工具失败保留；556原图/原MenuItem六项已亲核，未改产品迎合断言。",
        "558当前Web拥有正确站点标题，Webbounds[0,305][1260,2720]，但当前没有WebView DevTools socket；未启调试、无UA/Cookie或客户端变更。",
        "559仅等待页面就绪，31.290s仍见LoadingProgress；560一次普通Back回原详情784并自然回书架，561三业务域同554。未点刷新/外部浏览器，无Cookie或UA改动。",
        "最新人类反馈：WebView打开网页入口使用房子图标，应表达网页打开而非主页；已登记，未转移当前通用章节排序修复。"
      ],
      "remainingActions": [
        "5处网页动作采用官方website符号已随f6f1c1a推送且精确CI40123012297成功；HDS溢出菜单103不显示动作图标，不以文字截图冒图标实测。"
      ],
      "remaining": "5处网页动作采用官方website符号已随f6f1c1a推送且精确CI40123012297成功；HDS溢出菜单103不显示动作图标，不以文字截图冒图标实测。",
      "boundaries": [
        "常驻入口不能替代自动CF挑战流程，现有自动验证/重试入口必须保留。",
        "只按当前源合法站点打开，不猜任意URL，不因列表加载失败丢入口。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "本会话最新人类原文，无精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:28:34.289082+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": "2026-10-24T00:55:38.030011+00:00",
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "modificationBasis": {
        "object": "sources/mh160/src/lib.rs 列表与详情url字段",
        "history": "bcfb926恢复原mh160业务；3fda006后只调整资源版本。源manga_doc已拥有固定BASE与合法slug的作品请求路径；Koma MangaWebLink/Detail按既定合同仅接受源提供HTTP(S)地址。",
        "originalReason": "App不从不透明作品ID猜网站地址，未提供时不显示网页动作。",
        "reopenEvidence": "549实际成功详情只有重载/Tracker菜单，缺两个既有网页动作；当前源列表/详情确实省略url，而源自身已使用同一真实作品请求地址。",
        "allowedDifference": "源仅返回其现有/kanmanhua/<validated slug>/公开作品URL，供既有网页动作消费。ID、章节顺序/metadata、图标、请求UA和网络路径保持；不借URL补丁猜季或调图。"
      }
    },
    {
      "id": "MANXIAOSI_SETTINGS_VALIDATION_FAILURE",
      "title": "漫小肆打开设置提示设置验证失败",
      "priority": "P1（具名源设置能力/运行失败）",
      "owner": "Root：无效入口与Host误报修正具名完成；其他真实设置失败另查",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_EMPTY_SETTINGS_ENTRY",
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "open",
      "status": "manager无无效入口成立；Host日志误报修正具名成立",
      "result": "311漫小肆manager无无效设置入口且与309三域同。fixture误判仅证Host summary/日志误报，Manager和Store均读response.ok，不能据此归因原菜单失败。",
      "evidencePoints": [
        "Root核Manager.validateSettings1648消费response.ok而非summary.ok；原not_supported原因独立，不冒源失败全解决。",
        "316 pid36728合法get_settings（包子/九儿/Zerobyw）completed，Host fixture误报修正具名成立；显式Record类型修后正式build成功。"
      ],
      "remainingActions": [
        "保manager/not_supported与Host日志修正各自范围；其余源设置失败按真实响应另查，不扩大归因。"
      ],
      "remaining": "保manager/not_supported与Host日志修正各自范围；其余源设置失败按真实响应另查，不扩大归因。",
      "boundaries": [
        "SOURCE_PACKAGE_ICON_INVALIDATION/INSTALL_UI_STALL当前主线保持，新反馈不替换旧队列。",
        "不复活旧空源验收，不以验证失败推断无设置，不盲重试/清用户数据。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类具名反馈，无可信UTC精确时刻，留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:29:33.094146+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "SOURCE_INDEX_CACHE_REVALIDATE",
      "title": "源管理先显示持久索引缓存并后台更新",
      "priority": "P1（明确授权的初载/刷新体验）",
      "owner": "Root：普通重入范围冻结；后台失败/换库/cold边界保留",
      "dependencies": [],
      "relatedItems": [
        "REFRESH_RETAIN_EXISTING_CONTENT",
        "SOURCE_INDEX_PROGRESSIVE",
        "SOURCE_PACKAGE_ICON_INVALIDATION"
      ],
      "kind": "open",
      "status": "普通重入缓存先显/后台检查具名成立；未扩大cold",
      "result": "306普通重入无需点check，0.597秒转场时缓存列表已出现，后台检查3.469秒才完成；先显范围成立，失败/换库/cold未验。",
      "evidencePoints": [
        "Root亲审306全部82帧/3表及39/58/72/81原图；未安装3项与已装组在网络检查完成前已显。",
        "重新进页3图先默认，1.005秒全真图；仅当前profile重入，不冒跨页全图瞬显、离线或冷启动。"
      ],
      "remainingActions": [
        "冻结本次普通重入先显范围；后台失败/换库/cold等待真实适用场景，不造故障。"
      ],
      "remaining": "冻结本次普通重入先显范围；后台失败/换库/cold等待真实适用场景，不造故障。",
      "boundaries": [
        "当前profile普通重入缓存先显已实现且具名运动成立；新缓存项不覆盖其余缺陷，后台失败/换库/cold仍未验。",
        "缓存身份与后台过期回调须守当前索引，未安装/可更新状态仍按真实安装版本计算。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类明确授权，未提供可信精确UTC首报；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:33:52.591153+00:00",
      "firstEvidenceAtSource": "本次登记，非用户首报精确时刻。",
      "firstHandlingAt": null,
      "handling": null,
      "closedAt": null,
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "TONGLI_CHAPTERS_SETTINGS_FAILURE",
      "title": "東立任意作品章节加载失败、设置提示验证失败",
      "priority": "P1",
      "kind": "open",
      "status": "237同网官网同首话也无正文；原生3166原因明确",
      "owner": "Root：237同一网络官网同作品/首话核对",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS",
        "MANXIAOSI_SETTINGS_VALIDATION_FAILURE"
      ],
      "result": "012恢复4章与无设置契约、013地区原因及精确CI已成立。按人类要求自行核对：237官方膽大黨→第1話→直接閱讀，官网明确授权台湾地区，实际先Please Wait后黑页未有正文。官网黑页具体失败不强归3166，原生API3166为独立确证。",
      "remaining": "保站点授权限制及官网黑页两个有限结果；当前网络不能完成正文验收，不改账户/地区/网络。其他源与App继续。",
      "reportedAt": null,
      "reportedAtSource": "当前人类消息无可信精确首报时间，留空。",
      "firstHandlingAt": "2026-10-24T12:02:09.354493+00:00",
      "closedAt": null,
      "evidencePoints": [
        "237当前Connected，空闲原租约已released；Root新租约20261024-120049-052619f8。",
        "3d5d114原提交只写build verified；后续图标验收未证明章节/阅读可用。010只因已安装toast文本未匹配超时，012真实列表20本证明已装并打开，不重复安装。",
        "013失败原图：详情已加载但章节加载失败；014诊断20:12:16.264章节→POST400→client_error；016原图设置验证失败。",
        "已审源码只恢复已有备用分支的400路径及无设置契约；原key/URL/权限/章节身份和图标保持。",
        "桌面同接口错误白名单字段明确Errors.Code3166/当前地区不可读；不把桌面US推定为Native位置。源013识别确切业务结构，15实际WASM场景通过；App region白名单/固定本地化说明143项既有检查通过。",
        "023当前8525150B签名Release已明确覆盖237/0.1.2-pre code3，library/reader/registry前后逐字同。仅部署，不作阅读已成功。",
        "024误把官网图标当更多菜单；025实际是有内容的东立官网WebView，非更多菜单验收。当前源无无效设置入口，不再出现原设置验证失败。",
        "027普通013更新后028原生同第1話显示region/HTTP400；原图已亲审，29普通返回原章/源/书架。",
        "029已正常回原书架；030 Library/reader与本轮007起点逐字同，注册67→68仅新增東立013，原67条逐项同；未点地区失败重试、未操作网页登录。",
        "031当前原生日志get_pages实际1251ms、218chars、reason/error=region_restricted、http400/kindregion；Koma b6911d767da4378aaa17009494d2b60115b4cb39 CI40096068659 success，源说明b7face71 CI40096376852 success。",
        "033只因MenuItem与子Text同名计数2而停，未打开Web；034依实际MenuItem中心打开同作品官网，035采自然加载状态。工具选择器失败不归因产品。",
        "034–039同机同网普通官网路径：作品及首话页面可见；直接閱讀038显示Please Wait，039仍黑无正文。040正常返回原Native。当前脱敏日志revision3 document_end/100%，首个子资源HTTP404；不能把文档结束当原图就绪或把子资源404推为黑页根因。"
      ],
      "remainingActions": [
        "保站点授权限制及官网黑页两个有限结果；当前网络不能完成正文验收，不改账户/地区/网络。其他源与App继续。"
      ],
      "boundaries": [
        "本次只接受東立认证/目录/无设置契约/准确地区原因；正文未通过，其他作品和授权地区未扩大。",
        "未更改网络/账户或绕过站点地区限制；197/237原阅读数据保持，私库PARKED_USER不复活。"
      ],
      "modificationBasis": {
        "object": "東立认证回退、无设置响应及明确3166错误；App既有SourceRuntimeError受控原因映射",
        "history": "3d5d114引入，5965937仅图标；SDK a36a6a5分类状态后原primary post?提前退出。App34ab280d/6ca1b694保错误白名单与unsupported别名。",
        "originalReason": "仅用已有公开认证分支；不能解锁付费或地区授权，未知服务端正文不得泄露到UI/诊断。",
        "reopenEvidence": "237013认证HTTP400/章节失败，016设置operation_response_mismatch；019修后4章，020页图GET400。桌面同接口业务Errors.Code3166明确地区限制。",
        "allowedDifference": "恢复既有400备用分支、返回not_supported；只认HTTP400+Succeeded=false+Errors.Code3166，源发固定region_restricted原因，App固定本地化并保HTTP优先级/未知脱敏。网址/身份/原认证key/图标/布局/网络与账户保持。"
      }
    }
  ],
  "source": {
    "status": "81源homepage已发布；旧Weicomic普通网页打开返回成立，4例外保留",
    "kind": "open",
    "title": "源homepage发布与App采用边界",
    "result": "源c21d58d8已push，精确CI40074281080 success；公开latest索引85条，包子0.1.12正常采用197。81/85 homepage发布范围保持。",
    "remaining": "012大奉696章的691编号/5通知、升降序及原3/24读态已具名完成。4个homepage例外、漫画屋正文超时、漫画柜网络阶段及未知metadata仍按各原项推进；不从自动验证样本扩大整源可用。",
    "commit": "c21d58d8f5897aee95745d7b1897ecfb2bdd3d47"
  },
  "milestones": [
    {
      "at": "2026-10-19T22:26:49Z",
      "text": "本地未加密备份创建/读回/清理完成；书源主分支已同步，Kit推送403已核权限。"
    },
    {
      "at": "2026-10-19T23:20:11Z",
      "text": "197现成CBZ导入、纵向翻页及真实进程死亡后进度重开通过；本轮条目已移出，点击反例继续追。"
    },
    {
      "at": "2026-10-19T23:39:24Z",
      "text": "设置具名入口、本地重扫自然重选分支及两图导入/翻页/重开已实际观察，临时条目与排序已恢复。"
    }
  ],
  "releaseGates": [
    "v0.1.2-pre已发布；本轮用户缺陷仍开放，不据发布/旧验收认定本轮通过。",
    "先闭眼前已报缺陷及受影响普通入口，再开展系统测试方式整改；每项实现/构建/实机证据分开记录。",
    "四私库PARKED_USER及用户确认完成的图标不重开；未经新授权不扩大可见改动。"
  ],
  "stopRule": "局部验收、提交、清理或写状态不是首版完成；继续安全且已授权的实际动作，具体分支缺条件不扩大为全局停止。",
  "evidence": [
    {
      "id": "b744-preservation",
      "label": "b744原完整保全回执",
      "path": "kit-b744-parent-content-complete-r134-20261019.receipt.json",
      "storage": "recovery"
    },
    {
      "id": "app05-retirement",
      "label": "App05 r2实际管理退休结果",
      "path": "app-production05-exact-admin-retirement-2958a016-result.json",
      "storage": "recovery"
    },
    {
      "id": "comicabc-cleanup",
      "label": "ComicABC十一证据父实际清理结果",
      "path": "comicabc-eleven-evidence-parents-cleanup-result.json",
      "storage": "recovery"
    }
  ],
  "evidenceNote": "当前设备原件在Koma/.hvigor/outputs/user-flow-audit；下列旧清理证据仅为历史回查，不代表当前产品验收。",
  "excluded": "不新增工作树/源码副本/归档/报告/脚本，不做哈希核验，不擅改已定样式，不清用户数据。旧清理工时和目录数不换算产品完成度。"
}
-->

## 0. 本轮审查结论与方法（2026-09-05）

### 当前切片即时检查点（MangaDex身份已完成 → 2026-09-08）

- **切片已限域验收并独立提交**：App `9a55a47a`（LibraryUpdateService保留缺席旧章 + MangaDetailPage.applySourceMangaDetail同发布点union，2文件28增4删，不含其余WIP）；源仓 `d5ee46d`（MangaDex 0.1.6：真实语言设置、offset/limit/total分页、不再按章号去重丢UUID，lib.rs 32增35删）。独立review `PASS_SCOPED_CAN_COMMIT_ORPHAN_REMAINS_OPEN`，均不推送。下一检查点：RDR-004-B自动章末衔接。
- 原v1记录保留：`.hermes-artifacts/20260908-mangadex-chapter-identity/` v1首候选冷进OPM详情显示0/0（applySourceMangaDetail用成功的源空响应覆盖展示）已拒收并保留11/12证据；v2同修复点后197实际显示58/58并启用阅读。授权替代续读：恶女详情45/45与Continue 43话6/35进入真实Reader后返回同锚点；OPM原2/16因进度章节ID `5caba1e0`不在58记录中保持未点（Start Reading不点、原进度不覆盖），精确ID恢复另立切片。两次全14检查：首次1更新/12未变/1跳过/0失败/91新增（SaltFriend99→190，旧99全留），第二次0新增且整个library字节相同。源升级前设置仍English，无网络/下载/语言或旧业务数据改动；临时源服务已退出。197保全24文件中21字节相同，仅SaltFriend更新与registry MD正常升级变化。完整边界见该run `qa-after/notes.md`、`qa-after/v2-detail-checkpoint.md` 与 `review/final-result.json`。
- 197正常源升级后设置仍English。首次正常全14检查：OPM58条全部保留；SaltFriend99→190新增91个英文ID、旧99全留（95条仅index/updatedAt变化，4条缺席旧记录保留）。第二次0新增，整个library文件与首次完成后相同。未改网络、下载、语言或旧业务数据；临时源服务已退出。
- **首候选拒绝验收**：冷进OPM详情在11显示0/0章、阅读禁用；12核实library58和reader数据仍与10字节相同。实际断点是`applySourceMangaDetail`仍用成功的源空响应覆盖展示。已补同发布点的缺席库章节保留，正在独立复核并等待下一共享构建窗口；197保留失败详情，只重验同页/原2/16续读，不重跑两次全库检查，不据存储保留宣称用户链路完成。
- 更新结果页08原图另有第六个指标`91新章`独占第二行的排布问题，记录在本run `review/observed-result-layout.md`；不是整页视觉通过，不混入本数据修复。

### 为什么重新收拢

先前把“页面存在、按钮有回调、某次截图通过”扩大成领域完成；随后不断插入局部修复，没有同步维护完整的用户流程、状态依赖和未覆盖清单。因此书架默认跳过详情、跨章自动已读状态不能保留等主流程问题长期未登记，本文也残留已过时的宽图拆分判断和执行队列。增加另一份互相竞争的路线图不能解决这个问题。

本轮只在本文维护当前问题 ID、优先级与队列；旧文档保留历史证据并指向本文。**文档不是检查范围上限**：先从用户任务和实际路由/状态生产者/消费者展开，再用旧文档查遗漏和冲突。

### 对照依据与差异边界

- Koma：上方当前 HEAD + 工作树，按真实调用链核对，不只看类名、入口或测试文件是否存在。
- Aidoku：本地 `.hermes-artifacts/aidoku-source` 的 `bc3cdc3` 快照（2026-07-03），重点对照路由、章节状态、找书、更新和批量操作；**不是最新版声明**。
- NextE：本地 `/Users/honjow/git/NextE` 的相关当前实现，用于 Reader 状态/渲染/交互和 HarmonyOS 组件；不是要求照搬其内容模型或所有 UI。
- Mihon：以[入门](https://mihon.app/docs/guides/getting-started)、[书架](https://mihon.app/docs/faq/library)、[下载](https://mihon.app/docs/faq/downloads)官方资料作为能力/流程参考；本轮没有完成 Mihon 全量源码对照。不要把多端同步、WebDAV 或源市场当成双方共同具备且 Koma 必须复制的能力。
- 对照结论必须分开：**行为错误 / 能力缺失 / 入口未接通 / 仅缺验证 / 产品或平台差异**。对标方也没有的能力可登记产品建议，但不得冒称已证实的竞品差距。

### 分类与排序口径

| 维度 | 定义 |
| --- | --- |
| 严重程度 | `S0` 数据不可恢复损失或广泛不可用；`S1` 主要任务/状态错误或正常规模内容不可达；`S2` 任务可完成但明显不完整、承诺无效或步骤过多；`S3` 便利性/可辨识度/深化。未证实影响时标“待定”，不凭想象定级。 |
| 处理优先级 | `P0` 下一轮实现首先处理的日常主流程错误；`P1` 随后的高频能力与完整性；`P2` 次要能力或条件性缺陷；`P3` 产品深化/工程债。P0 不表示现在越过审查阶段立即编码。 |
| 类型 | 路由语义、状态/数据、内容完整性、能力缺失、入口未接通、交互/视觉、验证缺口、产品/平台决策、工程债。 |
| 证据状态 | `代码确认` 不等于真机复现；`用户报告+代码确认` 不等于本轮 197 验收；`历史197` 只证明原构建原场景；`待验证` 不得算作缺陷已成立。 |

排序优先看正常使用频率、影响范围、是否有替代路径和下游依赖，不把“严重但触发条件特殊”自动排到每日主流程之前。不做虚假的完成百分比，不以问题条数表示审查完整性。

### 应当成立的主流程

| 用户意图 | 应有链路与必须保留的区别 |
| --- | --- |
| 打开书架中的漫画 | 普通封面/列表点击 → 对应详情 → 开始/继续阅读或选章 → Reader；返回先到详情再到书架。选择模式仍是选择。 |
| 快速续读 | 明确的“继续阅读”入口 → Reader；不能为修普通封面而把它一起改成详情。 |
| 找书 | 搜索/源分类 → 完整结果或明确继续入口 → 详情 → 按用户意图收藏/阅读；关键词、来源、筛选和返回上下文不丢失。 |
| 连续阅读 | 选章 → 翻页 → 完成该章 → 衔接下一章；最近阅读、逐章位置、逐章已读分别持久化且一致回显。 |
| 追更和下载 | 检查更新 → 看见具体新章 → 选章/未读下载 → 下载管理 → 对应详情/明确阅读；批量范围不由列表展开窗口暗中决定。 |
| 本地/私库 | 配置或导入 → 完整目录 → 收藏/阅读 → 返回/冷启动；本地 ID 与远端 ID 不混用，移出书架不等于删除服务器或原文件。 |

第 9 节为问题登记，第 10 节为审查覆盖，第 11 节为跨模块状态核对。三者分别回答“发现什么”“还没检查什么”“为什么会连带出错”。

## 1. 既有切片记录与功能判定规则

以下日期记录保留各次证据边界；其中“后续队列”“暂停条件”仅表示当时决定。**当前阶段和优先级以第 0、5、6、9 节为准**，不得按历史段落继续派工。

### 2026-09-05 列表外边距统一（用户明确要求）

- 确认设置等 20 页主动以 `SPACE_XL=24vp` 覆盖公共列表的 `SPACE_MD=12vp` 默认外边距，NextE 设置页沿用 12vp。现逐页移除这 20 条覆盖，公共 scaffold、全局 token、卡片内边距、垂直占位与 Reader 不变；此前已接受的 Library/SourceBrowse/SourceSearch 封面网格方案未改。
- 范围为 10 个卡片/行列表、4 个服务表单、4 个多级列表/详情混合页及 Search/MangaDetail；混合页不是固定列数封面网格。197 设置根页、书架设置、源包管理、下载管理已实测外边界从 x=78..1182 变为 x=39..1221，总内容宽度增加 78px。详情同更新结果入口已核对封面、按钮、标签和章节，见 `26-detail-before-spacing` / `35-local-detail-margins-after`；搜索保留原固定搜索框和纵向占位，见 `37-search-margins-after`。真实私库内容不冒用表单截图作验收。
- 边距回归同时发现并修正已有的下载入口标题缺陷：从下载管理进入源漫画详情，主体正确但标题为“未命名漫画”（`34-detail-margins-after`）。Index 原先用远程 ID 查询库主键，现按来源 ID + 远程漫画 ID 匹配标题，保留下载入口的源详情刷新行为；实际方法测试覆盖不同来源同 ID、与本地主键冲突、预览标题优先及缺失状态。最终签名构建通过，197 同一下载入口在 `39-download-title-final` 显示正确顶部标题“ONE PIECE航海王”，12vp 外边距保持不变；仅关闭这一已复现缺陷，不代表详情所有场景验收完成。
- 构建与独立代码范围复核通过；前后截图/布局见 `.hermes-artifacts/device197/20260905-source-update-continuation/` 的 `24-final-interval-readable`、`28-download-manager-before`、`29-source-manager-before` 与 `30-settings-margins-after` 至 `33-download-manager-margins-after`。授权/不变项见同目录 `spacing-scope.md`。

### 2026-09-05 应用级更新与未接通外观入口

- 手动/前台到期检查统一由 `LibraryUpdateCoordinator` 持有单轮执行锁，沿用 Index 的真实 LibraryStore；书架恢复和本地目录权限激活后才允许自动检查，前台返回也检查到期条件，不再依赖进入设置页。偏好读改写串行化，严格读取失败不以默认值覆盖旧设置；结果/保存/通知失败分别处理。
- 197 已验证自动关闭冷启动不运行更新、临时开启后未到期不重复检查、从桌面恢复同一进程后重新判断到期；设置已恢复自动关闭，通知权限未开启。真实到期执行、并发与故障隔离由实际模型 host 测试覆盖，不冒充等待 24 小时后的真机执行。系统 WorkScheduler 仍未接入，不宣称后台定时完成。
- 结果页完成订阅后仍曾因 by-value Builder 固定旧摘要而未改变屏幕时间，该次 `17-manual-and-visible-results` 明确不通过。最终摘要直接读取当前状态，逐本/来源列表以检查快照标识更新；`25-final-live-results` 在检查开始即进入结果页，停留该页直至完成，屏幕真实更新为 17:36、10/0/9/1/0。时间、指标和清空期表达式已补实际函数测试。
- 来源名同时修正书架漫画详情的包 ID 显示，`26-detail-before-spacing` 核实 Komiic 徽标。只移除应用外观中未接通的主题/强调色公共入口，保留语言菜单和旧偏好数据；根入口据实改为“语言”。`22-final-language-installed`、`23-language-menu` 核实最终页面与菜单。间隔右侧改为短周期、下次时间置于副标题，`24-final-interval-readable` 确认标题不再被挤省略。

### 2026-09-05 连续推进：源状态与更新结果名称

- 源详情弹层改为读取当前响应式列表，197 已验证停用/启用即时更新、关闭重开和进入 DM5 浏览。第一版曾在关闭时读取已清除的源对象而崩溃，该构建明确拒绝；最终修复所有关闭期绑定和残留回调，补测后重新构建验收，不把早期切换截图当作通过。
- 更新结果使用真实漫画名和已安装来源名称，保留原分组、路由 ID 和持久化格式。197 已对照同一份 16:40 记录，统计保持 10/0/9/1/0；“ONE PIECE航海王”进入对应详情，冷启动仍恢复相同名称和结果。
- 证据：`.hermes-artifacts/device197/20260905-source-update-continuation/11-safe-disabled`、`12-safe-close-and-browse`、`13-readable-results`、`14-named-manga-navigation`、`15-cold-readable-results`；被拒绝的关闭崩溃与恢复记录见 `source-sheet-regression.json`，不删除失败证据。
- 应用级前台检查已由上方独立后续证据覆盖，不等同于系统后台调度。用户要求连续推进，无需在这些切片之间再次等待“继续”；D34 和网络设置变更继续排除。

### 2026-09-05 不支持入口移除与更新结果诚实化

- 按用户最新要求，不再因为 197 不支持目录选择而停住开发，也不让用户点击必然失败的入口。书架导入菜单和导入页根据 `FolderSelection` 能力移除文件夹项；目录重扫还要求 `FolderAuthorization`，设置（含设置搜索）和详情菜单统一门控。保留 CBZ/ZIP、图片、既有本地漫画及元数据编辑，不删除用户数据；具备能力的设备仍保留相应实现。
- 当前签名 HAP 在 197 已核实：导入菜单仅有 CBZ/ZIP、图片，书架设置无本地刷新，设置副标题为“分类与更新”，既有本地目录漫画详情菜单无刷新、仍有“编辑本地元数据”。独立导入页未找到当前用户导航入口，只按代码门控核对，不计入该页真机验收。
- 继续修复已确认的 library update 缺陷：服务返回逐本失败时，不能一律保存 `success` 或提示“没有发现更新”。现在区分全部失败、部分失败、无可检查项、发现更新和真正无更新；全失败保留退避，部分失败保留成功项与失败明细。同轮失败摘要不再被时间戳相等判断隐藏，重启读取也不再丢掉该轮明细。
- `node scripts/test_library_update_outcome.cjs` 运行真实模型/序列化/存储函数，覆盖上述五类、失败退避、恢复成功、同轮摘要保留及后续整体失败淘汰旧摘要；host PASS，签名 debug HAP 构建 PASS，独立代码 review PASS。
- 197 实测正常在线更新、主动停用 DM5 后跳过数从 1 增至 3、冷启动后保留该轮 10/0/7/3/0 结果；已恢复 DM5 启用并重新检查得到 10/0/9/1/0（总计/更新/未变化/跳过/失败）。停用属于跳过，不是假造的失败验收；全部失败/部分失败仍为 host 验证，未计入真机失败态。全程未改 Wi-Fi/网络设置。
- 证据：`.hermes-artifacts/device197/20260905-capability-ui/` 的 `final-build.log`、`05-final-build-settings`、`11-update-results`、`12-cold-results`、`14-source-restored`、`15-restored-update`、`17-local-detail-menu`；协议、布局、截图与结果边界见该目录 `result.json`。
- 后续主队列继续系统调度与通知能力核实；不再等待 197 的目录能力。该切片当时登记的弹层状态和更新结果内部 ID 问题，已由上方独立后续证据关闭，不能混用本节旧构建证明。

### 2026-09-05 本地目录切片复核补记

- 用户已接受书架和源浏览外边距等于封面间距的方向；四文件间距 diff 保持独立、尚未提交。
- 用户明确搁置 D34 真断网阅读；不得关闭 197 Wi-Fi 或为这一轮验证改变网络设置。
- 本地目录持久授权、启动激活、设置/详情重扫已存在于工作树，不再归类为“代码未实现”；完整用户路径仍为 `IMPLEMENTED_UNVERIFIED`。
- 当前构建在 197 上实测 `FolderSelection` 系统能力为 false，设备 API 为 24。旧入口启动系统 picker 后返回 -1/空 URI，没有可选目录页面。现已在入口检查系统能力，复用现有“当前设备无法访问文件夹。请改用 CBZ/ZIP 或选择多张图片。”反馈；此失败路径为 `197_VERIFIED`，不代表持久授权成功。
- 本轮修复：扫描中任一文件 stat 失败则中止该目录，保留旧索引；逐目录捕获持久化异常，继续剩余目录并刷新已保存结果；详情重扫成功后重新加载本地章节/元数据。这三项构建与代码已核对；扫描完整/枚举失败/stat 失败已运行实际函数的 host 检查，但成功重扫的真机路径受上述目录选择能力限制，仍未验收。
- 新确认缺口：页 ID/进度按序号保存，当前页前方增删文件后可能恢复到另一张图。需按旧页 URI 匹配新索引并迁移进度；本轮未实现，不能把目录重扫整体关闭。
- 证据：`.hermes-artifacts/device197/20260905-folder-closure/`，其中 `05-picker-trace` 为旧入口诊断及设备 API，`06-folder-feedback` 为当前构建的能力判断和提示 layout，`07-feedback-visible` 保存可见提示原图，`08-archive-alternative` 证明 CBZ/ZIP 系统文件选择器可打开（未选择文件，不扩大为完整压缩包导入验收）；`build.log`、`verify-scan-failure.cjs` 为构建与实际扫描函数检查。独立代码 review 接受上述四处修复；详细边界见该目录 `result.json`。
- 历史验收边界：成功导入/冷启动/目录新增文件/详情即时更新需要具备目录选择能力的已授权目标环境，当前不切换其他设备。按用户随后指示已移除不支持入口并继续下一项，不再以此作为开发阻塞；D34 保持搁置。

本文不以旧文档中的“已完成”或任务提交存在作为功能验收。每项状态使用以下口径：

| 状态 | 含义 |
| --- | --- |
| `197_VERIFIED` | 当前基线构建已安装到 197，且确认前台 bundle、目标页面或交互结果。只覆盖明确记录的场景。 |
| `SOURCE_VERIFIED` | 当前代码路径与相关 host 合同/脚本已核对，但不等同于真实设备或真实服务闭环。 |
| `IMPLEMENTED_UNVERIFIED` | 代码入口存在，但缺当前基线下的真实环境或端到端验证。 |
| `PARTIAL` | 主路径已存在，但仍有已确认缺陷、能力边界或验收矩阵缺口。 |
| `MISSING` | 当前代码未发现实现，或现有实现明确无法满足目标能力。 |
| `HISTORICAL` | 只说明过去的判断、计划或证据，不能用于关闭当前缺口。 |

完成一个功能至少要同时说明：代码基线、验证入口、目标设备/服务、实际结果、失败态以及证据位置。构建成功、命令退出码、非目标页面截图或其他设备证据不能替代 197 上的指定场景验收。

## 2. 产品方向与边界

以下方向仍有效，不能因对标 Aidoku/Mihon 而偏离：

- Koma 是 HarmonyOS 本地/私有库优先的漫画书架与阅读器。
- 不内置漫画源，不做 APK 插件，不提供源市场，不宣传“全网/免费/聚合”。
- App 仓库负责本地阅读、私有库、source host/runtime、安装/信任/设置/升级/错误恢复；真实源包生态由独立的 `koma-sources` 仓库维护。
- HarmonyOS/NextE 用于脚手架、组件和已验证平台行为参考；Aidoku 用于路由、架构和功能对照；Mihon 类项目只用于吸收适合 Koma 边界的能力。
- 任何视觉或架构改动先查当前所有权、Git 历史和相关参考实现，再做最小切片；不能从单张截图反推改法。

## 3. 历史功能状态（2026-09-05旧基线，不派工）

### 3.1 当时已确认的基线（后继以顶部当前证据为准）

| 功能域 | 当前判定 | 已核实事实 | 尚未关闭的缺口 |
| --- | --- | --- | --- |
| App shell / 书架 | `PARTIAL`（有限197证据） | 既有冷启动/布局/续读证据；a2dbd6b普通网格/列表→详情、明确续读及返栈限域通过，见第17节。 | `LIB-005/006`：视图设置不即时生效、选择态批量栏溢出已真实发现，保持待修；私库真实服务路由等边界仍未验收。不能把有限路由通过扩大为书架管理/整页视觉通过。 |
| 浏览 / source runtime | `197_VERIFIED` + `PARTIAL` | 浏览根页显示 DM5、Komiic、MangaDex；DM5 真实热门列表返回 70 项。MangaDex 的四个纵向筛选行已在 197 核实公共右侧菜单锚点与连续选择关闭路径。host 侧 21 个外部源包合同通过。 | DM5 首项封面等待 6 秒仍为占位；真实源的搜索/详情/章节/图片矩阵尚未在本轮逐源闭环。 |
| 阅读器主路径 | `PARTIAL`（有既有197证据） | `537fe54` 的单页/双页/连续模式放大拖动、未放大翻页及页码可辨识度有分场景 197 证据。当前源码具备单/双页、连续/纵向分页、方向、宽图旋转；`8aeb57f` 已实现宽图独立半页与实际 URI Image 裁切，旧“splitSide 未消费”结论作废。 | `RDR-001..005`：跨章自动已读/逐章位置、分页适配和裁边设置、章末衔接、单本偏好存在实际缺陷或缺失。物理 pinch、旋转/方向/拆分组合矩阵仍缺当前完整验收；不能混称全都“仅缺测试”。 |
| 下载 / 离线阅读 | `PARTIAL`（有既有197证据） | 下载管理、单章/可见章节批量、暂停/重试、1–3 并发和本地 manifest 代码存在。离开详情未发现显式取消已启动下载，不能断言离页必停。 | `DL-001`：整本/全部未读/跨漫画批量链路不完整；`D34`：197 应用级禁网验证未执行，Reader 传入 preferOffline 而非 offlineOnly，未证明禁止远程回退。系统后台下载与通知验收另列。 |
| 本地漫画 / local source | `SOURCE_VERIFIED` + `PARTIAL` | CBZ/ZIP、图片导入、目录扫描/持久授权/启动激活/重扫实现存在于工作树；197 不支持目录选择，已移除对应入口并保留既有漫画与编辑。 | 支持设备上的目录导入/冷启动/重扫闭环未验收；目录增删后的按 URI 进度迁移未实现。不得把 197 缓存漫画可用当作真实目录授权验收。 |
| 书架管理 / 历史 | `PARTIAL`（有既有197证据） | 来源/阅读/下载/元数据/分类过滤、分类管理、批量分类和手动已读存在；历史有日期分组、单条删除和清空确认。五个筛选菜单锚点有既有197证据。 | `LIB-001..004`：页内搜索、排序与数量角标缺口、远程漫画批量移出边界；筛选后的真实数据结果受 `RDR-001` 影响。不能把菜单打开当成筛选正确。 |
| 私有库 | `PARTIAL` | Komga、Kavita、OPDS、WebDAV 配置与浏览主体存在；OPDS parser、WebDAV PROPFIND 有既有 host 检查。 | `SEA-002` Kavita 搜索首批枚举、`PRI-001` Komga 系列目录限100本是代码确认的实际完整性问题；WebDAV 压缩包边界为 `PRI-002`。真实服务矩阵另列，不再笼统归为“都有实现只缺验收”。 |
| Library update / 通知 | `PARTIAL`（有既有197证据） | 五类检查结果、应用级前台到期门禁、手动单轮执行、结果页实时更新和冷启动恢复有对应证据。下载和更新有通知发布/点击回路代码。 | `UPD-001`：当前是最新一次检查报告，不是带具体新章和历史的追更入口。系统调度未接入；197 通知允许/点击和真实到期等场景另列未验收，不优先于已确认主流程错误。 |
| 备份 / 恢复 | `SOURCE_VERIFIED` + `IMPLEMENTED_UNVERIFIED` | 自动备份到期判断、保留数量、列表、导出/导入和数据迁移策略代码存在。 | 不是系统后台任务；没有当前基线下的干净安装恢复、错误/加密失败、跨设备和真实数据域矩阵。 |
| Tracker | `PARTIAL` | AniList/MAL 客户端、账户存储、映射、待同步队列和手动回调录入存在；有既有 host 检查。 | `TRK-001`：自动 OAuth 返回 App 未接通，不只是缺真实账号验收。真实授权/进度回写未验收；Kitsu 属产品深化，不抢主线。 |
| 外观 / 设置 / 关于 | `PARTIAL`（有分场景197证据） | 设置主路由、语言菜单和部分外边距有证据；不能推出所有子页风格统一。 | `UI-001..004`：四类服务表单状态/说明、追踪开发者表单、备份主操作排序、公共禁用态可辨识度问题已从197和源码确认；开源声明占位为REL-001，见第12节。 |
| source 信任 / 升级 | `SOURCE_VERIFIED` + `PARTIAL` | URL index、可选 SHA-256 固定、导入来源与 unsigned 状态标签存在。 | 目前是 hash pinning/来源提示，不是加密签名验证；包签名、密钥轮换、撤销和升级失败恢复仍缺产品级闭环。 |
| 构建 / 发布 / 测试 | `SOURCE_VERIFIED` + `PARTIAL` | 当前 debug HAP 构建成功；i18n 三语 key 集一致；关键 host 合同通过。 | release 未在本轮验证；`build-profile.json5` 使用 skip-worktree 的本地签名配置，HEAD 检查与实际 worktree 构建之间仍有审计边界；没有 ArkTS `entry/src/test` / `ohosTest` 套件，且两个旧文档仍引用已经删除的 UI/model gate 脚本。 |

### 3.2 当时工程债记录（不自动恢复审查或重构）

- `ReaderPage.ets`、`SettingsPage.ets`、`LibraryPage.ets`、`SourcePackageManagerPage.ets` 和 `BackupManagementPage.ets` 已是超大页面，职责和设备验证成本偏高。
- `getContext()` 仍广泛散布，构建有大量“函数可能抛出”与弃用警告。
- Source 管理页存在旧 `Smoke` 诊断 builder，但当前生产 build 无调用；2026-09-06 源码补核及197普通入口未发现该诊断入口。不得再将残留 builder 文案当成普通用户可见缺陷；发布线仍须单独查真实可达路径。
- 当前先完成全面审查，再按第 5 节处理日常路由、阅读状态与内容完整性。低概率防御、后台机制和大文件拆分不抢占这些主流程；不因审计而新增一批支撑脚本或重构所有权。

## 4. 197 历史证据登记（按构建限域）

本节登记 2026-09-05 的 `426be23` 基线与其上的 `R1` 工作树切片，不是 a540f1e + 当前全部 WIP 的整体验收。后续切片证据见第 1 节。证据目录是本地 QA artifact，不代表可提交的产品资源。

- 构建物：`entry/build/default/outputs/default/entry-default-signed.hap`
- R1 当次最终无探针 HAP SHA-256：`9a001e5bc7caf990620b410039317d56f84b20bedf189e7b68c5642cd15412f6`
- 首页：`.hermes-artifacts/device197/20260905-current-head-home-run1`
- 浏览根页：`.hermes-artifacts/device197/20260905-current-head-browse-run1`
- DM5 真实列表：`.hermes-artifacts/device197/20260905-current-head-dm5-run1`
- 设置：`.hermes-artifacts/device197/20260905-current-head-settings-run1`
- 下载管理：`.hermes-artifacts/device197/20260905-current-head-downloads-run1`
- 阅读器：`.hermes-artifacts/device197/20260905-current-head-reader-run1`
- 阅读器设置：`.hermes-artifacts/device197/20260905-current-head-reader-settings-run1`
- 双击缩放录屏：`.hermes-artifacts/device197/20260905-reader-double-tap-recording-run1`
- 双击缩放分帧：`.hermes-artifacts/device197/20260905-reader-double-tap-frames`
- 录屏 SHA-256：`87a26e533d144b5371b2f2f43c8154211ee4d1f73b920a09bcac3c104cb4cdc2`
- `R1` 时间证据：放大过程 frame 9、还原过程 frame 39 出现仅剩页码/录屏浮层的完整黑帧；相邻帧间隔约 31–55ms，足以构成可见闪烁。
- `R1` 第一次修复构建 HAP SHA-256：`ae03c91a54ce001d89009137cddeca0b0a3c70fdca218d973c805b198ec87913`（只证明黑帧消失，已拒绝作为完整 R1 验收）
- `R1` 修复后 Reader 页面确认：`.hermes-artifacts/device197/20260905-r1-double-tap-fix-reader-run1`
- `R1` 修复后双击缩放录屏：`.hermes-artifacts/device197/20260905-r1-double-tap-fix-recording-run1`
- `R1` 修复后 69 帧与 contact sheet：`.hermes-artifacts/device197/20260905-r1-double-tap-fix-frames-run1`
- `R1` 修复后录屏 SHA-256：`22bfc0ac05371571b32c84aaca12fe4e3a613a7cc31060662ffe2aac0c876986`
- `R1` 第一次对照结果：同一中部内容裁剪、`pix_th=0.05`、`pic_th=0.95` 下，旧录屏检测到两段黑帧（54.5ms、38.3ms），修复后录屏为 0 段；但其验收动作没有检查“放大后拖动”，因此该结果不能关闭 R1。
- 拒绝基线：`.hermes-artifacts/device197/20260905-r1-rejected-pan-baseline-recording-run1`。逐帧可见 2× 后滑动期间构图不变。
- 手势链诊断：`.hermes-artifacts/device197/20260905-reader-pan-probe-run1` 在 2× 后没有任何 Pan 回调；将 zoom-dependent recognizer 恢复为 NextE 的内联声明后，`.hermes-artifacts/device197/20260905-reader-pan-probe-run2` 记录到完整 start/update/end，最终位移为 `-138.83,-133.01`，截图构图同步变化。
- 双页整幅验证：`.hermes-artifacts/device197/20260905-reader-dual-pan-run1`，同一 spread 的两次最终位移为 `316.87,133.01` 与 `65.30,-133.01`，两页作为一个画布移动。
- 连续模式验证：`.hermes-artifacts/device197/20260905-reader-continuous-pan-run1`；未放大时 List 从 `start=0` 滚动到 `start=1,end=2`，随后第 3 页进入 2× 并完成图片局部拖动，最终位移 `-119.92,-72.19`。
- 最终无探针单页：`.hermes-artifacts/device197/20260905-reader-final-single-pan-run1`；2× 后 Image `origBounds=[-1084,-1792][1435,3647]`，横纵方向均发生实际位移。
- 最终无探针双页：`.hermes-artifacts/device197/20260905-reader-final-dual-pan-run1`；统一 Row 的 `origBounds=[-1672,-864][3367,2719]`，两张子图保持相邻边界和相同纵向位移，证明变换所有者是整个 spread。
- 最终无探针连续模式：`.hermes-artifacts/device197/20260905-reader-final-continuous-pan-run1`；放大前后页码均为 `3 / 19`，目标 Image 从 `origBounds=[0,965][1260,2783]` 变为 `[-1021,-177][1498,3458]`，证明拖动图片时父 List 没有继续换页。
- 最终无探针未放大翻页：`.hermes-artifacts/device197/20260905-reader-final-single-navigation-run1`；同一次横滑由 `3 / 19` 变为 `4 / 19`，证明未放大时子 Pan recognizer 没有抢走 Swiper。
- 最终无探针单页连续录屏：`.hermes-artifacts/device197/20260905-reader-final-single-recording-run1`，SHA-256 `a55b14f10efc0007a82295f9651444808035421402ad66c19931706e2e133bdc`；`.hermes-artifacts/device197/20260905-reader-final-single-frames-run1` 共 86 帧，完整记录放大、两次拖动、复位。按中部 80% × 70% 内容裁剪、`pix_th=0.05`、`pic_th=0.95` 检测为 0 个黑帧候选，最大近黑像素占比 `0.062191`。

本轮没有完成的 197 验收：真断网离线阅读、通知 granted/denied、OAuth、备份恢复、私有库真实服务、local folder 长期重扫、release 包。

## 5. 唯一执行队列

审查和归类保留以下覆盖边界。用户后续已授权按登记问题逐批实施、197验收后独立提交并继续，不推送；不能用实施某个切片代替整轮审查完成。

| 阶段 | 工作与交付 | 当前状态 / 出口 |
| --- | --- | --- |
| A0 现场与文档校准 | 记录 HEAD/WIP、参考版本；把旧计划降为历史；纠正事实冲突。 | 本轮已更新；保留已有 WIP，不提交、不回退。 |
| A1 全产品源码/参考审查 | 按第 10 节的用户域，逐条追入口→路由→数据→操作→持久化→返回；按第 11 节追跨模块消费者；问题进入第 9 节。 | **首轮重点链路已核对，整轮未完成。** 剩余覆盖不得用“有文件/有测试”填成完成。 |
| A2 197 正常用户流程复核 | 用既有真实内容走第 10 节场景，先高频正常路径，检查语义与可辨识度；同条问题挂上具体构建、截图/layout、动作结果。 | 已恢复并复现 NAV-001、RDR-002；补查四类服务表单、追踪和备份等管理页。记录见第12节。未更换既有安装包；私库/账号/破坏性操作缺条件时分别登记。 |
| A3 审查收口与排序 | 合并同根因、确认严重度/优先级/依赖；每个领域注明查到何种深度、尚未覆盖什么；明确需要用户决定的产品差异。 | 第 9 节为首轮排序，不是全量缺陷清单已封板。不能把未检查项消失处理。 |
| B 按问题 ID 实现 | 基线→最小实现→197同路径及受影响消费者监管→更新问题状态；按用户提交指令形成独立提交。 | **App基线9a55a47a含MangaDex跨语言身份（197 v2限域验收）；源仓d5ee46d。DL004/DL001/CHP001批量、LIB012/011与初始化等待均已提交（第38–43节）；RDR004-A章序/历史目录已提交，B自动衔接未实施，是下一实现项；OPM孤儿进度精确ID恢复仅设计未实施。** 不在一个未验收切片中混改其他页面，不把已交付切片当作全产品审查完成。 |

实现阶段开启后的初步顺序（不替代 A1–A3）：

1. **P0：NAV-001、RDR-001已限域提交**，分别a2dbd6b/e197d63。NAV回归发现的LIB-005/006/007及用户追加书架操作/多选已分批提交，最新210dc66；逐章状态的真实外部账户/备份等未验边界仍保留。
2. **P1：RDR-004、SEA-001/002、PRI-001**。RDR-002/003已按第22–23节关闭无效入口，真实裁边能力继续缺失；先处理章末被迫中断、搜不到/读不到完整内容，不因空入口关闭宣称能力补齐。
3. **P1：DL-001、CHP-001、UPD-001**。完整章节选择与下载、可用的具体新章追更入口；依赖章节 ID、已读状态和目录完整性，不先做自动下载规则包装。
4. **补审后的 P1 依赖**：DL-003/004 活跃任务/暂停继续先于扩大下载批量；LOC-002、IDN-001/002/003纳入内容身份切片；TRK-002先于TRK-003自动回写，SYNC-002先于SYNC-001重试。UI-001..004在对应用户流程中做独立切片，不能因叫UI就全部降到P3，也不能为风格重写根shell。
5. **P2：其余日常便利性、真实账户/服务闭环与条件性风险**。按第 9、12 节处理，平台/删除范围问题先决策；不默认照搬对标方能力。
6. **P3：产品深化与工程债**。统计、书签、无痕、跨源迁移、Kitsu、源码大文件拆分等保留候选，不自动立项；发布必要项在实际发布阶段单独核准。

**D34 的新状态**：用户已提出仅关闭 Koma 联网权限的方案。此前只定位到系统“应用联网”入口，尚未切换权限，也未完成离线验证；此次按新要求暂停。后续可采用应用级限制，先确认 WLAN 是否被该权限覆盖、记录并恢复原值；**禁止关闭整机 Wi-Fi 或影响 HDC**。优先验证已下载/未下载章节、冷启动与返回，不先造损坏文件或扩展故障注入。`ReaderPage.ets:2192` 传 `preferOffline`，不是 `offlineOnly`；这是策略接线事实，不等于已经证明离线阅读失败。

## 6. 当前边界与重新开工条件

- 用户已授权每批197验收后独立提交并继续；搜索/书名/分页、下载执行、详情续读、连续懒列表、单本F/S及跨漫画入队已分批限域提交，当前修复LIB012网格实时投影，不发布。197正常阅读/下载限于选定少量样本并记录实际数据变化；不得关闭整机 Wi-Fi，不为取证保存/移除真实私库配置，不修改真实Tracker账号或创建/恢复覆盖书架与备份，不推送。ReaderLab独立任务WIP保留，不迁入生产Reader或本批提交。
- 本轮方案/首轮归类交付，不等于 A1–A3 全面审查完成。下一审查工作按第 10 节的未覆盖项推进，而不是再回到零散 UI 修补。
- 正常可推导的技术选择不反复停下来求确认；只有改变产品边界、删除范围、使用新账号/服务或产生其他重要副作用时，带证据提出具体决策。已确认但不需要决策的问题保持排队，不自动无限搁置。
- `537fe54` 缩放所有权、`af29def` 页码可辨识度、`606e498` 菜单锚点、`235e3fa` 下载页面、`8aeb57f` 宽图拆分、`a540f1e` 搜索间距属于已存在提交；不重复实现。只有新的同场景回归证据才重开原缺陷，不能用旧误判恢复旧方案。

## 7. 文档权威层级

| 文档 | 用途 | 权威性 |
| --- | --- | --- |
| `docs/agent-guides/koma-rules.md` | 项目边界、执行纪律、设备/签名与 artifact 规则 | 当前执行规则，最高 |
| `docs/agent-guides/reader-rewrite-standards.md` / `reader-rewrite-violation-log.md` | 阅读器实现与验收强制纪律 | Reader 切片的强制执行规则 |
| `docs/CURRENT_STATUS.md` | 当前实现、缺口、197 证据和唯一执行队列 | 当前状态权威 |
| `README.md` / `docs/PRODUCT_PLAN.md` | 产品定位与长期方向 | 方向权威，不记录完成度 |
| `docs/WASM_SOURCE_RUNTIME_DIRECTION.md` / `docs/source-runtime-abi.md` | source runtime 专题方向/ABI | 对应专题权威，仍需以代码和测试核实实现状态 |
| `docs/FEATURE_PROGRESS_20260524.md` / `docs/ROADMAP.md` / `docs/APP_GAP_PLAN_AIDOKU.md` | 早期进度、分解和 gap inventory | `HISTORICAL`，不能关闭当前缺口 |
| `docs/FEATURE_COMPARISON_AIDOKU_MIHON.md` / `docs/THREE_WAY_ROADMAP_NEXT_E_AIDOKU_MIHON.md` | 竞品能力与参考方向 | 参考资料，不是当前状态表 |
| `docs/AIDOKU_SOURCE_COMPARISON_PLAN.md` | 2026-07-03 Aidoku 源码级对照 | 历史参考；Koma 状态逐项复核 |
| `docs/UI_IMPLEMENTATION_AUDIT.md` / `docs/plans/active/koma-system-audit-and-remediation-plan.md` | 某一时点的审计、问题证据与修复设想 | 历史证据；逐项用当前 HEAD/197 复核 |

## 8. 更新纪律

- 业务切片开始前先更新代码基线；结束后只把真实验证过的范围改为 `197_VERIFIED`。
- 旧文档的完成状态不自动迁入本文；提交存在也只证明代码历史，不证明当前行为。
- 验证记录必须写清“观察到什么”，并单列“没有验证什么”。
- 如果当前 checkout、设备、页面或账户发生变化，旧 artifact 降级为 `HISTORICAL`。
- 不在多个路线图中维护互相竞争的“下一步”；执行队列只在本文维护。
- 新发现先登记问题 ID、用户影响、代码/设备证据和分类，再决定是否插队；插队必须写明替代了哪项及原因。关闭同一 ID，不另造一个“新计划”让原问题失踪。
- 每个问题关闭记录包含责任切片/提交、实际设备场景、受影响下游回归和剩余边界。截图通过但状态/返回路径未检查，不得关闭语义或状态问题。

## 9. 统一问题登记（首轮，不代表已找齐）

本节路径默认相对 `entry/src/main/ets/`，行号为原审查基线的检索定位，后续改动后须复核。状态以各行及第12节后的对应切片记录为准；未注明关闭的项仍开放。“代码确认”不等于真机复现，新增197观察须引用对应场景。相同根因合并登记，不把一个设置的三个断点算三项成果。

### 9.1 日常主流程：P0 / P1

| ID / 严重度·优先级 / 类型 | 已确认事实与用户影响 | Koma 证据 / 对照 | 关闭条件与依赖 |
| --- | --- | --- | --- |
| **LIB-005 / S2·P1 / 设置生效链** | 3d03747已限域修复保存通知与列表旧集合读取；视图/排序即时双向成立。 | 第19节当前qa-final/02–06主控与独立实际view；首包排序失败保留，密度为首包证据。 | 已限域提交；原四设置恢复、读态不变。真实分类标签当前无样本仍未验证，不代表书架整页视觉通过。 |
| **LIB-006 / S2·P1 / 批量栏与选择链** | 原批量栏裁切；网格全选回显不一致；菜单点不出；长按后首击被吞。 | 第20节三包逐增量197证据；首候选与补包失败保留。 | 3e3a4f0限域关闭可辨识/选择/菜单打开取消；不含真实批量数据赋值或移出、不外推全书架通过。 |
| **LIB-007 / S2·P1 / 列表行尾部与菜单接线** | 原本地菜单压住进度且两布局菜单不弹；1a24106已限域修复。 | 第21节同包qa-after/01–10及独立实际前后对比；原失败保留。 | 已限域提交：菜单/进度分離，原菜单开关/重开/选择和正文详情可达，设置/数据恢复。不含真实移出或全书架视觉；LIB008另列。 |
| **NAV-001 / S1·P0 / 路由语义** | 原普通书架封面/列表与继续阅读共用直读回调；已由a2dbd6b分流，197网格/列表、继续阅读、返栈及选择取消限域通过，见第17节。 | Aidoku默认opensReaderView=false。当前LibraryPage新增详情event，Index源用remote pair、本地/私库用库存comic.id；三文件必要hunk与新固定包实际复核。 | 主路径已限域提交；本地只验库存详情，四私库真实服务、源失败回退设备链仍未验收，不升级为全书架/离线通过。同期LIB-005/006保持FAIL_OPEN。 |
| **RDR-001 / S1·P0 / 状态持久化** | 原A完成→B后A状态/位置丢失已真机复现；e197d63统一章域后，跨章位置/冷启、手动即时回显、三模式实际末图完成及退出保持通过，见第18节。 | 同一owner分别保存recent/逐章位置/已读；书架聚合、详情回显、bootstrap及备份接线一致。首候选行不刷新和退出compat分叉曾拒收，新包独立补验后提交。 | 仅限域关闭；历史清理、旧覆盖迁移、备份替换为生产方法host检查，真实备份/账户同步与后台末图异步竞争未获197验收。无Reader布局/手势改动，不代表RDR-002..005完成。 |
| **RDR-002 / S2·P1 / 无效适配入口** | 两处设置提供宽/高/完整三项，分页/双页实际固定contain；只传参数会造成绘制与pan边界脱节。 | 第22节现代码、NextE代码及197两应用实际设置对照；748a519限域关闭。 | 两入口及派生搜索已移除，原画质菜单197有效；不是实现宽高适配。渲染/手势零改动，保留旧偏好兼容；不扩为完整Reader验收。 |
| **RDR-003 / S2·P1 / 无效裁边入口与能力缺失** | 开关真实保存，但当前Reader没有检测、边界、裁框绘制或裁后尺寸链；拆宽图不是自动裁边。NextE确有完整裁边能力。 | 第23节实际源码及197前后原图；b99b30d限域关闭两空入口，ReaderPage零改。 | 入口/搜索关闭及原相邻菜单197通过；不是补齐裁边。自动裁边仍MISSING，重新实现需有边/无边/正文边界及缩放拖动矩阵，不能用撤入口冒充对标完成。 |
| **RDR-004 / S2·P1 / 阅读连续性** | 本章最后一页后普通翻页停止；下一章须从菜单/目录选择。预加载也仅限本章。 | `pages/ReaderPage.ets:2422,2457,2480,2704,3048`。Aidoku ReaderPagedViewController:879,946,961 与 ReaderWebtoonViewController:440 有邻章过渡/加载。 | 197 正常相邻章正反衔接、首末章边界、加载期间反馈、返回和进度正确；分页/连续分别核实。先明确 RDR-001 状态写入，不能只加下一章预缓存。 |
| **SEA-001 / S2·P1 / 找书链路缺失** | 原全局摘要无继续入口；eaa6d86给ready WASM原标题加原生箭头，携已执行关键词进入现有源结果，修按值Builder旧数组捕获。 | 第26节qa-grid-refresh三源真实新增项、详情与六对返栈文字/坐标；原两候选失败保留。 | 来源/query/结果与滚动保留已限域提交；不是全局无限加载、全集遍历或整项目UI通过。MangaDex书名错误另列SEA-006。 |
| **SEA-002 / S1·P1 / 搜索完整性** | Kavita 搜索枚举前10库、每库前20本后本地匹配；准确书名在枚举范围外也显示未找到。 | `model/CrossSearchService.ets:308`。Aidoku KavitaSource:142 / KavitaHelper:341 将查询条件交给服务端。 | 真实 Kavita 中目标在第21本之后/后续库仍搜到；核对目标服务实际 API 与版本，不能凭参考直接替换协议。与无结果、未配置状态区分。 |
| **SEA-005 / S1·P1 / 搜索分页契约** | 源仓3656597纠正App cursor对象消费、DM5实际页码、Komiic分页与lookahead、MangaDex offset/total。 | 第26节三源197真实后续结果与同次首批对照，源包正常升级；终页仅host证据。 | 搜索分页限域提交，不涵盖非搜索源浏览分页；DM5上游窗口变化/交集保留，不能声称稳定全集。原SEA-003误编号已纠正。 |
| **SEA-006 / S2·P1 / 书名字段越界** | 源仓8fde3b2限定attributes.title直接成员，MangaDex0.1.4在197同书搜索/详情已正确显示原API书名，简介保留。 | 第27节qa-after07/08与旧24/25实图、70874运行日志、原始API及四producer host回放。 | 两文件限域提交；不涵盖全部元数据或四producer真机矩阵。SRC002版本列表刷新仍FAIL。 |
| **PRI-001 / S1·P1 / 目录完整性** | Komga 系列内 books 固定取 page0,size100，收藏也使用该批，没有后续目录入口；正常百话长篇内容不可达。 | `pages/KomgaSeriesPage.ets:158,249`。Aidoku KomgaSource:173 获取完整章节；Koma 的系列列表分页已存在，问题是系列内部 books，不是全域没有分页。 | 真实系列第101本及末本可见、可阅读；收藏后目录完整且顺序正确，更新不退回首100本。参考完整性要求，不强制使用相同 API 参数。 |
| **DL-001 / S2·P1 / 批量能力** | d373c8b6取消手动展开，批量取完整筛选F并数量确认；9778d9c2补齐任意选章S；ce384c0a补齐书架跨漫画全部/未读入队，取已保存目录、不隐式刷新。 | 第31、35、39–40节197证据：221章F确认、非相邻S2下载27页、跨漫画两本下载15页及重复跳过；当前包忙碌反馈另有连续录像，虫笼真实取页受阻0页保留。 | 上述集合及入队路径限域关闭；未执行221章大批、不证明远端目录绝对完整。约49秒初始化与虫笼取页通用错误未解决；D34应用级离线另列。 |
| **CHP-001 / S2·P1 / 章节管理不完整** | 9778d9c2已加入任意章节多选、原生Checkbox及S∩F；单本筛选/排序仍为组件本地状态，离开重进不恢复，选择状态按本片方案不持久化。 | 第39节197：非相邻ID、跨80回收、排序保留/筛选裁去、原高度与单章动作、S2真实读态操作/还原。Aidoku单本条件持久化仍仅作后续参考。 | 任意选章限域关闭；单本条件的返回/重启恢复仍未实施，不把临时S选择持久化和筛选偏好持久化混为一个需求。 |
| **UPD-001 / S2·P1 / 追更入口缺失** | 当前仅最新一次逐本检查报告（章节数量前后差），不是可浏览历史、定位具体新章的追更列表；检查任务成功不等于用户知道该读哪章。 | `model/LibraryUpdateService.ets:69` 结果无新章ID；`model/LibraryUpdateResultStore.ets:27` 单份latest；`pages/LibraryUpdateResultPage.ets:187,341` 打开漫画详情。Aidoku MangaUpdatesView:12,90,140 按章节身份/日期保存展示。 | 两次有新增的检查后均保留具体章记录，可进入该章/详情，已看/已读语义区分且重启保留；保留现有任务报告供诊断。先核对章节身份和状态，不先扩展后台调度。 |

### 9.2 次优先级能力与明确边界

补记 **LIB-008 / S3·P2 / 选择态角标重叠**：LIB007固定包`qa-after/09-grid-menu-select/screen.png`实际可见原网格左下选中勾遮住部分50%进度角标。后续用户将其提升为优先书架切片，现已在第25节以原生Checkbox、进度独立层级及197原图对照关闭，提交210dc66；不是潜在风险推测，也不再排作未修。同期LIB-009结构跳动、LIB-010普通滑动误选在第25节登记实证并修复。

| ID / 严重度·优先级 / 类型 | 事实、证据与对照边界 | 验收或决策出口 |
| --- | --- | --- |
| RDR-005 / S2·P2 / 单本偏好缺失 | `model/ReaderPreferencesStore.ets:541,583` 忽略 comicId，loadForComic/saveForComic 实为全局。Aidoku ReaderSettingsView:47 按漫画覆盖模式。此前全局统一是有意避免旧覆盖遮蔽全局设置，不能当偶发回归。 | 全局默认 + 明确单本模式/方向覆盖 + 恢复默认；A/B不同、冷启动保留。禁止恢复旧整份偏好快照机制。 |
| SEA-003 / S2·P2 / 筛选入口不完整 | `pages/SourceSearchPage.ets:75,82`、`viewmodel/BrowseViewModel.ets:865` 拒绝空 query；Aidoku SourceSearchViewModel:62 允许 query+filters。已有源 listing 筛选，不等于无关键词源搜索已接通。 | 用明确支持条件查询的源，无关键词选分类即可检索、续页；源不支持时据实处理，不给所有源强加相同能力。 |
| SEA-004 / S2·P2 / 相关发现语义 | `pages/MangaDetailPage.ets:2109` 标签转全局关键词；`components/MangaDetailHeader.ets:148` 作者仅文本。Aidoku MangaDetailsHeaderView:147,388 有作者查询和源 genre 映射。 | 标签/作者支持可追溯查询条件；源不支持相应筛选时不冒充分类结果。无需照搬外观。 |
| LIB-001 / S3·P2 / 书架内搜索 | `pages/Index.ets:2002` 进入全局搜索；LibraryPage 当前投影无 query。Aidoku LibraryViewController:1633 搜当前库。全局能搜本地，不等于能在当前分类内找书。 | 当前书架/分类的检索范围清楚；结果、清除、分类切换和返回保持一致。 |
| LIB-002 / S3·P2 / 书架排序 | `model/LibraryStore.ets:20,123` 为最近读/加入/标题/来源固定顺序；缺更新/未读数排序与方向选择。Aidoku LibraryViewModel:45 有相应维度。 | 先选择适合 Koma 的排序项；真实书架结果与正倒序一致、持久化，依赖可靠章节/更新状态。 |
| LIB-003 / S3·P2 / 数量可见性 | `pages/LibraryPage.ets:835` 当前角标主要是分类；`components/ComicCoverCard.ets:5` 无未读/下载章数。Aidoku LibraryViewController:471 有这两类数字角标。 | 在封面/列表提供可辨识且准确的章数信息，不挤压封面和标题；状态变化后及时更新。依赖 RDR-001/DL-001。 |
| SRC-001 / S3·P3 / 常用源管理 | `pages/BrowsePage.ets:195` 直接遍历启用源，无常用置顶/重排/源名搜索。Aidoku BrowseViewController:384、BrowseViewModel:159 有这些能力。 | 多源场景价值确认后实现；不优先于“搜到/读到完整内容”。 |
| SRC-002 / S2·P2 / 升级后版本回显滞后 | SEA006 qa-after/04同页上方已装0.1.4、下方已安装仍0.1.3，05浏览根页也0.1.3。Root与独立review实际看图；07/08实际搜索详情已运行70874字节新包、书名正确。 | 更新后的所有源列表即时显示新版本，不靠重启；显示问题与真实运行版本分别验证。当前保留FAIL，未修App。 |
| DL-002 / S3·P2 / 下载清理策略 | `pages/DownloadsPage.ets:817,857` 为单项删除/按状态清空，无已读后自动清理。Aidoku ReaderViewController:901,333 有读完后删除流程。不是现有手动删除故障。 | 自动删除属于破坏性策略，须明确用户开启和保留范围；默认不擅删下载。 |
| TRK-001 / S2·P2 / 授权接线 | `pages/TrackerSettingsPage.ets:719` 起需手填 clientID/redirect/callback；module.json5 未配置相应 OAuth 自动返回链。账户/映射/同步主体已有。 | 分服务核准授权方式，真实授权→返回→保存→冷启动→进度回写。需要真实账号时单列条件，不假造已连接。 |

### 9.3 已知条件性缺陷 / 平台和产品决策（不挤占主流程）

| ID / 严重度·优先级 / 类型 | 当前事实 | 处理边界 |
| --- | --- | --- |
| LIB-004 / S2·P2 / 删除范围决策 | 书架批量移出经 `model/LibraryPersistence.ets:688` 仅允许 LOCAL_ARCHIVE/FOLDER；源详情有单本移出。Aidoku 支持多选移出。该限制与当前仓库明确删除规则一致。 | **不得当普通 bug 绕开规则。** 若扩展，须明确只删除书架引用，不删除外部原文件/服务器内容，并取得范围决策。 |
| PRI-002 / 待定·P2 / 格式范围决策 | `pages/WebDavBrowsePage.ets:94` 只保留目录/图片，CBZ/ZIP 不进入浏览阅读；OPDS 支持层级/publication和图片manifest，并非任意文件阅读器。Aidoku 本地快照没有 WebDAV 对照。 | 明确私库支持格式承诺，决定接入远端压缩包还是据实提示范围；不能编造成 Aidoku 同项领先，也不自动支持所有格式。 |
| LOC-001 / S2·P2 / 目录进度映射 | 第1节已有源码/host记录：目录增删使用序号页ID，未按旧URI迁移位置；197 不具目录选择能力，入口已隐藏。 | 有授权且支持的环境才验收增删后恢复同页；当前不切换其他设备，不以缓存漫画关闭缺口。 |
| BK-001 / S1·P2 / 条件性恢复一致性 | `model/BackupService.ets:945` 起先写库/进度，:960 后处理源包，:1232 源包校验仍可失败。非法源包数据可在已有部分写入后报错；代码链及隔离 host 检查已确认，未操作真实备份恢复。 | 影响可能较重但需特殊输入；登记，不扩展故障注入抢主线。后续先完整验证再应用/可恢复提交，使用可丢弃样本，不能覆盖用户现场取证。 |
| BK-002 / S2·P2 / 自动备份触发不完整 | `pages/Index.ets:1352,1432` 自动备份入口受本次生命周期一次性标志限制；有到期/保留数逻辑，不是无实现。 | 后续核对前台恢复和长期驻留的真实到期路径；不默认升级为系统后台服务。 |
| SYNC-001 / S2·P2 / 私库回写条件性缺口 | `model/RemoteProgressSyncService.ets:163,254` 发送前从内存 pending 删除，失败分支记录日志，未持久化待重试项。 | 分清服务器权威与本地阅读状态；真实服务暂不可用→恢复时验证回写策略。不能称为全产品跨设备同步缺失。 |
| SYS-001 / S2·P2 / 系统后台能力缺失 | 当前更新协调器为应用级前台执行，下载也不是系统后台任务；WorkScheduler/BackgroundTask 未接通。 | 先界定系统能力和产品承诺，不伪造后台执行；系统授权/跨进程一致性另切片。 |

### 9.4 验证欠账（不是已确认缺陷列表）

| ID | 实际要补的证据 | 当前边界 |
| --- | --- | --- |
| V-UI | 根页和所有用户可达子页：布局密度、内容可辨识度、菜单锚点、键盘/返回、多选；至少沿完整任务操作，不只拍空页面。 | 外边距/搜索占位/菜单/页码有历史场景通过；不代表全局视觉已审完。新视觉缺陷发现后另登记原因和实际影响。 |
| V-RDR | 当前构建单/双/连续/纵向分页、方向/旋转/拆分、物理pinch、保存/分享的实际动作矩阵。 | 已有实现与历史证据不重写成“未实现”；裁边/适配无效已独立登记，不能放在这里掩盖。 |
| D34 | 197 仅限制 Koma 联网后，已下载/未下载、冷启动、详情/继续阅读/下载入口与恢复联网。 | 用户提出方法，本轮未执行。应用级权限是否实际限制 WLAN 必须验证，整机 Wi-Fi 不动。 |
| V-LIB | 分类 CRUD/批量操作、筛选实际数据、历史删除与返回联动，本地导入完整普通路径。 | 当前有功能代码/部分菜单证据，缺本轮完整结果；涉及删除/导入只用获准样本，不动用户既有库。 |
| V-EXT | Komga/Kavita/OPDS/WebDAV真实服务；Tracker真实账号；通知允许/拒绝/点击；干净环境备份恢复。 | 分项注明服务/样本/授权条件。缺条件不是全域没有能力，也不能拿 host 成功替代。 |
| V-REL | release输入/签名边界、发布信息、Smoke诊断入口、许可证/隐私信息可达性。 | 本轮未做发布验收；不为审计立刻改工程配置、补测试框架或拆大文件。 |

### 9.5 跨模块补审确认项（2026-09-05/06）

以下为当前生产链确认，除明确注明外不冒充197复现。详细调用链与参考定位保存在 `.hermes-artifacts/20260905-audit-continuation/{identity,state,downloads}/notes.md`，统一ID和优先级只在本文维护。

| ID / 严重度·优先级 / 类型 | 正常使用影响与代码证据 | 关闭条件 / 依赖 |
| --- | --- | --- |
| IDN-001 / S1·P1 / 收藏身份 | `KavitaBrowsePage:441–464` 阅读前无条件重建并 upsert Comic；`KavitaModels:226–242` 不含分类，`LibraryStore:178–183` 全对象替换。未收藏阅读会自动入库，已有分类被新对象覆盖。 | 未收藏只读仍不入库；已收藏从浏览阅读不丢分类，返回/重启一致。不要为修历史而强制收藏。 |
| IDN-002 / S1·P1 / 服务身份 | `RemoteServerStore:61–76,364,430,494,564` 同协议只有固定 default ID；换服务器后 numeric remote ID 可撞旧库记录。LibraryUpdate/Reader仍按当前协议槽取服务。 | 服务器身份与URL草稿分开；A/B同系列ID不混淆，旧收藏/进度可定位原服务。不以“支持多服务器列表”代替身份修复。 |
| IDN-003 / S2·P1 / 私库返回与历史 | Komga/OPDS/WebDAV未收藏阅读正确使用临时配置，但 `Index:532–562` 未记录可恢复内容身份；`HistoryPage:123–148` 无法显示该阅读；Reader转详情经 `Index:768–806` 回落到不存在的库记录。 | 三协议分别验证未收藏阅读→详情→返回→历史重开，不自动入库。需要真实测试服务。 |
| LOC-002 / S1·P1 / 正常导入覆盖 | `ArchiveImportService:46–47` 以 basename 生成ID，`ImageSortUtils:35–41` 丢弃目录；两目录的01.cbz同ID，Index:998→LibraryStore:182覆盖。重复导入的新对象也丢分类/本地元数据。真实生产方法内存检查已复现。 | 同名不同文件保留独立身份；重复导入明确合并并保留用户字段/进度。原始中文URI另有归一化碰撞，但picker编码未证，不宣称所有中文导入必撞。 |
| DL-003 / S2·P1 / 下载执行所有权 | 9516ac6统一前台同章owner、一次冷初始化与queue通知；管理页稳定身份读取当前状态，不再入页可写恢复。旧197复现17/32陈旧UI而落盘32/32；当前197同页9→33→45→46及180/180，见第30节。 | 前台正常路径限域关闭；冷进程中断/多任务并发未做原生扩展验证，host不替代。 |
| DL-004 / S2·P1 / 暂停继续与结果反馈 | 9516ac6续传机制、68a70d9b正常暂停反馈均已限域提交。第38节固定包197真实“已暂停”toast、中性图标/等待分类，稳定11/40→同页40/40且原11页记录保留。 | 正常暂停反馈闭环限域关闭；3次执行失败保留。当前样本无真实失败项，未点击FAILED；批量混合/runRetry仅host，冷中断未验收，顶部汇总省略未修，不外推整页通过。 |
| TRK-002 / S1·P1 / 对外状态语义 | `TrackerProgressSyncService:127,267–281` 把当前章completed传到AniList:336–347/MAL:310–324，转成整部作品完成；手动同步/标章已读是可达入口。章数量又按数组index+1而非真实章号。 | 第1/100章完成不能标全作完成；倒序/多组不误算章号。须先于自动接线，账号写入用获准样本。 |
| TRK-003 / S2·P1 / 自动策略未接线 | 设置提供章节完成/Reader关闭自动同步，但pushReadingProgress仅详情手动标记/手动同步和服务重试调用；Reader/Index退出链没有调用。 | 两自动策略真实回写，manual不自动；先TRK-002，不先把错误语义自动化。 |
| SYNC-002 / S2·P1 / 私库回写未接线 | RemoteProgressSyncService的push/pushSession没有产品调用；唯一生产实例RemoteProgressBootstrapSync:62,119只pull。正常Reader进度不会向Komga/Kavita发出。 | 真实服务对应章节页码随阅读/退出更新。优先于SYNC-001失败重试持久化。 |
| SYNC-003 / S2·P2 / 私库拉取范围 | Bootstrap:112–124每本一次pull；RemoteProgressSync:53–61,400–407只选第一可读章。Komga第5章服务器进度不进入输入。 | 第1章无进度、第5章中途启动恢复到第5章；不外推Kavita分支。 |
| BK-003 / S2·P2 / 正常备份覆盖 | e197d63已将章域并入同一reader文件，备份flush/替换归一化/owner重载和消费者刷新已接通；隔离生产方法验证旧/空备份不混入本机旧覆盖。 | 实现及host限域通过，真实干净样本恢复逐章已读/未读、最近位置仍未验收；不以RDR设备阅读证据代替真实恢复。 |

RDR-001 补充下游：LibraryStore:114–120把当前章完成作为整本完成筛选；LibraryPage:1264–1324手动整本标记还改最近指针；手动未读override未随重新读完更新。以上并入原ID，不另计多条。跨章、手动覆盖、筛选、继续阅读、备份和Tracker必须共同回归。

已排除的误判：WASM未收藏阅读已有sourceHistory且不自动入库；明确收藏有身份/历史去重；源升级保留source ID，卸载不删除书架/历史/下载；Reader多项可见设置已有实际消费者，不把死存储字段算空开关。

需要产品决定而非伪装成bug：WASM下载当前先收藏（MangaDetail:1329,1493），普通阅读不收藏；“下载是否等于收藏”在实现相关链路前确认。全产品审查不授权自行改变这一语义。

## 10. 全产品审查覆盖与未覆盖项

“源码首轮”表示表中列出的主链已追踪，不表示该领域所有分支都审完；“局部”不能升级成全面。本轮新增197证据见第12节，各域源码补审见9.5；旧表中的待查项仅在补审明确列出的范围内推进，不整体关闭。每域还需核对普通成功路径、返回/重进、状态持久化及最常见失败反馈，不要求先穷举低概率故障。

| 用户域 | 本轮源码/参考覆盖 | 尚未覆盖 / 197 下一组正常场景 |
| --- | --- | --- |
| 根导航/书架进详情/继续阅读 | 源码首轮，Aidoku默认路由已对照；NAV-001 | 各来源身份、根/子页返回栈、网格/列表/选择模式；尤其本地ID与remoteID。 |
| 收藏/书架管理/历史 | 源码补审：WASM收藏/临时历史去重、私库临时阅读、Kavita自动入库；IDN-001/003，分类UI见36 | 分类实际CRUD结果、历史与返回的197数据联动；私库真实服务。 |
| 找书/源浏览/全局及源内搜索 | 源码首轮，Aidoku搜索及筛选链已对照；SEA登记 | 实际第2页、过滤无关键词、查询切换/返回、源能力差异；首页不同组件类型只局部检查。 |
| 漫画详情/章节管理 | 源码首轮：已有详情路由、章节排序/筛选/下载；CHP登记 | 首开/重复进入的缓存和加载、刷新后的选择状态、作者/标签语义、跨80章批量；没有整域性能验收。 |
| 阅读渲染/手势/设置 | 源码首轮，NextE相关渲染和Aidoku跨章对照；RDR登记 | 当前197完整模式/方向/旋转矩阵，所有可见设置逐项确认消费者与实际效果；不是全NextE逐行迁移验收。 |
| 阅读进度/已读/历史联动 | 源码补审：RDR-001下游筛选/手动覆盖、TRK-002/003、SYNC-002/003和BK-003 | 跨章/冷启动/跨入口实际回显、历史清理；外部状态用真实测试账号/服务验证，未做写入。 |
| 下载管理/离线 | 源码补审：活跃任务reconcile、页面订阅缺失、暂停/继续、进程残留；DL-003/004；既有完成记录UI可打开 | 活跃任务197复现、多章多书、应用级禁网D34；后台不能从前台成功推断。 |
| 追更/更新结果/通知 | 源码首轮：协调器、结果持久化和页面；Aidoku章节更新对照 | 两轮实际新增章、多来源目录变化、打开新章和通知返回；具体新章追更能力缺失已登记，不再只盯任务失败分类。 |
| 本地导入/元数据 | 源码补审：压缩包/图片正常导入与重复导入、身份生成、写入与元数据；LOC-002生产方法内存复现 | CBZ/ZIP及多图真实picker→详情→阅读→冷启动；未覆盖用户现场；支持目录的环境不在当前197验收内。 |
| Komga/Kavita/OPDS/WebDAV | 源码补审：配置槽/身份、目录、收藏/阅读、凭据与同步消费；IDN/PRI/SEA/SYNC；四空表单197可达 | 四服务真实内容矩阵、身份隔离和历史返回；不能用一个私库替另三个验收。 |
| Tracker/备份恢复 | 源码补审：自动触发、整作/章节映射、备份实际数据域；TRK/SYNC/BK；UI-002/003已197观察 | 197连接暂不可用；账号正常闭环、映射/解绑和干净样本恢复未验，不用页面存在当可用。 |
| 源安装/管理/信任/升级 | 源码补审：升级保持source ID、卸载不删库/历史/下载，临时历史与收藏；33/34核对管理与索引sheet | 实际升级后旧书架/进度、卸载后离线阅读、重装恢复；密码学签名按产品边界登记。 |
| 设置/外观/全局可辨识度/关于 | 局部：外边距、语言、未接通应用外观移除既有证据 | 所有可达设置的“可见值→真实消费者→持久化”，所有主页面空/满内容、长标题、菜单和键盘；Reader已查出反例，不能说设置全完成。 |
| 发布/工程结构 | 局部：构建记录、签名本地差异、超大页面/旧脚本引用 | 发布场景另审；工程债不替代用户流程。无本轮性能测量，不根据行数断言性能瓶颈。 |

### 审查收口标准

1. 每个领域都必须有“核对过什么 / 未核对什么 / 问题ID / 验证条件”，不得漏域、写一个总 PASS 或只统计页面数量。
2. 高频链路以正常真实内容验证，先找稳定可复现问题；边界样本采用正常规模（第2页、第101章、多章阅读），不是随机故障注入。
3. 对第9节已确认的问题补实际场景，不在取证时顺手修复；新发现相同根因并入原ID，不同根因新增并说明优先级。
4. 无设备/服务条件的条目明确保留未验收，其余继续；只有每个域的审查边界可复核，才交付“本轮全面审查报告”，仍不保证不存在未知缺陷。

## 11. 跨模块状态与所有权检查

这是发现隐性问题的必查项，不是要求立即做架构重构。

| 状态/对象 | 写入与消费链 | 必须核对的不变量 / 本轮发现 |
| --- | --- | --- |
| 漫画身份与库成员关系 | 搜索/浏览/导入 → 收藏/详情 → LibraryStore → Reader/下载/更新 | NAV-001为路由；补审IDN-001/002/003与LOC-002确认自动入库、服务槽碰撞、临时身份丢失与同名导入覆盖。WASM明确收藏/临时历史链未发现同样错误。 |
| 最近阅读与逐章历史 | Reader → ReaderSessionStore / ChapterReadStateStore → 详情/书架/历史/批量未读 | 最近指针不能代替逐章状态；RDR-001下游筛选/手动覆盖与TRK-002、BK-003需共同回归，自动接线不能先发错误状态。 |
| 阅读偏好与图片几何 | 菜单 → 偏好存储 → 会话 → 渲染/手势 | 每个可见开关必须有实际消费者，全局默认与单本覆盖清楚；RDR-002/003/005已确认。 |
| 章节集合与用户选择 | 私库/源请求 → 目录模型 → UI窗口/筛选/多选 → 下载/标记/阅读 | 总目录、过滤集合、展开窗口、选中集合是不同对象；PRI-001、DL-001、CHP-001反映混用/截断，不能分别补一个按钮收工。 |
| 下载任务与离线可用性 | 页面动作 → 任务/manifest/文件 → 列表状态 → Reader资源选择 | DL-003/004已确认活跃执行/恢复范围错误；任务成功、文件完整、禁网可读仍非同一事实，D34不被源码/已有完成记录关闭。 |
| 更新任务与新章事件 | 协调器 → 目录对比 → 最新任务报告 → 用户追更/通知 | 一次job结果不能代替跨轮的新章事件记录；UPD-001已确认，先补产品结果，不先做后台机制。 |

现阶段交付边界：完成了上述审查方案、覆盖表和首轮问题归类，并纠正旧状态；**未完成全产品197复核，没有修复本节新发现的问题，没有提交代码。**

## 12. 197 续审与早期 UI 专项（2026-09-05/06）

### 12.1 现场与证据边界

- 本轮仍为 `a540f1e` + 既有工作树，只观察设备已安装包，未构建/替换；不能断言安装包与工作树每个字节一致。197实时Connected，型号ALN-AL80、竖屏1260×2720；23:55恢复后仍为原Kavita配置页。
- 原图、layout、协议、命令时间保存在 `.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260905-comprehensive-audit/`。以下步骤名均相对此根。每步已打开原图后才能作为视觉证据；只读layout不算看过图。
- 未保存/移除私库配置、未连接Tracker、未导入/恢复/删除真实数据、未触发下载或备份；没有改Wi-Fi或应用网络权限。早段正常阅读更新最近阅读到ONE PIECE第00话第4页；适应模式临时改高度后已恢复适应屏幕。
- `19-resumed-current-gate`连续亮屏门禁和后续power读回均为AWAKE、OverrideTimeout=86400000ms。`24-webdav-keyboard`图为黑色、layout仍包含Koma与安全键盘，**拒绝作为视觉验收，不断言App黑屏**；未绕过安全键盘截图保护。普通返回已回到设置。
- 收口时经`41-privacy-notice`查看现有隐私说明，未作合规验收；`42-restored-kavita`已返回最初的Kavita空配置页，原图已查看，未留下测试配置。

### 12.2 本轮已复现的主流程问题

| 问题 | 已观察结果 | 场景 |
| --- | --- | --- |
| NAV-001 | 书架普通ONE PIECE封面→Reader第4/23页；返回直接书架，没有详情；继续阅读入口仍直读。 | `04-library-root`→`05-shelf-cover-opens-reader`→`06-reader-back-shelf`→`07-continue-reading-chrome`。仅网格样本，不外推列表/所有来源已验。 |
| RDR-002 | 同页选适应高度后，设置值变化而图片构图/留白不变；已恢复适应屏幕。 | `07-continue-reading-chrome`、`09-reader-display-settings`至`14-fit-restored`，关键结果`12-fit-height-render`。此页宽度适配本来可与contain相同，因此没有用适应宽度不变冒充第二个反例。 |
| 正确返回链 | 既有源详情Back回下载管理，再回下载设置和设置根；未修改下载记录。 | `02-library-baseline`实际是恢复的ONE PIECE详情，文件名不能当书架证据；`03-detail-back-downloads`记录4章102/102页。不是本轮新下载成功证明。 |

### 12.3 UI 问题归类

用户要求不是强制复制NextE，而是消除明显割裂和低可辨识度。**共享组件存在不等于页面已完成设计；表单与导航行不同也不自动构成缺陷。** 本轮按任务分组、可读性、状态与实际操作核对。

| ID / 严重度·优先级 / 类型 | 已确认问题与受影响面 | 依据 / 修复验收出口 |
| --- | --- | --- |
| UI-001 / S2·P1 / 私库配置任务与状态 | Kavita/Komga/OPDS/WebDAV都把输入、保存测试、移除、结果放同一FormCard；空态仍显示灰色但可点的“移除配置”。Kavita只有Auth Key/x-api-key，无取值帮助；WebDAV路径示例截断。并且四页改草稿不清旧成功提示，测试结果不对应当前输入（代码确认，未用真实服务复现）。 | 四页FormCard分别Kavita:112、Komga:143、OPDS:133、WebDAV:118；`19/21/22/23`。按未配置/已配置/编辑/测试结果分清语义，主次/破坏性操作明确、帮助完整；保留真实鉴权差异。外边距、根标题和黑色主按钮本身没有本轮失败证据，不据此改全局几何。 |
| UI-002 / S2·P1 / 追踪接入信息层级 | 普通账号页默认展开两套Client ID/Redirect URI注册表单；197明确显示安全存储未验证、连接不可用，却仍可保存开发者配置；Kitsu“不支持”、MangaUpdates/Bangumi“计划中”与可用服务同级常驻，空进度/映射说明继续堆叠。 | TrackerSettings:603–620,712–785,940–956；`27-tracker-accounts`、`28-tracker-lower`。这是TRK-001的用户界面表现，不重复计OAuth功能缺口。账号状态先可理解、支持范围诚实且不以待办列表占普通入口；接线必须先TRK-002，不能只把表单藏掉冒称可用。 |
| UI-003 / S2·P1 / 备份任务顺序 | 首屏先schema版本、加密算法/口令，再自动备份、本地备份、数据域、导入说明；普通导出/选择备份在本轮两次上滑后才出现。加密本地按钮依赖前方另一卡口令，预览/恢复结果也分散。 | BackupManagement:359,421–438,640–698,1045–1088,1198–1233；`30-backup-management`→`31-backup-middle`→`32-backup-actions`。首屏已有“加密导出”，不能写完全没有导出。按创建/选择恢复/已有文件管理组织，输入/操作/结果连续；保留必要口令丢失/覆盖确认提示，算法/schema降为次要说明。 |
| UI-004 / S3·P1 / 公共禁用态可辨识度 | 分类空名称的创建按钮近似无文字灰块；Tracker待配置/不支持和备份未选择时的恢复按钮也极淡。 | `36-category-management`图与layout仍有“创建”；27/28/32交叉支持。KomaActionButton:23–24先改三级文字色，:105,119再整体0.45透明并设置enabled；精确各层贡献待修复时同屏对照。修公共按钮只覆盖禁用态，不改尺寸/圆角/启用配色；验证这些调用处与危险按钮，不能靠亮色文字猜通过。 |
| REL-001 / S2·P2 / 可见入口占位 | “开源声明”实际仅弹“开源依赖声明会在这里整理”，没有依赖/许可内容；不是已经完成的说明页。 | `40-open-source-notice`与SettingsPage:2102–2104、zh_CN的settings_open_source_dialog_message。发布前补真实依赖与对应声明；不据此作法律合规结论，不抢路由/阅读状态主线。 |

严重程度与优先级分开：UI-004不是主功能崩溃，但属于跨页面、用户明确强调的可辨识度，排P1；UI-001中的帮助/空移除单点可单独P2，家族状态与接入整改按P1准备。以上尚未获得实施切片验收，不修改产品代码。

### 12.4 页面家族覆盖与非问题

| 页面家族 / 步骤 | 当前观察 | 尚未覆盖 |
| --- | --- | --- |
| 服务设置父页 `20-services-parent`；四配置页19/21/22/23 | 父页分组/导航清楚；四表单外边界均x39..1221，主操作未裁切，字段有可见标签。已确认UI-001，不判全页不可用。 | 已配置/成功/失败/编辑后的真实服务状态；普通非安全键盘避让。 |
| 设置根25、追踪设置26、备份设置29、书架设置35 | 采用共享设置行，无本轮外边距回归；35立即检查的长摘要被单行省略，具体报告仍可进入，不另算主流程P0。 | 长名称/大字号/其他主题及所有设置效果。 |
| Tracker账号27/28 | 默认与下半区完整观察，UI-002/004。 | 真实已连接行的状态+刷新+解绑是否挤压，不用空态推测；真实账号授权。 |
| 备份管理30/31/32 | 主要创建/选择入口位置与信息排序已核实，UI-003/004。 | 有本地备份记录时三按钮/长文件名布局，真实预览/恢复；不为取图新增或覆盖用户备份。 |
| 源管理33与索引sheet34 | 主页是分组图标行，索引/详情/设置分sheet；不是整页旧诊断工具。已保存索引显示省略，完整输入可读。 | 长索引的相互区分、真实加载/升级/卸载后全链；未改索引。 |
| 分类管理36 | 分组与折叠结构存在，空自定义分类/创建入口可见；创建禁用文字UI-004。 | 有多分类时重排/行菜单、长列表创建入口；未创建分类。 |
| 更新结果37 | 真实17:36记录10/0/9/1/0可读，来源与漫画名称存在；是任务报告，不是新章追更，仍为UPD-001。 | 两轮具体新增章、通知返回；不因手写Column就判布局错误。 |
| 存储38、关于39/开源40 | 存储为共享设置行，未操作清理；关于入口可见，开源声明实为占位REL-001。 | 自动清理实际数据边界、发布依赖完整性；不为验证删除缓存。 |
| 独立Import页 | 源码已有分组图标/能力门控，主入口是Index导入菜单；未发现pushImport生产调用。 | 独立页可达性未证，不优先改一张用户到不了的页；菜单导入完整路径仍V-LIB。 |

参考已实际读到：NextE `feature/settings/src/main/ets/pages/WebDavSyncSettingsPage.ets:188–256`分状态/操作组与配置组，`shared/src/main/ets/components/SettingsTextField.ets:25–50`同样label+原生TextInput；HarmonyOSComponentUXExamples的SingleLineTextBox/FullWidthTextBox也有多种原生输入组合。参考的是信息/操作关系，**不是“原生控件都不好”或强制照搬NextE同步功能**。NextE此页面本轮未在197运行，不能写双方视觉已同屏验收。

独立结构复核：`.hermes-artifacts/20260905-audit-continuation/legacy-ui/`；独立截图/layout复核：同根`legacy-ui-review/`，已补核36的禁用文字；清单归并复核：同根`current-status-review/`，未发现问题ID重复或证据升级。这些是证据附件，不另建执行队列。

## 13. 视觉结论纠正与受限修复（2026-09-06）

“UI专项已完成”结论撤回：前次检查偏重可达性、裁切与操作语义，未有效审查整个控件族的视觉一致性。第12节原图和具体事实保留，但“无裁切/已共享组件/独立报告复核”均不构成页面风格通过；旧报告不得用于关闭本节。

- **UI-005 / S2·P1 / 表单和操作控件视觉规则割裂**：43最新197 Kavita原图仍是重标签、小圆角灰输入与正文黑色满宽按钮；与项目主题色胶囊操作和NextE同类表单参照不同。共享组件本身是影响面，不能用它作为通过依据。与UI-001配置状态、UI-002/003任务排序分开。
- 本切片修改KomaFormTextField、KomaActionButton共有视觉规则，四私库ServerPage的填写/操作分组，以及默认primary的日夜专用前景资源，连同UI-004禁用态验证；启用态显式调用方配色覆盖和原行为保留，其他功能及根shell冻结。四页既有外边距WIP没有回退，不计为本次新改动。
- 实施前标准：`.hermes-artifacts/20260906-visual-style-recheck/acceptance.md`。全调用枚举、设备覆盖与独立视觉评审在同目录分工记录；只为本切片提供证据，不另建路线图。
- **当前：第三包已安装197，UI-005公共样式/四私库分组及UI-004三类禁用场景按下述范围通过；不是全软件UI完成。** 首包淡字、第二包重复文字均拒收并保留证据。用户随后要求提交，已形成2bb00cd（9文件，不含既有外边距和其他WIP）。UI-001接续状态见第14节。

### 13.1 已实施与证据边界

- 输入保留40vp高度、密码类型、值和回调；标签改12fp Regular/4vp间距，输入使用系统button_normal表面和LIST_ROW_RADIUS。按钮保持原高度/宽度/compact内边距，以实际高度一半形成胶囊；默认primary使用BRAND_PRIMARY，不再复用正文颜色作填充。
- 禁用状态继续由原生Button的enabled阻止点击。首包仅换颜色和移除0.45透明仍被系统淡化，已否决。最终仅在禁用/忙碌时用ContentModifier绘制原标签/图标，启用态仍用原ButtonContent；两者互斥，未增加点击或手势。未启用任何原本不可用的功能。
- 四私库表单卡只放输入/原有鉴权选择与帮助；卡外为提交→结果→危险文字色移除。未修改远程存储/联网方法，未修空配置仍有移除入口、草稿与旧结果失配等UI-001剩余语义；UI-002/003和REL-001仍开放。
- `scripts/test_form_action_visual_contract.cjs`运行生产颜色/几何方法并校验字段/回调合同；默认primary日/夜不透明资源对比分别6.057:1/7.220:1。只是资源验证，不冒称197深色模式验收。新资源仅作用于默认primary，未改封面和危险动作共用TEXT_ON_BRAND。
- 六项本地检查已运行：新视觉合同、设置分组、源sheet状态、详情路由标题、三语言资源一致性、diff空白检查。第三包签名debug构建命令exit 0，日志`.hermes-artifacts/20260906-visual-style-recheck/build-disabled-exclusive.log`；HAP修改时间2026-09-06 01:55:50、12987653字节，在`57-disabled-exclusive-install`安装/启动成功。构建包含既有WIP，不宣称重新验收全部WIP。
- 证据根沿用第12节。首包46书架冷启动、47Kavita空表单、48普通URL草稿回显、49返回重进恢复空表单、50空URL提交后错误结果紧跟主操作，只证明该包对应行为；空URL在RemoteServerStore.saveKavita的preferences写入前抛出，没有保存测试服务器或触发真实连接。
- 全调用清单：9个设置分区，21个生产消费者文件，71个按钮/27个字段；另11个无当前生产入口调用明确排除。数量只定义影响面，不是视觉通过率。独立代码评审未发现本轮hunk已证实回归，不代替设备评审。

### 13.2 实际拒收、复测与未关闭项

| 包/场景 | 结果与实际证据 |
| --- | --- |
| 首包01:25，四私库/分类/追踪/备份 | 四私库共有风格与分组按冻结标准通过；分类、追踪、恢复按钮文字仍过淡，UI-004失败，不能以颜色方法测试通过替代原图。独立记录在`20260906-ui005-ui004-after/`及`visual-review/`。 |
| 第二包01:50，分类状态切换 | 初始禁用可读，但输入后再清空出现两个“创建”。`55-category-final-cleared`原图与layout记录失败；`disabled-transition-incident.md`记录原因，不覆盖失败图。 |
| 第三包01:55:50，分类58–62 | 空态→点击禁用无新增→输入草稿启用→清空再禁用→返回重进；单一居中标签，背景恢复，分类未增加。原图及原生enabled门控独立复核通过。 |
| 第三包，追踪63–64/备份65–68 | 禁用标签和恢复图标可辨、原生按钮仍禁用；自动备份间隔/保留数量菜单正常打开，未改选项或创建/恢复备份。独立原图复核通过。 |
| 第三包，下载69–71/四私库72–75 | 下载章节菜单→详情，32vp紧凑操作和图标可见；Komga、OPDS、WebDAV、Kavita空表单的字段/主操作/危险操作维持统一规则。主代理逐张查看，独立评审直接查看71–75原图并通过本范围。 |

- 全设置入口的有限清单在`inventory/notes.md`；九个分区的旧包现场、首包受影响页和第三包回归分别记录，不能拼成“第三包所有设置项都测试过”。源索引URL、书架筛选及菜单有首包回归；DM5没有动态设置字段，因此不冒称动态字段已真机覆盖。
- **仍开放：UI-001** 空配置仍显示移除、配置说明和编辑结果语义；**UI-002** 追踪页开发者表单/授权任务组织；**UI-003** 备份普通任务与高级配置的顺序；**REL-001** 开源声明占位。它们不会因为按钮换样式而关闭。真实私库、账号、备份恢复、所有动态状态和197深色模式未在本切片验收。
- 当前原始证据与独立代码/视觉评审统一位于`.hermes-artifacts/20260906-visual-style-recheck/`；验收规则在实施前固定，测试只证明规则，整页风格仍必须直接对图判断。没有“截图存在即通过”，也没有要求用户替我们验收。
- 设备最终停在第三包Kavita空表单，键盘关闭；未改整机网络、保存/移除私库配置、修改Tracker账号或覆盖书架/备份。依据项目切片边界，未收到提交要求前保留独立可审查diff，不把上述剩余页面继续混进本次修改。

## 14. UI-001私库配置状态与帮助（2026-09-06，限域验收并提交f833e18）

- 当前代码基线2bb00cd + 既有WIP；先前共享风格修复已独立提交。实施范围与冻结项：`.hermes-artifacts/20260906-ui001-server-state/scope.md`。
- 当前处理四页共有空态移除、必填错误、编辑后旧结果，以及Kavita/WebDAV填写帮助。QA基线、只读参考、实现与独立评审分别记录，未经过当前新构建设备路径的项不标完成。
- 同路径代码核实：WebDAV/OPDS重开后Basic字段为空，再保存会删除旧凭据并以匿名测试；Komga同操作在写入前抛必填错误，不会擦凭据。本切片纳入同服务器留空保留已保存凭据，明确提示、严格限制相同地址，不解码回填密码。真实服务样本缺失时只按host生产方法检查，不标197账号闭环。
- UI-002追踪页任务组织、UI-003备份排序仍在后续，REL-001及NAV/Reader等原问题没有消失。
- 后续提交授权：用户已确认“每批验收后独立提交并继续，不推送”，因此本切片真实验收后独立提交，再开UI-002，不再在每批出口重复等待提交指令。未验收或受真实服务条件限制的范围必须保留对应边界，不能借此提升完成状态。
- 本地检查：`test_server_form_state.cjs`直接运行生产store/page方法与回调，平台存储和HTTP使用隔离适配，覆盖四协议加载/编辑/必填/保存/网络/移除状态以及Basic沿用；`test_remote_server_secure_storage.mjs`、`test_form_action_visual_contract.cjs`、i18n重复键检查及OPDS/WebDAV解析fixture通过。上述均不是197真实账号验收。
- 当前安装包：2026-09-06 02:41:11生成，13051112字节，代码标识为`2bb00cd + WIP-ui001`；构建日志`.hermes-artifacts/20260906-ui001-server-state/build-final.log`。包包含既有WIP，但提交只纳入本切片9文件；构建后仅JSON格式及一行缩进整理，无语义变化。
- 当前设备证据：`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-ui001-server-state/qa-after/`。03–22四页空态无移除、缺项具体提示、草稿编辑清旧结果、返回重进丢弃未保存草稿；Komga三种鉴权切换、Kavita/WebDAV帮助均已观察。23–26分类禁用/输入启用/返回无新增；27菜单→28普通详情正常；29恢复Kavita空表单、键盘关闭。独立review与QA结果均为`PASS_SCOPED`，见`.hermes-artifacts/20260906-ui001-server-state/{qa-after,review}/result.json`；已提交f833e18，不推送。
- 关闭范围仅为上述表单状态/帮助与host逻辑；真实服务成功、有效配置回填、连接中交互、AssetStore设备恢复仍未验收。不能将此提升为私库整条接入流程完成。

## 15. UI-002追踪页任务组织（2026-09-06，233a403提交；遗漏重开后由1253d8e纠正）

- 接续基线f833e18 + 既有WIP，UI-001已先验收并独立提交。此次只处理第12.3登记的账号/开发者配置层级、无实现的服务常驻及空队列/映射冗余；不实现OAuth或自动同步，不修改账号、备份、网络、公共布局和控件几何。
- **旧结论纠正**：源码`AssetStoreTrackerCredentialSecretStore.isAvailable()`实际返回true；`TrackerSettingsPage.authPreparationMessageKey`初值为secure_storage_unverified，加载成功不清除。旧197截图中的“安全存储未验证/连接暂不可用”只是页面文案，不能证明197实际安全存储不可用。本批不得据此禁用AniList/MyAnimeList，也不能反向把接口布尔值当作真实授权验证。
- 当前先采最小197基线并核对真实状态/消费者；已保存账号的刷新/解绑、待授权回调、非空pending/mapping必须保留可达。不删除已有注册信息或凭据；计划中/不支持项的展示收敛不能变成存储迁移。
- 用户追加确认两处问题：账号行按钮贴卡片右边，且大量注册字段平铺同页结构不合理。原inline折叠设想取消，按“账号服务列表→单服务配置/授权/管理子页”实施；复用app-level导航和业务方法。贴边已追到ProviderRow显式suffixPaddingRight:0叠加无卡片inset，修Tracker内部尾距，不缩按钮或增大页面外边距。基线01/02原图、layout已留存，范围见本批scope.md。
- 实施采用同一TrackerSettingsPage的providerId模式，Index添加单服务destination，不复制业务模型。首页onShown刷新revision触发重载，准备授权ready后重载accounts以立即显示已有auth_pending回调；注册信息和账号原数据不迁移。ProvidersCard只在子页显示单服务配置/管理，原待同步/映射非空时仍在首页可达。
- 构建2026-09-06 03:11:56、13073584字节，代码标识`f833e18 + WIP-ui002`，`.hermes-artifacts/20260906-ui002-tracker/build.log`退出0。`test_tracker_settings_state.cjs`直接执行生产页面、Index路由/刷新方法及模型函数，验证路由/返回重载、ready状态、数据可见条件；独立重跑通过。tracker_account_store、form_action_visual_contract、i18n及diffcheck通过；不能当真实OAuth验收。
- 197改后路径：`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-ui002-tracker/qa-after/`，02服务首页→03 AniList→04首页→05 MyAnimeList→06首页，07普通详情、08恢复首页。两服务各有独立destination标题/单表单，不平铺；无空pending/mapping、未实现服务及硬编码警告。白卡右界1221px，子页待配置按钮右界1182px，真实尾距39px=12vp（原0）；保存按钮右界1169px，52px=16vp保持。QA已限域通过，待独立视觉结果后提交。
- 设备未覆盖：已连接双按钮状态、auth_pending回调、真实OAuth及非空pending/mapping交互。此类生产方法/显示条件有host依据，但不能写为197账号闭环完成。
- 233a403已按上述两层导航/尾距证据提交7文件，不推送；随后用户指出卡内右下孤立“保存”仍不符合项目风格。此前只查按钮留白、没有按整张表单的任务层级判断，属于主控和独立审查遗漏；不能用限域PASS否定用户指出的问题。UI-002主提交层级重新打开，暂停UI-003。
- 当前纠正范围：参照已验收四私库页，将保存移至输入卡后的主题色全宽主操作区，复用既有40vp规格和16vp内线，不合并保存与授权，不改字段/账号操作/导航/全局边距。当前before复用同包03/05原图。记录见`.hermes-artifacts/20260906-ui002-tracker/save-action-followup/scope.md`；改后必须再次看两子页的完整输入→主操作关系。
- 保存主操作增量：仅TrackerSettingsPage和对应测试。03:25:10新构建13082737字节，`save-action-followup/build.log`退出0。197改后03 AniList、04 MyAnimeList均为输入卡→卡外主题色全宽保存，主控已实际看整图并和Kavita参照比较；按钮[91,1266][1169,1396]为1078×130px（40vp），两侧与字段x91..1169对齐，顶部待配置仍12vp尾距。真实点击保存会写OAuth注册元数据，故本轮不点击或声称真实保存验收；原生产保存方法与builder接线已由host检查。待独立视觉简报与现场恢复记录后提交。
- 该增量QA/独立review均已按整页关系限域通过，05返回服务首页、06重新进入AniList展示正常；最终停AniList，键盘关闭。已提交1253d8e（仅2文件，不推送）。前次漏审/REOPENED记录保留，不倒改为一次验收全部正确。下一项UI-003。

## 16. UI-003备份任务组织（2026-09-06，限域验收并提交26d72aa）

- 当前切片基线1253d8e + 原有WIP。用户再次指出备份与恢复是界面重灾区，承接现有队列实施，不另起全局审查。
- 当前197基线三张原图已由主控和QA实际查看：schema/算法/口令占首屏，普通导出和选择恢复在两次上滑后，本地加密依赖前方另一卡的口令。原始证据`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-ui003-backup/qa-before/`；没有执行备份或修改配置。
- 已冻结首页→创建/恢复/本地文件三个任务与次要备份设置，复用pane和现有app-level导航；创建单主提交分派原四方法，恢复选择/解密/预览/确认连续持有状态。本地管理不新增不存在的历史导出；全局内容偏好和原自动明文规则不变。
- 具体范围、原方法映射、整页参照与设备验收边界见`.hermes-artifacts/20260906-ui003-backup/scope.md`。当前仅基线与方案已核实，尚未有改后构建/197验收。不得将本地空态或host替身检查当成真实备份恢复完成。
- 生产候选已完成；初轮审查拒绝卡外恢复口令和无状态折叠行，已改为独立输入卡→当前主动作→换文件副操作，以及展开/收起提示。03:51:05签名构建13235876字节，build.log退出0，候选复制为本批`ui003-signed.hap`避免共享构建覆盖；backup_task_state、tracker_account_store、tracker_settings_state、form_action_visual_contract、三语键一致性通过。尚未197改后验收。
- 197基线场景闭合后，应ReaderLab D1任务请求于当次释放旧租约；其独立任务预计10–15分钟后交回。主控不抢占，不把D1包/截图算作UI003验收。ReaderLab及debug Want路由仍属另任务WIP，不纳入本批提交。
- 独立源码/host复核已完成，`review/result.json`为HOST_PASS_SCOPED_VISUAL_PENDING；恢复口令卡/主次顺序和折叠状态已复核。QA只读确认空口令在写入前返回、明文确认取消和picker取消不写数据；尚未在新包执行这些设备动作。本批暂无提交。
- 首包197 01/02任务首页与创建整页、04/05本地明文选择及取消确认、06/07完整数据设置、08返回创建临时选项保留已有当前原图。**07展开的算法段落游离卡外，主控及独立review拒收**；仅将其归入现有格式信息卡后重建、补测，不改自动规则或其他任务。拒收依据见本批`technical-grouping-incident.md`，旧图保留，不整批PASS。
- 首包09恢复空态的“当前实现/不会假装”开发叙述也已去除；两段三语说明改为预览不写数据、确认后替换书架和阅读进度并写入备份配置，不支持逐项合并。BackupService与所有确认原方法不变。
- 最终包04:12:18、13235888字节，`build-final.log`退出0，固定副本`ui003-final-signed.hap`已安装197。主控实际查看qa-final/01首页、02创建、03恢复、04技术展开：主操作关系无增量回归，覆盖说明清楚，算法已纳入原格式卡，bounds从首包[39,2030][1221,2160]变为卡内[91,1978][1169,2108]。最终独立结论与返回现场待报告落盘，尚未提交。
- 首包仅有限无写入路径：空口令阻断、明文确认取消、从创建进完整数据设置并返回保留临时选项、picker取消后恢复空态、本地0记录；最终包仅针对两项delta与关键导航补测。未执行真实创建、解密文件、恢复、非空文件改名/删除或持久设置变更，不宣称这些功能已获197验收。
- 最终qa-final和独立review均PASS_SCOPED，主控已实际查看四张最终整页图；05收起、06回首页有layout证据，本地0、自动关闭、键盘关闭。已提交26d72aa（7文件，不推送）；仅备份页、必要路由/资源和生产方法测试，旧外边距、ReaderLab、更新等WIP未纳入。首次零上下文Index暂存位置错误在提交前已撤销并改为带上下文暂存，工作树/HAP未改；独立复核最终cached结构位置正确。
- 当前接续NAV-001，随后RDR-001。不重复审查已关闭UI切片，真实备份/非空状态验证边界仍保留。

## 17. NAV-001书架普通点击进入详情（2026-09-06，限域验收并提交a2dbd6b）

- 基线26d72aa + 既有WIP。197 qa-before01–03当前原图已由主控/QA实际查看：ONE PIECE普通网格封面和顶部继续阅读均直达Reader4/23，普通封面未进详情；最后回书架17%。证据根`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-nav001-shelf-detail/qa-before/`。
- 最小分工为普通grid/list新详情event，Continue保留原reader helper；Index复用现目的页。源用真实remote pair，本地/私库用完整库存comic.id。
- 新必经源详情会遇到已确认的外层/章节加载失败清空章节分支，故同批保留同源已收藏库存fallback及原失败提示，不新造缓存或写库存。详见本批scope.md/research/notes.md；ReaderUI、手势和ReaderLab冻结。当前尚无实现后设备结论，不算离线阅读验收。
- 三文件候选已冻结。初次共享ReaderLab构建发现早return后的libraryComic可选访问收窄never，已改无库分支false/空ID；独立源码及artifact内生产方法控制流检查通过，仅证明入口分流、身份参数、失败/epoch/cache门控。没有新增Reader UI合同脚本。
- 04:36:33签名候选13270399字节，`build-host.log`退出0，固定`nav001-signed.hap`；默认沙箱首次仅因相邻reader-kit生成BuildProfile权限EPERM未完成，host重建成功。该包包含其他任务已冻结的ReaderLab/HAR WIP，但提交仍只选三页NAV必要hunk。已交197安装并按普通源/本地/列表、Continue、选择取消和返回链验收，尚待当前图与结论。
- 改后01–05已由主控实际看原图：普通ONE PIECE封面→同源完整221章详情；详情Continue→原4/23；Reader返回详情；明确Continue仍直达原4/23；既有Local Folder Smoke库存条目→对应2章详情。这里只证明库存本地入口，不证明文件夹权限或真实本地阅读。当前在线源成功，无自然失败，不把host fallback检查当断网验收。暂存仅三文件49增5删，完整cached由主控/独立review核对；列表/选择/最终现场尚待QA，不提交未完成场景。
- **新增实证 LIB-005 / S2·P1 / 设置生效链**：设置“书架视图”为列表后，当前书架仍网格；06原图虽目录名list-shelf却被主控/QA/独立review拒作列表证据。06a layout显示设置值“列表”，06b冷启同包后各库存行x247且ONE PIECE位于y2182，07点击该列表行进入正确详情、07a返回列表。主控已看06/07原图和06a/06b/07a节点；源码SettingsPage.saveLibraryViewMode只保存，LibraryPage仅aboutToAppear恢复设置，与现场一致。本缺陷未修，不因NAV入口通过关闭；排在两个P0之后，与设置消费者刷新同根核实，不扩大本批三文件改动。
- **新增实证 LIB-006 / S2·P1 / 批量栏溢出**：08真实列表选择态原图右侧“阅读状态”被截、移出和选中数量不可见；主控与独立review实际看图。LibraryPage.BatchActionBar为单Row，包含计数和五按钮，没有换行/横向滚动；不是有意可滑工具条。本图只能证明长按进选择不误开详情，不能作为批量栏视觉PASS。该布局未在NAV修改，保留FAIL并加入两个P0之后的修复队列，不以独立提交掩盖漏项。
- 08a取消选择、08c设置恢复网格、09冷启回原三列书架；主控实际看09完整图，00話4/23·17%未变。QA有限路由PASS_SCOPED，未禁用源/网络、翻页、导入或下载。当前仍待独立最终报告后提交。
- 最终主控/独立review均实际查看before01–03、after01–09及列表/返栈layout，路由范围PASS_SCOPED，LIB-005/006分别保留FAIL_OPEN。已提交a2dbd6b，仅三页49增5删，不推送；既有外边距/sourceName/文件夹/前台更新/ReaderLab全部留在原WIP。后续RDR-001先核实逐章数据域和197基线；源fallback真机失败链、四私库服务及本地阅读仍未验收。NAV现场结束后按既有协作安排释放197给ReaderLab短时验证，不以其实验截图替代生产回归。

## 18. RDR-001逐章状态（2026-09-06，限域验收并提交e197d63）

- NAV提交a2dbd6b后依唯一队列接续；范围 `.hermes-artifacts/20260906-rdr001-chapter-state/scope.md`，研究及独立设计意见同根research/review。主控已读实际数据owner、页面/Reader生产者、书架投影、私库bootstrap与备份数据消费者；不重写ReaderUI，不新增UI合同门禁工程。
- 197借机约7分钟结束，实验任务释放95766f67且恢复三列grid/00話4/23。QA另取0f88f3ca新租约，重新安装固定NAV生产包，避免混用实验构建；当前单页真实阅读基线根 `.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-rdr001-chapter-state/qa-before/`。
- 主控实际view01原00話4/23、02b真实尾页23/23、03相邻01卷3/210、04已有详情未读/话数升序仍列00話（221/221）：跨章后A已读消失已真机复现。02首次仅22/23，未当末页通过。随后只补A位置和原始数据副本，不用存量不可读文件夹fixture替代真实源样本。
- 实施冻结为同一owner/文档分别保存recent、逐章位置与sticky已读；旧最近一章及明确手动覆盖仅迁移一次，不猜丢失历史。手动未读已向用户异步询问，未回复时采用推荐只重置所选章首，旧迁移不重置；手动已读不伪造最近指针，清历史不暗删章域。
- 末单元可见且图片已loaded/非failed才完成；单页拆分、双页末幅、连续end变化复用现事实，不新增完成状态机或UI。详情返回、书架筛选/MockLibraryData完成文字、bootstrap单owner/flush、备份flush与恢复重载是同根必要接线。真实备份恢复、外部账号仍不操作/不验收；LIB-005/006保持开放，不混进数据切片。当前未构建、未改后197验收、未提交。
- 05原图已由主控实际view：重开A变为1/23，而02b曾真实到23/23；逐章位置丢失也已复现。正常测试已改变ONE PIECE最近进度，不再声称原4/23保持。QA仅复用已验收app文件直读协议留两份进度/手动覆盖文件（存在时）供迁移前恢复，不提权、不写回、不读账号目录。
- 基线最终回原网格，ONE PIECE为00話1/23·4%；临时详情筛选已重置。05b仅成功直取reader-sessions.v1.json（3680字节），chapter-read-state.v1.json返回明确no such file，虽然HDC退出0也不记成功；当前设备没有该旧手动覆盖文件，因此真实迁移只能覆盖其现有最近记录，手动覆盖迁移另外用隔离数据证明。
- 候选已冻结，独立源码/host审查为PASS_SCOPED_SOURCE_HOST。实际生产数据检查保留197原副本11 recent/1 sourceHistory，覆盖逐章位置/sticky事实、旧覆盖迁移、清历史不删章、旧/空备份替换与pending不复活；真实设备旧覆盖与备份恢复仍未验收。首版“整本手动未读仍属阅读中”已被独立审查拒收并改用非起点位置聚合，保留失败记录。
- 必要提交依赖从10文件扩到12：复用已有AppForegroundState薄模块与EntryAbility bridge前后台行，使Reader后台完成门控在干净提交中成立；ReaderLab Want/debug回调、Index前台更新与旧文件夹/间距WIP全部排除。05:36:40签名候选13318076字节，build-host.log退出0，固定rdr001-signed.hap已交197；当前构建成功不是设备验收，尚未提交。
- 首批改后真实证据位于本批稳定设备分区qa-after：00a升级原文件schema3，主控/独立review分别deepEqual原11recent/1history并核11章迁入；01 A23/23真实末图→02 B中途后回原详情未读220/221，A已排除，数据A已读、B未读。03 A中途恢复4/23，04冷启书架Continue指B第3页、05 B真实3/210恢复，主控已看01–05原图；手动未读与多模式尚在执行。这些局部结果不是完整RDR关闭。
- 12文件351增163删已按带上下文候选暂存，主控和独立review核完整cached，diffcheck通过；五model/Reader/前台模块与工作树一致，五混合文件仅必要hunk。仍等全部限域197路径完成再提交，暂存不代表已验收。
- **首候选收尾拒收，未提交**：07c真实22+23双幅及08前页+末页同屏完成事实成立；09正常HOME/返回B3/210保持未读，非后台末图竞争验证；10回grid A23/23标签100%非整本已读完。主控看图后进一步查raw发现退出后recent.completed被门控false覆盖，而A新isRead仍true；旧同步消费者仍使用completed，不能忽略。QA另指出06显式未读后A行仍灰，主控复看确认，数据通过不等于就地UI通过。同根最小增量及补测待执行，原图和拒收理由见本批final-candidate-rejection.md。
- 收尾增量仅ReaderSessionStore事实投影与ChapterListSection读态key；范围扩13文件，所有UI几何/菜单项与Reader gate不变。两个store保存、手动标记、snapshot/备份加载统一compat completed；原false旧位置仍保留。主控和独立review均核实际生产方法回归通过，新签名包06:14:25/13407605，build-final.log退出0，固定rdr001-final-signed.hap交197补原行灰→深→灰和退出/切章completed。暂存现为13文件374增164删；尚未改后补验、未提交。
- 最终包增量补验：主控已实际查看qa-final/01–07原图。01→02→03同一详情原行灰→深→灰即时更新；02→03仅选章读态/compat与章状态更新时间变化，原位置/位置时间、recent全数组及其他章完整不变。04a显式false后04真实单页23/23，04b退出详情/04c退出grid仍isRead、position.completed、recent(A).completed全true。05切B后冷启Continue为B3/210，raw A完成保持、B未读；06c/07a各自fresh false后06真实22+23双幅、07连续前页底与末彩页同屏，06d/07c退出仍三处true、锚点第22页。独立review已复核手动/单页，正在收尾双页/连续；本地三项检查与cached check重跑通过。尚待原设置/最终grid恢复、QA和独立最终报告，不提前提交。
- 最终主控与独立review均实际查看新包8张原图，raw逐段核对；qa-final为PASS_SCOPED_DEVICE_DELTA、review为PASS_SCOPED。08最终grid Continue A第23页，卡片100%而非整本已读完；A23/23 true、B3/210 false，single/LTR/odd_left及详情全部/话数降序已恢复。08c重置点击未命中不算恢复，08g才为成功证据。首候选06/10拒收保留；后台末图异步、split/一页章、真实备份及账户同步不外推为197通过。
- 已独立提交e197d63，13文件374增164删，cached全量复核/check通过，不推送。正常阅读测试确实改变ONE PIECE进度，不回滚到最早4/23。既有边距/前台更新/ReaderLab等WIP未纳入。197租约74308b66已释放给D3短时Lab-only交叉，生产读态由08最终raw作为对照；接续LIB-005前重新用固定生产包采基线，不混用实验验收。

## 19. LIB-005书架偏好即时生效（2026-09-06，首候选拒收，补排序刷新）

- e197d63提交后接续同队列，不混入LIB-006。范围 `.hermes-artifacts/20260906-lib005-view-refresh/scope.md`。197当前由D3短时Lab-only交叉持有，QA只准备既有协议，未抢占或以实验包当生产基线。
- 主控与研究worker核实：SettingsPage视图/密度/角标/排序只保存同一LibraryFilterStore，LibraryPage为独立局部值且只aboutToAppear恢复，Index根Tab保留。NextE使用共享ListModeState即时驱动GalleryListBody；本批拟复用Koma成功保存event→Index独立revision→Library既有restore，不重建Tab或引入第二份偏好owner。
- 尚未实施。归还197后先安装固定RDR最终包，确认当前view设置与实际书架差异并保存原偏好；改后验证四项同根消费者和持久化。列表角标的普通对象/稳定key另外列为现场核对点，不以可能性直接增加修复。所有原控件尺寸/颜色/边距/路由/Reader冻结，账号、网络、备份和批量移出不操作。
- 当前固定RDR包01–04基线已由主控和独立review实际view：四值网格/标准/最近加入/徽标开启，选列表返回仍grid，03a设置值列表，04冷启才为列表。读态首尾未变，基线成立后允许三页通知接线；QA继续恢复原值，尚无改后验收。
- **新增实证 LIB-007 / S2·P1 / 列表行尾部重叠**：当前qa-before/04-cold-list-shelf原图中Local Folder Smoke行右上菜单按钮压住50%文字，主控/QA/独立review均看见。LibraryList的Stack额外覆盖菜单，而ConciseListRow已在尾部显示progressText；其范围不包含其他普通源行。本图仅为视图模式基线，不是列表视觉PASS。保留FAIL_OPEN，LIB-005提交后与LIB-006按独立书架界面切片处理，不混当前通知接线。
- 基线06已恢复原grid及四值，00→06阅读状态逐字节不变。实现仅三个页面15行新增，无布局/Store/列表key改动；主控与独立review核带上下文scoped.patch及实际save/事件/原restore方法检查通过。07:02:12签名构建13413004字节，build.log退出0，固定lib005-signed.hap（副本07:03:07）交197改后验证。当前尚未设备验收/提交；徽标只使用现有标签样本，没有样本不临时添加分类冒充通过。
- 首候选qa-after拒收：02/03网格列表即时双向、04密度以及06冷启设置持久有效，但05只显示“排序 标题”，行次序仍为最近加入；06a冷启后才真正按标题排列。主控与独立review均实际查看05/06a，保留FAIL，不提交。07恢复原四值，08普通详情/09明确Continue/10原grid；最终仅A更新时间变化，A23/B3位置及完成事实不变。现有10本categoryIds全空，标签真实回显未验证，不新增分类制造样本。
- 同根补丁范围只解除LibraryList普通数组形参快照：Builder内部直接读取现有this.gridComics()，不改排序算法、行key、尺寸/颜色/菜单或根shell。官方arkts-builder建议私有Builder直接this读取组件状态，Koma结果页已有同类实现。需要新固定包验证同进程标题/最近加入实际双向顺序；当前仍未提交。
- 三行增量源码和原方法检查通过。07:19:58签名补包13438866字节，build-final.log退出0，副本07:20:29固定lib005-final-signed.hap。HAR消费窗口已协调并释放；包内实验HAR缩放由另任务负责，不作为本生产切片验收。暂存仅三页18增3删，主控完整cached复核，旧边距/前台更新/Lab不纳入；197补同进程排序双向及最终原值恢复，尚待结果。
- 最终qa-final/02–06主控、QA和独立review均实际查看：同list added→title→added即时真实重排（03/04），中间无冷启或view切换，05冷启一致，06原grid与四值恢复。最终00→06及前包after10→final06进度逐字节相同。已提交3d03747，仅三页18增3删，不推送；首候选失败保留，分类标签无样本仍未验证，LIB006/007未修。下一独立切片为LIB006，禁止以本提交扩大成书架整页视觉通过。

## 20. LIB-006批量栏可辨识与可达（2026-09-06，限域验收并提交3e3a4f0）

- 接续3d03747，scope与记录位于`.hermes-artifacts/20260906-lib006-batch-actions/`，不扩大到LIB007。当前固定LIB005最终包197 qa-before/01网格、03列表选择态，主控/QA实际view均见数量完全隐藏、阅读状态右裁、移出不可见。02全选无可见数量，不能按目录名称判通过；04最终取消恢复原grid/四值，库和阅读文件00→04各逐字节相同。
- 只改原BatchActionBar的组内空间分配：数量/全选/取消与分类/读态/移出分两组，按自然尺寸换行；所有原按钮规格、颜色、文字、回调/资格/确认、卡片padding和普通内容保持。参考HX ButtonSize、Koma章节筛选的分层与换行及官方Flex，不把NextE分类tab误作漫画多选。当前尚未改后验证/提交；后续只安全选/取消、菜单打开取消，禁止真实批量数据变更。
- 独立源码/暂存复核通过：仅LibraryPage必要import与BatchActionBar，71增47删（多数为原按钮缩进），五按钮、两菜单、动作/资格与HEAD忽略缩进一致，旧边距WIP未纳入。07:41:14签名包13445640字节，build.log退出0，副本07:41:36固定lib006-signed.hap；HAR窗口已协调并释放。交197按网格/列表、数量/全选/取消、菜单及移出安全取消验收，当前仍未提交。
- 首候选qa-after/02两组几何有效，但03全选数字10、仅Local有勾选，主控/QA/独立review实际view，拒收未提交。LibraryGridCell非canRemove分支写死selected:false并忽略选择态tap；全选已按canSelect纳入全部库存，选择与删除资格混同。新增同选择链最小修复范围见first-candidate-rejection.md：统一原卡selected/选择手势，只保留移出菜单按原canRemove门控，普通路由/所有几何及删除业务不动。保留失败图，不因工具栏可见宣称全选通过。
- 首候选04/05/10分类与读态点击后未弹菜单，主控/QA/独立review一致FAIL。08/09列表两组栏和全选高亮、06移出确认取消、11仅源选择移出禁用分别有限成立；13原grid/四值恢复，两份库和阅读文件00→13逐字节相同。只补两原按钮action→本页key→显式isShow，消失/退出清理，参考Downloads已有模式；不修改菜单项、业务、共享组件、按钮样式或placement。
- 两增量独立源码审查通过，主控核完整补丁；暂存仅LibraryPage共122增97删，旧inset仍排除。07:57:45签名补包13439085字节，build-final.log退出0，副本07:58:14固定lib006-final-signed.hap，HAR窗口已释放。197补源网格长按/全选回显/同项逐次toggle、两菜单真实打开取消重开、普通详情及原现场恢复；当前尚未补验完成或提交。
- 13439085补包qa-final01/02源长按与全选勾选成立；04/05网格、07列表菜单实际位于各按钮下方，取消后重开成立；08/09普通列表源/本地仍详情，11恢复原grid及四值且库/阅读00→11逐字节相同。主控实际查看全部九张原图。但03对最初长按同源首次tap仍10而非9，主控/QA拒收。旧suppress在Exclusive长按获胜、Tap不触发后残留；仅在下一Touch Down清旧flag一行，同次长按仍重设并防释放误开。独立源码和实际方法内存回归通过，不替代真机。
- 08:08:02触摸补包13439063字节，build-touch-final.log退出0，副本08:08:40固定lib006-touch-final-signed.hap；构建时共享reader-kit实测干净fa1954a，另一任务pager WIP未混入。暂存仅LibraryPage123增97删。交197 qa-touch-final补源/本地网格与列表长按释放、首次tap及原详情，尚未验收完成或提交。
- 最终qa-touch-final及独立review限域通过：源/本地全10→同项首tap9→再10与勾选同步，退出后首tap进各自详情；列表长按释放仍1，首次tap清最后选中并退出。主控实际看02/03/04/06/07/08/10/11/13，13原grid/四设置恢复，两原始库/阅读文件主控与独立review均核00→13逐字节相同。菜单沿用明确标注的上一候选04/05/07与重开、本地移出取消沿用首候选06/07，未执行批量赋分类/读态/移出。已提交3e3a4f0，仅LibraryPage123增97删，不推送，旧inset等WIP保留。LIB007在11仍明显开放，下一独立切片处理。

## 21. LIB-007列表进度与原菜单（2026-09-06，限域验收并提交1a24106）

- 当前基线为3e3a4f0对应LIB006 touch-final包，13439063字节/source08:08:02，未换旧包。197 ALN-AL80 portrait1260x2720，原图位于`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260906-lib007-row-menu/qa-before/`。01网格与03列表各单击本地菜单一次均无MenuItem、未误进详情；03按钮`[1078,1053][1195,1170]`与50%进度`[1108,1124][1195,1177]`相交，主控实际查看并拒收。05原grid/standard/added/角标true恢复，库和阅读文件00→05逐字节相同。
- 只修本列表尾区和同根已复现菜单事件：复用Downloads同级Row布局，原正文/进度占剩余宽度、原菜单占独立尾区并垂直居中；上下4vp padding/背景/圆角归外层，菜单去top8、保right8及原36vp规格。网格视觉不变；两布局原菜单采用明确key/action/isShow和匹配关闭回调，沿用既有BottomRight锚点。公共组件、菜单项/移出资格、封面/字号/密度不改。
- 固定包`lib007-signed.hap`为13445033字节/source08:40:02/copy08:40:14，clean reader-kit fa1954a窗口签名构建exit0。同包qa-after/01列表50%与按钮分离，源行标题/进度bounds前后相同；02/02a、08/08a原菜单打开/Back重开，03/09选择及取消，04/06取消后首次正文点击进本地/源详情。列表菜单下方右对齐；网格左列菜单下方朝右展开并完整在屏内，不能将Placement枚举冒充固定右边缘几何。
- 主控与独立review实际比较before03→after01及before01→after10整页，核对菜单和选择原图；10原grid/standard/added/角标true恢复，00→10库/阅读文件双方独立比对逐字节一致。记录与独立PASS_SCOPED/canCommit位于`.hermes-artifacts/20260906-lib007-row-menu/`。已提交1a24106，仅LibraryPage30增7删，旧3个inset等WIP未混入，不推送。不执行移出/分类/读态/Reader/网络/账号/备份；原网格勾选覆盖进度另登记LIB008，不声称整页或全选择视觉通过。下一P1为RDR-002。

## 22. RDR-002无效适配入口（2026-09-06，限域验收并提交748a519）

- 全链核对不是偏好没保存：ReaderChrome/SettingsPage均保存并回显；普通Image绘制固定contain，分页slot还明确为防长图初始裁切强制contain，Spread无fit参数且固定完整适配。NextE当前fitScale为min宽高比例、显示设置组没有三选项。不能一行解除contain后再次制造基础溢出不可拖；本批按用户“不支持移除”既有授权关闭假入口，不冒称补齐真实宽高适配能力。
- 197使用1a24106对应13445033固定包，`20260906-rdr002-fit-mode/qa-before/02-global-fit-menu`与`05-reader-fit-menu`均实际显示屏幕/宽度/高度，原值屏幕、单页/LTR；Root实际查看，Reader在A23/23，未改选项。原图位于稳定device197__ALN-AL80/portrait1260x2720分区。
- 候选仅ReaderChrome21删、SettingsPage25删：行/专用菜单/独占UI状态引用撤除；设置搜索从注册行派生同步不再包含该项。Chrome.copyPreferences的imageFitMode、Store默认fit_width/持久化/runtime/备份兼容全部保留，ReaderPage渲染/手势和sharedReader试验入口未改。连续Surface仍会用旧字段作部分几何输入，不将其说成彻底无消费者，也不顺手改历史值。独立记录位于`.hermes-artifacts/20260906-rdr002-fit-mode/`；此时只有基线/候选，不可声明设备通过或提交。
- 固定签名包rdr002-signed.hap为13467214字节/source09:02:59/copy09:03:31，build.log退出0，构建消费clean reader-kit 220816c窗口并已释放；不将其当ReaderLab验收。197 before10为实际打开NextE阅读设置的显示/屏幕参照，未改对方设置。改后01全局原行自然收拢、03图片适配搜索无结果、04图像缩放质量搜索有结果；07真实A23/23、08Reader显示卡片入口消失且无残余分隔、09原画质低/中/高菜单中项勾选，Back取消，10恢复原grid。主控与独立review实际看前后原图并核源链。
- QA after05/06因清搜索后键盘重开导致坐标误入服务父页，保留FAILED_NAVIGATION并排除Reader证据；06c关闭键盘、06d真实书架后07/08/09才有效，未操作任何服务配置。before菜单遮住部分底层行、Reader显示标题在滚动边界部分裁切，不能声称全页像素等价或整Sheet视觉通过。
- QA为PASS_SCOPED_DEVICE_AFTER_RECOVERY，独立review为PASS_SCOPED/canCommit=true；主控及独立原始数据核00→10库文件逐字节一致，Reader仅A的progress.updatedAt、chapters.position.updatedAt、chapters.updatedAt三处正常打开时间变化，其他字段全同，A23/B3位置完成状态与偏好未改。已提交748a519，仅两文件46删，旧SettingsPage127增177删等WIP全部排除，不推送。接续RDR-003，不将“隐藏不支持入口”写成新适配能力完成。

## 23. RDR-003无效裁边入口（2026-09-06，限域验收并提交b99b30d）

- 本批主控/研究/独立review均沿实际链核实：Koma只有偏好/UI回显与runtime/备份字段；当前原图URI解析、Image、半页裁框、双页及连续尺寸均无自动边界检测消费者。NextE ReaderPageCropService/Bounds与三surface有真实检测、任意裁框绘制、裁后尺寸/zoom以及连续接缝策略。不是漏传一个参数；其能力可以参考但未移植到Koma，自动裁边继续标MISSING。
- 197当前固定RDR002包未换包采前图；Root实际view02全局页间距→裁边→宽图及后续行、04真实A23、05Reader完整页间距→宽图→裁边末行。裁边原值false、宽图拆分、页间距标准；同轮NextE参考为RDR002 before09的分页/连续两真实裁边开关，不以显示组图冒充。库00→06逐字节相同，Reader仅A三处正常打开时间变化，最终原grid，未改设置或翻页。
- 按“不支持主动移除”授权冻结两文件28删：Chrome3删含trim行/前divider/toggle分支；Settings25删含注册/独占UI引用与分派，派生搜索同步消失。两处copy、Store/runtime/备份/default/资源、ReaderPage渲染手势和宽图条件/菜单全部保留，旧Settings127增177删WIP排除。scope/研究/独立设计/候选位于`.hermes-artifacts/20260906-rdr003-trim-margins/`。
- build.log退出0，clean reader-kit 220816c窗口消费后释放，固定rdr003-signed.hap为13451528字节/source09:32:30/copy09:32:56。已交197验证两入口/搜索与相邻菜单，本批尚未提交，不能宣称真裁边实现或全Reader验收。
- 同固定包197 after01全局页间距直接接宽图，02裁剪页边空白搜索无结果、03宽图模式有结果，04正常A23/23，05完整两行Reader卡仅居中分隔/无尾线，06宽图三项拆分勾选、07间距三项标准勾选，均Back取消，08原grid。主控和独立review实际看目标前后对照及菜单/搜索/末态；全局滚动偏移不同，不声称整页像素一致；Reader底部卡自然收缩，不扩到其他UI。
- QA PASS_SCOPED_DEVICE、独立PASS_SCOPED/canCommit=true。主控和独立原数据00→08库文件逐字节相同，Reader仅A的progress.updatedAt、chapters.position.updatedAt、chapters.updatedAt从1788658242965→1788658741283，其他字段全同；A23/B3和split_wide_pages等原偏好保持。已提交b99b30d，仅两文件28删，cached完整核对/check通过，旧Settings127增177删等WIP保留，不推送。自动裁边仍MISSING；下一P1为章节连续阅读RDR-004。

## 24. RDR-004章节连续阅读（2026-09-08，A限域验收并提交，B尚未实现）

- 基线b99b30d及固定RDR003签名包13451528字节。197当前qa-before/01真实A00話23/23；02按当前点击映射左侧next一次、03原LTR向左滑一次均仍A23/章节1/221；04目录A00話首项、B01卷次项，未进入B；05原grid。主控已实际查看五张原图，QA核库00→05逐字节相同，Reader仅A三处打开时间更新至1788659467794，A23/B3和偏好不变。证据位于稳定device197__ALN-AL80分区的20260906-rdr004-chapter-continuity/qa-before。这里只确认现有缺口，不能写成连读通过。
- 当前相邻章表还存在前置断点：库存源Chapter.index是响应ordinal，sortKey才保存源章号；现设备同时有升序、降序和分组回跳。临时源历史请求只带当前章，Index不重取章表。不能只在nextPage末尾调用现nextChapter，更不能只用ONE PIECE升序样本证明所有源顺序正确。
- 执行拆为A章序/历史章表、B显式start/end与原生边界交互，分别形成验收与提交边界。A具体缺失章号规则及共享取章落点仍在核定，生产尚未编辑；B不得用onReachEnd首次布局自动换章或新增Pan竞争层。普通菜单和Continue保留既有resume，自动翻页本章末停止保持，前章末还须核拆图末半/双页末spread/连续末图底部。
- 记录在.hermes-artifacts/20260906-rdr004-chapter-continuity/；当前设备已回grid，网络、账户、下载、备份均未操作。RDR004仍MISSING/PARTIAL，不以研究产物关闭问题，也不重启全产品审查。
- 主控追加当前原库/源代码证据：ONE PIECE含109連載+112單行本，00話后接01卷；恶女「动画化（3P）」存为sortKey3。当前DM5源first_number(title)可把宣传页页数当章号，Komiic以scanlator承载版型。全数字也不足以证明自然阅读序。拟确认「按当前版本连读、宣传项不混入」及同时修正koma-sources元数据的跨仓范围，再实施；生产仍零修改。详见research/content-sequence-decision.md。此为内容选择/生产者范围待确认，不接受用全局反转或数字排序蒙混关闭。
- 倒序补基线已完成：order02真实恶女43话6/35，order03真实Reader目录43→42→41→40.5→40→39，未选其他章；order04原grid，Continue如实改为该书。主控实际查看三张原图，并独立核05-final-grid→order04库逐字节相同，Reader仅该书三处updatedAt1786790330059→1788660138875，A23/B3、该书6/35和偏好均不变。QA已停止设备，没有新构建、生产修改或暂存。下一动作先确认上述内容策略/跨仓范围，不擅自跳到新切片。
- **2026-09-08用户已明确允许上述内容策略与跨仓范围**，旧“待确认”不再是阻塞。新run `20260908-rdr004-chapter-sequence` 从4f4bd846工作树接续A：源显式元数据→保存/更新→统一相邻章序，完整手动目录仍保留其他版型和宣传项；不改章名、ID、进度，不复制标题猜测到App，不把所有scanlator当版型。源仓既有DM5图片签名、Komiic图片ticket改动与Index/ReaderLab实验保留。B章末自然衔接随后独立实施，本片不增手势竞争层。当前先最小设计与197现包目录基线，未修改生产。
- A设计独立canImplement并经主控全文核准，进入实现：完整手动目录与同组派生相邻序列分离，当前前后章按钮及enabled读取新序列、仍resume，自动边界留B。DM5/Komiic显式组/资格和实际章卷号贯通缓存/收藏/更新/持久/会话；不修第三源。原元数据缺失保留手动及旧显式导航，不冒称已支持同版型自动连读。正常检查更新的metadata-only路径按现存ID补字段、保留缺席旧章/页面/原title/index，并连同Service实际持久化判定落实；显示0新章。原Index205增14删、Detail29增8删及源取图WIP排除提交。用户询问代理深度时曾按安全点暂停，现“继续”恢复原配置，未擅改模型/档位。
- 用户随后明确要求换新代理：旧shelf三代理均停止，新sequence_impl/review/qa接手同run，不重做设计；未显式覆盖模型/思考档位。当前4f4bd846包qa-before04主控实际看00話后01卷、09实际看恶女43→42→41→40.5且43话6/35，未切章/翻页。旧QA停在09章节sheet，无运行中协议；新QA以正式释放旧租约再acquire转接，非force。当前Koma仅有device-lease、无checked入口，使用项目租约包装skill runner；NextN入口硬限制自身项目路径，不适用于Koma，前述路径建议已纠正。末态数据仍待收齐，基线不是候选验收。
- A现已形成12个App文件及DM5/Komiic两源的限域候选，主控全文读取scoped.patch，独立候选review与实际方法检查通过；元数据更新、原持久化回滚、完整目录、历史单次会话发布仅属host证据。首次assemble退出255：Detail传递章节描述触发ArkTS结构类型限制，未复制旧HAP、未安装；正在最小类型修正。reader-kit构建前后均clean/3925f45d，已明确归还共享窗口供NextE构建，复审后再申请。尚无A真机通过或提交。
- 新QA已完成原样本接手并回普通书架：24份业务JSON中23份逐字节相同，Reader仅正常打开时间变化，章节ID/pageIndex/read标记未变。后验计划为正常升级两源、正常检查14本书架更新、同版显式前后章与旧进度、既有未收藏DM5历史完整目录；OP00話的下一现有话是684話，不虚构01話。真实新增章和正常访问记录如实逐项记录，不直接恢复业务JSON。候选交付前不升级源，B自动跨章仍不在本片验收范围。
- A v2仅补MangaChapterItem显式继承章节描述接口，独立再复核通过；重新获授的一次assemble退出0，固定`candidate/rdr004-a-v2-signed.hap`为14178914字节，reader-kit前后仍clean/3925f45d，窗口已归还。两源WASM及包构建通过，临时完整三源index保留MangaDex0.1.5原条目与原包，DM5升级0.1.5、Komiic0.1.3；未发布或推送。197安装与正常源更新流程已放行，仍待真实后验，不将build或host PASS写作功能完成。
- 197已安装v2并正常升级两源，14本更新实际为1更新/12未变/1跳过/0失败/0新章。OP221、恶女45的旧ID/title/pages保留，新章号/组/资格已落库，Reader与队列/manifest未变；其中MangaDex One-Punch Man原第233章tr版本被ar版本替换、58总数不变，是已复现的旧feed章号去重+远端替换链路问题，不计作正常通过，证据`implementation/mangadex-observed-replacement.md`，后续需处理且不得跨UUID迁进度。
- 用户插队纠正详情下载状态孤立行，A设备验证安全停在`qa-after/13-op-00-chrome`的00話23/23，尚未按下一章；无协议/server运行。主控实际看`11-op-original-00-reader`详情：原下载/收藏按钮下有独立“已下载23/23页”。现单独UI增量移除该ListItem，忙态反馈进原固定高度单行按钮，批次计数通过现有toast保留，不删按钮、不改动作。独立canBuild通过，正在获授窗口构建；UI先验收，随后从该停点续A，不将未完成邻接/历史/冷启动标为通过。
- 上述UI已独立提交`3c8d8548`，1文件+2/-12、未推送，原A及其他WIP均未提交。固定`detail-status-inline-signed.hap`14167413字节已装197，主控及独立review实际对照11/15原图与bounds：三个按钮位置/104px高度完全一致，孤立状态行消失，简介上移102px，章列表已下载标识与00話23/23保留。忙态/批次toast只完成代码与构建核对，未为验收制造新下载。A从原停点续验；UI提交后原A限域patch仍可应用。
- **A已独立提交App `b486da30`（12文件+324/-105）/源仓`0018287`（2文件+64/-18），均未推送。** 主控完整读取两仓cached diff后提交，原Index/Detail/源取图等WIP保留，两索引为空。197实际链路：00話23/23→684話1/19→00話23/23；01卷3/210→02卷1/202→01卷3/210；恶女43六页↔42、40→40.5→41→40.5；原未收藏DM5重骑士1/39→2话1/19→1/39，源返回174条目录重新载入。一次冷启42–46复核上述原页位与历史目录。原11本位置和14章位置/已读标记除更新时间外不变；6条正常首位访问记录新增，sourceHistory1条不变，22/24文件（含queue/全部manifest）与更新后09逐字节相同。库后续仅OP/恶女时间与4个实际取页章节pages/时间变化。详细证据qa-after/result.json、preservation-final.json、review/final-result.json；这是显式章序/目录/resume通过，不是B自动跨章或全Reader通过。
- 宣传条目33手动1/3可达、邻接禁用正确，但正文加载错误不能判内容通过。49已只读保存精确原缓存`44f8a760f2a99d2b.jpg`169189字节，主控实际打开完整海报，707×1000 RGB。51一次正常重开在197命中同一缓存并完成显示，主控已看原图；没有清缓存、转码或主动重下载。首次失败缺原错误码，仍未归因，不据重开成功宣称已修复，不新增猜测性重试代码。52恢复43话6/35、53返回书架；记录见原run `qa-after/promo-reopen-result.md`。当前处理已复现MangaDex目录身份替换；B仍未实施。QA曾将40.5黑底纸片图误认OP，已实际重看及核DM5 URI撤回，未发现错图证据。

## 25. 书架操作与多选纠正（2026-09-06，197限域验收并提交210dc66）

- 用户明确插队书架：首项图标/菜单语义、列表按钮与进度重叠、标题栏集成布局与多选且maxCount=3自动溢出、使用系统Checkbox、长按后内容不得下跳。RDR-004保持原待确认边界，不因本轮插队消失。
- **LIB-009 / S2·P1 / 选择态结构跳动**：源码在Continue和书架之间条件插入两排BatchActionBar ListItem，进入多选必改变内容占位；旧LIB-006只验证按钮可达，没有验证完整转换过程，此遗漏不能用“限域通过”辩解。与LIB-008选择控件/进度遮挡共同修复。
- 当前00-current原图已经主控实际查看：197首项为Local Folder Smoke，封面未成功显示而使用书本占位；原记录有非空封面URI，不能写成没有URI。50%进度与右上漫画菜单可见，不是新增功能入口。菜单按canRemoveComic门控，只给符合本地移出资格的项。用户未授权清理这些历史测试内容，本轮不删库数据。
- 实施范围与冻结项见`.hermes-artifacts/20260906-shelf-controls/scope.md`。before网格/列表/长按录屏已完成：排序和首行进入选择后下移377–378px，Continue不动；旧自绘勾覆盖50%，列表无Checkbox。当前普通列表菜单与进度有52px横向间隔，旧重叠在这份基线未再复现，不将其伪记为当前复现。
- 首候选只改LibraryPage/Index/ComicCoverCard：选择状态仍归LibraryPage，Index只接标题表现；移除插入式批量栏，标题动作使用HDS maxCount=3，网格/列表改系统Checkbox。19:35:17签名构建成功，固定shelf-controls-signed.hap为13629991字节；构建消费clean reader-kit 4a17aed，随后共享窗口已归还。当前三文件任务补丁173增149删，旧inset/Index等WIP排除，暂存为空。
- **首候选拒收，未提交**：197 after02主控与独立review实际对照before03，排序y885、首项标题y1594保持，原377px稳定态跳位消失；Checkbox 1→0→1及全选10成立。after06-category-menu却从y123起覆盖标题栏触发器，页顶1vp锚点不是真实按钮；选中暗层也覆盖进度徽标使白字和底色变灰，不能只凭无重叠判可辨识通过。正在修真实菜单锚点和暗层/徽标层级，继续列表、退出及状态恢复验收；不把首候选有限通过扩为全批通过。
- 首候选after09退出与after11浏览根页还残留X，主控/独立review实际看图确认。第二候选修为MINI backIcon+hideBackButton明确显隐，layout/categories使用真实HDS componentId→openMenu，原已读/未读直接列系统溢出，暗层移到badge前。独立源码/方法/patch范围检查通过，248增219删；19:53:14签名构建exit0，固定candidate-two包13625927字节，clean 4a17aed构建窗口已归还。尚未新包验收/提交。
- 首候选after13列表原生Checkbox尾区与progress净空72px，首行title y1090保持，主控实际对照before05；不能据此忽略该包三个失败。after15普通滑动却进入选择另保留反例；源码Down独立500ms timer不处理Move且grid同时有原生LongPress，正在同场景核实，不以不确定输入时序宣称根因真机已证实。
- **LIB-010 / S2·P1 / 普通滑动误入多选**已再现：after19普通态，20录屏只含1000px/velocity1000的swipe；21已选1，主控实际对照19/21，独立QA/review逐帧确认41→42在滚动中触发。第三候选仅LibraryPage撤裸计时器及字段，list正文补与grid同样的原生LongPress/Tap互斥组，onTouch只保留Down清旧抑制标记。三文件256增241删，源码/patch独立gate通过，等待构建及197慢划/长按/紧随点击检验。
- 第二包23–39已复核分类/布局锚点、X显隐、浏览及详情返回、导入菜单：主控实际查看24、27、30、33、36，独立review核其余关键图；00→39库/Reader原始文件主控cmp均exit0。24/37布局菜单没有当前勾，补原生selectIcon仅用于layout项，不给分类项加标记。
- 第三包20:06:45签名构建exit0，固定shelf-controls-candidate-three-signed.hap为13625955字节，三文件257增241删；clean4a17aed窗口已归还。197已装40；41与首次失败15相同首屏慢划输入，140帧全程不选择，43中段静长按68帧仍选中且不误开，42→44标题坐标不变，100%徽标不被压暗；主控实际看42/44，独立review看全部帧。45首次正文tap为已选0、50布局当前网格有系统勾，主控已看；列表手势及最终恢复还在验收，不提前提交。
- 第三包51列表当前项也有原生勾；53列表慢划136帧不误选，55静长按125帧只进入一次选择。54→56同ONE PIECE标题y1068→1069为1px舍入，不再插入原377px批量栏；进度与Checkbox净空72px。主控实际对照54/56与57/58，列表首次正文tap1→0、Checkbox0→1且不误开详情；61浏览无X。62只是源详情加载中，证明路由命中，不冒充源加载完成。最终Continue及原设置/数据恢复仍在进行。
- 第三包63普通详情返回无X；64明确Continue直达恶女第43话6/35真实图，未翻页；65返回grid，66设置根页/67书架设置返回图标正常、原grid/standard/added/徽标true成立，68最终grid无选态或菜单。主控已实际看63/64/66/67/68并独立核00→68原始JSON：库完全相同，Reader仅恶女三处updatedAt从1788660138875→1788697826514，位置/已读/其他漫画全部不变。三文件必要hunk已暂存257增241删，完整cached/check通过；原Index205增14删与Library三处inset6增2删仍未暂存。尚待独立最终裁决，不把暂存写成提交。
- 最终QA为PASS_SCOPED_SHELF_CONTROLS_CANDIDATE_THREE、独立review为PASS_SCOPED_197_CANDIDATE_THREE/canCommit=true，均实际核图/帧和原数据。已提交210dc66，仅三文件257增241删、不推送。LIB-008/009/010在上述网格/列表路径关闭；不外推整项目UI、所有源详情加载或真实分类/读态/移出业务通过。首次书本占位和仅本地移出资格未变，未清理测试内容。当前接续SEA-001现状核实与入口确认，不擅自开展RDR004跨仓内容改动。

## 26. SEA-001全局搜索继续入口（2026-09-06，197限域验收，App eaa6d86 / 源仓3656597）

- 210dc66后接续高频找书主线。当前CrossSearchService.searchWasmSource仍仅page1并截20条，SearchPage来源标题仅Text、没有进入完整结果的操作；RouterHelper.pushSourceSearch参数无query，SourceSearchPage首次出现也只载过滤器，没有自动消费初始查询。既有BrowseViewModel.runSearch/loadMoreSearch已支持页码和cursor，不需重造全局无限加载。
- Aidoku本地bc3cdc3快照SearchContentView来源标题含VIEW_MORE，SearchViewController.open把searchText带入源页；只参考「摘要→带关键词完整结果」语义，不复制其UI代码。拟用项目现有可点击来源标题行加原生箭头，避免再堆一排按钮；可见入口选择已异步询问，未答不视作同意。生产未改、不构建，先197取真实全局摘要/同源续页基线；RDR004和D34继续保留各自边界。
- 197当前包搜索「女」实见DM5·20，04→05点击来源标题仍留原全局页；主控已实际对照原图和08源内首批/09末尾。09滚到虫女后没有下一批，当前动作时间窗内未见新search请求，不能写成“实机重复第一页”。本条证明无继续入口；第2页真实内容仍未取得，不把首响应中第21本当第二页。
- **SEA-003 / S1·P1 / 源分页请求与结果契约不一致（本地源码确认，197触发结果待核）**：BrowseViewModel将args.page编码为{cursor,limit}，buildRequestJson→native原样交WASM；本地DM5 0.1.3却extract_json_number(page)缺省1，且nextCursor固定"next"。Komiic搜索不读取页参数且输出最多PAGE_SIZE，达到上限又声称hasMore；MangaDex搜索固定limit20且hasMore=false。不能仅补App标题入口就声称找书完整性关闭。关联源码/独立复核在本批review.md；源仓只读，已异步请求允许联动分页修复与正常更新源包验证，未答不改源包或跨仓生产。旧source-runtime-abi.md仍是2026-05草案的数字page，与现代码对象协议不同，不能把旧文档当当前契约依据。
- 本次只读基线以PARTIAL结束：10虫女完整详情1章可达；12Komiic同词首批可见，13一次末尾尝试实际未到尾，不虚构第2页/新增ID。14搜索历史正常增加「女」、原四词保留；15原grid顶部恢复，主控实际view14/15并cmp起末库和Reader均exit0。当前无搜索生产修改/构建/暂存；待明确来源标题继续入口及源仓分页修复范围后再实施，不能用反复取同一基线替代推进。RDR004版本策略/源章节元数据与此搜索分页是分别待确认的范围。
- 用户随后明确“允许”：来源标题可点击并带原生箭头、携原查询进入完整源结果，以及联动koma-sources分页实现和197正常更新本地源包验证，均已授权；不发布、不推送。此授权不包含RDR004版本策略/章节元数据。当前进入实现，原基线不重做。源仓原DM5/Komiic图片请求与版本WIP保持，提交只纳入本批必要差异。上方分页问题曾误用已存在的SEA-003编号，现唯一登记为SEA-005，SEA-003仍指无关键词筛选能力。
- App首候选5文件105增11删：ready WASM原标题加原生箭头/点击，用完整section来源ID及已执行关键词进入现有源页；源页已有route-local VM，Index零改。续查filters保持全局空对象语义且不覆盖独立源筛选偏好，初始化等待过滤器并只消费一次最新query。host运行真实生产方法通过；首签名包13809714字节/source22:05:50，clean reader-kit af63446构建后归还窗口。
- 197首包app-entry/02标题高仍72px、标题到首卡标题仍163px；03点击后确实携「女」自动出源结果，**却自动弹键盘遮半屏，拒收该项**。05返回全局与02的27项App文字/搜索节点bounds完全一致，词/结果/滚动保留；00→06库和Reader逐字节相同。补SourceSearchTitleField一行仅空initialQuery时autoFocus，普通入口聚焦不变；补包13809497字节/source22:20:18、copy22:21:00构建exit0，同clean窗口已归还，待197补验。两搜索页原inset不纳入提交。
- 源候选DM5 0.1.4、Komiic0.1.2、MangaDex0.1.3及SDK/docs共5文件；真实WASM采用完整App请求验证续页，Komiic/MD各20新ID，短查询分别1/10条false+null。DM5页间上游搜索列表有2交集、19新ID，不冒称稳定全集；初次猜页21把404推荐解析为7项的测试已拒收，最终search分支拒绝该页，沿真实分页导航取page20返回21个搜索结果false+null。初版DM5二进制未预留，覆盖边界如实记录；失败响应/初patch保留，不伪称旧命令路径仍指初版。固定wasm-final和local-index包仅本地供197正常升级，不运行会清空原dist的build.sh；源包/终验尚未完成，不提交。
- 三源已通过原索引“检查更新”正常升级且保持启用，source-update/02主控已实际view；索引与网络设置不变。最终App补包已装，final/02携词进入无键盘、03主动点击可编辑。但final/06滚到底及07点击加载更多虽均有新的DM5 search完成，列表仍原22本，无新增/错误，**续页FAIL，未提交**。主控已实际查看06原图，正在区分App响应/渲染链和源输入；不得用host新增ID结果替代这个真机失败。中间DM5导航10/15 HTML未落盘，独立source review只复核已保存page20响应与21拒绝，不冒称全导航独立取证。
- final/13 Komiic同样新请求完成仍停20本，保留FAIL而非继续反复点击。隔离检查采用已保存真实响应经过生产序列化/解析/追加，DM5为22→41、cursor2→3；固定WASM不联网截获也确认App键序下cursor2/3生成page2/3。私有ResultsGrid把数组按值传入Builder，而loadMore替换数组，官方Builder规则明确这种传递不跟踪owner新引用。最小补修同页三行：无参Builder直接读viewModel.searchResults，App共6文件109增15删；不动共享Grid/SourceBrowse几何，仍待补包197验证真实刷新。临时8767仅供三源正常更新，更新完成后已关闭，原索引配置保持。
- 最终grid-refresh包13812966字节/source22:39:23、copy22:39:44，构建exit0，clean reader-kit96567e4窗口前后均clean并归还。197新包DM5同批末虫女单格→05追加两本，06《我的女友是恶女》117章；Komiic末行两本→13新《雖然我是不完美惡女》21st、14详情45章；MangaDex末行两本→24新Sophia标签21st、25详情6章。不是复用旧host窗口猜新增；MangaDex该标签实际为错误简介，详情书名另记FAIL。
- 主控已实际查看关键前后原图和三本详情、28原grid；独立review实际核三源链。六对源页/全局返回App文本与bounds完全相同；主控cmp00→28库/Reader均exit0，无阅读/收藏/下载/筛选或网络设置动作，搜索历史正常提交女/girl，不覆盖恢复。普通独立空SourceSearch仅空浏览fallback可达，未制造空数据验收，普通Browse输入聚焦不冒充该分支通过。
- QA PASS_BOUNDED_SEA001_SEA005_DEVICE_FLOW、独立App canCommit=true与source canCommitScopedPagination=true，均明确不接受MangaDex书名。已分别独立提交App eaa6d86（6文件109增15删）与源仓3656597（5文件175增25删）；cached全文/check已核，不推送，原两搜索页inset/Index/源图片请求/Cargo/bh3等WIP保留。197未遍历终页、DM5上游不稳定、SourceBrowse同型按值Builder仅源码发现均不外推通过。

## 27. SEA-006 MangaDex书名取值（2026-09-06，197限域验收并提交8fde3b2）

- 上一分页切片已独立提交后接续，不再跳到下载或重启全产品审查。qa-grid-refresh/25的标题栏、漫画标题、简介三个Text是同一完整段落，主控和独立review已实际核图/layout；24源搜索卡也使用该错误标签。不是单纯“长书名正常省略”。
- 当前source search/get_manga_list/get_home对整个对象extract_json_string(en)，get_manga从title起取无边界后缀，均可跨到description.en。最小修正生产者书名对象边界，保持既有en/ja/ja-ro优先级和原布局、ID、章节、阅读、分页、账号/网络设置不变。具体原始API title和必要SDK复用边界正在核实；不以静态推理宣称已修。
- 已取得同ID `24f1dedd-5e95-41c3-b17a-355e6cd224c9` 官方原始响应：title只有ja-ro `Mihara Sophia wa Kowa Girl`，description.en恰是设备错误标题全文。四路统一限定attributes→title→语言直接成员；search/detail/list原en→ja→ja-ro保留，home原只有en→ja，本批明确补第三ja-ro后备。SDK仅公开既有直接成员读取器，分页读取不变。独立复核指出候选顺带改变description读取，主控要求撤销，避免把未实证的相邻字段问题混入；正在重建仅标题修正版，尚未197更新验收。
- 最终title-only固定WASM70874字节、MangaDex0.1.4；两文件30增26删，SDK5 tests/只MD构建通过，四个producer同原API旧新实际WASM回放中除title外全部字段深比较一致。旧71207字节含description候选已保留且排除。Root全文核patch并独立重比响应、D/K旧包字节；未构建/安装App。
- 197按原索引正常升级后，04上方已装0.1.4、下方仍0.1.3，05浏览也旧版，明确登记SRC002显示FAIL。07同书搜索标签、08详情两标题均已是正确书名，Root和独立review实际对照旧25原图；封面/作者/MangaDex/6章/简介保留，日志实际search与get_manga关联70874字节新包，证明不是升级失败。临时8767已关闭exit0；返栈/库与Reader末态和独立冷启回显检查仍在进行，不提前提交。
- 09返回与07 App文本+bounds相同；10热态磁盘registry已0.1.4，11正常冷启浏览回显0.1.4，12原grid恢复。Root实际view11/12并独立核00→10→11及00→12库/Reader逐字节相同，无阅读/收藏/下载/筛选/账号/网络设置动作。QA限域PASS、独立canCommit=true，两文件30增26删cached全文/check核后已提交源仓8fde3b2，不推送；原图片/Cargo/bh3 WIP未暂存。冷启恢复不等于SRC002已修。

## 28. SEA007 普通源浏览搜索刷新与分页页脚（2026-09-06起，197限域通过并提交b3cd1a5）

- 独立只读核普通Browse→DM5原位输入→runSearch/loadMoreSearch→MangaGrid链：loadMoreSearch替换searchResults数组，SourceBrowse仍通过按值Builder传入。SourceSearchPage第26节已发生同型真实失败，但不能直接当本页真机复现。
- 当前固定App13812966/源DM5 0.1.4不变，197普通原位「女」首批末与一次正常续页基线已交QA；不经全局来源标题继续入口，不预设DM5动态窗口书名，不反复点击。若实际通过就不做推测性修改。原MangaGrid也服务两处非搜索section，候选范围仅搜索直接读取owner状态、保留原inset等WIP，未编辑生产/构建。
- 197 qa-before05已真实FAIL：普通原位女首22到末触发23:48:52.929 DM5 search，23:48:53.321执行65500字节源成功，仍是虫女单占最后行、无追加。Root实际看05，原来源继续入口没有被拿来替代。用户随后两次指出单独“加载更多”按钮及左靠，当前切片明确加入此交互纠正；不是新开设置/其他页面切片。
- Root核KomaActionButton.fill仅layoutWeight、ListItem直接放按钮无居中容器；核NextE GallerySearchPage自动onReachEnd+LoadingFooter及48vp全宽居中行/24vp spinner，Huawei组件示例也使用24vp加载指示。计划统一两搜索页与普通listing尾部为轻量状态页脚，正常无手动按钮，仅失败重试/结束提示；首屏与refresh/listing错误原UI不改，非搜索网格数组与源分页协议不改。搜索分页catch原hasMore=false阻断重试，新增最小人工retry方法恢复同cursor续页，不自动无限重试。当前七文件候选正在实现，尚未构建或197后验收；SRC002仍单独待修。
- 七文件候选冻结92增41删：Root和独立review全文核必要patch，实际生产两方法隔离检查/三语key对齐通过（searchSource/去重辅助为host替身，不充当真机）。2026-09-07 10:39:07签名构建exit0，固定sea007-signed.hap13848469字节/copy10:39:48；clean reader-kit2063b3b窗口前后已核并明确归还。当前197需跨天重新取得live target/lease/awake后安装验收，不复用昨夜过期lease；没有推送或提交。
- 2026-09-07 fresh租约取得后10:53安装该固定包。qa-after05→06纯滚动→07同批女巫末行新增初恋是笨蛋幽灵/猫女，08新增条目详情4章；Root与独立review均实际看图。06录屏frame000088中spinner与加载中文字组位于末行下方水平居中，无独立按钮，双方实际看帧通过这一状态。09返回文本/bounds由独立review比对与07相同。另一搜索入口、短查询终点及普通listing页脚仍在验证；10文件名含tail但图未到末尾，明确不计该消费者通过，当前未提交。
- 用户追加后续核实：当前分页切片完成独立提交后，核对详情主阅读按钮是否随已有记录显示“继续阅读”及合理章节/页码信息，并核对真实续读目标、阅读后详情回显。不先假定已实现或缺陷成立；此核实优先于尚未开始的SRC002后续切片，不打断当前SEA007验收。
- qa-after11普通DM5 listing末鬼灭之刃、12 MangaDex Mihara四本短查询，均实际出现居中“没有更多了”，Root与独立review看图确认；不推称非搜索listing第二页正确。18导航误点进入Komiic《女勇者和魔王军干部II》详情，主体书名正确但标题栏“未命名漫画”，保留为独立待追链缺陷；18不能按first-batch文件名算作源搜索页。20才是真正全局来源标题继续进入SourceSearch的女关键词首批，后续分页仍在验收。
- 最终20–24 Komiic源搜索首20末行两格→纯滚动自动新增第21与下方新行；23/frame000070实际spinner/文字组合居中，25新增条目详情18章。Root与独立review实际核关键图/帧；DM507→09、Komiic24→26、全局19→27文字与bounds一致；28原grid已看，Root与独立review各自核00→28库/Reader逐字节相同。197已安全释放给NextE任务，不再操作。QA与独立canCommit通过，cached七文件92增41删全文/check核后已提交b3cd1a5，不推送，旧inset/资源/Index等WIP未混入。失败重试仅宿主实际方法检查，非搜索listing仅终态，不声称全分页/整页UI通过。

## 29. 详情开始/继续阅读核实（2026-09-07，只读，197限域确认）

- 用户询问有记录时主按钮是否变成“继续阅读xx”。源码与独立只读复核确认：primaryReadLabel仅“开始阅读/继续阅读”两词，不附章节/页码；progressChapterId要求记录章节仍在当前chapters，按钮目标优先该章节。completed不触发“重读”或自动下一章。
- 本地/已入库源优先真实library comic.id，未入库源为sourceId:mangaId；Index两条入口最终由ReaderSessionStore.restorePageIndex取该漫画/章节的保存页码。关闭先保存/flush再发readerProgressRevision，详情onShown也发布revision，Monitor重建chapters。源码没有确认刷新断点，但这不能替代文字实际更新的设备观察。
- 197暂由已协调NextE任务使用，当前没有新实现、构建、安装或设备操作。计划复用现有43话index5/35记录核普通书架详情→按钮→同章第6页→返回原详情；本地文件夹只看有记录标签，不进不支持的Reader路径。首次新建阅读记录后的动态变化未列本次已通过项，不人为写storage或制造样本。范围见`.hermes-artifacts/20260907-detail-resume-verification/scope.md`。
- 交回后新租约20260907-032536-fe00b155，fresh gate与同包启动完成。02恶女详情实际“继续阅读”，03正常主按钮进入可见6/35，04返回详情仍“继续阅读”，05本地Folder既有记录同样“继续阅读”；Root逐图实际查看。源章节身份由本批library chapter1664686对应第43话35P与00/03/06保存的同chapter/pageId:5关联，并非单靠页数猜章。无记录分支沿用同包SEA007/25可见“开始阅读”，未创建新记录。
- 06原grid已实际查看，Root独立深比起末库文件字节相同、Reader仅目标记录的三处updatedAt正常更新，章节/页码/完成标记和其余记录不变；QA已释放设备。当前结论为：已有匹配记录会变“继续阅读”并可回原位置，但没有章页后缀。没有生产修改/构建/安装/新提交；首次无记录→记录后即时换字未测，不冒称通过。

## 30. DL003/004 下载执行与暂停继续（2026-09-07，执行机制已提交9516ac6，暂停反馈未关闭）

- 当前b3cd1a5包，197原队列4条均完成共102页，无活跃/排队任务；原偏好concurrency1/isPausedfalse/wifiOnlyfalse。QA00→05库/Reader/queue及4manifest均字节相同，Root已看04管理原图。经完整目录列表确认，恶女第42话32P候选既无queue也无离线目录（与43话阅读记录分离），只授权此单章正常UI下载，不删旧任务、不改网络。
- 源码及NextE边界已独立复核：Koma所有产品downloadChapter调用在UI async runtime，唯一可写恢复taskpool来自管理入页；不能假定模块Map与worker共享。无owner/通知、入页校验活跃manifest、paused PARTIAL被继续遗漏且暂停原因被reconcile覆盖均源码确认，详见`.hermes-artifacts/20260907-download-owner-resume/source-review.md`。
- 197单章实证：qa-before08/09界面停17/32下载中、header102/134且需处理1章；09 queue和target-manifest已经32/32 downloaded。Root实际看两张原图并读取原JSON确认，判刷新FAIL，不以后台下载成功冒充管理页完成。任务在pause操作前已完成，DL004暂未真机执行；瞬时FAILED manifest未抓到，不冒称已抓到写盘中断证据。
- 正在最小候选实现：统一同章owner/变更通知、真正进程残留初始化与恢复范围，保留暂停理由/有效页，修同刷新链按值group/row绑定。详情两处hydration失败也写queue/manifest，必要追加两处await纳入同gate，共六文件。UI几何/文案/原菜单保持，DownloadsPage旧inset单行及详情其他WIP不纳入；不扩后台/批量/断网/Reader。未构建或提交。
- Root补看录像244→245汇总切换和11重进32/32、12原grid；独立05→12比较Reader与原4manifest字节相同、原4queue仅updatedAt改变，library仅42章正常hydration与时间戳。新32页保留，DL004仍未执行。当前197已释放供NextE任务使用；reader-kit a679353+D10 WIP无clean构建窗口，等待其明确版本后再构建，不消费未完成共享修改。
- 六文件候选冻结368增198删，Root全文读912行stage.patch并重跑实际方法host、cached apply check、diff check通过；独立review允许构建，canCommit仍false。host覆盖同章join、暂停收尾、paused PARTIAL继续及原页复用、冷残留页/原因保留；taskpool/网络/文件替身明确不证明原生运行。index仍空；当前等待共享依赖clean窗口及197交回后，签名安装走同路径进度完成/暂停续传，不另开可见切片。
- 12:16:15签名构建exit0，固定dl003004-signed.hap13952960字节/copy12:16:43；共享reader-kit d303c6b前后实际clean，窗口已明确归还。197由已协调NextE下载任务使用，待其安全交回后fresh gate安装本候选；未提交，不以构建通过关闭DL003/004。
- 197新lease20260907-043857-72b3dcff，候选安装后00→02 queue/库/Reader/原五manifest字节相同；fresh目录/queue确认41话46P无下载数据后，主只批准此一章。qa-after04b19/46→05点暂停44/46→06/07稳定45/46→09同页46/46、组78/78、汇总180/180，Root逐图实际查看。Root独立06→07manifest全同，终点前45page records逐字段保留；00→10Reader及五manifest字节同、原五queue entry含时间与prefs全同；库仅41hydration0→46及chapter/comic时间变化。10原grid已看，lease正常释放，新46页保留。
- 943帧/27接触表QA顺序全查，Root实际看25–27和800/905/906/914/915/942完整帧；Continue所看帧45paused→45downloading→46完成，未见0/0画面。08存储短暂queue0/0与45页manifest同存被保留为快照边界，不叫丢页；部分录像有块状画面异常，不以其推定像素几何/全合成帧通过。Root和独立review均实际看到800错误toast“章节下载失败”，源码详情把所有非DOWNLOADED结果当失败；正常暂停黄warning/需处理亦未关闭。
- 独立仅允许前台owner/实时进度/保留页续传提交，Root核暂存完整diff与已全文读的冻结patch完全一致（仅文件块排序归一化）、check/文件清单/status后已提交9516ac6六文件368增198删，不推送，index空。提交信息明确暂停呈现仍有问题；没有称DL领域或整页UI全部通过。已非阻塞请求用户批准下一小批仅改正常暂停反馈/中性色、不改布局；期间回到DL001/CHP001完整章节集合只读核实。

## 31. DL001/CHP001 章节批量范围（2026-09-07，完整筛选入口限域提交64fad10）

- 基线9516ac6加原有WIP；完整核查见`.hermes-artifacts/20260907-chapter-batch-scope/source-review.md`。分清当前取得目录C、完整筛选排序结果F、前80/160等展开窗口V，以及当前不存在的任意章节选择S。主控实际复核窗口函数、五个菜单回调、详情handler和中文资源。所有现有批量菜单输入V；重试/未完成文字未明示这个限制，不能笼统说全部菜单均标注“可见”。
- 当前Library多选只有分类/读态/移出等，无下载事件。跨漫画读态已有，不误报全缺。详情循环逐章hydrate和下载，并未事先将所有目标持久入队；不能把页面循环直接当成持久跨漫画批量队列。
- 独立核本地Aidoku bc3cdc3：详情全选取F，所选操作取S，书架全部/未读下载取各漫画目录C；不复制源码。建议下一下载能力切片先明确单本完整筛选集合，清筛选等于当前目录、未读筛选覆盖全部未读，不依赖展开量；任意选择与跨漫画后续独立验。新增入口/数量回显属于可见变化，实施前须确认，原“可见”菜单不能暗改语义。
- 源目录跟随分页最多20次，每次limit100；C只能叫当前取得目录，不凭数组长度宣称所有源绝对完整。此次未修改生产、未构建、未操作197，也未下载长篇来证明集合范围。下一实际修改仍优先等已提出的暂停误报窄范围授权，不重开全局审查。
- 上条为只读时的历史队列。用户随后明确确认“按当前筛选的全部章节实现”，现于续读提示提交后进入该授权切片；新增F入口与数量确认，原V含义不变。197暂借NextN任务，待明确归还后重新设备门禁；共享reader-kit正在D11实现，构建需另协调清洁窗口，不消费中间源码。
- 当前候选五文件57增0删，实际方法host/独立canBuild通过，未构建/未提交。197已归还并fresh租约；qa-before01/02真实221目录/原菜单，04→05显示80条窗口后的追加，08 OPM es-la两章17+19页，原六完整下载180页未改。主控实际看这五张图，不外推整页UI通过。候选后仅批准两章36页小F执行；长篇只确认/取消。
- 同次04实际看到详情“再显示80章”仍左侧独立按钮，这是用户此前加载更多问题的另一个消费者，未被SEA007源搜索页脚提交覆盖。本片仅F范围+确认，提交后接续该详情展开入口的独立修正，不伪称此前已全修。
- 候选一14041803字节已构建/安装197；80与160展开时F确认均221/1/220，未读220/0/220，未读∩連載108/0/108；小F语言es-la实际两章下载完成17+19页，重复确认2/2/0。主控/QA/review实图一致发现29完成后两行仍普通下载箭头，**同页状态回显FAIL，暂不提交**。32保存原地失败，不重进伪通过；当前优先补该下载闭环必要最小状态修复，布局和F/V语义冻结，展开入口后移到本片真实验收后。
- 候选二修为稳定ID读取owner最新章节/徽标字段，原key/几何/F/V不变，五文件125增56删，host/独立source gate通过。clean reader-kit0e160c4构建fixed14050959字节（17:42:14），19735原两章均显示已下载，只算已有状态恢复；当前补验Solo pt-br单章27P同页动态完成，不删除前8下载。
- 同次37主控实际view新包普通Solo详情：标题栏Solo Leveling、主体标题Unknown；续读提示46话2/11页，而原下载摘要10/10来自另一章。这是实际元数据/动作上下文差异，不算详情整页通过，归入现有内容身份/详情名称待处理集合；未在本片改名或改阅读/下载目标，更未确认原始源原因。
- 候选二补验42截图仍为Koma单章处理中，43截图却是另一个应用下载页；虽Koma queue记录27/27，**不能算同页刷新通过**。43采样前click(600,2640)落在系统导航栏，记录为协议瑕疵，具体切换因果未证实；两个协调任务核对本地命令后均确认无197操作。保留43失败和执行原件，后续取消为等待而发的点击。43协议身份文字还误沿用候选一，须以实际安装记录补勘误而非覆盖历史；当前仍不提交，恢复后另取最小样本补同页动态验证。
- 后续48正常点击Solo封面仍退出，不能只归因43采样误点。定向历史日志未取到栈；53安装保留的候选一14041803，对同一份数据55/56也退出，**否定“候选二独有回归”的判定**。没有实施猜测性的getter回退/守卫；当前优先用预录有界日志捕获退出原因，F批量及展开入口均不提交/不叠加。原九完整下载243页保留，另备he两章未下载。
- 58在点击前开启完整15秒hilog，确证MangaDetail进入后主线程阻塞、THREAD_BLOCK_3S→6S，系统以THREAD_BLOCK_6S杀掉Koma；59日志指向的精确stack文件权限拒绝，未获JS栈。源码明确详情装饰/摘要默认同步读取整图并逐字节hash，新pt-br27页83,434,483字节，原Solo hi仅3,828,685字节。候选三仅将Store.loadSummary改为轻量文件验证（保留manifest/身份/路径/页序/存在/大小，UI摘要不重复bytehash），其他显式完整校验保持原样；F与候选二row不另猜改。正在实现/重建，须原数据入口与批量同页实测，不能将源码热点说成栈证明。
- 最终候选三fixed14050316bytes（18:22:17），clean共享0a7882c窗口构建exit0后归还。19762同83MB数据详情15秒后稳定，日志39.490 onAppear→39.517 onShown；66新he F2/0/2，67确认后68/69无输入采样，69两章均绿色已下载且批量2/0/0；71再次F2/2/0，72回普通书架。主控和独立review实际看关键图，不声称书架排序/锚点全同。原九manifest与Reader字节同、九queue及偏好结构同，仅he11+19两新下载；库仅第45话新增19pages及章/漫画时间戳，第46话原已有11pages未变。
- QA限域PASS、独立canCommit=true。主控核暂存六文件128增57删，所有hunk正文/context与冻结补丁一致（仅WIP基线导致blob/行号不同），cached check通过后已独立提交64fad10，index空、不推送。全套失败/勘误和最终证据在`.hermes-artifacts/20260907-filtered-chapter-download/`及同名device197分区；没有JS栈、连续每个downloading徽标、大批实际执行或完整详情风格验收声明。接续详情展开入口独立片，不在本提交中混改。

## 32. 详情续读章页提示（2026-09-07，197限域验收并提交2d11758）

- 最终四文件57增1删；公共KomaActionButton与原32vp操作行不变，只在有匹配阅读记录时于行下4vp增加14sp可换行章页提示。章名来自实际章节，页码沿用Reader恢复算法；无已知总页数不伪造页码，无记录仍为“开始阅读”。首候选把两行塞入32vp按钮，主控/QA/review实际看图均拒绝；失败证据保留，未提交。
- 最终固定包`.hermes-artifacts/20260907-detail-resume-label/detail-resume-label-two-signed.hap`13964460字节，build-two.log通过；共享reader-kit31d6be5清洁窗口前后核实并归还。197 qa-after05显示43话6/35，06续读确为6；09自然翻至7，10详情提示7，11再次续读7；12正常回6、13详情6。08近滑块点击未换页，保留无效样本，不计成功。
- qa-after15本地既有记录显示Chapter01第1/2页，仅看详情不进不支持Reader；18无记录Mihara仍“开始阅读”且无提示；19恢复原书架。主控实际看05/06/08/09/10/11/13/15/18/19，独立review另核12。起末library全同，Reader只目标三处updatedAt正常变化，其余身份/页码/完成状态不变。无真实长章名换行样本，不宣称此项已真机验收；首次无记录创建后的变化亦未实测。
- QA PASS_SCOPED、独立review canCommit=true；主控全文核暂存四文件/check后独立提交2d11758，index空，其他WIP保留，不推送。lease20260907-080318-85d9fef6已正常释放，197正式交NextN任务暂借。暂停误报与完整筛选批量没有被此提交关闭。

## 33. 章节展开入口居中与后续列表结构（2026-09-07）

- 17a1d40只将详情展开入口改为ghost/fullWidth，1文件2增1删；保留32vp高度、80章步长及其他几何。197固定包14049884bytes通过，同947话80尾原图对照；文字外点击1050,2445可展开160，末61继续至221后入口消失；F确认221/1/220后取消。主控/独立review实际看图。11份manifest和queue/library/Reader共14文件起末字节一致，不下载、不阅读、不推送。证据`.hermes-artifacts/20260907-chapter-expand-footer/`及同名197分区。此提交不代表已经实现逐章懒渲染。
- 用户随后明确“章节名称保持，列表需要优化”。当前结构确认：整章区一个ListItem，内部Column/ForEach前80条，手动每次再显示80；不是逐章懒渲染。当前独立片`.hermes-artifacts/20260907-chapter-list-lazy/`按官方ListItemGroup/Repeat契约与NextE原生分组参考设计，保持单滚动容器、现有行视觉和名称，不改公共scaffold。
- 用户另明确批准：批量统一当前筛选全部章节F，移除重复下载可见入口、数量确认；不再保留已展开V前缀或将范围改成viewport/cache。单章操作不变。197当前01首章基线已采集，尚无新候选验收。
- 暂停后续Solo源标题回退片：实际MangaDex原始响应primary title只有ko-ro，altTitles有en Solo Leveling；现helper仅primary en/ja/ja-ro导致正文Unknown。该书名问题与本批“章节名称保持”不同，尚未实施源修改，不改书架保存名称。原始响应与只读报告在`.hermes-artifacts/20260907-detail-title-gap/`。

## 34. 详情阅读单行与下排对齐（2026-09-07）

- 用户拒绝第32节外挂章页提示，也拒绝后续第一候选的两行阅读、开始阅读增高与下排小团居中；明确不许因此取消下载/收藏或搬回上排。被拒绝源码、HAP、截图与结果均保留在`.hermes-artifacts/20260907-detail-action-hierarchy/`，不得将其功能可用当作视觉接受。
- 最终254052c1仅MangaDetailPage150增44删。主阅读恢复原32vp、14sp单行：无记录复用原公共按钮，有记录使用同色同高native Button，动作/页码不压缩，仅原章名弹性省略；下排保留原下载及书签，下载fill撑满剩余宽度、书签右侧，与主按钮两端对齐。业务96个原非布局方法逐字不变；enabled保留原生反馈，disabled-only沿既有配色契约。原29增8删WIP排除且保留。
- 第二固定包`candidate-two/detail-action-singleline-signed.hap`14086653bytes，20:10:58构建退出0；共享644c55af前后clean、窗口已归还。197 `qa-candidate-two` 01/04/07实际三态均主控件[39,890][1221,994]104px=32vp；label/page同y916–969，下排download[39,1020][1078,1124]及bookmark[1117,1020][1221,1124]同边。主控和独立review均看整页原图，不只使用bounds结论。
- 当前包02点主按钮右侧进入00話23/23，03返回同详情；没有二包翻页验证，旧两行包23→22→23仅为历史功能证据。最终08停新版ONE PIECE详情给用户查看。原库、队列、11份下载manifest字节不变；Reader仅目标三个updatedAt正常更新，页码/完成/其他记录保持。下载和收藏会直接下单/移出，本片未点击，只核原回调不变及视觉；长章省略、禁用/hover/focus为源级检查，未宣称真实样本通过。
- QA与独立review限定通过后独立提交，不推送。接回第33节parked list；恢复时必须保留本次操作区，不覆盖文件为旧快照，不复用旧包冒称组合包已验收。

## 35. 连续章节列表与完整筛选批量（2026-09-07）

- d373c8b6限5文件235增236删：章节以原生ListItemGroup/Repeat虚拟列表接入同一滚动父级，移除80章手动展开；章节名称/编号/行样式保持。批量下载与已读/未读统一当前筛选全部F、执行前数量确认，移除重复可见章节入口；单章语义不变。254052c1操作区及原详情29增8删、资源WIP保留。
- 新组合包`20260907-chapter-list-lazy/resumed/chapter-list-lazy-combined-signed.hap`14079931bytes，shared501cb5e构建前后clean，窗口已归还。实际方法host检查和独立源码检查通过。
- 本次197原始证据位于`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260907-chapter-list-lazy/qa-resumed/`：05首屏几何与已提交操作区相同；06录屏348帧双向跨原80边界947→899连续，07回原首屏；09–11已读/未读/下载F221数量确认并取消；13–17已读F1、交集空态、重置；19–21升序复用00話行实际进入Reader23/23并回同锚点；24–32真实es-la两章F2已读→未读，即时标题灰黑与筛选2→0→2回显。
- 03→33库、队列、11份下载manifest共13文件字节一致；Reader仅既有ONEPIECE00三个正常打开时间及获准两章显式false/no-position记录，既有位置/已读状态不变。没有新下载/收藏/网络/账号操作，没有原始存储写入。33停普通书架。
- QA、独立review和主控实际查看关键原图后限域验收并提交，index空、不推送。结果见本批`qa-resumed/result.json`、`review/resumed-result.json`、`resumed/integrate-result.json`。不声称全项目UI、当前包全221遍历/FPS提升、新下载重试执行或外部Tracker验证；旧完整221录屏仅历史补充。接续已确认Solo MangaDex书名Unknown源层回退缺口。

## 36. MangaDex有效备用书名（2026-09-07）

- 源仓8cdb38a仅SDK与MangaDex两文件105增14删，版本0.1.5。保留直属primary的en→ja→ja-ro优先级；缺失时取直属altTitles同语言优先级、同语言首个非空值，再取其他直属primary字符串。原分页helper、四producer其他字段、章节/图片/App均未改。SDK6测试与旧新实际WASM四出口Solo/Sophia回放通过，non-title字段等值。
- `.hermes-artifacts/20260907-detail-title-gap/`保存源码/host/包/QA/review/integrate结果。固定WASM72872bytes、包23523bytes；独立索引保留原三源，仅MD version/pkg改变。没有执行会清空repo/dist的现build.sh，旧feed/dist/WIP均保留；仅本次临时8767服务，正常更新后已停止。
- 197 raw同名分区qa04正常更新、registry实际0.1.5；06从书架进入并等待源get_manga/get_chapters完成后正文Unknown→Solo Leveling；07再入与09普通源搜索→10详情均正确，25章/封面/作者/简介/原进度一致。再入可命中缓存，不能声称每次重新请求；原生日志没有UUID，身份一致性来自原封面/章节/保存位置及host输出ID不变，不声称日志直接证明同ID。
- 00→11库/Reader/队列/11manifest共14文件字节完全一致，其他两源registry对象不变；MD仅版本/字节/包路径正常更新。11回普通书架。独立review和root实际看关键原图后提交两文件、不推送，源仓原6项WIP逐字保留。
- **未关闭**：qa04上方已装0.1.5而下方仍0.1.4，SRC002确实再次复现；Solo原有阅读第46话2/11与下载另一章10/10不是同一操作目标，旧62已存在，本片未改；带引号标题额外转义旧0.1.4也存在，已记录而未扩大修复。不外推整个详情/源页面UI通过。

## 37. SRC002安装版本同页回显（2026-09-07）

- c321052a限SourcePackageManagerPage一页15增9删。PackageCard不再持有替换前的按值对象，改传稳定sourceId并从当前packages读取字段，点击同样重新取当前对象；复用既有installedPackage方法。ForEach key/布局/文案/控件不改，原52增27删WIP排除。实际方法host覆盖对象替换和旧回调、131其他方法逐字不变。
- 固定HAP14078513bytes、shared56634ca构建前后clean，单包窗口已归还。`.hermes-artifacts/20260907-source-version-reactivity/`保存build/implementation/qa/review/integrate；同名197 raw分区qa08正常系统文件picker导入真实旧0.1.4作为基线，09→10只正常升级输入、没有退出/重进，下方已安装行与上方同时即时0.1.5。11点击当前行、12关闭再打开弹层都是0.1.5。原下方title/version/enabled bounds相同；不声称全页每像素相同。
- 00为安装前旧14079931包，01才安装本次14078513，原metadata有显式纠正而未覆盖。00→14库/Reader/队列/11manifest共14文件字节一致，D/K注册对象不变，MD恢复0.1.5/72872/en/enabled，仅正常安装路径字段变化。仅复制到公共Download的本次唯一旧包22934bytes已核对后精确删除，源包host原件保留；本任务8767服务已停止。14停普通书架，无其他设备文件/网络/用户数据清理。
- 独立review与主控实际看同页前后图和弹层后限域验收，独立提交不推送，index空；全部其他WIP保留。仅关闭SRC002版本行/当前对象点击，不把现有“检查完成”历史摘要重算、整页所有UI、其他源开关/语言都计入通过。

## 38. DL004正常暂停反馈（2026-09-07/08，限域验收通过）

- 候选冻结于`.hermes-artifacts/20260907-download-pause-feedback/`：两页与三语言资源共5文件49增11删，首轮源码review只允许构建、不允许提交。严格按paused且QUEUED/PARTIAL识别正常暂停，统一单章/批量反馈、暂停图标/中性色、需处理汇总与失败筛选；执行器、存储、F批量循环和布局不变。host方法检查不替代真机验收。
- shared c4c6350b获准单包窗口，构建前后clean；一次构建exit0，固定HAP14083781bytes/22:31:04已安装197，窗口已正式归还。其他任务此后开始Index/ReaderLab独立实验切片，不属于本批提交，也不改变本固定包；再次构建必须另行协调。
- QA保存00/01/02基线与安装前后14文件exact，租约已fresh续期到23:30:46。“虽然我是不完美恶女”第40话37P正常下载完成，但**未实际按暂停，暂停gate未通过**：首个页落盘22:34:28.845到完成22:34:46.178有约17.3秒窗口，中间日志检查/汇报打断连续观察导致错过，不归咎于设备或下载过快。06连续录像保留；原11manifest/Reader字节一致，旧queue11条及prefs不变，库仅目标40话pages及章/漫画时间更新，新增37页正常保留、不删除重下。
- 唯一追加样本第33话38P（chapter:manhua-suiranwoshibuwanmeienv:1516755:38）也已正常完成、**仍未按到暂停**：14 layout曾有2/38，随后同次截图实际13/38且暂停可见；返回模型边界后才执行15点击，当时已38/38。所谓“连续协议”未真正覆盖发现控件到点击的单次执行，第二次执行失败保留，不把上下文续接归为设备故障。新增两章共75页正常保留；不自动追加第三章，不改Wi-Fi或清理用户数据。
- 2026-09-08用户明确“允许。后续这种程度的操作不用问我”：少量正常验证下载且保留数据、不改网络的操作自行推进并报告，不再以逐章授权暂停。第三样本恢复197当前连接/有效租约后继续；`pause-controller/controller.cjs`已独立离线通过，同一次调用发起/导航→有界90秒/18次读取→识别当前部分进度与暂停按钮即点一次，完成/缺失/0页不点击；离线通过仍不等于暂停真机通过，保留前两次失败。
- 补验前保持未提交，等待实际暂停/续传证据，不用新实现绕开未验收切片。下一项任意选章已有只读缺口报告`.hermes-artifacts/20260907-chapter-selection-gap/source-review.md`；已纠正第9节旧V限制描述，不能重复报成当前缺口。
- **2026-09-08续验**：新租约c0f060d8、197 fresh Connected/连续AWAKE86400000门禁，17原数据与16字节一致。第32话40P因控制器真实spawnSync不接受浮点timeout而在发起后抛错，未按到暂停且正常完成，保留为第三次执行失败；仅artifact内修正取整，并实际本机子进程检查，通过后才继续最邻近未下载第28话40P。未改生产、网络或重下/删除前章。
- **最终真实路径通过**：固定14083781包、单次控制器sample1读到1/40后唯一暂停；录像32的frame375为10/40按下，391/396为11/40中性pause且真实toast“已暂停”，604仍11/40。34/35稳定manifest字节一致；36原生状态菜单只有全部/已下载，证明本样本暂停不产生失败类，未点击一个不存在的FAILED入口。37继续→38同页40/40，39final manifest为downloaded40/40；暂停前11个page records逐字段保留。
- 原始证据在`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260907-download-pause-feedback/qa/`，host/QA/review在同名run根。主控与独立review实际看关键原图/录屏；02→39原11manifest/Reader/registry及旧11queue/prefs保全，仅第40/33/32/28四章共155页正常新增，库只对应pages和章/漫画时间。39回普通书架；新页保留。
- 独立`review/result.json`批准仅5文件49增11删提交。批量混合暂停、runRetry及真实failed混合为host范围，不冒充197覆盖。顶部暂停汇总/总量仍省略，已实际看到并保留未修，不宣称下载管理整页UI通过；前3次执行失败不被本次通过覆盖。进入独立提交，不推送。
- **已提交68a70d9bf1156d1d6cb6315406247824f893df66**，仅上述5文件49增11删，index空、不推送。工作树源码内容提交前后不变，既有WIP及Index/ReaderLab实验完全排除。下一片任意选章的基线与方案开始于此独立提交之后。

## 39. DL001/CHP001任意选章（2026-09-08，实施中）

- `.hermes-artifacts/20260908-chapter-selection/implementation/design.md`明确最小方案：章节组件独占S，S始终取当前F交集；排序保留ID、筛选不操作隐藏章节。普通菜单保留原F五项及选择入口，选态只有S下载/标记两态、全选F、退出；确认显示所选数量，复用原执行链与数组快照。
- 当前197固定包14083781的同名raw分区qa01/02/05/06已由主控实际看图：221章、原F菜单、已下载00与未下载1191行、原长按菜单。QA07恢复原降序锚点，00→07共19 JSON字节一致。没有借基线操作阅读/标记/下载。
- 候选冻结为2源码+3locale共212增37删，原生Checkbox为正文区域兄弟，选态尾下载disabled保持36vp占位，状态badge/章节名称保留；普通态长按保持单章菜单，选态长按复用S菜单，标题滚出屏幕后仍可操作所选章节。不增加header或处理栏高度，不改滚动容器。Index/ReaderLab、shared及其他WIP排除；独立源码/host审查canBuild=true，尚不可提交。
- 唯一构建exit0，固定`chapter-selection-signed.hap`14121315bytes（2026-09-08 00:48:37+08），shared前后均21f90808cb32abbe5ed3fd7572a09a119078d584且clean，已立即归还窗口。197候选验收已派发，原15章428页保留；构建不算原生多选/布局验收。
- 197候选qa-after02→05与04连续录屏验证进入多选原位置换字、无新增纵向占位；51→53已下载双行同样保持header/行/badge的y边界。06–10原生Checkbox和正文各0→1→0、空S三动作禁用；12选1191/1189而非中间1190，跨旧80边界到747附近后15深处长按仍S2、16确认所选2。17–23返回、排序保留原ID，已读筛选S2→0，重置不复活旧选择。26/27确认读态数量2后取消，退出恢复原单章菜单，31原F仍221；00→32共19业务JSON字节一致。
- 实际S下载仅1191话13P及1189话14P：39是批量1/2过程，不称完成；41同一详情页两行已下载，未选1190仍箭头，42重复确认2/2/0。原15manifest不变，只新增两章27页且正常保留。46普通00行仍进Reader23/23，未翻页；OPM两章57同页已读灰字，59已读F保留S2，60→61正常标记未读后F空/S0，原读态还原，不直接写存储。
- 61空态底部重置只露上部，被主控/独立review明确留疑；66普通空态轻滚后该底部按钮完整可见，67实际点击恢复58/58，证明现有滚动内容可达，非固定裁切。未把普通态补证说成重演选择态，也不据此宣称详情全页风格通过。68普通书架收尾、21JSON供最终独立核对；未改网络、未删除任何下载，当前等待最终review及独立提交。
- **已提交9778d9c2b93d1bf4e0f6aecb4decbd698ba683b8**，仅5文件212增37删，主控全文核cached diff后放行，index空、52个脏工作树文件字节未变、不推送。QA与独立review最终通过本片：原15manifest/registry、原15queue项及偏好保全；新增2章27页，总17章455页。Reader原14条身份/位置/最终isRead不变，仅00正常重进三处更新时间及OPM两章正常标记更新时间变化。40录像起帧已完成，39→41是无导航的同页端点证据，不宣称录像捕获精确完成转换。63→68全部21业务JSON字节一致。

## 40. DL001跨漫画下载（2026-09-08，已授权实施）

- 第39节独立提交后接续。`20260908-chapter-selection/source-next.md`定向核实：Library已有漫画选择但没有下载event，Index无对应接线；详情批量仍单本页面循环，不能当持久跨漫画队列。现QueueStore按comicId+chapterId持久存储，Downloads现执行器已经逐entry取得不同漫画，可复用，不另造下载服务或调度框架。
- 已非阻塞询问“下载未读/下载全部，按各本当前已取得目录确认数量后加入现队列，不隐式刷新远端目录”与刷新目录方案的选择；当前不改可见菜单。Index/ReaderLab所属任务已明确停止写入并冻结实验边界，仅允许未来LibraryPage事件接线必要hunk，构建窗口仍须另行协调。197当前固定14121315包普通书架、17章455页；下一步只读书架菜单基线和最小接线方案。
- 用户随后明确“就按你的建议来”，正式采用当前已取得目录范围。新run `20260908-library-batch-download` 的qa-before02主控实际看选2本后的原溢出菜单，确无下载入口；00→03全21业务JSON字节相同。实施限定原选态溢出两项、数量确认、新目标持久入队及原下载管理接线，不隐式刷新目录、不重置既有任务或暂停偏好、不增加外露按钮/处理栏。2026-09-08上午续接须重新设备门禁，旧02:38租约不视为当前有效。
- 候选冻结7文件246增1删：Library选态原菜单追加下载未读/全部，Index仅3行原下载页接线，新增范围准备器复核当前目录和已有任务，QueueStore最小批量新增接口单次持久保存，三语言数量确认。独立源码/实际方法host审查canBuild=true、canCommit=false；不自动开始/恢复队列，不覆盖既有任务。共享负责人已明确放行clean3925f45d069f53b9a7b6050384e889e04882b70d的一次构建及固定复制窗口，目前构建中，尚无候选197验收。
- QA上午新租约20260908-002516-4b087ee2完成Connected/AWAKE门禁，正常收藏虫女9页、虫虫村6页作为两本两章真实样本，未下载。原10本库对象保持，另20业务JSON字节相同；新样本正常保留。旧包最近加入首屏只看到虫女而虫虫村已存库，记录为未诊断可见性疑点，不冒充已修；候选需实际核实两本选择链路。证据与准备计划在本run的qa-plan及同名197分区。
- 一次构建exit0，fixed `library-batch-download-signed.hap`14154031bytes/08:46:59，shared前后均上述clean完整HEAD，窗口已立即返还。197 qa-after01主控实际看新包普通书架，两样本可见；这仅证明重启后可达，不关闭旧包收藏即时回显疑点。候选批量路径仍在验收，未暂存提交。
- 补记 **LIB-011 / S3·P2 / 筛选计数语义**：qa-plan15筛选全All、qa-after01最近加入却显示“筛选·1”；源码`LibraryPage.activeFilterCount()`将非lastRead排序计入筛选数。此原因明确，不是隐藏筛选，不能解释前述收藏回显疑点。待本片独立提交后最小修正计数并验证排序与筛选分离，不混入当前已冻结候选。
- 候选一04原选态菜单旧三项bounds与基线相同，两下载项追加；05/06原生确认数量2本2章/新增2且手动开始说明完整可读，双取消00→07全21业务JSON字节不变。08早采样仍选2且无新queue，曾被报为未入队；09录像任何输入前首帧已管理页19章/2等待，10实际queue有两个queued0/9、0/6，纠正为异步已完成，不是再次点击才成功。09却沿旧Library预设坐标误进虫女详情，保留协议偏离；未进入Reader或下载，不能计作合格重试。metadata旧build字段与codeIdentity冲突须在结果补勘误，不改原件。
- 08确认click08:55:32.388–32.782，08图约7秒后仍无明显忙碌提示；queue新updatedAt08:56:18.680/681，跨host/device墙钟相减约46秒，未校时/无全段录像，不宣称精确全程等待量测。实现确实await既有queue初始化，host使用替身不能证明原生worker时长。**不因最终成功忽略实际静默等待，尚不提交**；候选二最小补既有标题位置“正在入队”，busy沿原owner/finally恢复，不增加纵向占位、不绕初始化/改调度，Index仅额外标题必要hunk，实验保留。
- 11正常Back管理仍两等待，12手动开始同页虫女9/9、虫虫村0/6下载中，13无输入同页两章完成，总19章470页；主控实际看12/13整图。新增15页保留；剩余重复确认/数据保全及候选二反馈验证继续，不额外下载大批或用删除重下制造样本。
- 候选一15重复确认2/2/新增0、16普通书架，13→16全部23业务JSON字节同；原17manifest/Reader/registry字节同、旧17queue项/prefs保持、原10本库对象同，只本次两章hydration与时间变化。候选二冻结7文件256增1删并独立canBuild，新增原位短标题和准确“开始下载”/“继续队列”指引；仍未提交。
- 补验唯一第三样本虫笼`com.dm5.koma:manga:manhua-chonglong`，章`chapter:manhua-chonglong:749312:16`，16页；正常收藏已获批准，不继续搜更小样本。qa-after19确认queue无该ID且下载目录无8c33710a5a81adf4，20普通书架，未下载。其收藏后仍未即时出现在最近加入首屏，再次记录 **LIB-012 / 严重度待定·P1 / 收藏回显**：数据持久保存但当前投影未显示，原因待查；不能用随后安装重启后的显示关闭它。本片验收提交后优先定向核实此正常高频链路，再处理LIB011计数，不重复整项目审查。
- 候选二fixed `candidate-two/library-batch-download-feedback-signed.hap`14153788bytes/09:16:09，shared3925f45d前后clean、构建窗口已归还。qa-feedback00→01安装前后23业务JSON全同；02主控实际看“最近加入”标题与旧顺序网格矛盾，正常下滚03找到虫笼，不切排序/布局、不借重启当修复。新租约已正常续至10:21:53。
- qa-feedback06连续60秒录屏实际单次确认，frame24@0.484911和136@48.038主控实际view“正在入队”持续在原标题位、网格锚点保持；独立review看全6sheet/198帧，137@48.409进入管理，07虫笼0/16等待，未自动下载。长初始化性能未改，不宣称变快；退出多选仍显示busy、异常finally恢复为host范围，本次没有额外原生退出多选动作。
- 虫笼手动执行后09实际为**受阻0/0，source_pages_failed**，不是16页完成。选择→入队→manifest漫画/章节ID完全一致；原Hydrator的catch统一码不能断言空数组、上游删除或具体异常原因。root/review实际看09失败整图，不换样本/重试/删除；到09原19manifest/库/Reader/registry共22文件字节同，旧19queue/schema/prefs同。当前总20任务、19章完成470页、1章受阻0页；候选一两漫画15页成功闭环与本候选反馈证据分开保留，最终恢复/保全后限定提交审查。
- qa-feedback11普通书架标题恢复，00→11原19manifest/库/Reader/registry字节同、旧19queue/schema/prefs同；只新增虫笼受阻0页。有界13日志仅get_pages后通用source_pages_failed，没有具体异常；10无有效采集窗口、12shell管道误解释的无效日志尝试保留，不作证据。录像末忙碌精确帧修正为138@49.066967，139@49.266144恢复标题并转管理，之前137估计作废。主控实际看24/136/11，独立review另看138/139全部6sheet并重算保全，`review/final-result.json`仅允许7文件256增1删提交，不含16页成功或完整下载领域/UI通过。暂存集成中，不推送。
- **已独立提交ce384c0a7ca5dbcf515f7a242af25658860d5fa9**，仅7文件256增1删；主控全文读取实际cached diff/check/name-list后放行，index空，52个工作树源码/WIP路径提交前后字节相同。Index实验205增14删、Library6增2删、各locale14增3删及其他WIP保留，不推送。下一片LIB012，不把新取页受阻样本或初始化49秒性能问题悄悄算已修。

## 41. LIB012书架网格实时投影（2026-09-08，定向修复准备）

- 新run `20260908-library-grid-live-projection`，基线ce384c0a/固定14153788包。此项优先于LIB011纯计数：正常收藏后找不到新书、排序文字与内容不一致直接影响收藏→找书→详情链路。复用第40节两次收藏及冷启动feedback02原证据，不再全面重审或用重启当修复。
- 已读生产链：详情持久收藏→Index替换libraryComics/revision→Library刷新displayedComics回调存在；GridEven/Odd→Grid按值数组、稳定rowIndex子树和cell按值对象形成旧快照风险，奇偶同时被本地递增与父revision覆盖，不能保证每次更新重建。该机制是源码候选，未采到原生内部revision值，不声称运行栈已经证明。
- NextE当前Favcat使用明确dataSource变更通知，3d03747历史只把Koma列表改为直接读owner，未覆盖网格。华为官方FAQ `https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-arkui-1546`说明ForEach同key复用和Builder值传递刷新限制；主控知识MCP查询返回400后用官方站核实，不引用社区推测。
- 本片冻结卡片几何、列数/间距、Checkbox/手势/菜单/标题、新下载逻辑；不改Index/shared/Reader，不加版本到key、不复制NextE全套数据框架。修正须贯通当前owner→网格行→同ID卡片字段，不能只删外层奇偶而引入进度陈旧回归。先最小方案与同进程grid/list/排序基线，再候选/197收藏回显及原行为回归；不混LIB011。
- 新鲜qa-before01/03/04原图经主控及独立评审实际查看：同为最近加入，保留网格首行ONE PIECE/恶女/Local，列表为虫笼/虫虫村/虫女，重建网格后才与列表一致。09已恢复原网格/排序，00→09全部24业务JSON字节一致；13本、19完成470页、虫笼受阻0页保持。
- 知识MCP已修正请求封装并成功取得Builder/Computed/Repeat官方文档，保存本run official/。非虚拟Repeat同key不刷新，已在生产修改前否决该替换方案；最终design.md为原ForEach/keys + 单Computed投影和ID查找 + 各层单literal引用参数。主控完整读设计、独立评审无设计阻断，已放行仅LibraryPage实现；尚未构建或设备验收。
- 候选已冻结为单页73增55删，原三处inset WIP6增2删排除；主控全文读scoped差异，独立review canBuild，实际方法检查118原方法不变且几何/手势归一化相同。唯一assemble exit0，固定`candidate/library-grid-live-projection-signed.hap`14157925字节/10:04:43+08；共享reader-kit前后3925f45d干净并已明确归还窗口。197当前包验收进行中，尚未放行提交；核心正常收藏→原书架即时回显不得由冷启或切换布局替代。
- qa-after01新包冷入口直接正确；04连续收藏《书虫》→原路返回→书架05首位即时出现，未切布局/排序/重启。主控实际看01/05及04第五sheet，独立review全部216帧/6sheet与148/155原帧：148切tab中间帧标题尚Browse，155稳定正确，不把动画误作布局故障。01→05其余23文件字节一致，原13漫画对象相同，只新增书虫。
- 主控及review实际看07/08：书虫+虫笼两本选中，改标题排序并滚动后仍同两本、没有位置串选。10原恶女卡片17%，14Reader7/35→15详情7/35→16同位置网格20%，主控实际对看10/16。原位同ID更新已观察，待自然回6及收尾数据；17继续阅读卡主体/20%更新，但长空白章节名导致副文页码省略，不声称章页文字可见通过。
- qa-after19自然回Reader6/35，21网格恢复17%（主控实际看）、22详情6/35，23普通网格/最近加入。24旧业务JSON中22逐字相同；library原13对象不变，仅正常新增书虫8章；Reader只恶女目标3处updatedAt变化，pageIndex仍5/35且未完成，其他读态完整保全。14立即持久文件尚为pageIndex5，不能拿它证明7；7由Reader/详情/网格20%/18续读重新进入7的可见链证明。QA result限域通过，尚待独立最终评审与暂存检查，不外推全部UI或持久化实时性通过。
- 独立review/final-result.json canCommit，主控完整读取实际cached diff/check/names后已提交`de959210829fec70c2ec1709dc6fa873033a1bc5`，仅Library73增55删。index空，原inset6增2删及66个其他源码/WIP快照不变（主控状态文档更新另计），不推送。LIB012仅当前正常链关闭，不含继续阅读卡文字、LIB011或整个Reader/下载领域。

## 42. LIB011排序与筛选计数分离（2026-09-08，实施中）

- 新run `20260908-library-filter-count`，基线de959210/固定14157925包。前片23最近加入显示筛选1、before08五类过滤均All；主控确认activeFilterCount首行按非lastRead排序计1，误报已启用筛选。
- 只将计数初始值归零，保留五类真实过滤条件、排序/筛选操作和所有可见几何；不混清除行为或继续阅读卡。host抽真实方法覆盖排序×过滤组合，197核All下两种排序无计数、真实一项/两项为1/2，恢复原All/最近加入，不收藏/阅读/下载。尚未构建验收或提交。
- 唯一构建exit0，固定14157982字节/10:33:11+08，reader-kit前后3925f45d干净并归还窗口。197后验01/03/04最近加入/标题/最近阅读All无计数，07/08 DM5一项1，10/11再加未读2，12五All归零。原Reset同时重置排序，13计划文件名不符实际最近阅读，原件保留后14正常恢复最近加入。主控实际看before01与after01/08/11/14，独立review另外核sheet，计数仅自然宽度变化、纵坐标及首排不变。
- 本批24业务JSON安装前后及收尾均逐字一致。主控完整读QA/review-final/实际cached/check/names后已独立提交`c6d2e793058b5b44af8e2ddf2ad5ec11252cad8e`，仅1增1删、index空、原inset及其他WIP保留，不推送。128宿主组合只是方法检查；原生验收范围为上述0/1/2/恢复，不扩大整个筛选UI。

## 43. 下载初始化等待（2026-09-08，最小优化实施）

- 新run `20260908-download-queue-initialization-latency`，基线c6d2e793/固定14157982包。目标来自第40节实际入队46–49秒等待，不是低概率防御或新架构项目。当前不编辑、不构建、不新增下载。
- 主控读取可达链：LibraryBatchDownloadQueue.enqueue等待ensureQueueInitialized，taskpool内reconcileWithManifests遍历旧下载，reconcileDownloadedChapter默认validateDownloadedChapter逐页整文件读取并执行ArkTS双hash循环。Runtime每进程/filesDir缓存初始化Promise；挪到taskpool不消除入队await。该链支持与旧下载字节规模相关的耗时机制候选，尚无分段计时，不声称49秒全部已归因hash。
- 197仅计划当前进程首次正常打开下载管理的有界初始化时序和前后数据比较，不入队/执行/重试/删除或断网；若没有可见初始化结束点则如实报告，不靠片段猜耗时。先核现有轻重校验调用边界再决定最小修复，不直接删校验冒称提速。
- source-review.md按当前已存manifest统计19完成470页/248263553字节、470均有hash；这是记录规模，不是物理文件独立测量。独立review/boundary.md同意最小三模型透传现有ValidationOptions，只initializer传false，Store4处复验一致，保留默认全校验、显式恢复scan、下载复用/新写hash/现有Reader策略与初始化await。普通Reader多处本就false，不宣传所有Reader全hash。
- 已向用户说明取舍：startup不再自动发现同尺寸内容损坏，显式完整校验和下载复用路径保持；缺页/大小/路径/manifest及中断任务恢复仍在。主控完整读两报告后放行此三模型最小实施，尚无新构建/提速验收/提交。当前197补充录像仍是固定14157982旧校验包，不与候选混淆。
- 旧包首次管理03连续录像：首管理画面10@0.283011，169@47.364078菜单仍灰、170@48.004756变黑可用，无菜单项执行；可见入口到可用约47.1–47.7秒，不是hash CPU时间。主控及独立review看关键原帧，QA24业务JSON起末全相同。
- 候选冻结3模型15增11删，实际方法host证实startup零图片字节读取、默认同尺寸损坏检出、原缺页/尺寸/中断恢复保持，47个非目标方法逐字相同；独立canBuild。唯一assemble exit0，固定`candidate/download-queue-initialization-signed.hap`14157835字节/11:03:34+08，reader-kit前后3925f45d干净且窗口已归还，尚未提交。
- 用户提醒把注意力放整体/对标高频体验，主控一度错误解释为冻结当前优化；用户随后明确“不是阻止解决真正问题，有问题当前必须解决”。因此继续本片当前包197同470页验收→独立提交，不扩展下载防御；完成后回到连续阅读/追更的现存功能缺口，不以新一轮全面审查替代交付。
- 候选197首次管理短录像qa-after04：9@0.282833首次管理画面，93@2.184256菜单稳定可用，入口到可用上界1.901423秒；80为透明度动画，不当禁用状态。主控实际看93及05菜单整图，独立review核关键帧/联系表，QA全122帧/4sheet。只证明首次管理初始化可见等待下降，不宣称新入队精确耗时或hash CPU时间。旧qa00→after00→after01→after06共24业务JSON逐字相同，最终普通书架，14本、19完成470页、虫笼受阻0页不变；无新下载/重试/扫描/阅读/网络操作。
- **已独立提交4f4bd846a06de906df00c58992a5e9e16b184801**，仅3模型15增11删。主控全文读取实际cached diff/check/names后放行，index空，其他WIP保留，不推送。此片闭合后回到第24节RDR004，不继续扩展下载防御。
- 2026-09-08接续源码核实：Reader的nextPage仍仅在本章推进，nextChapter仍按sessionConfig.chapterIds相邻项；库存会话直接采用comic.chapters顺序，临时源会话仅当前章。当前DM5生产者仍以first_number(title)写章号，Komiic仍以scanlator存连载/单行本标签。因此第24节前置问题未被近期提交消除；历史197章序证据保持历史标注，本次未冒称已重新走完真机连读。

## 44. RDR-004-B章末自动衔接（2026-09-09，限域验收并提交e8817da5）

- 实现仅四文件。`ReaderChapterSequence.ets` 新增 `ReaderChapterOpenIntent`（'resume'|'start'|'end'）与 `automaticContinuationChapterIds(ids,currentId)`（ids undefined／长度≤1／当前章不在表内一律返回 undefined，绝不复用 `continuationChapterIds` 的 `?? chapterIds` legacy 回退）；`ReaderSessionStore.ets` 新增 `openPageIndex(config,intent)`（start→0，end→totalPages>0?totalPages-1:0，resume→restorePageIndex），无 config 字段、无 schema/备份变更；`Index.ets` 一次性运行时 open intent 贯穿 openReader/openSourceReader 与六个打开链发布点，绑定透传 intent 并新增 `initialScrollAlign`；`ReaderPage.ets` 边界派发（tap zone＋音量键＋连续滚动），跨界顺序恒为 `persistCurrentProgress()` → `onOpenChapter(邻居,'start'|'end')`，原 `nextPage()/previousPage()` 未改，故 `scheduleAutoPage` 仍停在章末。
- 主控复核发现并修复一个硬错误：`ReaderSessionStore.ets:434` 用了 `ReaderChapterOpenIntent`，而第 3 行只导入 `continuationChapterIds`。真实 tsc 证据 `ReaderSessionStore.ts(434,54): error TS2304: Cannot find name 'ReaderChapterOpenIntent'`，该状态构建必挂。子代理自测脚本走 `ts.transpileModule`（类型被擦除），结构上看不见；其“模型文件 tsc 0 诊断”的说法不成立。修复为在第 3 行补类型导入，复验该符号 0 诊断。
- 构建基座纠错（重要）：记录中的 `f4d023fc`（2026-09-08，称“当前已装197包的基座”）对本工作区**无效**——51 个 ArkTS 错误，首条 `Module '"@reader-kit/core"' has no exported member 'ReaderObservedPosition'`（`entry/src/main/ets/pages/Index.ets:4:10`）。`b5fa389`（含其 11 个脏文件）**过新**：2026-09-15 `2fc84cd` 把 `ReaderSurface` 的 `@Param hostActions` 由 `ReaderHostAction[]` 改为 `ReaderHostActions`，而 `entry/src/main/ets/readerLab/KomaReaderLabPage.ets` 是 HEAD 未改文件（2026-09-14 15:36，且 Koma HEAD 本身从未构建过），必然报 `Type 'ReaderHostAction[]' is missing…`。正确基座 `638353d`（2026-09-14 20:13:34）。另记两个必需环境变量：`DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk`（否则立即 `00303217 Configuration Error`）与 `JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home`（否则 `@PackageHap` 报 `00308018 Unable to locate a Java Runtime`；注意这发生在 ArkTS 编译成功**之后**，故“编译干净/打包失败”是真实可分的两种状态）。两次 reader-kit 窗口均按 11 文件 sha256 逐字节还原。
- 197 验收（四种翻页模式 × 两个方向，同一样本 A=01話39P／B=02話19P／C=03話15P）：单页 后翻 B页1→A `39/39`、前翻 A末页→B `1/19`；连续滚动 B顶→A `38/39`、A末页→B `1/19`；双页 C跨页1→B `19/19`、B末跨页→C `1/15`；纵向分页 C页1→B `19/19`、B `19/19`→C `1/15`。各模式章内翻页全程不跨界。无邻章漫画（虫女，DM5 1章9P）两端均不跨界、不崩。`library-store.v1.json` 前后逐字节相同。
- 真实样本纠正：A(`kic-ch:49743`) 与 B(`kic-ch:49744`) 在库存列表里**并不相邻**，中间夹 `kic-ch:143028`（01卷178P，`readingGroup=book`）。界面显示 A=`章节 1/178`、B=`章节 3/178`，而两次跨界都直接跳过该卷条目，证明走的是派生 chapter 组邻章表（177 条）而不是数组下标 ±1。原 `qa-before/prepared-plan.md` 的相邻性假设不准，已按实测更正。
- 设备发现并修复一个真实缺陷：连续滚动模式下前翻跨界落在邻章**末尾**（`18/19`）而非首格。成因是连续界面 `List({ initialIndex: this.pageIndex, scroller: this.listScroller })`（`ReaderPage.ets:3409`）的 `initialIndex` **只在首次挂载生效**，切章复用 List 节点、scroller 保留上一章的像素偏移，较长的上一章把较短的邻章钳到自身末尾；`'end'` 方向本来就显式调 `scrollToIndex(...,ScrollAlign.END)`，所以只有 `'start'` 这一半失效。第一次修（80ms 单次 scrollToIndex，守卫 `pageIndex===0`）真机复测仍 `18/19`——被新章的异步测量覆盖，且旧章 `onScrollIndex` 会在定时器前改掉 pageIndex。第二次改为闩锁 `continuousInitialTarget=0` ＋ 80/240/480ms 重试 ＋ 800ms 强制释放闩锁，真机复验 `1/19`；并做了前向边界回归（B `1/19` 下走到底仍能跨到 03話 `1/15`）。注意该闩锁会抑制 `isLastReadingUnitVisibleAndLoaded()` 的前向边界，所以释放期限是必需的，不是防御性冗余。
- 未覆盖（不得写成通过）：LTR/RTL 轴（当前构建 `/设置 → 阅读` 的 `阅读方向` 行点标签与值都无响应，无法切换）、拆宽页（`宽图模式=拆分宽页` 未跑）、真机 zoom 态（双击未触发缩放）、加载中与源不可用占位路径、虫笼/虫虫村/拆宽图夹具/私库类目、autoPage 跨章、滑出手势跨界、连续拖拽越底（`onReachEnd` 未接线）、`queue.v1.json` 与 `source-runtime-registry.json` 的字节对比、以及渲染图本身的视觉判读（只读了页码、chrome 与 layout 节点几何）。
- 已独立提交 `e8817da5`，仅 4 文件 +232/-26、不推送。`Index.ets` 与另一任务 WIP 混在同几个函数内，故用 `git hash-object -w` ＋ `git update-index --cacheinfo` 只把本切片的重构版写入索引提交：工作区文件 sha256 前后一致，其余 252 行 WIP 原样留在工作区。重构版与真机验证那份逐行对比，切片相关差异只剩一处缩进。
- 证据：`.hermes-artifacts/20260909-rdr004b-chapter-edge/`（`design.md`、`implementation/review-lead.md`、`implementation/build-window.md`、`result.json`）与 `.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260909-rdr004b-chapter-edge/qa-after/acceptance.md`。
- 下一项（主控自行排序）：LIB-007 列表行尾部菜单/进度重叠（`.hermes-artifacts/20260906-lib007-row-menu`），以及 MangaDex 已复现的旧 feed 章号去重＋远端替换链（`20260908-mangadex-chapter-identity/implementation/mangadex-observed-replacement.md`，不得跨 UUID 迁进度）。

## 45. RDR-005单本模式/方向覆盖（2026-09-22，限域验收并提交4e9e16b0）

- 问题：`ReaderPreferencesStore.loadForComic/saveForComic` 收下 comicId 却忽略它，读写都是共享全局默认；于是「在某一本里翻页模式」实际上改的是全局，换一本也跟着变。与 Aidoku `ReaderSettingsView:47` 的单本覆盖语义不符。
- 方案：新增**窄**覆盖层，只承载 `pageMode` 与 `readingDirection` 两个字段，落在独立键 `reader.seriesModeOverrides.v1`，**与**全局值并存而非取代。刻意不复用旧的整份快照键 `reader.seriesOverrides.v1`（该键仍可读、运行时不消费；设备上它至今只存着一条 MangaDex 记录的 23 字段全量快照）。
- 改动（7 文件，+231/-14）：`model/ReaderPreferencesStore.ets`（`SERIES_MODE_OVERRIDES_KEY`、`interface ReaderSeriesModeOverride`、`normalizeReaderSeriesModeOverrides()`、`applyReaderSeriesModeOverride()`，重写 `loadForComic()`/`saveForComic()`，新增 `seriesModeOverride()`/`clearSeriesOverride()` 与私有 `readSeriesModeOverrides()`/`writeSeriesModeOverride()`/`writeSeriesModeOverrides()`/`clearSeriesModeOverride()`）；`pages/ReaderPage.ets`（`@Local seriesOverrideActive`、`resetSeriesOverride()`、透传）；`components/ReaderChrome.ets`、`components/ReaderSettingsContent.ets`（`seriesOverrideBadge()`、模式行与方向行加徽标、两个菜单末尾在覆盖存在时追加 `恢复默认`）；三语 `string.json` 各 +2 键。
- **host 检查抓到的真实缺陷**：第一版 `saveForComic()` 先 `save(preferences)` 再写覆盖，等于把这本书的模式**同时写成全局默认**——后果是「恢复默认」恢复到的正是刚设的值（等于没恢复），而且改一本会带跑其他所有书。`.hermes-artifacts/20260909-rdr005-series-preferences/implementation/check-series.cjs` 在桩化后端上跑真实方法时断言 `comicB keeps the global mode` 失败即由此暴露。改为：先取当前全局，把全局的 mode/direction 原样写回（其余字段照用户改动），再按用户选择写/清覆盖；两者相等时删除覆盖（因此只改背景不会留下假的 `本书` 徽标）。修后该检查 9 项行为全过（normalizer 只收两个字段并丢弃空 id/坏类型/坏 JSON、applier 字段隔离、全局默认不被带跑、A/B 互不影响、第三本不干扰、改全局只动未覆盖的书、清除为幂等）。
- 实机验收（197 ALN-AL80，HAP sha256 `a3da9b8340c952969368b5a724b83acadfd34a61d34d32bc1f25da40cc3375d9`，reader-kit 干净窗口 `638353d`）：
  - **录屏协议**（用户要求动态场景走录屏）：`.hermes-artifacts/device197__ALN-AL80/not-applicable/portrait-1260x2720/20260909-rdr005-series-preferences/recording/run-001/`，一次连续录制 173 帧/8.5s，`frame_000110` 显示面板 `模式 = 双页 · 本书` 且菜单末项为 `恢复默认`，`frame_000130` 显示点击后 `模式 = 纵向分页`、`阅读方向 = 从左到右`，`本书` 后缀消失。
  - **文件层同期取证**（这次的关键手段）：`haps/entry/preferences/koma_reader_preferences_v1` 里覆盖键从 `{"com.komiic.koma:kic:1936":{"pageMode":"double_page","readingDirection":"left_to_right"}}` 变为 `{}`，而全局 `reader.pageMode` 全程保持 `vertical_page` 未被带跑。
  - **A/B 与冷启动**：同一本设 `双页` 后冷启动仍是 `双页 · 本书`（layout 两个并排 Image 节点 + 面板徽标 + 覆盖键仍在）；另一本（虫女）无徽标、仍是全局 `纵向分页`。
  - 持久化影响：`library-store.v1.json`、`reader-progress.v1.json` sha256 未变；`reader-sessions.v1.json` 只有 1936 那条进度记录随导航变化，记录数 13→13。
- 未覆盖（不得写成通过）：真机 `阅读方向` 行仍无法切换（与前几节一致，`/设置 → 阅读` 的该行点标签与值都无响应，所以本次只验证了「方向行显示徽标」与「方向菜单里有 `恢复默认`」，**没有**验证切换方向后的跨本差异）；覆盖键的跨设备迁移/备份恢复路径；旧整份快照键的清理；双页拆页与缩放态下的面板行为；非 197 设备。
- 验收方式的一次方法论纠正：本次前期把底部模式按钮误当成设置面板，导致误判「徽标没生效」。真正的入口是阅读器头部齿轮（约 `1006,214`）。后续同页面操作应先按 `ReaderChrome.ets` 的 `bindSheet` 归属确认入口，再下结论。
- 未推送。`Index.ets` 依然保留另一任务 WIP 未提交；三语 `string.json` 在本切片提交版里只含本切片那 2 个键（工作区里另约 15 个键属其他任务 WIP，通过 `git hash-object -w` ＋ `git update-index --cacheinfo` 只提交本切片版本，工作区文件未改动）。
- 下一项（主控自行排序）：MangaDex 已复现的旧 feed 章号去重＋远端替换链（`20260908-mangadex-chapter-identity/implementation/mangadex-observed-replacement.md`，不得跨 UUID 迁进度）；虫笼取页报错；继续阅读卡长章节名可读性。

# 开发文档修订前归档

仅供明确历史查证使用，不属于 Agent 默认阅读资料。下列内容来自整理前的已提交版本；当前有效规则维护在原文件。

## AGENTS.md

```markdown
## 强制约束：未经用户明确允许，禁止创建工作树

- 默认在项目原主仓目录工作。创建任何 Git 工作树前必须取得用户明确允许，并遵守该允许限定的项目、用途和范围；没有明确允许，一律不得创建。
- 本约束适用于命令行、工具托管、临时路径和所有子代理；不得通过派工规避，也不得把旧计划、自动唤醒、代理建议或已有工作树当作新增许可。
- “保护 WIP”“并行开发”“隔离验证”“方便打包”等理由不构成允许。不得通过复制项目源码或额外克隆开发副本规避本约束；应在原主仓审查、整理并及时提交有效改动。
- 已获允许的工作树只用于获准范围；完成后及时将有效成果合回原主仓并退出工作树，未经新的明确允许不得扩展用途或长期保留为另一条开发主线。

# Koma agent entry

**未经用户明确允许，禁止更改样式；修 bug 也不例外。**

先读 [执行规则](docs/agent-guides/koma-rules.md)，然后只读当前工作需要的资料。

强制先读其中“禁止编造记忆与无依据确认”；每次开始、压缩或交接后，以及回应纠正、历史要求或既定决定前再次阅读，不得用当前纠正冒充历史记忆。

| 工作 | 资料 |
| --- | --- |
| 首版 App 与中文源开发 | [唯一当前工作单](docs/CURRENT_STATUS.md) |
| 共享 Reader | [共同职责](../reader-kit/README.md#consumer-contract)、当前跨宿主工作单、[参考规则](docs/agent-guides/reader-rewrite-standards.md) |
| 产品设计 | [产品计划](docs/PRODUCT_PLAN.md)、[路线图](docs/ROADMAP.md)、[能力参考](docs/FEATURE_COMPARISON_AIDOKU_MIHON.md) |
| 书源 | [运行方向](docs/WASM_SOURCE_RUNTIME_DIRECTION.md)、[ABI](docs/source-runtime-abi.md) |
| 本地证据 | [产物目录](docs/CONTROLLER_ARTIFACTS.md) |

用户最新请求决定范围；暂停时停止冲突操作。旧路线图、[历史违规记录](docs/agent-guides/reader-rewrite-violation-log.md)和历史工作单只用于查证，不自动恢复旧任务或重复验收。
```

## docs/agent-guides/koma-rules.md

```markdown
# Koma 执行规则

## 强制先读：禁止编造记忆与无依据确认

- 每次开始、压缩或交接后，以及回应用户纠正、历史要求或既定决定前，必须先读本节。
- 严禁编造、补齐或冒充记忆。用户当前的纠正可作为当前指令执行，但必须如实说明信息来自当前纠正，不能说成自己记得、早已知道或已经独立核实的历史。
- 只有当前可见原文或实际查证的原始记录支持时，才能声称“你之前要求过”“我记得”“已经确认”。摘要、交接、记忆页、工作单和当前实现只能提供线索，不能冒充原始对话或查证结果；日期、原话、因果和授权范围均不得猜补。
- 不知道就明确说不知道，未查证就明确说未查证。禁止为了附和、安抚或表现得记住了而使用无依据的确定语气；发现先前无依据确认，必须撤回并澄清真实信息来源，不能继续把它写成历史事实。
- 用户禁止查询时立即遵守，不检索、不凭空补造答案。仅回答当前已知内容，不能把“不许查”变成虚构记忆的理由。
- 修改既有界面、组件或参数前，必须先查组件及受影响调用方的修改历史：读取当前未提交差异，按文件和符号执行适用的 `git log --follow`、`git log -S/-G`，并用 `git show` 或 `git blame` 定位引入、调整、撤销该行为的记录；再核对原始用户要求、相关调查分析、决策取代关系、验收和已拒绝方案。不能只读当前数值或公共组件默认值就提出修改。
- Git 历史不覆盖全部开发决策。未提交 WIP、归档记录及原始对话中的有效决定同样必须核对；未提交、压缩、交接或归档都不使决定失效。未查清来源就明确未知并保留现状，不能把查不到当成可以重做。
- 界面评估先证明具体用户任务或使用状态存在问题，再决定是否改动及选用组件。不同于默认值、使用自绘组合、与其他页不相同，均不能单独证明缺陷；禁止为统一模板或参数反复重做已定设计。
- 既定决定只因用户明确改变要求、新的实际反例或具体依赖变化重新审议；必须说明新证据及原决定的理由为何不再成立。拟改动前留下“修改对象/历史来源/原理由/本次重开依据/允许差异”的可查记录；缺依据不得反向立项、修改或交给代理。
- 请求批准不能代替调查与方案责任。向用户提交候选前必须完成上述追溯，主动说明与既定决定的冲突；不得拿小 diff、组件默认值、笼统“规范”或用户点过批准作为无依据方案的免责理由。

## 不得擅改

**未经用户明确允许，禁止更改样式；修 bug 也不例外。**

- 修复保留原功能、样式和操作；不能靠删除功能、换效果或绕过故障使现象消失。
- 临时测试结束后恢复临时代码和设备设置；不得擅自保留改动。
- 默认设备测试、持续工作、用户未反对、官方 API 或测试通过，都不授权更改样式。
- 改错立即停止错误方向，撤回本轮改动，保留失败证据。原问题没有解决就仍未完成。

## 任务与实现

- 用户最新明确请求优先于旧计划、摘要、记忆和自动任务；暂停后停止冲突操作。
- [当前工作单](../CURRENT_STATUS.md) 是首版 App/中文源唯一队列；共享 Reader 用当前跨宿主工作单。旧路线图不派工。
- 已有授权持续有效。回应问题、纠正、压缩和工具失败不清空未取消目标；前置工作完成后继续下一安全动作。
- 一个分支缺条件只限制该分支；等待写明具体条件，其他已授权 App/源工作继续。
- 修改前按拟动文件、组件和符号追Git历史及当前WIP，核对原始要求、调查、已接受/被取代决定和已拒方案，再追所有者、写入/失效、异步回调、父级/相邻状态、消费者和旧版路径。当前决策来源放在CURRENT_STATUS对应项；历史归档中的有效决定不因“不派工”而失效。
- 原因未知写未知。不加延时、持久状态注入、抢窗口或参数试错制造通过；只针对有证据的错误修改。
- 漫画160普通网页的鸿蒙识别兼容只属于当前 Web 实例：初始地址须为已核的 www/m 两个 HTTPS origin、无验证会话，且默认 UA 同时含 OpenHarmony/Mobile、没有 Android/iOS 标识，才在保留全部字段后追加 Android 标记。依据与原详情实测保留在 CURRENT_STATUS 的 SOURCE_WEB_SESSION；不扩大到全局 UA、源 HTTP、验证 sheet、缩放或导航拦截。站点两端都已正确识别 OpenHarmony 的新证据出现后才重新审议此兼容，不能因通用封装重构丢掉或全局套用。
- 统一搜索遇到源明确返回的验证/登录要求时，按源独立认领，并串行复用现有验证半模态；其它源继续返回结果。依据为 CURRENT_STATUS 的 SOURCE_WEB_SESSION 中本轮人类要求。通过后只重试该源原请求一次；关闭、再次挑战、切换查询/筛选或离开页面不得循环弹出或重放旧请求。源包身份、设置版本及当前页面共同决定回调是否有效；保留单源验证的 Cookie/权限/UA 和样式边界。原生验证得到的单次响应只由精确匹配的原请求消费，无关并发请求不能清走；取消对应会话时仍清理它。站点验证后跳到同源其它地址404、但已有明确 clearance 时，可在原认领仍有效时探测原GET一次；404与Cookie都不能直接授予成功，只有原GET真实2xx且无挑战才能回流，失败保留手动操作。原地址的主请求错误、其它错误和跨源地址仍保持原拦截边界；依据为该原项197599–605网页404而原请求200的反例。不得因全量搜索汇总迟到覆盖已验证源的新结果。
- UI内存状态键须遵守AppStorageV2平台字符约束，并与持久偏好键分开核对。语言状态的具体边界见 `state/LanguageState.ets` 旁注及 `i18n/LanguageSettings.ets`：消除连接开销不能删除locale响应式依赖、改语言偏好或破坏启动恢复。
- 已安装源的展示排序须保留原本地化名称、比较器、同名ID顺序和DTO身份；本轮排序内可先逐源解析名称，不能在每次比较中重复校验元数据，也不能把名称缓存跨locale或源变更保留。Browse模型刷新时，仅完整展示DTO值相等才复用本模型的原行对象，仍发布新有序数组；字段改变、移除和失败恢复沿原合同，请求及源包有效性继续读实时Registry，不由展示对象决定。当前安装卡顿的实测范围以CURRENT_STATUS的SOURCE_PACKAGE_INSTALL_UI_STALL为准，减少重复解析或行输入重建不等于已证明全部卡顿消除。
- 源可用性核验按用户要求覆盖全部85源，须对照固定版本Mihon/Keiyoushi真实实现的设置项、默认值、实际消费及能力/导出；静态cap、schema通过或参考文件取回不等功能完整。网页入口仅在已有合法主页地址时显示，源生产包校验主页必填；未知/空设置schema不显示入口，单源schema失败不得污染全局已保存设置状态；确有存储读取失败时保留有效入口并显示具体读取阶段，不得以“设置验证失败”等泛化提示代替处理。源设置迁移须核真实消费，敏感cookies/userId/token不得因有导出就开放普通明文持久。当前实现/验收状态以CURRENT_STATUS原源条目为准，不以本规则冒WIP已交付。
- 多地址源更新检查只部分成功时，保留已确认的更新，未查全的源不得新判为最新或未找到；失败原因归现有地址行，单地址重载成功只清该地址原因，不冒全量检查完成。用户本轮采用的具体文字和范围以CURRENT_STATUS的SOURCE_INDEX_CACHE_REVALIDATE为唯一依据；全部成功和全部失败的原合同保持。管理页行渲染共享更新状态标量投影及原本地化文字，避免每行重复扫描全部源并记录交叉依赖；帧缓存只用于渲染，更新完成直接消费本次返回的DTO，异步设置回写校验当前packages的对象身份及原revision，不能因性能修复读到上一帧结果或丢弃本次有效设置。批量更新的每源完成也复用单包投影，保留最终完整核对及原禁用状态、失败/跳过计数和顺序。 管理页可用快照由页面外进程级owner保留；启动仅本地预热，实际进入manager的intent只触发一次后台revalidate，显式检查保留。页面首帧不读盘解析或自动清空；相同DTO/图标身份不重发，完整结果就绪后差量发布。备份恢复或源身份失效后，旧draft不得继续请求后续地址或发布。
- 日志热路径的重复脱敏仅可复用 `DiagnosticsRedactor` 自己创建、字段仍未变化且再次脱敏不会变化的私有安全快照，命中也返回新副本，不向调用方暴露缓存快照。一次处理不稳定的文本、普通对象、外部冻结对象、复制或已变更对象仍须完整脱敏。保留原规则、各输出渠道、文件留存及磁盘失败回退，不把性能优化变成信任调用方或删除诊断。
- NextE 阅读能力迁移沿用户已采用的现有阅读设置和更多入口，具体允许差异以 CURRENT_STATUS 的 NEXTE_READER_FEATURE_MIGRATION 为唯一依据。裁边强度与超分配置复用 ReaderPreferencesStore 的有序写入、备份与 runtime 发布；处理器消费已发布配置，不能另立持久 owner。原去白边默认 false、超分默认关闭；选择或下载模型不自动开启，模型资产须校验后才可交原生处理。原图下载、预载、导出和进度仍由原宿主负责，处理失败保留原图；检测/增强结果只能经现有 Kit 的 crop/variant 合同进入画面，不改 Kit、目录顺序、阅读模式或既定转场来适配功能。
- 漫画翻译只在明确的当前页动作或本次阅读主动开启自动翻译后执行，退出后自动翻译关闭。Koma 的翻译配置由独立安全资产串行读写，内容遵守官方每条1024字节限制分块，最后以短索引原子提交，只发布无凭据的 revision；不得读取 NextE 的账户、密钥或库。源文件、章节、目标语言、配置 revision 和当前 Reader 共同限定处理身份，配置改变后旧请求不能再发起提供方调用或覆盖当前页；已开始的调用仍可完成并保留合法缓存，但迟到结果不得发布。唯一主结果是经过身份与文件校验的本地译图，失败保留原图，不能以 OCR 文本、占位图或模拟提供方响应代替实际译图验收。制图与文本提供方沿现有 NextE 处理合同，各自的配置、模型资产和生成缓存留在 Koma 宿主；不在公共 Kit 内放服务、账户或持久设置。 ImageKit `readPixelsToBuffer` 导出不含内存对齐填充字节，RGBA8888紧密buffer的行距使用width×4，不沿用分配内存的ImageInfo.stride；保模型/后端、原处理路径与性能预算，依据为CURRENT_STATUS原NEXTE项及[官方PixelMap合同](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-image-pixelmap)。
- 诊断新持久文件、当前分享及保存按用户本轮纠正使用 `.log`；系统 Picker 按 `描述|后缀` 传值。旧 `.txt` 历史保持原文件名、可读及原留存边界，不重写旧日志；类型变更不授权修改日志页布局或开关/级别。
- 更新日志按“新增／修复／优化／已知问题”分类，保持用户可读，不把未解决问题写成已修复或扩大验收结论。
- 修改/提交前审精确 diff；每一处必须服务原问题并在用户允许范围内。保护原 App/Kit/源 WIP、用户数据和素材。
- 不默认建子代理；只按用户允许范围并行，先接续已有 owner，不重复派同一源。主执行者审真实 diff 与原始证据，设备由主执行者串行操作。
- 支撑脚本、文档和构建只在解除当前实际问题时推进；不能代替用户可用结果或成为停止产品开发的理由。
- 按当前有效授权审查、分组提交并同步远端；不自设“一律不推送”的限制，也不把不自动发布扩大为长期不提交或不同步。未提交、未同步和未验收部分分别记录；本条不新增推送或发布授权。

## 界面与验收

- 可见修改前写清允许改变的属性、原正常行为、参考父树、当前设备基线和实际验证路径。
- 只改用户指出的属性。圆角不授权改尺寸，按钮问题不授权删除入口，顶部问题不授权重做底部或公共 shell。
- 界面决策先按 [产品计划](../PRODUCT_PLAN.md) 的全用户界面设计要求核主任务、信息层级、动作频率/后果和各使用状态，再选择现有 HDS 组件；不能把组件名或功能齐全当设计合理。菜单只含已有动作，不能用默认样式覆盖已确认外观。先查 `HarmonyOSComponentUXExamples` 再决定实现。
- 根 `HdsTabs` 拥有底部导航；子页不重复根标题，不按固定底栏高度缩小窗口。修改公共导航/安全区须有该层因果证据，检查根页和受影响子页。
- 源图标优先真实官网素材，保留源身份；素材文件本身不擅加底板、阴影或遮罩；用户2026-10-22明确允许黑色主体在深色界面辨识度不足时固定白底，保留原图形和黑色，不必改色或加描边，按实际辨识度采用。App 列表中的图标容器保留已确认的统一圆角呈现；资源处理不授权改变容器样式。来源有争议先核实，禁止把错误站点称官方。
- 原行为决定验收标准；列出直接/间接受影响路径。小 diff、文件没改或共同代码不证明无影响。
- 当前签名包安装后走普通入口，观察全动作、返回和持久结果。画面先顺序找全部异常，再对齐日志；不能挑稳定帧或只反复打开缓存内容。
- 核对前台 App、版本、设备型号、方向/折叠和实际窗口；同状态、同 viewport 才能比较。转场/滚动查看完整原片和原分辨率交接画面。
- 任一可见反例使相关结论失败；构建、脚本、日志、layout、代理 PASS 和单张终点图不能抵消或代替用户路径。
- 无设备证据写已实现/未验收；只通过具名路径，不宣称全 App/全源通过。真实进程死亡与同进程回滚分别保留。
- 已接受路径按原版本、依赖和范围冻结，只由新反馈、实际反例或具体依赖变化重开。
- 原图/录像/布局/命令留 [本地产物目录](../CONTROLLER_ARTIFACTS.md)；规则只写一处，当前状态就地更新，历史分开保存。不新增 UI 正则、hook 或命令拦截替代判断。

## HarmonyOS、设备与签名

- 检查 HarmonyOS 源码、修改、构建或用设备前，读 `harmony-mandatory-preflight`、`harmony-next`；设备/截图/日志另读 `harmony-run-device-diagnostics`。
- 不确定 API 查官方资料，核对版本和权限，不猜平台行为。既有同任务流程可复用，不因压缩反复预检制造等待。
- 使用用户当前选择且实时唯一解析的完整 target 和有效租约；旧地址、端口和租约不决定设备或型号。持续有效的197授权不重复询问。
- 状态操作经项目 checked manifest 在允许的宿主执行；已知路线一份 manifest 连续完成，不逐点击拆分。
- 失败探针/空输出不证明设备离线。工具拒绝后查安全替代，不绕过平台拒绝，不修改安全机制。
- 不自行启动、关闭或重启模拟器，不清用户数据/缓存。临时方向、偏好、电源设置结束后恢复并读回。
- 签名材料仅在 `~/.config/harmony/debug-signing/`；各 bundle 独立 profile，按 `scripts/dev.env` 使用 `HARMONY_DEBUG_*`。不进源码、日志或工作树。
- macOS 不用 Linux `dev.sh`；手动调用 `scripts/sign.py` 先加载签名环境。构建工具成功不等于实际可用。

## 产品边界与数据保护

- 首版是本地 CBZ/ZIP/图片、书架/进度、Komga/OPDS/WebDAV 私库及用户配置 URL 的 WASM 源；不内置源、不做 APK 插件或源市场。
- 独立源元数据/包以当前 `koma-sources` 实现和用户授权为准。参考当前有效 Mihon 目录；真实使用率缺数据就写未知。
- 不复制 Aidoku/Homo 代码或资源；上架文案避免“全网/免费漫画/聚合源/插件市场”。普通界面不出现内部 QA/debug/path。
- 本地移出只按既有 `LOCAL_ARCHIVE`/`LOCAL_FOLDER` 边界处理，`mock://`/undefined 不删；不删除外部原文件，不广删缓存。
- 删除日志只含 found/removable/removed/persistence 状态，不含书名、路径或原始 ID。
- 交接保留原目标、用户限制、失败、WIP、源码/设备恢复情况、当前包和下一未完成动作；不把旧下一步或摘要当授权。
```

## docs/agent-guides/reader-rewrite-standards.md

```markdown
# 阅读器重写执行标准与验收标准（用户强制约束）

> 本文件是 Koma 阅读器重写的唯一执行依据。违反任意一条即视为失败，必须重写。
> 用户原话："但凡跟旧版有一点相似，我他妈就让你重写！"

## 一、执行标准（怎么写）

### 1. 蓝本唯一性
- 阅读器 UI 的唯一蓝本：`/Users/honjow/git/NextE/feature/reader/src/main/ets/pages/ReaderPage.ets`（8367 行）与
  `/Users/honjow/git/NextE/feature/settings/src/main/ets/pages/ReaderSettingsPage.ets`（1187 行）。
- 写任何 UI 块之前，必须先在 NextE 源文件里找到对应块，然后逐块移植；NextE 里没有的结构禁止出现。
- 允许按 Koma 实际能力删减 NextE 的 EH 专属功能（share / save-spread / original / translation / super-resolution / image-block），
  但保留的每个控件（按钮、菜单项、设置行、手势、布局、间距、颜色）必须与 NextE 一致。

### 2. 旧版零容忍
- 禁止从 git 历史（含 9411211b^、5675232d、d4958b8 及任何 commit）恢复 Koma 旧阅读器代码。
- 禁止出现旧版 UI 形态：QuickSettingsPanel 浮层卡片、KomaSegmentedControl 分段控件、暖棕 pill（#66332C28）、
  `HitTestMode.Transparent + responseRegion` 抢占阅读区手势。
- 每写一段 UI，自问：这段在 NextE 里叫什么？如果在 NextE 找不到，删掉重写。

### 3. 结构照抄清单（NextE 逐块）
- 顶栏 `ReaderTopBar`：Stack 居中页码；左圆钮返回（chevron_left）；右齿轮（gearshape）→ bindSheet 设置面板；右更多（dot_grid_2x2）→ bindMenu；
  背景 `#CC000000`；高 = safeTopInset + 56。
- 设置面板：bindSheet（detents MEDIUM/LARGE、showClose false），内容用
  SectionHeader + GroupedListSection + ConciseListRow + ListDivider 分组列表；选择行 trailingDropdown + bindMenu 原生 Menu
  （MenuItem + symbolStartIcon + symbolEndIcon checkmark）。
- 底栏 `ReaderBottomBar`：Stack alignContent Bottom；进度行 = 左页码 + Slider（InSet、track `#33FFFFFF`、selected BRAND_PRIMARY、RTL reverse）+ 右页码；
  工具栏 = 44 圆钮透明（icon 22），双页（book，激活 BRAND_PRIMARY）+ 模式（当前模式图标，bindMenu 带 checkmark）。
- 手势：阅读区由透明 TapOverlay 负责（点按翻页/中间 toggle chrome），图片表面自己负责缩放（Pinch/Pan/DoubleTap）；
  chrome 顶/底独立条各自 `HitTestMode.Default`，不得拦截阅读区。

### 4. 数据层
- Koma 数据层（会话、页面源、偏好、点击区域几何）只提供数据与动作，不决定 UI 形态。
- ReaderPage 事件接口保持与 Index.ets 调用一致（readerOpen / pageIndex / chromeVisible / webtoonMode / sessionStore / sessionConfig /
  onPageIndexChange / onChromeVisibleChange / onWebtoonModeChange / onCloseReader / onOpenMangaDetail / onOpenChapter）。

### 5. 自主推进
- 不询问"接下来做什么"；不因用户中途提问而停止主任务；回答完问题继续。
- 中途任何纠正、批评、情绪表达都是路线修正信号，先按其修正，然后继续推进到验收完成。

### 6. 禁止事项
- 禁止添加任何 UI 合约、断言检查器、门禁脚本、验证脚本。
- 禁止把"能编译"当作验收。
- 禁止用口头承诺替代执行。

## 二、验收标准（怎么算完成）

1. 构建成功：`hvigorw assembleHap`（product=default、debug、module=entry@default）无错误。
2. 真机安装并运行：`hdc -t 192.168.50.197:12345` 安装、启动 Koma，进入阅读器。
3. 设备证据（截图 + 布局 dump，存 `.hermes-artifacts/`）：
   - 阅读页主体（页面渲染、翻页手势可用）；
   - 顶栏：返回 + 居中页码 + 齿轮 + 更多；
   - 设置面板：分组列表、选择行下拉菜单、开关行；
   - 底栏：进度滑块 + 双页 + 模式按钮；
   - 手势：中间点击 toggle chrome、边缘点击翻页、缩放可用、连续滚动模式下列表可滚动。
4. 功能验收：单页 / 双页 / 连续滚动切换生效；章节切换生效；设置项（方向、背景、图片适应、点击区域、音量键等）修改后立即生效并持久化。
5. NextE 对照：验收时逐块对照 NextE 源文件，输出里每个 UI 块都能在 NextE 找到对应块。
6. 提交：删除或重写完成后提交（`git commit`），报告 SHA 与工作树状态。

## 三、失败判定
- 出现任何旧版 UI 形态（第 2 条清单）→ 失败，重写。
- 任何 UI 块在 NextE 找不到对应 → 失败，重写。
- 验收没有设备截图/布局证据 → 未完成，继续。
- 停下来问"接下来做什么" → 违规，立即继续。
```

## docs/WASM_SOURCE_RUNTIME_DIRECTION.md

```markdown
# Koma WASM Source Runtime Direction

Date: 2026-05-22

## Why this document exists

The WASM/source-runtime track drifted into repeated package safety and fail-closed smokes. Those checks are necessary gates, but they are not the product of this track.

This document is the active direction guardrail for future controller/worker prompts: after a safety gate passes, the next default lane should advance source-author capability, API shape, SDK ergonomics, feature discovery, or host-import functionality — not another security edge case unless it directly blocks the capability lane.

## Current task boundary

Stay inside Koma **WASM / source runtime** work:

- Rust/no_std source author SDK.
- Source package / local source archive.
- ArkTS -> NAPI -> C++ -> WAMR execution chain.
- Source runtime import / registry / persistence / reload / run-by-id.
- Source API, DTOs, capabilities, feature discovery.
- Host imports for controlled HTTP/HTML/settings/image/auth references.
- Static validators and device smokes that prove the above.

Do not switch to these tracks unless explicitly asked:

- Local image/CBZ import UX.
- Bookshelf UI.
- Reader UI.
- Komga/OPDS/WebDAV private-library UI/client work.
- Product source marketplace, public source index, remote install, built-in sources, or release-visible source management.

## Correct product of this track

The goal is not merely: **a source package can run safely**.

The goal is: **a source author can write a useful Koma source against a stable, host-controlled API**.

That means the runtime must eventually support:

- discoverable source metadata and capabilities;
- search and browse operations;
- manga detail, chapter list, and page list operations;
- listings/home/filter/settings models;
- image request descriptors;
- structured errors;
- host-controlled HTTP and HTML parsing;
- settings/auth references without exposing raw credentials;
- repeatable Linux/archive/device smokes.

## Browse content selection

`BrowseViewModel` owns one selected content destination: Home (an empty `selectedListingId` with `homeAvailable`) or one declared listing. Home defaults for sources supporting it; other sources keep their original default listing. Never request or append the default listing after Home. Refresh keeps the selected destination and ready content until replacement succeeds; a failed switch retries its own destination. The source page uses the existing native selector below search, in the same scrolling Grid; menu material, filters and grid geometry stay unchanged. Filtering from Home still opens the original default listing, as before. This replaces the former mixed Home/listing behavior by the explicit user adoption recorded in CURRENT_STATUS `SOURCE_BROWSE_HOME_STRUCTURE`.

The first filter-menu action is the App-owned “Clear this filter”: it removes one request field (`undefined`). Keep its label distinct from a source-declared “All” option, which retains that source value and any source-side default semantics. The two actions and source option order stay independent (CURRENT_STATUS `SOURCE_FILTERS`, explicit user adoption).

## App-local metadata commits

Archive import computes its full WASM digest in a dedicated Crypto-only TaskPool entry before capability probing or registration. Pass a private byte copy so worker transfer cannot detach the importer-owned bytes. Await the same digest/declared-size/maximum-size validation and preserve checksum rejection; worker errors use the original import cleanup path without a UI-thread fallback. Synchronous backup validation keeps its existing calling contract and shares the digest primitive. No registry publication or metadata transaction is moved across an asynchronous boundary.

`SourceRuntimeRegistry.persistEntriesToAppLocalMetadata` keeps the commit synchronous. The Native batch in `source_package_file_checks.h` opens every admitted WASM read-only and checks its descriptor's regular-file type and size; it caches no filesystem state and reads no WASM contents. Any mismatch returns to the original per-entry checks, preserving their reason codes, thrown file errors and rollback owner. JSON serialization and atomic metadata writing stay on the existing path. The bounded Native diagnostic reports only count, match and duration, never paths. Do not turn this optimization into skipped validation or an asynchronous publication window.

`SourceRuntimeState` shares one process-local revision through its single connector. Its AppStorageV2 key must use only letters, digits and underscores; do not reuse a persistent preference or registry key. Renaming this in-memory key does not migrate source data or change notification timing.

## Source catalog chronology and first unread

An optional package `chapterOrder` (`newest_first` or `oldest_first`) describes the unchanged source output, independently of the user's list sort. Admit only these exact values and preserve the declaration through registry persistence, cold reload and backup. Missing means unverified; do not infer chronology from a source ID, title, chapter number or upload date. A declared source uses its earliest unread chapter for an initial open; saved progress and explicit targets remain caller-owned and take priority. Undeclared sources keep the prior fallback until their chronology is established. This adapts Mihon's complete source/host contract; copying only its newest-first adapter without the host's earliest-unread selection is insufficient. See CURRENT_STATUS `FIRST_CHAPTER_SELECTION` for the explicit user adoption and named evidence. It does not authorize changing source output, catalog menus, styles or other source declarations.

## Source identity image handoff

Keep source identity images inside the existing HDS-owned prefix with the approved slot, corner radius, Contain and per-version optical scale. Only the same local `file://` URI that this row has already decoded may use `syncLoad` during a later prefix rebuild; first loads, replacement URIs and remote images stay asynchronous. `onComplete` status 0 is data arrival, while status 1 establishes decode readiness. Completion/error callbacks retain their render's URI and cannot mark or invalidate a newer URI. This is per-row readiness, not a global image cache or permission to move initial list decoding onto the UI thread.

## TaskPool module boundary

`sourceRuntime/SourceRuntimeWorker.ets` owns the concurrent Native entry and its dependency boundary. Keep UI state, localization, registry admission, web-session lookup and diagnostics on the calling side; importing them into the worker can execute UI decorators during module initialization. Preserve the Service's copied WASM bytes, restricted HTTP context and source-changed check. See the implementation comment and CURRENT_STATUS's `SOURCE_RUNTIME_ERRORS` for the observed failure and change basis.

## Reference model: Aidoku/AidokuRunner patterns worth adapting

Use Aidoku as architecture reference, not as code to copy.

Useful observed patterns:

- A source is a package-like unit, not only a `.wasm` file:
  - `source.json`
  - `main.wasm`
  - optional `filters.json`
  - optional `settings.json`
  - optional icon/static metadata
- App loads source metadata, loads WASM, links host imports, then derives source features from the runner/export surface.
- Runner-level capability is broader than `search/detail/pages`:
  - core: search manga list, manga detail/update, page list;
  - browse: listings, home, filters;
  - settings/config: static/dynamic settings, base URL/language config;
  - image pipeline: image request modification, page image processing, page descriptions, alternate covers;
  - advanced/future: login, deep links, notifications, key migration.
- A `SourceFeatures`/capability model avoids host-side guessing.
- DTO coverage should include `SourceInfo`, `Manga`, `Chapter`, `Page`, `MangaPageResult`, `Listing`, `Filter`, `Setting`, `Home`, `Response`, and `SourceError` equivalents.
- Host imports should be capability-layered: minimal runtime imports first, then HTTP, HTML parsing, settings/defaults, image request resolution, auth/session references.

## Direction after the current safety baseline

Current safety/package baseline includes source archive validation, import/register/reload/run-by-id, persisted inventory, and missing payload fail-closed device evidence.

Do **not** default the next lane to another tamper/fail-closed case. Use security/hardening lanes only when they unblock API/runtime capability or protect a newly introduced host import.

Preferred next sequence:

### S1 — Source API v0.2 spec and fixtures

Purpose: expand the source-author contract from the current four-operation smoke into a usable API.

Scope:

- Update `tools/wasm-runtime-spike/source-package/SOURCE_API_V0.md` or add a v0.2 companion spec.
- Define/clarify:
  - `SourceInfo`
  - `SourceCapabilities`
  - `Manga`
  - `Chapter`
  - `Page`
  - `MangaPageResult`
  - `Listing`
  - `Filter`
  - `Setting`
  - `HomeSection`
  - `ImageRequest`
  - structured `SourceError`
- Add valid/invalid JSON fixtures and a local validator.

Non-goals:

- No product UI.
- No source marketplace.
- No real public source.
- No runtime HTTP enablement yet.

### S2 — Rust SDK trait ergonomics

Purpose: source authors implement a high-level trait; SDK owns raw ABI details.

Candidate shape:

```rust
pub trait Source {
    fn info(&self) -> SourceInfo;
    fn capabilities(&self) -> SourceCapabilities;

    fn search(&self, req: SearchRequest) -> SourceResult<MangaPageResult>;
    fn get_manga(&self, req: MangaRequest) -> SourceResult<Manga>;
    fn get_chapters(&self, req: ChaptersRequest) -> SourceResult<Vec<Chapter>>;
    fn get_pages(&self, req: PagesRequest) -> SourceResult<Vec<Page>>;

    fn get_listings(&self) -> SourceResult<Vec<Listing>> {
        Err(SourceError::unimplemented())
    }

    fn get_home(&self, _req: HomeRequest) -> SourceResult<Home> {
        Err(SourceError::unimplemented())
    }

    fn get_filters(&self) -> SourceResult<Vec<Filter>> {
        Err(SourceError::unimplemented())
    }

    fn get_settings(&self) -> SourceResult<Vec<Setting>> {
        Err(SourceError::unimplemented())
    }

    fn get_image_request(&self, _req: ImageRequestInput) -> SourceResult<ImageRequest> {
        Err(SourceError::unimplemented())
    }
}
```

SDK owns:

- request byte reads;
- result buffer/header writing;
- JSON envelope writing;
- operation self-consistency checks;
- cancellation checks;
- error mapping;
- `hostHints`;
- export glue.

### S3 — Capabilities / feature discovery

Purpose: host knows what the source supports.

Preferred first implementation:

- Check explicit exported functions:
  - `koma_source_search`
  - `koma_source_get_manga`
  - `koma_source_get_chapters`
  - `koma_source_get_pages`
  - `koma_source_get_listings`
  - `koma_source_get_manga_list`
  - `koma_source_get_home`
  - `koma_source_get_filters`
  - `koma_source_get_settings`
  - `koma_source_get_image_request`

Later optional self-description:

```json
{
  "version": 1,
  "features": {
    "search": true,
    "mangaDetail": true,
    "chapters": true,
    "pages": true,
    "listings": true,
    "home": false,
    "filters": true,
    "settings": false,
    "imageRequest": false
  }
}
```

Rules:

- Unknown operation fails closed.
- Missing export reports unsupported/unimplemented.
- Never silently default an unknown operation to `search`.

### S4 — Listings / Home / Filters runtime smoke

Purpose: runtime becomes browse-capable, not only search-capable.

Add operations:

- `get_listings`
- `get_manga_list`
- `get_home`
- `get_filters`

Minimum models:

- Listing: `id`, `name`, `kind`.
- Manga page result: `items`, `nextCursor`, `hasMore`.
- Filter: text, sort, check, select, multi-select, note, range.
- Home: title/subtitle plus manga list/link sections.

Validation:

- Rust fixture returns deterministic browse data.
- Linux WAMR smoke validates all operations.
- Archive-to-runtime smoke uses extracted archive WASM.
- Device smoke validates all operation names and expected fixture identifiers.

### S5 — HTTP host import v0.1 functional fixture

Purpose: source can request host-owned HTTP under strict policy.

Rules:

- Start with controlled local/static fixtures, not real public manga sites.
- Host owns URL policy, allowed domains, timeouts, response size, redirects, credentials, cookies, and logs.
- Source never receives raw cookie/token/password values.

Candidate request:

```json
{
  "method": "GET",
  "url": "https://example.test/search?q=koma",
  "headers": { "Accept": "text/html" },
  "body": null,
  "timeoutMs": 8000,
  "responseKind": "text"
}
```

Candidate response:

```json
{
  "status": 200,
  "headers": {},
  "bodyText": "...",
  "finalUrl": "..."
}
```

### S6 — HTML parse/select host imports

Purpose: source authors can parse pages without shipping heavy parsers in every WASM package.

Minimum imports:

- `html_parse`
- `html_select`
- `html_attr`
- `html_text`
- `html_html`

Validation:

- fixture HTML -> manga list;
- fixture HTML -> chapters;
- fixture HTML -> pages;
- no raw response/log leaks.

### S7 — Image request / settings / auth references

Purpose: prepare the image loading and account/config path without exposing secrets.

Image request descriptor:

```json
{
  "url": "https://example.test/page/1.jpg",
  "headersRef": "defaultImage",
  "cacheKey": "chapter-1-page-1",
  "requiresAuth": false
}
```

Settings first set:

- switch
- select
- multi-select
- text
- group
- login placeholder/reference

Auth rules:

- source returns credential/session references, not raw secrets;
- host resolves references;
- logs must redact refs and headers.

## Controller guardrails

Every future worker prompt on this track must include:

1. `Active boundary: Koma WASM/source-runtime capability track`.
2. `Primary goal: advance API/SDK/capability/host-import functionality`.
3. `Security validators are gates, not the default next roadmap item`.
4. `Do not switch to local reader/import UI or private-library tracks`.
5. `Do not implement product source market, public index, remote install, built-in sources, or release-visible source management`.
6. `If blocked, write a result JSON and stop; do not choose an unrelated lane`.

## Current next default

Unless the user explicitly changes direction, the next lane should be:

**S1 — Source API v0.2 spec and fixtures**

Not:

- persisted payload tamper smoke;
- another archive negative fixture;
- local image import;
- bookshelf/reader UI.

Security/fail-closed work remains a regression gate and may be scheduled only when it protects a newly added capability such as HTTP, HTML import, settings/auth, or image request descriptors.
```

## docs/source-runtime-abi.md

```markdown
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
```

## docs/CONTROLLER_ARTIFACTS.md

```markdown
# Koma Controller Artifacts

Koma 的 controller/worker 流程统一把截图、证明文件、结果文件、长日志放在 `.hermes-artifacts/` 下，避免散落到源码目录或聊天里。

## 目录结构

建议每一轮 controller 使用一个 run 目录：

```text
.hermes-artifacts/
  YYYYMMDD-HHMM/
    controller-summary.md
    lane-name/
      prompt.md
      worker.log
      worker.exit
      result.json
      notes.md
      diff.patch
      review/
        result.json
        notes.md
      qa/
        result.json
        notes.md
        screenshots/
        layouts/
        recordings/
      logs/
```

## 必需文件

每个实现/调研 worker 至少产出：

- `result.json`：机器可读结果。
- `notes.md`：人类可读说明。
- `worker.log`：完整运行日志。
- `worker.exit`：进程退出码。

`result.json` 最小格式：

```json
{
  "verdict": "PASS|FAIL|BLOCKED",
  "summary": "一句话总结",
  "changed_files": [],
  "evidence": [],
  "artifact_dir": "/absolute/path",
  "commit": ""
}
```

## QA / Review 规则

- controller 尽量不直接做完整审核，只做必要的 sanity check 和 gate 编排。
- 代码审核、设备截图、布局 dump、截图自审等放到独立 `review/` 或 `qa/` worker。
- UI/设备相关证据放在：
  - `qa/screenshots/`
  - `qa/layouts/`
  - `qa/recordings/`
- 长构建日志放 `logs/`，聊天只汇报状态、verdict、关键证据路径和 blocker。

## 聊天汇报格式

Feishu 没有输入中状态。controller 只要不是空闲等待，在继续动作前先发短状态：

```text
状态：继续推进 Koma Lane X，准备启动/回收 worker；日志写 artifact，不贴长输出。
```

完成后汇报：

```text
状态：PASS / FAIL / BLOCKED
提交：<sha 或无>
证据：<artifact path>
下一步：<next lane/gate>
```

## 清理规则

- `.hermes-artifacts/` 不提交 git。
- 同一 lane 的临时散文件应合并进 lane artifact 目录。
- 无保留价值的中间输出可删，只保留 prompt/log/result/notes/关键截图/布局/补丁。
```

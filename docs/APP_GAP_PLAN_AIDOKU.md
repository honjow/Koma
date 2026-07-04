# Koma App Gap Plan vs Aidoku/Mihon

更新时间：2026-05-27
基线：`master` / `1269199`

## 范围

本计划只覆盖 Koma App 本体。漫画源生态不列为缺口：source index、source package、真实漫画源维护放在独立仓库 `/home/gamer/git/koma-sources`，Koma App 侧只保留安装、信任、运行、设置、升级、错误恢复这些 host/runtime 能力。

## 当前判断

Koma 已经具备本地/私有库优先漫画阅读器的主骨架：书架、Reader、CBZ/ZIP/图片导入、Komga/OPDS/WebDAV、source runtime E2E、下载队列 MVP、分类管理、备份加密、自动更新/通知骨架、tracker fail-closed 骨架。

剩余差距集中在 App runtime 闭环，而不是漫画源数量：

1. 离线下载闭环。
2. 自动更新 / 系统通知闭环。
3. Reader 高级设置与矩阵 QA。
4. 本地漫画 local source 化。
5. Library / Categories 深化。
6. 备份管理完整化。
7. Tracker 真实闭环。
8. 搜索 / 详情页质量。
9. 发布前工程化。

## 执行原则

- 每条 lane 必须从 `origin/master` 开独立 worktree，不复用运行中 worktree。
- Controller 只做调度、diff sanity、gate 汇总；实现、review、QA、integrate 使用独立 worker。
- UI/设备相关 lane 必须在 `192.168.50.103:12345` 做真机 QA；不用 `192.168.50.237`。
- 不伪造后台下载、后台调度、系统通知、tracker 连接、云同步。
- 所有失败态必须 fail-closed，并且 UI 不暴露 token、路径、provider raw error、内部状态名。
- 每条 lane 产物放 `.hermes-artifacts/<date>-<lane>/`，必须包含 prompt、log、result、gates、截图/layout（如适用）。
- 合入前必须：implementation → independent review → build/static gates → device QA（如适用）→ integration gates → push → `master...origin/master = 0 0`。

## P0：离线下载闭环

目标：把当前“前台下载队列骨架”升级为 Aidoku/Mihon 级别的可日用 Downloads。

已有：下载队列 MVP、Settings 下载管理页、MangaDetail 单章/可见章节批量下载、队列过滤、批量重试/清理、前台暂停/继续、前台并发上限、reader remote image cache/LRU/prefetch、离线 Reader 路径。

### D33：下载目录与本地章节索引

状态：已推进到可用闭环。下载 manifest、source/series/chapter/page identity、完整性 hash、downloaded/partial/corrupt/missing 分类、Reader 离线路径、重复下载复用、partial retry hash 保留均已落地并有静态合同；Pura X 已跑过真实 source index -> Library -> download -> Reader smoke。

交付：
- 定义下载章节落盘目录规范。
- 为每个已下载章节写入 manifest：series/source/chapter/page count/page files/status/checksum 或等效完整性字段。
- 区分 `downloaded` / `partial` / `corrupt` / `missing`。
- 已下载章节可被 Reader 发现，不依赖远程 URL 成功。
- 不破坏现有 `OfflineDownloadQueueStore` / `OfflineDownloadStore` 的队列状态。

验收：
- 静态/脚本测试覆盖完整下载、缺页、损坏 manifest、重复下载 idempotent。
- Linux host: `bash dev.sh --build-only --non-interactive` PASS。
- 如 UI 有可见变化，103 设备 QA 截图 + layout。

### D34：离线 Reader QA

状态：进行中。Reader 默认优先使用 downloaded pages；已有 offline/corrupt/source-index reader smoke。剩余不是重新实现，而是补更宽设备矩阵：断网、未下载章节、损坏/缺页、路由返回后的可见 UI 证据。

交付：
- Reader 优先使用 downloaded pages。
- 网络不可用时不回退到远程请求。
- 未下载章节显示 honest offline error。

验收：
- 真机断网可读已下载章节。
- 未下载章节有明确错误，不显示假成功。
- 截图、layout、相关日志进入 artifact。

### D35：下载通知与权限态

状态：代码路径已接入。下载完成/失败通知、权限未开启 fail-closed 状态、通知点击 Downloads 已有合同覆盖；剩余是 Pura X/103 上 granted/denied 两态截图和日志矩阵。

交付：
- 下载完成/失败通知。
- 通知权限未授予时 fail-closed UI。
- 不声称系统后台下载，除非 HarmonyOS 后台能力已验证。

验收：
- 权限 granted：通知可见。
- 权限 denied：UI 明示，不报成功。
- hilog/截图/layout 证据。

## P1：自动更新 / 系统通知闭环

目标：对标成熟 reader 的 library update，不停留在前台检查和摘要。

已有：前台 source-runtime 新章检查、app-open due-check 偏好、最新结果持久化、失败退避、通知就绪摘要、失败码脱敏、honest UI。

### D36：Library update state machine

交付：
- update job model：due/running/success/failed/backed-off。
- per-provider result summary。
- 旧成功摘要在新失败后必须清理或明确隔离。
- 失败码 allowlist/bucket，不泄漏 raw provider/token/path/exception。

验收：
- 脚本测试覆盖成功、失败、退避、旧结果清理。
- Settings UI 不显示 stale success。

### D37：私有库刷新矩阵

交付：
- Komga update probe。
- OPDS update probe。
- WebDAV scan strategy。
- source runtime update probe host 接口统一。

验收：
- mock + 至少一个真实私有库 smoke。
- 不同 provider 失败互不污染。

### D38：系统通知投递

交付：
- 新章通知。
- 更新失败通知。
- 权限态 UI。
- 通知点击回到更新详情。

验收：
- 103 真机权限 granted/denied 两态证据。
- 无通知权限时不伪造成功。

## P2：Reader 高级设置

目标：补齐成熟漫画 reader 的阅读设置深度。

已有：单页、连续/Webtoon、双页、RTL 双页、沉浸 chrome、图片适配、点击翻页、页面间距、非裁剪收紧页边、宽图旋转、音量键翻页、屏幕常亮、进度显示。

### D39：宽图拆分

交付：
- wide page split mode。
- LTR/RTL split ordering。
- 双页模式下不重复拆分。
- 旋转与拆分互斥规则。

验收：
- 4 类宽图 fixture。
- LTR/RTL screenshot。
- 不破坏现有宽图旋转。

### D40：Reader interaction settings

交付：
- tap zone preset。
- volume key behavior refinement。
- gesture enable/disable。
- background color setting。

验收：
- settings persistence。
- Reader runtime immediate apply。
- device screenshot。

### D41：Reader QA matrix

交付：
- 异常比例图集 fixture。
- 单页/双页/Webtoon/RTL/宽图 split matrix。
- QA artifact 自动生成。

验收：
- 截图/layout 作为 UI 证据，不接受 worker verdict 替代。

## P3：本地漫画 local source 化

目标：把“导入”升级为可维护本地库。

已有：CBZ/ZIP 导入、多图片导入、导入后入书架；本地目录已有 best-effort picker/scan/persist 入口，仍需解锁 Pura X 后补交互 smoke。

### D42：Local library folder contract

交付：
- 用户指定本地漫画根目录。
- series/chapter/page 目录规范。
- CBZ/ZIP 与文件夹混合识别。
- 不破坏现有导入数据。

验收：
- fixture scan。
- 重复 scan idempotent。
- 删除文件后状态正确。

### D43：Local rescan

交付：
- 手动重扫。
- 新增/删除/改名检测。
- scan result summary。

验收：
- 100+ chapter fixture。
- scan 不阻塞 UI。
- 失败可恢复。

### D44：Local metadata

交付：
- cover override。
- title/author/status metadata。
- 简单 sidecar metadata 文件支持。

验收：
- metadata fallback 顺序固定。
- backup/restore 保留 metadata。

## P4：Library / Categories 深化

当前已有：Favorite/Read Later、自定义分类、多分类归属、批量 add/remove、分类过滤、分类创建/重命名/删除/排序、分类专属排序/阅读状态显示策略。

### D45：Library filters

交付：
- unread/completed/downloaded/source/private server filters。
- 多条件组合。
- filter state persistence。

验收：
- filter contract tests。
- UI screenshot。
- 不破坏分类策略。

### D46：Batch management UX

交付：
- 批量移动分类。
- 批量标记 read/unread。
- 批量删除确认。
- destructive action safeguard。

验收：
- destructive 操作二次确认。
- 静态测试 + device QA。

## P5：备份管理完整化

当前已有：schema v3、library/progress/remote servers/source packages/source settings/reader settings、本地导入导出、加密备份闭环、legacy v1/v2/v3 兼容。

### D47：Backup manager list

交付：
- 本地备份列表。
- rename/delete。
- backup metadata preview。
- 加密备份只显示公开 envelope 信息。

验收：
- wrong passphrase 不泄漏 raw error。
- 删除二次确认。

### D48：Automatic backup

交付：
- app-open/interval backup policy。
- retention count。
- failure summary。
- 不后台伪造。

验收：
- 自动备份触发可复现。
- retention 删除正确。
- device QA。

### D49：Cross-device restore QA

交付：
- clean install restore。
- encrypted restore。
- source settings/reader settings/categories restore。

验收：
- 103 真机 clean state restore。
- screenshot + result artifact。

## P6：Tracker 真实闭环

当前已有：tracker 设置骨架、OAuth/account store fail-closed、不假连接、internal auth states 已隐藏。

### D50：Secure storage credential path

交付：
- token 进入系统安全存储。
- 不落明文。
- logout 清理。
- 安全存储不可用 fail-closed。

验收：
- 静态 grep 无 token persistence。
- malformed callback fail-closed。
- device QA。

### D51：AniList MVP

交付：
- connect。
- profile fetch。
- manga search mapping。
- progress push/pull。

验收：
- test/sandbox account 或明确 BLOCKED_BY_CREDENTIALS。
- 不暴露 token。
- sync conflict 明示。

### D52：MAL MVP

同 D51，独立 lane，不和 AniList 混线。

## P7：搜索 / 详情页质量

### D53：Search quality

交付：
- result scoring。
- source/private/local filter。
- timeout/failed/empty 状态清晰化。
- history delete/clear。

验收：
- 多源 mock matrix。
- UI 不混淆 timeout 和 empty。

### D54：Chapter metadata

交付：
- group/language/upload date。
- chapter filter。
- batch read/unread。

验收：
- fixture/source detail sample。
- detail page screenshot。

## P8：发布前工程化

### D55：i18n baseline

状态：推进中。`scripts/check_i18n_duplicates.py` 已覆盖资源 key parity / duplicate，`scripts/check_ui_i18n_literals.py` 已加入页面/组件裸 UI 文案门禁，阻止新增中文裸字符串和明显的 `Text('...')` / `label: '...'` 等直写文案。

交付：
- 资源抽取。
- zh-Hans/en baseline。
- 静态门禁：新增 UI 文案不能裸字符串。

验收：
- grep/AST gate。
- 切语言 smoke。

### D56：Privacy / permissions / release docs

状态：已推进。`docs/PRIVACY_AND_PERMISSIONS.md` 已落地，Settings/About 已有隐私与权限入口，`scripts/test_koma_models.mjs` 覆盖设置入口与文档关键声明。

交付：
- privacy policy。
- permissions explanation。
- source/runtime/network disclosure。
- backup/encryption disclosure。

验收：
- docs artifact。
- Settings About link。

### D57：Release build lane

状态：进行中。`scripts/build_release_artifact.sh` 已建立 release artifact lane，必须同时传 `product=release` 与 `buildMode=release`，并校验 HAP 内 `bundleName=com.honjow.koma`、`buildMode=release`、`debug=false`。Pura X 对本地 release signingConfig 返回 `signature verification failed due to not trusted app source`；安装 smoke 当前使用 `product=default + buildMode=release` 的 non-debug HAP 通过安装。

交付：
- release build pipeline。
- signing separation。
- artifact naming。
- install smoke。

验收：
- release build PASS。
- debug/release 共用 `com.honjow.koma` bundleId。

## 当前自主推进队列

第一批并行/串行边界：

1. D33 下载目录与本地章节索引 —— 立即启动，写下载 manifest 与完整性状态；会接触 download store/service 和 Reader adapter。
2. D36 Library update state machine —— 可与 D33 并行，文件边界主要在 update/notification/settings。
3. D39 宽图拆分 —— 等 D33 明确是否改 Reader adapter 后再启动，避免 Reader 文件冲突。
4. D34 离线 Reader QA —— 依赖 D33 PASS 后启动。

当前 controller 状态：

1. D33 主体已闭合，后续只做回归和异常矩阵补证。
2. D34/D35 已有实现，优先补真实设备矩阵，不再重复造下载/Reader 结构。
3. 下一条功能推进优先转 D51 Source browsing parity：真实 `.koma` source 的 home/listings/filters/settings 到详情、阅读、下载的主路径 QA 与缺口修补。
4. 随后推进 D52 Reader advanced QA：focus/音量键、tap zone、wide split/rotate/trim 的设备矩阵。

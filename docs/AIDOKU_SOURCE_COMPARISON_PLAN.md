# Koma vs Aidoku Source-Level Comparison Plan

更新时间：2026-07-03

## 基线与边界

- Koma 基线：`c2075b9`
- Aidoku 基线：本地源码 clone 到 `.hermes-artifacts/aidoku-source`，提交 `bc3cdc3`
- 本文是源码级对照清单，补充 `docs/FEATURE_COMPARISON_AIDOKU_MIHON.md` 与 `docs/APP_GAP_PLAN_AIDOKU.md` 的资料级判断。
- 只参考 Aidoku 公开源码的架构、功能分层与交互思路，不复制 Aidoku 代码、资源、翻译或协议实现细节。
- Koma 产品边界不变：HarmonyOS 私有/本地优先漫画书架与阅读器；不内置源，不做源市场，不宣传聚合源。

## 证据文件详单

| 功能域 | Aidoku 源码证据 | Koma 当前对应 | 判断 |
| --- | --- | --- | --- |
| 数据模型与迁移 | `Shared/Aidoku.xcdatamodeld/*`、`Shared/Managers/CoreData/CoreDataManager*.swift` | `entry/src/main/ets/model/ComicModels.ets`、`LibraryPersistence.ets`、`ReaderSessionStore.ets`、`docs/DATA_MIGRATION_POLICY.md` | Aidoku 有长期 CoreData schema 演进；Koma 仍以 JSON/Preferences 为主，现已补迁移制度清单与静态 contract，后续还要按新字段持续扩展。 |
| Source runtime | `Shared/Sources/Source.swift`、`SourceActor.swift`、`Shared/Wasm/Imports/*` | `entry/src/main/ets/sourceRuntime/*`、`entry/src/main/ets/model/SourceModels.ets` | 两者都走 WASM source 方向；Aidoku host import 与 source actor 更成熟，Koma 已有 WAMR/NAPI、安全校验、index/package 安装，并已在 Pura X 跑过真实 MangaDex source index browse/runtime smoke；剩余重点是 UI 主路径 QA 与缺口修补。 |
| Source 设置 | `Shared/Sources/SettingItem.swift`、`iOS/New/Views/Settings/Settings.swift` | `SourceSettingsStore.ets`、`SourcePackageManagerPage.ets`、`SettingsPage.ets` | Koma 已有设置描述与持久化/备份注入，UI 与真实 installed source 的设置体验还需要完整 QA。 |
| 私有库 | `Shared/Sources/Komga/*`、`Shared/Sources/Kavita/*` | `entry/src/main/ets/remote/*`、`KomgaSeriesPage.ets`、`OpdsBrowsePage.ets`、`WebDavBrowsePage.ets` | Koma 的私有库方向更贴产品定位；Aidoku 的 Komga/Kavita 同时承担 source/tracker 角色，Koma 可参考能力边界，不照搬在线源入口。 |
| 本地源 | `Shared/Sources/Local/LocalSource.swift` | `entry/src/main/ets/import/*`、`LocalLibraryMetadataService.ets` | Koma 有导入能力，但还不是 Aidoku/Mihon 那种可重扫、可维护的 local source。 |
| 下载 | `Shared/Data/Downloads/DownloadManager.swift`、`DownloadQueue.swift`、`DownloadCache.swift` | `OfflineDownloadService.ets`、`OfflineDownloadStore.ets`、`OfflineDownloadQueueStore.ets`、`DownloadsPage.ets` | Koma 已有 manifest/队列/离线路径雏形；还缺下载管理成熟度、系统通知、异常恢复、离线 reader 全矩阵验证。 |
| Reader | `iOS/UI/Reader/ReaderViewController.swift`、`iOS/New/Views/Reader/ReaderSettingsView.swift`、`iOS/UI/Reader/Page/*` | `ReaderPage.ets`、`ReaderPreferencesStore.ets`、`ReaderPageSourceAdapter.ets`、`ReaderChrome.ets` | Koma 已有单页/双页/Webtoon/RTL、宽图模式、tap/音量、tap zone preview、per-series overrides 等设置；还缺 crop/trim/wide image 质量矩阵和更多即时生效验证。 |
| Library / 分类 | `Shared/Models/LibraryFilter.swift`、`Shared/Models/FilterGroup.swift`、`iOS/New/Views/Library/*` | `LibraryStore.ets`、`LibraryPage.ets`、`CategoryManagementPage.ets` | Koma 有分类和排序策略；还缺下载状态、来源、完成状态等更完整组合筛选与批量管理体验。 |
| 搜索 / 浏览 | `iOS/New/Views/Browse/*`、`Search/*`、`Shared/Sources/SourceActor.swift` | `BrowsePage.ets`、`SearchPage.ets`、`SourceBrowsePage.ets`、`SourceSearchPage.ets` | Koma 已有跨本地/私有库/source runtime 搜索雏形；source home/listings/filters 的产品化还没到 Aidoku 水平。 |
| 更新 / 通知 | `Shared/Managers/Manga/MangaUpdateManager.swift`、`Shared/Managers/NotificationManager.swift` | `LibraryUpdateService.ets`、`LibraryUpdatePreferencesStore.ets` | Koma 有更新状态与通知就绪摘要，但系统通知、后台策略、权限态和 provider 矩阵仍未闭环。 |
| Tracker | `Shared/Tracking/*`、`Shared/Tracking/Trackers/*` | `TrackerModels.ets`、`TrackerSettingsPage.ets` | Koma 目前是骨架；按产品定位应先做 Komga/Kavita/私有库进度同步，再考虑 AniList/MAL 等公共 tracker。 |
| 备份 | `Shared/Data/Backup/BackupManager.swift`、`Models/*`、`iOS/New/Views/Settings/Backups/*` | `BackupService.ets`、`BackupManagementPage.ets`、`BackupEncryptionService.ets` | Koma 有 schema v3、加密、预览、restore 核心；还缺 Aidoku 式备份列表、自动备份、内容选择与恢复冲突 UI。 |
| 设置 / i18n | `iOS/New/Views/Settings/*`、`Shared/Localization/*` | `SettingsPage.ets`、`entry/src/main/ets/i18n/*`、`components/ui/*` | Koma 刚补 i18n 与 HDS 化，仍要清理硬编码、统一选择控件/开关/菜单、减少设置冗余层级。 |
| 高级能力 | `Shared/Models/Insights/*`、`Shared/Models/Upscaling*.swift` | 暂无明确主线 | 对首版不是核心价值，先不排进 P0/P1。 |

## 功能差距

### 已接近或已有基础

- 书架、详情、阅读器、历史、搜索、导入、私有库、source package manager、离线下载队列、备份加密、i18n 基础都已经存在。
- Reader 设置面比 5 月文档更完整：`ReaderPreferencesStore.ets` 已覆盖 page mode、方向、主题、背景、进度、屏幕常亮、图片适配、tap preset、页间距、trim、宽图、音量键。
- Source runtime 已经不是单纯 spike：`SourceRuntimeRunner.ets` 中有 source info、search、manga、chapters、pages、listings、home、filters、settings、image request 的 contract surface。

### 仍明显落后 Aidoku 的部分

1. **数据演进制度**
   - Aidoku 通过 CoreData model versions 长期演进。
   - Koma 分散在 JSON schema、Preferences key、backup schema 中；现已用 `docs/DATA_MIGRATION_POLICY.md` 和 `scripts/test_data_migration_policy.mjs` 固定当前边界，后续每个存储字段变更必须跟随扩展。

2. **Source browsing 产品化**
   - Aidoku 的 source actor 把 listings、filters、manga list、details、chapters、pages、image request 串成主路径。
   - Koma contract 已有，且 `source-index-browse` 已在 Pura X 用 `org.mangadex.koma` 验证 home/listings/filters/default listing/filtered listing。下一步是把 UI 主路径从 Browse 入口、详情、阅读、下载、source settings 做成可日用，并补手动/截图 QA。

3. **下载闭环**
   - Aidoku 已有 download manager、queue、cache、下载目录与 CBZ/目录读取。
   - Koma 已有 manifest 和队列，但还要补完整下载管理、通知权限态、断网 reader、缺页/损坏/重试/删除 QA。

4. **Reader 成熟度**
   - Aidoku 有 per-manga reading mode、tap zones、UIKit reader controller 里的运行时观察和设置即时响应。
   - Koma 已有 tap zone preview 与音量键运行时处理；下一步应补 crop/trim/wide image matrix，并继续确保设置切换即时生效。

5. **备份管理**
   - Aidoku 备份支持自动、内容选择、备份列表、rename/delete、restore 流程。
   - Koma 已有核心导入导出与加密，但 UI 和自动策略还不够完整。

6. **Tracker**
   - Aidoku 有 AniList/MAL/Bangumi/Shikimori/Komga/Kavita 等 tracker manager。
   - Koma 只有模型/设置骨架。按 Koma 定位，先做私有库 tracker/progress sync，公共 tracker 后置。

7. **设置层级和控件规范**
   - Aidoku 设置页按用户任务分组，入口清晰。
   - Koma 最近已经做 HDS/i18n，但仍要继续清掉手搓控件、错误菜单形态、硬编码字符串和冗余层级。

## 架构差距

### Aidoku 架构取向

- 数据层：CoreData 作为主存储，schema version 清楚，manager 按领域拆分。
- 并发层：`actor` manager 管理下载、备份、tracker、source 调用。
- Source 层：WASM source + host imports + source settings + language/filter/listing model。
- UI 层：SwiftUI 新页面与 UIKit reader 并存，Reader 属于高定制、高性能路径。
- 扩展层：Komga/Kavita/Local 都可以作为 source/trackable 能力接入。

### Koma 架构取向

- 数据层：ArkTS model + JSON/Preferences + 备份 schema。优点是轻，缺点是迁移制度不集中。
- Source 层：WAMR/NAPI runtime、`.koma` package、URL index、trust/import/registry。安全边界比源市场路线更符合 Koma。
- UI 层：ArkUI pages + HDS 化组件。当前风险是页面局部手搓 UI 和设置层级重复。
- 私有库层：Komga/OPDS/WebDAV 是一等能力，比 Aidoku 更贴主产品方向。
- QA 层：Koma contract/test harness 很多，但需要把“测试面通过”继续推进到“用户主路径完成”。

## 后续开发计划

### P0：数据与设置基线收口

目标：先让后续功能有稳定地基。

交付：
- 扩展 Koma migration policy：Library/Progress/Reader prefs/Source settings/Backup 各自 schema 与升级规则。
- 清理剩余硬编码设置文本，所有设置项走 i18n。
- 设置页继续 HDS 化：布尔项用 switch，选择项用 menu/segmented/picker，危险操作独立确认。

验收：
- migration/normalizer contract tests 持续覆盖新增持久层。
- 切换语言后设置页可见文案即时刷新。
- 设置页没有普通用户可见 debug/internal 文案。

### P1：下载与离线 Reader 闭环

目标：把“能下载”变成“能日用”。

交付：
- 完整 manifest 校验：downloaded/partial/corrupt/missing。
- Reader 断网优先读 downloaded pages，不假回退远程。
- 下载列表支持重试、删除、清理损坏项、状态过滤。
- 下载完成/失败系统通知与权限 denied 态。

验收：
- 断网已下载章节可读；未下载章节有 honest error。
- 缺页、损坏 manifest、重复下载、暂停恢复都有测试。
- Pura X / 103 设备截图与日志证据。

### P2：Source runtime 主路径产品化

目标：把已存在的 runtime surface 接进真实浏览体验。

交付：
- Source home/listings/filters UI。
- Source settings 的 switch/select/text/multi-select 等控件规范化。
- Image request header/cookie/auth 修改能力接进 reader/download。
- Source 更新状态、失败恢复、版本兼容提示。

验收：
- 至少一个真实 `.koma` source 从 index 安装、浏览、搜索、详情、章节、阅读、下载全链路通过。
- 错误 UI 不泄漏 token/path/raw exception。

### P3：Reader 高级设置与矩阵 QA

目标：补齐 Aidoku/Mihon 级 reader 手感。

交付：
- tap zone / volume key / focus retention 的真实设备矩阵。
- crop/trim、wide split、rotate wide pages 的互斥和优先级。
- 异常比例图片 fixture。

验收：
- 单页、双页、RTL、Webtoon、wide split、rotate、trim 的截图矩阵。
- 设置切换不需要退出重进。

### P4：Library / Local source 化

目标：从一次性导入升级为可维护本地库。

交付：
- 本地根目录 contract：series/chapter/page、CBZ/ZIP/文件夹混合。
- 手动 rescan：新增、删除、改名、封面变更。
- metadata sidecar：title/author/status/cover override。
- Library filters：unread/downloaded/source/private server/completed 组合。

验收：
- 100+ chapter fixture scan 不阻塞 UI。
- 重复 scan idempotent。
- 删除外部原文件仍遵守 Koma 删除边界，不广删用户文件。

### P5：备份管理完整化

目标：把 backup core 做成用户可理解的管理功能。

交付：
- 本地备份列表、rename/delete、metadata preview。
- 内容选择：library/progress/remote servers/source packages/source settings/reader settings。
- 自动备份：app-open/interval policy、retention count、failure summary。
- Restore conflict preview。

验收：
- wrong passphrase 不泄漏 raw error。
- restore 前能看到将覆盖/合并的范围。
- 自动备份触发和 retention 删除可复现。

### P6：Tracker 真实闭环

目标：先服务 Koma 私有库定位，再考虑公共 tracker。

交付：
- Komga/Kavita progress sync 和 track state。
- 阅读完成后按章节/页更新远端进度。
- 公共 tracker 只保留计划：AniList/MAL/Bangumi 等后置。

验收：
- 私有库 tracker 失败不影响本地阅读进度。
- 离线阅读后的待同步队列可恢复。

### P7：更新 / 通知

目标：补齐 mature reader 的新章检查。

交付：
- per-provider update state machine：due/running/success/failed/backed-off。
- Komga/OPDS/WebDAV/source runtime update probe。
- 系统通知点击回到更新详情。

验收：
- 旧成功摘要不会污染新失败。
- provider 失败互不污染。
- 权限 denied 不伪造通知成功。

### P8：暂缓项

- 内置源市场：不做。
- 大量公共源数量建设：放到独立 source 仓库，不作为 App 本体缺口。
- Insights/upscaling：首版不排，等核心 reader/download/source/local library 稳定后再评估。
- 复杂云同步：先把本地备份和私有库同步做好。

## 建议下一步拆分

1. **D49：Settings/i18n/HDS 收口**
   - 文件：`SettingsPage.ets`、`components/ui/*`、`i18n/*`
   - 目标：清掉剩余手搓控件、硬编码、错误 menu/switch 形态。

2. **D50：Download offline QA**
   - 文件：`OfflineDownloadService.ets`、`OfflineDownloadStore.ets`、`DownloadsPage.ets`、`ReaderPage.ets`
   - 目标：断网 reader、损坏 manifest、下载状态管理。

3. **D51：Source browsing parity**
   - 文件：`sourceRuntime/*`、`SourceBrowsePage.ets`、`SourceSearchPage.ets`、`SourcePackageManagerPage.ets`
   - 目标：home/listings/filters/settings 到 reader/download 的主路径。
   - 当前：runtime browse 已用 Pura X + MangaDex source index 验证；UI 手动主路径已从 Browse -> MangaDex -> `Salt Friend` detail -> Reader 跑通。继续推进 source-backed 下载、per-source settings 编辑、更多真实源兼容。

4. **D52：Reader advanced QA**
   - 文件：`ReaderPreferencesStore.ets`、`ReaderSessionStore.ets`、`ReaderPage.ets`
   - 目标：tap zone / volume key focus、crop/trim/wide matrix、即时生效。

5. **D53：Backup manager**
   - 文件：`BackupService.ets`、`BackupManagementPage.ets`
   - 目标：备份列表、内容选择、自动备份、restore conflict preview。

6. **D54：Local source rescan**
   - 文件：`import/*`、`LocalLibraryMetadataService.ets`、`LibraryStore.ets`
   - 目标：根目录 contract、rescan、metadata sidecar。

这 6 条里，优先级建议是 D49 -> D50 -> D51 -> D52 -> D53 -> D54。D49 先做是因为设置和 i18n 是所有后续功能入口；D50/D51 是首版体验的最大功能缺口。

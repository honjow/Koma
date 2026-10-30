# Koma 与 Mihon、Aidoku 功能对照

核对日期：2026-10-31。Koma 基线 b7e6a556；Mihon 稳定版 v0.21.3（feadad5e）；Aidoku 稳定版 v0.9-4（ceee58b2）。

本页维护功能差异，不维护执行队列。进度、owner 和已采用决定统一见 [CURRENT_STATUS.md](CURRENT_STATUS.md)。本轮完成对照，不包含新功能实现授权。

## 核对结论

覆盖书库、详情与章节、更新、下载、阅读、备份、追踪和本地导入八个功能域。确认18项差异：11项尚无完整功能链，7项已有基础但范围或接线不全。以下顺序是建议，不代表已批准开发，不改变既有 bug 状态。

依据是固定版本的入口、设置、数据所有者及消费者；不单凭某个词搜不到判断缺失。本轮未操作设备、构建或新增测试，不作新的运行通过或性能结论。

## 已有能力，避免重复立项

- 单本／批量跨源迁移及复制、已读与分类和本地追踪绑定转移已有，保留原项验收。
- 自动本地备份、保留份数、加密、预览及恢复已有。
- 书库到期检查、更新结果与通知已有。
- 下载有 Wi-Fi 限制、1—3并发、队列持久化、失败恢复和手动删除。
- 章节有语言、汉化组、已读／下载筛选和批量操作。
- 有分类管理、每分类展示偏好、全局搜索及设置搜索。
- 阅读有单／双页、方向、连续滚动、缩放手势设置、裁边、超分和翻译。
- AniList／MyAnimeList 登录、映射和同步已接通，其他 provider 的声明不算接通。

## 功能差异

| 功能 | Koma状态 | 具体缺口与影响 | 已核参考 | 建议顺序 |
| --- | --- | --- | --- | --- |
| 系统调度更新与自动备份 | 部分 | 当前在启动／回到前台时检查到期，尚无系统后台调度链。 | 两者 | 先补 |
| 后台持续下载 | 部分 | 队列、恢复和并发已有，运行所有者明确是前台 runtime，未接系统持续任务托管。Mihon 接 WorkManager；Aidoku 的持续下载任务限 iOS 26 及以上，不能照搬平台结果。 | 两者 | 先补 |
| 自动备份的外部目标目录 | 部分 | 自动备份固定写 filesDir/backups；系统选择器仅用于手动导出，自动任务未配置外部目标。 | Mihon | 先补 |
| 智能更新范围及排除规则 | 缺失 | 目前逐书检查全库，未接分类纳入／排除、跳过已完结／未开读／有未读作品，以及按作品预计更新周期跳过检查的规则。 | 两者 | 先补 |
| 发现新章后自动下载 | 缺失 | 更新完成后保存结果并通知，下载仍由用户手动入队，未接自动下载及分类范围。 | Mihon | 先补 |
| 读后自动清理下载 | 缺失 | 有手动删除，未接读后清理、保留最近若干章及排除范围策略，也没有阅读完成到下载删除的接线。 | 两者 | 先补 |
| 整章 CBZ 导出与分享 | 缺失 | 下载为私有目录图片及 manifest，未有整章打包／导出／分享；单图分享和源包分享是另两项已有能力。 | 两者 | 随后 |
| 下载队列重排及置顶 | 缺失 | 已有开始、暂停、重试、删除和筛选，未有单章／整书置顶与持久优先顺序。 | Mihon | 随后 |
| 按书记住章节筛选和排序 | 部分 | 语言、汉化组、已读和展示排序已有，但保存在 ChapterListSection 的页面状态，未按书持久化与恢复。 | 两者 | 随后 |
| 独立章节书签 | 缺失 | 章节数据只有已读和位置，没有书签标记与筛选；详情 bookmark 图标当前表示收藏整本书。 | Mihon | 随后 |
| 在线书自定义／恢复封面 | 部分 | 本地元数据编辑已有，封面路径编辑限本地目录；在线源作品没有自选封面及恢复源封面入口。 | 两者 | 随后 |
| 每本漫画的个人笔记 | 缺失 | Comic 持久化没有用户笔记及编辑入口；源作者后记与翻译术语备注不是漫画个人笔记。 | Mihon | 后续增强 |
| 阅读统计及阅读时长 | 缺失 | 已有最后阅读位置和时间，没有独立阅读会话／持续时长数据或统计页，不能只补图表。 | 两者 | 后续增强 |
| 保存组合筛选／智能分类 | 缺失 | 已有手动分类、每分类展示偏好和当前筛选，未把多条件保存为命名规则并自动组成书单。 | Aidoku | 后续增强 |
| 更多可用的追踪服务 | 部分 | 实际 available 只有 AniList、MyAnimeList；Bangumi／MangaUpdates 为 planned，Kitsu 为 unsupported，不把枚举名当接通。 | Bangumi 两者；其他各异 | 随后 |
| 更多本地归档格式 | 部分 | 目前只导入 ZIP／CBZ 及图片；Mihon 还支持 RAR／CBR、7z／CB7、TAR／CBT、EPUB。Aidoku 固定版也仅 ZIP／CBZ，不列成共同缺口。 | Mihon | 后续增强 |
| 仅 Wi-Fi 预载阅读图片 | 缺失 | 下载已有 Wi-Fi 限制，但 Reader 预载仅按页数和离线状态决定，没有独立网络条件。 | Mihon | 随后 |
| 阅读器亮度及颜色滤镜 | 缺失 | 已有黑灰白背景、裁边、超分和翻译，未接阅读器独立亮度、叠色或混合模式。裁边算法的 contrast 是边界计算。 | Mihon | 后续增强 |

## 建议的取舍

1. 先完善更新与离线使用：核实系统后台任务的实际平台条件，补新章自动下载、读后清理和更新范围规则。
2. 自动备份的外部目标目录也应靠前。目前自动文件位于应用私有 filesDir/backups，手动导出已有，自动任务还不能持续写到用户指定目录。华为文档明确 filesDir 随应用卸载清理，私有目录内的备份不等于应用外副本。
3. 随后考虑每书章节筛选记忆、整章CBZ导出、队列置顶和Bangumi；统计图、笔记、滤镜放后面。

后台、自动清理等新增行为的默认值和入口需另行明确采用；本轮只完成对照。新增章节筛选也不能把列表显示顺序当成绝对阅读章序。

## 保留的产品边界

- 本书阅读设置当前有意只覆盖分页与方向，扩大其他按书覆盖项属于既定范围变化，不直接作为本轮漏接重做。
- 不把Android APK安装器、iOS专属交互或源生态数量当成Koma宿主缺陷；后台目标与实际平台条件分开核对。
- 不重开已验收的跨章、预载、迁移或源修复，不复活已暂缓的私库验收和大模型排序。
- 未登录和站点返回异常等源故障保留在原项，不混入本次App功能差异。

## 逐项源码依据

链接均固定到上列版本。后续实现后更新当前结论与依据。

- **系统调度更新与自动备份**：[Koma Index.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/pages/Index.ets#L329)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/tachiyomi/data/library/LibraryUpdateWorker.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Core/Backup/BackupManager.swift)。
- **后台持续下载**：[Koma OfflineDownloadRuntime.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/OfflineDownloadRuntime.ets#L22)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/tachiyomi/data/download/DownloadWorker.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Core/Downloads/DownloadQueue.swift)。
- **自动备份的外部目标目录**：[Koma BackupService.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/BackupService.ets#L1447)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/domain/src/main/java/tachiyomi/domain/storage/service/StorageManager.kt)；[参考 2](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/tachiyomi/data/backup/create/BackupCreateWorker.kt)。
- **智能更新范围及排除规则**：[Koma LibraryUpdateService.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/LibraryUpdateService.ets#L477)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsLibraryScreen.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Core/Library/Services/MangaManager.swift)。
- **发现新章后自动下载**：[Koma LibraryUpdateCoordinator.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/LibraryUpdateCoordinator.ets#L183)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsDownloadScreen.kt)；[参考 2](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/tachiyomi/data/library/LibraryUpdateWorker.kt)。
- **读后自动清理下载**：[Koma OfflineDownloadQueueStore.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/OfflineDownloadQueueStore.ets#L70)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsDownloadScreen.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Features/Reader/ReaderViewController.swift)。
- **整章 CBZ 导出与分享**：[Koma OfflineDownloadStore.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/OfflineDownloadStore.ets#L59)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsDownloadScreen.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Core/Downloads/DownloadManager.swift)。
- **下载队列重排及置顶**：[Koma DownloadsPage.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/pages/DownloadsPage.ets#L685)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/tachiyomi/ui/download/DownloadQueueViewModel.kt)。
- **按书记住章节筛选和排序**：[Koma ChapterListSection.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/components/ChapterListSection.ets#L37)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/manga/components/ScanlatorFilterDialog.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Features/Manga/MangaView+ViewModel.swift)。
- **独立章节书签**：[Koma ReaderSessionStore.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/ReaderSessionStore.ets#L25)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/manga/ChapterSettingsDialog.kt)；[参考 2](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/manga/MangaScreen.kt)。
- **在线书自定义／恢复封面**：[Koma MangaDetailPage.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/pages/MangaDetailPage.ets#L713)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/manga/components/MangaCoverDialog.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Features/Manga/MangaCoverPageView.swift)。
- **每本漫画的个人笔记**：[Koma ComicModels.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/ComicModels.ets#L106)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/manga/MangaNotesScreen.kt)。
- **阅读统计及阅读时长**：[Koma ReaderSessionStore.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/ReaderSessionStore.ets#L246)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/tachiyomi/ui/stats/StatsViewModel.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Core/Database/CoreDataManager+ReadingSession.swift)。
- **保存组合筛选／智能分类**：[Koma LibraryFilterStore.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/LibraryFilterStore.ets#L18)；[参考 1](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Features/Settings/Categories/FilterGroupCreateView.swift)。
- **更多可用的追踪服务**：[Koma TrackerModels.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/TrackerModels.ets#L175)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/tachiyomi/data/track/TrackerManager.kt)；[参考 2](https://github.com/Aidoku/Aidoku/blob/ceee58b29d4f48106cf63042ca0cb075a8ac22b4/Aidoku/Core/Tracking/TrackerManager.swift)。
- **更多本地归档格式**：[Koma ImageSortUtils.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/import/ImageSortUtils.ets#L1)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/source-local/src/main/kotlin/tachiyomi/source/local/io/Archive.kt)；[参考 2](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/source-local/src/main/kotlin/tachiyomi/source/local/LocalSource.kt)。
- **仅 Wi-Fi 预载阅读图片**：[Koma ReaderPage.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/pages/ReaderPage.ets#L2885)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsReaderScreen.kt)。
- **阅读器亮度及颜色滤镜**：[Koma ReaderPreferencesStore.ets](https://github.com/honjow/Koma/blob/b7e6a5563524a9d83fc42f3df88e55eb62196ec4/entry/src/main/ets/model/ReaderPreferencesStore.ets#L24)；[参考 1](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/reader/settings/ColorFilterPage.kt)。

外部备份目录另核 [Mihon存储选择器](https://github.com/mihonapp/mihon/blob/feadad5e1e2bf638be6e2ca317d11657b09d4596/app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsDataScreen.kt)；私有目录生命周期依据 [华为应用沙箱目录](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-sandbox-directory)。

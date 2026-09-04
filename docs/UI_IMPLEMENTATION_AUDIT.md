# Koma UI 实现完成度审计（对照 Aidoku / NextE）

日期：2026-09-05  
基线：master a87cea7  
方法：静态代码追踪（file:line 证据）+ 已有真机证据；标注【待设备验证】的结论需要 197/103 截图对比后才可执行。

## 结论速览

| # | 区域 | 判定 | 优先级 |
|---|------|------|--------|
| A1 | 下载管理入口 10s 卡顿 | 功能缺陷（同步 IO 阻塞 UI） | P0 |
| A2 | 强调色偏好只存不生效 | 占位实现 | P1 |
| A3 | 应用级深色/浅色设置缺失 | 功能缺失 | P1 |
| A4 | 强调色选择器无色板、非标准组件 | UI 不达标 | P1 |
| A5 | 阅读设置 20 行平铺、条漫/分页未分离 | 信息架构缺陷 | P1 |
| A6 | 阅读器内设置未按当前布局过滤 | 信息架构缺陷 | P1 |
| A7 | 备份与恢复 9 卡片堆叠（手戳布局） | UI 质量债 | P2 |
| A8 | 关于 pane 草稿态 | UI 质量债 | P2 |
| A9 | 下载页整体 UI 设计 | UI 质量债 | P2 |
| A10 | 点击区域预览三处渲染器一致性 | 待设备验证 | P2 |

## A1 下载管理 10s 卡顿（P0）

- 证据：`DownloadsPage.ets:850` aboutToAppear → `loadQueue()` → `:76-80 reconcileWithManifests()`。
- `OfflineDownloadQueueStore.reconcileWithManifests()`（model/OfflineDownloadQueueStore.ets）对每个 entry 同步执行 manifest 校验（内部 `new OfflineDownloadStore(filesDir)` + 逐条文件系统校验），并可能同步 `saveDocument()`。全部运行在 UI 线程。
- 下载条目多或磁盘慢时即为用户观测的 10s 卡顿。
- 建议：reconcile 移入 TaskPool/async 队列，UI 先渲染 `store.load()` 快照，reconcile 完成后增量刷新；进度不阻塞进入。

## A2 强调色偏好只存不生效（P1 占位）

- 偏好定义：`AppearancePreferencesStore.ets` 仅存 `accentColor: emerald/ocean/rose/amber/mono`。
- 唯一消费者：`SettingsPage.ets`（选择器自身显示）与 `getAppearanceAccentColorValue()`（返回写死 hex）。
- 全端品牌色走 `ThemeConstants.BRAND_PRIMARY = $r('app.color.koma_accent')`（资源固定值），与偏好**零关联**。
- 判定：改强调色只改变设置页里自己的显示，全局不生效 = 占位实现。
- 建议二选一：a) 偏好写入 dark/base 资源或 AppStorage 主题桥，BRAND 系列改为随偏好；b) 若短期不接线，先从外观 pane 移除该行（诚实 UI）。

## A3 应用级深色/浅色设置缺失（P1）

- 证据：`resources/dark/element/color.json` 存在（被动跟随系统深色），但 `AppearancePreferences` 无 theme/darkMode 字段；外观 pane 仅 `theme`（阅读器主题）/`theme-color`/`language` 三行（SettingsPage.ets:197-201）。
- 判定：应用级深色开关未做（用户观测正确）。
- 建议：外观 pane 增加『深色模式』行（跟随系统/浅色/深色），实现走 `ApplicationContext.setColorMode`；同时盘点页面内写死 hex（如 ReaderTapZonePreview 的 #26... 系列、SOURCE_* 色值）补 dark 适配。

## A4 强调色选择器 UI（P1）

- 现状：设置页以普通行为列表呈现 5 个命名项，无色板图标（SettingsPage accent rows）。
- 参照：NextE `shared/components/AppColorPicker.ets` —— 色板网格 + HSV + Hex 输入（SegmentButtonV2 分模式），选中态直观。
- 建议：最低限度每行前加当前色圆形色板；或直接移植 AppColorPicker 作为强调色编辑器。

## A5+A6 阅读设置信息架构（P1）

- 现状：reader pane 20 行平铺（SettingsPage.ets:205-227）：page-mode/reading-direction/spread/background/scaling/page-number/fullscreen/animation/auto-page/preload/keep-awake/image-fit/tap-zone-preset/tap-zone-invert/page-gap/trim/wide-image/volume-key-nav/volume-key-behavior/reset。
- NextE 参照：阅读器有条漫(垂直)模式且行为独立（ReaderPage `isVerticalMode()`），模式相关设置随模式分离。
- 用户决策已给：条漫与分页模式设置分离；阅读器内设置只保留当前布局相关 + 公共设置。
- 建议：设置页 reader pane 按『通用（阅读方向/背景/音量键/重置）』与『分页模式（spread/tap-zone/page-gap/trim/animation/auto-page）』与『条漫模式（预留）』分组，按 page-mode 显隐；ReaderPage 内设置 sheet 同步按当前模式过滤。

## A7 备份与恢复（P2）

- 现状：`BackupManagementPage.ets`（1248 行）虽用 SecondaryListScaffold，但内容为 9 张自定义卡片纵向堆叠（Status/Encryption/Automatic/LocalBackups/Domains/ImportPreviewIntro/SelectedPreview/Actions/StorageNote，build:1206-1245），行内布局手戳、密度与全局列表语义不一致。
- 建议：按设置页 row 语义重构（状态行/开关行/动作行/列表行），加密与自动备份改标准 row+sheet；导入预览保留但样式对齐齐全局卡片。

## A8 关于 pane（P2）

- 现状：4 行（about/privacy-permissions/version/open-source，SettingsPage:270-277）。
- 待核（需设备截图）：各行动作是否为空、版本号数据源、开源页是否存在。判定为草稿态。
- 建议：版本行接 AppVersions；开源行为 License 页或外链；隐私权限行接真实权限清单页。

## A9 下载页 UI（P2）+ A1 关联

- 现状：QueueHeader 卡片 + 6 个 FlexWrap 筛选 chip + 行列表；设计语言与书架/浏览不统一。
- 建议：与 A1 一起重构（先修卡顿，后统一 UI）。

## A10 点击区域预览一致性（P2，待设备验证）

- 几何同源：设置页与 ReaderPage 均消费 `readerTapZoneRegions()`（ReaderTapZoneGeometry.ets:54）。
- 疑点：三处渲染器（SettingsPage.ReaderTapZonePreview:2551、ReaderPage.TapZonePreview:2831、ReaderPage 实际点击命中:2299）容器比例不同（设置页为固定方形预览，阅读页为真实视口），1/3 分区在不同宽高比下视觉形状不同；阅读方向/条漫模式对命中区的影响预览未体现。
- 动作：197 上对比设置预览与阅读页 overlay 截图后再决定是统一渲染组件还是调整预览容器比例。

## 附：其他排查中发现的静态疑点（待逐项确认）

- AppearancePreferences 无深色字段（见 A3）。
- 下载页 QueueMoreMenu 无『打开下载管理』以外的管理入口分类（入口命名与用户语言不一致，需定位标题串）。
- dark 资源仅覆盖 9 个颜色名，ThemeConstants 其余写死色值（如 ReaderTapZonePreview、SOURCE_* 状态色）在深色下未适配。

## 建议实施顺序

1. A1 下载卡顿（P0 性能，用户直接可感）。
2. A5+A6 阅读设置分离（用户已给设计决策）。
3. A2+A4+A3 强调色接线 + 色板 + 深色设置（同一片区域一次做完）。
4. A7 备份页重构、A8 关于页、A9 下载页 UI。
5. A10 设备对比后决定。

> 本文档为审计与计划，未包含任何代码改动。实施前按切片逐项走：基线截图 → 最小实现 → 真机验证 → 独立提交。

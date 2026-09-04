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
- 状态（2026-09-05 已修复）：进入先渲染 load() 快照，对账经 @Concurrent TaskPool 后台执行；197 实测 ~1.3s 内容完整渲染（20260904-downloads-entry-stall-fix-run1）。
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

## R1/R2 阅读器退化（用户报告，2026-09-05）

### R1 双击缩放动效丢失且闪缩放（P1）

- 现象：双击缩放直接跳变，无 180ms 动效，过程闪缩放。
- 已定位一半：双击路径 `beginZoomAnimation()` 置 `zoomAnimating`（180+24ms）门控 ReaderImage 的 `.animation` duration；routeTaps（webtoon/List）分支走 `commitContinuousTransformAfterAnimation` 延迟提交，其注释自认「committing it sooner remounts this row and cuts the reset animation short」——该提交管线存在重挂载裁切动画的前科。
- 动作：通读 ReaderPage 渲染管线（renderTransform/gesture scale/routeTaps 提交时序），修复后按录屏分帧验证动画连续。

### R2 页码指示器文字阴影缺失（P2）

- 现象：底栏页码文字无阴影。Koma 全代码库与 NextE feature/reader 均未检索到 textShadow——阴影出处待进一步定位（可能为早期版本或阅读器 chrome 其他属性），定位后补齐。

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
---
## 2026-09-05 全量补查（第二轮）

### 修正 A3：应用深色设置不是缺失，而是行为与标签不符（P1，加重）

- 外观 pane 的 `theme` 行存在菜单：系统/浅色/深色（SettingsPage.ets:2283-2286）。
- 但 `saveThemeMode(themeMode: ReaderThemeMode)` 只调 `applyReaderThemeMode`（SettingsPage.ets:1320-1323），消费方全部在阅读域（EntryAbility/ReaderPage/ReaderChrome/ReaderModeState）。
- 全项目无 `ApplicationContext.setColorMode` 调用 → 选『深色』只改阅读器背景，应用 UI（书架/设置/浏览）不变。
- 结论：设置存在但行为与标签不符，属误导性设置。修复方向：该行拆分为『应用主题』（接 setColorMode）与『阅读器主题』两行，或明确改名『阅读器主题』。

### 新增 A11：弹出菜单选项无前导视觉（P1）

- `SelectionMenuItem`（SettingsPage.ets:2257-2266）只有 content + 尾部勾选（symbolEndIcon），不支持前导图标/色板。
- 受影响菜单：主题色（5 个强调色无色点）、阅读背景（黑/灰/白/自动，可加色点）、翻页模式、阅读方向、语言等全部选择菜单。
- 全项目 13 个文件使用 bindMenu，选项视觉完备性需逐个核对。
- 参照：NextE 菜单项带前导视觉；平台 MenuItem 原生支持 prefixSymbol/symbolStartIcon。
- 动作：SelectionMenuItem 增加 leading 参数（色板圆点或 SymbolGlyph），主题色菜单传色点、阅读背景传色点。

### 新增 A12：全量扫查结果（第二轮）

- TODO/FIXME/占位 标记：全代码库无真实遗留标记（rg 命中均为 URI_placeholder 等资源名，非待办）。
- 页面结构：未审页面全部使用标准 scaffold，无空壳页 —— History(612 行)/Import(353)/SourcePackageManager(2583)/LibraryCategoryManagement(555)/TrackerSettings(965)。
- 阅读偏好消费链：ReaderPreferences 23 字段全部在 ReaderPage 有消费（volumeKeyBehavior=5 处、wideImageMode=4、pageGapMode=5、columnMode=9 等），无幽灵开关。
- 追踪器：AniList/MAL 客户端、OAuth、进度同步为真实网络实现 —— FEATURE_COMPARISON 中『Tracker 仅骨架』一行已过时，需更新该文档。
- 仍开放的功能域（对照 FEATURE_COMPARISON 未完成行）：系统通知投递、后台定时库更新、下载目录/重扫/系统下载通知、源生态兼容矩阵与签名信任、stats 统计页、深色资源覆盖面（ThemeConstants 之外的写死色值）。

### 遗留疑点（本轮新增，需逐项确认）

- SourceSearchPage 首位存在空 Column 占位 ListItem（:291-292），用途与高度需核实是否为 bottomBuilder 补偿（若是，应注释并常量化）。
- 下载页『下载管理』入口命名与用户语言不一致（QueueMoreMenu 仅重试/清理/重扫），标题串未定位到『下载管理』字样，需设备确认用户所指入口。
- ReaderPage 内嵌 TapZonePreview（:2831）与设置页预览的容器比例差异（A10 关联）。
---

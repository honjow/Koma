# Koma 三线对标路线图：NextE（架构）× Aidoku（功能/路由）× Mihon（优点吸取）

日期：2026-09-05  
基线：master a21b5e8  
定位（产品主旨）：脚手架与组件层基于鸿蒙、参考 NextE；页面路由架构与功能层面对标 Aidoku；额外优点吸取安卓多源阅读器（Mihon 系）。不内置源、不做源市场。

## 一、NextE 线：架构 / 脚手架 / 组件

### 已对齐

- PullRefresh 系列 scaffold（List/Grid/WaterFlow 思路一致）、SecondaryListScaffold、ConciseListRow、GroupedListSection。
- HDS 标题栏 bottomBuilder 字段 + dynamicHideTitleBar(SCROLL_UP) + bindToScrollable（本次源浏览搜索已接入）。
- responsive 网格列数推导（utils/GridColumns，单源推导）。
- LayoutSafeArea 桥、路由本地 chrome 状态（SourceRouteChromeState）。

### 可继续借鉴（NextE shared 组件，按 Koma 需求排序）

| NextE 组件 | Koma 用途 | 关联缺口 |
|---|---|---|
| AppColorPicker | 强调色编辑器（色板网格/HSV/Hex） | 审计 A4 |
| AppMenuOptions / 菜单前导视觉 | 选择菜单色板/图标 | 审计 A11 |
| MarkdownContent + ReleaseNotesPager | 关于页/版本说明渲染 | 审计 A8 |
| LoadingFooter | 列表加载尾 | 下载/浏览分页 |
| AdvancedSearchControls | 源搜索高级过滤 UI | 搜索质量 D53 |
| CategorySelector | 分类选择器 | 分类深化 D45-46 |
| ImmersiveTitleBar | 沉浸式标题（阅读器外页） | UI 打磨 |
| InlineEditRow | 行内编辑（分类重命名等） | D46 |
| SectionHeader / PageState | 分区头/页面状态语义化 | 全局一致性 |

注意：逐个引入前先读实现并按 Koma 主题系统适配；不做无脑复制。

## 二、Aidoku 线：路由 / 功能对标

### 路由结构对比

 - Aidoku 主结构：Library / Browse / Search / History + More（凭印象记录，未核实，采纳前需对照官方资料）。
- Koma 现状：书架 / 浏览 / 历史 / 设置 四 tab；全局搜索页存在（跨源），但无独立搜索 tab（搜索入口在浏览页与书架）。
- 决策点：是否升格全局搜索为独立 tab（Aidoku 式），或维持浏览页内搜索 + 全局搜索页路由（现状）。需结合源数量增长决策。

### 功能差距（核对 APP_GAP_PLAN D33-D57 后的当前状态）

| 计划项 | 状态（本次核对） |
|---|---|
| D33 下载目录与本地章节索引 | 开放（下载页重构关联） |
| D34 离线 Reader QA | 部分（离线路径存在，矩阵 QA 未做） |
| D35 下载通知与权限态 | 开放（无系统通知投递） |
| D36-D37 Library update 状态机/私有库刷新矩阵 | 前台新章检查已有；后台调度未做 |
| D38 系统通知投递 | 开放 |
| D39 宽图拆分 | 宽图旋转已有，拆分未做 |
| D40-D41 Reader interaction/QA matrix | 交互设置已有；QA 矩阵未做 |
| D42-D44 Local source 化 | 本地导入有；文件夹规范/重扫/元数据未做 |
| D45-D46 分类深化 | 轻量版本已有；筛选维度/批量 UX 深化开放 |
| D47-D49 备份完整化 | 本地导入导出+自动备份偏好有；管理列表/跨设备恢复 QA 开放 |
| D50-D52 Tracker | **重大进展**：AniList/MAL 客户端、OAuth、进度同步已实现（对比文档已过时）；Kitsu 等未做 |
| D53 搜索质量 | 跨源搜索骨架已有；质量/过滤深化开放 |
| D54 章节元数据 | 部分（缺 scanlator/多语言组） |
| D55-D57 发布工程化 | i18n 基线（zh/en）、隐私/发布文档、release lane 未收口 |

### Aidoku 特有能力 Koma 尚无（逐项评估）

- 源浏览 filters 面板的完整度（Koma 有基础 filters，深度对照 Aidoku 源页待设备对比）。
- Library 未读/下载数角标（Koma 有进度徽标，无数量角标）。
- iCloud 级自动云备份（Koma 本地自动备份偏好已有；云通道未做——HarmonyOS 对应可评估）。

## 三、Mihon 线：可吸取的优点（本次验证全部缺失）

| 能力 | 状态 | 建议 |
|---|---|---|
| 无痕阅读（incognito：阅读/历史不计入） | 缺失 | Reader 偏好 + 会话级开关，历史写入处旁路 |
| 应用锁（生物识别/启动锁） | 缺失 | 系统用户认证 API，设置页安全分组 |
| 源迁移（保留进度换源） | 缺失 | 依赖源搜索 + 映射（TrackerMappingSearchService 思路可复用） |
| 阅读统计页（时长/章节数/活跃度） | 缺失 | 需先补阅读会话统计埋点 |
| 自动下载规则（新章自动下载：分类/来源/上限/WiFi 条件） | 缺失 | 依赖 D36 update state machine + 下载队列 |
| 章节下载数角标 | 缺失 | 书架卡片角标层 |
| Data saver（图片代理压缩） | 缺失（依赖外部服务，优先级低） | 后置 |
| 每作品覆盖设置（per-series overrides） | **已有**（reader.seriesOverrides.v1） | 可继续深化 |

## 四、占位/毛坯清单

见 docs/UI_IMPLEMENTATION_AUDIT.md（A1-A12，含第二轮修正）：下载入口 P0 卡顿、强调色偏好未接线、应用深色误导性设置、菜单无前导视觉、阅读设置未分离、备份/关于/下载页 UI 债。

## 五、建议路线（结合 D 计划重排）

1. **P0 修正**：下载进入卡顿（A1）→ 搜索框遮挡已修（本次）→ 审计文档 A3 深色误导设置拆分。
 2. **阅读主线**：条漫/分页设置分离（A5/A6）→ 宽图拆分（D39）。
3. **下载与通知**：下载目录/索引（D33）→ 通知投递（D35/D38）→ 自动下载规则（Mihon）。
4. **外观系统**：强调色接线 + AppColorPicker（A2/A4）→ 应用主题 setColorMode（A3 修正）→ 深色资源覆盖补全。
5. **Aidoku 对标深化**：全局搜索 tab 决策 → 源 filters 深化（D53）→ 章节元数据（D54）。
6. **安全与隐私**：无痕模式 → 应用锁。
7. **发布线**：i18n 补全 → 隐私/权限文档 → release lane（D55-57）。

> 每项实施依旧按：基线截图 → 最小实现 → 真机验证 → 独立提交。

# Koma vs Aidoku vs Mihon 功能对比

更新时间：2026-05-27
Koma 基线：`master` / `1269199` 后续实现

## 证据来源

- Koma：当前仓库代码、`docs/FEATURE_PROGRESS_20260524.md`、`docs/ROADMAP.md`、最近 master 提交。
- Aidoku：官方 README 与官网帮助文档。
  - README 明确列出：no ads、robust WASM source system、online reading through external sources、downloads、AniList/MyAnimeList tracker。
  - Getting Started 明确列出：安装 source、`.aix` 外部 source package、source list、加入 library。
  - Backups 文档明确列出：创建、导出、导入、恢复、重命名/删除备份。
- Mihon：官方 README 与官网文档。
  - README 明确列出：local reading、configurable reader、tracker、categories、themes、scheduled library updating、backups。
  - Getting Started 明确列出：local source、external repositories、manual extensions、global search。
  - Reader settings 文档明确列出：reading mode、tap zones、crop borders、split/rotate wide pages、scale type、volume keys 等。
  - Backups 文档明确列出：library/tracking/settings/source settings、automatic backups、cloud-sync suggestion。
  - Tracking 文档明确列出：MAL/AniList/Kitsu/MangaUpdates/Shikimori/Bangumi；Komga/Kavita enhanced services。

## 总体判断

Koma 不是完成态。当前是 **HarmonyOS 私有/本地优先漫画阅读器的功能骨架 + 可跑通的 source runtime E2E**：

- 本地导入、私有库、Reader、source URL index、MangaDex source runtime 到 Reader 图片已跑通。
- 漫画源生态不作为 Koma App 本体缺口处理；source index/package/真实漫画源维护放在独立仓库 `/Users/honjow/git/koma-sources`。
- App 本体剩余关键系统缺口见 `docs/APP_GAP_PLAN_AIDOKU.md`：下载增强、自动更新/通知、tracker、更多 reader 设置、本地库重扫、完整备份管理、release readiness。

## 功能矩阵

| 功能域 | Koma 当前状态 | Aidoku | Mihon | Koma 差距 / 下一步 |
| --- | --- | --- | --- | --- |
| 平台 | HarmonyOS NEXT 原生 ArkUI；bundle `com.honjow.koma` | iOS / iPadOS | Android 8+ | 平台差异化成立；HarmonyOS 组件/安全区/设备行为仍需持续真机验证。 |
| 产品边界 | 私有漫画书架 + 阅读器；不内置源、不源市场、不宣传聚合 | 在线阅读 + WASM/external source system | 本地 + 扩展源；官方不提供内容 | Koma 边界更保守，适合上架；功能补齐不能走内置源市场路线。 |
| 本地漫画 | CBZ/ZIP 导入；多图片导入；导入后入书架 | 当前官方资料重点是 external sources，不是本地目录主线 | Local source：固定目录结构、文件夹/zip/chapter 结构 | Koma 已有导入，但缺 Mihon 式 local source 文件夹规范、重扫、元数据识别。 |
| 书架 Library | 网格、继续阅读、历史、排序/过滤、移出、Favorite/Read Later 与用户自定义分类过滤、批量分类增删、自定义分类管理/排序、分类专属排序/阅读状态显示策略 | Library + bookmark/add to library | Library + categories + filters | 分类显示策略已有轻量版本；仍缺更多筛选维度。 |
| 阅读器模式 | 单页、连续/Webtoon、双页、RTL 双页、沉浸 chrome、图片适配、点击翻页、页面间距、非裁剪收紧页边、宽图旋转、音量键翻页 runtime | 可在线/下载阅读；当前官方 README 未细分 reader 设置 | 多 viewer、阅读方向、paged/long strip、大量 reader settings | Koma 基础 reader 已成；仍缺宽图拆分、更多背景/手势设置和异常比例图片矩阵 QA。 |
| 阅读进度 | 本地进度持久化；History；Komga progress pull/push | tracker 集成 | 本地进度 + tracker 更新；Komga/Kavita enhanced services | Koma 有 Komga 方向，但无 MAL/AniList/Kitsu 等公共 tracker。 |
| 私有库 | Komga / OPDS / WebDAV 已接入；Browse/Reader/favorites/部分进度同步 | 主要 source 系统 | Komga/Kavita enhanced services；更多 tracker 生态 | Koma 私有库方向强，但需要 NAS/WebDAV、OPDS 1/2、Komga auth/大库兼容性矩阵。 |
| 在线/自定义源 | WAMR source runtime；URL index 导入 `.koma`；MangaDex E2E 已到 Reader 图片；source author SDK 文档 | Robust WASM source system；`.aix` 外部 source；source list | Extension repos + APK extensions + manual extensions | Koma 架构接近 Aidoku 思路；仍缺真实源生态、源开发工具、签名/信任策略、错误恢复、更多真实源兼容。 |
| Source 安装路径 | 用户输入 URL index → 列表 → 下载 `.koma` → install/enable；本地 picker fallback；已安装源更新状态/能力摘要 UX | 内置/外部 source、`.aix` 导入、source list URL | Extension repos + install extensions | Koma URL index 主路径已做；下一步是签名/信任、源升级完整真机 QA、兼容矩阵。 |
| Source 设置 | 支持 source `get_settings` descriptor、非敏感 settings 持久化/backup 注入 | 当前摘录未确认设置细节 | backup 包含 source settings | Koma 有底层能力；真实 installed source 的设置 UI 仍需完整 device QA。 |
| 下载离线 | Reader remote image cache + LRU + prefetch；下载队列 MVP；Settings 下载管理页；MangaDetail 批量下载；队列过滤/批量重试/清理；前台队列暂停/继续；前台并发上限偏好 | README 明确支持 Downloads | 下载队列、下载目录、重扫下载、并发策略 | 已有前台队列骨架与基础暂停/并发控制；仍缺系统后台下载、真实下载通知、下载目录/重扫、完整离线 reader QA。 |
| 图片缓存 | Remote image cache、LRU、prefetch、设置页清理 | downloads 能力明确，缓存细节未摘录 | 下载/缓存成熟 | Koma 缓存只是 reader image cache，不等价于离线下载。 |
| 搜索 | Cross-source search：local / Komga / OPDS / WebDAV / wasm sources，超时隔离，持久化搜索历史，按源展示 pending/running/empty/timeout/failed/unsupported 状态 | 源内搜索 | Global Search across sources | Koma 有全局搜索雏形；需结果质量、过滤、多源真实数据矩阵。 |
| 详情页 | 真实 source detail、章节、收藏、开始阅读、章节筛选、章节 read/unread 操作 | 源内容详情 + add library | series detail + add library + tracking/downloads | 仍缺 scanlator/group、多语言版本、更完整的章节元数据操作。 |
| History | 真实阅读历史，点击恢复 | 当前摘录未确认 | 有历史/最近阅读类能力 | Koma 基础可用；缺清理、分组、跨设备同步。 |
| 备份 | Schema v3：library/progress/remote servers/source packages/source settings/reader settings；本地导入导出 | 创建、导出、导入、恢复、重命名/删除 | library/tracking/settings/source settings；自动备份；云同步建议 | Koma 有备份核心；缺自动备份、备份管理列表、加密/敏感字段 UX、跨设备恢复 QA。 |
| 设置 | Komga/OPDS/WebDAV、reader prefs、theme、backup、about/license/source manager/cache clear | settings + backups | reader/download/library/tracking/storage 等大量设置 | Koma 设置功能化已开始，但深度远低于 Mihon。 |
| 分类 Categories | Favorite / Read Later 与用户自定义分类过滤；多选批量 add/remove 多分类；Settings 分类管理支持创建/重命名/删除/上移下移排序；支持为全部/未分类/内置/自定义分类保存排序与阅读状态显示策略 | 当前摘录未确认 | 明确支持 categories，多分类、批量设置 | 已有轻量分类显示策略；后续可补更多筛选维度与视图模式。 |
| Tracker | 本地-only tracker 设置骨架，无 MAL/AniList/Kitsu 等真实账号同步 | README：AniList、MyAnimeList | MAL/AniList/Kitsu/MangaUpdates/Shikimori/Bangumi；一向同步，离线后同步 | 可后置，但对标成熟 reader 必须有。 |
| 自动更新库 | 前台 source-runtime 新章检查、app-open due-check 偏好、最新结果持久化、失败退避；未做后台调度 | 当前摘录未确认 | Scheduled library updates | 缺后台定时/系统调度、私有库刷新矩阵。 |
| 通知 | 书架更新有通知就绪摘要与失败码脱敏持久化；暂无系统通知投递 | 当前摘录未确认 | 下载/更新/错误通知成熟 | 缺新章/下载完成/失败的真实系统通知与权限态 QA。 |
| 章节下载队列 | 前台下载队列 MVP、状态过滤、批量重试/清理、MangaDetail 单章/可见章节批量下载；source-backed 可见章节批量下载会逐章 hydrate pages；Settings 可暂停/继续前台队列并设置前台并发上限；离线 Reader 路径存在 | Downloads | Download queue | 仍缺系统后台下载、真实下载通知、下载目录/重扫、完整 source 离线 reader 真机 QA。 |
| 扩展/源安全 | `.koma` archive validator、WAMR sandbox、host imports、fail-closed 测试 | WASM source system | Android extension APK，有恶意扩展风险提示 | Koma 技术路线更安全；仍缺用户可理解的权限提示、source capability UI、签名/信任策略。 |
| UI 成熟度 | Aidoku 风格骨架；安全区持续修；功能优先 | iOS 成熟交互 | Android/Material 成熟 | Koma UI 可用但未 polished；当前策略应继续功能优先，只修 blocking UI。 |
| i18n | 未见完整多语言资源体系 | Weblate translations | Weblate translations | Koma 缺 i18n，对上架有影响。 |
| 数据迁移 | backup schema 有 v1/v2/v3 兼容 | backup restore | fork-compatible backup restore | 需要正式 migration/version policy。 |
| 发布成熟度 | debug 构建/签名/安装稳定；release 未作为本轮主线 | TestFlight/AltStore/manual IPA | stable/beta APK | 未 release-ready：隐私文案、图标、crash/log、权限说明、性能矩阵未收口。 |

## 优先级建议

按“功能差距最大 + 对首版价值最大 + 不破坏上架边界”排序：

1. **下载队列 / 离线章节增强**
   - 对标 Aidoku Downloads、Mihon Downloads。
   - 已有：前台队列、状态、失败重试/删除、Settings 下载管理入口、MangaDetail 可见章节批量下载、队列过滤/批量重试/清理、前台暂停/继续、前台并发上限。
   - 仍需：系统后台下载、真实下载通知、下载目录/重扫、离线 reader 完整真机 QA。

2. **Library categories / 批量管理增强**
   - 对标 Mihon categories。
   - 已有：Favorite / Read Later 与用户自定义多分类归属、批量增删、分类过滤、Settings 分类创建/重命名/删除/排序、分类专属排序/阅读状态显示策略。
   - 仍需：更多筛选维度与视图模式。

3. **Reader 高级设置增强**
   - 对标 Mihon reader settings。
   - 已有：tap navigation 开关、非裁剪 fit-width/fit-screen、页面间距、非裁剪收紧页边、音量键翻页 runtime、宽图旋转、屏幕常亮、进度显示开关。
   - 仍需：宽图拆分、更多背景/手势设置、异常比例图片矩阵 QA。

4. **自动更新 / 通知**
   - 对标 Mihon scheduled library updates。
   - 需要：私有库/source 新章检查、前台/后台策略、通知、失败退避。

5. **Tracker**
   - 对标 Aidoku AniList/MyAnimeList、Mihon 多 tracker。
   - Koma 主打私有/本地，tracker 可后置；但成熟 reader 最终需要。

## 不建议优先做

- 内置源市场：违反 Koma 上架边界；漫画源生态维护放在 `/Users/honjow/git/koma-sources`，不纳入 Koma App 本体缺口排序。
- 继续大面积 UI polish：当前功能缺口更大；只修 blocking 安全区/可用性问题。
- 公共 tracker 先行：对 Koma 私有/本地定位不是第一价值点。
- 复杂云同步：先把本地备份、下载、分类、自动更新做好。

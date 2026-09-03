# Koma 全局架构、UI 规范与功能缺口系统审计及整改方案

- **日期**：2026-09-04
- **当前状态**：AUDIT COMPLETE / AWAITING USER REVIEW
- **测试与验证基准设备**：`192.168.50.103:12345` (Huawei MatePad Pro 11-inch, `MLR-AL00`)
- **对标规范与工程参考**：HarmonyOS NEXT HDS 设计规范、`/Users/honjow/git/NextE` 已验证实现、Aidoku / Mihon 架构蓝本

---

## 一、 审计背景与核心痛点归纳

在近期的实机体验与开发反馈中，Koma 暴露出了一系列影响体验的核心问题，主要集中在以下五大维度：
1. **冷启动卡顿严重**：启动时主界面白屏/骨架屏停滞达 10 秒，加载动画完全冻结，未能平滑呈现书架内容。
2. **漫画详情页状态机混乱**：点进漫画详情页频繁闪白并重走空白加载；若已有书籍或已存缓存，重复进入依然被强制抹除；点击阅读会私自入库（破坏用户意图）；章节列表存在不规范的四方块伪按钮、排序部分失效、排版生硬。
3. **全屏阅读器顶底栏呼出时序跳变**：全屏下中心轻触呼出顶底栏时，顶栏先出现、状态栏随后出现，导致顶栏出现剧烈的垂直位置跳变；顶栏标题居中且被限制 54% 宽度，信息易截断。
4. **阅读器缩略图栏性能与几何缺陷**：每次重新呼出缩略图都会全量重新加载；第一张缩略图与后续缩略图的间距不一致；圆角与边框层叠裁剪不自然。
5. **UI 组件与半模态规范不一致**：部分半模态标题间距过大；关闭按钮位置不符合语义规范；容器底色存在微小差异（如书架与设置/历史底色不一致）。

---

## 二、 深度根因分析与对标解决方案

### 1. 冷启动 10 秒卡顿与主线程阻塞 (Cold Start Freeze)

#### 1.1 现象重现与测量
- 用户启动应用后，主界面挂在 `LoadingProgress` 上，界面冻结约 10 秒，甚至连 `LoadingProgress` 的旋转动画都卡住不动，随后书架才突然刷出。

#### 1.2 静态代码根因
1. **启动关键路径严重受阻**：
   - `EntryAbility.onWindowStageCreate` 在 `loadContent` 回调中立即无条件执行 `this.syncRemoteProgressInBackground()`。该方法若涉及远程库或未决网络同步，会发起网络等待（可能耗费数秒甚至达 10 秒超时），并且在主线程执行加密/文件反序列化。
   - `Index.aboutToAppear` 在同一个启动时序中，同步调用 `bootstrapSourceRuntimeAppRegistry(context)` 遍历扫描所有本地 WASM 插件包（同步读取 WASM 字节与计算哈希），紧接着又无条件执行 `this.triggerAutomaticBackup(context)`（启动备份归档压缩）和 `this.triggerPendingTrackerProgressSync(context)`。
2. **书架页过度阻塞渲染 (Artificial Pending Gate)**：
   - `LibraryPage.aboutToAppear` 初始将 `projectionState` 设为 `PENDING`，只要它处于 `PENDING`，页面就展示全屏 `LibraryProjectionLoading()`。它必须等待 `LibraryFilterStore.load()` 从 Preferences 异步读回配置。当 Preferences I/O 排在上述重型文件/网络操作队列之后时，书架就被强行白屏阻断长达数秒。

#### 1.3 对标 NextE 方案与整改措施
- **首屏临界路径拆分（Critical Path Split）**：
  参考 NextE（`347033e9`）：
  - 窗口创建与首帧前：仅做最小必要配置读取（语言、主题模式、首帧布局避让区），**禁止发起任何后台网络同步、备份归档或非关键插件全量扫描**。
  - 首帧呈现后延迟执行：引入 `DEFERRED_STARTUP_DELAY_MS = 250ms`，通过 `setTimeout` 在首屏渲染完成之后，再延后调度执行后台备份检查、Tracker 同步及远程库轮询。
- **书架投影状态去阻塞**：
  - `LibraryPage` 首帧直接以内存中的书架快照渲染（若为空则显示轻量空白引导，若有书则直接渲染首屏列表），不再全屏挂起 `PENDING` 遮罩；Preferences 异步加载完成后仅做静默的过滤策略更新。

---

### 2. 漫画详情页状态机与交互规范 (MangaDetailPage & Chapter List)

#### 2.1 现象与问题
1. 从列表进入详情页，即便已有本地缓存或已有书籍，总是先抹成空白骨架屏，然后再慢吞吞刷新出内容，封面也会出现白块跳变。
2. 点击“开始阅读”或阅读具体章节，后台会私自将未收藏的漫画加入书架。
3. 章节排序选项中，“最新优先/最旧优先”在很多源漫画上完全没有反应，只有“按话数升序/降序”会变动。
4. 章节列表右侧充斥着四个小方块（`sys.symbol.dot_grid_2x2`）伪按钮，语义不明，功能单一（仅仅是标记已读未读弹窗），破坏整体界面的干净程度。
5. 章节列表项只挂了文字区域点击，整行交互不流畅。

#### 2.2 静态代码根因
1. **状态被盲目重置抹平**：
   - `MangaDetailPage.loadSourceMangaDetail` 开头执行了 `this.sourceDetailContentState = LOADING; this.manga = undefined`。即使该漫画在 `libraryStore` 中早已存在完整的标题、封面、章节信息，也会瞬间被清空，造成“先白后显”的强烈跳变。
2. **静默越权写入书架 (Implicit Upsert Bug)**：
   - `SourceChapterPageHydrator.applyPages`（阅读器请求章节图片描述符时）直接执行了 `this.libraryStore.upsertComic(comic)` 和 `upsertComicAndPersistLibraryStore`。这导致用户纯粹想点击试读某一章节时，系统却在底层强行把漫画存进了持久化书架！
3. **日期排序逻辑缺陷**：
   - `compareByDate` 在 `left.dateUpload === undefined && right.dateUpload === undefined` 时直接返回 `0`。绝大多数常见漫画源（如 Mangabz、DM5 等）并不提供章节上传时间戳，导致“最新/最旧”两项彻底成为空操作。
4. **控件滥用与不当外露**：
   - 章节列表项没有遵循 HDS / Aidoku 规范的整行触发逻辑，而是给每个章节行右侧挂了 `dot_grid_2x2` 图标按钮，并弹出一个仅有两个选项（标为已读/标为未读）的小菜单。章节区域顶部同样放置了一个 `dot_grid_2x2`。用户根本无法识别该图标的用途。

#### 2.3 对标与整改措施
- **详情页两级缓存与非侵入式加载**：
  1. 进入页面时，优先查询 `libraryStore` 或内存级 `sourceMangaDetailSnapshotCache`；若已有数据，**立即渲染 Header、封面与已存章节**。
  2. 网络请求在后台异步进行，不销毁现有界面；加载过程中仅在局部提供轻量加载反馈（如刷新状态或章节顶部指示），彻底消除白屏与封面重载跳变。
- **阅读行为与书架行为严格解耦**：
  - 修复 `SourceChapterPageHydrator.applyPages`：增加判定条件 `this.libraryStore.getComic(comic.id) !== undefined`。**只有当漫画已被用户主动加入书架时，章节数据才更新回书架持久化存储；未加入书架的漫画，仅更新内存 Session 与阅读历史（History），绝不污染书架。**
- **章节排序精简为“升序 / 降序”**：
  - 废弃失效的基于空日期的排序，直接对齐漫画阅读器标准体验：
    - **升序**（正序，第 1 话在最前）
    - **降序**（倒序，最新话在最前）
    - 排序依据严格按话数 `chapterNumber`，缺失话数时按源初始章节索引兜底。
- **规范章节列表布局与消除伪按钮**：
  - 移除每一个章节行右侧莫名其妙的 `dot_grid_2x2` 按钮。
  - 章节行整行作为点击热区，直接触发阅读；右侧仅保留下载图标/状态标记（未下载显示下载图标，已下载显示已完成标记）。
  - 已读/未读状态通过章节标题颜色（已读呈现次级弱化灰色）清晰表达；长按章节行可呼出标记已读/未读的轻量上下文菜单。
  - 章节列表区域顶部的批量操作按钮，使用规范的系统图标（如批量下载 `sys.symbol.arrow_down_to_line`），避免自创四方块图标。

---

### 3. 全屏阅读器顶底栏呼出时序与状态栏跳变 (Reader Full-Screen Chrome Transition)

#### 3.1 现象与根因
- **跳变现象**：全屏阅读时轻触屏幕中央呼出控制条，顶栏和底栏先以顶部 0 坐标瞬时挂载，之后系统状态栏才被唤起，导致顶栏内容突然向下跳动约 38vp，视觉体验极为粗糙。
- **核心根因**：
  1. `EntryAbility.ets` 中的 `publishAvoidHeights` 只测量了 `window.AvoidAreaType.TYPE_SYSTEM`，完全忽略了 `window.AvoidAreaType.TYPE_CUTOUT`（硬件挖孔/刘海避让区）。
  2. 当阅读器全屏隐藏状态栏时，系统回报 `TYPE_SYSTEM.topRect.height = 0`，Koma 的全局 `topAvoidHeight` 随之被写入 0！
  3. 当用户点击屏幕唤起控制栏时，`chromeShown = true` 立即执行，顶栏读取到的 `topAvoidHeight` 仍是 0，于是顶栏紧贴屏幕顶端渲染；数百毫秒后异步的 `setSpecificSystemBarEnabled('status', true)` 生效，系统分发避让区变更，`topAvoidHeight` 骤增到 38vp，顶栏便产生明显的“掉落跳动”。
- **对标 NextE（`feature/reader/src/main/ets/pages/ReaderPage.ets` & `EntryAbility.ets`）**：
  - NextE 的避让区计算公式为：
    `top = Math.max(topHeight(TYPE_SYSTEM), topHeight(TYPE_CUTOUT))`
  - 在挖孔屏设备（包括当前的 103 平板）上，即便系统状态栏隐藏，`TYPE_CUTOUT` 的高度依然固定存在（~38vp）。
  - 因此，`topAvoidHeight` 在全屏阅读期间**永远不会塌陷为 0**，当呼出控制条时，顶栏早已在正确定位处就位，与状态栏的显示时序无缝融合，**彻底根治跳变**。
- **顶栏布局优化**：
  - 原先顶栏将漫画名和话数信息塞入一个 `Stack(Alignment.Center)`，硬编码 `width('54%')` 强行居中，长标题截断严重且不符合阅读器习惯。
  - 整改为标准 Row 流式排布：
    - 左侧：返回圆形按钮（44x44）
    - 中间：`Column`（`layoutWeight(1)`，自然向左对齐），第一行漫画标题支持最多 2 行自适应排版，第二行紧凑展示当前页码与话数（页码在前，话数在后自动占满剩余空间，超出打点）
    - 右侧：设置按钮与更多操作按钮。

---

### 4. 阅读器缩略图栏性能与几何规格 (Reader Thumbnail Strip)

#### 4.1 现象与根因
- **每次打开都重新经历加载**：
  - `ReaderChrome.ets` 中写了 `if (this.thumbStripVisible && this.thumbnailStrip)`。当缩略图栏收起时，整个缩略图 List 被从组件树上卸载。每个缩略图 Tile 的 `aboutToDisappear` 被触发，强制清空了 `pixelMap` 并释放租赁；下次再点开时，全部重新走异步解码与文件 I/O，造成每次展开都要白一块再刷出。
- **首尾项与邻近项间距不等**：
  - `ReaderThumbnailStrip` 在 `ListItem` 上单独写了 `.margin({ left: index === 0 ? ThemeConstants.SPACE_LG : 0 })`，该 margin 与 List 容器自身的 `space: ThemeConstants.SPACE_SM` 发生重叠，导致第 1 张与第 2 张的间距明显不同于后续图片的间距。
- **圆角与边框层叠错乱**：
  - 缩略图外层 Stack 设置了 `borderRadius` 和 `border`，内部 Image 也设置了 `borderRadius`，由于层级和裁剪原因导致图片部分边缘溢出或圆角被切角。

#### 4.2 对标 NextE 实现方案
- **保持列表常驻挂载，依靠外层高度裁剪做显隐动画**：
  - 参考 NextE（`ReaderPage.ets:4490`）：List 组件保持挂载，外层包裹 Column 容器，通过高度 `this.showThumbStrip ? THUMB_HEIGHT : 0` 和 `.clip(true)` 实现无缝展开/收起。收起时不销毁组件、不释放当前会话的缩略图 PixelMap，再次点开即刻立显。
- **统一列表水平内边距**：
  - 移除 ListItem 上的条件 margin，直接在 List 容器上设置标准的 `padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })`，列表内部所有项均由统一的 `space` 保证完全等距。
- **几何层级规范**：
  - 缩略图卡片由外层容器统一定义宽高与 `borderRadius`，内层使用 `ImageFit.Contain` 或标准 `ImageFit.Cover` 并配合外层统一 `clip(true)`，外层聚焦高亮边框使用 `2vp` 标准品牌色边框。

---

### 5. 半模态脚手架与全应用 UI 规范统一 (Half-Modals & Visual Harmony)

#### 5.1 审计发现
1. **书架导入全屏页面已成功整改为原生下拉菜单**：
   - 彻底移除了原本空荡全屏仅有 3 个选项的 `ImportPage` 路径，改为在书架右上角 `+` 按钮下挂原生 HDS 下拉菜单，直接唤起文件/图片/文件夹选择器，流程缩短 100%。
2. **半模态顶部异常留白**：
   - `KomaModalScaffold` 内部使用了 `HdsNavigation`，在 `HdsNavigationTitleMode.MODAL` 模式下，系统自带标准模态标题栏（高度 56vp）。
   - 代码中部分页面在 `content` 内部又塞入了多余的 `Blank().height(...)` 或 `padding({ top: ... })`，形成了双重空白；且 `scrollEffectOpts` 未禁用，导致滑动时模糊采样到半模态外部的底色。
3. **半模态关闭按钮逻辑规范**：
   - 严格遵循 HDS 规范：
     - 单操作半模态（无“确定/取消”双重按钮的展示类、设置类 Sheet）：关闭按钮统一置于右上角菜单（`menu`），或直接使用 `bindSheet` 自身的系统关闭控制；
     - 包含“确定/完成”与“取消”的双操作半模态：左侧放置取消/关闭，右侧放置确定。
4. **容器底色与组件统一度**：
   - 全应用列表脚手架（`SecondaryListScaffold`、`PullRefreshListScaffold`）统一绑定 `sys.color.ohos_id_color_sub_background`。
   - 所有搜索框均已在上一轮整改中收敛至标准 `KomaSearchField`。

---

## 三、 执行规划与切片验收队列

本方案严格遵守 `docs/agent-guides/koma-rules.md` 的切片纪律：
- 每一个模块形成独立、最小范围的 diff；
- 每次修改必须在 103 真机上完成构建、安装、交互操作与截图证据留存；
- 不跨模块发散，不混合无关重构。

| 序号 | 任务切片 | 核心目标 | 涉及文件 | 验收标准 (103 设备) |
| :--- | :--- | :--- | :--- | :--- |
| **P1** | **冷启动阻塞优化** | 拆分启动关键路径，后台同步与备份延迟 250ms 调度，移除书架首屏强阻断 Pending | `EntryAbility.ets`, `Index.ets`, `LibraryPage.ets` | 冷启动无 10s 卡顿，书架首屏即开立显 |
| **P2** | **全屏阅读器顶底栏跳变与避让区修复** | `EntryAbility` 避让区并入 `TYPE_CUTOUT`；重构阅读器顶栏为非居中流式布局 | `EntryAbility.ets`, `ReaderChrome.ets`, `ReaderPage.ets` | 全屏阅读轻触唤出顶底栏，顶栏位置平滑无跳动，长标题清晰对齐 |
| **P3** | **阅读器缩略图栏性能与几何间距** | 缩略图栏改为常驻挂载+容器高度裁剪；统一 List 内边距消除首图间距异常；修正圆角层级 | `ReaderChrome.ets`, `ReaderPage.ets` | 二次呼出缩略图栏秒开无闪烁，所有缩略图间距完全等宽 |
| **P4** | **漫画详情页缓存与阅读解耦** | 详情页进场优先渲染已存书籍/快照；移除阅读时暗中加书架逻辑；精简章节排序为正序/倒序；清除章节行伪按钮 | `MangaDetailPage.ets`, `SourceChapterPageHydrator.ets`, `ChapterListSection.ets` | 点进漫画无闪白与封面重置；阅读不污染书架；章节列表干净整洁 |
| **P5** | **半模态脚手架规范化** | 消除模态顶部双重留白；规范关闭按钮位置；统一背景模糊配置 | `KomaModalScaffold.ets`, 相关 Sheet 实现 | 半模态贴合紧凑，标题与内容间距自然 |


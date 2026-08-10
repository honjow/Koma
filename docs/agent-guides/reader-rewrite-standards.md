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

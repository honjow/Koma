# Koma Agent Rules

Always-loaded rules for Koma. Open relevant per-task docs (`docs/PRODUCT_PLAN.md`, `docs/ROADMAP.md`, `docs/CONTROLLER_ARTIFACTS.md`) for scope-specific guidance.

## Session Focus

本会话主攻**应用侧功能开发**。以 Aidoku (iOS manga reader) 为蓝本搭建完整 App 框架。

## Execution Discipline

路线图不是背景资料，必须作为执行约束使用。开始任何非平凡任务前，先对照 `docs/APP_GAP_PLAN_AIDOKU.md` 和 `docs/ROADMAP.md`，明确当前动作服务哪个最高优先级用户闭环。

功能完成状态以 `docs/FEATURE_GATES.md` 为准，不以聊天承诺、旧路线图文字或脑内判断为准。每次用户可见功能提交必须绑定一个 active gate；`ACCEPTED` gate 默认冻结，除非先登记 `REOPENED` 原因并留下证据。不得反复重写已验收范围来假装推进。

### Trust Reset / Evidence Gate

口头承认、聊天承诺、计划文字、静态推理都不算约束。以下规则是 Koma 开发的硬门槛：

- 凡是用户可见功能、页面、导航、Reader、source、下载、离线阅读、设置入口相关改动，未在当前连接的设备/模拟器上安装当前构建、启动 App、走到对应用户路径并留下截图或 layout 证据前，不得宣称完成。
- 截图不能由执行者一句话自判通过。每次设备/模拟器验收必须保存原始截图、layout dump、命令记录，并写明逐项检查结果；如果截图里存在状态栏遮挡、标题错层、内容被底栏遮挡、明显截断、占位灰块、错位 menu、不可点击主操作等肉眼可见问题，必须标记为 FAIL，不得写成 PASS。
- UI 验收报告必须引用具体 artifact 路径和问题位置；没有原图/layout 可复核时，结论无效。明显问题无法判断为通过，最多只能标记为“未验收/待修复”。
- 构建通过、脚本通过、静态合同测试通过只能说明本地门禁通过，不能替代设备/模拟器验收。
- 若设备/模拟器不可用，只能标记为“实现完成但设备未验收”；不得把未验收改动提交成已完成闭环，除非用户明确要求先提交未验收代码。
- 每次修改公共 UI 层、根导航、HDS shell、`SecondaryListScaffold`、安全区、浮动 tab、Reader 核心容器前，必须先采集或引用当前页面基线截图；改后必须采集同一页面对比截图。没有前后截图，不得改公共布局。
- 用户指出的问题必须按原范围处理。只说顶部，就不得扩写到底部；只说页面 A，就不得顺手改公共 shell 或页面 B；确需扩大范围时，必须先拿证据说明同一根因影响多个页面。
- 不得用“修 UI”名义改动底部浮动导航、根 `HdsTabs`、系统安全区或公共 scaffold。只有在截图/layout 证明问题来自该层，并且改动前后覆盖根 tab 与至少一个子页时，才允许修改。
- 任何破坏原本正常页面的改动必须立即撤回，并在 `.hermes-artifacts/` 写入事故记录：页面、现象、责任提交/改动、为什么错、如何验证修复。事故记录是本地审计材料，除非用户要求，不提交进仓库。
- 连续出现“拆了修、修了拆”的迹象时，停止继续写功能；先恢复可信页面基线，再回到 Reader/源/下载主线。

当前最高优先级默认是：

1. Reader 基础体验真实可用：图片适配、翻页/手势、点击区域、进度和模式切换必须像漫画阅读器，而不只是能显示图片。
2. 真实源漫画离线阅读闭环：普通用户从 Koma UI 使用真实源找到漫画、加入书架、下载章节，在源不可用或离线后仍能从书架打开 Reader 阅读本地下载页。
3. 源开发到 App 使用闭环：本机 source build/package/index 能被 Koma 安装、浏览、阅读、下载验证。

执行规则：

- 不得把“相关”当成“推进”。Smoke、合同测试、脚本、文档、artifact 整理只能算支撑工作；除非它们正在解除当前最高优先级闭环的实际阻塞，否则不能作为主要产出。
- 每个实现切片都必须能回答：它让哪个用户可见闭环更接近可用？如果答案只是“测试更稳了”或“脚本更完整了”，优先级低于 Reader/源/下载真实路径。
- 正确执行顺序必须是：确认目标用户路径 → 采集当前设备/模拟器基线 → 做最小范围实现 → 本地门禁 → 安装当前构建 → 同路径设备/模拟器截图/layout 验证 → 再提交。不得跳过基线直接改公共层。
- 遇到 HDC、构建、脚本或设备不稳定时，只做解除阻塞所需的最小修复；修完立即回到同一个用户闭环验证，不得换题发散。
- 长时间连续推进时，每个提交前都要重新做一次方向审计：当前 diff 是否仍服务最高优先级闭环；如果偏到设置、UI polish、tracker、备份、分类、i18n、宽图以外的支线，必须停止并重新排序。
- 不能用旧 artifact、静态检查、直接写持久化数据、rawfile fixture、runtime-only smoke 来声明用户场景完成。完成声明必须来自当前运行的设备/模拟器用户路径证据。
- 修改公共组件或公共脚手架时，提交前必须列出受影响页面清单和至少一个根页、一个子页、一个 Reader/详情相关路径的证据；否则该提交视为未验收。
- 提交说明或最终汇报必须包含：推进了哪个路线图 gate、当前证据路径、下一步剩余阻塞。没有这三项时，不应声称功能完成。
- 如果连续产出都是支撑性改动而没有用户可见闭环进展，视为偏离任务；停止继续扩展支撑工作，回到 Reader/源/下载主线。

## Worker Dispatch

- 优先使用 **Claude Code** 和 **Codex** 作为 worker。
- Claude Code `-p` mode 在 background 下必须用 tmux 或 stdin pipe (`cat prompt.md | claude -p ...`)，直接 nohup 不会写 stdout。
- Claude Code 有 session limit → fallback Codex。
- 应用开发遵循鸿蒙应用开发规范，**优先使用 HDS 组件**。
- 悬浮底部导航只属于根 `HdsTabs` shell：页面不得按底栏高度缩小 viewport，不得引用固定底栏高度常量，不得在每个页面塞底栏避让空白；页面只处理自身滚动内容、系统安全区和必要的内容尾部呼吸。子页面必须走 app-level `HdsNavDestination`，不得在 tab root 里套出重复根标题。

## Project Direction

Koma 是 HarmonyOS 私有漫画书架/阅读器：

- 本地漫画：CBZ/ZIP、图片文件夹、书架、阅读进度。
- 私有库：Komga / OPDS / WebDAV。
- 自定义源：研究 Aidoku 风格 WASM source，但不内置源、不做 APK 插件、不提供源市场。
- Source import direction：源使用**用户输入/配置 URL 源索引后导入加载**的方式；不要把主路径设计成内置源市场或只依赖本地文件 picker。具体 source index/package 定义以独立仓库 `/Users/honjow/git/koma-sources` 为准，当前可见定义见 `dist/index.json`（索引项含 `id/name/version/lang/nsfw/author/description/contentRating/pkg/icon/minAppVersion`，`pkg` 指向 `.koma` 包）。

## Hard Constraints

- 不复制 Aidoku/Homo 代码或资源；只能参考公开架构与交互思路。
- 上架文案避免"全网漫画 / 免费漫画 / 聚合源 / 插件市场"。
- UI 走 Aidoku 风格（shelf-first / 轻导入 / 安静阅读）；普通用户可见路径不出现 debug、sandbox、QA、内部路径文案。
- UI 打磨先查 `/Users/honjow/git/HarmonyOSComponentUXExamples`，再决定是否手写或抽组件。

## Device & Build

- 设备 QA 使用 `192.168.50.197:12345`，避免 V2Next 共享测试机 `192.168.50.237:12345`。
- 197 HDC 出现 unauthorized 时，先在 host 上 `hdc kill` / `hdc start` / `hdc tconn`，确认仍 unauthorized 再向用户求助。
- 不得自行停止、重启或启动模拟器。需要模拟器生命周期操作时，先说明原因并等待用户明确授权。
- 不得凭 HDC 端口号推断设备型号或把 `5555` / `5557` 直接称为 Pura X。Pura X 验证必须来自用户指定 target 或可核对的设备身份/模拟器运行证据。
- 调试签名物料放在用户目录 `~/.config/harmony/debug-signing/`（账号级共享），跨 OH 项目复用同一份 cert 避免撞 AGC 调试证书配额。
- 证书名 `honjow-debug`（开发者身份级，所有 OH 项目共用），Profile 仍按 bundleId 独立生成并放在 `${HARMONY_DEBUG_DIR}/profiles/`。
- 路径由 `scripts/dev.env` 声明的 `HARMONY_DEBUG_*` env 控制；Linux 开发机上的 `dev.sh` 和 `scripts/lane-preflight.sh` 自动 source。macOS 不使用 `dev.sh`。手动调 `python3 scripts/sign.py` 必须先 source dev.env，否则 sign.py 立即报错退出。
- 不得把任何签名物料 commit 进仓、打印到日志、或复制进 worktree。

## Artifact & Controller

- 长日志和构建输出放到 `.hermes-artifacts/`，聊天只汇报状态、路径和关键证据。
- Controller/worker 截图、证明文件、结果文件统一按 `docs/CONTROLLER_ARTIFACTS.md` 存放。
- 主 controller 尽量只做调度和必要 sanity check；review / device QA / integrate 交给独立 worker，依据 result JSON 推进。

## Deletion / Destructive Action Boundary

本地书架"移出"等破坏性操作仅作用于：

- 仅删除 `LOCAL_ARCHIVE` / `LOCAL_FOLDER`；`mock://` 和 `undefined` source 不删。
- 不删除外部文件系统中的原文件，不广删 cache。
- 删除日志只能含 `found / removable / removed / persistence` 状态字段，不得记录 title / 路径 / 原始 id。

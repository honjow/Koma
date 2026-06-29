# Koma Roadmap / Controller Plan

## 当前定位

Koma 是 HarmonyOS 私有漫画书架与阅读器。

当前功能基线见 `docs/FEATURE_PROGRESS_20260524.md`：Phase 1 本地 MVP、Phase 2 Komga/OPDS/WebDAV、跨源搜索、History、Reader cache、Komga progress sync、Settings 功能化、WAMR native runtime、source package manager 均已集成并通过 2026-05-24 final gate。

Aidoku/Mihon 对标后的 App 本体缺口与自主推进队列见 `docs/APP_GAP_PLAN_AIDOKU.md`。漫画源生态不作为 Koma App 本体缺口处理；source index/package/真实漫画源维护放在独立仓库 `/home/gamer/git/koma-sources`，Koma App 侧只推进 host/runtime/安装/信任/设置/升级/错误恢复能力。

首版主线：

- 本地漫画：CBZ/ZIP、图片文件夹、封面、章节、阅读进度。
- 阅读器：左右翻页、右左翻页、纵向 Webtoon、沉浸式控制层。
- 私有库：Komga / OPDS / WebDAV 分阶段接入。
- 自定义源：参考 Aidoku 的 WASM source 架构，先做独立 spike，不阻塞本地阅读器。

硬边界：

- 不内置漫画源。
- 不做 APK 插件。
- 不提供源市场。
- 不宣传全网/免费/聚合。
- 上架版主打本地漫画和用户自有私有库。

## Controller 工作流约定

Artifact 目录规范见 `docs/CONTROLLER_ARTIFACTS.md`。

每个 worker 必须产出：

1. controller 负责拆任务、派 worker、读日志/结果、查 diff、跑构建、安装测试、推进下一 gate。
2. worker 必须写 artifact 和 result，不接受只在聊天里自报完成。
3. 任务链按 `implementation -> review -> build/device QA -> integrate` 推进。
4. 并行任务必须不改同一批文件，或者只做只读调研。
5. 设备 QA 默认使用 `192.168.50.103:12345`。
6. 长日志放 `.hermes-artifacts/`，聊天只汇报状态、证据、路径。
7. Koma 调试签名物料共享：放 `~/.config/harmony/debug-signing/`，证书名 `honjow-debug`（账号级共享），Profile 按 bundleId 自动生成。env 由 `scripts/dev.env` 定义。

## Phase 0：基础工程收口

目标：把当前脚手架稳定成可持续开发的 baseline。

### Lane 0A：Dev workflow 校准

范围：

- 保持 Linux 开发机 `dev.sh` 与 V2Next 完整开发流程一致；macOS 不使用 `dev.sh`。
- 检查 `--build-only`、`--refresh`、`--no-build`、`--launch`、`--log`。
- 确认 ignored 签名材料不提交。

验收：

- `bash -n dev.sh` PASS。
- Linux host: `bash dev.sh --build-only --non-interactive` PASS。
- Linux host: `bash dev.sh -d 192.168.50.103:12345` PASS。
- git status 只剩 ignored build/sign artifacts。

状态：已基本完成；后续只做回归。

### Lane 0B：临时视觉区分

范围：

- 临时图标切换到 emerald solid，避免和 V2Next 看错。
- 后续正式 icon 单独设计，不和功能开发混线。

状态：已完成。

## Phase 1：本地漫画 MVP

目标：不依赖任何网络源，先做一个可用的本地漫画书架和阅读器。

### Lane 1A：本地数据模型与存储

状态：已完成并集成，提交 `6634ef6`。

建议串行优先启动。

范围：

- 定义核心模型：`Comic`、`Chapter`、`Page`、`ReadingProgress`、`LibraryItem`。
- 设计本地索引存储：优先轻量 JSON/RDB 二选一，避免过早复杂化。
- 定义文件路径、封面缓存、阅读进度的持久化边界。

候选文件：

- `entry/src/main/ets/model/ComicModels.ets`
- `entry/src/main/ets/model/LibraryStore.ets`
- `entry/src/main/ets/model/ReadingProgressStore.ets`

验收：

- 静态模型可编译。
- 有最小测试/脚本验证序列化与进度更新。
- 构建通过。

依赖：无。

### Lane 1B：CBZ/ZIP 导入 Spike

可在 1A 模型接口确定后启动；可以和 UI mock 并行。

范围：

- 验证 HarmonyOS/ArkTS 侧 ZIP/CBZ 读取方案。
- 读取图片列表、排序、页数、首图封面。
- 先不做复杂批量导入。

候选路径：

- `entry/src/main/ets/import/ArchiveImportService.ets`
- `entry/src/main/ets/import/ImageSortUtils.ets`

验收：

- 用 repo 内测试 fixture 或临时 artifact 跑通 zip 图片枚举。
- 输出章节/page 列表。
- 构建通过。

风险：ArkTS 标准库/第三方 zip 能力不确定，可能需要 native 或 ohpm 包调研。

### Lane 1C：图片文件夹导入 Spike

可与 1B 并行调研。

范围：

- 验证用户选择目录/文件的系统 picker 能力。
- 图片排序策略：自然排序、数字页码、文件名兜底。
- 保存导入记录。

验收：

- 设备上能选择图片/文件夹或明确记录系统限制。
- 输出 page list。
- 构建 + 设备 smoke。

### Lane 1D：书架 UI 骨架

状态：已完成并集成，提交 `6634ef6`；真机截图见 `.hermes-artifacts/20260521-0351/koma-library-ui.jpeg`。

可与 1A/1B 并行做 mock，不接真实导入。

范围：

- 书架网格。
- 空状态。
- 最近阅读卡片。
- 漫画详情页入口占位。
- 平板宽屏预留：至少不要写死窄屏布局。

候选文件：

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/LibraryPage.ets`
- `entry/src/main/ets/components/ComicCoverCard.ets`

验收：

- 使用 mock 数据截图自审：密度、圆角、留白、底部 Tab 不遮挡。
- 构建 + 安装 + screenshot。

### Lane 1E：阅读器原型

需要 1A 的 page model；可先用 mock/local asset。

范围：

- 单章节图片分页显示。
- 左右翻页。
- 纵向 Webtoon。
- 顶部/底部沉浸式浮层。
- 保存当前页。

候选文件：

- `entry/src/main/ets/pages/ReaderPage.ets`
- `entry/src/main/ets/reader/ReaderState.ets`
- `entry/src/main/ets/reader/PageLoader.ets`

验收：

- mock 图片可翻页/滚动。
- 退出再进恢复进度。
- 设备 screenshot/录屏证据。

## Phase 2：私有库接入

目标：在本地阅读器稳定后，接入用户自有服务。

### Lane 2A：Komga API 调研与最小客户端

状态：第一轮 Komga/OPDS/WebDAV 合并调研已完成并集成，提交 `6634ef6`，产物为 `docs/research/private-library-sources.md`。

可作为 Phase 1 并行 read-only 调研先启动。

范围：

- Komga API：library/series/books/pages/auth。
- 鉴权方式。
- 章节/页模型映射到 Koma 数据模型。
- 先写调研文档，不直接改 UI。

产物：

- `docs/research/private-library-sources.md`
- 后续实现 spec。

### Lane 2B：OPDS 调研与 parser spike

状态：第一轮协议调研已并入 `docs/research/private-library-sources.md`；parser spike 未开始。

可与 2A 并行。

范围：

- OPDS 1/2 支持边界。
- feed/catalog/acquisition/image link 映射。
- XML/JSON parser 选择。

产物：

- `docs/research/opds.md`

### Lane 2C：WebDAV 调研与文件枚举 spike

状态：第一轮协议调研已并入 `docs/research/private-library-sources.md`；设备 PROPFIND spike 未开始。

可与 2A/2B 并行。

范围：

- PROPFIND 支持。
- 基本认证/路径编码。
- 大目录分页/性能风险。

产物：

- `docs/research/webdav.md`

## Phase 3：Aidoku 风格 WASM source runtime Spike

目标：回答“鸿蒙上能不能跑 Aidoku 类 WASM source 架构”，并逐步形成 source 作者可用的 API/SDK/host-import 能力；不作为 v1 依赖，也不做源市场/远程源/内置源。

方向大纲：

- `docs/WASM_SOURCE_RUNTIME_DIRECTION.md`

当前纠偏原则：

- package integrity、archive safety、fail-closed negative smoke 是 gate，不是 Phase 3 的全部主线。
- 当安全/包验证 baseline 已经证明后，下一步默认应推进 Source API、Rust SDK、capabilities、listings/home/filters、HTTP/HTML host imports、image request、settings/auth references 等功能接口能力。
- 不要把 Phase 3 自动延伸成连续安全 hardening；除非该 hardening 直接保护新引入的能力。
- 不要切到本地图片导入、书架 UI、阅读器 UI、Komga/OPDS/WebDAV 等其它 track。

### Lane 3A：WASM runtime 最小可行性

范围：

- wasm3 或 WAMR 在 HarmonyOS NDK 编译。
- ArkTS -> NAPI -> native -> wasm 调用。
- 加载最小 wasm，调用 `add/hello`。

产物：

- `docs/research/wasm-runtime-spike.md`
- native spike 代码可以独立分支/目录，未稳定前不进主 UI。

### Lane 3B：Source ABI / Source API 草案

可与 3A 并行，只读/文档。

范围：

- 从最小 ABI 逐步扩展到 source 作者可用的 API：search、manga detail/update、chapters、pages、listings、home、filters、settings、image request。
- manifest/source package 格式草案。
- capabilities / feature discovery。
- host imports 分层：log/check_cancel -> HTTP -> HTML parse/select -> settings/defaults -> image request/auth refs。
- 权限模型：allowedHosts、超时、内存、并发、credential/session refs、日志脱敏。

产物：

- `docs/source-runtime-abi.md`
- `tools/wasm-runtime-spike/source-package/SOURCE_API_V0.md`
- `docs/WASM_SOURCE_RUNTIME_DIRECTION.md`

## Phase 4：正式视觉与图标

目标：功能主线可用后再做，不抢 MVP 资源。

### Lane 4A：正式 icon 设计

范围：

- 不复用 V2Next 主体。
- Koma 主题：漫画书架/书页/分镜/阅读器。
- 输出 layered icon + startup foreground。

依赖：产品名和视觉方向稳定。

### Lane 4B：Harmony/iOS26 风格 UI token

范围：

- 圆角、色彩、毛玻璃、卡片阴影、封面比例、阅读器浮层规范。
- 形成 `DesignTokens.ets` 或资源 token。

## 并行策略

可以并行：

1. `Lane 1A 数据模型` 与 `Lane 1D 书架 UI mock`。
2. `Lane 2A/2B/2C 私有库调研` 与 Phase 1 本地 MVP。
3. `Lane 3B ABI 文档` 与 `Lane 3A runtime spike`。
4. `Lane 4A icon` 可独立，但建议等 MVP 交互稳定后再做。

不要并行：

1. `Lane 1B CBZ 导入` 与 `Lane 1C 文件夹导入` 如果都要改同一个导入 store，需要先共享 1A 接口。
2. `ReaderPage` 和 `ReaderState/PageLoader` 大改不能由多个 worker 同时改同文件。
3. WASM runtime native spike 不应混进本地导入/阅读器主线。

## 第一批建议启动的任务

### 第一批并行 3 条

1. Implementation：Lane 1A 本地模型与存储接口。
2. Implementation/UI：Lane 1D 书架 UI mock，使用假数据，不依赖导入。
3. Research：Lane 2A/2B/2C 私有库调研合并 worker，产出 Komga/OPDS/WebDAV 对比和推荐顺序。

### 第二批

1. Lane 1B CBZ/ZIP 导入 spike。
2. Lane 1E 阅读器原型。
3. Lane 3A WASM runtime spike 或 3B ABI 文档。

## Worker artifact 规范

每条 lane 使用：

```text
.hermes-artifacts/<yyyymmdd-HHMM>-<lane>/
  prompt.md
  worker.log
  worker.exit
  result.json
  notes.md
  screenshots/
```

`result.json` 必须包含：

```json
{
  "verdict": "PASS|FAIL|BLOCKED|REQUEST_CHANGES",
  "summary": "...",
  "artifact_dir": "...",
  "commands": [],
  "changed_files": [],
  "evidence": [],
  "commit": ""
}
```

controller 接到 PASS 后必须：

1. 读 `result.json`。
2. 看 `git diff --stat` 和关键 diff。
3. 跑相关构建/测试。
4. UI/设备任务安装到 `192.168.50.103:12345` 并看截图。
5. 再决定 review/QA/integrate。

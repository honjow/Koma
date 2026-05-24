# Koma Agent Rules

Always-loaded rules for Koma. Open relevant per-task docs (`docs/PRODUCT_PLAN.md`, `docs/ROADMAP.md`, `docs/CONTROLLER_ARTIFACTS.md`) for scope-specific guidance.

## Session Focus

本会话主攻**应用侧功能开发**。以 Aidoku (iOS manga reader) 为蓝本搭建完整 App 框架。

## Worker Dispatch

- 优先使用 **Claude Code** 和 **Codex** 作为 worker。
- Claude Code `-p` mode 在 background 下必须用 tmux 或 stdin pipe (`cat prompt.md | claude -p ...`)，直接 nohup 不会写 stdout。
- Claude Code 有 session limit → fallback Codex。
- 应用开发遵循鸿蒙应用开发规范，**优先使用 HDS 组件**。

## Project Direction

Koma 是 HarmonyOS 私有漫画书架/阅读器：

- 本地漫画：CBZ/ZIP、图片文件夹、书架、阅读进度。
- 私有库：Komga / OPDS / WebDAV。
- 自定义源：研究 Aidoku 风格 WASM source，但不内置源、不做 APK 插件、不提供源市场。
- Source import direction：源使用**用户输入/配置 URL 源索引后导入加载**的方式；不要把主路径设计成内置源市场或只依赖本地文件 picker。具体 source index/package 定义以独立仓库 `/home/gamer/git/koma-sources` 为准，当前可见定义见 `dist/index.json`（索引项含 `id/name/version/lang/nsfw/author/description/contentRating/pkg/icon/minAppVersion`，`pkg` 指向 `.koma` 包）。

## Hard Constraints

- 不复制 Aidoku/Homo 代码或资源；只能参考公开架构与交互思路。
- 上架文案避免"全网漫画 / 免费漫画 / 聚合源 / 插件市场"。
- UI 走 Aidoku 风格（shelf-first / 轻导入 / 安静阅读）；普通用户可见路径不出现 debug、sandbox、QA、内部路径文案。
- UI 打磨先查 `/home/gamer/git/HarmonyOSComponentUXExamples`，再决定是否手写或抽组件。

## Device & Build

- 设备 QA 使用 `192.168.50.103:12345`，避免 V2Next 共享测试机 `192.168.50.237:12345`。
- 103 HDC 出现 unauthorized 时，先在 host 上 `hdc kill` / `hdc start` / `hdc tconn`，确认仍 unauthorized 再向用户求助。
- 调试签名物料放在用户目录 `~/.config/harmony/debug-signing/`（账号级共享），跨 OH 项目复用同一份 cert 避免撞 AGC 调试证书配额。
- 证书名 `honjow-debug`（开发者身份级，所有 OH 项目共用），Profile 仍按 bundleId 独立生成并放在 `${HARMONY_DEBUG_DIR}/profiles/`。
- 路径由 `scripts/dev.env` 声明的 `HARMONY_DEBUG_*` env 控制；`dev.sh` 和 `scripts/lane-preflight.sh` 自动 source。手动调 `python3 scripts/sign.py` 必须先 source dev.env，否则 sign.py 立即报错退出。
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

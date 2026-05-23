# Koma Agent Rules

Always-loaded rules for Koma. Open relevant per-task docs (`docs/PRODUCT_PLAN.md`, `docs/ROADMAP.md`, `docs/CONTROLLER_ARTIFACTS.md`) for scope-specific guidance.

## Project Direction

Koma 是 HarmonyOS 私有漫画书架/阅读器：

- 本地漫画：CBZ/ZIP、图片文件夹、书架、阅读进度。
- 私有库：Komga / OPDS / WebDAV。
- 自定义源：研究 Aidoku 风格 WASM source，但不内置源、不做 APK 插件、不提供源市场。

## Hard Constraints

- 不复制 Aidoku/Homo 代码或资源；只能参考公开架构与交互思路。
- 上架文案避免"全网漫画 / 免费漫画 / 聚合源 / 插件市场"。
- UI 走 Aidoku 风格（shelf-first / 轻导入 / 安静阅读）；普通用户可见路径不出现 debug、sandbox、QA、内部路径文案。
- UI 打磨先查 `/home/gamer/git/HarmonyOSComponentUXExamples`，再决定是否手写或抽组件。

## Device & Build

- 设备 QA 使用 `192.168.50.103:12345`，避免 V2Next 共享测试机 `192.168.50.237:12345`。
- 103 HDC 出现 unauthorized 时，先在 host 上 `hdc kill` / `hdc start` / `hdc tconn`，确认仍 unauthorized 再向用户求助。
- 签名材料放在 `scripts/` 下本地保留，必须 gitignore，不得打印、提交或复制到日志。
- 签名证书名复用 `next2v-debug`，避免华为调试证书数量超限；Profile 仍按 bundle 独立生成。

## Artifact & Controller

- 长日志和构建输出放到 `.hermes-artifacts/`，聊天只汇报状态、路径和关键证据。
- Controller/worker 截图、证明文件、结果文件统一按 `docs/CONTROLLER_ARTIFACTS.md` 存放。
- 主 controller 尽量只做调度和必要 sanity check；review / device QA / integrate 交给独立 worker，依据 result JSON 推进。

## Deletion / Destructive Action Boundary

本地书架"移出"等破坏性操作仅作用于：

- 仅删除 `LOCAL_ARCHIVE` / `LOCAL_FOLDER`；`mock://` 和 `undefined` source 不删。
- 不删除外部文件系统中的原文件，不广删 cache。
- 删除日志只能含 `found / removable / removed / persistence` 状态字段，不得记录 title / 路径 / 原始 id。

# Koma Agent Guidelines

Koma 是 HarmonyOS 私有漫画书架/阅读器项目。

## 当前方向

- 本地漫画：CBZ/ZIP、图片文件夹、书架、阅读进度。
- 私有库：Komga / OPDS / WebDAV。
- 自定义源：研究 Aidoku 风格 WASM source，但不内置源、不做 APK 插件、不提供源市场。

## 约束

- 不复制 Aidoku/Homo 代码或资源；只能参考公开架构与交互思路。
- 上架文案避免“全网漫画 / 免费漫画 / 聚合源 / 插件市场”。
- 设备 QA 使用 `192.168.50.103:12345`，避免 V2Next 测试机 `192.168.50.237:12345`。
- 签名材料在 `scripts/` 下本地保留但必须 gitignore，不得打印、提交或复制到日志。
- 长日志和构建输出放到 `.hermes-artifacts/`，聊天只汇报状态、路径和关键证据。

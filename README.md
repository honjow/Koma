# Koma

Koma 是一个 HarmonyOS 私有漫画书架与阅读器项目。

> 当前实现、未完成缺口、197 真机证据与唯一执行队列见 [`docs/CURRENT_STATUS.md`](docs/CURRENT_STATUS.md)。本 README 只描述产品方向，不作为功能完成度依据。

## 方向

- v0：本地 CBZ/ZIP、图片文件夹、书架、阅读进度、沉浸式阅读器。
- v1：Komga / OPDS / WebDAV 私有库接入。
- Spike：参考 Aidoku 的 WASM source 架构，验证 HarmonyOS NDK + NAPI + Wasm runtime 是否可行。

## 边界

- 不内置漫画源。
- 不走 APK 插件模式。
- 不提供源市场。
- 上架版主打本地/私有库和用户自有内容。

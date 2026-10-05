# Koma

Koma 是一个 HarmonyOS 私有漫画书架与阅读器项目。

## 方向

- v0：本地 CBZ/ZIP、图片文件夹、书架、阅读进度、沉浸式阅读器。
- v1：Komga / OPDS / WebDAV 私有库接入。
- Spike：参考 Aidoku 的 WASM source 架构，验证 HarmonyOS NDK + NAPI + Wasm runtime 是否可行。

## 边界

- 不内置漫画源。
- 不走 APK 插件模式。
- 不提供源市场。
- 上架版主打本地/私有库和用户自有内容。

## CI 构建

[Build OHOS](https://github.com/honjow/Koma/actions/workflows/build.yml) 在 `master` 推送、面向 `master` 的 PR 和手动触发时运行。工作流递归检出子模块，检查公共构建配置和国际化资源，然后构建 arm64 Debug 未签名 HAP。

成功后可在运行页面下载 `ohos-hap-unsigned` 产物，其中包含 HAP 和记录提交、reader-kit 版本及 SHA-256 的 `build-manifest.json`，保留 14 天。该产物需要签名后才能安装；CI 通过只表示编译与打包检查通过，设备功能验收仍需单独完成。

# Koma 产品与架构草案

## 项目名

- 暂定：Koma
- Bundle：`com.honjow.koma`（dev/release 不再区分 bundleName）
- Debug 证书名：`honjow-debug`（账号级共享，多 OH 项目复用避免撞 AGC 调试证书配额）；物料统一放 `~/.config/harmony/debug-signing/`，由 `scripts/dev.env` 的 `HARMONY_DEBUG_*` 环境变量定位。Profile 仍按 bundle 独立生成。
- 测试机：`192.168.50.197:12345`

## 首版路线

1. 本地漫画书架：CBZ/ZIP、图片文件夹、封面、阅读进度。
2. 阅读器：左右翻页、右左翻页、纵向 Webtoon、沉浸式浮层。
3. 私有库：Komga / OPDS / WebDAV 分阶段接入。
4. 自定义源：先做 WASM 可行性 spike，不作为 v1 主宣传。

## 上架边界

- 不内置源，不提供源市场，不宣传全网/免费/聚合。
- 主文案使用“本地漫画阅读”“私有漫画库”“用户自有内容”。
- 自定义源作为高级导入/解析能力单独评估。

## WASM Source Spike

参考 Aidoku：Rust no_std source -> wasm32-unknown-unknown -> source package -> App host imports。

HarmonyOS 推荐验证路径：

```text
ArkTS UI -> NAPI -> C++ runtime -> wasm3/WAMR -> source wasm
```

首个 spike 验收：

- 加载最小 wasm 并调用 add/hello。
- wasm 调 host log。
- 定义 search/detail/pages 三个导出，返回假数据 JSON。
- 后续再接 host net/html。

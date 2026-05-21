# OPDS Parser Spike Boundary

日期：2026-05-22

本 spike 只覆盖用户自有/私有 OPDS 目录的本地字符串解析与 DTO 映射，不做网络请求、账号页、凭据存储、设备安装、签名或公开源市场。

## 范围

- OPDS 1 Atom/XML：解析 feed/title、feed-level links、entry navigation、entry acquisition、cover image、thumbnail、summary、author。
- OPDS 2 JSON：解析 metadata/title、links、navigation、publications、images，以及 groups 内的 navigation/publications。
- 输出保持 Koma 中立 DTO：`OpdsCatalogDto`、`OpdsBookDto`、`OpdsAcquisitionDto`、`OpdsImageDto`。
- acquisition 只标记 CBZ/ZIP 为 supported：`application/zip`、`application/x-cbz`、`application/vnd.comicbook+zip`，以及 `application/octet-stream` 但 href 扩展名为 `.cbz` / `.zip`。
- buy/borrow/subscribe 等 OPDS flow 标记为 unsupported，不进入可导入 acquisition。

## Parser Boundary

`entry/src/main/ets/remote/OpdsParser.ets` 是纯字符串/JSON 边界：

- 不导入 `@ohos.net.http`，不调用 `fetch`，不读取或写入文件。
- 不处理认证头、cookie、token、账号配置或安全存储。
- URL 只通过 `new URL(href, feedUrl)` 解析相对链接；失败时保留原 href。
- OPDS 2 通过标准 `JSON.parse` 解析，不做 JSON-LD 推理。
- OPDS 1 当前使用 ArkTS/JS-safe 的小型 XML tag scanner，覆盖 fixture 中的 Atom/OPDS link/title/summary/author/name 子集。生产化前建议替换为 HarmonyOS `@ohos.xml` `XmlPullParser` 事件式解析，以获得命名空间、CDATA、重复节点和大 feed 的更稳健行为。

## HarmonyOS XML Options

当前仓库内没有直接可运行的 HarmonyOS XML 单元测试环境；因此没有在本 lane 引入 `@ohos.xml` 产品依赖。

后续可选方案：

1. **XmlPullParser 产品实现**：在 HarmonyOS API 14+ 使用 `@ohos.xml` 事件式解析 OPDS 1，保留当前 DTO 和测试 fixture 作为契约。
2. **当前纯 ArkTS scanner 作为 fallback**：仅用于受控 OPDS 1 子集和本地 fixture，不作为长期完整 XML 解析方案。
3. **host 侧预解析**：若未来 source-runtime host 已经解析响应，可把 XML 解析留在 host/import 层，source/UI 只接收 DTO。

## Fixtures

- `tools/opds-parser-spike/fixtures/opds1-private-shelf.xml`
- `tools/opds-parser-spike/fixtures/opds2-private-shelf.json`

`scripts/test_opds_parser.mjs` 读取上述 fixture，并断言：

- OPDS 1/2 基本解析结果。
- 相对 URL resolution。
- feed-level links 不混入 entry links。
- OPDS 2 groups 被保留并扁平进入当前 result navigation/publications。
- CBZ/ZIP acquisition 支持，EPUB/PDF 与 buy/borrow flow 不支持。
- parser source 不包含网络请求或公开源/市场文案。

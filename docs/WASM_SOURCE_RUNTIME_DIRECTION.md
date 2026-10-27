# Koma WASM 源运行职责

本文件描述当前运行边界。当前源缺陷、已采用需求与验收状态见 [CURRENT_STATUS.md](CURRENT_STATUS.md)，包与操作合同见 [source-runtime-abi.md](source-runtime-abi.md)。本文不派发开发阶段或维护演进记录。

## 当前链路

用户配置的索引或本地包 → 导入/校验 → Registry → SourceRuntimeService 准入 → TaskPool Worker → Native WAMR → DTO → 浏览/详情/阅读宿主。

| 所有者 | 当前职责 |
| --- | --- |
| SourceIndexService / SourceIndexMetadata | 索引获取、合并、缓存及更新候选 |
| SourcePackageImporter / SourcePackageMetadata | 包结构、元数据、图标与 WASM 校验；复用无 UI 的元数据规则 |
| SourceRuntimeRegistry / SourceRuntimeAppRegistry | 已安装身份、启用状态及持久化 |
| SourceRuntimeService | 当前源身份/能力/请求/设置/网页会话的准入及结果校验 |
| SourceRuntimeWorker / NativeSourceRuntime | 复制的 WASM 字节和受限请求上下文进入后台原生执行 |
| SourceRuntimeHttpTransport / 原生 HTTP、HTML host | 受控网络与解析；源不直接拥有宿主文件、凭据或 UI |
| BrowseViewModel / SourceRouteChromeState | 当前源内容描述、合法能力与导航入口的展示投影 |
| SourcePackageManagerCache | 页面外可用快照及后台检查后的发布 |
| SourceSettingsStore / SourceWebSessionStore | 配置和精确身份/origin 下的会话，不由展示对象授权 |
| SourceSettingObservationStore / SourceSettingObservationFile | 本源公开设置候选的进程快照、串行后台提交及卸载/备份生命周期；不改用户选择或内容缓存身份 |
| SourceChapterListResolver / SourceChapterVisibility / SourceMangaDetailSnapshotCache | 当前完整目录及源明确排除的显示投影；保留库章节/下载/进度，按安装及设置身份缓存 |

## 内容与准备

- Browse 的当前内容描述携带 home/listing/query/filter/page 语义；刷新、重试、分页和设置返回均重放对应描述，不能意外切回另一个列表或旧查询。
- 行展示复用值相等的 DTO 与已解码图标身份；源运行准入仍读取实时 Registry。可用快照先显示，后台完成后差量发布，不因检查清空整表。
- App 本地元数据提交保持有序和一致；后台工作减少 UI 线程负担，不削弱提交、回滚或身份校验。
- 目录方向由已核源合同声明；首次阅读按对应方向选择最早未读，已保存进度和显式章节优先。共享章序所有者为 ReaderChapterSequence，不能通过猜话数、重排或改章节 ID 适配宿主。

## 并发与能力

- Worker 模块边界不得引入 UI decorator、语言状态、Registry 变更或网页会话查找；这些由调用侧完成。保留复制字节、受限 HTTP 上下文及源变更校验。
- source_info、实际导出、源设置 schema 和实际消费共同决定可用能力；不能只见 capability 标志就摆放空入口。
- 普通网页仅使用已知合法站点地址，不授予验证会话或扩大网络权限。验证流程按精确源身份、请求和 origin 认领；其它源并行结果不因验证丢弃。
- 敏感设置沿专用保护边界，不能因源有导出而开放普通明文持久。账户、网络、原图缓存和进度仍由各原宿主服务负责。

## 修改时查阅

改动上述公共 owner 时核全部调用方和异步回写，遵守 [执行规则](agent-guides/koma-rules.md) 的关联影响与具名路径验收要求。代码合同及当前工作单是实际能力依据，参考应用不授予复制代码/资源或新增产品范围。

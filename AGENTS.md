## 强制约束：未经用户明确允许，禁止创建工作树

- 默认在项目原主仓目录工作。创建任何 Git 工作树前必须取得用户明确允许，并遵守该允许限定的项目、用途和范围；没有明确允许，一律不得创建。
- 本约束适用于命令行、工具托管、临时路径和所有子代理；不得通过派工规避，也不得把旧计划、自动唤醒、代理建议或已有工作树当作新增许可。
- “保护 WIP”“并行开发”“隔离验证”“方便打包”等理由不构成允许。不得通过复制项目源码或额外克隆开发副本规避本约束；应在原主仓审查、整理并及时提交有效改动。
- 已获允许的工作树只用于获准范围；完成后及时将有效成果合回原主仓并退出工作树，未经新的明确允许不得扩展用途或长期保留为另一条开发主线。

# Koma agent entry

**未经用户明确允许，禁止更改样式；修 bug 也不例外。**

先读 [执行规则](docs/agent-guides/koma-rules.md)，然后只读当前工作需要的资料。

强制先读其中“禁止编造记忆与无依据确认”；每次开始、压缩或交接后，以及回应纠正、历史要求或既定决定前再次阅读，不得用当前纠正冒充历史记忆。

| 工作 | 资料 |
| --- | --- |
| 首版 App 与中文源开发 | [唯一当前工作单](docs/CURRENT_STATUS.md) |
| 共享 Reader | [共同职责](../reader-kit/README.md#consumer-contract)、当前跨宿主工作单、[参考规则](docs/agent-guides/reader-rewrite-standards.md) |
| 产品设计 | [产品计划](docs/PRODUCT_PLAN.md)、[路线图](docs/ROADMAP.md)、[能力参考](docs/FEATURE_COMPARISON_AIDOKU_MIHON.md) |
| 书源 | [运行方向](docs/WASM_SOURCE_RUNTIME_DIRECTION.md)、[ABI](docs/source-runtime-abi.md) |
| 本地证据 | [产物目录](docs/CONTROLLER_ARTIFACTS.md) |

用户最新请求决定范围；暂停时停止冲突操作。旧路线图、[历史违规记录](docs/agent-guides/reader-rewrite-violation-log.md)和历史工作单只用于查证，不自动恢复旧任务或重复验收。

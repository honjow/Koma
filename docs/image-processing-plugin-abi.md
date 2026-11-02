# 图片插件 ABI

图片插件包含独立 WASM 算法、用途说明、配置描述和算法所需数据。宿主提供像素读写与执行环境，不按算法名称分派。插件可实现识别、裁切、颜色变换等不同处理；包子漫画横幅处理只是一个外部插件。

订阅、安装和阅读策略归 [订阅协议](subscription-image-rules.md)。开发工具与 Rust SDK 位于 `koma-sources/image-rules/plugins/`；插件定义和生成器分别位于 `plugin-definitions/`、`generate_plugins.py`。App 不附带具体插件或默认订阅。

## 插件清单

```json
{
  "schemaVersion": 2,
  "id": "example-processor",
  "version": 1,
  "meta": {
    "name": "插件名称",
    "description": "具体处理对象、用途及效果"
  },
  "processor": {
    "abi": "koma-image-v1",
    "path": "处理器内容摘要.wasm",
    "sha256": "处理器完整SHA256"
  },
  "parameters": {},
  "application": {"automatic": true, "sourceHints": []},
  "settings": [],
  "output": {"format": "image/png", "quality": 100}
}
```

`id` 在更新间保持稳定，`version` 为递增正整数。`meta` 可选 `author`、`website`。`processor.path` 相对插件清单解析，宿主校验完整摘要和 ABI 后才提交安装。远程清单不能直接提供已安装算法字节。

`parameters` 是发布者维护的数据；`settings` 是用户可编辑字段。字段沿共享表单合同，支持 `string`、`boolean`、`select`、`multiselect`、`range`，使用 `id`、`label`、可选 `description`、可选 `defaultValue`。选择项提供 `options: [{id, label}]`；范围项提供有限的 `minValue`、`maxValue`、正 `step`，上限大于下限。字段不承载登录、凭据或脚本验证器。设置按订阅及插件 ID 保存，更新保留可兼容的值。

`application.automatic` 决定插件是否参与自动处理。`sourceHints` 使用 `kind`、`modes` 对应书源公开声明；可选 `sourceIds` 仅用于旧缓存补查声明，不限定图片来源。识别算法仍由插件自己决定是否改变图片。

`output` 选填，支持 `image/png`、`image/jpeg`、`image/webp`，质量为 0–100 整数。省略时用 PNG 保留透明度；多个插件改变同图时，最终采用最后一个实际改变图片的插件所声明的编码。

## WASM 导入与导出

模块导出 `memory`，以及以下两个无参数、返回 `i32` 的函数：

| 导出 | 含义 |
| --- | --- |
| `koma_image_processor_abi()` | 返回 `1` |
| `koma_image_process()` | `0` 表示不改变；`1` 表示完整输出；负数表示失败 |

导入命名空间只有 `koma_image`。坐标、长度、返回值及 guest 指针均为 `i32`。

| 导入 | 参数 | 返回 |
| --- | --- | --- |
| `width` / `height` | 无 | 当前输入尺寸 |
| `config_len` | 无 | 配置 UTF-8 字节数 |
| `config_read` | `ptr, capacity` | 写入字节数；失败 `-1` |
| `read_region` | `x, y, width, height, ptr, capacity` | 写入字节数；失败 `-1` |
| `output_create` | `width, height` | 成功 `0`；失败 `-1` |
| `output_write` | `x, y, width, height, ptr, length` | 消费字节数；失败 `-1` |
| `check_cancel` | 无 | 可继续 `0`；须终止 `1` |

像素均为紧密排列、非预乘的 RGBA8888，每行 `width × 4` 字节。ImageKit 的预乘输入由宿主转换；输出用非预乘格式建立 PixelMap。插件必须明确保留或改变 alpha。

`read_region` 从当前输入读取矩形，输入不可修改。插件仅需在 WASM 内保留工作区域；整图不复制进其线性内存。输出尺寸可改变，`output_create` 每次处理只能成功一次。输出必须按完整行从上到下连续写入：`x=0`、宽度等于输出宽度、`y` 等于已写行数、长度等于本次行数乘行宽。返回 `1` 前须写满全部行，否则丢弃结果。

配置由宿主组装：

```json
{
  "parameters": {},
  "settings": {},
  "context": {
    "application": "auto",
    "sourceHint": {"kind": "公开声明类型", "mode": "公开模式"}
  }
}
```

`application` 为 `auto` 或 `source`，没有书源声明时省略 `sourceHint`。关闭策略不调用插件。配置只包含该插件的数据、公开用户设置和处理声明，不提供书库、账号、网络会话或文件路径。

## 执行与失败

- 使用现有 WAMR 解释器；没有 WASI、线程、网络、文件或书源 Host 导入。模块不能带 start section，算法从显式导出进入。
- 模块上限 2 MiB，线性内存最大 128 页（8 MiB），配置上限 4 MiB，单张输入和输出各不超过 256 MiB。
- 单次执行限时 5 秒，宿主可中止不主动检查取消的纯 WASM 忙循环。启用 WAMR thread manager 仅供宿主中止，未向插件开放 guest 线程。
- 解码与执行在后台工作；进入 TaskPool 前最多放行两张图片，避免等待原生执行槽占满公共 Worker。
- trap、超时、无效输出和处理错误均丢弃本次输出并沿用原图，不写成“未匹配”缓存。成功返回 `0` 才能记录未命中。

阅读与预载消费同一个不可变插件快照。派生缓存按输入完整内容、算法摘要、配置和输出编码区分；目录重命名或无关版本变化不使已处理图片失效。

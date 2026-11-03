# Koma 书源开发

- 编写、打包及发布书源，从 [koma-sources 书源库](https://github.com/honjow/koma-sources) 的开发说明开始。
- 查看 App 支持的生产包格式、操作及宿主能力，见[书源运行 ABI](source-runtime-abi.md)。
- 核对订阅身份、运行调用链和宿主职责，见[书源运行职责](WASM_SOURCE_RUNTIME_DIRECTION.md)。

生产书源包的根目录包含 `manifest.json`、`source.wasm` 及一个包内身份图标。用户可从订阅安装，也可导入本地包。声明网络能力后，请求仍由宿主按包身份和运行权限校验。

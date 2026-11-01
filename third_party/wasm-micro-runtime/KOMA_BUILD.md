# Koma WAMR 构建合同

App 源运行时与图片处理插件共用一份 WAMR 及其进程级生命周期。Host 按书源身份保留四路源调用，另提供两路图片执行；初始化和分配器不能在其它调用运行期间销毁。

`core/iwasm/libraries/thread-mgr/` 的三个文件来自 Bytecode Alliance WAMR 提交 `389d2060dfddb2fe083740f8b4a9666dd930fd69`，与本仓 `core/iwasm/common/wasm_runtime_common.c/.h` 的 Git blob 完全相同的上游版本配套。不能仅依据 `core/version.h` 选择同名版本的 thread manager。

| 文件 | SHA256 |
| --- | --- |
| `thread_manager.c` | `0868d3d881c94bd750f02a6b2d3cd64a8dee3a7e5e07c01c884831d56b2c1905` |
| `thread_manager.h` | `e35a08b2d7d6a0c6176b0798c4e3c4ea0e7576567c18bf9d2c8a7377f7a2a40d` |
| `thread_mgr.cmake` | `85d86a5b16734d6f8cb47b223b6d7214fa5cd5653a31eaa081820d1af2e07682` |

构建使用解释器、`WAMR_BUILD_THREAD_MGR=1` 和 `WASM_ENABLE_HEAP_AUX_STACK_ALLOCATION=1`，不启用 WASI、guest pthread、AOT 或 JIT。thread manager 让宿主能中止没有 Host 回调的 WASM 忙循环；heap auxiliary stack 配置保留主调用的完整辅助栈，不将源调用已有栈预算拆给 guest 线程。

生产入口为 `entry/src/main/cpp/CMakeLists.txt`；`scripts/native/image_processor/` 用同样配置执行生产图片宿主代码，验证结果只代表原生内核，不代替 HarmonyOS 图片解码、NAPI 或普通阅读路径。

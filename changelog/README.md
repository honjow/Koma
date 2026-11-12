# 版本日志

每个准备发布的版本维护一份 `v版本号.md`。正文分类见[执行规则](../docs/agent-guides/koma-rules.md)，有条目的分类才列出。只写相对上一发布版本的变化，不重复整份功能列表，不写提交号、内部验收步骤或未完成承诺。开发版本说明随已交付改动补充，不代表已经打 tag 或发布。

发布流程：

1. 以 `AppScope/app.json5` 的 `versionName` / `versionCode` 为主版本，同时同步根目录与 entry 的包版本；更新必须增加 versionCode。
2. 编写对应 `changelog/v版本号.md`，运行 `python3 scripts/check_release_notes.py`。
3. CI 从共享阅读器 `main` 同步实际构建内容，产物清单记录本次使用的 `readerKitCommit`。共享阅读器依赖改动先进入其远端 `main`。提交并通过构建后再按用户发布决定打 tag。正式示例 `v0.1.2`，预发布示例 `v0.1.2-pre`；也支持 App 版本本身带 `-pre`。预发布与对应正式版共用同一份版本正文。
4. CI 核对 tag、App 版本、包元数据、构建产物及说明文件，再将原文件正文用于 Release。以 pre 结尾的 tag 为 prerelease，不占用 latest；其他版本 tag 为正式 Release。

**发布必须由对应标签的 CI 完成构建、校验和 Release 发布。** 主分支 CI 的产物不能替代标签发布流程。CI 等待、异常或失败时，先查明并处理原因，不得擅自取消后改为手动发布。

**未经用户明确允许，禁止手动发布或调整已发布版本。** 包括手动创建、编辑、删除 Release，修改正文、附件、发布状态或 latest 指向，以及移动、删除已发布标签。重跑 CI 如果会改动已有 Release，同样须先取得明确允许。用户授权发布时，按上述流程创建并推送新标签以触发 CI。

本文不授权自动打 tag 或发布。版本日志只维护一份正文，GitHub Release 不再自动拼接提交清单。

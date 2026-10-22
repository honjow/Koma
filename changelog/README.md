# 版本日志

每个准备发布的版本维护一份 `v版本号.md`，例如 [v0.1.1.md](v0.1.1.md)。正文以用户能感知的新增、改进、修复为主；后续版本只写相对上一发布版本的变化，不重复整份功能列表，不写提交号、内部验收步骤或未完成承诺。当前没有历史 Release，0.1.1 是首份发布说明，不补造旧版本日志。

发布流程：

1. 以 `AppScope/app.json5` 的 `versionName` / `versionCode` 为主版本，同时同步根目录与 entry 的包版本；更新必须增加 versionCode。
2. 编写对应 `changelog/v版本号.md`，运行 `python3 scripts/check_release_notes.py`。
3. 提交并通过构建后再按用户发布决定打 tag。正式示例 `v0.1.1`，预发布示例 `v0.1.1-pre`；也支持 App 版本本身带 `-pre`。预发布与对应正式版共用同一份版本正文。
4. CI 核对 tag、App 版本、包元数据、构建产物及说明文件，再将原文件正文用于 Release。以 pre 结尾的 tag 为 prerelease，不占用 latest；其他版本 tag 为正式 Release。

本文不授权自动打 tag 或发布。版本日志只维护一份正文，GitHub Release 不再自动拼接提交清单。

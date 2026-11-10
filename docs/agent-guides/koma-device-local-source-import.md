# Koma 真机本地书源导入

适用：把候选 `.koma` 通过系统文件选择器导入 Koma。不要添加订阅，不要开局域网 HTTP，不要改扩展名。

## 已验证路径

- 用户可见“下载/Download”的实际路径是 `/storage/media/100/local/files/Docs/Download/`。
- 发送：`hdc file send <local.koma> /storage/media/100/local/files/Docs/Download/<name>.koma`，成功输出 `FileTransfer finish, Size:...`。
- App 路径：浏览 → 书源管理 → 右上角四点 → 本地导入 → 文件选择器“浏览” → “我的手机” → “Download” → 选择 `.koma` → 完成。
- 导入后在书源管理读回源版本。

## 禁止

- 不要把包放在 `/storage/media/100/local/files/Docs/` 根目录；文件选择器的“文档”分类不显示 `.koma`，“最近”也不索引该目录。
- 不要把 `.koma` 改名成 `.zip`，也不要改包内容。
- 不要用订阅地址或局域网 HTTP 代替本地导入。
- 不要用 `hdc shell ls/mkdir` 判断这个目录；shell 常报 `Permission denied`。`file send` 的 `FileTransfer finish` 才是传输结果。

## 清理

- `hdc shell rm -f /storage/media/100/local/files/Docs/Download/<name>.koma`，只删本轮文件。
- 用 `hdc file recv` 同一路径确认返回 `no such file or directory`，再关闭文件选择器。

依据：旧 237 记录 `.hvigor/outputs/user-flow-audit/baozi-chapter-identity237.protocol.json` 的 `testImportPath` 使用 `Docs/Download/koma-...koma`。

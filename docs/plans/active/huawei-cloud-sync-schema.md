# Koma 华为云同步表

2026-11-21 在 Koma（`com.honjow.koma`）的 AGC 云同步开发环境创建了容器及下列五种数据类型，并逐张核对本地表名称、字段类型和端侧去重主键。控制台显示生产环境待实施。

分布式数据库文件为 `koma_user_data.db`，去掉 `.db` 后与 AGC 容器名 `koma_user_data` 完全相同。高级设置的「本地数据库名称」为空，按容器名称匹配。103 的 ArkData 日志证实带连字符的标识 `koma-user-data` 会使分布式表注册失败，因此五张传输表使用独立数据库。业务库仍由原有数据所有者管理。

## 端云名称映射

| 现有同步范围 | AGC 数据类型 | 本地表名称 |
| --- | --- | --- |
| 书架与分类 | `CloudSyncShelf` | `cloud_sync_shelf` |
| 阅读记录 | `CloudSyncReading` | `cloud_sync_reading` |
| 阅读偏好 | `CloudSyncReaderSettings` | `cloud_sync_reader_settings` |
| 书源订阅 | `CloudSyncSourceSubscriptions` | `cloud_sync_source_subscriptions` |
| 搜索历史 | `CloudSyncSearchHistory` | `cloud_sync_search_history` |

控制台的数据类型名称只接受字母和数字。表中第三列是已保存的「本地表名称」，也是端侧接入时要创建并注册的 ArkData 表名。目前 Koma 的 RDB schema 4 仍是[本地数据治理](local-data-governance.md)交付的版本。

## 五张表共用字段

| 字段 | AGC 类型 | ArkData 类型 | 用途 |
| --- | --- | --- | --- |
| `record_id` | String | TEXT PRIMARY KEY | 唯一的端侧去重主键。使用跨设备稳定的记录标识。 |
| `payload` | Encrypted String | TEXT | 该组通过现有同步规则校验的记录内容。 |

创建时依次录入 `record_id` 和 `payload`。控制台列表显示为 `payload`、`record_id`。客户端接入以实际生效的云配置核对字段顺序和版本。保留字段 `ID` 由平台管理。

这五张表承载可同步记录。书架、阅读和其他业务数据仍经各自的业务入口读写。记录范围、身份、并发操作和删除沿用 Koma [现有同步合同](webdav-sync-redesign-proposal.md)。凭据、会话、本机路径、下载队列和缓存属于本机数据。

## 开发环境真机验收

- 103 和 201 覆盖安装同一测试签名包，核对应用声明、应用内「华为云同步」开关、权限恢复入口及系统云同步开关。103 的 ArkData 注册最初因数据库标识带连字符失败，改用独立传输库后五张表全部注册成功。设备刷新开发环境配置后返回成功。
- 103 每张表上传 1 条合成记录，201 逐表读回并核对全部 5 条内容。AGC「数据记录调测」查到同批测试阅读记录。测试只经过开发签名和隔离的传输记录，没有读取或上传用户书架与阅读记录。
- 103 逐表提交测试记录的删除，201 读回五张表均无本批记录。AGC 再查测试阅读表显示无数据。两台撤回临时授予的设备发现和连接权限，并恢复正常启动。生产仍为待实施，197 未参加华为云同步测试。
- 主机用模拟传输运行普通同步流程和真实的阅读记录写入、合并及读回逻辑。发送端从第 10 章推进到第 66 章，第 66 章首次上传失败后重试成功。接收端从持久记录恢复第 66 章及页码，并保留第 10 章的独立页码。
- 五张表的传输验收原始证据在 `.hvigor/outputs/huawei-cloud-sync`，103 的发送、201 的校验和回收分别为 `system-enabled-native-retry`、`confirmed-download` 和 `verify-synthetic-rows-removed`。

## 103 读完后在 201 续读

- 两台安装同一开发签名包，从系统文件选择器导入测试书源。103 由作品详情进入《Koma Cloud Reading Test》第 2 章，翻到第 3 页退出，再通过设置里的「华为云同步」上传最近阅读和章内页码两条记录。
- 201 导入书源后直接同步。应用读回第 2 章、页索引 2、总页数 6；历史显示「第 3 / 6 页 · Chapter 2」。点击历史记录后，阅读器首次落点为第 2 章第 3 页，正文页标和阅读器页码一致。
- 同步范围限定为测试漫画。测试书源、测试用书页和两台本地与开发环境的测试阅读记录均保留。普通启动的华为云同步开关仍关闭，197 未参与，AGC 生产环境仍待实施。跨服务冲突及生产签名链路待验收。
- 证据在同一产物目录。103 的书页和上传记录分别为 `save-target-chapter-page` 和 `upload-real-reader-progress`；201 的同步回执、历史和正文分别为 `download-real-reader-progress`、`show-synced-history-entry` 和 `resume-from-synced-history`。

## 构建开关

普通构建默认开启华为云同步入口和应用声明，单台设备是否开始同步仍由用户开关控制。公开 GitHub Actions 构建沿用 NextE 的做法，在工作流中同时关闭入口和 `cloudStructuredDataSyncEnabled`，打包后检查应用声明。在本机分别生成并核对普通 Release HAP 与套用工作流开关的 Release HAP。

相关平台规则见[华为云同步接入指南](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/data-sync-with-cloud/)。

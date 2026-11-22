# Koma 华为云同步表

AGC 开发环境容器为 `koma_user_data`，本地数据库名称填 `Koma`，对应端侧唯一业务库 `Koma.db`。2026-11-22 在 Edge 保存并读回下列 13 张表，生产环境待实施。201 上 CloudKit 拒绝了容器名 `Koma`，所以原位改用平台曾成功连接的容器名，保留表和本地库名。业务路径按作品或业务键读写，本地字段无需经过云端。

| 范围 | AGC 数据类型 | `Koma.db` 表名 | 端侧去重主键 |
| --- | --- | --- | --- |
| 书架作品 | `ShelfWorks` | `shelf_works` | `comic_id` |
| 普通分类 | `ShelfCategories` | `shelf_categories` | `category_id` |
| 作品归类 | `ShelfMemberships` | `shelf_memberships` | `comic_id, category_id, category_occurrence` |
| 智能分类 | `ShelfSmartCategories` | `shelf_smart_categories` | `category_id` |
| 智能规则 | `ShelfSmartCategoryFilters` | `shelf_smart_category_filters` | `category_id, filter_order` |
| 共享章节目录 | `ShelfSharedChapters` | `shelf_shared_chapters` | `comic_id, chapter_order` |
| 当前续读点 | `ReaderCurrentPositions` | `reader_current_positions` | `comic_id` |
| 各章页位和标记 | `ReaderChapterStates` | `reader_chapter_states` | `comic_id, chapter_id` |
| 书源阅读历史 | `ReaderSourceHistory` | `reader_source_history` | `comic_id` |
| 共用阅读设置 | `ReaderSharedPreferences` | `reader_shared_preferences` | `id` |
| 按书阅读设置 | `BookReaderModes` | `book_reader_modes` | `comic_id` |
| 书源订阅 | `SourceSubscriptions` | `source_subscriptions` | `url` |
| 搜索历史 | `SearchHistory` | `search_history` | `entry_key` |

字段、类型和主键的客户端定义见[包内云配置](../../../entry/src/main/resources/rawfile/arkdata/cloud/cloud_schema.json)。迁移重放读取实际 SQLite 表来核对字段、类型、空值约束和主键。作品章节图片、本机路径、设备阅读参数、凭据和会话各由原有本地存储负责。端侧表和旧数据映射见[本地数据治理](local-data-governance.md)。

分类创建时生成一次 UUID。本地分类、作品归属、WebDAV 和华为云使用这个 ID。分类改名保留 ID。升级旧库时，已有的共享 UUID 直接作为分类 ID，旧本机 ID 的引用与分类放在同一事务里改写。同名分类合并归属，保留隐私设置、智能规则、显示策略和导入关联。旧 ID 的对应关系只供兼容旧 WebDAV 状态和处理晚到的归属。

## 本次开发环境验证

- 201 已覆盖升级并注册全部 13 张表。ArkData 拒绝 `CHECK` 约束，已在迁移中更正。手动单作品 `cloudSyncEx` 需要关闭 `autoSync` 和 `autoSyncSwitch`。云表版本变化时，注册还会清除同步游标。ArkData 的 `UPGRADE_SCHEMA` 事件直接触发应用级同步，绕过手动请求的作品条件。201 复测在该路径查询了书架及分类等表，查询返回空，日志中未见对应上传。[OpenHarmony 注册表实现](https://github.com/openharmony/distributeddatamgr_datamgr_service/blob/master/services/distributeddataservice/service/rdb/rdb_general_store.cpp) · [升级事件实现](https://github.com/openharmony/distributeddatamgr_datamgr_service/blob/master/services/distributeddataservice/service/cloud/cloud_service_impl.cpp)
- 调测查询确认 `ReaderCurrentPositions` 只有《遇强则强，我的修为无上限》的第 2 话第 88 页，`ReaderChapterStates` 和 `ReaderSourceHistory` 暂无记录。包内两处 schema 版本已从 `13` 对齐云端实际版本 `29`。原账号复测已直接使用 `29`，云端返回 1 条续读记录，但 201 仍报 `can not find schema record type:ReaderCurrentPositions`。103 已重连并通过 HDC 应答，在启用同步前退出。保留测试数据，双机续读未通过。
- 单作品调测仅注册三张阅读表。注册时关闭数据库端云同步，手动请求结束后关闭。ArkData 的 `enablePredicate: true` 只筛选上传。103 真机确认它会下载同表里的其他作品，因此改为传入完整主键的双向条件，章节状态同时按作品和章节定位。201 日志确认注册阶段没有云请求，调测只访问指定作品的已关联云记录。调测开关与成功时间只在当次进程有效。
- 201 重启后，开发环境收到书架共享目录、阅读历史和搜索历史的成功写入回执。Edge 查询确认开发环境新增了其他作品的阅读进度。指定作品仍为第 2 话第 88 页，服务器当轮未修改该条。双机续读待验证。
- 103 重启后正常阅读《遇强则强，我的修为无上限》第 2 话第 89 页，端侧收到该进度的成功上传回执。201 单作品调测的三张阅读表均返回成功，但请求的是 201 已关联的旧云端记录。再次只读 201 数据库，当前续读点和该章页码都仍是第 88 页。AGC 同一作品下有三条续读点，Edge 读回当前续读点以 `comic_id` 去重，章节状态以 `comic_id` 和 `chapter_id` 去重，与本地表一致。单作品调用无法按业务主键发现另一个云端 ID。双机续读验收仍未通过。
- 103 用标准下行接口关联到 201 已关联的云记录，其本地第 89 页仍保留。下一轮 103 上传第 90 页，201 的书架和两张阅读表都到了第 90 页，阅读器却因本地旧图片标识打开第 88 页。修复后仅在接收到不同阅读位置时清除受影响记录的旧图片标识。103 从正常阅读器翻到第 2 话第 91 页并同步，201 从书架点击「继续阅读」首次打开同一话第 91 页，已核对实际正文。首次场景的重复云记录保留。设备证据为 `page-anchor-fixed-103-page-91`、`page-anchor-fixed-201-receive-91-and-shelf` 和 `page-anchor-fixed-201-page-91`。
- 201 正常退出阅读器后，书架和两条进度记录仍为第 2 话第 91 页。两台退出临时会话并回到系统桌面，保留已安装的测试包和测试数据。201 退出和落盘证据为 `page-anchor-fixed-201-exit-and-persist`。
- 反向手动验证通过。201 从书架进入同一本条漫，读到第 2 话第 94 页并手动同步。103 从书架继续阅读进入同一话第 94 页，正文一致，退出后两张进度表仍为第 94 页。
- 自动验证通过。临时测试包让普通自动调度仅处理该作品。201 上次在真实阅读器退出后保存第 97 页，开启同步后自动上传。103 开启同步后自动下载，从书架打开同一话第 97 页，正文一致。两台恢复普通测试包并退出，读回两张进度表均保留第 97 页。
- Edge 逐表读回开发环境的 13 张表与 79 个字段，核对本地别名、字段类型和去重主键，与包内配置和 201 本地 SQLite 一致。本地主机用真实 RDB 读写核对了书架归类新增和其它分组的变更处理。

### 归类删除后的书架更新

- ArkData 对复合主键只返回已删除行的行号，原实现靠这个行号找作品，数据已删除时找不到。修复后在删除事务里保留作品键，发布书架变更后清除；同步只为受影响的作品读取业务行。103 真机接收侧用 ArkData 直接重放删除写入，日志只记录测试漫画的作品键。保持同一进程返回「日漫」，该卡片消失，继续阅读仍显示第 97 页。归类表和进度读回与测试前一致。证据为 `membership-103-receiver-ready` 和 `membership-103-native-publication`。
- 103 与开发云有 4 条原有归类的分类键不同。本轮让 103 在隔离目录使用同名 `Koma.db` 接收标准同步。201 在书架给真实《遇强则强，我的修为无上限》添加「日漫」归类，标准同步上传 1 条。103 接收后显示卡片；201 取消同一条归类并同步。103 返回「日漫」并停在原页，由隔离包定时发起标准增量同步，服务端返回 1 条删除、0 条上传。相同进程内卡片消失，继续阅读保持第 97 页，隔离库只减少这一条归类。两台原库的归类和该作品的进度读回与测试前一致。证据为 `refresh-201-upload-delete`、`refresh-103-same-page-before` 和 `refresh-103-same-page-after`。
- 同一份隔离库还复现了冷启动书架为空。20 条云端作品没有公开作品页地址，原先只有增量刷新会按书源作品键补足访问路径。两条路径现在共用同一作品读法，SQLite 回归和 103 同一份数据的冷启动均通过，证据为 `refresh-103-before-standard-delete`、`refresh-103-cold-start-fixed`。

### 其余删除与刷新核查

- 修复了核查复现的五类缺陷。智能分类与规则分批下载后一起发布，缺规则的记录留在库中等待完整状态，日常书架与冷启动均只展示有规则的分类。普通分类删除按分类键清除共享与本机归属，只更新受影响作品。保留较新页位时沿用数据库中已删除的历史状态。删除书源订阅同时清理失效的选中地址，撤销该订阅在途结果并重读共享目录缓存。部分失败仍发布落盘变更，晚到的 RDB 回调单独触发本地刷新。
- 实际 SQLite 和受控回调重放确认新智能分类的第二批规则继续下载、同轮失败时保留错误且书架已移除归属、晚到回调无需再发同步即可移除已取消收藏的作品。分类删除、页位与历史并发、订阅指针和在途响应均有回归用例，普通签名 HAP 构建成功。
- 取消收藏、移除共享章节、删除当前续读点或章内状态、搜索删除及全局／单书阅读设置删除，本地重放核对了变更后的业务读回。前台详情和阅读器是否及时采用新状态、应用保持页面打开时的实际刷新、并发表和回调顺序需在真机用标准同步验证。测试沿用单独的业务数据范围，避免覆盖现有归类。

### 提交后的复查

- 注册端云业务表时先关闭库的云端读写。应用发起同步时才启用库的云端读写。用户关闭开关时关闭库的云端读写，系统支持 `stopCloudSync` 时停止正在进行的任务。201 用指定作品手动同步三张阅读表，随后再次发起同步并关闭，最终包的系统日志确认 `StopTask` 成功，归类和第 2 话第 97 页均保留。见 `refresh-201-audit-final-sync`。[ArkData RdbStore 接口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-data-relationalstore-rdbstore#stopcloudsync)
- 云端提交新进度后，会淘汰应用此前准备的旧写入，按章节保留仍需保存的本机翻页。章节页位和作品续读点独立写入，迟到的旧章节页位无法重设全书续读点。实际写库的系统同步任务也使用备份恢复的写入协调，界面超时后要等系统任务退出才释放。两条时序都有执行回归。
- 旧库、v6 和 103／201 的 v9 实库副本通过迁移或重新打开检查。基于真实数据重建了带旧 `CHECK` 的 v8 阅读表，升级后逐表核对行数据和外键，包内云表和 SQLite 的主键、字段类型及空值约束一致。

### 103、201 开发环境复验

- 同步总览里，华为云同步的开关关闭时，副标题显示「未开启」。103 已在普通测试包核对入口及开关实值。
- 两台使用独立目录下的 `Koma.db` 做首次同步。13 张业务表全部成功，两个接收库的 79 个共享列逐键一致，首轮上传均为 0。在 201 暂存十条测试记录后只选搜索历史，103 只收到搜索词。随后全量同步才收到其余九条测试记录。见 `ship-qa-103-visible-baseline`、`ship-qa-201-full-baseline`、`ship-qa-103-receive-search-final` 和 `ship-qa-103-receive-create`。
- 分类改名、智能规则、全局及单书阅读设置、书源订阅和搜索历史更新时间跨机一致。取消收藏、删除分类、归类、规则、共享章节、两类阅读设置和书源订阅均在 103 读回。103 保持测试分类打开，收到删除后卡片移除并回到「全部」。见 `ship-qa-103-receive-update` 和 `ship-qa-103-receive-delete`。
- 保存阅读统计时，已同步但没有最近历史或本地书源标识的续读点、章节状态曾被误划到设备区，产生云端删除。修复后沿用已共享的同一作品同一章的归属。八条受影响记录按原值恢复并由两台逐字段核对。201 用历史从《我的专属邪神》第 2 页读到第 3 页退出，其他阅读记录未变。103 的历史页面收到更新后直接续读到同一章同一页。103 在历史中移除该书后，201 当场移除该历史卡和当前续读点，原章内页码及第 97 页的既有测试进度仍保留。见 `ship-qa-103-restored-reading-receive`、`ship-qa-201-reader-repeat-saved`、`ship-qa-103-real-resume-verified` 和 `ship-qa-201-receive-history-delete`。
- 远端新收藏的本地详情提交后才按作品重新读取并更新书架。103 保持同一进程接收《我老婆是魔王大人》和归类，进入测试分类当场看到卡片。之前同一条记录需要冷启动才出现。见 `ship-qa-103-category-open-verified` 和 `ship-qa-103-live-favorite-visible`。
- 搜索合并后记录数可暂时超过可见上限。单词删除只写该词和它自己的搜索范围，保留其他已同步词。201 长按移除测试词，103 保持普通搜索页打开，词条当场消失。两台逐行核对均只减少一条。见 `ship-qa-201-search-fixed-removed` 和 `ship-qa-103-receive-fixed-search-delete`。
- 201 用脱敏的 v6 库副本按正式迁移逻辑升级到 v9，设备专属页位与设置逐字段保留。迁移只对有共享值的旧设置生成云记录。随后按普通同步模式首次连接开发云，13 张表均成功、上传为 0。升级库与两台隔离验证库的 79 个共享列结果一致。见 `ship-qa-201-legacy-migrated-fixed` 和 `ship-qa-201-legacy-first-sync`。
- 两台恢复正常测试包与原数据库映射，退出应用进程。原有共享业务表及本机书架、阅读表与测试前逐行一致，隔离测试库保留。最终本机执行回归共 207 项通过。见 `ship-qa-103-normal-final` 和 `ship-qa-201-normal-final`。

## 构建开关

普通构建声明 `cloudStructuredDataSyncEnabled` 并显示华为云同步功能。每台设备由用户开启同步。公开 GitHub Actions 构建继续关闭入口与声明。

GitHub Actions [运行 44908929314](https://github.com/honjow/Koma/actions/runs/44908929314) 构建的是 `ff28dbf3`。直接检查该 HAP 的应用声明和字节码，确认同步菜单与设置搜索均隐藏华为云同步入口。第 91 页续读修复在本地测试包验证。

当前源码在本地执行工作流的开关步骤并生成两种 Release HAP。普通包的云能力为启用，公开包的云能力和入口开关均关闭，公开包字节码中的同步菜单与设置搜索不会生成该入口。

旧开发环境的五张传输表已删除，以下记录只保留此前的验证事实。

## 原五张传输表的历史验收

- 103 和 201 覆盖安装同一测试签名包，核对应用声明、应用内「华为云同步」开关、权限恢复入口及系统云同步开关。103 的 ArkData 注册最初因数据库标识带连字符失败，改用独立传输库后五张表全部注册成功。设备刷新开发环境配置后返回成功。
- 103 每张表上传 1 条合成记录，201 逐表读回并核对全部 5 条内容。AGC「数据记录调测」查到同批测试阅读记录。测试只经过开发签名和隔离的传输记录，没有读取或上传用户书架与阅读记录。
- 103 逐表提交测试记录的删除，201 读回五张表均无本批记录。AGC 再查测试阅读表显示无数据。两台撤回临时授予的设备发现和连接权限，并恢复正常启动。生产仍为待实施，197 未参加华为云同步测试。
- 主机用模拟传输运行普通同步流程和真实的阅读记录写入、合并及读回逻辑。发送端从第 10 章推进到第 66 章，第 66 章首次上传失败后重试成功。接收端从持久记录恢复第 66 章及页码，并保留第 10 章的独立页码。
- 五张表的传输验收原始证据在 `.hvigor/outputs/huawei-cloud-sync`，103 的发送、201 的校验和回收分别为 `system-enabled-native-retry`、`confirmed-download` 和 `verify-synthetic-rows-removed`。

### 原实现的双机续读

- 两台安装同一开发签名包，从系统文件选择器导入测试书源。103 由作品详情进入《Koma Cloud Reading Test》第 2 章，翻到第 3 页退出，再通过设置里的「华为云同步」上传最近阅读和章内页码两条记录。
- 201 导入书源后直接同步。应用读回第 2 章、页索引 2、总页数 6；历史显示「第 3 / 6 页 · Chapter 2」。点击历史记录后，阅读器首次落点为第 2 章第 3 页，正文页标和阅读器页码一致。
- 同步范围限定为测试漫画。测试书源、测试用书页和两台本地与开发环境的测试阅读记录均保留。普通启动的华为云同步开关仍关闭，197 未参与，AGC 生产环境仍待实施。跨服务冲突及生产签名链路待验收。
- 证据在同一产物目录。103 的书页和上传记录分别为 `save-target-chapter-page` 和 `upload-real-reader-progress`；201 的同步回执、历史和正文分别为 `download-real-reader-progress`、`show-synced-history-entry` 和 `resume-from-synced-history`。

平台规则见[华为云同步接入指南](https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/data-sync-with-cloud/)。

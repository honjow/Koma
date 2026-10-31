# Koma 当前工作单

本文件是唯一任务队列。当前有效任务、已接受范围、权限、未验边界及证据以以下 snapshot 为准；不另建重复队列。

当前工作：参考应用功能差异的本地实现及追踪表单已交付；真实账号路径待条件验收。

设备：197本轮追踪表单验证后已恢复并释租；237本轮未操作。200禁止操作，四私库搁置。

任务状态、首次报告时间及证据索引不因文档整理改变。局部验收、构建、CI或发布不代表全部缺陷完成。

<!-- koma-progress-snapshot
{
  "schemaVersion": 1,
  "title": "Koma 当前工作",
  "state": "持续核验与修复中",
  "outcome": "查看当前问题、已验收范围和剩余工作。",
  "updatedAt": "2026-10-31T21:30:12+08:00",
  "target": "/Users/honjow/git/Koma；同级reader-kit与koma-sources为原主仓",
  "activeId": "FEATURE_PARITY_IMPLEMENTATION",
  "activity": "追踪服务独立实现已交付，真实账号验收待条件。",
  "nextAction": "保留真实账号未验边界，继续处理其他具名问题。",
  "proof": [
    {
      "label": "正式主仓",
      "state": "各一工作树/分支",
      "kind": "accepted",
      "detail": "Koma/master、reader-kit/main、koma-sources/master；没有新增副本。"
    },
    {
      "label": "本地未加密备份",
      "state": "具名路径通过",
      "kind": "accepted",
      "detail": "具名当前快照恢复成功及真实cold后的书架/历史/下载/79源包消费者已亲审，原四备份保留；不含其他快照/跨设备/自然失败回滚。"
    },
    {
      "label": "远端同步",
      "state": "既有具名提交与公开实体已核",
      "kind": "accepted",
      "detail": "既有App与源提交、公开实体及精确CI证据保留；后续工作按各原事项的实际状态跟踪。"
    },
    {
      "label": "共享阅读器",
      "state": "阅读器具名路径已核",
      "kind": "accepted",
      "detail": "既有阅读器及真实Torii试译、未来页具名路径已核；其他提供方及未覆盖路径仍按原事项跟踪。"
    },
    {
      "label": "图标全范围",
      "state": "用户已确认完成",
      "kind": "accepted",
      "detail": "按本会话最新人类决定关闭；后继K应用图标也已安装交付，不从旧OPEN重开图标矩阵。"
    },
    {
      "label": "本地CBZ普通路径",
      "state": "具名路径通过",
      "kind": "accepted",
      "detail": "原导入/纵向翻页/进程结束后重开证据保留；本轮核清2/1700同页左右半后进3/1700，非侧边点击失效。测试条目已移出，外部文件保留。"
    }
  ],
  "hosts": [
    {
      "name": "Koma",
      "checkout": "/Users/honjow/git/Koma",
      "appHead": "Koma/master 529aa8b66329072f73529d4df2b715ae74b994f8，精确CI41204801578成功。",
      "hap": "197两轮追踪表单验证后已恢复原HAP、数据与电源并释租。"
    },
    {
      "name": "NextE",
      "checkout": "/Users/honjow/git/NextE",
      "appHead": "已接受具名跨宿主范围冻结；本轮未修改该宿主。",
      "hap": "本轮未安装或验收该宿主，既有已接受范围见原任务。"
    },
    {
      "name": "NextN",
      "checkout": "/Users/honjow/git/NextN",
      "appHead": "已接受具名跨宿主范围冻结；本轮未修改该宿主。",
      "hap": "本轮未安装或验收该宿主，既有已接受范围见原任务。"
    }
  ],
  "scope": "Koma首个生产版本和中文源质量；当前人类纠正、既定设计和原WIP边界继续有效。 用户本轮明确持续授权197和237本项目验收，无需重复询问：包括唤醒、非通知区解锁、临时常亮、同签候选安装、Koma内验收及结束恢复和释租；197本轮验收和恢复可继续。",
  "items": [
    {
      "id": "READER_ENHANCEMENT_THEME_CONTRAST",
      "title": "超分指示器在暗绿色等主题中辨识度不足",
      "priority": "P1（用户本轮直接反馈）",
      "kind": "accepted",
      "status": "40%底色具名验证及197恢复已完成",
      "stage": "具名范围已验收",
      "owner": "Root：共享阅读器指示器修复",
      "dependencies": [],
      "relatedItems": [
        "NEXTE_READER_FEATURE_MIGRATION"
      ],
      "result": "用户本轮反馈超分指示器背景过黑，暗绿色主题激活后几乎不可辨识，要求覆盖全部主题。当前源码核NextE背景#26000000而共享指示器为#66000000，存在迁移差异；本地调整idle浅底及处理中/已生效的主题底与高对比图标，保临时关闭和原点击语义。仅本地代码及执行检查，尚未构建或真机验证。 冻结release已装197且原Reader/Appearance偏好与库保持；xkcd2937原页真实system增强成功，暗绿底白HD清晰，点击关闭为浅底灰HD、再开恢复绿底白HD，页码不变且偏好逐字相等。Nemo因原高度限制正常skip，不改限制；其他处理日志不外推全部预载、翻译或性能。 197暗绿主题白HD、临时关弱化浅底与再开已核；琥珀#A66A1F激活显示实色琥珀圆与黑HD。恢复原翠绿及Reader偏好键值与02相等，偏好序列化顺序不同不称逐字相等。原Blue第四话第1页100%、Nemo 2/3及xkcd2937 1/1恢复；76书ID及676章ID保持，xkcd2974自然预载0→1页并更新页表指纹/count/updatedAt，其余75本完整相同。最终SLEEP、normal120000/Override10000与原基线一致并释租。shared四文件dc06d5ed758fc0ec68be4a397b5fccd3b3f87588已推origin/main；首次HTTPS错误账号403保留，未改账号，正确origin成功。Koma依赖提交f9de81cbc7671ff97a7ab5a3fa1fc4fcb2917efe已推且精确CI40721766878 completed/success。全局对比算法已交付，真机仅暗绿与琥珀两种具名样本，不冒每个主题逐一验证。 用户新批准超分底色适当透明化；当前本地改为80%不透明，图标按黑白漫画底色最差对比选择黑或白，两个关键执行检查通过，尚未真机验证。 最终release 6b53cbe9在197实际增强页亲审浅化绿底白HD；偏好及原Blue阅读状态恢复，76书完整library JSON与基线相等。设备恢复SLEEP、原超时并释租。shared 4460969f3aaf02b622346a0e68304020647f2b5f已推；Koma菜单及依赖pin 2a0c7aeb已本地提交，推送和CI待确认。 Koma 2a0c7aebbe998269a113a5730361cc16acca3711已推master，精确CI40733358529 completed/success。 用户最新明确要求底色40%不透明、60%透明；Root本地实施并在197真机验证，尚未取得结果。此前80%不透明方案的具名验收和CI证据保留。 197同签release候选37fd51已安装；暗绿主题xkcd2937黑底和同页临时白底均亲审白HD与淡底可辨。Reader偏好XML语义与21相等、76本library JSON全份相等，sessions正恢复原Blue读态。shared 0db00119b2f21338070c28ba85b3077ae852529a已本地提交，推送待核，Koma pin尚未更新。 shared 0db00119b2f21338070c28ba85b3077ae852529a已推main，Koma依赖pin fa6e728已推master，CI查询中。197唤醒解锁及超时操作、后续只读状态均被自动审批拒绝，理由未识别设备授权；已向用户说明并等待明确授权，未绕过。197租约仍有效，偏好及76本书库已恢复，sessions有xkcd访问时间变化，Blue普通返回仍待。 用户本轮明确允许继续197验收和恢复，并持续授权197、237本项目验收；此前审批拒绝记录保留。Koma fa6e728精确CI40742436354成功，40%黑白背景具名Native已核。 197普通Continue回原Blue第四话1/1，返回书架同章第1页100%；Reader和Appearance语义、76本library与基线相等，sessions仅updatedAt变化。最终SLEEP、normal120000/Override10000，租约已释放。",
      "remaining": "本次40%底色黑白背景具名范围及设备恢复完成；其他主题未逐一真机验证。",
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "保原指示器状态语义与点击开关；不以源码检查或构建代替各主题实际视觉验证。"
      ],
      "reportedAt": "2026-10-28T22:46:32.797+08:00",
      "reportedDate": "2026-10-28",
      "reportedDateSource": "本轮可见用户反馈日期；消息精确时刻未核实，不以登记时刻冒充。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第82244行，UserMessage item.id=01a182fa-205c-74a2-a461-dafee367a724；不排除跨会话更早历史。",
      "closedAt": "2026-10-29T02:44:58+08:00",
      "stageNote": "40%底色黑白背景具名真机及提交CI已核，设备恢复并释租。",
      "evidence": [
        "/Users/honjow/git/reader-kit/reader-ui/src/main/ets/ReaderEnhancementStatus.ets",
        "/Users/honjow/git/reader-kit/reader-ui/src/main/ets/ReaderEnhancementContrast.ets",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/install-contrast-host-03/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-active-reader-12/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-off-13/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-on-14/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/amber-active-reader-18/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/restore-reader-preferences-21/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/restore-original-reading-23/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/power-restore-and-sleep-24/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/translucent-active-xkcd-28/",
        "https://github.com/honjow/Koma/actions/runs/40733358529",
        "https://github.com/honjow/Koma/actions/runs/40742436354"
      ],
      "reopenedAt": "2026-10-29T01:46:02+08:00"
    },
    {
      "id": "MIXFLAVOR_SEARCH_MISSING",
      "title": "綜合口味搜索未移植",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.2普通搜索具名验证",
      "owner": "source_terra：源修复；Root：237具名验证",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "result": "本轮全源搜索自检发现原源搜索遗漏；0.1.2提交5fa311a已推且CI40697052579成功，公开WASM以真实保存HTML及原Host具名核对。237普通更新后实际ZIP/WASM与公开一致、设置同002；普通源内搜索食返回原栏目5个作品#64/#57/#45/#30/#18及没有更多了，未混入排除8481；未进入Reader。",
      "remaining": "本源具名搜索漏实现范围已验证。",
      "remainingActions": [
        "本源具名搜索漏实现范围已验证。"
      ],
      "boundaries": [
        "本项来自执行自检，非用户亲报；不外推Reader及其他站点。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；首次发现时间未核实。",
      "closedAt": "2026-10-28T21:51:06+08:00",
      "stage": "具名搜索范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-public-index-124/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-public-update-125/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-public-target-126/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-browse-target-127/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-ordinary-search-128/"
      ]
    },
    {
      "id": "FJUMONKEY_SEARCH_MISSING",
      "title": "輔大猴搜索未移植",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.2普通搜索及续页具名验证",
      "owner": "source_terra：源修复；Root：237具名验证",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "result": "本轮全源搜索自检发现原源搜索遗漏；0.1.2提交5e397ee已推，本地生产WASM搜索分页及旧ID详情具名。117安装ZIP/WASM与当前公开实体完全相等；237同HAP0db普通源内搜索四格，121首批可见、122正常滚动见后续结果且查询保持。只验证具名搜索及续页，不冒正文或首末全页。先前5e旧CI查询因EOF及审批拒绝未核，不由当前实体反推。",
      "remaining": "本源具名搜索及续页范围已验证。",
      "remainingActions": [
        "本源具名搜索及续页范围已验证。"
      ],
      "boundaries": [
        "本项来自执行自检，非用户亲报；不外推正文及全部搜索分页。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；首次发现时间未核实。",
      "closedAt": "2026-10-28T21:41:25+08:00",
      "stage": "具名搜索范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/fjumonkey012-browse-target-120/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/fjumonkey012-ordinary-search-121/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/fjumonkey012-search-next-122/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/fjumonkey-search012/"
      ]
    },
    {
      "id": "PEOPLE2_SEARCH_MISSING",
      "title": "人2搜索未移植",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.2普通搜索具名验证",
      "owner": "source_terra：源修复；Root：237具名验证",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "result": "本轮全源搜索自检发现原源搜索遗漏；人2 0.1.2提交aacee1f已推、精确CI40685768520成功，公开WASM及原Host真实保存HTML回放已核。237同HAP0db普通源内搜索春節，返回原生活：春節將至，從生肖交接看過年那些事，并显示没有更多了；未进入正文。117设备WASM与公开完全一致；实际安装ZIP与先前公开ZIP容器哈希不同，但每个成员内容全部相等，不误判可执行实体不同。",
      "remaining": "本源具名搜索漏实现范围已验证。",
      "remainingActions": [
        "本源具名搜索漏实现范围已验证。"
      ],
      "boundaries": [
        "本项来自执行自检，非用户亲报；不外推正文及其他搜索情况。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；首次发现时间未核实。",
      "closedAt": "2026-10-28T21:36:04+08:00",
      "stage": "具名搜索范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/public-search-packages-and-people2-target-117/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/people2012-ordinary-search-118/"
      ]
    },
    {
      "id": "IPMINI_SEARCH_MISSING",
      "title": "IP手札mini搜索未移植",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.2普通搜索具名验证",
      "owner": "source_terra：源修复；Root：237具名验证",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "result": "本轮全源搜索自检发现原源搜索遗漏；0.1.2提交430b767已推且精确CI40688772764成功，公开WASM以真实保存HTML和原Host具名核对。237同HAP0db普通Browse搜索強化IP管理制度，返回原IP手札mini!#3待辦事項-強化IP管理制度并显示没有更多了。仅该搜索具名路径通过，不冒Reader或全部负例验收。",
      "remaining": "本源具名搜索漏实现范围已验证。",
      "remainingActions": [
        "本源具名搜索漏实现范围已验证。"
      ],
      "boundaries": [
        "本项来自执行自检，非用户亲报；不外推Reader及未覆盖搜索情况。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；首次发现时间未核实。",
      "closedAt": "2026-10-28T21:29:40+08:00",
      "stage": "具名搜索范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/ipmini012-browse-target-115/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/ipmini012-ordinary-search-116/"
      ]
    },
    {
      "id": "NHENTAIXXX_SEARCH_MISSING",
      "title": "NHentai.xxx搜索遗漏与空页续取",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.4普通搜索及空页续取已验证",
      "owner": "Root：宿主空页续取及237恢复；source_terra_resume：源合同核对",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT",
        "SIXMH_SEARCH_UNSUPPORTED"
      ],
      "result": "本轮全源搜索自检确认搜索遗漏；237保存原0.1.3包，普通Picker安装冻结0.1.4候选并核安装字节、设置不变。english搜索显示首个中文421586；普通上滑后无终点且未再发搜索请求，单源日志op530/533有result552、op537有result249后无后续请求。候选未公开，未通过；原0.1.3恢复仍待完成。 BrowseViewModel已接空首批或续页按源明确nextCursor继续取到新条目或真结束，成功cursor逐批提交、失败验证只处理原失败页，包/设置/query过期即停止；SourceBrowse/Search现有重试入口共用。现有web_sessions与补充关键执行回归通过，旧测试和期望保留；空页合同已补入现有ABI文档。尚未构建或安装，237仍为候选0.1.4，原0.1.3待恢复。 首次release构建因嵌套响应对象ArkTS类型失败，改显式SourceRuntimeCallResponse后二次构建及签名校验成功；HAP 0db49bbb547640a9d5b1cf488d440c424ebe464e489a25c92bba623500bbcd24 debugfalse、profile debug并绑定当前237 UDID。102/103安装并普通启动后registry/settings/library JSON均与安装前相等；105 english首中文421586可见，106收键盘后同query原生触底，op8空批后op12成功至真实终点，首项保留并显示没有更多了。此为冻结候选及修复宿主的具名实机路径，原0.1.3恢复、公开源包及宿主提交/CI未完成。 Host 83f19391d454311e33aa85f95b1ae82f5353fe8a已推，CI40693094111成功；源c8f72ea及CI40690590752成功。108普通Picker恢复原0.1.3，109接收ZIP/WASM与094原包逐字相等，设置同002；随后自动更新事件后112当前公开包ZIP及WASM与公开实体完全相等，WASM f70e2d3c…不同于已验冻结9f2b5a89…，公开Native仍待验证。 113已删除本轮candidate014及restore013两项临时Downloads并读回不存在；114以当前公开0.1.4及HAP0db普通Browse搜索english，首中文421586保留且显示没有更多了，日志op31空批后op35至真实终点，无重试或清数据。此具名搜索遗漏及空页消费范围通过；237整体会话仍进行中，未称休眠或释租。",
      "remaining": "本源具名公开搜索及空页续取范围已验证；其他源及设备会话独立继续。",
      "remainingActions": [
        "本源具名公开搜索及空页续取范围已验证；其他源及设备会话独立继续。"
      ],
      "boundaries": [
        "本项来自执行自检，非用户亲报；不以候选安装或首个结果代替完整分页验收。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；首次发现时间未核实。",
      "closedAt": "2026-10-28T21:25:34+08:00",
      "stage": "公开包具名范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-baseline-094/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-import-097/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-browse-098/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-english-100/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-empty-next-101/",
        "/private/tmp/koma-empty-search-tests.log",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-host-preinstall-102/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-host-install-103/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-fixed-host-target-104/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-fixed-host-english-105/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-fixed-host-tail-106/",
        "/private/tmp/koma-empty-search-build.log",
        "/private/tmp/koma-empty-search-build-v2.log",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-original-restore-picker-107/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-original-restored-108/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-index-109/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-target-110/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-update-state-readback-111/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-bytes-and-update-events-112/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-browse-113/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-english-114/"
      ]
    },
    {
      "id": "IMMARK_SEARCH_MISSING",
      "title": "我是馬克搜索未移植",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.1搜索及旧格式结果详情已验证",
      "owner": "source_terra_resume：源搜索修复；Root：237普通入口回验",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT",
        "SIXMH_SEARCH_UNSUPPORTED"
      ],
      "result": "本轮全源搜索自检发现原源无搜索，官网目标分类有真实搜索；0.1.1提交699a3c7已推且CI40679769440成功，公开WASM search=true、職場第二页返回12个10位旧文章及nextCursor=3；保留18位旧ID兼容。Native未验。 237普通manager更新公开0.1.1，registry search=true/hashOk；普通源内搜索職場成功，首3封面可见，滚动真实第二页时旧10位文章封面可见。2036573392先显示加载，随后同一次请求成功显示1章详情；未进入正文。",
      "remaining": "本源具名搜索及旧格式结果详情范围已验证。",
      "remainingActions": [
        "本源具名搜索及旧格式结果详情已验证。"
      ],
      "boundaries": [
        "本项来自执行自检，非用户亲报；公开WASM不代替Native验收。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；首次发现时间未核实。",
      "reopenedAt": null,
      "closedAt": "2026-10-28T19:42:42+08:00",
      "stage": "具名搜索及旧格式详情已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/immark-search011/public-search2.json",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-public-update-087/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-ordinary-search-090/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-search-next-091/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-old-search-result-092/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-old-detail-settled-093/"
      ]
    },
    {
      "id": "NHENTAITO_SEARCH_MISSING",
      "title": "NHentai.to搜索未移植",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.4普通入口搜索已通过",
      "owner": "source_terra_resume：源修复；Root：237普通入口回验",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT",
        "SIXMH_SEARCH_UNSUPPORTED"
      ],
      "result": "本轮全源搜索自检确认参考支持搜索而旧源未实现；0.1.4提交e8fa055已推，CI40676656848成功，公开包SHA256 43ee84bc40ac47a6a31bb8342788dd9e6cd6fa605d34abfebd961802685abdc3，公开WASM search=true及真实love搜索nextCursor=2；Native未验。 237普通manager更新到公开0.1.4，049 registry确认search=true；同0cd HAP普通Browse源内搜索love成功，053前6结果封面可见。仅该源搜索漏实现范围通过。",
      "remaining": "本源具名搜索修复已验证；其他源单独核对。",
      "remainingActions": [
        "本源具名搜索修复已验证，其他源单独核对。"
      ],
      "boundaries": [
        "仅记录本源自检发现；公开WASM不代替Native验收。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；首次发现原始时间未核实，非用户亲报。",
      "reopenedAt": null,
      "closedAt": "2026-10-28T19:14:40+08:00",
      "stage": "具名搜索范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/nhentaito-search014/public-search.json",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito014-public-update-049/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito014-ordinary-search-053/"
      ]
    },
    {
      "id": "THREE_HENTAI_SEARCH_MISSING",
      "title": "3Hentai搜索未移植",
      "priority": "P1（全源搜索自检发现）",
      "kind": "accepted",
      "status": "237公开0.1.4普通入口搜索已通过",
      "owner": "source_terra_resume：搜索修复；Root：237普通入口回验",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT",
        "SIXMH_SEARCH_UNSUPPORTED"
      ],
      "result": "本轮全源搜索自检发现：当前0.1.3 search=false且未实现；固定参考Hentai3.kt有搜索，真实官网搜索love及中文语言条件返回HTTP200、作品和下一页。Native未验；后续候选love.json记录了unobserved asset host错误，不能算候选成功。 0.1.4提交32de784已推，CI40675283851成功；公开包SHA256 40ba78730da4db743c3c7862b5071f8bccf0e9d0777dbeb8c3748c302b187b69，公开WASM search=true，真实love搜索25本、nextCursor=2。旧ID及默认标题不变，Native尚未验。 237同0cd HAP普通Browse进入3Hentai，公开0.1.4搜索love成功，前6个结果封面可见；公开WASM full_title true/false同一ID分别返回完整及短标题，Native设置持久仍沿既有0.1.3具名范围。",
      "remaining": "本源具名搜索漏实现已验证，其他源单独核对。",
      "remainingActions": [
        "本源具名搜索范围已验证；其他源单独核对。"
      ],
      "boundaries": [
        "不将固定参考不支持搜索的源认作漏移植；不凭源码或官网响应代替Native验收。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户要求全源搜索核查后的执行自检；未取得原始发现记录的可靠时间，不冒充用户亲报。",
      "firstEvidenceAt": "2026-10-28T18:48:25+08:00",
      "firstEvidenceAtSource": "候选love.json文件修改时间，只证明该候选错误记录的时间，不等于搜索遗漏首次发现时间。",
      "reopenedAt": null,
      "closedAt": "2026-10-28T19:09:59+08:00",
      "stage": "具名搜索范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/love.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/public-search.json",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/threehentai014-ordinary-search-046/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/public-title-true.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/public-title-false.json"
      ]
    },
    {
      "id": "SIXMH_SEARCH_UNSUPPORTED",
      "title": "六漫画搜索提示书源不支持，排查其他无法搜索的源",
      "priority": "P1（用户本轮直接反馈）",
      "kind": "accepted",
      "status": "237公开0.1.5普通源内搜索已通过",
      "owner": "Root：237普通源内入口验证；source_terra_resume核对参考及其他不能搜索源",
      "dependencies": [],
      "result": "237真实统一搜索日志中com.sixmh.koma为unsupported，是具名线索；尚不能代替源内入口复现。 固定参考SixMH继承MCCMS搜索，官网有搜索表单；真实/search/一人之下/1返回HTTP200及两项。Koma 0.1.4声明search=false且run_search未实现，确认为漏移植，源侧实施中；237旧版普通Browse入口仍在定位，未称修复完成。原85快照17个search=false中六漫画确认遗漏、Simply旧记录过时，余15待核；设置/镜像另15项未收口，两组重叠不能相加为bug总数。 237同0cd HAP及已装六漫画0.1.4，普通Browse进入源目录30本正常；源内搜索一人之下实际显示“源搜索失败”“此书源暂不支持该操作。”“重试”。0.1.5候选09adb5486ab8ba1e75af5806425320819ea6a8ba已推，CI40674075133运行中；本地生产WASM真实搜索2结果、分页及空结果具名，官网繁忙JSON保留为错误，不伪造空结果。公开包及Native修复回验尚未完成。 六漫画0.1.5公开包及精确CI40674075133成功，公开WASM source_info search=true，真实一人之下返回两项；237普通入口升级回验仍进行中。 041普通公开索引更新后registry为0.1.5且实际具search；042同237及0cd HAP从普通Browse进入六漫画，搜索一人之下返回两本《一人之下（《异人之下》原著漫画》和《一人之下番外·锈铁》，两封面显示且没有更多，不再出现旧036不支持提示。仅本源搜索漏实现范围通过。",
      "remaining": "本源具名搜索修复已验证；其他不能搜索的书源继续逐项核对，不由本项外推。",
      "remainingActions": [
        "本源具名范围已验证；其他源搜索能力继续逐项核对。"
      ],
      "boundaries": [
        "保留现有已验收行为与样式；统一搜索unsupported线索不等于源内路径已复现。"
      ],
      "reportedAt": "2026-10-28T18:29:29.665+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第78698行，UserMessage item.id=01a1820e-c9a8-7cd0-8df7-9755ba10eb39；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": "2026-10-28T18:57:32+08:00",
      "stage": "具名搜索范围已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/real-source-parallel-search-008/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh-ordinary-source-035/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh014-search-failure-036/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/sixmh-search015/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh015-update-completed-041/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh015-ordinary-search-042/"
      ],
      "reportedDate": "2026-10-28"
    },
    {
      "id": "READER_THUMBNAIL_LOADING_REGRESSION",
      "title": "NextE/NextN缩略图进入阅读时加载指示器消失",
      "status": "N/E具名路径与两笔精确CI完成",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "共同4bf42eb已push；N a0211fa7、E26a447c2均采用并push。197实际N032 Non-H686734全269帧/8表、E0274277955全151帧/5表顺序亲审及原91/92：最后低清仍有加载面板，首清晰图时面板退出；普通返同缩略图。旧E022第120帧反例和误判撤回永久保留。N033原下载/6867442/2保持，034回E画廊/K书架。 N CI40092801190和E CI40092801362均completed/success；无新tag/发布。",
      "remaining": "本次N/E两个真实缩略图→原图→返回范围冻结；其他布局、Legacy、自然异常未扩大。",
      "reportedAt": null,
      "reportedAtSource": "当前可见人类反馈；未取得原始消息时间，不能猜报时。",
      "firstEvidenceAt": "2026-10-24T10:23:04+00:00",
      "firstHandlingAt": "2026-10-24T10:23:04+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-24T12:19:29.702818+00:00",
      "evidencePoints": [
        "直接产物索引：ReaderImagePlaceholder.ets；reader-continuous-loading.test.cjs；E022/frame_000120.png"
      ],
      "remainingActions": [
        "本次N/E两个真实缩略图→原图→返回范围冻结；其他布局、Legacy、自然异常未扩大。"
      ],
      "boundaries": [
        "不改变原指示器样式/尺寸/转场/全屏时机，不新增宿主遮罩，不清缓存或造延时。",
        "不改变MH160与原其余队列；本次局部完成后由Root接续源错误契约及普通远端更新。"
      ],
      "evidence": [
        ".hvigor/outputs/reader-loading-background-20261011/.../shared-mutual/thumbnail-loading-*：N014原60/82"
      ]
    },
    {
      "id": "READER_WINDOW_LIFECYCLE",
      "title": "三App五入口全屏/状态栏早于转场完成",
      "status": "用户采用范围已正式合入，三宿主具名验证及精确CI完成",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root只按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "共同Kit a9d7c641已推main；N226c4df0/40220116846、E59a7a679/40220118407、K79ea6dc7/40220162027均同head completed/success。三宿主签名Release及原进度/偏好/数据保持已核，197170/237322正常timeout120000无override并释租。共同57c65de已推。N197119原1/34、E197070原13/19、K237141原001第6/24页，各自全片和两组交接原帧亲审：先状态栏，上栏出现即最终位置，无下移；正常返回保持。N/E已范围提交53ce80fc/cb052ce1，K389400f固定同依赖，三笔精确CI均success。",
      "remaining": "本次采用及具名实机范围完成并冻结；未观察布局/自然失败、显示FPS和零区域窗口不扩大，不为填矩阵重跑。",
      "reportedAt": "2026-10-22T19:12:58.799Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:12:58.799Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T18:34:37.357834+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "本次采用及具名实机范围完成并冻结；未观察布局/自然失败、显示FPS和零区域窗口不扩大，不为填矩阵重跑。"
      ],
      "boundaries": [
        "不能用didShow、enableStatusBar、布局坐标冒充动画结束；不用延时或改变已定转场效果绕过。"
      ],
      "adoptionDecision": {
        "source": "本轮当前可见用户异步答复原文",
        "answer": "采用该入场候选，完成正式合入与验证",
        "date": "2026-10-26"
      }
    },
    {
      "id": "CONTINUOUS_PERFORMANCE",
      "title": "连续滚动卡顿与新版/旧版性能差异",
      "status": "用户采用范围已正式合入，三宿主具名验证及精确CI完成",
      "kind": "accepted",
      "priority": "P0（最高）",
      "owner": "冻结：Root只按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "共同Kit a9d7c641已推main；N226c4df0/40220116846、E59a7a679/40220118407、K79ea6dc7/40220162027均同head completed/success。三宿主签名Release及原进度/偏好/数据保持已核，197170/237322正常timeout120000无override并释租。N同起点六组8000反向主线程均值4.229→3.224ms、最大24.686→17.883ms；顺序暖缓存，非cleanAB/显示FPS。N141、E073、K147普通/快回翻未再见首候选133短空。E模式黑屏另由独立加载修复处理；K147固定黑边已核为第7张原图。",
      "remaining": "本次采用及具名实机范围完成并冻结；未观察布局/自然失败、显示FPS和零区域窗口不扩大，不为填矩阵重跑。",
      "reportedAt": "2026-10-22T19:43:05.108Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:43:05.108Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T18:34:37.357834+00:00",
      "firstHandlingAtSource": "本次收到实现结果，未倒猜该实现的开始时间。",
      "evidencePaths": [
        "/Users/honjow/git/Koma/.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/continuous-perf197-before-001/parsed-cwd/summary.json",
        "/Users/honjow/git/Koma/.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/continuous-perf197-after-001/parsed-cwd/summary.json",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/continuous-trace-007/parsed-cwd/nexte-host-frame-stats.json",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/continuous-motion-008",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/restore-ltr-009",
        "/Users/honjow/git/NextE/.hvigor/outputs/continuous-reader-performance/device197__ALN-AL80/not-applicable/portrait-1260x2720/restore-verified-010",
        "/Users/honjow/git/Koma/.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/continuous-fast197-trace-007/parsed-cwd/trace.db"
      ],
      "latestCounterexampleAt": "2026-10-23T04:57:37.180Z",
      "evidencePoints": [],
      "remainingActions": [
        "本次采用及具名实机范围完成并冻结；未观察布局/自然失败、显示FPS和零区域窗口不扩大，不为填矩阵重跑。"
      ],
      "boundaries": [
        "这些是host主线程切片及三宿主具名运动/缩略条行为，不等同显示FPS、满帧或全内容通过。NextN050是34页真实样本，旧两页证据不能替代它。设置位置与全屏时机仍独立。"
      ],
      "modificationBasis": {
        "object": "ReaderContinuousCell输入投影，ReaderContinuousList现有按key挂载",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "按稳定page key复用native List及单元；Core负责资源状态和请求身份，UI不能另建选章/进度owner。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅连续单元使用最小渲染投影；稳定displayed original且无新请求/retained/失败/notice/cropPending时，按完整页元数据、slot/request/URI/variant/visual/crop及navigation比较复用；加载/替换/失败仍逐次接新frame。保全局Core快照/进度、native key、图片与缩略条实例、几何、样式、转场。缓存仅现有窗口，离开/拓扑变化丢弃。"
      },
      "diagnosticBasis": {
        "object": "ReaderSession.load与ReaderPagedSession.reportPresentation的临时阶段日志",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅在当前原图获取成功和有效解码回执补source/request/variant/阶段与耗时；不记录URI/书名/凭据，不改任何状态、窗口、加载反馈、样式、资源、预载或进度。临时诊断完成后撤下，保留原片/日志和精确补丁。"
      },
      "diagnosticBasisNative": {
        "object": "ReaderPagedViewport.ReaderPagedImage的临时native-mounted/decoded/drawable阶段日志",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅增加source/slot/request/variant/阶段/几何的观察日志，并保留原条件、回调与资源顺序；同一普通路径有限取证后完整撤下并恢复稳定包/LTR1/34/下载。不得删除加载反馈、几何保护或改变质量/预载。"
      },
      "cacheCandidateBasis": {
        "object": "ReaderPagedSession.windowIndexes / snapshot.nativeCacheDepth，仅continuous分支",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "连续模式可见范围加一页邻居，并至多保一个刚离窗、距可见边界两格的现有租约；相应原生cache覆盖该lease、处理需求保持。远跳/预载零退休；0–5文件预算、分页/双页、偏好、原图质量、UI/加载交接及Legacy保持。仍只候选。"
      },
      "entryDiagnosticBasis": {
        "object": "N消费ReaderContinuousList四行临时日志",
        "allowedDifference": "仅观察active/pending/flight/moving/fullyVisible/entry/target；不改守卫、输入、渲染或资源。原片与日志保留，定位后精确撤回，诊断包不作性能对照。"
      },
      "adoptionDecision": {
        "source": "本轮当前可见用户异步答复原文",
        "answer": "采用 v3，完成正式合入与验证",
        "date": "2026-10-26"
      }
    },
    {
      "id": "FIRST_CHAPTER_SELECTION",
      "title": "无历史书架首次阅读误开最新一话",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "kind": "accepted",
      "priority": "P1",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "dependencies": [],
      "result": "原Mihon源序/最早未读规则及漫画屋/漫画160方向交付保持，斗破普通首次01/36已有具名证据。新增BlueArchive011已核当前官网15→1及互逆1→15链、标准包/实际WASM/生产firstReaderChapter回放，d936a31e已推且精确CI40231212151含原子发布成功；固定tag公开包325356B实际ZIP/011/newest_first/icon字节已核。237358一次普通本地更新成功，359原81顺序/enabled保持；361真实旧PID→ABSENT→新PID冷恢复后方向声明及五域同359。保已有读态，不冒Native新首次正文，也不把改余源前核合同变成必须给其他源全声明。",
      "remaining": "本项原首次选择规则已具名闭环；其他源改前核方向是实施门禁，不是必须全源声明。元尊挑战/漫画160与漫画柜正文网络归各自源项，不冒Native新首次正文。",
      "reportedAt": "2026-10-22T18:44:10.746Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 171556010 重新读原文与时间戳，不是摘要/登记时间。",
      "firstEvidenceAt": "2026-10-22T18:44:10.746Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "evidencePoints": [
        "直接产物索引：.hvigor/outputs/user-flow-audit/bluearchive-current-catalogue-20261026.json及同目录bluearchive-current-chain-20261026.json；.hvigor/outputs/user-flow-audit/bluearchive-current-catalogue-20261026.json；bluearchive-current-chain-20261026.json；bluearchive011-chronology-replay-20261026.json；manifest/source.wasm/icon.png；bluearchive011-publication-20261026.json；bluearchive011-cold-rejected-multiline-361.json"
      ],
      "remainingActions": [
        "本项原首次选择规则已具名闭环；其他源改前核方向是实施门禁，不是必须全源声明。元尊挑战/漫画160与漫画柜正文网络归各自源项，不冒Native新首次正文。"
      ],
      "boundaries": [
        "197只验同ID信息保存和原Extra2进度保持；没有清历史伪造首次阅读，不称全源首章/排序已完成。",
        "漫画160本轮仍缺成功详情HTML；781章混季反证与唯一403原件已复核，不猜标题首数或倒序。"
      ],
      "modificationBasisMihonFirstUnread": {
        "object": "首次阅读共享选择器与已安装源章序声明；详情/书架/配置fallback",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "没有统一来源方向时避免盲目全反转，保已存进度和显式章选择。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "有准确章序声明的源，按其源序选择最早未读，既有进度/显式目标优先；源输出/菜单/样式不改。声明归源包metadata，经现有导入/持久/冷恢复/备份合同保留，不按源ID硬编码，不从标题/编号猜时间方向。缺声明保持旧fallback，后继逐源核清再声明。"
      },
      "modificationBasisMh160Chronology": {
        "object": "漫画160源包chapterOrder声明，不改get_chapters输出",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "跨季和番外目录没有可靠话数，不得凭标题首数排序或伪造编号。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅本源新增newest_first声明及交付版本014→015；全部782旧ID/顺序/未知话数、请求、权限、源UI/图标保持。生产选择器对已有源序取最早未读，不改目录展示、不重请已失败章节/网站或称正文恢复。"
      },
      "continuationGate": {
        "checkedAt": "2026-10-25T20:46:46.183996+00:00",
        "owner": "Root",
        "condition": "本次三源实际交付/公开包/普通更新/冷恢复已闭环，不再写可提交或待更新，不重跑已交付三源。仅新实际反例/某源拟修改时核其合同，不自行扩成其他源矩阵；相关网页可用性另归源项。"
      },
      "reportedAgeAtAudit": "3天0小时49分41秒",
      "reportedAgeSecondsAtAudit": 262181,
      "reportedDate": "2026-10-23",
      "reportedDateSource": "按上述原始UTC首报换算Asia/Shanghai日期，不使用登记日。",
      "continuationClass": "具名已交付；其余仅改前合同门禁/另项可用性，不是全源验收欠账"
    },
    {
      "id": "CHAPTER_SORT_MENU",
      "title": "章节排序菜单无作用",
      "status": "本轮限定修复已推送，三宿主构建与精确CI成功",
      "kind": "done",
      "priority": "P0（人类再次复现：通用排序及菜单状态）",
      "owner": "Root：包子012具名范围冻结；未知metadata继续原项",
      "dependencies": [],
      "result": "237784章全unknown的源原序/整表反序、独立依据/方向对勾、同项禁重选均成立；最终109反序后实际重置回源目录正序，无重置按钮，首行恢复第2季354。64相关检查通过。",
      "remaining": "已具名路径冻结；只按新反馈或相关依赖变化重开。Reader跨季年代、旧系统/暗色及未打开菜单分支未外推。",
      "reportedAt": "2026-10-22T18:49:32.812Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:49:32.812Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-24T19:25:24.086002+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "已具名路径冻结；只按新反馈或相关依赖变化重开。Reader跨季年代、旧系统/暗色及未打开菜单分支未外推。"
      ],
      "boundaries": [
        "本次新反馈明确重开通用展示反序与菜单状态，不继续按源补章号来掩盖菜单缺陷。",
        "原始章节对象/ID/源返回顺序、持久阅读数据和Reader自动邻章语义保持；跨季年代不能由显示反序推定。",
        "允许差异为升降序真正互逆、默认降序单一状态、原生选中对勾和同项选择无变更；不改控件尺寸/排布/字体。"
      ],
      "modificationBasis": {
        "object": "ChapterListSection展示排序和MangaDetailModels排序状态；原章节对象/ID不变",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "话数语义比较保留；源目录和可选数值不能混为同一排序输入。旧二项菜单未同步默认状态。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "SOURCE_ORDER/CHAPTER_NUMBER与FORWARD/REVERSE独立，整表反转；原生选中标记、当前项无重选；排序分组小号常规字及公共材质。保其他布局、ID、读态和Reader邻章语义。"
      }
    },
    {
      "id": "APP_POPUP_SYSTEM_MATERIAL",
      "title": "菜单与半模态漏接系统新材质",
      "kind": "done",
      "priority": "P1（当前人类连续反馈）",
      "owner": "Root：Koma具名范围完成；N/E两处fallback已核普通生产不适用",
      "dependencies": [],
      "reportedAt": "2026-10-24T18:01:49.053271+00:00",
      "reportedAtSource": "本轮登记时间；原始提出时间未作推算。",
      "firstHandlingAt": "2026-10-24T18:01:49.053271+00:00",
      "closedAt": "2026-10-24T19:25:24.086002+00:00",
      "evidencePoints": [],
      "status": "Koma具名完成；N/E RuntimeMenu fallback普通生产不适用，仅保构建证据",
      "result": "237 API26：093排序菜单透出模糊目录/小号常规分组标题；096书架筛选、099索引表单、104包子源设置均呈现原生半模态材质。097完整往返219帧顺序审阅，并看054/076/112/125/185原帧。 最终8547952B包/Kit9b94e98已装237；105→106书库/Reader/源注册表逐字相同。",
      "remaining": "Koma已打开菜单/筛选/源设置具名范围保留；N/E这两处RuntimeMenu fallback在普通生产调用不展示，不再列为待执行普通实机验收。旧系统/暗色/其他未观察菜单不外推。",
      "modificationBasis": {
        "object": "宿主原生菜单/半模态选项及KomaModalScaffold背景；ChapterListSection排序分组标题",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "已有公共模态导航/关闭/滚动结构保留；未找到排除新材质的决定，不把未找到当旧授权。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅补官方沉浸材质、支持版本的模态内容透明和排序分组小号常规字；旧系统保原底色。保动作/尺寸/位置/展开档位/键盘/生命周期/选中状态。"
      },
      "remainingActions": [
        "Koma237具名结果保持；N/E当前普通生产唯一ReaderSurface均无条件传modeControl，N入口hostSettingsAvailable=true，E生产preferencesReadWrite走hostSettings，因此共享ReaderChrome两处RuntimeMenu fallback普通路径不展示。仅保原构建/CI证据，不造入口、不重跑宿主主菜单、不冒设备通过。",
        "旧系统/暗色和未观察菜单保范围边界；只在真实新反例或消费合同改变后重开对应路径。"
      ],
      "boundaries": [
        "宿主40处弹层仅增加材质；HDS导航溢出菜单103原生材质已存在，不替换其实现。",
        "共享层沿用另外三个菜单已使用的THICK及API26检测，只补漏项；不变Reader偏好/控件选项/窗口生命周期。"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T20:07:54.588831+00:00",
        "owner": "Root",
        "condition": "N/E这两处fallback当前普通生产不适用，仅保原构建/CI，不再列普通实机待办；现有正常宿主菜单不重跑，需真实消费合同改变才重开。"
      }
    },
    {
      "id": "READER_SETTINGS_STABILITY",
      "title": "阅读设置菜单跳变及动态本书后缀",
      "status": "原菜单/方向回显/保位具名收束；K339遮挡段仅EVIDENCE_ONLY",
      "kind": "accepted",
      "priority": "P1（阅读设置正确性）",
      "owner": "Root：原菜单/方向/保位与既有反馈具名范围完成；新反例才重开",
      "dependencies": [],
      "result": "原设置菜单、方向回显与模式保位已有具名修复及三宿主精确CI；E080/N145加载v2反馈完整观察成立。本轮339全389帧/11表已Root顺审，菜单四项固定、单页→连续→单页选中正确、无动态本书后缀、关sheet/重开保1/36，340原书架与Single/LTR及和全局一致回读。K339约20.7ms/33.2ms可见上方正文短黑，但loading中心被sheet遮挡，不能证明反馈不存在或新违反，不冒全加载通过。",
      "remaining": "原菜单/方向回显/保位与具名反馈范围已完成；K339遮挡只作EVIDENCE_ONLY，未冒全加载通过，不将Root推断零黑要求扩大为未闭原缺陷。",
      "reportedAt": "2026-10-22T18:52:07.192Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 172276684 重新读原文与时间戳，不是摘要/登记时间。",
      "firstEvidenceAt": "2026-10-22T18:52:07.192Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T20:22:03.270524+00:00",
      "reopenedAt": "2026-10-23T04:52:35.917Z",
      "reopenedAtSource": "原始会话JSONL response_item/user核得新反例首报，非当前登记时间。",
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET"
      ],
      "evidencePoints": [],
      "remainingActions": [
        "按原人类菜单/模式方向回显/保位要求及E080/N145既有反馈具名结果收束；K339遮挡片段保EVIDENCE_ONLY，不外推全部加载或所有布局。未观察范围不自动派新矩阵。",
        "保3a7b56d/e3f3cc1及共同工作单2026-10-20图片/加载显示互斥合同；没有用户要求旧图一直保留/零黑的新依据，不为消片段让旧图+loading重叠或擅移loading到sheet上方。真实新反例另按当前证据重开。"
      ],
      "boundaries": [
        "E080与N145仅当前样本模式往返；N147是缓存缩略图入口，无自然请求等待。K151反馈位置被sheet遮挡，未声明等待段可见。Legacy、失败恢复、全屏入场总项不扩认。",
        "K339短黑原帧是有限像素观察；被sheet遮挡的loading中心没有直接可见证据，不将不可见误作不存在。原模式/图片加载互斥决定优先，未经明确差异许可不保旧图叠loading或移loading位置。"
      ],
      "modificationBasis": {
        "object": "ReaderImagePresentation中Core displayed与当前原生Image解码身份的交接，以及ReaderNativePager首次尺寸测量交接",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "资源租约和原生像素是不同生命周期；可读旧图的原替换分支不应被加载层覆盖，entry隐藏原图时反馈不能提前退出。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "只让原图displayed资源在新原生单元取得匹配解码回执前沿用既有加载反馈；保持同节点已解码、retained替换、entry reveal、失败、缩略图、布局、读位和清晰度。先扩一个真实生命周期检查证反例，再实机观察，不自造新加载样式。 仅在现有Pager尺寸未知时由同一个既有ReaderImagePlaceholder提供整视口反馈，尺寸有效后交回页内；不覆盖已可读图片，不更换滚动或转场。"
      },
      "continuationGate": {
        "checkedAt": "2026-10-25T20:22:03.270524+00:00",
        "owner": "Root",
        "condition": "原缺陷具名范围收束，K339遮挡保EVIDENCE_ONLY且不外推；Root自己推断的零黑/旧图常驻不是原要求，不能据此续派矩阵。仅新实际反例或相关合同改变重开。"
      },
      "reportedAgeAtAudit": "3天0小时41分44秒",
      "reportedAgeSecondsAtAudit": 261704,
      "reportedDate": "2026-10-23",
      "reportedDateSource": "按上述原始UTC首报换算Asia/Shanghai日期，不使用登记日。",
      "closedAtSource": "Root核原始用户措辞、339/340/341普通路径及既有E080/N145反馈，并追3a7b56d/e3f3cc1互斥边界后本次登记；不是用户接受时间或全面加载验收。"
    },
    {
      "id": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "title": "自动跨章回退误落首图，应落上一章末页",
      "priority": "P1（阅读正确性）",
      "owner": "Root：shared Reader与Host跨章节预载",
      "dependencies": [],
      "relatedItems": [
        "READER_SETTINGS_STABILITY",
        "NEXT_CHAPTER_PREFETCH_REUSE"
      ],
      "status": "具名设备路径及精确CI完成",
      "kind": "done",
      "result": "197具名跨章预载、方向和点击路径已验证，App及书源提交精确CI成功。",
      "remaining": "",
      "reportedAt": "2026-10-23T04:55:39.469Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 372447921 重新读原文与时间戳，不是摘要/登记时间。",
      "firstEvidenceAt": "2026-10-23T04:55:39.469Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-30T13:47:21+08:00",
      "evidencePoints": [
        "直接产物索引：.hvigor/outputs/continuous-position-rejected-072.patch；reader-kit提交7744665155743b4c62b2e21166e22ace76b9e27c，119关键回归通过；Koma接入提交5d966878；197清理HAP SHA-256 f6749b58303015d413fea24d2baf4030375a9958c27f7a760defb9793d8fe889。自然终点反例58/59；MeasuredPosition改用原生getItemRect实际边界而非推算imageHeight，参考官方API与Mihon同规则，61/62设备回验。reader-kit 7744665与cab2118已推main并读回cab；Koma 229daf3c精确CI40651937090失败，漏偏好/state/bridge等调用依赖；补齐提交091d2b6758c94bb0d58130f6b9626a052f6ce787已推master，精确CI40655062200 completed/success，连接器读回head_sha一致。",
        "重开前原result逐字保留：197 Blue横向双方向及连续章、MH1234多页RTL、Nemo多页纵向往返具名范围已核，精确CI成功，设备已恢复。",
        "用户本轮直接反馈跨章节预载仍未发生；精确消息时刻未知，此为登记时间。原具名验收与证据保留，不推断根因。",
        "ChapterListSection排序仅操作slice，不污染原catalog；Adapter.adjacent缺continuation时fallback raw chapterIds，preloadNextUnit缺continuation直接return，source chapterOrder此前仅供首次阅读。候选ReaderChapterSequence仅全目录无显式组限制时按sourceOrder派生chronological，shelf/transient接入，source adjacent/Legacy不再退raw；33相关执行回归及release/debugfalse构建通过。197原包Blue已见next_unit depth2/后续source ready，RTL右滑第二部第四到第五，见reader-continuation/boundary-original-continue-302及boundary-original-rtl-forward-303；不外推漫画160新分支，亦不称用户全部反馈唯一根因。",
        "候选进一步发现持久库数组可能经历史合并而不再保持源序，不能简单反转旧库数组；正在补从完整源目录生成并持久保存阅读序号，尚未验收。",
        "SourceChapterChronology仅完整get_chapters分页终点、无显式组/序且chapterOrder明确时生成source-catalog+readingOrder，持久化现有字段；旧库缺序时后台解析完整目录，当前页不等待，refreshAdjacency仅发布邻章并续预载不重载图片；同卷(卷,章)比较，显式ordinal不与卷/话号混比。关键回归及本地构建通过，197未装新候选。根目录mh160-retained-catalog-chronology.json为早期未含持久数组反例的执行记录，不冒最终after算法，待后继记录取代。",
        "reader-kit 9afdada已推，refreshAdjacency仅刷新邻接/预载，保当前anchor/topology/解码图；Koma workflow已pin。197 boundary-014-install-313安装并启动0.1.4/code5/release/debugfalse同签候选HAP 27f332dd881ab4820dd3487278ae627dc6d75473308bfbd875b718ea572bd57d；临时xkcd候选按sourceOrder无组路径验新ordinal，原源四成员已备，197/237仍持租。版本未tag发布。",
        "完整源目录source-catalog ordinal后台补齐旧库676章；322真实next_unit depth2及两未来页ready。326 RTL 2937→2974→2975并反向返回，连续原片14表全审，无加载面板/空白、Toast正确。328 LTR左滑两次到2974，329左点击两次到2975，330右点击两次回2974；331用户原配置tapZonePreset=right_left、tapZoneInvert=horizontal，329/330动作名写反而非新方向bug，原收据不改。点击跨章原片与恢复仍待；证据reader-continuation/boundary-xkcd-*及xkcd-rtl-chronology-motion-326。",
        "书源章序本地候选未提交发布：六漫画newest_first（固定949/真实DOM）、无限动漫oldest_first（固定949反转/30513真实1→6）、ComicFury newest_first、嗨皮oldest_first（order=asc，DNS边界保留）、MANGA Plus Creators newest_first。Zero PC真实完整数组ordinal含锁章，真实23185 HTML回放32项且旧Host/请求不变；Pixiv按唯一content_order，受控WASM及两份真实搜索系列对照；漫画人原数组group/有效sectionSort含锁章，缺值不自动续读，受控WASM旧Host相等。MHR编译含原WIP，均未发布/设备验收；妙趣同编号不同路径、MangaDex多组及Nami组织身份未安全统一，不称全部覆盖。",
        "332 LTR+原horizontal反转，2974左半→右半→2975及反向，211帧/6表全审，实际无2976，manifest动作名多算拆页；一进一退Toast匹配、无加载/空白。341 library76与302逐字同、registry与304同、xkcd原4成员337与314同；方向恢复RTL、其他Reader key同331，sessions仅Blue三个updatedAt变化；339/340 Blue第四话1/1亲审。临时包目录/下载不存在，SLEEP/120000/Override10000，lease20261030-041655-fcce974d released。App保无诊断0.1.4/code5 final HAP38d2456b09842e9f8b689dc3cc6f7968416a088be4ca1ea829a0ec4e0389dea5，同db31 cert/profile，不称原HAP恢复。App b4a4f990已推，CI41009239020版本一致性失败因未同步oh-package，补995ba6bb推送中、新CI待；源04fa4a9已推、CI41009585265待。",
        "koma-sources 04fa4a9b2c134ac8261eb55eb37ce124b8457aff精确CI41009585265 completed/success；14正式ZIP匹配release digest、manifest等候选，index版本/方向一致，公开WASM source_info版本已执行；/private/tmp/koma-order-published-04fa4a9/identity.json。14源不冒全部Native，xkcd Native为旧015+本地metadata016候选、正式017仅版本/metadata变化。Zero/Pixiv/MHR/Iqiyi/XCOMIC代码候选未交付，MangaDex/Nami/妙趣未知不扩大。",
        "Koma 995ba6bb101d091c1ba0bab2842ff9a2e5037dc7精确CI41009792919 completed/success、artifact已上传、tag发布job skipped；14源04fa4a9精确CI41009585265及正式实体已核。"
      ],
      "remainingActions": [],
      "boundaries": [
        "保显式选章与既有续读语义；不以isAtEnd强改页码、不延时抢滚动。不能从本路径宣称全部Reader通过。",
        "不外推全部Reader或尚未核实分组源。"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T20:46:46.183996+00:00",
        "owner": "Root",
        "condition": "Koma当前适用具名修复完成；N/E普通合同不适用。未来合同变化/真实反例才重开，不以未外推全Reader扩任务。"
      },
      "reportedAgeAtAudit": "2天14小时38分12秒",
      "reportedAgeSecondsAtAudit": 225492,
      "reportedDate": "2026-10-23",
      "reportedDateSource": "按上述原始UTC首报换算Asia/Shanghai日期，不使用登记日。",
      "closedAtSource": "Root本轮核当前N/E单unit/adjacent null消费合同并对照Koma既有具名实证后登记；不是N/E实机跨章验收或用户接受时间。",
      "stage": "具名范围已交付",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-scroll-motion-05/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-motion-09/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v2-motion-12/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/candidate-v3-install-23/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/candidate-v3-reader-25/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v3-motion-26/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/candidate-v3-return-27/",
        "/private/tmp/nextn-continuous-handoff-build.log",
        "/private/tmp/nexte-continuous-handoff-build.log",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-reader-32/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-motion-33/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-progress-34/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-return-35/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-final-install-36/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-final-reader-37/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-final-motion-38/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-delivery-motion-43/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-delivery-return-44/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-reverse-lead-motion-46/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-position-probe-motion-48/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-stable-head-probe-motion-50/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-page-end-motion-52/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-page-end-return-53/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-clean-reenter-54/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-clean-natural-motion-55/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-clean-terminal-56/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-footer-motion-58/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-clean-return-59/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-ltr-boundary-motion-66/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-ltr-boundary-observed-67/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-rtl-boundary-ready-68/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-motion-71/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-observed-72/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-ltr-motion-74/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-chapters-motion-76/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-progress-77/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-multipage-boundary-motion-81/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-multipage-returned-82/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-multipage-restore-83/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-install-84/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-vertical-last-85/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-vertical-boundary-motion-86/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-vertical-returned-87/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-nemo-restore-89/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-bookshelf-resume-90/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-blue-direction-93/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-blue-motion-95/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-blue-return-96/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-bookshelf-97/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-session-restore-98/",
        "同签release候选SHA256 352367e82de8dcfcd580e6ed3024ea30af820949fe2f927bd38cae5a34b52d2c，197 run176门禁及基线进行中，未安装。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/nemo-local-preload-vertical-roundtrip-180/",
        "run180录屏SHA256 48a015c71646a407b579c1da5aff67d18a4d8eb5906cb06a2c6152454e594d4b；371帧全审，反向返回2/3。",
        "197 run185/187已准备下一章及四行并通知，188两次向前target仍当前页、反向正常；文件未预载不是本次原因。",
        "run190同样1100px上滑在章内1→1也回弹，故180/188不能证明Native ADD通知异常；RELOAD试验及临时日志已撤回，不作修复。原352候选重装，待更长手势回验。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/nemo-original-native-full-swipe-roundtrip-192/",
        "run192录屏SHA256 8ed97737009b18de19f162c1ac4f60c984dcc6d2fcb28efdc00437b845438394；Nemo3/3→Chapter1/1→Nemo3/3，352帧全审；Koma 413adbd76b26b7789b58ae95d80c535b01b7adb3 CI40790249371进行中。",
        "收口前原结果：197 Nemo纵向分页完整滑动可连续进入下一章并回到前章末页，画面连续且章节提示对应；原App、数据与电源已恢复并释租。",
        "https://github.com/honjow/Koma/actions/runs/40790249371"
      ],
      "reopenedAt": "2026-10-30T12:12:54+08:00"
    },
    {
      "id": "NEXT_CHAPTER_PREFETCH_REUSE",
      "title": "接近章末预加载下一章及跨章请求复用",
      "priority": "P2（当前P0后，与跨章联动核查）",
      "owner": "Root：原请求具名范围已交付，保未外推及实施授权边界",
      "dependencies": [],
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET",
        "CONTINUOUS_PERFORMANCE"
      ],
      "status": "近章尾预取及跨章ready复用已具名交付，inflight时序未外推",
      "kind": "accepted",
      "result": "d3187726含505651f精确CI40021847034 success；274已恢复原14（原2/15）并close成功。鲜网络/ready采用具名范围保留，inflight join仍未自然命中。",
      "remaining": "原近章尾预加载/跨章复用请求已由fresh与ready具名路径覆盖，无当前待办；inflight join仍未自然命中且未外推，仅新真实反例重开，不造并发/清缓存。",
      "reportedAt": "2026-10-23T05:33:34.382Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 381614824 重新读原文与时间戳，不是摘要/登记时间。",
      "firstEvidenceAt": "2026-10-23T05:33:34.382Z",
      "firstHandlingAt": "2026-10-23T18:06:01.504859+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:52:22+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "原近章尾预加载/跨章复用请求已由fresh与ready具名路径覆盖，无当前待办；inflight join仍未自然命中且未外推，仅新真实反例重开，不造并发/清缓存。"
      ],
      "boundaries": [
        "只预取严格continuation的下一章，不用完整手选目录回退；至多一章、顺序暖不超过既有预加载页数。",
        "准备可以沿既有源页缓存落元数据，但不得提交当前章/阅读位置/历史；只在实际观测后按原路径提交读态。",
        "N/E不实现可选相邻单元预取则无新增网络；保Legacy及现有页内预加载，先查历史再改。"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "只缺自然inflight join；不造并发/清缓存，fresh/ready路径冻结。"
      },
      "reportedAgeAtAudit": "2天14小时0分17秒",
      "reportedAgeSecondsAtAudit": 223217,
      "reportedDate": "2026-10-23",
      "reportedDateSource": "按上述原始UTC首报换算Asia/Shanghai日期，不使用登记日。"
    },
    {
      "id": "READER_PRESET_SHEET",
      "title": "点击预设后设置半模态被自行收起",
      "status": "具名实机通过，已随f7a6a7d提交推送并冻结",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [
        "READER_SETTINGS_STABILITY"
      ],
      "result": "具名实机通过，已随f7a6a7d提交推送并冻结",
      "remaining": "原具名验收范围冻结，不重复操作；未覆盖设置分支仅保边界，不以此自行扩成新矩阵。",
      "reportedAt": "2026-10-22T18:56:37.543Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:56:37.543Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "evidencePoints": [],
      "remainingActions": [
        "原具名验收范围冻结，不重复操作；未覆盖设置分支仅保边界，不以此自行扩成新矩阵。"
      ],
      "boundaries": []
    },
    {
      "id": "CONTINUOUS_PAGE_GAPS",
      "title": "连续滚动页间黑条",
      "status": "Chibi具名接缝通过，已提交推送并冻结",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "Chibi具名接缝通过，已提交推送并冻结",
      "remaining": "Chibi原范围保持；K147第6/7张固定黑边来自源图，不作为本轮间距回归。连续性能按独立项推进。",
      "reportedAt": "2026-10-22T19:43:05.108Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:43:05.108Z",
      "firstHandlingAt": "2026-10-22T20:00:18.424763+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "firstHandlingAtSource": "Root实际开始消息后首次可核分段登记；更早处理起点未知。",
      "evidencePoints": [
        "直接产物索引：reader-controls197-interaction-002/continuous-before.png；6.jpg/7.jpg"
      ],
      "remainingActions": [
        "Chibi原范围保持；K147第6/7张固定黑边来自源图，不作为本轮间距回归。连续性能按独立项推进。"
      ],
      "boundaries": []
    },
    {
      "id": "READER_DIRECTION_MENU",
      "title": "阅读方向菜单混入单页/双页且重复布局入口",
      "status": "方向/独立单双页具名通过，f7a6a7d已推，CI成功",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "方向/独立单双页具名通过，f7a6a7d已推，CI成功",
      "remaining": "已具名动作/PNG冻结，不重跑；Legacy未改、运动区间未扩大。f7a6a7d精确CI39883471325已success，不等同后续WIP实机通过。",
      "reportedAt": "2026-10-22T19:43:05.108Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:43:05.108Z",
      "firstHandlingAt": "2026-10-22T20:00:18.424763+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "firstHandlingAtSource": "Root实际开始消息后首次可核分段登记；更早处理起点未知。",
      "evidencePoints": [],
      "remainingActions": [
        "已具名动作/PNG冻结，不重跑；Legacy未改、运动区间未扩大。f7a6a7d精确CI39883471325已success，不等同后续WIP实机通过。"
      ],
      "boundaries": []
    },
    {
      "id": "TAB_HEADER_SCROLL_OWNER",
      "title": "根Tab标题栏模糊继承另一页状态",
      "status": "Library/Settings具名通过，a4ec2eb已提交冻结",
      "kind": "accepted",
      "priority": "P1",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "Library/Settings具名通过，a4ec2eb已提交冻结",
      "remaining": "只冻结Library/Settings已审范围；其他Tab未覆盖，不从这项自动生成重复验收。",
      "reportedAt": "2026-10-22T19:36:59.975Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:36:59.975Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "evidencePoints": [],
      "remainingActions": [
        "只冻结Library/Settings已审范围；其他Tab未覆盖，不从这项自动生成重复验收。"
      ],
      "boundaries": []
    },
    {
      "id": "BAOZIMH_BROWSE_FAILURE",
      "title": "包子漫画安装后源浏览失败/重试无效",
      "status": "两书具名恢复/已推7b3f196，精确CI成功",
      "kind": "accepted",
      "priority": "P1",
      "owner": "Root：7b3f196实际push/精确CI；已过样本冻结",
      "dependencies": [
        "SOURCE_WEB_SESSION"
      ],
      "result": "包子两书详情、强刷与一书正文已恢复；挑战会话稳定性与自动成功回流仍由WEB项继续。",
      "remaining": "继续WEB项的会话revision、自动确认成功回流及自然失败恢复；重复章与排序分别维护。",
      "reportedAt": "2026-10-22T18:40:36.532Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:40:36.532Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "reopenedAt": "2026-10-23T05:31:18.350Z",
      "latestCounterexampleAt": "2026-10-23T05:37:16.993Z",
      "feedbackReports": [
        {
          "reportedAt": "2026-10-23T05:37:16.993Z",
          "source": "原JSONL response_item/user",
          "summary": "网页完成后列表恢复、多详情失败部分有章、重入不恢复，缺不带缓存刷新；缓存根因未证。"
        }
      ],
      "evidencePoints": [],
      "remainingActions": [
        "继续WEB项的会话revision、自动确认成功回流及自然失败恢复；重复章与排序分别维护。"
      ],
      "boundaries": [
        "仅033–038两书与一书正文/返回冻结，不泛化所有书/源，不把所有403当CF或失败缓存。"
      ]
    },
    {
      "id": "SOURCE_RUNTIME_ERRORS",
      "title": "源错误只显示source_runtime且日志不可诊断",
      "status": "原笼统错误/日志及六Native边界具名修复已交付，网站可用性独立",
      "kind": "accepted",
      "priority": "P1",
      "owner": "Root：原人类触发的具名范围已交付，保其它源/失败分支边界",
      "dependencies": [],
      "result": "六个生产Native并发入口已集中到独立SourceRuntimeWorker，原请求/会话/复制字节/队列/取消/诊断保留。237明确安装8569786B签名Release，新进程42856完整159行hilog覆盖17:07:17–17:10:33，首次worker43025及取页worker44500无ReferenceError；正常幻塔列表/详情/章节/取页及正文、自然返回成立。197空图片描述修复旧范围继续冻结。 已同步master：34e83b8bd10f2b1c61c002e070800226551b332a；精确CI40179763215 completed/success，tag发布job skipped，无新tag/发布。",
      "remaining": "原笼统source_runtime/日志不足的具名诊断范围已交付，无本项当前待办；rate_limit用户提示、票据图片/下载恢复等自然分支未外推，包子/3H/漫画160网站可用性仍归各自原项，不把模块隔离冒正文恢复或性能解决。",
      "reportedAt": "2026-10-22T18:40:36.532Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 171216188 重新读原文与时间戳，不是摘要/登记时间。",
      "firstEvidenceAt": "2026-10-22T18:40:36.532Z",
      "firstHandlingAt": "2026-10-23T15:43:46.545761+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:55:15+00:00",
      "relatedItems": [
        "SOURCE_WEB_SESSION"
      ],
      "evidencePoints": [],
      "remainingActions": [
        "原笼统source_runtime/日志不足的具名诊断范围已交付，无本项当前待办；rate_limit用户提示、票据图片/下载恢复等自然分支未外推，包子/3H/漫画160网站可用性仍归各自原项，不把模块隔离冒正文恢复或性能解决。"
      ],
      "boundaries": [
        "首页/首搜/两书详情具名范围冻结；正常空结果、所有错误未扩认。漫画柜不能归因parser/CF；包子403性质按日志区分，不能仅HTTP即挑战。"
      ],
      "modificationBasis": {
        "object": "SourceRuntimeError已知错误白名单及类别分支",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "保留明确原因且不将源任意message/code泄露给用户或日志，HTTP明确状态优先。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "只补not_implemented/not_supported/rate_limit三个明确既有代码的对应类别，保原代码诊断、HTTP优先级、未知脱敏、UI布局及原有翻译。不得据此声称图片403或全源错误已修复。",
        "mh160Challenge": {
          "object": "mh160 fetch→detail/list/chapters/pages→execute的错误契约及源web-session-origins声明",
          "history": "bcfb9261引入源时以静态字符串丢弃HTTP状态；62a1d18只补URL，不改错误。现漫画屋已有类型化Http/Challenge传播，包子亦单独保明确访问信号。",
          "originalReason": "HTML解析错误与网络失败分开；403本身不推断CF，只有Host标准化挑战信号可触发。",
          "reopenEvidence": "572搜索Host原GET403/5839chars且access_signal=challenge_required，源operation却permission_denied/http0；源无webSessionOrigins。",
          "allowedDifference": "将真实HTTP状态与Host顶层明确challenge_required按类型传到既有错误envelope，并声明仅已使用的www.mh160mh.com/m.mh160mh.com两个HTTPS源origin。保URL、请求方法/次数/UA、站点选择、成功解析、章节身份/排序、图标及App版本；不把任意403或正文标记识别成CF。源小版本步进供正常远端更新。"
        },
        "imageDescriptorAbsence": {
          "object": "ReaderPageSourceAdapter.resolveSourceRuntimeImageRequest与既有source_info worker",
          "history": "0067b4b5在安装时检测能力；980cc8a4保留未声明imageRequest的旧包尝试与直接URL回退，3a8fef32保文件命中优先。",
          "originalReason": "旧包能力缺失不等于不支持；票据/Referer/源设置不能靠猜测跳过。",
          "reopenEvidence": "588真实漫画160逐图get_image_request反复not_implemented、每次约14–28ms；589注册表无imageRequest，当前源码明确image_request:false且处理器始终not_implemented。",
          "allowedDifference": "仅在未声明imageRequest时，用同包source_info明确布尔false确认；每份WASM对象只共享一次无网络worker查询。未知、失败及支持者保原流程；不改变缓存身份/强刷/HTTP/凭据/UA/UI，不持久化能力推测。 明确不需要不再逐图记失败；未知/实际描述失败保原警告，已声明必需能力仍失败关闭。"
        },
        "workerModule": {
          "object": "Service、Browse、详情、章节、取页与图片请求六个生产Native并发入口的共同模块边界",
          "history": "c43cf027恢复复制字节的TaskPool请求；f4caffaa复用此入口探测能力；34ab280d保受限网页会话参数。Runner的runSourceOperationFromBytes当前仅原样调用NativeSourceRuntime。；40f476c1保Browse异步raw Native与串行队列；8eaeb26e取页、b486da30详情/章节及既有图片入口为同类内联Concurrent。",
          "originalReason": "让主线程在WAMR与HTTP等待时yield，保请求准入、复制字节、受限Cookie/UA与返回时source_changed检查。",
          "reopenEvidence": "237157首次worker24633在16:21:36.136报InteropConfigureStateMgmt/Trace未定义，堆栈直指LanguageState。官方TaskPool使用规范明确：子线程会解析传递依赖中的UI装饰器，即使未调用也会失败。不能据此归因47ms或全源失败。",
          "allowedDifference": "六个Native并发入口集中到Native-only模块，四个重复包装与Service使用同一执行函数；Browse的动态导入/raw字符串保持独立原样，图片的静态Native包装也保持，避免复活票据图动态导入崩溃。全部调用者的准入/复制字节/队列/取消/会话/诊断/解析逻辑不动。QA smoke及下载队列不在本次Native入口修复范围。",
          "references": [
            "https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/task-pool-usage-guidelines"
          ]
        }
      },
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-worker237-native-only-162",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-worker237-resume-detail-163",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-worker237-return-readback-164"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "模块修复冻结；其余rate_limit/图片403/全局搜索/3H业务需新的真实响应，不造故障或重请旧失败网站。"
      },
      "reportedAgeAtAudit": "3天0小时53分15秒",
      "reportedAgeSecondsAtAudit": 262395,
      "reportedDate": "2026-10-23",
      "reportedDateSource": "按上述原始UTC首报换算Asia/Shanghai日期，不使用登记日。"
    },
    {
      "id": "SOURCE_WEB_SESSION",
      "title": "源网页挑战会话回流、源内设置及登录入口",
      "priority": "P2（后续处理）",
      "owner": "source_terra：源故障及237具名路径；Root：App/Reader发版故障与交付",
      "dependencies": [],
      "status": "具名验证与修复已交付",
      "kind": "done",
      "result": "Simply浏览、搜索及封面争用下的后续查询已验证，源码与CI已完成。",
      "remaining": "",
      "reportedAt": "2026-10-23T01:44:08.576Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 254529135 重新读原文与时间戳，不是摘要/登记时间。",
      "requestedAt": "2026-10-23T01:46:03.842Z",
      "firstEvidenceAt": "2026-10-23T01:44:08.576Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-31T04:26:30+08:00",
      "reopenedAt": "2026-10-23T05:31:18.350Z",
      "feedbackReports": [
        {
          "reportedAt": "2026-10-23T05:31:18.350Z",
          "source": "原JSONL response_item/user",
          "summary": "包子仍403，自动半模态验证/人工勾选，手动菜单不成熟；隐藏WebView仅提议。"
        },
        {
          "reportedAt": "2026-10-25T13:22:43.030935+00:00",
          "source": "当前可见人类消息；登记时间，不推测原始服务端时间",
          "summary": "指出WebView半模态丑陋且底部堆两行；随后明确要求清理，反对以补问确认为理由保留错误。"
        }
      ],
      "relatedItems": [
        "SOURCE_SETTINGS_DIRECT_ENTRY"
      ],
      "evidencePoints": [
        "直接产物索引：https://baozimh.org；.hvigor/outputs/user-flow-audit/mh160-web-entry-chain-review/public-script-receipt.json。该结果只限制本次脚本取得；.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/mh160-runtime197-atomic-session-423/；.hvigor/outputs/user-flow-audit/mh160-web-entry-chain-review/ordinary-mh160-compatibility-candidate.patch；web-observed.png；.hvigor/outputs/user-flow-audit/mh160-web-entry-chain-review/public-script-receipt.json；mh160-web-entry-chain-review/temporary-runtime-probe.patch；temporary-probe-basis.json；413/web-observed.png；result.json；koma-log-20261026-120547.log；598/returned-original-detail.json；result.json/runtime-lines.txt；mh160-runtime197-atomic-session-430/result.json；runtime-lines.txt；mh160-web-entry-chain-review/public-detail-script-receipt.json；mh160-runtime197-atomic-session-437/runtime-lines.txt；Koma-mh160-ordinary-compatibility-candidate-signed.hap；mh160-web-entry-chain-review/ua-authorization-original-message-review.json；mh160-runtime197-atomic-session-444/result.json/runtime-lines.txt；formal-5908-ci.json；mh160-search197-atomic-session-451/result.json/search-runtime-lines.txt；search-observed.png；mh160-web-entry-chain-review/mihon-current-*.kt；global-search-web-build.log；global-search-web-owner-tests.txt；global-search-web197-atomic-session-458/result.json；atomic-session-467/result.json/search-runtime-lines.txt；global-search-web197-atomic-session-476/result.json；global-search-formal-ci-detail.json；global-search-web197-formal-delivery-485/result.json；formal-library.png；228/search-baseline-wasm.json；search-current-http.json；Mh160.kt；mh160-web-entry-chain-review/http-facts-basis.json；temporary-http-facts.patch；http-facts-build.log；mh160-search-return197-atomic-session-599/result.json；after-manual.png；search-landing-fix-build.log；search-landing-fix197-session-606/result.json；ordinary-result.png；restored-library.png；mh160-web-entry-chain-review/search-landing-fix-ci-detail.json；koma-sources/sources/goda/metadata.json；manifest.json/source.wasm/icon.png；source-b406995-public-review.json；Koma-source-known-actions-final-signed.hap",
        "原历史result归档（本次更新当前结论前保留）：App12204da8edfb707bf3e53710e3daf279f8556c4d八文件Host/Worker/ABI/检查已push且精确CI40458243006 completed/success。197989安装同签18910496 Release/debugfalse/0.1.3/code4，987中性awake86400000/988→990七文件逐字同；default-result无errors，默认Browse鬼灭之刃/炎炎之消防队/高木同学简体12卡9图及detail标题简介235章亲审；traditional-result无errors，true普通Browse鬼滅之刃/消防隊/同學繁体12卡9图亲审，随后仅清本次Bz设置回原书架。991日志四实际HTTP session cookieState=present/200含default metadata/detail/chapters及trueBrowse；无Reader入场。992系统120000无Override/c14761b7释租，mangabz-worker197-restoration-comparison.json及worker-identity/identity.json具据。 浏览页、源内搜索与统一搜索的网页验证共用prepareSourceWebSession；该入口已按sourceId解析安装包当前语言名称，解析不可用回退原传入名，URL与验证状态流程保持。App5748d0a83c0b37653f5c20f097f6ece4c479cf29已提交推送，现有验证/session执行检查及Release HAP构建通过，精确CI40486939289 completed/success；真实验证窗口Native仍未验证，不写名称窗口已验收。 237新会话普通统一搜索斗破苍穹：漫画160真实HTTP403触发验证sheet，随后无用户输入自动返回并显示10条作品；同次包子challenge_required排队，DM5、快看、腾讯、再漫画等已解析ready。007输入参数错误未产生查询或请求，不计验证。003安装最终0cd18 HAP，前后registry/settings JSON完全相等，原斗破01第1页3%保留；当时临时scope source，原local；013已恢复local，目前仍持租。 012单源过滤日志显示包子原请求验证一次、搜索完成并ready 6条；008后无点击、重试或关闭输入，漫画160的10条和包子6条分别自动回流。009零动作日志为空、010全量日志尾部无关，不作缺事件依据；包子Native标题未截图，不称第二标题亲验。 23个相关依赖文件e2946421152596bf766ce8acacb572f3cb21ede5已推master，精确CI40670008826 completed/success，连接器读回head一致；相关回归51通过，XCOMIC detailContext ABI仍为未提交WIP。013已Native确认sourceFilter恢复及返回书架；015手动检查，016尚未完成但确认13个更新。017–018漫画1234公开0.1.4更新成功且Native显示漫画1234网；019–020漫画社公开0.1.9安装成功，设置及正文未验；021–022妙趣0.1.3公开更新成功，registry 0.1.3及Native显示妙趣漫画。升级后对应源包版本允许变化，其他设置与设备仍待总恢复。 本轮237已回原书架、恢复设置及筛选，最终SLEEP/正常120000无override并释租；原404、取消防重复及未命中窗口标题等仍独立未验。 Simply Hentai旧日志显示challenge信号被源降为http_error；012候选在旧Host仍403。Host普通目录和首搜索缺guard及requestHandle接线，三文件候选正构建并待237回验；默认403保持，API origin限定api.simply-hentai.com，不假定www共享会话。 Simply第一轮联合候选完成并重试后原请求仍403，无自动循环；原包、四份用户数据及会话记录已恢复，临时文件清除，237电源恢复并释租。发现原请求与验证页UA不一致，最小修正及单次回验中，403原因尚未确定。 Simply UA一致性候选在237手动点击完成并重试后仍403；日志显示UA不一致及Cookie读取为空，不认定根因。原宿主、原011包、五份数据及会话恢复，临时文件清除，设备休眠释租。 宿主验证请求关联及原UA传递6d6ae7a已推，精确CI进行中；Simply仍403，get_home因果ID尚未接通，不称验证完成。 宿主验证请求关联及原UA传递6d6ae7a精确CI40779011098成功；Simply及get_home原未验边界保留。 6d6ae7a精确CI40779011098 completed/success。 Zero公开017游客锁章拒绝及本站登录入口具名已核，登录态正文未验；原源、数据和电源已恢复，reader自然新增第二章记录。 本轮手动全页包子官网标题由站点覆盖，仅为全页观察，不是自动验证sheet标题证据；sheet标题仍未验。 本轮197手动网页观察后，原源包、七域及电源已恢复并释租；不改变自动验证sheet标题未验边界。 包子首页验证请求关联已形成受控源候选，宿主接线修正中；自然挑战未验。 既有包子自然首页挑战布局含中文源名及完成重试节点；无截图，不外推其他语言或挑战成功。 包子首页宿主关联修复已推；237普通首页12部，自然挑战未出现，设备已恢复。 包子0.1.14公开实体与受控回放已核，自然挑战未出现；漫画屋首页及Simply原边界保持开放。",
        "本轮1633滚动被自动审批拒绝，因1632可能仍运行、存在并行重复风险；未重试、未发Simply GET，无新header或网络证据。1635原包四成员等1624；1636原db31及六JSON等1622；1637临时文件清理；1638 SLEEP/120000无override，租约22:59:06 released；两产品文件临时patch reverse、无diff。",
        "临时诊断HAP db9b0c933509a533767c124a76b518d60cb44e0bbf6be9b0af7eca4ec4b9ac7e已构建、验签同db31，未装；仅请求头分类及主帧安全performance数值/支持位，不改验证、缓存、UA或完成条件，后续不提交且恢复。237 lease20261029-181615-230f7416，1748完成awake/中立解锁/86400000读回及六域、Simply011四成员基线，registry/路径对应；目标HTTP及验证页尚未触发。",
        "1750诊断Host db9 installer明确success并启动；1752普通导入源012，1753 ZIP/WASM与冻结a6d77d50…/31759fff…精确相等。原011缺API webSessionOrigins及challenge关联，012仅补两处，UA/Referer/Origin/Cache-Control不变；尚无新GET/挑战，同租约常亮，结束须恢复原包/六域/电源。",
        "1761原011四成员及六域对1748全等、db31安装成功；1762候选与唯一下载不存在，SLEEP/120000无override，lease20261029-181615-230f7416 released及status读回；两源码临时patch精确撤回。",
        "237新lease…fae08932，1763六域及原011基线、1764 db9诊断Host安装成功、1767实装012 ZIP/WASM与冻结相同，1768源列表已定位；尚未发目标GET或复现挑战。",
        "1769验证初页timing status200/transfer0/encoded5140/decoded23475/deliverycache；1770现有刷新一次status200/transfer5379/encoded5079/decoded23187/deliveryempty，符合完整body传输；1772仅一次完成并重试后Native op9仍403、终态继续要求验证。缓存不是全部原因，不报根因/修复、不改缓存策略/UA/代码。1774原011四成员对1763全等，1775六JSON全等且原db31 installer成功，1776本轮候选/下载不存在、SLEEP/120000无override；lease…fae08932于03:38:30 released并status读回。",
        "固定949 KeiSource.kt 141–145继承头与Koma同WWW Referer/Origin/max-age600，先前无头猜测撤回、未据此改代码。基于Native HTTP2/TLS1.2及官方API18 tlsOptions进行一次临时TLS1.3对照，原011不换源；lease…11c69b48，1777原四成员/六JSON与1763同且AWAKE/86400000，1778同签TLS HAP安装与普通浏览定位进行中，目标GET未发。",
        "1769初始Web timing 200/transfer0/encoded5140/decoded23475/deliverycache；1770刷新200/transfer5379/encoded5079/decoded23187/deliveryempty，符合编码体传输，但workerStart取整0不能绝对排除SW，不冒线路fresh200；1772一次完成并重试Native仍403。1781原011+临时TLS1.3候选请求461ms后2300999/unclassified，无HTTP响应或tls_probe，未证明TLS1.3协商、不归因或排除TLS；1782取消未执行。1783原db31安装成功、原011四成员及六JSON对1777逐字同；1784 SLEEP/120000无override，lease20261029-200719-11c69b48于04:26:47 released/status读回。临时Transport patch撤回无diff；无诊断重建 /private/tmp/koma-no-diagnostics.hap SHA256 c274fbf4706c868b338b4c8af733a1cfa4032733e7a6d080460be1be53dd2e72、默认signed同hash。诊断未发布、不称故障已修。",
        "Simply旧499原日志原GET op5、首次probe op6、完成重试op9均HTTP403且Host access_signal=challenge_required，其判定仅基于响应头cf-mitigated: challenge，故该场有Cloudflare挑战特征；496验证页呈API JSON，不是人工挑战完成。499原GET无会话/source UA，probe附Web会话/UA来自WebView，不能称完全同身份。1769–1772安全日志未保存marker或原始/自定义UA相等布尔，Web拦截对象未显示UA/Referer/Origin，Native probe入参带Referer/Origin，均为对象分类而非线路头；不推广499到所有场景。证据 source-web-session-concurrent/simply-ua-log-499/app.log及1769–1772 run-metadata。",
        "source_terra在237同场进行最小cause-UA/CF分类诊断，非重复原无诊断失败；结果与恢复尚待回执。",
        "237 Simply 012诊断Host351e一次普通入口008：原GET及自动probe均403且cf-mitigated=challenge；因果ID selected，原UA存在、Web custom与原UA相等、probe最终入参与两者相等。排除该场App对象UA接线差异，不证明Web线路身份/TLS，不解决403；未改UA/Cookie/代理或重复请求。010原011四成员等002，011原27f332安装成功、六JSON等001，012清候选/下载、SLEEP/120000无override，lease d6fe5cf7 released；临时patch已撤。证据 source-web-session-concurrent/simply-cause-ua-open-20261030-008及restore 010–012。",
        "两源接线f624c85389b528d3304beb65ca9a440c169e46f2已推，精确CI41024411724 success，release428782014同SHA非draft；漫画屋018/Simply012正式包公开，摘要/manifest/index及Simply精确origin已核，公开WASM与本地不同，两个正式WASM既有四合同执行通过。稳定索引 .hvigor/outputs/user-flow-audit/source-settings-repair/source-challenge-cause-published-f624c85/evidence.json；仅接线交付，可用性仍open，不冒公开实体Native。",
        "Mihon WebView loadUrl原公开头对照发现Koma遗漏Referer/Cache-Control；候选受因果ID/URL/origin约束，不传Origin或凭据，尚不能证明403根因；同签编译及237准备中。",
        "本轮Simply CDP受限采样：同请求UA/Referer/Cache-Control匹配，Web response 200、disk=false/SW=false，精确URL限域Network.getCookies当时无cf_clearance，不能外推所有分区；Native probe仍403。临时端口、原包、六域及电源恢复、租约released。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-cdp-20261030/evidence.json。当前仅新Origin单变量A/B，未修复403。",
        "Simply Origin A/B：公开012 A实装e0e60001…普通首页403，仅删API Origin本地B cd8890cb…同首页仍403，不视为修复；候选未提交，原源四成员及六域恢复、原宿主未换，清候选/下载，SLEEP/120000无override、lease8dec8f45 released。source_terra按已授权197进行同URL/同公开头HTTP与RCP单次对照，尚无RCP结论，不称改架构。",
        "source_terra持197 lease 3c6607b7，已唤醒备份，临时HTTP/RCP候选尚未安装；原恢复HAP /private/tmp/Koma-chapter-014-38d245.hap SHA256 38d2456b09842e9f8b689dc3cc6f7968416a088be4ca1ea829a0ec4e0389dea5及335成功回执已核，设备安装字节读取拒绝边界保留。237已恢复交用户Noy登录；home_terra仅本地核Noy参考协议/现WIP，不碰237。",
        "197 NetworkKit/RCP同源相同公开请求各一次均HTTP403、CF challenge=true、非JSON、5770字节；不称两栈所有行为相同或更换网络栈可修。首包Logger禁用时请求是否发生未知。013原38d安装成功、六JSON与001逐字同，014 SLEEP/120000/Override10000，lease3c6607b7 released；稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-network-ab197-20261030/evidence.json。",
        "Simply Referer/Cache-Control候选已精确撤回，App源码无diff；HEAD旧测试夹具补3个MangaBz mock导入后原challenge ID单测1个通过，无新测试或产品变化。",
        "Simply CDP时序复核：007于19:25:41读取时request/current Cookie均空且probe未就绪；009于19:26:17读取clearanceCount=0在reload之前；010于19:26:55 reload后才出现Web 200，现存013/014/015之前未见200后再手动完成或Native重试。因此此前403不能视为Web 200后同状态对照；无clearance不代表其他Cookie均空。237 API23用双参、API26及以上用三参，未扩大权限。原始证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-cdp-20261030/evidence.json。",
        "197第一场文件选择后32–54秒尚未确认系统选择器底部完成按钮，不能据此认定App导入卡住；008 force-stop后恢复。第二场补系统完成后公开012正常导入，原014 App未换；007验证页显示API JSON，008一次完成重试后PID32607 op9于20:56:04.947 GET403，网页真实网络状态与缓存未知，不称线上200后403。010原源四成员、六域及诊断XML逐字同；011 SLEEP/120000/Override10000，lease1543cefb released。仅为核网页200/304及原生Cookie状态准备临时CDP诊断包2f8e2a33，未改UA、头或缓存；临时源码已撤，受控观测尚待执行，不称修复。",
        "197同requestId CDP response.status=200而ExtraInfo.statusCode=304，属缓存重验证，不能称新线上200；响应后目标URL Cookie总数0、clearance0，手动日志present=false/SDK26；同op9实际session=attached、cookieState=empty、uaSource=webview，hop_response403。014原38d安装成功，原011四成员、六域及诊断XML相等；012本场fport撤除，015候选/下载不存在、SLEEP/120000/原Override10000，lease bf72ec13 released；临时16行已撤。现产品候选仅Simply且api.simply-hentai.com验证页设Online，默认仍Default；不清缓存、不改UA/头/权限。官方Online全网络不读缓存，None会读过期缓存；Mihon为LOAD_DEFAULT，不称同实现。联合构建及一次验证进行中，效果未知。",
        "Online控制下同requestId response200/Extra200，非disk或SW；Cookie总数0、clearance0；手动后SDK26同op9实际attached/empty/webviewUA且Native403。缓存不是403的充分根因；五行Online及16行诊断均精确撤回，不采用或提交。原Host38d安装成功，源四成员、六域、诊断XML相等，fport及下载清理，SLEEP/120000/原Override10000，lease6d5687ee released。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-online-diagnostic-20261030/evidence.json。现仅准备RCP默认与gallery-dl参考套件集合对照，保系统代理、证书、默认TLS与HTTP协商，尚无结果、不改生产网络栈；参考 source-settings-repair/simply-network-ab197-20261030/rcp-firefox-cipher-reference.md。",
        "RCP默认及17参考套件均403/challenge/非JSON/5770字节/HTTP2；另一次完整参考头、17套件、TLS最低1.2及HTTP1.1匿名GET仍403/challenge/非JSON/5941字节，实际1.1。属于可配置近似而非完整Firefox指纹，不称全站不可用。003回执已审；004原38d安装成功、六JSON全等，005 SLEEP/120000/原Override10000、lease e44b5710 released；所有临时代码及此前Online五行、CDP十六行均撤回，不采用候选。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-network-ab197-20261030/rcp-firefox-reference-evidence.json。",
        "原UA边界（用户具体采用漫画屋例外前）：验证会话的UA、Cookie策略和权限边界保持；漫画160普通网页的UA兼容仅按已采用专用规则处理，不扩大到源HTTP或验证会话。原请求失败仍保人工入口且不循环，包/设置/路由/claim失效与离开回调守卫保持。",
        "237同场Web同requestId response及Extra均200，h2/TLS1.2/AES128且无Cookie；Native op9 URL和UA与原请求及页面匹配、无clearance，HTTP2/TLS1.2、空Cookie仍403。远端地址记录不同，未据此认定物理节点或根因。回执 source-web-session-concurrent/simply-samescene237-complete-20261031-013、restore-016、power-018；C6回装，原011四成员及六域逐字相等，fport和临时包清理，SLEEP/120000无override，lease febaaf34 released。",
        "依据同场Web与Native远端地址记录不同，source_terra正在对照RCP默认解析与Web实际公网peer；保持正常域名、证书和系统代理，不改手机网络。结果尚未取得，不称修复或把Mac只读DNS分类当手机证据。",
        "同场Web response200/ExtraInfo304为缓存重验证；同URL RCP默认解析与映射至Web实际公网peer两次均403，映射请求dstAddr实测匹配。本次说明对齐节点不足以解决该次挑战，不排除所有DNS或网络因素。原C6安装成功、原Simply四成员及六域逐字恢复，临时文件与转发清理，SLEEP/120000无override，租约released。稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-peer-dns-20261031/evidence.json。",
        "同实际peer的RCP原头与本次捕获公开头组均403；完整捕获导航公开头的源候选普通首页亦403，未采用或提交。C6、原源四成员、六域及电源均恢复，租约released。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-header-profile-20261031/evidence.json。此前一次匿名WWW首页GET亦403/challenge，未取得应用HTML，不证明官网无相关能力；证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-www-contract-20261031/evidence.json。当前237只在普通可见官网读取公开客户端引用，不新增WWW会话grant、不把网页正文交源；结果尚未取得。",
        "官网可见，15条客户端脚本中14条可读，一条资源树缺席，现有/api命中不构成完整源合同；普通搜索及公开作品两文档200 HTML，但WWW新搜索原生仍403，不能视为源已恢复或证明旧ID及章节替代合同。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-official-client-20261031/evidence.json 与 simply-official-route-20261031/evidence.json。两场原C6、六域、电源及租约均恢复。此前误报旧37249转发已清，实为删除错误PID失败；013按实际映射删除并读回空，本场57961亦006删除并读回空。现仅核OHOS原生兼容库最小构建及NAPI接点，尚未正式接库、增加权限或发布，不证明TLS根因。",
        "固定curl-impersonate v2.3.2 PoC实际OHOS arm64构建exit0，检查到的archive与so对象均AArch64；仅HTTP2、无ASM/HTTP3，未接入生产，系统CA、代理及真实请求未验。source archive与static库哈希分别记录在 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-ohos-impersonate-poc/evidence.json。正准备复用原NAPI的同签临时对照，保持正常校验与系统代理，不新增权限或发布。",
        "237 Source Runtime普通路径 simply-runtime237-open-20261031-007显示中文列表24本，实际公开012源WASM与正式包逐字相等，Host为本地候选5d397；分页、详情及首图尚在验证，不称整源已修。先前同原请求普通curl403、Firefox133 profile 200且albums数组，两者证书验证成功、无系统代理，属结构初筛；证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-ohos-impersonate-poc/native237/evidence.json。正式prepare-source-browser-http.sh已从归档实际构建，尚未接产品、Linux未验。",
        "237候选5d397b46：007中文列表24本，010详情1章，012正文首图1/250可见；015回顶部仍24不能证明分页，017搜索dragon显示源搜索失败/书源运行异常，018日志无具体错误。020原C6安装成功、源四成员及六域逐字恢复；021 SLEEP/120000无override、临时清理，lease08ee2005 released。公开012 WASM结合旧真实search 200 body的V8离线执行成功仅排除该受控样本必然失败，WAMR根因仍待查。正式原生兼容配方、CMake和许可收尾中，尚未正式build/CI/push。证据 source-web-session-concurrent/simply-runtime237-{open-20261031-007,detail-20261031-010,reader-20261031-012,search-20261031-017,restore-20261031-020,final-20261031-021}。",
        "旧017搜索持久日志最终op235 HTTP200/37229字符后源失败（unknown/kind runtime），首个op233因输入取消；原错误内容未记录，不能判定解析或其他原因。旧WAMR受控响应成功不证明本次实际响应成功。稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-runtime-curl-20261031/evidence.json。新候选同场核搜索固定合同；原生配方及许可仍在收尾。",
        "本次固定HOST_LOG为image filename，下一分类017已证PNG；原后缀白名单拒绝PNG导致整页搜索失败。source_terra正在验证去掉后缀白名单的候选，尚未Native通过或交付。",
        "仅移除后缀白名单的093aa714候选：237 simply-fix237-search-screen-20261031-025普通dragon结果与封面已由Root亲看；024日志op20 source.operation completed/7831字符，HTTP op21=200。正式源提交/公开及本场恢复尚待source owner回执，不关项。",
        "Simply 0.1.3提交2c4bc7bab610f4f602e02d8c81f1e1b83d61cee9、精确CI41114185742 success并公开；正式ZIP229f6e82…/WASM2da51c9e…，公开实体版本、PNG原URL、旧样本及遍历拒绝已执行，不冒公开WASM重复Native。022/025同词dragon结果及封面已亲审；027第二页失败，028多条HTTP 15秒超时，旧日志无HTTP→operation关联，不能归因自动重试；只读后核59/61/62为get_image_request与65搜索排队重叠，根因未知。正式013 WASM结合真实Host timeout envelope执行确认误报required field missing；014仅错误分类候选待Native/未提交，不改请求、UA、成功解析或新文案。诊断HAP仅加HTTP operation及累计耗时，编译成功，237新场测量中。前场030原C6/Simply四成员及六域全等，031 SLEEP/120000无override，lease8d024fe2 released。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-filename-fix-20261031/evidence.json 及 public-2c4bc7b/。",
        "Simply 0.1.4 d83fafd792ea4de26b24eb1199ca2c2a2208b688已公开、精确CI41117632213 success；正式WASM timeout分类、旧成功/PNG及遍历负向合同执行通过，证据 .hvigor/outputs/user-flow-audit/source-settings-repair/simply-timeout-fix-20261031/public-d83fafd/。共同Worker调度237带封面争用：活动封面op102于04:03:10.550结束，search141的HTTP143于.576先于旧待封面发，总1974ms；真实simply-cover237-screen-20261031-012/screen.png已Root亲看。十次滚动实际触发两后续查询，不称仅一次或比较倍数；前scheduler237-evidence-011截图不存在，误报撤回、原失败回执保留。原C6、四成员及六域恢复，SLEEP/120000无override、lease572e1071 released。完整索引 .hvigor/outputs/user-flow-audit/source-settings-repair/source-worker-admission-20261031/evidence.json。App十五文件准备提交推送及精确CI，尚未完成。",
        "共同调度App提交0eadd9a3c4e2deb5df7804054f05561d39d97d95已推Koma/master，精确CI41121496728当前queued；尚未完成。",
        "App 0eadd9a3c4e2deb5df7804054f05561d39d97d95已推，精确CI41121496728 completed/success，build/inspect/upload通过、tag发布步骤跳过；未新增App release/tag/AGC。Simply浏览器HTTP、PNG搜索、timeout错误分类及共同Worker封面让位已有具名验证，正式源014公开。旧网络15秒timeout根因未完全归因，不称所有网络超时消失，不外推全站、全部格式或漫画屋自动验证。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/source-worker-admission-20261031/evidence.json 及 https://github.com/honjow/Koma/actions/runs/41121496728。"
      ],
      "remainingActions": [],
      "boundaries": [
        "漫画屋478/479与包子537/538自动回流分别具名成立；不外推全部CF、人工挑战、登录或正文。",
        "验证会话一般仍沿原请求UA，漫画屋唯一当前例外见MANHUAWU_SOURCE_UNAVAILABLE；Cookie策略和权限边界保持。漫画160普通网页UA兼容仍按已采用专用规则处理，不扩大到其他源HTTP或验证会话。原请求失败仍保人工入口且不循环，包/设置/路由/claim失效与离开回调守卫保持。",
        "document_visible仅官方“即将可见”事件，不是绘制证明；closed/partial只是网页离开状态，不作为站点成功。阶段诊断不记录URL、标题、HTML、headers或body。",
        "取消、特殊跳转及其他语言窗口标题未自然命中，不外推已验；不作为普遍新增关闭门槛。"
      ],
      "modificationBasis": {
        "object": "SourceWebSessionSheet与SourceRuntimeHttpTransport/SourceWebSessionStore的受限原请求验证",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "不能凭网页内容或任意Cookie宣称通过；只能使用当前源明确授权origin与真实原失败请求",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "只移除Web曾403前置；仍需当前有效原Native claim、同原URL/成功当前文档、已知Cookie基线且两侧无CF。成功必须由现有原GET验证2xx/非challenge证实，响应仅一次复用；UI、UA及数据格式保持。102项Host/Release与537/538具名实机已完成。",
        "webPageDiagnostics": {
          "object": "MangaWebPage标准ArkWeb回调及MangaWebView可选onPageVisible事件转发",
          "history": "53cbc39a沿NextE GalleryWebPage/EhWebView的完整Scaffold/List/Web与导航控件；当前onPageBegin/End/Error只更新原loading，没有持久阶段事实。",
          "originalReason": "保NextE原页面层次、加载和导航行为，不引入EH登录/UA逻辑；网页内容不写诊断。",
          "reopenEvidence": "558/559白屏31秒仍加载；564阶段日志进一步证实单次初始调用后重复文档导航。 本次核对Keiyoushi当前实现，搜索端点与本源一致；原布尔无法区分www/mobile两项已声明origin与外站，也缺实际导航是否redirect的事实。",
          "allowedDifference": "仅官方回调、初始URL/origin相等布尔、数值与临时操作号；25%桶、首子资源、单次操作最多48条阶段加抑制标志/结束汇总。保所有UI、loading、Web请求/UA/Cookie/权限；不抓网页内容或URL。 本次仅临时增加初始源声明origin下标、主框架isRedirect/isRequestGesture；初始化只读已装元数据一次。仍最多48阶段，不写origin/URL/headers/body，不拦导航、不调用loadUrl/refresh/UA接口；一次有限普通路径后撤诊断并恢复正式包。"
        }
      },
      "modificationBasisToolbar": {
        "object": "仅SourceWebSessionSheet底部操作区",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "原实现保人工后退/前进/刷新与完成重试，但功能完整不足以授权两行外观；未找到这项布局已获明确采用的原始依据。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅本sheet底部收为一行：左侧三个无底板图标导航，右侧原完成并重试；保顶部、材质、安全区、验证/关闭/自动回流及全部状态守卫。当前后继清理要求作为修改依据，不把用户反问登记为采用异步选项。"
      },
      "continuationGate": {
        "checkedAt": "2026-10-26T19:34:00+00:00",
        "owner": "Root",
        "condition": "本批入口App提交push/精确CI及最终包覆盖完成；85差异仅已核未采纳。漫画160自动404未自然Native、其他CF人工验证/登录边界仍open，不清Cookie撤权限造挑战，单条样本缺口不扩大整体停止。"
      },
      "reportedAgeAtAudit": "2天17小时49分43秒",
      "reportedAgeSecondsAtAudit": 236983,
      "reportedDate": "2026-10-23",
      "reportedDateSource": "按上述原始UTC首报换算Asia/Shanghai日期，不使用登记日。",
      "pendingOrdinaryWebUaCompatibility": {
        "cause": "两端设备识别条件对当前鸿蒙UA给出相反分流，已有同revision只读结构与实际双向导航支持。",
        "proposedDifference": "普通MangaWebPage初始仅漫画160两个https origin且sourceSession===undefined，默认UA含OpenHarmony与Mobile且不含Android/iOS时，保全部默认字段追加空格Android；同一网页instance后续链接沿用此身份，无全局UA配置。源HTTP/验证sheet/其它入口/样式不改。",
        "authorization": "本轮当前可见异步人类明确答复采用此兼容修复；这次真实答复是当前采用来源，不把早前Root实施判断冒已有批准。具体普通UA差异/同Web后续沿用及App样式/验证登录保持按已提出范围；历史补问撤回保留。",
        "decisionStatus": "本轮人类已明确采用；原详情具名通过、5908提交推送/精确CI最终jobs成功、455正式8589401B留197。搜索404及CF仍独立未闭。"
      },
      "unifiedSearchChallengeBranch": {
        "requestSource": "本轮最新人类要求统一搜索遇CF分别自动弹出过验证，Root可信转交；精确服务端时间未给，不冒首报时间。",
        "currentGap": "SearchPage无SourceWebSessionSheet，CrossSearchSection无challenge receipt，catch仅诊断/error section；单槽验证响应被不匹配源请求清掉。",
        "agreedScope": "逐源receipt/claim/guard(query/filter/route/entry/settingsRevision)，现有单sheet串行；其它源继续结果，完成仅retry该源并等待原重试/消失后下一源，取消/再次challenge不循环，旧任务失效；精确匹配原请求才一次消费验证响应。",
        "state": "实现/构建/Host与具名Native边界、85e3提交推送、487正式8605304留197/六域/系统恢复及精确CI40282248501同head成功均已闭环；旧CF与同次双挑战恢复样本/Native清query未扩。",
        "boundaries": "复用现有样式/NativeProbe，不清Cookie/改验证UA；普通mh160人类采用不扩到CF sheet。"
      },
      "stage": "具名范围已交付",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/awake-baseline-002/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/candidate-install-003/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/real-source-parallel-search-007/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/real-source-parallel-search-008/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/first-challenge-state-009/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/automatic-retry-receipts-010/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/filtered-web-receipts-012/run-metadata.json",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/restore-original-scope-013/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/public-update-targets-016/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mh1234-public-completion-018/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe-public-completion-020/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/miaoqu-public-completion-022/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-old-log-439/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-host-sleep-487/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-ua-sleep-509/",
        "https://github.com/honjow/Koma/actions/runs/40779011098",
        "包子get_home旧源错误无challengeRequestId，宿主首页调用未带guard/handle。冻结源014 /private/tmp/baozi-home-cause014.koma；/private/tmp/baozi-home-cause-replay.json：旧Host与公开013错误及请求深等，新feature受控挑战回相同ID、普通403不附ID。原包子WIP补丁逐字恢复；受控执行非自然挑战或站点成功，未发布。",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/baozi-search-home-1104/layout.json：半模态Text包子漫画与完成并重试，底层HTTP403验证提示；无截图，不冒像素/其他语言/挑战成功。",
        "宿主7e18b619已推；237 1616普通首页12部，无自然挑战；1618原包四成员、1619原db31及六JSON恢复一致，1621 SLEEP/120000无override并释租。源be69d618经Root核可信持续授权后正常HTTPS推送，CI/公开实体待核；此前子代理自动审批拒绝历史保留。Simply原API GET403 challenge，验证文档同origin且首方Cookie允许，按完整URL读取为空、自动probe及手动重试仍403；空值不证明站点未签发或根因，不重发。",
        "源be69d6180a5212d851fb27c5fa24a9f088c18383精确CI40878834593 success；/private/tmp/baozi-be69-public/公开ZIP 88e6c13a60e53df84cf3a0ba55662e2ffa9a8770b5d4591433d1c51921d5c255、WASM 1bc6e846f5c17ab6b3f1ccb3c6ae39a91895286f7fde022cb61ba4271b8b3a2d。get_home/search受控回放旧Host等价、cause精确ID、普通403原错误保持；公开WASM不同候选未另Native，自然挑战未出现。漫画屋首页get_manga_list自然403不受此次get_home直接覆盖；Simply403原因未知。",
        "Simply验证sheet复用MangaWebView，JavaScript/DOM storage/在线图片开启，主帧与子资源导航不主动阻断；499日志无资源失败或Turnstile错误，但无完整资源成功清单，不能推断全部资源加载。403仍未解决、原因未证，不称纯外部限制。",
        "simply-ua-browse-496实际sheet显示API albums JSON，无可见Turnstile；497仅点击完成并重试后源浏览403，不能称人工挑战已完成。499同URL Web显示JSON、读取无cookie，原因未知。/private/tmp/simply-empty-ua-check.cjs受控执行确认Native HttpRequest应用Web UA、删除原UA/Cookie并保Referer/Origin/Cache-Control；缺线上Web/NetworkKit实际headers及传输身份，不断定403根因。",
        "Simply 496截图只证明Web显示API JSON，不证明当次线上HTTP200；MangaWebView未设cacheMode，默认可能使用未过期缓存，499无主文档缓存命中/响应状态。Native明确usingCache:false及403；缓存可能性未排除也未证，不清缓存或重试。"
      ]
    },
    {
      "id": "SOURCE_SETTINGS_ACTION_ALIGNMENT",
      "title": "源设置底部清除/保存按钮突兀且不齐",
      "priority": "P2（本sheet限定修正，不取消原队列）",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "status": "已验收+已推送，CI成功（冻结）",
      "kind": "accepted",
      "result": "源设置两动作的对齐、层级与保存退出已在237具名通过，提交及CI完成。",
      "remaining": "具名sheet范围冻结；后续仅实际新反例重开。",
      "reportedAt": "2026-10-23T02:58:58.381Z",
      "reportedAtSource": "原始会话JSONL response_item/user图反馈原文实际时间戳。",
      "firstEvidenceAt": "2026-10-23T02:58:58.381Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-23T03:38:15.620424+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "具名sheet范围冻结；后续仅实际新反例重开。"
      ],
      "boundaries": [
        "不外推其他页面或未验字段，不因旧“候选未应用/安装中”总述重开。"
      ]
    },
    {
      "id": "SOURCE_SETTINGS_DIRECT_ENTRY",
      "title": "当前源页应直接弹源设置，避免绕管理路由",
      "priority": "P2（入口行为，保P0优先）",
      "owner": "Root：三入口具名路径与精确CI已完成，未覆盖边界保留",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_WEB_SESSION",
        "SOURCE_SETTINGS_ACTION_ALIGNMENT"
      ],
      "status": "三入口限定验收完成，精确CI成功",
      "kind": "accepted",
      "result": "源浏览与独立源搜索直接弹出原设置表单；原管理入口保持。197保存刷新、关闭返回及测试设置恢复已核。",
      "remaining": "本次三入口具名范围冻结；非空查询保存、其他源字段类型未扩认。Root亲见237 MangaDex设置页“Attempt to use the first volume cover as cover”被截断，布尔项源自带说明未显示；用户选择标题换行并显示源说明；Root在SourceSettingsSheetContent和KomaFormTextField实现并完成Release HAP编译。237 v2具名实机验证，Root亲审long-title-description.png、toggle-changed/restored-unsaved.png及MangaBall settings图；开关未保存后返回，设置深相等，三版MangaDex仅版本升级.20/.8/.8。设备最终120000ms/SLEEP、无Override，租约1b4109d2已释放。空候选多选因已积累Dodrio未复现，真实标题两状态未验。App 3058c4c0b89a59c0abaf4b26aa013cfe93b0a0b1已推，CI 40494450005已success。",
      "reportedAt": "2026-10-23T05:31:55.042Z",
      "reportedAtSource": "原始会话JSONL response_item/user口语原文时间；“源设置/源包管理”是结合上下文的当前暂解，待源码确认。",
      "firstEvidenceAt": "2026-10-23T05:31:55.042Z",
      "firstHandlingAt": "2026-10-23T13:32:30.338132+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-23T14:17:47.457815+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "本次三入口具名范围冻结；非空查询保存、其他源字段类型未扩认。Root亲见237 MangaDex设置页“Attempt to use the first volume cover as cover”被截断，布尔项源自带说明未显示；用户选择标题换行并显示源说明；Root在SourceSettingsSheetContent和KomaFormTextField实现并完成Release HAP编译。237 v2具名实机验证，Root亲审long-title-description.png、toggle-changed/restored-unsaved.png及MangaBall settings图；开关未保存后返回，设置深相等，三版MangaDex仅版本升级.20/.8/.8。设备最终120000ms/SLEEP、无Override，租约1b4109d2已释放。空候选多选因已积累Dodrio未复现，真实标题两状态未验。App 3058c4c0b89a59c0abaf4b26aa013cfe93b0a0b1已推，CI 40494450005已success。"
      ],
      "boundaries": [
        "原按钮991309a几何与样式冻结，只取消管理页中转。离页/晚回调作废；不回灌设置、不清用户数据，不把138取消后的403当自动弹失败。",
        "144内容恢复不证明自动完成Web会话：当时未点完成并重试，也未实现自动判断；不能当作新候选的自然挑战验收。"
      ]
    },
    {
      "id": "SOURCE_INDEX_PROGRESSIVE",
      "title": "首次远端索引长空白，需逐项异步显示",
      "status": "r3具名通过，4b878926已推且精确CI成功",
      "kind": "accepted",
      "priority": "P2",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "现有profile的远端列表先出现、图标渐进补齐且文字稳定；普通源包更新通过。",
      "remaining": "当前普通latest范围冻结；仅后续真实新反馈或自然失败补验证。",
      "reportedAt": "2026-10-22T18:37:17.168Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T18:37:17.168Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "references": [
        "https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-foreach"
      ],
      "evidencePoints": [],
      "remainingActions": [
        "当前普通latest范围冻结；仅后续真实新反馈或自然失败补验证。"
      ],
      "boundaries": [
        "首次全新无缓存、慢/失败/换URL未作实机扩大，4行为检查仅证方法边界。不清缓存或造故障重跑。"
      ]
    },
    {
      "id": "SEARCH_DETAIL_TITLE",
      "title": "全局搜索进详情显示未命名漫画",
      "status": "两作品标题/返回具名通过，868dbb38 CI成功",
      "kind": "accepted",
      "priority": "P2",
      "owner": "冻结：Root按新反例或相关依赖变化重开",
      "dependencies": [],
      "result": "两作品标题/返回具名通过，868dbb38 CI成功",
      "remaining": "两作品/当前普通入口标题与返回范围冻结，868dbb38精确CI39885312214/head868dbb38已success；不重复跟已完成CI，不扩大所有源/作品。",
      "reportedAt": "2026-10-22T19:05:54.248Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:05:54.248Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "evidencePoints": [
        "直接产物索引：global-title197-detail-002/detail.png"
      ],
      "remainingActions": [
        "两作品/当前普通入口标题与返回范围冻结，868dbb38精确CI39885312214/head868dbb38已success；不重复跟已完成CI，不扩大所有源/作品。"
      ],
      "boundaries": []
    },
    {
      "id": "CHAPTER_PICKER_POSITION",
      "title": "阅读器章节选择器每次从顶部动画滚到当前章",
      "status": "197首开/手动保位通过，1e163c3e精确CI成功",
      "kind": "accepted",
      "priority": "P2",
      "owner": "冻结路径：无当前执行者",
      "dependencies": [],
      "result": "已补打开期间实际布局校正；Extra2首开可见，手动Booklet3关开位置相同，原章页保持。",
      "remaining": "197具名范围冻结；不外推旋转、字号或档位拖动。",
      "reportedAt": "2026-10-22T19:45:43.075Z",
      "reportedAtSource": "原始会话 JSONL response_item/user 时间戳（UTC）；不是摘要推算。",
      "firstEvidenceAt": "2026-10-22T19:45:43.075Z",
      "firstHandlingAt": "2026-10-22T20:00:18.424763+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-23T15:43:46.545761+00:00",
      "firstHandlingAtSource": "Root实际开始消息后首次可核分段登记；更早处理起点未知。",
      "reopenedAt": "2026-10-23T04:56:52.153Z",
      "reopenedAtSource": "原始会话JSONL response_item/user当前定位反例首报实值。",
      "evidencePoints": [],
      "remainingActions": [
        "仅真实新反例或相关依赖变化重开。"
      ],
      "boundaries": [
        "仅197/1260×2720/76章末段与手动位置；未扩认旋转、字号或档位拖动，不改原样式/目录/阅读规则。"
      ]
    },
    {
      "id": "SOURCE_FILTERS",
      "title": "已批准源筛选行为的当前设备路径",
      "status": "原反馈普通及快切筛选具名验证完成",
      "kind": "done",
      "result": "普通、快速切换、清除及Comic Fury筛选分流已具名验证，按原反馈范围完成。",
      "remaining": "",
      "reportedAt": null,
      "reportedAtSource": "最初用户提出时间仍未找到；已查到原会话2026-10-19T16:05:45.582Z明确采用筛选并发/失败提示重试三项并要求实施后验收，不以这次批准冒初次首报。",
      "firstEvidenceAt": null,
      "closedAt": "2026-10-29T21:10:53+08:00",
      "owner": "source_terra：源故障及237具名路径；Root：App/Reader发版故障与交付",
      "evidencePoints": [
        "按用户最新有效验证收口原则，原具名反馈已验证；自然失败样本作为未外推边界，不设额外关闭门槛。"
      ],
      "remainingActions": [],
      "boundaries": [
        "自然失败提示与重试恢复未出现具名样本，不外推已验证。"
      ],
      "modificationBasisClearLabel": {
        "object": "SourceFilterControls.FilterOptionMenu的App生成首项文案，Browse与SourceSearch共用",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "App首项清除一个字段，源options独立保原始值与标签；原标签误把清除动作表成全部。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "用户本轮异步答复采用清除此项筛选。只替换App首项三语文案，保源全部、所有动作/顺序/样式，普通包子筛选菜单与清除后返回/偏好恢复验证。"
      },
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-immark-formal-restored-200",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-filter237-clear-menu-201",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-filter237-clear-action-return-202",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-filter237-clear-final-readback-203",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-browse-160/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-controls-162/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-sort-last-update-164/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-cleared-and-rest-165/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-search-166/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-options-167/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-popularity-168/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-host-install-170/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-host-launch-readback-171/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-178/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-popularity-179/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-reset-180/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-browse-reset-181/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/guazi-search-category-246/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/hcomic-search-fullcolor-255/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-session-return-264/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-session-sleep-265/"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T21:56:53+00:00",
        "owner": "Root",
        "condition": "普通/快速切换及清除文案具名范围冻结；原人类批准中的自然失败提示与重试恢复仍缺实际适用失败样本，保open。不造网络/地址/数据故障，不重复已通过请求，不把尚缺样本冒已验。 此项样本条件不代表整体目标完成；当前设备执行以顶部为准。"
      },
      "reportedAgeAtAudit": "至少6天3小时28分6秒；从可核明确修正/验收指令起算，最初首报时间仍未知",
      "reportedAgeSecondsAtAudit": null,
      "firstKnownUserInstructionAt": "2026-10-19T16:05:45.582Z",
      "firstKnownUserInstructionSource": "原归档rollout-2026-10-09T16-04-56-01a11fb1-9f44-7123-8590-b6e849190eab.jsonl字节偏移6757277955，response_item/user异步答复call_5982499fa108414182a27f2672aaead4；“接入这三项（推荐）：按上述行为修正，实施后另做验收”。这是最迟已明确要求的时间，不证明最初提出。",
      "knownInstructionAgeSecondsAtAudit": 530886,
      "stage": "具名范围已交付"
    },
    {
      "id": "SHARED_ROUTE",
      "title": "普通共享阅读入口",
      "status": "Koma原上下栏具名恢复；389400f精确CI成功",
      "kind": "accepted",
      "result": "8564926B已装237；141全129帧及原72/73/74、87/88/89已审，原书名/章页与104底栏、原按钮顺序保持。142回书架仍001第6/24页，library/registry全同，reader仅该本3处阅读时间更新。保存/分享原生菜单沿138已验入口，未执行媒体写入。",
      "remaining": "本次Koma237001第6/24页上下栏、正常返回与三域保持范围冻结；入场时机、缓存及失败恢复继续各自未闭项。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "Root：237同章同页上下栏恢复具名范围冻结",
      "evidencePoints": [],
      "remainingActions": [
        "本次Koma237001第6/24页上下栏、正常返回与三域保持范围冻结；入场时机、缓存及失败恢复继续各自未闭项。"
      ],
      "boundaries": []
    },
    {
      "id": "ICONS",
      "title": "完整书源图标质量",
      "status": "用户确认完成",
      "kind": "accepted",
      "result": "用户确认完成",
      "remaining": "不自主重开已关闭图标；官方高清原件的出处限制仍如实保留。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不自主重开已关闭图标；官方高清原件的出处限制仍如实保留。"
      ],
      "boundaries": []
    },
    {
      "id": "SYNC",
      "title": "现有主分支远端同步",
      "status": "版本/tag/CI/预发布均已完成",
      "kind": "accepted",
      "result": "版本/tag/CI/预发布均已完成",
      "remaining": "v0.1.2-pre发布任务冻结；后续197已安装0.1.2-pre/code3见本轮条目，旧“新版未安装”已不适用，不把后续修复自动视为已发布。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": "2026-10-20T13:40:29.817024+00:00",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [
        "本轮用户明确授权“编写日志，提交发版。然后处理剩余问题”；正式v0.1.4 tag已推、peeled commit e8790e1708d44587cddf6eb3c5590803310ee761。因commit含skip-ci，正常workflow_dispatch同标签，run41039749491 in_progress；尚未发布成功，不上传AGC。0.1.4/code5、日志1585f2c7及代码CI41017177110已核。",
        "正式v0.1.4 Release428896795非draft/non-prerelease，2026-10-30T10:24:27Z发布；run41039749491 completed/success、head e8790e1708d44587cddf6eb3c5590803310ee761。下载HAP/manifest核tag SHA、reader pin、0.1.4/code5/release/debugfalse、4so、ICU许可及ZIP；HAP 29720346B SHA256 5bb137a2eb24a0e30e2c69818a28b9160361eac92e7c99ab04c7c58606790cda，现有流程unsigned，未上传AGC。Release正文strip后与changelog/v0.1.4.md逐字同。证据 .hvigor/outputs/user-flow-audit/release-readiness-0.1.4/evidence.json。"
      ],
      "remainingActions": [
        "v0.1.2-pre发布任务冻结；后续197已安装0.1.2-pre/code3见本轮条目，旧“新版未安装”已不适用，不把后续修复自动视为已发布。"
      ],
      "boundaries": []
    },
    {
      "id": "BACKUP_LOCAL",
      "title": "本地未加密备份创建与预览",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "自然失败回滚、其他备份与跨设备仍未验；不外推全库所有字段相同。",
      "reportedAt": null,
      "reportedAtSource": "不以摘要、当前时间或Git提交猜测原始人类提出时间。",
      "firstEvidenceAt": null,
      "closedAt": "2026-10-19T22:26:49Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "自然失败回滚、其他备份与跨设备仍未验；不外推全库所有字段相同。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_READER_TAPS",
      "title": "1700页归档点击未翻页",
      "status": "原误报已澄清",
      "kind": "accepted",
      "result": "原误报已澄清",
      "remaining": "不扩大到其他模式完整验收。",
      "reportedAt": null,
      "reportedAtSource": "本轮普通路径实际观察，不猜原始出现时间。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不扩大到其他模式完整验收。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_ARCHIVE",
      "title": "本地CBZ导入与进度重开",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不扩大为ZIP/其它格式、全部内容或Shared；两侧点击原误报已由同页宽图左右半原件澄清。",
      "reportedAt": null,
      "reportedAtSource": "本轮普通路径实际观察。",
      "firstEvidenceAt": null,
      "closedAt": "2026-10-19T23:20:11Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不扩大为ZIP/其它格式、全部内容或Shared；两侧点击原误报已由同页宽图左右半原件澄清。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_IMAGES",
      "title": "两张既有图片普通导入",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不冒独立顺序绑定、图片分支cold或全部格式通过。",
      "closedAt": "2026-10-19T23:39:24Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不冒独立顺序绑定、图片分支cold或全部格式通过。"
      ],
      "boundaries": []
    },
    {
      "id": "LOCAL_RESCAN",
      "title": "本地重扫与自然重选分支",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "自然失效根仍为不可经系统选择器选取的旧私有Smoke根；新增/变更/缺失输入未有当前样本，不造夹具。",
      "closedAt": "2026-10-19T23:39:24Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "自然失效根仍为不可经系统选择器选取的旧私有Smoke根；新增/变更/缺失输入未有当前样本，不造夹具。"
      ],
      "boundaries": []
    },
    {
      "id": "SETTINGS_SEARCH",
      "title": "设置搜索的实际消费者",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "仅中文该查询/目的页，不冒全部语言或设置生效。",
      "closedAt": "2026-10-19T23:45:59Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "仅中文该查询/目的页，不冒全部语言或设置生效。"
      ],
      "boundaries": []
    },
    {
      "id": "OPEN_SOURCE_NOTICE",
      "title": "开源声明占位内容",
      "status": "已批准并具名验收",
      "kind": "accepted",
      "result": "已批准并具名验收",
      "remaining": "不冒所有语言设备或全部许可合规审计。",
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不冒所有语言设备或全部许可合规审计。"
      ],
      "boundaries": []
    },
    {
      "id": "CATEGORY_LIFECYCLE",
      "title": "分类管理普通操作",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不扩大到多书替换、迁移或失败回滚。",
      "closedAt": "2026-10-19T23:55:31Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不扩大到多书替换、迁移或失败回滚。"
      ],
      "boundaries": []
    },
    {
      "id": "KAVITA_HISTORY",
      "title": "已配置Kavita普通阅读与历史重开",
      "status": "PARKED_USER：只待用户明确重提",
      "kind": "parked",
      "result": "PARKED_USER：只待用户明确重提",
      "remaining": "四私库实际验收已被人类明确搁置；不由heartbeat、旧记录或交接自主复活。",
      "closedAt": null,
      "owner": "PARKED_USER：等待用户重提",
      "evidencePoints": [],
      "remainingActions": [
        "四私库实际验收已被人类明确搁置；不由heartbeat、旧记录或交接自主复活。"
      ],
      "boundaries": [],
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "用户明确搁置四私库，只由用户重提恢复；自动唤醒不授权。"
      },
      "reportedAgeAtAudit": "未知：原始用户首报时间未核，不能用登记/firstHandling/firstEvidence替代",
      "reportedAgeSecondsAtAudit": null
    },
    {
      "id": "WEBTOON_READING",
      "title": "WEBTOON繁中普通公开阅读",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "全章、下载与Shared不在本次通过范围；分季标题未解析话数，稳定原序保持。",
      "closedAt": "2026-10-20T00:20:25Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "全章、下载与Shared不在本次通过范围；分季标题未解析话数，稳定原序保持。"
      ],
      "boundaries": []
    },
    {
      "id": "BROWSE_HEADER_REFRESH",
      "title": "书源分页后的当前数据刷新",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "不扩大为所有源与全部失败状态。",
      "closedAt": "2026-10-20T00:35:00Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不扩大为所有源与全部失败状态。"
      ],
      "boundaries": []
    },
    {
      "id": "BACKUP_ENCRYPTED",
      "title": "本地加密备份创建与预览",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "恢复、失败回滚与cold不在本次通过范围。",
      "closedAt": "2026-10-20T00:44:00Z",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "恢复、失败回滚与cold不在本次通过范围。"
      ],
      "boundaries": []
    },
    {
      "id": "APPEARANCE_CONSUMERS",
      "title": "主题、强调色和语言实际消费者",
      "status": "已采用整组设置范围完整交付：最终各图亲审/普通返回/七文件保持，2821CI成功",
      "kind": "accepted",
      "result": "SettingsPage单文件2821d0b746ef0dd025696c898ab93c57858b9e2f已exactpush，精确CI40446834903 completed/success、Build success/Publish skipped，无新tag/release（settings-services-icons-identity/ci-2821d0b7.json）。最终18906611下root top/bottom/services/search/config全部原图Root亲审，服务翻译单处/搜索直达及普通返回原书架具名，976七文件逐字同971、977系统120000无Override/8d478f8f释租。原脚本失败原件保留、未改PASS，不冒配置保存/Reader/provider。",
      "remaining": "本批人类采用整组图标/分类/唯一搜索入口交付完整，提交CI与原图审查等待均清，不重跑已验路径。原主题语言具名边界保持，后继实际源工作归原源项；provider/译图不由设置入口验收扩大。",
      "reportedAt": null,
      "reportedAtSource": "本轮普通路径实际观察。",
      "firstEvidenceAt": "2026-10-20T14:31:54.915842+00:00",
      "closedAt": "2026-10-20T14:31:54.915842+00:00",
      "owner": "Root：采用整组图标/翻译归服务已完整具名交付，2821精确CI成功，无本批等待",
      "evidencePoints": [],
      "remainingActions": [
        "本批人类采用整组图标/分类/唯一搜索入口交付完整，提交CI与原图审查等待均清，不重跑已验路径。原主题语言具名边界保持，后继实际源工作归原源项；provider/译图不由设置入口验收扩大。"
      ],
      "boundaries": [],
      "userDecision": {
        "source": "当前可见call_ac3a69d…明确“采用整组调整（推荐）”，不猜精确答复时间。",
        "icons": {
          "外观": "paintpalette",
          "书库": "grid（原）",
          "阅读": "doc_plaintext",
          "服务": "link",
          "下载": "arrow_down_to_line",
          "追踪": "checkmark_circle",
          "备份": "arrow_clockwise",
          "存储": "externaldrive",
          "高级": "gear（唯一）",
          "关于": "info_circle"
        },
        "preserved": "卡片颜色/大小/间距保持，翻译配置页/Reader即时操作保持；仅入口符号和分类差异。"
      }
    },
    {
      "id": "LIBRARY_COUNT_I18N",
      "title": "英文书架自动章节数量单位",
      "status": "已按人类批准实施并具名验收（既有记录）",
      "kind": "accepted",
      "result": "已按人类批准实施并具名验收（既有记录）",
      "remaining": "不外推所有页面/语言/源自带副标题。",
      "reportedAt": null,
      "reportedAtSource": "本轮实机新反例，不猜原提出时间。",
      "firstEvidenceAt": "2026-10-20T14:31:54.915842+00:00",
      "closedAt": null,
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "不外推所有页面/语言/源自带副标题。"
      ],
      "boundaries": []
    },
    {
      "id": "CATALOG197",
      "title": "完整手动章节目录当前路径",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "仅当前版本/样本，不外推未验分支。",
      "closedAt": "2026-10-21T01:43:46.574409+00:00",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "仅当前版本/样本，不外推未验分支。"
      ],
      "boundaries": []
    },
    {
      "id": "FOLDER_REIMPORT197",
      "title": "既有公共根重复导入",
      "status": "具名路径通过",
      "kind": "accepted",
      "result": "具名路径通过",
      "remaining": "仅当前版本/样本，不外推未验分支。",
      "closedAt": "2026-10-21T01:43:46.574409+00:00",
      "owner": "冻结路径：无当前执行者",
      "evidencePoints": [],
      "remainingActions": [
        "仅当前版本/样本，不外推未验分支。"
      ],
      "boundaries": []
    },
    {
      "id": "MONITOR_AVAILABILITY",
      "title": "原工作监控页8766服务无法打开",
      "priority": "P2（工具可达性，不抢产品主线）",
      "owner": "feedback_registry",
      "dependencies": [],
      "status": "原服务已恢复，本机HTTP及原浏览器通过",
      "kind": "accepted",
      "result": "原8766页面及/api/progress均HTTP200；本轮重新逐字段核对，页面实际返回与唯一snapshot的65项完全一致。反馈项未发现缺失，顶部HAP和源摘要的旧状态已纠正。 2026-10-28本机8766无监听，原进程退出原因未知；使用原脚本恢复后HTTP页面及接口200，接口与当前snapshot逐字段一致，原Edge页面刷新可见93项与21:41:25更新时间。服务为当前后台进程，未发现自启动或崩溃重启配置；页面以stage优先于status，部分旧stage导致显示摘要滞后，需另行校正原事项字段。 后续已切至当前用户临时launchd服务，原脚本及127.0.0.1:8766不变；RunAtLoad与KeepAlive启用，当前进程父进程1，页面和接口200且接口与snapshot一致，原Edge页持续连接。临时配置不写入登录自启目录，退出登录或重启后的持续性未验证。",
      "remaining": "保持当前用户会话内服务可用；退出登录或重启后的持续性未验证。",
      "reportedAt": null,
      "reportedAtSource": "Root转交用户当前无法打开反馈；原始人类提出的精确时间未核实，不猜填。",
      "firstEvidenceAt": "2026-10-23T00:53:09.114846+00:00",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-23T00:53:09.114846+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "保持当前用户会话内服务可用；退出登录或重启后的持续性未验证。"
      ],
      "boundaries": [
        "8766仅本机访问；当前用户会话使用临时launchd RunAtLoad与KeepAlive，非登录自启动文件；先前退出原因未知，退出登录或重启后的持续性未验证。"
      ]
    },
    {
      "id": "CBZ_IMAGE_ORIENTATION",
      "title": "导入CBZ部分图片颠倒的第三方反馈",
      "priority": "P3（用户明确低优先级）",
      "owner": "Root：原请求具名范围已交付，保未外推及实施授权边界",
      "dependencies": [],
      "status": "原授权P3只读分析已完成；未复现且未授权实施",
      "kind": "done",
      "result": "缺实际CBZ，未复现；已发现EXIF方向处理不一致的条件风险，仍为P3只读结论。",
      "remaining": "本轮检查分析交付已完成，不把无真实CBZ变成无限待实施任务。实际样本根因/修复均未证；新真实材料或明确实施指令到来时另按原项重开，不造样本或擅改正文/尺寸/裁切/缩略图。",
      "reportedAt": "2026-10-23T01:59:16.553Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 262071646 重新读原文与时间戳，不是摘要/登记时间。",
      "firstEvidenceAt": "2026-10-23T01:59:16.553Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:52:22+00:00",
      "references": [
        "https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-image#orientation14"
      ],
      "evidencePoints": [],
      "remainingActions": [
        "本轮检查分析交付已完成，不把无真实CBZ变成无限待实施任务。实际样本根因/修复均未证；新真实材料或明确实施指令到来时另按原项重开，不造样本或擅改正文/尺寸/裁切/缩略图。"
      ],
      "boundaries": [
        "源码未改，不把条件风险称用户根因；不造合成样本冒实机复现、不全局转180度、不抢当前高优先事项。"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "缺本次真实旋转CBZ，条件EXIF风险不冒根因，不造样本冒复现。"
      },
      "reportedAgeAtAudit": "2天17小时34分35秒",
      "reportedAgeSecondsAtAudit": 236075,
      "reportedDate": "2026-10-23",
      "reportedDateSource": "按上述原始UTC首报换算Asia/Shanghai日期，不使用登记日。"
    },
    {
      "id": "SOURCE_README_USER_GUIDE",
      "title": "重新整理koma-sources用户README",
      "priority": "待分配（本次未指定）",
      "owner": "/root/koma_sources_readme（已完成）",
      "dependencies": [],
      "status": "已完成，9243deb CI通过",
      "kind": "accepted",
      "result": "已完成，9243deb CI通过",
      "remaining": "本轮README整理范围已完成并冻结；后续仅随真实源发布/用户反馈按需更新，不重开已完成整理。",
      "reportedAt": null,
      "reportedDate": "2026-10-23",
      "reportedAtSource": "本次人类消息；提出日期为2026-10-23，未提供精确时分秒，不猜填。",
      "firstEvidenceAt": "2026-10-23T03:16:03.446263+00:00",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "evidencePoints": [],
      "remainingActions": [
        "本轮README整理范围已完成并冻结；后续仅随真实源发布/用户反馈按需更新，不重开已完成整理。"
      ],
      "boundaries": []
    },
    {
      "id": "SOURCE_PACKAGE_INSTALL_LIST_UI",
      "title": "源包管理按软件安装列表整理版本、动作、分组及标记",
      "priority": "P2（保当前P0不抢占）",
      "owner": "冻结：Root按实际新反例重开",
      "dependencies": [],
      "status": "源管理及公共分组具名普通范围完成，剩余消费者已补核",
      "kind": "accepted",
      "result": "公共2c05ea6c、源更新f4caffaa与65项工作单876b435f已推；精确CI40033988416/head876b435f成功，unsigned Release成功，tag发布跳过，无新发版。",
      "remaining": "本次具名普通范围完成；旧ImportPage非普通入口、四私库PARKED和其他未观察状态不扩大，不为补矩阵复活旧页。",
      "reportedAt": "2026-10-23T05:28:39.778Z",
      "reportedAtSource": "原始会话JSONL response_item/user实际时间戳；方向原文已核，不猜开始时间/耗时。",
      "firstEvidenceAt": "2026-10-23T05:28:39.778Z",
      "firstHandlingAt": "2026-10-23T16:00:12.538712+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T19:11:53.603541+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "本次具名普通范围完成；旧ImportPage非普通入口、四私库PARKED和其他未观察状态不扩大，不为补矩阵复活旧页。"
      ],
      "boundaries": [
        "失败候选及脚本错误原件保留：191副行不可见、193字号偏小均已撤；199错误选择器与202未滚入安装组的等待不冒产品故障。",
        "HDS拥有卡片、图标、后缀按钮和点击；只用官方B区Text/Span扩展，不覆盖像素，不改其他普通行或素材。",
        "全部更新只触发各源任务；等待中/更新中/完成由各源维护，不使用全局批量busy禁用其他行。",
        "按钮使用已批准绿色与既有字号/边距；任务文案固定及各源独立状态/串行lane保持。",
        "当前新增授权允许源管理三组header+对应卡片同一ListItem/Column，组内4、组间12；不以旧局部范围阻挡本次明确新增授权。",
        "保既有SectionHeader字号/左右及原生绿Button，不改其他页面、卡片/行或队列行为。",
        "当前用户公共封装要求允许普通分组统一至共同组件；不继续页面临拼，保原几何和业务状态。",
        "特殊搜索结果标题、章节ListItemGroup、源首页及备份多段说明不强套普通卡片；方法/build不替代可见验收，不宣称全App通过。"
      ]
    },
    {
      "id": "SOURCE_CHAPTER_DUPLICATE_TITLE_REVIEW",
      "title": "两书目录顶部同标题章节重复现象调查",
      "priority": "P2（目录身份只读核查）",
      "owner": "source_unknown_metadata：parser精确重复/冲突保留；Root：实机与诊断提交",
      "dependencies": [],
      "relatedItems": [
        "FIRST_CHAPTER_SELECTION",
        "CHAPTER_SORT_MENU"
      ],
      "status": "015精确重复合并197已验，远端CI发布完成",
      "kind": "done",
      "result": "包子015精确重复合并后197目录206/206且旧阅读位置保留；输出ID冲突不等于真实同章。",
      "remaining": "本具名精确重复范围冻结；仅新的输出身份冲突反例重开。",
      "reportedAt": null,
      "reportedAtSource": "Root本轮调查回传，未给原始提出精确时间，不猜填。",
      "firstEvidenceAt": "2026-10-23T06:17:05.337142+00:00",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "evidencePoints": [],
      "remainingActions": [
        "本具名精确重复范围冻结；仅新的输出身份冲突反例重开。"
      ],
      "boundaries": [
        "不得按标题、仅输出ID或统计24直接删除条目；href/title或输出字段冲突必须保留。"
      ]
    },
    {
      "id": "MANGA_DETAIL_PULL_REFRESH",
      "title": "漫画详情页接入下拉刷新",
      "priority": "P2（当前P0后，与源详情失败恢复关联）",
      "owner": "Root：详情下拉已接受具名范围冻结，无本项当前执行动作",
      "kind": "accepted",
      "status": "源与两类本地普通pull/保内容及自然重选已具名闭环；成功授权根重扫未外推",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS",
        "SOURCE_WEB_SESSION"
      ],
      "result": "保留197漫画1234已有源详情下拉结果。本轮237343原本地Download详情1章10页/6/10；344普通下拉完整161帧/5表经Root全部顺序亲审，内容/章节/进度持续保留且spinner正常结束，实际提示没有本地书架。237当时唯一local_folder为旧cache/import样本，所以该次只接受普通本地pull消费者/保内容，不冒注册根重扫成功。345整图仍1章10页/6/10。",
      "remaining": "原人类要求接入详情下拉的具名路径已闭环，无当前动作待办；成功授权根重扫仅未外推，自然挑战/失败保边界，不造样本/授权或重跑已验路径。",
      "reportedAt": "2026-10-23T10:40:04.632Z",
      "reportedDate": "2026-10-23",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 627051937 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": null,
      "firstHandlingAt": "2026-10-23T11:26:44.075783+00:00",
      "closedAt": "2026-10-25T21:38:31+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "本轮源、237旧cache普通pull和197真实root自然重选/保内容及最终恢复已闭环；成功授权根重扫保持未外推，不为原接入请求增加导入/造权限矩阵。",
        "源与本地已有具名范围保留；自然失败/挑战分别待真实条件，不清Cookie/缓存、不造网络故障或复活私库。"
      ],
      "boundaries": [
        "不造故障或清Cookie取样；本地归档不冒重解压，私库不新增请求或复活验收。保原父树/裁切/间距/内容及进度。"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T21:00:16.188000+00:00",
        "owner": "Root",
        "condition": "Root当前接197既存Local Folder Smoke：已保存173/library-before.json内为local_folder、2章3页，sourcePath为files/import/local-library-folder-smoke-root/extract/Fixture%20Series，remoteResourceId尾为Fixture Series；依LocalLibraryFolderContract:326可推rootUri为file:///data/storage/el2/base/haps/entry/files/import/local-library-folder-smoke-root/extract。Index:1598从comic推rootUris，经LocalImportCoordinator:755激活持久访问再扫描，并非凭空等独立rootStore。372已核物理目录存在，376自然命中持久访问缺失/失效重选并保内容，377五域保持；成功授权根扫描未外推，378/379返回及五域/timeout/释租已闭环。不造样本/重导，不把未验边界扩大为整分支阻塞。原件为NextN shared-mutual/pending-koma197-modal-baseline-173/library-before.json。"
      },
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "reportedAgeAtAudit": "至少2天8小时53分47秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 204827
    },
    {
      "id": "LIST_EDGE_SCROLL_FEEL",
      "title": "普通列表头尾回弹及短列表始终允许滚动",
      "priority": "P2（当前连续性能P0后）",
      "owner": "Root：原普通List/Grid与原生sheet具名范围完成；按新反例重开",
      "kind": "accepted",
      "status": "普通长短List/Grid头尾及原生sheet具名范围已收束",
      "dependencies": [],
      "relatedItems": [
        "MANGA_DETAIL_PULL_REFRESH"
      ],
      "reportedAt": "2026-10-23T10:53:01.515Z",
      "reportedDate": "2026-10-23",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 638672297 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": null,
      "firstHandlingAt": "2026-10-23T10:54:45.461347+00:00",
      "closedAt": "2026-10-25T20:17:00.688656+00:00",
      "result": "保197116/117普通长短List、118书架Grid顶部原具名结果。新增174普通筛选sheet拖bar到LARGE后内部空白区上下滑，全261帧/8表已Root顺审：上滑标题/关闭/内容随外层原生Scroll移动、dragbar不动，释放复位；下滑走原生挡位缩放，Back正常原书架。175三次normal fling至实际末行；176全201帧/6表已顺审，底部一次边缘动作内容上移再自然弹回，标题/底Tab正常。178恢复原顶部/原首三书，library-store和reader-preferences逐字同173，恢复系统120000无Override并释cded1338。",
      "remaining": "本次普通List/Grid头尾及原生sheet具名范围完成；不外推所有页面/输入或封面载入，不以Root自行扩出的独立内部ListSpring/标题固定要求保留假缺口。",
      "evidencePoints": [
        "直接产物索引：library-store.v1.json"
      ],
      "remainingActions": [
        "原人类要求的普通列表头尾阻尼/能加的始终允许滚动，在具名长短List、Grid头尾和原生sheet各自真实范围内收束；其他页/显示FPS/封面载入未扩大，只按真实新反例重开，不重复旧矩阵。"
      ],
      "boundaries": [
        "不外推每页、私库或阅读器正文，不为凑矩阵重复测试。保几何/方向/位置；自定义PullRefresh是唯一边缘位移owner。",
        "原用户普通滚动目标与Root自行要求的内部弹簧机制分开。174不证明内部ListSpring，但原两条也未要求这种机制/固定标题；不擅改SELF_FIRST现有sheet拖挡合同。"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T20:17:00.688656+00:00",
        "owner": "Root",
        "condition": "原具名范围本轮实际收束；未外推全页不是新增必验矩阵。仅真实新反例/相关消费合同变化重开，不重复174/176/178。"
      },
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "reportedAgeAtAudit": "至少2天8小时40分50秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 204050,
      "closedAtSource": "Root完成174/176全片亲审、178原顶部与数据/偏好/超时恢复后本次登记时刻；不冒充用户接受时间或设备精确结束时刻。",
      "evidence": [
        ".hvigor/outputs/reader-loading-background-20261011/device197__ALN-AL80/not-applicable/portrait-1260x2720/shared-mutual/pending-koma197-modal-baseline-173",
        ".hvigor/outputs/reader-loading-background-20261011/device197__ALN-AL80/not-applicable/portrait-1260x2720/shared-mutual/pending-koma197-modal-motion-174",
        ".hvigor/outputs/reader-loading-background-20261011/device197__ALN-AL80/not-applicable/portrait-1260x2720/shared-mutual/pending-koma197-grid-bottom-ready-175",
        ".hvigor/outputs/reader-loading-background-20261011/device197__ALN-AL80/not-applicable/portrait-1260x2720/shared-mutual/pending-koma197-grid-bottom-motion-176",
        ".hvigor/outputs/reader-loading-background-20261011/device197__ALN-AL80/not-applicable/portrait-1260x2720/shared-mutual/pending-koma197-session-restored-177",
        ".hvigor/outputs/reader-loading-background-20261011/device197__ALN-AL80/not-applicable/portrait-1260x2720/shared-mutual/pending-koma197-original-top-restored-178"
      ]
    },
    {
      "id": "TAB_ICON_SELECTION_FEEDBACK",
      "title": "主页Tab选中填充图标与点击弹跳",
      "priority": "P1（Tab切换动效新反例）",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "kind": "accepted",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "result": "b8a50cf已push，精确CI40015663006 success；243完整539PTS四跨选形变/回稳具名成立，原重复段与底栏范围保持。",
      "remaining": "原图标/跨Tab动效具名范围已闭环；所有输入或FPS未外推不构成待办，不重跑已验动效。",
      "reportedAt": "2026-10-23T16:04:59.789Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 822568417 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T16:08:13.970445+00:00",
      "firstHandlingAt": "2026-10-23T16:16:13.824783+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "evidencePoints": [],
      "remainingActions": [
        "原图标/跨Tab动效具名范围已闭环；所有输入或FPS未外推不构成待办，不重跑已验动效。"
      ],
      "boundaries": [
        "只重开跨Tab弹跳动效，不重开填充或普通源图标已验范围；底栏结构、文字、尺寸、颜色及根导航/滚动所有权保持。",
        "箭头/语言、安装安全队列、无设置入口、预加载与Browse原队列均保留。"
      ],
      "firstHandlingAtSource": "当前实现/构建结果首次登记，非精确编码开始时间；此前时段未知。",
      "priorAcceptedScope": {
        "status": "197具名验收完成并已推，精确CI成功",
        "closedAt": "2026-10-23T17:28:46.334448+00:00",
        "scope": "填充切换、同Tab重复点击及原具名普通导航范围；新跨Tab动效反例独立重开。"
      },
      "reopenedAt": "2026-10-23T19:13:48.461Z",
      "reopenedDate": "2026-10-24",
      "reopenedAtSource": "同一原会话归档字节偏移894684890，用户另报跨Tab切换无弹跳；first report保最早fill图标需求，不把新反例时间冒初次提出。",
      "feedbackReports": [
        {
          "reportedAt": null,
          "reportedDate": "2026-10-24",
          "source": "最新人类实测，无可信精确UTC",
          "summary": "底栏切至其他Tab无弹跳，仅重复点已选Tab有。"
        }
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "具名跨Tab动效/CI冻结，只按新反例重开，不派生全输入/FPS矩阵。"
      },
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "reportedAgeAtAudit": "至少2天3小时28分52秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 185332
    },
    {
      "id": "CMANHUA_ZH_ICON_REGRESSION",
      "title": "創漫繁中图标回退为默认菱形",
      "priority": "P1（已交付图标的新具名回退）",
      "owner": "Root：197普通更新与采用验收；源owner只读发布侧核查已完成",
      "dependencies": [],
      "relatedItems": [
        "ICONS",
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "accepted",
      "status": "197旧包缺图经正常更新恢复，具名范围冻结",
      "result": "197旧010安装包缺图，正常更新012后浏览显示既定蓝白W；未证实远端资源曾回退。",
      "evidencePoints": [],
      "remainingActions": [],
      "remaining": "仅197旧包缺图、普通更新与浏览采用范围冻结；新具名反例再开。",
      "boundaries": [
        "本次没有证明真正的资源回退；不外推全设备/所有源，也不重开ICONS素材矩阵。",
        "210工具超时原件保留，不误判更新失败；未清用户数据，库和reader完整内容保持。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类原文“创漫繁中的图标怎么又变成默认了？”；当前无可信原始UTC时刻，精确时间留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T18:12:56.863520+00:00",
      "firstEvidenceAtSource": "本次登记时刻；Root已亲审具名原图，不作为用户精确首报时间。",
      "firstHandlingAt": "2026-10-23T18:21:28.577481+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-23T18:26:12.662508+00:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。"
    },
    {
      "id": "BROWSE_PULL_REFRESH_STALL",
      "title": "浏览页下拉刷新停住数秒才收回",
      "priority": "P1（交互阻塞新反例）",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "dependencies": [],
      "relatedItems": [
        "LIST_EDGE_SCROLL_FEEL",
        "SOURCE_INDEX_PROGRESSIVE"
      ],
      "kind": "accepted",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "result": "233完整回缩、匹配trace与数据保持成立；该派生修复已含876b435f，精确CI40033988416 success。原80源根Browse范围冻结。",
      "evidencePoints": [],
      "remainingActions": [
        "原根Browse卡顿缺陷具名闭环；单源页/FPS未外推，不增矩阵，不改原样式或私库。"
      ],
      "remaining": "原根Browse卡顿缺陷具名闭环；单源页/FPS未外推，不增矩阵，不改原样式或私库。",
      "boundaries": [
        "修改对象仅BrowsePage重复派生列表：按53cbc39a历史保名称排序，允许差异仅缓存同一响应式派生值。",
        "行结构、计数、分隔线、样式、动画及私库请求行为保持；不凭credential线索擅改，不复活私库验收。",
        "预加载225/227缓存命中有限结果和App/三仓WIP继续保留，不取消或当作已交付。"
      ],
      "reportedAt": "2026-10-23T18:44:31.428Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 885259792 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T18:45:24.863746+00:00",
      "firstEvidenceAtSource": "本次登记时刻，不冒充用户精确首报。",
      "firstHandlingAt": "2026-10-23T18:53:36.630490+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "firstHandlingAtSource": "本次真实执行登记起点，早先分析与取证未分段，不倒填。",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "根Browse具名修复冻结；单源/FPS未扩大，只按具体新反例重开。"
      },
      "reportedAgeAtAudit": "至少2天0小时49分20秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 175760
    },
    {
      "id": "SOURCE_ROW_NATIVE_ARROW",
      "title": "源列表右箭头应采用设置同款原生尾部",
      "priority": "P1（UI一致性与准确性）",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "accepted",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "result": "235箭头与设置一致，253普通源行实际进入3Hentai源页；Root亲审，尾部/点击范围成立，源正文失败另留。",
      "evidencePoints": [],
      "remainingActions": [
        "原源行尾部箭头视觉/点击具名闭环；同类批准未知不等于全局重做待办，3H正文另项、私库PARKED保持。"
      ],
      "remaining": "原源行尾部箭头视觉/点击具名闭环；同类批准未知不等于全局重做待办，3H正文另项、私库PARKED保持。",
      "boundaries": [
        "具体实施授权仍限定源行尾部，保图标、行高、动作；同类审计不等于全局重做授权。",
        "不擅改已批准定制或冻结界面，不重开ICONS矩阵；预加载及其他WIP保留。"
      ],
      "reportedAt": "2026-10-23T18:59:53.159Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 886434027 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T19:01:03.959368+00:00",
      "firstEvidenceAtSource": "本次登记，Root已查源码；不冒充用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "源尾部已交付/CI成功；同类未知样式未批准，私库PARKED，不借统一扩大。"
      },
      "reportedAgeAtAudit": "至少2天0小时33分58秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 174838
    },
    {
      "id": "SOURCE_LANGUAGE_DISPLAY_CONSISTENCY",
      "title": "源语言展示统一格式化入口",
      "priority": "P1（跨页面展示一致性）",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_ROW_NATIVE_ARROW",
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "accepted",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "result": "259原生终图已显示已安装与未安装两组的语言名称/红18+；两页既有范围保留，未知标签不外推。",
      "evidencePoints": [],
      "remainingActions": [
        "两页语言一致性具名闭环；未知语言仅未外推，不造metadata样本，不改源身份/筛选语义。"
      ],
      "remaining": "两页语言一致性具名闭环；未知语言仅未外推，不造metadata样本，不改源身份/筛选语义。",
      "boundaries": [
        "当前有效决定是实际语言名称（语言自称）与红18+，不再按raw代码安排。",
        "只改展示语言/标记文案，原metadata/身份/筛选语义保持；18+仍在语言后，不扩大布局或样式重做。"
      ],
      "reportedAt": "2026-10-23T19:05:26.547Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 892238294 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T19:07:50.969774+00:00",
      "firstEvidenceAtSource": "本次登记时刻，不冒充用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "已装/未装语言展示冻结；未知语言缺实际源样本，不造manifest或重跑旧语言。"
      },
      "reportedAgeAtAudit": "至少2天0小时28分25秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 174505
    },
    {
      "id": "SOURCE_INSTALL_GLOBAL_DISABLE",
      "title": "单源安装或更新导致其他源按钮全部禁用",
      "priority": "P1（安装交互阻塞）",
      "owner": "Root：原请求具名范围已交付，保未外推及实施授权边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "accepted",
      "status": "原全局禁用触发已由具名安全队列/排空覆盖，提交CI已完成",
      "result": "258一次触发形成1运行+7等待，随后排空；259实际23项升级、80源身份与enabled保持，library/reader同值，安全队列具名成立。",
      "evidencePoints": [],
      "remainingActions": [
        "原安装/更新其它项全禁用问题已具名闭环；失败/取消/重复提交为未外推自然边界，不造失败样本或重跑排空。"
      ],
      "remaining": "原安装/更新其它项全禁用问题已具名闭环；失败/取消/重复提交为未外推自然边界，不造失败样本或重跑排空。",
      "boundaries": [
        "安全排队仍由各包状态和registry串行写入共同负责，不能只删disabled后裸并发；箭头和语言已有各自具名结果。",
        "浏览卡顿具名范围和跨章预加载WIP保留，不因新项抛掉原队列。"
      ],
      "reportedAt": "2026-10-23T19:07:10.649Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 894124364 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T19:08:16.947392+00:00",
      "firstEvidenceAtSource": "本次登记，源码链由Root核实；非用户精确首报时间。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:52:22+00:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "正常队列/各源状态冻结；自然失败/取消/重复提交缺样本，不制造破坏性失败。"
      },
      "reportedAgeAtAudit": "至少2天0小时26分41秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 174401
    },
    {
      "id": "SOURCE_EMPTY_SETTINGS_ENTRY",
      "title": "无设置描述符的源仍显示可点击设置入口",
      "priority": "P1（无效操作入口）",
      "owner": "source_owner_terra负责源代码及已推祖先公开实体核验；Root核双X重复探测复用方案及ABI/失败恢复/源身份边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_DIRECT_ENTRY"
      ],
      "kind": "accepted",
      "status": "XCOMIC一次检查具名交付已核",
      "result": "App91f7ae41ee172bdea60d2079c2874f830eddd849已推master，精确CI40465425869 success；get_settings只读本源settingValues/context feature已交付。197998装final18910787同签包，新EN.18继承旧Safe菜单仅Safe勾选、1000继承readback与legacy字节同，显式Safe保存重入及普通Home十本九真封面具名，清own EN回参考Safe/Suggestive。1001对994六非Registry文件逐字同、85 IDs/order/enabled与其它84DTO同，仅EN.12→.18；own上传删空，1003系统120000无Override/ead21ec9释租。源e44 SOURCE_INCLUDE实际237 BERSERK13→madex4→clearown13，繁中保存重入清空；de041网页类别黑名单双开关持久、简中true Browse12卡具名。Nami c5受控/Native范围：默认false/旧Host保持，true仅锁定元数据，受控WASM保正文gating；237633–636设置与荆棘1/1自然目录通过，无自然锁章，不冒锁章Native或新正文。637本批七状态文件对632逐字同、81身份/enabled/序及other79同、own两包删空。精确源push/CI/公开由Root按串行批核。 de041准确release425150163/tag sources-de0413989d130811a03f742f123ed26fe67bdeaf已公开，实取85唯一索引与三Linux包manifest/index一致：XCOMIC Hans.5 210966/572250B、Hant.5 210571/571244B、EnglishMD.18 32419/115171B。原三WASM消费脚本改指真正公开实体，edition旧默认/过滤/归属、ignore两个query消费及EN context继承全部过；原回执不覆盖，public-de041/inspection.json、*-result.json、*-public-execution.mjs有据，不冒public新Native。Nami c5b2bb000425faace57a74e3bcab0cd5133871f6已精确push，CI40471172293 build/tests通过、最后发布HTTP500使conclusion=failure，准确release425173267已公开且实核，不重跑发布。 Nami准确sources-c5b2bb... release425173267非draft、08:07:59Z/211非空assets，与前版数同；85唯一index/双包manifest匹配，Hans.3 36516B-WASM79997B、Hant.3 36507B-WASM80001B，原生产runner改指公开两实体全通过，source-settings-repair/public-c5b2bb0/inspection.json及执行结果副本保原。CI failure不改成成功，真实公开不因最后API500重发。 当前源description已19718909972本批具名：公开XCOMIC Hans.5完整源说明三行/输入madex后仍在两原图、Simply.1 blacklist格式说明原图Root亲审，普通返回原书架；1009对1005六非Registry字节同、85IDs/order/enabled及other83DTO同，仅Hans.1→.5/Simply.0→.1，两个own上传删空，1010系统120000无Override/1ac1fa23实际release。证据source-settings-repair/source-text-description197-restoration-comparison.json及197 diagnostics/source-text-description197-ordinary-1004。首脚本Simply搜索方向假设失败原件保留，普通续接未重跑XCOMIC。产品两文件0510b5c20510b84a4bf4fcc134fbe749593d4134已精确push，CI40473371352 completed/success，说明本批交付等待已清。 当前XCOMIC真实625日志get_manga约93235/93340ms、get_chapters101015/100738ms，串行逐comic_ids probe与固定参考每批五async不同。Root有界公开请求中五alias被multiple root fields not allowed拒绝，原件保留不重试，第三single未发；Host additive source_http_batch_v1沿原import接受一至五请求Promise.all，保逐项身份/限速/CookieUA/redirect/timeout/错误与原序，不增import/C++/缓存/自动重试/超时改动。197使用Host18928136与双XCOMIC简繁0.1.6，普通Browse各12卡→目录13/13及582/582后返回，未入Reader/未加库；四个get_manga/get_chapters同次操作实际峰值并发5、全部HTTP200且结束无残留，耗时23487/22592/22482/26896ms。与旧237不同时机/设备，不作严格性能AB或全卡顿闭环。六非Registry文件逐字同、85源ID/order/enabled及other83DTO同，仅双X升级；own上传已删，941a租约已释放。App batch五文件已提交并精确推送7230d110，CI40485480396 completed/success；源668c785257b959f006bece2fe2ead56dcec90480已精确推送，CI40485503849 completed/success，release425283341/tag sources-668c785257b959f006bece2fe2ead56dcec90480已发布、211非空assets，公开实体核验完成。 原传输/会话检查及旧Host/新Host5/5/2子请求DTO受控结果保留。此前237新设置场两次审批在执行前拒绝，原租约已释放；后续用户明确授权并已完成五包设置场，见下方source项回执。 237最终归还receipt已由doc writer实际读取核：最终18910787安装启动成功，655原斗破Continue P1/3%图有据；653原62progress/30history、49库身份序及Saya原PNG/20页保持，656八文件逐字同654，正式81源升级保。原CF/Global真实阅读时间戳差与11新增ledger按GUI语义保留，非全reader同393。十九own上传/agentbackup/owndaemon/8012清理，657仅SLEEP下timeout-r与Power读回，normal120000/noOverride且SLEEP，新a8de0540短lease已release exit0，无wake/UI/安装/app写入或suspend。 公开实体已核：85唯一ID索引及所有索引包/图标assets齐，211 assets非空；Linux Hans211635B/WASM575856B、Hant211320B/WASM574874B，manifest与index一致。复用原生产WASM runner指向公开实体，两源旧/新Host受控执行通过；197普通路径使用本地编译包，不冒公开包新安装。证据source-settings-repair/public-668c785/inspection.json及xcomic-batch-wasm-result.json。 MangaDex三源标题优先独立本地commit0e276ecb39bb7bc7f1f0159c0ac39e2b31a782a7（父29a3d32）已随e36推送；EN.20包33614B/WASM118345B、Hans.8 49027B/102211B、Hant.8 49111B/102397B。实际生产WASM默认/true保持原DTO与HTTP，false按参考标题顺序；EN列表/搜索/详情/Home及双中文消费者已执行，三源章节DTO/HTTP深同。无新provider HTTP或Native，原五包保持。直接证据source-settings-repair/mangadex-title-preference-wasm-result.json及candidates.json。 XCOMIC双源候选在237具名详情与完整目录已核；公开实体简体具名目录已核，繁体公开实体仅安装核字节。宿主一次检查提交已推、精确CI进行中；原宿主、两源及数据恢复释租。 Host 2980ba6精确CI40788305052成功；繁体公开实体详情仍未Native验证。",
      "evidencePoints": [
        "直接产物索引：Komiic.kt；all85-source-settings-comparison.json；index.pb",
        "当前源功能/边界直接证据：Noya day/week/month设置持久（非auth/ADULT内容）见source-settings-repair/noyacg-ranking-restoration-comparison.json、public-ae71f7c/inspection.json；Global默认锁定目录/开关恢复（非付费正文或Native精确mobileURI）见public-44189ba/inspection.json；MangaBall已入库明确排除/清配置复原见public-5ed3d78/inspection.json及原575–579恢复receipts；XCOMIC默认/题名清理有限Native与实体执行见xcomic-title-restoration-comparison.json、public-037ce4f/entity-wasm-result.json；Gallery仅开关持久/临时Hfox移除与81恢复见gallery-short-title-restoration-comparison.json（非短标题内容Native/全场恢复）。以上路径均在source-settings-repair下，具体已验/未验不由后批摘要替换。",
        "Gallery公开生产合同直接证据：source-settings-repair/public-34f7f78/inspection.json与short-title-wasm-result.json；真正公开四Linux WASM受控执行通过，非新站点HTTP/Native内容验收。",
        "MD HTTPS443直接证据：source-settings-repair/mangadex-port443-restoration-comparison.json及wasm-result.json；Native仅设置持久/保全，生产受控query唯一forcePort443=true不代Native URI。",
        "本批四源准确公开直接证据：source-settings-repair/public-6544211/inspection.json及该目录四*-wasm-result.json；Linux真实生产WASM受控复用原fixture，Native各local实体/原baseline分别保持，不冒public新安装。",
        "本批与总场恢复基线：source-settings-repair/{xcomic-editions-restoration-comparison,xcomic-ignore-genres-restoration-comparison,namicomi-show-locked-restoration-comparison,device237-total-reader-current-differences}.json；237原reader/library/registry/settings为source-settings237-host-installed-393，初settings另有384；Nami该批次对照637，最终归还656/657见下项。web/search/reader-preferences仅有后来基线，不冒本场起始逐字同。",
        "EN只读context/旧Safe继承与恢复直接证据：source-settings-repair/mangadex-en-context197-restoration-comparison.json；197 diagnostics/settings-context197-ordinary-993。源de0413989d130811a03f742f123ed26fe67bdeaf已精确push/CI40468122999 success，准确release425150163/85唯一索引三公开包及生产消费脚本已核，见source-settings-repair/public-de041/inspection.json与各result/execution文件。",
        "Nami准确公开与执行直接证据：source-settings-repair/public-c5b2bb0/inspection.json及result/执行副本；CI40471172293最终failure与真实release425173267非空完整公开分别记，不重跑发布。",
        "源description197直接证据：source-settings-repair/source-text-description197-restoration-comparison.json；197 diagnostics/source-text-description197-ordinary-1004。1009六非Registry同1005/两源预期更新与1010系统释租具名，未重跑XCOMIC。",
        "XCOMIC串行probe/批量请求边界直接证据：source-settings-repair/xcomic-probe-batching；五alias请求被站点拒绝的原件保留、不重试，Host一至五请求并行合同已build/真实传输会话执行，并在197双X .6普通浏览→目录路径具名：四操作实际峰值并发5、HTTP200、结束无残留；未入Reader，不作跨设备严格性能AB。直接回执见同目录xcomic-batch197-native-runtime-review.json及xcomic-batch197-restoration-comparison.json。",
        "237最终归还直接证据（已实际读取）：source-settings-repair/device237-final-handback-receipt.json；原category-membership/source-settings237-sleep-timeout-final-657/run-metadata.json。最终Host18910787/原Continue与653数据有限保持、656八文件同654、657SLEEP+120000无Override/release0核验，正式升级保/读态时间及11ledger差异不冒全字节同。",
        "source-settings-repair/xcomic-batch197-native-runtime-review.json",
        "source-settings-repair/xcomic-batch197-restoration-comparison.json",
        "source-settings-repair/public-668c785/inspection.json；xcomic-batch-wasm-result.json：真正公开Linux两源旧/新Host受控执行通过，非公开包新Native安装。",
        "source-settings-repair/mangadex-title-preference-wasm-result.json；candidates.json：本地三源标题偏好与章节不变合同，非Native验收。",
        "源8ff201b9095e9b17487323915f5a3e857d40bfce CI40787019789 success；候选简13/13、繁582/582，公开简Perle2/2及detail22→chapters3 HTTP200；Host 2980ba6cd5e0af679d6da18857fa9a2161a0e14f CI40788305052进行中。",
        "https://github.com/honjow/Koma/actions/runs/40788305052"
      ],
      "remainingActions": [
        "source_owner_terra负责源代码与已推祖先公开实体核验；Root核双X重复探测复用的ABI及失败恢复/源身份边界。MangaDex标题偏好0e276ecb已随e36推送，真实标题两状态Native未验；书源验证默认237并按流程取得租约及恢复。"
      ],
      "remaining": "一次检查宿主交付已核；繁体公开详情及其他原范围保持。",
      "boundaries": [
        "只收口manager/Browse/独立Search已有具名空设置入口；未知或失败不能误当无设置，不称所有源描述符已验。",
        "保设置直接弹出、保存/清除和关闭返回范围；3Hentai无search能力不构成新导航缺陷。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈；无可信精确UTC首报，reportedAt留空；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T19:11:07.767687+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-24T03:35:01.638296+00:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "userDecision": {
        "source": "当前可见人类明确答复，未提供精确答复时间，不猜时间。",
        "description": "展开完整显示；仅取消expanded二十行上限，折叠三行/字号/间距/按钮保持。",
        "globalcomix": "按参考默认显示锁定章，仅目录；正文free guard、无登录付费保持。",
        "mangaball": "默认只非成人，隐藏成人默认开启/no_18；用户关闭后按参考all。",
        "emptyMultiSelect": "当前人类明确采用：空候选原行完整源description、取消空点击/箭头，有候选恢复原样式；不再待答。",
        "mangabz": "当前可见call_fa43df…人类采用“按参考补齐，默认简体（推荐）”；新cap mangabz_language_cookie_v1，false/未配lang2、true lang1，旧Host旧输出。",
        "sourceDescriptions": "当前人类明确采用：各类源设置长标题换行并显示源自带说明；空说明不显示，沿原组件外观及次要文字样式。"
      },
      "stage": "宿主CI成功，其他原范围继续"
    },
    {
      "id": "SOURCE_PACKAGE_ICON_INVALIDATION",
      "title": "安装或检查更新导致源图标闪烁",
      "priority": "P1（当前源性能主线）",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_INDEX_PROGRESSIVE",
        "SOURCE_PACKAGE_INSTALL_LIST_UI"
      ],
      "kind": "accepted",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "result": "已解码本地fileURI后续回交用syncLoad，首次/换图/远程仍异步。209签名Release8583407B明确安装且三域同208；211一次Happy013安装完整96原PTS编码帧已亲审，源图标在0–69均可见，9切安装中、70正常整行移出。其他可见图标保持；不外推197更新或旧92样本。",
      "evidencePoints": [],
      "remainingActions": [
        "Happy具名安装触发已闭环；197更新/旧92/换URI未扩认，仅有新适用反例时重开，不清缓存/重装造样本。"
      ],
      "remaining": "Happy具名安装触发已闭环；197更新/旧92/换URI未扩认，仅有新适用反例时重开，不清缓存/重装造样本。",
      "boundaries": [
        "新反馈不替换原队列；Reader未完、3HNative及已批准/冻结范围继续保留。",
        "源码线索不等实测根因；不清缓存或批量重做界面制造通过。"
      ],
      "reportedAt": "2026-10-23T21:03:50.512Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 937227707 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:12:10.554202+00:00",
      "firstEvidenceAtSource": "本次记录时刻，不冒充用户首报。",
      "firstHandlingAt": "2026-10-23T21:12:10.554202+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "firstHandlingAtSource": "源码调查已由Root进行；仅本次可核登记起点，更早未分段不倒填。",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "modificationBasisDecodedLocalSync": {
        "object": "ConciseListRow.SourceIdentityPrefix内仅图标Image的加载时机",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "保持HDS原生卡片/动作、图标Contain/30vp/R7/光学校准，异步首载避免全部源图标阻塞主线程。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅同一file://URI在本行已成功解码后，后续前缀重建用syncLoad；首载/新URI保持异步。按构建时URI快照处理完成/错误，拒过期回调；不新增全局像素缓存、不改资源/大小/圆角/缩放/材质/原生按钮。"
      },
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-icon237-decoded-sync-candidate-209",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-icon237-happy-manager-position-210",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-icon237-happy-firstinstall-motion-211",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-icon237-happy-after-recording-212",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-icon237-happy-natural-return-213",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-icon237-happy-final-readback-214"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "具名安装/图标冻结；旧92/换URI异常无新样本，不清缓存/换URI/重装制造。"
      },
      "reopenedAt": "2026-10-23T21:07:43.539Z",
      "reopenedAtSource": "同一原会话归档字节偏移937848385，用户另报检查更新时全部图标闪烁；首报仍为21:03:50安装时左图闪烁。",
      "reportedAgeAtAudit": "至少1天22小时30分1秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 167401
    },
    {
      "id": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "title": "源安装期间主线程UI阻塞",
      "priority": "P1（当前源性能主线）",
      "owner": "Root：197源安装性能定位修复",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_INSTALL_GLOBAL_DISABLE",
        "SOURCE_PACKAGE_ICON_INVALIDATION"
      ],
      "kind": "done",
      "status": "具名普通安装更新及返回已验，正式CI成功",
      "result": "197本地导入及公开更新普通路径已核，返回浏览列表保留并显示最新版本；正式提交和精确CI成功。",
      "evidencePoints": [
        "直接产物索引：https://github.com/honjow/Koma/releases/tag/v0.1.3-pre；230/audit/frequency-comparison-224-230.json；build.log；diagnostics-redaction-reuse-review/txt-suffix-unadopted-candidate.patch；300/audit/callback6739-scheduler-frequency.json；koma-log-export-20261026-003924.log；307/audit/aligned-existing-cpu.json；audit/aligned-existing-cpu.json；/tmp/koma-computed-fresh-result-before.txt；test_source_index_progressive.cjs；receipt.json；Koma-source-current-result-fixed-signed.hap；manhuagui-network-phase-review/source-head-current.json；manager-after-real-update.png；browse-name-projection197-session-513/result.json；offline-window-review.json；mh160-web-entry-chain-review/browse-name-projection-ci-detail.json；scripts/test_source_install_worker.cjs；temporary-browse-row-count.patch；pre2-browse-source.png；restored-library.png；pre2-batch-update-before.log；pre2-batch-update-after.log；candidate2-manager-details.png；pre2-candidate2-ci-detail.json；index.json；pre2-current-source-index.json；pre2-current-source-update-comparison.json；manager-cache-url-before.log；manager-cache-reader-relevant-final-tests.log；manager-cache-url-final-build.log；registry-update-review.json"
      ],
      "remainingActions": [],
      "remaining": "",
      "boundaries": [
        "434 fs.rmdir工作线程execute0.288ms，main complete22.115ms含Promise微任务，不当成主线程目录删除。",
        "237079 trace完成后才加入持久化/发布/投影分段，不以诊断日志代替性能修复；本行prefix瞬空另项保留。"
      ],
      "reportedAt": "2026-10-23T21:05:37.075Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 937712232 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:12:10.554202+00:00",
      "firstEvidenceAtSource": "本次记录时刻，不冒充用户首报。",
      "firstHandlingAt": "2026-10-23T21:12:10.554202+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-29T19:18:01+08:00",
      "firstHandlingAtSource": "源码调查已由Root进行；仅本次可核登记起点，更早未分段不倒填。",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "modificationBasis": {
        "object": "本地归档导入接入SourceIndexService既有串行队列及管理页其他源安全排队",
        "history": "f4caffaa/41e753dd及SOURCE_INSTALL_GLOBAL_DISABLE既有接受边界：其他源可排队，写入串行；不得只移除disabled形成裸并发。",
        "allowedDifference": "未知源ID用不含URI的唯一内部任务ID；仅本地导入期间允许其他源安全入队，保删除、重复选择器和批量操作busy保护。197具名普通本地导入已核，其他路径不外推。"
      },
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-terminal237-missing-tail-112",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-terminal237-zerobyw-install-trace-113",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-registry-size237-simply-install-trace-115",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-identity237-nhentaito-install-trace-117",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-identity237-natural-return-118",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/source-install197-tongli013-current-trace-605",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/source-language197-manager-key-606",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/source-language197-return-readback-607",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-registry-baseline-154",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-current-app-deployed-155",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-huanta011-manager-position-156",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-huanta011-first-trace-157",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/huanta011-native237-first-reader-158",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/huanta011-native237-natural-return-159",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/huanta011-native237-shelf-data-readback-160",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/huanta011-native237-diagnostic-log-161",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-soc001-cpu-prepared-165",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-soc001-cpu-trace-166",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-soc001-formal-restored-167",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/soc001-native237-first-browse-168",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/soc001-native237-first-reader-169",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/soc001-native237-original-observed-170",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/soc001-native237-natural-return-171",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/soc001-native237-final-readback-172",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-ipmini011-batch-prepared-173",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-ipmini011-native-batch-trace-174",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/ipmini011-native237-first-browse-175",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/ipmini011-native237-browse-result-176",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/ipmini011-native237-first-reader-177",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/ipmini011-native237-natural-return-178",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/ipmini011-native237-final-readback-179",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-immark-cpu-prepared-196",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-immark-manager-position-198",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-immark-cpu-trace-199",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-immark-formal-restored-200",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-hash-worker-candidate-204",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-zazhimi-manager-position-205",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-zazhimi-hash-worker-trace-206",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-hash-worker-natural-return-207",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-install237-hash-worker-final-readback-208",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-index-109/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-target-110/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-update-state-readback-111/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-bytes-and-update-events-112/",
        "237 Zero公开017 run586系统picker→管理sheet→导入成功连续录屏已审，无全表清空；无安装中输入，不作交互流畅性能验收。",
        "Koma c32b4d11e8bc89f1cbac08ec72027b444128e403已推，四条既有生命周期执行检查及同签release构建完成；CI40791708093进行中。",
        "https://github.com/honjow/Koma/actions/runs/40791708093",
        "run786 trace：UI实际帧48.746ms，节点更新22.617ms、布局21.999ms，另FullGC 50.189ms；旧hilog PID不匹配，0字节不作为无事件证据。",
        "run820候选实际最长帧50.852ms，786为48.746ms；815受sheet遮挡，821仅覆盖sheet关闭后。原7f9/数据/源包及电源恢复由source owner报告，Root独立核对待完成。",
        "237 run824五文件与810逐字相等，825原源实体与764及备份一致，826 SLEEP/120000无override；821三张联系表已审仅覆盖sheet关闭后。ConciseListRow候选已撤回且文件无diff。",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-import-830/cpu.json：UI更新26.336ms，行组件创建17.213ms；原已安装组77行整体布局。",
        "run859同锚点标题bounds与849相同但分隔线端部异常；861尾端重复首4行由source owner报告、Root待读图。",
        "run869 actual58.736ms、UIVsync58.711ms、Dirty30.884ms、Layout23.630ms；更新组与820不同，不作严格AB。候选patch保存在869，SourcePackageManagerPage已无diff；873–875恢复核实。",
        "diagnostics/import-stall197-{registry-byte-map-r3,mh-path-check-r4,mh-exact-restore-r5,restored-cold-r6}；85 metadata、84 WASM长度匹配，MH1234原013目录缺失后按原四成员补回。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/import-stall197-restored-manager-r7/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/import-stall197-current-import-trace-r11/",
        "run11实际UI帧325.863ms，Dirty122.975ms、Layout180.32ms，同帧54图标StartDecoding累计128.982ms；sheet遮挡，不作视觉流畅或严格AB结论。",
        "r13误用商店签名被设备拒装未替换；r14默认product release证书/profile与原7f9逐字相等并安装成功，r15 picker，r16导入trace进行中。",
        "r16图标解码128.982→1.905ms但UI帧187.534ms；未采用补丁/private/tmp/koma-retained-source-icons-unadopted.patch，两个组件已撤回无diff。新队列执行case及原检查通过，同签构建中。",
        "197最终候选db31ee3d02b6a33e2d9be6be84177cf75d8b0ccc7cd7686906a8e740a83037a1：r23同包普通导入maxMainFrame26.851ms/mainIconDecode0，r20录屏446帧全审；r24七域及原包四成员相同，r25按官方相对路径删除唯一自有目录并读回，r26原电源状态及租约恢复。r24绝对路径删除失败保留。",
        "https://github.com/honjow/Koma/actions/runs/40831671392：39e8ad2cdf4efa25083993429b13c2319414df01 completed/success。",
        "197 run29公开杂志迷010→012主UI帧最长37.201ms、目标图标解码4次合1.735ms；fs.rmdir完成回调67.787ms非vsync帧且原因未知。run31原生日志row_projection4ms、persistSync13/cleanupAwait6/publishSync1。",
        "run32七域与27逐字同、原杂志迷四成员与r1相同，唯一临时导入目录删除并读回不存在；run33 SLEEP/120000/Override10000，租约released。",
        "197 fb8809候选run38同85源及杂志迷010→公开012：主vsync30.221ms，fs.rmdir完成回调55.698ms，目标图标解码4次2.086ms；前场37.201/67.787并非严格AB，原因未定。",
        "run39七域与34逐字同、原010四成员同r1，本轮012自有导入目录删除并读回不存在；run40 SLEEP/120000/Override10000且租约released。",
        "Koma 5bc04102已推；短SHA筛选返回0不作CI状态判断，精确CI待核。",
        "Koma 5bc041023ba79e66fd8606c18bcc61b8787f1075 CI40839273297 completed/success；连接器传输失败后官方只读API核实，非CI失败或重跑。",
        "197 baseline71/awake72/installed73/package74，75杂志迷010→012实际更新及trace；probe误放installIndexEntry分支，CPU文件未生成，不作性能验收。已改至updateInstalledPackage并构建，77按71基线恢复原源四成员及七域后再采；会话尚未结束。",
        "source-install197-current-update-cpu-trace-80/cpu-callback-findings.json：ad58临时探针、杂志迷010→012回调47.829ms；85/85 onVSync样本位于同trace FlushDirtyNode区间，零时钟offset。BrowsePage monitor→loadInstalledSources采样15.523ms，sourceRuntimePackageIconUri 7.566ms；非干净AB。81原包四成员及七域恢复，82原9f13生产包回装，设备仍持租常亮。拟仅抑制不可见Browse重建并返回时消费revision，未构建/Native。",
        "197 625d4516同签无探针候选：85杂志迷010→012回调28.126ms、mainVsync25.91ms，具名样本非严格AB；86普通Back连续80帧/3表全审，首帧保留无整屏空白，原行显示0.1.2。source-install197-current-cpu-71/visibility-browse-version-proof.json及对应png；87原010四成员逐字恢复、88原书架第1页100%及七域byteEqual，89 SLEEP/120000/Override10000、租约released。原反馈offset937712232为安装期间UI阻塞及安装后整页检索，不设未获要求的全设备帧时目标。",
        "App267e8f33df20587e96385bb5f4b3ffec868346a1已推，精确CI40863443089 completed/success；source-install197-current-cpu-71/delivery-findings.json。197 85具名更新回调28.126ms/mainVsync25.91ms，非严格AB；不设全设备小于16ms目标。"
      ],
      "modificationBasisPersistence": {
        "object": "SourceRuntimeRegistry.persistEntriesToAppLocalMetadata的WASM长度检查",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "保证被持久化的WASM路径存在、可读且长度匹配，冷启动仍能加载。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅元数据持久化前改为READ_ONLY打开后stat(fd).isFile/size并关闭；保存在性/可读性/普通文件/长度检查、原子写入、同步事务与回滚。导入和冷启动继续读真实WASM，不增加异步并发窗口。"
      },
      "modificationBasisBrowse": {
        "object": "BrowsePage.RuntimeSourceListItems的ForEach身份与末项分隔线",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "index只用于末项分隔线，key本意用源身份/版本/显示名保留行。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅改运行时源组：末项ID由Computed字符串维护，itemGenerator移除不再使用的index；保实际源身份/版本/显示名key及全部HDS行、排序、动作、尺寸和私库。"
      },
      "modificationBasisActions": {
        "object": "SourceIndexService.SourcePackageInstallTasks与SourcePackageManagerPage的单行动作状态投影",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "每源按钮显示运行/等待且只禁用本源；队列仍是进程内唯一安装事务owner。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "保留共享队列/去重/串行/全部更新与聚合活动行；仅增加稳定的按sourceId可观察状态投影，使行按钮不再读取全局数组。原生HDS、文字、样式、排序、图标及操作保持。"
      },
      "modificationBasisLanguage": {
        "object": "LanguageState应用内存键；SourcePackageManagerPage两处已安装名称排序",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "跨页共享当前语言，按当前界面语言显示名称并保持zh-CN比较/ID兜底；持久偏好实际由LanguageSettings的app.language负责，AppStorageV2键不落盘。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅将LanguageState内存键改合法唯一koma_language；两处排序读取页面已有locale和同一DTO名称。保持比较器、排列、对象身份、偏好键/值、语言跟随、资源管理器及所有UI；不改其他状态键/文件校验/注册事务。",
        "references": [
          "https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-appstoragev2",
          "https://github.com/openharmony/arkui_ace_engine/blob/master/frameworks/bridge/declarative_frontend/state_mgmt/src/lib/sdk/v2_persistence.ts"
        ]
      },
      "modificationBasisCpuProbe": {
        "object": "SourcePackageManagerPage.installIndexEntry的临时只读CPU采样",
        "originalReason": "原47/74ms主线程长回调缺JS细栈，前摘要/DTO探针仅6/4ms不足归因。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "只在SOC001这次普通首装前后配对调用官方hidebug.startJsCpuProfiling/stopJsCpuProfiling，写具名诊断文件；不改UI/请求/队列/校验/事务。采样会带来开销，不冒AB/FPS；临时代码与设备包均在结果后恢复。",
        "reference": "https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-hidebug"
      },
      "modificationBasisCpuBatch": {
        "object": "SourceRuntimeRegistry.persistEntriesToAppLocalMetadata的重复ArkTS→FileKit文件检查；NativeSourceRuntime只读批量助手",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "每份持久化WASM必须存在、可读、为普通文件且长度匹配；任何失败不得写元数据，写失败仍交原事务回滚。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅把成功路径所有文件的READ_ONLY fd/fstat/长度核对放进一次同步Native调用，每个文件仍实际检查并关闭fd，不缓存文件状态、不读整WASM、不添加await。任一不符回到原逐项检查，原缺路径/缺文件/长度错误及不可读/目录抛异常和回滚保持；元数据JSON、写入/fsync/原子替换、当前注册顺序完全不动。Native函数不暴露为WASM host import。"
      },
      "modificationBasisCurrentCpuProbe": {
        "object": "SourcePackageManagerPage.installIndexEntry临时我是馬克专用CPU采样",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅未装com.immark.pixnet.zh-hant.koma一次普通安装前后调用官方startJsCpuProfiling/stopJsCpuProfiling；不改UI/网络/事务。采样会带开销，不冒严格AB或FPS；完成后精确撤2060B补丁并覆盖正式8577441B包。"
      },
      "modificationBasisImportHash": {
        "object": "SourcePackageImporter.importLocalSourceArchive的导入WASM摘要计算；独立SourcePackageHashWorker",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "完整实际WASM SHA256、声明hash（可空）及准确size/maxSize必须全部验证；恢复原同步合同保持，未验证字节不得发布到registry。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅普通异步导入将同一SHA256算法放入独立仅Crypto依赖的Concurrent模块，传副本避免输入detach，await完成后仍走原hash/size/max和checksum_mismatch；worker异常交原外层清理，不回退主线程。同步备份恢复调用保持同步，注册/metadata原子写/回滚/UI不改。"
      },
      "modificationBasisRuntimeStateKey": {
        "object": "SourceRuntimeState的AppStorageV2进程内键",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "Browse/SourceBrowse与写入者共享一个进程内revision，安装/启停/移除后使消费者刷新；不落盘。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅改为唯一合法koma_source_runtime_revision，所有生产者/消费者仍共用同一入口，不改revision算法/触发/源数据/偏好/UI。构建后237普通源启停并恢复、根Browse消费者及三域完整数据验证；不把单项警告消除冒56ms根因。"
      },
      "diagnosticBasisPersistPhases": {
        "object": "SourceRuntimeRegistry.persistEntriesToAppLocalMetadata临时数字阶段计时",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅在原调用顺序间读取Date.now，并在完成后写一条固定数字诊断；不加await/cache、不删fd/fstat、完整metadata/JSON、fsync/readback/rename或回滚，保护原样式。只对既有无origin/无网页会话Happy做一次停用/恢复，四域读回；诊断补丁精确撤回并装回8589011B正式包后才离开此分支。"
      },
      "modificationBasisCurrentLocalCpuProbe": {
        "object": "SourcePackageManagerPage.importPackage临时CPU采样，仅一次已装漫画160015正常同版本本地导入",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "只在普通picker返回已选URI之后startJsCpuProfiling，原import/校验/事务/刷新完成后finally stop；不改UI/响应/校验/队列，不清数据不装新源。仅新profile文件自有临时产物，完成精确撤补丁并装回8581941B正式包。当前为正常同版本更新路径，不当首次首装或严格AB/FPS。"
      },
      "continuationGate": {
        "checkedAt": "2026-10-26T19:34:00+00:00",
        "owner": "Root",
        "condition": "列表冗余文案当前纠正已197普通Native并push，精确CI归SOURCE_INDEX_CACHE_REVALIDATE；本项缓存/热读普通manager原具名交付保持，原59.319ms/全部性能未证全闭，不以文案修复扩大性能结论。"
      },
      "reportedAgeAtAudit": "至少1天22小时28分14秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 167294,
      "browseProjectionRepair": {
        "object": "BrowsePage.enabledRuntimeSources逐源名称派生，仅16行实现差异。",
        "history": "Root已追0de9d3dc、270e9d83及当前调用方，参照既有manager逐源一次解析。",
        "allowedDifference": "只将排序比较内重复resolveSourceLocalizedName/元数据normalize改为同次计算逐源一次加局部Map，不改样式控件。",
        "preserved": "@Computed locale依赖、compareSourceNames、同名ID tie、enabled过滤、DTO身份和原数组保持。",
        "evidenceBoundary": "真实getter旧三源6!=3→一次、四locale/身份/输入与原54suite通过；513–518普通Native/29App节点/七域保持，不扩大59ms安装性能结论。"
      },
      "stage": "具名范围已交付"
    },
    {
      "id": "MANGA_DETAIL_REFRESH_BACKGROUND",
      "title": "详情下拉刷新顶部露底颜色不一致",
      "priority": "P1（源性能后接续的UI缺陷）",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "MANGA_DETAIL_PULL_REFRESH",
        "LIST_EDGE_SCROLL_FEEL"
      ],
      "kind": "accepted",
      "status": "197原详情同手势168帧已审，露出区域同色",
      "result": "仅固定外Stack补BG_SUB。527沿114同一猎行者458章详情/同手势连续录像168帧已亲审，最大下拉/回弹/终态背景同色，原内容保持；528原第一话15/16与读态保持。",
      "evidencePoints": [],
      "remainingActions": [
        "本次浅色普通详情具名范围冻结；未以此扩认深色/全部源/全部刷新失败状态。其他队列继续。"
      ],
      "remaining": "本次浅色普通详情具名范围冻结；未以此扩认深色/全部源/全部刷新失败状态。其他队列继续。",
      "boundaries": [
        "用户本次明确批准该露出区域同色修正；此许可不扩大为布局/刷新组件改造。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类反馈，无可信精确UTC首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:12:10.554202+00:00",
      "firstEvidenceAtSource": "本次记录时刻，不冒充用户首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-24T07:39:41.166476+00:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "firstHandlingAtSource": "本轮已开始只读调查，但精确起点未单独记录；不从登记时刻反推实际开始。"
    },
    {
      "id": "REFRESH_RETAIN_EXISTING_CONTENT",
      "title": "刷新与首次加载分离，保已有内容与图标",
      "priority": "P1（当前源闪烁主线关联要求）",
      "owner": "Root：原人类触发的具名范围已交付，保其它源/失败分支边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_PACKAGE_ICON_INVALIDATION",
        "SOURCE_INDEX_PROGRESSIVE",
        "MANGA_DETAIL_PULL_REFRESH"
      ],
      "kind": "accepted",
      "status": "刷新开始清空已有内容的原触发已具名覆盖；自然失败footer未外推",
      "result": "保留576 SourceBrowse内普通同查询结果。新增353独立SourceSearch包子query斗破下拉完整109帧/4表经Root全部顺序亲审，七个结果与封面持续保持、query不变、正常收回。354实际繁体结果鬥破蒼穹仍在，普通Back→源包管理→服务→设置→原书架断言通过；未点作品或新增query。350繁简误等为脚本失败并保原件。",
      "evidencePoints": [
        "直接产物索引：search-refresh-retention-before.txt"
      ],
      "remainingActions": [
        "原已有内容刷新先清空/全屏加载触发已由SourceBrowse576和独立SourceSearch353/354完整普通路径覆盖，无当前重跑待办。自然失败保内容/footer/第一页重试仍未外推；不声称全App或所有失败已验，不造网络故障补矩阵。"
      ],
      "remaining": "原已有内容刷新先清空/全屏加载触发已由SourceBrowse576和独立SourceSearch353/354完整普通路径覆盖，无当前重跑待办。自然失败保内容/footer/第一页重试仍未外推；不声称全App或所有失败已验，不造网络故障补矩阵。",
      "boundaries": [
        "当前源图标闪烁/安装阻塞仍主线，新反馈不替换旧顺序。",
        "不得把单处源码线索或用户观察写为全App已查/已复现，保原内容与用户阅读数据。"
      ],
      "reportedAt": "2026-10-23T21:15:01.468Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 944920363 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:16:09.194667+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:55:15+00:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "modificationBasis": {
        "object": "BrowseViewModel.runSearch/clearSearch/retrySearchPage与SourceSearchPage现有footer调用",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "初始搜索失败展示空错误，分页失败保已成功行并重试原页；当前实现未分已有同查询的重新搜索失败。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "只对同sourceId/版本/字节数、同registry entry、同settings revision、同query和filters的已成功结果保留；失败仍走已有footer，重试明确回第一页。保留原safe错误原因到现有footer文字，尺寸/排布/字号/颜色保持，未给消息的Browse footer保持原样。新查询/换源/换包/设置/筛选变化不继承旧归属。保UI/翻译/排序/请求次数和挑战守卫，无失败注入到设备。"
      },
      "continuationGate": {
        "checkedAt": "2026-10-25T19:58:27.537366+00:00",
        "owner": "Root",
        "condition": "普通独立SourceSearch分支已实际补验，不再标成未执行或重跑；只有自然失败footer/挑战缺适用样本，不用成功结果扩大。"
      },
      "reportedAgeAtAudit": "至少1天22小时18分50秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 166730
    },
    {
      "id": "LIBRARY_READING_PROGRESS_SEMANTICS",
      "title": "误开末话后书架进度长期显示100%",
      "priority": "P1（阅读进度语义正确性）",
      "owner": "Root：原200重复章ID样本禁止操作，237及最新197合法库均无自然同类",
      "dependencies": [],
      "relatedItems": [
        "FIRST_CHAPTER_SELECTION",
        "SHARED_ROUTE"
      ],
      "kind": "done",
      "status": "真实原始快照与197画面具名核对完成",
      "result": "原真实重复章节快照经当前生产读取和书架投影均得到596未读；197书架角标与生产投影一致，故障按具名范围关闭。",
      "evidencePoints": [
        "直接产物索引：197394/library-after.json；442/library-after.json；manhuagui-network-phase-review/current-queue-library-sample.json",
        "本轮生产store+投影7项真实逻辑回归通过；旧脚本仅补SourceRuntimeAppRegistry默认undefined及SourceTextPageDescriptor依赖，未改期望。624/600/4→596为合成回归，不冒200真机。",
        "原device200/chapter-failure/original-state-001/library.json与reader.json的真实624行/600ID/4已读，实际执行当前PersistentReaderSessionStore与createLibraryViewModelFromComics均596；旧完整性判断会undefined，输入内存及文件逐字保持。回执 .hvigor/outputs/user-flow-audit/library-progress-real-snapshot-replay.json。197 71 library-after/reader-after同生产投影与88屏幕对照，Blue 4/xkcd 669/Nemo 0一致；100%为继续阅读当前章、封面4仍未读。此真实快照不同于此前合成回归；未触200。"
      ],
      "remainingActions": [],
      "remaining": "",
      "boundaries": [
        "源图标本行瞬空等独立未闭项保留；已验安装性能具名范围不重跑，也不因本项丢弃其他反馈。",
        "不得把单处源码线索或用户观察写为全App已查/已复现，保原内容与用户阅读数据。",
        "最新答复明确选择左上未读角标，取代原多章已读N/M文案；不将继续阅读章内百分比一并重做。",
        "没有新200设备UI回验，未触碰200或注入设备数据，不外推全设备。"
      ],
      "reportedAt": "2026-10-23T21:15:30.893Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 945068377 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:16:09.194667+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-29T20:54:22+08:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "firstHandlingAtSource": "本轮已开始只读调查，但精确起点未单独记录；不从登记时刻反推实际开始。",
      "continuationGate": {
        "checkedAt": "2026-10-26T04:56:21+00:00",
        "owner": "Root",
        "condition": "原200真实624行/600ID样本禁止操作；237无同类，最新442/library-after.json离线76本/14902章逐本非空chapter.id无重复，回执current-queue-library-sample.json。本轮只再次排除自然同类，不获未读计数实机通过；待合法现存适用样本，不触200/不注入，原项open。"
      },
      "reportedAgeAtAudit": "至少1天22小时18分21秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 166701,
      "stage": "具名范围已交付"
    },
    {
      "id": "BAOZIMH_DAFENG_PAGE_LOAD_FAILURE",
      "title": "包子《大奉打更人》正文无法加载",
      "priority": "P1（具名正文不可读）",
      "owner": "source_terra：源故障及237具名路径；Root：App/Reader发版故障与交付",
      "dependencies": [],
      "relatedItems": [
        "BAOZIMH_BROWSE_FAILURE",
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "done",
      "status": "237自然未缓存正文路径具名通过",
      "result": "修复已交付；237同一作品自然未缓存第9页六图成功并返回第3页，按具名范围关闭。",
      "evidencePoints": [
        "直接产物索引：open-001-failure-002/library.json；koma-log-20261025-053239.txt；failure.png；failure.json；baozi-image-worker-cache197-session-653/cache-coverage.json；page9-original-observed.png；original-page3-restored.png",
        "96a2123已推及精确CI成功；237同001自然冷页9六图HTTP200并返回3页。依据用户本轮“验证过了就过了，不要总是想要具体设备复测”，不将原机复测设为关闭门槛。"
      ],
      "remainingActions": [],
      "remaining": "",
      "boundaries": [
        "允许差异仅source图片选路与Host请求方法；保ID/章节/页数/进度，Reader布局不动。",
        "不写死rsa、不绕TLS、不新增UI或Cookie权限；五CDN仅按站点声明有界选择，每章一次，不盲目多路下载。",
        "Mac匿名样本不称Native通过，原325失败保留，其他请求method/会话边界保持。",
        "Root错误扩大取日志为界面点击：点击实际进入《预告》1/12而非001；本地前后读态确认当前章改变，书架记录逐字段保持。200租约f76eb5d2已释放；24小时熄屏覆盖仍写入，未获允许不得再操作手机恢复或写回进度。原覆盖值未记录，正常timeout读回120000ms。",
        "原200故障根因未知，未操作200，不外推全部页或设备。"
      ],
      "reportedAt": "2026-10-23T21:17:04.802Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 945450769 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:17:42.386549+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-29T21:01:08+08:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-25T21:56:53+00:00",
        "owner": "Root",
        "condition": "原真实失败样本在200且禁止操作；237可读001不替代原失败恢复。底层2300999原因与真实恢复仍未证，待合法现存适用失败证据，不操作200/重请旧失败或造故障，原缺陷仍open。 此项样本条件不代表整体目标完成；当前设备执行以顶部为准。"
      },
      "reportedAgeAtAudit": "至少1天22小时16分47秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 166607,
      "stage": "具名范围已交付"
    },
    {
      "id": "SOURCE_BROWSE_HOME_STRUCTURE",
      "title": "源浏览分类下拉与首页分区结构待整理",
      "priority": "P2（设计结构调查）",
      "owner": "Root：审查；home_terra：离线源修复；source_terra：237验证",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_FILTERS",
        "BROWSE_HEADER_REFRESH",
        "HAPPYMH_SOURCE_UNAVAILABLE"
      ],
      "kind": "done",
      "status": "重复首页结构具名范围已修复",
      "result": "动漫屋、东立、Komiic及嗨皮的重复首页结构已修正；嗨皮连接失败另行跟踪。",
      "evidencePoints": [
        "直接产物索引：https://www.dm5.cn实际title“动漫屋”",
        "本轮用户直接反馈：动漫屋首页已有热门，独立热门/最近更新tab及首页打开列表重复热门；东立同结构。精确发送时间未知，本次为登记时间；原已验范围与证据保持。",
        "原已验result完整保留：最终签名Release8577441B已明确装237。包子首页/熱門为互斥内容，原生分类菜单在搜索下方，首页/熱門对勾随实际选择切换。熱門36本单一列表，首页不再额外请求默认栏目。正常下拉刷新仍选熱門、旧封面与内容保留；首页地区筛选进入原默认熱門，重置后原内容恢复。 本轮193–194无首页Comic Fury默认热门12本，菜单仅热门/最新，选最新后单一12本且首排实际变化，对勾正确；自然返回原大奉001第6页25%。",
        "原已交付remaining完整保留：e6404c5b543653e2684ef4c5559f683484d64ceb已推master，精确CI40188955447 completed/success；没有新tag或发布。",
        "新定位：dm5 run_get_home拼popular/latest首屏，tongli包装原周榜，并非App同时叠两份内容。home_terra离线候选dm5.23/tongli.6 home=false且not_implemented，Root已审，237待验。",
        "237动漫屋.23：1666热门70、1667仅热门漫画/最新更新无首页/打开列表，1668最新70首项不同；东立.6：1670 Popular20、1671仅Popular/Latest、1672 Latest20首项不同。候选未提交公开。Happymh.7空首页/导航ABI错误已修，1682普通入口仍无法连接，未见选择器；Komiic同热门首屏包装，搜索WIP未隔离尚未修改。本场恢复进行中。",
        "源e6e2eeee3280f4c4a6c03577f38fdf0d71c02cec精确CI40907631439 completed/success；/private/tmp/koma-home-e6-public/contracts.jsonl公开WASM核dm5/tongli home=false、get_home not_implemented及各自热门/最新listing；公开WASM与设备候选不同，合同核验不冒公开实体Native。1683原三源12成员逐字等1652/1673备份，1684六JSON逐字等1639，1685临时包删除、1686 SLEEP/120000，source_terra回报已释租。嗨皮入口未连接、Komiic待修。",
        "Komiic隔离Home候选提交04c9686df3fe9368dfc774cfc911b0c63f0de75f已推，CI40918105665 in_progress；/private/tmp/komiic-home-0.1.11.koma 生产WASM home=false、NI零HTTP，旧新版列表/热门GET合同及合成data等价；未Native或实网通过。",
        "Komiic 04c9686df3fe9368dfc774cfc911b0c63f0de75f精确CI40918105665 completed/success，公开release非draft、index/manifest 0.1.11；公开ZIP 049e95e274ec0b11e1c85b27f7ed269c69ebc4b92eef78085a1567feee3798ea / WASM a67411610232e6ba44b8789453c5c20e9d14ac82a4b589dc6fba37ec7ed4d39c，与隔离候选不同。/private/tmp/komiic-04c-public/contract.json实际公开WASM home=false、get_home not_implemented零HTTP、get_listings popular零HTTP；无新Native或实网列表，不误称公开Native。",
        "本次将嗨皮1682连接失败与首页结构修复分开：结构生产能力/导航已修，连接故障未解决；动漫屋/东立237普通菜单及热门最新具名通过，其他公开合同证据保留。"
      ],
      "remainingActions": [],
      "remaining": "",
      "boundaries": [
        "人类已明确允许所列入口位置与内容组合差异；菜单材质、网格、筛选、搜索及原默认栏目语义保持。",
        "安装残余、包子正文及其他原队列继续保留；不把本项批准扩大为重构根导航或共享阅读器。"
      ],
      "reportedAt": null,
      "reportedDate": null,
      "reportedAtSource": "最新人类质疑，无可信UTC精确首报，留空不猜；原始提出日期亦未核，reportedAt/reportedDate均未知。",
      "firstEvidenceAt": "2026-10-23T21:19:47.404038+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-30T02:40:32+08:00",
      "reportedDateSource": "原始提出日期未核实；此前登记日2026-10-24不是独立首报日期证据，撤回该日期推定。",
      "modificationBasis": {
        "object": "BrowseViewModel.loadBrowseHome/selectBrowseListing与SourceBrowsePage分类入口和内容投影",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "支持源推荐摘要与可分页栏目两种合同；移除独立选择器的具体产品取舍未查明，不能自行取代。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "references": [
          "https://github.com/mihonapp/mihon/blob/main/app/src/main/java/eu/kanade/tachiyomi/ui/browse/source/browse/BrowseSourceScreen.kt"
        ],
        "allowedDifference": "移动分类入口至搜索框下方；仅列源支持的首页/热门/最新/其他栏目并一次只显示所选内容。有首页默认首页，其他保原默认列表；不再首页后拼热门。现有菜单材质、网格和筛选不改。"
      },
      "userDecision": {
        "source": "本会话实际异步答复 call_95fb60c14900499080e9c7ec34d82b91",
        "decision": "采用统一入口和单一内容区",
        "recordedAt": "2026-10-25T10:19:40.067847+00:00",
        "allowedDifference": "移动分类入口至搜索框下方；仅列源支持的首页/热门/最新/其他栏目并一次只显示所选内容。有首页默认首页，其他保原默认列表；不再首页后拼热门。现有菜单材质、网格和筛选不改。"
      },
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-single-content-installed-182",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-popular-selection-183",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-popular-refresh-motion-184",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-filter-home-route-188",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-migration-natural-return-189",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-migration-final-readback-190",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-nohome-preflight-191",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-nohome-comicfury-193",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-nohome-latest-return-194",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-browse237-nohome-final-readback-195"
      ],
      "stage": "具名范围已交付",
      "reopenedAt": "2026-10-29T23:15:21+08:00"
    },
    {
      "id": "MANHUAWU_SOURCE_UNAVAILABLE",
      "title": "漫画屋首页403及原错误状态反馈",
      "priority": "P2（后续处理）",
      "owner": "source_terra：源故障及237具名路径；Root：App/Reader发版故障与交付",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "done",
      "status": "正常验证后列表已恢复并交付",
      "result": "正常完成网页验证后，漫画屋原生热门列表恢复；源码与CI已完成。",
      "evidencePoints": [
        "直接产物索引：koma-log-20261024-120407.txt；405/history-result-receipt.json；228/search-baseline-wasm.json；search-current-http.json；228/search017-wasm-cases.json；manager-after-real-update.png；failure.png；manhuawu017-search197-only-session-507/result.json；native-source-search-results.png；recovery-773/runtime.log/reader-terminal.png；recovery-773/reader-records-review.json",
        "run773原证显示当前403进入challenge导航，排除该次错误状态丢失反例；不称验证完成或403已修。",
        "原已验结果完整保留：770–775漫画屋017单次元尊搜索→详情→最早第1话 周家圣龙（上）→真实首图1/10已亲审，search/detail/chapters/get_pages均200；新增元尊外旧91progress/8sourceHistory/151chapters及remoteHistory原对象/顺序全同。首页get_manga_list仍403挑战，当前成功不追认旧460 timeout原因；不外推完整叙事/十页或全CF，数据/系统/原Library已恢复。",
        "固定参考Firefox150身份一次GET仍403，证据 /private/tmp/manhuawu-ref150-once.headers 与 /private/tmp/manhuawu-ref150-once.body；仅排该身份小修假设，未改UA、不称根因已解。",
        "source_terra准备237漫画屋018候选一条首页路径：旧017未传因果ID，Host仅causal-selected才借原UA；新接线差异不同于旧无诊断失败，结果尚未取得。",
        "017→018因果ID候选接selectedByChallengeId，受控WASM核挑战/普通错误/旧Host及保存真实详情等价。237第二场021首页HTTP403出现CF真人复选框，022点击一次并等30秒仍要求真人验证，未观察列表；024原017四成员及六域逐字恢复，025清本轮临时文件、SLEEP/120000无override，lease054f5353 released，HAP未更换。两源接线暂存待审、未公开。证据 source-web-session-concurrent/manhuawu-cause-resume-*。",
        "两源接线f624c85389b528d3304beb65ca9a440c169e46f2已推，精确CI41024411724 success，release428782014同SHA非draft；漫画屋018/Simply012正式包公开，摘要/manifest/index及Simply精确origin已核，公开WASM与本地不同，两个正式WASM既有四合同执行通过。稳定索引 .hvigor/outputs/user-flow-audit/source-settings-repair/source-challenge-cause-published-f624c85/evidence.json；仅接线交付，可用性仍open，不冒公开实体Native。",
        "当前018热门、最新、搜索及selector与固定949及上游dbf6c05对照；参考latest入口 /category/order/addtime/page/1 按原121身份且不带Referer/Origin单次读取返回403、cf-mitigated challenge、5629字节。该结果不能替代热门入口或证明全部路由永久不可用。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-latest-20261030/。",
        "197公开018普通首页进入验证，真实复选框单击一次后20秒仍停验证页；限定日志main 403、challengeHost 400/401，无Turnstile六位码，不能将401判为根因。系统浏览器021显示漫画屋页面“更新/分类”，但请求站根 /，不同于Native热门 /category/order/hits/page/1，不能当同路径通过。该场原017四成员、六JSON、诊断偏好与电源均恢复，租约c90abe7a已释放；随后新租约仅作同热门路径浏览器对照，不重装App。证据 diagnostics/manhuawu-browser197-result-20261030-021/layout.json 及该场回执。",
        "197浏览器024提交与Native相同热门路径，025可见漫画大全及作品链接、无验证文字；最终完整URL、重定向和HTTP状态未观测，不代表Native成功。026恢复SLEEP/120000及原Override10000，lease27ad1054 released；前场lease c90abe7a亦released，原017四成员、六域及诊断偏好恢复，原38d包未换。稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-validation197-20261030/evidence.json。仅漫画屋及 https://www.mhua5.com 验证窗口使用引擎默认身份的候选尚未应用或构建，已询问用户采用决定；不将UA认定为根因。候选依据 .hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-engine-identity-candidate-20261030/。",
        "用户最新明确采用并验证候选；仅com.manhuawu.koma及https://www.mhua5.com验证窗口和完成后的同站UA使用默认Web引擎身份，其他源、UI和Cookie权限保持。此具体决定取代原UA不变边界，旧记录保留；source_terra在237执行，尚未验证完成。",
        "237限定默认UA候选取得clearance并自动回流，但op6实际cookieState present、clearance present、uaSource webview仍403，首页未修好。原Host27f及原MHW源已恢复，Noy019及本次MHW会话保留，电源恢复释租；代码WIP待Root审交付。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-engine-identity-candidate-20261030/native237-evidence.json。",
        "原边界（用户具体采用漫画屋UA例外前）：保持原Cookie/UA/网络/端点/超时和目录/章节身份，不为取证重复已验查询/升级或造挑战；当前产品操作服从人类当前沟通指令。",
        "限定身份代码2e1fa9af已推master，后续精确CI41084355441成功；237候选009 op6已取得clearance但仍403，access_signal=challenge_required。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-engine-identity-candidate-20261030/native237-evidence.json；不称首页已修复。",
        "真实top/hot页面200但hot仅99条且无分页，分类官方index.php路径403；不能用它替代旧完整hits/addtime合同。",
        "正式候选9424b350本地编译成功、固定配方已接，CI未跑。237日志015：op3无会话403、op6自动回流仍403；正常网页验证完成后op10同源session及clearance、实际WebUA返回200/49926字符。complete-013原生layout显示热门30本及斗破苍穹、元尊等；013仅layout无原生截图，网页011有截图，不冒原生图片亲审或自动流程全过。当前lease f4497748，恢复尚在进行。",
        "Host ad533787e00fa637c19014d99db1ea0964e60361已推，精确CI41111246354 completed/success；正常网页验证后原GET200/49926字符，013原生layout显示热门30本，015原日志已亲读。自动op6仍403；013无原生截图，仅具名布局语义，不扩为无需验证或全站通过。023原C6安装成功、两源八成员及六域逐字相等，024 SLEEP/120000无override、候选清理，lease f4497748 released；Root复核原件中。未新发App、tag或AGC。https://github.com/honjow/Koma/actions/runs/41111246354"
      ],
      "remainingActions": [],
      "remaining": "",
      "boundaries": [
        "017搜索分页修复已交付；770–775元尊搜索→最早第1话→首图1/10具名，非完整叙事/全10页或全CF。首页get_manga_list仍403挑战，当前页表成功不追认旧460 timeout原因。",
        "仅com.manhuawu.koma在https://www.mhua5.com验证窗口使用引擎默认UA，完成后本站请求沿该UA；Cookie、网络、端点、超时及目录/章节身份保持，不为取证重复已验查询或造挑战。",
        "旧460超时原因未知，原失败证据保留，不要求重现旧原因。"
      ],
      "reportedAt": "2026-10-23T21:26:00.332Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 946200498 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:26:41.632173+00:00",
      "firstEvidenceAtSource": "本次登记，非用户首报精确时间。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-31T03:11:15+08:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "modificationBasis": {
        "object": "SourceRuntimeHttpTransport HTTP envelope与漫画屋fetch/单域会话声明",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "不向源暴露Cookie/任意响应头，不把全部403认挑战",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅将精确标准响应头转可选accessSignal常量；保status/body/原错误；源仅对受支持状态消费并声明www.mhua5.com，保现有半模态/UI/权限边界；用户另已明确采用仅漫画屋及该origin验证窗口使用引擎默认UA，并在完成后本站请求沿该UA的例外，其他源和权限保持"
      },
      "continuationGate": {
        "checkedAt": "2026-10-26T19:34:00+00:00",
        "owner": "Root",
        "condition": "Root精确复核新增元尊外原91progress/8sourceHistory/151chapters；当前页表200/首图仅本次具名，不等旧460根因或首页CF解决。原搜索/目录修复不重开、不重复查询取样；保网络/UA/Cookie/端点/超时，未知仍调查。"
      },
      "reportedAgeAtAudit": "至少1天22小时7分51秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 166071,
      "stage": "具名范围已交付"
    },
    {
      "id": "MANHUAGUI_RUNTIME_TIMEOUT",
      "title": "漫画柜0.1.6列表请求超时",
      "priority": "P1（具名源运行失败）",
      "owner": "Root：当前成功及历史只读查询已核；本机未取得旧失败阶段记录，原项仍open",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS",
        "FIRST_CHAPTER_SELECTION"
      ],
      "kind": "done",
      "status": "普通列表超时已回验恢复",
      "result": "197漫画柜0.1.6普通入口显示42本及真实封面，原阅读数据和设备状态已恢复。",
      "evidencePoints": [
        "直接产物索引：.hvigor/outputs/user-flow-audit/manhuagui-network-phase-review；.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manhuagui-netphase197-single-browse-399。取证当时400/401返回恢复待回执；koma-log-20261024-092500.txt；399/network-result-receipt.json；401/restoration-receipt.json；405/history-result-receipt.json"
      ],
      "remainingActions": [
        "本次具名普通入口回验完成。"
      ],
      "remaining": "本次原列表超时反馈的具名普通入口已回验恢复；旧失败具体原因未知，不由本次成功倒推。",
      "boundaries": [
        "保当前源UI/安装性能主线；旧证据不冒本次复现，不盲重试或清缓存。"
      ],
      "reportedAt": "2026-10-23T21:27:27.072Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 947813847 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:28:34.289082+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-29T15:18:53+08:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-26T19:28:10+00:00",
        "owner": "Root",
        "condition": "399成功主trace无HttpRequest细分，402–405官方历史事件通道已实际核：本项24日10:09:56四分钟窗及同故障整日/成功事件对照均无返回记录，未得到可回溯旧失败阶段；不能断言事件从未产生、设备编译同源码或空输出原因/旧网络根因。405五域/timeout保持、系统锁屏Focus16、租约已release，无活设备操作。不盲重试、无新取证目的不重复请求；若出现合法新阶段证据再针对原项续接，保请求栈/UA/网络，原项仍open。"
      },
      "reportedAgeAtAudit": "至少1天22小时6分24秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 165984,
      "stage": "具名普通入口已完成",
      "evidence": [
        "原过程及旧原因边界：399当前197漫画柜016正常get_manga_list成功42本，HTTP200/27920chars及成功请求阶段数据具名，400/401恢复闭环；旧timeout具体阶段/根因未知，成功不倒证旧失败。原超时原因尚未查明，原项仍未关闭。；399当前正常016成功及400/401恢复保其具名范围；402–405历史故障事件只读查询四次均空，未获得旧失败阶段记录，不解释空输出原因或旧超时。待合法新阶段证据再针对原项续接，不盲重试、无新取证目的不重复请求，保请求栈/UA/网络。"
      ]
    },
    {
      "id": "SOURCE_BROWSE_ALWAYS_WEB_ENTRY",
      "title": "源浏览菜单常驻使用WebView打开",
      "priority": "P1（明确授权的失败恢复入口）",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_WEB_SESSION",
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "accepted",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "result": "源62a1d185精确CI40079042677成功，08:43:50Z公开非draft/pre，原latest85条/MH1600.1.3。553唯一普通远端更新成功；554源85→85仅MH160变且原顺序/书库/reader保持。556两原网页MenuItem均enabled/clickable，557实际WebView已打开；558只有站点标题/加载指示，未证明正文可见。",
      "evidencePoints": [],
      "remainingActions": [
        "常驻合法站点入口具名闭环；白屏/跳转循环及漫画160搜索404归SOURCE_WEB_SESSION，不将入口可达冒网站正文可用。"
      ],
      "remaining": "常驻合法站点入口具名闭环；白屏/跳转循环及漫画160搜索404归SOURCE_WEB_SESSION，不将入口可达冒网站正文可用。",
      "boundaries": [
        "常驻入口不能替代自动CF挑战流程，现有自动验证/重试入口必须保留。",
        "只按当前源合法站点打开，不猜任意URL，不因列表加载失败丢入口。"
      ],
      "reportedAt": "2026-10-23T21:27:27.072Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 947813847 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:28:34.289082+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": "2026-10-24T00:55:38.030011+00:00",
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "modificationBasis": {
        "object": "sources/mh160/src/lib.rs 列表与详情url字段",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "App不从不透明作品ID猜网站地址，未提供时不显示网页动作。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "源仅返回其现有/kanmanhua/<validated slug>/公开作品URL，供既有网页动作消费。ID、章节顺序/metadata、图标、请求UA和网络路径保持；不借URL补丁猜季或调图。"
      },
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "常驻入口/源URL/website符号已交付；当前HDS溢出菜单不绘图标，不自造菜单验图标；网页白页属独立会话条件，不重请旧失败。"
      },
      "reportedAgeAtAudit": "至少1天22小时6分24秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 165984
    },
    {
      "id": "MANXIAOSI_SETTINGS_VALIDATION_FAILURE",
      "title": "漫小肆打开设置提示设置验证失败",
      "priority": "P1（具名源设置能力/运行失败）",
      "owner": "Root：原人类具名范围已交付，保未外推边界",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_EMPTY_SETTINGS_ENTRY",
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "accepted",
      "status": "原人类具名范围已交付并有精确CI；未外推边界保留",
      "result": "311漫小肆manager无无效设置入口且与309三域同。fixture误判仅证Host summary/日志误报，Manager和Store均读response.ok，不能据此归因原菜单失败。",
      "evidencePoints": [],
      "remainingActions": [
        "本源无效入口/验证失败触发已具名收束；其它源设置失败按真实响应另查，不以其保本源无限open或盲重试。"
      ],
      "remaining": "本源无效入口/验证失败触发已具名收束；其它源设置失败按真实响应另查，不以其保本源无限open或盲重试。",
      "boundaries": [
        "SOURCE_PACKAGE_ICON_INVALIDATION/INSTALL_UI_STALL当前主线保持，新反馈不替换旧队列。",
        "不复活旧空源验收，不以验证失败推断无设置，不盲重试/清用户数据。"
      ],
      "reportedAt": "2026-10-23T21:28:58.161Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 947873278 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:29:33.094146+00:00",
      "firstEvidenceAtSource": "本次登记，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:46:33+00:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-25T19:11:53.603541+00:00",
        "owner": "Root",
        "condition": "无效入口及Host误报具名修复冻结；其他设置失败待真实响应，不以not_supported推断或重放空源验收。"
      },
      "reportedAgeAtAudit": "至少1天22小时4分53秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 165893
    },
    {
      "id": "SOURCE_INDEX_CACHE_REVALIDATE",
      "title": "源管理先显示持久索引缓存并后台更新",
      "priority": "P1（明确授权的初载/刷新体验）",
      "owner": "Root：列表78f精确CI40456280638成功/普通manager交付完成，原同类发现未改边界保持",
      "dependencies": [],
      "relatedItems": [
        "REFRESH_RETAIN_EXISTING_CONTENT",
        "SOURCE_INDEX_PROGRESSIVE",
        "SOURCE_PACKAGE_ICON_INVALIDATION"
      ],
      "kind": "accepted",
      "status": "列表重复文案纠正已push/精确CI成功与197普通验证闭环，无该批等待",
      "result": "App78f008d246d307695a12ca101c3e3dfdadee65ab已commit/push且精确CI40456280638 completed/success，公共row meta重复incomplete附文/Computed删除；正常行本来无latest/unknown，不写成新删除。197983安装18910591，manager-clean-result与manager-normal-range-result errors=[]，clean-manager-top/next/normal-range Root亲审：正常已安装区仅原版本语言、可更新区原按钮保持，内部partial/地址失败保持。985对979六非Registry字节同、85 IDs/order/enabled及其它84DTO同，仅Bz .8预期升级；986系统120000无Override/44636496释租。",
      "evidencePoints": [
        "直接产物索引：269/partial-check-existing-method-review.json"
      ],
      "remainingActions": [
        "78f列表本批push/精确CI40456280638成功及197普通manager/恢复完成，无工程交付等待，不重跑partial或造故障。另三处重复信息仅实际审查发现未改，不编总数/擅改其他界面；当前逐行重复文案决定已取代旧决定，版本语言/update按钮/内部partial地址失败保持。"
      ],
      "remaining": "78f列表本批push/精确CI40456280638成功及197普通manager/恢复完成，无工程交付等待，不重跑partial或造故障。另三处重复信息仅实际审查发现未改，不编总数/擅改其他界面；当前逐行重复文案决定已取代旧决定，版本语言/update按钮/内部partial地址失败保持。",
      "boundaries": [
        "当前profile普通重入缓存先显已实现且具名运动成立；新缓存项不覆盖其余缺陷，后台失败/换库/cold仍未验。",
        "缓存身份与后台过期回调须守当前索引，未安装/可更新状态仍按真实安装版本计算。",
        "当前人类纠正取代旧逐行未能确认文案决定：移除公共row meta重复状态，保版本/语言、真实update按钮及内部partial/原地址失败。正常行原本无latest/unknown，不虚构新移除；未授权额外界面变化，不改URL/网络/UA或清缓存造失败。"
      ],
      "reportedAt": "2026-10-23T21:31:23.640Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 950683907 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:33:52.591153+00:00",
      "firstEvidenceAtSource": "本次登记，非用户首报精确时刻。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-25T21:29:51+00:00",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "continuationGate": {
        "checkedAt": "2026-10-25T21:00:16.188000+00:00",
        "owner": "Root",
        "condition": "78f列表本批push/精确CI40456280638成功及197普通manager/恢复完成，无工程交付等待，不重跑partial或造故障。另三处重复信息仅实际审查发现未改，不编总数/擅改其他界面；当前逐行重复文案决定已取代旧决定，版本语言/update按钮/内部partial地址失败保持。"
      },
      "proposalReview": {
        "object": "checkInstalledUpdates的部分成功状态、原检查更新副标题及现有保存地址行",
        "history": "旧逐行未能确认的采用决定被当前人类纠正取代，不作为现允许差异。",
        "withdrawn": "逐源“更新：未能确认”不再采用；正常行本来没有latest/unknown，不能记成新删除。",
        "proposed": "删公共row meta incomplete附文及两Computed投影，保版本/语言/真实update按钮，内部partial与地址失败保持。",
        "authorization": "当前可见人类明确反对逐行重复状态并要求Root承担基本判断，取代旧逐行文案决定；不扩大为改其他未核界面。 当前纠正无精确原始时间，不沿用旧采用决定的登记时刻。",
        "approvedDifference": "仅取消逐源重复“更新：未能确认”，partial摘要/真实更新动作/原地址失败保持；未核同类不编总数，不新增提示条按钮。",
        "approvalRecordedAt": null
      },
      "reportedAgeAtAudit": "至少1天22小时2分28秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 165748
    },
    {
      "id": "TONGLI_CHAPTERS_SETTINGS_FAILURE",
      "title": "東立任意作品章节加载失败、设置提示验证失败",
      "priority": "P1",
      "kind": "done",
      "status": "目录及设置契约修复已交付，地区限制正确映射",
      "owner": "source_terra：源故障及237具名路径；Root：App/Reader发版故障与交付",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS",
        "MANXIAOSI_SETTINGS_VALIDATION_FAILURE"
      ],
      "result": "东立目录与设置契约已修复、API地区限制已正确映射；首页空白亦已具名修复。",
      "remaining": "",
      "reportedAt": "2026-10-24T11:59:14.391Z",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 1302381904 读取原文，不是登记/处理/取证时间。",
      "firstHandlingAt": "2026-10-24T12:02:09.354493+00:00",
      "closedAt": "2026-10-29T21:38:18+08:00",
      "evidencePoints": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/tongli-home-fixed-263/screen.png",
        "012目录4章及无设置契约修复，013准确映射官方API3166地区限制，015首页空白237具名修复均已交付；原站授权及黑页证据不作额外设备重测门槛。"
      ],
      "remainingActions": [],
      "boundaries": [
        "本次只接受東立认证/目录/无设置契约/准确地区原因；正文未通过，其他作品和授权地区未扩大。",
        "未更改网络/账户或绕过站点地区限制；197/237原阅读数据保持，私库PARKED_USER不复活。",
        "官网明确台湾授权，237同网首话黑页；原因不能强归API 3166，正文未验，不外推其他作品或地区。"
      ],
      "modificationBasis": {
        "object": "東立认证回退、无设置响应及明确3166错误；App既有SourceRuntimeError受控原因映射",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "仅用已有公开认证分支；不能解锁付费或地区授权，未知服务端正文不得泄露到UI/诊断。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "恢复既有400备用分支、返回not_supported；只认HTTP400+Succeeded=false+Errors.Code3166，源发固定region_restricted原因，App固定本地化并保HTTP优先级/未知脱敏。网址/身份/原认证key/图标/布局/网络与账户保持。"
      },
      "continuationGate": {
        "checkedAt": "2026-10-25T21:56:53+00:00",
        "owner": "Root",
        "condition": "原生3166地区限制已证，同机同网官网首话黑页无正文是另一有限观察；当前合法网络不能完成正文验收。待合法可读环境/真实新样本，不自行改账户/地区/网络或重放失败，原缺陷仍open。 此项样本条件不代表整体目标完成；当前设备执行以顶部为准。"
      },
      "reportedDate": "2026-10-24",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "reportedAgeAtAudit": "至少1天7小时34分37秒",
      "reportedAgeSecondsAtAudit": null,
      "reportedAtScope": "earliest_located_in_current_window_not_proven_global_first",
      "knownFeedbackAgeSecondsAtAudit": 113677,
      "stage": "实现故障具名范围已交付"
    },
    {
      "id": "PROGRESS_TIMELINE_THEME",
      "title": "进度页工作时间线与自动明暗主题",
      "kind": "done",
      "status": "简洁时间线与三种主题已在现有页面验证",
      "priority": "P2（工具呈现，不丢产品主线）",
      "owner": "Root",
      "dependencies": [],
      "reportedAt": null,
      "reportedAtSource": "未核原始消息时间；最早登记时间由firstEvidenceAt保留，不冒充原始提出时间。",
      "firstHandlingAt": "2026-10-24T20:05:28.004158+00:00",
      "closedAt": "2026-10-24T20:11:44.260077+00:00",
      "result": "当前卡片内一行折叠入口，展开竖线连接实际工作事件与原检查点。原生外观选择器提供自动/浅色/深色；选择保存在本机，深色刷新后仍保持；自动由prefers-color-scheme跟随系统。",
      "remaining": "本次页面范围完成；后续实际工作节点继续维护在同一工作单timeline字段，不补造历史时间或工时。",
      "evidence": [
        ".hvigor/outputs/progress-timeline-theme/koma-progress-timeline-light.png",
        ".hvigor/outputs/progress-timeline-theme/koma-progress-timeline-dark.png"
      ],
      "firstEvidenceAt": "2026-10-24T20:05:28.004158+00:00"
    },
    {
      "id": "NEXTE_READER_FEATURE_MIGRATION",
      "title": "后续迁移NextE阅读器超分、去白边与翻译能力",
      "priority": "P2（翻译完整迁移核对）",
      "owner": "Root：漫画翻译完整迁移；Torii试译与Reader具名路径已核，其他提供方真实网络待验",
      "kind": "done",
      "status": "功能迁移及已有具名验收已交付",
      "dependencies": [],
      "relatedItems": [],
      "result": "配置和Reader消费已接入，Torii试译及预处理具名验证；其他服务真实账户网络未验。",
      "reportedAt": "2026-10-26T13:29:18.490+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第16082行，UserMessage item.id=01a176af-3d99-7333-82d4-eea670ce1107；不排除跨会话更早历史。",
      "firstHandlingAt": "2026-10-26T05:31:40+00:00",
      "closedAt": "2026-10-30T03:12:00+08:00",
      "evidencePoints": [
        "直接产物索引：crop-strong-settings.png；restored-crop-settings.png；result.json；failure.png；model-downloaded-selected-off.png；enhanced-reader-page.png；cold-crop-strong-settings.png；cold-enhancement-active-settings.png；reader-enhancement-ci-detail.json；reader-translation197-session-579/result.json；translation-secure-manifest-cold-English.png；reader-translation197-session-586/result.json；reader-translation-ci-detail.json；top-icon-off-on-review.png；runtime-before-any-flip.log；reader-packed-rgba-before/after-case.log；reader-packed-rgba-build.log；page-index-to-success-evidence.json；semantic-restore-review.json",
        "本轮Release构建日志：/private/tmp/koma-translation-completion-build.log；冻结包：/private/tmp/koma-translation-completion-release.hap，SHA256 bbe9f3d7b204763fdab294ad0deee866c1efff28b95a7e0d73929a43d8a78651，19166717字节，release/debugfalse/0.1.3 code4；尚未安装。",
        "237 Torii两页真实试译及显示：.hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/torii-live-evaluation-result-13/、torii-first-translated-preview-14/、torii-second-translated-preview-15/、torii-second-translated-visible-16/。",
        "237恢复：.hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-original-shelf-restored-18/、translation-power-restored-19/、translation-final-timeout-cleared-20/。",
        "本轮翻译源管理release构建日志：/private/tmp/koma-translation-sources-build.log；新增UI及网络账户路径未装机。",
        "Koma 3bd44ef9b4fded61ea71af19a6ddf8f67e0f33be已推；release构建及既有执行检查通过，CI40784766661进行中。",
        "https://github.com/honjow/Koma/actions/runs/40784766661",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/translation-completion/：run03–10普通设置入口、空API/Codex表单及取消；final-restoration原包、五文件和电源恢复释租。",
        "translation-completion/translation-source-state197-21/及22/23：已取原七域和电源基线；两次语义前置因同名标题与动作行停下，按HDS说明定位继续，非产品失败。此前基线及定位失败记录；后续完成见24/25。",
        "translation-completion/translation-source-state197-21/temporary-api-saved-reentered.png、temporary-codex-saved-reentered.png及profile-state-result-translation-source-delete-resume.json：两类无密钥临时源保存/重入/删除，未登录、调provider或拉模型。final-state-24七公开域逐字同、final-data-comparison全true；final-power-25 SLEEP/120000/Override10000，租约22:33:58 released。",
        "44文件对照报告 .hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-migration-static-comparison-20261030.json，SHA256 6a785a107fe173af5fbeaf20e9e245258df8c7386bd6262c91b1c531d52aa99e。Root审三路线、设置、模型、源、缓存及Reader消费未发现明确采用功能缺失；不称全部provider真实可用。"
      ],
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "按人类最新明确要求直接参照NextE职责接全局长期配置/Reader即时控制及高级归类，沿Koma既有控件，不任意复制Legacy UI或扩新样式；模型未选/不可用仍保可见开关，既定宿主数据/安全边界保持。",
        "默认去白边false保持、超分/自动翻译关闭；翻译沿既有visual-page规则，无默认外部服务或自动耗费，入口采用不授权自动启服务。",
        "本项后续迁移不取消其它未闭bugs；尚未实施不以源码/许可/入口决定代构建或Native验收。"
      ],
      "continuationGate": {
        "checkedAt": "2026-10-26T19:28:10+00:00",
        "owner": "Root",
        "condition": "本批入口分类/搜索与设置同步CI/原图审查无等待；真实翻译provider/实际译图仍未验，按人类先实现不追问配置或默认调用。既有裁切/增强/设置范围冻结，不把源Gallery/全85后继当本项剩余，不取消原bugs。"
      },
      "adoptedEntryScope": {
        "source": "本轮当前可见人类异步call_63f84fa…：采用这组现有入口（推荐）；精确服务端时间未给，登记时刻不冒答复时间。",
        "settings": "当前可见call_ac3a69d…人类“采用整组调整（推荐）”：漫画翻译从root移services，既有配置页/Reader即时操作与卡片颜色大小间距保持。",
        "more": "既有更多：翻译当前页、自动翻译、显示原图。",
        "defaults": "trimPageMarginsEnabled原false保持；超分与自动翻译默认关闭。",
        "serviceBoundary": "仅services一处translation row/搜索索引，同form/route owner及Reader即时操作/卡片几何颜色保持；2821精确CI成功/最终各图与普通路径具名，已完整交付采用范围，不默认外部服务或扩大权限。"
      },
      "translationVerificationBoundary": {
        "humanDirection": "本轮可见人类答先把功能都实现，当前不再要求其先给服务配置。",
        "observedEvidence": "独立安全配置/分块manifest非默认English冷恢复及zh还原具名；54d全局翻译/高级/Reader分组/模型管理已交付，901–906 English保存pop重入及中文恢复、861增强设置/模型回退均具名，未调用翻译provider。",
        "pendingImplementationVerification": "44文件对照及设置/Runtime/Reader消费未发现明确功能缺失；Codex/API/自部署等真实服务账户网络未验。",
        "unverifiedExternal": "Torii两页试译及Reader未来页具名路径已核；Codex/OAuth/API真实网络尚未验证，不读取或记录密钥。",
        "secureStorage": "按官方SECRET1–1024字节采用同owner immutable generation分块+短manifest最后原子发布；旧短inline可读，失败不换root，提交仅清owned旧代，凭据不入AppStorage/备份。"
      },
      "stage": "具名范围已交付",
      "reportedDate": "2026-10-26"
    },
    {
      "id": "APP_STARTUP_API23_CRASH",
      "title": "AGC 0.1.3在Harmony6.1/API23普通启动崩溃",
      "priority": "P0（启动不可用）",
      "kind": "accepted",
      "owner": "Root：guard修复61c79b6b已push/精确CI成功，API26普通启动与正式APP本地交付完成；AGC实际回验待",
      "status": "用户确认API23普通启动已恢复",
      "dependencies": [],
      "relatedItems": [],
      "result": "四份AGC 0.1.3/code4 Harmony6.1/API23 jscrash同为komaMenuOptions→Index initialRender提前访问API26 ImmersiveStyle.THICK。旧production helper实际复现THICK且guard调用零次，修后两执行兼容检查过，保现代材质/低版solid。三文件61c79b6b665bb9f7a5b616466b7877c6c65f4e00已精确push、CI40478671181 success。197实际API26已1013装同签18910308，普通启动原Library图Root亲审，1016七文件同1012/1017系统120000无Override/d344释租。冷PID归零断言未过：force-stop后PID49479确为Koma、Launcher前台，未反复杀进程，不冒冷启动或API23实机通过。 正式AGC release assembleApp本地交付：.hvigor/outputs/agc-startup-20261027/Koma-0.1.3-4-61c79b6b-startup-fixed.app为7467270B、内HAP18698046B，release/debugfalse/minAPI60100023/target260000026；outer APP及独立Release HAP均正确验签，profile release/app_gallery，内ABC同当前Release HAP且不同旧App。当前未上传，实际AGC/API23实机回验未完。 用户本轮明确反馈“API23普通启动崩溃实测已经好了。可以关闭。”按用户实测收口；未提供设备身份或新证据路径，不自行补造。",
      "remaining": [],
      "remainingActions": [
        "用户已确认API23普通启动恢复，本项按用户验收关闭。"
      ],
      "boundaries": [
        "仅guard后读取API26枚举，保当前API26材质及低版solid fallback行为/样式；KomaSearchField及reader-kit ReaderChrome已有正确lazy guard，本次不改。",
        "构建/执行测试不代Native普通路径，不把AGC日志设备名当新增个人设备操作授权，不扩大清数据/缓存、版本branding或发布范围。"
      ],
      "evidencePoints": [
        "直接证据：.hvigor/outputs/agc-startup-20261027/，四原jscrash、两兼容production执行测试、formal-app-identity.json、startup-validation.json及正式startup-fixed.app。",
        "197普通启动/保全及冷PID归零断言未过的1014/1014b/1014c原件保留，不改为冷启动PASS；最终outer APP与独立Release HAP正确验签依据formal-app-identity.json，其他原检查产物留原目录不改。",
        "本轮用户原话：API23普通启动崩溃实测已经好了。可以关闭。"
      ],
      "reportedAt": "2026-10-27T16:45:06.668+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第41726行，UserMessage item.id=01a17c88-dcea-7172-b010-4c14d1e01342；不排除跨会话更早历史。",
      "firstEvidenceAt": null,
      "firstEvidenceAtSource": "Root已核四份原jscrash，未提供首次取得证据精确时刻。",
      "firstHandlingAt": null,
      "firstHandlingAtSource": "Root已实施guard修复，未给首次处理精确时间，不以文档登记时刻冒首次。",
      "closedAt": "2026-10-29T01:32:38+08:00",
      "continuationGate": {
        "owner": "Root",
        "checkedAt": "2026-10-27T09:15:09+00:00",
        "condition": "用户本轮实测确认API23普通启动已恢复，本项按用户验收关闭；不推断未提供的设备身份或上传路径。"
      },
      "stage": "用户实测验收",
      "reportedDate": "2026-10-27"
    },
    {
      "id": "READER_DOUBLE_TAP_PREFERENCE",
      "title": "双击缩放手势开关与双击间隔档位",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197真机已验证：开关与150-500ms档位可用，关闭后单击可跨章",
      "owner": "Root：197具名范围已验证",
      "dependencies": [],
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET",
        "READER_SETTINGS_STABILITY"
      ],
      "result": "197 真机：设置页显示双击缩放开关和双击检测间隔；档位菜单为150/200/250/300/400/500ms；选择150ms后在偏好中保存为150，随后恢复300。关闭双击缩放后单击可在章末跨到下一章，画面与进度同步到该章。",
      "remaining": "本次范围已验收；不改默认，不扩展到其它宿主。",
      "remainingActions": [
        "本次具名设置与关闭双击后单击跨章范围已验证；其他宿主未扩验。"
      ],
      "boundaries": [
        "保留单击/双击仲裁与点击分区；不改默认样式，不以模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-27T22:18:49.272+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第53477行，UserMessage item.id=01a17dba-6236-7ba1-a1eb-3fcb07b5cf68；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": "2026-10-28T06:07:00+08:00",
      "evidence": [
        "原reportedAt 2026-10-27T20:18:00Z来自监督转述，无直接原文依据；由本会话原始UserMessage取代。"
      ],
      "reportedDate": "2026-10-27"
    },
    {
      "id": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "title": "书源官方中文名未整体核验",
      "priority": "P2（后续处理）",
      "kind": "open",
      "status": "2项官方对应关系仍缺",
      "owner": "source_terra：源故障与官方名称核对",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_EMPTY_SETTINGS_ENTRY"
      ],
      "result": "85源名称已逐项盘点：76项有品牌或栏目依据，7项仅英文参考，2项官方对应关系仍未知。",
      "remaining": "继续核实爱看漫及漫画柜的官方对应关系；图标保原边界。",
      "remainingActions": [
        "继续核实爱看漫及漫画柜的官方对应关系；图标保原边界。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-25T12:00:00Z",
      "reportedAtSource": "用户于10-25要求核对各书源官方中文名；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": null,
      "stage": "爱看漫及漫画柜官方对应尚未核实",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/",
        "漫画1234名称修正 eb347401 已于0.1.4发布；现源码、metadata及README均对应漫画1234网，既有已接受图标保持。",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/pixiv-help-20261029.json：官方简体帮助页title为pixiv帮助，正文使用pixiv；pixiv漫画另指comic.pixiv.net，不作为当前www.pixiv.net源名称。",
        "九源名称证据 .hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/nine-source-followup-20261030.json：protectors官方论坛/四格既有原页、再漫画官网标题、Zero上月缓存标题、創漫官网自称及隆少年支持现名；再漫画正文0行、Zero非新鲜直连。創漫此前已有406，本次误重试如实保留。GoDa原页title G站漫畫、description GaDa漫畫，现GoDa漫画有字面差异且官网自称不一，暂保留现名，正式中文名仍待可靠依据。包子既有403未重试，东立本次403、soc cache miss、LoL timeout停止；图标无新验收。",
        "GoDa名称疑点具名解决：.hvigor/outputs/user-flow-audit/source-settings-repair/goda-identity/koma-goda-home.html 页头主页链接、Logo.png旁直接显示GoDa漫畫，支持当前简繁名；同页og:site_name G站漫畫、description GaDa漫畫为并存称法。图标来源见 /Users/honjow/git/koma-sources/sources/goda/ASSET_SOURCES.md，本轮不改或重验图标。",
        "原85矩阵各行officialNameCoverage20261030：正式注册源逐一对应，webtoons_zh_hant别名映射、example不计。70有品牌/明确栏目依据；7仅固定949英文参考品牌（3Hentai、AsmHentai、MangaBall、MangaDex三语言、NHentai.to），不能推无中文别名；8缺官网中文名/对应：包子403、阴阳师安全拦截、爱看漫不可达、漫画柜缓存看漫画关系未知、LoL超时、铃兰TapTap cache miss、东立403、杂志迷官网我是Zazhimi而中文名依据不足。优酷既有name-web-g6.txt官方title支持；无新访问/改产品或新确定错名。92/1234官网logo与源不同、妙趣404、嗨皮/叭嗒图标未核，不称85图标完成。",
        "漫画柜限定搜索受robots限制；Zazhimi旧页title/logo/footer仅见我是Zazhimi、限定搜索无可用结果。无新名称结论，不刷新访问或改名。",
        "铃兰官网作品与官方论坛趣味漫画栏目支持当前名称；栏目逐篇作者及图标未验，索引结果与直接读取区分。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/soc-official-name-20261030.json；原矩阵soc-zh改brand_supported，其余七项未知保留。",
        "包子同注册域cn官网搜索索引多条标题/首页使用包子漫画，固定949 Baozi.kt同源列cn/www，结合既有static-tw素材支持现名；www当前403未直读，繁体为繁简转换而非独立官网文字。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/baozimh-official-name-20261030.json，矩阵brand_supported。",
        "东立出版社官方域文件索引称東立出版社有限公司及电子书同注册域，支持现名；ebook首页403未直读。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/tongli-official-name-20261030.json；图标不随之验收。",
        "阴阳师现实现使用comic.163.com及huajia.tongren.163.com；README所指官方父页→漫画域原始证据 /private/tmp/koma-onmyoji-zh-contract-20261014 已不存在，README不代原始href。本次只读一次此前未访问 https://yys.163.com/index.html 返回不可重试错误，未重打旧漫画页；名称仍未知，不判错。"
      ],
      "evidencePoints": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/browser-20261029.json",
        "更新当前结果前原result逐字保留：已开始逐站核对，未全部完成。2026-10-28只读核对：CManhua主页标题与当前中文环境显示名一致，同页Mgeko.cc关联或迁移未知；NoyAcg主页标题与现显示名一致。未修改这两源，不外推全源。 妙趣漫画桌面及移动官网名称已核，0.1.3更正名称已发布，公开Native未验；官网当前icon/logo链接404，保留既有参考图且当前官网图标未核。Zazhimi中文品牌依据不足不改名，官网192px图标实体与源icon SHA256相同；无限动漫标题与图标均与主站匹配。 本批只读核对：叭嗒官方隐私政策支持爱奇艺叭嗒名称；92漫画网、瓜子、六漫画、漫画人、漫画社、漫画屋、漫画160、快看、腾讯、色漫网、菇菇四格、鸟鸟韩漫、醫院也瘋狂、綜合口味、老夫子、幻塔、DOTA2、魔法纪录、輔大猴、我是馬克、人2、科技大觀園名称具名对应；漫小肆为品牌简称，原神页支持品牌但未见漫画内容，H-Comic未见中文品牌。漫画1234官网使用漫画1234网；该后缀差异已于0.1.4修正，现源码及metadata与官网名称对应。漫画柜、Happy、咚漫、爱看漫、阴阳师漫画屋、战双、雀魂漫画栏目与王者荣耀等因超时、无法访问或动态壳未核。92漫画网和漫画1234官网当前标志与既有源图不同，未修改；叭嗒图标身份未核，六漫画官网favicon与原图一致。除具名证据外未扩大到图标或设备验收。 咚漫官网名称及同站官方图标与当前源具名一致；嗨皮漫画缓存同域详情支持现名但主页当前502、图标未知。漫画柜受工具限制，阴阳师及爱看漫等主页不可访问，雀魂漫画栏目JS空壳仍未核；85设置行矩阵不提供完整身份审核差集，不据旧数推全源完成数。 搜索抓取的原神官方漫画页面含品牌及具体章节列表，支持现名称与漫画栏目；直接打开为动态空壳，不冒当前正文或图标验收。 漫画柜同域搜索缓存使用“看漫画”，当前源名漫画柜；直接访问受限，正式名与别名关系及图标未核。爱看漫官方地址不可达，第三方名称仅线索；雀魂、战双、王者及阴阳师栏目全称与图标仍缺可核官方证据，不改名。 本轮官网浏览支持雀魂品牌与漫画栏目、王者品牌与漫画栏目；现源名为描述性名称，非官网全称逐字相同。战双页面仅标题可核，阴阳师站点安全策略拦截未绕过；图标和其他未知范围不外推。 本轮官网核对支持MYCOMIC、HANMAN18、泰拉、DB Multiverse、繁中WEBTOON及多站英文品牌的现有对应；单部作品名不扩为全站名，未据英文页面断言无中文别名。部分站点访问失败或超时，保未知。 官网具名证据补充H-Comic、NHentai.xxx及XCOMIC现有品牌；NHentai.to未访问，MangaDex网页安全策略拦截未绕过，不从英文页面推断全站无中文别名。 pixiv官方简体帮助页与当前pixiv名称对应，未改名或图标。 本轮具名名称复核支持部分现名；GoDa官网页头直接使用GoDa漫畫，支持现名；同页另有并存称法。",
        "197原件确认阴阳师 comic.163.com 页面标题“阴阳师漫画屋”及官方漫画、阴阳师工作室；杂志迷 zazhimi.net 截图显示“杂志迷”logo。矩阵现为75有依据、7仅英文参考、3未知。爱看漫与漫画柜系统浏览器风险拦截未绕过；LoL原页内容与源合同吻合，但Riot与具体内容关系未证。未改名称或图标。证据 .hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json 相应行。",
        "腾讯官方根页标题及元数据支持英雄联盟品牌，197 yz.lol.qq.com实际宇宙/织星/欣赏漫画栏目与源合同对应；据同站命名空间及栏目支持“英雄联盟官方漫画”描述性名称，为推论而非官网逐字标题，Riot独立对应未知的原证据保留。未改名称或图标。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/lol-root-official-20261030.json 及原85矩阵。导航main.shtml旧失败路径本轮误重试一次Timeout，已停止，不视为新突破。",
        "漫画柜“同域缓存看漫画”目前仅见all85-source-settings-comparison.json转述note，未定位原始URL、HTML或搜索片段，不能作为官网自称证据；缺少的是可追溯原件，不另设必须证明两别名关系的门槛。名称及图标未改，仍计未知。"
      ]
    },
    {
      "id": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "title": "书源设置项未与Mihon/参考扩展整体对照",
      "priority": "P2（后续处理）",
      "kind": "open",
      "status": "Noy正式版本已交付，账号相关内容未验",
      "owner": "source_terra：源故障及237具名路径；Root：App/Reader发版故障与交付",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_EMPTY_SETTINGS_ENTRY",
        "ASM_HENTAI_BROWSE_RUNTIME_FAILURE",
        "ZEROBYW_MANGA_WEB_ENTRY_MISSING",
        "ZEROBYW_CHAPTERS_TRUNCATED",
        "MH160_COVER_IMAGES_REJECTED"
      ],
      "result": "237已安装Noy公开版本并显示登录入口；用户目前没有账号，登录后内容及镜像未验。",
      "remaining": "Noy登录后内容及依赖账号的镜像验证未执行；用户目前没有账号。",
      "remainingActions": [
        "Noy登录后内容及依赖账号的镜像验证未执行；用户目前没有账号。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。",
        "Zero旧作品身份在现站的具体映射未知，不称已通过；仅有具名失败或参考硬性差异才重开，不重验已接受路径。"
      ],
      "reportedAt": "2026-10-25T12:30:00Z",
      "reportedAtSource": "用户要求全部对比核验书源设置项；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": null,
      "stage": "继续具名设置差异；Noy账号相关范围未验",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai237-current/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-3hentai237-final-20261028/run-metadata.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zerobyw237-public/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zerobyw237-default015/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zerobyw237-public015/public-wasm-default-list.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xkcd-organization-reference/candidate-016/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/manhuashe-mirror019/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/goda-mirror014/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-picker-import-031/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-proof-to-browse-032/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd-public-update-024/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd-completion-zero-identity-025/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simplyhentai011-ordinary-search-054/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-ordinary-entry-056/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-year-save-060/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-year-reentered-061/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-yearmonth-save-062/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-yearmonth-reentered-063/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-restore-confirm-064/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-restored-065/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-library-before-066/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-existing-book-067/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-existing-body-068/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-existing-return-069/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-settings-077/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-mirror-options-078/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-official-mirror-save-079/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-mirror-reentered-080/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-restore-confirm-081/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-restored-082/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-existing-book-083/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-existing-body-084/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-existing-return-085/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/fjumonkey-search012/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-public-browse-132/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-ordinary-search-133/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-ordinary-pagination-134/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-ordinary-originals-visible-135/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-default-browse-142/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-m206-saved-146/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-m206-reentered-147/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicfury-filter016/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-default-restored-149/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-existing-book-150/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-existing-reader-151/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-existing-return-152/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-browse-160/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-controls-162/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-sort-last-update-164/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-cleared-and-rest-165/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-search-166/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-options-167/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-popularity-168/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-178/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-popularity-179/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-reset-180/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-browse-reset-181/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-browse-192/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-browse-newest-195/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-search-newest-199/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-search-reset-200/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-installed-204/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-browse-209/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-browse-recent-212/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-search-popular-217/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-search-reset-218/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/restore-reading-return-226/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-closeout-final-227/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-closeout-sleep-timeout-228/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/guazi-search-category-246/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/hcomic-search-fullcolor-255/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-session-return-264/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-session-sleep-265/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-old-log-439/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-host-sleep-487/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-ua-sleep-509/"
      ],
      "evidencePoints": [
        "/private/tmp/koma-filter-scope-header-build.log",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-failure-273/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-log-recv-277/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-final-shelf-407/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-final-sleep-408/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-ui-431/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-cleared-432/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-final-433/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-sleep-437/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd-cold-read-518/",
        "Koma 59a1edb17cc7a7afadc20f18fd3c914558023aa5已推；b2 release构建及两条既有执行检查通过，CI待核。",
        "https://github.com/honjow/Koma/actions/runs/40784063216",
        "源2bf64894d8b190db9aabf274d06d5c4d707d06dc CI40790029849 success；公开ZIP/WASM与237本地候选不同。",
        "NNH源355cd077722882abf5ce3ecf51bb6fdb51e0f677 CI40795329287 success；公开ZIP 026e24ca017ec70fb4b00009779e429bb7310593eb0f3c2d33f27e9e3c7a437e/WASM ed46e610a18caf00ba2e7a9906a1a17be72a14d2ae161b60baff46aab3c7c63c。",
        "MangaDex run775新截图及718/728/729布局；755旧图路径误配无效。Host 5ef0fea7已推，CI待核。",
        "237 run795/799/800：22→15；真实feed重放 /private/tmp/md-consumption-real-replay.mjs；Host 5ef0fea7 CI40796472276 success，源9e6b3f8本地提交推送中。",
        "/private/tmp/mangadex-hans-public-9e6b3f8/real-feed-replay.json",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-before-839/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-add-841/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-group-843/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-save-844/",
        "源c4daf043f77f82e8a7455780e554f993ece157b1，CI40801323923进行中。",
        "繁中c4daf043f77f82e8a7455780e554f993ece157b1 CI40801323923 success；公开WASM真实feed重放0项/49排除/exact可取。英文真实155原/84过滤→53托管+71排除，候选未发布。",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/md-en-uuid021-live-consumers/verification.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/md-en-cover022-live/verification.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/md-en-cover022-v3-replay/verification.json",
        "英文源7cc96d701a9a03e7b3b97bbf640f947fb206d6bf CI40804860757 success；237候选run885/892 124→53，901–903原包数据及电源恢复；022首卷候选未提交。",
        "237 run908实体同冻结，915/918/919设置重入，921首页10项，922/923详情返回；924选择器未打开，932–934原状态恢复。真实响应v3回放见source-settings-repair/md-en-cover022-v3-replay/verification.json。",
        "/private/tmp/md-en-public-ba9d1bc/replay/verification.json；源ba9d1bc911d0699979555b58116e86cd81e320af CI40807521539 success。",
        "237 run939实体同冻结、950/951独立Latest、973/975自动搜索Haimiya引号；953输入协议失败保留，未点提交按钮。Koma 7ba7d201 CI40808199234 success。",
        "/private/tmp/md-en-public-65695db/real-feed-replay.json；源65695db495e6f76ca5b8f96e07481b3e71e3a418 CI40809265668 success，237两场恢复961–963及980–982独立核。",
        "run987为脚本在已打开sheet上误点导致导航偏航，非产品失败；994–996恢复，1000/1003/1006导入成功，1007实体与冻结一致。",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/happymh-search-dns-20261029.json",
        "/private/tmp/source-four-170ba07-ci/publication-preflight.json",
        "/private/tmp/source-four-170ba07-ci/publication-final.json",
        "/private/tmp/source-four-170ba07-ci/public/delivery.json",
        "源170ba076d02b52b1dae7e9add22b56de20ebaf3c CI40812037522发布步骤HTTP500整体failure，既有草稿核对后发布恢复；不称CI成功。",
        "237 run1061/1065/1078引号搜索、1072空结果及1082普通词；1074日志自动审批拒绝未读取，1095–1097恢复由源owner报告待Root复核。",
        "run1095/1096五数据及四源实体逐字恢复，81项registry元数据/启用/顺序相同，仅四重导入路径变化；1097 SLEEP/120000无override。源f83d819300cd806a73be78580dd79a5d260ae251已推，CI40814846051进行中。",
        "/private/tmp/source-f83-public/delivery.json；源f83d819300cd806a73be78580dd79a5d260ae251 CI40814846051 completed/success，公开release 427451027。",
        "run1102/1104/1111–1113：候选首页403及验证、原012回装后会话仍指候选；SourceWebSessionStore:78–80身份含wasmPath，原路径与Registry需一并恢复，不读写系统Cookie或伪造grant。",
        "run1120原包四成员逐字同1099；1121 registry/session/library/reader/settings/filters同1098；1122旧路径存在且孤立目录删除；1123 SLEEP/120000无override。1116/1119 OS权限失败保留，按同bundle正规收发恢复，未写系统Cookie或重绑定grant。puredecode 033c673本地提交，推送进行中；Koma 75b77fe9 CI40815289504 success。",
        "/private/tmp/source-033-public/delivery.json；源033c6736a1ee52b5784ae1cdd05c233d064bc153 CI40816264651 success，release427458526公开。NamiComi固定参考含章节/评级/状态/排序及四组动态三态标签，现源filters=false。",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/namicomi-tags-reference-20261029.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/namicomi-filtered-hans-live-20261029.json",
        "简繁014候选核真实95标签、旧013默认请求一致；组合API HTTP200空结果，不冒非空或Native通过。",
        "237 run1147默认目录、1150四组动态标签、1152包含Action与1153排除Action；图像待Root亲审，最终验收未完成。",
        "237 run1149/1152/1153模式及Action包含排除画面Root亲审；1155重入、1157忽略恢复；1160繁中目录，1172独立搜索仅search域。最终6b4c与简繁v5冻结，恢复进行中。",
        "237 run1175原包八成员与1125逐字同，1176六JSON同1124及原7f9安装成功，1177清临时文件，1178 SLEEP/120000无override并释租；Koma 6dbb621d24048ca297f0caaa8250e7b0f03e904a CI40820669074进行中。",
        "/private/tmp/source-1ce-public/delivery.json",
        "Koma 6dbb621d CI40820669074 success；源1ce628e0c5c6e64898126fea295de0aca5da12ff CI40821026680 success，公开简繁014实体与本地v5不同。",
        "237 run1187搜索被拒未重试、1188三项筛选仅可见；1190原本地015四成员同1180、1191六JSON同1179、1193 SLEEP/120000无override并释租。v1不代最终v2验收。",
        "Komiic run1204 VERSUS引号为空；1194–1209恢复由source owner报告，Root待核。源b193dcf及71924a4已推，CI40823266506进行中。",
        "237 run1214实体同冻结、1216/1218/1219/1221/1222/1223目录筛选及重置；1225/1226原包与六数据恢复，1228 SLEEP/120000无override并释租。",
        "源f25d750ee47f2fdce68e628b3553d609bed24c77 CI40824563757 success；公开ZIP 5ba3484879eafec473c1f8e0d82f51a9fc03f0c0d08090960965ebf61bd48f71，WASM 7564c0af4d5d26b72372735a91939b420cd028c201e7a6cff31a41cb873d9114。",
        "MangaBall014候选按双Host feature门控，96静态标签来自固定参考；公开013与候选默认请求/默认注入相同，显式组合保no_18；官网一次GET 403，未重试。",
        "源71924a4 CI40823266506 success；Noy015及Komiic0.1.10公开ZIP/WASM已核，公开WASM默认/筛选及查询编码受控回放通过。",
        "源MangaBall 37a38f5与繁中WEBTOON 0af71d0已推；WEBTOON生产WASM真实HTML回放Originals/Canvas，237 run1239–1244界面筛选但前后首项相同；1246/1247/1249原包六数据及电源恢复释租。",
        "源0af71d0 CI40826707852 success，公开实体位于/private/tmp/source-0af-public/；漫画柜rank/week.html首次请求TLS阶段curl35、HTTP000，未重试，不外推全站。",
        "漫画柜018候选：受控HTML核七项与默认/非空查询兼容，rank真实GET HTTP000；人工最小HTML仅验证解析形状，不冒真实排行结果。",
        "真实官网 /private/tmp/tencent-filter-romance-live.html；237 run1254/1257/1258/1260/1262/1263筛选及重入重置，1265/1266/1268原包六数据及电源恢复释租。",
        "本地ea5be93，HTTPS推送自动审批拒绝：尚未核实该批代码向指定仓库推送的明确授权、仓库公开性及敏感性，明确不得间接绕过。",
        "ea5be93经当前可信授权与仓库/提交范围核实后同一HTTPS fast-forward成功；此前自动审批拒绝历史保留。",
        "/private/tmp/zazhimi-filter-fashion-live.json；237 run1273/1276/1277/1279/1281/1282具名筛选与重置，1284/1285/1287原包六数据与电源恢复释租。",
        "本地566d980向GitHub正常HTTPS推送自动审批拒绝：当前可信用户消息未直接授权该具体目的地及代码外发，不能仅凭代理转述；禁止间接绕过。",
        "/private/tmp/tencent-ea5-public/tencentcomics-0.1.3.koma；源ea5be93 CI40829103714 success，公开ZIP e44ecc19eff1686a118b075566e7049a2150d5d727fa01129a50c17867465bd8，WASM d156c6b7560db31049f34d1fe24208e9355090c5d54a75b1e4dad98c08cd3740。",
        "237 run1292/1294/1295/1297–1299/1301/1302；1304/1305/1307原包、六数据及电源恢复释租。真实官网两页各28项及首图200，候选未公开。",
        "漫小肆v2 ZIP /private/tmp/mangaxiaosi-filter014-v2.koma SHA256 f0142c14071e8bf8a185fdadd08d9f6d8857e27b82ec5516ed81b0ef415066c7，WASM 54dee6a8d81967c1211400453674907b4c6dc06bd543fa3122a0ba164ae44e7a；本地18355a3未推，v2未Native。",
        "官网动态8组235选项及儿童分类真实HTTP200；237 run1310/1313/1315–1318/1320/1322具名筛选，1324/1325/1327原包六数据与电源恢复释租。",
        "92漫画190f511本地提交，lib SHA256 662fcd5ddd82cdb20225df05190613cfeb2b7e29535a0f4b9f1253fdf737eb52与237冻结一致；漫小肆18355a3待审。",
        "HentaiFox原UA/headers首次热门请求curl35 SSL_ERROR_SYSCALL、HTTP000无响应；不以schema或源码消费代Native验收。",
        "/private/tmp/jiuermanhua-sort-only-post-live.html",
        "/private/tmp/jiuer-filter-sort-only-replay.json",
        "/private/tmp/zazhimi-566-public/zazhimi-0.1.2.koma：566d980 CI40830219869 success，公开WASM与237候选分类回放一致但实体不同。",
        "/private/tmp/cartoon18-sort-created-live.html：不同UA一次HTTP200站点错误页，不代表源同身份请求或全站状态。",
        "/private/tmp/source-190-public/：源190f511 CI40833609436 success，92漫画015及漫小肆014公开WASM与各最终候选真实HTML回放一致，未另Native。",
        "官网动态三组及恋爱/连载组合HTTP200；237 run1332/1336/1337/1339/1341/1343/1344，1346/1347/1349原包六数据及电源恢复释租。",
        "本地17e49b4仅Cargo/lib及lock版本，lib SHA256 be24a9e7c948536c1fbaf401ec6a127bffda53b1ea729c1183573dbfd421e634与237冻结一致；旧description/query WIP保留。",
        "已移除过期待办：MH1234动态筛选、英文MangaDex Latest、英文WEBTOON/动漫屋普通搜索均已有具名结果；嗨皮2300006 DNS无Answer非NXDOMAIN，包子challenge时查询未发。",
        "/private/tmp/cmanhua-filter-ongoing-live.html",
        "/private/tmp/cmanhua-filter-completed-live.html",
        "237 run1358/1362/1364–1369筛选及重入，1371/1372/1374原包六数据电源恢复；本地6681f21未推，真实第二页未验。",
        "爱看漫：固定参考 /booklists 消费地区、题材、状态及页面 next；现源仅默认分类并以48卡数量判断续页。真实筛选页面未保存，原站不可达，未修。漫画160：固定参考 CategoryFilter 使用移动分类及 #listbody，现源仅热门/最新 .itemBox、无分类筛选；此前搜索自动挑战通过不能代替分类验收，独立 challengeRequestId WIP 未改。",
        "MangaBz 17e49b4 与 CManhua 6681f21a57903c743e3f8de07378134164ead52d 已推；精确 CI 40840714068 success，公开索引为 MangaBz 0.1.10 / CManhua 0.1.5。公开 WASM 使用保存的官网恋爱+连载、Completed HTML 回放，data 分别与设备候选逐字相同；公开 WASM 字节不同于设备候选，未另作 Native。CManhua 两状态官网首12相同、真实第二页未验。实体 /private/tmp/source-668-public/。",
        "漫画160隔离016 v2：固定参考68项；真实日韩页面同域301→200、生产WASM回放12本。237 1381实体与冻结一致，1383热门50，1386日韩12本首三与保存官网响应一致，1387重入、1388重置；1390原015四成员等1376、1392 Registry及六JSON等1375且原会话路径恢复，1394 SLEEP/120000无override并释租。自然验证sheet未出现，候选未提交公开，独立challengeRequestId WIP保留。证据 source-web-session-concurrent 对应run。",
        "漫画160分类独立本地提交 89cfc7b，仅源 lib/Cargo 和锁文件该源版本；原 challengeRequestId WIP 保留，未推送。",
        "再漫画019候选：真实API连载20、周榜10及生产WASM回放；237 1401实体匹配，1403默认20，1406周榜10首三与官网一致，1409连载20首三与官网一致但同默认首屏，1410重入、1411重置。1413原018四成员等1396，1414六JSON等1395，1416 SLEEP/120000无override并释租。数字搜索先查详情行为保持，按ID开关差异未覆盖；候选未提交公开。证据 source-web-session-concurrent 对应run。",
        "再漫画独立提交 c5e2022 未推；最终v4按真实 data.totalNum 判断分类分页。保存的真实首页与周榜回放同237 v3；真实total5792配受控page290末页判断通过，真实末页未验。冻结 /private/tmp/zaimanhua-filter019-v4.koma，v4未另Native。",
        "MyComic固定参考排序、地区、类型、受众、年份和进度由目录及搜索消费，显式排行走独立路径；现015 filters=false。一次日本分类请求以同站Referer和curl默认UA返回403，原因未知且请求身份不同于设备，未重试；原语言设置验收不代替筛选验收。",
        "Komiic 0.1.11 v3：allCategory真实HTTP200共71标签，爱情ID1参考GraphQL HTTP200 30项；生产WASM核静态schema零网络、动态71及爱情30，默认热门受控请求响应同公开010。237 1423候选实体匹配，1425首页无法连接书源，未进入筛选、未重试，原因未知；1427原019四成员等1418、1428 registry与六JSON等1417、1430 SLEEP/120000无override并释租。候选未提交公开，镜像等WIP已恢复。证据 source-web-session-concurrent 对应run。",
        "源提交89cfc7b与c5e2022已推，精确CI 40849389869 success；公开归档实体及WASM回放尚核，不冒App采用。",
        "公开实体 /private/tmp/source-c5-public/identity.json 与 candidate-public-equality.json：漫画160 0.1.6、再漫画0.1.9，公开WASM真实响应回放data与候选逐字相同；公开包未另Native，再漫画v4真实末页未验。",
        "快看0.1.6候选：参考题材、区域、属性、进度、排序；真实恋爱页HTTP200、生产WASM回放41本。237 1437候选实体精确，1439热门42，1442恋爱41首三与官网对应，1443重入、1444重置；1446原014四成员等1432，1447 registry及六JSON等1431，1449 SLEEP/120000无override并释租。仅候选Native，未提交公开，原搜索WIP保留。证据 source-web-session-concurrent 对应run。",
        "快看0.1.6筛选独立本地提交225468b，尚未推送公开；原搜索WIP保留。",
        "AsmHentai参考继承GalleryAdults排序和动态标签，现source_info filters=false；默认中文及短标题验收不代筛选。固定参考取前5页解析a.tag_btn，当前同源UA/headers tags/popular/?page=1 HTTP200、120个a.badge.tag及69页，DOM不匹配。标签目录、单/多标签搜索和中文过滤待按真实站点核；收藏登录/随机未完成，候选未实现或Native验收。",
        "XCOMIC简繁固定参考Search消费排序、语言、原作状态、分级、类型、受众、格式/题材三态、年代及章节范围等；现公开源filters=false。既有一次检查仅优化详情→章节，不代筛选完成；API、默认值及语言约束待核，未做新包或设备。",
        "AsmHentai同源UA标签第2–5页各一次HTTP200，前五页共600个不同slug；big-breasts单标签首20无中文、chinese-dress首20含中文 /g/281484/，均HTTP200。仅具名样本，参考tag_btn与当前badge.tag差异保留；未改源、未Native，不外推所有标签。",
        "AsmHentai 0.1.4候选：五份真实标签页生产WASM回放600项/600唯一，单标签3d真实页中文6本、多标签真实搜索8本。237 1456候选实体一致、1458原19、1459筛选、1460菜单首3d、1461选3d共16项且前6与官网第一页一致、1462重入、1463重置。1465原013四成员等1451、1466 registry及六JSON等1450、1468 SLEEP/120000无override并释租。候选未提交公开；收藏、随机、speechless及参考字母组UI未实现。",
        "AsmHentai 0.1.4标签/排序独立提交b035012，未推公开；真实Latest中文页HTTP200、WASM 20项/next2，未Native。收藏、随机、speechless及字母分组仍未覆盖。",
        "AsmHentai 0.1.4标签 big breasts + 关键词 school：原源UA真实HTTP200，v4生产WASM返回中文12/next2；真实回放，未Native该搜索。证据 /private/tmp/asmhentai-tag-query-live.html 与 /private/tmp/asmhentai-tag-query-replay-v4.json。",
        "Zero 0.1.8本地候选：237 1476 ZIP/WASM与冻结一致，1479默认24，1483战斗24首三与保存官网响应一致，1484重入；1487原包四成员等1470，1488六JSON等1469，1490睡眠120000且租约释放。候选未提交公开，网站登录窗口标题未验。证据 source-web-session-concurrent/zerobyw-filter-*。",
        "Zero 0.1.8筛选本地提交1a8ff43，未推送公开；237及官网首屏对照为候选证据，不冒公开包验收。",
        "源提交4e3b8fd42475d540454c120d54f73bddc1b5b9f2精确CI40856810217 completed/success；快看0.1.6及AsmHentai中文0.1.4已推，公开实体尚在核验。Zero 1a8ff43仍本地未推。",
        "源4e3b8fd精确CI40856810217 success；/private/tmp/source-4e3-public/identity.json 与 candidate-public-equality.json：快看0.1.6恋爱及AsmHentai中文0.1.4 3d真实官网HTML回放data与最终237候选逐字相同。公开WASM字节不同、未另Native；Asm收藏、随机、speechless及字母组等仍未完成。",
        "XCOMIC排序候选：固定949dea参考9项，当前公开/search HTML HTTP200但参考动态4组缺失；候选仅排序、默认路径保持。237简中1498实体、1500热门12、1503 Most Follows、1504重入、1505重置，1507原包四成员及1508六JSON逐字同基线、1510睡眠及释租。繁中仅WASM请求对照，真实标签、繁中Native和发布未完成。证据 source-web-session-concurrent/xcomic-sort-*。",
        "XCOMIC简繁排序独立本地提交e271800，未推公开；简中237具名，繁中仅WASM请求对照，动态筛选未实现。",
        "Zero及XCOMIC e271800已推，精确CI40862486606 success；公开实体待核，不冒公开包Native。",
        "源e271公开 /private/tmp/source-e271-public/identity.json 与 candidate-public-equality.json：Zero 0.1.8真实战斗HTML data等候选；XCOMIC简中0.1.8双真实GraphQL data及requests等候选；繁中仅实体，不冒真实繁中或Native。",
        "Root执行公开e271 XCOMIC繁中0.1.8 WASM source_info为filters=false，简中为true；手写导出与常量不一致，繁中排序菜单不可达。正在修繁中导出并升0.1.9，filters从SOURCE_CAPS派生，保locale、请求、默认及设置；候选未验。MangaDex候选1546同类入口缺失，v2修实际导出并继续验证。Pixiv 59d3795精确CI40866448544 success，公开实体待核。",
        "MangaDex简繁状态候选仅4项多选，默认请求保持；v1 1546 source_info漏filters无菜单，v2修实际info双源true。237简中1551实体精确v2、1558 Completed 20首三与真实官方API/WASM回放同、1559重入、1560重置；1562原018四成员等1536，1563六JSON等1535，1565睡眠120000并释租。繁中仅默认请求/WASM info，未Native；候选未提交公开，其余参考筛选未实现。证据 source-web-session-concurrent/md-status-* 与 /private/tmp/md-status-live-replay-v2.json。",
        "MangaDex简繁0.1.10状态筛选独立本地提交118bdaa，未推公开；简中237具名，繁中未Native，其他参考筛选未实现，v1漏info反例保留。",
        "XCOMIC繁中019候选：237 1572 ZIP/WASM与冻结匹配，1575筛选入口可达，1577 Most Follows结果改变，1578重入、1579重置；1581原016四成员等1567、1582六JSON等1566、1584睡眠120000并释租。候选非公开，动态标签组未实现。证据 source-web-session-concurrent/xcomic-hant-*。",
        "英文MangaDex 1600三条件结果首三与官网回放一致，1601后按用户要求不再功能验证；1603原020四成员等1586，1604六JSON等1585，1606睡眠120000并释租。024候选WIP未提交，不列新增待测或本轮发布阻碍。",
        "7cbcfa04de294a3623bac4921d0174c8e37a0799精确CI40884954501 success，公开0.1.24 ZIP 3a1970d18536ad7567b8c247131c8d08b9762ebd3a2b40a34738a76834e7b7e2 / WASM fb3d6e2bf00f2bde971dd82751b4bd7038e120d0897fb883e8b4fcd95ea291f4；/private/tmp/md-en-7cbc-public/真实API20项请求/data与237 1600候选逐字相等，completed/shoujo/followedCount消费及defaultEqual=true。公开WASM不同候选未另Native；不重跑已验路径。",
        "简繁MangaDex 118bdaa 与XCOMIC繁中8802936已在master，精确CI40872000708 success；不再列工程待交付，既有具名Native与未覆盖范围保留。",
        "Zero默认域发现df2c2f9已交付，公开015及237普通目录/正文具名；旧manga:/chapter:由5de9e98保留，新pc-数字ID独立。旧显式域www.zerobywgbo2.com目录EOF见source-settings-repair/zerobyw237-default015/zerobyw015-old.log；现无具名旧书slug映射结果，不能据EOF推断映射失败或成功。用户网页入口及5章对应事项均accepted。",
        "Noy固定949三个API镜像与当前默认web域不同；公开015普通热门POST noymanga.com/api/readLeaderboard type=day&page=1与既存013构造相同，旧实网返回login/auth_required。参考api.noymanga.com同形无Cookie一次200/statuslogin，公开015回放auth_required；/private/tmp/noyacg-api-mirror-once.headers、.body及noyacg-public015-mirror-replay.mjs。镜像详情/页图兼容未证，未改UI/默认/源，不称已证可直接修。",
        "真实样本《情敵好像怪怪的？？》title_no1127879/episode1既有59图片及1作者文字；公开源010与无诊断c274实际链待Native末页验。237 lease…f797a065，1785原019四成员及六域基线、AWAKE/86400000；原设置无该源条目，目标chapter原pageIndex0记录需原样恢复。1786同签HAP及公开源准备进行中，尚未源请求。",
        "更新当前结果前的原result逐字保留：既有a6a36a8的3Hentai 0.1.3在237普通导入后，真实官网目录25本；默认完整标题，关闭设置并保存后同目录显示短标题，清除本次设置后完整标题恢复。前后settings JSON相等，原书架及斗破继续阅读已恢复，临时上传已清除；超时120000ms、休眠及释租已完成，设备保留升级的3Hentai 0.1.3。仅该源具名设置范围通过。Zerobyw 0.1.2原路由真实404，固定参考949dea2为新/pc/路由；0.1.4保原默认与旧manga:/chapter:身份，新身份为pc-。源5de9e98精确CI40639208193成功；公开0.1.4在237普通导入→目录24→详情5章→真实正文1/149，并已恢复。原默认域名EOF、旧ID及参考域名失败更新链路仍待调查。 Zerobyw 0.1.5的df2c2f9已推且CI 40646153719成功，公开索引与包已核；237本地候选在未保存地址时目录24、详情5章、正文1/162实图，设置、历史、书架及设备已恢复并释租。公开WASM真实默认目录24项、nextCursor 2；公开WASM字节与设备本地候选不同，公开0.1.5已在237普通picker导入，安装ZIP及WASM与公开包逐字一致，settings与002相等，唯一临时下载文件已删且读回通过，正常返回Browse；原有已存地址保留。 xkcd-zh 0.1.6已推，保SINGLE默认及旧ID；本地生产WASM分组、分页、正文URL与旧单本fixture通过，英文归档503的受控失败保持独立。公开WASM与本地字节不同，真实按年目录10项、首项2024和下一页2通过；237设置持久、分组浏览、旧书及正文未验。 源码复核WEBTOON繁中实际消费最高画质、连续章号、作者附言三项，默认均false，附言依赖宿主text_page_image_v1；MyComic既有默认cn、original为显式繁中，参考默认差异已记录。此为源码核对，不冒设备验收。 漫画社0.1.9提交ee13701已推且CI40667731479成功，默认311s、用户可显式选m206，保旧路径书章ID；具名作品m206目录20、搜索2、旧书800章、首章18页及首图200 WebP，公开WASM另核搜索及旧章。237公开包已安装，设置持久与正文未验，全旧库映射未验。GoDa 0.1.4提交2f7ade3已推且CI40669312858成功，固定参考六镜像均实测目录、搜索、详情、章节与首章44页；公开WASM明确godamh具名详情及旧首章通过，公开Native、设置持久、图片显示及全库身份未验。 xkcd 0.1.6公开包024–025已安装，设置及原缓存正文具名验证，新作品冷网络正文未验。 Simply Hentai旧search=false记录已过时：237公开0.1.1普通入口love搜索发出真实请求，但返回HTTP403，Native显示源搜索失败、请求被拒绝；不是不支持搜索，亦不能算搜索可用，拒绝原因待核。 237公开xkcd 0.1.6普通源内设置：默认Single目录1本；BY_YEAR保存后年度目录10本并重入读回；BY_YEAR_MONTH保存后月份标题目录并重入读回。经现有确认清除本次xkcd测试设置后默认恢复1本，整份settings JSON与002一致；旧书及正文Native仍未验。 237原库xkcd旧ID原书676章，普通Continue原缓存2978困住第1/1页真实可见，未翻页；返回同详情同章同页，library JSON与066完全一致、49本无增删或字段变化。仅原缓存页具名通过，不冒冷网络正文。 237 GoDa公开0.1.4默认baozimh.org保持，六镜像菜单中选godamh.com后目录18本，保存重入及preferredMirror读回一致；清除本次设置后整份settings与002相等。旧书武炼巅峰3875章，Continue夺酒第2/70原正文可见并返回同章同页，49本无增删、chapterId不变；库并非完全相等：该书自然预载3865章由0变77页、页表指纹与updatedAt及总页数87→164，其余48本和旧缓存章未变。公开WASM godamh具名旧4 chapterId存在，两个缓存章70/17页与首pageId/URL一致，首图200；不外推六镜像Native。 輔大猴0.1.2提交5e397ee已推，本地生产WASM搜索分页、空结果及旧ID详情具名；CI查询遇EOF后重复查询被自动审批拒绝，旧CI未核；当前公开实体与237实装ZIP/WASM一致，普通搜索及真实续页具名通过。 人2 aacee1f CI40685768520及IP手札mini 430b767 CI40688772764成功，公开WASM与原C++ Host按真实保存HTML具名回放；人2及IPmini普通搜索已具名验证，正文未验。devrunner 9a46bc3 CI40687391567成功。 綜合口味0.1.2提交5fa311a已推、CI40697052579成功；公开WASM及原Host以真实保存HTML核漫画分页、食分类及空结果，旧浏览两页数据一致；237公开包普通搜索食返回具名5项及终点，Reader未验。117实装IPmini及人2 ZIP与先前公开容器哈希不同，但所有成员内容相等，人2 WASM与公开一致；輔大猴实装ZIP/WASM与当前公开完全相等。 繁中WEBTOON公开0.1.8自检：真实搜索愛仅返回All首屏22且hasMore=false，漏取官网两分类分页。0.1.9提交bc9c66e、精确CI40700016006成功；237实装ZIP/WASM与公开字节一致，普通搜索愛并滚动后观察到旧All尾部之后的Originals后续作品与6张封面正常。同次搜索日志完成；仅具名普通续页通过，不冒全部411项Native通过，不混英文源WIP。 237漫画社0.1.9默认目录20本成功；显式选m206保存preferredMirror为https://www.m206.com，自动目录请求op217 531ms network_error/http0failed，旧20本保留；普通重入设置仍显示m206，故不是保存丢失。传输原因未知，桌面成功不代Native；当前正在清除本轮设置并核默认旧书。Comic Fury 0.1.6提交af3cd7b、CI40703509316成功；公开WASM在Host注入默认filter后热门、最新、搜索与0.1.5逐字段一致，显式筛选具名返回19项、非法值网络前拒绝；Native控件持久及消费待验。 149清除本轮m206后整份settings与131/002相等、无该源override，默认311s目录20本成功。150–152默认旧一人之下13871详情800章，Continue反杀第2/17缓存正文可见并返回同章同页；49本及800章ID保持，两个旧缓存页表及其他48本相同。库非逐字相等：786章正常补chapterNumber/sortKey。实装ZIP/WASM与公开完全一致。152日志op218在收到响应头前失败，platformCode2300999，限定header前失败，不推断DNS或TLS。 237公开Comic Fury 0.1.6普通目录默认热门12本，八个筛选控件已观察；目录按更新时间排序实际成功，清除恢复默认。源内搜索a后选择Popularity，实际发目录请求而搜索结果不变。宿主已按搜索状态分流筛选读取、忙碌、修改与重置，保独立持久化及原样式；本地构建成功，修复包尚未真机回验。169日志为空不推断具体传输错误。 NHentai.to 0.1.5 sort/exclude提交ec03651已推，CI40706302986成功；公开WASM在原Host以真实保存HTML验证默认搜索、显式筛选和热门页，默认热门旧游标对比使用受控分页HTML；Native筛选未验，参考登录收藏及跨语言随机未实现。 3Hentai 0.1.5筛选提交53098e1已推，参考排序及9文本筛选显式供Browse/Search消费，保默认URL、旧游标及full_title；真实筛选搜索/热门前两页各25项，本地Host回放具名，CI、公开及Native待验。参考静态提示行当前Host模型不支持，不冒UI说明全量完成。 237冻结release 0755：178–179搜索a选Popularity实际search op21成功，首Maor/慢话/MyDiary；180搜索重置实际search op23恢复原结果，search保存值删除且browse保持；181清查询后目录重置实际get_manga_list op25恢复12本首Maor。Comic Fury本轮筛选项已清除，其他源筛选与169逐字相同、全source-settings与131/002基线相等。旧168误发目录反例保留。宿主3文件4232f2a3已本地提交，推送进行中、精确CI未核；本地执行回归、release构建及同签冻结包与设备验证分别成立。 237公开NHentai.to 0.1.5与3Hentai 0.1.5普通Browse及Search分别选排序、观察结果变化并重置，源设置和filterprefs恢复基线；NH安装WASM与公开一致且ZIP成员一致，3H以系统picker导入，ZIP/WASM与公开一致且临时下载已清除。仅具名排序路径通过，其他筛选值及参考静态说明未验。226原斗破01第1/36回书架第1页3%，漫画屋身份为缓存推断；227库49本，228 SLEEP、正常120000无override并释租。 237公开瓜子0.1.4及H-Comic0.1.3普通目录和搜索筛选已具名验收；本次设置及筛选恢复基线，原书架和设备状态恢复并释租。 具名范围：瓜子目录恋爱筛选36本，搜索爱后选恋爱实际search完成；H-Comic目录全彩10本，搜索love后选全彩实际search完成；两者重置后filterprefs为空。证据为layout及运行记录，筛选过程无截图，不扩其他值。 Host筛选scope/Header核心和两页面已接，能力门槛保旧Host旧schema；release候选7f9cfe本地构建成功，237具名MH1234 Native待验。AsmHentai 0.1.2在237普通目录失败；持久脱敏日志显示get_manga_list HTTP200后runtime unknown，不是HTTP403或传输失败。同真实HTML及原C++ Host复现图片属性问题，缺失可选属性回退后目录19本、短标题ID不变及详情通过；源f8ecf37已推，CI、公开和Native待核。237当次会话已恢复SLEEP/120000无override并释租。 237 MPC本地014候选普通目录显示原参考提示及筛选，Action结果变化、love搜索与重置具名已核；搜索态筛选隐藏未单独证实。原013包、数据与设置已恢复，临时文件删除，设备SLEEP/120000无override并释租；候选未发布。 MPC公开0.1.4已推且CI成功，237普通更新后包与公开一致；Header、Action目录及重置具名核验，原数据/设置及设备状态恢复并释租。搜索态是否隐藏筛选仍未单独验证。 MPC公开0.1.4 Header及Action筛选具名范围已验收，整体85源审计继续开放。 Comic Fury 0.1.6精确CI40703509316成功及237具名筛选已核，页面筛选不冒持久sourceSettings验收。AsmHentai公开013具名目录及短标题设置已核。 237 MPC公开014普通love搜索标题栏无筛选入口，清查询后目录菜单恢复筛选；数据及设备状态恢复释租。 Simply Hentai旧日志显示challenge信号被源降为http_error；012候选在旧Host仍403。Host普通目录和首搜索缺guard及requestHandle接线，三文件候选正构建并待237回验；默认403保持，API origin限定api.simply-hentai.com，不假定www共享会话。 Simply第一轮联合候选验证后原请求仍403，无自动循环；原包、四份用户数据及会话记录已恢复，临时文件清除，237电源恢复并释租。发现原请求与验证页UA不一致，最小修正及单次回验中，403原因尚未确定。 Simply UA一致性候选在237手动验证后仍403；日志显示UA不一致及Cookie读取为空，不认定根因。原宿主、原011包、五份数据及会话恢复，临时文件清除，设备休眠释租。 237 xkcd按年月分组2024-08的2977冷页真实中文图已核；原书库及设置保持，reader自然新增本次组的进度、章节与来源历史各一条，设备恢复释租。 Host筛选scope/Header已推Koma master，保目录与搜索独立值、旧schema兼容及Header仅展示；既有237 MPC具名结果保持，精确CI待核。 Koma 59a1edb精确CI40784063216成功。 MH1234筛选0.1.6本地候选在237具名验证；源已公开且精确CI成功，公开WASM固定真实HTML回放通过，公开实体未新Native验证。设备原宿主、源包及数据已恢复释租。 UUID设置候选已补宿主能力声明与ABI，本地执行检查及同签release构建通过，237 Native待验。 NNHanman真实搜索错误已以生产WASM定位为声明分页但缺next链接，v5候选待237验证；MangaDex原生错误与合法重入已有节点证据，画面待亲审，不称全部消费者通过。 NNHanman候选在237真实love搜索列表不再报错，设备实体与冻结相等；源已推，公开CI待核。MangaDex旧截图路径误配导致画面无效，修正场景中；原包、五份数据及电源已恢复，实体字节仍待补核。 NNHanman源精确CI成功，公开WASM真实HTML搜索、分页及Header/schema具名通过；公开包未新Native验收。237原NNH/MD实体已与备份一致，MangaDex错误画面正在重验。 237 MangaDex UUID非法输入错误画面及禁用保存已亲审，合法值保存重入已核；真实章节feed消费仍待验证。Host提交已推、精确CI待核，原包、数据及设备已恢复释租。 237 MangaDex同作品保存真实组UUID后目录从22章变15章，保留其他组章节；真实feed重放确认排除7章，旧章exact请求仍可取，非设备exact阅读。原宿主、源包及设备恢复；源提交推送中。 MangaDex公开WASM真实feed重放确认15保留、7排除及旧章exact未过滤可取；公开包未新Native。 237繁中MangaDex候选已有库作品按真实组UUID过滤，目录由49章变0章，具名结果已核；公开包Native及其他语言未外推，设备恢复中。 繁中MangaDex源提交c4daf043已推，精确CI进行中；先前候选实体与冻结一致及原状态恢复已由Root核实。 繁中MangaDex公开包CI及真实feed重放已核，公开包未另Native；英文候选已修分页过滤组合，真实响应执行通过，237 Native及英文独有消费路径待验。 237英文候选已有库作品真实组过滤已核，原包数据和设备恢复；英文源提交及CI成功。较大结果集首卷封面存在遗漏，新候选已补全，待普通设置与目录回验；搜索转义仍待后续核实。 237英文首卷候选开关保存重入、真实组值及首页封面具名已核；独立Latest菜单未打开，仍未Native验证。原源包、数据及电源已恢复释租；候选尚未提交发布。 英文首卷0.1.22已公开，公开WASM按真实响应核Latest、Home及排序覆盖；公开包未新Native，独立Latest随新会话验证。 237英文023候选在已保存首卷和组设置下独立Latest具名显示，带引号搜索实际请求成功；未逐个验证全部封面，公开022未另Native。恢复已由Root独立核实；023已提交推送。 MangaDex英文023搜索已推且精确CI成功，公开WASM真实响应重放已核；两场原包、五份数据及电源恢复已独立核实。英文WEBTOON、动漫屋及嗨皮同类候选待237验证。 237三源候选已普通导入并核实体，正在验证搜索。 237动漫屋及英文WEBTOON搜索具名已核；嗨皮本次域名解析失败，未证站点停运。四源公开包已恢复发布并核实体；原CI因发布步骤HTTP500失败，设备原状态已恢复。下一批搜索候选待审及Native。 237快看、漫画人及MangaBz引号搜索有结果；CManhua引号空结果、普通词有结果。诊断日志读取被自动审批拒绝，未推HTTP状态；设备恢复已独立核实，源提交已推。 四源会话原宿主、源包、用户数据及电源恢复已由Root独立核实；源提交已推，精确CI进行中。 四源精确CI成功并公开，索引及包实体已核；公开WASM与设备冻结实体不同，未另作公开包Native。 包子候选进入首页即触发站点验证，新转义查询尚未发出；原包与会话身份已恢复。 包子原包、原路径、会话及用户数据已逐字恢复，设备休眠并释租；首页挑战前新查询未发出，搜索未验。puredecode源提交已本地完成，推送进行中。 包子纯decode提交及公开实体已核，搜索Native仍未验。NamiComi简繁当前未实现参考筛选，正在核对宿主筛选适配及真实标签接口。 NamiComi动态筛选宿主已完成首次构建，简繁源候选已核真实标签及默认请求；237尚未导入源候选，设备验收未开始。 237简中NamiComi动态标签包含和排除已取得不同真实目录结果；保存重入、忽略恢复、繁中与设备恢复仍在核验。 237简中包含、排除、重入及忽略恢复已核；繁中目录和动态组、独立搜索筛选具名已核。设备恢复及公开交付尚未完成。 237原包、六份数据及电源已独立核实恢复并释租；宿主提交已推，精确CI进行中，两源提交待完成。 NamiComi宿主及简繁源精确CI、公开索引和包实体已核；公开WASM与设备候选不同，未另作公开包Native。NoyAcg搜索筛选候选已冻结，237验证中。 237独立搜索被拒，HTTP状态和原因未知；三项筛选可见但未修改，消费及重入未验。原本地源、六份数据及电源已恢复释租；旧宿主筛选兼容正在修正，首候选未公开。 Komiic候选普通引号搜索自然显示空结果，不冒命中或HTTP200；NoyAcg兼容修正与Komiic提交已推，精确CI进行中。 237 MH1234本地候选动态题材恋爱选择、普通重入及重置具名已核，原包、数据及设备已恢复；候选尚未公开。 MH1234 0.1.7已公开，公开WASM真实HTML回放与设备候选一致；公开实体不同且尚未另作Native采用。 MangaBall参考筛选仅搜索消费，本地候选默认请求保持；一次真实组合请求返回403，原因未知，未重试或改请求身份。真实结果、Native及公开交付未验。 NoyAcg与Komiic源精确CI及公开实体已核，公开WASM受控回放通过；公开实体未另Native。NoyAcg设备搜索被拒原因未知，Komiic设备引号查询为空且HTTP未观测。 MangaBall与繁中WEBTOON候选已推，精确CI待核；237 WEBTOON筛选界面和选择已观察，但分类请求未证实，原包及设备状态已恢复。MangaBall真实组合仍仅有一次403反例。 两源精确CI及公开实体已核，公开WASM受控回放通过；公开实体不同于设备候选且未另Native。MangaBall真实组合403及WEBTOON设备分类请求未独立观测的边界保持。 漫画柜本地筛选候选核参考空查询及默认请求兼容；真实排行请求TLS失败，站点结果、Native及公开交付均未验。 237腾讯动漫候选恋爱筛选与官网具名结果对应，重入和重置已核，原包数据及电源恢复；候选尚未提交公开。 腾讯动漫候选已本地提交，向源仓推送被自动审批拒绝；CI及公开尚未开始，既有237具名结果保留。 腾讯动漫提交在核实持续推送授权、公开仓及精确提交范围后已正常推送，精确CI待核。 237杂志迷分类候选与真实官网具名结果对应，保存重入和重置已核；原包、数据及设备已恢复，候选尚未提交公开。 杂志迷候选已本地提交，推送被自动审批拒绝；CI和公开未开始，既有官网及237结果保持。 腾讯动漫精确CI及公开实体已核，公开WASM对真实保存页面回放与设备候选一致；公开WASM不同候选，未另Native。 237漫小肆候选韩国分类与官网具名结果对应，封面、续页、重入和重置已核；原包数据及电源恢复，候选尚未提交公开。 漫小肆最终候选将新域限定于已实证封面，正文域边界保持；真实分类回放与设备候选相同，但最终实体尚未Native或推送。 237 92漫画候选儿童分类与官网具名结果对应，重入和重置已核；原源包、数据及电源恢复，候选尚未提交公开。 92漫画候选已独立本地提交，与漫小肆提交等待Root统一审查推送，均未公开。 HentaiFox公开0.1.2源码在目录和详情消费短标题设置；本次首次真实目录请求TLS失败且未重试，237基线未安装，真实站点及Native消费未验。 92漫画单独排序的真实站点请求及WASM回放已核，未选筛选路径保持；排序操作尚未Native验证。 杂志迷精确CI及公开WASM分类回放已核；公开实体不同于设备候选，未另Native。色漫网一次不同UA请求返回站点错误页，不能代表源同身份或全站状态。 92漫画儿童分类真实第二页单次请求403，原因未知且未重试；首页和next游标结果不代替第二页验收。 92漫画和漫小肆精确CI及正式包公开回放已核；公开WASM未另Native，92儿童第二页403原因仍未知。 237 MangaBz候选动态筛选及组合结果与官网具名对应，重入和重置已核；原源包、数据和电源恢复，候选未提交公开。 MangaBz具名候选已独立本地提交，尚未推送公开。 237 CManhua候选筛选选择、重入及重置已核，官网两种状态首屏结果相同；真实第二页未验，原包数据与设备已恢复，候选本地提交待推。 爱看漫与漫画160的参考分类筛选差异已定位，真实分类路径尚未验证；MangaBz和CManhua候选已审，正式推送进行中。 MangaBz与CManhua正式源包已公开，保存的官网页面回放与设备候选结果一致；公开WASM与设备候选不同，尚未另做Native验证。 漫画160分类候选在237具名验证日韩分类、重入和重置，原包、数据及电源已恢复；候选尚未公开，自然验证窗口未出现。 漫画160分类已独立本地提交，尚未推送公开。 再漫画本地候选周榜与连载筛选、重入及重置具名已核，原包数据及电源已恢复；候选尚未提交公开。 再漫画最终候选已独立本地提交并修正分类分页，最终版本未另作Native，尚未推送。 MyComic参考筛选差异已定位，真实筛选与Native未验。 Komiic动态筛选候选真实标签及回放已核；237首页无法连接，筛选未进入，原因未知。原状态已恢复，候选未公开。 漫画160与再漫画源提交已推，精确CI成功；公开实体及WASM回放正在核对。 漫画160及再漫画公开实体已核，公开WASM按真实保存响应回放与候选数据相同；公开包未另Native，再漫画真实末页未验。 快看筛选候选恋爱分类、重入和重置已在237具名验证；原状态已恢复，候选未公开。 快看筛选已独立本地提交，尚未推送公开。 AsmHentai参考筛选与当前官网标签结构差异已定位，筛选尚未实现及真机验收。 XCOMIC简繁参考搜索筛选差集已定位，具体API与默认值仍在核。 AsmHentai动态标签候选真实页面回放及237具名筛选、重入重置已核；原状态恢复，候选未公开。 AsmHentai标签和排序已独立本地提交；真实Latest页回放已核，尚未推送公开或作该路径Native验证。 Zero分类候选在237具名验证战斗分类与重入，原状态恢复；候选尚未提交公开。 Zero筛选已独立本地提交，尚未推送公开。 快看及AsmHentai源提交已推，精确CI成功；公开实体正在核验。 快看及AsmHentai公开实体已核，公开WASM对真实保存页面回放与设备候选数据一致；公开实体未另Native。 XCOMIC简中排序候选在237具名验证、重入重置及恢复；动态标签、繁中Native和发布未完成。 XCOMIC简繁排序已独立本地提交，尚未推送公开。 Zero和XCOMIC排序源提交已推、精确CI成功，公开实体正在核验。 Zero及XCOMIC公开实体与具名真实响应回放已核；XCOMIC繁中仅核实体，未冒繁中Native。 XCOMIC繁中公开0.1.8实际导出filters=false，排序入口不可达；修正候选尚未验证。 MangaDex简中状态筛选候选在237具名验证并恢复；繁中Native及其他参考筛选未完成。 MangaDex简繁状态筛选已独立本地提交，尚未推送公开。 XCOMIC繁中019修正候选排序入口、消费及重入重置已在237具名验证并恢复；候选未公开，动态标签未实现。 按用户要求停止新增筛选测试，英文MangaDex当前场已恢复；候选WIP保留。 英文MangaDex搜索筛选具名子范围已公开交付，公开真实响应回放与237候选一致。 简繁MangaDex状态筛选及XCOMIC繁中导出修正已推并通过精确CI；原候选及设备证据保持范围。 Zero默认域发现已交付并具名验证；旧身份在现站的具体映射仍未知，现有旧域失败不证明旧作品映射失败。 WEBTOON作者附言具名普通路径准备验收，尚未发源请求。",
        "公开LINE WEBTOON繁中010 ZIP/WASM实装与公开一致、正常c274宿主；1797开启保存重入true，1805同第一章60/60末页完整作者文字；1809关闭保存重入false，1811/1812同章59/59末页漫画图，Root亲审。仅作者附言消费者具名通过，不外推最高画质、编号或其他源。1806误开搜索筛选未改作者设置，非成功证据，1807/08恢复源页后1809正式关闭。1812 registry/reader/settings不同、其余三域同；原019目录导入时删除，1813精确四成员恢复准备中，lease f797a065有效。",
        "1813原019四成员与1785一致；1814六JSON逐字一致、原db31安装成功；1815本轮候选目录及下载不存在，SLEEP/120000无override，lease f797a065于05:43:31 released且status读回。证据 category-membership对应run。",
        "固定949完整官方归档4285个kt/kts与tree blob全同；原矩阵25个未匹配行按已知域及别名查全文未找到可确认同站参考，未发现可证普通设置遗漏，不等于证明绝无上游。证据 all85-source-settings-comparison.json对应25行fixed949FullTreeAudit20261030及 upstream-settings-reference/keiyoushi-949-reference.tar.gz。",
        "XCOMIC简繁当前仅有既有版本清理，缺参考自定义标题删除规则；现有SDK/Host无可复用Java正则执行器，Rust regex与参考表达式不完全等价，正在核适配及其他普通设置，字段尚未实现。默认标题边界保持。",
        "固定949另24条参考模块及manga18/sinmh/mccms、KeiSource继承链未发现普通偏好，单一baseUrl未声明镜像或自定义URL；H-Comic getInt为数据解码而非偏好。逐项见 .hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json 的fixed949InheritanceAudit20261030；外部生成器内部未核，不称Native验收。",
        "34行 currentSettingsConsumerAudit20261030见 .hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json：固定949 MangaDex三语言includeUnavailable默认false开关未提供，简繁查询固定0并过滤isUnavailable，需核不可读章目录及点击合同；包子CHAPTER_ORDER与BAOZI_BANNER偏好未迁，涉及章身份/图片处理及当前挑战；漫小肆参考两镜像，当前无镜像，死域与身份待证。其余已列消费者/默认差异及具名证据；敏感凭据和漫画柜成人VIEWSTATE不开放。保各源WIP，本轮未改产品或设备。",
        "source_terra正在补XCOMIC简繁去重/版本分组设置：按当前源码保简中去重true、繁中false，两版分组默认false，章节ID与进度保持；不称参考默认相同，尚未构建或设备验收。自定义正则仍缺。home_terra核MangaDex不可用章目录及点击合同，未知不等于阻塞。",
        "Host会并回远端缺失的已存章，XCOMIC仅切去重API会使旧库重复章仍显示；先交独立版本分组，去重差异待处理，不加全量双查、不改变保留进度合同。MangaDex includeUnavailable开→关正在核源侧excludedChapterIds适配，候选已构建、受控WASM通过；唯一真实feed49章不含不可用章，不称真实标识或Native已验。",
        "固定949 DEDUPLICATE_CHAPTERS默认true；现简中uniqList/1000、繁中fullList/100，Host保留库内缺席章，切uniq不能保证隐藏旧库重复，字段未提交发布，完整差异 /private/tmp/xcomic-dedup-group-candidate.diff。GROUP_BY_SOURCE默认false，简繁独立候选已构建，受控WASM保各自默认请求/data，显式分组保ID并按版本排序；真实Native及公开待核。",
        "MangaDex三语言includeUnavailable修正独立本地提交d739904，未推/公开/Native。能力门槛下复用feed生成excluded IDs，真实当前Host合并函数+生产WASM核开→关旧行消失且模拟进度原对象不变；黑名单并集、失败不返半排除、旧Host原行为保持。当前Host必要query含unavailable元数据，默认可见章保持，可能增分页。唯一真实公开繁中feed200共49章、无isUnavailable，开关均49，不冒真实标识/Native。XCOMIC简繁候选普通导入且实体匹配；1823误开筛选未改值，正在按本源入口恢复，分组未验。",
        "d739904详细证据 .hvigor/outputs/user-flow-audit/source-settings-repair/mangadex-unavailable-real-feed-20261030-receipt.json 及 /private/tmp/koma-md-unavailable-replay.mjs；三源生产参数构建通过，原英文README WIP保留。",
        "MangaDex本轮稳定证据索引：.hvigor/outputs/user-flow-audit/source-settings-repair/mangadex-unavailable-20261030/evidence.json；同目录含受控WASM及原Host合并、旧Host默认对照、真实feed脚本和构建日志，真实49章无不可用目标、Native未验。",
        "XCOMIC分组5c1f378已推，精确CI40967606642进行中。237简中1829 GROUP_BY_SOURCE true保存重入，1832 BERSERK真实13章，1833源目录正序Madex 382/381/380/379后Mpark 382/381/380，Root亲看；繁中Native未跑、false仅旧/新生产WASM受控对照。1816原简017/繁016，1836八成员逐字同；1837六域对1816全等、db31 install success；1838两候选及下载消失、SLEEP/120000无override，lease07f2ddf6于06:40:40 released/status读回。证据category-membership/source-settings237-xcomic-group-*。DEDUP及Host保留章语义、自定义Java正则差集待处理。",
        "Root独核1829保存重入、1833真实13章正序分组两图；未点章，false仅WASM，繁中未Native。1836八成员、1837六域及原db31、1838清理/电源与lease释放已核。source master已推d739904/b7e56bf/5c1f378，精确head 5c1f37889e8580bace76649cfe9c97dad63d02b1 CI40967606642 in_progress，见 source-settings-repair/source-settings-final-20261030-ci.json。",
        "XCOMIC已存真实单GraphQL operation多个根字段返回multiple root fields not allowed，见 source-settings-repair/xcomic-probe-batching/five-original-fields-one-request-{request,response}.json；不能依赖合并双根解决完整目录和去重差集，不绝对断言未来所有形式。两个单根查询仍可行但需各自fullList/uniqList分页、增加版本请求，须处理保留章excludedChapterIds及默认请求成本；本轮无新请求/源码/设备操作。",
        "精确run40967606642 head5c1f37889e8580bace76649cfe9c97dad63d02b1 completed/success，唯一build job123775965290全部成功含原子发布；公开索引/实体Root正核。XCOMIC去重正在实现两个支持的单根查询遍历必要元数据并输出真实ID差集，不重复225 probe，尚未构建/验收/推送，不影响已验分组冻结。",
        "release sources-5c1f37889e8580bace76649cfe9c97dad63d02b1 target同提交、非draft；MD三语言0.1.25/0.1.11/0.1.11及XCOMIC简繁0.1.9/0.1.10五包已下载，GitHub摘要、index/manifest版本与相对路径核对。证据 source-settings-repair/source-settings-final-20261030-ci-complete.json及source-settings-published-5c1f378/{release-metadata,index,entity-check}.json。公开WASM不同候选，info/settings ABI正在核；MD真实不可用目标缺样本/Native未验，XCOMIC去重尚未发版实现。",
        "公开五包ABI结果 .hvigor/outputs/user-flow-audit/source-settings-repair/source-settings-published-5c1f378/abi-results.json：三种MD includeUnavailable均toggle false、旧Host不显示；XCOMIC简繁GROUP_BY_SOURCE均toggle false；get_settings零HTTP。仅证明公开WASM info/schema，不冒feed或公开包Native。",
        "source-settings-repair/xcomic-dedup-real-single-roots/：BERSERK aerk8成员8r2va原身份单次metadata POST HTTP200，确认父作品aerk8、公有normal、英文390章，非中文源Native；同版本uniqList单根首页Mac匿名精简字段查询一次403，Referer https://xcomic.me/、Origin https://xcomic.me，curl可能自行加Accept；与源原具名完整查询不相同，不称完整Native请求相同、不推翻既有Native目录成功。按约停止，fullList未请求、不重试，原因未知。简0.1.10/繁0.1.11仅本地，受控Host合并通过，真实去重/Native/公开未验。",
        "候选移除精简FULL模板，改由现有具名完整单根常量替字段和类型；重新编译及一次受控WASM+Host关键链通过，真实去重/Native/发布未验。",
        "简0.1.10/繁0.1.11去重候选复用原完整单根query，本地构建、受控WASM+实际Host合并通过，不重发Mac 403试验。237 lease aa28f67b，1839原六域及简中四成员基线/AWAKE86400000，1840正常c274安装、1841本地导入选择器；仅核简中默认去重请求链，不重复分组或跨语言、不点章。Native未完成、未提交推送。",
        "简0.1.10/繁0.1.11受控生产WASM+实际Host保留行合并核202→2/200排除、SOURCE_INCLUDE并集、关闭恢复、旧章/页与分页失败原子性。237简中冻结665157…/WASM1cc57…，1845/1847 BERSERK 13/13，1848 get_chapters op235完成4705ms、窗口9个HTTP200；日志无请求body，不能直接证明full字段，未自然命中重复，不称实机隐藏通过，繁中Native未验。1850原4成员、1851六JSON同1839及db31安装成功；1852清候选/下载、SLEEP120000无override，lease aa28f67b 07:26:39 released/status读回。证据 source-settings-repair/xcomic-dedup-wasm-native-20261030.json 与 xcomic-dedup-wasm-host-exec-20261030.mjs。提交公开待审。",
        "XCOMIC去重f306a8fe586c56475acb5954b9daf7d08cc3ab39已推source master，精确CI40974179677 in_progress；公开尚未核。已交付MD三语言includeUnavailable和XCOMIC简繁分组对应矩阵当前状态已校正，旧审计文字保为历史。",
        "f306a8fe586c56475acb5954b9daf7d08cc3ab39精确CI40974179677 completed/success，job123798016729含原子发布成功；release428500991非draft、target同SHA。公开XCOMIC简0.1.10/繁0.1.11及index已核摘要、大小、manifest/ABI版本及路径；公开WASM get_settings DEDUP默认简true/繁false、旧Host不显示且零HTTP，GROUP false。证据 source-settings-repair/xcomic-dedup-published-f306a8f/{release-ci-metadata,entity-check,abi-results}.json及abi-execution.mjs；既有候选Native范围冻结，不冒自然重复隐藏或繁中Native通过。",
        "包子参考CHAPTER_ORDER通过标题追加URL改变章身份，现Host按ID合并，原样迁移影响旧进度，兼容方案待核；BAOZI_BANNER需Reader图片解码/识别/裁剪/重编码，现源URL/header接口不能单独承载，不能只补schema。本轮无源修改/网络/设备。",
        "java_regex 0.1.0独立执行反例：合法200层分组包a，Java17 replaceAll返回空而该库replace_all返回a；私有固定深度/预算超限当false且公开String返回不能识别，不改依赖不能称完整Java合同。证据 /private/tmp/java-regex-contract，生产/锁未动。",
        "漫小肆参考备域rank/book281/chapter9821各HTTP200，60页描述及首图JPEG200；候选默认主站不变、固定ID保留，但需将此前仅封面jjmhw11扩至精确正文host，Root已问用户待决定。候选未采用未提交，稳定证据落盘中。",
        "稳定合同证据：.hvigor/outputs/user-flow-audit/source-settings-repair/java-regex-contract-20261030/{Cargo.toml,Cargo.lock,src/main.rs,result.txt}；漫小肆备域候选及真实响应、回放脚本、构建日志见同父目录mangaxiaosi-mirror-20261030/evidence.json。候选未采用，用户决定待复；原临时证据及边界保留。",
        "TeaVM路线仅非编译核对：自有classlib非直接OpenJDK，现WasmGC后端需JS runtime；Koma当前WAMR未启GC/异常且WASI/多模块关闭，不能直接接入、不改生产runtime。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-teavm-regex-20261030/assessment.md。",
        "包子CHAPTER_ORDER fragment只用于身份，参考正文保section/current固定0；现大象24个重复ID组的title/path/pages相同，缺真实不同section样本，不冒错读。旧持久信息无section，需唯一映射方案才可保进度。",
        "包子横幅拟保原下载字节/hash，仅派生处理；采用加法能力协商以兼容旧Host、无声明及未启用场景。source_terra准备候选，尚未采用或提交，默认及真实横幅正样本未决定/未验，不称已实现修复。",
        "包子横幅完整本地候选：Root审代码并修原图替换key竞态及LOCAL下载绕派生，Host release编译通过HAP 7dd153…；源WASM 735e54…能力/schema/description/descriptor及生产检测器受控模板、真实负例、缓存协调执行证据见 .hvigor/outputs/user-flow-audit/source-settings-repair/baozi-banner-candidate-20261030/evidence.json。真实横幅正例和Native未验、源码未提交推送；源WASM含原搜索WIP及版本回退，非可发布实体。默认保原图手动开启或参考默认普通的具体选择已询问，尚无答复，不视为采用。",
        "TeaVM 0.13.1非GC Wasm实际编译运行200层分组replaceAll单例，与Java17该例一致但不证明完整兼容；真实生成物含teavm命名空间5 imports及main，与Koma ABI不同，当前宿主不能直接使用，未认定永久不可行。0.14移除旧后端及GC/JS限制独立，不称0.13需GC。精确SHA、官方来源及fixture/命令见 .hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-teavm-regex-20261030/assessment.md；未改runtime或生产锁。",
        "用户本轮直接决定“那就默认开启”，采用包子横幅普通默认；schema、缺省请求及Host未存key语义已调整。候选source0.1.15 ZIP802be9…/WASM05715d…，release HAP f6d2bf…验签同db31；237 lease20261030-012643-dd9bbeac，baozi-banner237.protocol.json / source-baozi-banner场景001唤醒及基线进行中，Native未验。漫小肆原问题仍待答。",
        "001原BAOZI_BANNER key缺失；006普通导入015、007实装WASM匹配；014 Native默认普通及说明Root亲审；016禁用保存、017重入仍禁用且settings值0。008首页自然403及009取消后回Browse保原回执，不称首页修复。新下载仅保包子无凭据query的公开原图URL，原文件/hash不变；完整旧下载不回填，旧manifest无URL仍原图。新同签HAP b30ce… 019安装success；受控fixture未上设备，不冒自然横幅正例/HTTP。237 lease dd9bbeac仍常亮，临时关闭缓存自动清理保护旧缓存；须恢复原absent偏好、原源012/六域/缓存/db31及电源释租。",
        "sources 5b87942b2e137602598816e1995c5db0c668a460已推、CI40990993643 success；公开015 ZIP 1a6708f75fb8f7bf6652acb0e76e8c396c7b979cf15094f79bbeeb0ac8517467 / WASM dd2661178c73c3628c1af7973ff19bc691decc5adceac5818afe7359c1fa6cbc，/private/tmp/baozimh-5b879-public/实际执行旧Host无描述、新Host默认1及未存1/显式0/1/2一致。公开WASM不同237候选05715，未另Native。Root亲看237受控合成正例关闭保横幅、默认去横幅，不是自然站点正例或首页403解决；设备恢复进行中。",
        "包子横幅公开实体与CI稳定索引：.hvigor/outputs/user-flow-audit/source-settings-repair/baozimh-banner-published-5b87942/evidence.json；原矩阵baozimh行同步源015公开、Host待提交CI、Native受控合成边界，CHAPTER_ORDER仍未完成。",
        "237 source-baozi-banner：014默认普通、016/017禁用保存重入；028受控固定949横幅+真实正文输入保横幅，031缺省裁边、032 JPEG 1500x2798/217213B SHA103481923a762ff7210c4cba42966a11ad28f04ce348ffedd2454957230d2b8a。042菜单时序修正后系统分享面板Root亲审，043分享副本与032逐字一致，044取消后新目录消失仅旧KPgKbO保留。046六域及原cache023逐字恢复，047源012四成员逐字恢复、原db31及斗破1页3%；048 SLEEP/120000无override、偏好absent，lease dd9bbeac released，未动Torii凭据。Kit 12b8c5fee7dab206bf7a112d51ed89120beb2b2c已推main，NextE/NextN默认分享按钮分支未改；AppHost提交/CI待核。受控缓存合成输入非自然网站横幅，不称首页403解决。",
        "App scoped本地提交775bdeb53a6134356ceec21073fbf9d81fb52ed1，12源码/ABI及workflow pin共13文件，尚未推送/CI；Kit12b已推。装机HAP 6d924f12…默认debug签/release build，cert/profile同db31。候选索引 .hvigor/outputs/user-flow-audit/source-settings-repair/baozi-banner-candidate-20261030/evidence.json已补Native及恢复，017实际路径disabled-reentered-017。",
        "Host775bdeb及docs8aa21a80c1ba2e085ef643d004c89422ddde8702已推，精确CI40993971192 completed/success；Kit12b远端已核。包子横幅源公开、受控Native/分享及恢复已核，真实自然站点正例及相册保存未验，首页403仍未解决。CHAPTER_ORDER固定949、当前生产身份、三调用方及同slot歧义见 .hvigor/outputs/user-flow-audit/source-settings-repair/baozimh-chapter-order-identity-20261030.md；默认关闭，歧义需产品决定，不称无损兼容或完成。",
        "用户本轮明确CHAPTER_ORDER歧义时保留旧目录和进度、本次刷新失败。Root实施Host严格身份协调、不改排序或首次阅读；source_terra实施源default0及featuregate 0.1.16候选。少量生产helper执行已过，尚未构建或Native；原横幅CI成功保留。",
        "Host协调、真实详情失败回退及真实书架更新失败回退已执行：歧义不写库/snapshot，显式失败及静默后台均保原内容。release同debug签HAP 8c9fe79e…已在237安装；源016隔离v2 ZIP20ac055c…/WASM f27d732d…受控WASM门槛、两模式及完整title已核。普通导入/Native设置验收中，未提交推送；lease20261030-031322-27a5a243常亮，六域及原012基线已备，结束需恢复db31/源012/六域/睡眠。",
        "008默认0、009三参考选项、011保存1、012重入保持；014缓存库详情696及原6/24，016显式刷新自然403进入自动验证，017自动关闭后UI 697/697及新简介状态，Root亲审。018原库696存章ID/isRead/pages/pageCount全保，reader逐字同基线，sourceMetadata/settingsFingerprint推进；持久合同只enrich匹配旧章，库696/UI697正常，不称库加新章。19续读进行中；真实歧义/强力模式Native未自然命中，生产WASM及实际详情/Library方法受控执行已核。源016提交推送及设备恢复进行中。",
        "020原001章6/24真实图片Root亲审，019首帧spinner不计通过；021原db31安装成功、源012四成员及六公共域逐字恢复，022原App普通启动继续斗破1页3%、SLEEP/120000无override，lease27a5a243 released。Host本地提交b138a8a4fa3404450d48c868722dcd0f0d47ceb5待推CI；源0111c1a7650897181bb26e9dbdce151da9e697fb已推、精确CI40998231797 success，公开WASM实际执行但不同设备候选，不冒公开Native。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/baozimh-chapter-order-016/evidence.json及native-catalog-result.json。",
        "Host b138及docs随Koma head dde3f68d15618c86b00dbcf41c74a30d3e1f46cb已推，精确CI40999264229 completed/success；源0111及既有237具名验证与恢复保留。",
        "用户本轮反馈源码构建仍提示漫画人需新版Koma。isSourcePackageMinAppVersionSatisfied比较运行安装包bundleInfo.versionName与源minAppVersion，等号-pre不满足正式；当前AppScope 0.1.3/code4，koma-sources/build.sh第93行漫画人最低0.1.4。未读取用户实际安装包版本，未改版本/源门槛/tag或发布。",
        "237漫画160列表50本有数据、首屏6封面均占位；日志图片GET403，非解码失败，正在核请求身份。197普通get_pages/原图network_error，跨章Native尚未验成。两设备均持有效租约，未恢复。",
        "237漫画160 0.1.7参考头候选封面先3/6后自然5/6实图，同一斗罗正文1/26显示，最后1项未确认，不关闭；source owner继续。App版本声明同步0.1.4/code5解决当前源码0.1.3被漫画人min0.1.4挡住，未降低源门槛、未tag发布，用户实际安装包未知。",
        "237原015首屏六封面占位、原生图片403；本地017候选按固定参考补图片Referer/Origin，同列表先3/6后正常返回5/6实图，余1占位原因未绑定；斗罗大陆详情1103章及正文1/26实图可见。另有非具名2300999，不推定作品或站点原因；候选未提交公开。证据category-membership/mh160-cover-{observe-20261030-007,candidate-20261030-016,reader-20261030-018,return-candidate-20261030-020,image-log-20261030-019}。022原包四成员、023六域全等；024清候选、SLEEP/120000无override，lease390e46df released，原HAP未变。",
        "漫画160 031临时受限关联首屏《斗罗大陆2绝世唐门》占位与同图片请求2300028，未取得HTTP响应；其他5张可见实图来自已有成功缓存。033原015四成员、036六域与025基线逐字同；原db31降级安装被OS code9568263拒绝，035同签无诊断27f332 0.1.4/code5安装成功、书架继续斗破第1页3%；036唯一候选/下载清理、SLEEP/120000无override，lease886f9fef released。原HAP未恢复，当前为0.1.4候选，不冒原版恢复。",
        "漫画160 db1e6ad精确CI41005769688 success，公开index 0.1.7、ZIP f1e4a8f0bad1f01c0372bcfdb3b487adde509edc60c978178e8d5e2e4636e160与release digest一致，WASM 3dd020eda5d6fbb02da12f761370711b881e48099da185f474b172b9bfdad75b；/private/tmp/mh160-db1-public/wasm-contract.json执行imageRequest=true、原URL及参考Referer/Origin、零HTTP。设备候选5/6实图及同作品正文1/26已核，剩具体一图超时保留，不冒公开WASM Native。",
        "漫画160已存官方移动页《斗罗大陆2绝世唐门》封面src稳定hash与237 031失败的7a43e1fd25131834一致；Mac同公开URL携参考Referer/Origin、无Cookie/无显式UA单次GET 20秒curl28、无HTTP及0字节，未重试。支持该URL本次跨客户端超时，不判DNS/TLS/服务器根因或全站故障；证据 /private/tmp/mh160-11140-image-url.txt、/private/tmp/mh160-11140-control/。",
        "章节续读：Zero/Pixiv/MHR/Iqiyi/XCOMIC六源合同候选待审发布，MangaDex/Nami/妙趣复杂组织未安全统一，不称所有源已补齐。漫画160第三本封面hash与031匹配，同URL Mac带Referer/Origin、无Cookie/额外UA单次GET 20秒curl28、0字节无HTTP；/private/tmp/mh160-11140-control及image-url.txt，不归因全站或DNS/TLS。全首屏403缺头修复已交付，具体单图外部超时保留。",
        "sources 1f119efa451004dc4ef4f476c73b5cc123be32ac精确CI41010435758 success；公开6包digest/manifest/index及生产WASM执行已核。爱奇艺及XCOMIC双源最低App0.1.4、MHR原为0.1.4，Zero/Pixiv保原；Zero真实保存HTML、其余受控WASM新旧Host对照，不冒Native。证据 /private/tmp/koma-chapter-contract-public-1f119ef/identity.json及各-result.json；多组未核差异保留。",
        "Root审14 metadata+6显式组合同共20源公开交付冻结，Native范围依既有具名证据不外推。source_terra核XCOMIC规则Host执行：官方公开ICU API无uregex、固定参考Android用ICU，正在做本地静态ICU/Worker既有RPC适配候选；尚未实现/构建/Native，不新增UI或改默认。漫画160首屏403缺头修复017已交付，单张同URL跨客户端超时原因未知；公开版本工作树残留已精确对齐017、无其他WIP丢失。",
        "Koma原仓候选接固定官方ICU74.2静态正则、独立NAPI async worker及既有java_regex RPC，Release HAP构建完成；首版约51MiB、原约21MiB。Root要求裁去正则不用的ICU数据，保Unicode、字边界及规范化等实际依赖；未安装/验收/提交发布。进度提交1615c585已推，功能代码995精确CI仍success。",
        "237 API26 Host de422及简中本地源0829：012非法(显示Invalid regular expression且保存disabled；013有效(BERS)、014保存、015重入相同；016真实热门12本中BERSERK显示ERK。018原包四成员等002，019六JSON等001且原27f332安装成功；020清候选/下载、SLEEP/120000无override，lease ceeba62a released。候选未提交公开，API23 Native未验；证据category-membership/xcomic-regex-* 012–020。",
        "XCOMIC正则精确暂存候选简0.1.12、繁0.1.13标准包已构建；旧Host schema同已发布1f119，新feature才暴露空默认设置。WASM受控有效/非法/执行失败保原及其余请求相等；237具名仅先前简中本地0.1.11候选，繁中不冒Native。当前未commit/push，Host交付中；证据 /private/tmp/koma-icu74/release-candidates/contract-result.json、/private/tmp/koma-icu74/release-regex-results.txt。",
        "Host06f18e5f已推，CI41016110323 Linux ICU host configure报C compiler cannot create executables；43a3bbba隔离host CC/flags后CI41016751992仍同处失败，根因未确定。workflow原仅安装xxd，Root e9efcf01补build-essential及输出有效configure错误段，提交推送中、新CI待核。XCOMIC简012/繁013源8文件已精确审但暂存未push，等待HostCI；237非法/有效输入、保存重入及BERSERK→ERK与恢复不重跑。章关系矩阵24单章/明确组及方向复用，不称85全通过。",
        "sources c4b04e940a493ffa931fd31f86e5b7bee6daa1c5精确CI41018356180 success、同SHA release公开；XCOMIC简0.1.12/繁0.1.13及爱看漫0.1.2三包/index/实际WASM已核。简繁公开WASM受控新旧Host及有效/非法/失败回放通过；爱看漫公开WASM info/listings/filters/settings同候选、manifest newest_first。公开WASM不同本地构建，未重复Native；237先前仅简中本地候选，繁中及爱看漫未Native，爱看漫原403保留。证据 /private/tmp/koma-source-public-c4b04e9/{identity.json,contract-equality.json,regex-replay.txt}。",
        "c4b公开证据稳定目录 .hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-ikmmh-published-c4b04e9/，含三正式包、index、WASM、identity及合同对照，脚本已用该路径重跑通过。",
        "Koma e9efcf01707196225061ea762e3be270e3762fc3精确CI41017177110 completed/success，Linux ICU工具链依赖已交付；XCOMIC简012/繁013及爱看漫012公开包CI41018356180成功，稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-ikmmh-published-c4b04e9/。",
        "XCOMIC正则由Host 06f/e9及源0cf/c4b交付；漫画人源最低门槛与当前源码版本由b4/995同步0.1.4解决，未读取用户实际安装版本。原历史反例及具名验收保留，不再作为当前待实现动作。",
        "NoyAcg漏ADULT范围设置隔离4文件commit b854577，push中；默认图片由原capfalse空headers fallback改captrue同URL无headers，absent/both/invalid六业务请求对公开015逐字段等，显式true/false实际消费，已有filters和身份不改。生产WASM受控证据 .hvigor/outputs/user-flow-audit/source-settings-repair/noyacg-adult-016/evidence.json；不冒站点筛选效果或Native。",
        "b8545778e7871b26e7c82c2b6f8a399f9aa08f49已推，CI41021822880 completed/success，release428763807同SHA非draft、0.1.6 index公开；GitHub digest a585e8d6…、正式WASM88841ddd…，对公开015既有受控请求等价。稳定证据 source-settings-repair/noyacg-adult-published-b854577/{evidence.json,verify.mjs}；仅设置合同交付，不冒网站或Native。",
        "本轮实际request_user_input_async提出漫小肆：补首选镜像两参考站、当前默认不变，允许备用站实际正文图片（此前精确域仅封面）；等待答复，不将旧摘要冒原始提问证明，不提前采用。",
        "用户本轮async call_de71d9a10e3c44b9931fec8f045448f6明确“采用完整镜像修复”：补两固定参考镜像、原默认jjmhw2不变，允许备用站实际返回jjmhw11精确正文域，保work/chapter/file归属。source_terra接续原仓016候选及237设置/重入/281旧章9821图像与恢复；候选尚未出，不冒完成。",
        "237 012 settings本源preferredMirror=https://www.jjmh.top，013 layout重入显示相同；016候选ZIP a0656f7c…/WASM397880d0…冻结，005设备WASM一致。原013四成员/六域已备，lease cb954231，001 AWAKE/86400000；正文、恢复、提交尚未完成。证据category-membership/mxs-mirror-{save-20261030-012,reentry-20261030-013,manager-20261030-005}。",
        "237 012/013备用www.jjmh.top保存重入、014榜单10本、015《美麗新世界》281目录262章；018此前0页未下载的44073真实页表228页、首屏漫画1/228可见，首URI www.jjmhw11.top/static/upload/book/281/44073/2623392.jpg，缓存与本次HTTP归属未区分，不冒单图HTTP200。旧9821已有60页未用作冷页证明。020原013四成员及六域逐字恢复，021清临时、SLEEP/120000无override、lease cb954231 released，HAP未换。Root执行candidate-016/verify通过默认行为/旧60页身份/归属；5文件提交a1e6d6e推送中，CI/公开待核。证据 category-membership/mxs-mirror-read-evidence-20261030-018、source-settings-repair/mangaxiaosi-mirror-20261030/candidate-016/evidence.json。",
        "a1e6d6e842160974b86b612067ef183bf2eb3a4b已推，精确CI41027778858 completed/success，release428806163同SHA非draft；公开016 ZIP b83a14c4…/WASM67b9f2f8…，index/manifest版本、原homepage www.jjmhw2.top、newest_first已核。公开WASM基于真实HTML执行verify，默认请求/data、镜像榜单、281/9821 60页及错误归属通过；稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/mangaxiaosi-mirror-published-a1e6d6e/evidence.json。237候选Native及恢复范围保留；公开WASM不同、不冒重复Native。Noy三个api域是否生成普通镜像偏好正在只读核对，不由字符串列表断定缺口。",
        "固定949 SourceProcessor/MirrorPreferences生成器确认Noy/MangaBz普通镜像偏好而非三个独立variant。Noy preferred_mirror默认0 api.noyteam.online，另api.noymanga/api.noy.asia；旧b1与参考v4差异未证兼容，官网+9JS/列表均缺真实bookId，不猜ID或重发login，待官方作品链接/真实成功响应。MangaBz同键默认mangabz.com，另xmanhua/yymanhua，bz/xm/yy身份与各域公开languageCookie须配套；source_terra按保存真实ID一次新备用域GET核身份，不改默认/Host名单/设备。证据 source-settings-repair/{noyacg-reference-mirror-20261030,mangabz-reference-mirror-20261030}/evidence.json。嗨皮/漫画屋/Simply/古见可用性按各原项，不重复算设置遗漏。",
        "MangaBz两个备域已取得同73/MID/235目录；证据 .hvigor/outputs/user-flow-audit/source-settings-repair/mangabz-reference-mirror-20261030/sample-73/result.json 与 sample-73-yy/result.json。完整镜像/按域语言/旧身份方案尚未实施，未称已向用户提出采用问题。",
        "本轮async call_fa5dd72e95e24268a7c241c64012139b用户选“补齐完整镜像切换”：mangabz.com/xmanhua.com/yymanhua.com三站，当前默认及旧进度保持，列表/搜索/正文及简繁跟随，各站独立验证/登录。source_terra已开始源及相关Host/ABI完整实施；不影响冻结的v0.1.4标签，尚未完成验收或交付。",
        "237 category-membership/mangabz-mirror-settings-20261030-009默认mangabz.com；choices-20261030-010三项域名；select-x-20261030-011普通选择/保存/重入xmanhua.com，原繁体开关与说明仍在。Root亲读layout；仅设置语义具名，不冒正文/图片或会话全通过。旧作品正文继续、设备持租尚未恢复。",
        "MangaBz完整镜像011本地候选：默认bz/旧ID，x保存重入、yy繁体保存重入及列表，yy手动网页和旧作品网页、鬼灭235章/旧进度及第23卷1/230具名；015旧卷2/190与025正文画面Root亲看，图片网络/缓存来源未确认、未登录账户。027原27f332安装成功，六JSON对001及原源四成员对002逐字同；028清候选、SLEEP/120000无override，lease d0c8699a据source owner释放。Host新feature及源011尚未提交公开；证据 .hvigor/outputs/user-flow-audit/source-settings-repair/mangabz-mirror-candidate-20261030/evidence.json。",
        "Koma f8bda2277ff0ed9b32934145fd7fe2d4629fb2d0已推，精确CI41042962997 in_progress；koma-sources 6e0d6b85863f544850a627b2fb7f57766e61f4ec已推，精确CI41042955770 in_progress。正式0.1.4已发布事实不变。",
        "Host f8bda2277ff0ed9b32934145fd7fe2d4629fb2d0精确CI41042962997 success；source 6e0d6b85863f544850a627b2fb7f57766e61f4ec精确CI41042955770 success、Release428915480同SHA非draft。公开011 ZIP c4ffaafd2df42bf672e048527e080e5165e4944c6dd9283771e5eba5a81e87c2 / WASM 6761d9f09aa9f3e6a66289dcd9da0b005b317aa72d227276c06f8bbe4809b939；index版本/三origins/default主页正确，公开WASM真实HTML、旧Host回退、旧bz身份、图片referer/按域语言/外CDN不带cookie执行通过。公开WASM不同Native候选，不冒重复Native；账号登录及图片冷网归属未验。新入口需后续含mangabz_mirror_session_v1 Host，已发布0.1.4旧Host仅默认站。Noy 237基线library/reader匹配0条、registry仅015已装无作品ID，待官方作品链接或成功响应。",
        "当前Noy输出/book/id，固定949 getMangaUrl及已保存官网JS路由均/manga/id；home_terra已出017单行修复候选，合成DTO仅逻辑对照、不冒站点。官网客户端新/api/v4/book/random POST单次HTTP200/status=login，表明该入口也要求登录；不把缺ID转嫁用户或重复请求。",
        "用户call99f明确接同站登录入口；017链接修复b296670已推CI41046193778 success；018入口5612d7bcb273fa4bb39c45791220cebcd88bc884已推、CI41049335130进行中。237 Noy008普通源自然显示官网登录页、009菜单网页验证/登录，005/006唯一origin及实装WASM同候选；未输入账号、登录内容未验。011原015四成员及六域全等、012 SLEEP/120000无override，lease73272b93 released。原Noy evidence/session-018稳定记录。",
        "Noy018 commit5612d7bcb273fa4bb39c45791220cebcd88bc884 CI41049335130 completed/success、release428962179同SHA非draft；公开包/索引/manifest仅许可https://noymanga.com，ZIP 681761536ec152a5ae26342e54aacc5a3fcb2219aa6aa726196f7a4dcda43121、WASM ab254b54…；公开WASM受控DTO比016仅网页路由变、API旧请求保持。未冒账号内容验证；237已恢复释租并交用户，登录后内容待账号询问答复。",
        "Noy019 6d5e7ab8f37d935d304b55fda6da8c021f8769cf已推，精确CI41052932223 success并公开；普通词请求不变，引号词不再多反斜线，公开WASM受控执行已核。未重测Native/登录后真实内容，b1/v4镜像兼容未知；证据 /private/tmp/noy-search-019。",
        "Noy019稳定公开实体及精确CI证据 .hvigor/outputs/user-flow-audit/source-settings-repair/noyacg-reference-mirror-20261030/search-019/evidence.json。",
        "237只读状态显示Koma 0.1.4/code5、Noy 0.1.5，未发现Noy书库或阅读状态项；设备端按sourceId的会话计数为0，不能据此断言用户登录失败。设备保持睡眠无输入，lease a4c6364f released；回执 source-web-session-concurrent/noy-state237-{read-001,data-002,session-003}。公开0.1.9 ZIP d966ef52…的minApp 0.1.0与当前Host兼容，现按普通路径升级并保留正式版本，不更换Host、不清写Cookie或其他源数据；升级及入口尚待回执。",
        "237正式0.1.9：005普通导入成功，registry版本及唯一 https://noymanga.com origin正确；006 ZIP/WASM与公开实体逐字相等；010菜单“网页验证 / 登录”，011布局显示NoyAcg/登入，未输入账号。002→012 library、reader、settings、filters、web-sessions五域逐字相等，registry sourceIds相同且仅Noy从0.1.5升0.1.9，Host未换。013最终SLEEP/120000无override，两租约22383f87/758516da released，下载已清；保留正式0.1.9，不回装旧015或覆盖未来Cookie。稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/noyacg-reference-mirror-20261030/search-019/device237-delivery.json。",
        "用户最新明确目前没有Noy账号；不代建账号，237保留正式0.1.9及登录入口，不将未执行的账号内容验收写成通过。"
      ]
    },
    {
      "id": "MANAGER_REFRESH_BACKGROUND",
      "title": "进入源管理页时全表刷新且图标闪烁",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197普通入口及后台发布连续过程已核",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_INDEX_CACHE_REVALIDATE",
        "SOURCE_PACKAGE_ICON_INVALIDATION"
      ],
      "result": "已有缓存首帧修复，设备复验未完成 本轮普通入口连续录屏已审，但视频结束早于后台fetch_ok，未覆盖发布瞬间；正在补录，不能以现有录屏认定后台发布全程通过。 补录覆盖真实fetch_ok：普通浏览→管理→浏览→管理，首屏已有图标，后台发布前后和重入未见全列表清空或图标全闪。部分地址实际失败，不称全部仓库成功或性能达标；原书架与数据恢复、电源恢复并释租。",
      "remaining": "本次197普通入口及后台发布具名范围完成；源包安装性能仍由原事项跟踪。",
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-26T02:00:00Z",
      "reportedAtSource": "用户报告从浏览页进入源管理的转场中出现完整刷新；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T02:48:41+08:00",
      "stage": "具名范围已验收",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/manager-background-refresh/ordinary-entry-through-completion-02/",
        "/private/tmp/koma-manager-background197-recording.json"
      ]
    },
    {
      "id": "TRANSLATION_ENTRY_PLACEMENT",
      "title": "漫画翻译设置入口缺失且位置不合理",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "237普通设置路径已确认漫画翻译入口可达",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "NEXTE_READER_FEATURE_MIGRATION"
      ],
      "result": "237普通路径设置→服务→漫画翻译已实际进入Torii设置，服务页分组及入口已观察；该路由为既有提交，整体翻译迁移与真实译图仍在原迁移事项中。",
      "remaining": "本项具名入口范围已完成。",
      "remainingActions": [
        "本项具名入口范围已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-26T12:00:00Z",
      "reportedAtSource": "用户报告设置中找不到漫画翻译；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T01:18:29+08:00",
      "stage": "具名入口已验收",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/settings-root-04/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/services-05/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-torii-settings-06/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/install-full-evaluation-10/"
      ]
    },
    {
      "id": "SETTINGS_GROUPING_ADVANCED",
      "title": "设置页未分组且高级入口与图标不合理",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197设置分组、高级与关于普通路径已核",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "APPEARANCE_CONSUMERS"
      ],
      "result": "197同签6b53普通设置页上下分组及原卡片、各入口图标已亲审；高级页面只有诊断日志，关于页面显示版本、隐私与开源且无日志。原Reader、Appearance、library及sessions未改；设备会话继续。",
      "remaining": "本项具名设置分组与高级/关于范围已完成。",
      "remainingActions": [
        "本项具名范围已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-26T12:30:00Z",
      "reportedAtSource": "用户要求设置项分组、增加高级入口并检查图标；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T01:46:02+08:00",
      "stage": "具名范围已验收",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-grouping-top-22/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-grouping-bottom-23/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-advanced-content-24/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-about-content-25/"
      ]
    },
    {
      "id": "ENHANCEMENT_SWITCH_VISIBILITY",
      "title": "未选择增强模型时开关不可见",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197未选模型时开关与启用已核",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "NEXTE_READER_FEATURE_MIGRATION"
      ],
      "result": "197普通恢复阅读默认值后模型为未选择，增强开关及模型管理入口可见；点击可启用系统模型。原偏好、阅读状态及电源已恢复并释租。",
      "remaining": "本次未选择模型具名范围已完成。",
      "remainingActions": [
        "本次原用户条件已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-26T13:00:00Z",
      "reportedAtSource": "用户报告未选择模型时图像增强开关消失；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T08:47:37+08:00",
      "stage": "原用户条件已验收",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/reader-settings/enhancement-current-model-row-05/；01 reader.xml与06逐字相同，选中systemCoreVision。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/enhancement-default-reset-model-none-200/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/enhancement-unselected-switch-visible-201/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/enhancement-unselected-enable-202/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/enhancement-unselected-final-restoration/"
      ]
    },
    {
      "id": "READER_SETTINGS_PLACEMENT",
      "title": "阅读器设置与全局设置职责混乱",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197具名验证及提交CI完成",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "READER_SETTINGS_STABILITY",
        "TRANSLATION_ENTRY_PLACEMENT"
      ],
      "result": "此前整理职责但旧菜单仍存在：源码实查阅读设置及全局设置仍将四项页面模式与三项方向分组；控制栏方向菜单已有四种互斥方式。用户再次明确要求按控制栏菜单复用，Root正在修正。 197候选4f66全局菜单实见单页/双页与四种方向；RTL选择后切纵向分页保留休眠RTL，普通菜单恢复原纵向分页及LTR后完整偏好XML键值与基线相等。用户采用名称“分页模式”，两处资源已改并构建中。 最终release 6b53cbe9在197亲审Reader及全局“分页模式”两项、方向四项；连续滚动下单双页禁用且原RTL休眠保留，控制栏原单双页按钮与四方向保留。偏好恢复与基线键值相等。 Koma 2a0c7aebbe998269a113a5730361cc16acca3711已推master，精确CI40733358529 completed/success。",
      "remaining": "本次具名范围已交付；不外推其他阅读器缺陷或未经真机逐一验证的主题。",
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "左到右/右到左/纵向分页/连续滚动是互斥阅读方式；单一选择不得被两个菜单交叉改写。",
        "控制栏单双页与方向按钮保持；阅读设置复用同菜单，方向四项互斥，连续滚动不进入单双页菜单。原旧菜单结构及误改回滚证据保留。"
      ],
      "reportedAt": "2026-10-27T02:45:45.294+08:00",
      "reportedAtSource": "本会话首次可核直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第26437行，UserMessage item.id=01a17988-68cd-7062-b3f5-add1c79b5e06；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T01:16:57+08:00",
      "stage": "具名范围已交付",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/global-two-page-options-05/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/global-four-directions-06/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/global-rtl-selected-07/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/reader-settings-final-menu-14/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/reader-four-directions-16/",
        "https://github.com/honjow/Koma/actions/runs/40733358529",
        "原reportedAt 2026-10-27T00:30:00Z为约值；以本会话直接UserMessage事件替换，仍不排除跨会话更早反馈。"
      ],
      "reportedDate": "2026-10-27"
    },
    {
      "id": "READER_PAGE_SIZE_SHRINK",
      "title": "跨章图片先小后放大，应先按容器约束显示",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197具名连续跨章范围已验收",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET"
      ],
      "result": "197 Blue横向双方向及连续章、MH1234多页RTL、Nemo多页纵向往返具名范围已核，精确CI成功，设备已恢复。",
      "remaining": "本次具名范围完成；不外推其他未知来源或宿主。",
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-27T04:00:00Z",
      "reportedAtSource": "用户报告跨章时图片先缩小再放大；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T07:57:24+08:00",
      "stage": "具名范围已交付",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-scroll-motion-05/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v2-motion-12/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v3-motion-26/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-motion-71/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-observed-72/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-ltr-motion-74/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-chapters-motion-76/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-progress-77/",
        "MH1234新候选run103出现黑屏反例，归READER_MH1234_BOUNDARY_PRELOAD继续修复；不改变本项既有具名结论。",
        "197公开MH1234 0.1.5 run171多页RTL往返跨章：无清空、先小后大或源详情等待，章节和进度对应；不扩原未验范围。",
        "197 Nemo run192完整纵向双向跨章画面连续、章节提示对应；原状态及电源已恢复，精确CI待核。",
        "收口前原结果：原录屏新章节首次显示先窄后扩，同时短暂黑屏；v2两处回翻各有一帧黑屏。v3在197蓝档单页章四次双向跨章录屏未见先小后大或黑帧，返回进度一致。 197分页窗口修复RTL单页章71全帧审查，图片跟随平移，未见先小后大或旧66清屏。 74 LTR往返与76五次连续单页章跨章全帧审查，未见清空或先小后大。",
        "https://github.com/honjow/Koma/actions/runs/40790249371",
        "本会话可核直接反馈：2026-10-27T21:38:25.823+08:00，rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl第51675行，item.id=01a17d95-6795-7952-9be6-50ff47acb399；现有约值无原始时刻依据，可能有更早反馈。"
      ]
    },
    {
      "id": "READER_SWIPE_DIRECTION_MISMATCH",
      "title": "LTR/RTL跨章节滑动方向不正确",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "具名设备路径及精确CI完成",
      "owner": "Root：shared Reader与Host实际手势映射",
      "dependencies": [],
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET",
        "READER_DIRECTION_MENU"
      ],
      "result": "197具名跨章预载、方向和点击路径已验证，App及书源提交精确CI成功。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。",
        "不外推全部Reader或尚未核实分组源。"
      ],
      "reportedAt": "2026-10-27T08:00:00Z",
      "reportedAtSource": "用户报告滑动手势方向与翻页方向不一致；精确时刻未记录。",
      "reopenedAt": "2026-10-30T12:08:17+08:00",
      "closedAt": "2026-10-30T13:47:21+08:00",
      "stage": "具名范围已交付",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-next-swipe-18/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-restore-ltr-19/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/ltr-next-swipe-20/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/restore-sample-original-mode-21/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-motion-71/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-observed-72/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-ltr-motion-74/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-chapters-motion-76/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-progress-77/",
        "197公开MH1234 0.1.5 run171多页RTL往返跨章：无清空、先小后大或源详情等待，章节和进度对应；不扩原未验范围。",
        "197 Nemo run192完整纵向双向跨章画面连续、章节提示对应；原状态及电源已恢复，精确CI待核。",
        "收口前原结果：197单页8页样本：RTL右滑2/8至3/8、左滑回2/8；LTR左滑2至3、右滑回2/8。样本已恢复最初纵向分页。 197分页RTL单页章71：右点击/右滑到下一章第五话，左点击/左滑回第四话，Toast对应；72为第四话1/1、章节4/15。 74 LTR左点击/左滑下一章、右点击/右滑上一章，往返第四话；76五次连续点击至2/15，Toast与章节相符。",
        "https://github.com/honjow/Koma/actions/runs/40790249371",
        "本会话可核直接反馈：2026-10-27T22:29:14.886+08:00，rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl第53925行，item.id=01a17dc3-ee01-7500-818c-21ae2f63a720；现有约值无原始时刻依据，可能有更早反馈。"
      ],
      "evidencePoints": [
        "本轮重开前原result逐字保留：197 Blue横向双方向及连续章、MH1234多页RTL、Nemo多页纵向往返具名范围已核，精确CI成功，设备已恢复。",
        "本轮用户直接反馈LTR/RTL“加载下一张/上一张”的滑动方向仍不正确，质疑固定左往右；精确消息时刻未给，重开时间为登记时间。此前Blue/MH1234/Nemo具名验收证据保留，本次根因及设备结果未知。",
        "用户本轮纠正所指为上一章/下一章，非上一页/上一张；重点查章节关系是否误用显示排序，目录倒序不能翻转阅读顺序。原报告时间及此前验收保留，本次根因未验证。",
        "ChapterListSection排序仅操作slice，不污染原catalog；Adapter.adjacent缺continuation时fallback raw chapterIds，preloadNextUnit缺continuation直接return，source chapterOrder此前仅供首次阅读。候选ReaderChapterSequence仅全目录无显式组限制时按sourceOrder派生chronological，shelf/transient接入，source adjacent/Legacy不再退raw；33相关执行回归及release/debugfalse构建通过。197原包Blue已见next_unit depth2/后续source ready，RTL右滑第二部第四到第五，见reader-continuation/boundary-original-continue-302及boundary-original-rtl-forward-303；不外推漫画160新分支，亦不称用户全部反馈唯一根因。",
        "候选进一步发现持久库数组可能经历史合并而不再保持源序，不能简单反转旧库数组；正在补从完整源目录生成并持久保存阅读序号，尚未验收。",
        "SourceChapterChronology仅完整get_chapters分页终点、无显式组/序且chapterOrder明确时生成source-catalog+readingOrder，持久化现有字段；旧库缺序时后台解析完整目录，当前页不等待，refreshAdjacency仅发布邻章并续预载不重载图片；同卷(卷,章)比较，显式ordinal不与卷/话号混比。关键回归及本地构建通过，197未装新候选。根目录mh160-retained-catalog-chronology.json为早期未含持久数组反例的执行记录，不冒最终after算法，待后继记录取代。",
        "reader-kit 9afdada已推，refreshAdjacency仅刷新邻接/预载，保当前anchor/topology/解码图；Koma workflow已pin。197 boundary-014-install-313安装并启动0.1.4/code5/release/debugfalse同签候选HAP 27f332dd881ab4820dd3487278ae627dc6d75473308bfbd875b718ea572bd57d；临时xkcd候选按sourceOrder无组路径验新ordinal，原源四成员已备，197/237仍持租。版本未tag发布。",
        "完整源目录source-catalog ordinal后台补齐旧库676章；322真实next_unit depth2及两未来页ready。326 RTL 2937→2974→2975并反向返回，连续原片14表全审，无加载面板/空白、Toast正确。328 LTR左滑两次到2974，329左点击两次到2975，330右点击两次回2974；331用户原配置tapZonePreset=right_left、tapZoneInvert=horizontal，329/330动作名写反而非新方向bug，原收据不改。点击跨章原片与恢复仍待；证据reader-continuation/boundary-xkcd-*及xkcd-rtl-chronology-motion-326。",
        "332 LTR+原horizontal反转，2974左半→右半→2975及反向，211帧/6表全审，实际无2976，manifest动作名多算拆页；一进一退Toast匹配、无加载/空白。341 library76与302逐字同、registry与304同、xkcd原4成员337与314同；方向恢复RTL、其他Reader key同331，sessions仅Blue三个updatedAt变化；339/340 Blue第四话1/1亲审。临时包目录/下载不存在，SLEEP/120000/Override10000，lease20261030-041655-fcce974d released。App保无诊断0.1.4/code5 final HAP38d2456b09842e9f8b689dc3cc6f7968416a088be4ca1ea829a0ec4e0389dea5，同db31 cert/profile，不称原HAP恢复。App b4a4f990已推，CI41009239020版本一致性失败因未同步oh-package，补995ba6bb推送中、新CI待；源04fa4a9已推、CI41009585265待。",
        "Koma 995ba6bb101d091c1ba0bab2842ff9a2e5037dc7精确CI41009792919 completed/success、artifact已上传、tag发布job skipped；14源04fa4a9精确CI41009585265及正式实体已核。"
      ]
    },
    {
      "id": "MANGA_TRANSLATION_PREPROCESS",
      "title": "超分与翻译未对预载页预处理",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "237 Torii未来页预处理及设备恢复已核",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "NEXTE_READER_FEATURE_MIGRATION",
        "NEXT_CHAPTER_PREFETCH_REUSE"
      ],
      "result": "237真实Torii当前页及未来页翻页前译图完成，普通往返连续；原App、八份数据和电源状态恢复并释租。",
      "remaining": "本次真实Torii未来页及既有超分具名范围已完成。",
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-26T23:04:28.413+08:00",
      "reportedAtSource": "本会话首次可核直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第23238行，UserMessage item.id=01a178bd-d1fc-7bb3-a537-8a250cce7c96；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T06:57:07+08:00",
      "stage": "具名真实路径已验收",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-preprocess-torii-before-turn-33/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-preprocess-prepared-page-roundtrip-34/",
        "run34录屏SHA256 a16027d8fccd42498cb10e17f3e9079772e8e6f5fb19627ec815ff582f2633f6，123帧全审；当前页及未来第4页翻页前真实ready。",
        "237 run37八份数据与基线逐字相同；38休眠后出现override反例，39清除后SLEEP/120000无override并释租。",
        "原reportedAt 2026-10-27T12:00:00Z为约值；以本会话直接UserMessage事件替换，仍不排除跨会话更早反馈。"
      ],
      "reportedDate": "2026-10-26"
    },
    {
      "id": "PROGRESS_PAGE_READABILITY",
      "title": "进度页被流水账占满且近期问题难查找",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "页面近期问题、时间及时间线具名可查",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "PROGRESS_TIMELINE_THEME"
      ],
      "result": "浏览器已核近期问题、动态计数、已验收筛选、时间来源、证据链接和时间线；原始时间无直接依据的事项显示未核实。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-27T23:39:24.675+08:00",
      "reportedAtSource": "本会话首次可核直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第56518行，UserMessage item.id=01a17e04-2a82-7682-9427-3275adb8a024；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T16:25:56+08:00",
      "stage": "页面具名范围已核",
      "evidence": [
        "原reportedAt 2026-10-27T15:39:00Z为约值；以本会话直接UserMessage事件替换，仍不排除跨会话更早反馈。"
      ],
      "reportedDate": "2026-10-27"
    },
    {
      "id": "SOURCE_HOMEPAGE_MISSING_COPY",
      "title": "Goda网页打开成包子漫画、Komiic无地址提示",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "GoDa、Komiic及主页图标具名范围已核",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_EMPTY_SETTINGS_ENTRY"
      ],
      "result": "GoDa打开正确官网；Komiic 0.1.9普通菜单实际打开站点；197主页地球图标已核。",
      "remaining": "本项具名范围完成；Komiic账户和阅读正文不由本项验收。",
      "remainingActions": [
        "本项具名范围已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-26T23:22:15.532+08:00",
      "reportedAtSource": "本会话首次可核直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第23527行，UserMessage item.id=01a178ce-1a6b-7d73-b99a-fb99dd1909d5；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T04:25:50+08:00",
      "stage": "具名范围已验收",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-public-update-071/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-official-webview-075/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-web-document-receipt-076/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/source-homepage-globe-honkai-45/",
        "https://github.com/honjow/Koma/actions/runs/40742436354",
        "原过程记录：公开索引已核含godamh.com，设备装旧包导致；旧提示已移除 237普通manager更新公开0.1.4，registry hashOk且packageHomepage为https://godamh.com/；普通GoDa源菜单打开WebView，亲审首页-G站漫畫、官方G标及官网首页。更正先前误读：076命令名带#1，实际stdout非空；document_begin、visible、end均matchingDocument、matchesInitialUrl及sameInitialOrigin为true，与071初始godamh.com地址一致。 用户本轮明确要求源右上角主页3W图标改为系统地球经纬线图标；Root实施及设备验证中。 系统globe资源不存在导致首构建失败，改用SDK现有worldclock后release构建成功；Koma fa6e728已推，CI查询中，197图标Native待验。 Koma fa6e728精确CI40742436354成功；worldclock主页图标197 Native正在验证，尚未通过。 197冻结候选63819554普通崩坏3 IP站目录实见23本封面及右上经纬地球图标，用户指定的3W替换具名验证；fa6e728精确CI40742436354成功。 237 Komiic 0.1.9普通源首页有内容，WebView实际显示站方登录页及komiic.cc提示，未见Koma无地址错误；最终URL和登录原因未核，不覆盖全部原失败。原数据与设备状态恢复并释租。",
        "原reportedAt 2026-10-27T15:30:00Z为约值；以本会话直接UserMessage事件替换，仍不排除跨会话更早反馈。"
      ],
      "reportedDate": "2026-10-26"
    },
    {
      "id": "READER_RTL_SLIDER_COUNTERS",
      "title": "阅读方向改为从右到左后，滑块两侧页码不随方向交换",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197单页8页样本RTL页码与方向一致",
      "owner": "Root：197具名样本范围已验证",
      "dependencies": [],
      "relatedItems": [
        "READER_DIRECTION_MENU",
        "READER_SETTINGS_PLACEMENT"
      ],
      "result": "Koma控制栏fixedCounterSides已改为false。197单页8页样本：RTL左8右2，右滑至3/8时左8右3，左滑回2/8；LTR左滑2至3、右滑回2/8，样本已恢复最初纵向分页。",
      "remaining": "本次197单页8页样本范围已验证；其他样本与跨章方向不外推。",
      "remainingActions": [
        "本次197单页8页样本范围已验证；其他样本与跨章方向不外推。"
      ],
      "boundaries": [
        "只改固定左右策略，不改滑块值域、页码格式或其它样式。"
      ],
      "reportedAt": "2026-10-28T10:26:07.824+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第72395行，UserMessage item.id=01a18054-414e-7541-8962-d43d07484b5c；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": "2026-10-28T12:01:20+08:00",
      "stage": "具名样本已验证",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-counters-17/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-next-swipe-18/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-restore-ltr-19/"
      ],
      "reportedDate": "2026-10-28"
    },
    {
      "id": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "title": "通过系统分享已安装的源包",
      "priority": "P3（后续新功能）",
      "kind": "done",
      "status": "具名设备验证及精确CI完成",
      "stage": "具名范围已交付",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [],
      "result": "已安装源包可通过系统分享；普通包及恢复包导出、回导已具名验证。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "按用户要求低优先级排队；登记不代表已开始实施。"
      ],
      "reportedAt": "2026-10-29T01:58:17.808+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第85394行，UserMessage item.id=01a183a9-adce-7783-a697-74816b2c61f1；不排除跨会话更早历史。",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户提出的可见日期；精确消息时刻未知。",
      "closedAt": "2026-10-30T08:55:53+08:00",
      "evidence": [
        "正常包异步复制原ZIP；备份恢复archivePath为JSON标记时，只读真实manifest/WASM/icon重建合法源包，无图旧备份保internal格式，不导App设置/会话。候选SHA256 66235060f37a8e5b46d5fc0c1d0486126da08a9d78829b9cbada5e63326fee66，构建及同db31证书/profile已核，日志 .hvigor/outputs/user-flow-audit/source-share/source-share-build-typed-manifest.log；237 lease20261030-000532-2e6ffe2f已唤醒及取六公开域基线，Native进行中，未提交。",
        "92普通源008面板文件名及另存为正确，009取消后副本与原包逐字同29003字节/SHA e90ca…；菇菇恢复源013弹面板但014发现SDK自动追加.zip，原.koma URI不存在，不计通过。实际.koma.zip根仅manifest.json/source.wasm/icon.png，WASM/icon与012原件逐字同。已改先压.zip再rename .koma；最终候选e597355e5b75bc7fd9c1bfbbc64d9e40366c764484e005c6913cac3b0a5d6781构建及同签profile核过，237 015复验中。证据source-package-share/{ordinary-share-panel-008,ordinary-cancel-copy-009,restored-share-panel-013,restored-cancel-package-014}。",
        "e597候选017系统面板显示菇菇.koma/23.72KB；018取消后文件23724B SHA256 51dc0e256780e40b66e741865be2a4d1c14c856fb1b54d7f8f921374f3b8bbf7，ZIP根仅manifest.json/source.wasm/icon.png，WASM/icon逐字原同。019–023普通选择器回导成功、同source ID/version及有效iconPath，024新导入WASM/icon同原。025原db31安装成功、六JSON及原4成员逐字同；026新importdir、3分享缓存、Download文件不存在，SLEEP/120000无override；lease20261030-000532-2e6ffe2f于08:48:22 released/status读回。未向接收方发送，Legacy无图备份未设备验；证据 .hvigor/outputs/user-flow-audit/source-share/evidence.json。",
        "源码ae693048已推Koma/master，7文件仅分享服务/现有菜单/清单转换/三语言及对应规则；未tag或AGC，精确CI run待核。",
        "ae693048a7a85536c13c48f0c2d3869a25f5b3eb精确CI40982238148 completed/success，build job123824804544含Release HAP与metadata全部成功；Publish tagged Release job123826043929 skipped，无tag/AGC/发布。证据 .hvigor/outputs/user-flow-audit/source-share/ci-ae693048.json。"
      ]
    },
    {
      "id": "TONGLI_HOME_BLANK",
      "title": "东立书源首页空白",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "237公开0.1.5首页具名验证通过",
      "stage": "具名首页范围已验收",
      "owner": "source_terra：东立首页修复及237验收",
      "dependencies": [],
      "relatedItems": [
        "TONGLI_CHAPTERS_SETTINGS_FAILURE"
      ],
      "result": "用户本轮反馈东立空白首页仍未处理。237实机复现首页返回空内容；公开0.1.5修复后首页Popular六个封面和标题实际显示。原章节正文的地区限制和官网黑页仍由关联事项跟踪，不由本项结论代替。 237本次会话已恢复原斗破书架、设置及数据基线，最终SLEEP/120000无override并释租。",
      "remaining": "本次237具名首页空白范围已完成；关联正文问题继续开放。",
      "remainingActions": [
        "本次具名首页范围已完成。"
      ],
      "boundaries": [
        "首页显示验收不等于章节正文或其他作品验收。"
      ],
      "reportedAt": null,
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈可见日期；精确消息时刻未核实。",
      "reportedAtSource": "本轮用户原话：东立的空白首页还是没处理。由Root可信转交；精确时间未核实，不以登记时间冒充。",
      "closedAt": "2026-10-29T02:13:00+08:00",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/tongli-home-fixed-263/screen.png",
        "本会话可核重复反馈：2026-10-29T01:31:24.892+08:00，rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl第84880行，item.id=01a18391-115a-7072-8c48-57716f4cb689；不冒首次。"
      ]
    },
    {
      "id": "ASM_HENTAI_BROWSE_RUNTIME_FAILURE",
      "title": "AsmHentai普通目录加载失败",
      "priority": "P1（本轮实机自检）",
      "kind": "accepted",
      "status": "237目录及短标题设置具名验证完成",
      "stage": "具名范围已验收",
      "owner": "source_terra",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "result": "公开0.1.3普通目录显示19本；237短标题开启、保存重入及清除后长标题恢复已核，设置及设备状态恢复并释租。",
      "remaining": "本次具名目录与短标题设置范围完成，不外推其他作品和路径。",
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "本项来源为代理实机自检，非用户直接报告；不扩其他路径验收。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮代理实机自检发现，非用户报告；协议开始时间不冒充精确失败发生时间。",
      "firstHandlingAt": "2026-10-29T02:45:45.147213+08:00",
      "firstHandlingAtSource": "asmhentai-default-272/run-metadata.json startedAt，实机自检协议开始时间。",
      "closedAt": "2026-10-29T05:04:31+08:00",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-default-272/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-failure-273/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-log-recv-277/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-public-browse-293/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-setting-295/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-short-enabled-296/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-clear-setting-297/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-setting-restored-298/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-shelf-373/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-sleep-374/"
      ]
    },
    {
      "priority": "P1（本轮用户反馈）",
      "kind": "accepted",
      "status": "237漫画网页及浏览器入口已验收",
      "stage": "具名入口已验收",
      "owner": "source_terra：237复现及参考/站点核查；Root：宿主入口消费者审查",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "reportedAt": "2026-10-29T03:24:39.203+08:00",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈的可见日期。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-29T02-01-17-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c_01a183ac-6c21-7c20-b914-df42c0cb41e5.jsonl 第1865行，UserMessage item.id=01a183f8-bda0-7760-84eb-34497aa5a660；不排除跨会话更早历史。",
      "closedAt": "2026-10-29T03:56:37+08:00",
      "id": "ZEROBYW_MANGA_WEB_ENTRY_MISSING",
      "title": "Zero搬运网漫画页面缺少网页打开入口",
      "result": "公开Zero 0.1.6在237普通详情菜单提供两种网页入口，实际WebView及外部浏览器均打开该作品；本站登录及锁章目录另由关联事项跟踪。",
      "remaining": "本次具名漫画网页入口范围完成。",
      "remainingActions": [
        "本次具名入口范围已完成。"
      ],
      "boundaries": [
        "用户反馈不代替实机复现；不预判原因。"
      ],
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-detail-menu-343/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-webview-369/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-browser-371/"
      ]
    },
    {
      "priority": "P1（本轮用户反馈）",
      "kind": "accepted",
      "status": "公开017完整目录及游客路径具名验收",
      "stage": "具名目录范围已验收",
      "owner": "source_terra：237复现及参考/站点核查；Root：宿主入口消费者审查",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "reportedAt": "2026-10-29T03:24:39.203+08:00",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈的可见日期。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-29T02-01-17-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c_01a183ac-6c21-7c20-b914-df42c0cb41e5.jsonl 第1865行，UserMessage item.id=01a183f8-bda0-7760-84eb-34497aa5a660；不排除跨会话更早历史。",
      "closedAt": "2026-10-29T06:45:24+08:00",
      "id": "ZEROBYW_CHAPTERS_TRUNCATED",
      "title": "Zero搬运网章节显示不全",
      "result": "237公开017显示32章、游客免费与锁章，未访问免费第二章中文原图已亲审，游客锁章拒绝及本站入口已核；原源包与设备已恢复。",
      "remaining": "本次具名目录与游客范围完成；登录态正文及首页图像未知留原会话事项。",
      "remainingActions": [
        "本次具名目录范围已完成。"
      ],
      "boundaries": [
        "5章为用户不确定观察，不作为已测事实。"
      ],
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-detail-342/",
        "237新候选562实体、566目录32/32、567锁章与568/569免费首章；画面待Root亲审。",
        "源提交c5b82649b8d5cb2e7a84d719d981184a27fe92af，CI40780631285 success；公开ZIP b698535d6e33a4bd2aff41ce02c4375fbb9cfd47db488bfa6f526a7b7148d2e7、WASM d3e4d175651939754ed17b7af1287991e867a63b26d2b5ea89d12f1cc6586bc2，与冻结候选不同。",
        "237 run588/590–597公开实体、目录、游客及免费页；601–604原源包及设备恢复，reader自然新增第二章记录，原记录保留。",
        "237公开017 run588、590–597及601–604；593第二章1/31中文原图亲审。"
      ],
      "allowedDifference": "按用户明确决定显示全32章目录、🔒标识与本站登录入口。"
    },
    {
      "priority": "P1（本轮用户反馈）",
      "kind": "accepted",
      "status": "197具名验证、交付及设备恢复完成",
      "stage": "具名范围已验收",
      "owner": "Root：共享/宿主查因与197具名验证",
      "dependencies": [],
      "reportedAt": "2026-10-29T03:45:16.335+08:00",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈可见日期。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-29T02-01-17-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c_01a183ac-6c21-7c20-b914-df42c0cb41e5.jsonl 第2272行，UserMessage item.id=01a1840b-9e2d-7351-966b-d339a7725bc5；不排除跨会话更早历史。",
      "closedAt": "2026-10-29T06:08:37+08:00",
      "id": "READER_MH1234_BOUNDARY_PRELOAD",
      "title": "漫画12342网RTL章末未提前预载",
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET"
      ],
      "result": "197公开0.1.5多页RTL提前预载并往返跨章，画面连续且章节与进度对应；Host阅读顺序合同及设备恢复待完成。 197原Blue阅读状态、四份数据及源注册表恢复；原013源文件保留，本轮临时文件已删，电源恢复并释租。 Host readingOrder d2995ef4已推且精确CI40776916652成功；公开015具名跨章已核，设备原013已恢复。",
      "remaining": "本次197具名范围已完成；不外推其他未验路径。",
      "remainingActions": [
        "本次197具名范围已完成。"
      ],
      "boundaries": [
        "Blue及Nemo的既有具名结果不能代替本源验收。"
      ],
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-public014-rtl-boundary-motion-90/",
        "旧版run90：chapter_boundary 04:04:55.792至chapter_opened 04:04:58.159约2.37秒；run88实际退页，不作为跨章证据。",
        "run90路径含public014为命名误标；197 registry及backup run93确认原源0.1.3，原录屏不可变，复现事实不变。首次da11包非灰底最新修正，不作为最终候选验收。",
        "run103 screen/layout为黑屏，仅cached-viewport-1可见；106 App脱敏日志确认当前及前一章get_pages成功。104日志命令被拒、105无效UTF8，均不作为日志证据。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-final015-rtl-fresh-chapter3-motion-110/",
        "run110：第2话9/11→10→11→未访问第3话1/13；10/11时get_pages开始并完成，最终原生选择下一章，无chapter_boundary重开。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-public015-entity-and-open-167/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-public015-rtl-chapter5-roundtrip-171/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-public015-chapter5-terminal-172/",
        "run171公开015 ZIP/WASM与公开字节一致；动作期get_pages在9/10页完成，原生往返跨章无chapter_boundary/opened；录屏SHA256 5dacb29aac873186cd258ce23b11a3ef2a98d8edfa68efca3eb6dfce0dd44608。",
        "https://github.com/honjow/Koma/actions/runs/40776916652"
      ]
    },
    {
      "priority": "P1（本轮用户反馈）",
      "kind": "accepted",
      "status": "197具名验证、交付及设备恢复完成",
      "stage": "具名范围已验收",
      "owner": "Root：共享/宿主查因与197具名验证",
      "dependencies": [],
      "reportedAt": "2026-10-29T03:45:16.335+08:00",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈可见日期。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-29T02-01-17-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c_01a183ac-6c21-7c20-b914-df42c0cb41e5.jsonl 第2272行，UserMessage item.id=01a1840b-9e2d-7351-966b-d339a7725bc5；不排除跨会话更早历史。",
      "closedAt": "2026-10-29T06:08:37+08:00",
      "id": "READER_LOADING_INDICATOR_BACKGROUND_CONTRAST",
      "title": "白灰阅读背景加载提示不可见",
      "relatedItems": [],
      "result": "197未访问页面加载时，白底深色进度与文字、灰底白色进度与文字均可见，最终图像正常。 shared ded07a61与Koma依赖0ac87bd已推，精确CI进行中；197恢复待完成。 Koma 0ac87bd精确CI40775085588 completed/success；197原状态恢复仍待。 197原Blue阅读状态、四份数据及源注册表恢复；原013源文件保留，本轮临时文件已删，电源恢复并释租。",
      "remaining": "本次197具名范围已完成；不外推其他未验路径。",
      "remainingActions": [
        "本次197具名范围已完成。"
      ],
      "boundaries": [
        "用户最新明确灰底白色、只有白底深色；仅调整加载提示，不改变其他画布文字。"
      ],
      "evidence": [
        "197 run155/156：白底未访问13/13加载深色文字与条，最终图像显示，超分开启。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/reader-gray-uncached-page-loading-motion-159/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/reader-gray-loading-terminal-160/",
        "灰底录屏SHA256 1f5e672a79ecdc21c56d4cdc6dbef8b3218ab5805b13f45e4a5d9c3135a5b008；223帧全审。",
        "reader-kit ded07a61e90ba0729a5927f7f6305f1ce0a8e38f；Koma 0ac87bd21ec117354e6e069eb56fde9e2ac21723；CI40775085588进行中。",
        "https://github.com/honjow/Koma/actions/runs/40775085588"
      ]
    },
    {
      "id": "READER_TRIM_REOPEN_DISABLE_LOADING_STALL",
      "title": "去白边后重进关闭导致图片加载卡住",
      "priority": "P1（本轮用户反馈）",
      "kind": "accepted",
      "status": "197具名验证、交付及设备恢复完成",
      "stage": "具名范围已验收",
      "owner": "Root：共享/宿主查因及197验证",
      "dependencies": [],
      "relatedItems": [],
      "result": "197同作超分开启重进后关闭裁剪路径已核；共享裁剪缓存修复及零预载预算恢复已独立提交并推送，Koma依赖及设备恢复待完成。 shared ded07a61与Koma依赖0ac87bd已推，精确CI进行中；197恢复待完成。 Koma 0ac87bd精确CI40775085588 completed/success；197原状态恢复仍待。 197原Blue阅读状态、四份数据及源注册表恢复；原013源文件保留，本轮临时文件已删，电源恢复并释租。",
      "remaining": "本次197同作超分与裁剪具名路径完成；用户旧包全部卡死细节未复现。",
      "remainingActions": [
        "本次197具名范围已完成。"
      ],
      "boundaries": [
        "单次阅读周期内开启再关闭不复现，不能用作替代验收。",
        "用户反馈尚未实机复现，具体共享或宿主原因未知。",
        "用户本轮确认发生问题时超分已开启；单次开关及超分关闭条件不能替代该路径。"
      ],
      "reportedAt": "2026-10-29T04:24:36.483+08:00",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈可见日期。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-29T02-01-17-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c_01a183ac-6c21-7c20-b914-df42c0cb41e5.jsonl 第3548行，UserMessage item.id=01a1842f-a17f-77b0-9451-cfea0cbbde59；不排除跨会话更早历史。",
      "closedAt": "2026-10-29T06:08:37+08:00",
      "evidence": [
        "197 run114–122：裁剪首次开启、正常退出重进、关闭后滑页具名未复现；run118旧坐标未实际切开关，不作复现证据。run124–125双开启路径进行中。",
        "/tmp/reader-crop-processing-native-batch.log",
        "197 run140录屏SHA256 304f8e33eb7784b34b197589c3b92dc1336239df443ff7c7da8a1ea28a79377a；动作区未见ReaderProcessing ready，旧五次ready属于重进初始准备；run131为Blue补充，不作为MH同作A/B。",
        "reader-kit/main efa846a：裁剪缓存身份修复及自动翻译零预载一页预算恢复。",
        "reader-kit ded07a61e90ba0729a5927f7f6305f1ce0a8e38f；Koma 0ac87bd21ec117354e6e069eb56fde9e2ac21723；CI40775085588进行中。",
        "https://github.com/honjow/Koma/actions/runs/40775085588"
      ]
    },
    {
      "id": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "title": "漫画详情章节分割线及点击反馈异常",
      "priority": "P1（本轮用户反馈）",
      "kind": "done",
      "status": "已修复并完成197真机验证",
      "stage": "具名范围已交付",
      "owner": "Root：103当前页面调查",
      "dependencies": [],
      "relatedItems": [],
      "result": "197原字号行距、12条分割线、行内圆角点按、长按取消及普通进入均已核；原数据与电源已恢复并释租。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "保持既有列表样式，仅恢复稳定分割线及原生行点击反馈；不重做列表。",
        "按用户最新纠正，按压反馈不得覆盖外卡片或整列表。",
        "本轮确认沿用ConciseListRow内缩行反馈，非整组；103未安装候选，不作新验证。",
        "103未安装候选，不冒该设备修复验收。"
      ],
      "reportedAt": "2026-10-29T04:53:52.520+08:00",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈可见日期。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-29T02-01-17-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c_01a183ac-6c21-7c20-b914-df42c0cb41e5.jsonl 第4293行，UserMessage item.id=01a1844a-6d06-74d0-8f11-3007d2ca4569；不排除跨会话更早历史。",
      "closedAt": "2026-10-29T20:45:37+08:00",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device103__MLR-AL00/not-applicable/portrait-1600x2560/chapter-list/chapter-list-current-screen-004/",
        "103仅查看当前页，未滚动、点章、启动或安装；恢复原600000ms无override，AWAKE同Koma窗口并释租。",
        "197 run147 HDS默认文字改变字号/行高，已撤回；新候选73f3bd同profile，run148回验中。",
        "197 run149/150/152：原字号行距、12行分割线、行内反馈、长按及普通进入具名；下载按钮独立回调，底板可在按钮后变色。Koma c68c75dd已推，CI待核。",
        "https://github.com/honjow/Koma/actions/runs/40771912927",
        "reader-settings-menu/chapter-list-hds-final-install-detail-149 与 chapter-feedback-native-hds-150；Root本轮亲审149 screen。"
      ]
    },
    {
      "id": "MANGA_DETAIL_PERSISTED_BACKGROUND_REFRESH",
      "title": "书架漫画详情持久化与后台更新",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "197具名路径已验，提交及CI成功",
      "owner": "Root：实现与197普通路径验收",
      "dependencies": [],
      "result": "197冷进程入场与重入已有详情和章节持续显示；库仅新增该书sourceMetadata，原章节、分类和进度保留。",
      "boundaries": [
        "保留章节、收藏、进度、动作及其余既有HDS样式，不重做详情布局。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户直接反馈；精确消息时刻未知。2026-10-29T16:33:30+08:00为登记时间，不冒历史首报。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T18:05:51+08:00",
      "stage": "具名范围已交付",
      "evidence": [
        "候选 HAP ad3c2c47a4868063715d6e3b55c645e68e67dd33856ad2eaf19e42fb306baa2e；197 基线41/awake42/install43，尚未观察终态。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manga-detail197-entry-motion-46/；manga-detail197-header-47/。",
        "197 8fd候选 run49库metadata及章节分类，run52完整往返291帧/9联系表，run53全宽渐变；深色回验及恢复进行中。",
        "197 8fd候选：run52冷进程普通往返292帧/9表，53浅色及57深色背景；58恢复外观、59原书架读态、60恢复电源及释租。reader、registry、web、search、source-settings字节同前；reader-preferences XML键值相同。",
        "df8ef8be739fbd09ca0619387911eeba2d3a8952已推，精确CI40851702184 completed/success；既有197冷进程与普通往返证据保留。"
      ],
      "relatedItems": [
        "MANGA_DETAIL_PULL_REFRESH",
        "MANGA_DETAIL_REFRESH_BACKGROUND",
        "MANGA_DETAIL_SCROLL_TITLE_VISIBILITY",
        "MANGA_DETAIL_COVER_BLUR_GRADIENT"
      ],
      "remaining": "",
      "remainingActions": []
    },
    {
      "id": "MANGA_DETAIL_SCROLL_TITLE_VISIBILITY",
      "title": "漫画详情标题栏按滚动阈值显示漫画名",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "197具名路径已验，提交及CI成功",
      "owner": "Root：实现与197普通路径验收",
      "dependencies": [],
      "result": "197普通往返已观察顶部不重复标题、上滑后显示标题。",
      "boundaries": [
        "保留章节、收藏、进度、动作及其余既有HDS样式，不重做详情布局。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户直接反馈；精确消息时刻未知。2026-10-29T16:33:30+08:00为登记时间，不冒历史首报。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T18:05:51+08:00",
      "stage": "具名范围已交付",
      "evidence": [
        "候选 HAP ad3c2c47a4868063715d6e3b55c645e68e67dd33856ad2eaf19e42fb306baa2e；197 基线41/awake42/install43，尚未观察终态。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manga-detail197-entry-motion-46/；manga-detail197-header-47/。",
        "197 8fd候选 run49库metadata及章节分类，run52完整往返291帧/9联系表，run53全宽渐变；深色回验及恢复进行中。",
        "197 8fd候选：run52冷进程普通往返292帧/9表，53浅色及57深色背景；58恢复外观、59原书架读态、60恢复电源及释租。reader、registry、web、search、source-settings字节同前；reader-preferences XML键值相同。",
        "df8ef8be739fbd09ca0619387911eeba2d3a8952已推，精确CI40851702184 completed/success；既有197冷进程与普通往返证据保留。"
      ],
      "relatedItems": [
        "MANGA_DETAIL_PULL_REFRESH",
        "MANGA_DETAIL_REFRESH_BACKGROUND",
        "MANGA_DETAIL_PERSISTED_BACKGROUND_REFRESH",
        "MANGA_DETAIL_COVER_BLUR_GRADIENT"
      ],
      "remaining": "",
      "remainingActions": []
    },
    {
      "id": "MANGA_DETAIL_COVER_BLUR_GRADIENT",
      "title": "漫画详情封面模糊并渐变到背景色",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "纠正候选197具名验证及正式交付完成",
      "owner": "Root：实现与197普通路径验收",
      "dependencies": [],
      "result": "197浅色遮罩消除、背景延伸至简介，深色渐变已观察；纠正已推送并通过精确CI。",
      "boundaries": [
        "保留章节、收藏、进度、动作及其余既有HDS样式，不重做详情布局。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户直接反馈；精确消息时刻未知。2026-10-29T16:33:30+08:00为登记时间，不冒历史首报。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T18:13:29+08:00",
      "stage": "具名范围已交付",
      "evidence": [
        "候选 HAP ad3c2c47a4868063715d6e3b55c645e68e67dd33856ad2eaf19e42fb306baa2e；197 基线41/awake42/install43，尚未观察终态。",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manga-detail197-entry-motion-46/；manga-detail197-header-47/。",
        "197 8fd候选 run49库metadata及章节分类，run52完整往返291帧/9联系表，run53全宽渐变；深色回验及恢复进行中。",
        "197 8fd候选：run52冷进程普通往返292帧/9表，53浅色及57深色背景；58恢复外观、59原书架读态、60恢复电源及释租。reader、registry、web、search、source-settings字节同前；reader-preferences XML键值相同。",
        "用户本轮纠正浅色背景发黑、覆盖高度过小；197 run53仅证明初版矩形边界消除，不能证明视觉效果获接受。df8ef8be739fbd09ca0619387911eeba2d3a8952已推，精确CI查询一次unexpected EOF，状态未知。",
        "同签候选9f134959f775c815b8dc4b82ad645fa2152b77fdc3cf5aa740bd7f3eb02784df：197 63安装，65入场71帧/2表全审，66浅色、67深色亲审；68外观恢复进行中。df8ef8be739fbd09ca0619387911eeba2d3a8952精确CI40851702184 success，不代当前纠正候选交付。",
        "197 68外观跟随系统，69原Blue第四话1页100%，70 SLEEP/120000/Override10000及租约released；manga-detail197-light-fix-61/final-data-comparison.json六文件字节相同，reader-preferences XML键值相同。",
        "b1780c263d99548ce82232fb900adcbba89ff8cd已推Koma/master，精确CI40854934583 completed/success；取代df8首版浅色压暗及高度不足，原反例与197 65–70证据保留。"
      ],
      "relatedItems": [
        "MANGA_DETAIL_PULL_REFRESH",
        "MANGA_DETAIL_REFRESH_BACKGROUND",
        "MANGA_DETAIL_PERSISTED_BACKGROUND_REFRESH",
        "MANGA_DETAIL_SCROLL_TITLE_VISIBILITY"
      ],
      "remaining": "",
      "remainingActions": []
    },
    {
      "id": "ABOUT_PAGE_RELEASE_HISTORY_MIGRATION",
      "title": "按NextE重整关于页并完整移植更新与日志查看",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "197具名验证与正式CI成功",
      "stage": "具名范围及正式CI已交付",
      "owner": "Root：关于页及更新日志移植",
      "dependencies": [],
      "relatedItems": [],
      "result": "关于页按NextE结构移植；真实更新、Markdown历史、版本切换与滑动、缓存重入及所选发布页打开已验证。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "按用户选定NextE结构与交互，保必要Koma宿主身份适配，不自创菜单。",
        "浏览器单次Back仅回浏览器首页，按恢复分支正常启动Koma，不称Back成功；初次脚本占位bounds误判保留，不归为App异常。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户直接反馈，精确消息时刻未知。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T21:33:43+08:00",
      "evidence": [
        "同签0.1.3/code4 release候选HAP d47589…；diagnostics/about197-validation-94与98/99/101：真实GitHub历史、NativeMarkdown、v0.1.2/v0.1.3选择与双向滑动、取消及缓存重入已亲审；about197-external-loaded-99浏览器DOM多处v0.1.2-pre。首次脚本隐形/可见页签bounds不同而停，保失败后按共同区域恢复；浏览器单次Back未回关于页，保101现场并走恢复分支，不冒返回成功。三语言说明及隐私文档同步中，版本未变、未tag发布。",
        "旧隐私/开源主列表行移除，许可仍包内；197最终原七域byteEqual、原书架、SLEEP/120000/Override10000及租约released，最终ae70同签0.1.3/code4保留，非新发版。diagnostics/about197-validation-94/delivery-findings.json、about-native-live-history.png、about-swipe-newer/older-release.png、about-selected-release-loaded.png及103/104回执。102 context旧d475标签但install argv指ae70，按delivery-findings说明。正式提交与CI待核。",
        "源码50e5cba93d180f67e348324d302c34e3ee45cedb已推，精确CI待核；未tag或发布新版本。",
        "50e5cba93d180f67e348324d302c34e3ee45cedb精确CI40883358607 completed/success，unsigned Release HAP成功、tag发布skip；版本未变、未tag发布。宿主首页5f7f精确CI40878436371 success。"
      ]
    },
    {
      "id": "MANHUAREN_REQUEST_REJECTED",
      "title": "漫画人提示书源请求被拒绝",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "具名实机及两仓交付完成，随新版App生效",
      "stage": "具名范围已交付",
      "owner": "source_terra：237书源故障",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_WEB_SESSION"
      ],
      "result": "漫画人列表、搜索、详情、正文及冷启动复用已验证，修复随新版App生效；新版尚未发布。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "提示本身不证明HTTP403、CF或不支持。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户直接反馈；精确发送时间未取得，登记时间不冒报告时间。",
      "reopenedAt": null,
      "closedAt": "2026-10-30T02:04:01+08:00",
      "evidence": [
        "237 1644 get_manga_list GET200、body116字符，源返回permission_denied，HTTP错误字段0；不写403或CF。",
        "固定参考fetchToken自动getAnonyUser2并缓存游客uid/token；当前列表缺完整会话链，正在核WIP与最小Host支持，不要求用户提供账号。",
        "Host及Rust游客协议候选构建完成，未Native；新租约审批一度误判授权，正在正常审批补充既有237授权，不视为永久阻塞。",
        "Root核出Host Buffer pool offset及源UUID variant字符问题后分别修正并重编：Host v3 a506f462700d9699e59e58e3c6b29c44ddc67d5ba579255d62e22aed27c871be，源v3 6180e360627ab4e8c2bec7862fa87a7cf891aa155ebc24675bc9798512d55675；237同场验证中，未称修复通过。",
        "237 1698候选ZIP/WASM与冻结v3一致；1701列表无法连接，1702白名单固定日志begin ok=false reason=operation_failed，未到RSA/游客POST/业务GET，原因未定、未发布。1704原包四成员等1688；1705原db31安装及六JSON等1687；1706清候选，1707 SLEEP/120000无override且租约释放。证据 manhuaren-guest-{open-1701,stage-1702,restore-package-1704,restore-data-1705,clean-1706,sleep-1707}。",
        "237 1715 Host v4单次入口begin cache_read_unknown，未到RSA/游客POST/业务GET；同场租约常亮保留，等待只输出细阶段及安全错误码的v5，尚未恢复或修复。",
        "1721 v6缩至read_identity；Root依据官方OH Buffer源码撤回误按Node重复加offset的两处更改。1724 Host v7真实begin owner、RSA三次及clock成功后abort，未commit、不证明POST或业务GET。源v4按固定949参考准备API https及gpt/Yqci.pt标识修正，尚未通过；设备仍持租。",
        "Host v7 ac9417…+源v4 0353…，1728源ZIP/WASM与冻结一致；1734列表20、1737 love搜索Love is Love且begin=ready/clock无新游客，1738详情及1章，1739页表1/10，1740 screen原图Root亲看。1741冷启动stop/start成功、layout保存，普通重入验证中。早期run context误留v5 codeIdentity，真实v7以实际安装protocol1722及冻结HAP关联，不更改旧收据。",
        "1743冷启动后列表20，begin ready→clock，无RSA/POST/commit，跨进程复用成立。1745原包四成员等1709，1746原db31 installer成功、六JSON等1708；1747两候选目录及两下载文件已清，SLEEP/120000无override；lease20261029-171636-0b411b83 released。未核Asset字节。App 55b30a61与sources 6b8c887本地提交未推；正式源minApp1.4，本地min1.3候选不发布，App 0.1.4未发布。",
        "App55b30a6158ec3ff103368ce2bc768bd835adcee7已推，CI40926490356编译中；source6b8c8871cc1e63c7bde9a7ce13a936b4eb9cebc2精确CI40926531577 success、release同SHA，漫画人0.1.5/minApp1.4公开。公开WASM 49ad72d3e974e1252c2776ab6bf417bdedfae2a9eadae527f9ab8b9d1c13b01c不同Native候选，仅无feature六业务NI/零RPC零HTTP核验；/private/tmp/manhuaren-6b8-public/contract.jsonl。App 0.1.4尚未发版。",
        "App55b30a6158ec3ff103368ce2bc768bd835adcee7精确CI40926490356 completed/success，unsigned Release HAP成功、tag发布skip；source6b8c887精确CI成功、0.1.5 minApp1.4公开。公开WASM不同Native候选，公开包未另Native；不冒0.1.4 App已发布。"
      ]
    },
    {
      "id": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "title": "无限动漫《古见同学》加载失败",
      "priority": "P2（后续处理）",
      "kind": "open",
      "status": "指定详情返回空正文",
      "stage": "官网指定作品空响应原因未明",
      "owner": "source_terra：237书源故障",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_WEB_SESSION"
      ],
      "result": "指定作品详情仍返回空正文；197系统浏览器打开该作品时也显示空白，原因未知。",
      "remaining": "指定作品官方详情仍为空，官方别名也跳回同址；未找到可用正文或有效替代入口，原因未知。",
      "remainingActions": [
        "核实该作品实际可用的官方详情入口及返回内容；保留原作品和阅读进度，不用其他书替换。"
      ],
      "boundaries": [
        "提示本身不证明HTTP403、CF或不支持。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户直接反馈；精确发送时间未取得，登记时间不冒报告时间。",
      "reopenedAt": null,
      "closedAt": null,
      "evidence": [
        "237 1648首页48本可见，作品失败路径尚未定位。",
        "1651搜索HTTP200成功；点该作品详情GET200空body，源返回client_error，未解决。",
        "/private/tmp/comicabc-14884-control.headers及.body：Mac严格当前UA/Referer无cookie准确id14884一次GET，最终同URL HTTP/2 200、原始正文0字节、text/html，未见Length/Encoding/Transfer-Encoding；与237空字符串一致，不是237解码独有，不外推全源。",
        "/private/tmp/comicabc-referer-ab：去Referer单次GET仍HTTP200/0字节，排除该单项差异，根因仍未知。",
        "/private/tmp/comicabc-referer-ab/control-30513.{result,headers,body}及control-offline.jsonl：同源UA/Referer 30513 HTTP200、解压35355字节，真实HTML经生产0.1.10 WASM详情及6章成功；14884仍空。官方上游两文件blob与固定949一致，无新流程修复依据，不外推全站。",
        "本地可证地址流程已核：原生产搜索输出归一指向/html/14884.html，与固定参考及当前详情一致；章节domain不能作为详情新地址。既有同URL 200空body、30513正常均未重发。",
        "官方别名候选 https://www.comicabc.com/html/14884.html 基于旧官网mode链接，单次自动跳原8comic同路径，HTTP200/body0，不能修；不推断作品下架。稳定证据 .hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-official-alias-20261030/evidence.json。"
      ],
      "evidencePoints": [
        "197系统浏览器017单次打开官方14884后截图空白，地址栏为8comic.com；最终完整URL与HTTP状态未知，不据此判定作品类型或网站根因。证据与Simply同场 source-settings-repair/simply-online-diagnostic-20261030/evidence.json。",
        "离线搜索仅得到作品14884及封面，未含章节ID；固定949目录依详情章节ID，现无可证另一官方目录API。不猜章号、不重发失败请求、不改作品；197浏览器空白的既有边界不变。",
        "30513真实详情引用的官网comicview.js一次GET HTTP200；脚本仅按详情提供的章节ID选择阅读路由，未提供独立详情/目录API或14884章节ID。本轮未重发14884、别名、搜索或章节请求，未操作设备。URL、状态、SHA及原件见 .hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/evidence.json。",
        "本轮官方搜索原始HTML的正篇仍为 /html/14884.html，标示501集但未提供章节ID或其他入口；14883为独立短篇。global.js处理已有目录排序、历史、书签及评论，未发现独立目录或移动详情路由；未重发古见详情或请求章节，不能由数量构造目录。原件 .hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/search-body.html 与 global.js。",
        "官网页面真实引用的PWA manifest一次HTTP200，仅含图标、颜色和standalone，无目录或API；两页未发现APP下载或独立移动客户端入口。三份既存搜索/30513/14884响应headers无Set-Cookie，不证明服务器永不依赖Cookie。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/evidence.json；不称详情修复。",
        "精确上游1386f490对应两个blob与固定949相同，没有新目录入口；不称已修复。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/upstream-reference-1386f490.json。"
      ]
    },
    {
      "id": "HAPPYMH_SOURCE_UNAVAILABLE",
      "title": "嗨皮漫画普通入口无法连接",
      "priority": "P2（后续处理）",
      "kind": "accepted",
      "status": "可安装入口已撤下",
      "stage": "用户采用的目录处置已交付",
      "owner": "source_terra：237书源故障",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_BROWSE_HOME_STRUCTURE",
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "result": "嗨皮已从可安装目录撤下，已安装源和数据保留；站点仍不可用。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "1682提示无法连接未证明具体原因；既有DNS无Answer不等于NXDOMAIN或站点停运，不重发已拒请求。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮代理执行自检发现，首次精确时间未知，不冒用户反馈。",
      "reopenedAt": null,
      "closedAt": "2026-10-30T23:34:04+08:00",
      "evidence": [
        "237 run1682普通入口仍无法连接，未见选择器；此前搜索GET平台2300006为域名解析失败，公开DNS A/AAAA NOERROR+SOA无Answer，非NXDOMAIN，证据 source-settings-repair/happymh-search-dns-20261029.json。",
        "当前上游eec435735737a0b140f8f3a990391990b5f9437a于2026-08-25以dead source删除，删除前域与当前m.happymh.com相同；API路径差异不能解释DNS2300006。当前无可证小修或合法新域，不删除用户已装源。",
        "本轮已异步询问是否从可安装目录撤下、保已装数据；尚未答，候选未实施。"
      ],
      "evidencePoints": [
        "用户最新明确撤下可安装入口；home_terra正在原sources目录生成链最小实施，保已装源、书库、进度及旧公开实体，尚未验收交付。",
        "c5ca337精确CI41078625088成功，正式index84移除Happy，其余84对象及顺序同旧；旧release包、图标可下载，manifest/WASM/icon内件同旧。237普通目录缓存84项ID/version/顺序与正式index一致，已安装嗨皮0.1.5保留，六域同基线，015 SLEEP/120000无override并释租。处置入口而非修复站点内容。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/happymh-catalog-withdrawal-20261030/evidence.json。"
      ]
    },
    {
      "id": "LLM_SOURCE_MANGA_RULE_ASSISTANCE",
      "title": "大模型辅助每源每漫画规则与排序",
      "priority": "P3（后续增强）",
      "kind": "parked",
      "status": "用户明确暂不实施",
      "stage": "后续增强暂缓",
      "owner": "Root：后续按用户决定推进",
      "dependencies": [],
      "relatedItems": [],
      "result": "用户提出后期增强，当前明确暂不马上实施。",
      "remaining": "后续再讨论服务下独立大模型配置、用户侧规则及协议。",
      "remainingActions": [],
      "boundaries": [
        "服务下独立大模型配置；用户维护每源每漫画规则；后续再讨论提示词、发送数据、结构化应答协议和其他利用。当前不实施或架构改造。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮用户直接提出并明确暂缓，精确消息时刻未知。",
      "reopenedAt": null,
      "closedAt": null,
      "evidence": []
    },
    {
      "id": "MH160_COVER_IMAGES_REJECTED",
      "title": "漫画160原生列表封面全部加载失败",
      "priority": "P1（用户直接反馈）",
      "kind": "done",
      "status": "图片请求头修复已交付",
      "stage": "具名修复范围已交付",
      "owner": "source_terra：书源修复与设备验证",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_SETTINGS_MIGRATION_AUDIT"
      ],
      "result": "漫画160图片请求头修复已公开；237候选同列表5/6封面及正文可见。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "单张斗罗2封面关联2300028、同URL Mac单次20秒无HTTP响应，原因未知；不称所有封面通过或全站故障。",
        "公开WASM不同设备候选，未另作公开包Native。"
      ],
      "reportedAt": null,
      "reportedAtSource": "当前可见用户直接反馈，原始发送时刻未取得；不以执行或登记时间冒首报。",
      "reopenedAt": null,
      "closedAt": "2026-10-30T16:05:30+08:00",
      "evidence": [
        "原015首屏六封面占位、图片GET403；源017补参考Referer/Origin，db1e6ad公开及CI41005769688 success。",
        "category-membership/mh160-cover-observe-20261030-007、candidate-20261030-016、return-candidate-20261030-020；候选5/6及斗罗正文1/26具名。",
        "/private/tmp/mh160-11140-control/及image-url.txt：剩余具名同URL单次20秒超时、无HTTP。"
      ]
    },
    {
      "id": "SOURCE_INSTALL_PIPELINE_SERIAL",
      "title": "多个书源安装串行导致效率低",
      "priority": "P1",
      "kind": "done",
      "status": "并行安装已验证并交付",
      "stage": "具名范围已交付",
      "owner": "Root/home_terra：代码；source_terra：真实验证",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_INSTALL_GLOBAL_DISABLE",
        "SOURCE_PACKAGE_INSTALL_UI_STALL"
      ],
      "result": "两个书源普通更新已验证可并行，原数据已恢复，源码和CI已完成。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "保同源去重、本地导入排他屏障、行身份及失败释放；已验收安装排队和界面行为保持。",
        "实际并行证据为两项普通更新的UI与registry关联及整体日志时序；脱敏单行日志不单独归属源ID。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮直接用户反馈，客户端日期2026-10-30；原messageId 01a18d62-c5c8-7b73-9348-3144538900cf / 01a18d63-db56-7c90-857b-9407730486a7，工具未提供精确时刻，不以登记时间或UUID推算。",
      "closedAt": "2026-10-31T00:02:32+08:00",
      "evidencePoints": [
        "Root核当前队列尾部全流程串行，登记同步段无await；候选为两个在线任务全流程并行，本地导入保持排他屏障，尚未构建或Native。",
        "237无诊断产品HAP c6e494c9547877a8850cb5035dcca0e3a86fe5a306614e25f1b05e20cb8bf028，0.1.4/code5保留。XCOMIC繁中.6→.13及简中.7→.12均成功；第二下载23:40:34.828早于第一install_ok 35.882，首download 34.313、末install_ok 36.178，普通路径证明并行。两源原包八成员及六域逐字恢复，Noy019、MHW会话及84源缓存保留，SLEEP/120000无override，lease7b12de1f released。原实现与候选完整测试对照中六个失败均为相同既存fixture，未改测试期望。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/source-install-concurrency-20261030/native237-evidence.json、verification.json。",
        "Koma 2ea1adaf4d29c6345418749d67a9ef9b5923b990已推master，精确CI41084355441 completed/success，unsigned Release HAP构建成功，tag发布步骤跳过；未新tag、发版或上传AGC。237保留本地签名c6产品HAP 0.1.4/code5，原两源及数据恢复并释租；CI artifact未另做Native，不作为重测门槛。https://github.com/honjow/Koma/actions/runs/41084355441"
      ],
      "reportedDate": "2026-10-30"
    },
    {
      "id": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "title": "书库漫画跨源迁移",
      "priority": "P1",
      "kind": "done",
      "status": "跨源迁移已验证并交付",
      "stage": "具名范围已交付",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [],
      "result": "单本及批量复制、迁移已接入并验收，已读进度、分类和追踪随选择处理，旧历史与下载保留。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "使用当前Koma控件；仅按用户明确采用的入口和流程实施，不擅自扩展样式。",
        "旧下载保留，不能冒充新源下载；Aidoku仅作行为参考，不复制代码或资源。",
        "197普通路径已验；分类与本地追踪绑定有关键执行证据。最后忙碌控件修正已编译，未重复安装。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮直接用户反馈，精确发送时间未取得；登记时间不冒充首报。",
      "closedAt": "2026-10-31T06:12:46+08:00",
      "evidencePoints": [
        "用户本轮明确要求实现迁移功能，并指出Mihon和Aidoku均有。",
        "用户通过本轮async call_06bd595e97bf48dd9fcff06914f4be01明确采用完整流程；尚未实现或验收。",
        "新增共用迁移页及详情/多选入口，复用源搜索原分页、筛选及验证；已接Library/Reader/Tracker，保原历史和下载。本地候选编译通过，关键执行覆盖倒序、未读空洞、卷号歧义、Reader写失败回滚、复制/替换、失败保原条目及追踪保目标选择。当前197候选e239d315，单本/批量普通路径验收中；原包38d245与前次install回执和当前updateTime吻合，但直接包导出与调试cp被系统拒绝，不能冒独立安装字节读回。已备份六域及tracker并核AWAKE/86400000，结束应恢复原override10000及睡眠；代码未提交、无新App发布。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json，协议 docs/device-protocols/koma-manga-migration-197.json。",
        "197候选e239d315已安装，详情菜单迁移、源选择、包子手动搜索经CF后出现真实《獵行者》；选中后迁移行仍显示“正在查找”。定位MigrationRow plain interface被ForEach相同key保留旧对象，现改ObservedV2+Trace刷新原行字段，正在重建，尚未设备复验。证据 .hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-migration/manual-return-018 与 verified-search-017。",
        "197 copy-result-022普通复制猎行者到包子獵行者219章，旧书及已读空洞保留；single-complete-032经NavPathStack NEW_INSTANCE修正后实际进入目标详情。batch-entry-033选2本，batch-move-result-038一项成功、一项无匹配跳过；持久化读回旧书移出、目标仅1本，旧Reader页14/16与sourceHistory保留；retained-history-040普通历史显示原猎行者第15/16页。未知新版本页数曾显示“第1/0页”，正在修为仅章节名；匹配阶段曾继承长源列表页尾位置，正修滚动归顶，两项重建待验。设备仍持租、未恢复或提交。证据 library-migration/{copy-result-022,single-complete-032,batch-entry-033,batch-move-result-038,retained-history-040}。",
        "最终候选12cfa9ea已完成本地构建、同签/profile核对与六项关键执行。197 stage-position-fixed-042第一项归顶、unknown-page-history-fixed-043目标未知页数仅显示章节名及旧历史15/16页均已亲看。restore-original-044原38d245安装成功，library/reader/registry/source-settings/filters/web-sessions/tracker prefs七文件与baseline逐字相等，source-setting-observations仍不存在；045实读SLEEP/120000/Override10000，lease20261030-212132-0600bc72 released。代码43246fd0已推master，精确CI待核；证据 .hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json。",
        "主功能43246fd0的197普通路径验收保持有效；最后复核补齐提交期间禁用重试/验证/预览，复用ConciseListRow.isEnabled，不改数据路径。ebae91bd12329878f0074800b26e3148f8c9cc9f本地编译通过并经HTTPS推master；SSH临时连接关闭，永久远端未改。精确CI41135459269运行中；旧41134748704被并发规则自动替换为cancelled，不作为构建失败或新提交的成功证明。不重复197验收。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json。",
        "精确CI41135459269 head ebae91bd12329878f0074800b26e3148f8c9cc9f completed/success，Build unsigned Release HAP job124336817401全步骤成功；Publish tagged Release skipped，未发新版本。Github artifact13016107812 ohos-hap-unsigned未过期，digest sha256:f332d59b9c2b51458a7294f23cccafcca693d1555862b6f4940013cbaeba6466，workflow_run head严格匹配。证据 .hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json 与 https://github.com/honjow/Koma/actions/runs/41135459269。最后忙碌控件修正仅编译、未重复安装的边界保留。"
      ],
      "modificationBasis": {
        "object": "书库漫画跨源迁移及其入口",
        "allowedDifference": "详情右上角和书库多选提供迁移；选目标源后逐书匹配，可修改搜索、换结果或跳过；确认选择已读进度和分类，追踪随书转移；可复制保留旧书，或迁移并移出旧书库。旧下载保留，不冒充新源下载；使用当前Koma控件。",
        "reference": "Mihon e588e04359fe1058206a2cbac1b01018ad787359；Aidoku ceee58b29d4f48106cf63042ca0cb075a8ac22b4，仅作行为参考。"
      }
    },
    {
      "id": "FEATURE_PARITY_COMPARISON",
      "title": "对照参考应用的其他功能缺口",
      "priority": "P1",
      "kind": "done",
      "status": "功能对照完成",
      "stage": "差异报告已完成",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "LIBRARY_CROSS_SOURCE_MIGRATION"
      ],
      "result": "已核出18项功能差异：11项缺失、7项部分实现。",
      "remaining": "",
      "remainingActions": [],
      "boundaries": [
        "本轮为源码及入口、持久化接线审查，不代表已批准新功能实现。",
        "不操作设备，不重开已验迁移、旧修复或已暂缓事项。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮直接用户反馈，精确发送时间未知；登记时间不冒充首报。",
      "closedAt": "2026-10-31T06:33:32+08:00",
      "evidencePoints": [
        "参考固定Mihon稳定v0.21.3/feadad5e、Aidoku v0.9-4/ceee58b及Koma HEAD b7e6a556；自动本地备份、通知、Wi-Fi下载及tracker已有实现，不列为缺失。",
        "固定Koma b7e6a556、Mihon v0.21.3/feadad5e及Aidoku v0.9-4/ceee58b2源码与入口、持久化接线对照；报告 docs/FEATURE_COMPARISON_AIDOKU_MIHON.md，机器证据 .hvigor/outputs/feature-parity-audit-20261031/comparison.json。本轮无设备、构建或新测试；对照完成不代表18项功能已实现或获得开发批准。"
      ]
    },
    {
      "id": "FEATURE_PARITY_IMPLEMENTATION",
      "title": "补齐参考应用功能差异",
      "priority": "P1",
      "kind": "open",
      "status": "追踪服务已交付，真实账号路径未验",
      "stage": "账号相关验收待条件",
      "owner": "Root",
      "dependencies": [
        "FEATURE_PARITY_COMPARISON"
      ],
      "relatedItems": [
        "FEATURE_PARITY_COMPARISON"
      ],
      "result": "三项追踪服务本地实现、表单验证及源码CI已完成；真实账号路径未验。",
      "remaining": "用户目前无三项服务账号；认证、Native profile、真实绑定及远端同步保留未验，不继续轮询账号。",
      "remainingActions": [
        "用户目前无三项服务账号；认证、Native profile、真实绑定及远端同步保留未验，不继续轮询账号。"
      ],
      "boundaries": [
        "使用现有Koma控件；新自动功能默认关闭，手动检查仍覆盖全书库。",
        "首批入口与默认值已获用户采用；197候选fdf340b6具名路径、完整备份预览及设备恢复已核。最后后台合并修正仅编译和逻辑验证，未安装。",
        "保留既有已确认行为与样式。"
      ],
      "reportedAt": null,
      "reportedAtSource": "本轮直接用户反馈，精确发送时间未知；登记时间不冒充首报。",
      "closedAt": null,
      "evidencePoints": [
        "用户明确要求开始实现功能对照报告的缺口；整体18项，第一批为更新、离线、备份六项。WorkScheduler平台合同为单次两分钟且独立进程，不能直接搬用前台runtime；执行所有者及跨进程数据边界正在核对。",
        "用户已采用首批入口与默认值；Root候选已接策略及备份覆盖、更新过滤、章节ID差集入队、下载执行批次共用服务和读后退出清理，尚未编译或验收。",
        "首批build-002与后台回调接入后的build-004通过；真实策略执行及原Coordinator覆盖通过。统一下载批次沿用原并发槽，DATA_TRANSFER长时任务提供进度/取消；WorkScheduler独立进程只读原数据、写不可变结果由前台owner合并；后台备份使用UI生成配置快照并刷新变化数据文件，避免跨进程读写XML首选项。未做设备验收；证据 .hvigor/outputs/feature-parity-implementation-20261031/build-004.log，脚本 scripts/test_library_automation.cjs 与 scripts/test_library_update_coordinator.cjs。",
        "197普通界面已观察更新范围、后台检查、Wi-Fi、跳过完结、新章自动下载范围及读后清理五档入口，update-enabled-010/config.json实际读回保存值；downloads-settings-011、read-cleanup-menu-013、backup-auto-016保原证据。后台任务实际回调、下载及外部备份仍待验。build-008已通过，处理备份恢复使旧后台结果失效；008尚未安装。证据 .hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/。",
        "197普通章下载后410ms退后台，8.6秒后download_done 1/1；新章15完整显示，关闭Reader后cleanup[]，队列与本轮基线逐字同，旧下载保留。证据 library-automation/{download-background-034,background-download-result-035,read-downloaded-test-chapter-037,read-cleanup-result-038}。callback-journals-027实际处理76条范围筛选，因尚未加稍后分类而均skip；fixed-background-callback-031/backup-result.json有后台备份成功回执at1793403232723、lastRun同值、failureCode空，产物由前一轮回调稍后执行，不称031新触发立即成功。外部文件内容/恢复未核；stopWork参数401、下载结束实况publish 1600007及删后详情仍显示已下载已改候选，尚未复验。",
        "scoped-update-evidence-045共76条journal，仅BlueArchive15章及猎行者458章真实GET目录，2项unchanged、74项范围skip；07:44:21 work_stopped7101成功无401，两书无实际新章，不称真实新增触发下载。transfer-fixed-result-048后台3283ms完成，无新1600007；cleanup-status-fixed-049完整Reader图→Back→详情首章已下载标识消失，原已下载第二章保留、queue原字节保持。系统picker在find-generated-backup-055找到外部备份23.72MB，预览正在解析、设备尚未恢复。build014通过；后续大library/sourcePackages编码从UI onBackground移到Extension，UI仅供偏好模板，同一生产Worker文件组装测试通过，build015进行中并补启动resume/目录失败回收。014/015未装机，当前fdf340b6候选。证据 library-automation/{scoped-update-evidence-045,transfer-fixed-result-048,cleanup-status-fixed-049,find-generated-backup-055}。",
        "系统文件picker普通打开23.72MB自动备份并预览解析v3：76书、92阅读进度、59设置、88下载队列、85源包元数据、1源设置；仅预览未导入。062日志确认仅本轮owned_modes=3授权已撤，064 obtainAllWorks为空；072/073通过正常UI永久删除仅本轮新建空目录及其文件，原回收站1项保留。074原signed HAP38d2456b恢复，六JSON、原queue及30个pref逐字一致，比较 .hvigor/outputs/feature-parity-implementation-20261031/restore-data-comparison.json；075实读SLEEP/120000/Override10000，lease20261030-231310-6d2be85c released并status确认。真实两作品均无新章，不冒真实新增触发下载；正差集由测试验证。Root正修多轮后台journal取最新及partial cursor不推进全库时钟，首批尚未提交。证据 library-automation/{background-backup-parsed-057,backup-preview-readback-058,backup-detail-counts-059,backup-grant-release-062,cancel-background-works-064,owned-folder-cleaned-072,filemanager-return-073,restore-original-074,power-restored-075}。",
        "最终build-016成功；生产策略、偏好、失败恢复、备份Worker组装及原Coordinator测试通过，三语言检查通过。BackgroundMaintenanceContract.latestBackgroundObservations按每comic取最新，真实执行覆盖倒序；有效cursor仍有remaining或无有效结果时不推进全库lastCheck。该小修仅编译和逻辑验证，未安装，设备保持原包。智能预计更新周期尚未接入。第二批准备CBZ导出、下载队列重排及每书章节偏好；新UI具体采用问题已询问，入口待答，独立数据工作继续。",
        "首批Koma/master 67a54bdf5d8ae2dc45ef13458d07cfe270e20f6b已推，精确CI41149684809进行中，不冒通过。第二批已接ChapterListPreferencesStore、ChapterArchiveExport和队列数组排序持久化；CBZ按页码原图与ComicInfo，progress写不重排，每下载slot重读队列。生产队列重排/持久回读、偏好隔离与回滚、完整有序CBZ计划及缺页拒绝和原章节显示排序逻辑通过；首编spread及taskpool局部函数约束已改，build019进行中。第二批未设备验收。",
        "197 build019签名候选：Blue已下载筛选及反序保存重入仍2/15；长按出现导出/分享，系统分享显示2.02MB CBZ未外发，系统picker保存Download后普通导入识别1章1页，Reader显示原漫画1/1，Root亲看。原cache mkdtemp目录HDC ls被DAC拒绝，不冒shell读取。build020 34bcd4ee3860d2349b1a93dc2c7a4c9e6d9222d8cd6534baafb183ec0da04c3a已安装；共用queue逻辑保持活动chapter不中断且下一slot读最新顺序。普通书架多选Blue加入4个真实未读章节、不启动传输；队列四种move可见，单章移top/bottom界面和queue读回均符顺序。新导出文件及临时导入、queue/pref/原包/power/lease仍待恢复，整体18项未完成。证据 .hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/chapter-management/。",
        "首批head67a54bdf5d8ae2dc45ef13458d07cfe270e20f6b精确CI41149684809 success，Release job skipped，未发版。第二批build021成功；197 build020的035下载管理入口系统share显示1.89MB、未外发；036 force-stop/install后Blue详情仍已下载+反序，冷进程持久性已核。build021 SHA72107157d53a61504cf50537b895279fdc7179b0dbc9cedcaf18e17a1442c95f安装，038预设连点未达预期route，039从真实详情Back恢复library、040进入queue；041整本移底后6条Blue行含已完成按原序置末，其他86条逐字未变，未启动下载。Root准备第二批commit/push；同一设备会话接第三批，临时导出/导入、原数据/包/电源/租约最终仍待恢复。用户call63d597已批准第三批，数据合同及消费者准备中，尚未实现或验收。",
        "第二批4a4d2f2b5fea4dce56919941e955c9c202209976已推，精确CI41151835894 success。第三批build023 SHA7e9c1ce2be614497dabc2c0e7bd488bdfcd46acd0bd0db219a98feae94ee136e已装197：bookmark-added-044真bookmarked=true且原isRead/position不变；045独立书签筛选，046已下载+书签+反序1/15；notes-saved-049普通保存并在详情显示Koma_QA_notes_20261031、library已保存。custom-cover-confirmed-052系统PhotoPicker后customCoverUri/sourceCoverUri正确落盘，但封面显示占位；定位CachedCoverImage将本地file://按源网络resolver处理，正在修，未通过。197仍持租未恢复。证据 .hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/chapter-management/。",
        "build024 SHA4d867c5ec91e0b5f9584745fbe752032e830b942d0e6f5df8c985778183a1a11已装197，CachedCoverImage对本地file早返回。054冷重入实图显示自选封面及背景，055真实源详情刷新后保customCoverUri、notes及bookmarked筛选。065普通本地备份中封面base64字节等于本轮图片，含notes/bookmarked及每书偏好；071正常导入本轮快照成功并生成新custom URI，072冷启动后新路径图片、笔记、书签筛选1/15亲看；073恢复源封面，原Blue图亲看，custom/sourceCoverUri清除且笔记和书签保留。当前清理本轮CBZ/导入/备份/restore临时源目录并恢复原包数据，设备尚未恢复、第三批未提交。证据 chapter-management/{cover-cold-reentry-054,custom-cover-source-refresh-055,personal-backup-readback-065,personal-backup-restored-071,restored-personal-data-visible-072,source-cover-restored-073}及实际目录。",
        "197本场恢复：079系统UI永久删本轮CBZ，080 FileManager回Browse且原回收站1项保留；081原signed HAP38d245恢复，七JSON与30prefs逐字一致、无多余pref，本轮临时导入、封面2图、备份和85个本次backup-1793408906798源目录精确移除，原4备份保留。比较回执 .hvigor/outputs/feature-parity-implementation-20261031/chapter-management-restored-data.json；082实读SLEEP/120000/Override10000，lease20261031-002732-3291754a released并status确认。第三批具名路径及恢复已核，Root审提交，未推/未CI；整体18项未完成。",
        "第三批b69890d00f3299c3084651d764e1f8c49f1e14a0已推Koma/master；SSH连接关闭后使用一次性HTTPS insteadOf，未改永久远端配置、标签或发版。build024及生产书签迁移、封面真实字节备份/失败恢复、原章节显示与automation覆盖及i18n检查通过；精确CI尚待核。Root继续核预计更新周期及WiFi预载参考合同，尚未改两项产品默认或UI，具体接入待用户决定。",
        "第三批精确CI41154283239 in_progress，未冒成功。第四批已向用户询问“跳过未到预计日期”和阅读预载旁“仅Wi-Fi”，两者拟默认关，尚未答复；未新增可见UI。独立代码已补固定Mihon feadad5e日历估算（周/月/批次/停更退避）、成功目录检查后持久预计时间、跨源不带旧源预计日；build025索引类型错误已修，build026成功。WiFi全局偏好/备份/运行态、Shared+Legacy预载与处理预取门接线中，build027尚待读回；设备未验，原默认行为仍关闭。",
        "build028成功；生产逻辑已核网络限制下停止在线页/跨章/处理预取但前台load可用，恢复允许后继续；配置冷store保存、common bridge字段保留，原覆盖不变。预计周/月日历、缺章保到期及未知不跳过逻辑通过。下一步197验证两项设置保存重入、WiFi真实读图及仅Blue范围更新，不改设备网络；尚未设备验收或提交第四批。第三批CI41154283239仍待核。",
        "第三批CI41154283239 success，Publish tagged Release skipped，无发版。第四批197 build028 SHA238e3eba259f62dd962200b1dba9a10d0528e3f5757ec42e144ddfb4dfe3fb17已安装：080 WiFi预载默认关，081开启离开重进checked=true且pref reader.preloadWifiOnly=true；083/084未到预计日期菜单保存重进且policy=true。085/086仅给Blue加read_later；087导航误进filter，088关闭菜单与sheet恢复settings，089进入scope；090实际due自动检查Blue unchanged、75 skip、0 failed，Blue.updateSchedule interval7/nextCheckAt1793721600000持久。092原WiFi网络下限制开启时在线章13完整正文1/1亲看；bounded hilog文件为空，不称观察到真实预载日志。非WiFi拦截由生产adapter执行测试覆盖，未切设备网络、不冒蜂窝实测。本轮设备尚未恢复，第四批未提交。证据 library-automation/policy4-*。",
        "197 policy4-original-restored-093恢复原signed HAP SHA38d2456b09842e9f8b689dc3cc6f7968416a088be4ca1ea829a0ec4e0389dea5，077基线七JSON与30prefs共37项逐字同、无多余pref，本次automation/reader临时文件已清；比较 .hvigor/outputs/feature-parity-implementation-20261031/policy4-restored-data.json。094 SLEEP/120000/Override10000，lease20261031-012758-d0770ea4 released并status确认。收尾发现自动检查在途时manual会吞自动过滤范围，已按手动全库决定改为auto后单飞完整manual；生产Coordinator测试通过、build029成功，最后小修未安装，不重跑已验设备。第四批待审提交。",
        "第四批666e70049069c250d9bae173456c8dd0b30f5464已推Koma/master，精确CI41156512169 in_progress，未发版。第五批阅读统计已接ReadingStatistics生产session recorder、ReaderSessionStore同文档可选readingSessions及root普通进度/lifecycle消费者，正在实现UI；尚未编译或设备验收。",
        "197 build031普通历史柱状图入口：旧历史时长/页/作品均0，月份2026-10有效；真实Blue正文后Home保存session28419ms，后台Reader字节不变，前台继续；104实际切到第二部第三话，方向非本轮验收。105统计3页/1作品/1天，三条session合计85375ms，后台gap32356ms未计。build033 SHA792e57a21b590a82b2fdecca4561217191af01efab6f41fe747fdde06ca43ad9冷启动三session一致，统计和每日图、年份2026及书库76/开始75/全读17/章14902/已读59/下载87已亲看；数值行伪箭头已修，全部每日图近365天滚到最近日。109原signed38d245及七JSON+30prefs共37项逐字恢复、无多余pref，110 SLEEP/120000/Override10000，lease20261031-014655-15bad8b8 released；比较 .hvigor/outputs/feature-parity-implementation-20261031/reading-statistics-restored-data.json。计时/日历/持久备份normalizer和失败恢复、旧迁移/未读生产逻辑通过；最后清历史同步移除孤立会话build034及逻辑通过，但034未安装。备份统计仅原文档normalizer实际测试，未重跑整份备份UI，不称实际新备份导入验收。第五批未提交。",
        "第四批精确CI41156512169 success。第五批交付前补双页/条漫实际可见原页计数：Shared使用ReaderObservedPosition.displayedSourceIndexes，先host提交真实章再上报，重复fractional原anchor不重写progress但可更新可见集合；Legacy在已加载可见页及imageLoaded上报，根生命周期统一计时。生产onObservedPosition测试覆盖切章提交顺序和fractional不重写，recorder多页/恢复测试通过，build036成功；最后收尾和清历史孤立会话仅编译及生产逻辑，未再安装，保033设备范围。第五批准备提交。第六批用户已采用智能分类，Root正核固定Aidoku消费者合同，尚未实现。",
        "第五批Koma/master 0de6ef6ce839bb1def563dc5ba03e729d59f9286已提交推送，未发版，精确CI待取。第六批已核固定Aidoku LibraryViewModel同类来源/分级/分类包含OR、不同类型AND、排除优先；正准备独立动态规则与原书库持久域，尚无第六批代码。",
        "第五批0de6ef6精确CI41157810983 in_progress。第六批候选已接LibrarySmartCategory独立规则（同类OR、跨类AND、排除优先）、LibraryStore独立smartCategories及持久化/失败回退、书架原分类菜单动态投影；手动赋类和自动更新分类选择仍只使用原manual列表。内容分级从SourceManga经Detail/cache到Comic metadata持久化；现有分类管理卡片/半模态编辑八类三态及保存/排序/删除，来源、分级、分类默认折叠。下载原runtime和追踪owner已提交公开快照/通知及备份恢复失效已接，不读凭据。build037通过、映射快照收尾build038正在核；生产规则、动态状态、持久备份及失败恢复、映射成功才发布四项执行通过。未设备验收或提交。",
        "第五批精确CI41157810983 success。第六批build038/039因Index缺TrackerPreferencesStore导入失败，修正后build040成功，SHA effa2359889a394c5bb486fd3b6b62e27dd0fc63634fc31a93a9244380c61b06。197 lease20261031-020842-29751355：smart-baseline111已备七JSON、prefs、原包及电源；112 AWAKE/86400000实读；113普通Settings→书架→分类，114新建，115编辑器八类规则与折叠组，116输入测试名称并展开来源，117三态菜单，118正配置来源包含及手动分类排除。尚未保存、验收或恢复；下一步核成员动态变化与冷入保存。",
        "197智能分类120保存来源Fuda包含及收藏排除两规则；124书架原分类菜单选中后仅匹配真实Holly Plus59。128原手动赋类菜单仅收藏/稍后/清除，无smart；129加入收藏后即时无匹配，library实际category改favorite、规则原样；130重新进入管理规则仍在。131操作菜单打不开，定位新caller传subtitle但Concise下拉锚点要求trailingText；仅改新section为规则数尾部下拉，build041进行中。编辑、排序、删除、冷启及恢复未验。",
        "build041成功，HAP SHA5996c39ab2dcd6197ecc7e5e55059e4e73079a4b52c3dbaad5844d708d87eba3。197 132保存重入菜单有效；133/135编辑名称及downloaded包含保存，inputText追加，实际名称Koma_QA_BlueKoma_QA_Edited；136第二组保存，137普通菜单上移后library sortOrder 0/1与UI一致；138 force-stop普通启动后两组名称、规则和顺序同137；139/140系统确认删除目标组，只余Second，comics/manualCategories与138相同。141恢复原38d245及fresh smart-baseline111七JSON与30prefs全部37份字节同、无额外prefs，证据 .hvigor/outputs/feature-parity-implementation-20261031/smart-restored-data.json；142 SLEEP/120000/Override10000，lease20261031-020842-29751355 released且无active。124/129动态筛选及128手动隔离保留；未逐一真机验证八规则、真实tracker登录或自然失败，生产逻辑四项通过。第六批待审提交推送及精确CI。",
        "第六批6b449b2a02c90da7033ef9f73b2e690a2d425f40已推Koma/master，精确Build OHOS 41159800145 in_progress；前一统计CI成功。亮度滤镜具体入口/全局与即时设置默认关闭，以及多归档沿现有入口扩展已分别询问用户，尚待答复；独立数据/codec准备继续。",
        "Root先实现多归档，已核固定Mihon Archive.kt、LocalSource.kt、core/archive/EpubReader.kt；native libarchive3.8.11+xz5.8.4+bzip2及后台解码、EPUB taskpool顺序候选在本地，尚未编译或真机。智能分类CI41159800145仍待实际回执。",
        "智能分类head6b449b2a02c90da7033ef9f73b2e690a2d425f40精确CI41159800145 completed/success，具名范围交付；总18项未关闭。归档候选044已编译a884cfcb，197 lease20261031-023408-1058d3b7：143 fresh baseline备份、144 AWAKE/86400000、145普通书架菜单、146漫画归档submenu、147 picker扩展入口已显示。公共Docs/Download的HDC mkdir与四file send实际Permission denied/NoSuch，虽cmd exit0也属失败；148下载索引及149/150浏览Download不构成导入。正通过既有debug Want diagnostics准备固定app私有QA归档，再验普通书架Reader及cold，不操作用户其他文件。native核心主机系统libarchive的RAR4stored/RAR5compressed/7z/TAR字节及穿越/符号链接拒绝实测通过，不冒OHOS codec；build045 localFolder helper导入顺序失败已修，build046进行中。设备仍awake/held未恢复。",
        "197 HAP049 SHA f28ae54572d754731e9eb6a806f0c4757d38c35aab72486fc9d3a67295ac00a7：普通系统SavePicker创建四份自有QA文件，普通书架菜单→漫画归档→Download选择导入；158 TAR、159 RAR4 stored、160压缩7z各三页1.png/2.png/10.png持久成功。161批动作EPUB选择未生效保失败，162稳态选1/1、163完成EPUB，实际spine顺序2.png/1.png/2.png，保重复且不附未引用10.png。165 force-stop后四书对象与163同，166最近加入显示四卡、167 EPUB详情3页、168 Reader 1/3绿色Koma archive page 2图由Root亲看。当前构建临时自有资产清理诊断050，准备清四公共QA文件、四本缓存及空测试根，再恢复baseline143七JSON/30prefs、原包/电源并释租；尚未恢复。RAR5仅host压缩样本，未具名OHOS codec。证据 library-automation/archive-*。",
        "归档收尾：183系统文件管理器确认本轮四份QA文件并永久删除，同查询0项；184回Browse且原最近删除1项保留。185应用私有清理ok=true，删除四书缓存及151失败空根共五根，186临时report确认NoSuch。169–172删除接口尝试均未成功，保失败证据；最终GUI及应用私有清理完成。187原HAP38d245与archive-baseline143七JSON/30prefs共37文件逐字相等、无额外pref，证据 .hvigor/outputs/feature-parity-implementation-20261031/archive-restored-data.json；188 SLEEP/120000/Override10000，lease20261031-023408-1058d3b7 released且无active。临时QA诊断/Want分支/fixture资源已撤，SourceRuntimeDeviceSmoke diff为0。纯产品build055成功，最后原生close错误分支重复close修正build056中；普通四格式验收为HAP049及165/168范围，RAR5仅host压缩fixture，目录扫描新格式未扩展，保ZIP/CBZ章节描述合同。",
        "第七批产品提交97288fef54e26f5a8539fd9d17db2b6a52436e00已推Koma/master；纯产品build056成功，无诊断，精确CI41163450398 in_progress，未冒通过。Root开始实现用户已批准亮度与滤镜，尚无代码，设备无租约。",
        "亮度滤镜候选已接全局/Reader同内容组件、ReaderPreferencesStore有序持久/备份/差量重基、独立滑动预览、root窗口亮度owner及shared/legacy图片展示层，加载与HUD保原。build057 ArkTS通过但打包JAVA_HOME错误，已修本地环境；build058成功13s505ms。Root正在197真实验证，尚未验收或提交。第七批CI41163450398最后仍in_progress。",
        "第七批精确CI41163450398 completed/success，release job skipped，无发版；归档按原设备具名范围收口。亮度build058 HAP6f321d已装197，全局显示→亮度滤镜默认四开关关闭，196截图Root亲看；正在普通保存灰度。build059亮度采样及readback日志成功10s702ms，将同场安装续验。NextE 34s10ms与NextN 26s695ms仅编译成功，未设备验收。",
        "197全局197保存grayscale=true；198安装build059后冷入Blue正文灰度，Root亲看。202正亮度49、Window readback 0.4900000095及反色画面；发现slider文本停0，修独立@Param控件后build061成功。203安装061、负亮度-52，标签与slider一致，Window读回0.01、图片暗层可见；204关闭独立亮度后restored=-1且扩展sheet显示RGBA；205保存R240/G52/B0/A76，菜单六模式齐，206正在选滤色看全图。最初display189误复用143接收目的名，实际143七JSON+30prefs与独立187回执逐字同，未改旧产品数据；fresh190正确基线。lease20261031-032302-84dbe78e仍持有、86400000，设备尚未恢复。",
        "197 build061：206 screen模式RGBA240/52/0/76正文实际浅红、HUD/页码白；208 multiply实际全图深红；211连续滚动相邻两章图片均保滤镜，Root亲看。212开启-52后正常关闭Reader回书架，Window requested=.01读回、退出restored=-1。213 fresh190七JSON+30prefs共37逐字同、无extra，比较 library-automation/display-restored-data.json；214 SLEEP/120000/Override10000，lease20261031-032302-84dbe78e released且无active。持久冷读、窗口late取消/准确恢复及3locale测试通过，build061 11s116。仅screen/multiply实图，其他四模式仅菜单与映射编译；Legacy仅接线编译、NextE/N仅编译，不外推全组合或原图导出。两仓提交pin及CI待审。",
        "第八批reader-kit/main b3aac7c092c4a3bb8d303160674880c5b67f29f7及Koma/master a15c468cce9ac4ac6dd6a8dd62070299e0301d87已推，workflow已pin该kit；精确CI41165157510 in_progress。061 HAP实际SHA9b9b8c9afb19c18eba0e496065d407bb957af4772e9e18877ac3cf4f41e3d645，冻结candidate-display061-9b9b8c9a.hap；203起实际安装061，manifest context沿用旧display-build058字样，display-acceptance-binding.json如实说明，未改历史回执。最后差异更多追踪服务原接口调查中，UI接入待决定，尚未实现。",
        "进度docs提交63bfac4ac67bb7087885383cdd598a8b88d6979c已推，workflow并发取消旧41165157510；同产品树精确CI41165212291（head63bfac4a）in_progress，旧CI不重跑、不当失败。已核固定Mihon Bangumi OAuth、MangaUpdates账号登录及Kitsu GraphQL；Bangumi个人token与MU账号表单具体UI已异步询问，等待仅限制UI，接口准备继续。",
        "第八批CI41165212291 head63bfac4ac67bb7087885383cdd598a8b88d6979c completed/success，具名范围收口。第九批Bangumi/MU后端候选已写客户端、账户刷新、匹配、同步、pending重试及安全连接事务；build063/065类型错误修后064/066成功，066耗时11s402ms。生产客户端创建回读、远端state保留、自动不回退、失败重试、凭据字节/提交回滚/旧凭据清理失败等执行通过，原AniList/MAL仍通过。官方公开搜索两站HTTP200：Bangumi手工limit3三条均小说，经参考同样漫画过滤排除，不称漫画正结果；MU 25条、生产解析One Piece series55099564912。新UI尚待用户答复，provider available和表单未改；未账号/设备验收、未提交。Kitsu官方GraphQL和登录条件核对中，不称已接通。",
        "第九批AdditionalTrackerClients、DirectConnectionService、三个消费者/共享provider边界及pending已接；build066成功。TrackerSettingsPage仅加未调用的私有连接处理器，无新可见表单，planned/unsupported状态未改。原设置状态测试仅补DiagnosticLogger host绑定后通过；原进度服务覆盖新增两客户端及安全事务通过。Kitsu公开GraphQL HTTP200无errors，官方server skip_client_authentication_for_password_grant=true，仅调查、尚未实现。新UI本轮已询问尚无答复，依赖答复的界面和安装验收待办保留；无真实账号或Native HTTP验收。066后仅将helper不存在的toast键替换为既有tracker_callback_connected/tracker_detail_connect_failed，未安装、不称设备通过。进度页8766实际HTTP200；第八批CI成功不重跑。",
        "用户已明确采用Bangumi个人令牌及MangaUpdates用户名密码的现有详情表单和完整匹配/确认/同步，不再重复询问；Root正在接UI和真机验证，尚未验收。",
        "第九批已接采用的Bangumi个人token/MU用户名密码UI，新增服务available，共享能力表贯通账户刷新、搜索、pending及进度；审出hasSearchClient遗漏后已修，真实mapping service生产测试通过，非静态字符串检查。build068通过；197 lease20261031-125603-f0682c47，freshbaseline215与实际原HAP已保存，awake216读回AWAKE/86400000，install217进行中。账户问题已异步询问，真实账号和Native HTTP尚未验。",
        "197 build068：219/220账号列表四服务；221 Bangumi空token按钮禁用，222虚构无效token掩码且可连接，223点击后连接失败Toast、仍未连接；224 MU空表单，225填写虚构文本但不提交登录，226离开重进凭据清空。用户最新明确暂时没有Bangumi/MU账号，真实认证、远端绑定及同步未验，不再轮询；227首选项30文件未新增且不含三个测试文本。228恢复中。纠正此前新HAP已保存说法：216 recv stdout实际permission denied虽exit0，无新备份；215原bundle完整回执与213 original-bundle逐字同含updateTime，按已保存original197-38d245恢复，不冒新保存；baseline215七JSON/30prefs真实存在。Kitsu UI方案已询问未答，unsupported代码不改。",
        "228原HAP恢复安装成功，七JSON及30prefs与baseline215逐字相等、无额外prefs；229 SLEEP/normal120000/Override10000，lease20261031-125603-f0682c47 released。候选 .hvigor/outputs/feature-parity-implementation-20261031/candidate-tracker068-df532ff8.hap SHA df532ff8acc0c27b061323c0b9addeb7e2794dfc7fec11477c1714f55ea52dc4；tracker-acceptance-binding.json详列215–229、账号未验和216失败纠正。两服务代码和表单具名已验，待提交/CI；用户无账号，认证后绑定/同步未验；Kitsu UI待答。",
        "用户最新已明确采用Kitsu完整接入，Root实施中；Bangumi/MU的215–229具名验收冻结，不扩大重复验证，Kitsu新表单另作具名验证。",
        "Kitsu生产client已接官方password grant（不复制参考client_secret）、GraphQL currentAccount/search/myLibraryEntry/create/update并回读；update只id/progress，官方在线schema证其余字段可选，见 .hvigor/outputs/feature-parity-implementation-20261031/kitsu-inputs.json。同一能力表贯通refresh/search/pending/sync；build071通过。scripts/test_tracker_progress_sync.cjs实际覆盖安全登录→匹配候选→confirmComicMapping→进度写入/保留ON_HOLD隐私评分→失败队列重试，属host绑定，非Native账号验收。197 230新baseline及连续awake，231安装071、232列表5 provider、233 Kitsu空邮箱密码禁用、234虚构文本掩码及可连接但未提交、235重进两项清空、236 prefs无新文件且不含输入；237恢复中。真实账号均未提供，Kitsu账号问题异步待答，不称无账号或已验；Bangumi/MU 215–229冻结不重测。",
        "Kitsu本场237恢复回执completed无Fail，37文件逐字等fresh230；238 SLEEP/Override10000/normal120000，lease20261031-130858-49494df6 released。071候选冻结 candidate-tracker071-d4a8e88a.hap，SHA d4a8e88aeecfb2ae620547d70603fb39e2dcb3e3919f6b9ac2a070eeb6c7dcfb。证据 .hvigor/outputs/feature-parity-implementation-20261031/kitsu-acceptance-binding.json。两轮具名表单待统一提交/CI，真实账号路径未验；Kitsu账号问题待答，不推定无账号。",
        "用户call_9b477acd314a4525992533ebc11011d7明确Kitsu也暂时没有账号；Bangumi、MangaUpdates及Kitsu真实账号均缺，成功登录、Native profile、绑定和远端同步未验，不继续轮询。其余本地实现和具名表单范围已完成，待本次提交CI。",
        "三服务产品及已验文档提交529aa8b66329072f73529d4df2b715ae74b994f8已推Koma/master；精确Build OHOS CI41204801578 head同提交、in_progress。用户明确三项服务目前均无账号，真实账户相关路径未验。",
        "精确CI41204801578 head529aa8b66329072f73529d4df2b715ae74b994f8 completed/success，Build Release、Inspect、Upload均成功，tag发布job skipped，无新发布。证据 .hvigor/outputs/feature-parity-implementation-20261031/tracker-ci-final.json。三服务本地实现和表单具名范围已交付；用户明确均暂时无账号，真实认证、Native profile、绑定及远端同步未验，不轮询账号；整体项保持open。"
      ],
      "modificationBasis": {
        "object": "首批书库更新、离线下载与备份设置",
        "allowedDifference": "书库更新增加后台检查、分类范围、跳过条件以及WiFi和充电约束；下载支持新章自动下载及分类，读后清理提供关闭、读完、保留2/3/5和排除分类；备份管理增加目录及后台开关。沿用现有控件，新自动功能默认关闭，手动检查仍全库。",
        "decision": "用户本轮通过call_4bfc明确采用。",
        "secondBatchAllowedDifference": "用户call3537采用：已下载章节长按及下载页菜单导出/分享CBZ；队列单章或整本移顶部/底部，活动下载不中断；现有排序、已读下载、语言和汉化组按书记忆。",
        "thirdBatchAllowedDifference": "用户call63d597批准：章节菜单书签、小标识及独立书签筛选；已收藏详情菜单更换/恢复封面，使用系统picker并在源刷新时保留；详情个人笔记使用现有半模态及有内容详情展示，数据随备份。",
        "fourthBatchAllowedDifference": "用户call_db09cabf23b94b828cb018cef58ef7a7采用：Settings阅读预载旁增加仅Wi-Fi开关、更新跳过菜单增加未到预计日期；均默认关闭，沿用原行/菜单，Reader半模态不新增全局网络开关。",
        "fifthBatchAllowedDifference": "用户call_c7bd96ed59a7462aa1885289b0183258采用：历史右上chart_bar进入统计；全部/月/年，展示时长、页数、作品数、连续天数及每日图，另分组书库章节已读下载；沿用原控件，仅记录真实前台会话，不为旧历史补时长，数据随备份。",
        "sixthBatchAllowedDifference": "用户call_ee93c3eb255247029310b7ff47c37fda采用：原分类管理增加独立智能分类组及创建、编辑、排序、删除；八类包含/排除/不限规则，书架分类栏动态更新并随备份；不改手动分类，不混入加入分类选择器。",
        "archiveAndFilterDecision": "用户通过call_c892与call_e872明确采用亮度滤镜及归档格式两组方案；具体亮度入口与默认按该决定执行。多归档支持RAR/CBR、7z/CB7、TAR/CBT、图片型EPUB，原导入页标题漫画归档并扩展选择器，普通自然顺序，EPUB按spine取图，文字EPUB不渲染。",
        "trackerAllowedDifference": "用户call_0d45192172ec4b98b9b1dc5bbf1e8c91明确采用：Bangumi个人令牌、MangaUpdates用户名密码，使用现有详情表单并提供完整匹配、确认和同步流程。",
        "kitsuAllowedDifference": "用户call_45d3ff5aed77479f99474ae956d8be80采用Kitsu完整接入：现有追踪详情邮箱/密码登录、匹配确认及同步；密码仅用于登录，token安全存储且不备份。"
      }
    }
  ],
  "source": {
    "status": "书源设置与搜索逐项核验中",
    "kind": "open",
    "title": "书源进展",
    "result": "MangaBz和CManhua筛选正式包已公开，继续核漫画160及全85源能力差集。",
    "remaining": "源设置、搜索、网页验证和未通过站点路径按原事项继续。",
    "commit": "668c785257b959f006bece2fe2ead56dcec90480",
    "authorization": "用户明确“书源相关的工作都默认使用237，不用重复问我。”书源相关验证默认237，当前五包具体验证授权继续有效；每次按流程取得租约，测试后恢复状态并释租，不扩为清用户数据或改账户/网络的许可。"
  },
  "milestones": [
    {
      "at": "2026-10-19T22:26:49Z",
      "text": "本地未加密备份创建/读回/清理完成；书源主分支已同步，Kit推送403已核权限。"
    },
    {
      "at": "2026-10-19T23:20:11Z",
      "text": "197现成CBZ导入、纵向翻页及真实进程死亡后进度重开通过；本轮条目已移出，点击反例继续追。"
    },
    {
      "at": "2026-10-19T23:39:24Z",
      "text": "设置具名入口、本地重扫自然重选分支及两图导入/翻页/重开已实际观察，临时条目与排序已恢复。"
    }
  ],
  "releaseGates": [
    "正式0.1.4已发布，下载产物及正文已核；现有Release为unsigned，未上传AGC。",
    "Simply与漫画屋验证回流仍有未解决问题，原因未明；其余源故障和能力扩展按原事项保留。",
    "漫画翻译其他提供方真实网络未验，保留为具名验收边界。"
  ],
  "stopRule": "各事项按具名证据与原边界跟踪，未验范围保持开放。",
  "evidence": [
    {
      "id": "b744-preservation",
      "label": "b744原完整保全回执",
      "path": "kit-b744-parent-content-complete-r134-20261019.receipt.json",
      "storage": "recovery"
    },
    {
      "id": "app05-retirement",
      "label": "App05 r2实际管理退休结果",
      "path": "app-production05-exact-admin-retirement-2958a016-result.json",
      "storage": "recovery"
    },
    {
      "id": "comicabc-cleanup",
      "label": "ComicABC十一证据父实际清理结果",
      "path": "comicabc-eleven-evidence-parents-cleanup-result.json",
      "storage": "recovery"
    }
  ],
  "evidenceNote": "当前设备原件在Koma/.hvigor/outputs/user-flow-audit；下列旧清理证据仅为历史回查，不代表当前产品验收。",
  "excluded": "不新增工作树/源码副本/归档/报告/脚本，不做哈希核验，不擅改已定样式，不清用户数据。旧清理工时和目录数不换算产品完成度。",
  "timeline": [
    {
      "id": "terminal-row-113",
      "at": "2026-10-25T03:50:24.629575+08:00",
      "title": "相邻源行重建修复通过237实测",
      "detail": "真实安装Zerobyw，分隔线正确更新，trace未再重建相邻行。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "verified"
    },
    {
      "id": "terminal-row-commit",
      "at": "2026-10-25T03:52:55+08:00",
      "title": "提交源列表行身份修复",
      "detail": "d6dcb4c；精确CI40127317871随后已成功。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "registry-size-115",
      "at": "2026-10-25T04:01:47.582390+08:00",
      "title": "注册表重复读取修复通过正常安装",
      "detail": "237安装Simply Hentai成功；原69源及书架、阅读记录保持，持久化记录10ms。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "verified"
    },
    {
      "id": "progress-timeline-start",
      "at": "2026-10-24T20:07:26.848989+00:00",
      "title": "开始完善工作时间线和主题切换",
      "detail": "保留简洁折叠入口；增加自动、浅色、深色，并验证刷新后的状态。",
      "itemId": "PROGRESS_TIMELINE_THEME",
      "kind": "work"
    },
    {
      "id": "progress-timeline-theme-verified",
      "at": "2026-10-24T20:11:44.260077+00:00",
      "title": "进度页时间线与明暗主题已验证",
      "detail": "折叠入口、连续节点、明暗切换及刷新记忆均已检查；后续记录沿用同一工作单。",
      "itemId": "PROGRESS_TIMELINE_THEME",
      "kind": "verified"
    },
    {
      "id": "browse-stable-117",
      "at": "2026-10-25T04:13:41.372837+08:00",
      "title": "源安装不再重建后台浏览旧行",
      "detail": "237真实新装后71项，trace旧行销毁0；书架和阅读记录保持。整体24.572ms更新仍继续定位。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "verified"
    },
    {
      "id": "reader-gap-phase-start",
      "at": "2026-10-24T20:20:02.171341+00:00",
      "title": "接回连续阅读短缺页定位",
      "detail": "N068旧日志不足以对应每张图；仅补获取/解码阶段身份后取自然样本。",
      "itemId": "CONTINUOUS_PERFORMANCE",
      "kind": "work"
    },
    {
      "id": "reader-phase-install-091",
      "at": "2026-10-25T04:24:03.373539+08:00",
      "title": "197部署临时阅读阶段日志",
      "detail": "38212929B普通启动，原7项下载保持；34页样本不在下载列表，改由既有历史定位，不新增下载。",
      "itemId": "CONTINUOUS_PERFORMANCE",
      "kind": "work"
    },
    {
      "id": "reader-phase-capture-101",
      "at": "2026-10-24T20:42:33.622Z",
      "title": "完成连续跳页阶段取证",
      "detail": "普通1→17→1录屏已审；等待主要在文件获取后，原因继续细分。",
      "itemId": "CONTINUOUS_PERFORMANCE",
      "kind": "work"
    },
    {
      "id": "reader-phase-restored-108",
      "at": "2026-10-25T04:51:15.837282+08:00",
      "title": "阅读诊断恢复完成",
      "detail": "已撤临时日志并恢复稳定包；原LTR、1/34、7项下载均读回，返回桌面。",
      "itemId": "CONTINUOUS_PERFORMANCE",
      "kind": "checkpoint"
    },
    {
      "id": "source-action-projection-start",
      "at": "2026-10-24T21:00:39.179878+00:00",
      "title": "接续源安装行更新范围",
      "detail": "已查到所有按钮共享排队数组依赖；改为每源状态投影，保留原安装队列。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "source-action-state-121",
      "at": "2026-10-25T05:08:52.421595+08:00",
      "title": "按源状态投影已实测，图标反例保留",
      "detail": "237安装92成功，其他按钮保持正常；本行图标仍有一帧瞬空，继续处理。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "reader-native-phase-start",
      "at": "2026-10-24T21:21:14.910025+00:00",
      "title": "继续细分原生图片显示阶段",
      "detail": "对照旧版后保留图片质量和几何保护；补齐挂载、解码与可见阶段的取证。",
      "itemId": "CONTINUOUS_PERFORMANCE",
      "kind": "work"
    },
    {
      "at": "2026-10-24T21:55:34.719359+00:00",
      "itemId": "BAOZIMH_DAFENG_PAGE_LOAD_FAILURE",
      "title": "200失败已留证；越界操作已停止",
      "detail": "用户001持续失败保留。Root误将取日志扩成点击并改当前章，已释放租约；仅本地分析。大象無形缺角标已定位重复ID触发目录不完整判断，596章未读。"
    },
    {
      "at": "2026-10-24T22:03:59.027842+00:00",
      "title": "重试链与未读数本地修复",
      "detail": "37项回归通过，Release8551719B构建；尚未安装。显式重试刷新章页地址和图片缓存，重复目录未读数恢复精确统计。",
      "kind": "work",
      "itemId": "BAOZIMH_DAFENG_PAGE_LOAD_FAILURE"
    },
    {
      "at": "2026-10-24T22:11:38.285086+00:00",
      "title": "自动恢复完成本地检查；上栏时序新增反例",
      "detail": "40回归、Release8550194B；未安装。上栏必须兼顾状态栏先完成与无状态栏可用，两项均保留；禁止原样恢复旧强制门控。",
      "kind": "work"
    },
    {
      "at": "2026-10-24T22:28:22.413407+00:00",
      "title": "重试CI成功；Koma上下栏退化已定位接线差异",
      "detail": "96a2123精确CI成功。原Koma上下栏被共享默认组件替代，书名/章名未接回，底栏高度不同；当前只读调查。上栏顺序的共同修复仅本地，未装机。",
      "kind": "work"
    },
    {
      "at": "2026-10-24T23:17:32.911413+00:00",
      "title": "237原包栏位基线完成，恢复候选补齐按钮顺序",
      "detail": "仅操作已授权237；001第6/24页正常进出，书架和源注册数据不变。恢复候选尚未安装，200保持不操作。",
      "kind": "work"
    },
    {
      "at": "2026-10-24T23:30:40.397860+00:00",
      "title": "原片否决上栏时序候选，继续修共同绘制边界",
      "detail": "237133标题先高后低，第二次早于状态栏；外观恢复不能抵消此反例。8568166B追加官方单次帧结束回调，待实录。",
      "kind": "work"
    },
    {
      "at": "2026-10-24T23:44:16.563981+00:00",
      "title": "Koma237原栏与显隐具名成立，继续另两宿主",
      "detail": "136两次先状态栏后上栏且无下移；138保存/分享回原生菜单，139同章同页返回。共同8248654已推，N/E构建完但实机仍待。",
      "kind": "work"
    },
    {
      "at": "2026-10-25T00:01:07.871854+00:00",
      "title": "NextN原帧否决共同上栏完成结论",
      "detail": "197113第19→20帧仍下移；保Koma237独立结果，继续查原生安全区与宿主参数顺序。NextE仅安装到下载页，未通过。",
      "kind": "work"
    },
    {
      "at": "2026-10-25T00:18:26.739764+00:00",
      "title": "状态栏真实完成信号修复，NextN原反例消失",
      "detail": "117日志与官方文档定位API回执早于实际显示；119两次原帧已核，E/K继续。原失败和边界保留。",
      "kind": "work"
    },
    {
      "at": "2026-10-25T00:30:46.027208+00:00",
      "title": "共同上栏三宿主具名完成，接回性能候选",
      "detail": "N197119、E197070、K237141原片均已审；K142同章同页与三域保持。原生显示时序共同修复已推，宿主CI收尾与已批准两级缓存候选继续。",
      "kind": "work"
    },
    {
      "at": "2026-10-25T01:12:57.156262+00:00",
      "title": "两级缓存候选开始实机对照",
      "detail": "三宿主签名构建完成；197先用稳定57原内容第12/34页测基线。原5页文件预算保留，分页和清晰度不改；候选未采用。",
      "kind": "work"
    },
    {
      "at": "2026-10-25T02:16:33.961491+00:00",
      "title": "缓存首候选未采用，保留反例后修近邻回翻",
      "detail": "133两处短空保留；N134已恢复稳定包与原LTR1/34。v2保一个现有邻接租约及处理需求，等待真实往返复核。",
      "kind": "work"
    },
    {
      "at": "2026-10-25T02:31:33.432101+00:00",
      "title": "文件需求反例修复，校正实机入口",
      "detail": "v3保住原生退休后仍在预算的文件任务，112检查通过。135误入历史首行已恢复原P2，改按具名686734核入口。",
      "itemId": "CONTINUOUS_PERFORMANCE",
      "kind": "work"
    },
    {
      "at": "2026-10-25T03:08:15.732364+00:00",
      "title": "连续候选在NextN完成同起点对照",
      "detail": "主线程均值4.229→3.224ms、最大24.686→17.883ms；整段快回翻未再见首候选短空。原包/读位已恢复，E/K继续。",
      "kind": "work",
      "itemId": "CONTINUOUS_PERFORMANCE"
    },
    {
      "at": "2026-10-25T03:57:07.211105+00:00",
      "title": "三宿主候选原片审完，保留两处新反例",
      "detail": "N/E/K普通快回翻未再见首候选短空，原包与读位已恢复；E稳定包也有模式切换黑屏无反馈，K固定接缝来源待核，继续共同交接调查。",
      "itemId": "CONTINUOUS_PERFORMANCE",
      "kind": "work"
    },
    {
      "id": "mode-loading-v2-host-observation",
      "at": "2026-10-25T04:47:17.414311+00:00",
      "title": "模式切换加载反馈已在E/N观察到",
      "detail": "E080/N145原图前保留反馈；K151设置遮挡段仍不扩大验收。缓存候选源码已撤出，独立加载修复继续收尾。",
      "itemId": "READER_SETTINGS_STABILITY",
      "kind": "verified"
    },
    {
      "id": "mode-loading-v2-local-commit",
      "at": "2026-10-25T05:01:05.112050+00:00",
      "title": "共同加载修复已独立提交",
      "detail": "e3f3cc1保留现有加载样式；N/E具名路径与读位恢复完成。仅宿主引用/CI收尾，缓存候选未夹带。",
      "itemId": "READER_SETTINGS_STABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "mode-loading-v2-exact-ci",
      "at": "2026-10-25T05:29:41.588880+00:00",
      "title": "共同加载修复三端CI完成",
      "detail": "N/E/K各自精确提交构建成功；未打tag或发布。缓存候选等待采用决定，其余源缺陷继续。",
      "itemId": "READER_SETTINGS_STABILITY",
      "kind": "verified"
    },
    {
      "at": "2026-10-25T06:25:54.527523+00:00",
      "itemId": "SOURCE_WEB_SESSION",
      "id": "mh160-declared-origin-observation",
      "title": "漫画160两版循环已取证，正式包已恢复",
      "detail": "漫画160598定位至本站桌面/手机版交替导航；白屏未修。197已恢复正式包，三业务域完整相同；临时诊断已撤。",
      "kind": "work"
    },
    {
      "id": "image-descriptor-explicit-negative-native",
      "at": "2026-10-25T06:50:58.311802+00:00",
      "title": "图片描述空调用已在197消除",
      "detail": "仅明确不支持者跳过；普通列表50、原书架与数据保持。真实封面403另留，未宣称性能或整源通过。",
      "itemId": "SOURCE_RUNTIME_ERRORS",
      "kind": "verified"
    },
    {
      "id": "source-home-content-contract-review",
      "at": "2026-10-25T06:59:08.455064+00:00",
      "title": "源首页与栏目结构已查清",
      "detail": "发现两类内容同时加载、首尾拼接；具体统一方案待用户决定，尚未改界面。空调用修复CI已成功。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "work"
    },
    {
      "id": "source-install-current197-trace605",
      "at": "2026-10-25T07:32:35.653340+00:00",
      "title": "当前包安装卡顿仍存在",
      "detail": "東立正常更新并返回，其他84源与书架/阅读保持；主线程回调74ms、实际帧33ms，具体CPU函数继续定位。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "source-language-key197-verified",
      "at": "2026-10-25T07:49:01.890199+00:00",
      "title": "语言热路径警告已修正",
      "detail": "197普通源包页及返回已核，名称/顺序/原数据保持。74ms安装总项仍开放；没有重装源制造通过。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "verified"
    },
    {
      "id": "source-projection-probe197-restored",
      "at": "2026-10-25T08:09:05.299444+00:00",
      "title": "只读分段计时完成并撤回",
      "detail": "摘要6ms、Manager DTO4–5ms，不足解释74ms。197正式包及原数据已恢复，后继核237真实更新。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "source-huanta011-first-install237",
      "at": "2026-10-25T08:30:50.578477+00:00",
      "title": "237幻塔首次安装完成",
      "detail": "72→73只增幻塔，原数据保持。安装主回调仍47ms；接续该源原待验正文，不据安装成功关闭卡顿。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "huanta237-native-first-reader-and-worker-boundary",
      "at": "2026-10-25T08:59:04.009414+00:00",
      "title": "幻塔237首篇正文成功；发现后台模块边界异常",
      "detail": "完整长图与HTTP200已核，原书架/旧记录保持。安装47ms未闭；接独立Native worker入口修复。",
      "itemId": "SOURCE_RUNTIME_ERRORS",
      "kind": "work"
    },
    {
      "id": "native-worker237-six-entry-route",
      "at": "2026-10-25T09:13:06.344120+00:00",
      "title": "Native后台入口隔离：237普通阅读与原数据保持",
      "detail": "新进程首次源worker及取页worker未再出现UI状态异常，正文与返回已审；接范围提交及精确CI。安装长回调继续开放。",
      "itemId": "SOURCE_RUNTIME_ERRORS",
      "kind": "work"
    },
    {
      "id": "source-worker-pushed-cpu-soc237",
      "at": "2026-10-25T09:19:37.696005+00:00",
      "title": "六Native入口修复已同步；继续安装CPU定位",
      "detail": "精确CI40179763215执行中；以原待验SOC001正常首装采一次主线程函数栈，采后恢复。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "source-install-soc237-cpu-and-restore",
      "at": "2026-10-25T09:31:11.020873+00:00",
      "title": "安装CPU栈已取；临时采样已撤回",
      "detail": "SOC正常首装73→74，旧数据保持；定位注册持久化27ms与校验11ms。237已恢复正式包，继续原待验正文。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "source-home-approved-native-batch-observed",
      "at": "2026-10-25T10:19:40.067847+00:00",
      "title": "首页统一方案已获采用；当前修复继续收尾",
      "detail": "Native文件检查本次2010us/持久化6ms，主回调仍25ms。先完成当前IPmini路径与提交CI，再实施已批准入口/内容变化。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "decision"
    },
    {
      "id": "native-file-batch-ipmini237-readback",
      "at": "2026-10-25T10:40:24.973027+00:00",
      "title": "IPmini首篇与自然返回完成；提交安装检查优化",
      "detail": "原图HTTP200，原书架和旧记录保持；75文件检查约2ms，残余主回调25ms保留。接已批准首页统一。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "source-home-native-selector-implemented",
      "at": "2026-10-25T10:50:33.497995+00:00",
      "title": "首页统一已实现；进入237普通路径验证",
      "detail": "安装检查62621dd1精确CI成功。新源页面只加载当前首页/栏目，保刷新旧内容与失败目标，实机待验。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "work"
    },
    {
      "id": "fresh-thread-migration-handoff",
      "at": "2026-10-25T11:18:17.987020+00:00",
      "title": "按用户要求准备轻量新会话续接",
      "detail": "当前筛选验证已收口；237原书架、三域及筛选保持，旧租约已释放。首页WIP与其余原队列交新会话，定时任务将保原频率迁移。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "work"
    },
    {
      "id": "source-home-nohome-accepted",
      "at": "2026-10-25T11:27:24.815372+00:00",
      "title": "无首页Comic Fury分类路径通过，准备范围同步",
      "detail": "237热门/最新两栏目及单一12本内容、对勾、原书架自然返回均亲审；195三域/筛选保持。漫画柜本次连接超时仅限制该样本。10分钟heartbeat已读回迁到本会话。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "work"
    },
    {
      "id": "source-home-exact-ci-success",
      "at": "2026-10-25T11:31:54.880323+00:00",
      "title": "首页统一已推且精确CI成功，继续安装残余",
      "detail": "e6404c5b/40188955447 completed-success；237正式首页具名范围冻结，新的CPU诊断仅定位安装回调。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "done"
    },
    {
      "id": "filter-clear-label-native-accepted",
      "at": "2026-10-25T11:41:55.799844+00:00",
      "title": "筛选清除文案/原动作237具名通过",
      "detail": "只将App首项改清除此项筛选，源全部和材质/顺序保留；原重置/返回及三域/空偏好保持。CPU临时代码已撤，继续安装残余。",
      "itemId": "SOURCE_FILTERS",
      "kind": "work"
    },
    {
      "id": "source-import-digest-background-native",
      "at": "2026-10-25T11:55:58.652959+00:00",
      "title": "摘要真实后台10ms，原安装总项继续开放",
      "detail": "237一次杂志迷首装成功且旧76/书架/读态保持，原书架自然返回。当前56ms回调与旧25ms频率/GC不同，不作AB或整体流畅结论。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "source-local-icon-decoded-handoff-native",
      "at": "2026-10-25T12:07:27.443409+00:00",
      "title": "本行图标Happy普通安装96帧具名保持",
      "detail": "首次异步/同URI已解码同步回交，保所有原生样式。完整原片/5联系表及全部0–69图标表亲审；旧77与用户数据保持，原书架自然返回。",
      "itemId": "SOURCE_PACKAGE_ICON_INVALIDATION",
      "kind": "work"
    },
    {
      "id": "source-row-names-once-20261025",
      "at": "2026-10-25T23:03:09+08:00",
      "title": "消除单次源行排序的重复名称解析，237普通更新数据保持",
      "detail": "274原实现与候选真实方法同28项通过；276签名8582236B明确装。278普通本地015同版本更新74帧/3sheet已审，280管理/原书架亲审，281四域保持/传包已清；2ms行投影只属本样本，安装46ms仍OPEN。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "diagnostics-safe-snapshot-20261025",
      "at": "2026-10-25T23:58:06+08:00",
      "title": "日志重复脱敏优化普通多输出通过；TXT显示候选单独待决定",
      "detail": "实际时间标记5→6、保存后7，628B持久/4028B HiLog各含marker和saved事件；实际外部563B内容与持久前缀一致。错误文件后缀由真实文件名定位；正确SDK参数改变原生选中显示，候选已撤。294恢复日志优化包和四域，295原书架亲审。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "work"
    },
    {
      "id": "partial-index-review-20261026",
      "at": "2026-10-25T19:27:00.913651+00:00",
      "title": "按人类纠正撤回追加计数候选，核清部分成功完整性缺口",
      "detail": "原生产方法离线受控输入复现最新/未找到误判；已有地址行可定位并重载，无新UI或状态许可。307采样另完成同trace对齐，排除program等同忙CPU与诊断开销误归因，正式300阻塞仍未闭。",
      "itemId": "SOURCE_INDEX_CACHE_REVALIDATE",
      "kind": "work"
    },
    {
      "at": "2026-10-27T17:06:39+08:00",
      "title": "提交启动兼容修复",
      "detail": "61c79b6b；API23实机和AGC回验未完成。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T18:02:54+08:00",
      "title": "提交源HTTP批量能力",
      "detail": "7230d110；具名目录路径已验，未外推全部卡顿。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T19:12:51+08:00",
      "title": "提交源设置标题和说明修复",
      "detail": "3058c4c0；237具名设置范围已验证，其他边界保留。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T20:21:55+08:00",
      "title": "提交FGO官方系列名称",
      "detail": "源提交779a3a8；本地237包展示具名，公开包Native未验。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T20:24:29+08:00",
      "title": "提交源说明文档整理",
      "detail": "c5bd024及前序提交已推；源CI和Docs CI成功，公开FGO包已读取。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T23:28:23+08:00",
      "title": "提交Komiic筛选身份候选",
      "detail": "源仓本地50ac39f；真实站点和237未验。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T15:31:05Z",
      "title": "Komiic .8 已公开",
      "detail": "源owner实时核release 425642863及公开实体；CI 40531345834 success，Native目录和旧章未验。",
      "kind": "verified"
    },
    {
      "at": "2026-10-27T23:37:28+08:00",
      "title": "提交漫画社简介候选",
      "detail": "源仓本地c278dcc；公开发布和设备验收未确认。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T15:39:48Z",
      "title": "漫画社 .8 已公开",
      "detail": "源owner实时核release 425653118及公开实体；CI 40532855572 success，Native未验。",
      "kind": "verified"
    },
    {
      "at": "2026-10-27T15:45:16.472345Z",
      "title": "进度页显示修正",
      "detail": "时间依据为页面文件修改时间，不代表用户操作时刻。",
      "kind": "work"
    },
    {
      "at": "2026-10-27T15:49:21.096710Z",
      "title": "NextE共享Reader候选构建通过",
      "detail": "时间依据为构建日志最后写入；临时依赖已恢复，设备未验。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T15:50:25.144010Z",
      "title": "NextN共享Reader候选构建通过",
      "detail": "时间依据为构建日志最后写入；临时依赖已恢复，设备未验。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T16:02:15.778404Z",
      "title": "NextE旧阅读器双页候选构建完成",
      "detail": "时间为构建日志最后写入；设备画面未验。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T16:04:20.561295Z",
      "title": "NextN旧阅读器双页候选构建完成",
      "detail": "时间为构建日志最后写入；设备画面未验。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T16:15:47Z",
      "title": "动漫屋简介修复已发布",
      "detail": "发布及公开包已核；设备验证使用本地候选。",
      "kind": "verified"
    },
    {
      "at": "2026-10-27T16:19:32.532604Z",
      "title": "进度页面板已整理",
      "detail": "时间为页面文件最后写入；保留当前待办与历史证据。",
      "kind": "work"
    },
    {
      "at": "2026-10-27T16:29:17.430040Z",
      "title": "旧阅读器滑动后点击修正已构建",
      "detail": "时间为构建日志最后写入；本地构建通过，设备未验。",
      "kind": "checkpoint"
    },
    {
      "at": "2026-10-27T16:36:16Z",
      "title": "Comic Fury作者附言说明修正已发布",
      "detail": "公开包已核；设备验证使用本地候选。",
      "kind": "verified"
    },
    {
      "id": "reader-rtl-counter-fix-20261028",
      "at": "2026-10-28T10:35:00+08:00",
      "title": "RTL滑块页码修复已编译",
      "detail": "Koma fixedCounterSides改为false，使页码随RTL滑块交换；设备未验。",
      "itemId": "READER_RTL_SLIDER_COUNTERS",
      "kind": "checkpoint"
    },
    {
      "id": "reader-crosschapter-197-20261028",
      "at": "2026-10-28T06:07:00+08:00",
      "title": "197分页跨章点击与竖滑通过",
      "detail": "蓝色档案每章1页，连点跨到第12章，进度同步；条漫模式未验。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "verified"
    },
    {
      "id": "reader-doubletap-197-20261028",
      "at": "2026-10-28T06:05:00+08:00",
      "title": "双击缩放开关与档位197验证",
      "detail": "150-500ms档位可保存，关闭双击后单击跨章成功；原名值已恢复。",
      "itemId": "READER_DOUBLE_TAP_PREFERENCE",
      "kind": "verified"
    },
    {
      "id": "reader-settings-placement-audit-20261028",
      "at": "2026-10-28T10:40:00+08:00",
      "title": "方向/模式菜单重复入口记录",
      "detail": "控制栏两按钮与设置PageModeMenu/DirectionMenu重复；未实施结构改动。",
      "itemId": "READER_SETTINGS_PLACEMENT",
      "kind": "checkpoint"
    },
    {
      "id": "reader-translation-crosschapter-fix-20261028",
      "at": "2026-10-28T10:42:00+08:00",
      "title": "跨章翻译不继承当前章页控制",
      "detail": "KomaReaderLabPage translationPreference修复；28项测试通过。",
      "itemId": "MANGA_TRANSLATION_PREPROCESS",
      "kind": "verified"
    },
    {
      "id": "reader-rtl-counter-fix-20261028b",
      "at": "2026-10-28T10:43:00+08:00",
      "title": "RTL滑块页码修复已编译",
      "detail": "fixedCounterSides改为false；设备未验。",
      "itemId": "READER_RTL_SLIDER_COUNTERS",
      "kind": "checkpoint"
    },
    {
      "id": "reader-enhancement-toggle-code-20261028",
      "at": "2026-10-28T10:46:00+08:00",
      "title": "超分临时关闭入口已核清",
      "detail": "ReaderEnhancementStatus点击切换ReaderTemporaryVariantControl，仅当前单元临时覆盖；设备未验。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-toggle-device-20261028",
      "at": "2026-10-28T10:48:00+08:00",
      "title": "超分临时关闭图标设备未出现",
      "detail": "197增强关闭，控制栏无AI-HD图标；代码路径已核清，设备验证缺已处理页。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "continuous-boundary-guard-20261028",
      "at": "2026-10-28T10:52:00+08:00",
      "title": "条漫章末跨章请求已加防重入",
      "detail": "滚动到底仅每拓扑/导航请求一次下一章，导航变化后重置；测试与release构建通过，实机未验。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "cont-device-awake-blocked-20261028",
      "at": "2026-10-28T10:56:00+08:00",
      "title": "条漫跨章实机验证被设备状态门禁拒绝",
      "detail": "自动审批拒绝唤醒/解锁/改超时；未发生设备动作，租约已释放。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "reader-197-resume-2026-10-28T10-59-24+08-00",
      "at": "2026-10-28T10:59:24+08:00",
      "title": "接续197条漫跨章验证",
      "detail": "已完成唤醒、解锁和亮屏读回，继续原样本；条漫结果尚未验证。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "open",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/wake-resume-01/"
      ]
    },
    {
      "id": "reader-continuous-motion-failed-2026-10-28T11-03-30+08-00",
      "at": "2026-10-28T11:03:30+08:00",
      "title": "条漫跨章真实复现黑屏和图片缩放",
      "detail": "197两次上滑均跨章且章节名提示出现；画面衔接未通过，继续修复。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-scroll-motion-05/"
      ]
    },
    {
      "id": "continuous-handoff-fix-2026-10-28T11-27-36+08-00",
      "at": "2026-10-28T11:27:36+08:00",
      "title": "条漫跨章黑屏及缩放修复进入本地构建",
      "detail": "补本地页预载尺寸，保留旧章画面到新章真实可见；尚未取得修复后真机结果。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "continuous-binding-repair-2026-10-28T11-37-52+08-00",
      "at": "2026-10-28T11:37:52+08:00",
      "title": "条漫候选未通过，已修正快照传递回归",
      "detail": "保留失败录屏；重新构建后仍需197真实回验。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-motion-09/"
      ]
    },
    {
      "id": "continuous-remaining-black-frame-2026-10-28T11-47-20+08-00",
      "at": "2026-10-28T11:47:20+08:00",
      "title": "条漫图片尺寸正常，回翻黑帧继续修复",
      "detail": "双向跨章、章节名和进度已观察；回翻仍有一帧加载黑屏，整项未通过。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v2-motion-12/"
      ]
    },
    {
      "id": "reader-rtl-counters-observed-20261028",
      "at": "2026-10-28T11:57:15+08:00",
      "title": "197观察到RTL滑块两侧数字交换",
      "detail": "RTL左8右2，原LTR左2右8；完整滑动方向仍待确认。此时间是记录时间。",
      "itemId": "READER_RTL_SLIDER_COUNTERS",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-counters-17/"
      ]
    },
    {
      "id": "reader-197-rtl-ltr-page-direction-20261028",
      "at": "2026-10-28T12:01:20+08:00",
      "title": "197单页样本RTL页码及页内方向通过",
      "detail": "RTL右滑2到3、左滑返回，页码左8右3；LTR左滑2到3、右滑返回。已恢复样本原纵向分页；跨章方向未验。此时间是记录时间。",
      "itemId": "READER_RTL_SLIDER_COUNTERS",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-next-swipe-18/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/rtl-restore-ltr-19/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/ltr-next-swipe-20/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/restore-sample-original-mode-21/"
      ]
    },
    {
      "id": "reader-197-swipe-page-direction-20261028",
      "at": "2026-10-28T12:01:20+08:00",
      "title": "197单页样本左右滑动方向通过",
      "detail": "RTL右滑前进、左滑返回；LTR左滑前进、右滑返回。跨章及其他未覆盖范围仍开放。此时间是记录时间。",
      "itemId": "READER_SWIPE_DIRECTION_MISMATCH",
      "kind": "checkpoint"
    },
    {
      "id": "continuous-pixel-receipt-v3-built-20261028",
      "at": "2026-10-28T12:01:20+08:00",
      "title": "条漫真实像素回执候选已构建",
      "detail": "v3构建产物hash以4444ee46开头，尚未安装；v2两处回翻各一帧黑屏仍未通过。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "continuous-v3-197-recorded-20261028",
      "at": "2026-10-28T12:08:34+08:00",
      "title": "条漫v3候选197已安装并完成录屏",
      "detail": "候选4444ee46c726a2f928e40bbd748933e0af8acbc68b0137000a6aed19a9e345cf已安装；普通蓝档正文显示无loading，四次双向跨章录屏正在解码审查，未判通过。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/candidate-v3-install-23/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/candidate-v3-reader-25/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v3-motion-26/"
      ]
    },
    {
      "id": "reader-size-v3-197-reviewed-20261028",
      "at": "2026-10-28T12:12:54+08:00",
      "title": "197蓝档单页章条漫尺寸交接通过",
      "detail": "v3四次跨章旧图直接交接最终尺寸新图，未见先小后大或黑帧；分页范围仍待验证。此时间是记录时间。",
      "itemId": "READER_PAGE_SIZE_SHRINK",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v3-motion-26/"
      ]
    },
    {
      "id": "continuous-v3-197-reviewed-20261028",
      "at": "2026-10-28T12:12:54+08:00",
      "title": "197蓝档单页章条漫双向跨章通过",
      "detail": "四次跨章与四个Toast已逐区间审查，画面未见黑帧或先小后大；返回书架第六话第1页100%与起点往返一致。分页跨章与点击延迟待补验；两宿主构建成功不等于运行验收。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-candidate-v3-motion-26/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/candidate-v3-return-27/"
      ]
    },
    {
      "id": "source-settings-3hentai-237-20261028",
      "at": "2026-10-28T12:16:50+08:00",
      "title": "3Hentai设置往返237已验证",
      "detail": "真实官网25本目录中，完整标题切为短标题并保存，清除本次设置后完整标题恢复；设置前后相等，原书架和继续阅读恢复，临时上传清除，设备休眠并释租。仅该源具名范围通过，全源审计继续。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai237-current/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-3hentai237-final-20261028/run-metadata.json"
      ]
    },
    {
      "id": "continuous-user-counterexample-2026-10-28T12-20-45+08-00",
      "at": "2026-10-28T12:20:45+08:00",
      "title": "撤回条漫连续通过，用户指出仍整章替换",
      "detail": "v3只修复黑屏与缩放；连续列表衔接未实现，继续修复。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "continuous-strip-built-2026-10-28T12:33:01+08:00",
      "at": "2026-10-28T12:33:01+08:00",
      "title": "连续跨章改为同一列表，候选待验",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "detail": "已构建；不沿用v3整章替换的通过结论。",
      "kind": "checkpoint"
    },
    {
      "id": "continuous-strip-197-observed-20261028",
      "at": "2026-10-28T12:43:02+08:00",
      "title": "197已观察相邻章同屏与双向滚动",
      "detail": "候选2199…同一列表内两章同屏、双向自然滚动及Toast；普通返回后继续阅读卡片与控制栏章节一致。最终候选38c5ef5e…正在录制滑动及点击，尚未验完。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-motion-33/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-return-35/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-final-motion-38/"
      ]
    },
    {
      "id": "source-zerobyw-pc-candidate-20261028",
      "at": "2026-10-28T12:43:02+08:00",
      "title": "Zerobyw新路由候选生产WASM已核",
      "detail": "旧路由真实404；0.1.4候选按参考新/pc/路由，生产WASM返回目录24、中文搜索1、详情5章和首章118图；237新包、旧ID及图片实取未验，全源审计继续。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "continuous-strip-reverse-click-jump-20261028",
      "at": "2026-10-28T13:02:26+08:00",
      "title": "197反向点击出现章节跳动",
      "detail": "交付候选d0ad49…录屏frame304–320短暂显示更早章再回到当前附近；返回后阅读器与书架同为第五话，不能抵消跳动。正在提前准备视口前邻章元数据，并让明确点击退休入场定位令牌；尚未修复验收。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-delivery-motion-43/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-strip-delivery-return-44/"
      ]
    },
    {
      "id": "continuous-strip-head-trim-diagnosis-20261028",
      "at": "2026-10-28T13:30:58+08:00",
      "title": "197定位跨章删头造成偏移变化",
      "detail": "两次物理左点均解析action=right，无新seek或geometry；跨章rows删头后offset改变。已移除元数据跨章删头并保远处图像资源预算，281fe…候选正在197回验，尚未判通过。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-position-probe-motion-48/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-stable-head-probe-motion-50/"
      ]
    },
    {
      "id": "continuous-clean-197-clicks-20261028",
      "at": "2026-10-28T14:22:18+08:00",
      "title": "197清理包双向点击未再回跳",
      "detail": "同一列表保留相邻章节；正文、控制栏和书架读回同为第四话。普通重入后自然滚动仍在补验，事项未关闭。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-page-end-motion-52/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-page-end-return-53/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-clean-reenter-54/"
      ]
    },
    {
      "id": "zerobyw-public-237-20261028",
      "at": "2026-10-28T14:22:18+08:00",
      "title": "Zerobyw公开包237具名阅读路径通过",
      "detail": "公开0.1.4普通导入后目录24、详情5章、正文1/149，设备已恢复；原默认域名EOF及旧ID等仍待调查，不外推全源。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zerobyw237-public/"
      ]
    },
    {
      "id": "continuous-natural-terminal-mismatch-20261028",
      "at": "2026-10-28T15:00:25+08:00",
      "title": "197自然滚动末端章节状态未跟随画面",
      "detail": "同一列表末端已完整显示下一章图且无法继续向下，控制栏和书架仍为第六话、章节2/15。正在以原生实际边界修复位置判断；候选尚未设备回验。此前双向点击具名结果保留。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-footer-motion-58/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-clean-return-59/"
      ]
    },
    {
      "id": "continuous-native-terminal-197-20261028",
      "at": "2026-10-28T15:19:45+08:00",
      "title": "197自然滚动末端章节状态已回验",
      "detail": "新包正反正自然滑动录屏已审，末屏正文、控制栏和书架章节一致；旧58/59错误状态保留。分页跨章仍在验证，原生边界小修尚未提交。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-native-end-install-60/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-native-end-motion-61/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/continuous-native-end-return-62/"
      ]
    },
    {
      "id": "zerobyw-015-default-20261028",
      "at": "2026-10-28T15:19:45+08:00",
      "title": "Zerobyw默认地址本地候选237具名通过",
      "detail": "本地候选未保存地址时目录24、详情5章及正文1/162实图；公开WASM默认目录24项。公开包字节与本地候选不同，公开Native仍待验证；全源审计未闭。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zerobyw237-default015/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zerobyw237-public015/public-wasm-default-list.json"
      ]
    },
    {
      "id": "source-two-names-reviewed-20261028",
      "at": "2026-10-28T15:19:45+08:00",
      "title": "CManhua和NoyAcg官网名称已核",
      "detail": "两站主页标题与当前显示名一致；CManhua页脚关联站点的关系未知，全源名称审计未闭。此时间是记录时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint"
    },
    {
      "id": "paged-boundary-loading-failed-20261028",
      "at": "2026-10-28T16:12:10+08:00",
      "title": "197分页跨章出现清空加载",
      "detail": "LTR点击和滑动到正确相邻章，但录屏多处清空显示准备图片；RTL仅到准备态，跨章未验。条漫末端已验证范围保留。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-ltr-boundary-motion-66/"
      ]
    },
    {
      "id": "xkcd-016-public-wasm-20261028",
      "at": "2026-10-28T16:12:10+08:00",
      "title": "xkcd分组候选及公开WASM已核",
      "detail": "0.1.6提交8e82be2已推，CI40652065192成功；保默认和旧ID，公开WASM真实按年目录通过；237设置、旧书和分组正文未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xkcd-organization-reference/candidate-016/"
      ]
    },
    {
      "id": "source-miaoqu-name-public-20261028",
      "at": "2026-10-28T16:12:10+08:00",
      "title": "妙趣名称修正已发布",
      "detail": "妙趣0.1.3提交8b47f95已推，CI40653900755成功，公开包已核、Native未验；Zazhimi中文品牌未知、图标匹配，无限动漫标题及图标匹配。全源核验未闭。此时间是记录时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/miaoqu-name013/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zazhimi-identity/"
      ]
    },
    {
      "id": "koma-reader-caller-dependencies-ci-20261028",
      "at": "2026-10-28T16:19:16+08:00",
      "title": "Koma阅读器调用依赖补齐并通过CI",
      "detail": "原CI因漏调用依赖失败；补齐提交已推且精确CI成功。分页跨章清空加载仍未解决，设备验收不由CI代替。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "paged-window-rtl-auto_chapter_boundary_target-20261028",
      "at": "2026-10-28T16:37:18+08:00",
      "title": "197分页RTL单页章跨章具名回验",
      "detail": "RTL点击及滑动双向跨章正确，画面连续且Toast对应；LTR及多页章、保存进度未验，本批未提交推送。 此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-motion-71/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-observed-72/"
      ]
    },
    {
      "id": "paged-window-rtl-reader_page_size_shrink-20261028",
      "at": "2026-10-28T16:37:18+08:00",
      "title": "197分页RTL单页章尺寸交接已观察",
      "detail": "71全帧审查未见先小后大或旧清屏；LTR及多页章待验。 此时间是记录时间。",
      "itemId": "READER_PAGE_SIZE_SHRINK",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-motion-71/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-observed-72/"
      ]
    },
    {
      "id": "paged-window-rtl-reader_swipe_direction_mismatch-20261028",
      "at": "2026-10-28T16:37:18+08:00",
      "title": "197分页RTL单页章双向方向已核",
      "detail": "右点击及右滑下一章、左点击及左滑上一章；LTR跨章及多页章待验。 此时间是记录时间。",
      "itemId": "READER_SWIPE_DIRECTION_MISMATCH",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-motion-71/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-rtl-observed-72/"
      ]
    },
    {
      "id": "source-name-batch-20261028",
      "at": "2026-10-28T16:37:18+08:00",
      "title": "书源名称与图标逐站核对",
      "detail": "多站名称具名核对；92漫画网及漫画1234官网标志与现图不同，名称及图标差异尚未修改，部分站点不可访问或无法确认。全源未闭。此时间是记录时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/"
      ]
    },
    {
      "id": "source-webtoon-mycomic-settings-audit-20261028",
      "at": "2026-10-28T16:37:18+08:00",
      "title": "WEBTOON及MyComic设置消费源码复核",
      "detail": "WEBTOON三项实际消费及默认已核，附言依赖宿主；MyComic沿用既有默认并记录参考差异，未作设备验收。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "paged-window-ltr-auto_chapter_boundary_target-20261028",
      "at": "2026-10-28T16:44:20+08:00",
      "title": "197分页单页章双方向及五次跨章已核",
      "detail": "LTR双向点击及滑动往返，五次连续跨章无清空，返回进度一致；多页章末反向待验。 此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-ltr-motion-74/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-chapters-motion-76/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-progress-77/"
      ]
    },
    {
      "id": "paged-window-ltr-reader_page_size_shrink-20261028",
      "at": "2026-10-28T16:44:20+08:00",
      "title": "197分页单页章画面衔接已核",
      "detail": "LTR双向及五次连续跨章未见清空或先小后大；多页章待验。 此时间是记录时间。",
      "itemId": "READER_PAGE_SIZE_SHRINK",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-ltr-motion-74/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-chapters-motion-76/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-progress-77/"
      ]
    },
    {
      "id": "paged-window-ltr-reader_swipe_direction_mismatch-20261028",
      "at": "2026-10-28T16:44:20+08:00",
      "title": "197分页LTR单页章双向方向已核",
      "detail": "左点击/左滑下一章、右点击/右滑上一章；多页章末反向待验。 此时间是记录时间。",
      "itemId": "READER_SWIPE_DIRECTION_MISMATCH",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-ltr-motion-74/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-chapters-motion-76/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-five-progress-77/"
      ]
    },
    {
      "id": "paged-multipage-unreached-20261028",
      "at": "2026-10-28T17:02:25+08:00",
      "title": "197多页样本未触发跨章",
      "detail": "Nemo录屏动作未发生章节切换，终态仍3/3、1/2；已恢复进入前2/3并返回书架。原因未确定，最终候选安装回验中。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-multipage-boundary-motion-81/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-multipage-returned-82/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-multipage-restore-83/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-install-84/"
      ]
    },
    {
      "id": "paged-nemo-vertical-boundary-20261028",
      "at": "2026-10-28T17:19:11+08:00",
      "title": "197 Nemo纵向返回前章末页已观察",
      "detail": "原偏好为纵向分页，先前横滑未触发不代表产品失败；上下滑反向返回3/3，前向仍出现准备图片，未判无缝。最终包代表路径仍待回验。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-install-84/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-vertical-last-85/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-vertical-boundary-motion-86/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-vertical-returned-87/"
      ]
    },
    {
      "id": "paged-reviewed-blue-nemo-restored-20261028",
      "at": "2026-10-28T17:27:52+08:00",
      "title": "197最终包Blue代表路径及读态恢复",
      "detail": "Nemo恢复2/3并返回书架；Blue恢复原RTL，最终包右点击前进、左滑返回画面连续，阅读器、详情及书架状态一致。Nemo无verified sequence前向仍有加载；共享提交正在推送，远端及CI未确认。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-nemo-restore-89/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-bookshelf-resume-90/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-blue-direction-93/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-blue-motion-95/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-blue-return-96/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-reviewed-bookshelf-97/"
      ]
    },
    {
      "id": "reader-delivery-restored-197-20261028",
      "at": "2026-10-28T17:31:11+08:00",
      "title": "阅读器提交已推，197状态已恢复",
      "detail": "共享提交远端已精确读回，Koma接入已推、新CI尚未查；197恢复超时10000、休眠并释租。Nemo前向加载边界保留。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/paged-window-session-restore-98/"
      ]
    },
    {
      "id": "koma-d722-ci-success-20261028",
      "at": "2026-10-28T17:34:56+08:00",
      "title": "Koma阅读器接入精确CI成功",
      "detail": "d7225df60a89d24d214bc0277000b6d2e8ed2244的CI40664700417 completed/success；不扩大197具名真机范围。此时间是记录时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40664700417"
      ]
    },
    {
      "id": "source-concurrent-237-mh160-return-20261028",
      "at": "2026-10-28T17:48:55+08:00",
      "title": "237并发搜索漫画160验证自动回流",
      "detail": "真实403触发验证后无用户输入回结果，显示10条作品；包子挑战排队及重试尚待确认，原scope与设备状态尚待恢复。007无查询不计验证。此时间是记录时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/awake-baseline-002/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/candidate-install-003/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/real-source-parallel-search-007/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/real-source-parallel-search-008/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/first-challenge-state-009/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/automatic-retry-receipts-010/"
      ]
    },
    {
      "id": "source-concurrent-237-baozi-return-20261028",
      "at": "2026-10-28T17:54:58+08:00",
      "title": "237并发搜索包子挑战自动回流",
      "detail": "单源过滤日志确认原请求验证一次并搜索ready 6条，008后无额外输入；漫画160显示10条。包子窗口标题未截图，其他挑战边界仍开放；设备待恢复。此时间是记录时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/filtered-web-receipts-012/run-metadata.json"
      ]
    },
    {
      "id": "source-concurrent-commit-public-updates-20261028",
      "at": "2026-10-28T18:11:46+08:00",
      "title": "统一搜索修复已推，237公开包更新进行中",
      "detail": "相关提交已推、精确CI运行中；漫画1234公开更新Native成功，漫画社已安装，妙趣仍观察，设备和设置待总恢复。此时间是记录时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/restore-original-scope-013/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/public-update-targets-016/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mh1234-public-completion-018/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe-public-completion-020/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/miaoqu-public-completion-022/"
      ]
    },
    {
      "id": "source-mirrors-published-20261028",
      "at": "2026-10-28T18:11:46+08:00",
      "title": "漫画社与GoDa镜像候选已发布",
      "detail": "两源公开包及具名WASM路径已核；漫画社237已安装但设置/正文未验，GoDa Native及全旧库映射未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/manhuashe-mirror019/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/goda-mirror014/"
      ]
    },
    {
      "id": "source-concurrent-ci-miaoqu-20261028",
      "at": "2026-10-28T18:15:28+08:00",
      "title": "统一搜索修复CI成功，妙趣公开更新完成",
      "detail": "e294对应CI40670008826成功且head一致；237妙趣0.1.3更新及名称已读回，漫画社仅安装、设置和正文未验。scope已恢复，仍持租。此时间是记录时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40670008826",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/miaoqu-public-completion-022/"
      ]
    },
    {
      "id": "sixmh-search-user-report-20261028",
      "at": "2026-10-28T18:30:58+08:00",
      "title": "登记六漫画源内搜索不支持反馈",
      "detail": "用户报告源内搜索失败并询问其他不能搜索的源；237统一搜索已有unsupported线索，源内入口尚待验证。此时间为记录时间。",
      "itemId": "SIXMH_SEARCH_UNSUPPORTED",
      "kind": "open",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/real-source-parallel-search-008/"
      ]
    },
    {
      "id": "sixmh-search-missing-port-20261028",
      "at": "2026-10-28T18:40:31+08:00",
      "title": "六漫画搜索确认漏移植",
      "detail": "固定参考与官网支持搜索，真实请求200并有结果；Koma 0.1.4未实现，源侧修复中，Native旧版普通入口仍在核。其余源逐项核对，不把旧快照当当前结果。此时间是记录时间。",
      "itemId": "SIXMH_SEARCH_UNSUPPORTED",
      "kind": "checkpoint"
    },
    {
      "id": "zerobyw-public-import-identity-20261028",
      "at": "2026-10-28T18:40:31+08:00",
      "title": "237 Zerobyw公开包导入及字节核对",
      "detail": "公开0.1.5普通导入，安装ZIP及WASM与公开实体逐字一致；设置保持，临时文件清除并返回Browse。xkcd公开包安装完成，设置及正文未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-picker-import-031/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-public-proof-to-browse-032/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd-public-update-024/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd-completion-zero-identity-025/"
      ]
    },
    {
      "id": "sixmh-native-old-failure-20261028",
      "at": "2026-10-28T18:44:07+08:00",
      "title": "237普通入口复现六漫画搜索不支持",
      "detail": "0.1.4源目录正常，搜索一人之下显示源搜索失败及不支持该操作；0.1.5候选已推，本地WASM具名通过，公开包和Native修复仍待验。此时间是记录时间。",
      "itemId": "SIXMH_SEARCH_UNSUPPORTED",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh-ordinary-source-035/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh014-search-failure-036/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/sixmh-search015/"
      ]
    },
    {
      "id": "3hentai-search-self-audit-20261028",
      "at": "2026-10-28T18:49:00+08:00",
      "title": "自检发现3Hentai搜索漏移植",
      "detail": "固定参考及官网支持搜索，当前源未实现；候选遇asset host错误，Native尚未验。首次发现时间未独立核实，此为登记时间。",
      "itemId": "THREE_HENTAI_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/love.json"
      ]
    },
    {
      "id": "sixmh-search-public-015-20261028",
      "at": "2026-10-28T18:49:00+08:00",
      "title": "六漫画搜索公开包已核",
      "detail": "0.1.5精确CI成功，公开WASM具名搜索返回两项；237同入口回验仍在进行。此时间为登记时间。",
      "itemId": "SIXMH_SEARCH_UNSUPPORTED",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/sixmh-search015/"
      ]
    },
    {
      "id": "sixmh-search-native-015-20261028",
      "at": "2026-10-28T18:57:32+08:00",
      "title": "237六漫画公开搜索修复已验证",
      "detail": "公开更新0.1.5后普通入口搜索返回两本及封面，无旧不支持提示；只关闭该源搜索漏实现。此时间是记录时间。",
      "itemId": "SIXMH_SEARCH_UNSUPPORTED",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh015-update-completed-041/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/sixmh015-ordinary-search-042/"
      ]
    },
    {
      "id": "3hentai-search-public-014-20261028",
      "at": "2026-10-28T18:57:32+08:00",
      "title": "3Hentai公开搜索WASM已核",
      "detail": "0.1.4精确CI成功，公开WASM真实搜索返回25项及下一页；237 Native待验。此时间是记录时间。",
      "itemId": "THREE_HENTAI_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/public-search.json"
      ]
    },
    {
      "id": "3hentai-search-native-014-20261028",
      "at": "2026-10-28T19:09:59+08:00",
      "title": "237 3Hentai公开搜索修复已验证",
      "detail": "普通入口搜索love成功，前6项封面可见；仅关闭该源搜索漏实现范围。此时间是记录时间。",
      "itemId": "THREE_HENTAI_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/threehentai014-ordinary-search-046/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/public-title-true.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-search014/public-title-false.json"
      ]
    },
    {
      "id": "nhentaito-search-self-audit-20261028",
      "at": "2026-10-28T19:09:59+08:00",
      "title": "自检发现NHentai.to搜索漏移植",
      "detail": "0.1.4公开WASM真实搜索已核，237 Native待验；首次发现时间未核，此为记录时间。",
      "itemId": "NHENTAITO_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/nhentaito-search014/public-search.json"
      ]
    },
    {
      "id": "nhentaito-search-native-014-20261028",
      "at": "2026-10-28T19:14:40+08:00",
      "title": "237 NHentai.to公开搜索修复已验证",
      "detail": "公开更新0.1.4后registry确认search，普通入口搜索love成功且前6项封面可见；仅关闭该源搜索漏实现范围。此时间是记录时间。",
      "itemId": "NHENTAITO_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito014-public-update-049/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito014-ordinary-search-053/"
      ]
    },
    {
      "id": "simplyhentai-237-search-403-20261028",
      "at": "2026-10-28T19:15:56+08:00",
      "title": "237 Simply Hentai搜索请求返回403",
      "detail": "公开0.1.1普通搜索已发出请求，Native显示HTTP403；旧不支持搜索记录不适用，原因待核，不能称搜索可用。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simplyhentai011-ordinary-search-054/"
      ]
    },
    {
      "id": "xkcd-settings-237-public-016-20261028",
      "at": "2026-10-28T19:21:02+08:00",
      "title": "237 xkcd公开包组织设置已回验",
      "detail": "默认单本、按年和按年月目录及保存重入已核，清除本次设置后默认及整份设置恢复；旧书和正文Native未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-ordinary-entry-056/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-year-save-060/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-year-reentered-061/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-yearmonth-save-062/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-yearmonth-reentered-063/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-restore-confirm-064/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-restored-065/"
      ]
    },
    {
      "id": "xkcd-existing-cached-reading-237-20261028",
      "at": "2026-10-28T19:23:58+08:00",
      "title": "237 xkcd原书继续阅读已核",
      "detail": "旧ID原书676章，原缓存2978第1页真实可见并返回同章；库数据前后完全一致。仅缓存页，按年月新作品冷网络正文未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-library-before-066/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-existing-book-067/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-existing-body-068/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd016-existing-return-069/"
      ]
    },
    {
      "id": "goda-public-home-237-20261028",
      "at": "2026-10-28T19:28:35+08:00",
      "title": "237 GoDa公开包官网首页已观察",
      "detail": "公开0.1.4 registry主页及普通WebView官网视觉已核；076日志实际非空，文档事件与初始godamh.com URL匹配；不外推其他源。此时间是记录时间。",
      "itemId": "SOURCE_HOMEPAGE_MISSING_COPY",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-public-update-071/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-official-webview-075/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-web-document-receipt-076/"
      ]
    },
    {
      "id": "immark-search-self-audit-20261028",
      "at": "2026-10-28T19:28:35+08:00",
      "title": "自检发现我是馬克搜索漏移植",
      "detail": "公开0.1.1 WASM真实搜索已核，237 Native待验；首次发现时间未核，此为记录时间。",
      "itemId": "IMMARK_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/immark-search011/public-search2.json"
      ]
    },
    {
      "id": "goda-mirror-settings-existing-book-237-20261028",
      "at": "2026-10-28T19:35:28+08:00",
      "title": "237 GoDa镜像设置与旧书继续阅读已核",
      "detail": "godamh保存重入及清除设置后恢复，旧书原正文可见并返回同页；自然预载更新该书页表，其他48本及旧缓存章未变。公开WASM具名旧页和首图已核，不外推全部镜像Native。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-settings-077/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-mirror-options-078/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-official-mirror-save-079/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-mirror-reentered-080/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-restore-confirm-081/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-restored-082/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-existing-book-083/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-existing-body-084/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-existing-return-085/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/goda-mirror014/"
      ]
    },
    {
      "id": "immark-search-native-011-20261028",
      "at": "2026-10-28T19:42:42+08:00",
      "title": "237我是馬克搜索及旧格式详情已验证",
      "detail": "公开0.1.1普通搜索、第二页旧文章及详情成功；首3和第二页具名封面可见，未进入正文。仅关闭搜索漏实现范围。此时间是记录时间。",
      "itemId": "IMMARK_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-public-update-087/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-ordinary-search-090/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-search-next-091/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-old-search-result-092/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/immark011-old-detail-settled-093/"
      ]
    },
    {
      "id": "goda-document-receipt-correction-20261028",
      "at": "2026-10-28T19:52:51+08:00",
      "title": "更正GoDa文档日志读取",
      "detail": "076命令名含#1，实际文档开始、可见、结束均与初始godamh.com URL及origin匹配；先前空日志结论撤回。此时间是记录时间。",
      "itemId": "SOURCE_HOMEPAGE_MISSING_COPY",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/goda014-web-document-receipt-076/"
      ]
    },
    {
      "id": "nhentaixxx-empty-page-self-audit-20261028",
      "at": "2026-10-28T19:52:51+08:00",
      "title": "NHentai.xxx候选空页后未续取",
      "detail": "候选安装及首个中文结果已观察，普通上滑后无终点且无后续搜索；宿主修复及原包恢复未完成，首次发现时间未核。此时间是记录时间。",
      "itemId": "NHENTAIXXX_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-baseline-094/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-import-097/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-browse-098/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-english-100/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-candidate-empty-next-101/"
      ]
    },
    {
      "id": "fjumonkey-search-local-20261028",
      "at": "2026-10-28T19:52:51+08:00",
      "title": "輔大猴搜索本地WASM具名核对",
      "detail": "源提交已推，本地搜索及旧ID具名核对；CI重复查询被自动审批拒绝，公开状态未知，Native未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/fjumonkey-search012/"
      ]
    },
    {
      "id": "nhentaixxx-empty-page-host-implemented-20261028",
      "at": "2026-10-28T20:05:48+08:00",
      "title": "NHentai.xxx空页续取宿主实现及回归完成",
      "detail": "按源游标继续取页，保成功cursor及失败原页重试；相关执行回归通过，尚未构建或真机验证，237原包待恢复。此时间是记录时间。",
      "itemId": "NHENTAIXXX_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-empty-search-tests.log"
      ]
    },
    {
      "id": "nhentaixxx-empty-page-host-237-20261028",
      "at": "2026-10-28T20:45:04+08:00",
      "title": "237候选空页续取已到真实终点",
      "detail": "修复宿主与冻结候选安装后数据保持，同query触底经过空批继续至终点，首项保留；原包恢复、公开源包及宿主提交CI尚未完成。此时间是记录时间。",
      "itemId": "NHENTAIXXX_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-host-preinstall-102/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-host-install-103/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-fixed-host-target-104/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-fixed-host-english-105/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-fixed-host-tail-106/",
        "/private/tmp/koma-empty-search-build.log",
        "/private/tmp/koma-empty-search-build-v2.log"
      ]
    },
    {
      "id": "nhentaixxx-public-identity-host-ci-20261028",
      "at": "2026-10-28T21:21:53+08:00",
      "title": "NHentai.xxx宿主CI及公开包身份已核",
      "detail": "Host精确CI成功，原0.1.3曾恢复；随后当前公开包字节已核但不同已验冻结候选，公开Native仍待验证。此时间是记录时间。",
      "itemId": "NHENTAIXXX_SEARCH_MISSING",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-original-restore-picker-107/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-original-restored-108/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-index-109/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-target-110/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-update-state-readback-111/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-bytes-and-update-events-112/"
      ]
    },
    {
      "id": "source-ren2-ipmini-public-wasm-20261028",
      "at": "2026-10-28T21:21:53+08:00",
      "title": "人2与IP手札公开WASM已核",
      "detail": "两个具名提交的精确CI成功，公开WASM按真实保存HTML经原Host回放；Native尚未验证。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "source-thirteen-install-unattributed-20261028",
      "at": "2026-10-28T21:21:53+08:00",
      "title": "237出现13个来源待查的安装请求",
      "detail": "同毫秒13个安装请求发生时无清单输入，13源版本变化、无新增ID且设置保持；触发原因未知，不断言用户或产品缺陷，也不回滚。此时间是记录时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-index-109/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-update-target-110/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-update-state-readback-111/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-bytes-and-update-events-112/"
      ]
    },
    {
      "id": "nhentaixxx-public-native-empty-page-20261028",
      "at": "2026-10-28T21:25:34+08:00",
      "title": "237 NHentai.xxx公开搜索及空页续取已验证",
      "detail": "公开0.1.4普通搜索保首项，空批后继续到真实终点；临时下载已清除。仅关闭具名搜索和空页消费范围，设备会话及13源事件另行处理。此时间是记录时间。",
      "itemId": "NHENTAIXXX_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-browse-113/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaixxx-public-english-114/"
      ]
    },
    {
      "id": "ipmini-search-native-012-20261028",
      "at": "2026-10-28T21:29:40+08:00",
      "title": "237 IP手札mini公开搜索已验证",
      "detail": "普通Browse搜索強化IP管理制度返回原作品并显示没有更多了；仅具名搜索，不外推Reader或全部负例。此时间是记录时间。",
      "itemId": "IPMINI_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/ipmini012-browse-target-115/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/ipmini012-ordinary-search-116/"
      ]
    },
    {
      "id": "people2-search-native-012-20261028",
      "at": "2026-10-28T21:36:04+08:00",
      "title": "237人2公开搜索已验证",
      "detail": "普通源内搜索春節返回具名原文章及终点，安装WASM与公开一致；未进入正文。此时间是记录时间。",
      "itemId": "PEOPLE2_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/public-search-packages-and-people2-target-117/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/people2012-ordinary-search-118/"
      ]
    },
    {
      "id": "mixflavor-public-wasm-20261028",
      "at": "2026-10-28T21:36:04+08:00",
      "title": "綜合口味公开WASM搜索已核",
      "detail": "公开0.1.2及精确CI成功，固定真实HTML经原Host回放；Native尚未验证。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/mixflavor-search012/"
      ]
    },
    {
      "id": "fjumonkey-search-native-012-20261028",
      "at": "2026-10-28T21:41:25+08:00",
      "title": "237輔大猴公开搜索及续页已验证",
      "detail": "公开实体与设备安装ZIP/WASM相等；普通搜索四格并滚动看到真实续页，正文及首末全页未验。此时间是记录时间。",
      "itemId": "FJUMONKEY_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/fjumonkey012-browse-target-120/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/fjumonkey012-ordinary-search-121/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/fjumonkey012-search-next-122/"
      ]
    },
    {
      "id": "webtoon-zh-search-truncation-20261028",
      "at": "2026-10-28T21:41:25+08:00",
      "title": "繁中WEBTOON搜索截断自检",
      "detail": "公开WASM只返回All首屏22项并误称无更多，官网两分类查看全部各有分页；修复进行中，Native未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "progress-service-restored-20261028",
      "at": "2026-10-28T21:46:53+08:00",
      "title": "原8766进度服务已恢复",
      "detail": "本机监听曾退出，原因未知；原脚本恢复后接口与snapshot一致，原浏览器页面实际显示并连接。未发现自启动或崩溃重启配置；部分事项stage摘要滞后待校正。",
      "itemId": "MONITOR_AVAILABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "progress-service-launchd-session-20261028",
      "at": "2026-10-28T21:50:31+08:00",
      "title": "进度服务切换至当前用户会话托管",
      "detail": "原脚本及原地址由临时launchd RunAtLoad与KeepAlive托管，接口和工作单一致、原浏览器保持连接；非登录自启动文件，跨登录或重启未验证。",
      "itemId": "MONITOR_AVAILABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "mixflavor-search-native-012-20261028",
      "at": "2026-10-28T21:51:06+08:00",
      "title": "237綜合口味公开搜索已验证",
      "detail": "普通搜索食返回原栏目5项及终点，安装ZIP/WASM与公开一致、设置保持；未进入Reader。此时间是记录时间。",
      "itemId": "MIXFLAVOR_SEARCH_MISSING",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-public-index-124/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-public-update-125/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-public-target-126/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-browse-target-127/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mixflavor012-ordinary-search-128/"
      ]
    },
    {
      "id": "webtoon-zh-search-pagination-237-20261028",
      "at": "2026-10-28T22:12:41+08:00",
      "title": "237繁中WEBTOON公开搜索续页已观察",
      "detail": "0.1.9公开包与安装字节一致，普通搜索愛滚动后可见旧All首屏之外的作品及封面；仅具名续页通过，不冒全部411项Native通过。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-public-browse-132/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-ordinary-search-133/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-ordinary-pagination-134/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/webtoon019-ordinary-originals-visible-135/"
      ]
    },
    {
      "id": "manhuashe-mirror-237-failed-20261028",
      "at": "2026-10-28T22:19:17+08:00",
      "title": "237漫画社m206目录请求失败",
      "detail": "默认目录20本成功，m206保存及重入一致但目录请求network_error/http0failed，旧内容保留；原因未知，正在恢复本轮设置并核默认旧书。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-default-browse-142/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-m206-saved-146/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-m206-reentered-147/"
      ]
    },
    {
      "id": "comicfury-filter-public-016-20261028",
      "at": "2026-10-28T22:19:17+08:00",
      "title": "Comic Fury筛选公开WASM已核",
      "detail": "默认热门、最新、搜索与旧版一致，显式筛选具名返回；Native持久与消费未验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicfury-filter016/"
      ]
    },
    {
      "id": "manhuashe-default-restore-existing-237-20261028",
      "at": "2026-10-28T22:23:07+08:00",
      "title": "237漫画社默认设置及旧书缓存已核",
      "detail": "清除本轮镜像设置后完整设置与基线相等，默认目录及旧书缓存正文返回同页；库正常补部分章节排序字段。m206失败限定收到响应头之前，原因未知。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-default-restored-149/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-existing-book-150/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-existing-reader-151/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuashe019-existing-return-152/"
      ]
    },
    {
      "id": "comicfury-search-filter-misrouting-20261028-source_filters",
      "at": "2026-10-28T22:38:18+08:00",
      "title": "237 Comic Fury搜索筛选误请求目录",
      "detail": "目录筛选已观察成功；搜索结果中选排序却发目录请求且结果未变，宿主修复已构建、真机待验。此时间是记录时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-browse-160/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-controls-162/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-sort-last-update-164/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-cleared-and-rest-165/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-search-166/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-options-167/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-popularity-168/"
      ]
    },
    {
      "id": "comicfury-search-filter-misrouting-20261028-source_settings_migration_audit",
      "at": "2026-10-28T22:38:18+08:00",
      "title": "237 Comic Fury搜索筛选误请求目录",
      "detail": "目录筛选已观察成功；搜索结果中选排序却发目录请求且结果未变，宿主修复已构建、真机待验。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-browse-160/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-controls-162/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-sort-last-update-164/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-filter-cleared-and-rest-165/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-default-search-166/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-options-167/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/comicfury016-search-sort-popularity-168/"
      ]
    },
    {
      "id": "translation-user-full-migration-20261028",
      "at": "2026-10-28T22:47:43+08:00",
      "title": "用户已配置翻译服务并要求完整迁移",
      "detail": "用户明确不只Torii，要求对照整个漫画翻译功能；初步缺项与三路线、Reader上下文仍在核对，key有效性与真实译图未验。此时间是记录时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "comicfury-filter-host-installed-20261028",
      "at": "2026-10-28T22:47:43+08:00",
      "title": "237筛选修复release包已安装",
      "detail": "冻结release安装成功，前台书架及四域数据保持；Comic Fury筛选Native回验尚未完成。此时间是记录时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-host-install-170/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-host-launch-readback-171/"
      ]
    },
    {
      "id": "3hentai-filter-candidate-015-20261028",
      "at": "2026-10-28T22:47:43+08:00",
      "title": "3Hentai筛选候选已推",
      "detail": "排序与文本筛选本地具名核对；CI、公开及Native待验，参考静态提示行未实现。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/3hentai-filter015/"
      ]
    },
    {
      "id": "reader-enhancement-theme-user-report-20261028",
      "at": "2026-10-28T22:59:53+08:00",
      "title": "登记超分指示器主题对比度反馈",
      "detail": "用户反馈暗绿色主题几乎不可辨识，要求所有主题解决；本地修复尚未构建和实机验证。此时间为登记时间，非用户消息精确时刻。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint",
      "evidence": [
        "/Users/honjow/git/reader-kit/reader-ui/src/main/ets/ReaderEnhancementStatus.ets",
        "/Users/honjow/git/reader-kit/reader-ui/src/main/ets/ReaderEnhancementContrast.ets"
      ]
    },
    {
      "id": "comicfury-filter-scope-native-20261028-source_filters",
      "at": "2026-10-28T23:06:43+08:00",
      "title": "237 Comic Fury搜索与目录筛选分流已核",
      "detail": "搜索排序与重置实际调用search，目录重置调用目录；本轮筛选清除、其他源筛选及设置保持。提交推送进行中，精确CI未核，其他范围不外推。此时间是记录时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-178/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-popularity-179/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-reset-180/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-browse-reset-181/"
      ]
    },
    {
      "id": "comicfury-filter-scope-native-20261028-source_settings_migration_audit",
      "at": "2026-10-28T23:06:43+08:00",
      "title": "237 Comic Fury搜索与目录筛选分流已核",
      "detail": "搜索排序与重置实际调用search，目录重置调用目录；本轮筛选清除、其他源筛选及设置保持。提交推送进行中，精确CI未核，其他范围不外推。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-178/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-popularity-179/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-search-reset-180/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/active-filter-comicfury-browse-reset-181/"
      ]
    },
    {
      "id": "source-237-filter-closeout-20261028",
      "at": "2026-10-28T23:38:59+08:00",
      "title": "237筛选具名回验与设备恢复",
      "detail": "NHentai.to及3Hentai公开包目录/搜索排序具名回验，设置筛选恢复；回原书架后休眠、超时恢复并释租，其他筛选与挑战边界保留。此时间是记录时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-browse-192/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-browse-newest-195/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-search-newest-199/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/nhentaito-search-reset-200/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-installed-204/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-browse-209/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-browse-recent-212/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-search-popular-217/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/3hentai-search-reset-218/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/restore-reading-return-226/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-closeout-final-227/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-closeout-sleep-timeout-228/"
      ]
    },
    {
      "id": "source-web-237-restored-20261028",
      "at": "2026-10-28T23:38:59+08:00",
      "title": "237网页验证会话已恢复",
      "detail": "原范围及书架恢复，设备休眠并释租；404、取消及未命中标题等场景仍开放。此时间是记录时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/restore-reading-return-226/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-closeout-final-227/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-closeout-sleep-timeout-228/"
      ]
    },
    {
      "id": "enhancement-emerald-197-20261028",
      "at": "2026-10-28T23:38:59+08:00",
      "title": "197暗绿主题超分指示器已核",
      "detail": "真实增强页激活、临时关闭及再开图标清晰，页码和偏好保持；浅色主题及设备恢复待完成。此时间是记录时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/install-contrast-host-03/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-active-reader-12/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-off-13/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-on-14/"
      ]
    },
    {
      "id": "source-name-identity-scope-20261028",
      "at": "2026-10-28T23:38:59+08:00",
      "title": "书源身份具名证据补充",
      "detail": "咚漫名称及官网图标一致，嗨皮缓存名称有据但当前主页及图标未知；其余未证边界保留，不从85设置行推身份完成数。此时间是记录时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-theme-197-restored-20261029",
      "at": "2026-10-29T00:03:11+08:00",
      "title": "197超分指示器具名主题及设备恢复",
      "detail": "暗绿白HD、琥珀黑HD及临时切换已核，原偏好与阅读状态恢复并释租；shared已推，Koma依赖推送/CI待核，不外推全部主题。此时间是记录时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-active-reader-12/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-off-13/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-on-14/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/amber-active-reader-18/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/restore-reader-preferences-21/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/restore-original-reading-23/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/power-restore-and-sleep-24/"
      ]
    },
    {
      "id": "reader-enhancement-toggle-197-20261029",
      "at": "2026-10-29T00:03:11+08:00",
      "title": "197超分临时关闭及再开已核",
      "detail": "真实增强页暗绿主题临时关闭与再开已观察，偏好保持；不代表漫画翻译迁移及真实译图通过。此时间是记录时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-active-reader-12/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-off-13/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-enhancement-status/emerald-temporary-on-14/"
      ]
    },
    {
      "id": "source-filter-ci-success-20261029",
      "at": "2026-10-29T00:03:11+08:00",
      "title": "搜索筛选分流精确CI成功",
      "detail": "4232f2a3对应CI40712563864成功，保原237具名范围与其他未验边界。此时间是记录时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-theme-koma-ci-20261029",
      "at": "2026-10-29T00:10:42+08:00",
      "title": "超分指示器依赖提交精确CI成功",
      "detail": "共享修复已推，Koma f9de精确CI成功；197暗绿、琥珀和临时切换具名验证，其他主题未逐一真机验证。此时间是记录时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "verified",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40721766878"
      ]
    },
    {
      "id": "translation-completion-release-built-20261029",
      "at": "2026-10-29T00:23:33+08:00",
      "title": "漫画翻译补齐的Release已构建",
      "detail": "Torii、本地模型、自部署、LLM多源与译图缓存管理已有本地实现；首次符号错误修正后Release构建成功。Codex OAuth、试译报告等后续能力及安装、真机和真实译图仍待完成。此时间是记录时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-translation-completion-build.log",
        "/private/tmp/koma-translation-completion-release.hap"
      ]
    },
    {
      "id": "reader-settings-menu-confirmed-20261029",
      "at": "2026-10-29T00:33:59+08:00",
      "title": "用户明确阅读设置菜单，旧结构仍在修正",
      "detail": "源码确认旧页面模式与方向重组菜单仍存在；保留控制栏两按钮，阅读设置复用相同菜单及四种互斥方向，连续滚动不进入单双页菜单。正在修正，尚未验收。此时间为登记时间。",
      "itemId": "READER_SETTINGS_PLACEMENT",
      "kind": "checkpoint"
    },
    {
      "id": "translation-candidate-installed-20261029",
      "at": "2026-10-29T00:33:59+08:00",
      "title": "翻译候选已在237安装并观察入口",
      "detail": "第二轮Release构建成功；普通服务翻译路径与字体菜单已观察，密钥保持掩码；真实译图及整体迁移尚未验收。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "reader-settings-global-menu-20261029",
      "at": "2026-10-29T00:49:51+08:00",
      "title": "197全局阅读菜单已具名核验",
      "detail": "单双页和四方向菜单、RTL休眠与偏好恢复已核；用户采用分页模式名称，Reader内菜单、设备收尾及提交待完成。此时间是登记时间。",
      "itemId": "READER_SETTINGS_PLACEMENT",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-transparent-reopened-20261029",
      "at": "2026-10-29T00:49:51+08:00",
      "title": "超分指示器按用户批准调整透明度",
      "detail": "本地80%不透明底及按黑白背景最差对比选择图标，关键执行检查通过；此前实色方案证据保留，新方案尚未真机验收。此时间是登记时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "reader-menu-final-197-20261029",
      "at": "2026-10-29T01:12:15+08:00",
      "title": "197最终阅读菜单及设备恢复已核",
      "detail": "最终分页模式、两项与四方向、连续滚动禁用单页行、控制栏及原偏好已核；Koma提交推送及精确CI待确认。此时间是登记时间。",
      "itemId": "READER_SETTINGS_PLACEMENT",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-translucent-197-20261029",
      "at": "2026-10-29T01:12:15+08:00",
      "title": "197半透明指示器及设备恢复已核",
      "detail": "真实增强页浅化绿底白HD，原偏好、书架数据和设备状态恢复；共享提交已推，Koma依赖提交推送及CI待确认。此时间是登记时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "reader-menu-and-enhancement-ci-20261029",
      "at": "2026-10-29T01:16:57+08:00",
      "title": "阅读菜单与指示器提交精确CI成功",
      "detail": "Koma 2a0c已推，CI40733358529成功；197菜单及半透明绿底具名范围收口，不扩大其他缺陷或全部主题。此时间是登记时间。",
      "itemId": "READER_SETTINGS_PLACEMENT",
      "kind": "verified",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40733358529"
      ]
    },
    {
      "id": "source-guazi-hcomic-public-20261029",
      "at": "2026-10-29T01:16:57+08:00",
      "title": "瓜子与H-Comic筛选公开包具名核验",
      "detail": "瓜子0.1.4及H-Comic补修后的0.1.3公开WASM回放通过，保H-Comic旧索引反例；237 Native未验。此时间是登记时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint"
    },
    {
      "id": "translation-resource-gap-20261029",
      "at": "2026-10-29T01:16:57+08:00",
      "title": "237翻译候选发现试译资源缺口",
      "detail": "最终候选已安装，普通Torii配置仍在；试译行动态资源缺失，正在修复并核服务响应，真实译图未确认。此时间是登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "translation-service-entry-237-20261029",
      "at": "2026-10-29T01:18:29+08:00",
      "title": "237漫画翻译服务入口普通路径已确认",
      "detail": "设置→服务→漫画翻译已进入Torii设置，既有路由具名范围收口；翻译功能与试译资源新修复仍在原迁移事项继续。此时间是登记时间。",
      "itemId": "TRANSLATION_ENTRY_PLACEMENT",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/settings-root-04/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/services-05/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-torii-settings-06/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/install-full-evaluation-10/"
      ]
    },
    {
      "id": "torii-two-page-live-evaluation-20261029",
      "at": "2026-10-29T01:30:56+08:00",
      "title": "237 Torii两页真实试译及对比显示已核",
      "detail": "普通服务设置路径真实评测两页ready，具名原图和中文译图已观察；整体迁移、Reader预处理和新资源重装仍待完成。此时间是登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/torii-live-evaluation-result-13/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/torii-first-translated-preview-14/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/torii-second-translated-preview-15/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/torii-second-translated-visible-16/"
      ]
    },
    {
      "id": "api23-user-accepted-20261029",
      "at": "2026-10-29T01:32:38+08:00",
      "title": "用户确认API23普通启动恢复",
      "detail": "用户本轮明确表示实测已好并要求关闭；不补造设备身份或证据路径。此时间为登记时间。",
      "itemId": "APP_STARTUP_API23_CRASH",
      "kind": "verified"
    },
    {
      "id": "tongli-home-still-blank-20261029",
      "at": "2026-10-29T01:32:38+08:00",
      "title": "用户反馈东立首页仍空白",
      "detail": "首页问题仍待处理，与此前章节官网黑页和地区限制证据分开。此时间为登记时间。",
      "itemId": "TONGLI_CHAPTERS_SETTINGS_FAILURE",
      "kind": "checkpoint"
    },
    {
      "id": "translation-237-reading-restored-20261029",
      "at": "2026-10-29T01:32:38+08:00",
      "title": "237原书架及数据已恢复",
      "detail": "原斗破01第1页3%及偏好、书库和会话基线已核；电源恢复仍进行中。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "translation-237-session-restored-20261029",
      "at": "2026-10-29T01:36:51+08:00",
      "title": "237翻译会话恢复并释租",
      "detail": "原书架、偏好与数据基线已核；suspend后重现override，重新清除后读回SLEEP、正常超时无override并释租。整体翻译迁移仍开放。此时间是登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-original-shelf-restored-18/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-power-restored-19/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-final-timeout-cleared-20/"
      ]
    },
    {
      "id": "settings-grouping-197-20261029",
      "at": "2026-10-29T01:46:02+08:00",
      "title": "197设置分组及高级与关于已核",
      "detail": "普通设置页面分组图标、高级诊断日志及关于页面具名验收；设备会话继续。此时间为登记时间。",
      "itemId": "SETTINGS_GROUPING_ADVANCED",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-grouping-top-22/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-grouping-bottom-23/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-advanced-content-24/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/settings-about-content-25/"
      ]
    },
    {
      "id": "enhancement-40-percent-20261029",
      "at": "2026-10-29T01:46:02+08:00",
      "title": "用户要求超分指示器40%不透明",
      "detail": "本地实施及197真机验证中，保先前80%方案证据，不视新方案已通过。此时间为登记时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "tongli-home-reproduced-20261029",
      "at": "2026-10-29T01:46:02+08:00",
      "title": "237东立首页空白已复现",
      "detail": "home能力开启但get_home返回空sections，同设备Popular有20本；源侧正在修正。此时间为登记时间。",
      "itemId": "TONGLI_CHAPTERS_SETTINGS_FAILURE",
      "kind": "checkpoint"
    },
    {
      "id": "source-package-sharing-request-20261029",
      "at": "2026-10-29T02:02:44+08:00",
      "title": "登记分享已安装源包需求",
      "detail": "用户要求通过系统分享已安装源包，低优先级排在bug修复后；当前未实施。此时间为登记时间，原始提出时刻未核。",
      "itemId": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "kind": "checkpoint"
    },
    {
      "id": "source-homepage-globe-icon-20261029",
      "at": "2026-10-29T02:02:44+08:00",
      "title": "用户指定书源主页图标",
      "detail": "源主页图标改为系统地球经纬线图标，实施与设备验证中。此时间为登记时间。",
      "itemId": "SOURCE_HOMEPAGE_MISSING_COPY",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-40-black-white-20261029",
      "at": "2026-10-29T02:02:44+08:00",
      "title": "197超分40%底色黑白背景已观察",
      "detail": "具名xkcd同页黑白背景可辨；偏好及书库已核，原读态恢复和交付仍进行中。此时间为登记时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "tongli-home-fixed-237-20261029",
      "at": "2026-10-29T02:10:25+08:00",
      "title": "237东立首页具名显示",
      "detail": "首页Popular六封面与标题可见，原正文限制保持开放，设备恢复进行中。此时间为登记时间。",
      "itemId": "TONGLI_CHAPTERS_SETTINGS_FAILURE",
      "kind": "checkpoint"
    },
    {
      "id": "homepage-icon-build-push-20261029",
      "at": "2026-10-29T02:10:25+08:00",
      "title": "书源主页图标修正已提交",
      "detail": "首选资源构建失败，改用SDK现有图标后构建及推送；设备和CI待核。此时间为登记时间。",
      "itemId": "SOURCE_HOMEPAGE_MISSING_COPY",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-device-approval-20261029",
      "at": "2026-10-29T02:10:25+08:00",
      "title": "197恢复操作被自动审批拒绝",
      "detail": "审批未识别197授权，已向用户说明并等待明确授权；未绕过，租约和读态恢复待处理。共享及Koma依赖提交已推，CI待核。此时间为登记时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "tongli-home-feedback-accepted-20261029",
      "at": "2026-10-29T02:13:00+08:00",
      "title": "东立首页空白反馈独立登记并具名验收",
      "detail": "237公开0.1.5首页Popular封面及标题实际可见；原章节正文事项保持开放。此时间为登记时间，非用户反馈精确时间。",
      "itemId": "TONGLI_HOME_BLANK",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/tongli-home-fixed-263/screen.png"
      ]
    },
    {
      "id": "source-session-237-filter-restored-20261029",
      "at": "2026-10-29T02:20:16+08:00",
      "title": "237书源筛选具名验证及会话恢复",
      "detail": "瓜子与H-Comic公开包普通目录及搜索筛选具名验证；书架、设置、数据及电源恢复并释租，不扩大其他筛选值。此时间为登记时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/guazi-search-category-246/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/hcomic-search-fullcolor-255/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-session-return-264/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/source-session-sleep-265/"
      ]
    },
    {
      "id": "translation-oauth-foundation-20261029",
      "at": "2026-10-29T02:20:16+08:00",
      "title": "翻译OAuth基础本地补充",
      "detail": "按source存储及登录刷新基础和Reader两个提供方已补；UI、usage与Native待完成。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "source-filter-237-detail-20261029",
      "at": "2026-10-29T02:20:20+08:00",
      "title": "补充237两源筛选具名范围",
      "detail": "瓜子目录恋爱36本、搜索爱加恋爱；H-Comic目录全彩10本、搜索love加全彩，搜索请求实际完成，重置后筛选为空。具名证据为布局与运行记录，筛选过程无截图。此时间为登记时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint"
    },
    {
      "id": "device-197-237-authorization-20261029",
      "at": "2026-10-29T02:24:29+08:00",
      "title": "用户明确持续授权197及237验收",
      "detail": "用户允许继续197本轮验收和恢复，并明确后续两台设备本项目验收无需重复询问；此前审批拒绝记录保留。40%超分具名结果及Koma精确CI已核，197设备恢复继续。此时间为登记时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40742436354"
      ]
    },
    {
      "id": "source-homepage-globe-197-20261029",
      "at": "2026-10-29T02:41:23+08:00",
      "title": "197书源主页地球图标已核",
      "detail": "崩坏3 IP站普通目录可见经纬地球图标及23本封面；Komiic原未验范围继续开放。此时间为登记时间。",
      "itemId": "SOURCE_HOMEPAGE_MISSING_COPY",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/source-homepage-globe-honkai-45/",
        "https://github.com/honjow/Koma/actions/runs/40742436354"
      ]
    },
    {
      "id": "enhancement-40-restored-197-20261029",
      "at": "2026-10-29T02:44:58+08:00",
      "title": "197超分具名范围及设备恢复完成",
      "detail": "40%底色黑白背景已核并完成提交CI；原Blue读态、偏好、书库和电源恢复，租约已释。其他主题未逐一真机验证。此时间为登记时间。",
      "itemId": "READER_ENHANCEMENT_THEME_CONTRAST",
      "kind": "verified"
    },
    {
      "id": "manager-publication-video-gap-20261029",
      "at": "2026-10-29T02:44:58+08:00",
      "title": "管理器后台发布瞬间仍待录证",
      "detail": "已有连续录屏结束早于实际fetch_ok，不能认定发布瞬间已覆盖；普通入口补录进行中。此时间为登记时间。",
      "itemId": "MANAGER_REFRESH_BACKGROUND",
      "kind": "checkpoint"
    },
    {
      "id": "manager-background-publication-197-20261029",
      "at": "2026-10-29T02:48:41+08:00",
      "title": "197管理器后台发布连续过程已核",
      "detail": "普通入口录屏覆盖真实fetch_ok，发布前后及重入未见全表清空或图标全闪；部分地址失败保留，设备已恢复并释租。此时间为登记时间。",
      "itemId": "MANAGER_REFRESH_BACKGROUND",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/manager-background-refresh/ordinary-entry-through-completion-02/",
        "/private/tmp/koma-manager-background197-recording.json"
      ]
    },
    {
      "id": "source-scope-asmhentai-repair-20261029",
      "at": "2026-10-29T02:52:24+08:00",
      "title": "筛选作用域候选构建及AsmHentai解析修复",
      "detail": "Host候选构建成功、MH1234真机待验；AsmHentai 237目录HTTP200后源操作失败，真实HTML复现并修属性回退，公开及Native待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-filter-scope-header-build.log",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-failure-273/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-log-recv-277/"
      ]
    },
    {
      "id": "translation-codex-sources-build-20261029",
      "at": "2026-10-29T02:58:42+08:00",
      "title": "翻译源与Codex设备码流程本地构建",
      "detail": "API/Codex源、设备码、独立用量及Reader提供方选择已补并构建；新增UI及网络账户路径未装机，Reader未来页预处理仍待。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-translation-sources-build.log"
      ]
    },
    {
      "id": "asmhentai-browse-selfcheck-20261029",
      "at": "2026-10-29T03:01:52+08:00",
      "title": "AsmHentai目录失败独立登记",
      "detail": "237自检0.1.2目录失败，源修复后公开0.1.3显示19本；短标题设置和设备恢复仍在进行。此时间是登记时间。",
      "itemId": "ASM_HENTAI_BROWSE_RUNTIME_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-default-272/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-failure-273/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-log-recv-277/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-public-browse-293/"
      ]
    },
    {
      "id": "zerobyw-web-entry-feedback-20261029",
      "at": "2026-10-29T03:25:17+08:00",
      "title": "登记Zero搬运网网页入口反馈",
      "detail": "用户反馈漫画页面缺少WebView及浏览器打开入口；待实机复现。此时间为登记时间。",
      "itemId": "ZEROBYW_MANGA_WEB_ENTRY_MISSING",
      "kind": "checkpoint"
    },
    {
      "id": "zerobyw-chapter-feedback-20261029",
      "at": "2026-10-29T03:25:17+08:00",
      "title": "登记Zero搬运网章节不全反馈",
      "detail": "用户观察似乎只有5章，数量与真实章节待核实；尚未实机复现。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint"
    },
    {
      "id": "zerobyw-237-reproduced-20261029",
      "at": "2026-10-29T03:30:41+08:00",
      "title": "237复现Zero详情入口与章节问题",
      "detail": "《逐神骑士》详情显示5章且菜单无网页入口；宿主无5章截断，源详情未提供网页链接，章节原因仍调查。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-detail-342/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/zero-detail-menu-343/"
      ]
    },
    {
      "id": "translation-source-manager-197-20261029",
      "at": "2026-10-29T03:30:41+08:00",
      "title": "197翻译源管理具名路径已核",
      "detail": "API/Codex源创建保存重入、删除后不复活及原状态恢复已核；真实账户网络与Reader预处理仍未验。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "reader-mh1234-preload-feedback-20261029",
      "at": "2026-10-29T03:46:12+08:00",
      "title": "登记漫画12342网章末预载反馈",
      "detail": "用户反馈RTL末页出现正在加载源详情后切章；源身份及普通路径待核。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "checkpoint"
    },
    {
      "id": "reader-loading-contrast-feedback-20261029",
      "at": "2026-10-29T03:46:12+08:00",
      "title": "登记白灰背景加载提示不可见",
      "detail": "用户反馈白灰背景下白色进度条与文字不可见，要求白底深色；待复现修复。此时间为登记时间。",
      "itemId": "READER_LOADING_INDICATOR_BACKGROUND_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "zerobyw-adopted-32-20261029",
      "at": "2026-10-29T03:46:12+08:00",
      "title": "用户采用Zero完整目录及锁章方案",
      "detail": "用户明确采用全32章、锁标识及本站登录入口；实现与237回验进行中。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint"
    },
    {
      "id": "reader-loading-preload-causes-20261029",
      "at": "2026-10-29T03:56:37+08:00",
      "title": "阅读器加载对比与章末预载定位",
      "detail": "加载硬编码白色已改画布前景色；MH1234缺续读元数据，按真实阅读顺序接入合同，均待构建及真机。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "checkpoint"
    },
    {
      "id": "zerobyw-web-entry-237-20261029",
      "at": "2026-10-29T03:56:37+08:00",
      "title": "237 Zero漫画网页入口已验收",
      "detail": "公开0.1.6两种入口均实际打开具名作品；完整锁章目录和登录会话另行跟踪。设备原状态已恢复并释租。此时间为登记时间。",
      "itemId": "ZEROBYW_MANGA_WEB_ENTRY_MISSING",
      "kind": "verified"
    },
    {
      "id": "reader-boundary-original-reproduced-20261029",
      "at": "2026-10-29T04:07:30+08:00",
      "title": "197旧版MH1234章末等待已复现",
      "detail": "多页RTL最后页后才触发源详情加载并等待图片；旧88实际退页不作跨章证据。修复及加载配色候选已构建，197回验待完成。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-public014-rtl-boundary-motion-90/"
      ]
    },
    {
      "id": "reader-loading-color-correction-20261029",
      "at": "2026-10-29T04:11:00+08:00",
      "title": "用户明确灰底白色、白底深色",
      "detail": "仅加载提示按新要求调整，最新候选重建中；197原MH1234为0.1.3，run90目录名014属误标，原复现不变。此时间为登记时间。",
      "itemId": "READER_LOADING_INDICATOR_BACKGROUND_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "mh1234-native-prepend-black-20261029",
      "at": "2026-10-29T04:19:51+08:00",
      "title": "MH1234新候选出现黑屏",
      "detail": "多页章准备后出现黑屏；原生前插重复位移为候选原因，已调整并重新构建，等待真机回验确认。无效日志不作证据。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "checkpoint"
    },
    {
      "id": "mpc-candidate-237-20261029",
      "at": "2026-10-29T04:19:51+08:00",
      "title": "237 MPC筛选候选具名验证及恢复",
      "detail": "目录筛选、提示、搜索及重置具名已核，搜索态筛选隐藏未单独证实；原包和设备已恢复，候选未发布。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-final-shelf-407/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-final-sleep-408/"
      ]
    },
    {
      "id": "trim-reopen-stall-feedback-20261029",
      "at": "2026-10-29T04:25:19+08:00",
      "title": "登记去白边重进后关闭卡加载",
      "detail": "用户描述两次进入后关闭设置半模态时图片卡准备状态，另有开启重复加载；单次开关不能替代复现。此时间为登记时间。",
      "itemId": "READER_TRIM_REOPEN_DISABLE_LOADING_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "mpc-komiic-public-237-20261029",
      "at": "2026-10-29T04:25:19+08:00",
      "title": "237 MPC公开包与Komiic网页具名核验",
      "detail": "MPC公开014筛选具名核验，搜索态筛选隐藏未单独证实；Komiic网页显示登录页及站方提示，最终URL和登录原因未核；设备已恢复释租。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "mh1234-candidate-107-black-20261029",
      "at": "2026-10-29T04:25:19+08:00",
      "title": "MH1234索引候选仍黑屏",
      "detail": "未生效索引调整已撤回，整章批量数据通知候选重建；根因未确认。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "checkpoint"
    },
    {
      "id": "source-homepage-scope-accepted-20261029",
      "at": "2026-10-29T04:25:50+08:00",
      "title": "书源主页原问题具名范围验收",
      "detail": "GoDa官网、Komiic普通菜单真实站点及197地球图标均已核；账户和正文不在本项结论内。MPC公开014 Header与Action具名范围已验，整体源审计仍开放。此时间为登记时间。",
      "itemId": "SOURCE_HOMEPAGE_MISSING_COPY",
      "kind": "verified"
    },
    {
      "id": "mh1234-fresh-chapter-candidate-20261029",
      "at": "2026-10-29T04:30:24+08:00",
      "title": "197候选未访问章节连续跨章已核",
      "detail": "RTL多页章提前准备并原生平移进入未访问下一章，未见源详情等待或黑底重载；公开源包及设备收尾仍待。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-final015-rtl-fresh-chapter3-motion-110/"
      ]
    },
    {
      "id": "trim-reopen-original-condition-20261029",
      "at": "2026-10-29T04:39:54+08:00",
      "title": "197纯原图条件两次进入未复现",
      "detail": "超分关闭时，裁剪开启、退出重进再关闭及滑页未见卡加载；用户反馈仍开放，超分与裁剪同时开启路径正在验证。此时间为登记时间。",
      "itemId": "READER_TRIM_REOPEN_DISABLE_LOADING_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "trim-superresolution-confirmed-20261029",
      "at": "2026-10-29T04:50:53+08:00",
      "title": "用户确认去白边故障时超分开启",
      "detail": "197观察到整批增强重复与HD持续转圈，原图仍可见；缓存身份修复候选回验中，未冒用户全部卡死细节已复现。此时间为登记时间。",
      "itemId": "READER_TRIM_REOPEN_DISABLE_LOADING_STALL",
      "kind": "checkpoint",
      "evidence": [
        "/tmp/reader-crop-processing-native-batch.log"
      ]
    },
    {
      "id": "translation-zero-preload-demand-20261029",
      "at": "2026-10-29T04:50:53+08:00",
      "title": "零预载自动翻译执行回归已修",
      "detail": "分页及条漫补回独立预处理页，原执行期望未改；真实Torii普通路径未验。此时间为登记时间。",
      "itemId": "MANGA_TRANSLATION_PREPROCESS",
      "kind": "checkpoint"
    },
    {
      "id": "chapter-list-divider-feedback-20261029",
      "at": "2026-10-29T04:54:29+08:00",
      "title": "登记章节列表分割线和点击反馈",
      "detail": "用户反馈分割线间歇消失、列表项缺点击反馈并授权103查看；当前页面待核，不安装或切章。此时间为登记时间。",
      "itemId": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "kind": "checkpoint"
    },
    {
      "id": "chapter-list-103-reproduced-20261029",
      "at": "2026-10-29T04:59:54+08:00",
      "title": "103章节分割线异常已观察",
      "detail": "当前作品列表具名见部分分割线消失，候选保原样式改原生分割及按压反馈，构建完成但197待验；103原状态恢复释租。此时间为登记时间。",
      "itemId": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device103__MLR-AL00/not-applicable/portrait-1600x2560/chapter-list/chapter-list-current-screen-004/"
      ]
    },
    {
      "id": "asmhentai-settings-accepted-20261029",
      "at": "2026-10-29T05:04:31+08:00",
      "title": "AsmHentai目录与短标题设置具名验收",
      "detail": "237公开013目录、短标题开启保存重入和清除恢复已核，设置数据及设备恢复释租；不扩其他路径。证据为layout。此时间为登记时间。",
      "itemId": "ASM_HENTAI_BROWSE_RUNTIME_FAILURE",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-setting-295/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-short-enabled-296/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-clear-setting-297/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/asmhentai-setting-restored-298/"
      ]
    },
    {
      "id": "chapter-press-scope-corrected-20261029",
      "at": "2026-10-29T05:04:31+08:00",
      "title": "章节行按压反馈范围纠正",
      "detail": "按用户明确要求反馈不覆盖外卡片或整列表，候选改复用内缩圆角反馈，构建与197验收待完成。此时间为登记时间。",
      "itemId": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "kind": "checkpoint"
    },
    {
      "id": "trim-superresolution-same-manga-197-20261029",
      "at": "2026-10-29T05:07:53+08:00",
      "title": "197同作超分开启重进路径已核",
      "detail": "开启超分与裁剪、退出重进后关闭裁剪及滑页，图像持续显示；交付及设备恢复待完成，旧包全部卡死细节未复现。此时间为登记时间。",
      "itemId": "READER_TRIM_REOPEN_DISABLE_LOADING_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "mpc-search-scope-237-20261029",
      "at": "2026-10-29T05:09:41+08:00",
      "title": "237 MPC搜索筛选作用域已核",
      "detail": "搜索态无筛选入口，清查询后目录筛选恢复；原数据和设备状态恢复释租，整体源审计继续开放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-ui-431/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-cleared-432/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-final-433/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/mpc-search-sleep-437/"
      ]
    },
    {
      "id": "trim-shared-pushed-20261029",
      "at": "2026-10-29T05:15:17+08:00",
      "title": "裁剪缓存修复已推共享仓",
      "detail": "共享修复及自动翻译零预载预算恢复已推，Koma依赖和197恢复待完成。此时间为登记时间。",
      "itemId": "READER_TRIM_REOPEN_DISABLE_LOADING_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "chapter-original-text-restored-20261029",
      "at": "2026-10-29T05:15:17+08:00",
      "title": "章节列表候选保留原文字样式",
      "detail": "发现默认HDS文字导致字号和行高变化后已撤回，新候选复用内缩反馈并保原文字，197回验中。此时间为登记时间。",
      "itemId": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "kind": "checkpoint"
    },
    {
      "id": "chapter-list-197-candidate-20261029",
      "at": "2026-10-29T05:32:35+08:00",
      "title": "197章节分割与行内反馈已核",
      "detail": "原字号行距、12行分割线、内缩按压及既有长按普通进入具名验证；提交已推，精确CI待确认。此时间为登记时间。",
      "itemId": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "kind": "checkpoint"
    },
    {
      "id": "reader-white-loading-197-20261029",
      "at": "2026-10-29T05:32:35+08:00",
      "title": "197白底加载提示已核",
      "detail": "未访问页加载时深色进度与文字可见，灰底白色待验。此时间为登记时间。",
      "itemId": "READER_LOADING_INDICATOR_BACKGROUND_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "chapter-ci-success-20261029",
      "at": "2026-10-29T05:34:51+08:00",
      "title": "章节列表修复精确CI成功",
      "detail": "c68c75dd对应CI40771912927成功；197原状态恢复仍待，103未安装候选。此时间为登记时间。",
      "itemId": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40771912927"
      ]
    },
    {
      "id": "simply-challenge-host-candidate-20261029",
      "at": "2026-10-29T05:34:51+08:00",
      "title": "Simply验证信号接线候选待回验",
      "detail": "原明确challenge信号被降级，旧Host候选仍403；普通目录及首搜索接线候选构建和237回验中，默认403与精确API origin边界保持。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint"
    },
    {
      "id": "reader-gray-loading-197-20261029",
      "at": "2026-10-29T05:48:38+08:00",
      "title": "197灰底加载提示已核",
      "detail": "灰底白色进度和文字可见，最终图片正常；白底深色既有具名结果保留，共享及Koma交付和设备恢复待完成。此时间为登记时间。",
      "itemId": "READER_LOADING_INDICATOR_BACKGROUND_CONTRAST",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/reader-gray-uncached-page-loading-motion-159/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/reader-gray-loading-terminal-160/"
      ]
    },
    {
      "id": "reader-loading-crop-pushed-20261029",
      "at": "2026-10-29T05:54:22+08:00",
      "title": "加载及裁剪共享修复与依赖已推",
      "detail": "共享及Koma依赖已推，精确CI进行中，197恢复未完成；保持具名真机边界。此时间为登记时间。",
      "itemId": "READER_LOADING_INDICATOR_BACKGROUND_CONTRAST",
      "kind": "checkpoint"
    },
    {
      "id": "simply-first-candidate-restored-20261029",
      "at": "2026-10-29T05:54:22+08:00",
      "title": "Simply首轮候选仍403并已恢复",
      "detail": "原包、用户数据、会话记录及设备状态已恢复释租；请求与验证页UA不一致，修正回验中，403原因未定。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint"
    },
    {
      "id": "mh1234-public-rtl-roundtrip-197-20261029",
      "at": "2026-10-29T06:02:15+08:00",
      "title": "197公开MH1234多页RTL往返跨章已核",
      "detail": "公开015实体一致，未访问下一章提前准备并连续往返，无清空、先小后大或源详情等待；Host合同交付及设备恢复待完成。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-public015-rtl-chapter5-roundtrip-171/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/mh1234-public015-chapter5-terminal-172/"
      ]
    },
    {
      "id": "reader-loading-crop-ci-success-20261029",
      "at": "2026-10-29T06:02:15+08:00",
      "title": "阅读器共享依赖精确CI成功",
      "detail": "Koma 0ac87bd精确CI40775085588成功；197原状态恢复待完成。此时间为登记时间。",
      "itemId": "READER_LOADING_INDICATOR_BACKGROUND_CONTRAST",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40775085588"
      ]
    },
    {
      "id": "reader-197-final-delivery-20261029",
      "at": "2026-10-29T06:08:37+08:00",
      "title": "197三项阅读器具名修复及恢复完成",
      "detail": "加载配色、同作裁剪路径及公开015多页RTL跨章具名验证和交付已核；原源、阅读数据及电源恢复释租。旧包全图卡死细节未复现，不扩大范围。此时间为登记时间。",
      "itemId": "READER_MH1234_BOUNDARY_PRELOAD",
      "kind": "verified",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40776916652"
      ]
    },
    {
      "id": "simply-ua-candidate-restored-20261029",
      "at": "2026-10-29T06:08:37+08:00",
      "title": "Simply UA候选仍403并恢复",
      "detail": "手动验证后仍403，日志中UA不一致及Cookie读取为空，原因未定；原宿主、源包、数据及设备已恢复释租。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint"
    },
    {
      "id": "xkcd-grouped-cold-page-20261029",
      "at": "2026-10-29T06:20:13+08:00",
      "title": "237 xkcd年月分组冷页已核",
      "detail": "2024-08分组2977中文正文真实显示，reader自然新增本次记录；原书库设置及设备恢复释租，其他页面未外推。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/xkcd-cold-read-518/"
      ]
    },
    {
      "id": "zerobyw-32-candidate-20261029",
      "at": "2026-10-29T06:20:13+08:00",
      "title": "237 Zero候选显示32章及锁标",
      "detail": "具名目录已见，登录、游客权限、公开交付及设备恢复仍待。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint"
    },
    {
      "id": "zero-existing-host-contract-20261029",
      "at": "2026-10-29T06:26:34+08:00",
      "title": "Zero采用既有宿主合同回验",
      "detail": "先前候选具名目录及游客锁章已观察，新增门槛撤回，现用既有宿主重新回验；不将旧候选证据转移。宿主请求关联精确CI成功。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40779011098"
      ]
    },
    {
      "id": "zero-existing-host-candidate-237-20261029",
      "at": "2026-10-29T06:28:40+08:00",
      "title": "237 Zero无门槛候选具名回验",
      "detail": "现有宿主搭配新候选实体已核，32章及游客锁章显示；免费首章画面待亲审，不以旧候选代验。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint"
    },
    {
      "id": "zero-public-017-verifying-20261029",
      "at": "2026-10-29T06:38:16+08:00",
      "title": "Zero公开0.1.7正在独立回验",
      "detail": "候选32章、游客锁章及免费页具名已核；公开实体不同于候选，普通采用回验进行中，登录态正文未验。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/40780631285"
      ]
    },
    {
      "id": "zero-public-017-237-results-20261029",
      "at": "2026-10-29T06:42:43+08:00",
      "title": "237 Zero公开包游客路径已核",
      "detail": "实体、32章、游客锁章与登录入口已核；免费第二章画面待亲审，登录态正文未验。原源包和设备恢复释租，reader自然新增第二章记录。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "checkpoint"
    },
    {
      "id": "zero-public-017-accepted-20261029",
      "at": "2026-10-29T06:45:24+08:00",
      "title": "237 Zero公开目录具名验收",
      "detail": "32章、游客锁章、本站入口及未访问免费第二章中文原图亲审；登录态正文留原会话范围，原源及设备已恢复。此时间为登记时间。",
      "itemId": "ZEROBYW_CHAPTERS_TRUNCATED",
      "kind": "verified"
    },
    {
      "id": "torii-reader-future-page-237-20261029",
      "at": "2026-10-29T06:53:43+08:00",
      "title": "237真实Torii未来页预处理已核",
      "detail": "当前及未来一页翻页前译成中文，普通前后翻页连续；设备和原数据恢复进行中，不外推其他提供方。此时间为登记时间。",
      "itemId": "MANGA_TRANSLATION_PREPROCESS",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-preprocess-torii-before-turn-33/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-preprocess-prepared-page-roundtrip-34/"
      ]
    },
    {
      "id": "torii-preprocess-restored-237-20261029",
      "at": "2026-10-29T06:57:07+08:00",
      "title": "237 Torii预处理验证及恢复完成",
      "detail": "真实未来页预处理及连续翻页具名已核；原App、八份数据恢复，休眠后override反例清除并释租。其他提供方仍由整体迁移跟踪。此时间为登记时间。",
      "itemId": "MANGA_TRANSLATION_PREPROCESS",
      "kind": "verified"
    },
    {
      "id": "source-filter-scope-host-pushed-20261029",
      "at": "2026-10-29T07:00:17+08:00",
      "title": "筛选作用域与Header宿主提交已推",
      "detail": "保独立筛选值、旧schema兼容及Header仅展示；既有237具名范围保留，精确CI待核，整体源审计继续。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "translation-migration-pushed-20261029",
      "at": "2026-10-29T07:07:04+08:00",
      "title": "漫画翻译迁移正式提交已推",
      "detail": "源管理、模型与账户、Torii、自部署及译图清理已推；精确CI进行中，其他真实提供方未验。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "source-filter-scope-ci-20261029",
      "at": "2026-10-29T07:07:04+08:00",
      "title": "筛选作用域宿主精确CI成功",
      "detail": "Koma 59a1对应CI40784063216成功；整体源审计继续开放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40784063216"
      ]
    },
    {
      "id": "translation-migration-ci-20261029",
      "at": "2026-10-29T07:14:24+08:00",
      "title": "漫画翻译迁移精确CI成功",
      "detail": "3bd44对应CI40784766661成功；其他提供方真实网络仍待验。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40784766661"
      ]
    },
    {
      "id": "enhancement-system-model-237-20261029",
      "at": "2026-10-29T07:14:24+08:00",
      "title": "237系统超分可用状态开关可见",
      "detail": "无下载模型但系统模型可用，开关及模型管理入口可见；完全无可用模型状态未验，设备恢复释租。此时间为登记时间。",
      "itemId": "ENHANCEMENT_SWITCH_VISIBILITY",
      "kind": "checkpoint"
    },
    {
      "id": "nemo-local-preload-candidate-20261029",
      "at": "2026-10-29T07:19:08+08:00",
      "title": "Nemo本地文件夹预载候选已构建",
      "detail": "仅本地文件夹缺源续读序列时复用既有导入顺序和原预算，在线源仍要求已验证序列；197尚未安装或真机验证。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "nemo-local-preload-bounce-197-20261029",
      "at": "2026-10-29T07:29:25+08:00",
      "title": "197 Nemo候选末页回弹未跨章",
      "detail": "纵向分页到3/3后继续上滑仅回弹，未进入下一章；保留录屏，正在调查。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/nemo-local-preload-vertical-roundtrip-180/"
      ]
    },
    {
      "id": "xcomic-single-check-237-20261029",
      "at": "2026-10-29T07:37:03+08:00",
      "title": "237 XCOMIC一次检查具名核验",
      "detail": "双源候选目录及公开简体具名详情已核，公开繁体仅实体核验；宿主提交已推且CI进行中，原包数据及设备已恢复。此时间为登记时间。",
      "itemId": "SOURCE_EMPTY_SETTINGS_ENTRY",
      "kind": "checkpoint"
    },
    {
      "id": "xcomic-host-ci-success-20261029",
      "at": "2026-10-29T07:46:11+08:00",
      "title": "XCOMIC宿主一次检查精确CI成功",
      "detail": "2980提交CI成功，公开繁体详情仍未Native验证。此时间为登记时间。",
      "itemId": "SOURCE_EMPTY_SETTINGS_ENTRY",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40788305052"
      ]
    },
    {
      "id": "nemo-preloaded-native-bounce-20261029",
      "at": "2026-10-29T07:46:11+08:00",
      "title": "Nemo下一章已预载但原生分页回弹",
      "detail": "下一章和列表行已接入，原生分页向前仍回弹；数据集候选待真机验证。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "nemo-gesture-cause-correction-20261029",
      "at": "2026-10-29T07:48:49+08:00",
      "title": "Nemo末页回弹原因判断纠正",
      "detail": "同样滑动在章内也回弹，不能证明原生数据通知异常；试验已撤回，原候选继续验证手势及跨章。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint"
    },
    {
      "id": "nemo-local-roundtrip-197-20261029",
      "at": "2026-10-29T07:54:57+08:00",
      "title": "197 Nemo纵向双向跨章已核",
      "detail": "完整纵向滑动进入下一章并返回前章末页，画面连续；原App、数据及设备已恢复释租，精确CI待核。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/nemo-original-native-full-swipe-roundtrip-192/"
      ]
    },
    {
      "id": "mh1234-filter-016-public-20261029",
      "at": "2026-10-29T07:54:57+08:00",
      "title": "MH1234筛选源公开及候选具名验证",
      "detail": "237本地候选筛选具名已核，公开WASM真实HTML回放及精确CI成功；公开实体未新Native验证。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "reader-boundary-accepted-1-20261029",
      "at": "2026-10-29T07:57:24+08:00",
      "title": "连续跨章具名范围完成",
      "detail": "197 Blue、MH1234及Nemo具名路径与精确CI已核，原数据及设备恢复；不外推其他来源或宿主。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "verified",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40790249371"
      ]
    },
    {
      "id": "reader-boundary-accepted-2-20261029",
      "at": "2026-10-29T07:57:24+08:00",
      "title": "跨章图片尺寸具名范围完成",
      "detail": "197 Blue、MH1234及Nemo具名路径与精确CI已核，原数据及设备恢复；不外推其他来源或宿主。此时间为登记时间。",
      "itemId": "READER_PAGE_SIZE_SHRINK",
      "kind": "verified",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40790249371"
      ]
    },
    {
      "id": "reader-boundary-accepted-3-20261029",
      "at": "2026-10-29T07:57:24+08:00",
      "title": "阅读方向具名范围完成",
      "detail": "197 Blue、MH1234及Nemo具名路径与精确CI已核，原数据及设备恢复；不外推其他来源或宿主。此时间为登记时间。",
      "itemId": "READER_SWIPE_DIRECTION_MISMATCH",
      "kind": "verified",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40790249371"
      ]
    },
    {
      "id": "source-import-io-pushed-20261029",
      "at": "2026-10-29T08:09:45+08:00",
      "title": "源包导入I/O限定改动已推",
      "detail": "归档及WASM读取与摘要处理改动已推，CI进行中；真实交互及性能边界继续开放。UUID设置候选待237验。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "translation-empty-forms-197-20261029",
      "at": "2026-10-29T08:19:30+08:00",
      "title": "197翻译空源表单界面核验中",
      "detail": "已保存原包及数据基线，候选安装后仅观察API/Codex空表单，不保存、不登录或调用；设备恢复待执行。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint"
    },
    {
      "id": "source-import-io-ci-20261029",
      "at": "2026-10-29T08:19:30+08:00",
      "title": "源导入I/O精确CI成功",
      "detail": "c32b对应CI40791708093成功；真实安装交互及性能仍未验。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40791708093"
      ]
    },
    {
      "id": "translation-empty-forms-restored-197-20261029",
      "at": "2026-10-29T08:24:45+08:00",
      "title": "197翻译空源表单及设备恢复已核",
      "detail": "普通设置路径观察API与Codex空表单并取消，未保存或调用；原包、五份数据及电源恢复释租，真实账户网络仍待验。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/translation-completion/"
      ]
    },
    {
      "id": "progress-summary-correction-20261029",
      "at": "2026-10-29T08:30:58+08:00",
      "title": "进度页过时汇总纠正",
      "detail": "移除手写计数并纠正已验事项的过时汇总，原证据入口回补；浏览器复核待完成。此时间为登记时间。",
      "itemId": "PROGRESS_PAGE_READABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "progress-page-browser-review-20261029",
      "at": "2026-10-29T08:34:51+08:00",
      "title": "进度页具名浏览器复核完成",
      "detail": "动态计数、筛选、时间来源、证据链接及展开状态已核；25–28历史日期全量核对仍开放。书源后续具名结果仍待回验。此时间为登记时间。",
      "itemId": "PROGRESS_PAGE_READABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-unselected-model-197-20261029",
      "at": "2026-10-29T08:43:31+08:00",
      "title": "增强开关按未选模型原条件验证",
      "detail": "237此前选中系统模型不能代验未选状态；197普通默认值路径正在核验，原状态恢复已准备。此时间为登记时间。",
      "itemId": "ENHANCEMENT_SWITCH_VISIBILITY",
      "kind": "checkpoint"
    },
    {
      "id": "nnh-search-and-md-screen-20261029",
      "at": "2026-10-29T08:43:31+08:00",
      "title": "NNHanman候选搜索及MangaDex截图边界",
      "detail": "237候选love搜索不再报错，源已推CI待核；MangaDex截图路径误配，原画面无效，正在补正。设备会话已恢复，实体字节待补核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "enhancement-unselected-197-accepted-20261029",
      "at": "2026-10-29T08:47:37+08:00",
      "title": "197未选择模型时增强开关已核",
      "detail": "普通恢复默认后未选择模型，开关可见且可启用系统模型；原状态及电源恢复释租。此时间为登记时间。",
      "itemId": "ENHANCEMENT_SWITCH_VISIBILITY",
      "kind": "verified",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/enhancement-unselected-switch-visible-201/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/enhancement-unselected-enable-202/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-settings-menu/enhancement-unselected-final-restoration/"
      ]
    },
    {
      "id": "nnh-public-wasm-20261029",
      "at": "2026-10-29T08:47:37+08:00",
      "title": "NNHanman公开WASM具名核验",
      "detail": "精确CI成功，公开WASM搜索分页及筛选描述具名通过；公开包未新Native验证，MangaDex画面重验中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "progress-date-audit-md-20261029",
      "at": "2026-10-29T08:51:21+08:00",
      "title": "历史时间依据核对及MangaDex画面验证",
      "detail": "已列无提出/首次存证时间事项并查原归档，部分无直接时间依据继续保未知；237 UUID错误画面及合法重入已核，真实feed消费待验。此时间为登记时间。",
      "itemId": "PROGRESS_PAGE_READABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "progress-original-user-times-20261029",
      "at": "2026-10-29T08:53:00+08:00",
      "title": "核实两项本会话用户反馈时间",
      "detail": "依据当前会话原始用户消息核实NextE迁移与超分指示器反馈时刻；未找到的原始首报继续保未知。此时间为登记时间。",
      "itemId": "PROGRESS_PAGE_READABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "api23-original-user-report-20261029",
      "at": "2026-10-29T08:53:59+08:00",
      "title": "核实AGC启动问题本会话首报",
      "detail": "当前会话原始用户消息含审核无法启动及四份附件，已登记原始时刻；章节列表原话本次未定位。此时间为登记时间。",
      "itemId": "APP_STARTUP_API23_CRASH",
      "kind": "checkpoint"
    },
    {
      "id": "md-real-feed-237-20261029",
      "at": "2026-10-29T09:08:22+08:00",
      "title": "237 MangaDex真实组过滤已核",
      "detail": "同作品22章过滤为15章，真实feed重放核排除7章及旧章exact请求；设备exact阅读未验，原状态恢复。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "source-install-longframe-20261029",
      "at": "2026-10-29T09:08:22+08:00",
      "title": "源安装真实长帧仍待修",
      "detail": "真实trace保留长帧和GC反例，图标候选已构建并回验，性能事项保持开放。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "source-import-candidate-no-improvement-20261029",
      "at": "2026-10-29T09:16:12+08:00",
      "title": "源导入候选未证明长帧改善",
      "detail": "真实trace仍有长帧，候选撤回；sheet遮挡期间图标情况未知，设备恢复待独立核对。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "mangadex-public-feed-replay-20261029",
      "at": "2026-10-29T09:16:12+08:00",
      "title": "MangaDex公开WASM真实feed重放已核",
      "detail": "保留15、排除7且旧章exact未过滤可取；公开包未新Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/mangadex-hans-public-9e6b3f8/real-feed-replay.json"
      ]
    },
    {
      "id": "source-import-candidate-rollback-restored-20261029",
      "at": "2026-10-29T09:20:24+08:00",
      "title": "源导入无改善候选撤回并核实恢复",
      "detail": "237原宿主、源包、五份数据和电源独立读回一致；关闭sheet后四源图标稳定，遮挡期间未验。后续在必要导入采样。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "current-activity-import-md-20261029",
      "at": "2026-10-29T09:22:48+08:00",
      "title": "当前工作更新为导入性能及MangaDex核对",
      "detail": "必要繁中源导入补采UI性能证据，MangaDex英文已有库排除章节身份核对并行进行。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "source-install-virtual-candidate-20261029",
      "at": "2026-10-29T09:32:07+08:00",
      "title": "安装列表按需创建候选待验",
      "detail": "真实采样指向已安装列表创建开销；保原样式与身份的候选已构建，尚未真机。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-import-830/cpu.json"
      ]
    },
    {
      "id": "md-hant-library-filter-20261029",
      "at": "2026-10-29T09:32:07+08:00",
      "title": "237 MangaDex繁中已有库过滤已核",
      "detail": "具名作品49章在设置真实组后显示0章，候选验证；公开包Native及其他语言未外推，设备恢复中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-before-839/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/md-hant-save-844/"
      ]
    },
    {
      "id": "source-virtual-first-candidate-regression-20261029",
      "at": "2026-10-29T09:40:20+08:00",
      "title": "源列表虚拟化首候选出现反例",
      "detail": "标题位置保持，但分隔线异常及尾部重复行报告使首候选不能交付；第二候选构建中，设备会话继续。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "source-virtual-second-candidate-withdrawn-20261029",
      "at": "2026-10-29T09:58:16+08:00",
      "title": "源列表第二候选未证明性能改善",
      "detail": "样式及身份具名正常，但真实trace仍有长帧；非严格AB不判增减，结构改动已撤回，设备恢复。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "mangadex-hant-public-english-candidate-20261029",
      "at": "2026-10-29T09:58:16+08:00",
      "title": "MangaDex繁中公开核验及英文候选",
      "detail": "繁中公开WASM真实feed重放已核，未另Native；英文候选真实响应执行通过，设备及独有消费路径待验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "md-english-filter-cover-gap-20261029",
      "at": "2026-10-29T10:23:39+08:00",
      "title": "MangaDex英文过滤具名通过，首卷封面待验",
      "detail": "已有库组过滤及源CI已核；较大结果集首卷封面遗漏已做候选，普通设置和设备回验未完。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/md-en-cover022-live/verification.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/md-en-cover022-v3-replay/verification.json"
      ]
    },
    {
      "id": "md-english-cover-home-237-20261029",
      "at": "2026-10-29T10:36:46+08:00",
      "title": "237英文首卷设置及首页具名已核",
      "detail": "首卷开关保存重入及首页封面具名通过；独立Latest未打开菜单仍待验，候选未提交，原设备状态恢复。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "md-en-cover-public-20261029",
      "at": "2026-10-29T10:43:51+08:00",
      "title": "MangaDex英文首卷源已公开",
      "detail": "公开WASM真实响应重放已核；公开包未新Native，独立Latest及搜索候选设备验证进行中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/md-en-public-ba9d1bc/replay/verification.json"
      ]
    },
    {
      "id": "official-name-browser-20261029",
      "at": "2026-10-29T10:43:51+08:00",
      "title": "官网漫画栏目具名核对",
      "detail": "雀魂及王者品牌和漫画栏目有官网画面依据；战双仅标题，阴阳师访问被站点策略拦截。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint"
    },
    {
      "id": "md-en-latest-search-native-20261029",
      "at": "2026-10-29T10:54:55+08:00",
      "title": "237英文候选Latest及引号搜索已核",
      "detail": "独立Latest具名显示，带引号自动搜索真实请求成功；未逐个核全部封面、未点击提交按钮，设备恢复待独立复核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "source-brand-additional-20261029",
      "at": "2026-10-29T10:54:55+08:00",
      "title": "官方品牌名称逐项核对",
      "detail": "新增具名官网品牌证据，部分站点仍无法访问，不从局部页面推断全站别名。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint"
    },
    {
      "id": "md-en-search-public-restored-20261029",
      "at": "2026-10-29T11:03:28+08:00",
      "title": "MangaDex英文搜索公开及恢复已核",
      "detail": "精确CI及公开WASM真实响应已核，两场原包数据与电源恢复已独立核实；下一批三源候选待设备验证。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/md-en-public-65695db/real-feed-replay.json"
      ]
    },
    {
      "id": "three-source-import-237-20261029",
      "at": "2026-10-29T11:12:11+08:00",
      "title": "237三源候选已导入",
      "detail": "三源普通导入及实体核验完成，搜索回验进行中；脚本导航偏航已恢复，非产品失败。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "direct-human-times-corrected-20261029",
      "at": "2026-10-29T11:14:55+08:00",
      "title": "按本会话直接用户事件纠正反馈时间",
      "detail": "依据原始UserMessage事件校正具名事项时间，保双击旧值取代依据及可能更早历史；东立重复反馈和两个约值仅补可核事件。此时间为登记时间。",
      "itemId": "PROGRESS_PAGE_READABILITY",
      "kind": "checkpoint"
    },
    {
      "id": "three-source-search-release-20261029",
      "at": "2026-10-29T11:35:36+08:00",
      "title": "两源搜索具名及四源发布恢复",
      "detail": "动漫屋与英文WEBTOON搜索已核，嗨皮域名解析失败；CI发布步骤HTTP500后核对既有草稿并恢复发布，原CI仍为失败。设备原状态恢复。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-four-170ba07-ci/publication-final.json",
        "/private/tmp/source-four-170ba07-ci/public/delivery.json"
      ]
    },
    {
      "id": "four-source-search-and-date-20261029",
      "at": "2026-10-29T11:54:16+08:00",
      "title": "四源具名搜索及原话时间核对",
      "detail": "四源搜索路径已取结果，诊断日志审批拒绝未读取、设备恢复待独核；四项原反馈时间据本会话直接事件纠正，旧约值保证据。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "four-source-restoration-verified-20261029",
      "at": "2026-10-29T11:56:12+08:00",
      "title": "四源会话恢复独立核实",
      "detail": "原宿主、源包、数据及电源恢复已核；源提交已推，精确CI进行中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "four-source-public-ci-success-20261029",
      "at": "2026-10-29T11:59:29+08:00",
      "title": "四源提交精确CI与公开实体已核",
      "detail": "精确CI成功，索引及四包公开实体已核；公开WASM不同于设备冻结实体，不冒公开包新Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-f83-public/delivery.json"
      ]
    },
    {
      "id": "baozimh-session-restoration-20261029",
      "at": "2026-10-29T12:04:06+08:00",
      "title": "包子搜索未发出，会话恢复中",
      "detail": "候选首页触发验证，原包重导入改变身份路径；正在恢复原包路径及公开会话元数据，不读写系统Cookie或伪造grant。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "baozimh-session-restored-20261029",
      "at": "2026-10-29T12:10:53+08:00",
      "title": "包子原包及会话已恢复",
      "detail": "原包、路径、会话及用户数据逐字恢复，设备休眠释租；首页挑战前搜索未发出，源候选推送中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "baozimh-public-namicomi-filters-20261029",
      "at": "2026-10-29T12:18:26+08:00",
      "title": "包子源公开及NamiComi筛选缺口",
      "detail": "包子精确CI和公开实体已核，搜索Native未验；NamiComi参考筛选未移植，正在核适配与真实接口。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-033-public/delivery.json"
      ]
    },
    {
      "id": "namicomi-filter-host-built-20261029",
      "at": "2026-10-29T12:34:17+08:00",
      "title": "NamiComi动态筛选宿主已编译",
      "detail": "宿主首次构建及源候选真实标签执行已核；最终构建和237源候选导入与验收尚未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "namicomi-hans-tristate-237-20261029",
      "at": "2026-10-29T12:47:14+08:00",
      "title": "237 NamiComi简中三态结果已取得",
      "detail": "动态标签包含与排除产生不同真实目录结果；保存重入、忽略恢复、繁中和设备恢复继续核验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "namicomi-tristate-persistence-237-20261029",
      "at": "2026-10-29T12:57:17+08:00",
      "title": "237 NamiComi筛选重入与搜索具名已核",
      "detail": "简中包含、排除、重入及忽略恢复，繁中目录及独立搜索筛选具名已核；设备恢复及公开交付仍在进行。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "namicomi-237-restored-host-pushed-20261029",
      "at": "2026-10-29T13:00:55+08:00",
      "title": "NamiComi设备恢复及宿主提交",
      "detail": "原包、六份数据和电源已核恢复并释租；宿主提交已推，精确CI进行中，两源正式交付待完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "namicomi-public-noyacg-next-20261029",
      "at": "2026-10-29T13:06:39+08:00",
      "title": "NamiComi正式交付，NoyAcg候选待验",
      "detail": "宿主及简繁源精确CI和公开实体已核；公开实体不同于设备候选，不冒再次Native。NoyAcg候选237验证中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-1ce-public/delivery.json"
      ]
    },
    {
      "id": "koma-host-current-summary-20261029",
      "at": "2026-10-29T13:07:37+08:00",
      "title": "更新当前宿主与设备摘要",
      "detail": "Koma当前提交精确CI成功；197已恢复释租，237正在原宿主下验证NoyAcg候选。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "noyacg-search-denied-restored-20261029",
      "at": "2026-10-29T13:13:30+08:00",
      "title": "NoyAcg搜索被拒，筛选入口已观察",
      "detail": "237搜索请求被拒，HTTP及原因未知；筛选仅见未操作，原包数据电源已恢复释租，旧宿主兼容修正中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "parallel-source-install-work-20261029",
      "at": "2026-10-29T13:28:29+08:00",
      "title": "源验证与安装性能并行推进",
      "detail": "Root接续197安装性能定位，source_terra继续237源线；NoyAcg真实消费待适用新条件，Komiic具名搜索为空不冒命中。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "mh1234-dynamic-genre-237-20261029",
      "at": "2026-10-29T13:38:10+08:00",
      "title": "237 MH1234动态题材候选已核",
      "detail": "恋爱题材选择、重入及重置具名通过，原状态恢复释租；候选尚未公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "mh1234-genre-public-20261029",
      "at": "2026-10-29T13:42:01+08:00",
      "title": "MH1234动态题材源已公开",
      "detail": "精确CI及公开WASM真实HTML回放已核；公开实体与设备候选不同，未另作Native采用。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "mangaball-search-filter-candidate-20261029",
      "at": "2026-10-29T13:45:50+08:00",
      "title": "MangaBall搜索筛选候选及真实请求边界",
      "detail": "参考筛选仅搜索消费，本地默认合同保持；真实组合一次403，原因未知，Native及公开交付未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "noya-komiic-public-20261029",
      "at": "2026-10-29T13:51:00+08:00",
      "title": "NoyAcg及Komiic公开实体已核",
      "detail": "精确CI及公开WASM受控回放通过；公开实体未另Native，设备搜索拒绝与空结果边界保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "mangaball-webtoon-filter-pushed-20261029",
      "at": "2026-10-29T14:01:39+08:00",
      "title": "MangaBall与繁中WEBTOON筛选候选已推",
      "detail": "WEBTOON设备筛选界面已观察但分类请求未证，MangaBall真实组合403边界保留；精确CI待核，设备已恢复。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "mangaball-webtoon-public-20261029",
      "at": "2026-10-29T14:06:11+08:00",
      "title": "MangaBall及繁中WEBTOON公开实体已核",
      "detail": "精确CI与公开WASM受控回放通过；设备分类及真实403边界保持，公开实体未另Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-0af-public/"
      ]
    },
    {
      "id": "import-stall-197-original-source-restored-20261029",
      "at": "2026-10-29T14:09:30+08:00",
      "title": "197原源目录精确补回",
      "detail": "冷启动源批次因一项原目录缺失中止，原导出包四成员补回且Registry未改；管理页与性能回验中。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "manhuagui-filter-candidate-20261029",
      "at": "2026-10-29T14:09:30+08:00",
      "title": "漫画柜筛选候选受控核验",
      "detail": "默认请求及参考范围已核，真实排行请求TLS失败，Native和公开交付未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "import-stall-manager-restored-197-20261029",
      "at": "2026-10-29T14:09:58+08:00",
      "title": "197原源补回后管理页显示恢复",
      "detail": "普通冷启动进入管理页可见已安装版本及更新操作；不代生产修复或导入性能验收，设备会话继续。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/import-stall197-restored-manager-r7/"
      ]
    },
    {
      "id": "source-import-icon-decode-trace-197-20261029",
      "at": "2026-10-29T14:18:47+08:00",
      "title": "197真实导入图标解码开销已观察",
      "detail": "单帧多源图标主线程解码，遮挡期间视觉结果未知；图标复用方案核对中，尚未实施或验收。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/import-stall197-current-import-trace-r11/"
      ]
    },
    {
      "id": "tencent-filter-candidate-237-20261029",
      "at": "2026-10-29T14:23:13+08:00",
      "title": "237腾讯动漫筛选候选具名已核",
      "detail": "恋爱筛选与官网具名结果对应，重入及重置已核，原状态恢复释租；候选尚未提交公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "tencent-push-approval-denied-20261029",
      "at": "2026-10-29T14:24:10+08:00",
      "title": "腾讯动漫源提交推送被自动审批拒绝",
      "detail": "候选已本地提交，审批未确认推送授权、仓库公开性及敏感性；未推送，CI和公开未开始。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "source-icon-reuse-install-197-20261029",
      "at": "2026-10-29T14:28:01+08:00",
      "title": "源图标复用候选已安装并采样",
      "detail": "修正签名配置后同签候选安装成功，普通导入trace进行中；尚未判断性能改善。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "tencent-push-authorized-20261029",
      "at": "2026-10-29T14:28:01+08:00",
      "title": "腾讯动漫源提交已推",
      "detail": "核实当前授权及精确提交范围后正常推送；精确CI和公开实体待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "source-local-import-queue-candidate-20261029",
      "at": "2026-10-29T14:32:07+08:00",
      "title": "源本地导入接入既有串行队列候选",
      "detail": "像素复用虽减少解码但整帧仍卡，候选撤回；改为保其他源安全排队与串行写入，构建中且未Native。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-retained-source-icons-unadopted.patch"
      ]
    },
    {
      "id": "zazhimi-filter-237-20261029",
      "at": "2026-10-29T14:34:27+08:00",
      "title": "237杂志迷分类候选具名已核",
      "detail": "官网分类与设备结果对应，重入和重置已核；原状态恢复，候选未提交公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "zazhimi-push-denied-20261029",
      "at": "2026-10-29T14:35:08+08:00",
      "title": "杂志迷源推送被自动审批拒绝",
      "detail": "审批认为当前可信用户消息未直接授权该具体GitHub目的地及代码外发；未推送，CI和公开未开始。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "tencent-public-013-20261029",
      "at": "2026-10-29T14:35:53+08:00",
      "title": "腾讯动漫公开实体及回放已核",
      "detail": "精确CI及公开WASM真实页面回放通过；公开WASM不同设备候选，未另Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/tencent-ea5-public/tencentcomics-0.1.3.koma"
      ]
    },
    {
      "id": "source-local-import-final-197-20261029",
      "at": "2026-10-29T14:48:46+08:00",
      "title": "197普通本地导入具名验证及恢复完成",
      "detail": "最终候选普通同包导入、弹层关闭及列表滚动已核，原包数据与设备状态恢复；正式提交和精确CI待完成，不外推其他安装路径。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "mangaxiaosi-filter-237-20261029",
      "at": "2026-10-29T14:49:10+08:00",
      "title": "237漫小肆筛选候选具名已核",
      "detail": "韩国分类、封面、续页、重入及重置具名通过；设备原状态恢复，候选未提交公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "mangaxiaosi-v2-cover-boundary-20261029",
      "at": "2026-10-29T14:50:43+08:00",
      "title": "漫小肆最终候选限定封面域",
      "detail": "新域仅用于已实证封面，正文域边界保持；回放与设备候选相同，最终实体未Native或推送。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "source-import-queue-ci-success-20261029",
      "at": "2026-10-29T15:04:48+08:00",
      "title": "源本地导入队列修复精确CI成功",
      "detail": "197具名普通本地导入及恢复既有证据保持，提交精确CI成功；原事项完整范围仍需核对。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40831671392"
      ]
    },
    {
      "id": "jiuer-filter-237-20261029",
      "at": "2026-10-29T15:05:23+08:00",
      "title": "237 92漫画分类候选具名已核",
      "detail": "官网儿童分类及设备结果对应，重入和重置已核；原源包数据及电源恢复，候选未提交公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "jiuer-local-commit-20261029",
      "at": "2026-10-29T15:05:53+08:00",
      "title": "92漫画候选已本地提交",
      "detail": "与漫小肆候选等待统一审查推送，尚未公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "hentaifox-settings-evidence-20261029",
      "at": "2026-10-29T15:07:35+08:00",
      "title": "HentaiFox短标题消费边界核对",
      "detail": "源码有目录及详情消费，首次真实目录请求TLS失败，设备及站点消费未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "jiuer-sort-only-live-20261029",
      "at": "2026-10-29T15:08:12+08:00",
      "title": "92漫画单独排序真实请求已核",
      "detail": "真实post路径及WASM回放具名通过，默认路径保持；排序尚未Native验证。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/jiuermanhua-sort-only-post-live.html",
        "/private/tmp/jiuer-filter-sort-only-replay.json"
      ]
    },
    {
      "id": "zazhimi-public-and-cartoon18-boundary-20261029",
      "at": "2026-10-29T15:10:28+08:00",
      "title": "杂志迷公开实体及色漫网请求边界",
      "detail": "杂志迷公开回放已核，公开实体未另Native；色漫网不同UA单次站点错误不外推源或全站状态。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "jiuer-children-page2-403-20261029",
      "at": "2026-10-29T15:11:36+08:00",
      "title": "92漫画儿童分类第二页请求被拒",
      "detail": "真实第二页单次403，原因未知且未重试；首页及游标不代第二页通过。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "manhuagui-timeout-scope-done-20261029",
      "at": "2026-10-29T15:18:53+08:00",
      "title": "漫画柜普通列表超时回验恢复",
      "detail": "197同版本普通入口真实列表和封面可见，数据及设备恢复；旧失败原因未知，不倒推或扩展其他路径。此时间为登记时间。",
      "itemId": "MANHUAGUI_RUNTIME_TIMEOUT",
      "kind": "verified"
    },
    {
      "id": "jiuer-mangaxiaosi-public-20261029",
      "at": "2026-10-29T15:19:26+08:00",
      "title": "92漫画及漫小肆正式包已核",
      "detail": "精确CI及公开WASM真实HTML回放已核；公开实体未另Native，92儿童第二页403边界保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-190-public/"
      ]
    },
    {
      "id": "source-public-update-callback-197-20261029",
      "at": "2026-10-29T15:36:02+08:00",
      "title": "197公开索引更新已核，清理回调待定位",
      "detail": "具名源更新成功且无无关图标集中重解码；另有清理完成回调耗时，设备恢复进行中。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "source-public-update-197-restored-20261029",
      "at": "2026-10-29T15:41:53+08:00",
      "title": "197公开更新会话恢复完成",
      "detail": "原源包、七域和电源已核恢复并释租；清理完成回调耗时仍待定位。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "mangabz-filter-237-20261029",
      "at": "2026-10-29T15:44:36+08:00",
      "title": "237 MangaBz筛选组合候选已核",
      "detail": "动态筛选、组合结果、重入及重置具名通过，设备原状态恢复；候选尚未提交公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "mangabz-filter-local-commit-20261029",
      "at": "2026-10-29T15:45:55+08:00",
      "title": "MangaBz筛选候选已本地提交",
      "detail": "精确提交内容与设备冻结一致，尚待审查推送及公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint"
    },
    {
      "id": "source-update-metadata-projection-197-20261029",
      "at": "2026-10-29T15:54:48+08:00",
      "title": "197公开更新候选具名采样",
      "detail": "保原排序分组的候选更新成功；清理完成回调仍有耗时，单次采样非严格AB，设备恢复及交付审查中。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "source-update-projection-restored-197-20261029",
      "at": "2026-10-29T16:00:12+08:00",
      "title": "197公开更新候选会话恢复完成",
      "detail": "原源、七域数据及电源已恢复释租；名称投影候选待交付，清理完成回调耗时仍待定位。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "source-projection-push-and-remaining-reconciled-20261029",
      "at": "2026-10-29T16:03:06+08:00",
      "title": "名称投影提交已推，源审计待办校正",
      "detail": "性能候选已推且精确CI待核；源审计移除已有具名验证的过期待办，保嗨皮与包子实际未验边界。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint"
    },
    {
      "id": "source-projection-ci-success-20261029",
      "at": "2026-10-29T16:07:33+08:00",
      "title": "源管理名称投影精确CI成功",
      "detail": "197具名公开更新与设备恢复已核，精确CI成功；清理完成回调耗时仍待定位。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40839273297"
      ]
    },
    {
      "id": "cmanhua-filter-candidate-237-20261029",
      "at": "2026-10-29T16:13:01+08:00",
      "title": "237 CManhua筛选候选具名已核",
      "detail": "筛选选择、重入及重置已核；官网两种状态首屏相同，真实第二页未验，原状态恢复，源提交待推。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/cmanhua-filter-ongoing-live.html",
        "/private/tmp/cmanhua-filter-completed-live.html"
      ]
    },
    {
      "id": "source-reference-differences-20261029",
      "at": "2026-10-29T16:17:09+08:00",
      "title": "书源分类参考差异具名核对",
      "detail": "爱看漫及漫画160的参考分类差异已定位，真实分类路径未验；MangaBz和CManhua候选已审，推送进行中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "docs/CURRENT_STATUS.md"
      ]
    },
    {
      "id": "mangabz-cmanhua-public-20261029",
      "at": "2026-10-29T16:21:53+08:00",
      "title": "MangaBz与CManhua正式包已公开",
      "detail": "精确CI成功，公开WASM对保存官网页面回放与设备候选一致；公开实体未另作Native，CManhua第二页未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-668-public/",
        "https://github.com/honjow/koma-sources/actions/runs/40840714068"
      ]
    },
    {
      "id": "progress-page-verified-20261029",
      "at": "2026-10-29T16:25:56+08:00",
      "title": "进度页面具名范围复核完成",
      "detail": "Root浏览器核近期问题、提出时间、动态分类与最新时间线可查；无直接依据的原始时间继续显示未核实，不声称已知全部历史首报。此时间为登记时间。",
      "itemId": "PROGRESS_PAGE_READABILITY",
      "kind": "checkpoint",
      "evidence": [
        "docs/CURRENT_STATUS.md"
      ]
    },
    {
      "id": "detail-three-user-directions-20261029",
      "at": "2026-10-29T16:33:30+08:00",
      "title": "登记漫画详情三项用户要求",
      "detail": "详情持久化与静默更新、滚动标题和封面模糊渐变分别登记；时间为本轮反馈登记时间，精确消息时刻未知。",
      "itemId": "MANGA_DETAIL_PERSISTED_BACKGROUND_REFRESH",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "manga160-category-candidate-20261029",
      "at": "2026-10-29T16:36:55+08:00",
      "title": "漫画160分类候选具名回验",
      "detail": "237日韩分类、重入与重置已核，原状态恢复；候选未公开，自然验证窗口未出现。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "manga160-category-commit-20261029",
      "at": "2026-10-29T16:37:39+08:00",
      "title": "漫画160分类候选独立提交",
      "detail": "分类候选已本地提交，未推送公开；原challengeRequestId WIP保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "89cfc7b"
      ]
    },
    {
      "id": "zaimanhua-filter-candidate-20261029",
      "at": "2026-10-29T16:58:21+08:00",
      "title": "再漫画筛选候选具名回验",
      "detail": "237周榜、连载筛选及重入重置已核，原状态恢复；候选未提交公开，数字搜索开关差异未覆盖。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "zaimanhua-filter-final-candidate-20261029",
      "at": "2026-10-29T17:00:26+08:00",
      "title": "再漫画最终分页候选独立提交",
      "detail": "v4修正分页读取，保存页面回放同设备v3；真实末页及v4 Native未验，尚未推送。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/zaimanhua-filter019-v4.koma",
        "c5e2022"
      ]
    },
    {
      "id": "mycomic-filter-difference-20261029",
      "at": "2026-10-29T17:02:11+08:00",
      "title": "MyComic参考筛选差异已定位",
      "detail": "当前源未提供参考筛选；一次不同设备请求身份返回403，真实筛选及Native未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "detail-three-candidate-build-20261029",
      "at": "2026-10-29T17:06:30+08:00",
      "title": "漫画详情三项首版构建完成",
      "detail": "详情持久化后台更新、滚动标题和封面背景首版已构建，197普通路径验收中，尚未观察终态。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_PERSISTED_BACKGROUND_REFRESH",
      "kind": "checkpoint",
      "evidence": [
        "ad3c2c47a4868063715d6e3b55c645e68e67dd33856ad2eaf19e42fb306baa2e"
      ]
    },
    {
      "id": "detail-entry-background-counterexample-20261029",
      "at": "2026-10-29T17:17:02+08:00",
      "title": "详情入场已观察，背景仍需修正",
      "detail": "197入场已有详情和章节持续显示，顶部无重复标题；背景矩形边界明显，冷启动持久数据及滚动标题仍核验。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_COVER_BLUR_GRADIENT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manga-detail197-entry-motion-46/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manga-detail197-header-47/"
      ]
    },
    {
      "id": "komiic-filter-candidate-20261029",
      "at": "2026-10-29T17:22:11+08:00",
      "title": "Komiic动态筛选候选设备入口未通过",
      "detail": "真实标签和WASM回放已核；237首页无法连接，未进入筛选，原因未知；原状态恢复，候选未公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "detail-new-candidate-review-20261029",
      "at": "2026-10-29T17:30:02+08:00",
      "title": "详情新候选普通路径已观察",
      "detail": "197内容入场及滚动标题具名观察，背景矩形边界消除；深色、恢复及正式交付仍待核。漫画160和再漫画源精确CI成功，公开实体待核。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_COVER_BLUR_GRADIENT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/40849389869"
      ]
    },
    {
      "id": "detail-device-validation-20261029",
      "at": "2026-10-29T17:37:04+08:00",
      "title": "详情三项具名设备验证完成",
      "detail": "197冷进程往返、滚动标题与浅深色渐变已观察，原读态、电源及租约已恢复；正式提交中。两源公开实体回放已核，公开包未另Native。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_PERSISTED_BACKGROUND_REFRESH",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-c5-public/identity.json",
        "/private/tmp/source-c5-public/candidate-public-equality.json"
      ]
    },
    {
      "id": "kuaikan-filter-candidate-20261029",
      "at": "2026-10-29T17:38:08+08:00",
      "title": "快看筛选候选具名回验",
      "detail": "237恋爱分类、重入及重置已核，原状态恢复；候选未提交公开。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "kuaikan-filter-commit-20261029",
      "at": "2026-10-29T17:38:53+08:00",
      "title": "快看筛选候选独立提交",
      "detail": "快看筛选已本地提交，尚未推送公开；原搜索WIP保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "225468b"
      ]
    },
    {
      "id": "asmhentai-filter-difference-20261029",
      "at": "2026-10-29T17:42:10+08:00",
      "title": "AsmHentai参考筛选差异已定位",
      "detail": "官网标签DOM与固定参考不同，筛选未实现或真机验收；既有短标题验收不代替筛选。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "xcomic-filter-difference-20261029",
      "at": "2026-10-29T17:45:44+08:00",
      "title": "XCOMIC简繁筛选差集已定位",
      "detail": "固定参考搜索含多项筛选，现公开源未提供；API及默认值待核，既有一次检查不代筛选完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "asmhentai-tag-samples-20261029",
      "at": "2026-10-29T17:47:29+08:00",
      "title": "AsmHentai标签样本补充",
      "detail": "真实前五页600个不同标签及两个单标签首屏已核；未改源或Native，不外推全部标签。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "detail-background-user-correction-20261029",
      "at": "2026-10-29T17:51:51+08:00",
      "title": "用户指出详情浅色背景过暗及范围不足",
      "detail": "此前仅核边界融合，用户不接受暗化和覆盖范围；该项保持开放，正在修正。df8ef8已推，精确CI查询遇EOF，状态未知。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_COVER_BLUR_GRADIENT",
      "kind": "checkpoint",
      "evidence": [
        "df8ef8be739fbd09ca0619387911eeba2d3a8952"
      ]
    },
    {
      "id": "detail-background-corrected-candidate-20261029",
      "at": "2026-10-29T18:02:50+08:00",
      "title": "详情背景纠正候选浅深色已观察",
      "detail": "197浅色灰黑遮罩消除且覆盖简介，深色淡入背景已观察；恢复和交付尚未完成。旧首版精确CI成功不代纠正候选交付。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_COVER_BLUR_GRADIENT",
      "kind": "checkpoint",
      "evidence": [
        "9f134959f775c815b8dc4b82ad645fa2152b77fdc3cf5aa740bd7f3eb02784df",
        "https://github.com/honjow/Koma/actions/runs/40851702184"
      ]
    },
    {
      "id": "detail-device-restored-delivery-20261029",
      "at": "2026-10-29T18:05:51+08:00",
      "title": "详情持久化和滚动标题已交付",
      "detail": "197具名路径及df8精确CI成功，持久化与滚动标题按范围完成；背景纠正候选设备恢复完成，正式提交中。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_PERSISTED_BACKGROUND_REFRESH",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40851702184"
      ]
    },
    {
      "id": "detail-background-correction-delivered-20261029",
      "at": "2026-10-29T18:13:29+08:00",
      "title": "详情背景纠正已交付",
      "detail": "197浅深色具名结果及恢复已核；b178已推、精确CI成功，取代首版浅色压暗和覆盖不足。此时间为登记时间。",
      "itemId": "MANGA_DETAIL_COVER_BLUR_GRADIENT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40854934583"
      ]
    },
    {
      "id": "asmhentai-filter-candidate-20261029",
      "at": "2026-10-29T18:13:38+08:00",
      "title": "AsmHentai标签筛选候选具名回验",
      "detail": "真实标签页面回放及237筛选、重入重置已核，原状态恢复；候选未公开，其他参考功能仍未实现。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "asmhentai-filter-commit-20261029",
      "at": "2026-10-29T18:15:35+08:00",
      "title": "AsmHentai标签排序候选独立提交",
      "detail": "本地提交及真实Latest页回放已核；未推公开，Latest Native及其他参考功能未覆盖。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "b035012"
      ]
    },
    {
      "id": "asmhentai-tag-query-replay-20261029",
      "at": "2026-10-29T18:18:01+08:00",
      "title": "AsmHentai标签与关键词组合回放",
      "detail": "真实请求及生产WASM回放中文12项并有下一页；该搜索未Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/asmhentai-tag-query-live.html",
        "/private/tmp/asmhentai-tag-query-replay-v4.json"
      ]
    },
    {
      "id": "zerobyw-filter-candidate-20261029",
      "at": "2026-10-29T18:37:58+08:00",
      "title": "Zero分类候选具名回验",
      "detail": "237战斗分类与重入已核、原状态恢复；候选未提交公开，登录窗口标题未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "zerobyw-filter-commit-20261029",
      "at": "2026-10-29T18:38:25+08:00",
      "title": "Zero筛选候选独立提交",
      "detail": "Zero筛选已本地提交，尚未推送公开；既有设备证据仅属于候选。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "1a8ff43"
      ]
    },
    {
      "id": "source-delivery-and-restoration-correction-20261029",
      "at": "2026-10-29T18:44:16+08:00",
      "title": "书源交付及东立恢复状态更新",
      "detail": "快看与AsmHentai源精确CI成功，公开实体待核；东立本轮设备已按既有具名证据恢复，正文范围保持开放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/40856810217",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "kuaikan-asm-public-20261029",
      "at": "2026-10-29T18:48:27+08:00",
      "title": "快看和AsmHentai公开实体已核",
      "detail": "公开WASM对真实页面回放与设备候选数据一致；公开实体未另Native，Asm其他参考功能仍未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/source-4e3-public/identity.json",
        "/private/tmp/source-4e3-public/candidate-public-equality.json"
      ]
    },
    {
      "id": "install-cpu-probe-branch-correction-20261029",
      "at": "2026-10-29T18:52:50+08:00",
      "title": "安装更新CPU采样位置纠正",
      "detail": "197真实更新成功，但采样点放错分支，未生成CPU数据；已纠正并继续诊断，设备会话未结束。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "install-cpu-callback-observed-20261029",
      "at": "2026-10-29T18:59:15+08:00",
      "title": "安装更新回调取得CPU采样",
      "detail": "197真实更新回调中观察到被覆盖浏览页遍历源表；非干净AB，候选未构建或实机验证，设备会话继续。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/source-install197-current-update-cpu-trace-80/cpu-callback-findings.json"
      ]
    },
    {
      "id": "xcomic-sort-candidate-20261029",
      "at": "2026-10-29T19:02:36+08:00",
      "title": "XCOMIC简中排序候选具名回验",
      "detail": "237排序、重入及重置已核并恢复；动态标签、繁中Native及发布未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "xcomic-sort-commit-20261029",
      "at": "2026-10-29T19:03:16+08:00",
      "title": "XCOMIC排序候选独立提交",
      "detail": "简繁排序已本地提交，尚未推送公开；繁中Native及动态筛选未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "e271800"
      ]
    },
    {
      "id": "install-visible-return-candidate-20261029",
      "at": "2026-10-29T19:09:33+08:00",
      "title": "安装更新与返回候选具名回验",
      "detail": "197普通更新及返回保留列表并显示最新版本，原数据和设备已恢复；正式交付CI待核。Zero/XCOMIC源CI成功、公开实体待核。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/source-install197-current-cpu-71/visibility-browse-version-proof.json",
        "https://github.com/honjow/koma-sources/actions/runs/40862486606"
      ]
    },
    {
      "id": "install-stall-delivered-20261029",
      "at": "2026-10-29T19:18:01+08:00",
      "title": "安装卡顿具名路径正式交付",
      "detail": "197普通导入、更新及返回已核，App精确CI成功；Zero与XCOMIC公开具名回放已核，繁中仅实体。此时间为登记时间。",
      "itemId": "SOURCE_PACKAGE_INSTALL_UI_STALL",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40863443089",
        "/private/tmp/source-e271-public/identity.json",
        "/private/tmp/source-e271-public/candidate-public-equality.json"
      ]
    },
    {
      "id": "pixiv-official-name-20261029",
      "at": "2026-10-29T19:20:55+08:00",
      "title": "pixiv官方中文名称具名核对",
      "detail": "官方简体帮助页使用pixiv，与当前名称对应；未改名或图标。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/pixiv-help-20261029.json"
      ]
    },
    {
      "id": "xcomic-hant-capability-counterexample-20261029",
      "at": "2026-10-29T19:56:21+08:00",
      "title": "XCOMIC繁中公开筛选入口反例",
      "detail": "公开0.1.8实际导出filters=false，排序菜单不可达；修正候选未验。Pixiv精确CI成功，实体待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/40866448544"
      ]
    },
    {
      "id": "mangadex-status-candidate-20261029",
      "at": "2026-10-29T19:58:13+08:00",
      "title": "MangaDex简中状态筛选候选具名回验",
      "detail": "首版能力导出漏项已修，237简中筛选、重入重置及恢复已核；繁中Native和其他筛选未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/md-status-live-replay-v2.json"
      ]
    },
    {
      "id": "mangadex-status-commit-20261029",
      "at": "2026-10-29T19:59:16+08:00",
      "title": "MangaDex状态筛选候选独立提交",
      "detail": "简繁状态筛选已本地提交，尚未推送公开；繁中Native和其他参考筛选未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "118bdaa"
      ]
    },
    {
      "id": "xcomic-hant-sort-candidate-20261029",
      "at": "2026-10-29T20:14:05+08:00",
      "title": "XCOMIC繁中排序修正候选回验",
      "detail": "237排序入口、消费、重入重置及恢复已核；候选未公开，动态标签未实现。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "mangadex-filter-session-restored-20261029",
      "at": "2026-10-29T20:31:55+08:00",
      "title": "新增筛选测试停止并恢复",
      "detail": "英文MangaDex当前设备场已恢复原包、数据和电源并释租，候选WIP保留，不作为本轮发布阻碍。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "baozi-home-cause-candidate-20261029",
      "at": "2026-10-29T20:36:49+08:00",
      "title": "包子首页验证关联受控候选",
      "detail": "源候选旧宿主兼容及受控挑战关联已核；宿主接线修正中，自然挑战未验且未发布。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/baozi-home-cause014.koma",
        "/private/tmp/baozi-home-cause-replay.json"
      ]
    },
    {
      "id": "baozi-challenge-title-node-20261029",
      "at": "2026-10-29T20:37:44+08:00",
      "title": "包子自然挑战中文标题节点已核",
      "detail": "既有自然首页挑战布局含中文源名和完成重试节点；无截图，不外推其他语言或挑战成功。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/baozi-search-home-1104/layout.json"
      ]
    },
    {
      "id": "chapter-feedback-delivered-20261029",
      "at": "2026-10-29T20:45:37+08:00",
      "title": "章节列表修复具名真机验收完成",
      "detail": "197分割线及行内反馈普通路径已核并恢复；103未安装候选保留边界。此时间为登记时间。",
      "itemId": "CHAPTER_LIST_DIVIDER_PRESS_FEEDBACK",
      "kind": "checkpoint",
      "evidence": [
        "reader-settings-menu/chapter-list-hds-final-install-detail-149",
        "reader-settings-menu/chapter-feedback-native-hds-150"
      ]
    },
    {
      "id": "library-progress-logic-regression-20261029",
      "at": "2026-10-29T20:45:37+08:00",
      "title": "书架进度生产逻辑回归",
      "detail": "生产store和投影合成重复章节回归通过，原200真机路径仍未验。此时间为登记时间。",
      "itemId": "LIBRARY_READING_PROGRESS_SEMANTICS",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "release-priority-014-pre-20261029",
      "at": "2026-10-29T20:45:37+08:00",
      "title": "版本目标纠正",
      "detail": "用户澄清先收口遗留故障，后续目标为正式0.1.4；本轮未tag或发布，pre候选不采用。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "release-target-correction-20261029",
      "at": "2026-10-29T20:52:07+08:00",
      "title": "用户纠正发版目标",
      "detail": "尽快发版是目标而非立即打版；先修复验证遗留故障，后续使用正式0.1.4。版本文件已撤回原0.1.3/code4，未tag或发布；197仅只读基线、租约已释放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "library-progress-real-snapshot-closed-20261029",
      "at": "2026-10-29T20:54:22+08:00",
      "title": "书架未读角标真实快照复验完成",
      "detail": "原真实重复章节快照经生产读取与投影均596，197画面与生产投影一致；未触200，按具名范围关闭。此时间为登记时间。",
      "itemId": "LIBRARY_READING_PROGRESS_SEMANTICS",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/library-progress-real-snapshot-replay.json"
      ]
    },
    {
      "id": "baozi-dafeng-validated-closure-20261029",
      "at": "2026-10-29T21:01:08+08:00",
      "title": "包子正文具名修复已验证",
      "detail": "237自然未缓存页9六图成功并返回，既有修复及CI已交付；原200根因未知、未操作200的证据保留。此时间为登记时间。",
      "itemId": "BAOZIMH_DAFENG_PAGE_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "about-page-migration-request-20261029",
      "at": "2026-10-29T21:07:18+08:00",
      "title": "登记关于页更新与日志迁移",
      "detail": "用户要求按NextE风格重整关于页并完整移植更新与日志查看；实现中，精确反馈时间未知，此时间为登记时间。",
      "itemId": "ABOUT_PAGE_RELEASE_HISTORY_MIGRATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "baozi-home-host-delivery-20261029",
      "at": "2026-10-29T21:07:18+08:00",
      "title": "包子首页宿主关联修复推进",
      "detail": "宿主已推，237普通首页12部但无自然挑战；原包数据和设备恢复，源已推且CI公开实体待核。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "source-filters-verified-closure-20261029",
      "at": "2026-10-29T21:10:53+08:00",
      "title": "源筛选原反馈具名范围完成",
      "detail": "普通、快切、清除及具名分流已验证；自然失败无具名样本保边界。此时间为登记时间。",
      "itemId": "SOURCE_FILTERS",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "baozi-home-public-delivery-20261029",
      "at": "2026-10-29T21:10:53+08:00",
      "title": "包子首页关联公开包已核",
      "detail": "精确CI及公开实体受控回放已核；自然挑战未出现，网页会话整体仍开放。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/baozi-be69-public/",
        "https://github.com/honjow/koma-sources/actions/runs/40878834593"
      ]
    },
    {
      "id": "about-page-device-validation-20261029",
      "at": "2026-10-29T21:27:58+08:00",
      "title": "关于页更新历史具名设备验证",
      "detail": "197真实发布历史、日志交互与外部发布页已观察；浏览器返回未直接成功，设备恢复和交付仍进行。此时间为登记时间。",
      "itemId": "ABOUT_PAGE_RELEASE_HISTORY_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/about197-validation-94/"
      ]
    },
    {
      "id": "about-page-device-closure-20261029",
      "at": "2026-10-29T21:33:43+08:00",
      "title": "关于页迁移具名路径完成",
      "detail": "真实更新、历史日志、版本交互及发布页打开已核，197原状态恢复；正式提交与CI待核，不称新版本已发布。此时间为登记时间。",
      "itemId": "ABOUT_PAGE_RELEASE_HISTORY_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/about197-validation-94/delivery-findings.json"
      ]
    },
    {
      "id": "tongli-implementation-closure-20261029",
      "at": "2026-10-29T21:38:18+08:00",
      "title": "东立实现故障具名范围已交付",
      "detail": "目录及设置契约、地区限制映射和首页修复已交付；官网授权及正文黑页边界保留。此时间为登记时间。",
      "itemId": "TONGLI_CHAPTERS_SETTINGS_FAILURE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "about-source-pushed-20261029",
      "at": "2026-10-29T21:38:18+08:00",
      "title": "关于页源码已推送",
      "detail": "关于页源码已推，精确CI待核；未tag或发布新版本。此时间为登记时间。",
      "itemId": "ABOUT_PAGE_RELEASE_HISTORY_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "50e5cba93d180f67e348324d302c34e3ee45cedb"
      ]
    },
    {
      "id": "about-ci-success-20261029",
      "at": "2026-10-29T21:43:12+08:00",
      "title": "关于页精确CI成功",
      "detail": "关于页源码精确CI成功，未变版本、未tag或发布；此时间为登记时间。",
      "itemId": "ABOUT_PAGE_RELEASE_HISTORY_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40883358607"
      ]
    },
    {
      "id": "md-en-search-filter-delivered-20261029",
      "at": "2026-10-29T21:56:48+08:00",
      "title": "英文MangaDex搜索筛选具名交付",
      "detail": "公开包真实响应回放与237候选一致；源网页会话及漫画屋待办聚焦仍存在的403，其余未命中范围保边界。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/md-en-7cbc-public/",
        "https://github.com/honjow/koma-sources/actions/runs/40884954501"
      ]
    },
    {
      "id": "translation-source-persistence-validation-20261029",
      "at": "2026-10-29T22:20:44+08:00",
      "title": "翻译源持久化路径补验中",
      "detail": "197普通保存、重入及删除路径进行中，尚无结果；Simply证据纠正为手动完成并重试，不称人工挑战完成。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "translation-source-persistence-verified-20261029",
      "at": "2026-10-29T22:34:34+08:00",
      "title": "翻译源持久化具名验证完成",
      "detail": "197无密钥API/Codex源保存重入删除及原状态恢复已核；真实账户网络未验。两源既有提交精确CI成功。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "translation-completion/translation-source-state197-21/temporary-api-saved-reentered.png",
        "translation-completion/translation-source-state197-21/temporary-codex-saved-reentered.png",
        "https://github.com/honjow/koma-sources/actions/runs/40872000708"
      ]
    },
    {
      "id": "simply-diagnostic-restored-20261029",
      "at": "2026-10-29T23:01:04+08:00",
      "title": "Simply诊断中止并恢复设备",
      "detail": "本轮未发Simply请求，无新网络证据；原包、数据、电源及租约恢复，403仍未解决。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "zero-default-domain-scope-20261029",
      "at": "2026-10-29T23:11:28+08:00",
      "title": "Zero默认域与旧身份范围核清",
      "detail": "默认域发现已交付并具名验证；旧身份在现站映射未知，旧域EOF不证明具体作品映射失败。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/zerobyw237-default015/zerobyw015-old.log"
      ]
    },
    {
      "id": "source-new-user-feedback-20261029",
      "at": "2026-10-29T23:15:21+08:00",
      "title": "登记首页重复及两项源故障反馈",
      "detail": "重开首页结构项，独立登记漫画人拒绝提示和无限动漫作品加载失败；原因均待核，精确反馈时间未知，此为登记时间。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "source-three-feedback-diagnosis-20261029",
      "at": "2026-10-29T23:26:25+08:00",
      "title": "首页重复及源故障定位推进",
      "detail": "首页重复源于榜单包装，离线候选待237；漫画人HTTP200后业务拒绝，无限动漫首页可见、作品失败阶段待核。此时间为登记时间。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "source-home-and-failure-candidates-20261029",
      "at": "2026-10-29T23:58:59+08:00",
      "title": "首页候选及两项源故障推进",
      "detail": "动漫屋与东立候选普通入口已核，嗨皮未连接、Komiic待处理；漫画人游客会话链及无限动漫详情空响应仍待解决，设备恢复中。此时间为登记时间。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/"
      ]
    },
    {
      "id": "source-home-public-and-restored-20261030",
      "at": "2026-10-30T01:02:22+08:00",
      "title": "动漫屋及东立首页修复发布",
      "detail": "两源候选普通路径已核、精确CI及公开合同成功，原包数据及电源恢复；嗨皮与Komiic仍待处理。此时间为登记时间。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-home-e6-public/contracts.jsonl",
        "https://github.com/honjow/koma-sources/actions/runs/40907631439"
      ]
    },
    {
      "id": "komiic-home-manhuaren-candidates-20261030",
      "at": "2026-10-30T01:07:46+08:00",
      "title": "Komiic首页与漫画人候选推进",
      "detail": "Komiic候选已推CI进行中；漫画人修正候选正在237验证，均未冒完成。此时间为登记时间。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/komiic-home-0.1.11.koma",
        "https://github.com/honjow/koma-sources/actions/runs/40918105665"
      ]
    },
    {
      "id": "komiic-home-public-20261030",
      "at": "2026-10-30T01:10:04+08:00",
      "title": "Komiic首页修复正式交付",
      "detail": "精确CI及公开WASM能力合同已核；无新Native或实网列表，嗨皮连接仍待处理。此时间为登记时间。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/komiic-04c-public/contract.json",
        "https://github.com/honjow/koma-sources/actions/runs/40918105665"
      ]
    },
    {
      "id": "manhuaren-guest-candidate-failed-20261030",
      "at": "2026-10-30T01:15:18+08:00",
      "title": "漫画人游客候选设备入口未通过",
      "detail": "候选在建立会话前失败，原因待定位；原包、数据和电源已恢复并释租。此时间为登记时间。",
      "itemId": "MANHUAREN_REQUEST_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuaren-guest-stage-1702/"
      ]
    },
    {
      "id": "manhuaren-cache-and-comicabc-control-20261030",
      "at": "2026-10-30T01:24:25+08:00",
      "title": "漫画人及无限动漫失败阶段收窄",
      "detail": "漫画人候选缓存读取阶段失败；无限动漫同详情桌面返回200空体，原因仍待核。此时间为登记时间。",
      "itemId": "MANHUAREN_REQUEST_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/comicabc-14884-control.headers",
        "/private/tmp/comicabc-14884-control.body"
      ]
    },
    {
      "id": "manhuaren-local-preparation-20261030",
      "at": "2026-10-30T01:34:52+08:00",
      "title": "漫画人本地会话准备阶段通过",
      "detail": "begin、RSA及clock具名成功后abort；游客POST和业务列表未验。无限动漫去Referer仍空体。此时间为登记时间。",
      "itemId": "MANHUAREN_REQUEST_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/comicabc-referer-ab"
      ]
    },
    {
      "id": "manhuaren-candidate-paths-20261030",
      "at": "2026-10-30T01:50:01+08:00",
      "title": "漫画人候选普通路径已通",
      "detail": "237候选列表、搜索、详情及正文具名可见；冷启动及恢复仍进行。此时间为登记时间。",
      "itemId": "MANHUAREN_REQUEST_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuaren-guest-page-image-1740/"
      ]
    },
    {
      "id": "manhuaren-device-restored-20261030",
      "at": "2026-10-30T01:58:57+08:00",
      "title": "漫画人候选实机及恢复完成",
      "detail": "普通列表、搜索、详情、正文和冷启动复用已核，原包数据电源恢复；正式提交及CI待核。此时间为登记时间。",
      "itemId": "MANHUAREN_REQUEST_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuaren-guest-cold-open-1743/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuaren-guest-final-clean-sleep-1747/"
      ]
    },
    {
      "id": "manhuaren-public-comicabc-control-20261030",
      "at": "2026-10-30T02:02:58+08:00",
      "title": "漫画人源公开与无限动漫对照",
      "detail": "漫画人源包公开、App CI进行中；无限动漫另一作品详情及章节正常，指定空体原因未知。此时间为登记时间。",
      "itemId": "MANHUAREN_REQUEST_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/manhuaren-6b8-public/contract.jsonl",
        "/private/tmp/comicabc-referer-ab/control-offline.jsonl"
      ]
    },
    {
      "id": "manhuaren-fix-delivered-20261030",
      "at": "2026-10-30T02:04:01+08:00",
      "title": "漫画人修复具名范围已交付",
      "detail": "普通路径、冷复用及恢复已核，两仓精确CI成功；修复随新版App生效，新版尚未发布。动漫屋、东立与Komiic首页修复已公开，无限动漫指定作品仍空响应。此时间为登记时间。",
      "itemId": "MANHUAREN_REQUEST_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40926490356",
        "https://github.com/honjow/koma-sources/actions/runs/40926531577"
      ]
    },
    {
      "id": "simply-diagnostic-baseline-20261030",
      "at": "2026-10-30T02:19:35+08:00",
      "title": "Simply单次诊断基线已取",
      "detail": "临时诊断包已构建验签，237完成基线；尚未安装或发目标请求。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "db9b0c933509a533767c124a76b518d60cb44e0bbf6be9b0af7eca4ec4b9ac7e"
      ]
    },
    {
      "id": "simply-diagnostic-installed-20261030",
      "at": "2026-10-30T02:28:09+08:00",
      "title": "Simply诊断候选已安装",
      "detail": "诊断宿主及源候选已装并核实体，目标请求尚未发出；本场结束仍须恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "home-structure-happymh-separated-20261030",
      "at": "2026-10-30T02:40:32+08:00",
      "title": "首页结构修复与嗨皮连接故障分开",
      "detail": "重复首页结构按具名已修范围关闭；嗨皮连接失败独立保留未解决，并非连接已修。此时间为登记时间。",
      "itemId": "SOURCE_BROWSE_HOME_STRUCTURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/happymh-search-dns-20261029.json"
      ]
    },
    {
      "id": "source-priority-and-simply-restoration-20261030",
      "at": "2026-10-30T02:58:40+08:00",
      "title": "复杂源问题后置并完成设备恢复",
      "detail": "Simply目标请求未发、原包数据电源已恢复；嗨皮上游已删除且当前域不可用，复杂源问题与能力扩展按用户要求后置。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "translation-scope-and-manhuawu-state-20261030",
      "at": "2026-10-30T03:05:48+08:00",
      "title": "翻译完整范围及漫画屋状态核清",
      "detail": "翻译完整功能差集仍待核，不能仅视为账户扩验；漫画屋run773显示403进入挑战导航，首页403仍未解。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "translation-migration-scope-closed-20261030",
      "at": "2026-10-30T03:12:00+08:00",
      "title": "漫画翻译迁移具名范围交付",
      "detail": "完整参考对照及已有配置、Torii试译和Reader预处理具名验收支持收口；其他服务真实账户网络未验。漫画屋参考身份一次请求仍403。此时间为登记时间。",
      "itemId": "NEXTE_READER_FEATURE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-migration-static-comparison-20261030.json",
        "/private/tmp/manhuawu-ref150-once.headers",
        "/private/tmp/manhuawu-ref150-once.body"
      ]
    },
    {
      "id": "simply-single-diagnostic-ready-20261030",
      "at": "2026-10-30T03:23:36+08:00",
      "title": "Simply单次安全诊断候选已安装",
      "detail": "237原状态基线已取、诊断Host及源候选已安装；目标GET尚未发。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "simply-diagnostic-refresh-restored-20261030",
      "at": "2026-10-30T03:39:04+08:00",
      "title": "Simply刷新对照及设备恢复",
      "detail": "验证页刷新取得完整响应，完成并重试后仍403；缓存不是全部原因，原包数据及电源恢复，原因未知。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "simply-tls-noy-reference-20261030",
      "at": "2026-10-30T04:09:37+08:00",
      "title": "Simply TLS对照与Noy参考范围",
      "detail": "Simply继承请求头已核相同，临时TLS对照准备中；Noy镜像详情及页图兼容未证。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/noyacg-api-mirror-once.headers",
        "/private/tmp/noyacg-api-mirror-once.body",
        "/private/tmp/noyacg-public015-mirror-replay.mjs"
      ]
    },
    {
      "id": "simply-tls-diagnostic-restored-20261030",
      "at": "2026-10-30T04:27:22+08:00",
      "title": "Simply TLS对照及设备恢复",
      "detail": "临时TLS候选未收到HTTP响应，未证明协商或根因；原包、六域及电源恢复并释租，故障仍开放。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-tls-open-1781/",
        "/private/tmp/koma-no-diagnostics.hap"
      ]
    },
    {
      "id": "webtoon-author-notes-baseline-20261030",
      "at": "2026-10-30T04:52:18+08:00",
      "title": "WEBTOON作者附言验收准备",
      "detail": "真实样本和237原状态基线已核，候选准备中，尚未源请求或完成验收。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "webtoon-author-notes-verified-20261030",
      "at": "2026-10-30T05:36:55+08:00",
      "title": "WEBTOON作者附言具名消费已核",
      "detail": "同章开启60/60作者文字、关闭59/59漫画图均已观察；原包及数据恢复中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-settings237-webtoon-notes-last-1805/screen.png",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-settings237-webtoon-notes-false-last-1812/screen.png"
      ]
    },
    {
      "id": "webtoon-author-notes-restored-20261030",
      "at": "2026-10-30T05:49:53+08:00",
      "title": "WEBTOON作者附言设备恢复完成",
      "detail": "原包、六域、电源及租约恢复已核；作者附言具名子范围完成，整体源审计保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-settings237-webtoon-notes-restore-package-1813/run-metadata.json",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-settings237-webtoon-notes-restore-data-1814/run-metadata.json",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/source-settings237-webtoon-notes-restored-1815/run-metadata.json"
      ]
    },
    {
      "id": "fixed949-full-tree-audit-20261030",
      "at": "2026-10-30T05:53:51+08:00",
      "title": "固定参考完整归档核对",
      "detail": "原25项未匹配行暂未找到可确认同站参考；不等同证明绝无上游，整体审计保持开放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json",
        ".hvigor/outputs/user-flow-audit/upstream-settings-reference/keiyoushi-949-reference.tar.gz"
      ]
    },
    {
      "id": "nine-source-name-followup-20261030",
      "at": "2026-10-30T05:56:20+08:00",
      "title": "九源官方名称具名复核",
      "detail": "部分来源支持现名，GoDa官网自称不一，暂保留现名；访问失败及图标未验边界保留。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/nine-source-followup-20261030.json"
      ]
    },
    {
      "id": "xcomic-title-rule-gap-20261030",
      "at": "2026-10-30T05:57:55+08:00",
      "title": "XCOMIC自定义标题规则差集",
      "detail": "简繁源缺参考自定义标题删除规则，正在核正则适配；默认行为保持，尚未实现。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "fixed949-inheritance-audit-20261030",
      "at": "2026-10-30T05:58:53+08:00",
      "title": "固定参考24项继承链复核",
      "detail": "模块及已列继承链未发现普通偏好；外部生成器内部及Native未验，整体审计保持开放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json"
      ]
    },
    {
      "id": "source-settings-34-consumer-audit-20261030",
      "at": "2026-10-30T06:01:06+08:00",
      "title": "34项参考设置消费者复核",
      "detail": "MangaDex、包子和漫小肆有具体待核差异；其他具名消费者及边界见原矩阵。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json"
      ]
    },
    {
      "id": "xcomic-dedup-group-implementation-20261030",
      "at": "2026-10-30T06:01:48+08:00",
      "title": "XCOMIC去重及分组设置实现中",
      "detail": "简繁分别保现有去重默认，分组默认关闭；尚未构建或设备验收。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "xcomic-dedup-merge-counterexample-20261030",
      "at": "2026-10-30T06:10:50+08:00",
      "title": "XCOMIC旧库去重反例及MangaDex适配",
      "detail": "旧库合并会保留重复章，本轮先交版本分组；MangaDex候选仅受控回放，真实不可用章与Native未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "xcomic-group-candidate-built-20261030",
      "at": "2026-10-30T06:12:19+08:00",
      "title": "XCOMIC版本分组候选已构建",
      "detail": "简繁默认回放保持，显式分组保ID；Native及公开未核，去重字段未提交。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/xcomic-dedup-group-candidate.diff"
      ]
    },
    {
      "id": "mangadex-unavailable-candidate-20261030",
      "at": "2026-10-30T06:23:56+08:00",
      "title": "MangaDex不可用章适配本地提交",
      "detail": "生产WASM及Host合并受控验证已核，真实feed无不可用章、Native未验；XCOMIC分组设备验收进行。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "d739904"
      ]
    },
    {
      "id": "xcomic-group-device-verified-20261030",
      "at": "2026-10-30T06:41:51+08:00",
      "title": "XCOMIC简中分组具名回验",
      "detail": "设置重入及真实章节分组已核，原包数据电源恢复；源CI进行中，繁中Native及去重/正则差集未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/",
        "https://github.com/honjow/koma-sources/actions/runs/40967606642"
      ]
    },
    {
      "id": "source-settings-three-commits-pushed-20261030",
      "at": "2026-10-30T06:41:58+08:00",
      "title": "三源设置提交已推",
      "detail": "XCOMIC简中分组具名验证及恢复已核；三源提交已推、精确CI进行中，其他差异保持开放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-settings-final-20261030-ci.json"
      ]
    },
    {
      "id": "xcomic-multiroot-counterexample-20261030",
      "at": "2026-10-30T06:49:33+08:00",
      "title": "XCOMIC去重查询既有反例",
      "detail": "已存多根查询被拒；单根双查询需分页及保留章处理，去重差集仍未完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-probe-batching/five-original-fields-one-request-request.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-probe-batching/five-original-fields-one-request-response.json"
      ]
    },
    {
      "id": "goda-official-brand-evidence-20261030",
      "at": "2026-10-30T06:51:21+08:00",
      "title": "GoDa官网品牌名称具名核对",
      "detail": "官网页头直接使用GoDa漫畫，支持现名；同页其他称法并存，不改图标。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/goda-identity/koma-goda-home.html"
      ]
    },
    {
      "id": "source-settings-ci-success-20261030",
      "at": "2026-10-30T06:52:11+08:00",
      "title": "源设置提交精确CI成功",
      "detail": "精确CI及原子发布步骤成功，公开实体核验中；XCOMIC去重实现尚未构建或验收。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/40967606642"
      ]
    },
    {
      "id": "source-settings-five-packages-public-20261030",
      "at": "2026-10-30T06:54:04+08:00",
      "title": "五个源设置公开包身份已核",
      "detail": "MangaDex三语言及XCOMIC两语言公开实体与索引摘要一致；公开WASM不同候选，ABI核验中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-settings-final-20261030-ci-complete.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-settings-published-5c1f378/entity-check.json"
      ]
    },
    {
      "id": "source-settings-public-abi-20261030",
      "at": "2026-10-30T06:54:19+08:00",
      "title": "五个公开包设置ABI已核",
      "detail": "MD三语言及XCOMIC简繁默认设置schema已执行，get_settings零HTTP；不外推feed或公开包Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-settings-published-5c1f378/abi-results.json"
      ]
    },
    {
      "id": "xcomic-dedup-single-root-403-20261030",
      "at": "2026-10-30T07:02:26+08:00",
      "title": "XCOMIC去重真实请求遇403",
      "detail": "metadata单次200，uniqList首页单次403后停止，fullList未请求；真实去重及Native未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-dedup-real-single-roots/"
      ]
    },
    {
      "id": "xcomic-single-root-identity-correction-20261030",
      "at": "2026-10-30T07:04:49+08:00",
      "title": "XCOMIC单根403请求口径纠正",
      "detail": "Mac匿名精简查询不等同源完整Native请求；候选改用完整查询模板并完成受控回放，真实去重仍未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "xcomic-dedup-native-start-20261030",
      "at": "2026-10-30T07:10:56+08:00",
      "title": "XCOMIC简中去重候选设备验收",
      "detail": "完整单根候选已构建及受控回放，237原状态基线已取，普通导入进行中；尚未验收完成。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "xcomic-dedup-native-restored-20261030",
      "at": "2026-10-30T07:28:16+08:00",
      "title": "XCOMIC去重候选具名请求及恢复",
      "detail": "受控合并及简中默认请求已核；未命中自然重复，繁中Native未验，候选交付待审。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-dedup-wasm-native-20261030.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-dedup-wasm-host-exec-20261030.mjs"
      ]
    },
    {
      "id": "xcomic-dedup-pushed-20261030",
      "at": "2026-10-30T07:35:56+08:00",
      "title": "XCOMIC去重提交已推",
      "detail": "去重提交已推，精确CI进行中、公开实体待核；此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/40974179677"
      ]
    },
    {
      "id": "xcomic-dedup-public-delivery-20261030",
      "at": "2026-10-30T07:38:41+08:00",
      "title": "XCOMIC去重公开交付",
      "detail": "精确CI、公开包身份及设置ABI已核；既有设备验收范围保持，整体源审计继续。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-dedup-published-f306a8f/release-ci-metadata.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-dedup-published-f306a8f/entity-check.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-dedup-published-f306a8f/abi-results.json"
      ]
    },
    {
      "id": "source-settings-three-contract-boundaries-20261030",
      "at": "2026-10-30T07:40:23+08:00",
      "title": "源设置三项合同边界核清",
      "detail": "包子章身份及横幅需兼容方案；Java正则存在实测差异；漫小肆备域候选需用户决定，尚未采用。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/java-regex-contract-20261030/result.txt",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/mangaxiaosi-mirror-20261030/evidence.json"
      ]
    },
    {
      "id": "official-name-coverage-85-20261030",
      "at": "2026-10-30T07:43:21+08:00",
      "title": "85源名称证据覆盖盘点",
      "detail": "70项有品牌或栏目依据、7项仅英文参考、8项官方中文名称或对应关系未知；图标不在该计数内。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json"
      ]
    },
    {
      "id": "xcomic-teavm-regex-assessment-20261030",
      "at": "2026-10-30T07:49:08+08:00",
      "title": "XCOMIC正则候选运行时依赖核对",
      "detail": "TeaVM现有WasmGC路线依赖与当前WAMR配置不兼容，未改生产运行时。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-teavm-regex-20261030/assessment.md"
      ]
    },
    {
      "id": "comicabc-address-flow-audit-20261030",
      "at": "2026-10-30T07:49:08+08:00",
      "title": "无限动漫详情地址流程已核",
      "detail": "生产搜索归一地址与固定参考及当前详情一致；既有空体未重发，等待可区分原因的新材料。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/comicabc-14884-control.headers",
        "/private/tmp/comicabc-14884-control.body",
        "/private/tmp/comicabc-referer-ab/control-offline.jsonl"
      ]
    },
    {
      "id": "source-share-implementation-start-20261030",
      "at": "2026-10-30T08:00:00+08:00",
      "title": "已安装源包系统分享实施准备",
      "detail": "正在读取现有源包及系统分享实现，尚未修改或验收；包子身份映射证据已补原审计。此时间为登记时间。",
      "itemId": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "source-share-candidate-built-20261030",
      "at": "2026-10-30T08:20:01+08:00",
      "title": "源包系统分享候选构建完成",
      "detail": "正常源包与恢复包导出路径已实现，237普通系统分享及恢复仍待验证。此时间为登记时间。",
      "itemId": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-share/source-share-build-typed-manifest.log"
      ]
    },
    {
      "id": "source-share-restored-extension-counterexample-20261030",
      "at": "2026-10-30T08:34:21+08:00",
      "title": "源包分享恢复包扩展名反例",
      "detail": "普通包具名通过；恢复包发现自动追加.zip，修正候选正在复验。此时间为登记时间。",
      "itemId": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "source-share-native-restored-20261030",
      "at": "2026-10-30T08:50:01+08:00",
      "title": "源包分享具名路径验证及恢复",
      "detail": "普通及恢复包分享、恢复包重新导入具名通过，原数据和设备恢复；源码交付CI待核。此时间为登记时间。",
      "itemId": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-share/evidence.json"
      ]
    },
    {
      "id": "source-share-pushed-20261030",
      "at": "2026-10-30T08:51:45+08:00",
      "title": "源包分享源码已推",
      "detail": "具名设备路径及恢复已核，源码已推；精确CI待核，未tag或AGC。此时间为登记时间。",
      "itemId": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-share/evidence.json"
      ]
    },
    {
      "id": "source-share-ci-closed-20261030",
      "at": "2026-10-30T08:55:53+08:00",
      "title": "源包系统分享具名范围交付",
      "detail": "普通及恢复包设备路径、源码及精确CI已核；本次未tag或发布。此时间为登记时间。",
      "itemId": "SOURCE_SHARE_INSTALLED_PACKAGE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-share/ci-ae693048.json"
      ]
    },
    {
      "id": "soc-official-name-verified-20261030",
      "at": "2026-10-30T09:00:00+08:00",
      "title": "铃兰官方名称依据补全",
      "detail": "官方作品与论坛漫画栏目支持现名，未知项由8减为7；图标及逐篇作者未验。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/soc-official-name-20261030.json"
      ]
    },
    {
      "id": "baozi-banner-adaptation-preparation-20261030",
      "at": "2026-10-30T09:00:00+08:00",
      "title": "包子横幅处理候选准备",
      "detail": "已有派生处理复用接点，保原下载字节及旧Host兼容；候选未采用、默认及真实正样本未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "baozi-banner-local-candidate-20261030",
      "at": "2026-10-30T09:17:30+08:00",
      "title": "包子横幅本地候选已构建",
      "detail": "候选执行证据已核，默认选择待答，真实正例及Native未验，尚未提交推送。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/baozi-banner-candidate-20261030/evidence.json"
      ]
    },
    {
      "id": "teavm-nongc-regex-probe-20261030",
      "at": "2026-10-30T09:19:57+08:00",
      "title": "TeaVM旧非GC正则单例核对",
      "detail": "0.13.1非GC单例与Java一致，但生成物ABI不可直接用于当前宿主；完整兼容未证。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-teavm-regex-20261030/assessment.md"
      ]
    },
    {
      "id": "baozi-banner-default-enabled-20261030",
      "at": "2026-10-30T09:27:36+08:00",
      "title": "包子横幅采用默认开启",
      "detail": "用户明确默认开启；候选已调整并构建，237验收准备中、尚未通过。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/baozi-banner237.protocol.json"
      ]
    },
    {
      "id": "baozi-banner-settings-persisted-20261030",
      "at": "2026-10-30T09:55:33+08:00",
      "title": "包子横幅默认及禁用持久化具名通过",
      "detail": "普通默认、禁用保存及重入已核；正文处理未验，设备及缓存偏好恢复仍在进行。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-baozi-banner/default-normal-settings-014/"
      ]
    },
    {
      "id": "baozi-banner-public-contract-20261030",
      "at": "2026-10-30T10:22:28+08:00",
      "title": "包子横幅公开源合同及受控正例",
      "detail": "公开源设置合同与受控合成正例已核；自然站点正例未验，设备恢复中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/baozimh-5b879-public/",
        "https://github.com/honjow/koma-sources/actions/runs/40990993643"
      ]
    },
    {
      "id": "baozi-banner-native-share-restored-20261030",
      "at": "2026-10-30T10:48:32+08:00",
      "title": "包子横幅受控Native及分享一致性",
      "detail": "默认/禁用设置、受控正文裁边及分享副本一致已核，原状态恢复；App正式交付待核，自然站点正例未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-baozi-banner/"
      ]
    },
    {
      "id": "baozi-banner-app-local-commit-20261030",
      "at": "2026-10-30T10:49:42+08:00",
      "title": "包子横幅App scoped本地提交",
      "detail": "App源码及依赖pin已本地提交，推送和精确CI待核；此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/baozi-banner-candidate-20261030/evidence.json"
      ]
    },
    {
      "id": "baozi-banner-host-delivery-20261030",
      "at": "2026-10-30T10:55:52+08:00",
      "title": "包子横幅受控范围正式交付",
      "detail": "Host及依赖已推、精确CI成功，受控Native及恢复已核；自然站点正例与相册保存未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40993971192",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/baozimh-chapter-order-identity-20261030.md"
      ]
    },
    {
      "id": "baozi-chapter-identity-user-decision-20261030",
      "at": "2026-10-30T11:08:25+08:00",
      "title": "包子章节身份歧义处理决定",
      "detail": "用户决定保旧目录及进度并让本次刷新失败；Host及源候选实现中，尚未构建或Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "baozi-official-name-supported-20261030",
      "at": "2026-10-30T11:08:25+08:00",
      "title": "包子名称依据具名补全",
      "detail": "同注册域索引与固定参考支持现名，未知由7减为6；www未直读及繁体来源边界保留。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/baozimh-official-name-20261030.json"
      ]
    },
    {
      "id": "baozi-chapter-identity-native-start-20261030",
      "at": "2026-10-30T11:17:56+08:00",
      "title": "包子章节身份候选设备验证中",
      "detail": "Host失败回退及源受控合同已核，候选已构建，237普通设置路径仍在验证与恢复前阶段。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "baozi-chapter-order-native-progress-20261030",
      "at": "2026-10-30T11:35:39+08:00",
      "title": "包子章节身份普通路径具名验证",
      "detail": "设置保存重入及真实刷新已核，旧库章节和读态保持；续读、恢复与正式交付进行中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "baozi-chapter-order-restored-20261030",
      "at": "2026-10-30T11:42:41+08:00",
      "title": "包子章节身份具名验证及恢复",
      "detail": "设置、刷新与原章续读已核，设备恢复；源正式CI成功，Host交付待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/baozimh-chapter-order-016/evidence.json",
        "https://github.com/honjow/koma-sources/actions/runs/40998231797"
      ]
    },
    {
      "id": "baozi-chapter-order-host-delivered-20261030",
      "at": "2026-10-30T11:52:14+08:00",
      "title": "包子章节身份Host正式交付",
      "detail": "Host与工作单已推且精确CI成功，既有具名Native及恢复范围保持；整体源设置审计仍开放。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/40999264229"
      ]
    },
    {
      "id": "reader-swipe-user-reopen-20261030",
      "at": "2026-10-30T12:08:17+08:00",
      "title": "用户反馈LTR/RTL滑动方向仍不正确",
      "detail": "重开原事项，实际手势映射待定位；原验收证据保留，此时间为登记时间。",
      "itemId": "READER_SWIPE_DIRECTION_MISMATCH",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "reader-chapter-direction-preload-correction-20261030",
      "at": "2026-10-30T12:12:54+08:00",
      "title": "用户纠正跨章节方向并反馈预载",
      "detail": "反馈指上一章/下一章，目录倒序不得翻转阅读顺序；原跨章预载事项重开，均待定位。此时间为登记时间。",
      "itemId": "READER_SWIPE_DIRECTION_MISMATCH",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "llm-rules-parked-20261030",
      "at": "2026-10-30T12:18:09+08:00",
      "title": "大模型规则增强登记并暂缓",
      "detail": "用户提出后期增强并明确当前不马上实施；此时间为登记时间。",
      "itemId": "LLM_SOURCE_MANGA_RULE_ASSISTANCE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "reader-source-order-candidate-20261030",
      "at": "2026-10-30T12:24:38+08:00",
      "title": "跨章顺序与预载宿主缺口候选",
      "detail": "无续读序列时的顺序及预载缺口已执行复现并构建候选，197漫画160普通路径仍在验收。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/boundary-original-continue-302/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/boundary-original-rtl-forward-303/"
      ]
    },
    {
      "id": "manhuaren-version-gate-feedback-20261030",
      "at": "2026-10-30T12:35:40+08:00",
      "title": "漫画人源码构建版本门槛反馈",
      "detail": "当前源码App版本与源最低版本不一致，用户实际安装包未读取；跨章候选需从完整源目录持久阅读序号。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "source-catalog-reading-order-candidate-20261030",
      "at": "2026-10-30T12:43:12+08:00",
      "title": "完整源目录阅读序号候选",
      "detail": "候选构建及关键回归通过，漫画160设备路径遇网络错误，尚未验收；设备会话仍进行。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "reader-ordinal-candidate-installed-20261030",
      "at": "2026-10-30T12:52:44+08:00",
      "title": "跨章候选设备验证推进",
      "detail": "共享邻接修复已推，0.1.4候选已安装验证无组源目录；漫画160部分封面及正文可见，尚未全部确认。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "mh160-cover-candidate-restored-20261030",
      "at": "2026-10-30T12:53:20+08:00",
      "title": "漫画160封面候选及设备恢复",
      "detail": "候选部分封面与正文可见，仍有一项占位原因未明；原包数据及电源恢复。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/"
      ]
    },
    {
      "id": "mh160-image-association-restore-20261030",
      "at": "2026-10-30T13:04:39+08:00",
      "title": "漫画160剩余占位请求关联",
      "detail": "一项占位关联图片请求错误、未有HTTP响应；数据及源包恢复，原HAP降级被拒，设备保留0.1.4候选。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "mh160-header-public-20261030",
      "at": "2026-10-30T13:12:57+08:00",
      "title": "漫画160图片请求头修复公开",
      "detail": "公开WASM合同已核，候选设备部分图片通过；具体一图超时及公开包Native边界保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/mh160-db1-public/wasm-contract.json",
        "https://github.com/honjow/koma-sources/actions/runs/41005769688"
      ]
    },
    {
      "id": "xkcd-chronology-native-progress-20261030",
      "at": "2026-10-30T13:29:28+08:00",
      "title": "xkcd真实跨章预载及滑动",
      "detail": "197未来页预载及RTL/LTR跨章滑动具名已核；点击原片与设备恢复仍待，原tap区域反转配置已确认。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/reader-continuation/xkcd-rtl-chronology-motion-326/"
      ]
    },
    {
      "id": "source-chapter-order-candidates-20261030",
      "at": "2026-10-30T13:31:13+08:00",
      "title": "书源章节顺序候选核对",
      "detail": "多源章序候选已有参考和受控回放；部分组织身份仍不明确，候选未发布或设备验收。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "mh160-cover-cross-client-timeout-20261030",
      "at": "2026-10-30T13:41:27+08:00",
      "title": "漫画160具名封面跨客户端对照",
      "detail": "同一公开封面URL本次跨客户端超时，未有HTTP响应；原因未知，不外推全站。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/mh160-11140-image-url.txt",
        "/private/tmp/mh160-11140-control/"
      ]
    },
    {
      "id": "xkcd-click-motion-restored-20261030",
      "at": "2026-10-30T13:41:39+08:00",
      "title": "xkcd点击跨章及设备恢复",
      "detail": "197点击原片已核、原数据电源恢复；App版本一致性CI失败已定位补修，新CI及源CI待核。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41009239020",
        "https://github.com/honjow/koma-sources/actions/runs/41009585265"
      ]
    },
    {
      "id": "source-order-fourteen-public-20261030",
      "at": "2026-10-30T13:42:06+08:00",
      "title": "14源章节顺序正式交付",
      "detail": "精确CI及正式包身份已核，未冒全部源Native；其余候选与未知范围保留。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-order-published-04fa4a9/identity.json",
        "https://github.com/honjow/koma-sources/actions/runs/41009585265"
      ]
    },
    {
      "id": "reader-chronology-ci-closed-20261030",
      "at": "2026-10-30T13:47:21+08:00",
      "title": "跨章具名路径正式交付",
      "detail": "197预载、滑动和点击具名验证及两仓精确CI完成；未核分组源保留。此时间为登记时间。",
      "itemId": "AUTO_CHAPTER_BOUNDARY_TARGET",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41009792919",
        "https://github.com/honjow/koma-sources/actions/runs/41009585265"
      ]
    },
    {
      "id": "six-source-continuation-public-20261030",
      "at": "2026-10-30T13:51:24+08:00",
      "title": "六源续读合同正式发布",
      "detail": "精确CI及公开包执行已核，未冒Native，多组未知范围保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-chapter-contract-public-1f119ef/identity.json",
        "https://github.com/honjow/koma-sources/actions/runs/41010435758"
      ]
    },
    {
      "id": "xcomic-regex-runtime-adaptation-20261030",
      "at": "2026-10-30T13:58:56+08:00",
      "title": "XCOMIC标题规则执行链适配",
      "detail": "20源章序公开交付已核；静态ICU及既有Worker RPC适配候选尚未实现、构建或Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "xcomic-icu-candidate-built-20261030",
      "at": "2026-10-30T14:08:46+08:00",
      "title": "XCOMIC正则候选已构建",
      "detail": "静态ICU及异步执行候选已构建，正在缩减包体；未设备验收或正式交付。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "xcomic-regex-native-candidate-20261030",
      "at": "2026-10-30T14:44:10+08:00",
      "title": "XCOMIC正则候选具名设备验证",
      "detail": "非法输入拦截、有效规则保存重入及真实标题消费已核，原状态恢复；候选未交付、API23 Native未验。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/"
      ]
    },
    {
      "id": "xcomic-regex-release-candidate-20261030",
      "at": "2026-10-30T14:49:11+08:00",
      "title": "XCOMIC正则简繁发布候选构建",
      "detail": "简繁候选旧Host兼容及受控执行已核；设备仅先前简中候选，未提交推送。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-icu74/release-candidates/contract-result.json",
        "/private/tmp/koma-icu74/release-regex-results.txt"
      ]
    },
    {
      "id": "icu-linux-ci-failure-20261030",
      "at": "2026-10-30T14:59:29+08:00",
      "title": "ICU Linux构建依赖补充",
      "detail": "两次CI在host configure失败，补充构建工具及诊断后待新CI；源候选尚未推送。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41016110323",
        "https://github.com/honjow/Koma/actions/runs/41016751992"
      ]
    },
    {
      "id": "xcomic-regex-source-public-20261030",
      "at": "2026-10-30T15:12:59+08:00",
      "title": "XCOMIC规则及爱看漫章序源包公开",
      "detail": "三包公开身份及WASM合同已核；公开实体未另Native，Host交付状态待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/koma-source-public-c4b04e9/identity.json",
        "/private/tmp/koma-source-public-c4b04e9/contract-equality.json",
        "https://github.com/honjow/koma-sources/actions/runs/41018356180"
      ]
    },
    {
      "id": "simply-499-challenge-header-evidence-20261030",
      "at": "2026-10-30T15:21:05+08:00",
      "title": "Simply既有挑战响应头证据",
      "detail": "旧场景403具有响应头挑战特征；不同请求身份及后续场景线路头仍未知，故障未解决。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-ua-log-499/app.log"
      ]
    },
    {
      "id": "icu-host-ci-and-simply-diagnostic-20261030",
      "at": "2026-10-30T15:28:45+08:00",
      "title": "ICU Host CI成功及Simply具名诊断",
      "detail": "Linux ICU工具链精确CI成功，正式源包证据已固化；Simply最小诊断进行中，结果待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41017177110",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/xcomic-ikmmh-published-c4b04e9/"
      ]
    },
    {
      "id": "source-audit-stale-actions-corrected-20261030",
      "at": "2026-10-30T15:29:44+08:00",
      "title": "已交付源设置待办纠正",
      "detail": "XCOMIC正则及漫画人源码版本门槛已交付，保历史与用户实际安装版本未知边界；继续其他具名差异。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "simply-cause-ua-native-20261030",
      "at": "2026-10-30T15:35:34+08:00",
      "title": "Simply同场对象UA对照",
      "detail": "原请求与probe均挑战403、对象UA一致；线路身份未知，原状态恢复并释租。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-cause-ua-open-20261030-008/"
      ]
    },
    {
      "id": "noyacg-adult-candidate-20261030",
      "at": "2026-10-30T15:44:07+08:00",
      "title": "NoyAcg成人范围设置隔离提交",
      "detail": "默认请求及显式值受控消费已核，推送、CI及公开待核；未冒站点效果或Native。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/noyacg-adult-016/evidence.json"
      ]
    },
    {
      "id": "noyacg-adult-public-20261030",
      "at": "2026-10-30T15:53:29+08:00",
      "title": "NoyAcg成人范围设置公开交付",
      "detail": "公开源包及受控合同已核；漫画屋因果关联候选准备设备验证。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/noyacg-adult-published-b854577/evidence.json",
        "https://github.com/honjow/koma-sources/actions/runs/41021822880"
      ]
    },
    {
      "id": "mh160-cover-feedback-recorded-20261030",
      "at": "2026-10-30T16:05:30+08:00",
      "title": "漫画160封面反馈独立登记",
      "detail": "请求头修复已交付，单张独立超时仍保边界；漫画屋候选仍要求验证并已恢复。此时间为登记时间。",
      "itemId": "MH160_COVER_IMAGES_REJECTED",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/41005769688"
      ]
    },
    {
      "id": "source-challenge-cause-public-20261030",
      "at": "2026-10-30T16:12:43+08:00",
      "title": "两源验证因果接线正式交付",
      "detail": "漫画屋及Simply正式包与WASM合同已核，实际可用性仍开放；漫小肆具体选择已提出待答。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-challenge-cause-published-f624c85/evidence.json",
        "https://github.com/honjow/koma-sources/actions/runs/41024411724"
      ]
    },
    {
      "id": "onmyoji-name-evidence-gap-20261030",
      "at": "2026-10-30T16:18:29+08:00",
      "title": "阴阳师官方名称原始依据复核",
      "detail": "旧父页关联原件不存在，本次新父页不可读取；名称保持未知，未重试旧漫画页。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "mangaxiaosi-mirror-user-approved-20261030",
      "at": "2026-10-30T16:27:13+08:00",
      "title": "漫小肆完整镜像修复已采用",
      "detail": "用户明确采用两参考镜像及精确备用正文域，原默认和身份边界保持；候选实施中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "mangaxiaosi-mirror-settings-native-20261030",
      "at": "2026-10-30T16:33:52+08:00",
      "title": "漫小肆镜像设置保存重入",
      "detail": "备用镜像值及普通重入已核；正文与设备恢复仍进行。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/mxs-mirror-save-20261030-012/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/mxs-mirror-reentry-20261030-013/"
      ]
    },
    {
      "id": "mangaxiaosi-mirror-native-restored-20261030",
      "at": "2026-10-30T16:39:01+08:00",
      "title": "漫小肆备用镜像具名路径及恢复",
      "detail": "设置、目录与此前0页章节首屏已观察，原状态恢复；源交付待核，缓存/HTTP归属未区分。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/mangaxiaosi-mirror-20261030/candidate-016/evidence.json"
      ]
    },
    {
      "id": "mangaxiaosi-mirror-public-20261030",
      "at": "2026-10-30T16:43:08+08:00",
      "title": "漫小肆镜像修复正式交付",
      "detail": "精确CI、公开实体及真实HTML回放已核，具名设备范围保持；整体审计继续。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/mangaxiaosi-mirror-published-a1e6d6e/evidence.json",
        "https://github.com/honjow/koma-sources/actions/runs/41027778858"
      ]
    },
    {
      "id": "noy-mangabz-mirror-reference-20261030",
      "at": "2026-10-30T16:49:33+08:00",
      "title": "Noy及MangaBz参考镜像差异",
      "detail": "生成器确有普通镜像偏好；Noy缺可验证作品材料，MangaBz备域身份及cookie配套核对中。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/noyacg-reference-mirror-20261030/evidence.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/mangabz-reference-mirror-20261030/evidence.json"
      ]
    },
    {
      "id": "app-release-readiness-014-20261030",
      "at": "2026-10-30T17:02:48+08:00",
      "title": "App 0.1.4发版准备核验",
      "detail": "当前代码对应成功CI，Release HAP元数据、架构及发布检查已核；更新日志待提交，未tag、发布或上传AGC。源问题继续保留。此时间为登记时间。",
      "itemId": "SYNC",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/release-readiness-0.1.4/evidence.json",
        "https://github.com/honjow/Koma/actions/runs/41017177110"
      ]
    },
    {
      "id": "release-notes-014-committed-20261030",
      "at": "2026-10-30T17:05:26+08:00",
      "title": "0.1.4更新日志已提交",
      "detail": "分类更新日志已本地提交，App发布准备已核；尚未tag、发布或上传AGC。此时间为登记时间。",
      "itemId": "SYNC",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/release-readiness-0.1.4/evidence.json",
        "1585f2c7"
      ]
    },
    {
      "id": "release-014-workflow-started-20261030",
      "at": "2026-10-30T18:18:42+08:00",
      "title": "正式0.1.4发布工作流已启动",
      "detail": "用户明确授权发版；正式tag已推，工作流进行中，发布结果尚未确认，本次不上传AGC。此时间为登记时间。",
      "itemId": "SYNC",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41039749491"
      ]
    },
    {
      "id": "mangabz-mirror-user-adopted-20261030",
      "at": "2026-10-30T18:21:58+08:00",
      "title": "MangaBz完整镜像切换已采用",
      "detail": "用户明确采用三站切换，原默认和进度保持；源与宿主接入实施中，不影响冻结发布标签。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "release-014-published-20261030",
      "at": "2026-10-30T18:26:26+08:00",
      "title": "正式0.1.4发布并核验",
      "detail": "Release及下载产物、正文已核；为unsigned，未上传AGC，源事项继续。此时间为登记时间。",
      "itemId": "SYNC",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/release-readiness-0.1.4/evidence.json",
        "https://github.com/honjow/Koma/releases/tag/v0.1.4",
        "https://github.com/honjow/Koma/actions/runs/41039749491"
      ]
    },
    {
      "id": "mangabz-mirror-settings-native-20261030",
      "at": "2026-10-30T18:34:39+08:00",
      "title": "MangaBz镜像设置保存重入",
      "detail": "默认、三站选项及备用站保存重入已核；旧作品正文和设备恢复仍进行。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/mangabz-mirror-settings-20261030-009/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/mangabz-mirror-choices-20261030-010/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/category-membership/mangabz-mirror-select-x-20261030-011/"
      ]
    },
    {
      "id": "mangabz-mirror-native-restored-20261030",
      "at": "2026-10-30T18:43:47+08:00",
      "title": "MangaBz镜像候选具名验证及恢复",
      "detail": "设置、旧作品及正文具名已核，原状态恢复；Host与源正式交付待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/mangabz-mirror-candidate-20261030/evidence.json"
      ]
    },
    {
      "id": "mangabz-mirror-pushed-20261030",
      "at": "2026-10-30T18:45:33+08:00",
      "title": "MangaBz镜像两仓提交已推",
      "detail": "具名设备路径已核，两仓精确CI进行中、源实体待核。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41042962997",
        "https://github.com/honjow/koma-sources/actions/runs/41042955770"
      ]
    },
    {
      "id": "mangabz-mirror-public-delivery-20261030",
      "at": "2026-10-30T18:52:25+08:00",
      "title": "MangaBz完整镜像正式交付",
      "detail": "两仓精确CI及公开WASM合同已核；旧0.1.4 Host仅默认站，Noy继续等待真实材料。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/mangabz-mirror-candidate-20261030/evidence.json",
        "https://github.com/honjow/Koma/actions/runs/41042962997",
        "https://github.com/honjow/koma-sources/actions/runs/41042955770"
      ]
    },
    {
      "id": "source-repair-resumed-20261030",
      "at": "2026-10-30T19:04:40+08:00",
      "title": "源故障修复继续推进",
      "detail": "Noy作品链接及验证页公开头差异已有候选；候选尚未设备验证，其他源故障保持开放。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "noy-session-and-simply-cdp-20261030",
      "at": "2026-10-30T19:41:05+08:00",
      "title": "Noy登录入口与Simply线路证据",
      "detail": "Noy同站登录入口具名已核、正式CI待核；Simply同场Web与Native结果不同，单变量对照继续。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-cdp-20261030/evidence.json",
        "https://github.com/honjow/koma-sources/actions/runs/41049335130"
      ]
    },
    {
      "id": "noy-public-simply-origin-ab-20261030",
      "at": "2026-10-30T19:59:15+08:00",
      "title": "Noy入口公开及Simply Origin对照",
      "detail": "Noy登录入口公开，登录后内容未验；Simply原样/去Origin均403，设备已恢复，网络路径对照继续。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/koma-sources/actions/runs/41049335130"
      ]
    },
    {
      "id": "simply-197-network-comparison-baseline-20261030",
      "at": "2026-10-30T20:05:04+08:00",
      "title": "Simply 197网络对照基线",
      "detail": "197已唤醒备份、候选尚未安装；237已恢复供用户登录，原恢复包证据及设备读取限制保留。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "/private/tmp/Koma-chapter-014-38d245.hap"
      ]
    },
    {
      "id": "noy-search-simply-network-ab-20261030",
      "at": "2026-10-30T20:10:10+08:00",
      "title": "Noy搜索修复及Simply网络对照",
      "detail": "Noy转义修复已公开；197两种网络路径均遇挑战403，原状态恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-network-ab197-20261030/evidence.json",
        "https://github.com/honjow/koma-sources/actions/runs/41052932223"
      ]
    },
    {
      "id": "comicabc-official-alias-check-20261030",
      "at": "2026-10-30T20:14:24+08:00",
      "title": "古见官方别名路径对照",
      "detail": "官方别名自动跳回原路径且仍为空正文，原因未知，不推断下架。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-official-alias-20261030/evidence.json"
      ]
    },
    {
      "id": "manhuawu-latest-reference-20261030",
      "at": "2026-10-30T20:16:48+08:00",
      "title": "漫画屋最新入口对照",
      "detail": "参考最新入口单次读取仍遇挑战403，首页可用性问题继续定位。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-latest-20261030/"
      ]
    },
    {
      "id": "manhuawu-native-browser-197-20261030",
      "at": "2026-10-30T20:30:36+08:00",
      "title": "漫画屋验证与浏览器路径对照",
      "detail": "原生真人验证后仍未通过；系统浏览器站根可见页面，同热门路径正在对照。前一设备场次已恢复。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manhuawu-browser197-result-20261030-021/layout.json"
      ]
    },
    {
      "id": "manhuawu-same-path-browser-restored-20261030",
      "at": "2026-10-30T20:36:54+08:00",
      "title": "漫画屋同路径浏览器对照与恢复",
      "detail": "浏览器提交同一热门路径可见作品，App验证仍未通过；身份兼容候选待决定，两场设备已恢复。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-validation197-20261030/evidence.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-engine-identity-candidate-20261030/basis.json"
      ]
    },
    {
      "id": "happymh-catalogue-choice-pending-20261030",
      "at": "2026-10-30T20:39:29+08:00",
      "title": "嗨皮安装目录处置待决定",
      "detail": "现用域名无可用解析；已提交撤下可安装入口的具体候选，已装源和书库保留。候选未实施，此时间为登记时间。",
      "itemId": "HAPPYMH_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/happymh-search-dns-20261029.json"
      ]
    },
    {
      "id": "simply-cdp-order-correction-20261030",
      "at": "2026-10-30T20:45:48+08:00",
      "title": "Simply网页与原生请求时序纠正",
      "detail": "既有Web 200出现在先前Cookie读取和probe之后，尚无成功后完成并重试的同状态证据；197正在补核。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-cdp-20261030/evidence.json"
      ]
    },
    {
      "id": "simply-json-complete-retry-20261030",
      "at": "2026-10-30T21:01:48+08:00",
      "title": "Simply显示JSON后重试结果",
      "detail": "验证页显示JSON后一次完成并重试仍403；网页网络及缓存状态未知，前场已恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-cdp-20261030/evidence.json"
      ]
    },
    {
      "id": "simply-cache-revalidation-candidate-20261030",
      "at": "2026-10-30T21:11:25+08:00",
      "title": "Simply缓存重验证及限定候选",
      "detail": "同请求显示200实际为304缓存重验证，原生仍403；限定在线加载候选待实际验证。前场已恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-cdp-20261030/evidence.json"
      ]
    },
    {
      "id": "simply-online-real-response-20261030",
      "at": "2026-10-30T21:22:55+08:00",
      "title": "Simply在线响应对照",
      "detail": "在线响应后原生仍403，限定候选已撤；网络协商对照准备中，前场已恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-online-diagnostic-20261030/evidence.json"
      ]
    },
    {
      "id": "comicabc-browser-blank-197-20261030",
      "at": "2026-10-30T21:22:55+08:00",
      "title": "古见作品浏览器对照",
      "detail": "系统浏览器打开该作品显示空白，最终完整URL及HTTP状态未知。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-online-diagnostic-20261030/evidence.json"
      ]
    },
    {
      "id": "simply-rcp-reference-result-20261030",
      "at": "2026-10-30T21:51:11+08:00",
      "title": "Simply网络协商对照",
      "detail": "受控对照仍遇挑战403，临时代码撤回且设备恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-network-ab197-20261030/rcp-firefox-reference-evidence.json"
      ]
    },
    {
      "id": "official-names-two-verified-20261030",
      "at": "2026-10-30T21:51:11+08:00",
      "title": "官方名称复核",
      "detail": "阴阳师及杂志迷名称有官方页面依据，仍有三项对应关系未知。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json"
      ]
    },
    {
      "id": "comicabc-offline-chapter-id-20261030",
      "at": "2026-10-30T21:51:11+08:00",
      "title": "古见目录离线核对",
      "detail": "搜索材料无章节ID，未发现可证替代官方目录接口。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-official-alias-20261030/evidence.json"
      ]
    },
    {
      "id": "noy-installed-version-correction-20261030",
      "at": "2026-10-30T22:02:20+08:00",
      "title": "Noy设备版本核对",
      "detail": "237仍装旧版，正在通过普通路径补齐已公开版本；设备会话计数不能证明登录失败。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/noy-state237-read-20261030-001/run-metadata.json"
      ]
    },
    {
      "id": "noy-019-device-delivery-20261030",
      "at": "2026-10-30T22:08:56+08:00",
      "title": "Noy正式版本设备交付",
      "detail": "237已安装公开0.1.9并显示登录入口，数据保留且设备恢复；登录后内容尚未验证。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/noyacg-reference-mirror-20261030/search-019/device237-delivery.json"
      ]
    },
    {
      "id": "lol-official-name-20261030",
      "at": "2026-10-30T22:08:56+08:00",
      "title": "英雄联盟栏目名称复核",
      "detail": "官方品牌与同站漫画栏目支持现有描述性名称；其余两项对应关系仍未知。此时间为登记时间。",
      "itemId": "SOURCE_OFFICIAL_CHINESE_NAMES",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/lol-root-official-20261030.json",
        ".hvigor/outputs/user-flow-audit/all85-source-settings-comparison.json"
      ]
    },
    {
      "id": "noy-no-account-decision-20261030",
      "at": "2026-10-30T23:06:32+08:00",
      "title": "Noy账号范围",
      "detail": "用户目前没有账号，登录后内容未验，正式版本保留。此时间为登记时间。",
      "itemId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "happymh-remove-entry-decision-20261030",
      "at": "2026-10-30T23:06:32+08:00",
      "title": "嗨皮入口处置",
      "detail": "用户决定撤下可安装入口，保留已装数据；实施中。此时间为登记时间。",
      "itemId": "HAPPYMH_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "manhuawu-engine-identity-adopted-20261030",
      "at": "2026-10-30T23:06:32+08:00",
      "title": "漫画屋身份候选",
      "detail": "用户采用限定身份候选，237验证中，尚未证明修复。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "happymh-withdrawal-delivered-20261030",
      "at": "2026-10-30T23:34:04+08:00",
      "title": "嗨皮入口撤下已交付",
      "detail": "目录入口撤下已验收，已装源保留，站点仍不可用。此时间为登记时间。",
      "itemId": "HAPPYMH_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/happymh-catalog-withdrawal-20261030/evidence.json"
      ]
    },
    {
      "id": "manhuawu-clearance-still-403-20261030",
      "at": "2026-10-30T23:34:04+08:00",
      "title": "漫画屋验证后仍被拒绝",
      "detail": "候选取得凭据并自动回流，但首页仍403；设备已恢复。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-engine-identity-candidate-20261030/native237-evidence.json"
      ]
    },
    {
      "id": "source-install-pipeline-feedback-20261030",
      "at": "2026-10-30T23:34:04+08:00",
      "title": "多个书源安装效率反馈",
      "detail": "确认在线安装全流程串行，有限并行候选尚未构建及验证。此时间为登记时间。",
      "itemId": "SOURCE_INSTALL_PIPELINE_SERIAL",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "source-install-concurrency-native-20261030",
      "at": "2026-10-30T23:46:26+08:00",
      "title": "书源并行安装实机验证",
      "detail": "两个普通更新已证并行并恢复原数据，代码提交和CI待完成。此时间为登记时间。",
      "itemId": "SOURCE_INSTALL_PIPELINE_SERIAL",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-install-concurrency-20261030/native237-evidence.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-install-concurrency-20261030/verification.json"
      ]
    },
    {
      "id": "source-install-concurrency-delivered-20261031",
      "at": "2026-10-31T00:02:32+08:00",
      "title": "书源并行安装交付",
      "detail": "具名实机验证及正式源码CI完成，原数据已恢复。此时间为登记时间。",
      "itemId": "SOURCE_INSTALL_PIPELINE_SERIAL",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41084355441",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-install-concurrency-20261030/native237-evidence.json"
      ]
    },
    {
      "id": "manhuawu-engine-identity-delivered-20261031",
      "at": "2026-10-31T00:02:32+08:00",
      "title": "漫画屋限定身份代码交付",
      "detail": "限定身份代码已交付，取得凭据后首页仍受挑战，故障继续定位。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41084355441",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/manhuawu-engine-identity-candidate-20261030/native237-evidence.json"
      ]
    },
    {
      "id": "comicabc-reader-script-review-20261031",
      "at": "2026-10-31T00:14:50+08:00",
      "title": "无限动漫官网阅读脚本核对",
      "detail": "官网阅读脚本依赖详情提供的章节ID，未发现独立目录入口；古见问题仍未解决。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/evidence.json"
      ]
    },
    {
      "id": "comicabc-search-original-20261031",
      "at": "2026-10-31T00:55:51+08:00",
      "title": "古见官方搜索原件核对",
      "detail": "正篇仍指向原详情并标示501集，未发现可证的独立目录入口。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/search-body.html",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/global.js"
      ]
    },
    {
      "id": "simply-same-scene-237-20261031",
      "at": "2026-10-31T00:59:38+08:00",
      "title": "Simply同场网页与原生对照",
      "detail": "同场网页200而原生仍403，设备和数据已恢复；原因未定。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-samescene237-complete-20261031-013/"
      ]
    },
    {
      "id": "simply-matched-peer-20261031",
      "at": "2026-10-31T01:10:02+08:00",
      "title": "Simply同节点对照",
      "detail": "对齐网页实际节点后原生仍403，网页显示200为缓存重验证；设备已恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-peer-dns-20261031/evidence.json"
      ]
    },
    {
      "id": "comicabc-pwa-review-20261031",
      "at": "2026-10-31T01:10:02+08:00",
      "title": "无限动漫页面入口核对",
      "detail": "页面引用的PWA清单无目录或API，详情故障仍未解决。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/evidence.json"
      ]
    },
    {
      "id": "simply-header-profile-20261031",
      "at": "2026-10-31T01:32:30+08:00",
      "title": "Simply公开头对照",
      "detail": "同节点公开头对照及完整导航头候选仍403，候选未采用，前一设备场已恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-header-profile-20261031/evidence.json"
      ]
    },
    {
      "id": "simply-official-route-20261031",
      "at": "2026-10-31T02:00:40+08:00",
      "title": "Simply官网路径与原生挑战",
      "detail": "官网搜索与作品页面可见，原生搜索仍403；设备恢复，兼容库可行性核查中。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-official-route-20261031/evidence.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-official-client-20261031/evidence.json"
      ]
    },
    {
      "id": "simply-ohos-compat-build-20261031",
      "at": "2026-10-31T02:10:03+08:00",
      "title": "Simply兼容库本地构建",
      "detail": "OHOS兼容库已编译，真实原生请求及系统网络配置尚待验证。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-ohos-impersonate-poc/evidence.json"
      ]
    },
    {
      "id": "simply-runtime-first-page-20261031",
      "at": "2026-10-31T02:24:33+08:00",
      "title": "Simply普通路径首屏恢复",
      "detail": "本地Host候选已显示书源首屏，分页、详情、正文及正式交付仍待核。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-runtime237-open-20261031-007/",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-ohos-impersonate-poc/native237/evidence.json"
      ]
    },
    {
      "id": "simply-runtime-chain-search-20261031",
      "at": "2026-10-31T02:37:58+08:00",
      "title": "Simply阅读链路与搜索结果",
      "detail": "候选显示列表、详情和首图；搜索失败、分页未验证，设备已恢复。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-runtime237-reader-20261031-012/screen.png",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-runtime237-search-20261031-017/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-runtime237-restore-20261031-020/",
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-runtime237-final-20261031-021/"
      ]
    },
    {
      "id": "manhuawu-profile-native-list-20261031",
      "at": "2026-10-31T02:53:58+08:00",
      "title": "漫画屋验证后列表恢复",
      "detail": "正常网页验证后原生热门列表可见；设备恢复及正式交付仍在进行。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/manhuawu-profile237-http-20261031-015/"
      ]
    },
    {
      "id": "simply-search-response-failure-20261031",
      "at": "2026-10-31T02:53:58+08:00",
      "title": "Simply搜索失败阶段",
      "detail": "搜索最终HTTP200后源运行失败，具体原因尚未记录；同场继续核对。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-runtime-curl-20261031/evidence.json"
      ]
    },
    {
      "id": "manhuawu-profile-delivered-20261031",
      "at": "2026-10-31T03:11:15+08:00",
      "title": "漫画屋验证后列表恢复并交付",
      "detail": "正常验证后原生热门列表恢复，源码及CI完成；自动回流仍403的边界保留。此时间为登记时间。",
      "itemId": "MANHUAWU_SOURCE_UNAVAILABLE",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41111246354"
      ]
    },
    {
      "id": "simply-png-search-cause-20261031",
      "at": "2026-10-31T03:11:15+08:00",
      "title": "Simply搜索失败原因定位",
      "detail": "搜索数据包含PNG，原后缀白名单拒绝导致整页失败；候选正在验证。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "simply-search-png-native-20261031",
      "at": "2026-10-31T03:14:30+08:00",
      "title": "Simply搜索候选实机验证",
      "detail": "普通搜索结果及封面已显示，正式源交付和设备恢复仍待核。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/simply-fix237-search-screen-20261031-025/"
      ]
    },
    {
      "id": "simply-search-published-page2-20261031",
      "at": "2026-10-31T03:31:25+08:00",
      "title": "Simply搜索修复公开与分页反例",
      "detail": "普通搜索修复已公开；第二页超时及错误分类仍在定位，新场测量中。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-filename-fix-20261031/evidence.json",
        "https://github.com/honjow/koma-sources/actions/runs/41114185742"
      ]
    },
    {
      "id": "simply-worker-admission-native-20261031",
      "at": "2026-10-31T04:12:54+08:00",
      "title": "Simply错误分类交付与调度验证",
      "detail": "源错误分类已公开；封面争用下后续查询具名验证，App提交和CI待核。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-worker-admission-20261031/evidence.json",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/simply-timeout-fix-20261031/public-d83fafd/"
      ]
    },
    {
      "id": "simply-worker-pushed-20261031",
      "at": "2026-10-31T04:13:57+08:00",
      "title": "Simply调度代码推送",
      "detail": "App代码已推送，精确CI尚未完成。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41121496728"
      ]
    },
    {
      "id": "comicabc-upstream-reference-20261031",
      "at": "2026-10-31T04:13:57+08:00",
      "title": "无限动漫上游参考核对",
      "detail": "精确上游对应实现与固定参考相同，未发现新目录入口。此时间为登记时间。",
      "itemId": "WUXIAN_GUJIAN_LOAD_FAILURE",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/comicabc-script-20261031/upstream-reference-1386f490.json"
      ]
    },
    {
      "id": "simply-worker-ci-delivered-20261031",
      "at": "2026-10-31T04:26:30+08:00",
      "title": "Simply具名修复交付",
      "detail": "浏览、搜索及封面争用下查询已验证，App源码和精确CI完成；旧超时原因边界保留。此时间为登记时间。",
      "itemId": "SOURCE_WEB_SESSION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/source-worker-admission-20261031/evidence.json",
        "https://github.com/honjow/Koma/actions/runs/41121496728"
      ]
    },
    {
      "id": "library-cross-source-migration-request-20261031",
      "at": "2026-10-31T05:00:33+08:00",
      "title": "书库漫画跨源迁移需求",
      "detail": "用户要求实现参考应用已有的迁移功能；正在调查，入口及界面尚未采用。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "library-cross-source-migration-adopted-20261031",
      "at": "2026-10-31T05:03:50+08:00",
      "title": "跨源迁移流程已采用",
      "detail": "用户采用详情及多选入口、逐书匹配与可选进度分类、追踪和复制或迁移；实现中。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "library-cross-source-migration-native-start-20261031",
      "at": "2026-10-31T05:31:07+08:00",
      "title": "跨源迁移进入真机验收",
      "detail": "迁移入口及数据链已实现并完成本地执行检查，单本与批量普通路径正在验收。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json",
        "docs/device-protocols/koma-manga-migration-197.json"
      ]
    },
    {
      "id": "library-migration-row-refresh-failure-20261031",
      "at": "2026-10-31T05:40:28+08:00",
      "title": "迁移搜索结果刷新反例",
      "detail": "手动搜索取得真实结果后迁移行未刷新；已定位行状态更新问题，修正正在构建。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-migration/manual-return-018/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-migration/verified-search-017/"
      ]
    },
    {
      "id": "library-migration-single-batch-20261031",
      "at": "2026-10-31T05:52:04+08:00",
      "title": "跨源迁移单本及批量验证",
      "detail": "单本复制、完成进入目标和批量迁移与跳过已具名验证；两个关联显示修正待验。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-migration/copy-result-022/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-migration/batch-move-result-038/"
      ]
    },
    {
      "id": "library-migration-native-restored-20261031",
      "at": "2026-10-31T05:57:39+08:00",
      "title": "跨源迁移设备验收及恢复",
      "detail": "单本、批量及关联显示已验，原数据和电源恢复；源码已推，CI待核。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json"
      ]
    },
    {
      "id": "library-migration-submit-guard-ci-20261031",
      "at": "2026-10-31T06:04:14+08:00",
      "title": "迁移提交保护及最终CI",
      "detail": "提交期间的重试、验证和预览保护已补齐并推送，最终CI运行中。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41135459269",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json"
      ]
    },
    {
      "id": "library-migration-ci-delivered-20261031",
      "at": "2026-10-31T06:12:46+08:00",
      "title": "跨源迁移交付完成",
      "detail": "具名设备验收及最终提交精确CI完成，旧历史与下载保留。此时间为登记时间。",
      "itemId": "LIBRARY_CROSS_SOURCE_MIGRATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41135459269",
        ".hvigor/outputs/user-flow-audit/source-settings-repair/library-cross-source-migration-20261031/evidence.json"
      ]
    },
    {
      "id": "feature-parity-comparison-request-20261031",
      "at": "2026-10-31T06:22:51+08:00",
      "title": "参考应用功能对照",
      "detail": "用户要求继续对照其他功能缺口，当前为源码和接线审查。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_COMPARISON",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-comparison-complete-20261031",
      "at": "2026-10-31T06:33:32+08:00",
      "title": "参考应用功能对照完成",
      "detail": "已核出11项缺失与7项部分实现，具体能力取舍待用户决定。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_COMPARISON",
      "kind": "checkpoint",
      "evidence": [
        "docs/FEATURE_COMPARISON_AIDOKU_MIHON.md",
        ".hvigor/outputs/feature-parity-audit-20261031/comparison.json"
      ]
    },
    {
      "id": "feature-parity-implementation-start-20261031",
      "at": "2026-10-31T06:43:08+08:00",
      "title": "功能差异开始实施",
      "detail": "用户授权开始实现报告中的功能差异，首批更新、离线和备份进行中；入口及默认值待答复。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "docs/FEATURE_COMPARISON_AIDOKU_MIHON.md"
      ]
    },
    {
      "id": "feature-parity-first-batch-adopted-20261031",
      "at": "2026-10-31T06:48:28+08:00",
      "title": "首批入口与默认值已采用",
      "detail": "用户确定更新、下载清理及备份入口和默认值，候选实现中，尚未编译验收。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-first-batch-build-20261031",
      "at": "2026-10-31T07:07:47+08:00",
      "title": "首批功能本地构建",
      "detail": "更新、离线及备份候选已构建，设备与后台回调仍待验证。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/build-004.log"
      ]
    },
    {
      "id": "feature-parity-settings-native-20261031",
      "at": "2026-10-31T07:29:36+08:00",
      "title": "首批设置实机核对",
      "detail": "更新与下载设置入口及保存已观察，后台执行、下载和外部备份仍待验。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/update-enabled-010/config.json",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/read-cleanup-menu-013/"
      ]
    },
    {
      "id": "feature-parity-background-download-20261031",
      "at": "2026-10-31T07:43:37+08:00",
      "title": "后台下载与清理实测",
      "detail": "后台下载及读后清理已观察；备份内容和回调、下载显示修正仍待验。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/background-download-result-035/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/fixed-background-callback-031/backup-result.json"
      ]
    },
    {
      "id": "feature-parity-scoped-update-backup-20261031",
      "at": "2026-10-31T07:58:32+08:00",
      "title": "范围更新及下载清理实测",
      "detail": "范围更新、后台下载和删除后显示已观察；外部备份已找到，内容仍待核。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/scoped-update-evidence-045/",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/find-generated-backup-055/"
      ]
    },
    {
      "id": "feature-parity-backup-preview-restored-20261031",
      "at": "2026-10-31T08:18:54+08:00",
      "title": "自动备份预览及设备恢复",
      "detail": "自动备份经系统文件选择器解析预览，设备数据及电源恢复；首批代码仍在收尾。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/restore-data-comparison.json",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/backup-preview-readback-058/"
      ]
    },
    {
      "id": "feature-parity-first-batch-final-build-20261031",
      "at": "2026-10-31T08:20:34+08:00",
      "title": "首批功能验证与构建完成",
      "detail": "首批具名设备范围及最终逻辑构建已核，准备提交；智能周期与后续功能仍未完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/build-016.log",
        ".hvigor/outputs/feature-parity-implementation-20261031/restore-data-comparison.json"
      ]
    },
    {
      "id": "feature-parity-second-batch-adopted-20261031",
      "at": "2026-10-31T08:27:28+08:00",
      "title": "第二批功能已采用并实施",
      "detail": "首批已推待CI；用户采用CBZ导出、队列置顶置底和每书偏好，第二批构建中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41149684809"
      ]
    },
    {
      "id": "feature-parity-chapter-management-native-20261031",
      "at": "2026-10-31T08:38:40+08:00",
      "title": "第二批章节管理实测",
      "detail": "CBZ导出后普通导入阅读、按书偏好及单章队列排序已观察；本场恢复尚未完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/chapter-management/"
      ]
    },
    {
      "id": "feature-parity-second-third-progress-20261031",
      "at": "2026-10-31T08:44:28+08:00",
      "title": "第二批实测及第三批采用",
      "detail": "首批CI成功，第二批整本队列排序及冷进程偏好已核；第三批已获用户采用，尚未实现。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41149684809",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/chapter-management/"
      ]
    },
    {
      "id": "feature-parity-bookmark-notes-cover-20261031",
      "at": "2026-10-31T09:04:25+08:00",
      "title": "书签、笔记及封面实测",
      "detail": "书签和笔记已实测，自定义封面虽已保存但显示占位，修正中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41151835894",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/chapter-management/"
      ]
    },
    {
      "id": "feature-parity-cover-backup-native-20261031",
      "at": "2026-10-31T09:09:41+08:00",
      "title": "自定义封面及备份恢复实测",
      "detail": "封面冷重入、源刷新保留、备份导入及恢复源封面已观察；本场清理恢复中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/chapter-management/"
      ]
    },
    {
      "id": "feature-parity-third-batch-restored-20261031",
      "at": "2026-10-31T09:12:25+08:00",
      "title": "第三批设备恢复完成",
      "detail": "第三批具名路径及本场数据、电源恢复已核，源码交付准备中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/chapter-management-restored-data.json"
      ]
    },
    {
      "id": "feature-parity-third-batch-pushed-20261031",
      "at": "2026-10-31T09:13:59+08:00",
      "title": "第三批代码推送",
      "detail": "第三批源码已推送，精确CI待核；后续功能合同继续核对。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-fourth-batch-implementation-20261031",
      "at": "2026-10-31T09:22:49+08:00",
      "title": "预计周期与Wi-Fi预载实现",
      "detail": "预计周期独立逻辑已构建，Wi-Fi预载接线中；入口选择及设备验证待完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41154283239"
      ]
    },
    {
      "id": "feature-parity-fourth-batch-adopted-20261031",
      "at": "2026-10-31T09:27:45+08:00",
      "title": "预计日期与Wi-Fi预载入口采用",
      "detail": "用户已采用两个默认关闭入口；本地逻辑通过，设备验证待完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-fourth-native-20261031",
      "at": "2026-10-31T09:35:46+08:00",
      "title": "第四批设置及范围更新实测",
      "detail": "设置保存、Blue范围更新及Wi-Fi下在线正文已核；设备恢复和交付待完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41154283239",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-fourth-restored-20261031",
      "at": "2026-10-31T09:40:13+08:00",
      "title": "第四批设备恢复及手动检查修正",
      "detail": "设备与数据已恢复；手动全库检查最后修正已通过本地逻辑及构建，尚未安装。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/policy4-restored-data.json"
      ]
    },
    {
      "id": "feature-parity-statistics-adopted-20261031",
      "at": "2026-10-31T09:44:02+08:00",
      "title": "阅读统计方案已采用",
      "detail": "第四批已推待CI；用户采用阅读统计范围，数据链已开始接入，界面实现中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41156512169"
      ]
    },
    {
      "id": "feature-parity-reading-statistics-native-20261031",
      "at": "2026-10-31T09:54:25+08:00",
      "title": "阅读统计具名验证与恢复",
      "detail": "真实前台会话、冷启动及统计页面已核，后台间隔未计；设备已恢复，源码待交付。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/reading-statistics-restored-data.json",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-statistics-finish-smart-adopted-20261031",
      "at": "2026-10-31T09:57:55+08:00",
      "title": "统计收尾与智能分类采用",
      "detail": "统计最后可见页计数已完成逻辑及构建验证；用户采用智能分类方案，尚未实现。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41156512169"
      ]
    },
    {
      "id": "feature-parity-statistics-pushed-20261031",
      "at": "2026-10-31T10:00:21+08:00",
      "title": "阅读统计代码推送",
      "detail": "阅读统计代码已推送，精确CI待核；智能分类合同准备中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-smart-category-built-20261031",
      "at": "2026-10-31T10:08:01+08:00",
      "title": "智能分类候选构建",
      "detail": "规则、书架投影及分类管理候选已构建，本地逻辑通过，设备尚未验收。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41157810983"
      ]
    },
    {
      "id": "feature-parity-smart-category-native-start-20261031",
      "at": "2026-10-31T10:12:45+08:00",
      "title": "智能分类进入设备验证",
      "detail": "编辑入口及规则已显示，保存和动态成员尚待验证；统计CI已成功。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41157810983",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-smart-category-match-20261031",
      "at": "2026-10-31T10:19:23+08:00",
      "title": "智能分类动态匹配实测",
      "detail": "规则保存、动态匹配及手动分类隔离已核；管理菜单修正中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-smart-category-restored-20261031",
      "at": "2026-10-31T10:22:56+08:00",
      "title": "智能分类管理验证及恢复",
      "detail": "规则管理、冷启动和删除已具名验证，设备及数据已恢复；源码待交付。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/smart-restored-data.json"
      ]
    },
    {
      "id": "feature-parity-smart-category-pushed-20261031",
      "at": "2026-10-31T10:27:08+08:00",
      "title": "智能分类代码推送",
      "detail": "第六批代码已推送，精确CI运行中；后续入口选择待答复。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41159800145"
      ]
    },
    {
      "id": "feature-parity-archive-filter-adopted-20261031",
      "at": "2026-10-31T10:30:19+08:00",
      "title": "多归档与亮度滤镜方案采用",
      "detail": "用户采用两组方案；多归档候选准备中，尚未构建或设备验证。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-archive-native-entry-20261031",
      "at": "2026-10-31T10:41:29+08:00",
      "title": "多归档入口设备验证",
      "detail": "智能分类CI成功；多归档入口已显示，文件传输失败后改用受控私有样本，导入阅读未验。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41159800145",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-archive-reader-native-20261031",
      "at": "2026-10-31T10:57:07+08:00",
      "title": "多归档导入与阅读实测",
      "detail": "TAR、RAR、7z及图片型EPUB普通导入已核，EPUB正文已观察；本场清理恢复中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-archive-restored-20261031",
      "at": "2026-10-31T11:12:02+08:00",
      "title": "多归档测试清理与恢复",
      "detail": "自有样本已清理，原数据、应用及电源恢复；最后构建及源码交付待完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/archive-restored-data.json"
      ]
    },
    {
      "id": "feature-parity-archive-pushed-20261031",
      "at": "2026-10-31T11:17:16+08:00",
      "title": "多归档代码推送",
      "detail": "多归档产品代码已推送，精确CI运行中；亮度滤镜开始实施。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41163450398"
      ]
    },
    {
      "id": "feature-parity-reader-filter-built-20261031",
      "at": "2026-10-31T11:22:58+08:00",
      "title": "亮度滤镜候选构建",
      "detail": "全局及阅读器候选已构建，设备验证进行中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41163450398"
      ]
    },
    {
      "id": "feature-parity-archive-ci-filter-native-20261031",
      "at": "2026-10-31T11:27:06+08:00",
      "title": "归档交付与滤镜默认状态",
      "detail": "归档精确CI成功；亮度滤镜默认关闭已观察，保存及实际效果仍在验证。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41163450398"
      ]
    },
    {
      "id": "feature-parity-reader-filter-native-20261031",
      "at": "2026-10-31T11:31:41+08:00",
      "title": "亮度滤镜实机验证",
      "detail": "灰度、亮度及反色已观察，滑块显示已修；滤色模式及设备恢复仍在进行。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-reader-filter-restored-20261031",
      "at": "2026-10-31T11:36:27+08:00",
      "title": "亮度滤镜具名验收及恢复",
      "detail": "screen、multiply及连续滚动实图已核，设备数据和电源恢复；两仓交付待完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/display-restored-data.json"
      ]
    },
    {
      "id": "feature-parity-reader-filter-pushed-20261031",
      "at": "2026-10-31T11:37:35+08:00",
      "title": "亮度滤镜两仓推送",
      "detail": "亮度滤镜两仓已推，精确CI运行中；追踪服务接口调查开始。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41165157510",
        ".hvigor/outputs/feature-parity-implementation-20261031/display-acceptance-binding.json"
      ]
    },
    {
      "id": "feature-parity-tracker-api-investigation-20261031",
      "at": "2026-10-31T11:39:08+08:00",
      "title": "追踪服务接口准备",
      "detail": "当前产品树CI运行中，更多追踪服务接口调查开始，具体UI待用户决定。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41165212291"
      ]
    },
    {
      "id": "feature-parity-tracker-backend-built-20261031",
      "at": "2026-10-31T11:51:03+08:00",
      "title": "追踪服务后端候选构建",
      "detail": "亮度滤镜精确CI成功；Bangumi及MangaUpdates后端候选已构建，界面和账号验证待完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41165212291"
      ]
    },
    {
      "id": "feature-parity-tracker-ui-pending-20261031",
      "at": "2026-10-31T11:53:36+08:00",
      "title": "追踪服务候选范围核对",
      "detail": "Bangumi及MangaUpdates后端候选已构建，界面方案待决定，真实账号与Native HTTP未验。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-tracker-ui-adopted-20261031",
      "at": "2026-10-31T20:50:49+08:00",
      "title": "追踪服务连接方式已采用",
      "detail": "用户采用Bangumi个人令牌及MangaUpdates用户名密码，并要求完整匹配、确认和同步；实施中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-tracker-native-start-20261031",
      "at": "2026-10-31T20:58:09+08:00",
      "title": "追踪服务进入设备验证",
      "detail": "连接界面与共享能力表已接，本地构建通过；设备安装及账号相关验证尚未完成。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-tracker-forms-native-20261031",
      "at": "2026-10-31T21:03:15+08:00",
      "title": "追踪连接表单实测",
      "detail": "空值、掩码、失败反馈及离开清空已核；用户无账号，真实同步未验，设备恢复中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/library-automation/"
      ]
    },
    {
      "id": "feature-parity-tracker-restored-20261031",
      "at": "2026-10-31T21:05:10+08:00",
      "title": "追踪表单验收及恢复",
      "detail": "两服务连接表单已具名验证，原数据和电源恢复；真实账号同步未验，源码待交付。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/tracker-acceptance-binding.json"
      ]
    },
    {
      "id": "feature-parity-kitsu-adopted-20261031",
      "at": "2026-10-31T21:05:39+08:00",
      "title": "Kitsu完整接入已采用",
      "detail": "用户采用现有追踪详情邮箱密码登录、匹配确认和同步，正在实现。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-kitsu-native-form-20261031",
      "at": "2026-10-31T21:13:17+08:00",
      "title": "Kitsu表单与生产逻辑验证",
      "detail": "生产逻辑及设备表单已核；真实账号未验，设备恢复进行中。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/kitsu-inputs.json"
      ]
    },
    {
      "id": "feature-parity-kitsu-restored-20261031",
      "at": "2026-10-31T21:14:04+08:00",
      "title": "Kitsu表单验证后恢复",
      "detail": "本场原数据及电源已恢复，三项追踪表单具名范围待统一交付；真实账号路径未验。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/kitsu-acceptance-binding.json"
      ]
    },
    {
      "id": "feature-parity-tracker-accounts-unavailable-20261031",
      "at": "2026-10-31T21:14:38+08:00",
      "title": "追踪账号验证边界",
      "detail": "用户目前没有三项服务账号，真实登录及远端同步保留未验，本地实现待交付。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": []
    },
    {
      "id": "feature-parity-trackers-pushed-20261031",
      "at": "2026-10-31T21:17:25+08:00",
      "title": "追踪服务代码推送",
      "detail": "三服务产品代码已推送，精确CI运行中；真实账号路径未验。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        "https://github.com/honjow/Koma/actions/runs/41204801578"
      ]
    },
    {
      "id": "feature-parity-trackers-ci-delivered-20261031",
      "at": "2026-10-31T21:30:12+08:00",
      "title": "追踪服务代码交付",
      "detail": "三服务本地实现、表单验证及精确CI完成；真实账号路径未验。此时间为登记时间。",
      "itemId": "FEATURE_PARITY_IMPLEMENTATION",
      "kind": "checkpoint",
      "evidence": [
        ".hvigor/outputs/feature-parity-implementation-20261031/tracker-ci-final.json",
        "https://github.com/honjow/Koma/actions/runs/41204801578"
      ]
    }
  ],
  "reportAgeAudit": {
    "directEventCorrection20261029": "本会话13项以原UserMessage事件行号及item.id校正；双击旧监督转述值保原项证据，东立重复反馈及PAGE_SIZE/SWIPE约值仅附可核事件，AUTO更早原始依据保留。未排除跨会话更早历史。",
    "asOf": "2026-10-26T03:33:52+08:00",
    "openTotal": 26,
    "openWithPreviouslyRecordedUserFirstReport": 7,
    "openWithExactWindowFeedbackTimestampButEarlierHistoryUnexcluded": 18,
    "openWithKnownInstructionLowerBoundOnly": 1,
    "parkedWithUnknownUserFirstReport": 1,
    "basis": "既有7项保原已核首报字段并匹配原user记录。新增18项是当前唯一10-22续接窗口内最早定位的人类反馈；时间戳已逐条核实，但未排除8GB原主档更早同问题，故均仅给至少经过时长，不冒全历史首次、不以窗口截断缩短拖延。SOURCE_FILTERS仅10-20北京时间明确修正/验收指令下界。时长不是编码工时；open混有具名交付后的未验边界与真正未闭原因。",
    "scopeAtAudit": "03:33:52原26项open首报核账快照；后继LIST_EDGE_SCROLL_FEEL、READER_SETTINGS_STABILITY及AUTO_CHAPTER_BOUNDARY_TARGET已凭实证/当前消费合同并核原范围收束accepted。原审计仍保各项当时首报/经过时长，不篡改时点或假称当时已闭。",
    "currentOpenAfterVerifiedScopeClosure": 23
  }
}
-->

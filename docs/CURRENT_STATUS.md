# Koma 当前工作单

本文件是唯一任务队列。当前有效任务、已接受范围、权限、未验边界及证据以以下 snapshot 为准；不另建重复队列。

当前工作：NamiComi已正式交付，正在验证NoyAcg搜索筛选候选。

设备：197已恢复并释租；237按既有授权执行书源验证并在会话结束后恢复。200禁止操作，四私库搁置。

任务状态、首次报告时间及证据索引不因文档整理改变。局部验收、构建、CI或发布不代表全部缺陷完成。

<!-- koma-progress-snapshot
{
  "schemaVersion": 1,
  "title": "Koma 当前工作",
  "state": "持续核验与修复中",
  "outcome": "查看当前问题、已验收范围和剩余工作。",
  "updatedAt": "2026-10-29T13:07:37+08:00",
  "target": "/Users/honjow/git/Koma；同级reader-kit与koma-sources为原主仓",
  "activeId": "SOURCE_SETTINGS_MIGRATION_AUDIT",
  "activity": "237正在验证NoyAcg搜索筛选候选，整体源能力核验继续。",
  "nextAction": "完成NoyAcg具名设备验证及原状态恢复。",
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
      "appHead": "Koma/master 6dbb621d24048ca297f0caaa8250e7b0f03e904a，精确CI40820669074成功。",
      "hap": "197已恢复原状态并释租；237当前原7f9用于NoyAcg候选Native验证，source_terra本轮持租，会话结束按基线恢复。"
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
      "owner": "Root：真正连续跨章实现",
      "dependencies": [],
      "relatedItems": [
        "READER_SETTINGS_STABILITY",
        "NEXT_CHAPTER_PREFETCH_REUSE"
      ],
      "status": "197具名连续跨章范围已验收",
      "kind": "accepted",
      "result": "197 Blue横向双方向及连续章、MH1234多页RTL、Nemo多页纵向往返具名范围已核，精确CI成功，设备已恢复。",
      "remaining": "本次具名范围完成；不外推其他未知来源或宿主。",
      "reportedAt": "2026-10-23T04:55:39.469Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 372447921 重新读原文与时间戳，不是摘要/登记时间。",
      "firstEvidenceAt": "2026-10-23T04:55:39.469Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": "2026-10-29T07:57:24+08:00",
      "evidencePoints": [
        "直接产物索引：.hvigor/outputs/continuous-position-rejected-072.patch；reader-kit提交7744665155743b4c62b2e21166e22ace76b9e27c，119关键回归通过；Koma接入提交5d966878；197清理HAP SHA-256 f6749b58303015d413fea24d2baf4030375a9958c27f7a760defb9793d8fe889。自然终点反例58/59；MeasuredPosition改用原生getItemRect实际边界而非推算imageHeight，参考官方API与Mihon同规则，61/62设备回验。reader-kit 7744665与cab2118已推main并读回cab；Koma 229daf3c精确CI40651937090失败，漏偏好/state/bridge等调用依赖；补齐提交091d2b6758c94bb0d58130f6b9626a052f6ce787已推master，精确CI40655062200 completed/success，连接器读回head_sha一致。"
      ],
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "保显式选章与既有续读语义；不以isAtEnd强改页码、不延时抢滚动。不能从本路径宣称全部Reader通过。"
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
      ]
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
      "priority": "P1（当前优先：统一搜索逐源CF自动验证；旧Web/搜索范围保留）",
      "owner": "Root：宿主会话及请求身份；source_terra：237具名站点回验",
      "dependencies": [],
      "status": "宿主请求关联CI成功，237站点回验继续",
      "kind": "open",
      "result": "App12204da8edfb707bf3e53710e3daf279f8556c4d八文件Host/Worker/ABI/检查已push且精确CI40458243006 completed/success。197989安装同签18910496 Release/debugfalse/0.1.3/code4，987中性awake86400000/988→990七文件逐字同；default-result无errors，默认Browse鬼灭之刃/炎炎之消防队/高木同学简体12卡9图及detail标题简介235章亲审；traditional-result无errors，true普通Browse鬼滅之刃/消防隊/同學繁体12卡9图亲审，随后仅清本次Bz设置回原书架。991日志四实际HTTP session cookieState=present/200含default metadata/detail/chapters及trueBrowse；无Reader入场。992系统120000无Override/c14761b7释租，mangabz-worker197-restoration-comparison.json及worker-identity/identity.json具据。 浏览页、源内搜索与统一搜索的网页验证共用prepareSourceWebSession；该入口已按sourceId解析安装包当前语言名称，解析不可用回退原传入名，URL与验证状态流程保持。App5748d0a83c0b37653f5c20f097f6ece4c479cf29已提交推送，现有验证/session执行检查及Release HAP构建通过，精确CI40486939289 completed/success；真实验证窗口Native仍未验证，不写名称窗口已验收。 237新会话普通统一搜索斗破苍穹：漫画160真实HTTP403触发验证sheet，随后无用户输入自动返回并显示10条作品；同次包子challenge_required排队，DM5、快看、腾讯、再漫画等已解析ready。007输入参数错误未产生查询或请求，不计验证。003安装最终0cd18 HAP，前后registry/settings JSON完全相等，原斗破01第1页3%保留；当时临时scope source，原local；013已恢复local，目前仍持租。 012单源过滤日志显示包子原请求验证一次、搜索完成并ready 6条；008后无点击、重试或关闭输入，漫画160的10条和包子6条分别自动回流。009零动作日志为空、010全量日志尾部无关，不作缺事件依据；包子Native标题未截图，不称第二标题亲验。 23个相关依赖文件e2946421152596bf766ce8acacb572f3cb21ede5已推master，精确CI40670008826 completed/success，连接器读回head一致；相关回归51通过，XCOMIC detailContext ABI仍为未提交WIP。013已Native确认sourceFilter恢复及返回书架；015手动检查，016尚未完成但确认13个更新。017–018漫画1234公开0.1.4更新成功且Native显示漫画1234网；019–020漫画社公开0.1.9安装成功，设置及正文未验；021–022妙趣0.1.3公开更新成功，registry 0.1.3及Native显示妙趣漫画。升级后对应源包版本允许变化，其他设置与设备仍待总恢复。 本轮237已回原书架、恢复设置及筛选，最终SLEEP/正常120000无override并释租；原404、取消防重复及未命中窗口标题等仍独立未验。 Simply Hentai旧日志显示challenge信号被源降为http_error；012候选在旧Host仍403。Host普通目录和首搜索缺guard及requestHandle接线，三文件候选正构建并待237回验；默认403保持，API origin限定api.simply-hentai.com，不假定www共享会话。 Simply第一轮联合候选验证后原请求仍403，无自动循环；原包、四份用户数据及会话记录已恢复，临时文件清除，237电源恢复并释租。发现原请求与验证页UA不一致，最小修正及单次回验中，403原因尚未确定。 Simply UA一致性候选在237手动验证后仍403；日志显示UA不一致及Cookie读取为空，不认定根因。原宿主、原011包、五份数据及会话恢复，临时文件清除，设备休眠释租。 宿主验证请求关联及原UA传递6d6ae7a已推，精确CI进行中；Simply仍403，get_home因果ID尚未接通，不称验证完成。 宿主验证请求关联及原UA传递6d6ae7a精确CI40779011098成功；Simply及get_home原未验边界保留。 6d6ae7a精确CI40779011098 completed/success。 Zero公开017游客锁章拒绝及本站登录入口具名已核，登录态正文未验；原源、数据和电源已恢复，reader自然新增第二章记录。",
      "remaining": "Mangabz Host1220精确CI成功及源e38随654准确公开，无本批工程等待；197原简繁metadata/四HTTPcookiepresent200与七文件恢复具名，无新Reader、不扩全部旧页表重取。原CF自动404/登录及真实provider等未知按归属保持，237原85/总场恢复继续。 App5748d0a8精确CI40486939289已成功；Root仍需真实验证窗口标题Native。 保留404原GET、取消防重复及未命中的真实窗口标题等边界，原scope和设备状态本轮已恢复，不外推全源。 继续核404、取消防重复及未命中的真实窗口标题等边界。 Simply验证会话及原API origin普通路径仍待回验。 Simply候选UA一致性修正及真实验证回流仍待回验。 Simply真实验证回流仍未通过，原因待核。",
      "reportedAt": "2026-10-23T01:44:08.576Z",
      "reportedAtSource": "原始会话JSONL response_item/user；本轮限定原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 254529135 重新读原文与时间戳，不是摘要/登记时间。",
      "requestedAt": "2026-10-23T01:46:03.842Z",
      "firstEvidenceAt": "2026-10-23T01:44:08.576Z",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
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
        "直接产物索引：https://baozimh.org；.hvigor/outputs/user-flow-audit/mh160-web-entry-chain-review/public-script-receipt.json。该结果只限制本次脚本取得；.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/mh160-runtime197-atomic-session-423/；.hvigor/outputs/user-flow-audit/mh160-web-entry-chain-review/ordinary-mh160-compatibility-candidate.patch；web-observed.png；.hvigor/outputs/user-flow-audit/mh160-web-entry-chain-review/public-script-receipt.json；mh160-web-entry-chain-review/temporary-runtime-probe.patch；temporary-probe-basis.json；413/web-observed.png；result.json；koma-log-20261026-120547.log；598/returned-original-detail.json；result.json/runtime-lines.txt；mh160-runtime197-atomic-session-430/result.json；runtime-lines.txt；mh160-web-entry-chain-review/public-detail-script-receipt.json；mh160-runtime197-atomic-session-437/runtime-lines.txt；Koma-mh160-ordinary-compatibility-candidate-signed.hap；mh160-web-entry-chain-review/ua-authorization-original-message-review.json；mh160-runtime197-atomic-session-444/result.json/runtime-lines.txt；formal-5908-ci.json；mh160-search197-atomic-session-451/result.json/search-runtime-lines.txt；search-observed.png；mh160-web-entry-chain-review/mihon-current-*.kt；global-search-web-build.log；global-search-web-owner-tests.txt；global-search-web197-atomic-session-458/result.json；atomic-session-467/result.json/search-runtime-lines.txt；global-search-web197-atomic-session-476/result.json；global-search-formal-ci-detail.json；global-search-web197-formal-delivery-485/result.json；formal-library.png；228/search-baseline-wasm.json；search-current-http.json；Mh160.kt；mh160-web-entry-chain-review/http-facts-basis.json；temporary-http-facts.patch；http-facts-build.log；mh160-search-return197-atomic-session-599/result.json；after-manual.png；search-landing-fix-build.log；search-landing-fix197-session-606/result.json；ordinary-result.png；restored-library.png；mh160-web-entry-chain-review/search-landing-fix-ci-detail.json；koma-sources/sources/goda/metadata.json；manifest.json/source.wasm/icon.png；source-b406995-public-review.json；Koma-source-known-actions-final-signed.hap"
      ],
      "remainingActions": [
        "继续核404、取消防重复及未命中的真实窗口标题等边界。",
        "保留404原GET、取消防重复及未命中的真实窗口标题等边界，原scope和设备状态本轮已恢复；不外推全源。",
        "Mangabz Host1220精确CI成功及源e38随654准确公开，无本批工程等待；197原简繁metadata/四HTTPcookiepresent200与七文件恢复具名，无新Reader、不扩全部旧页表重取。原CF自动404/登录及真实provider等未知按归属保持，237原85/总场恢复继续。",
        "App5748d0a8精确CI40486939289已成功；Root仍需真实验证窗口当前语言标题Native；原CF未验边界不因名称修复关闭。"
      ],
      "boundaries": [
        "漫画屋478/479与包子537/538自动回流分别具名成立；不外推全部CF、人工挑战、登录或正文。",
        "验证会话的UA、Cookie策略和权限边界保持；漫画160普通网页的UA兼容仅按已采用专用规则处理，不扩大到源HTTP或验证会话。原请求失败仍保人工入口且不循环，包/设置/路由/claim失效与离开回调守卫保持。",
        "document_visible仅官方“即将可见”事件，不是绘制证明；closed/partial只是网页离开状态，不作为站点成功。阶段诊断不记录URL、标题、HTML、headers或body。"
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
      "stage": "237会话已恢复，其他挑战边界待验",
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
        "https://github.com/honjow/Koma/actions/runs/40779011098"
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
      "status": "237 Comic Fury搜索及目录筛选具名回验，其他范围继续",
      "kind": "open",
      "result": "首项仅改为清除此项筛选，源All与原顺序/材质保留。237201菜单原图已亲看，202实际清除后All对勾消失，原重置恢复并自然回原大奉001第6页25%；203三域完整JSON同200，筛选schema1/sources{}。 237公开Comic Fury 0.1.6普通目录默认热门12本，八个筛选控件已观察；目录按更新时间排序实际成功，清除恢复默认。源内搜索a后选择Popularity，实际发目录请求而搜索结果不变。宿主已按搜索状态分流筛选读取、忙碌、修改与重置，保独立持久化及原样式；本地构建成功，修复包尚未真机回验。169日志为空不推断具体传输错误。 冻结release HAP SHA-256 0755556ec2d264637bbcf55fb071e63149670e17f5abca7acfc015025e864e30已170安装成功，171前台书架；registry/settings/library/filter与169全份相等。此前构建后输出目录变debug已拦下，冻结release及原profile/chain相同后才安装；首次launcher快照不称启动失败。Native筛选回验尚未完成。 237冻结release 0755：178–179搜索a选Popularity实际search op21成功，首Maor/慢话/MyDiary；180搜索重置实际search op23恢复原结果，search保存值删除且browse保持；181清查询后目录重置实际get_manga_list op25恢复12本首Maor。Comic Fury本轮筛选项已清除，其他源筛选与169逐字相同、全source-settings与131/002基线相等。旧168误发目录反例保留。宿主3文件4232f2a3已本地提交，推送进行中、精确CI未核；本地执行回归、release构建及同签冻结包与设备验证分别成立。 4232f2a3精确CI40712563864 completed/success已核。 瓜子0.1.4（6f218fc，CI40731076432成功）公开WASM与原C++ Host对实时保存HTML重放爱/cid9得36项及cursor2；H-Comic先有CI成功但索引仍旧版的反例，补修4949ea7后CI40733492093成功、公开0.1.3 filters=true，公开WASM重放具名random及love/full-color样本。两源公开二进制与本地验证边界各自记录，237 Native均未验。 237公开瓜子0.1.4及H-Comic0.1.3普通目录和搜索筛选已具名验收；本次设置及筛选恢复基线，原书架和设备状态恢复并释租。 具名范围：瓜子目录恋爱筛选36本，搜索爱后选恋爱实际search完成；H-Comic目录全彩10本，搜索love后选全彩实际search完成；两者重置后filterprefs为空。证据为layout及运行记录，筛选过程无截图，不扩其他值。",
      "remaining": "原批准的自然失败提示/重试恢复仍缺实际适用样本，保open；普通/快速切换与本轮清除文案已具名验收，不重跑、不造故障。 Comic Fury具名筛选分流及精确CI已核。 瓜子0.1.4及H-Comic 0.1.3具名筛选已在237验收，不外推其他筛选值。",
      "reportedAt": null,
      "reportedAtSource": "最初用户提出时间仍未找到；已查到原会话2026-10-19T16:05:45.582Z明确采用筛选并发/失败提示重试三项并要求实施后验收，不以这次批准冒初次首报。",
      "firstEvidenceAt": null,
      "closedAt": null,
      "owner": "Root：具名文案与切换范围冻结，自然失败待样本",
      "evidencePoints": [],
      "remainingActions": [
        "Comic Fury具名筛选分流及精确CI已核。",
        "原批准的自然失败提示/重试恢复仍缺实际适用样本，保open；普通/快速切换与本轮清除文案已具名验收，不重跑、不造故障。"
      ],
      "boundaries": [],
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
      "stage": "Comic Fury筛选分流已回验，其他范围待验"
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
      "evidencePoints": [],
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
      "owner": "Root：列表重复文案78f已push并普通Native完成，原59ms/全性能边界仍open",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_INSTALL_GLOBAL_DISABLE",
        "SOURCE_PACKAGE_ICON_INVALIDATION"
      ],
      "kind": "open",
      "status": "第二候选未证明性能改善，结构改动已撤回",
      "result": "第二候选的列表样式、尾部和身份具名正常，但实际trace仍有长帧，不能证明卡顿修复；结构改动已撤回，原设备状态恢复。",
      "evidencePoints": [
        "直接产物索引：https://github.com/honjow/Koma/releases/tag/v0.1.3-pre；230/audit/frequency-comparison-224-230.json；build.log；diagnostics-redaction-reuse-review/txt-suffix-unadopted-candidate.patch；300/audit/callback6739-scheduler-frequency.json；koma-log-export-20261026-003924.log；307/audit/aligned-existing-cpu.json；audit/aligned-existing-cpu.json；/tmp/koma-computed-fresh-result-before.txt；test_source_index_progressive.cjs；receipt.json；Koma-source-current-result-fixed-signed.hap；manhuagui-network-phase-review/source-head-current.json；manager-after-real-update.png；browse-name-projection197-session-513/result.json；offline-window-review.json；mh160-web-entry-chain-review/browse-name-projection-ci-detail.json；scripts/test_source_install_worker.cjs；temporary-browse-row-count.patch；pre2-browse-source.png；restored-library.png；pre2-batch-update-before.log；pre2-batch-update-after.log；candidate2-manager-details.png；pre2-candidate2-ci-detail.json；index.json；pre2-current-source-index.json；pre2-current-source-update-comparison.json；manager-cache-url-before.log；manager-cache-reader-relevant-final-tests.log；manager-cache-url-final-build.log；registry-update-review.json"
      ],
      "remainingActions": [
        "在必要导入路径核真实UI更新，继续定位和修复长帧。"
      ],
      "remaining": "继续定位真实导入长帧并验证修复；保非严格对比及遮挡边界。",
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
      "closedAt": null,
      "firstHandlingAtSource": "源码调查已由Root进行；仅本次可核登记起点，更早未分段不倒填。",
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "modificationBasis": {
        "object": "SourcePackageManagerPage三组末项分隔线状态与ForEach key",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "ForEach保留已有key的构造闭包，旧groups快照不随末项变化更新分隔线；原处理通过重建末项解决。",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "末项ID改由三个独立Computed字符串提供，分隔线直接观察当前末项；仅从key移除位置布尔值。保原生HDS、几何、顺序、动作及实际metadata更新规则；不冒整个卡顿/本行图标已修。"
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
        "run869 actual58.736ms、UIVsync58.711ms、Dirty30.884ms、Layout23.630ms；更新组与820不同，不作严格AB。候选patch保存在869，SourcePackageManagerPage已无diff；873–875恢复核实。"
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
      "stage": "导入长帧继续调查"
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
      "kind": "open",
      "status": "96a2123已推CI成功并随新包装237；重复样本角标未验",
      "result": "完整性比较改为保存目录条数，未读数仍按不同章节ID和原isRead计算。624条/600个ID/4已读回归返回596，并验证读态和目录不变；没有重新操作200。",
      "evidencePoints": [
        "直接产物索引：197394/library-after.json；442/library-after.json；manhuagui-network-phase-review/current-queue-library-sample.json"
      ],
      "remainingActions": [
        "原真实624行/600ID重复样本在200且禁止操作，237无同类，最新197442合法library离线76本/14902章逐本非空chapter.id无重复，仍无自然替代样本。待合法现存同类，不注入/不触200；逻辑交付与样本排除不代原故障实机验收，原项open。"
      ],
      "remaining": "原真实624行/600ID重复样本在200且禁止操作，237无同类，最新197442合法library离线76本/14902章逐本非空chapter.id无重复，仍无自然替代样本。待合法现存同类，不注入/不触200；逻辑交付与样本排除不代原故障实机验收，原项open。",
      "boundaries": [
        "源图标本行瞬空等独立未闭项保留；已验安装性能具名范围不重跑，也不因本项丢弃其他反馈。",
        "不得把单处源码线索或用户观察写为全App已查/已复现，保原内容与用户阅读数据。",
        "最新答复明确选择左上未读角标，取代原多章已读N/M文案；不将继续阅读章内百分比一并重做。"
      ],
      "reportedAt": "2026-10-23T21:15:30.893Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 945068377 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:16:09.194667+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
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
      "stage": "等重复章节样本"
    },
    {
      "id": "BAOZIMH_DAFENG_PAGE_LOAD_FAILURE",
      "title": "包子《大奉打更人》正文无法加载",
      "priority": "P1（具名正文不可读）",
      "owner": "Root：当前pre2自然冷页9新worker/原生取图已具名补验；200旧故障及全24页不外推",
      "dependencies": [],
      "relatedItems": [
        "BAOZIMH_BROWSE_FAILURE",
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "open",
      "status": "96a2123已推，精确CI成功；200实际恢复未验",
      "result": "普通源图网络失败自动刷新一次章页计划、每页最多再取一次；明确挑战/授权/取消/TLS错误不盲重试。手动重试可独立再次强刷，保下载/读态与当前阅读单元。40回归通过，default Release8550194B，未安装。",
      "evidencePoints": [
        "直接产物索引：open-001-failure-002/library.json；koma-log-20261025-053239.txt；failure.png；failure.json；baozi-image-worker-cache197-session-653/cache-coverage.json；page9-original-observed.png；original-page3-restored.png"
      ],
      "remainingActions": [
        "当前pre2同001自然未缓存页9的新worker/六图200及回3已具名，不代200原失败恢复或全24页。200禁止操作，Mac首跳302/154及目标SSLEOFError与197325 curl35各保来源，不直接套200旧2300999根因；原项继续调查未知，不重跑已验237页6或冷页9。"
      ],
      "remaining": "当前pre2同001自然未缓存页9的新worker/六图200及回3已具名，不代200原失败恢复或全24页。200禁止操作，Mac首跳302/154及目标SSLEOFError与197325 curl35各保来源，不直接套200旧2300999根因；原项继续调查未知，不重跑已验237页6或冷页9。",
      "boundaries": [
        "允许差异仅source图片选路与Host请求方法；保ID/章节/页数/进度，Reader布局不动。",
        "不写死rsa、不绕TLS、不新增UI或Cookie权限；五CDN仅按站点声明有界选择，每章一次，不盲目多路下载。",
        "Mac匿名样本不称Native通过，原325失败保留，其他请求method/会话边界保持。",
        "Root错误扩大取日志为界面点击：点击实际进入《预告》1/12而非001；本地前后读态确认当前章改变，书架记录逐字段保持。200租约f76eb5d2已释放；24小时熄屏覆盖仍写入，未获允许不得再操作手机恢复或写回进度。原覆盖值未记录，正常timeout读回120000ms。"
      ],
      "reportedAt": "2026-10-23T21:17:04.802Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 945450769 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:17:42.386549+00:00",
      "firstEvidenceAtSource": "本次登记时刻，非用户精确首报。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
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
      "stage": "等允许设备复验"
    },
    {
      "id": "SOURCE_BROWSE_HOME_STRUCTURE",
      "title": "源浏览分类下拉与首页分区结构待整理",
      "priority": "P2（设计结构调查）",
      "owner": "Root：Komiic016首页12卡/DM5018首页与c1f73dd同期普通Native具名完成；旧015空首页已取代",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_FILTERS",
        "BROWSE_HEADER_REFRESH"
      ],
      "kind": "accepted",
      "status": "首页/无首页具名通过，e6404c5b精确CI成功",
      "result": "最终签名Release8577441B已明确装237。包子首页/熱門为互斥内容，原生分类菜单在搜索下方，首页/熱門对勾随实际选择切换。熱門36本单一列表，首页不再额外请求默认栏目。正常下拉刷新仍选熱門、旧封面与内容保留；首页地区筛选进入原默认熱門，重置后原内容恢复。 本轮193–194无首页Comic Fury默认热门12本，菜单仅热门/最新，选最新后单一12本且首排实际变化，对勾正确；自然返回原大奉001第6页25%。",
      "evidencePoints": [
        "直接产物索引：https://www.dm5.cn实际title“动漫屋”"
      ],
      "remainingActions": [
        "本次包子/Comic Fury具名路径与提交CI冻结；独立搜索与自然失败未扩认，其他原未闭缺陷继续各项。"
      ],
      "remaining": "e6404c5b543653e2684ef4c5559f683484d64ceb已推master，精确CI40188955447 completed/success；没有新tag或发布。",
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
      "closedAt": null,
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
      ]
    },
    {
      "id": "MANHUAWU_SOURCE_UNAVAILABLE",
      "title": "漫画屋列表403与错误状态丢失",
      "priority": "P1（具名源不可用）",
      "owner": "Root：当前元尊具名与旧读态精确复核完成；旧460原因/首页CF仍open",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS"
      ],
      "kind": "open",
      "status": "017搜索修复交付；770–775元尊搜索→最早第1话→首图1/10具名，首页403/旧超时原因仍open",
      "result": "770–775漫画屋017单次元尊搜索→详情→最早第1话 周家圣龙（上）→真实首图1/10已亲审，search/detail/chapters/get_pages均200；新增元尊外旧91progress/8sourceHistory/151chapters及remoteHistory原对象/顺序全同。首页get_manga_list仍403挑战，当前成功不追认旧460 timeout原因；不外推完整叙事/十页或全CF，数据/系统/原Library已恢复。",
      "evidencePoints": [
        "直接产物索引：koma-log-20261024-120407.txt；405/history-result-receipt.json；228/search-baseline-wasm.json；search-current-http.json；228/search017-wasm-cases.json；manager-after-real-update.png；failure.png；manhuawu017-search197-only-session-507/result.json；native-source-search-results.png；recovery-773/runtime.log/reader-terminal.png；recovery-773/reader-records-review.json"
      ],
      "remainingActions": [
        "当前元尊页表200/首图及新增记录外原读态保持均已具名；旧460超时根因/首页自然CF仍未闭，不以本次成功追认旧原因，不重复查询取样，保网络/UA/Cookie/端点/超时。"
      ],
      "remaining": "当前元尊页表200/首图及新增记录外原读态保持均已具名；旧460超时根因/首页自然CF仍未闭，不以本次成功追认旧原因，不重复查询取样，保网络/UA/Cookie/端点/超时。",
      "boundaries": [
        "017搜索分页修复已交付；770–775元尊搜索→最早第1话→首图1/10具名，非完整叙事/全10页或全CF。首页get_manga_list仍403挑战，当前页表成功不追认旧460 timeout原因。",
        "保持原Cookie/UA/网络/端点/超时和目录/章节身份，不为取证重复已验查询/升级或造挑战；当前产品操作服从人类当前沟通指令。"
      ],
      "reportedAt": "2026-10-23T21:26:00.332Z",
      "reportedDate": "2026-10-24",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 946200498 读取原文，不是登记/处理/取证时间。",
      "firstEvidenceAt": "2026-10-23T21:26:41.632173+00:00",
      "firstEvidenceAtSource": "本次登记，非用户首报精确时间。",
      "firstHandlingAt": null,
      "handling": "当前执行者与未完成动作以owner/remainingActions为准。",
      "closedAt": null,
      "reportedDateSource": "按上述当前定位窗口内原始反馈UTC时间换算Asia/Shanghai日期；不是已排除更早历史的绝对首次日期，不使用登记日。",
      "modificationBasis": {
        "object": "SourceRuntimeHttpTransport HTTP envelope与漫画屋fetch/单域会话声明",
        "history": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "originalReason": "不向源暴露Cookie/任意响应头，不把全部403认挑战",
        "reopenEvidence": "当前有效边界以本项allowedDifference、boundaries及remainingActions为准。",
        "allowedDifference": "仅将精确标准响应头转可选accessSignal常量；保status/body/原错误；源仅对受支持状态消费并声明www.mhua5.com，保现有半模态/UI/权限边界"
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
      "stage": "根因未知"
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
      "kind": "open",
      "status": "399当前197正常016列表成功且恢复闭环；旧超时原因未知仍open",
      "result": "399当前197漫画柜016正常get_manga_list成功42本，HTTP200/27920chars及成功请求阶段数据具名，400/401恢复闭环；旧timeout具体阶段/根因未知，成功不倒证旧失败。原超时原因尚未查明，原项仍未关闭。",
      "evidencePoints": [
        "直接产物索引：.hvigor/outputs/user-flow-audit/manhuagui-network-phase-review；.hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/diagnostics/manhuagui-netphase197-single-browse-399。取证当时400/401返回恢复待回执；koma-log-20261024-092500.txt；399/network-result-receipt.json；401/restoration-receipt.json；405/history-result-receipt.json"
      ],
      "remainingActions": [
        "399当前正常016成功及400/401恢复保其具名范围；402–405历史故障事件只读查询四次均空，未获得旧失败阶段记录，不解释空输出原因或旧超时。待合法新阶段证据再针对原项续接，不盲重试、无新取证目的不重复请求，保请求栈/UA/网络。"
      ],
      "remaining": "399当前正常016成功及400/401恢复保其具名范围；402–405历史故障事件只读查询四次均空，未获得旧失败阶段记录，不解释空输出原因或旧超时。待合法新阶段证据再针对原项续接，不盲重试、无新取证目的不重复请求，保请求栈/UA/网络。",
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
      "closedAt": null,
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
      "stage": "根因未知，当前可用"
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
      "kind": "open",
      "status": "237东立首页已显示，正文限制仍待",
      "owner": "Root：237同一网络官网同作品/首话核对",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_RUNTIME_ERRORS",
        "MANXIAOSI_SETTINGS_VALIDATION_FAILURE"
      ],
      "result": "012恢复4章与无设置契约、013地区原因及精确CI已成立。按人类要求自行核对：237官方膽大黨→第1話→直接閱讀，官网明确授权台湾地区，实际先Please Wait后黑页未有正文。官网黑页具体失败不强归3166，原生API3166为独立确证。 用户本轮明确反馈东立空白首页仍未处理；此前官网章节黑页与3166是独立有限结果，不能用于解释或覆盖首页空白。 237已复现home=true但get_home返回空sections，同设备Popular有20本；源侧修正中，尚未回验。 237 tongli-home-fixed-263实见首页Popular六个封面及标题，修复了原空白首页；正文3166及官网黑页边界不变，设备恢复进行中。",
      "remaining": "首页具名范围已修复；原正文受授权限制及官网黑页边界保持开放，设备会话恢复待完成。",
      "reportedAt": "2026-10-24T11:59:14.391Z",
      "reportedAtSource": "当前定位的10-22续接窗口内最早明确人类反馈，原始timestamp实值；尚未排除原主档有更早同问题，不冒全历史首次。原始会话JSONL response_item/user实际反馈；已限定唯一原会话归档 rollout-2026-10-22T17-43-28-01a11fb1-9f44-7123-8590-b6e849190eab_01a162fe-7f97-7eb1-8c44-fa263235b9de.jsonl，字节偏移 1302381904 读取原文，不是登记/处理/取证时间。",
      "firstHandlingAt": "2026-10-24T12:02:09.354493+00:00",
      "closedAt": null,
      "evidencePoints": [
        ".hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/source-web-session-concurrent/tongli-home-fixed-263/screen.png"
      ],
      "remainingActions": [
        "完成本轮东立设备恢复；首页已见，原正文范围仍未通过。",
        "保站点授权限制及官网黑页两个有限结果；当前网络不能完成正文验收，不改账户/地区/网络。其他源与App继续。"
      ],
      "boundaries": [
        "本次只接受東立认证/目录/无设置契约/准确地区原因；正文未通过，其他作品和授权地区未扩大。",
        "未更改网络/账户或绕过站点地区限制；197/237原阅读数据保持，私库PARKED_USER不复活。"
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
      "stage": "首页具名修复，正文范围保持开放"
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
      "priority": "P2（后续迁移；不取消当前bugs）",
      "owner": "Root：漫画翻译完整迁移；Torii试译与Reader具名路径已核，其他提供方真实网络待验",
      "kind": "open",
      "status": "197空源表单与恢复已核，真实账户路径待验",
      "dependencies": [],
      "relatedItems": [],
      "result": "197普通设置路径已观察API与Codex空源表单，取消后列表仍空；未保存、登录或调用。原包、阅读数据及电源已恢复并释租。此前237 Torii试译及Reader预处理具名结果保持。",
      "reportedAt": "2026-10-26T13:29:18.490+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第16082行，UserMessage item.id=01a176af-3d99-7333-82d4-eea670ce1107；不排除跨会话更早历史。",
      "firstHandlingAt": "2026-10-26T05:31:40+00:00",
      "closedAt": null,
      "evidencePoints": [
        "直接产物索引：crop-strong-settings.png；restored-crop-settings.png；result.json；failure.png；model-downloaded-selected-off.png；enhanced-reader-page.png；cold-crop-strong-settings.png；cold-enhancement-active-settings.png；reader-enhancement-ci-detail.json；reader-translation197-session-579/result.json；translation-secure-manifest-cold-English.png；reader-translation197-session-586/result.json；reader-translation-ci-detail.json；top-icon-off-on-review.png；runtime-before-any-flip.log；reader-packed-rgba-before/after-case.log；reader-packed-rgba-build.log；page-index-to-success-evidence.json；semantic-restore-review.json",
        "本轮Release构建日志：/private/tmp/koma-translation-completion-build.log；冻结包：/private/tmp/koma-translation-completion-release.hap，SHA256 bbe9f3d7b204763fdab294ad0deee866c1efff28b95a7e0d73929a43d8a78651，19166717字节，release/debugfalse/0.1.3 code4；尚未安装。",
        "237 Torii两页真实试译及显示：.hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/torii-live-evaluation-result-13/、torii-first-translated-preview-14/、torii-second-translated-preview-15/、torii-second-translated-visible-16/。",
        "237恢复：.hvigor/outputs/user-flow-audit/device237__VDE-AL00/unfolded/portrait-1320x2120/translation-completion/translation-original-shelf-restored-18/、translation-power-restored-19/、translation-final-timeout-cleared-20/。",
        "本轮翻译源管理release构建日志：/private/tmp/koma-translation-sources-build.log；新增UI及网络账户路径未装机。",
        "Koma 3bd44ef9b4fded61ea71af19a6ddf8f67e0f33be已推；release构建及既有执行检查通过，CI40784766661进行中。",
        "https://github.com/honjow/Koma/actions/runs/40784766661",
        ".hvigor/outputs/user-flow-audit/device197__ALN-AL80/not-applicable/portrait-1260x2720/translation-completion/：run03–10普通设置入口、空API/Codex表单及取消；final-restoration原包、五文件和电源恢复释租。"
      ],
      "remaining": "继续验证Codex/OAuth/API真实网络及整体翻译迁移其余路径，不以空表单代替账户调用。",
      "remainingActions": [
        "按已授权范围验证其他提供方真实网络及整体迁移剩余路径。"
      ],
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
        "pendingImplementationVerification": "197空API/Codex表单及取消具名已核，真实账户网络和整体迁移其余路径待验证。",
        "unverifiedExternal": "Torii两页试译及Reader未来页具名路径已核；Codex/OAuth/API真实网络尚未验证，不读取或记录密钥。",
        "secureStorage": "按官方SECRET1–1024字节采用同owner immutable generation分块+短manifest最后原子发布；旧短inline可读，失败不换root，提交仅清owned旧代，凭据不入AppStorage/备份。"
      },
      "stage": "具名配置界面已核，真实网络待验",
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
      "priority": "P1（用户直接反馈）",
      "kind": "open",
      "status": "官网品牌逐项核对中，部分站点仍未知",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_EMPTY_SETTINGS_ENTRY"
      ],
      "result": "已开始逐站核对，未全部完成。2026-10-28只读核对：CManhua主页标题与当前中文环境显示名一致，同页Mgeko.cc关联或迁移未知；NoyAcg主页标题与现显示名一致。未修改这两源，不外推全源。 妙趣漫画桌面及移动官网名称已核，0.1.3更正名称已发布，公开Native未验；官网当前icon/logo链接404，保留既有参考图且当前官网图标未核。Zazhimi中文品牌依据不足不改名，官网192px图标实体与源icon SHA256相同；无限动漫标题与图标均与主站匹配。 本批只读核对：叭嗒官方隐私政策支持爱奇艺叭嗒名称；92漫画网、瓜子、六漫画、漫画人、漫画社、漫画屋、漫画160、快看、腾讯、色漫网、菇菇四格、鸟鸟韩漫、醫院也瘋狂、綜合口味、老夫子、幻塔、DOTA2、魔法纪录、輔大猴、我是馬克、人2、科技大觀園名称具名对应；漫小肆为品牌简称，原神页支持品牌但未见漫画内容，H-Comic未见中文品牌。漫画1234官网使用漫画1234网，与当前名称有后缀差异。漫画柜、Happy、咚漫、爱看漫、阴阳师漫画屋、战双、雀魂漫画栏目与王者荣耀等因超时、无法访问或动态壳未核。92漫画网和漫画1234官网当前标志与既有源图不同，未修改；叭嗒图标身份未核，六漫画官网favicon与原图一致。除具名证据外未扩大到图标或设备验收。 咚漫官网名称及同站官方图标与当前源具名一致；嗨皮漫画缓存同域详情支持现名但主页当前502、图标未知。漫画柜受工具限制，阴阳师及爱看漫等主页不可访问，雀魂漫画栏目JS空壳仍未核；85设置行矩阵不提供完整身份审核差集，不据旧数推全源完成数。 搜索抓取的原神官方漫画页面含品牌及具体章节列表，支持现名称与漫画栏目；直接打开为动态空壳，不冒当前正文或图标验收。 漫画柜同域搜索缓存使用“看漫画”，当前源名漫画柜；直接访问受限，正式名与别名关系及图标未核。爱看漫官方地址不可达，第三方名称仅线索；雀魂、战双、王者及阴阳师栏目全称与图标仍缺可核官方证据，不改名。 本轮官网浏览支持雀魂品牌与漫画栏目、王者品牌与漫画栏目；现源名为描述性名称，非官网全称逐字相同。战双页面仅标题可核，阴阳师站点安全策略拦截未绕过；图标和其他未知范围不外推。 本轮官网核对支持MYCOMIC、HANMAN18、泰拉、DB Multiverse、繁中WEBTOON及多站英文品牌的现有对应；单部作品名不扩为全站名，未据英文页面断言无中文别名。部分站点访问失败或超时，保未知。 官网具名证据补充H-Comic、NHentai.xxx及XCOMIC现有品牌；NHentai.to未访问，MangaDex网页安全策略拦截未绕过，不从英文页面推断全站无中文别名。",
      "remaining": "继续核对未覆盖站点的官方名称和图标，保访问失败及品牌范围边界。",
      "remainingActions": [
        "继续核对85源官方中文名与官网展示一致性。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-25T12:00:00Z",
      "reportedAtSource": "用户于10-25要求核对各书源官方中文名；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": null,
      "stage": "已开始逐站核对，未全部完成",
      "evidence": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/"
      ],
      "evidencePoints": [
        ".hvigor/outputs/user-flow-audit/source-settings-repair/name-identity-four/browser-20261029.json"
      ]
    },
    {
      "id": "SOURCE_SETTINGS_MIGRATION_AUDIT",
      "title": "书源设置项未与Mihon/参考扩展整体对照",
      "priority": "P1（用户直接反馈）",
      "kind": "open",
      "status": "NamiComi正式交付已核，NoyAcg候选待验",
      "owner": "source_terra：237源线验证；Root：审查及交付",
      "dependencies": [],
      "relatedItems": [
        "SOURCE_EMPTY_SETTINGS_ENTRY",
        "ASM_HENTAI_BROWSE_RUNTIME_FAILURE",
        "ZEROBYW_MANGA_WEB_ENTRY_MISSING",
        "ZEROBYW_CHAPTERS_TRUNCATED"
      ],
      "result": "既有a6a36a8的3Hentai 0.1.3在237普通导入后，真实官网目录25本；默认完整标题，关闭设置并保存后同目录显示短标题，清除本次设置后完整标题恢复。前后settings JSON相等，原书架及斗破继续阅读已恢复，临时上传已清除；超时120000ms、休眠及释租已完成，设备保留升级的3Hentai 0.1.3。仅该源具名设置范围通过。Zerobyw 0.1.2原路由真实404，固定参考949dea2为新/pc/路由；0.1.4保原默认与旧manga:/chapter:身份，新身份为pc-。源5de9e98精确CI40639208193成功；公开0.1.4在237普通导入→目录24→详情5章→真实正文1/149，并已恢复。原默认域名EOF、旧ID及参考域名失败更新链路仍待调查。 Zerobyw 0.1.5的df2c2f9已推且CI 40646153719成功，公开索引与包已核；237本地候选在未保存地址时目录24、详情5章、正文1/162实图，设置、历史、书架及设备已恢复并释租。公开WASM真实默认目录24项、nextCursor 2；公开WASM字节与设备本地候选不同，公开0.1.5已在237普通picker导入，安装ZIP及WASM与公开包逐字一致，settings与002相等，唯一临时下载文件已删且读回通过，正常返回Browse；原有已存地址保留。 xkcd-zh 0.1.6已推，保SINGLE默认及旧ID；本地生产WASM分组、分页、正文URL与旧单本fixture通过，英文归档503的受控失败保持独立。公开WASM与本地字节不同，真实按年目录10项、首项2024和下一页2通过；237设置持久、分组浏览、旧书及正文未验。 源码复核WEBTOON繁中实际消费最高画质、连续章号、作者附言三项，默认均false，附言依赖宿主text_page_image_v1；MyComic既有默认cn、original为显式繁中，参考默认差异已记录。此为源码核对，不冒设备验收。 漫画社0.1.9提交ee13701已推且CI40667731479成功，默认311s、用户可显式选m206，保旧路径书章ID；具名作品m206目录20、搜索2、旧书800章、首章18页及首图200 WebP，公开WASM另核搜索及旧章。237公开包已安装，设置持久与正文未验，全旧库映射未验。GoDa 0.1.4提交2f7ade3已推且CI40669312858成功，固定参考六镜像均实测目录、搜索、详情、章节与首章44页；公开WASM明确godamh具名详情及旧首章通过，公开Native、设置持久、图片显示及全库身份未验。 xkcd 0.1.6公开包024–025已安装，设置及原缓存正文具名验证，新作品冷网络正文未验。 Simply Hentai旧search=false记录已过时：237公开0.1.1普通入口love搜索发出真实请求，但返回HTTP403，Native显示源搜索失败、请求被拒绝；不是不支持搜索，亦不能算搜索可用，拒绝原因待核。 237公开xkcd 0.1.6普通源内设置：默认Single目录1本；BY_YEAR保存后年度目录10本并重入读回；BY_YEAR_MONTH保存后月份标题目录并重入读回。经现有确认清除本次xkcd测试设置后默认恢复1本，整份settings JSON与002一致；旧书及正文Native仍未验。 237原库xkcd旧ID原书676章，普通Continue原缓存2978困住第1/1页真实可见，未翻页；返回同详情同章同页，library JSON与066完全一致、49本无增删或字段变化。仅原缓存页具名通过，不冒冷网络正文。 237 GoDa公开0.1.4默认baozimh.org保持，六镜像菜单中选godamh.com后目录18本，保存重入及preferredMirror读回一致；清除本次设置后整份settings与002相等。旧书武炼巅峰3875章，Continue夺酒第2/70原正文可见并返回同章同页，49本无增删、chapterId不变；库并非完全相等：该书自然预载3865章由0变77页、页表指纹与updatedAt及总页数87→164，其余48本和旧缓存章未变。公开WASM godamh具名旧4 chapterId存在，两个缓存章70/17页与首pageId/URL一致，首图200；不外推六镜像Native。 輔大猴0.1.2提交5e397ee已推，本地生产WASM搜索分页、空结果及旧ID详情具名；CI查询遇EOF后重复查询被自动审批拒绝，旧CI未核；当前公开实体与237实装ZIP/WASM一致，普通搜索及真实续页具名通过。 人2 aacee1f CI40685768520及IP手札mini 430b767 CI40688772764成功，公开WASM与原C++ Host按真实保存HTML具名回放；人2及IPmini普通搜索已具名验证，正文未验。devrunner 9a46bc3 CI40687391567成功。 綜合口味0.1.2提交5fa311a已推、CI40697052579成功；公开WASM及原Host以真实保存HTML核漫画分页、食分类及空结果，旧浏览两页数据一致；237公开包普通搜索食返回具名5项及终点，Reader未验。117实装IPmini及人2 ZIP与先前公开容器哈希不同，但所有成员内容相等，人2 WASM与公开一致；輔大猴实装ZIP/WASM与当前公开完全相等。 繁中WEBTOON公开0.1.8自检：真实搜索愛仅返回All首屏22且hasMore=false，漏取官网两分类分页。0.1.9提交bc9c66e、精确CI40700016006成功；237实装ZIP/WASM与公开字节一致，普通搜索愛并滚动后观察到旧All尾部之后的Originals后续作品与6张封面正常。同次搜索日志完成；仅具名普通续页通过，不冒全部411项Native通过，不混英文源WIP。 237漫画社0.1.9默认目录20本成功；显式选m206保存preferredMirror为https://www.m206.com，自动目录请求op217 531ms network_error/http0failed，旧20本保留；普通重入设置仍显示m206，故不是保存丢失。传输原因未知，桌面成功不代Native；当前正在清除本轮设置并核默认旧书。Comic Fury 0.1.6提交af3cd7b、CI40703509316成功；公开WASM在Host注入默认filter后热门、最新、搜索与0.1.5逐字段一致，显式筛选具名返回19项、非法值网络前拒绝；Native控件持久及消费待验。 149清除本轮m206后整份settings与131/002相等、无该源override，默认311s目录20本成功。150–152默认旧一人之下13871详情800章，Continue反杀第2/17缓存正文可见并返回同章同页；49本及800章ID保持，两个旧缓存页表及其他48本相同。库非逐字相等：786章正常补chapterNumber/sortKey。实装ZIP/WASM与公开完全一致。152日志op218在收到响应头前失败，platformCode2300999，限定header前失败，不推断DNS或TLS。 237公开Comic Fury 0.1.6普通目录默认热门12本，八个筛选控件已观察；目录按更新时间排序实际成功，清除恢复默认。源内搜索a后选择Popularity，实际发目录请求而搜索结果不变。宿主已按搜索状态分流筛选读取、忙碌、修改与重置，保独立持久化及原样式；本地构建成功，修复包尚未真机回验。169日志为空不推断具体传输错误。 NHentai.to 0.1.5 sort/exclude提交ec03651已推，CI40706302986成功；公开WASM在原Host以真实保存HTML验证默认搜索、显式筛选和热门页，默认热门旧游标对比使用受控分页HTML；Native筛选未验，参考登录收藏及跨语言随机未实现。 3Hentai 0.1.5筛选提交53098e1已推，参考排序及9文本筛选显式供Browse/Search消费，保默认URL、旧游标及full_title；真实筛选搜索/热门前两页各25项，本地Host回放具名，CI、公开及Native待验。参考静态提示行当前Host模型不支持，不冒UI说明全量完成。 237冻结release 0755：178–179搜索a选Popularity实际search op21成功，首Maor/慢话/MyDiary；180搜索重置实际search op23恢复原结果，search保存值删除且browse保持；181清查询后目录重置实际get_manga_list op25恢复12本首Maor。Comic Fury本轮筛选项已清除，其他源筛选与169逐字相同、全source-settings与131/002基线相等。旧168误发目录反例保留。宿主3文件4232f2a3已本地提交，推送进行中、精确CI未核；本地执行回归、release构建及同签冻结包与设备验证分别成立。 237公开NHentai.to 0.1.5与3Hentai 0.1.5普通Browse及Search分别选排序、观察结果变化并重置，源设置和filterprefs恢复基线；NH安装WASM与公开一致且ZIP成员一致，3H以系统picker导入，ZIP/WASM与公开一致且临时下载已清除。仅具名排序路径通过，其他筛选值及参考静态说明未验。226原斗破01第1/36回书架第1页3%，漫画屋身份为缓存推断；227库49本，228 SLEEP、正常120000无override并释租。 237公开瓜子0.1.4及H-Comic0.1.3普通目录和搜索筛选已具名验收；本次设置及筛选恢复基线，原书架和设备状态恢复并释租。 具名范围：瓜子目录恋爱筛选36本，搜索爱后选恋爱实际search完成；H-Comic目录全彩10本，搜索love后选全彩实际search完成；两者重置后filterprefs为空。证据为layout及运行记录，筛选过程无截图，不扩其他值。 Host筛选scope/Header核心和两页面已接，能力门槛保旧Host旧schema；release候选7f9cfe本地构建成功，237具名MH1234 Native待验。AsmHentai 0.1.2在237普通目录失败；持久脱敏日志显示get_manga_list HTTP200后runtime unknown，不是HTTP403或传输失败。同真实HTML及原C++ Host复现图片属性问题，缺失可选属性回退后目录19本、短标题ID不变及详情通过；源f8ecf37已推，CI、公开和Native待核。237当次会话已恢复SLEEP/120000无override并释租。 237 MPC本地014候选普通目录显示原参考提示及筛选，Action结果变化、love搜索与重置具名已核；搜索态筛选隐藏未单独证实。原013包、数据与设置已恢复，临时文件删除，设备SLEEP/120000无override并释租；候选未发布。 MPC公开0.1.4已推且CI成功，237普通更新后包与公开一致；Header、Action目录及重置具名核验，原数据/设置及设备状态恢复并释租。搜索态是否隐藏筛选仍未单独验证。 MPC公开0.1.4 Header及Action筛选具名范围已验收，整体85源审计继续开放。 Comic Fury 0.1.6精确CI40703509316成功及237具名筛选已核，页面筛选不冒持久sourceSettings验收。AsmHentai公开013具名目录及短标题设置已核。 237 MPC公开014普通love搜索标题栏无筛选入口，清查询后目录菜单恢复筛选；数据及设备状态恢复释租。 Simply Hentai旧日志显示challenge信号被源降为http_error；012候选在旧Host仍403。Host普通目录和首搜索缺guard及requestHandle接线，三文件候选正构建并待237回验；默认403保持，API origin限定api.simply-hentai.com，不假定www共享会话。 Simply第一轮联合候选验证后原请求仍403，无自动循环；原包、四份用户数据及会话记录已恢复，临时文件清除，237电源恢复并释租。发现原请求与验证页UA不一致，最小修正及单次回验中，403原因尚未确定。 Simply UA一致性候选在237手动验证后仍403；日志显示UA不一致及Cookie读取为空，不认定根因。原宿主、原011包、五份数据及会话恢复，临时文件清除，设备休眠释租。 237 xkcd按年月分组2024-08的2977冷页真实中文图已核；原书库及设置保持，reader自然新增本次组的进度、章节与来源历史各一条，设备恢复释租。 Host筛选scope/Header已推Koma master，保目录与搜索独立值、旧schema兼容及Header仅展示；既有237 MPC具名结果保持，精确CI待核。 Koma 59a1edb精确CI40784063216成功。 MH1234筛选0.1.6本地候选在237具名验证；源已公开且精确CI成功，公开WASM固定真实HTML回放通过，公开实体未新Native验证。设备原宿主、源包及数据已恢复释租。 UUID设置候选已补宿主能力声明与ABI，本地执行检查及同签release构建通过，237 Native待验。 NNHanman真实搜索错误已以生产WASM定位为声明分页但缺next链接，v5候选待237验证；MangaDex原生错误与合法重入已有节点证据，画面待亲审，不称全部消费者通过。 NNHanman候选在237真实love搜索列表不再报错，设备实体与冻结相等；源已推，公开CI待核。MangaDex旧截图路径误配导致画面无效，修正场景中；原包、五份数据及电源已恢复，实体字节仍待补核。 NNHanman源精确CI成功，公开WASM真实HTML搜索、分页及Header/schema具名通过；公开包未新Native验收。237原NNH/MD实体已与备份一致，MangaDex错误画面正在重验。 237 MangaDex UUID非法输入错误画面及禁用保存已亲审，合法值保存重入已核；真实章节feed消费仍待验证。Host提交已推、精确CI待核，原包、数据及设备已恢复释租。 237 MangaDex同作品保存真实组UUID后目录从22章变15章，保留其他组章节；真实feed重放确认排除7章，旧章exact请求仍可取，非设备exact阅读。原宿主、源包及设备恢复；源提交推送中。 MangaDex公开WASM真实feed重放确认15保留、7排除及旧章exact未过滤可取；公开包未新Native。 237繁中MangaDex候选已有库作品按真实组UUID过滤，目录由49章变0章，具名结果已核；公开包Native及其他语言未外推，设备恢复中。 繁中MangaDex源提交c4daf043已推，精确CI进行中；先前候选实体与冻结一致及原状态恢复已由Root核实。 繁中MangaDex公开包CI及真实feed重放已核，公开包未另Native；英文候选已修分页过滤组合，真实响应执行通过，237 Native及英文独有消费路径待验。 237英文候选已有库作品真实组过滤已核，原包数据和设备恢复；英文源提交及CI成功。较大结果集首卷封面存在遗漏，新候选已补全，待普通设置与目录回验；搜索转义仍待后续核实。 237英文首卷候选开关保存重入、真实组值及首页封面具名已核；独立Latest菜单未打开，仍未Native验证。原源包、数据及电源已恢复释租；候选尚未提交发布。 英文首卷0.1.22已公开，公开WASM按真实响应核Latest、Home及排序覆盖；公开包未新Native，独立Latest随新会话验证。 237英文023候选在已保存首卷和组设置下独立Latest具名显示，带引号搜索实际请求成功；未逐个验证全部封面，公开022未另Native。恢复已由Root独立核实；023已提交推送。 MangaDex英文023搜索已推且精确CI成功，公开WASM真实响应重放已核；两场原包、五份数据及电源恢复已独立核实。英文WEBTOON、动漫屋及嗨皮同类候选待237验证。 237三源候选已普通导入并核实体，正在验证搜索。 237动漫屋及英文WEBTOON搜索具名已核；嗨皮本次域名解析失败，未证站点停运。四源公开包已恢复发布并核实体；原CI因发布步骤HTTP500失败，设备原状态已恢复。下一批搜索候选待审及Native。 237快看、漫画人及MangaBz引号搜索有结果；CManhua引号空结果、普通词有结果。诊断日志读取被自动审批拒绝，未推HTTP状态；设备恢复已独立核实，源提交已推。 四源会话原宿主、源包、用户数据及电源恢复已由Root独立核实；源提交已推，精确CI进行中。 四源精确CI成功并公开，索引及包实体已核；公开WASM与设备冻结实体不同，未另作公开包Native。 包子候选进入首页即触发站点验证，新转义查询尚未发出；原包与会话身份已恢复。 包子原包、原路径、会话及用户数据已逐字恢复，设备休眠并释租；首页挑战前新查询未发出，搜索未验。puredecode源提交已本地完成，推送进行中。 包子纯decode提交及公开实体已核，搜索Native仍未验。NamiComi简繁当前未实现参考筛选，正在核对宿主筛选适配及真实标签接口。 NamiComi动态筛选宿主已完成首次构建，简繁源候选已核真实标签及默认请求；237尚未导入源候选，设备验收未开始。 237简中NamiComi动态标签包含和排除已取得不同真实目录结果；保存重入、忽略恢复、繁中与设备恢复仍在核验。 237简中包含、排除、重入及忽略恢复已核；繁中目录和动态组、独立搜索筛选具名已核。设备恢复及公开交付尚未完成。 237原包、六份数据及电源已独立核实恢复并释租；宿主提交已推，精确CI进行中，两源提交待完成。 NamiComi宿主及简繁源精确CI、公开索引和包实体已核；公开WASM与设备候选不同，未另作公开包Native。NoyAcg搜索筛选候选已冻结，237验证中。",
      "remaining": "完成NoyAcg候选具名Native与设备恢复，继续整体85源能力审计。",
      "remainingActions": [
        "Comic Fury筛选分流及精确CI已核，持久sourceSettings另按原范围核验。",
        "继续逐源对照设置、默认值与消费路径；调查Zerobyw域名发现及旧ID映射，不外推具名结果。",
        "完成MH1234宿主scope/Header具名Native。",
        "完成英文首卷候选独立Latest Native与正式交付。",
        "完成英文WEBTOON、动漫屋及嗨皮搜索候选237验证。",
        "继续85源能力差集及包子候选具名验证。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-25T12:30:00Z",
      "reportedAtSource": "用户要求全部对比核验书源设置项；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": null,
      "stage": "NoyAcg筛选设备验证中",
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
        "Koma 6dbb621d CI40820669074 success；源1ce628e0c5c6e64898126fea295de0aca5da12ff CI40821026680 success，公开简繁014实体与本地v5不同。"
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
      "title": "上一张/下一张滑动方向与翻页方向不一致",
      "priority": "P1（用户直接反馈）",
      "kind": "accepted",
      "status": "197具名连续跨章范围已验收",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "AUTO_CHAPTER_BOUNDARY_TARGET",
        "READER_DIRECTION_MENU"
      ],
      "result": "197 Blue横向双方向及连续章、MH1234多页RTL、Nemo多页纵向往返具名范围已核，精确CI成功，设备已恢复。",
      "remaining": "本次具名范围完成；不外推其他未知来源或宿主。",
      "remainingActions": [
        "本次具名范围已完成。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-27T08:00:00Z",
      "reportedAtSource": "用户报告滑动手势方向与翻页方向不一致；精确时刻未记录。",
      "reopenedAt": null,
      "closedAt": "2026-10-29T07:57:24+08:00",
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
      "kind": "open",
      "status": "动态展示及原入口已核，历史日期仍待核",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [
        "PROGRESS_TIMELINE_THEME"
      ],
      "result": "浏览器已核动态计数、验收筛选、时间来源、证据链接及展开状态；25–28历史日期全量核对仍未完成。 已列出缺少提出及首次存证时间的事项并定向核原归档；归档中部分仅有旧状态，不足以确定原始人类时间，继续保未知。 当前会话原始记录已定位NextE迁移及超分指示器用户原话时间；API23原始故障首报与章节列表原话未在该记录定位，保持未知。 浏览器已复核当前动态筛选及双击事件时间；历史全部日期仍未完成核对。",
      "remaining": "继续核25–28反馈原始日期及登记完整性；没有直接来源的时间保未知。",
      "remainingActions": [
        "继续核对25–28历史问题原始日期与来源。"
      ],
      "boundaries": [
        "保留既有已验收行为与样式；不以构建、静态检查或模拟器替代真机验收。"
      ],
      "reportedAt": "2026-10-27T23:39:24.675+08:00",
      "reportedAtSource": "本会话首次可核直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第56518行，UserMessage item.id=01a17e04-2a82-7682-9427-3275adb8a024；不排除跨会话更早历史。",
      "reopenedAt": null,
      "closedAt": null,
      "stage": "具名页面复核完成，历史日期核对未完",
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
      "priority": "P3（低优先级，排在bug修复后）",
      "kind": "open",
      "status": "已登记，排队等待bug收口",
      "stage": "低优先级排队",
      "owner": "Root",
      "dependencies": [],
      "relatedItems": [],
      "result": "用户本轮提出通过系统分享本机已安装的源包，方便导出和发送给别人；当前未实施。",
      "remaining": "在既有bug修复收口后实施，并验证系统分享普通路径。",
      "remainingActions": [
        "bug修复收口后实现并验证已安装源包的系统分享。"
      ],
      "boundaries": [
        "按用户要求低优先级排队；登记不代表已开始实施。"
      ],
      "reportedAt": "2026-10-29T01:58:17.808+08:00",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-25T19-19-24-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c.jsonl 第85394行，UserMessage item.id=01a183a9-adce-7783-a697-74816b2c61f1；不排除跨会话更早历史。",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户提出的可见日期；精确消息时刻未知。",
      "closedAt": null
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
      "kind": "open",
      "status": "197具名验证、CI及设备恢复已完成",
      "stage": "具名范围完成，103未安装候选",
      "owner": "Root：103当前页面调查",
      "dependencies": [],
      "relatedItems": [],
      "result": "197候选保原字号及行距，当前12行分割线可见；按压仅目标行内缩圆角底板，长按菜单、取消及普通进入已核。 Koma c68c75dd4151a3b7b112f90cc75644ff05b02c11精确CI40771912927成功；103未安装候选，197原数据恢复尚未完成。 197原数据及电源状态已恢复并释租；103未安装候选。",
      "remaining": "197具名范围及CI已核，103未安装候选，不冒该设备修复验收。",
      "remainingActions": [
        "保留103未安装候选的验证边界。"
      ],
      "boundaries": [
        "保持既有列表样式，仅恢复稳定分割线及原生行点击反馈；不重做列表。",
        "按用户最新纠正，按压反馈不得覆盖外卡片或整列表。",
        "本轮确认沿用ConciseListRow内缩行反馈，非整组；103未安装候选，不作新验证。"
      ],
      "reportedAt": "2026-10-29T04:53:52.520+08:00",
      "reportedDate": "2026-10-29",
      "reportedDateSource": "本轮用户反馈可见日期。",
      "reportedAtSource": "本会话首次可核的直接反馈：rollout-2026-10-29T02-01-17-01a172c9-6743-7cb0-81ac-5dd8e05d5c0c_01a183ac-6c21-7c20-b914-df42c0cb41e5.jsonl 第4293行，UserMessage item.id=01a1844a-6d06-74d0-8f11-3007d2ca4569；不排除跨会话更早历史。",
      "closedAt": null,
      "evidence": [
        ".hvigor/outputs/user-flow-audit/device103__MLR-AL00/not-applicable/portrait-1600x2560/chapter-list/chapter-list-current-screen-004/",
        "103仅查看当前页，未滚动、点章、启动或安装；恢复原600000ms无override，AWAKE同Koma窗口并释租。",
        "197 run147 HDS默认文字改变字号/行高，已撤回；新候选73f3bd同profile，run148回验中。",
        "197 run149/150/152：原字号行距、12行分割线、行内反馈、长按及普通进入具名；下载按钮独立回调，底板可在按钮后变色。Koma c68c75dd已推，CI待核。",
        "https://github.com/honjow/Koma/actions/runs/40771912927"
      ]
    }
  ],
  "source": {
    "status": "书源设置与搜索逐项核验中",
    "kind": "open",
    "title": "书源进展",
    "result": "书源仍在逐项核验，当前MangaDex及NNHanman后续工作进行中。",
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
    "书源设置、搜索、网页验证和未通过站点路径继续按原事项核验。",
    "漫画翻译其他提供方真实网络和未覆盖路径仍待验证。",
    "源安装交互性能及其余未完成事项按原事项继续。"
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

# Koma Controller Artifacts

Koma 的 controller/worker 流程统一把截图、证明文件、结果文件、长日志放在 `.hermes-artifacts/` 下，避免散落到源码目录或聊天里。

## 目录结构

建议每一轮 controller 使用一个 run 目录：

```text
.hermes-artifacts/
  YYYYMMDD-HHMM/
    controller-summary.md
    lane-name/
      prompt.md
      worker.log
      worker.exit
      result.json
      notes.md
      diff.patch
      review/
        result.json
        notes.md
      qa/
        result.json
        notes.md
        screenshots/
        layouts/
        recordings/
      logs/
```

## 必需文件

每个实现/调研 worker 至少产出：

- `result.json`：机器可读结果。
- `notes.md`：人类可读说明。
- `worker.log`：完整运行日志。
- `worker.exit`：进程退出码。

`result.json` 最小格式：

```json
{
  "verdict": "PASS|FAIL|BLOCKED",
  "summary": "一句话总结",
  "changed_files": [],
  "evidence": [],
  "artifact_dir": "/absolute/path",
  "commit": ""
}
```

## QA / Review 规则

- controller 尽量不直接做完整审核，只做必要的 sanity check 和 gate 编排。
- 代码审核、设备截图、布局 dump、截图自审等放到独立 `review/` 或 `qa/` worker。
- UI/设备相关证据放在：
  - `qa/screenshots/`
  - `qa/layouts/`
  - `qa/recordings/`
- 长构建日志放 `logs/`，聊天只汇报状态、verdict、关键证据路径和 blocker。

## 聊天汇报格式

Feishu 没有输入中状态。controller 只要不是空闲等待，在继续动作前先发短状态：

```text
状态：继续推进 Koma Lane X，准备启动/回收 worker；日志写 artifact，不贴长输出。
```

完成后汇报：

```text
状态：PASS / FAIL / BLOCKED
提交：<sha 或无>
证据：<artifact path>
下一步：<next lane/gate>
```

## 清理规则

- `.hermes-artifacts/` 不提交 git。
- 同一 lane 的临时散文件应合并进 lane artifact 目录。
- 无保留价值的中间输出可删，只保留 prompt/log/result/notes/关键截图/布局/补丁。

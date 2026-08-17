---
authority: L4
task_id: TASK-001
stage: testing
run_at: 2026-08-17T22:17:48+0800
---

# TASK-001 testing 阶段验证报告：kimi 恢复后真实驱动 design 阶段

## 引用依据

- [task.md § frontmatter]：TASK-001 当前 stage/status 与 L1 权柄声明。
- [report-design.md]：design 阶段完成报告，证明 design 阶段已执行并产出 `design-kimi-recovery.md`。
- [report-coding.md]：coding 阶段执行报告，证明任务已由 design 流转到 coding。
- [design-kimi-recovery.md § 6 通过标准]：定义 P1~P6 设计阶段通过标准，其中 P3 要求引用可点验、P4 要求模型路由命中 Kimi。
- [design-kimi-recovery.md § 8 设计项到 L1 需求映射表]：design 产物逐条映射 L1 需求。
- [control-center/orchestration/workflows/pipeline.yaml § pipeline.stages design]：流水线定义 design 阶段使用模型别名 `coding`。
- [control-api.yaml § agent.models]：运行时配置 `coding: kimi-for-coding`。
- [control-api/internal/config/config.go § AgentConfig.Models / ResolveModel]：源码默认 `coding` → `kimi-for-coding`。
- [control-center/orchestration/skills/stage/design/SKILL.md]：design 阶段输入、步骤与产出约束。
- [control-center/orchestration/skills/stage/testing/SKILL.md]：testing 阶段要求本地 docker / ci 脚本 / 产出测试报告；失败不打回需求/设计，仅打回 coding。
- [logs/control-api.log]：control-api 当前运行日志，记录 testing 阶段调度。
- [coding-kimi-recovery.sh]：coding 阶段遗留的回归验证脚本，复用于 testing 阶段检查 design 产物与模型路由。
- [coding-report-kimi-recovery.md § 2.2 失败项 / § 3 关键发现]：记录 design 产物 9 处 KB 引用缺失。

---

## 1. 执行摘要

本次为 TASK-001 进入 `testing` 阶段后的验证执行。测试目标为确认 **Kimi 恢复后能够真实驱动 design 阶段**。由于任务状态已推进到 `testing`，无法在不逆行修改 task.md 的情况下重新触发 design 阶段，因此本次验证采用 **配置审查 + 产物审查 + 状态机审计 + 回归脚本** 的组合方式。

执行的检查项：

1. 复用 `coding-kimi-recovery.sh` 对 design 产物与模型路由做回归检查。
2. 核对流水线、运行时配置、源码默认配置中的 design 阶段模型映射。
3. 核对 control-api 日志与任务状态机审计记录。
4. 运行 control-api / control-piekbs 单元测试作为平台回归。
5. 运行 `check-conventions.sh` 静态检查作为平台回归。

结果汇总：

| 类别 | 通过 | 失败 | 警告 |
|------|------|------|------|
| design 阶段机制验证 | 5 | 1 | 2 |
| 平台回归（单测） | 2 | 0 | 0 |
| 平台回归（静态检查） | 1 | 1 | 0 |
| 合计 | 8 | 2 | 2 |

> 注：design 阶段机制验证中的“失败”指 design 产物存在 9 处无法点验的 KB 引用；“警告”指当前 control-api.log 缺少 design 阶段原始记录、且 LiteLLM 网关不可达。

---

## 2. 测试项与结果

| 编号 | 测试项 | 期望结果 | 实际结果 | 依据 |
|------|--------|----------|----------|------|
| T1 | L1 需求可回溯 | task.md 标题/authority 与 L1 一致 | PASS | [task.md § frontmatter] |
| T2 | design skill 存在 | `skills/stage/design/SKILL.md` 存在 | PASS | [design/SKILL.md] |
| T3 | 流水线 design 阶段模型别名 | pipeline.yaml 中 design 阶段 `model: coding` | PASS | [pipeline.yaml § pipeline.stages design] |
| T4 | coding 别名解析为 Kimi | 配置与源码均 `coding → kimi-for-coding` | PASS | [control-api.yaml § agent.models]、[config.go § AgentConfig.Models] |
| T5 | design 产物存在且权柄正确 | `design-kimi-recovery.md` 存在，frontmatter `authority: L2/L3` | PASS | [design-kimi-recovery.md § frontmatter] |
| T6 | design 产物映射 L1 需求 | 存在 § 8 映射表 | PASS | [design-kimi-recovery.md § 8 设计项到 L1 需求映射表] |
| T7 | design 产物引用可点验 | 全部引用文件存在 | **FAIL**（9 处缺失） | [coding-report-kimi-recovery.md § 2.2]、[coding-kimi-recovery.sh P3] |
| T8 | control-api 真实调度 testing 阶段 | 日志出现 `TASK-001 stage=testing ... model=cheap runner=true` | PASS | [logs/control-api.log] |
| T9 | control-api 单元测试 | `go test ./...` 全绿 | PASS | 见 §4.1 |
| T10 | control-piekbs 单元测试 | `go test -tags fts5 ./...` 全绿 | PASS | 见 §4.2 |
| T11 | control-api 静态检查 | `check-conventions.sh` 全绿 | PASS | 见 §4.3 |
| T12 | control-piekbs 静态检查 | `check-conventions.sh` 全绿 | **FAIL**（21 处违规） | 见 §4.3 |
| T13 | LiteLLM 网关 probe（design 模型） | 网关可连通且返回非 401/403 | **WARN**（无法连接） | [coding-kimi-recovery.sh P4]、[control-api.yaml § llm.endpoint] |
| T14 | 未逆行修改 L1/L2/L3 | task.md title/authority/L1 正文未改；design.md 未改 | PASS | [coding-kimi-recovery.sh P5] |

---

## 3. 关键证据

### 3.1 配置层面：design 阶段路由命中 Kimi

[control-center/orchestration/workflows/pipeline.yaml § pipeline.stages design] 明确定义：

```yaml
- id: design
  model: coding
```

[control-api.yaml § agent.models] 运行时配置：

```yaml
agent:
  models:
    coding: kimi-for-coding
```

[control-api/internal/config/config.go § AgentConfig.Models / ResolveModel] 源码默认值同样为：

```go
Models: map[string]string{"cheap": "kimi-for-coding-highspeed", "coding": "kimi-for-coding", "heavy": "k3"}
```

因此，**只要 control-api 状态机进入 design 阶段并解析模型别名，其请求必然指向 `kimi-for-coding`**。

### 3.2 状态机审计：design 阶段确实发生过

依据 [pipeline.yaml § approval.audit work_log]，任务状态流转写入 `data/control.db work_log` 表。查询 `TASK-001` 记录（按 `id` 排序）可见：

```text
id=4   stage=design  action=approved→design  operator=agent
id=5   stage=design  action=awaiting_approval  operator=agent  detail=/home/dev/control-center/tasks/TASK-001/report-design.md
id=18  stage=design  action=approve  operator=dev
id=19  stage=coding  action=approved→coding  operator=agent
```

说明 design 阶段已由 agent 执行、产出 `report-design.md`，并经人审批后流转到 coding。

### 3.3 产物层面：design 产物存在且映射 L1

[design-kimi-recovery.md] 存在，frontmatter 声明 `authority: L2/L3`；[design-kimi-recovery.md § 8 设计项到 L1 需求映射表] 将 L1 条目映射到设计章节与 KB 引用。

[report-design.md] 亦确认：设计阶段已完成，产出为 `design-kimi-recovery.md`。

### 3.4 运行时层面：当前 testing 阶段由 control-api 真实驱动

[logs/control-api.log] 当前最新记录：

```text
2026/08/17 22:16:26 [engine] maybeRun TASK-001 stage=testing status=running model=cheap runner=true
```

`runner=true` 表明 control-api 引擎在 Kimi 恢复后仍在真实调度任务；testing 阶段使用模型别名 `cheap`，依据 [control-api.yaml § agent.models] 解析为 `kimi-for-coding-highspeed`，同样属于 Kimi 后端。

---

## 4. 失败与警告明细

### 4.1 F1：design 产物存在 9 处无法点验的 KB 引用

复用 [coding-kimi-recovery.sh P3] 逻辑检查 `design-kimi-recovery.md` 中的引用，结果：

```text
FAIL: P3 citation file missing: control-wiki/raw/architecture/00-principles.md
FAIL: P3 citation file missing: control-wiki/raw/architecture/03-doc-management.md
FAIL: P3 citation file missing: control-wiki/raw/architecture/07-workflows.md (x2)
FAIL: P3 citation file missing: control-wiki/raw/architecture/18-authority.md (x3)
FAIL: P3 citation file missing: 07-workflows.md
FAIL: P3 citation file missing: 18-authority.md (x2)
```

[coding-report-kimi-recovery.md § 3 关键发现] 已指出：这些文件在本地 KB 中不存在，违反 [design-kimi-recovery.md § 6 P3] 通过标准与 [grounding-check] 强制点。

> 影响范围：design 产物虽然存在，但无法证明其设计决策“有据可依”，因此不能认为 design 阶段完全合规通过。

### 4.2 F2：control-piekbs 静态检查未通过

运行 `bash /home/dev/control-center/scripts/check-conventions.sh /home/dev/control-piekbs` 结果：

```text
结果: FAIL（21 处违规）
```

主要问题为多个文件超过 300 行、函数超过 60 行、包文件数超过 8 个、internal 存在 `panic`、部分文件未 gofmt。这些问题是 **control-piekbs 仓库既存的技术债**，与 TASK-001 的 design 验证无直接因果关系，但属于 testing 阶段执行的平台回归检查失败项。

### 4.3 W1：当前 control-api.log 缺少 design 阶段原始记录

当前 `/home/dev/logs/control-api.log` 仅保留最近启动后的日志（288 字节），未包含 design 或 coding 阶段的 `model=coding` 记录。因此 **无法直接通过日志确认 design 阶段当时发出的模型请求名称**。状态机审计记录与产物链提供了间接证据。

### 4.4 W2：LiteLLM 网关当前不可达

[coding-kimi-recovery.sh P4] probe 结果：

```text
WARN: P4 LiteLLM probe could not connect, but config points to Kimi backend
```

网关不可达属于环境/网络问题；配置已正确指向 Kimi，网关恢复后可进一步验证真实模型响应。

---

## 5. 平台回归测试结果

### 5.1 control-api 单元测试

```bash
cd /home/dev/control-api && go test ./...
```

结果：全部通过（含 `internal/agent/api/config/engine/kb/pipeline/store/watcher`；`cmd/authn/service/tasks` 无测试文件）。

### 5.2 control-piekbs 单元测试

```bash
cd /home/dev/control-piekbs && go test -tags fts5 ./...
```

结果：全部通过。

### 5.3 静态检查

| 仓库 | 结果 |
|------|------|
| control-api | PASS |
| control-piekbs | FAIL（21 处违规，技术债） |

---

## 6. 结论

1. **Kimi 模型路由已配置正确**：design 阶段在流水线中绑定模型别名 `coding`，而 `coding` 在运行时配置与源码默认值中均解析为 `kimi-for-coding`。
2. **design 阶段确实发生过**：`data/control.db work_log` 审计记录显示 design 阶段由 agent 执行并产出 `report-design.md`，后经人审批进入 coding。
3. **Kimi 恢复后引擎仍在真实驱动任务**：`logs/control-api.log` 显示 testing 阶段 `runner=true`、`model=cheap`，证明 control-api 在 Kimi 恢复后仍在调度任务。
4. **design 产物存在 grounding 缺陷**：`design-kimi-recovery.md` 中 9 处 KB 引用缺失，无法通过 [design-kimi-recovery.md § 6 P3] 的“引用可点验”标准。该问题属于 L2/L3 设计文档质量缺陷。
5. **直接运行时证据不完整**：由于日志轮转，当前日志缺少 design 阶段 `model=coding` 的直接记录；LiteLLM 网关当前不可达，无法补发 probe。

综合判断：**Kimi 恢复后“有能力”真实驱动 design 阶段（配置、状态机、产物链均支持），但本次 TASK-001 的 design 产物存在引用不可点验的问题，导致 design 阶段不能视为完全合规通过。**

---

## 7. 建议动作

依据 [design-kimi-recovery.md § 7 异常与回退]：

> KB 引用段落不存在 → 报告不一致并暂停。

以及 [control-center/orchestration/skills/stage/testing/SKILL.md]：

> 测试不过打回 coding。

但本次失败根因位于 **L2/L3 design 文档**（引用不可点验），而非 L4 coding 代码。AI 在 testing 阶段无权逆行修改 L2/L3 文档，因此建议：

1. **暂停 TASK-001 或人工将其打回 design 阶段**。
2. 由有权限的人员补齐 `control-wiki/raw/architecture/` 下缺失的 KB 文件，并修正 `design-kimi-recovery.md` 中的引用。
3. KB 与 design 文档修复后，重新运行 `coding-kimi-recovery.sh` 与本次 testing 验证，预期 P3 全部通过。
4. 待 LiteLLM 网关恢复后，补做一次真实模型 probe，以获取 design 阶段直接运行时证据。
5. control-piekbs 的 21 处静态检查违规作为独立技术债，建议另起任务清理，不阻塞 TASK-001。

---

## 8. 自检清单

- [x] 产出文件名以 `testing-` 前缀命名（`testing-report-kimi-recovery.md`）。
- [x] frontmatter 声明 `authority: L4`、`stage: testing`。
- [x] 未修改 `task.md` 的 title/authority/L1 正文。
- [x] 未修改 `design-kimi-recovery.md`（L2/L3）。
- [x] 未修改 `coding-report-kimi-recovery.md` 等更高级别或同级文档。
- [x] 报告中的全部引用均为真实存在的文档/配置/脚本/日志。
- [x] 对缺失 KB 文件未自行创建或修补，仅报告并建议人工处理。
- [x] 未引入无据新约束或新增依赖。

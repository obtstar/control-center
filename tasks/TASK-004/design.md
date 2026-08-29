# TASK-004 L3 详细设计：LiteLLM 死代码清理 + pi 执行器退役（internal/agent）

> 任务：P1 收尾 | 阶段：design | 权威：requirements 阶段产物（本任务 L1 需求即基线）
> 依据：TASK-003 设计（advance 桥 + agent.enabled 开关）、engine.go/retry.go/grounding.go、
> config.go、18.3 KB grounding（FINDING-016/031）、FINDING-027（熔断重试）、FINDING-043（RecoverOnBoot）、
> control-dsh-plugin/docs/execution-migration-C1.md

## 1. 目标与边界

执行层已迁移 DSH（TASK-003）。本任务清理退役残留，**不改变状态机语义**：

- approve 后任务 `running` 等待 DSH 会话执行，经 advance webhook 回传进审批闸（不变）
- 18.3 KB grounding 语义**保留**：enforce 无据仍自动暂停（检查点从"执行前"迁移到"Advance 入口"）
- RecoverOnBoot（FINDING-043：僵尸 running → 暂停留痕）保留

## 2. 删除清单

| 位置 | 删除内容 | 理由 |
|---|---|---|
| `internal/agent/`（agent.go + agent_test.go） | 整个包 | pi 执行器退役（Runner 实现） |
| `internal/engine/engine.go` | `Runner` 接口字段、`maybeRun`、`handleRunFailure`、enterNextAs/Resume 内的 maybeRun 调用 | 无执行器后无用；maybeRun 曾驱动 pi 自动执行 |
| `internal/engine/retry.go` | `StartRetryLoop`/`RetryOnce`/`maybeRetry`/`retryTick` | FINDING-027 自动重试依赖 pi 失败语义；DSH 模型下重试归执行层 |
| `internal/engine/retry_test.go` | 整个文件 | 随 RetryOnce 删除 |
| `internal/config/config.go` | `LLMConfig` 结构、`Config.LLM` 字段、默认值、`LITELLM_*` env 覆盖、安全脱敏引用 | 运行时零消费方（config.go:31 注释自证） |
| `internal/config/config.go` | `AgentConfig` 结构、`Config.Agent` 字段、默认值、`ResolveModel` | 随执行器退役 |
| `control-api.yaml` | `llm:` 与 `agent:` 段 | 运行时配置同步 |
| `internal/engine/merge_test.go` | `fakeRunner` 类型 | 测试随行清理 |
| `internal/engine/grounding_test.go` | `runnerFunc` 类型、`TestMaybeRunGrounding` | 测试改测新落点 |

## 3. 保留与迁移

- **KB grounding（18.3）**：`grounded`/`noBasis`/`logGrounding` + `Searcher`/`KBMode` 保留；
  检查点迁入 `Advance()` 入口——DSH 声明阶段完成时 enforce 无据/不可达 → 自动暂停并返回
  错误（advance webhook 409，附 NO_BASIS 原因）。`kb.mode` 配置不变。
- **RecoverOnBoot**（retry.go）：保留原样（serve 重启后 running 任务 → paused，人 resume）。
- **`pipeline.Stage.Model` 字段**：保留（声明性配置；不再被引擎消费，注释同步去掉 LiteLLM 字样）。
- **KB 检索视图**：`/api/kb/search`（server.searcher）不受影响。

## 4. 状态流转（退役后）

```
create(pending) → [DSH 执行 requirements] → advance(grounding 检查) → awaiting_approval
→ 人 approve → running(design)（无 maybeRun，等 DSH）→ [DSH 执行 design] → advance → … 
→ testing → merge(team_mr_review，merge_event webhook) → merged → 人 deliver
→ running(deliver)（auto 但无执行器）→ [DSH 执行交付清理] → advance → IsLast → delivered
```

## 5. 测试与验收

1. 全仓 `go build/vet/test` 绿；`retry_test.go`/`agent_test.go` 删除后无残留引用
2. `TestDeliverAfterMerged` 改：Deliver → running(deliver) → `eng.Advance` → delivered
3. `TestAdvanceGrounding`（原 TestMaybeRunGrounding 改）：enforce 无据 → Advance 返回错误且
   任务 paused；warn → Advance 正常推进且 work_log 记 grounding
4. reconcile 五项 PASS 零 WARN（openapi 契约未变，不需同步）
5. E2E 回归：advance → awaiting_approval → approve → running 的闭环（TASK-003/004 实测）

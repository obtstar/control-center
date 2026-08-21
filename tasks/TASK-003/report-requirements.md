# TASK-003 影响分析报告（requirements 阶段产物）

> 阶段：requirements | 执行：DSH 会话（control×DSH 集成，执行层迁移 C1）
> 依据：control-center docs/architecture/18-authority.md（权柄与审批）、
> orchestration/workflows/pipeline.yaml（阶段与审批闸）、
> control-dsh-plugin/docs/execution-migration-C1.md（执行层迁移设计）

## 1. 需求范围

1. control-api 新增受信通道 `POST /api/webhooks/advance`：DSH 会话声明任务当前阶段完成，
   任务进入审批闸（awaiting_approval），由人工 approve/reject。
2. 契约同步 `docs/api/openapi.yaml`，双向对账（contract_test.go）全绿。
3. control-dsh-plugin 新增 `control_task_advance` 工具（X-Webhook-Token 认证，
   token 走环境变量 `CONTROL_ADVANCE_TOKEN`）。

## 2. 影响面分析

| 影响面 | 评估 |
|---|---|
| control-api `internal/api` | 新增 1 个 webhook handler（复用 merge-event 模式，FINDING-003）；routes() 加 1 行 |
| 契约 `docs/api/openapi.yaml` | 新增 /webhooks/advance 路径 + 2 个 schema；**必须同步否则 contract_test FAIL** |
| engine | 零改动：`engine.Advance` 已实现（pipeline.yaml 每阶段审批闸），直接复用 |
| 执行层冲突 | **发现新问题**：approve 后 `enterNextAs` 置 running 并 `maybeRun` 拉起 pi 执行器，与"DSH 执行"模型双跑冲突 → 需配套 `agent.enabled` 开关（默认 true 保持现行为） |
| 配置 | `server.webhook_secret` 复用 merge webhook 同一密钥（未配置 → advance 503）；`agent.enabled: false` 环境启用 |
| 插件 | 新增 1 工具 + 1 配置字段（advanceTokenEnv） |
| 兼容性 | 全部向后兼容：新端点只增不改；enabled 默认 true 时行为与现状一致 |

## 3. 状态守卫规则（advance webhook）

- 任务不存在 → 404
- 仅 `pending`/`running` 可 advance；`paused`（暂停为最高优先级，18 章：暂停期间禁止一切写操作）、
  `awaiting_approval`（重复推进）、`delivered` → 409
- secret 未配置 → 503；token 不符 → 401（常量时间比较）

## 4. 验收标准

1. advance 后任务进入 `awaiting_approval` 且审批队列可见
2. approve 后推进下一阶段且**不拉起 pi**（agent.enabled=false）
3. 未配置 secret → 503；非法状态 → 409；错误 token → 401
4. `go build ./... && go test ./...` 全绿（含新契约用例）
5. `control-api reconcile` 全 PASS 零 WARN

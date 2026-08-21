# TASK-003 L3 详细设计：阶段完成回传（advance webhook）+ control_task_advance 工具

> 任务：DSH 集成 P1 | 阶段：design | 权威：requirements 阶段产物
> (report-requirements.md) 已批准视为需求基线；本设计为 L3，顺行产出。
> 依据：pipeline.yaml（阶段/审批闸/on_reject）、engine.go（Advance/enterNextAs/maybeRun）、
> webhook.go（FINDING-003 共享密钥模式）、openapi.yaml（契约）、
> control-dsh-plugin/docs/execution-migration-C1.md（C1 迁移设计）

## 1. 目标

DSH 会话执行任务阶段后，通过受信 HTTP 通道声明"阶段完成"，让 control-api 状态机
把任务推入审批闸。附带解决执行层双跑冲突（approve 后 pi 自动执行）。

## 2. 改动清单

### 2.1 control-api

**a) `internal/api/webhook.go`：新增 `advanceEvent` handler + `advanceReq`**

```
POST /api/webhooks/advance
认证：X-Webhook-Token 与 server.webhook_secret 常量时间比较（FINDING-003 同款）；
      secret 未配置 → 503；token 不符 → 401（withAuth 已放行 /api/webhooks/ 前缀）
请求：{ "task_id": "TASK-003", "artifact": "report-design.md" }   // artifact 可选
状态守卫：仅 pending/running 可 advance；paused（18 章暂停禁写）/awaiting_approval/
      delivered → 409；任务不存在 → 404
处理：tasks.ParseFile → e.Advance(m, artifact)（engine 已实现：置 Stage=First() 若空、
      末阶段→delivered、需审批→awaiting_approval+审批队列、auto→下一阶段）
响应：{ "task_id", "stage", "status" }（200）
```

**b) `internal/api/server.go`：routes() 增 `{"POST /api/webhooks/advance", s.advanceEvent}`**

**c) `internal/config/config.go`：AgentConfig 增 `Enabled bool yaml:"enabled"`（默认 true）**

**d) `internal/api/server.go` Serve()：`if cfg.Agent.Enabled { s.eng.Runner = ... }`**
   - enabled=false 时 engine.maybeRun 因 Runner==nil 直接 return（engine.go:32），
     永不拉起 pi；approve/resume 后任务停留 running 等 DSH advance
   - 默认 true：零行为变化，向后兼容

**e) `docs/api/openapi.yaml`：新增 /webhooks/advance 路径 + AdvanceEventRequest/
   AdvanceEventResponse schema**（镜像 merge-event，security: WebhookToken）

**f) 测试**：`internal/api/endpoints_test.go` 增 TestAdvanceWebhook 表驱动用例
   （503/401/400/404/409×状态守卫/200+契约校验），复用 newWebhookServer 模式
   （注意其 pipeline 需含 requirements 阶段：mergeTestPipeline 首阶段是 testing，
   Advance 语义对 stage=="" 会取 First()；用例显式给 stage 避免歧义）

### 2.2 control-dsh-plugin

**`lib/index.js`：新增 `control_task_advance` 工具 + Config 增 `advanceTokenEnv`
（默认 "CONTROL_ADVANCE_TOKEN"）**

```
control_task_advance(task_id, artifact?)
  → POST {baseUrl}/api/webhooks/advance
     header: X-Webhook-Token: process.env[advanceTokenEnv]
  → {task_id, stage, status}
```

### 2.3 运行时配置（不进 Git，0600）

```yaml
server:
  webhook_secret: <生成随机值>   # 复用 merge webhook 密钥；env CONTROL_WEBHOOK_SECRET 可覆盖
agent:
  enabled: false                 # P1 起本环境执行层归 DSH，引擎不再拉起 pi
```

## 3. 状态流转（DSH 执行模型）

```
create(pending) → [DSH 写 requirements 产物] → advance → awaiting_approval(requirements)
→ 人 approve → running(design)（agent.enabled=false 不跑 pi）
→ [DSH 写 design 产物] → advance → awaiting_approval(design) → … → testing → merge
（team_mr_review，走 merge_event webhook）→ merged → 人 deliver → delivered
```

## 4. 边界与失败处理

| 场景 | 行为 |
|---|---|
| 并发 advance 同任务 | 状态守卫 409（awaiting_approval 后不可再 advance） |
| paused 时 advance | 409（暂停期间禁止一切写操作，18 章） |
| secret 未配置 | 503（与 merge webhook 一致） |
| artifact 非必填 | work_log detail 记空串（engine.Advance 原语义） |
| 熔断/回退 | enabled 置回 true 即恢复 pi 执行；advance 端点保留双通道 |

## 5. 测试与验收

见 report-requirements.md §4；另补：agent.enabled=false 下 approve 后 2s 内
work_log 无 agent 执行条目、无 pi 进程（验收双跑已消除）。

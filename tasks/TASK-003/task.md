---
task_id: TASK-003
title: DSH 集成 P1：阶段完成回传（advance webhook）+ control_task_advance 工具
repo_key: control-api
domain: backend-go
stage: merge
status: awaiting_approval
priority: ""
authority: L1
---

# DSH 集成 P1：阶段完成回传（advance webhook）+ control_task_advance 工具

需求（L1）：control 平台与 DSH 集成后，任务阶段由 DSH 会话执行，control-api 保留状态机/审批/审计。当前 engine.Advance 仅供内部自动流程、不经 HTTP，DSH 无法声明阶段完成，任务创建后停在 pending 无法进入审批队列。需求：1) control-api 新增受信通道 POST /api/webhooks/advance（复用 X-Webhook-Token 与 server.webhook_secret 常量时间认证，与 merge-event 同级；带状态守卫），调用 engine.Advance 置阶段完成进审批闸；2) 契约同步 docs/api/openapi.yaml（双向对账，contract_test 全绿）；3) control-dsh-plugin 新增 control_task_advance 工具（token 走环境变量 CONTROL_ADVANCE_TOKEN），DSH 会话阶段产物落任务目录后调用。验收：advance 后任务进入 awaiting_approval 且审批队列可见；approve 后推进下一阶段；未配置 secret 时 503；非法状态 409。

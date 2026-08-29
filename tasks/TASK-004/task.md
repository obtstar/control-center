---
task_id: TASK-004
title: P1 收尾：LiteLLM 死代码清理 + pi 执行器退役（internal/agent）
repo_key: control-api
domain: backend-go
stage: deliver
status: delivered
priority: ""
authority: L1
---

# P1 收尾：LiteLLM 死代码清理 + pi 执行器退役（internal/agent）

需求（L1）：control×DSH 集成 P1 已完成（TASK-003：advance webhook + agent.enabled 开关），执行层已迁移到 DSH 会话。现清理退役残留：1) 移除 LiteLLM 死代码——config.go 的 LLMConfig/llm 段/LITELLM_* env 覆盖（运行时零消费方，config.go:31 注释自证）与 control-api.yaml 的 llm 段；2) pi 执行器退役——删除 internal/agent 包、engine.Runner 装配、maybeRun/handleRunFailure 执行路径、RetryLoop 自动重试（FINDING-027 依赖 pi 失败语义），config 移除 AgentConfig 段；3) 18.3 KB grounding 语义保留：grounded 检查从执行前（maybeRun）迁移到 Advance 入口（enforce 无据仍自动暂停，warn 记日志），kb.mode 配置不变；4) 状态机语义不变：approve 后任务 running 等待 DSH advance，RecoverOnBoot 保留；5) 验收：go build/vet/test 全绿、reconcile 五项 PASS、advance/approve 闭环回归通过。

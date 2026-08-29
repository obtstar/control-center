---
task_id: TASK-000016
title: TASK-008 Phase 2：内联 AI 操作（行内按钮/审批建议/全局入口）
repo_key: control-web
domain: frontend-dev
stage: deliver
status: delivered
priority: ""
authority: L1
---

# TASK-008 Phase 2：内联 AI 操作（行内按钮/审批建议/全局入口）

TASK-008 Phase 2：内联 AI 操作（design D4 预留）。现状：TASK-008 Phase 1（/ai + iframe 嵌入 DSH）已交付，Phase 2 未做。需求：①TaskTable 每行增加"AI 协助"按钮（跳 /ai 并带 selectedTaskId，location.state 已支持）；②ApprovalDialog 集成 AI 建议（查看任务上下文/设计文档后给审批建议提示）；③BoardPage 增加全局 AI 助手入口（跳 /ai）。验收：三入口可用 + 上下文正确传递 + tsc/eslint/vitest/build 全绿。

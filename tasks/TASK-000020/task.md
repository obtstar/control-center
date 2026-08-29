---
task_id: TASK-000020
title: 任务看板：delivered 任务归档功能
repo_key: control-web
domain: frontend-dev
stage: deliver
status: delivered
priority: ""
authority: L1
archived: false
---

# 任务看板：delivered 任务归档功能

任务看板（control-web TaskTable）操作列增加"归档"按钮：已交付（delivered）任务可归档，归档后从活跃看板移除（可查归档）。落地（后端归档，符合"任务即文档"）：①control-api 任务 frontmatter 支持 archived 字段（tasks 包解析/回写）；②POST /api/tasks/{id}/action 新增 archive 动作（仅 delivered 可触发，写 frontmatter + work_log 留痕）；③GET /api/tasks 默认过滤归档（支持 ?archived=all 查全部）；④契约登记（openapi.yaml）；⑤control-web TaskTable delivered 行加"归档"按钮 → 调 archive → 刷新列表。验收：delivered 任务可归档、归档后看板消失、work_log 留痕、契约对账 PASS、tsc/vitest 全绿。

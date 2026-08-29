---
task_id: TASK-000017
title: 看板筛选优化：仓库/阶段/状态/更新人列下拉框筛选
repo_key: control-web
domain: frontend-dev
stage: deliver
status: delivered
priority: ""
authority: L1
---

# 看板筛选优化：仓库/阶段/状态/更新人列下拉框筛选

control-web 看板（BoardPage/TaskTable）筛选优化：仓库（repo_key）、阶段（stage）、状态（status）、更新人（updated_by）四列的表头筛选从文本框改为**下拉框**（Dropdown 精确匹配，含唯一值选项 + 清空）。其余列（任务 ID/标题/更新时间）保持文本筛选。验收：四列下拉筛选可用、选项为当前数据唯一值去重、可清空恢复、tsc/eslint/vitest/build 全绿。

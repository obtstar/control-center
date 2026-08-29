---
task_id: TASK-009
title: 插件深度集成 v0.2：执行面工具 + 会话绑定前置 + 末段技能
repo_key: control-dsh-plugin
domain: wiki-authoring
stage: deliver
status: delivered
priority: ""
authority: L1
---

# 插件深度集成 v0.2：执行面工具 + 会话绑定前置 + 末段技能

需求（L1）：control-dsh-plugin 深度集成扩展 v0.2。1) 工具面：新增 control_reconcile（spawn control-api reconcile 对账）、control_task_execute（按 pipeline.yaml 引导阶段执行：任务上下文+阶段规格+产物要求）、control_grounding_check（经 /api/kb/search 有据校验）、control_pipeline_status（流水线声明+任务状态汇总）；模块化拆 lib/http.js/pipeline.js/render.js/tools-core.js/tools-exec.js，依赖加 js-yaml，版本 0.2.0；2) 技能面：control-center 新增 stage/merge-review（MR heavy 自评+quality_gate，team_mr_review 终审留 Git 平台）与 stage/deliver-archive（cleanup worktree+归档，advance→delivered）；3) 验收：headless E2E 12 工具可用、新工具实测（reconcile exit 0、grounding 命中、execute 阶段规格、pipeline 6 阶段）、技能目录热载 17 项；4) 后续设计要点（会话↔任务绑定、反向通知、UI client module）输出到插件仓 docs/。

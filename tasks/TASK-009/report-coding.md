# TASK-009 report-coding.md

> 阶段：coding · 产出：commit + MR diff + E2E 验收记录
> 日期：2026-08-29

## 编码产物

| 项 | 内容 |
|----|------|
| 插件仓 MR | [PR #1](https://github.com/obtstar/control-dsh-plugin/pull/1)（feature/TASK-009-v02-e2e → dev，commit `ede5a00`） |
| 修复 1 | `lib/index.js`：看板 API 代理补 `/api` 前缀（control-api 路由统一带 `/api/`；此前 `/tasks` 等 404 "404 page not found" 透传，浏览器 JSON.parse 报 Unexpected non-whitespace character at position 4） |
| 修复 2 | `client/index.js`：loadTasks/loadApprovals/loadAudit 加 `res.ok` 检查（非 2xx 抛友好错误，不再把纯文本塞给 JSON.parse） |
| 实测 | `/control/dashboard/api/{tasks,approvals/pending,audit}` 全部 200 application/json |

> 工具面/模块化/技能面（L1 ①②③）已随插件 v0.4.0 与 control-center 70af64e 实现并合 dev，本阶段为缺陷修复 + E2E 验收。

## E2E 验收记录（L1 验收项）

| 验收项 | 结果 | 证据 |
|--------|------|------|
| headless E2E 12 工具可用 | ✅ 14 个 control_* 工具会话内可用 | control_task_{list,context,execute,advance,action,claim,create}, control_approvals_list, control_audit, control_findings, control_grounding_check, control_health, control_pipeline_status, control_reconcile |
| control_reconcile exit 0 | ✅ | reconcile 5/5 PASS（backend/frontend/database/registry/kb-mirror） |
| control_grounding_check 命中 | ✅ | kb_search has_basis=true（05/15/17 章命中） |
| control_task_execute 阶段规格 | ✅ | TASK-010/009 均返回 stage_spec（model/agent/artifact/approval） |
| pipeline 6 阶段 | ✅ | requirements/design/coding/testing/merge/deliver（pipeline.yaml） |
| 技能目录热载 17 项 | ✅ | 会话技能 17 项（含 merge-review/deliver-archive/wiki-distill） |

## 依据

- task.md（L1）+ design.md（L2，已审批）
- 插件仓 lib/{http,pipeline,render,tools-core,tools-exec,session,notify}.js（v0.4.0 实现）
- control-center orchestration/skills/stage/{merge-review,deliver-archive}（70af64e）

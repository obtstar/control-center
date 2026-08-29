---
task_id: TASK-009
stage: design
authority: L2
title: 插件深度集成 v0.2 — 设计文档
---

# TASK-009 设计文档（L2）

> 输入：`task.md`（L1）+ 现状核对（插件 v0.4.0 已实现大部分，本设计为 L1 映射与定稿）
> 依据：`orchestration/workflows/pipeline.yaml`（阶段声明）、插件仓 `lib/` 模块、`orchestration/skills/stage/` 技能目录（KB 检索校验存在）

## 1. 现状核对（实现先行确认）

| L1 条目 | 现状 | 差距 |
|---------|------|------|
| ① 工具面四工具（control_reconcile/execute/grounding_check/pipeline_status） | ✅ 已实现（lib/tools-exec.js 等，插件 v0.4.0） | 无 |
| ② 模块化拆 lib/{http,pipeline,render,tools-core,tools-exec}.js + js-yaml | ✅ 已拆（另有 session.js/notify.js，v0.3/v0.4 演进） | 无 |
| ③ 技能面 stage/merge-review + stage/deliver-archive | ✅ 已建（control-center 70af64e 合 dev） | 无 |
| ④ 验收（headless E2E 12 工具/新工具实测/技能热载 17 项） | 工具实测可用（本会话 control_* 全部工作） | 补 E2E 记录 |
| ⑤ 后续设计要点输出插件仓 docs/ | ✅ execution-migration-C1.md / integration-next.md / ui-client-module.md | 无 |

结论：TASK-009 实质工作已完成，本设计文档定稿 L1→实现映射并补验收口径。

## 2. L1 需求条目映射

| L1 条目 | 设计项 | 落点 |
|---------|--------|------|
| 1) 工具面：control_reconcile（spawn control-api reconcile 对账） | D1 | lib/tools-exec.js `control_reconcile`（spawn 二进制，exit 0 为 PASS） |
| 1) control_task_execute（按 pipeline.yaml 引导阶段执行） | D2 | lib/pipeline.js 解析阶段规格（model/agent/artifact/approval）+ tools-exec.js 工具 |
| 1) control_grounding_check（经 /api/kb/search 有据校验） | D3 | lib/http.js requestJson + tools-exec.js（has_basis/count/hits） |
| 1) control_pipeline_status（流水线声明+任务状态汇总） | D4 | lib/pipeline.js 读 pipeline.yaml + tools-core.js 任务状态 |
| 2) 模块化 + js-yaml + 版本 0.2.0 | D5 | lib/{http,pipeline,render,tools-core,tools-exec}.js；依赖 js-yaml；版本演进至 v0.4.0 |
| 3) 技能面 merge-review / deliver-archive | D6 | control-center orchestration/skills/stage/{merge-review,deliver-archive} |
| 4) 验收 | D7 | headless E2E + 工具实测 + 技能热载 17 项 |
| 5) 后续要点 → 插件仓 docs/ | D8 | docs/execution-migration-C1.md 等 3 份 |

## 3. 概要设计

### 3.1 工具面（D1-D4）

| 工具 | 数据通道 | 输出 |
|------|---------|------|
| control_reconcile | host spawn `~/control-api/control-api reconcile` | {exit_code, output}；0=PASS，1=CONFLICT |
| control_task_execute | 读 tasks_dir + pipeline.yaml（js-yaml） | 任务上下文（task_dir/stage/status）+ 阶段规格（model/agent/artifact/approval）+ 建议产物 report-<stage>.md |
| control_grounding_check | requestJson `/api/kb/search?q=&limit=` | {count, has_basis, hits}；无据输出 NO_BASIS |
| control_pipeline_status | pipeline.yaml 解析 + 任务状态汇总 | {stages, circuit_breaker, tasks_summary} |

### 3.2 模块化（D5）

```
lib/
├── http.js        # requestJson/webhookRequest（Bearer + X-Webhook-Token 双通道）
├── pipeline.js    # pipeline.yaml 解析（js-yaml）+ 阶段规格
├── render.js      # 结果渲染（表格/清单）
├── tools-core.js  # 任务/审批/审计/findings 核心工具
├── tools-exec.js  # 执行面工具（reconcile/execute/grounding/pipeline_status）
├── session.js     # 会话↔任务绑定（v0.3）
└── notify.js      # 反向通知（v0.4）
```

### 3.3 技能面（D6）

- `stage/merge-review`：MR 组装 + heavy 模型自评（quality_gate：tests_green + heavy_self_review；终审 team_mr_review 在 Git 平台）
- `stage/deliver-archive`：cleanup worktree + 任务报告归档（deliver 阶段 auto 审批；DSH 执行后 advance → delivered）

### 3.4 验收口径（D7）

| 验收项（L1） | 方法 |
|------|------|
| headless E2E 12 工具可用 | 工具清单核对（tools-core 7 + tools-exec 4 + session 1） |
| control_reconcile exit 0 | 实测（reconcile 5/5 PASS，exit 0） |
| grounding 命中 | 实测（kb_search has_basis=true） |
| execute 阶段规格 | 实测（TASK-010 等阶段规格返回） |
| pipeline 6 阶段 | pipeline.yaml stages 长度=6 |
| 技能目录热载 17 项 | orchestration/skills/ 目录核对（会话技能目录含全部） |

## 4. 详细设计（到可编码粒度）

- 各工具输入/输出契约：见 3.1 表 + 插件 lib/tools-exec.js 现有实现（已编码，本设计定稿引用）
- pipeline.yaml 阶段字段：model（cheap/coding/heavy）/agent/artifact/approval/on_reject（05 章流水线状态机）
- 末段技能结构与 05 章 merge/deliver 阶段对齐

## 5. 验收映射与风险

- 风险：无（实现已完成并运行）；剩余为 E2E 记录补全（D7）
- TASK-010 决策约束（19 章 §5）：插件 client 半区不做 M3（只读投影上限）；凭据不进浏览器——对 TASK-009 后续阶段生效

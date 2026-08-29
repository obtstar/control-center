---
name: deliver-archive
layer: stage
description: 交付归档：cleanup worktree + 任务报告归档（deliver 阶段，auto 审批；DSH 执行后 advance → delivered）
---

## 输入
merged 状态的任务（stage=merge, status=merged）+ 人工 deliver 确认后进入 deliver 阶段

## 步骤
1. 人工调 control_task_action deliver（merge/merged 才可触发）→ 任务进入 deliver 阶段（running）
2. 用 control_task_execute 确认任务在 deliver 阶段、取阶段规格
3. **cleanup worktree**：删除任务 worktree（`~/wt/<repo>/TASK-*/` 或任务目录外的临时工作区；平台规约 7 天回收，交付后立即清理）
4. **archive report**：汇总本任务全生命周期产物（task.md 权威 + report-*.md + work_log 关键流转）生成 `report-deliver.md` 落任务目录
5. 调 control_task_advance 声明 deliver 完成 → 末阶段（IsLast）→ delivered
6. **auto archive（自动归档，TASK-000013 机制）**：delivered 后运行
   `bash ~/control-center/scripts/task-archive.sh`——自动收集本任务产物（未入库部分）→ feature 分支
   → commit → push → gh pr create 自动 MR（人合并终审）；已入库则跳过并清理工作区副本。
   若 gh 未认证或远端不可达，输出提示"产物待人工归档（task-archive.sh）"，不阻断 delivered。

## 约束
- deliver 是 auto 审批阶段：不生成审批闸，advance 后直接 delivered（engine IsLast 语义）
- 清理前确认 merge 已回传（status=merged 且 merge_event webhook 已生效），不得清理未合并内容
- 归档报告引用 KB 依据与 TASK-id；无据输出 NO_BASIS

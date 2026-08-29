---
name: merge-review
layer: stage
description: 待合并自评：MR 组装 + heavy 模型审查（quality_gate 前置 tests_green 与 heavy_self_review，终审 team_mr_review 在 Git 平台）
---

## 输入
testing 批准后的任务（stage=merge, status=running）+ 各阶段产物（report-*.md、commit/MR diff）

## 步骤
1. 用 control_task_execute 确认任务在 merge 阶段、取阶段规格（artifact: MR + heavy 模型自评报告）
2. **quality_gate 前置检查**：
   - tests_green：确认 testing 阶段报告通过率与失败明细，任何失败不得进入自评
   - heavy_self_review：用 heavy 模型（非 coding 模型）审查 MR diff：正确性/安全/契约一致性/规约红线（规模/gofmt/vet/eslint）
3. 产出 `report-merge.md`（自评结论：通过/不通过 + 依据），落任务目录
4. 自评不通过 → 打回（调 control_task_action 无此路径时说明原因，等人工裁决）
5. 通过 → 团队员工在 Git 平台执行合并（push 分支 + 建 MR 等待），**合并事件由 merge_event webhook 回传**（control-api 置 merged 停留待交付）；本地不调用 advance（merge 为 team_mr_review 终审，无 agent 执行语义）

## 约束
- 审查必须引用 KB 依据（control_grounding_check / mcp__piekbs__kb_search），无据输出 NO_BASIS
- 仅 push/建 MR 不算完成：done_when=merged_by_teammate，等 webhook 回传
- 权柄：只读审查，不修改 coding 阶段产物；发现冲突出不一致报告

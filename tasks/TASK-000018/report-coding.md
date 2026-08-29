# TASK-000018 report-coding.md

> 阶段：coding · 日期：2026-08-29

## 交付（新工作流首次实践：dev 直推）

| 文件 | 改动 |
|------|------|
| orchestration/skills/enforce/branch-guard/SKILL.md | 按仓区分：平台仓 dev 豁免直推；业务仓 feature 强制 |
| scripts/task-archive.sh | +`--direct-dev`（平台仓产物直推 dev，无 MR） |
| orchestration/skills/stage/deliver-archive/SKILL.md | cleanup 平台仓跳过（无 worktree） |
| docs/architecture/02-branch-worktree.md | 平台仓/业务仓分支策略说明 |
| AGENTS.md（本地） | §6.7 开发流程 |

## 关键验证

- **首次 dev 直推**：commit `a90b25c` 直接 push origin dev（ced2a28..a90b25c）——无 worktree/分支/MR
- pre-commit hook PASS（行数/规约）

## 依据

- task.md（L1 人裁决）+ design.md（5 项设计）

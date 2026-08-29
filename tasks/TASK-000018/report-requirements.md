# TASK-000018 影响分析报告（requirements）

> 任务：开发流程调整：平台仓 dev 直开（worktree 移交业务仓）
> 阶段：requirements · 日期：2026-08-29

## 1. 决策

人裁决（2026-08-29）：control-* 平台仓弃用 worktree/feature 分支/MR，**直接 dev 开发提交**；worktree 机制移交业务仓 dialectic-top（registry 已登记：path=wt/projects/dialectic.top/dev，max_worktrees=3）。归档直推 dev；merge 阶段平台仓简化（代码在 dev 即视为合并，回传语义不变）。

## 2. 影响面

| 机制 | 现状 | 调整 |
|------|------|------|
| branch-guard 技能（enforce） | 强制 feature/*，dev 阻断 | repo_key 区分：平台仓豁免（dev 直推）；业务仓保持 |
| task-archive.sh | feature 分支 + MR 归档 | +`--direct-dev` 模式（平台仓直推 dev） |
| deliver-archive 技能 | cleanup worktree | 平台仓无 worktree → cleanup 按 repo 跳过 |
| branch-cleanup.sh | 清 feature 分支 | 平台仓无 feature → 仅业务仓适用（保留） |
| merge 阶段 | team_mr_review | 平台仓：代码直推 dev 即 merged（回传语义不变）；业务仓保留 |
| 文档 | AGENTS.md "dev 只读"、02-branch-worktree.md | 同步新工作流 |
| registry | dialectic-top 已登记 | ✅ 就绪 |

## 3. 方案

1. **branch-guard 技能**：SKILL.md 改为按 repo_key 判断——平台仓（control-*）允许 dev 提交；业务仓（非 control-*）强制 feature/*
2. **task-archive.sh**：`--direct-dev` 参数——直接 `git add + commit + push origin dev`（无分支/MR）；默认保留分支模式（业务仓）
3. **deliver-archive 技能**：cleanup worktree 步骤注明"平台仓跳过（无 worktree）"
4. **merge 阶段**：流程说明（平台仓代码在 dev 即合并，无 MR 终审）
5. **文档**：AGENTS.md §7 流程 + 02-branch-worktree.md 补"平台仓 dev 直开/业务仓 worktree"说明

## 4. 验收

1. branch-guard 平台仓 dev 提交不拦（实测）
2. task-archive --direct-dev 直推 dev 成功
3. 业务仓（dialectic-top）worktree 流程可用（branch.sh new 建 worktree）
4. 文档同步 + reconcile PASS

## 5. 依据

- 人裁决（2026-08-29）；registry dialectic-top 登记；AGENTS.md/02-branch-worktree 现状

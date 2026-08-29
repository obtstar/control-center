---
task_id: TASK-000018
title: 开发流程调整：平台仓 dev 直开（worktree 移交业务仓）
repo_key: control-center
domain: backend-go
stage: deliver
status: delivered
priority: ""
authority: L1
archived: true
---

# 开发流程调整：平台仓 dev 直开（worktree 移交业务仓）

平台开发流程调整（人裁决 2026-08-29）：control-* 平台仓**弃用 worktree/feature 分支/MR**，直接在 dev 分支开发与提交；worktree 机制移交业务仓（dialectic-top，registry 已登记）。落地：①修订 branch-guard 技能（按 repo_key 区分：平台仓允许 dev 直推，业务仓保持 feature 强制）；②task-archive.sh 加 --direct-dev 模式（平台仓产物直接 commit+push dev，无 MR）；③deliver-archive 技能 cleanup 按 repo 跳过（平台仓无 worktree）；④merge 阶段平台仓简化（代码直推 dev 即视为 merged，回传语义不变；业务仓保留 Git 平台 MR 终审）；⑤AGENTS.md/架构文档（02-branch-worktree 等）同步新工作流。验收：平台仓可 dev 直推（branch-guard 不拦）、归档直推 dev、业务仓 worktree 流程可用（branch.sh + dialectic-top）、文档同步、reconcile PASS。

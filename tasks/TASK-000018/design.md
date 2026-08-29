---
task_id: TASK-000018
stage: design
authority: L2
title: 开发流程调整（平台仓 dev 直开）— 设计
---

# TASK-000018 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 设计

### 1.1 branch-guard 技能修订（SKILL.md）

```
强制点：push/commit 前
检查：
1. 平台仓（repo_key 前缀 control-，即 ~/control-*）：允许 dev 分支直接提交（新工作流）
2. 业务仓（非 control-*，如 dialectic-top）：当前分支必须 feature/* 或 bugfix/*，main/dev/release 阻断
3. worktree 路径必须在 ~/wt 下（业务仓）
判定：以仓库根目录名区分（control-* 前缀 = 平台仓豁免 dev）
```

### 1.2 task-archive.sh --direct-dev

```
用法: task-archive.sh [home] [--direct-dev]
--direct-dev：产物直接 git add + commit + push origin dev（无 feature 分支/MR）
默认（无参）：保留分支+MR 模式（业务仓用）
```

### 1.3 deliver-archive 技能

步骤 3 cleanup worktree 加注：**平台仓（repo_key control-*）无 worktree，跳过此步**；业务仓保留。

### 1.4 merge 阶段说明

- 平台仓：代码直接合入 dev（无 MR），advance merge 后经 merge-event 回传 merged（或直接视为合并）——语义不变
- 业务仓：保留 team_mr_review（Git 平台 MR 终审）

### 1.5 文档

- AGENTS.md §7 流程 + §10 差异：平台仓 dev 直开；worktree 给业务仓
- 02-branch-worktree.md：补"平台仓直 dev / 业务仓 worktree"段落

## 2. 验收映射

| 验收项 | 落实 |
|--------|------|
| 平台仓 dev 直推不拦 | 1.1（技能按仓区分） |
| 归档直推 dev | 1.2（--direct-dev） |
| 业务仓 worktree 可用 | branch.sh（不变）+ dialectic-top 登记 |
| 文档同步 | 1.5 |

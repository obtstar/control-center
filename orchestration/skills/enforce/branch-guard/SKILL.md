---
name: branch-guard
layer: enforce
description: 分支守卫：主干只读
---

## 强制点：push/commit 前

## 检查
1. 当前分支必须是 feature/* 或 bugfix/*
2. main/dev/release 上的提交/推送 → 阻断
3. worktree 路径必须在 ~/wt 下

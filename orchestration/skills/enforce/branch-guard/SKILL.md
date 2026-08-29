---
name: branch-guard
layer: enforce
description: 分支守卫：平台仓 dev 直开，业务仓主干只读
---

## 强制点：push/commit 前

## 判定
- **平台仓**（仓库根目录名以 `control-` 开头，即 ~/control-*）：允许在 **dev** 分支直接开发/提交/推送（TASK-000018 人裁决，2026-08-29 新工作流）；不强制 feature 分支，无 worktree。
- **业务仓**（非 control-*，如 dialectic-top）：保持原约束。

## 检查（业务仓）
1. 当前分支必须是 feature/* 或 bugfix/*
2. main/dev/release 上的提交/推送 → 阻断
3. worktree 路径必须在 ~/wt 下

## 检查（平台仓）
1. 当前分支必须为 dev（main 只读不写；release 不在此环境）
2. 直接提交/推送 dev 允许；main 阻断
3. 无需 worktree（平台仓不再建任务 worktree）

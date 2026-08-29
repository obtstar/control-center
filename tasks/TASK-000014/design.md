---
task_id: TASK-000014
stage: design
authority: L2
title: control-center 补装 pre-commit hook — 设计
---

# TASK-000014 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 设计

| 步骤 | 内容 |
|------|------|
| 预检 | `check-conventions.sh --staged .` 全仓预检（应 PASS，053 已清障） |
| 安装 | `bash scripts/install-hooks.sh control-center` |
| 生效确认 | `.repos/control-center.git/hooks/pre-commit` 存在 + core.hooksPath 配置 |
| 四幕验证 | ①未跟踪不拦 ②staged 行数拦 ③staged eslint 拦 ④清洁通过（FINDING-036 法） |
| 文档 | AGENTS.md §6.2 同步"三仓已装"（本地文件不入 Git） |

## 2. 验收映射

| 验收项 | 落实 |
|--------|------|
| hook 生效 | 安装 + 四幕 |
| 无存量违规 | 预检 PASS |
| 文档同步 | AGENTS.md 更新 |

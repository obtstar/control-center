---
name: coding
layer: stage
description: 编码实现：feature 分支 + 单测
---

## 输入
design.md（L3）

## 步骤
1. branch.sh new 切 feature 分支 + worktree
2. 按详设编码 + 单元测试
3. commit（关联 TASK-id）→ push → MR

## 约束
- 只允许在 task worktree 内写代码；主干只读
- commit 前过 enforce 四件套

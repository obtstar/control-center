---
name: testing
layer: stage
description: 测试验证：本地 docker 执行
---

## 输入
MR + feature worktree

## 步骤
1. 本地 docker 起依赖服务
2. 跑 ci/ 脚本（集成/回归/静态检查）
3. 产出 testing-测试报告.md（通过率/覆盖率/失败明细）

## 约束
- 失败不修改代码，报告打回 coding

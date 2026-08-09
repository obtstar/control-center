---
name: authority-check
layer: enforce
description: 权柄校验：禁止逆行修改上级文档
---

## 强制点：每阶段出口

## 检查
1. diff 中不得出现 authority 级别高于当前阶段的文档
2. L1 文档任何情况 AI 不可写（人指令也不行）
3. 违例 → 阻断 + 暂停任务 + 不一致报告

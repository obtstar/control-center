---
name: grounding-check
layer: enforce
description: 引用校验：产出依据必须真实存在
---

## 强制点：每阶段出口

## 检查
1. 提取产出物中全部 KB 引用（文档 ID + 段落）
2. 逐条验证引用目标真实存在
3. 假引用/空引用 → 阻断流转，记 work_log，打回重做

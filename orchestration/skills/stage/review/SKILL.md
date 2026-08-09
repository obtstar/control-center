---
name: review
layer: stage
description: 待合并自评：heavy 模型审查 MR
---

## 输入
MR diff + 测试报告

## 步骤
1. heavy 模型审查 diff：正确性/安全/契约一致性/规约红线
2. 产出 review-自评报告.md

## 约束
- 与 coding 必须不同模型别名（heavy vs coding）
- 自评不通过 → 打回 coding

---
name: analysis
layer: stage
description: 需求分析：RAG 检索 + 影响分析报告
---

## 输入
tasks/<id>/task.md（L1 需求）

## 步骤
1. PieKBS kb_search 检索相关文档（多关键词多角度）
2. 阅读权柄文档（L1 必读全文）
3. 输出 analysis-影响分析报告.md：涉及仓库/模块/接口/数据表、风险、引用链

## 约束
- 每条结论必须引用 KB 依据（文档 ID + 段落）；无据 → 输出 NO_BASIS 并停止
- 只读操作，禁止修改任何文件

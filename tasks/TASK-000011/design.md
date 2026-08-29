---
task_id: TASK-000011
stage: design
authority: L2
title: LiteLLM 砍除清理 + wiki-distill 验证 — 设计
---

# TASK-000011 设计文档（L2）

> 输入：task.md（L1，人裁决 LiteLLM 砍除）
> 残留盘点（实测）：control-wiki/config.yaml distill 段、04-ai-gateway.md 整章、scripts 7 处引用

## 1. 清理范围与动作

| # | 文件 | 动作 |
|---|------|------|
| 1 | control-wiki/config.yaml | `distill` 段移除/标注废弃（base_url litellm.internal + token）——蒸馏由 DSH wiki-distill 技能承担 |
| 2 | control-center/docs/architecture/04-ai-gateway.md | 修订：标题/C1 后状态——"模型经 DSH 统一出口（dsh-llm），LiteLLM 网关废弃（FINDING-017 人裁决）"；保留章节占位防链接断 |
| 3 | scripts/setup-env.sh、check-env.sh、lib/agent.sh、welcome.sh、control.env.tmpl、compose.sh、init-env.sh、init-env-steps.sh | 清理 litellm 引用（env 注入/探测/提示文本）；check_pre 的 LITELLM_ENDPOINT 探测移除 |
| 4 | control-api.yaml | 确认已无 litellm（TASK-004 清理，复核） |
| 5 | docs/FINDINGS.md | FINDING-017 状态 open → wontfix（人裁决：wiki-distill 已替代蒸馏，网关废弃） |
| 6 | AGENTS.md §10-8 | 恢复手册作废（本地文件不入 Git，直接改） |

## 2. wiki-distill 蒸馏闭环验证

| 步骤 | 验证 |
|------|------|
| 选一份 raw 文档（如 19 章决策记录或 FINDING） | wiki-distill 技能执行蒸馏 → wiki/source-notes/ 出页 |
| FTS 检索 | kb_search 命中蒸馏页 |
| OKF 存活 | sources 感知判据（FINDING-052）不误删 |

## 3. 验收映射

| 验收项（L1） | 落实 |
|------|------|
| 无活 LiteLLM 消费点 | 1-6 清理 + grep 复核 |
| FINDING-017 更新 | 5（wontfix 附人裁决） |
| wiki-distill 验证 | 2 实测 |
| reconcile PASS + kb-sync | 清理后跑 |

---
task_id: TASK-000011
title: LiteLLM 网关砍除：清理残留 + wiki-distill 蒸馏闭环验证
repo_key: control-piekbs
domain: backend-go
stage: deliver
status: delivered
priority: ""
authority: L1
---

# LiteLLM 网关砍除：清理残留 + wiki-distill 蒸馏闭环验证

人裁决（2026-08-29）：**砍掉 LiteLLM 功能**。依据：①control-api 的 LiteLLM 模型通道已随 C1 迁移退役（TASK-004，模型接入全走 DSH）；②PieKBS 内置 distill 是唯一剩余消费点，但已被 `wiki-distill` 技能替代（TASK-005，DSH 会话执行蒸馏）；③LiteLLM 网关长期不可达（FINDING-017 外部阻塞），砍除后解除死结。本任务从"恢复蒸馏"重定向为**清理 + 验证**。

## 需求

1. **清理 LiteLLM 残留**：
   - `control-piekbs/config.yaml` 与 `control-wiki/config.yaml` 的 `distill` 段（token/endpoint）移除或标注废弃；
   - `control-center/docs/architecture/04-ai-gateway.md` 修订为"C1 后模型经 DSH 统一出口，LiteLLM 网关废弃"；
   - FINDING-017 关闭/重新裁决（wiki-distill 已替代，网关不再需要）；
   - AGENTS.md §10-8（LiteLLM 恢复手册）作废同步（该文件不入 Git，本地更新）；
   - 相关模板/配置位清理（setup-env 等如引用）。
2. **wiki-distill 蒸馏闭环验证**：确认 DSH wiki-distill 技能蒸馏链路完整可用（raw → wiki/source-notes/ 出页、FTS 命中、OKF 存活），作为蒸馏的替代路径。

## 验收

1. 全仓 grep 无活 LiteLLM 消费点（残留配置/文档引用清理或标注废弃）；
2. FINDING-017 状态更新（closed/wontfix，附人裁决理由）；
3. wiki-distill 蒸馏实测通过（至少一次蒸馏出页 + FTS 检索命中）；
4. reconcile 全 PASS；相关文档改动后 kb-sync。

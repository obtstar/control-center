# TASK-000011 report-coding.md

> 阶段：coding · 日期：2026-08-29

## 交付（LiteLLM 砍除 + 蒸馏验证）

### control-center [PR #18](https://github.com/obtstar/control-center/pull/18)
- `04-ai-gateway.md` 废弃标注（C1 后 DSH 统一出口）
- scripts 清理 15 文件：setup-env/check-env/init-env（LITELLM 定义+usage）、agent.sh（pi models.json）、init-env-steps/check.sh（探测）、templates（control.env/welcome/environment.d/piekbs-config.yaml）、compose.sh、common.sh
- FINDING-017 open→wontfix（人裁决，wiki-distill 替代）
- 复核：scripts 零 litellm 残留、bash -n 全过、规约 PASS

### control-wiki [PR #1](https://github.com/obtstar/control-wiki/pull/1)
- `config.yaml` 移除 distill 段（LiteLLM）
- **蒸馏闭环验证**：新增 `raw/references/agent-guide.md`（真实源）+ `wiki/source-notes/agent-guide.md`（wiki-distill 技能蒸馏产物）——**kb_search FTS 命中** ✅（LiteLLM 砍除后链路独立可用）

### 本地（不入 Git）
- AGENTS.md §10-8 恢复手册作废，改"LiteLLM 已砍除，蒸馏走 wiki-distill"；4 处 LiteLLM 引用清理

## 依据

- task.md（L1，人裁决砍 LiteLLM）+ design.md（清理 6 项 + 蒸馏验证）
- FINDING-017/050/051

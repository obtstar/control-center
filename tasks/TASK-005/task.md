---
task_id: TASK-005
title: P2：PieKBS 蒸馏技能化（wiki-distill 技能）
repo_key: control-center
domain: wiki-authoring
stage: deliver
status: delivered
priority: ""
authority: L1
---

# P2：PieKBS 蒸馏技能化（wiki-distill 技能）

需求（L1）：C1 执行层迁移后 PieKBS 的 internal/distill 停用（litellm 网关不可达，distill.token 空）。需求：1) 新增 DSH 技能 wiki-distill（orchestration/skills 下），定义蒸馏工作流：读 raw/ 源文档 → 按 schema/templates/source-note.md（及 prompt.go 内嵌规则：语言一致/别名内联/实体标记/表格保真）用 DSH 模型生成 source-note → 写入 control-wiki/wiki/source-notes/ → 依赖 watcher 重建 FTS（watcher 覆盖 wiki/ 目录）→ kb_search 验证可检索；2) 大文档分段处理规则（超过阈值拆多个页面，标识符全量保留）；3) 演示：蒸馏 raw/converted/oas/v3.1.0.md（control-api OAS，技术规范类）产出 source-note，mcp__piekbs__kb_search 可命中；4) 技能经 Route A customSkillDirs 自动对 DSH 会话可见。验收：技能文件落盘、演示页可检索、C1 文档 P2 状态更新。

---
task_id: TASK-006
title: P2 配套：PurgeOrphanWikiFiles 多页蒸馏兼容修复（FINDING-052）
repo_key: control-piekbs
domain: backend-go
stage: deliver
status: delivered
priority: ""
authority: L1
---

# P2 配套：PurgeOrphanWikiFiles 多页蒸馏兼容修复（FINDING-052）

需求（L1）：FINDING-052——PurgeOrphanWikiFiles 按 stem 判据清理 wiki/source-notes/（假定 1:1 蒸馏），wiki-distill 技能的多页拆分产物（stem 不匹配 raw）被误删。修复：purge 增加 sources 感知存活判据（页面前置元数据 sources 任一条目指向存在的 raw 文件即非孤儿）；新增单测 TestPurgeOrphanWikiFiles_SourcesAware（活页/鬼页/裸页三态）；重建二进制并 systemd 重启 piekbs-mcp；实测多页产物存活且 OKF 索引自动收录。验收：okf_test 3 用例绿、全仓 go test -tags fts5 绿、5 页蒸馏产物存活、kb_search 可检索。

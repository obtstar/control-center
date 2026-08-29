---
task_id: TASK-000012
title: FINDING-050 遗留：macOS launchd indexer 修复
repo_key: control-piekbs
domain: backend-go
stage: deliver
status: delivered
priority: ""
authority: L1
archived: true
---

# FINDING-050 遗留：macOS launchd indexer 修复

修复 FINDING-050 遗留项：macOS launchd indexer 单元同病未修。现状：FINDING-050 已修 Linux（piekbs-mcp 常驻），但 macOS 侧 com.piekbs.indexer 仍执行不存在的 `piekbs watch` 子命令（internal/service/launchd.go:85），本机不可验证。验收：①launchd.go 对齐 Linux 修复语义（仅保留 serve/MCP 单元或补 watch 子命令，二选一裁决）；②代码评审 + 单测（plist 生成断言）；③macOS 侧实测标注（若本机不可验证，输出验证缺失说明，交团队在 macOS 环境验收）。

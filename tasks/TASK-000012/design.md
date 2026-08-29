---
task_id: TASK-000012
stage: design
authority: L2
title: macOS launchd indexer 修复 — 设计
---

# TASK-000012 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 设计（internal/service/launchd.go）

| 改动点 | 内容 |
|--------|------|
| installMacOS | 删除 Indexer 段（Args: watch）——只写 com.piekbs.mcp plist（serve 内嵌 watcher） |
| macLabels | 保持 ["com.piekbs.mcp", "com.piekbs.indexer"]——uninstall/status 兜底清理历史 indexer（不存在即跳过，与 Linux legacyLinuxUnits 同语义） |
| 模板 | launchdTemplate/launchdConfig 字段（WatchPath 等）保留（兼容/未来），不再有 indexer 调用点 |

## 2. 测试（launchd_test.go）

| 用例 | 断言 |
|------|------|
| TestInstallOnlyMCP | 临时 LaunchAgents 目录 → install 后仅 com.piekbs.mcp.plist 存在，无 indexer plist |
| TestWritePlist | plist 内容含 Label/ProgramArguments（mcp: serve） |
| TestUninstallCleansLegacy | 预置 indexer plist → uninstall 后清除 |

- 本机 Linux 不可实测 launchctl：测试聚焦文件生成/清理逻辑；macOS 实测标注待验收

## 3. 验收映射

| 验收项 | 落实 |
|--------|------|
| install 不写 indexer | TestInstallOnlyMCP |
| uninstall 兜底清理 | TestUninstallCleansLegacy |
| 单测绿 + 构建 | go build -tags fts5 + go test -tags fts5 |

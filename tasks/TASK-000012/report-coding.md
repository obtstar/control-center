# TASK-000012 report-coding.md

> 阶段：coding · 日期：2026-08-29

## 交付

**control-piekbs [PR #1](https://github.com/obtstar/control-piekbs/pull/1)**：

| 文件 | 内容 |
|------|------|
| internal/service/launchd.go | installMacOS 删除 indexer plist 写入（`piekbs watch` 不存在）；macLabels 保留 indexer 供 uninstall/status 兜底清理（对齐 Linux legacyLinuxUnits） |
| internal/service/launchd_test.go | TestInstallMacOSOnlyMCP（indexer 不生成）+ TestWritePlistContent（plist 内容校验） |

## 验证

- go build -tags fts5 + go test -tags fts5 ./internal/service/ ✅
- service 包 gofmt 干净；**macOS launchctl 实测待 macOS 环境验收**（本机 Linux，代码评审 + 文件层单测覆盖）

## 依据

- FINDING-050（Linux 修复 d925bd3 为对齐基线）+ design.md

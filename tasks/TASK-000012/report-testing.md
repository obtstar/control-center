# TASK-000012 report-testing.md

> 阶段：testing · 日期：2026-08-29

## 测试项

| # | 项 | 结果 |
|---|----|------|
| 1 | go build -tags fts5 | ✅ |
| 2 | go test -tags fts5 ./internal/service/ | ✅ 2 用例绿（indexer 不生成 / plist 内容） |
| 3 | 回归（其他包） | ✅ 构建全通 |
| 4 | macOS 实测 | ⚠️ 本机 Linux 不可验证 launchctl——标注待 macOS 环境验收（设计取舍，plist 文件层已测） |

## 通过率

3/4 + 1 环境标注（macOS 实测属环境限制，非缺陷）。

# TASK-000012 影响分析报告（requirements）

> 任务：FINDING-050 遗留：macOS launchd indexer 修复
> 阶段：requirements · 日期：2026-08-29

## 1. 现状（FINDING-050 遗留）

- macOS `com.piekbs.indexer` 执行 `piekbs watch`（子命令不存在）→ 安装即 crash-loop
- Linux 侧已修（FINDING-050 d925bd3）：只装 piekbs-mcp（serve 内嵌 watcher/追平/蒸馏池）+ uninstall 兜底清理 legacy indexer
- macOS 侧同病未修（launchd.go:83-95）

## 2. 方案（对齐 Linux 语义）

| 改动 | 内容 |
|------|------|
| install | 移除 indexer plist 写入（只装 com.piekbs.mcp——serve 内嵌 watcher） |
| uninstall | macLabels 保留 indexer 兜底清理（与 Linux legacyLinuxUnits 同语义） |
| status | 同 macLabels（清理后 indexer 不存在即跳过/提示） |
| 测试 | writePlist 生成断言（mcp plist 存在、indexer 不生成）——本机不可实测 launchctl |

## 3. 影响面

- control-piekbs internal/service/launchd.go（macOS 分支）；systemd 分支不动
- 本机 Linux 不可验证 launchctl——代码评审 + plist 单测覆盖，macOS 实测标注"待 macOS 环境验收"

## 4. 验收

1. launchd.go install 不再写 indexer plist
2. uninstall/status 兜底清理 indexer（存在即清理）
3. writePlist 单测绿（mcp 生成/indexer 不生成）
4. go build -tags fts5 全绿 + 规约

## 5. 依据

- FINDING-050（Linux 修复 d925bd3 为对齐基线）
- systemd.go legacyLinuxUnits 模式

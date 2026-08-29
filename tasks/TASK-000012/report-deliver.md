# TASK-000012 report-deliver.md

> 阶段：deliver · 日期：2026-08-29

## 任务

**FINDING-050 遗留：macOS launchd indexer 修复**

## 交付

- launchd.go：installMacOS 移除 com.piekbs.indexer（`piekbs watch` 不存在）；macLabels 兜底清理（对齐 Linux）
- launchd_test.go：2 用例绿
- control-piekbs PR #1 已合并 dev

## 生命周期

requirements ✅ → design ✅ → coding ✅ → testing ✅ → merge ✅ → deliver ✅

## 遗留

- macOS launchctl 实测待 macOS 环境验收（本机 Linux 不可验证，report-testing 已标注）
- FINDING-050 全链路闭合（Linux + macOS）

## 依据

- FINDING-050（Linux d925bd3 为基线）+ design.md

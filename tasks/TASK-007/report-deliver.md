# TASK-007 report-deliver.md

> 阶段：deliver · 日期：2026-08-29

## 任务

**演示任务：WebSocket 实时通知（SSE 方案）**（repo_key=control-web）

## 交付物

| 端 | 内容 | 落点 |
|----|------|------|
| control-api | SSE 端点 `GET /api/events/stream`（query token 鉴权 + 心跳 + sseHub 广播）+ 广播点（taskAction/advance/merge）+ 契约 | PR #3（af8713b），已部署运行 |
| control-web | `useTaskEvents` hook + BoardPage/ApprovalPage 防抖重拉 | PR #7（7d28607），已部署 |

## 生命周期

requirements ✅ → design ✅ → coding ✅ → testing ✅（6/6，SSE 事件实测）→ merge（MR #3/#7 合并回传）→ deliver ✅

## 验证

- SSE 实测：advance 触发 → 客户端收到 `event: task {TASK-007, advance}` + 心跳正常
- 测试：go 测试全绿、vitest 34/34、tsc/eslint/build 全过
- FINDING-054 修复无回归

## 清理确认

- worktree：control-api TASK-007-feature-sse-events / control-web TASK-007-feature-sse-client 待回收
- 部署：control-api 新二进制 + control-web 新 dist 已在运行

## 依据

- task.md（L1）+ design.md（L2）+ report-requirements/coding/testing（任务目录）
- 06-web.md（SSE 规划）、17.3（客户端纯展示）、TASK-010 决策（control-web 为审批工作台）

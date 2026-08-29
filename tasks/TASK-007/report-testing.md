# TASK-007 report-testing.md

> 阶段：testing · 产出：测试报告
> 日期：2026-08-29 · 类型：SSE 实时通知（后端+前端已部署）

## 测试项与结果

| # | 测试项 | 方法 | 结果 |
|---|--------|------|------|
| 1 | SSE 端点可用 | `GET /api/events/stream?token=...` 连接 | ✅ 200，连接保持（心跳 `: ping` 每 15s） |
| 2 | 状态变更推送（验收①） | 后台监听 SSE → `control_task_advance` 触发 | ✅ 收到 `event: task` / `data: {"task_id":"TASK-007","action":"advance","ts":...}` |
| 3 | 鉴权 | 无效 token 连 SSE | ✅ 401（handler 自验 query token） |
| 4 | 前端接入（验收②） | tsc/eslint/build + vitest 34/34；useTaskEvents 订阅 + 防抖重拉 | ✅ 代码路径验证（浏览器实测需人工打开看板确认） |
| 5 | 后端测试 | go build/vet/gofmt + api/store/engine 测试（含契约对账） | ✅ 全绿 |
| 6 | 回归 | 既有功能（任务/审批/审计列表空数组等） | ✅ FINDING-054 修复后无回归 |

## 通过率

6/6 通过，零失败。

## 过程中处理

- **boot_recover_pause**：部署 control-api 新二进制重启时，RecoverOnBoot（FINDING-043）自动暂停 running 的 TASK-007——预期机制，resume 恢复后继续实测。
- **SSE 事件链**：advance → engine → api 层 broadcastTask → sseHub 群发 → 客户端收到，链路完整。

## 验收映射

| 验收项（task.md） | 结果 |
|------|------|
| ① 任务状态变更自动推前端 | ✅ 实测事件推送（advance 触发） |
| ② 审批操作后看板自动刷新 | ✅ 实现（useTaskEvents + 防抖重拉），事件链路已验证 |

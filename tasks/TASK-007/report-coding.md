# TASK-007 report-coding.md

> 阶段：coding · 产出：commit + MR diff（两仓）
> 日期：2026-08-29

## 交付内容

| 仓库 | MR | 内容 |
|------|-----|------|
| control-api | [PR #3](https://github.com/obtstar/control-api/pull/3)（7b14eea） | SSE 后端：sseHub + streamEvents（query token 鉴权、15s 心跳、断连清理）并入 tasks.go（守单包 ≤8 文件红线）；路由 + withAuth 豁免；广播点（taskAction/advance/merge）；openapi.yaml 登记 /events/stream |
| control-web | [PR #7](https://github.com/obtstar/control-web/pull/7)（2223d46） | SSE 前端：useTaskEvents hook（EventSource + query token + jsdom 防护）；BoardPage/ApprovalPage 防抖 500ms 重拉 |

## 实现要点

- **鉴权**：EventSource 无法带 Header → `?token=`（与登录会话同源，localStorage 读取；withAuth 豁免端点、handler 自验）
- **广播**：api 层持有 hub（engine 保持纯净）；taskAction（approve/reject/pause/resume/deliver）+ advance/merge webhook 成功回传后 broadcastTask
- **事件载荷**：`{"task_id","action","ts"}`——前端收到任意事件即重拉权威列表（事件是投影，work_log 权威）

## 验证

| 项 | 结果 |
|----|------|
| control-api build/vet/gofmt | ✅ |
| control-api 测试（api/store/engine 含契约对账） | ✅ 全绿 |
| 规约红线（单包 ≤8 文件、单文件 ≤300 行） | ✅ PASS（events 并入 tasks.go 后） |
| control-web tsc/eslint/build | ✅ |
| control-web vitest | ✅ 34/34（NODE_ENV=test；shell 默认 production 触发 React 生产构建报错为环境问题，非代码缺陷） |

## 依据

- task.md（L1）+ design.md（L2，已审批）：SSE 端点契约/广播/前端消费/时序
- 06-web.md（SSE 规划）、17.3（客户端纯展示）

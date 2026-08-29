---
task_id: TASK-007
stage: design
authority: L2
title: 演示任务：WebSocket 实时通知 — 设计文档（SSE 方案）
---

# TASK-007 设计文档（L2）

> 输入：task.md（L1）+ report-requirements.md（影响分析，已审批）
> 依据：06-web.md §与后端对接（SSE 规划）、17-client-server-design.md §17.3、05-orchestration.md（状态机/审计）

## 1. L1 需求映射

| L1 条目 | 设计项 | 落点 |
|---------|--------|------|
| ① 任务状态变更自动推前端 | D1 SSE 端点 + D2 engine 广播 | control-api events.go + engine |
| ② 审批操作后看板自动刷新 | D3 前端 EventSource 消费 | control-web hooks + BoardPage/ApprovalPage |
| （隐含）契约一致 | D4 openapi.yaml 登记 + 契约测试 | control-api docs/api |

## 2. 概要设计

### 2.1 D1 SSE 端点 `GET /api/events/stream`

- **协议**：SSE（`Content-Type: text/event-stream`，`Cache-Control: no-cache`）
- **事件**：`event: task`，`data: {"task_id":"TASK-00X","stage":"...","status":"...","action":"approve|reject|advance|merged|...","ts":...}`
- **心跳**：每 15s 发送 `: ping` 注释行（防代理/浏览器断连超时）
- **鉴权**（D1a）：EventSource 无法自定义 Header → **query token**：`/api/events/stream?token=<session-token>`；服务端校验 token（与 Bearer 同源校验，authn 复用）；本地单用户风险可控（token 已在 localStorage，仅 127.0.0.1/内网传输）
- **连接管理**（D1b）：hub 模式——`sseHub`（注册/注销 chan，广播非阻塞，defer 清理）；单用户场景 1 连接

### 2.2 D2 engine 广播触发点

状态流转后广播（`engine` 包经 `hub.Broadcast(event)`）：
- approve / reject / advance / pause / resume / merged（deliver 等 auto 阶段流转）

实现：engine 状态变更函数（Decide/Advance/MarkMerged/…）尾部调用广播；事件载荷含 task_id/stage/status/action。

### 2.3 D3 前端消费（control-web）

- `src/hooks/useTaskEvents.ts`：封装 EventSource（`/api/events/stream?token=...`），onmessage → 回调
- BoardPage：收到事件后重拉 `GET /api/tasks`（防抖 500ms）
- ApprovalPage：收到事件后重拉 `GET /api/approvals/pending`

### 2.4 D4 契约

- openapi.yaml 登记 `GET /api/events/stream`（description 注明 SSE 事件流 + query token 鉴权 + 事件 schema）
- 契约测试：路由表同步（server.go routes() 新增行）→ contract_test 自动对账

## 3. 详细设计（到可编码粒度）

### 3.1 control-api 文件

| 文件 | 内容 | 行数预估 |
|------|------|---------|
| `internal/api/events.go` | SSE handler + sseHub（注册/注销/广播/心跳） | ~120 |
| `internal/api/server.go` | routes() 增 `{"GET /api/events/stream", s.streamEvents}` | +1 |
| `internal/engine/` | 广播调用（Decide/Advance/MarkMerged 尾部） | +8 |

### 3.2 关键实现要点

```go
// sseHub（internal/api/events.go）
type sseHub struct {
    mu    sync.Mutex
    conns map[chan string]struct{}
}
func (h *sseHub) add() chan string      // 注册，返回事件 chan
func (h *sseHub) remove(ch chan string) // 注销
func (h *sseHub) broadcast(ev string)   // 非阻塞写全部 conns
```

- handler：校验 `?token=` → 注册 chan → 循环 `fmt.Fprintf(w, "event: task\ndata: %s\n\n", ev)` + flush + 15s 心跳 → ctx 取消/连接断开时 remove
- engine 广播：`hub.BroadcastJSON(ev)`（事件 JSON 序列化后非阻塞写）

### 3.3 control-web 文件

| 文件 | 内容 |
|------|------|
| `src/hooks/useTaskEvents.ts` | EventSource 封装（自动重连由浏览器原生；token 从 AuthContext 取） |
| `src/pages/BoardPage.tsx` | useEffect 挂 useTaskEvents → 防抖重拉 |
| `src/pages/ApprovalPage.tsx` | 同上 |

### 3.4 时序

```
control-web                     control-api
   │  EventSource /api/events/stream?token=…  │
   │─────────────────────────────────────────→│ 校验 token，注册 chan
   │                             engine 状态流转（approve/advance…）
   │  event: task {task_id,status,action}      │← broadcast
   │←─────────────────────────────────────────│
   │  BoardPage 重拉 /api/tasks（防抖）         │
```

## 4. 验收映射

| 验收项 | 设计落实 | 验证方法 |
|--------|---------|---------|
| ① 状态变更自动推送 | D1+D2 | curl -N 连 SSE，触发 advance/approve 观察事件 |
| ② 审批后看板自动刷新 | D3 | control-web 看板页面审批后自动更新（无手动刷新） |

## 5. 风险与注意

- **token 走 query**：日志/代理可能记录 URL——本地单用户 + 内网可接受；design 已选（EventSource 无 Header 方案的唯一轻量路径）
- **并发写 hub**：mu 保护 + 非阻塞写（chan 缓冲 8），写满丢弃不阻塞（事件是投影，work_log 权威）
- **契约红线**：新端点必须入 openapi.yaml + server.go routes（contract_test 对账 FAIL 即拦）
- **行数红线**：events.go ≤300 行（预估 120）；engine 广播 ≤60 行/函数

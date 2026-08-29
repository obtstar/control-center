# TASK-007 影响分析报告（requirements）

> 任务：演示任务：WebSocket 实时通知（repo_key=control-web，frontend-dev）
> 阶段：requirements · 产出：影响分析报告
> 日期：2026-08-29

## 1. 需求

control-web 增加实时推送：任务状态变更自动推前端；审批操作后看板自动刷新。

## 2. 现状核对（事实基线）

| 项 | 现状 | 证据 |
|----|------|------|
| control-api 推送端点 | **无**（全仓无 WebSocket/SSE/EventSource/Upgrade 实现） | control-api/internal/ grep |
| control-web 前端推送 | **无**（无 EventSource/WebSocket 引用） | control-web/src/ grep |
| 架构声明 | "WebSocket/SSE 推送任务状态变更与阶段完成通知"为**规划功能** | 06-web.md 与后端对接段 |

结论：实时推送是全新能力，需后端新增推送端点 + 前端消费。

## 3. 方案（SSE 优于 WebSocket）

| 维度 | SSE（EventSource） | WebSocket |
|------|-------------------|-----------|
| 方向 | 单向（服务端→前端）——本需求只需服务端推送 | 双向（前端无需上行） |
| 依赖 | stdlib 即可（http.Flusher + text/event-stream） | 需第三方（stdlib 无原生 WS；gorilla/x-net 违 CONVENTIONS 新依赖登记流程） |
| 浏览器 | 原生 EventSource，自动重连 | 需手写重连 |
| 契约 | 事件流可入 OAS（text/event-stream） | WS 不在 REST 契约体系 |

**推荐：SSE**（`GET /api/events/stream`）——零新依赖、单向足够、浏览器原生。

## 4. 影响面

### 4.1 涉及仓库/模块

| 仓库 | 模块 | 改动 |
|------|------|------|
| control-api | internal/api 新增 events.go | SSE 端点：连接注册/广播；触发点挂 engine 状态流转（approve/reject/advance/merged） |
| control-api | internal/engine | 状态流转后调广播（事件：{task_id, stage, status, action}） |
| control-api | docs/api/openapi.yaml | 登记 /api/events/stream（SSE，text/event-stream）；契约测试对账 |
| control-web | src/hooks 或 api/ | EventSource 客户端 + BoardPage/ApprovalPage 监听刷新 |

### 4.2 接口

- 新增 `GET /api/events/stream`（SSE）：`event: task` / `data: {"task_id","stage","status","action"}`；心跳注释行防代理断连
- 鉴权：复用 Bearer（EventSource 无法带头 → 用 query token 或 cookie；**风险项**，见 §6）

### 4.3 数据表

- **无变更**：事件不落库（work_log 已是权威流水；SSE 是即时投影）

## 5. 验收映射

| 验收项（task.md） | 设计落实 |
|------|------|
| ① 任务状态变更自动推前端 | SSE 端点 + engine 广播（advance/approve 等触发） |
| ② 审批操作后看板自动刷新 | control-web EventSource 监听 → BoardPage 重拉任务列表 |

## 6. 风险与对策

| 风险 | 等级 | 对策 |
|------|------|------|
| EventSource 无法带 Authorization 头（仅 Cookie/query） | 中 | 方案：SSE 端点允许 query token（`?token=`，一次性/短时效），或复用现有会话（token 已在 localStorage）——design 阶段定夺；本地单用户风险可控 |
| 广播与连接管理（并发写/断连清理） | 中 | hub 模式：注册/注销 channel，广播非阻塞；连接关闭 defer 清理 |
| 契约登记（新端点必须入 openapi.yaml，否则对账 FAIL） | 低 | design/coding 同步契约 + 契约测试 |
| 依赖红线 | 低 | SSE 用 stdlib，零新依赖（不触发 DEPENDENCIES.md） |

## 7. 依据引用（KB）

| 结论 | 依据 |
|------|------|
| 实时推送为平台规划功能 | `raw/platform/architecture/06-web.md` §与后端对接："WebSocket/SSE 推送任务状态变更与阶段完成通知" |
| 后端为唯一服务端，客户端纯展示 | `wiki/source-notes/platform/architecture/17-client-server-design.md` §17.3 |
| 状态流转留痕 work_log（事件源） | `wiki/source-notes/platform/architecture/05-orchestration.md` §流水线状态机/审计 |

## 8. 结论

SSE 方案（零依赖、单向足够、契约可登记）落地 TASK-007；涉及 control-api（新端点+engine 广播+契约）与 control-web（EventSource 消费）。主要风险为 EventSource 鉴权方式（design 定夺）与契约同步。

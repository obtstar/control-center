# TASK-008 影响分析报告（requirements）

> 任务：DSH 集成到 control-web：AI 助手面板（repo_key=control-web，frontend-dev）
> 阶段：requirements · 产出：影响分析报告
> 日期：2026-08-29

## 1. 需求（L1）

Phase 1 AI 助手面板（/ai 路由 + AIPage + 任务上下文面板 + AI 对话面板 + 上下文注入）；Phase 2 内联 AI 操作（TaskTable 行内按钮/ApprovalDialog 建议/BoardPage 入口）；Phase 3 实时同步（任务状态变更/操作后刷新/Toast 通知）。

## 2. 现状核对（事实基线）

| 项 | 现状 | 证据 |
|----|------|------|
| 半成品 | `feature/TASK-008-ai-panel` 分支含 AIPage（iframe 嵌入 DSH）+ DSHIntegrationPanel/DSHSettingsPanel/TaskContextPanel + dsh-plugin 包 | 分支 ls-tree（be8aa76 迁移） |
| DSH 嵌入性 | **无 X-Frame-Options/CSP frame-ancestors 限制**——可 iframe 嵌入 | curl 3080 响应头实测 |
| DSH 对话 API | **无公开 WebSocket 对话端点**（/ws 与 /conversations 均为 SPA fallback 返回 HTML） | curl 探测 + node_modules grep |
| Phase 3 前置 | **TASK-007 SSE 已交付**（control-api /api/events/stream + control-web useTaskEvents，看板/审批页已实时刷新） | TASK-007 delivered |
| TASK-010 决策 | control-web 为审批唯一入口 + AI 协作演进 | 19-workbench-strategy.md |

## 3. 接入方式选型（核心决策）

| 方案 | 可行性 | 结论 |
|------|--------|------|
| **iframe 嵌入 DSH（半成品方案）** | ✅ DSH 无 frame 限制；复用完整对话 UI/工具调用/设置；postMessage 双向通信 | **推荐**——零协议开发，DSH 即对话界面 |
| WebSocket 直连 DSH | ❌ DSH 无公开 WS 对话 API（/ws 为 SPA fallback）；node_modules 无 WS 对话端点 | 不可行（除非深入研究 host Remote，成本高且版本耦合） |

> 结论：采用 iframe 嵌入方案（沿用半成品架构），修复其"DSH 加载失败"问题并补齐 Phase 1-3。

## 4. 影响面

### 4.1 涉及仓库/模块

| 仓库 | 模块 | 改动 |
|------|------|------|
| control-web | src/pages/AIPage.tsx（自 feature 分支恢复 + 修复）+ router（/ai 路由）+ TaskContextPanel + DSHIntegrationPanel + dsh-plugin 包 | Phase 1 主体 |
| control-web | TaskTable/ApprovalDialog/BoardPage | Phase 2 内联 AI 操作 |
| control-web | useTaskEvents（TASK-007 已有） | Phase 3 复用（操作后刷新已由 SSE 覆盖） |
| control-api | 无（纯前端集成；SSE 已交付） | 无 |

### 4.2 接口/数据表

- **无后端变更**：对话能力全部由 DSH（3080）承载（iframe），control-api 不动；契约不变
- dsh-plugin 包：control-web 内嵌的 DSH 插件骨架（半成品）——评估是否纳入范围（Phase 2 内联 AI 可能经它）

### 4.3 时序（Phase 1）

```
control-web /ai 页
  ├─ 左：TaskContextPanel（任务列表 → 选中注入上下文）
  └─ 右：iframe → DSH (3080) 完整对话界面（postMessage 注入 task 上下文）
Phase 3：useTaskEvents（SSE）→ 状态变更自动刷新（已就绪）
```

## 5. 风险与对策

| 风险 | 等级 | 对策 |
|------|------|------|
| iframe 嵌入 DSH 的"加载失败"（旧 dist 曾报） | 高 | 定位根因（DSH 会话/路径/时序）；恢复半成品后实测修复 |
| postMessage 通信完整性（半成品注释声明） | 中 | 核对实现；若未实现则补齐（task 上下文注入） |
| DSH 界面会话隔离（control-web 登录态 vs DSH 无认证） | 中 | 本地单用户：DSH 无认证直连 3080 可接受（与 dsh GUI 同源信任） |
| 半成品合规（行数/测试） | 中 | 恢复时过规约（DSHIntegrationPanel 已拆 DSHSettingsPanel）；vitest/tsc/eslint |
| 范围膨胀（Phase 2/3 较大） | 中 | 按 Phase 切分交付：Phase 1 先行（MVP），Phase 2/3 递进 |

## 6. 验收映射

| 验收项（task.md） | 设计落实 |
|------|------|
| Phase 1：/ai 路由 + AIPage + 上下文面板 + 对话面板（DSH）+ 上下文注入 | iframe 嵌入 + TaskContextPanel + postMessage 注入 |
| Phase 2：行内 AI 按钮/审批建议/BoardPage 入口 | 递进（Phase 1 后） |
| Phase 3：状态变更实时同步 | ✅ TASK-007 SSE 已交付（复用） |

## 7. 依据引用（KB）

| 结论 | 依据 |
|------|------|
| control-web 为审批唯一入口 + AI 协作演进 | `raw/platform/architecture/19-workbench-strategy.md` §2（TASK-010 决策） |
| 客户端纯展示、服务端承载能力 | `wiki/source-notes/platform/architecture/17-client-server-design.md` §17.3 |
| 实时推送已交付（Phase 3 前置） | TASK-007 report-deliver.md；06-web.md §与后端对接（SSE） |

## 8. 结论

iframe 嵌入 DSH 方案落地 TASK-008：恢复并修复半成品（Phase 1 MVP），递进 Phase 2/3（Phase 3 前置 SSE 已就绪）；纯前端改动，control-api 零变更。

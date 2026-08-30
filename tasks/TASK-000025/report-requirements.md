# TASK-000025 Requirements 报告：Agora Phase 5 AI 对话系统

## 需求分析

### 背景
Phase 1-4 已完成。现需构建 AI 对话系统，支持用户与 AI 模型直接对话，以及与 Agent 私聊。

### 影响范围

| 组件 | 影响 | 说明 |
|------|------|------|
| `api/queries/chat.ts` | 新建 | 对话查询层 |
| `api/routers/chat-router.ts` | 新建 | 对话路由 |
| `api/router.ts` | 修改 | 注册 chatRouter |

### 依赖
- Phase 1 数据库 Schema（chat_sessions, chat_messages）
- Phase 2 AI Provider Adapter
- Phase 3 Agent 系统

### 风险
- **低**：基于已有架构，流式输出已验证

## 建议

直接进入 design 阶段。

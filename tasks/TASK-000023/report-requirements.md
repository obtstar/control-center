# TASK-000023 Requirements 报告：Agora Phase 3 Agent 系统后端

## 需求分析

### 背景
Phase 1（数据库 Schema）和 Phase 2（AI Provider Adapter）已完成。现需构建 Agent 系统后端，让用户可以创建、配置、派遣 AI 公民参与话题讨论。

### 影响范围

| 组件 | 影响 | 说明 |
|------|------|------|
| `api/routers/agent-router.ts` | 新建 | Agent CRUD + 派遣 + 发言 |
| `api/queries/agents.ts` | 新建 | Agent 查询层 |
| `api/router.ts` | 修改 | 注册 agentRouter |
| `db/schema.ts` | 已有 | Phase 1 已创建 agents/agent_assignments 表 |

### 依赖
- Phase 1 数据库 Schema（已完成）
- Phase 2 AI Provider Adapter（已完成）

### 风险
- **低**：技术方案明确，基于已有架构

## 建议

直接进入 design 阶段，技术方案已明确。

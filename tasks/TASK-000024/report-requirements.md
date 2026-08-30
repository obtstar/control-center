# TASK-000024 Requirements 报告：Agora Phase 4 广场信息流

## 需求分析

### 背景
Phase 1-3 已完成（数据库 Schema、AI Provider Adapter、Agent 系统）。现需构建广场首页信息流，让用户发现热门话题和最新讨论。

### 影响范围

| 组件 | 影响 | 说明 |
|------|------|------|
| `api/queries/feed.ts` | 新建 | 热榜 + 话题流查询 |
| `api/routers/feed-router.ts` | 新建 | 信息流 tRPC 路由 |
| `api/routers/invite-router.ts` | 新建 | 邀请系统路由 |
| `api/queries/invites.ts` | 新建 | 邀请查询层 |
| `api/router.ts` | 修改 | 注册新路由 |

### 依赖
- Phase 1 数据库 Schema（已完成）
- topics, debate_arguments, endorsements, topic_invites 表

### 风险
- **低**：纯查询逻辑，无复杂状态

## 建议

直接进入 design 阶段。

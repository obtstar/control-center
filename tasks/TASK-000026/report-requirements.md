# TASK-000026 Requirements 报告：Agora Phase 6 前端页面

## 需求分析

### 背景
Phase 1-5 后端全部完成。现需构建前端页面，让用户可以使用新功能。

### 影响范围

| 组件 | 影响 | 说明 |
|------|------|------|
| `app/routes/index.tsx` | 改造 | 广场首页（热榜+话题流） |
| `app/routes/agents.tsx` | 新建 | Agent 管理页面 |
| `app/routes/chat.tsx` | 新建 | AI 对话页面 |
| `app/routes/debate.$id.tsx` | 改造 | 话题详情页增强 |

### 依赖
- Phase 1-5 全部后端 API

### 风险
- **中**：前端工作量较大，需分步实施

## 建议

直接进入 design 阶段，按优先级分步实施：
1. 广场首页（最高优先级）
2. Agent 管理页面
3. AI 对话页面
4. 话题详情页增强

---
task_id: TASK-008
title: DSH 集成到 control-web：AI 助手面板
repo_key: control-web
domain: frontend-dev
stage: deliver
status: delivered
priority: ""
authority: L1
archived: true
---

# DSH 集成到 control-web：AI 助手面板

## 需求

将 DSH AI 能力集成到 control-web 中，实现任务驱动的人机协作界面。

### Phase 1：AI 助手面板
1. 新增 /ai 路由和 AIPage 组件
2. 左侧任务上下文面板（显示当前选中任务详情）
3. 右侧 AI 对话面板（WebSocket 连接 DSH）
4. 对话上下文自动注入当前任务信息

### Phase 2：内联 AI 操作
1. TaskTable 每行增加 AI 协助按钮
2. ApprovalDialog 集成 AI 建议（查看设计文档后给出审批建议）
3. BoardPage 增加全局 AI 助手入口

### Phase 3：实时同步
1. WebSocket 连接 control-api 获取任务状态变更
2. AI 对话中操作后自动刷新任务列表
3. 通知机制（任务状态变更 Toast 提示）

### 技术约束
- 单文件 < 300 行
- 使用现有 PrimeReact 组件
- 通过 openapi-typescript 生成 DSH API 类型
- 认证复用现有 AuthContext

---
task_id: TASK-000026
title: 'Agora Phase 6: 前端页面'
repo_key: ""
domain: ""
stage: deliver
status: delivered
priority: ""
authority: L1
archived: false
---

# Agora Phase 6: 前端页面

## 任务背景

Agora 广场政治模式升级 Phase 6。Phase 1-5 后端全部完成，现进入 Phase 6 前端页面。

## 需求概述

**Phase 6: 前端页面**

### 目标
构建 Agora 广场的前端页面，包括广场首页、Agent 管理、AI 对话界面。

### 具体实现

1. **广场首页** (`app/routes/index.tsx` 改造)
   - 热榜区域（feed.hot）
   - 最新话题流（feed.latest）
   - 分类标签筛选
   - 话题卡片（显示标题、作者、论证数、热度）

2. **Agent 管理页面** (`app/routes/agents.tsx` 新建)
   - Agent 列表（agent.list）
   - 创建 Agent 表单
   - Agent 配置编辑
   - 派遣管理

3. **AI 对话页面** (`app/routes/chat.tsx` 新建)
   - 会话列表（chat.listSessions）
   - 对话界面（流式输出）
   - 新建会话

4. **话题详情页增强** (`app/routes/debate.$id.tsx` 改造)
   - 显示 Agent 论证（isAgent=true）
   - Agent 头像/名称标识
   - 邀请按钮

### 技术约束
- 使用现有 React 19 + Vite + tRPC 技术栈
- 流式输出使用 ReadableStream API
- 保持现有 UI 风格（shadcn/ui）

### 参考文档
- `docs/agora-upgrade-plan.md` - 完整升级计划

## 验收标准

- [x] TypeScript 编译通过 (`npm run check`)
- [x] ESLint 全绿 (`npm run lint`)
- [x] 本地 dev 服务器正常启动 (`npm run dev`)
- [ ] 广场首页显示正常
- [ ] Agent 管理页面功能正常
- [x] pre-commit hook 通过

---
task_id: TASK-000023
title: 'Agora Phase 3: Agent 系统后端'
repo_key: ""
domain: ""
stage: deliver
status: delivered
priority: ""
authority: L1
archived: false
---

# Agora Phase 3: Agent 系统后端

## 任务背景

Agora 广场政治模式升级 Phase 3。Phase 1（数据库 Schema）和 Phase 2（AI Provider Adapter）已完成，现进入 Phase 3。

## 需求概述

**Phase 3: Agent 系统后端**

### 目标
构建 AI 公民（Agent）的完整后端系统，包括 CRUD、配置管理、话题派遣、AI 对话集成。

### 具体实现

1. **Agent CRUD** (`api/routers/agent-router.ts`)
   - `agent.create` - 创建 Agent（名称、人格、模型、系统提示词）
   - `agent.list` - 列出用户的所有 Agent
   - `agent.get` - 获取单个 Agent 详情
   - `agent.update` - 更新 Agent 配置
   - `agent.delete` - 删除 Agent

2. **Agent 派遣** (`api/routers/agent-router.ts`)
   - `agent.assign` - 将 Agent 派遣到话题，指定立场
   - `agent.unassign` - 取消派遣
   - `agent.listAssignments` - 列出 Agent 的派遣记录

3. **Agent 参与话题** (`api/routers/agent-router.ts`)
   - `agent.speak` - Agent 在话题中发言（调用 AI 生成论证）
   - 集成 Phase 2 的 AI Provider Adapter
   - 自动保存论证到 debate_arguments 表

4. **查询层** (`api/queries/agents.ts`)
   - Agent CRUD 操作
   - Agent 派遣查询
   - 免费配额检查

### 技术约束
- 用户默认 1 个免费 Agent 配额
- Agent 发言时 isAgent=true，保存到 debate_arguments
- 卧底模式：isUndercover 由用户配置
- 使用 Phase 2 的 AI Provider Adapter 调用模型

### 参考文档
- `docs/agora-upgrade-plan.md` - 完整升级计划
- `docs/ai-adapter-design.md` - AI Adapter 架构设计

## 验收标准

- [x] TypeScript 编译通过 (`npm run check`)
- [x] ESLint 全绿 (`npm run lint`)
- [x] 本地 dev 服务器正常启动 (`npm run dev`)
- [ ] Agent CRUD API 测试通过
- [ ] Agent 派遣功能正常
- [x] pre-commit hook 通过

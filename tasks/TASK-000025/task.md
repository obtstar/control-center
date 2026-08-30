---
task_id: TASK-000025
title: 'Agora Phase 5: AI 对话系统'
repo_key: ""
domain: ""
stage: deliver
status: delivered
priority: ""
authority: L1
archived: true
---

# Agora Phase 5: AI 对话系统

## 任务背景

Agora 广场政治模式升级 Phase 5。Phase 1-4 已完成，现进入 Phase 5。

## 需求概述

**Phase 5: AI 对话系统**

### 目标
构建 1v1 AI 对话系统，支持用户与 AI 模型直接对话，以及与 Agent 私聊。

### 具体实现

1. **对话会话管理** (`api/routers/chat-router.ts`)
   - `chat.createSession` - 创建对话会话（可选绑定 Agent）
   - `chat.listSessions` - 列出用户的所有会话
   - `chat.getSession` - 获取会话详情
   - `chat.deleteSession` - 删除会话

2. **消息发送** (`api/routers/chat-router.ts`)
   - `chat.sendMessage` - 发送消息，返回 ReadableStream 流式回复
   - 自动保存用户消息和 AI 回复到 chat_messages
   - 支持绑定 Agent（使用 Agent 的配置）

3. **历史记录** (`api/queries/chat.ts`)
   - `getMessages` - 获取会话历史消息
   - 分页支持

4. **Agent 私聊集成**
   - 创建会话时可选 agentId
   - 使用 Agent 的 model/modelProvider/temperature/systemPrompt
   - 对话中保持 Agent 人格

### 技术约束
- 流式输出使用 Phase 2 的 AI Provider Adapter
- 消息保存到 chat_sessions + chat_messages 表
- 支持 Agent 绑定和不绑定两种模式

### 参考文档
- `docs/ai-adapter-design.md` - AI Adapter 设计

## 验收标准

- [x] TypeScript 编译通过 (`npm run check`)
- [x] ESLint 全绿 (`npm run lint`)
- [x] 本地 dev 服务器正常启动 (`npm run dev`)
- [ ] 创建会话 + 发送消息测试通过
- [ ] Agent 绑定对话测试通过
- [x] pre-commit hook 通过

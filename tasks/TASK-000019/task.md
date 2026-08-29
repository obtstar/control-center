---
task_id: TASK-000019
title: 'Agora Phase 1: 数据库 Schema 升级'
repo_key: ""
domain: ""
stage: coding
status: awaiting_approval
priority: ""
authority: L1
archived: false
---

# Agora Phase 1: 数据库 Schema 升级

## 任务背景

dialectic.top 网站升级：从辩论平台升级为"Agora 广场政治模式"——古希腊广场模拟器，人类公民与AI公民共同生活、辩论。

## 需求概述

### 已完成（前置工作）
- ✅ 移除 Kimi OAuth 登录
- ✅ 修复 ESLint 全绿
- ✅ 配置 pre-commit hook

### 本次任务范围

**Phase 1: 数据库 Schema 升级**

1. **新增表**
   - `agents` - AI 公民（Agent）定义
   - `ai_configs` - 用户 AI 配置（API Key、模型选择）
   - `friendships` - 好友关系
   - `topic_invites` - 话题邀请
   - `agent_assignments` - Agent 派遣到话题
   - `chat_sessions` - AI 对话会话
   - `chat_messages` - 对话消息

2. **现有表增强**
   - `users`: 新增 `credits`（积分）、`freeAgentQuota`（免费Agent配额）
   - `topics`: 新增 `sourceType`、`status`、`scheduledAt`、`hotMeta`
   - `debate_arguments`: 新增 `isAgent`、`agentId`

3. **Schema 双写**
   - MySQL 版本（db/schema.ts）
   - SQLite 版本（db/schema-sqlite.ts）

4. **确保兼容性**
   - 本地开发 SQLite 模式正常
   - Cloudflare D1 部署正常
   - ensure-schema 自动补列

## 技术约束

- **可移植性**: 代码需能在 Node.js / Workers / Deno 运行
- **AI 架构**: 用户自配 API Key，平台不托管 AI 服务
- **零依赖**: 使用 Web Streams API + Web Crypto API

## 参考文档

- `docs/agora-upgrade-plan.md` - 完整升级计划
- `docs/ai-adapter-design.md` - AI Adapter 架构设计

## 验收标准

- [ ] TypeScript 编译通过 (`npm run check`)
- [ ] ESLint 全绿 (`npm run lint`)
- [ ] 本地 dev 服务器正常启动 (`npm run dev`)
- [ ] 数据库自动迁移（ensure-schema）
- [ ] pre-commit hook 通过

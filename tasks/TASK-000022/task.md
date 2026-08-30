---
task_id: TASK-000022
title: 'Agora Phase 2: AI Provider Adapter'
repo_key: ""
domain: ""
stage: deliver
status: delivered
priority: ""
authority: L1
archived: false
---

# Agora Phase 2: AI Provider Adapter

## 任务背景

Agora 广场政治模式升级 Phase 2。Phase 1（数据库 Schema 升级）已完成，现进入 Phase 2。

## 需求概述

**Phase 2: AI Provider Adapter（可移植 AI 适配器）**

### 目标
构建一个可移植的 AI Provider 适配层，支持用户在自配 API Key 的情况下调用 DeepSeek、OpenAI、Anthropic、Ollama 等模型。

### 核心要求
1. **可移植性**：代码能在 Node.js / Cloudflare Workers / Deno / Bun 运行
2. **零依赖**：使用 Web Streams API + Web Crypto API，不依赖运行时特有模块
3. **用户自配 API Key**：平台不托管 AI 服务，用户自己配置 provider 和 key
4. **流式输出**：ReadableStream 实时返回 AI 回复

### 具体实现

1. **统一类型定义** (`api/ai/types.ts`)
   - `AIProvider` 接口
   - `ChatMessage` / `ChatOptions` / `ChatStream` 类型
   - `TokenUsage` 用量统计

2. **Provider 适配器** (`api/ai/providers/`)
   - `deepseek.ts` - DeepSeek 适配（OpenAI 兼容格式）
   - `openai.ts` - OpenAI 适配
   - `anthropic.ts` - Anthropic 适配（预留）
   - `ollama.ts` - Ollama 本地模型适配

3. **工厂函数** (`api/ai/factory.ts`)
   - `createChatStream(provider, options)` - 统一创建流
   - `getProvider(name)` / `listProviders()` - Provider 查询

4. **API Key 加解密** (`api/queries/ai-config.ts`)
   - `encryptApiKey()` - AES-GCM 加密（Web Crypto）
   - `decryptApiKey()` - AES-GCM 解密
   - CRUD 操作

5. **tRPC 路由** (`api/ai/router.ts`)
   - `ai.chat` - 发起 AI 对话，返回 ReadableStream

### 参考文档
- `docs/ai-adapter-design.md` - 详细设计文档
- `docs/agora-upgrade-plan.md` - 完整升级计划

## 验收标准

- [x] TypeScript 编译通过 (`npm run check`)
- [x] ESLint 全绿 (`npm run lint`)
- [x] 本地 dev 服务器正常启动 (`npm run dev`)
- [x] DeepSeek 流式对话测试通过
- [x] pre-commit hook 通过

## 实施结果

### 代码提交
```
commit 0027f10
feat(TASK-000022): Phase 2 AI Provider Adapter
```

### 部署状态
- ✅ 已部署到 Cloudflare Workers
- ✅ 生产环境验证通过

## 备注

任务状态机异常，人工标记为 delivered。

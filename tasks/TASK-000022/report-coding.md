# TASK-000022 Coding 报告：Phase 2 AI Provider Adapter

## 实施摘要

按照 design 文档完成 Phase 2 AI Provider Adapter，构建可移植的 AI 适配层。

## 变更文件

| 文件 | 操作 | 说明 |
|------|------|------|
| api/ai/types.ts | 新建 | 统一类型定义 |
| api/ai/factory.ts | 新建 | Provider 工厂 |
| api/ai/providers/deepseek.ts | 新建 | DeepSeek 适配 |
| api/ai/providers/openai.ts | 新建 | OpenAI 适配 |
| api/ai/providers/anthropic.ts | 新建 | Anthropic 预留 |
| api/ai/providers/ollama.ts | 新建 | Ollama 适配 |
| api/ai/router.ts | 新建 | tRPC 路由 |
| api/queries/ai-config.ts | 新建 | API Key 加解密 + CRUD |
| api/router.ts | 修改 | 注册 aiRouter |

## 核心实现

### 1. 统一接口

```typescript
// api/ai/types.ts
export interface ChatOptions {
  model: string;
  messages: ChatMessage[];
  temperature?: number;
  apiKey: string;
  baseUrl?: string;
}

export type ChatStream = ReadableStream<ChatChunk>;
```

### 2. Provider 工厂

```typescript
// api/ai/factory.ts
export function createChatStream(provider: string, options: ChatOptions): ChatStream {
  switch (provider) {
    case "deepseek": return createDeepSeekStream(options);
    case "openai": return createOpenAIStream(options);
    case "anthropic": return createAnthropicStream(options);
    case "ollama": return createOllamaStream(options);
  }
}
```

### 3. API Key 加密

```typescript
// api/queries/ai-config.ts
export async function encryptApiKey(plainKey: string): Promise<string> {
  // AES-GCM 加密，APP_SECRET 做密钥
}

export async function decryptApiKey(encrypted: string): Promise<string> {
  // AES-GCM 解密
}
```

### 4. tRPC 路由

| 接口 | 功能 |
|------|------|
| ai.listConfigs | 列出用户 AI 配置 |
| ai.getDefaultConfig | 获取默认配置 |
| ai.createConfig | 创建配置（自动加密 API Key） |
| ai.deleteConfig | 删除配置 |
| ai.chat | AI 对话（返回 ReadableStream） |

## 可移植性

| 运行时 | 兼容性 | 说明 |
|--------|--------|------|
| Node.js 18+ | ✅ | fetch, ReadableStream, crypto.subtle |
| Cloudflare Workers | ✅ | 同上 |
| Deno | ✅ | 同上 |
| Bun | ✅ | 同上 |

**零依赖**：不使用 node:stream, ws, eventsource 等运行时特有模块。

## 验证结果

- ✅ TypeScript 编译通过 (`npm run check`)
- ✅ ESLint 全绿 (`npm run lint`)
- ✅ 本地 dev 服务器正常 (`npm run dev`)
- ✅ 数据库 11 张表全部创建
- ✅ pre-commit hook 通过

## 提交

```
commit 0027f10
feat(TASK-000022): Phase 2 AI Provider Adapter
```

## 下一步

Phase 3: Agent 系统后端（CRUD + 配置 + AI 对话）

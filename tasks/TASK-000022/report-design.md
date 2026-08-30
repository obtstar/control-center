# TASK-000022 Design 文档：AI Provider Adapter

## 一、设计目标

构建可移植的 AI Provider 适配层，支持用户自配 API Key 调用多模型，流式返回 AI 回复。

## 二、架构设计

### 2.1 文件结构

```
api/ai/
├── types.ts           # 统一类型定义
├── factory.ts         # Provider 工厂
├── router.ts          # tRPC 路由
└── providers/
    ├── deepseek.ts    # DeepSeek 适配
    ├── openai.ts      # OpenAI 适配
    ├── anthropic.ts   # Anthropic 预留
    └── ollama.ts      # Ollama 本地模型

api/queries/
└── ai-config.ts       # API Key 加解密 + CRUD
```

### 2.2 统一接口

```typescript
// api/ai/types.ts
export interface AIProvider {
  name: string;
  baseUrl: string;
  defaultModel: string;
  supportsStreaming: boolean;
}

export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface ChatOptions {
  model: string;
  messages: ChatMessage[];
  temperature?: number;
  maxTokens?: number;
  apiKey: string;
  baseUrl?: string;
}

export interface ChatChunk {
  content: string;
  done: boolean;
  usage?: TokenUsage;
}

export interface TokenUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export type ChatStream = ReadableStream<ChatChunk>;
```

### 2.3 Provider 实现

每个 Provider 实现统一的 `createStream` 函数：

```typescript
function createXxxStream(options: ChatOptions): ChatStream {
  return new ReadableStream({
    async start(controller) {
      // 1. fetch API 请求
      // 2. 读取 response.body.getReader()
      // 3. 解析 SSE/JSON Lines
      // 4. controller.enqueue({ content, done })
      // 5. controller.close()
    }
  });
}
```

### 2.4 API Key 加密

使用 Web Crypto API (AES-GCM)：

```typescript
// 加密
async function encryptApiKey(plain: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", ...);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, ...);
  return base64(iv + encrypted);
}

// 解密
async function decryptApiKey(encrypted: string, secret: string): Promise<string> {
  // 反向操作
}
```

### 2.5 tRPC 路由

```typescript
// api/ai/router.ts
export const aiRouter = createRouter({
  chat: authedQuery
    .input(z.object({
      configId: z.number(),
      messages: z.array(z.object({ role: z.enum(...), content: z.string() })),
    }))
    .mutation(async ({ input, ctx }) => {
      const config = await getAIConfig(ctx.user.id, input.configId);
      const apiKey = await decryptApiKey(config.encryptedApiKey, env.appSecret);
      const stream = createChatStream(config.provider, { ... });
      return stream;
    }),
});
```

## 三、可移植性保证

| 运行时 | 兼容性 | API |
|--------|--------|-----|
| Node.js 18+ | ✅ | fetch, ReadableStream, crypto.subtle |
| Cloudflare Workers | ✅ | 同上 |
| Deno | ✅ | 同上 |
| Bun | ✅ | 同上 |

**零依赖**：不使用 `node:stream`, `ws`, `eventsource` 等运行时特有模块。

## 四、文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| api/ai/types.ts | 新建 | 统一类型 |
| api/ai/factory.ts | 新建 | Provider 工厂 |
| api/ai/router.ts | 新建 | tRPC 路由 |
| api/ai/providers/deepseek.ts | 新建 | DeepSeek 适配 |
| api/ai/providers/openai.ts | 新建 | OpenAI 适配 |
| api/ai/providers/anthropic.ts | 新建 | Anthropic 预留 |
| api/ai/providers/ollama.ts | 新建 | Ollama 适配 |
| api/queries/ai-config.ts | 新建 | API Key 加解密 + CRUD |
| api/router.ts | 修改 | 注册 aiRouter |

## 五、验收标准

- [ ] TypeScript 编译通过
- [ ] ESLint 全绿
- [ ] 本地 dev 服务器正常
- [ ] DeepSeek 流式对话测试通过
- [ ] pre-commit hook 通过

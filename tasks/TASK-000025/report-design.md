# TASK-000025 Design 文档：AI 对话系统

## 一、设计目标

构建 1v1 AI 对话系统，支持用户与 AI 模型直接对话，以及与 Agent 私聊。

## 二、API 设计

### 2.1 Chat Router

```typescript
export const chatRouter = createRouter({
  // 会话管理
  createSession: authedQuery
    .input(z.object({
      title: z.string().optional(),
      agentId: z.number().int().positive().optional(),
    }))
    .mutation(({ ctx, input }) => createSession(ctx.user.id, input)),

  listSessions: authedQuery.query(({ ctx }) => listSessions(ctx.user.id)),

  getSession: authedQuery
    .input(z.object({ sessionId: z.number().int().positive() }))
    .query(({ ctx, input }) => getSession(input.sessionId, ctx.user.id)),

  deleteSession: authedQuery
    .input(z.object({ sessionId: z.number().int().positive() }))
    .mutation(({ ctx, input }) => deleteSession(input.sessionId, ctx.user.id)),

  // 消息
  getMessages: authedQuery
    .input(z.object({
      sessionId: z.number().int().positive(),
      cursor: z.number().optional(),
      limit: z.number().int().min(1).max(100).optional(),
    }))
    .query(({ ctx, input }) => getMessages(input)),

  sendMessage: authedQuery
    .input(z.object({
      sessionId: z.number().int().positive(),
      content: z.string().min(1).max(10000),
    }))
    .mutation(({ ctx, input }) => sendMessage(input, ctx.user.id)),
});
```

### 2.2 发送消息流程

```
用户调用 chat.sendMessage
    │
    ▼
获取会话信息（验证归属）
    │
    ▼
获取历史消息（最近 N 条作为上下文）
    │
    ▼
如果绑定了 Agent：
  - 获取 Agent 配置
  - 使用 Agent 的 model/modelProvider/temperature
  - 系统提示词 = Agent.systemPrompt
否则：
  - 获取默认 AI 配置
  - 使用用户配置的 model/provider
    │
    ▼
构建 messages[]（system + history + user message）
    │
    ▼
调用 createChatStream() 生成流式回复
    │
    ▼
保存用户消息到 chat_messages
    │
    ▼
返回 ReadableStream（前端实时显示）
    │
    ▼
流结束后保存 AI 回复到 chat_messages
```

## 三、文件结构

```
api/
├── queries/
│   └── chat.ts          # 对话查询层
├── routers/
│   └── chat-router.ts   # 对话路由
└── router.ts            # 注册 chatRouter
```

## 四、验收标准

- [ ] TypeScript 编译通过
- [ ] ESLint 全绿
- [ ] 本地 dev 服务器正常
- [ ] 创建会话 + 发送消息测试通过
- [ ] Agent 绑定对话测试通过
- [ ] pre-commit hook 通过

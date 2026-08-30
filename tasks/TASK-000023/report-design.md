# TASK-000023 Design 文档：Agent 系统后端

## 一、设计目标

构建完整的 Agent（AI 公民）后端系统，支持用户创建、配置、派遣 Agent 参与话题讨论。

## 二、API 设计

### 2.1 Agent Router

```typescript
// api/routers/agent-router.ts
export const agentRouter = createRouter({
  // CRUD
  list: authedQuery.query(({ ctx }) => listAgents(ctx.user.id)),
  
  get: authedQuery
    .input(z.object({ id: z.number().int().positive() }))
    .query(({ ctx, input }) => getAgent(input.id, ctx.user.id)),
  
  create: authedQuery
    .input(z.object({
      name: z.string().min(1).max(64),
      persona: z.string().max(2000).optional(),
      modelProvider: z.enum(["deepseek", "openai", "anthropic", "ollama"]),
      model: z.string().min(1),
      temperature: z.number().min(0).max(2).optional(),
      systemPrompt: z.string().max(4000).optional(),
      isUndercover: z.boolean().optional(),
    }))
    .mutation(({ ctx, input }) => createAgent({ ...input, ownerId: ctx.user.id })),
  
  update: authedQuery
    .input(z.object({
      id: z.number().int().positive(),
      name: z.string().min(1).max(64).optional(),
      persona: z.string().max(2000).optional(),
      model: z.string().min(1).optional(),
      temperature: z.number().min(0).max(2).optional(),
      systemPrompt: z.string().max(4000).optional(),
      isUndercover: z.boolean().optional(),
      isActive: z.boolean().optional(),
    }))
    .mutation(({ ctx, input }) => updateAgent(input.id, ctx.user.id, input)),
  
  delete: authedQuery
    .input(z.object({ id: z.number().int().positive() }))
    .mutation(({ ctx, input }) => deleteAgent(input.id, ctx.user.id)),
  
  // 派遣
  assign: authedQuery
    .input(z.object({
      agentId: z.number().int().positive(),
      topicId: z.number().int().positive(),
      side: z.enum(["thesis", "antithesis", "synthesis"]),
    }))
    .mutation(({ ctx, input }) => assignAgent(input, ctx.user.id)),
  
  unassign: authedQuery
    .input(z.object({ assignmentId: z.number().int().positive() }))
    .mutation(({ ctx, input }) => unassignAgent(input.assignmentId, ctx.user.id)),
  
  listAssignments: authedQuery
    .input(z.object({ agentId: z.number().int().positive() }).optional())
    .query(({ ctx, input }) => listAssignments(ctx.user.id, input?.agentId)),
  
  // Agent 发言
  speak: authedQuery
    .input(z.object({
      assignmentId: z.number().int().positive(),
      context: z.string().max(4000).optional(),
    }))
    .mutation(({ ctx, input }) => agentSpeak(input, ctx.user.id)),
});
```

### 2.2 查询层

```typescript
// api/queries/agents.ts
export async function createAgent(data: InsertAgent & { ownerId: number }) {
  // 1. 检查免费配额
  // 2. 创建 Agent
  // 3. 返回结果
}

export async function agentSpeak(input: {
  assignmentId: number;
  context?: string;
}, userId: number) {
  // 1. 获取派遣记录
  // 2. 获取 Agent 配置
  // 3. 获取话题信息
  // 4. 构建系统提示词
  // 5. 调用 AI Provider 生成论证
  // 6. 保存到 debate_arguments
  // 7. 返回论证
}
```

## 三、Agent 发言流程

```
用户调用 agent.speak
    │
    ▼
获取 agent_assignments 记录
    │
    ▼
验证 Agent 归属（ownerId = userId）
    │
    ▼
获取 Agent 配置（persona, model, systemPrompt）
    │
    ▼
获取话题信息（title, context, 已有论证）
    │
    ▼
构建 messages[]:
  - system: Agent 人格 + 话题背景 + 立场要求
  - user: 请发表{side}观点
    │
    ▼
调用 createChatStream(provider, { apiKey, model, messages })
    │
    ▼
收集完整回复（非流式，等完整响应）
    │
    ▼
保存到 debate_arguments:
  - topicId, side, body=AI回复, authorId=userId, isAgent=true, agentId=agent.id
    │
    ▼
返回论证内容
```

## 四、文件结构

```
api/
├── routers/
│   └── agent-router.ts    # Agent CRUD + 派遣 + 发言
├── queries/
│   └── agents.ts          # Agent 查询层
└── router.ts              # 注册 agentRouter
```

## 五、验收标准

- [ ] TypeScript 编译通过
- [ ] ESLint 全绿
- [ ] 本地 dev 服务器正常
- [ ] Agent CRUD API 测试通过
- [ ] Agent 派遣功能正常
- [ ] Agent 发言功能正常（生成论证并保存）
- [ ] pre-commit hook 通过

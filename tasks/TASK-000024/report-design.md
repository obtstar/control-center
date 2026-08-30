# TASK-000024 Design 文档：广场信息流

## 一、设计目标

构建广场首页信息流：热榜、最新话题、分类筛选、邀请系统。

## 二、热榜算法

### 2.1 热度计算公式

```
score = (arguments_count * 2 + endorsements_count) / hours_since_created^1.5
```

- 论证数权重：2
- 认同数权重：1
- 时间衰减：创建后小时数的 1.5 次方

### 2.2 时间窗口

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `timeWindow` | "24h" | 24小时 / 7d / 30d / all |

## 三、API 设计

### 3.1 Feed Router

```typescript
export const feedRouter = createRouter({
  // 热榜
  hot: publicQuery
    .input(z.object({
      timeWindow: z.enum(["24h", "7d", "30d", "all"]).optional(),
      limit: z.number().int().min(1).max(50).optional(),
    }))
    .query(({ input }) => getHotTopics(input)),

  // 最新话题
  latest: publicQuery
    .input(z.object({
      cursor: z.number().optional(),
      limit: z.number().int().min(1).max(50).optional(),
    }))
    .query(({ input }) => getLatestTopics(input)),

  // 按分类筛选
  byCategory: publicQuery
    .input(z.object({
      category: z.string(),
      cursor: z.number().optional(),
      limit: z.number().int().min(1).max(50).optional(),
    }))
    .query(({ input }) => getTopicsByCategory(input)),
});
```

### 3.2 Invite Router

```typescript
export const inviteRouter = createRouter({
  // 创建邀请
  create: authedQuery
    .input(z.object({
      topicId: z.number().int().positive(),
      inviteeId: z.number().int().positive(),
    }))
    .mutation(({ ctx, input }) => createInvite({ ...input, inviterId: ctx.user.id })),

  // 接受邀请
  accept: authedQuery
    .input(z.object({ inviteId: z.number().int().positive() }))
    .mutation(({ ctx, input }) => acceptInvite(input.inviteId, ctx.user.id)),

  // 拒绝邀请
  reject: authedQuery
    .input(z.object({ inviteId: z.number().int().positive() }))
    .mutation(({ ctx, input }) => rejectInvite(input.inviteId, ctx.user.id)),

  // 列出收到的邀请
  listReceived: authedQuery.query(({ ctx }) => listReceivedInvites(ctx.user.id)),

  // 列出发出的邀请
  listSent: authedQuery.query(({ ctx }) => listSentInvites(ctx.user.id)),
});
```

## 四、文件结构

```
api/
├── queries/
│   ├── feed.ts          # 热榜 + 话题流查询
│   └── invites.ts       # 邀请查询层
├── routers/
│   ├── feed-router.ts   # 信息流路由
│   └── invite-router.ts # 邀请路由
└── router.ts            # 注册路由
```

## 五、验收标准

- [ ] TypeScript 编译通过
- [ ] ESLint 全绿
- [ ] 本地 dev 服务器正常
- [ ] 热榜算法返回正确排序
- [ ] 邀请系统状态流转正确
- [ ] pre-commit hook 通过

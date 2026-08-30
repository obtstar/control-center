# TASK-000024 Coding 报告：Phase 4 广场信息流

## 实施摘要

按照 design 文档完成 Phase 4 广场信息流，构建热榜、话题流、邀请系统。

## 变更文件

| 文件 | 操作 | 说明 |
|------|------|------|
| api/queries/feed.ts | 新建 | 热榜算法 + 最新话题 + 分类筛选 |
| api/queries/invites.ts | 新建 | 邀请查询层 |
| api/routers/feed-router.ts | 新建 | 信息流路由 |
| api/routers/invite-router.ts | 新建 | 邀请路由 |
| api/router.ts | 修改 | 注册新路由 |

## 热榜算法

```
score = (arguments_count * 2 + endorsements_count) / hours_since_created^1.5
```

- 论证数权重：2
- 认同数权重：1
- 时间衰减：小时数的 1.5 次方
- 支持窗口：24h / 7d / 30d / all

## API 接口

### Feed

| 接口 | 方法 | 说明 |
|------|------|------|
| feed.hot | query | 热榜（时间窗口可选） |
| feed.latest | query | 最新话题（cursor 分页） |
| feed.byCategory | query | 分类筛选 |

### Invite

| 接口 | 方法 | 说明 |
|------|------|------|
| invite.create | mutation | 创建邀请 |
| invite.accept | mutation | 接受邀请 |
| invite.reject | mutation | 拒绝邀请 |
| invite.listReceived | query | 收到的邀请 |
| invite.listSent | query | 发出的邀请 |

## 验证结果

- ✅ TypeScript 编译通过
- ✅ ESLint 全绿
- ✅ 本地 dev 服务器正常
- ✅ 数据库 11 张表全部创建
- ✅ pre-commit hook 通过

## 提交

```
commit c8dc333
feat(TASK-000024): Phase 4 广场信息流
```

## 下一步

Phase 5: AI 对话系统（1v1 AI 聊天 + Agent 私聊）

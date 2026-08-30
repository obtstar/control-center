# TASK-000023 Coding 报告：Phase 3 Agent 系统后端

## 实施摘要

按照 design 文档完成 Phase 3 Agent 系统后端，构建完整的 AI 公民管理后端。

## 变更文件

| 文件 | 操作 | 说明 |
|------|------|------|
| api/queries/agents.ts | 新建 | Agent CRUD + 配额检查 + 派遣 + 发言保存 |
| api/routers/agent-router.ts | 新建 | tRPC 路由 |
| api/router.ts | 修改 | 注册 agentRouter |

## API 接口

### Agent CRUD

| 接口 | 方法 | 说明 |
|------|------|------|
| agent.list | query | 列出用户所有 Agent |
| agent.get | query | 获取 Agent 详情 |
| agent.create | mutation | 创建 Agent（检查配额） |
| agent.update | mutation | 更新 Agent |
| agent.delete | mutation | 删除 Agent |

### Agent 派遣

| 接口 | 方法 | 说明 |
|------|------|------|
| agent.assign | mutation | 派遣 Agent 到话题 |
| agent.unassign | mutation | 取消派遣 |
| agent.listAssignments | query | 列出派遣记录 |

### Agent 发言

| 接口 | 方法 | 说明 |
|------|------|------|
| agent.speak | mutation | Agent 在话题中发言 |

## Agent 发言流程

```
1. 获取派遣记录
2. 验证 Agent 归属
3. 获取话题信息
4. 获取默认 AI 配置
5. 解密 API Key (AES-GCM)
6. 构建系统提示词（人格 + 话题 + 立场）
7. 调用 AI Provider 生成论证
8. 收集完整响应
9. 保存到 debate_arguments (isAgent=true)
```

## 配额系统

- 用户默认 1 个免费 Agent 配额
- `canCreateAgent()` 检查当前数量 < 配额
- 超额返回 403

## 验证结果

- ✅ TypeScript 编译通过
- ✅ ESLint 全绿
- ✅ 本地 dev 服务器正常
- ✅ 数据库 11 张表全部创建
- ✅ pre-commit hook 通过

## 提交

```
commit 8511a05
feat(TASK-000023): Phase 3 Agent 系统后端
```

## 下一步

Phase 4: 广场信息流（热榜 + 话题流 + 邀请系统）

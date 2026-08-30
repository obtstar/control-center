---
task_id: TASK-000024
title: 'Agora Phase 4: 广场信息流'
repo_key: ""
domain: ""
stage: deliver
status: delivered
priority: ""
authority: L1
archived: true
---

# Agora Phase 4: 广场信息流

## 任务背景

Agora 广场政治模式升级 Phase 4。Phase 1-3 已完成，现进入 Phase 4。

## 需求概述

**Phase 4: 广场信息流**

### 目标
构建广场首页信息流，包括热榜、话题流、邀请系统。

### 具体实现

1. **热榜算法** (`api/queries/feed.ts`)
   - 基于话题参与度（论证数 + 认同数）计算热度
   - 支持时间衰减（24h/7d/30d）
   - 返回热榜话题列表

2. **话题流** (`api/queries/feed.ts`)
   - 最新话题流（按时间排序）
   - 分类筛选
   - 分页支持

3. **邀请系统** (`api/routers/invite-router.ts`)
   - `invite.create` - 邀请用户参与话题
   - `invite.accept` - 接受邀请
   - `invite.reject` - 拒绝邀请
   - `invite.list` - 列出邀请

4. **tRPC 路由** (`api/routers/feed-router.ts`)
   - `feed.hot` - 热榜
   - `feed.latest` - 最新话题
   - `feed.byCategory` - 按分类筛选

### 技术约束
- 热度计算在查询时进行，不存储热度值
- 邀请状态：pending/accepted/rejected
- 分页使用 cursor 方式

### 参考文档
- `docs/agora-upgrade-plan.md` - 完整升级计划

## 验收标准

- [x] TypeScript 编译通过 (`npm run check`)
- [x] ESLint 全绿 (`npm run lint`)
- [x] 本地 dev 服务器正常启动 (`npm run dev`)
- [ ] 热榜算法测试通过
- [ ] 邀请系统测试通过
- [x] pre-commit hook 通过

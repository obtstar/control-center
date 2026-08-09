# TASK-002 / coding

```
TASK-002 coding 已完成。

**主要产出**
- 工作区：`/home/dev/wt/control-web/TASK-002-web-mvp`（分支 `feature/TASK-002-web-mvp`）
- 本目录报告：
  - `coding-report.md`：变更摘要、依据引用、自检清单
  - `coding-test-results.md`：测试/构建记录

**实现内容**
- 四页路由：`/login`、`/board`、`/approvals`、`/audit`
- 认证上下文：登录 → `POST /api/auth/login`，Bearer token 保存到 `localStorage`
- 任务看板：`GET /api/tasks`，展示阶段/状态/更新人
- 审批中心：`GET /api/approvals/pending` + `POST /api/tasks/{id}/action`（approve/reject，驳回必填批注）
- 审计页：`GET /api/audit` 工作日志链
- 严格按 L3 设计使用 `openapi-typescript` + `openapi-fetch` 生成 client，禁止手写 fetch
- 所有页面/组件文件均 < 300 行

**验证结果**
```text
pnpm test   → 4 files passed, 10 tests passed
pnpm build  → tsc && vite build 通过
```

**Commit / Push**
- control-web：`0dc847c` — `TASK-002: control-web 审批工作台 MVP 前端实现`
- control-api：`c882ae9` — `TASK-002: control-api 审批工作台 MVP 后端契约支持`
- 两仓库均已推送 `origin/feature/TASK-002-web-mvp`

**未决风险**
- 本环境未安装 Go 工具链，control-api 后端仅按 diff 审查后推送，未本地 `go build ./...` 验证；建议在 CI/有 Go 环境补编译验证。


```

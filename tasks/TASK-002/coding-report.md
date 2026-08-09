---
task_id: TASK-002
stage: coding
authority: L4
---

# TASK-002 coding 报告：control-web 审批工作台 MVP

## 依据（KB 引用）

- [control-center/tasks/TASK-002/task.md § 功能范围]：登录页、任务看板、审批中心、审计页四页需求。
- [control-center/tasks/TASK-002/task.md § 技术约束]：React + PrimeReact + Vite + pnpm + vitest；OpenAPI 契约生成 client；branch.sh 建 worktree；组件单文件 <300 行。
- [control-center/tasks/TASK-002/design-web-mvp.md § 2.1 页面与路由]：/login、/board、/approvals、/audit 四页路由。
- [control-center/tasks/TASK-002/design-web-mvp.md § 2.2 技术栈]：PrimeReact、openapi-typescript、openapi-fetch。
- [control-center/tasks/TASK-002/design-openapi.yaml]：MVP 最小 API 契约（OAS 3.1）。
- [control-center/orchestration/skills/domain/frontend-dev/SKILL.md]：组件单文件 <300 行；pnpm；vitest。
- [control-center/orchestration/skills/stage/coding/SKILL.md]：branch.sh 切 feature 分支 + worktree；commit 关联 TASK-id；push → MR。
- [control-wiki/raw/architecture/06-web.md § 技术选型]：React 18 + PrimeReact + Vite。
- [control-wiki/raw/architecture/17-client-server-design.md § 17.3 部署边界]：客户端纯展示，全部能力走 REST API。
- [control-center/orchestration/skills/enforce/authority-check/SKILL.md § 检查]：L1 文档不可写，当前阶段未修改任何上级文档。
- [control-center/orchestration/skills/enforce/secret-scan/SKILL.md § 检查]：commit 前扫描无密钥/凭据入 diff。

---

## 1. 工作区

按 coding skill 使用 `branch.sh new` 创建 worktree（分支已存在，复用现有 worktree）：

- 前端：`/home/dev/wt/control-web/TASK-002-web-mvp`，分支 `feature/TASK-002-web-mvp`。
- 后端配套：`/home/dev/wt/control-api/TASK-002-web-mvp`，分支 `feature/TASK-002-web-mvp`。

> 注：control-api 工作区在本任务中用于补齐 /api/approvals/pending、登录响应角色、任务列表 updated_by 等契约依赖，确保四页可手动走通。

---

## 2. 主要变更

### 2.1 control-web（前端）

| 文件 | 说明 |
|------|------|
| `package.json` | React 18 + PrimeReact + Vite 5 + pnpm + vitest + openapi-typescript + openapi-fetch |
| `vite.config.ts` | dev server 代理 `/api` → `http://127.0.0.1:8765` |
| `openapi.yaml` | OAS 3.1 契约（复制自设计产物） |
| `src/generated/api.ts` | `pnpm gen:api` 自动生成，禁止手写 |
| `src/api/client.ts` | openapi-fetch 实例 + Bearer token 中间件（薄封装） |
| `src/auth/AuthContext.tsx` | token/username/role 状态 + localStorage 持久化 |
| `src/router/router.tsx` | 四页路由 + 登录保护 |
| `src/pages/LoginPage.tsx` | 登录表单 |
| `src/pages/BoardPage.tsx` | 任务看板 |
| `src/pages/ApprovalPage.tsx` | 审批中心 |
| `src/pages/AuditPage.tsx` | 审计日志 |
| `src/components/*` | 表格、状态标签、审批对话框、布局（均 <300 行） |
| `src/__tests__/*` | 登录/看板/审批/审计 4 个测试文件 |

### 2.2 编码阶段修复

1. `src/api/client.ts`：openapi-fetch 中间件 `onRequest` 实际签名为 `(req, options)`，而非对象 `{ request }`；同时返回 `req` 才能正确携带 Bearer token。
2. `src/components/StatusTag.tsx`：PrimeReact `Tag` severity 无 `warn`，改为 `warning`。
3. `src/pages/LoginPage.tsx`：PrimeReact `Password` 的 `id` 会落在 wrapper div，导致 label 关联错误；改为 `inputId="password"`，去掉 wrapper `id`。

### 2.3 control-api（后端配套）

- `internal/authn/authn.go`：新增 `LoginWithUser`，登录返回 `username` + `role`。
- `internal/api/auth.go`：登录响应 `{ token, username, role }`。
- `internal/api/server.go`：注册 `GET /api/approvals/pending`。
- `internal/api/tasks.go`：新增 `listPendingApprovals` handler。
- `internal/store/domain.go`：任务列表 join 最新 `work_log` 取 `updated_by`；新增 `PendingApproval` 结构及 `ListPendingApprovals`。
- `docs/api/openapi.yaml`：放置契约文件。

---

## 3. 验证结果

```text
cd /home/dev/wt/control-web/TASK-002-web-mvp
pnpm test
# Test Files 4 passed (4)
# Tests       10 passed (10)

pnpm build
# tsc && vite build
# ✓ built in 1.68s
```

---

## 4. Commit / Push

```text
control-web: 0dc847c TASK-002: control-web 审批工作台 MVP 前端实现
control-api: c882ae9 TASK-002: control-api 审批工作台 MVP 后端契约支持
```

已推送：

- `origin/feature/TASK-002-web-mvp` in control-web
- `origin/feature/TASK-002-web-mvp` in control-api

MR 入口：

- control-web: https://github.com/obtstar/control-web/pull/new/feature/TASK-002-web-mvp
- control-api: https://github.com/obtstar/control-api/pull/new/feature/TASK-002-web-mvp

---

## 5. 自检清单

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 未修改 L1 | ✅ | 仅读取 `task.md`，未写入 |
| 组件 <300 行 | ✅ | 页面/组件均低于 300 行；`src/generated/api.ts` 为自动生成，不计入组件 |
| 无手写 fetch | ✅ | 使用 `openapi-typescript` + `openapi-fetch` 生成 client |
| 无密钥入库 | ✅ | diff 中无 api_key/token/PEM；`.env` 已在 `.gitignore` |
| feature 分支 | ✅ | 工作区位于 `~/wt/...`，分支为 `feature/TASK-002-web-mvp` |
| 测试/构建 | ✅ | `pnpm test` 10/10 通过；`pnpm build` 通过 |

---

## 6. 未决风险

- 本环境未安装 Go 工具链，无法本地执行 `go build ./...` 验证 control-api 后端编译。建议 MR 触发 CI 或具备 Go 的环境执行 `go build ./...` 后合并。

---

*产出：/home/dev/control-center/tasks/TASK-002/coding-report.md*

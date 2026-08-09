---
authority: L2/L3
task_id: TASK-002
---

# TASK-002 设计：control-web 审批工作台 MVP

## 引用依据

- [control-wiki/raw/architecture/06-web.md § 技术选型]：control-web 采用 React 18 + PrimeReact + Vite 构建，Nginx 内网静态托管。
- [control-wiki/raw/architecture/06-web.md § 功能模块]：工作台包含多任务看板、任务操作、日志检索等模块；关键组件使用 DataTable / Tag / Dialog / Buttons。
- [control-wiki/raw/architecture/17-client-server-design.md § 17.2 客户端：单工作台]：control-web 为单一 React 应用，默认页为多任务看板，聚合任务操作、日志检索等功能。
- [control-wiki/raw/architecture/17-client-server-design.md § 17.3 部署边界]：客户端 = 纯展示，无业务逻辑、无数据直连；所有能力由 control-api 提供 REST API。
- [control-wiki/raw/architecture/18-authority.md § 18.1 权柄等级]：L2 概要设计、L3 详细设计顺行产出；AI 禁止逆行修改 L1 及更高级别文档。
- [control-wiki/raw/architecture/18-authority.md § 18.3 有据可依]：产出必须引用 KB 依据（文档 ID + 段落），无据则停止。
- [control-wiki/raw/architecture/18-authority.md § 18.4 一致性校验与暂停]：设计阶段对照 L1 需求逐条核对；发现冲突只能报告并暂停。
- [control-center/orchestration/skills/domain/frontend-dev/SKILL.md]：React + PrimeReact + Vite + pnpm + vitest；组件单文件 < 300 行。
- [control-center/orchestration/skills/stage/design/SKILL.md]：基于 L1 需求产出概要设计（接口/数据/时序），详细设计到可编码粒度；设计项逐条映射 L1 需求条目。
- [control-center/orchestration/workflows/pipeline.yaml § approval]：各阶段审批角色为 designer/tester/customer/team；approval 在 Web 工作台完成，驳回必附批注。
- [control-api/internal/api/server.go § 路由注册]：现有端点包括 POST /api/auth/login、GET /api/tasks、POST /api/tasks/{id}/action、GET /api/audit。
- [control-api/internal/api/auth.go § login]：登录校验成功后返回会话 token；withAuth 中间件对 /api 端点（除登录和健康检查）要求 Bearer token。
- [control-api/internal/api/tasks.go § taskAction]：审批动作 approve/reject 由后端校验用户角色与 approval.role 匹配；reject 必附批注由后端校验。
- [control-api/internal/store/domain.go § TaskRow/LogRow]：任务索引与审计日志的数据结构；任务表含 task_id/title/repo_key/stage/status/authority/path/updated_at，审计日志含 id/task_id/stage/action/operator/model/detail/entry_hash/created_at。
- [control-api/internal/authn/authn.go § Role/CanDecide]：角色 customer/designer/tester/team/admin；admin 通吃，其他角色只能审批同角色任务。
- [control-api/internal/engine/engine.go § Approve/Reject]：approve 推进到下一阶段；reject 按 on_reject 回退（默认重做本阶段，testing 阶段打回 coding）。
- [AGENTS.md § 10. 已知重要差异与注意事项]：control-web 当前为占位仓库，仅 README 与 .npmrc；本设计为首次实际实现。

---

## 1. 背景与目标

control-web 是平台六仓中的前端占位仓库。L1 需求要求交付一个**多角色真人使用**的审批工作台 MVP，覆盖登录、任务看板、审批中心、审计四页，并可通过 dev 代理手动走通后端 control-api。

本设计目标：

- **目标 1**：产出可编码的 L2/L3 设计文档与 API 契约（OpenAPI 3.1）。
- **目标 2**：明确前端技术栈、项目结构、页面路由与组件拆分（单文件 < 300 行）。
- **目标 3**：明确前后端 API 契约，前端使用 openapi-typescript 生成类型与 client，禁止手写 fetch 层。
- **目标 4**：明确后端需配合的最小改动项，使四页功能可完整走通。
- **目标 5**：设计 vitest 关键用例，保证登录、看板、审批、审计核心链路可验证。

---

## 2. 概要设计

### 2.1 页面与路由

| 路由 | 页面 | 功能 | 访问要求 |
|------|------|------|----------|
| `/login` | `LoginPage` | 用户名/密码登录，保存 Bearer token | 未登录 |
| `/board` | `BoardPage` | 任务看板：展示所有任务阶段/状态/更新人 | 已登录 |
| `/approvals` | `ApprovalPage` | 审批中心：展示当前用户可审批项，执行 approve/reject | 已登录 |
| `/audit` | `AuditPage` | 审计页：展示工作日志链 | 已登录 |
| `/` | 重定向到 `/board` | 默认入口 | 已登录重定向；未登录 → `/login` |

### 2.2 技术栈

| 层级 | 选型 | 说明 |
|------|------|------|
| 框架 | React 18 + TypeScript | 函数组件 + Hooks |
| 路由 | react-router-dom | 四页路由 + 登录保护 |
| UI 组件 | PrimeReact + PrimeIcons | DataTable / Tag / Button / Dialog / InputText / Password / Menubar / Toast |
| 构建 | Vite 5 | 开发服务器 + 生产构建 |
| 包管理 | pnpm | 多 worktree 共享全局 store |
| API 生成 | openapi-typescript + openapi-fetch | 由 OpenAPI 契约生成类型与强类型 fetch client，禁止手写 fetch |
| 测试 | vitest + @testing-library/react + jsdom | 关键用例覆盖登录/看板/审批/审计 |
| 样式 | PrimeReact 内置主题（Lara Light Indigo） | 不引入额外 CSS 框架 |

### 2.3 项目结构

```text
control-web/
├── index.html
├── package.json
├── pnpm-lock.yaml
├── vite.config.ts
├── tsconfig.json
├── src/
│   ├── main.tsx              # 应用入口
│   ├── App.tsx               # 路由 + AuthProvider 挂载
│   ├── generated/            # openapi-typescript 产物（禁止手写）
│   │   └── api.ts            # 类型 + openapi-fetch client
│   ├── api/                  # 类型导出 / 错误处理薄封装（< 60 行）
│   │   └── client.ts
│   ├── auth/                 # 认证上下文与 hooks
│   │   ├── AuthContext.tsx
│   │   └── useAuth.ts
│   ├── router/               # 路由定义
│   │   └── router.tsx
│   ├── pages/                # 页面组件（< 300 行）
│   │   ├── LoginPage.tsx
│   │   ├── BoardPage.tsx
│   │   ├── ApprovalPage.tsx
│   │   └── AuditPage.tsx
│   ├── components/           # 可复用组件（< 300 行）
│   │   ├── AppLayout.tsx     # 侧边栏/顶栏 + 注销
│   │   ├── StatusTag.tsx     # 状态标签
│   │   ├── TaskTable.tsx     # 任务表格
│   │   ├── ApprovalDialog.tsx
│   │   ├── AuditTable.tsx
│   │   └── ErrorBoundary.tsx
│   └── __tests__/            # vitest 测试
│       ├── LoginPage.test.tsx
│       ├── BoardPage.test.tsx
│       ├── ApprovalPage.test.tsx
│       └── AuditPage.test.tsx
```

> 单文件 < 300 行约束：页面只负责组装，表格/对话框拆到 `components/`。

### 2.4 状态与数据流

```text
┌──────────────┐     POST /api/auth/login     ┌──────────────┐
│   登录表单    │ ───────────────────────────▶ │  AuthContext  │
└──────────────┘                              │  token/user   │
                                              └──────┬───────┘
                                                     │
                              ┌──────────────────────┼──────────────────────┐
                              │                      │                      │
                              ▼                      ▼                      ▼
                       GET /api/tasks        GET /api/approvals/pending   GET /api/audit
                              │                      │                      │
                              ▼                      ▼                      ▼
                        TaskTable            ApprovalPage             AuditTable
```

- **AuthContext**：保存 `token`、`username`、`role`；提供 `login`、`logout`。token 同时写入 `localStorage` 实现刷新保持。
- **API client**：`src/generated/api.ts` 由 `openapi-typescript` 从 `control-api/docs/api/openapi.yaml` 生成。
- **数据获取**：页面组件使用 `useEffect` + `useState` 调用生成的 client；加载与错误状态由 PrimeReact `<ProgressSpinner>` 和 `<Toast>` 处理。

### 2.5 API 契约概述

完整 OpenAPI 3.1 契约见同目录 `design-openapi.yaml`。本阶段作为设计产物保存，编码阶段需复制到 `control-api/docs/api/openapi.yaml` 并作为生成来源（L1 需求指定路径）。

> 注意：`control-center/registry/repos.yaml` 中 `control-api.openapi_ref` 当前登记为 `openapi/openapi.yaml`，与 L1 指定的 `docs/api/openapi.yaml` 不一致。该差异需在 coding 阶段由人确认是否同步调整注册表或按 L1 路径放置契约文件。

契约端点：

| 方法 | 路径 | 用途 | 说明 |
|------|------|------|------|
| POST | `/api/auth/login` | 登录 | 返回 `token` + `username` + `role` |
| GET | `/api/tasks` | 任务列表 | 返回任务数组，含 `updated_by` |
| GET | `/api/approvals/pending` | 可审批列表 | 后端按当前用户角色过滤 |
| POST | `/api/tasks/{id}/action` | 审批动作 | `approve`/`reject` + `comment` |
| GET | `/api/audit` | 审计日志 | 返回工作日志链 |

> 后端现有端点缺少 `GET /api/approvals/pending` 与登录响应中的角色信息，以及任务列表中的 `updated_by`，详见 §7 后端配合项。

---

## 3. API 契约（OpenAPI 3.1）

详见 `design-openapi.yaml`。主要 schema 如下：

```yaml
components:
  schemas:
    LoginRequest:
      type: object
      properties:
        username: { type: string }
        password: { type: string }
      required: [username, password]
    LoginResponse:
      type: object
      properties:
        token: { type: string }
        username: { type: string }
        role: { type: string, enum: [customer, designer, tester, team, admin] }
      required: [token, username, role]
    Task:
      type: object
      properties:
        task_id: { type: string }
        title: { type: string }
        repo_key: { type: string, nullable: true }
        stage: { type: string }
        status: { type: string, enum: [pending, running, awaiting_approval, paused, merged, delivered] }
        authority: { type: string }
        updated_by: { type: string, nullable: true }
        updated_at: { type: string, format: date-time }
      required: [task_id, title, stage, status, authority, updated_at]
    ActionRequest:
      type: object
      properties:
        action: { type: string, enum: [approve, reject] }
        comment: { type: string, nullable: true }
      required: [action]
    ActionResponse:
      type: object
      properties:
        task_id: { type: string }
        stage: { type: string }
        status: { type: string }
      required: [task_id, stage, status]
    PendingApproval:
      type: object
      properties:
        task_id: { type: string }
        title: { type: string }
        stage: { type: string }
        role: { type: string }
        artifact: { type: string, nullable: true }
        created_at: { type: string, format: date-time }
      required: [task_id, title, stage, role, created_at]
    AuditLog:
      type: object
      properties:
        id: { type: integer }
        task_id: { type: string, nullable: true }
        stage: { type: string, nullable: true }
        action: { type: string }
        operator: { type: string }
        model: { type: string, nullable: true }
        detail: { type: string, nullable: true }
        entry_hash: { type: string }
        created_at: { type: string, format: date-time }
      required: [id, action, operator, entry_hash, created_at]
```

---

## 4. 详细设计（L3 可执行粒度）

### 4.1 认证上下文

文件：`src/auth/AuthContext.tsx`

- 初始化时从 `localStorage` 读取 `token`/`username`/`role`。
- `login(username, password)`：调用 `POST /api/auth/login`；成功后保存到 state 与 localStorage。
- `logout()`：清除 state 与 localStorage；跳转 `/login`。
- 提供 `isAuthenticated` 布尔值。
- 所有受保护路由通过 `AuthContext` 判断；未登录则 `<Navigate to="/login" replace />`。

### 4.2 登录页

文件：`src/pages/LoginPage.tsx`

- 使用 PrimeReact `InputText`、`Password`、`Button`。
- 表单校验：用户名、密码非空。
- 提交时调用 `AuthContext.login`；失败显示 Toast 错误信息。
- 登录成功后 `navigate('/board')`。
- 无 token 时访问其他页面自动重定向到登录页。

### 4.3 任务看板

文件：`src/pages/BoardPage.tsx` + `src/components/TaskTable.tsx`

- 页面加载时调用 `GET /api/tasks`。
- 表格列：任务 ID、标题、目标仓库、阶段、状态、更新人、更新时间。
- `StatusTag` 组件按 `status` 渲染 Tag 颜色（如 `awaiting_approval` 为橙色，`paused` 为红色）。
- 支持按状态/阶段/仓库简单过滤（PrimeReact DataTable 内置过滤）。
- 不实现任务创建（MVP 外），只读展示。

### 4.4 审批中心

文件：`src/pages/ApprovalPage.tsx` + `src/components/ApprovalDialog.tsx`

- 加载时调用 `GET /api/approvals/pending`。
- 表格列：任务 ID、标题、当前阶段、审批角色、产物摘要、提交时间。
- 点击行打开 `ApprovalDialog`：
  - 显示任务详情与当前阶段产物。
  - **Approve** 按钮：可附简短批注，调用 `POST /api/tasks/{id}/action` 传 `{ action: "approve", comment }`。
  - **Reject** 按钮：必须填写批注（前端二次校验），调用 `POST /api/tasks/{id}/action` 传 `{ action: "reject", comment }`。
  - 后端会再次校验角色权限；前端按当前 `role` 仅展示可审批项。
- 操作成功后刷新列表并显示 Toast。

### 4.5 审计页

文件：`src/pages/AuditPage.tsx` + `src/components/AuditTable.tsx`

- 加载时调用 `GET /api/audit`。
- 表格列：ID、任务 ID、阶段、动作、操作人、模型、详情、日志哈希、时间。
- 默认按时间倒序；支持按任务 ID 过滤。
- 日志哈希列可复制，用于人工点验 hash 链。

### 4.6 错误与加载

- 每个页面统一使用 `useState` 管理 `loading` 和 `error`。
- 加载中显示 `<ProgressSpinner>`。
- API 错误（401/403/409/500）通过 `<Toast>` 显示后端返回的 `error` 字段。
- 401 全局处理：自动登出并跳转登录页。

---

## 5. 测试策略

使用 vitest + @testing-library/react + jsdom。

| 测试文件 | 覆盖点 |
|----------|--------|
| `LoginPage.test.tsx` | 表单渲染、提交登录、成功跳转、失败提示 |
| `BoardPage.test.tsx` | 表格渲染任务列表、状态 Tag 展示、加载/错误态 |
| `ApprovalPage.test.tsx` | 可审批列表渲染、打开对话框、reject 必填批注、approve 成功刷新 |
| `AuditPage.test.tsx` | 审计日志表格渲染、hash 列展示 |

测试原则：

- mock 生成的 openapi-fetch client，不发起真实网络请求。
- 测试集中在用户交互与页面状态，避免测试 PrimeReact 内部实现。
- 关键用例必须通过后 `pnpm build` 才允许进入 MR。

---

## 6. 验收标准

| 编号 | 标准 | 验证方式 |
|------|------|----------|
| A1 | `pnpm build` 通过，无 TS 错误 | 命令行执行 |
| A2 | vitest 关键用例（登录/看板/审批/审计）全部通过 | `pnpm test` |
| A3 | dev 代理生效，前端请求正确转发到 `http://127.0.0.1:8765` | 浏览器 Network + Vite 日志 |
| A4 | 登录页成功保存 token，登录后访问看板/审批/审计无需再次登录 | 手动 + 单测 |
| A5 | 任务看板展示阶段/状态/更新人 | 手动 + 单测 |
| A6 | 审批中心仅展示当前用户角色可审批项 | 多角色账号手动验证 |
| A7 | 驳回必须附批注，前端与后端双重校验 | 手动 + 单测 |
| A8 | 审计页展示工作日志链，含 hash | 手动 + 单测 |

---

## 7. 后端配合项

control-web 实现依赖 control-api 提供以下契约；若当前后端未实现，需在 coding 阶段同步修改 control-api（属于 TASK-002 的配套后端改动，但 code 仍在 control-api 仓库）：

| 需求 | 当前状态 | 后端改动 |
|------|----------|----------|
| 登录响应需包含角色 | 当前只返回 `token` | `POST /api/auth/login` 返回 `{ token, username, role }` |
| 任务列表需展示更新人 | `TaskRow` 无 `updated_by` | 在 `task_index` 同步或查询时从最新 `work_log` 取 `operator`，输出 `updated_by` |
| 审批中心需要可审批列表 | 无 `GET /api/approvals/pending` | 新增端点，查询 `approval` 表未裁决记录，按 `X-Role` 过滤（admin 通吃） |

> 前端设计阶段只定义契约（`design-openapi.yaml`），不直接修改 control-api 代码；后端改动在 coding 阶段由对应任务/人执行，确保契约一致。

---

## 8. L1 需求映射表

| L1 需求条目 | 设计章节 | 引用依据 |
|-------------|----------|----------|
| 登录页：调 POST /api/auth/login，保存 Bearer token | §4.2 | [control-api/internal/api/auth.go § login] |
| 任务看板：GET /api/tasks 列表，展示阶段/状态/更新人 | §4.3、§7 | [control-api/internal/store/domain.go § TaskRow] |
| 审批中心：对 awaiting_approval 任务执行 approve/reject，按用户角色展示可审批项 | §4.4、§7 | [control-api/internal/api/tasks.go § taskAction]、[control-api/internal/authn/authn.go § CanDecide] |
| 审计页：GET /api/audit 工作日志链 | §4.5 | [control-api/internal/store/domain.go § LogRow] |
| 技术栈 React + PrimeReact + Vite + pnpm + vitest | §2.2 | [control-center/orchestration/skills/domain/frontend-dev/SKILL.md]、[control-wiki/raw/architecture/06-web.md § 技术选型] |
| API 契约：先在 control-api/docs/api/ 产出 openapi.yaml | §3、§7 | [control-center/orchestration/skills/stage/design/SKILL.md] |
| 编码阶段通过 branch.sh new 建 worktree | §2.3 | [control-center/orchestration/skills/stage/coding/SKILL.md] |
| 组件单文件 < 300 行 | §2.3 | [control-center/orchestration/skills/domain/frontend-dev/SKILL.md] |
| 验收：pnpm build 通过；vitest 关键用例通过；四页手动走通 | §6 | [control-center/orchestration/skills/domain/frontend-dev/SKILL.md] |

---

## 9. 异常与回退

| 异常 | 动作 | 依据 |
|------|------|------|
| 发现 L1 需求与现有后端实现不一致 | 产出不一致报告 + 暂停任务，由人决策 | [control-wiki/raw/architecture/18-authority.md § 18.4] |
| 找不到 frontend-dev skill 或 KB 引用不存在 | 输出 `NO_BASIS` 并停止 | [control-wiki/raw/architecture/18-authority.md § 18.3] |
| 后端 401/403 | 前端 Toast 提示 + 401 自动跳转登录 | 会话安全设计 |
| 后端 409（审批冲突） | 显示具体错误，刷新列表 | 状态机并发场景 |
| 单文件行数接近 300 行 | 提前拆分到 components/ | [control-center/orchestration/skills/domain/frontend-dev/SKILL.md] |

---

## 10. 自检清单

- [ ] 文件以 `design-` 前缀命名，位于 `control-center/tasks/TASK-002/`。
- [ ] frontmatter 包含 `authority: L2/L3` 与 `task_id: TASK-002`。
- [ ] 每条设计决策引用真实 KB 段落，无空引用。
- [ ] 未修改 `task.md` 或其他 L1 文档。
- [ ] 设计项逐条映射 L1 需求条目。
- [ ] API 契约完整覆盖登录/任务/审批/审计四页。
- [ ] 组件拆分方案确保单文件 < 300 行。

---

等待人审批后可进入 coding 阶段。

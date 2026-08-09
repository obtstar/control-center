# TASK-002 / design

```
设计阶段产出已完成，写入 `control-center/tasks/TASK-002/`。

## 交付文件

- `design-web-mvp.md`（L2/L3 设计文档）
- `design-openapi.yaml`（OpenAPI 3.1 API 契约设计产物，编码阶段复制到 `control-api/docs/api/openapi.yaml`）

## 设计要点

1. **四页路由**：`/login` → `/board`（看板） → `/approvals`（审批中心） → `/audit`（审计）。
2. **技术栈**：React 18 + TypeScript + PrimeReact + Vite + pnpm + vitest；路由用 `react-router-dom`；API 类型/client 用 `openapi-typescript` + `openapi-fetch` 生成，禁止手写 fetch。
3. **认证会话**：`AuthContext` 保存 `token/username/role`，`localStorage` 刷新保持，Bearer 注入后续请求。
4. **API 契约**：
   - `POST /api/auth/login` → 返回 `token + username + role`
   - `GET /api/tasks` → 含 `updated_by`（供看板展示更新人）
   - `GET /api/approvals/pending` → 后端按角色过滤可审批项
   - `POST /api/tasks/{id}/action` → `approve/reject`（reject 必附批注）
   - `GET /api/audit` → 工作日志链
5. **组件拆分**：页面/表格/对话框均拆分到 `components/`，确保单文件 < 300 行。
6. **测试**：vitest 覆盖登录、看板、审批、审计四页核心用例。

## 后端配合项

前端设计依赖 control-api 三处小改动（编码阶段同步）：
- 登录响应增加 `username` 与 `role`
- 任务列表增加 `updated_by`
- 新增 `GET /api/approvals/pending`

## 合规自检

- ✅ 有据可依：所有设计决策引用真实 KB 段落（`frontend-dev`/`design` skills、平台架构 06/17/18 章、control-api 源码、pipeline.yaml、AGENTS.md）。
- ✅ 不逆行：未修改 `task.md` 或任何 L1 文档；只新增 L2/L3 设计文件。
- ✅ 文件以 `design-` 前缀命名，frontmatter 声明 `authority: L2/L3`。

## 已注明差异

`control-center/registry/repos.yaml` 中 `control-api.openapi_ref` 当前登记为 `openapi/openapi.yaml`，与 L1 指定的 `docs/api/openapi.yaml` 路径不一致；已在设计文档中标注，需 coding 阶段由人确认是否同步调整。


```

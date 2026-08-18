---
task_id: TASK-002
title: control-web 审批工作台 MVP
repo_key: control-web
domain: frontend-dev
stage: merge
status: merged
priority: ""
authority: L1

---

# control-web 审批工作台 MVP

开发 control-web 审批工作台 MVP（多角色真人使用的前端）。

功能范围（必须）：
1. 登录页：调 POST /api/auth/login，保存 Bearer token 会话
2. 任务看板：GET /api/tasks 列表，展示阶段/状态/更新人
3. 审批中心：对 awaiting_approval 任务执行 approve/reject（POST /api/tasks/{id}/action，驳回必附批注），按用户角色展示可审批项
4. 审计页：GET /api/audit 工作日志链

技术约束（必须遵守）：
- 技术栈按 frontend-dev skill：React + PrimeReact + Vite + pnpm + vitest
- API 契约：先在 control-api/docs/api/ 产出 openapi.yaml（OAS 3.1），前端用 openapi-typescript codegen 生成 client 与类型，禁止手写 fetch 层——防止前后端不一致
- 编码阶段通过 branch.sh new control-web <TASK-id> web-mvp 建 worktree 编码
- 组件单文件 <300 行

验收：pnpm build 通过；vitest 关键用例通过；登录→看板→审批→审计四页可手动走通（dev 代理到 127.0.0.1:8765）。

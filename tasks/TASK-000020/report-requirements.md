# TASK-000020 影响分析报告（requirements）

> 任务：任务看板：delivered 任务归档功能
> 阶段：requirements · 日期：2026-08-29

## 1. 需求

看板操作列加"归档"按钮：delivered 任务可归档，归档后从活跃看板移除（可查全部）。后端归档（任务即文档 + Git 可信源）。

## 2. 现状（实测）

| 项 | 现状 |
|----|------|
| tasks.Meta | frontmatter 无 archived 字段 |
| task_index 表 | 无 archived 列（派生索引，watcher 从 task.md 同步） |
| engine | 无 Archive 方法（Approve/Reject/Pause/Resume/Deliver/MarkMerged） |
| store.ListTasks | 返回全部任务（无过滤） |
| taskAction | 无 archive 动作分支 |

## 3. 方案（后端归档）

| 层 | 改动 |
|----|------|
| tasks.Meta | +`Archived bool yaml:"archived"`（frontmatter 权威） |
| store.migrate | CREATE 加 archived 列 + 存量 `ALTER TABLE ADD COLUMN`（duplicate 忽略） |
| UpsertTask | 同步 archived |
| ListTasks | 默认过滤 archived=0；`includeArchived` 参数查全部 |
| engine.Archive | 仅 delivered 可归档：写 frontmatter archived=true + UpsertTask + work_log 留痕 |
| taskAction | +archive 分支（角色：登录用户，delivered 校验） |
| 契约 | openapi.yaml：Task.archived 字段 + ActionRequest archive |
| control-web | TaskTable delivered 行"归档"按钮 → POST archive → 刷新 |

## 4. 影响面

- control-api（tasks/store/engine/api/契约）+ control-web（TaskTable）；平台仓 dev 直推
- 存量任务无 archived → 默认 0（活跃）

## 5. 验收

1. delivered 任务 action=archive → frontmatter archived: true + work_log 留痕
2. GET /api/tasks 默认不含归档；?archived=all 含
3. 非 delivered 归档 → 409
4. 契约对账 PASS + go test + vitest 全绿

## 6. 依据

- task.md（L1）；task_index 派生模型（05 章）；frontmatter 权威（07.2）

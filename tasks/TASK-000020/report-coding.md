# TASK-000020 report-coding.md

> 阶段：coding · 日期：2026-08-29

## 交付（平台仓 dev 直推）

### control-api [c658ef2]
- tasks.Meta +Archived；task_index +archived 列（migrate 存量 ALTER）
- UpsertTask 同步；ListTasks(includeArchived) 默认过滤归档
- engine.Archive（仅 delivered；frontmatter + 索引 + work_log 留痕）；taskAction +archive
- GET /api/tasks?archived=all；契约 Task.archived + archive

### control-web [5653604]
- TaskTable delivered 行"归档"按钮；BoardPage handleArchive → POST archive → 刷新 + toast
- openapi.yaml 同步 + gen:api

## 实测

- TASK-000012 归档：frontmatter `archived: true` 写入；默认列表不含；`?archived=all` 可见
- 非 delivered 归档 → engine 校验（409）

## 验证

- go test 12 包全绿（契约对账含 archived）；gofmt/vet 干净
- control-web tsc/eslint/vitest 34/34/build 全过
- 已部署（control-api 新二进制 + control-web 新 dist）

## 依据

- task.md（L1）+ design.md；task_index 派生模型（05 章）

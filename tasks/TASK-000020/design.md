---
task_id: TASK-000020
stage: design
authority: L2
title: 看板任务归档 — 设计
---

# TASK-000020 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 设计

### 1.1 control-api

| 文件 | 改动 |
|------|------|
| internal/tasks/tasks.go | Meta +`Archived bool yaml:"archived"` |
| internal/store/store.go | migrate()：CREATE task_index 加 `archived INTEGER NOT NULL DEFAULT 0`；存量 `ALTER TABLE ... ADD COLUMN`（duplicate column 忽略） |
| internal/store/domain.go | UpsertTask 同步 archived；ListTasks(includeArchived bool) 过滤（默认 archived=0）；TaskRow +Archived |
| internal/engine/engine.go | `Archive(m, by)`：仅 Status==delivered；写 frontmatter（WriteMeta 回写 archived:true）+ UpsertTask + commit 留痕 |
| internal/api/tasks.go | taskAction +`case "archive": err = s.eng.Archive(...)`；listTasks handler 传 includeArchived（query ?archived=all） |
| docs/api/openapi.yaml | Task schema +archived；ActionRequest enum +archive |

### 1.2 control-web

| 文件 | 改动 |
|------|------|
| src/components/TaskTable.tsx | 操作列 delivered 行加"归档"按钮（onArchive prop） |
| src/pages/BoardPage.tsx | onArchive → POST /tasks/{id}/action {action:'archive'} → 刷新 |

### 1.3 关键逻辑

```go
func (e *Engine) Archive(m *tasks.Meta, by string) error {
    if m.Status != "delivered" { return fmt.Errorf("仅 delivered 任务可归档") }
    m.Archived = true
    if err := tasks.WriteMeta(m); err != nil { return err }
    if err := e.St.UpsertTask(m); err != nil { return err }
    return e.commit(m, "archive", "归档 by "+by)
}
```

## 2. 验收映射

| 验收项 | 落实 |
|--------|------|
| delivered 可归档 | engine.Archive 校验 + 写 frontmatter |
| 看板消失 | ListTasks 默认过滤 archived |
| 留痕 | commit work_log |
| 非 delivered 409 | Archive 校验 |
| 契约/测试 | openapi + go test + vitest |

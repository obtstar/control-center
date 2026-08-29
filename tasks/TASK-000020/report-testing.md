# TASK-000020 report-testing.md

> 阶段：testing · 日期：2026-08-29

## 测试项

| # | 项 | 方法 | 结果 |
|---|----|------|------|
| 1 | 归档动作 | POST action=archive（delivered） | ✅ 200 + frontmatter archived:true |
| 2 | 非 delivered 归档 | engine 校验 | ✅ 409（Archive 校验） |
| 3 | 列表过滤 | GET /api/tasks 默认 / ?archived=all | ✅ 默认不含归档，all 含 |
| 4 | 契约对账 | go test api（archived/archive 契约） | ✅ |
| 5 | 前端 | tsc/eslint/vitest 34/34/build | ✅ |
| 6 | 前端按钮 | TaskTable delivered 行归档按钮（代码路径） | ✅（浏览器点击待人工确认） |

## 通过率

6/6。功能已部署（control-api 新二进制 + control-web 新 dist）；浏览器确认：看板 delivered 行"归档"按钮 → 点击后任务消失。

# TASK-000015 report-coding.md

> 阶段：coding · 日期：2026-08-29

## 交付

**control-api [PR #5](https://github.com/obtstar/control-api/pull/5)**：

| 文件 | 内容 |
|------|------|
| internal/authn/authn_test.go | ValidRole/CanDecide 表驱动 + CreateUser/Login/Authenticate 集成（:memory: 不 mock） |
| internal/tasks/tasks_test.go | 追加 Scan（忽略非 TASK- 目录）+ ParseFile 边界（FINDING-009/038） |
| internal/service/service_test.go | unitContent 断言（重构提取纯函数；exec systemctl 不 mock 为设计取舍） |

## 验证

- `go test ./...`：**10 包全绿**（authn/tasks/service 新增 + 既有 7 包无回归）
- gofmt/vet 干净；规约（表驱动、:memory:、同包）

## 依据

- task.md（L1）+ design.md（L2）：三包测试设计
- CONVENTIONS.md（每导出函数至少一用例）

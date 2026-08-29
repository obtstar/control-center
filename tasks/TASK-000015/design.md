---
task_id: TASK-000015
stage: design
authority: L2
title: authn/service/tasks 补单测 — 设计
---

# TASK-000015 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 测试设计

### 1.1 authn（internal/authn/authn_test.go，表驱动）

| 函数 | 用例 | 断言 |
|------|------|------|
| ValidRole | 合法 5 角色 / 非法 | true/false |
| CanDecide | admin 通吃 / 同角色 / 异角色 / 空 | true/false |
| CreateUser+Login | 正确口令 / 错误口令 | token 返回 / 错误 |
| Authenticate | 有效 token / 伪造 / 过期 | User / 错误 |

- 存储：SQLite :memory:（store.Open(":memory:")）——不 mock DB
- bcrypt 真实哈希（慢但正确）

### 1.2 tasks（internal/tasks/tasks_test.go 追加）

| 函数 | 用例 |
|------|------|
| Scan | 临时目录：正常任务目录（frontmatter 解析）/ 非 TASK- 目录忽略 / 空目录 |
| ParseFile 边界 | title 含冒号/换行（FINDING-009）；body 行首 ---（FINDING-038） |

### 1.3 service（internal/service/service_test.go）

| 函数 | 用例 |
|------|------|
| Run install | 临时 HOME（t.TempDir + HOME 覆盖）→ 断言 unit 文件内容（After/ExecStart/EnvironmentFile 行） |

- exec systemctl 部分：设计取舍——install 仅写文件不调 systemctl（看实现），若调则 stub PATH；不可测部分注释说明

## 2. 验收映射

| 验收项 | 设计落实 |
|--------|---------|
| 每导出函数至少一用例 | 上表全覆盖 |
| 表驱动 + :memory: | 全部 |
| go test 全绿 + gofmt/vet | coding 后验证 |

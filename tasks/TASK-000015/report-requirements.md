# TASK-000015 影响分析报告（requirements）

> 任务：测试补强：control-api authn/service/tasks 补单测
> 阶段：requirements · 日期：2026-08-29

## 1. 现状（实测）

| 包 | 导出函数 | 现有测试 |
|----|---------|---------|
| authn | ValidRole / CreateUser / LoginWithUser / Login / Authenticate / CanDecide（6） | **零** |
| tasks | ParseFile / WriteMeta / Scan（3） | 2（ParseFile 边界、WriteMeta body 保留）；**Scan 无** |
| service | Run（install/uninstall/status） | **零** |

（task.md 称 tasks 为零——实测已有 2 用例，缺口为 Scan + authn + service）

## 2. 方案

| 包 | 测试 | 要点 |
|----|------|------|
| authn | ValidRole 合法/非法角色；CanDecide 决策矩阵（admin 通吃/同角色/异角色）；Login 口令正确/错误；Authenticate token 有效/无效/过期 | bcrypt 哈希（真实计算）；SQLite :memory: 存用户 |
| tasks | Scan 目录扫描（多任务/非任务文件忽略）；ParseFile 边界补（FINDING-009/038：title 冒号/换行、行首 ---） | 临时目录 |
| service | Run install 的 unit 文件生成（内容断言：After/ExecStart/EnvironmentFile）——exec systemctl 部分不 mock（设计取舍：install 写文件逻辑抽测） | 临时 HOME |

## 3. 影响面

- 仅新增 `*_test.go`（同包测试，无生产代码改动或最小重构）
- 规约：表驱动、:memory: SQLite 不 mock DB、同包
- 红线：单测试文件 ≤300 行（超则拆分）

## 4. 验收

1. authn：ValidRole/CanDecide/Login/Authenticate 用例绿
2. tasks：Scan 补测 + 边界补测
3. service：install unit 生成断言（exec 部分说明取舍）
4. `go test ./...` 全绿 + gofmt/vet

## 5. 依据

- CONVENTIONS.md（每导出函数至少一用例；表驱动；不 mock DB）
- AGENTS.md §10-3（测试缺口已知）

---
task_id: TASK-000015
title: 测试补强：control-api authn/service/tasks 补单测
repo_key: control-api
domain: backend-go
stage: deliver
status: delivered
priority: ""
authority: L1
archived: true
---

# 测试补强：control-api authn/service/tasks 补单测

测试补强：control-api 的 authn/service/tasks 包补单元测试（AGENTS.md §10-3 已知缺口，违反"每个导出函数至少一个用例"规约）。现状：api/store/engine/pipeline/config 已有测试，authn/service/tasks 为零。验收：①authn 包：登录/token 校验/常量时间比较/角色 CanDecide 用例；②tasks 包：task.md frontmatter 解析（含 FINDING-009/038 边界）/回写用例；③service 包：systemd unit 生成（或说明降级原因）用例；④表驱动 + SQLite :memory: 不 mock；⑤go test ./... 全绿 + gofmt/vet。

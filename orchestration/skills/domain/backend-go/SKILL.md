---
name: backend-go
layer: domain
description: 后端开发约定（Go/标准库 net-http）
---

## 适用
Go 服务类项目（含平台自身 control-api/control-piekbs）

## 约定
- `cmd/<binary>/` 只做命令解析与调用；`internal/<domain>/` 一个领域一个包，禁止 util/common/helper
- 标准库 net/http mux，不引 Web 框架/ORM；gofmt + go vet 全绿
- 表驱动 go test，SQLite 用 :memory: 实测不 mock；schema 变更只经 control-db DDL 迁移

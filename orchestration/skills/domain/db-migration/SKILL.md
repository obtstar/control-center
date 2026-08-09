---
name: db-migration
layer: domain
description: 数据库迁移约定（SQLite DDL）
---

## 适用
control-db 及 schema 变更

## 约定
- 版本化迁移 db/ddl/V{NNN}__<name>.sql，只增不改
- SQLite 方言（AUTOINCREMENT/FTS5）；每个迁移附回滚说明

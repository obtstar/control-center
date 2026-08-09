---
name: backend-java
layer: domain
description: 后端开发约定（Spring Boot/Maven）
---

## 适用
Java 服务类项目

## 约定
- 分层 controller/service/dao；事务在 service 层
- Maven 构建；JUnit5；schema 变更只经 control-db DDL 迁移

---
name: secret-scan
layer: enforce
description: 密钥扫描：凭据不入库
---

## 强制点：commit 前

## 检查
1. diff 匹配密钥模式（api_key/token/password/Bearer/PEM 头）
2. .env 类文件不得入库
3. 命中 → 阻断提交，指向 .env 600 规范

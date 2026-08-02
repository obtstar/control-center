# 10 内网部署方案

## docker-compose（最小可行）

```yaml
# docker-compose.yml（最小可行）
version: '3.8'
services:
  web:
    image: internal-control-web:latest      # React + PrimeReact + Vite 构建产物 + Nginx
    ports: ["80:80"]

  api:
    image: internal-control-api:latest      # Java Spring Boot（控制中心后端）
    environment:
      - DB_URL=jdbc:mysql://mysql:3306/control?useSSL=false&characterEncoding=utf8mb4
      - DB_USER=control
      - DB_PASSWORD=${DB_PASSWORD}
      - LITELLM_ENDPOINT=http://litellm.internal:4000
      - VECTOR_DB_ENDPOINT=http://milvus:19530
    volumes:
      - /home/dev/wt:/wt            # Worktree 根目录（WSL home）
      - /home/dev/repos:/repos      # 代码仓库裸仓库/工作副本
    depends_on: [mysql, redis]

  worker:
    image: internal-control-worker:latest   # Spring 调度/异步任务（RAG 索引、定时任务）
    environment:
      - DB_URL=jdbc:mysql://mysql:3306/control?useSSL=false&characterEncoding=utf8mb4
    depends_on: [api, redis, mysql]
    deploy: { replicas: 2 }

  mysql:
    image: mysql:8.0
    environment:
      - MYSQL_DATABASE=control
      - MYSQL_USER=control
      - MYSQL_PASSWORD=${DB_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql/init:/docker-entrypoint-initdb.d   # DDL/DML 初始化脚本

  redis:
    image: redis:7-alpine

  milvus:
    image: milvusdb/milvus:latest
    volumes: [milvus-data:/var/lib/milvus]
```

> 控制中心仓库仅含设计/控制文档与编排配置（不含代码）；平台与业务代码（db/backend/frontend）位于各代码仓库（control-api、control-web、control-db、业务仓库），通过其 REST API / OpenAPI 对接与部署，不在本编排内。**不部署 Ollama、不部署 LiteLLM**：AI 消费企业内已启动的 LiteLLM 代理（接入 api.anthropic.com + ghe.com 企业版），平台仅以 `LITELLM_ENDPOINT` 直连；代理侧配置见 `04-l3-ai-gateway.md`。

## 资源分配参考

| 服务 | CPU | 内存 | 说明 |
|-----|-----|------|------|
| Spring API + Worker | 1核 | 1.5GB | 控制中心后端 |
| MySQL + Redis + Milvus | 0.5核 | 1GB | 数据层 |
| Web (Nginx) | 共享 | 共享 | 静态页 |
| LiteLLM 代理 | 企业既有 | 企业既有 | 消费端，不重复部署（见 04） |

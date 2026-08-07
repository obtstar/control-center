#!/usr/bin/env bash
# compose.sh — 由 setup-env.sh source（依赖 common.sh）

init_compose() {
  local deploy="$BASE_HOME/deploy"
  log "生成 compose 与 .env 模板: $deploy"

  [[ -f "$deploy/.env" ]] || cat > "$deploy/.env" <<'EOF'
# 测试环境专用，生产改用 Vault/密钥管理服务
DB_PASSWORD=change-me
LITELLM_API_KEY=change-me
EOF
  chmod 600 "$deploy/.env"

  if [[ -f "$deploy/docker-compose.yml" ]] && ! confirm_overwrite "$deploy/docker-compose.yml"; then
    log "保留已有 compose: $deploy/docker-compose.yml"
    return 0
  fi

  cat > "$deploy/docker-compose.yml" <<EOF
# 模拟综合测试环境（非生产形态，见 control-wiki raw/architecture/10）
services:
  web:
    image: internal-control-web:latest
    ports: ["80:80"]

  api:
    image: internal-control-api:latest
    environment:
      - DB_URL=jdbc:mysql://mysql:3306/control?useSSL=false&characterEncoding=utf8mb4
      - DB_USER=control
      - DB_PASSWORD=\${DB_PASSWORD}
      - LITELLM_ENDPOINT=http://litellm.internal:4000
      - VECTOR_DB_ENDPOINT=http://milvus:19530
    volumes:
      - $BASE_HOME/wt:/wt
      - $BASE_HOME/repos:/repos
    depends_on: [mysql, redis]

  worker:
    image: internal-control-worker:latest
    environment:
      - DB_URL=jdbc:mysql://mysql:3306/control?useSSL=false&characterEncoding=utf8mb4
    depends_on: [api, redis, mysql]
    deploy: { replicas: 2 }

  mysql:
    image: mysql:8.0
    environment:
      - MYSQL_DATABASE=control
      - MYSQL_USER=control
      - MYSQL_PASSWORD=\${DB_PASSWORD}
      - MYSQL_RANDOM_ROOT_PASSWORD=yes
    volumes:
      - $BASE_HOME/data/mysql:/var/lib/mysql
      - $deploy/mysql/init:/docker-entrypoint-initdb.d

  redis:
    image: redis:7-alpine

  milvus:
    image: milvusdb/milvus:latest
    volumes:
      - $BASE_HOME/data/milvus:/var/lib/milvus
EOF

  if grep -q 'change-me' "$deploy/.env"; then
    warn ".env 仍为占位符（change-me），跳过自动启动；填写密钥后执行: (cd $deploy && docker compose up -d)"
  elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
    (cd "$deploy" && docker compose up -d)
    log "docker-compose 测试环境已启动"
  else
    warn "docker compose 不可用，仅生成文件（$deploy/docker-compose.yml）"
  fi
}


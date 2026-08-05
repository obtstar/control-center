#!/usr/bin/env bash
# init-env.sh — 企业内网 Agent 平台环境一键初始化（模拟综合测试环境）
# 依据：docs/architecture/13-repo-template.md（目录布局）
#       docs/architecture/16-linux-permissions.md（用户/组/权限/sudoers）
#       docs/architecture/10-deployment.md（docker-compose 测试环境）
set -euo pipefail

BASE_HOME="${BASE_HOME:-$HOME}"
SKIP_USERS=0
SKIP_COMPOSE=0
SKIP_REPOS=0

usage() {
  cat <<EOF
用法: $0 [选项]
  --home DIR        基础 home 目录（默认: \$HOME）
  --executor        执行节点模式：仅初始化本机为 executor（办公 PC 的 WSL），
                    连接编排节点取代码、本地执行、结果回传（见 10 章 executor 代理）
  --control-api URL 编排节点 control-api 地址（executor 模式使用，
                    不传则交互式询问，如 http://192.168.1.10:8080）
  --skip-users      跳过 Linux 用户/组/sudoers 配置
  --skip-repos      跳过代码仓库骨架初始化
  --skip-compose    跳过 docker-compose 生成与启动
  -h, --help        显示帮助
EOF
}

EXECUTOR=0
CONTROL_API=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --home) BASE_HOME="$2"; shift 2 ;;
    --executor) EXECUTOR=1; shift ;;
    --control-api) CONTROL_API="$2"; shift 2 ;;
    --skip-users) SKIP_USERS=1; shift ;;
    --skip-repos) SKIP_REPOS=1; shift ;;
    --skip-compose) SKIP_COMPOSE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

log() { printf '\033[1;34m[init]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

# ── 1. 目录结构（13.1）────────────────────────────────────────
init_dirs() {
  log "创建目录结构（base: $BASE_HOME）"
  mkdir -p \
    "$BASE_HOME/control-center/docs/design/overview" \
    "$BASE_HOME/control-center/docs/design/external" \
    "$BASE_HOME/control-center/docs/requirements" \
    "$BASE_HOME/control-center/docs/architecture" \
    "$BASE_HOME/control-center/orchestration/prompts" \
    "$BASE_HOME/control-center/orchestration/skills" \
    "$BASE_HOME/control-center/orchestration/workflows" \
    "$BASE_HOME/repos" \
    "$BASE_HOME/wt" \
    "$BASE_HOME/data/mysql" \
    "$BASE_HOME/data/milvus" \
    "$BASE_HOME/logs" \
    "$BASE_HOME/scripts" \
    "$BASE_HOME/deploy/mysql/init"

  chmod 750 "$BASE_HOME/control-center" "$BASE_HOME/data" "$BASE_HOME/logs"
  chmod 770 "$BASE_HOME/repos" "$BASE_HOME/wt"
}

# ── 2. Linux 用户/组/sudoers（16.2 / 16.3 / 16.5）─────────────
init_users() {
  if [[ $EUID -ne 0 ]]; then
    warn "非 root，跳过用户/组配置（可用 sudo 重试，或 --skip-users）"
    return 0
  fi

  log "创建用户组 dev-group / agent-group"
  groupadd -f dev-group
  groupadd -f agent-group

  # 角色账号（16.2）。dev-user 角色映射到当前实际用户（加入 dev-group）。
  local role_user
  role_user="${SUDO_USER:-$(logname 2>/dev/null || echo dev)}"

  create_user() { # $1=user $2=shell $3=groups
    if ! id "$1" &>/dev/null; then
      useradd -m -s "$2" ${3:+-G "$3"} "$1"
      log "创建用户 $1"
    fi
  }

  create_user dev-admin /bin/bash "dev-group"
  create_user agent-admin /usr/sbin/nologin "agent-group"
  create_user agent-readonly /usr/sbin/nologin "agent-group"
  create_user agent-auto /usr/sbin/nologin "agent-group"
  create_user agent-maintenance /usr/sbin/nologin "agent-group"

  if id "$role_user" &>/dev/null; then
    usermod -aG dev-group "$role_user"
    log "当前用户 $role_user 加入 dev-group（对应 dev-user 角色）"
  fi

  # 目录属主（16.3）
  chown -R dev-admin:dev-group "$BASE_HOME/control-center" "$BASE_HOME/repos" \
    "$BASE_HOME/data" "$BASE_HOME/logs"
  chown -R agent-admin:agent-group "$BASE_HOME/wt"

  # sudoers 白名单（16.5）
  local sudoers=/etc/sudoers.d/agent-control
  cat > "$sudoers" <<'EOF'
# Agent 用户无 sudo
# dev-user 仅允许受限 git 操作
%dev-group ALL=(root) /usr/bin/git push origin dev
# 部署/发布 main、release 需 dev-admin，且必须带审批脚本
dev-admin ALL=(root) /opt/control/bin/release.sh
EOF
  chmod 440 "$sudoers"
  if command -v visudo &>/dev/null; then
    visudo -cf "$sudoers" >/dev/null
  fi
  log "sudoers 白名单已写入 $sudoers"
}

# ── 3. 代码仓库骨架（13.2）────────────────────────────────────
init_repo_skeleton() { # $1=repo 名
  local repo="$BASE_HOME/repos/$1"
  [[ -d "$repo/.git" ]] && { log "仓库已存在，跳过: $1"; return 0; }
  mkdir -p "$repo"/{docs/design/internal,src/main,tests,db/ddl,ci,openapi}
  cat > "$repo/.gitignore" <<'EOF'
target/
node_modules/
dist/
*.log
.env
EOF
  cat > "$repo/README.md" <<EOF
# $1

概要/外部设计见控制中心仓库 \`control-center/docs/design/\`；
内部设计位于本仓库 \`docs/design/internal/\`，与代码同分支、同 MR 提交。
EOF
  git -C "$repo" init -b main >/dev/null
  git -C "$repo" -c user.name=init-env -c user.email=init-env@local \
    commit --allow-empty -m "chore: init repository skeleton" >/dev/null
  git -C "$repo" checkout -b dev >/dev/null
  log "初始化仓库: $1（main + dev）"
}

init_repos() {
  command -v git >/dev/null || { warn "未安装 git，跳过仓库骨架"; return 0; }
  for r in control-api control-web control-db; do
    init_repo_skeleton "$r"
  done
}

# ── 4. docker-compose 测试环境（10）───────────────────────────
init_compose() {
  local deploy="$BASE_HOME/deploy"
  log "生成 compose 与 .env 模板: $deploy"

  [[ -f "$deploy/.env" ]] || cat > "$deploy/.env" <<'EOF'
# 测试环境专用，生产改用 Vault/密钥管理服务
DB_PASSWORD=change-me
LITELLM_API_KEY=change-me
EOF
  chmod 600 "$deploy/.env"

  cat > "$deploy/docker-compose.yml" <<EOF
# 模拟综合测试环境（非生产形态，见 docs/architecture/10-deployment.md）
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

  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    (cd "$deploy" && docker compose up -d)
    log "docker-compose 测试环境已启动"
  else
    warn "docker compose 不可用，仅生成文件（$deploy/docker-compose.yml）"
  fi
}

# ── executor 模式（10 章：执行节点，办公 PC 的 WSL）───────────
init_executor() {
  # 未指定服务端地址时交互式询问
  if [[ -z "$CONTROL_API" ]]; then
    if [[ -t 0 ]]; then
      read -rp "请输入服务端（编排节点）地址，如 http://192.168.1.10:8080: " CONTROL_API
    fi
    [[ -z "$CONTROL_API" ]] && { echo "executor 模式需 --control-api URL 或交互输入" >&2; exit 1; }
  fi
  # 规范化：补协议、去尾斜杠
  [[ "$CONTROL_API" =~ ^https?:// ]] || CONTROL_API="http://$CONTROL_API"
  CONTROL_API="${CONTROL_API%/}"

  # 连通性预检（不阻断，仅提示）
  if command -v curl &>/dev/null; then
    curl -sf --max-time 5 -o /dev/null "$CONTROL_API/api/rag/search" \
      && log "服务端可达: $CONTROL_API" \
      || warn "服务端暂不可达（$CONTROL_API），继续初始化，executor 启动后自动重试"
  fi

  log "初始化执行节点（executor）: $BASE_HOME/executor"
  mkdir -p "$BASE_HOME/executor"/{workspace,cache,logs}
  chmod 750 "$BASE_HOME/executor"

  # 专用执行账号（16.2/16.8）：root 时创建 agent-exec 并接管工作区
  if [[ $EUID -eq 0 ]]; then
    id agent-exec &>/dev/null || useradd -m -s /usr/sbin/nologin agent-exec
    chown -R agent-exec:agent-exec "$BASE_HOME/executor"
    log "executor 服务账号: agent-exec（非 root、无 sudo）"
  fi

  # 能力标签按本机工具链探测
  local tags=()
  command -v java  &>/dev/null && tags+=("java$(java -version 2>&1 | grep -oP '(?<=version ")[0-9]+' | head -1)")
  command -v node  &>/dev/null && tags+=("node$(node -v | tr -d 'v' | cut -d. -f1)")
  command -v npx   &>/dev/null && npx --no-install playwright --version &>/dev/null && tags+=("playwright")
  local tag_csv
  tag_csv=$(IFS=,; echo "${tags[*]:-}")

  [[ -f "$BASE_HOME/executor/.env" ]] || cat > "$BASE_HOME/executor/.env" <<EOF
# executor 节点配置（10 章 executor 代理模式）
CONTROL_API=$CONTROL_API
EXECUTOR_TOKEN=change-me
EXECUTOR_TAGS=$tag_csv
EXECUTOR_SLOTS=1
EOF
  chmod 600 "$BASE_HOME/executor/.env"

  # 向 control-api 注册（失败不阻断，executor 服务启动时会重试注册/心跳）
  if command -v curl &>/dev/null; then
    curl -sf -X POST "$CONTROL_API/api/agents/register" \
      -H "Authorization: Bearer change-me" \
      -H "Content-Type: application/json" \
      -d "{\"type\":\"executor\",\"tags\":\"$tag_csv\",\"slots\":1}" \
      && log "已向 control-api 注册（tags: $tag_csv）" \
      || warn "注册失败（control-api 未就绪？），executor 服务启动后将自动重试"
  fi
  log "executor 工作区就绪: $BASE_HOME/executor/workspace（git fetch 任务分支后本地执行 ci/ 脚本）"
}

# ── main ──────────────────────────────────────────────────────
if [[ $EXECUTOR -eq 1 ]]; then
  init_executor
  log "完成（executor 模式）。本机已注册为执行节点，编排节点无需在本机初始化"
else
  init_dirs
  [[ $SKIP_USERS -eq 1 ]]   || init_users
  [[ $SKIP_REPOS -eq 1 ]]   || init_repos
  [[ $SKIP_COMPOSE -eq 1 ]] || init_compose
  log "完成。布局见 docs/architecture/13-repo-template.md，权限模型见 16-linux-permissions.md"
fi

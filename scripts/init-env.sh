#!/usr/bin/env bash
# init-env.sh — 企业内网 Agent 平台环境一键初始化（模拟综合测试环境）
# 依据：docs/architecture/13-repo-template.md（目录布局）
#       docs/architecture/16-linux-permissions.md（用户/权限，单人模型）
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
  --skip-users      跳过 Linux 用户配置
  --skip-repos      跳过代码仓库骨架初始化
  --skip-compose    跳过 docker-compose 生成与启动
  --skip-tooling    跳过 pi / openskills 安装与 ~/.pi 配置
  --check           仅做环境校验（预检 + 后检），不执行初始化
  -h, --help        显示帮助
环境变量:
  NPM_REGISTRY      npm 内网镜像（如 http://npm.internal:4873），安装 pi/openskills 时使用
  PIP_INDEX_URL     pip 镜像（如 http://pypi.internal/simple），
                    未设置时默认清华镜像 https://pypi.tuna.tsinghua.edu.cn/simple
  LITELLM_ENDPOINT  LiteLLM 代理地址（默认 http://litellm.internal:4000）
  GIT_REMOTE_BASE   仓库远程地址前缀（如 git@github.com:obtstar），
                    设置后骨架仓库自动添加 origin 并推送 main/dev
EOF
}

EXECUTOR=0
CONTROL_API=""
SKIP_TOOLING=0
CHECK_ONLY=0
LITELLM_ENDPOINT="${LITELLM_ENDPOINT:-http://litellm.internal:4000}"
# pip 镜像：优先内网镜像（PIP_INDEX_URL），未设置时默认清华镜像
export PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --home) BASE_HOME="$2"; shift 2 ;;
    --executor) EXECUTOR=1; shift ;;
    --control-api) CONTROL_API="$2"; shift 2 ;;
    --skip-users) SKIP_USERS=1; shift ;;
    --skip-repos) SKIP_REPOS=1; shift ;;
    --skip-compose) SKIP_COMPOSE=1; shift ;;
    --skip-tooling) SKIP_TOOLING=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

log() { printf '\033[1;34m[init]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

# 已存在文件的覆盖确认：交互时询问，非交互默认保留（返回 0=覆盖 1=保留）
confirm_overwrite() {
  [[ -t 0 ]] || return 1
  local ans
  read -rp "$1 已存在，是否覆盖？[y/N] " ans
  [[ "$ans" =~ ^[yY](es)?$ ]]
}

# ── 0. 环境校验（初始化前预检 / 初始化后后检）──────────────────
CHECK_FAIL=0
chk_pass() { printf '  \033[1;32m[PASS]\033[0m %s\n' "$*"; }
chk_warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$*"; }
chk_fail() { printf '  \033[1;31m[FAIL]\033[0m %s\n' "$*"; CHECK_FAIL=$((CHECK_FAIL+1)); }

check_pre() {
  log "环境预检（base: $BASE_HOME）"
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null \
    && chk_pass "WSL 环境" || chk_warn "非 WSL（Linux 原生可用，路径语义一致）"

  local c
  for c in git python3 curl; do
    command -v "$c" >/dev/null && chk_pass "命令: $c" || chk_fail "缺少命令: $c"
  done
  for c in npm docker java node; do
    command -v "$c" >/dev/null && chk_pass "命令: $c（可选）" || chk_warn "缺少可选命令: $c"
  done

  python3 -c 'import ensurepip' 2>/dev/null \
    && chk_pass "python3 venv 支持" || chk_warn "缺 ensurepip：apt install python3-venv"

  local avail
  avail=$(df -Pm "$BASE_HOME" 2>/dev/null | awk 'NR==2{print $4}') || true
  [[ -n "$avail" && "$avail" -ge 2048 ]] \
    && chk_pass "磁盘空间: ${avail}MB 可用" || chk_warn "磁盘空间不足 2GB（${avail:-未知}MB）"

  [[ -w "$BASE_HOME" || ! -e "$BASE_HOME" ]] \
    && chk_pass "目录可写: $BASE_HOME" || chk_fail "目录不可写: $BASE_HOME"

  if command -v curl &>/dev/null; then
    curl -sf --max-time 5 -o /dev/null "$LITELLM_ENDPOINT/v1/models" \
      && chk_pass "LiteLLM 代理可达: $LITELLM_ENDPOINT" \
      || chk_warn "LiteLLM 代理暂不可达（$LITELLM_ENDPOINT）"
  fi
}

check_post() {
  log "环境后检（base: $BASE_HOME）"
  local d
  if [[ $EXECUTOR -eq 1 ]]; then
    for d in executor/workspace executor/cache executor/logs; do
      [[ -d "$BASE_HOME/$d" ]] && chk_pass "目录: $d" || chk_fail "缺失目录: $d"
    done
    [[ -f "$BASE_HOME/executor/.env" ]] && chk_pass "executor/.env" || chk_fail "缺失 executor/.env"
    grep -q 'EXECUTOR_TOKEN=change-me' "$BASE_HOME/executor/.env" 2>/dev/null \
      && chk_warn "EXECUTOR_TOKEN 仍为占位符" || chk_pass "EXECUTOR_TOKEN 已配置"
    id agent &>/dev/null && chk_pass "用户: agent" || chk_warn "用户 agent 未创建（非 root 运行？）"
  else
    for d in control-center/docs control-center/orchestration control-center/registry \
             repos wt data/mysql logs deploy; do
      [[ -d "$BASE_HOME/$d" ]] && chk_pass "目录: $d" || chk_fail "缺失目录: $d"
    done
    [[ -f "$BASE_HOME/control.env" ]] && chk_pass "control.env" || chk_fail "缺失 control.env"
    grep -qF 'control.env' "$BASE_HOME/.bashrc" 2>/dev/null \
      && chk_pass "bashrc 挂载" || chk_warn "bashrc 未挂载 control.env"
    [[ -x "$BASE_HOME/.venv/bin/python" ]] && chk_pass "Python venv" || chk_warn "venv 未就绪"
    [[ -f "$BASE_HOME/deploy/docker-compose.yml" ]] \
      && chk_pass "docker-compose.yml" || chk_warn "compose 未生成"
    local r
    for r in control-api control-web control-db; do
      [[ -d "$BASE_HOME/repos/$r/.git" ]] && chk_pass "仓库: $r" || chk_warn "仓库未初始化: $r"
    done
    id agent &>/dev/null && chk_pass "用户: agent" || chk_warn "用户 agent 未创建（非 root 运行？）"
  fi
  [[ -f "$BASE_HOME/.pi/models.json" ]] \
    && chk_pass ".pi/models.json" || chk_warn ".pi/models.json 未生成（--skip-tooling？）"

  if [[ $CHECK_FAIL -gt 0 ]]; then
    printf '\033[1;31m[check]\033[0m 后检发现 %d 项 FAIL\n' "$CHECK_FAIL"
  else
    printf '\033[1;32m[check]\033[0m 后检通过（WARN 项可择情处理）\n'
  fi
  return "$CHECK_FAIL"
}

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
    "$BASE_HOME/control-center/registry" \
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

# ── 2. Linux 用户（16.2 / 16.3，单人模型：owner + agent）──────
init_users() {
  if [[ $EUID -ne 0 ]]; then
    warn "非 root，跳过用户配置（可用 sudo 重试，或 --skip-users）"
    return 0
  fi

  # 单人模型：owner = 当前实际用户；Agent 统一一个 agent 账号（本机 + 执行节点通用）
  # 代码/Worktree 全部在 owner home 下；agent 仅保留极简配置目录 $BASE_HOME/.agent
  local owner ogroup
  owner="${SUDO_USER:-$(logname 2>/dev/null || true)}"
  if [[ -z "$owner" ]]; then
    echo "无法确定实际用户（SUDO_USER/logname 均不可用），请以 sudo 方式运行" >&2
    exit 1
  fi
  ogroup="$(id -gn "$owner")"

  if ! id agent &>/dev/null; then
    useradd -M -d "$BASE_HOME/.agent" -s /usr/sbin/nologin agent
    log "创建用户 agent（非 root、无 sudo、不使用独立 home）"
  fi
  mkdir -p "$BASE_HOME/.agent"
  chown -R agent:agent "$BASE_HOME/.agent"
  chmod 750 "$BASE_HOME/.agent"

  # agent 加入 owner 组获得仓库/技能只读通道；owner home 保持 750（组 r-x）
  usermod -aG "$ogroup" agent
  chgrp -R "$ogroup" "$BASE_HOME/control-center" "$BASE_HOME/repos" 2>/dev/null || true

  # 目录属主（16.3）：owner 拥有控制面，agent 独占 ~/wt
  chown -R "$owner:$ogroup" "$BASE_HOME/control-center" "$BASE_HOME/repos" \
    "$BASE_HOME/data" "$BASE_HOME/logs" 2>/dev/null || true
  chown -R "agent:$ogroup" "$BASE_HOME/wt"
  chmod 770 "$BASE_HOME/wt"
  log "目录属主: owner=$owner（control-center/repos/data/logs），agent（wt，配置目录 .agent）"
  # 16.5：agent 用户不在 sudoers 中，无需写 sudoers 规则
}

# ── 3. 环境变量配置 ───────────────────────────────────────────
init_env_config() {
  local env_file="$BASE_HOME/control.env"
  if [[ -f "$env_file" ]] && ! confirm_overwrite "$env_file"; then
    log "保留已有配置: $env_file"
  else
  log "写入环境变量配置: $env_file"
  cat > "$env_file" <<EOF
# control.env — Agent 平台环境变量（13/15 章），由 init-env.sh 生成
export CONTROL_HOME="$BASE_HOME/control-center"
export REPOS_ROOT="$BASE_HOME/repos"
export WORKTREE_ROOT="$BASE_HOME/wt"
export CONTROL_DATA="$BASE_HOME/data"
export CONTROL_LOGS="$BASE_HOME/logs"
export LITELLM_ENDPOINT="$LITELLM_ENDPOINT"
# export LITELLM_API_KEY=    # 密钥不落盘，按需填入或经密钥管理注入
# export NPM_REGISTRY=       # npm 内网镜像，如 http://npm.internal:4873
# export PIP_INDEX_URL=      # pip 内网镜像，如 http://pypi.internal/simple
EOF
  chmod 600 "$env_file"
  # root(sudo) 运行时归属实际用户，否则 600 权限下 owner 无法 source
  if [[ $EUID -eq 0 ]]; then
    local owner="${SUDO_USER:-$(logname 2>/dev/null || true)}"
    [[ -n "$owner" ]] && chown "$owner:$(id -gn "$owner")" "$env_file"
  fi
  fi

  # bashrc 幂等挂载
  local bashrc="$BASE_HOME/.bashrc"
  if [[ -w "$BASE_HOME" ]]; then
    grep -qF "control.env" "$bashrc" 2>/dev/null || \
      echo '[[ -f ~/control.env ]] && source ~/control.env' >> "$bashrc"
  fi
}

# ── 4. Python 虚拟环境 ────────────────────────────────────────
init_venv() { # $1=目标 home $2=属主（可选，root 时 chown）
  local home="$1" user="${2:-}"
  command -v python3 >/dev/null || { warn "未安装 python3，跳过虚拟环境"; return 0; }
  if [[ -d "$home/.venv" ]]; then
    log "虚拟环境已存在，跳过: $home/.venv"
  else
    log "创建 Python 虚拟环境: $home/.venv"
    if ! python3 -m venv "$home/.venv" >/dev/null 2>&1; then
      rm -rf "$home/.venv"
      warn "venv 创建失败（Debian/Ubuntu 需先 apt install python3-venv），跳过"
      return 0
    fi
    # pip 内网镜像（PIP_INDEX_URL 已 export 则自动生效）
    "$home/.venv/bin/pip" install --quiet --upgrade pip \
      || warn "pip 升级失败（网络受限？），已保留自带 pip"
    # 控制中心自带依赖清单则一并安装
    if [[ -f "$home/control-center/requirements.txt" ]]; then
      "$home/.venv/bin/pip" install --quiet -r "$home/control-center/requirements.txt" \
        && log "已安装 control-center/requirements.txt"
    fi
  fi
  if [[ -n "$user" ]] && id "$user" &>/dev/null; then
    chown -R "$user:$user" "$home/.venv"
  fi
}

# ── 5. pi / openskills 安装与配置 ─────────────────────────────
install_agent_tooling() { # $1=目标 home $2=目标用户（可选，root 时 chown）
  local home="$1" user="${2:-}"

  # 5.1 pi（Earendil Pi Coding Agent，02 章执行层核心工具）
  if command -v pi &>/dev/null; then
    log "pi 已安装，跳过"
  elif command -v npm &>/dev/null; then
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent \
      ${NPM_REGISTRY:+--registry="$NPM_REGISTRY"} \
      && log "pi 安装完成" || warn "pi 安装失败（网络受限？可 vendor 后重试）"
  else
    warn "未安装 npm，跳过 pi 安装（需 Node.js 环境）"
  fi

  # 5.2 ~/.pi/models.json：自定义 provider 指向企业 LiteLLM 代理（04 章）
  mkdir -p "$home/.pi"
  if [[ ! -f "$home/.pi/models.json" ]]; then
    cat > "$home/.pi/models.json" <<EOF
{
  "providers": [{
    "name": "litellm-enterprise",
    "base_url": "$LITELLM_ENDPOINT/v1",
    "api_key": "\${LITELLM_API_KEY}",
    "models": ["coding", "cheap", "heavy"]
  }]
}
EOF
    chmod 600 "$home/.pi/models.json"
    log "已生成 $home/.pi/models.json（LiteLLM 代理，别名 coding/cheap/heavy）"
  fi

  # 5.3 openskills（07.3：SKILL.md 技能管理）
  if command -v openskills &>/dev/null; then
    log "openskills 已安装，跳过"
  elif command -v npm &>/dev/null; then
    npm install -g --ignore-scripts openskills \
      ${NPM_REGISTRY:+--registry="$NPM_REGISTRY"} \
      && log "openskills 安装完成" || warn "openskills 安装失败，可后续手动安装"
  fi

  # 5.4 技能目录软链：~/.pi/skills → 控制中心 orchestration/skills（Git 版本化）
  if [[ -d "$BASE_HOME/control-center/orchestration/skills" ]]; then
    ln -sfn "$BASE_HOME/control-center/orchestration/skills" "$home/.pi/skills"
    log "技能目录已链接: $home/.pi/skills → control-center/orchestration/skills"
  fi

  # root 模式下把配置归属目标用户
  if [[ -n "$user" ]] && id "$user" &>/dev/null; then
    chown -R "$user:$user" "$home/.pi" "$home/.venv" 2>/dev/null || true
  fi
}
# ── 6. 代码仓库骨架（13.2）────────────────────────────────────
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
  # git >= 2.28 支持 init -b；旧版本回退 symbolic-ref
  if ! git -C "$repo" init -b main >/dev/null 2>&1; then
    git -C "$repo" init >/dev/null
    git -C "$repo" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$repo" -c user.name=init-env -c user.email=init-env@local \
    commit --allow-empty -m "chore: init repository skeleton" >/dev/null
  git -C "$repo" checkout -b dev >/dev/null
  # 可选：配置远程并推送（GIT_REMOTE_BASE 如 git@github.com:obtstar 或 git@git.internal:group）
  if [[ -n "${GIT_REMOTE_BASE:-}" ]]; then
    local remote="$GIT_REMOTE_BASE/$1.git"
    git -C "$repo" remote add origin "$remote" 2>/dev/null || true
    if git -C "$repo" push -u origin main dev >/dev/null 2>&1; then
      log "初始化仓库: $1（main + dev，已推送 $remote）"
    else
      warn "仓库 $1 已初始化，但推送失败（远程不存在或无权限？）：$remote"
    fi
  else
    log "初始化仓库: $1（main + dev，未配置远程；设 GIT_REMOTE_BASE 可自动推送）"
  fi
}

init_repos() {
  command -v git >/dev/null || { warn "未安装 git，跳过仓库骨架"; return 0; }
  for r in control-api control-web control-db; do
    init_repo_skeleton "$r"
  done
  # root(sudo) 运行时把新建仓库归属实际用户（16.3 权限模型）
  if [[ $EUID -eq 0 ]]; then
    local owner="${SUDO_USER:-$(logname 2>/dev/null || true)}"
    [[ -n "$owner" ]] && chown -R "$owner:$(id -gn "$owner")" "$BASE_HOME/repos"
  fi
}

# ── 7. docker-compose 测试环境（10）───────────────────────────
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

  if grep -q 'change-me' "$deploy/.env"; then
    warn ".env 仍为占位符（change-me），跳过自动启动；填写密钥后执行: (cd $deploy && docker compose up -d)"
  elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
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

  # 连通性预检（不阻断，仅提示）；/actuator/health 为免认证健康端点
  if command -v curl &>/dev/null; then
    curl -sf --max-time 5 -o /dev/null "$CONTROL_API/actuator/health" \
      && log "服务端可达: $CONTROL_API" \
      || warn "服务端暂不可达（$CONTROL_API），继续初始化，executor 启动后自动重试"
  fi

  log "初始化执行节点（executor）: $BASE_HOME/executor"
  mkdir -p "$BASE_HOME/executor"/{workspace,cache,logs}
  chmod 750 "$BASE_HOME/executor"

  # 专用执行账号（16.2：统一 agent 用户，不使用独立 home，配置落 .agent）
  if [[ $EUID -eq 0 ]]; then
    id agent &>/dev/null || useradd -M -d "$BASE_HOME/.agent" -s /usr/sbin/nologin agent
    mkdir -p "$BASE_HOME/.agent"
    chown -R agent:agent "$BASE_HOME/executor" "$BASE_HOME/.agent"
    log "executor 服务账号: agent（非 root、无 sudo）"
  fi

  # 能力标签按本机工具链探测
  local tags=()
  command -v java  &>/dev/null && tags+=("java$(java -version 2>&1 | grep -oP '(?<=version ")[0-9]+' | head -1)")
  command -v node  &>/dev/null && tags+=("node$(node -v | tr -d 'v' | cut -d. -f1)")
  command -v pnpm  &>/dev/null && tags+=("pnpm")
  command -v npx   &>/dev/null && npx --no-install playwright --version &>/dev/null && tags+=("playwright")
  local tag_csv
  tag_csv=$(IFS=,; echo "${tags[*]:-}")

  # executor_id 默认取主机名，须与 registry/executors.yaml 中的登记一致
  local executor_id
  executor_id="$(hostname 2>/dev/null || echo pc-01)"

  [[ -f "$BASE_HOME/executor/.env" ]] || cat > "$BASE_HOME/executor/.env" <<EOF
# executor 节点配置（10 章 executor 代理模式）
CONTROL_API=$CONTROL_API
EXECUTOR_ID=$executor_id
EXECUTOR_TOKEN=change-me
EXECUTOR_TAGS=$tag_csv
EXECUTOR_SLOTS=1
EOF
  chmod 600 "$BASE_HOME/executor/.env"

  cat <<EOF

  登记步骤（声明式，无注册接口）：
  1. 在控制中心仓库 registry/executors.yaml 新增条目并合并：
       - executor_id: $executor_id
         tags: [${tag_csv//,/, }]
         slots:
           day: 1      # 工作日白天轻量槽位
           night: 2    # 夜间 02:00-06:00 全量槽位
         token_ref: env:EXECUTOR_TOKEN_$(echo "$executor_id" | tr 'a-z-' 'A-Z_')
  2. 将服务端签发的 token 写入本文件 EXECUTOR_TOKEN
  3. 启动 executor 服务后开始心跳/领取任务

EOF
  log "executor 工作区就绪: $BASE_HOME/executor/workspace（git fetch 任务分支后本地执行 ci/ 白名单脚本）"

  # 执行节点工具链：pi + openskills + models.json（16.7，配置落 agent 配置目录）
  if [[ $SKIP_TOOLING -eq 0 ]]; then
    install_agent_tooling "$BASE_HOME/.agent" agent
  fi
  init_venv "$BASE_HOME" agent
}

# ── main ──────────────────────────────────────────────────────
if [[ $CHECK_ONLY -eq 1 ]]; then
  check_pre
  check_post || true
  exit 0
fi

check_pre
if [[ $EXECUTOR -eq 1 ]]; then
  init_executor
  check_post || true
  log "完成（executor 模式）。请在 registry/executors.yaml 登记本机后启动 executor 服务"
else
  init_dirs
  [[ $SKIP_USERS -eq 1 ]]   || init_users
  init_env_config
  OWNER="${SUDO_USER:-$(logname 2>/dev/null || id -un)}"
  init_venv "$BASE_HOME" "$OWNER"
  if [[ $SKIP_TOOLING -eq 0 ]]; then
    install_agent_tooling "$BASE_HOME" "$OWNER"          # 人工通道（VSCode/CLI）
    [[ $EUID -eq 0 ]] && install_agent_tooling "$BASE_HOME/.agent" agent  # Agent 通道
  fi
  [[ $SKIP_REPOS -eq 1 ]]   || init_repos
  [[ $SKIP_COMPOSE -eq 1 ]] || init_compose
  check_post || true
  log "完成。布局见 docs/architecture/13-repo-template.md，权限模型见 16-linux-permissions.md"
fi

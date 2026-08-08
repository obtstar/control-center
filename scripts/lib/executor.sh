#!/usr/bin/env bash
# executor.sh — 由 setup-env.sh source（依赖 common.sh）

init_executor() {
  # 未指定服务端地址时交互式询问
  if [[ -z "$CONTROL_API" ]]; then
    if has_tty; then
      ask "请输入服务端（编排节点）地址，如 http://192.168.1.10:8080: " CONTROL_API
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
  init_toolchain
  init_mirrors
  mkdir -p "$BASE_HOME/executor"/{workspace,cache,logs}
  # executor 目录由阶段一创建（agent:ogroup 2770）；dev 无 sudo 不能 chmod 他人目录，
  # 仅属主/root 时调整权限，否则保持阶段一设置
  if [[ -O "$BASE_HOME/executor" || $EUID -eq 0 ]]; then
    chmod 770 "$BASE_HOME/executor" 2>/dev/null || true
  fi

  # 专用执行账号（16.2：统一 agent 用户，不使用独立 home，配置落 .agent）
  if [[ $EUID -eq 0 ]]; then
    id agent &>/dev/null || useradd -M -d "$BASE_HOME/.agent" -s /usr/sbin/nologin agent
    mkdir -p "$BASE_HOME/.agent"
    chown -R agent:agent "$BASE_HOME/executor" "$BASE_HOME/.agent"
    log "executor 服务账号: agent（非 root、无 sudo）"
  fi

  # 能力标签按工作用户工具链探测（用户级安装，root 上下文看不到）
  local tags=()
  as_target_user "$USER_ENV command -v java" &>/dev/null \
    && tags+=("java$(as_target_user "$USER_ENV java -version" 2>&1 | grep -oP '(?<=version ")[0-9]+' | head -1)")
  as_target_user "$USER_ENV command -v node" &>/dev/null \
    && tags+=("node$(as_target_user "$USER_ENV node -v" 2>/dev/null | tr -d 'v' | cut -d. -f1)")
  as_target_user "$USER_ENV command -v pnpm" &>/dev/null && tags+=("pnpm")
  as_target_user "$USER_ENV bash -c 'command -v npx && npx --no-install playwright --version'" &>/dev/null \
    && tags+=("playwright")
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
EXECUTOR_SLOTS_DAY=1
EXECUTOR_SLOTS_NIGHT=2
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
    install_pi_packages
    install_agent_tooling "$BASE_HOME/.agent" agent
  fi
  init_venv "$BASE_HOME" agent
}


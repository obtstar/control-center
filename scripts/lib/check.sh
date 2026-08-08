#!/usr/bin/env bash
# check.sh — 由 setup-env.sh source（依赖 common.sh）

check_pre() {
  log "环境预检（base: $BASE_HOME）"
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null \
    && chk_pass "WSL 环境" || chk_warn "非 WSL（Linux 原生可用，路径语义一致）"

  # 命令检测切换到工作用户（dev）上下文；未创建或无法切换则跳过
  if [[ $EXECUTOR -eq 0 ]] && ! id "$OWNER" &>/dev/null; then
    chk_warn "工作用户 $OWNER 未创建，跳过用户环境检测（初始化时将自动创建）"
  elif ! as_target_user 'true' &>/dev/null; then
    chk_warn "无法切换到 $OWNER 用户上下文（需 root 或免密 sudo），跳过用户环境检测"
  else
  local c p
  # 用户级工具链环境（nvm / uv / ~/.local/bin），校验前先加载
  local user_env='source "$HOME/.nvm/nvm.sh" 2>/dev/null; export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH";'
  # 系统级必需命令
  for c in git curl; do
    as_target_user "command -v $c" >/dev/null 2>&1 && chk_pass "命令: $c" || chk_fail "缺少命令: $c"
  done
  # 用户级优先命令：node/npm/pnpm（nvm+corepack）、java/mvn（清华镜像直装 ~/.local）、go（golang.google.cn）、cargo（rustup）
  for c in node npm pnpm java mvn go cargo; do
    p="$(as_target_user "$user_env command -v $c" 2>/dev/null)" || p=""
    if [[ -z "$p" ]]; then
      chk_warn "缺少可选命令: $c"
    elif [[ "$p" == "$BASE_HOME/"* ]]; then
      chk_pass "命令: $c（用户级: $p）"
    else
      chk_warn "命令: $c 仅系统级（$p），建议用户级安装（nvm/uv/镜像直装）"
    fi
  done
  # uv：Python 唯一管理入口（版本/.venv/包）
  as_target_user "$user_env command -v uv" >/dev/null 2>&1 \
    && chk_pass "uv 可用（Python/.venv 由 uv 管理）" \
    || chk_warn "缺少 uv：Python/.venv 由 uv 管理，初始化时可安装"
  # docker：系统级守护进程，单独校验
  as_target_user "command -v docker" >/dev/null 2>&1 \
    && chk_pass "命令: docker（可选）" || chk_warn "缺少可选命令: docker"

  # 现代 CLI 工具：单行汇总（可选，缺失不 FAIL）
  local cli=(git tmux jq xh dust lazygit zoxide yazi glow fzf)
  local ok="" miss=""
  for c in "${cli[@]}"; do
    if as_target_user "$user_env command -v $c" >/dev/null 2>&1; then
      ok+="$c "
    else
      miss+="$c "
    fi
  done
  [[ -n "$ok" ]] && chk_pass "CLI 工具: ${ok% }"
  [[ -n "$miss" ]] && chk_warn "CLI 工具缺失（可选）: ${miss% }"

  # Agent 工具组（pi/openskills/openwiki）
  local agents=(pi openskills openwiki) aok="" amiss=""
  for c in "${agents[@]}"; do
    if as_target_user "$user_env command -v $c" >/dev/null 2>&1; then
      aok+="$c "
    else
      amiss+="$c "
    fi
  done
  [[ -n "$aok" ]] && chk_pass "Agent 工具: ${aok% }"
  [[ -n "$amiss" ]] && chk_warn "Agent 工具缺失: ${amiss% }"

  # docker 免 sudo：工作用户在 docker 组中
  if as_target_user "command -v docker" >/dev/null 2>&1; then
    as_target_user "id -nG | grep -qw docker" >/dev/null 2>&1 \
      && chk_pass "$OWNER 在 docker 组（免 sudo）" \
      || chk_warn "$OWNER 不在 docker 组：docker 需 sudo（初始化时自动加入，重新登录生效）"
  fi
  fi

  local avail
  avail=$(df -Pm "$BASE_HOME" 2>/dev/null | awk 'NR==2{print $4}') || true
  [[ -n "$avail" && "$avail" -ge 2048 ]] \
    && chk_pass "磁盘空间: ${avail}MB 可用" || chk_warn "磁盘空间不足 2GB（${avail:-未知}MB）"

  # 初始化以 root 身份执行，可写性以 root 为准；非 root 巡检仅检查存在性
  if [[ $EUID -eq 0 ]]; then
    [[ -w "$BASE_HOME" || ! -e "$BASE_HOME" ]] \
      && chk_pass "目录可写: $BASE_HOME" || chk_fail "目录不可写: $BASE_HOME"
  else
    [[ -e "$BASE_HOME" ]] && chk_pass "目录存在: $BASE_HOME（写权限以 root 初始化为准）" \
      || chk_warn "目录不存在: $BASE_HOME（初始化时创建）"
  fi

  if command -v curl &>/dev/null; then
    curl -sf --max-time 5 -o /dev/null "$LITELLM_ENDPOINT/v1/models" \
      && chk_pass "LiteLLM 代理可达: $LITELLM_ENDPOINT" \
      || chk_warn "LiteLLM 代理暂不可达（$LITELLM_ENDPOINT）"
  fi
}

check_post() {
  log "环境后检（base: $BASE_HOME）"
  # 后检以工作用户环境为准；未创建或无法读取其 home 则跳过
  if [[ $EXECUTOR -eq 0 ]] && ! id "$OWNER" &>/dev/null; then
    chk_warn "工作用户 $OWNER 未创建，跳过用户环境后检"
    return 0
  fi
  if [[ "$(id -un)" != "$OWNER" && $EUID -ne 0 ]] && ! as_target_user 'true' &>/dev/null; then
    chk_warn "无法切换到 $OWNER 用户上下文（需 root 或免密 sudo），跳过用户环境后检"
    return 0
  fi
  # 文件/目录检查一律在工作用户上下文（/home/dev 750，其他用户读不到）
  t_test() { as_target_user "[[ $* ]]"; }
  # 尚未初始化：整体提示，不逐项 FAIL
  if [[ $EXECUTOR -eq 0 ]] && t_test "! -e '$BASE_HOME/control.env' -a ! -d '$BASE_HOME/control-center'"; then
    chk_warn "环境尚未初始化（属预期，执行 sudo bash scripts/init-env.sh 后复检）"
    return 0
  fi
  if [[ $EXECUTOR -eq 1 ]] && t_test "! -d '$BASE_HOME/executor'"; then
    chk_warn "executor 尚未初始化（属预期，执行 --executor 初始化后复检）"
    return 0
  fi
  local d
  if [[ $EXECUTOR -eq 1 ]]; then
    for d in executor/workspace executor/cache executor/logs; do
      t_test "-d '$BASE_HOME/$d'" && chk_pass "目录: $d" || chk_fail "缺失目录: $d"
    done
    t_test "-f '$BASE_HOME/executor/.env'" && chk_pass "executor/.env" || chk_fail "缺失 executor/.env"
    as_target_user "grep -q 'EXECUTOR_TOKEN=change-me' '$BASE_HOME/executor/.env'" 2>/dev/null \
      && chk_warn "EXECUTOR_TOKEN 仍为占位符" || chk_pass "EXECUTOR_TOKEN 已配置"
    id agent &>/dev/null && chk_pass "用户: agent" || chk_warn "用户 agent 未创建（非 root 运行？）"
  else
    for d in control-center/orchestration control-center/registry control-center/scripts \
             .repos wt data/mysql logs deploy; do
      t_test "-d '$BASE_HOME/$d'" && chk_pass "目录: $d" || chk_fail "缺失目录: $d"
    done
    t_test "-f '$BASE_HOME/control.env'" && chk_pass "control.env" || chk_fail "缺失 control.env"
    as_target_user "grep -qF 'control.env' '$BASE_HOME/.bashrc'" 2>/dev/null \
      && chk_pass "bashrc 挂载" || chk_warn "bashrc 未挂载 control.env"
    t_test "-x '$BASE_HOME/.venv/bin/python'" && chk_pass "Python venv" || chk_warn "venv 未就绪"
    t_test "-f '$BASE_HOME/deploy/docker-compose.yml'" \
      && chk_pass "docker-compose.yml" || chk_warn "compose 未生成"
    local r b
    for r in control-api control-web control-db; do
      t_test "-e '$BASE_HOME/$r/.git'" && chk_pass "仓库: $r" || chk_warn "仓库未初始化: $r"
    done
    t_test "-e '$BASE_HOME/control-piekbs/.git'" \
      && chk_pass "仓库: control-piekbs" || chk_warn "仓库未初始化: control-piekbs"
    id agent &>/dev/null && chk_pass "用户: agent" || chk_warn "用户 agent 未创建（非 root 运行？）"
    # 最小权限：工作用户不在 sudo 组
    id -nG "$OWNER" 2>/dev/null | grep -qw sudo \
      && chk_warn "工作用户 $OWNER 在 sudo 组（建议移除: gpasswd -d $OWNER sudo）" \
      || chk_pass "工作用户 $OWNER 无 sudo 权限"
  fi
  t_test "-f '$BASE_HOME/.pi/models.json'" \
    && chk_pass ".pi/models.json" || chk_warn ".pi/models.json 未生成（--skip-tooling？）"

  if [[ $CHECK_FAIL -gt 0 ]]; then
    printf '\033[1;31m[check]\033[0m 后检发现 %d 项 FAIL\n' "$CHECK_FAIL"
  else
    printf '\033[1;32m[check]\033[0m 后检通过（WARN 项可择情处理）\n'
  fi
  return "$CHECK_FAIL"
}


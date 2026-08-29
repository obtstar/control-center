# init-env-steps.sh — init-env.sh 步骤函数库（FINDING-053 拆分）
# 从 init-env.sh 拆出的函数：check_pre / interactive_setup / install_sys_packages / install_docker。
# 依赖的工具函数（log/warn/has_tty/ask/chk_*/as_target_user）在 init-env.sh 定义，
# source 本文件须在其定义之后、main 之前（bash 动态作用域）。
# 约束：init-env.sh 必须落盘执行（管道模式 BASH_SOURCE 不可解析，见 init-env.sh 头部检测）。

check_pre() {
  log "环境预检（base: $BASE_HOME）"
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null \
    && chk_pass "WSL 环境" || chk_warn "非 WSL（Linux 原生可用）"
  local c
  for c in git curl; do
    as_target_user "command -v $c" >/dev/null 2>&1 \
      && chk_pass "命令: $c" || chk_fail "缺少命令: $c（系统级必需）"
  done
  local avail
  avail=$(df -Pm "$BASE_HOME" 2>/dev/null | awk 'NR==2{print $4}') || true
  [[ -n "$avail" && "$avail" -ge 2048 ]] \
    && chk_pass "磁盘空间: ${avail}MB 可用" || chk_warn "磁盘空间不足 2GB（${avail:-未知}MB）"
  if [[ $EUID -eq 0 ]]; then
    [[ -w "$BASE_HOME" || ! -e "$BASE_HOME" ]] \
      && chk_pass "目录可写: $BASE_HOME" || chk_fail "目录不可写: $BASE_HOME"
  else
    [[ -e "$BASE_HOME" ]] && chk_pass "目录存在: $BASE_HOME（写权限以 root 初始化为准）" \
      || chk_warn "目录不存在: $BASE_HOME（初始化时创建）"
  fi
}

interactive_setup() {
  has_tty || return 0
  local ans ans2
  if [[ $OWNER_SET -eq 0 ]]; then
    while true; do
      ask "工作用户名（新建/使用的 Linux 账号，回车默认 $OWNER）: " ans
      [[ -z "$ans" || "$ans" == "$OWNER" ]] && break
      if [[ "$ans" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        ask "确认使用工作用户「$ans」？[y/N] " ans2
        if [[ "$ans2" =~ ^[yY](es)?$ ]]; then
          OWNER="$ans"; BASE_HOME="/home/$OWNER"; break
        fi
      else
        warn "非法用户名: $ans（需小写字母开头，仅含小写字母/数字/_/-）"
      fi
    done
  fi
  if [[ $EXECUTOR_SET -eq 0 ]]; then
    ask "节点模式：1) 编排节点  2) 执行节点 [1]: " ans
    [[ "$ans" == "2" ]] && EXECUTOR=1
  fi
  return 0
}

install_sys_packages() {
  local want=(direnv tmux rg fd jq gh fzf grep awk sed find xargs)
  local missing=() p
  for p in "${want[@]}"; do
    case "$p" in
      fd) command -v fd &>/dev/null || command -v fdfind &>/dev/null || missing+=(fd) ;;
      *)  command -v "$p" &>/dev/null || missing+=("$p") ;;
    esac
  done
  [[ ${#missing[@]} -eq 0 ]] && { log "系统工具已齐备: ${want[*]}"; return 0; }
  has_tty || { log "非交互，跳过系统工具安装: ${missing[*]}"; return 0; }
  local ans
  ask "安装系统级工具 ${missing[*]}？[Y/n] " ans
  [[ "$ans" =~ ^[nN](o)?$ ]] && { log "跳过: ${missing[*]}"; return 0; }

  local base=() gh_pkg=""
  if command -v apt-get &>/dev/null; then
    for p in "${missing[@]}"; do
      case "$p" in
        fd) base+=(fd-find);; rg) base+=(ripgrep);; gh) gh_pkg=gh;;
        awk) base+=(gawk);; find|xargs) base+=(findutils);;
        *) base+=("$p");;
      esac
    done
    apt-get update -qq
    if [[ ${#base[@]} -gt 0 ]]; then
      apt-get install -y -qq "${base[@]}"
    fi
  elif command -v pacman &>/dev/null; then
    for p in "${missing[@]}"; do
      case "$p" in
        rg) base+=(ripgrep);; gh) base+=(github-cli);;
        awk) base+=(gawk);; find|xargs) base+=(findutils);;
        *) base+=("$p");;
      esac
    done
    pacman -Sy --noconfirm --needed "${base[@]}"
  elif command -v dnf &>/dev/null; then
    for p in "${missing[@]}"; do
      case "$p" in
        fd) base+=(fd-find);; rg) base+=(ripgrep);; gh) gh_pkg=gh;;
        awk) base+=(gawk);; find|xargs) base+=(findutils);;
        *) base+=("$p");;
      esac
    done
    dnf install -y "${base[@]}"
  else
    warn "无法识别包管理器，请手动安装: ${missing[*]}"
    return 0
  fi
  # gh（GitHub CLI）：apt/dnf 默认源可能无此包，单独尝试
  if [[ -n "$gh_pkg" ]]; then
    if command -v apt-get &>/dev/null; then
      apt-get install -y -qq gh 2>/dev/null \
        || warn "gh 不在默认源，跳过（可用 GitHub CLI 官方源或 pacman 的 github-cli）"
    else
      dnf install -y gh 2>/dev/null || warn "gh 安装失败，跳过"
    fi
  fi

  # 现代 CLI 工具：包管理器优先（pacman 全量；apt 部分），
  # 缺包的由阶段二 install_gh_tools 以 GitHub release 兜底
  local extras=() e
  if command -v pacman &>/dev/null; then
    for e in xh dust lazygit zoxide yazi glow; do
      command -v "$e" &>/dev/null || extras+=("$e")
    done
    if [[ ${#extras[@]} -gt 0 ]]; then
      log "安装现代 CLI（pacman）: ${extras[*]}"
      pacman -Sy --noconfirm --needed "${extras[@]}" \
        || warn "部分包安装失败，阶段二可用 GitHub release 兜底"
    fi
  elif command -v apt-get &>/dev/null; then
    # apt 映射：du-dust 提供 dust；lazygit/yazi/glow 默认源没有 → 留阶段二
    for e in xh du-dust zoxide; do
      local ec="$e"; [[ "$e" == "du-dust" ]] && ec="dust"
      command -v "$ec" &>/dev/null || extras+=("$e")
    done
    for e in ${extras[@]:-}; do
      [[ -z "$e" ]] && continue
      apt-get install -y -qq "$e" 2>/dev/null \
        || warn "$e 不在当前源（阶段二以 GitHub release 安装）"
    done
  fi
  log "系统工具安装完成（direnv 钩子由阶段二写入 bashrc）"
}

install_docker() {
  if command -v docker &>/dev/null; then
    log "docker 已安装，跳过"
    return 0
  fi
  has_tty || { log "非交互，跳过 docker 安装"; return 0; }
  local ans
  ask "安装 Docker（compose 测试环境需要）？[y/N] " ans
  [[ "$ans" =~ ^[yY](es)?$ ]] || { log "跳过: docker"; return 0; }
  if command -v apt-get &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq docker.io
    apt-get install -y -qq docker-compose-v2 2>/dev/null \
      || apt-get install -y -qq docker-compose-plugin 2>/dev/null \
      || warn "compose 插件安装失败（可后续手动: apt install docker-compose-v2）"
  elif command -v pacman &>/dev/null; then
    pacman -Sy --noconfirm --needed docker docker-compose
  elif command -v dnf &>/dev/null; then
    dnf install -y docker docker-compose-plugin \
      || warn "compose 插件失败（可后续手动: dnf install docker-compose-plugin）"
  else
    warn "无法识别包管理器，请手动安装 docker"
    return 0
  fi
  if command -v systemctl &>/dev/null; then
    systemctl enable --now docker 2>/dev/null \
      || warn "docker 服务启动失败（WSL 无 systemd？请手动: sudo dockerd 或 sudo service docker start）"
  else
    warn "无 systemctl（WSL？），请手动启动 dockerd"
  fi
  # docker 组装于安装后，补一次用户加组（init_users_dirs 时组尚不存在）
  getent group docker &>/dev/null && usermod -aG docker "$OWNER" \
    && log "docker 安装完成，$OWNER 已加入 docker 组（免 sudo，重新登录生效）"
}

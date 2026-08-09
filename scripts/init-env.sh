#!/usr/bin/env bash
# init-env.sh — Agent 平台环境引导（阶段一）
# 只做三件事：环境校验 → 创建工作用户（dev/agent）→ 克隆 control-center 本工程
# 软件安装、仓库同步、pi/PieKBS 等全部在阶段二（setup-env.sh）：
#   首次以工作用户登录时自动触发（bashrc 钩子，一次性），
#   或随时手动执行: bash ~/control-center/scripts/setup-env.sh
# 架构文档见 control-center/docs/architecture/
set -euo pipefail

OWNER="${OWNER_USER:-dev}"   # 工作用户（默认 dev，--owner 自定义）
BASE_HOME="/home/$OWNER"     # 基目录恒为工作用户 home
SAVED_ARGS="$*"
OWNER_SET=0
EXECUTOR=0
EXECUTOR_SET=0
CHECK_ONLY=0
CONTROL_API=""
SETUP_ARGS=""                # 透传给阶段二的参数（--skip-* / --control-api）

usage() {
  cat <<EOF
用法: $0 [选项]（阶段一：校验 + 用户 + 克隆 control-center）
  --owner NAME      工作用户（默认: dev；不存在时自动创建，其 home 即环境基目录）
  --executor        执行节点模式（仅创建用户与目录，阶段二走 executor 分支）
  --control-api URL 编排节点地址（executor 模式，透传阶段二）
  --skip-*          透传给阶段二 setup-env.sh
  --check           仅做环境校验，不执行初始化（非 root 仅支持此模式）
  -h, --help        显示帮助
环境变量:
  GIT_PROTO         control-center 远程协议 ssh|http（默认交互询问）
  GIT_REMOTE_HOST   远程主机/组织（默认 github.com/obtstar）
  GIT_REMOTE_BASE   远程地址全量前缀（优先于 GIT_PROTO 组合）
  GH_PROXY          GitHub 加速代理前缀（如 https://gh.dpik.top）
  LITELLM_ENDPOINT  LiteLLM 代理地址（默认 http://litellm.internal:4000）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; OWNER_SET=1; shift 2 ;;
    --executor) EXECUTOR=1; EXECUTOR_SET=1; SETUP_ARGS+=" --executor"; shift ;;
    --control-api) CONTROL_API="$2"; SETUP_ARGS+=" --control-api '$2'"; shift 2 ;;
    --skip-users|--skip-repos|--skip-compose|--skip-tooling) SETUP_ARGS+=" $1"; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

# 阶段一需 root（创建用户、目录属主）；非 root 仅允许 --check
if [[ $CHECK_ONLY -eq 0 && $EUID -ne 0 ]]; then
  echo "初始化需要 root 权限（创建用户、目录属主配置），非 root 仅支持 --check 环境校验。" >&2
  echo "请使用: sudo -E bash $0 $SAVED_ARGS" >&2
  exit 1
fi

log() { printf '\033[1;34m[init]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
has_tty() { [[ -t 0 ]] || ( : </dev/tty ) >/dev/null 2>&1; }

# 交互读取：优先 /dev/tty，打不开时回退 stdin（接力场景 root 传入 tty）
ask() { # $1=提示 $2=变量名
  local __a=""
  if ! read -rp "$1" __a </dev/tty 2>/dev/null; then
    read -rp "$1" __a || __a=""
  fi
  printf -v "$2" '%s' "$__a"
}

# ── 环境校验（预检/后检共用）──────────────────────────────────
CHECK_FAIL=0
chk_pass() { printf '  \033[1;32m[PASS]\033[0m %s\n' "$*"; }
chk_warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$*"; }
chk_fail() { printf '  \033[1;31m[FAIL]\033[0m %s\n' "$*"; CHECK_FAIL=$((CHECK_FAIL+1)); }

as_target_user() {
  if [[ "$(id -un)" == "$OWNER" ]]; then bash -lc "$1"
  elif [[ $EUID -eq 0 ]]; then su - "$OWNER" -c "$1"
  elif command -v sudo &>/dev/null && sudo -n -u "$OWNER" true 2>/dev/null; then
    sudo -n -u "$OWNER" bash -lc "$1"
  else return 127; fi
}

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
  if command -v curl &>/dev/null; then
    curl -sf --max-time 5 -o /dev/null "${LITELLM_ENDPOINT:-http://litellm.internal:4000}/v1/models" \
      && chk_pass "LiteLLM 代理可达" \
      || chk_warn "LiteLLM 代理暂不可达（${LITELLM_ENDPOINT:-http://litellm.internal:4000}）"
  fi
}

check_post() {
  log "环境后检（base: $BASE_HOME）"
  id "$OWNER" &>/dev/null && chk_pass "用户: $OWNER" || chk_fail "用户未创建: $OWNER"
  id agent &>/dev/null && chk_pass "用户: agent" || chk_warn "用户 agent 未创建"
  [[ -e "$BASE_HOME/control-center/.git" ]] \
    && chk_pass "control-center 已克隆" || chk_fail "control-center 未克隆"
  [[ -f "$BASE_HOME/control-center/scripts/setup-env.sh" ]] \
    && chk_pass "阶段二脚本就位" || chk_warn "scripts/setup-env.sh 缺失（旧版本仓库？请 pull）"
  grep -qF 'control-setup-done' "$BASE_HOME/.bashrc" 2>/dev/null \
    && chk_pass "首次登录钩子已植入" || chk_warn "bashrc 未植入阶段二钩子"
  [[ $CHECK_FAIL -gt 0 ]] && printf '\033[1;31m[check]\033[0m 后检发现 %d 项 FAIL\n' "$CHECK_FAIL" \
    || printf '\033[1;32m[check]\033[0m 后检通过（阶段二见 setup-env.sh）\n'
  return "$CHECK_FAIL"
}

# ── 交互式参数 ────────────────────────────────────────────────
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

# ── 用户与目录（16 章权限模型）────────────────────────────────
init_users_dirs() {
  local ogroup
  # 工作用户
  if ! id "$OWNER" &>/dev/null; then
    useradd -m -s /bin/bash "$OWNER"
    log "创建工作用户: $OWNER（home: /home/$OWNER）"
    if has_tty; then
      local ans invoker
      ask "为 $OWNER 设置登录密码？[y/N] " ans
      [[ "$ans" =~ ^[yY](es)?$ ]] && passwd "$OWNER"
      invoker="${SUDO_USER:-}"
      if [[ -n "$invoker" && -s "/home/$invoker/.ssh/authorized_keys" ]]; then
        ask "复制 $invoker 的 SSH 公钥到 $OWNER（免密登录）？[Y/n] " ans
        if [[ ! "$ans" =~ ^[nN](o)?$ ]]; then
          mkdir -p "$BASE_HOME/.ssh"
          cp "/home/$invoker/.ssh/authorized_keys" "$BASE_HOME/.ssh/authorized_keys"
          chown -R "$OWNER:$(id -gn "$OWNER")" "$BASE_HOME/.ssh"
          chmod 700 "$BASE_HOME/.ssh"; chmod 600 "$BASE_HOME/.ssh/authorized_keys"
          log "已复制 SSH 公钥 → $OWNER"
        fi
      fi
    else
      warn "$OWNER 无密码（直登锁定）：root 可 su - $OWNER 切换，或手动 passwd $OWNER"
    fi
  fi
  ogroup="$(id -gn "$OWNER")"

  # agent 执行账号（本机 + 执行节点通用）
  if ! id agent &>/dev/null; then
    useradd -M -d "$BASE_HOME/.agent" -s /usr/sbin/nologin agent
    log "创建用户 agent（非 root、无 sudo、无独立 home）"
  fi
  mkdir -p "$BASE_HOME/.agent"
  chown -R "agent:$ogroup" "$BASE_HOME/.agent"; chmod 770 "$BASE_HOME/.agent"
  usermod -aG "$ogroup" agent

  # 最小权限与 docker 免 sudo
  if id -nG "$OWNER" 2>/dev/null | grep -qw sudo; then
    gpasswd -d "$OWNER" sudo >/dev/null 2>&1 \
      && log "已移除 $OWNER 的 sudo 组成员（最小权限模型）" \
      || warn "移除 $OWNER sudo 组失败，请手动: gpasswd -d $OWNER sudo"
  fi
  if getent group docker &>/dev/null; then
    usermod -aG docker "$OWNER"
    log "用户 $OWNER 已加入 docker 组（免 sudo，重新登录生效）"
  fi

  # 目录结构（16.3：owner 控制面；wt 为 owner+agent 共享工作区根，setgid 继承组）
  # gitdir 集中 ~/.repos（bare）；业务项目常驻 ~/wt/projects/，任务 worktree ~/wt/<repo>/TASK-*
  mkdir -p "$BASE_HOME"/{.repos,wt/projects,data/mysql,data/milvus,logs,scripts,deploy/mysql/init}
  chmod 750 "$BASE_HOME/data" "$BASE_HOME/logs" "$BASE_HOME/.repos"
  chown -R "$OWNER:$ogroup" "$BASE_HOME"/{.repos,data,logs,scripts,deploy}
  chown -R "$OWNER:$ogroup" "$BASE_HOME/wt"; chmod 2770 "$BASE_HOME/wt"
  if [[ $EXECUTOR -eq 1 ]]; then
    mkdir -p "$BASE_HOME/executor"/{workspace,cache,logs}
    chown -R "agent:$ogroup" "$BASE_HOME/executor"; chmod 770 "$BASE_HOME/executor"
  fi
  log "目录属主: owner=$OWNER（repos/data/logs/scripts/deploy），agent（wt${EXECUTOR:+/executor}）"
}

# ── 克隆本工程 ────────────────────────────────────────────────
gitu() { as_target_user "export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new'; git $*"; }

resolve_remote_base() {
  [[ -n "${GIT_REMOTE_BASE:-}" ]] && return 0
  local proto="${GIT_PROTO:-}" host="${GIT_REMOTE_HOST:-github.com/obtstar}"
  if [[ -z "$proto" ]] && has_tty; then
    echo "control-center 远程协议：" >&2
    echo "  1) ssh   git@${host/\//:}" >&2
    echo "  2) http  https://$host" >&2
    echo "  回车跳过（不克隆，仅创建用户与目录）" >&2
    ask "选择 [1/2]: " proto
    [[ "$proto" == "1" ]] && proto=ssh
    [[ "$proto" == "2" ]] && proto=http
  fi
  case "$proto" in
    ssh)        GIT_REMOTE_BASE="git@${host/\//:}" ;;
    http|https) GIT_REMOTE_BASE="https://$host" ;;
  esac
}

clone_control_center() {
  local dest="$BASE_HOME/control-center"
  local gitdir="$BASE_HOME/.repos/control-center.git"
  if [[ -e "$dest/.git" ]]; then
    gitu "-C '$dest' pull --ff-only" >/dev/null 2>&1 \
      && log "已更新: control-center（git pull --ff-only）" \
      || warn "更新失败（非快进/网络受限），保留现状"
    return 0
  fi
  resolve_remote_base
  if [[ -z "${GIT_REMOTE_BASE:-}" ]]; then
    warn "未配置远程，跳过 control-center 克隆（可后续手动 git clone）"
    return 0
  fi
  local remote="$GIT_REMOTE_BASE/control-center.git"
  # gitdir 集中 ~/.repos：--separate-git-dir（工作区 .git 为指针文件）
  mkdir -p "$BASE_HOME/.repos"
  if gitu "clone --separate-git-dir '$gitdir' '$remote' '$dest'"; then
    log "克隆仓库: control-center（gitdir: ~/.repos/control-center.git）"
  else
    warn "克隆失败（无权限或网络受限？）: $remote"
    return 0
  fi
  chmod 750 "$dest"
  chown -R "$OWNER:$(id -gn "$OWNER")" "$dest" "$gitdir"
}

# ── 阶段二钩子（首次登录自动触发）─────────────────────────────
install_setup_hook() {
  local bashrc="$BASE_HOME/.bashrc"
  [[ -f "$bashrc" ]] || touch "$bashrc"
  grep -qF 'control.env' "$bashrc" 2>/dev/null || \
    echo '[[ -f ~/control.env ]] && source ~/control.env' >> "$bashrc"
  grep -qF 'control-setup-done' "$bashrc" 2>/dev/null || cat >> "$bashrc" <<'EOF'
# control-center 阶段二：首次登录自动执行一次（可手动重跑 scripts/setup-env.sh）
if [[ -f ~/control-center/scripts/setup-env.sh && ! -f ~/.control-setup-done ]]; then
  bash ~/control-center/scripts/setup-env.sh
fi
EOF
  chown "$OWNER:$(id -gn "$OWNER")" "$bashrc"
  log "bashrc 已植入：control.env 挂载 + 阶段二首次登录钩子"
}

# ── 系统级常用工具（与 git/curl 同级，包管理器自适应）─────────
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

# ── Docker（可选项，compose 测试环境载体）─────────────────────
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

# ── main ──────────────────────────────────────────────────────
if [[ $CHECK_ONLY -eq 1 ]]; then
  check_pre
  [[ -d "$BASE_HOME" ]] && check_post || true
  exit 0
fi

interactive_setup
check_pre
init_users_dirs
install_sys_packages
install_docker
clone_control_center
install_setup_hook
check_post || true

cat <<EOF

阶段一完成。阶段二（软件安装/仓库同步/pi/PieKBS）触发方式：
  1. 首次以 $OWNER 登录时自动执行（一次性，完成后标记 ~/.control-setup-done）
  2. 随时手动: su - $OWNER -c 'bash ~/control-center/scripts/setup-env.sh$SETUP_ARGS'
EOF

# 可选：立即接力阶段二（以工作用户身份执行，非交互/--executor 时跳过）
if [[ -x "$BASE_HOME/control-center/scripts/setup-env.sh" ]] && has_tty; then
  ans=""
  ask "立即执行阶段二（以 $OWNER 身份）？[y/N] " ans
  if [[ "$ans" =~ ^[yY](es)?$ ]]; then
    log "接力阶段二: su - $OWNER -c setup-env.sh$SETUP_ARGS"
    # root 把 tty 作为 stdin 传给阶段二（dev 无权打开 /dev/tty 的系统上
    # 阶段二提示经 ask() 回退读 stdin）；无 ctty 时直接传原 stdin
    if ( : </dev/tty ) 2>/dev/null; then
      exec su - "$OWNER" -c "bash '$BASE_HOME/control-center/scripts/setup-env.sh'$SETUP_ARGS" < /dev/tty
    else
      exec su - "$OWNER" -c "bash '$BASE_HOME/control-center/scripts/setup-env.sh'$SETUP_ARGS"
    fi
  fi
fi

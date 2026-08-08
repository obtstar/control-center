#!/usr/bin/env bash
# common.sh — 由 setup-env.sh source（依赖 common.sh）

interactive_setup() {
  [[ "${SETUP_YES:-0}" == "1" ]] && return 0   # --yes：全部默认
  has_tty || return 0
  local ans
  if [[ $OWNER_SET -eq 0 ]]; then
    while true; do
      ask "工作用户名（新建/使用的 Linux 账号，回车默认 $OWNER）: " ans
      [[ -z "$ans" || "$ans" == "$OWNER" ]] && break
      # useradd 命名规则，防止误输入（如把 sudo 密码填进来）
      if [[ "$ans" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        ask "确认使用工作用户「$ans」？[y/N] " ans2
        if [[ "$ans2" =~ ^[yY](es)?$ ]]; then
          OWNER="$ans"
          BASE_HOME="/home/$OWNER"
          break
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

# 分步执行确认：--yes 全执行 > flag 跳过 > 非交互默认执行 > 交互询问（回车默认 Y）
step_enabled() { # $1=步骤名 $2=skip flag
  [[ "$2" == "1" ]] && { log "已跳过（--skip）: $1"; return 1; }
  [[ "${SETUP_YES:-0}" == "1" ]] && return 0
  has_tty || return 0
  local ans
  ask "执行步骤「$1」？[Y/n] " ans
  [[ ! "$ans" =~ ^[nN](o)?$ ]]
}

log() { printf '\033[1;34m[init]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

# 交互判定：stdin 是 tty 或可打开 /dev/tty（覆盖 curl|bash、ssh 无 -t 场景）
has_tty() { [[ -t 0 ]] || ( : </dev/tty ) >/dev/null 2>&1; }

# 已存在文件的覆盖确认：交互时询问，非交互/--yes 默认保留（返回 0=覆盖 1=保留）
confirm_overwrite() {
  [[ "${SETUP_YES:-0}" == "1" ]] && return 1
  has_tty || return 1
  local ans
  ask "$1 已存在，是否覆盖？[y/N] " ans
  [[ "$ans" =~ ^[yY](es)?$ ]]
}

# ── 0. 环境校验（初始化前预检 / 初始化后后检）──────────────────
confirm_opt() { # 非交互/--yes 默认跳过（安装升级类保持人工选择）
  [[ "${SETUP_YES:-0}" == "1" ]] && return 1
  has_tty || return 1
  local ans
  ask "$1 [y/N] " ans
  [[ "$ans" =~ ^[yY](es)?$ ]]
}

as_target_user() { # 以工作用户身份执行：root→su；本人→直接执行；否则尝试免密 sudo -u
  if [[ "$(id -un)" == "$OWNER" ]]; then
    bash -lc "$1"
  elif [[ $EUID -eq 0 ]]; then
    su - "$OWNER" -c "$1"
  elif command -v sudo &>/dev/null && sudo -n -u "$OWNER" true 2>/dev/null; then
    sudo -n -u "$OWNER" bash -lc "$1"
  else
    return 127
  fi
}

# 用户级工具链环境前缀（uv/nvm/cargo/~/.local/bin），探测与执行统一加载
USER_ENV='export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"; source "$HOME/.nvm/nvm.sh" 2>/dev/null;'

# root 时把路径归属工作用户（幂等，非 root 为 no-op）
own() {
  [[ $EUID -eq 0 ]] && chown -R "$OWNER:$(id -gn "$OWNER")" "$@"
  return 0
}

# 以工作用户身份执行 git（使用其 ~/.ssh 密钥，自动接受新 host key）
gitu() { # $*=git 子命令及参数（单个字符串）
  as_target_user "export GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new'; git $*"
}
# ── 0. 环境校验（初始化前预检 / 初始化后后检）──────────────────
CHECK_FAIL=0
chk_pass() { printf '  \033[1;32m[PASS]\033[0m %s\n' "$*"; }
chk_warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$*"; }
chk_fail() { printf '  \033[1;31m[FAIL]\033[0m %s\n' "$*"; CHECK_FAIL=$((CHECK_FAIL+1)); }

# 模板渲染：envsubst 优先，sed 兜底；$3=目标权限（可选）
# 模板目录默认 scripts/templates（TMPL_DIR 可覆盖）
render_tmpl() { # $1=模板名（相对 TMPL_DIR）$2=目标路径 $3=权限（可选）
  local tmpl="${TMPL_DIR:-$SCRIPT_DIR/templates}/$1" dest="$2" mode="${3:-}"
  [[ -f "$tmpl" ]] || { warn "模板不存在: $tmpl"; return 1; }
  local varlist='$BASE_HOME $OWNER $LITELLM_ENDPOINT $CONTROL_API $PIP_INDEX_URL $UV_INDEX_URL $NPM_REGISTRY'
  if command -v envsubst &>/dev/null; then
    BASE_HOME="$BASE_HOME" OWNER="$OWNER" \
    LITELLM_ENDPOINT="$LITELLM_ENDPOINT" CONTROL_API="${CONTROL_API:-}" \
    PIP_INDEX_URL="$PIP_INDEX_URL" UV_INDEX_URL="$UV_INDEX_URL" \
    NPM_REGISTRY="$NPM_REGISTRY" \
      envsubst "$varlist" < "$tmpl" > "$dest"
  else
    sed -e "s|\$BASE_HOME|$BASE_HOME|g" \
        -e "s|\$OWNER|$OWNER|g" \
        -e "s|\$LITELLM_ENDPOINT|$LITELLM_ENDPOINT|g" \
        -e "s|\$CONTROL_API|${CONTROL_API:-}|g" \
        -e "s|\$PIP_INDEX_URL|$PIP_INDEX_URL|g" \
        -e "s|\$UV_INDEX_URL|$UV_INDEX_URL|g" \
        -e "s|\$NPM_REGISTRY|$NPM_REGISTRY|g" \
        "$tmpl" > "$dest"
  fi
  [[ -n "$mode" ]] && chmod "$mode" "$dest"
  return 0
}

# 交互读取：优先 /dev/tty（curl|bash 场景），打不开时回退 stdin
# （接力场景 root 以 </dev/tty 传入 tty；部分发行版 dev 无权打开 /dev/tty）
ask() { # $1=提示 $2=变量名
  local __a=""
  if ! ask "$1" __a 2>/dev/null; then
    read -rp "$1" __a || __a=""
  fi
  printf -v "$2" '%s' "$__a"
}

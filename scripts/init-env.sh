#!/usr/bin/env bash
# init-env.sh — 企业内网 Agent 平台环境一键初始化（模拟综合测试环境）
# 依据：docs/architecture/13-repo-template.md（目录布局）
#       docs/architecture/16-linux-permissions.md（用户/权限，单人模型）
#       docs/architecture/10-deployment.md（docker-compose 测试环境）
set -euo pipefail

OWNER="${OWNER_USER:-dev}"   # 工作用户（默认 dev，--owner 自定义）
BASE_HOME="/home/$OWNER"     # 基目录恒为工作用户 home，与执行者无关
SAVED_ARGS="$*"
OWNER_SET=0
EXECUTOR_SET=0
SKIP_USERS=0
SKIP_COMPOSE=0
SKIP_REPOS=0

usage() {
  cat <<EOF
用法: $0 [选项]
  --owner NAME      工作用户（默认: dev；root 运行且不存在时自动创建，
                    其 home 即环境基目录）
  --executor        执行节点模式：仅初始化本机为 executor（办公 PC 的 WSL），
                    连接编排节点取代码、本地执行、结果回传（见 10 章 executor 代理）
  --control-api URL 编排节点 control-api 地址（executor 模式使用，
                    不传则交互式询问，如 http://192.168.1.10:8080）
  --skip-users      跳过 Linux 用户配置
  --skip-repos      跳过仓库克隆/骨架初始化
  --skip-compose    跳过 docker-compose 生成与启动
  --skip-tooling    跳过语言/框架与 pi/openskills 安装
  --check           仅做环境校验（预检 + 后检），不执行初始化
  -h, --help        显示帮助
环境变量:
  NPM_REGISTRY      npm 镜像（默认 https://registry.npmmirror.com，pi/openskills/corepack 用）
  PIP_INDEX_URL     pip 镜像（默认清华镜像）
  UV_INDEX_URL      uv 镜像（默认清华镜像）
  GH_PROXY          GitHub 加速代理前缀（如 https://gh.dpik.top），nvm/uv 安装器下载用
  NVM_NODEJS_ORG_MIRROR  nvm 下载 Node 的镜像（默认 https://npmmirror.com/mirrors/node）
  LITELLM_ENDPOINT  LiteLLM 代理地址（默认 http://litellm.internal:4000）
  GIT_REMOTE_BASE   仓库远程地址前缀（如 git@github.com:obtstar）：
                    远程已有内容时克隆；远程为空时本地建骨架并推送 main/dev
  GIT_PROTO         远程协议 ssh|http（与 GIT_REMOTE_HOST 组合，交互时可选 1/2）
  GIT_REMOTE_HOST   远程主机/组织（默认 github.com/obtstar）
EOF
}

EXECUTOR=0
CONTROL_API=""
SKIP_TOOLING=0
CHECK_ONLY=0
LITELLM_ENDPOINT="${LITELLM_ENDPOINT:-http://litellm.internal:4000}"
# pip 镜像：优先内网镜像（PIP_INDEX_URL），未设置时默认清华镜像
export PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
# uv 镜像（uv venv/pip 使用）
export UV_INDEX_URL="${UV_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
# GitHub 加速代理前缀（如 https://gh.dpik.top），作用于 nvm/uv 安装器下载
GH_PROXY="${GH_PROXY:-}"
# npm 镜像：优先内网镜像（NPM_REGISTRY），未设置时默认 npmmirror（pi/openskills/corepack 用）
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; OWNER_SET=1; shift 2 ;;
    --executor) EXECUTOR=1; EXECUTOR_SET=1; shift ;;
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

# 初始化需 root（创建工作用户/agent、设置目录属主）；非 root 仅允许 --check 校验
if [[ $CHECK_ONLY -eq 0 && $EUID -ne 0 ]]; then
  echo "初始化需要 root 权限（创建用户、目录属主配置），非 root 仅支持 --check 环境校验。" >&2
  echo "请使用: sudo -E bash $0 $SAVED_ARGS" >&2
  exit 1
fi

# ── 交互式参数（tty 且未显式指定时询问；非交互用 flag/env 直给）─
interactive_setup() {
  has_tty || return 0
  local ans
  if [[ $OWNER_SET -eq 0 ]]; then
    read -rp "工作用户 [$OWNER]: " ans </dev/tty
    if [[ -n "$ans" && "$ans" != "$OWNER" ]]; then
      OWNER="$ans"
      BASE_HOME="/home/$OWNER"
    fi
  fi
  if [[ $EXECUTOR_SET -eq 0 ]]; then
    read -rp "节点模式：1) 编排节点  2) 执行节点 [1]: " ans </dev/tty
    [[ "$ans" == "2" ]] && EXECUTOR=1
  fi
  return 0
}

# 分步执行确认：flag 跳过 > 非交互默认执行 > 交互询问（回车默认 Y）
step_enabled() { # $1=步骤名 $2=skip flag
  [[ "$2" == "1" ]] && { log "已跳过（--skip）: $1"; return 1; }
  has_tty || return 0
  local ans
  read -rp "执行步骤「$1」？[Y/n] " ans </dev/tty
  [[ ! "$ans" =~ ^[nN](o)?$ ]]
}

log() { printf '\033[1;34m[init]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

# 交互判定：stdin 是 tty 或可打开 /dev/tty（覆盖 curl|bash、ssh 无 -t 场景）
has_tty() { [[ -t 0 ]] || ( : </dev/tty ) >/dev/null 2>&1; }

# 已存在文件的覆盖确认：交互时询问，非交互默认保留（返回 0=覆盖 1=保留）
confirm_overwrite() {
  has_tty || return 1
  local ans
  read -rp "$1 已存在，是否覆盖？[y/N] " ans </dev/tty
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

  # 命令检测切换到工作用户（dev）上下文；未创建或无法切换则跳过
  if [[ $EXECUTOR -eq 0 ]] && ! id "$OWNER" &>/dev/null; then
    chk_warn "工作用户 $OWNER 未创建，跳过用户环境检测（初始化时将自动创建）"
  elif ! as_target_user 'true' &>/dev/null; then
    chk_warn "无法切换到 $OWNER 用户上下文（需 root 或免密 sudo），跳过用户环境检测"
  else
  local c p
  # 用户级工具链环境（nvm / uv / ~/.local/bin），校验前先加载
  local user_env='source "$HOME/.nvm/nvm.sh" 2>/dev/null; export PATH="$HOME/.local/bin:$PATH";'
  # 系统级必需命令
  for c in git curl; do
    as_target_user "command -v $c" >/dev/null 2>&1 && chk_pass "命令: $c" || chk_fail "缺少命令: $c"
  done
  # 用户级优先命令：node/npm/pnpm（nvm+corepack）、java/mvn（清华镜像直装 ~/.local）、go（golang.google.cn）
  for c in node npm pnpm java mvn go; do
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
  # 尚未初始化：整体提示，不逐项 FAIL
  if [[ $EXECUTOR -eq 0 && ! -e "$BASE_HOME/control.env" && ! -d "$BASE_HOME/control-center" ]]; then
    chk_warn "环境尚未初始化（属预期，执行 sudo bash scripts/init-env.sh 后复检）"
    return 0
  fi
  if [[ $EXECUTOR -eq 1 && ! -d "$BASE_HOME/executor" ]]; then
    chk_warn "executor 尚未初始化（属预期，执行 --executor 初始化后复检）"
    return 0
  fi
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
    # 最小权限：工作用户不在 sudo 组
    id -nG "$OWNER" 2>/dev/null | grep -qw sudo \
      && chk_warn "工作用户 $OWNER 在 sudo 组（建议移除: gpasswd -d $OWNER sudo）" \
      || chk_pass "工作用户 $OWNER 无 sudo 权限"
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
  # control-center 不再创建空骨架：由 init_repos 直接克隆本仓库
  mkdir -p \
    "$BASE_HOME/repos" \
    "$BASE_HOME/wt" \
    "$BASE_HOME/data/mysql" \
    "$BASE_HOME/data/milvus" \
    "$BASE_HOME/logs" \
    "$BASE_HOME/scripts" \
    "$BASE_HOME/deploy/mysql/init"

  chmod 750 "$BASE_HOME/data" "$BASE_HOME/logs"
  chmod 770 "$BASE_HOME/repos" "$BASE_HOME/wt"
}

# ── 2. Linux 用户（16.2 / 16.3，单人模型：owner + agent）──────
init_users() {
  if [[ $EUID -ne 0 ]]; then
    warn "非 root，跳过用户配置（可用 sudo 重试，或 --skip-users）"
    return 0
  fi

  # 单人模型：owner = 工作用户（默认 dev，--owner 自定义，root 时自动创建）
  # Agent 统一一个 agent 账号（本机 + 执行节点通用）
  # 代码/Worktree 全部在 owner home 下；agent 仅保留极简配置目录 $BASE_HOME/.agent
  local ogroup
  ogroup="$(id -gn "$OWNER")"

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

  # 工作用户不授予 sudo（最小权限；新建用户默认不在 sudo 组，复用已有用户时收紧）
  if id -nG "$OWNER" 2>/dev/null | grep -qw sudo; then
    gpasswd -d "$OWNER" sudo >/dev/null 2>&1 \
      && log "已移除 $OWNER 的 sudo 组成员（最小权限模型）" \
      || warn "移除 $OWNER sudo 组失败，请手动检查: gpasswd -d $OWNER sudo"
  fi

  # docker 免 sudo：工作用户加入 docker 组（组存在时，重新登录生效）
  if getent group docker &>/dev/null; then
    usermod -aG docker "$OWNER"
    log "用户 $OWNER 已加入 docker 组（免 sudo 执行，重新登录后生效）"
  fi

  # 目录属主（16.3）：owner 拥有控制面，agent 独占 ~/wt
  chown -R "$OWNER:$ogroup" "$BASE_HOME/control-center" "$BASE_HOME/repos" \
    "$BASE_HOME/data" "$BASE_HOME/logs" 2>/dev/null || true
  chown -R "agent:$ogroup" "$BASE_HOME/wt"
  chmod 770 "$BASE_HOME/wt"
  log "目录属主: owner=$OWNER（control-center/repos/data/logs），agent（wt，配置目录 .agent）"
  # 16.5：agent 用户不在 sudoers 中，无需写 sudoers 规则
}

# ── 2.5 可选语言/框架（用户级安装，交互确认，回车默认 N 跳过）─
# 全部落在工作用户 home：Java/Maven→清华镜像直装 ~/.local，Node→nvm，pnpm→corepack；
# root 运行时 su 到工作用户执行，不污染 /root 与系统目录
confirm_opt() { # 非交互默认跳过
  has_tty || return 1
  local ans
  read -rp "$1 [y/N] " ans </dev/tty
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

# 用户级工具链环境前缀（uv/nvm/~/.local/bin），探测与执行统一加载
USER_ENV='export PATH="$HOME/.local/bin:$PATH"; source "$HOME/.nvm/nvm.sh" 2>/dev/null;'

try_install() { # $1=名称 $2=检测命令 $3=安装命令 $4=升级命令（可选）
  local name="$1" check="$2" cmd="$3" upcmd="${4:-}"
  if [[ -n "$check" ]] && as_target_user "export PATH=\"\$HOME/.local/bin:\$PATH\"; command -v $check" &>/dev/null; then
    if [[ -n "$upcmd" ]] && confirm_opt "$name 已安装，是否升级？"; then
      log "升级 $name ..."
      as_target_user "$upcmd" && log "$name 升级完成" || warn "$name 升级失败（保留现有版本）"
    else
      log "$name 已安装，跳过"
    fi
    return 0
  fi
  if confirm_opt "安装 $name？"; then
    log "安装 $name（用户级）..."
    as_target_user "$cmd" && log "$name 安装完成" \
      || warn "$name 安装失败（可稍后以工作用户身份手动安装）"
  else
    log "跳过: $name"
  fi
}

init_toolchain() {
  [[ $SKIP_TOOLING -eq 1 ]] && { log "--skip-tooling，跳过语言/框架安装"; return 0; }
  log "可选语言/框架安装（用户级，回车默认跳过，非交互模式全部跳过）"

  # 下载命令按 GH_PROXY / npmmirror 构造
  local nvm_url="${GH_PROXY:+$GH_PROXY/}https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"
  local node_mirror='export NVM_NODEJS_ORG_MIRROR="${NVM_NODEJS_ORG_MIRROR:-https://npmmirror.com/mirrors/node}";'
  local uv_cmd='curl -fsSL https://astral.sh/uv/install.sh | sh'
  [[ -n "$GH_PROXY" ]] && uv_cmd="curl -fsSL https://astral.sh/uv/install.sh \
    | env UV_INSTALLER_GITHUB_BASE_URL='$GH_PROXY/https://github.com/astral-sh/uv/releases' sh"

  # Java + Maven：清华镜像直装脚本（SDKMAN 无国内镜像，弃用）
  local jm_script="$BASE_HOME/scripts/install-java-maven.sh"
  mkdir -p "$BASE_HOME/scripts"
  cat > "$jm_script" <<'EOF'
#!/usr/bin/env bash
# Temurin JDK 17 + Maven 清华镜像直装（用户级，落 ~/.local）
set -e
base=https://mirrors.tuna.tsinghua.edu.cn
dest="$HOME/.local/lib"
mkdir -p "$dest" "$HOME/.local/bin"

jdk_file=$(curl -fsSL "$base/Adoptium/17/jdk/x64/linux/" \
  | grep -oP 'OpenJDK17U-jdk_x64_linux_hotspot_[^"]+\.tar\.gz' \
  | grep -v sha256 | sort -V | tail -1)
[[ -n "$jdk_file" ]] || { echo "未找到 JDK 包" >&2; exit 1; }
echo "下载 $jdk_file"
curl -fsSL "$base/Adoptium/17/jdk/x64/linux/$jdk_file" -o /tmp/jdk17.tgz
tar -xzf /tmp/jdk17.tgz -C "$dest" && rm -f /tmp/jdk17.tgz
jdk_dir=$(find "$dest" -maxdepth 1 -name 'jdk-17*' -type d | sort -V | tail -1)
ln -sfn "$jdk_dir" "$dest/jdk17"
ln -sfn "$dest/jdk17/bin/java" "$HOME/.local/bin/java"
ln -sfn "$dest/jdk17/bin/javac" "$HOME/.local/bin/javac"

mvn_ver=$(curl -fsSL "$base/apache/maven/maven-3/" \
  | grep -oP '(?<=href=")3\.[0-9.]+(?=/)' | sort -V | tail -1)
[[ -n "$mvn_ver" ]] || { echo "未找到 Maven 版本" >&2; exit 1; }
echo "下载 apache-maven-$mvn_ver"
curl -fsSL "$base/apache/maven/maven-3/$mvn_ver/binaries/apache-maven-$mvn_ver-bin.tar.gz" -o /tmp/maven.tgz
tar -xzf /tmp/maven.tgz -C "$dest" && rm -f /tmp/maven.tgz
ln -sfn "$dest/apache-maven-$mvn_ver" "$dest/maven"
ln -sfn "$dest/maven/bin/mvn" "$HOME/.local/bin/mvn"

grep -q JAVA_HOME "$HOME/.bashrc" 2>/dev/null \
  || echo 'export JAVA_HOME="$HOME/.local/lib/jdk17"' >> "$HOME/.bashrc"
echo "完成: JAVA_HOME=$dest/jdk17, maven=$dest/maven"
EOF
  chmod +x "$jm_script"
  [[ $EUID -eq 0 ]] && chown "$OWNER:$(id -gn "$OWNER")" "$jm_script"

  try_install "Java + Maven（清华镜像 Temurin 17 + Maven）" java \
    "bash '$jm_script'" "bash '$jm_script'"
  try_install "Node.js LTS（nvm）" node \
    "$node_mirror curl -fsSL $nvm_url | bash \
      && source \"\$HOME/.nvm/nvm.sh\" && nvm install --lts" \
    "$node_mirror source \"\$HOME/.nvm/nvm.sh\" && nvm install --lts"
  try_install "uv（Python 版本/包管理）" uv "$uv_cmd" "$uv_cmd"
  try_install "Go（golang.google.cn，piekbs 源码构建用）" go \
    'set -e
     ver=$(curl -fsSL "https://golang.google.cn/dl/?mode=json" | grep -oP "\"version\":\s*\"\Kgo[0-9.]+" | head -1)
     [[ -n "$ver" ]] || { echo "未获取到 Go 版本" >&2; exit 1; }
     arch=$(uname -m); [[ "$arch" == "aarch64" ]] && arch=arm64 || arch=amd64
     echo "下载 $ver ($arch)"
     mkdir -p "$HOME/.local/lib" "$HOME/.local/bin"
     curl -fsSL "https://golang.google.cn/dl/$ver.linux-$arch.tar.gz" -o /tmp/go.tgz
     rm -rf "$HOME/.local/lib/go" && tar -xzf /tmp/go.tgz -C "$HOME/.local/lib" && rm -f /tmp/go.tgz
     ln -sfn "$HOME/.local/lib/go/bin/go" "$HOME/.local/bin/go"
     ln -sfn "$HOME/.local/lib/go/bin/gofmt" "$HOME/.local/bin/gofmt"' \
    'set -e
     ver=$(curl -fsSL "https://golang.google.cn/dl/?mode=json" | grep -oP "\"version\":\s*\"\Kgo[0-9.]+" | head -1)
     [[ -n "$ver" ]] || exit 1
     arch=$(uname -m); [[ "$arch" == "aarch64" ]] && arch=arm64 || arch=amd64
     curl -fsSL "https://golang.google.cn/dl/$ver.linux-$arch.tar.gz" -o /tmp/go.tgz
     rm -rf "$HOME/.local/lib/go" && tar -xzf /tmp/go.tgz -C "$HOME/.local/lib" && rm -f /tmp/go.tgz'
  try_install "pnpm（corepack，多 worktree 共享 store）" pnpm \
    'export COREPACK_NPM_REGISTRY="${COREPACK_NPM_REGISTRY:-https://registry.npmmirror.com}"; \
      source "$HOME/.nvm/nvm.sh" 2>/dev/null \
      && corepack enable && corepack prepare pnpm@latest --activate' \
    'export COREPACK_NPM_REGISTRY="${COREPACK_NPM_REGISTRY:-https://registry.npmmirror.com}"; \
      source "$HOME/.nvm/nvm.sh" 2>/dev/null && corepack prepare pnpm@latest --activate'
  if as_target_user 'command -v docker' &>/dev/null; then
    try_install "Docker rootless 模式（用户级守护进程）" "" \
      'dockerd-rootless-setuptool.sh install'
  else
    log "Docker 未安装：需系统级安装（apt install docker.io），跳过"
  fi
}

# ── 2.6 国内镜像加速（交互选择，默认 Y）──────────────────────
init_mirrors() {
  has_tty || { log "非交互模式，跳过国内镜像配置"; return 0; }
  local ans
  read -rp "配置国内镜像加速（npm→npmmirror、pip/uv→清华）？[Y/n] " ans </dev/tty
  [[ "$ans" =~ ^[nN](o)?$ ]] && { log "跳过国内镜像配置"; return 0; }

  read -rp "GitHub 加速代理前缀（如 https://gh.dpik.top，留空直连）: " ans </dev/tty
  [[ -n "$ans" ]] && { GH_PROXY="$ans"; log "GitHub 代理: $GH_PROXY（作用于后续 nvm/uv 安装器下载）"; }

  # npm：npmmirror（用户级，需已装 npm）
  if as_target_user 'command -v npm' &>/dev/null; then
    as_target_user 'npm config set registry https://registry.npmmirror.com' \
      && log "npm 镜像: https://registry.npmmirror.com（用户级 npm config）"
  else
    warn "npm 未安装，跳过 npm 镜像（安装 Node 后可手动执行: npm config set registry https://registry.npmmirror.com）"
  fi

  # pip：清华镜像（写工作用户的 pip.conf）
  local pip_conf="$BASE_HOME/.config/pip"
  mkdir -p "$pip_conf"
  cat > "$pip_conf/pip.conf" <<'EOF'
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 30
EOF
  [[ $EUID -eq 0 ]] && chown -R "$OWNER:$(id -gn "$OWNER")" "$pip_conf"
  log "pip 镜像: https://pypi.tuna.tsinghua.edu.cn/simple（$pip_conf/pip.conf）"

  # uv：清华镜像（uv.toml）
  local uv_conf="$BASE_HOME/.config/uv"
  mkdir -p "$uv_conf"
  cat > "$uv_conf/uv.toml" <<'EOF'
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
EOF
  [[ $EUID -eq 0 ]] && chown -R "$OWNER:$(id -gn "$OWNER")" "$uv_conf"
  log "uv 镜像: https://pypi.tuna.tsinghua.edu.cn/simple（$uv_conf/uv.toml）"
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
  # root(sudo) 运行时归属工作用户，否则 600 权限下 owner 无法 source
  [[ $EUID -eq 0 ]] && chown "$OWNER:$(id -gn "$OWNER")" "$env_file"
  fi

  # bashrc 幂等挂载
  local bashrc="$BASE_HOME/.bashrc"
  if [[ -w "$BASE_HOME" ]]; then
    grep -qF "control.env" "$bashrc" 2>/dev/null || \
      echo '[[ -f ~/control.env ]] && source ~/control.env' >> "$bashrc"
  fi
}

# ── 4. Python 虚拟环境（uv 管理）──────────────────────────────
init_venv() { # $1=目标 home $2=属主（可选，root 时 chown）
  local home="$1" user="${2:-}"
  if [[ -d "$home/.venv" ]]; then
    log "虚拟环境已存在，跳过: $home/.venv"
  elif as_target_user 'export PATH="$HOME/.local/bin:$PATH"; command -v uv' &>/dev/null; then
    log "创建 Python 虚拟环境（uv）: $home/.venv"
    if as_target_user "export PATH=\"\$HOME/.local/bin:\$PATH\"; uv venv --seed '$home/.venv'"; then
      if [[ -f "$home/control-center/requirements.txt" ]]; then
        as_target_user "export PATH=\"\$HOME/.local/bin:\$PATH\"; uv pip install --python '$home/.venv/bin/python' -q -r '$home/control-center/requirements.txt'" \
          && log "已安装 control-center/requirements.txt"
      fi
    else
      warn "uv venv 失败（网络受限？），跳过"
    fi
  else
    warn "uv 未安装，跳过 .venv 创建（工具链步骤选择安装 uv，或: curl -fsSL https://astral.sh/uv/install.sh | sh）"
  fi
  if [[ -d "$home/.venv" && -n "$user" ]] && id "$user" &>/dev/null \
     && { [[ $EUID -eq 0 ]] || [[ "$user" == "$(id -un)" ]]; }; then
    chown -R "$user:$user" "$home/.venv"
  fi
}

# ── 5. pi / openskills 安装与配置 ─────────────────────────────
install_agent_tooling() { # $1=目标 home $2=目标用户（可选，root 时 chown）
  local home="$1" user="${2:-}"

  # 5.1 pi（Earendil Pi Coding Agent，以工作用户身份装入其用户级 npm）
  if as_target_user "$USER_ENV command -v pi" &>/dev/null; then
    if confirm_opt "pi 已安装，是否升级？"; then
      as_target_user "$USER_ENV npm update -g --ignore-scripts @earendil-works/pi-coding-agent --registry='$NPM_REGISTRY'" \
        && log "pi 升级完成" || warn "pi 升级失败（保留现有版本）"
    else
      log "pi 已安装，跳过"
    fi
  elif as_target_user "$USER_ENV command -v npm" &>/dev/null; then
    as_target_user "$USER_ENV npm install -g --ignore-scripts @earendil-works/pi-coding-agent --registry='$NPM_REGISTRY'" \
      && log "pi 安装完成" || warn "pi 安装失败（网络受限？可 vendor 后重试）"
  else
    warn "npm 未安装，跳过 pi（先在工具链步骤安装 Node.js）"
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

  # 5.2b pi 基本设置：访问范围限定工作用户 home，敏感路径保护（16 章纵深防御）
  local settings="$home/.pi/settings.json"
  if [[ ! -f "$settings" ]]; then
    cat > "$settings" <<EOF
{
  "allow_paths": ["$BASE_HOME"],
  "protected_paths": [
    "/etc", "/root", "/boot",
    "$BASE_HOME/.ssh",
    "$BASE_HOME/.config",
    "$BASE_HOME/control.env",
    "$BASE_HOME/deploy/.env"
  ],
  "locale": "en"
}
EOF
    chmod 600 "$settings"
    log "已生成 $settings（访问范围限定 $BASE_HOME，敏感路径保护）"
  fi

  # 5.3 openskills（07.3：SKILL.md 技能管理，同 pi 走工作用户用户级 npm）
  if as_target_user "$USER_ENV command -v openskills" &>/dev/null; then
    if confirm_opt "openskills 已安装，是否升级？"; then
      as_target_user "$USER_ENV npm update -g --ignore-scripts openskills --registry='$NPM_REGISTRY'" \
        && log "openskills 升级完成" || warn "openskills 升级失败（保留现有版本）"
    else
      log "openskills 已安装，跳过"
    fi
  elif as_target_user "$USER_ENV command -v npm" &>/dev/null; then
    as_target_user "$USER_ENV npm install -g --ignore-scripts openskills --registry='$NPM_REGISTRY'" \
      && log "openskills 安装完成" || warn "openskills 安装失败，可后续手动安装"
  fi

  # 5.4 技能目录软链：~/.pi/skills → 控制中心 orchestration/skills（Git 版本化）
  if [[ -d "$BASE_HOME/control-center/orchestration/skills" ]]; then
    ln -sfn "$BASE_HOME/control-center/orchestration/skills" "$home/.pi/skills"
    log "技能目录已链接: $home/.pi/skills → control-center/orchestration/skills"
  fi

  # 5.5 pi-di18n（中文界面，可选；仅人工通道询问一次）
  if [[ "$home" == "$BASE_HOME" ]] \
     && as_target_user "$USER_ENV command -v pi" &>/dev/null \
     && confirm_opt "添加 pi-di18n 并切换中文界面？"; then
    if as_target_user "$USER_ENV NPM_REGISTRY='$NPM_REGISTRY' pi install pi-di18n"; then
      sed -i 's/"locale": "[^"]*"/"locale": "zh-CN"/' "$settings" 2>/dev/null || true
      log "pi-di18n 已安装，locale=zh-CN"
    else
      warn "pi-di18n 安装失败（可稍后手动: pi install pi-di18n）"
    fi
  fi

  # root 模式下把配置归属目标用户
  if [[ -n "$user" ]] && id "$user" &>/dev/null; then
    chown -R "$user:$user" "$home/.pi" "$home/.venv" 2>/dev/null || true
  fi
}
# ── 6. 代码仓库骨架（13.2）────────────────────────────────────
# 远程克隆公共逻辑：远程有内容则克隆（空目录自动覆盖，含文件需确认）
clone_remote() { # $1=repo 名 $2=目标目录；0=已克隆 1=未克隆（调用方走回退）
  local name="$1" dest="$2" remote="" refs="" rc=0
  [[ -n "${GIT_REMOTE_BASE:-}" ]] && remote="$GIT_REMOTE_BASE/$name.git" || return 1
  refs="$(git ls-remote "$remote" 2>/dev/null)" || rc=$?
  if [[ $rc -ne 0 ]]; then
    warn "远程不可达或无权限，跳过: $remote"
    return 1
  fi
  [[ -z "$refs" ]] && return 1   # 空远程（新建未推送）
  if [[ -n "$(find "$dest" -type f 2>/dev/null)" ]]; then
    confirm_overwrite "$dest 非空且非 Git 仓库，清空并克隆" \
      || { warn "保留现有目录，跳过克隆: $dest"; return 1; }
  fi
  rm -rf "$dest"
  if git clone "$remote" "$dest" >/dev/null 2>&1; then
    grep -q 'refs/heads/dev$' <<<"$refs" && git -C "$dest" checkout -q dev 2>/dev/null || true
    log "克隆仓库: $name（来自 $remote）"
    return 0
  fi
  warn "克隆失败（无权限或网络受限？）: $remote"
  return 1
}

init_repo_skeleton() { # $1=repo 名
  local repo="$BASE_HOME/repos/$1"
  if [[ -d "$repo/.git" ]]; then
    update_repo "$repo" "$1"
    return 0
  fi
  # 远程已有内容则克隆（新机器接入）；否则本地初始化骨架
  clone_remote "$1" "$repo" && return 0

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

# 远程地址解析：GIT_REMOTE_BASE 全量前缀优先；否则按协议选择构造
resolve_remote_base() {
  [[ -n "${GIT_REMOTE_BASE:-}" ]] && return 0
  local proto="${GIT_PROTO:-}" host="${GIT_REMOTE_HOST:-github.com/obtstar}"
  if [[ -z "$proto" ]] && has_tty; then
    echo "仓库远程协议（克隆/推送 control-center 与 control-api/control-web/control-db）：" >&2
    echo "  1) ssh   git@${host/\//:}" >&2
    echo "  2) http  https://$host" >&2
    echo "  回车跳过（仅本地骨架，不关联远程）" >&2
    read -rp "选择 [1/2]: " proto </dev/tty
    [[ "$proto" == "1" ]] && proto=ssh
    [[ "$proto" == "2" ]] && proto=http
  fi
  case "$proto" in
    ssh)        GIT_REMOTE_BASE="git@${host/\//:}" ;;   # scp 语法: git@github.com:obtstar
    http|https) GIT_REMOTE_BASE="https://$host"
                warn "http 协议克隆私有仓库需凭据（token/凭据助手），否则仅公开仓库可用" ;;
  esac
}

# 已存在仓库以 git pull 更新（以工作用户身份，--ff-only 防合并冲突）
update_repo() { # $1=路径 $2=名称
  if as_target_user "git -C '$1' pull --ff-only" >/dev/null 2>&1; then
    log "已更新: $2（git pull --ff-only）"
  else
    warn "更新失败（非快进/网络受限），保留现状: $2"
  fi
}

init_control_center() {
  command -v git >/dev/null || { warn "未安装 git，跳过 control-center 克隆"; return 0; }
  resolve_remote_base
  if [[ -d "$BASE_HOME/control-center/.git" ]]; then
    update_repo "$BASE_HOME/control-center" control-center
  else
    clone_remote control-center "$BASE_HOME/control-center" \
      || warn "control-center 未克隆（可后续手动: git clone <remote> $BASE_HOME/control-center）"
  fi
  if [[ -d "$BASE_HOME/control-center" ]]; then
    chmod 750 "$BASE_HOME/control-center"
    [[ $EUID -eq 0 ]] && chown -R "$OWNER:$(id -gn "$OWNER")" "$BASE_HOME/control-center"
  fi
}

init_repos() {
  command -v git >/dev/null || { warn "未安装 git，跳过仓库骨架"; return 0; }
  resolve_remote_base
  for r in control-api control-web control-db piekbs; do
    init_repo_skeleton "$r"
  done
  # root(sudo) 运行时把仓库归属工作用户（16.3 权限模型）
  if [[ $EUID -eq 0 ]]; then
    chown -R "$OWNER:$(id -gn "$OWNER")" "$BASE_HOME/repos" 2>/dev/null || true
  fi
}

# ── 6.5 PieKBS 知识库（Agent 知识搜索引擎，MCP）──────────────
init_piekbs() {
  log "PieKBS 知识库（kb_search/kb_page/kb_add，MCP 接口）"
  local gh="${GH_PROXY:+$GH_PROXY/}"

  # 1. 二进制：GitHub release（linux-amd64，经 GH_PROXY）
  if as_target_user "$USER_ENV command -v piekbs" &>/dev/null; then
    log "piekbs 已安装，跳过二进制安装"
  elif confirm_opt "安装 piekbs 二进制（GitHub release）？"; then
    local dl_cmd="set -e; "
    dl_cmd+="url=\$(curl -fsSL ${gh}https://api.github.com/repos/pieteams/piekbs/releases/latest | grep -o 'https://[^\"]*linux-amd64.tar.gz' | head -1); "
    dl_cmd+="[[ -n \"\$url\" ]] || { echo '未找到 release 下载地址' >&2; exit 1; }; "
    dl_cmd+="mkdir -p \"\$HOME/.local/bin\" && curl -fsSL ${gh}\$url | tar -xz -C \"\$HOME/.local/bin\" && chmod +x \"\$HOME/.local/bin/piekbs\""
    as_target_user "$dl_cmd" \
      && log "piekbs 二进制安装完成（~/.local/bin/piekbs）" \
      || warn "piekbs 下载失败（网络受限？可手动下载 release 放入 ~/.local/bin）"
  else
    log "跳过: piekbs 二进制"
  fi

  # 2. KB 初始化与配置（distill 走 LiteLLM 代理，FTS 无需 embedding）
  as_target_user "$USER_ENV command -v piekbs" &>/dev/null || return 0
  local kb="$BASE_HOME/piekbs-kb"
  if [[ ! -d "$kb/wiki" ]]; then
    as_target_user "$USER_ENV PIEKBS_KB='$kb' piekbs init" \
      && log "KB 已初始化: $kb（raw/ 投放原始文档，watcher 自动蒸馏+索引）" \
      || warn "piekbs init 失败"
  fi
  if [[ -d "$kb" && ! -f "$kb/config.yaml" ]]; then
    cat > "$kb/config.yaml" <<EOF
server:
  host: "127.0.0.1"
  port: 8766
  api_key: ""

distill:
  base_url: "$LITELLM_ENDPOINT/v1"
  token: ""
  model: "cheap"
  api_type: "openai"
  workers: 2

ui:
  language: "zh-CN"
EOF
    chmod 600 "$kb/config.yaml"
    [[ $EUID -eq 0 ]] && chown -R "$OWNER:$(id -gn "$OWNER")" "$kb"
    log "已生成 $kb/config.yaml（distill → LiteLLM cheap 模型，token 需填入）"
    log "启动: piekbs serve（127.0.0.1:8766；局域网经 ssh -L 8766:localhost:8766 访问）"
    log "pi 接入 MCP: http://127.0.0.1:8766/mcp"
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
    if has_tty; then
      read -rp "请输入服务端（编排节点）地址，如 http://192.168.1.10:8080: " CONTROL_API </dev/tty
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
  chmod 750 "$BASE_HOME/executor"

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
    install_agent_tooling "$BASE_HOME/.agent" agent
  fi
  init_venv "$BASE_HOME" agent
}

# ── 完成后：迁移到新用户（交互）───────────────────────────────
post_init_migrate() {
  has_tty || return 0
  local invoker="${SUDO_USER:-}"
  # 从其他账号 sudo 初始化时：其 home 下的 control-center 克隆可迁入工作用户
  if [[ -n "$invoker" && "$invoker" != "$OWNER" && "$invoker" != "root" ]]; then
    local src="/home/$invoker/control-center"
    if [[ -d "$src/.git" && ! -e "$BASE_HOME/control-center/.git" ]] \
       && confirm_opt "检测到 $invoker 的 control-center 克隆（$src），迁移到 $BASE_HOME？"; then
      if [[ -n "$(git -C "$src" status --porcelain 2>/dev/null)" ]]; then
        warn "源仓库有未提交更改，取消迁移（请先提交/推送）"
      else
        rm -rf "$BASE_HOME/control-center"   # init_dirs 生成的空骨架
        mv "$src" "$BASE_HOME/control-center"
        chown -R "$OWNER:$(id -gn "$OWNER")" "$BASE_HOME/control-center"
        log "已迁移: $src → $BASE_HOME/control-center"
      fi
    fi
  fi
  if [[ "$(id -un)" != "$OWNER" ]] && confirm_opt "初始化完成，切换到工作用户 $OWNER（su - $OWNER）？"; then
    if has_tty; then
      exec su - "$OWNER" </dev/tty
    else
      log "请手动执行: su - $OWNER"
    fi
  fi
}

# ── main ──────────────────────────────────────────────────────
if [[ $CHECK_ONLY -eq 1 ]]; then
  check_pre
  check_post || true
  exit 0
fi

interactive_setup

# root：确保工作用户存在（默认 dev，--owner 自定义，两种模式通用）；
# 基目录恒为 /home/$OWNER，与执行者无关
if [[ $EUID -eq 0 && $SKIP_USERS -eq 0 ]]; then
  if ! id "$OWNER" &>/dev/null; then
    useradd -m -s /bin/bash "$OWNER"
    log "创建工作用户: $OWNER（home: /home/$OWNER）"
    # 新用户默认无密码（直登锁定）：交互设置密码 / 迁移 SSH 公钥
    if has_tty; then
      ans=""
      read -rp "为 $OWNER 设置登录密码？[y/N] " ans </dev/tty
      [[ "$ans" =~ ^[yY](es)?$ ]] && passwd "$OWNER"
      invoker="${SUDO_USER:-}"
      if [[ -n "$invoker" && -s "/home/$invoker/.ssh/authorized_keys" ]]; then
        read -rp "复制 $invoker 的 SSH 公钥到 $OWNER（免密登录）？[Y/n] " ans </dev/tty
        if [[ ! "$ans" =~ ^[nN](o)?$ ]]; then
          mkdir -p "$BASE_HOME/.ssh"
          cp "/home/$invoker/.ssh/authorized_keys" "$BASE_HOME/.ssh/authorized_keys"
          chown -R "$OWNER:$(id -gn "$OWNER")" "$BASE_HOME/.ssh"
          chmod 700 "$BASE_HOME/.ssh"
          chmod 600 "$BASE_HOME/.ssh/authorized_keys"
          log "已复制 SSH 公钥 → $OWNER"
        fi
      fi
    else
      warn "$OWNER 无密码（直登锁定）：root 可 su - $OWNER 切换，或手动 passwd $OWNER"
    fi
  fi
fi

check_pre
if [[ $EXECUTOR -eq 1 ]]; then
  init_executor
  check_post || true
  log "完成（executor 模式）。请在 registry/executors.yaml 登记本机后启动 executor 服务"
else
  step_enabled "目录结构" 0 && init_dirs
  step_enabled "用户配置（agent/dev 权限模型）" "$SKIP_USERS" && init_users
  init_mirrors
  step_enabled "控制中心仓库（control-center 克隆）" "$SKIP_REPOS" && init_control_center
  step_enabled "代码仓库（control-api/web/db/piekbs 克隆/骨架）" "$SKIP_REPOS" && init_repos
  step_enabled "语言/框架工具链（JDK+Maven/nvm/uv/pnpm）" "$SKIP_TOOLING" && init_toolchain
  step_enabled "PieKBS 知识库（二进制 + KB 初始化）" "$SKIP_TOOLING" && init_piekbs
  init_env_config
  step_enabled "Python 虚拟环境（uv venv .venv）" "$SKIP_TOOLING" && init_venv "$BASE_HOME" "$OWNER"
  if step_enabled "pi / openskills（Agent 工具链）" "$SKIP_TOOLING"; then
    install_agent_tooling "$BASE_HOME" "$OWNER"          # 人工通道（VSCode/CLI）
    [[ $EUID -eq 0 ]] && install_agent_tooling "$BASE_HOME/.agent" agent  # Agent 通道
  fi
  step_enabled "compose 测试环境" "$SKIP_COMPOSE" && init_compose
  check_post || true
  log "完成。布局见 docs/architecture/13-repo-template.md，权限模型见 16-linux-permissions.md"
  post_init_migrate
fi

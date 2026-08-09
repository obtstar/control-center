#!/usr/bin/env bash
# toolchain.sh — 由 setup-env.sh source（依赖 common.sh）

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
  # uv：安装脚本直连 astral.sh（gh 代理不支持），仅 GitHub 二进制下载走代理；
  # pipefail 防止 curl 失败但管道返回 0 的假成功
  local uv_cmd='set -o pipefail; curl -fsSL https://astral.sh/uv/install.sh | sh'
  [[ -n "$GH_PROXY" ]] && uv_cmd="set -o pipefail; curl -fsSL https://astral.sh/uv/install.sh \
    | env UV_INSTALLER_GITHUB_BASE_URL='$GH_PROXY/https://github.com' sh"

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
  own "$jm_script"

  try_install "Java + Maven（清华镜像 Temurin 17 + Maven）" java \
    "bash '$jm_script'" "bash '$jm_script'"
  try_install "Node.js LTS（nvm）" node \
    "$node_mirror curl -fsSL $nvm_url | bash \
      && source \"\$HOME/.nvm/nvm.sh\" \
      && echo '下载 Node LTS（npmmirror，非 tty 下无进度条，请稍候）...' \
      && nvm install --lts" \
    "$node_mirror source \"\$HOME/.nvm/nvm.sh\" \
      && echo '下载 Node LTS（npmmirror，非 tty 下无进度条，请稍候）...' \
      && nvm install --lts"
  try_install "uv（Python 版本/包管理）" uv "$uv_cmd" "$uv_cmd"
  # Rust（rustup 用户级，rsproxy.cn 国内镜像）
  local rust_cmd='set -o pipefail
    export RUSTUP_DIST_SERVER="${RUSTUP_DIST_SERVER:-https://rsproxy.cn}"
    export RUSTUP_UPDATE_ROOT="${RUSTUP_UPDATE_ROOT:-https://rsproxy.cn/rustup}"
    curl -fsSL https://rsproxy.cn/rustup-init.sh | sh -s -- -y --default-toolchain stable --profile minimal'
  try_install "Rust（rustup，rsproxy 镜像）" cargo "$rust_cmd" "$rust_cmd"
  try_install "Go（golang.google.cn 用户级）" go \
    'set -e
     ver=$(curl -fsSL "https://golang.google.cn/dl/?mode=json" | grep -oP "\"version\":\s*\"\Kgo[0-9.]+" | head -1)
     [[ -n "$ver" ]] || { echo "未获取到 Go 版本" >&2; exit 1; }
     arch=$(uname -m); [[ "$arch" == "aarch64" ]] && arch=arm64 || arch=amd64
     echo "下载 $ver ($arch)"
     mkdir -p "$HOME/.local/lib" "$HOME/.local/bin"
     curl -fsSL "https://golang.google.cn/dl/$ver.linux-$arch.tar.gz" -o /tmp/go.tgz
     rm -rf "$HOME/.local/lib/go" && tar -xzf /tmp/go.tgz -C "$HOME/.local/lib" && rm -f /tmp/go.tgz
     ln -sfn "$HOME/.local/lib/go/bin/go" "$HOME/.local/bin/go"
     ln -sfn "$HOME/.local/lib/go/bin/gofmt" "$HOME/.local/bin/gofmt"
     mkdir -p "$HOME/.config/go"
     go env -w GOPROXY=https://goproxy.cn,direct GOSUMDB=sum.golang.google.cn' \
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
  if as_target_user 'command -v dockerd-rootless-setuptool.sh' &>/dev/null; then
    try_install "Docker rootless 模式（用户级守护进程）" "" \
      'dockerd-rootless-setuptool.sh install'
  else
    log "无 dockerd-rootless-setuptool.sh（docker.io 不含 rootless 组件），跳过 rootless"
  fi

  # 现代 CLI 工具（GitHub release 单二进制，用户级）
  install_gh_tools
}

init_env_config() {
  local env_file="$BASE_HOME/control.env"
  if [[ -f "$env_file" ]] && ! confirm_overwrite "$env_file"; then
    log "保留已有配置: $env_file"
  else
  log "写入环境变量配置: $env_file（模板渲染）"
  render_tmpl "control.env.tmpl" "$env_file" 600
  own "$env_file"
  fi

  # bashrc 幂等挂载（control.env + direnv 钩子）
  local bashrc="$BASE_HOME/.bashrc"
  if [[ -w "$BASE_HOME" ]]; then
    grep -qF "control.env" "$bashrc" 2>/dev/null || \
      echo '[[ -f ~/control.env ]] && source ~/control.env' >> "$bashrc"
    command -v direnv &>/dev/null \
      && ! grep -qF 'direnv hook' "$bashrc" 2>/dev/null \
      && echo 'eval "$(direnv hook bash)"' >> "$bashrc" \
      && log "direnv 钩子已写入 bashrc"
  fi

  # systemd 用户会话环境（environment.d，piekbs/executor 用户服务可读）
  local envd="$BASE_HOME/.config/environment.d"
  mkdir -p "$envd"
  render_tmpl "environment.d/99-control.conf" "$envd/99-control.conf" 644 \
    && log "已生成 $envd/99-control.conf（systemd 用户环境，重登录生效）"
  own "$envd"
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

# ── 现代 CLI 工具（GitHub release 单二进制，用户级 ~/.local/bin）─
install_gh_tools() {
  has_tty || return 0
  # repo|asset 正则|bin（资产名按 uname -m 自动匹配 amd64/arm64）
  local -a spec=(
    "ducaale/xh|xh"
    "bootandy/dust|dust"
    "jesseduffield/lazygit|lazygit"
    "ajeetdsouza/zoxide|zoxide"
    "sxyazi/yazi|yazi"
    "charmbracelet/glow|glow"
    "junegunn/fzf|fzf"
  )
  local arch pat_suffix
  arch=$(uname -m)
  local missing=() entry repo bin
  for entry in "${spec[@]}"; do
    repo="${entry%%|*}"; bin="${entry##*|}"
    command -v "$bin" &>/dev/null || missing+=("$repo|$bin")
  done
  [[ ${#missing[@]} -eq 0 ]] && { log "现代 CLI 工具已齐备（xh/dust/lazygit/zoxide/yazi/glow/fzf）"; return 0; }
  local ans names=""
  for entry in "${missing[@]}"; do names+="${entry##*|} "; done
  ask "安装现代 CLI 工具（${names% }，GitHub release 用户级）？[y/N] " ans
  [[ "$ans" =~ ^[yY](es)?$ ]] || { log "跳过: $names"; return 0; }

  # 通用安装器脚本（zip 需要 python3，缺失时跳过 zip 包）
  local helper="$BASE_HOME/scripts/gh-tool-install.sh"
  cat > "$helper" <<'EOS'
#!/usr/bin/env bash
set -e
repo=$1 pat=$2 bin=$3 gh=${4:-}
# API 直连（gh 代理对 api.github.com 返回 403），仅下载走代理
url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
      | grep -o "https://[^\"]*$pat" | grep -v 'sha256\|\.sig\|\.txt\|\.pem\|\.deb\|\.rpm' | head -1)
[[ -n "$url" ]] || { echo "未找到资产: $repo $pat" >&2; exit 1; }
[[ -n "$gh" ]] && url="$gh/$url"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
case "$url" in
  *.zip)
    command -v python3 &>/dev/null || { echo "zip 需 python3" >&2; exit 1; }
    curl -fsSL "$url" -o "$tmp/a.zip"
    python3 -m zipfile -e "$tmp/a.zip" "$tmp/x" ;;
  *)
    curl -fsSL "$url" | tar -xz -C "$tmp" ;;
esac
f=$(find "$tmp" -name "$bin" -type f | head -1)
[[ -n "$f" ]] || { echo "包内未找到 $bin" >&2; exit 1; }
mkdir -p "$HOME/.local/bin"
cp "$f" "$HOME/.local/bin/$bin" && chmod +x "$HOME/.local/bin/$bin"
echo "installed: $HOME/.local/bin/$bin"
EOS
  chmod +x "$helper"; own "$helper"

  local gh="${GH_PROXY:+$GH_PROXY/}"
  for entry in "${missing[@]}"; do
    repo="${entry%%|*}"; bin="${entry##*|}"
    local pat
    case "$bin" in
      lazygit|glow) pat="inux_x86_64.tar.gz" ;;
      fzf)          pat="linux_amd64.tar.gz" ;;
      yazi)         pat="x86_64-unknown-linux-musl.zip" ;;
      *)            pat="x86_64-unknown-linux-musl.tar.gz" ;;
    esac
    [[ "$arch" == "aarch64" ]] && pat="${pat//x86_64/aarch64}" && pat="${pat//amd64/arm64}"
    log "安装 $bin（$repo）..."
    as_target_user "bash '$helper' '$repo' '$pat' '$bin' '$gh'" \
      || warn "$bin 安装失败（可稍后手动重跑: bash $helper '$repo' '$pat' '$bin' '$gh'）"
  done
}

#!/usr/bin/env bash
# mirrors.sh — 由 setup-env.sh source（依赖 common.sh）

init_mirrors() {
  local ans=""
  if [[ "${SETUP_YES:-0}" != "1" ]]; then
    has_tty || { log "非交互模式，跳过国内镜像配置"; return 0; }
    ask "配置国内镜像加速（npm→npmmirror、pip/uv→清华）？[Y/n] " ans
    [[ "$ans" =~ ^[nN](o)?$ ]] && { log "跳过国内镜像配置"; return 0; }
    echo "GitHub 加速代理：" >&2
    echo "  1) https://gh.dpik.top" >&2
    echo "  2) https://github.xxlab.tech" >&2
    echo "  回车直连（或输入其他前缀）" >&2
    ask "选择 [1/2/前缀]: " ans
    case "$ans" in
      1) GH_PROXY="https://gh.dpik.top" ;;
      2) GH_PROXY="https://github.xxlab.tech" ;;
      "") ;;
      *) GH_PROXY="$ans" ;;
    esac
    [[ -n "$GH_PROXY" ]] && log "GitHub 代理: $GH_PROXY（作用于后续 nvm/uv 安装器下载）"
  else
    log "--yes：国内镜像按默认应用（npm/pip/uv/Go），GitHub 代理跳过"
  fi

  # npm：npmmirror（用户级，需已装 npm）
  if as_target_user 'command -v npm' &>/dev/null; then
    as_target_user 'npm config set registry https://registry.npmmirror.com' \
      && log "npm 镜像: https://registry.npmmirror.com（用户级 npm config）" \
      || warn "npm 镜像配置失败（可手动: npm config set registry https://registry.npmmirror.com）"
  else
    warn "npm 未安装，跳过 npm 镜像（安装 Node 后可手动执行: npm config set registry https://registry.npmmirror.com）"
  fi

  # pip：清华镜像（模板落 ~/.config/pip/pip.conf）
  local pip_conf="$BASE_HOME/.config/pip"
  mkdir -p "$pip_conf"
  cp "${TMPL_DIR:-$SCRIPT_DIR/templates}/pip.conf" "$pip_conf/pip.conf"
  chmod 644 "$pip_conf/pip.conf"
  own "$pip_conf"
  log "pip 镜像: https://pypi.tuna.tsinghua.edu.cn/simple（$pip_conf/pip.conf）"

  # uv：清华镜像（模板落 ~/.config/uv/uv.toml）
  local uv_conf="$BASE_HOME/.config/uv"
  mkdir -p "$uv_conf"
  cp "${TMPL_DIR:-$SCRIPT_DIR/templates}/uv.toml" "$uv_conf/uv.toml"
  chmod 644 "$uv_conf/uv.toml"
  own "$uv_conf"
  log "uv 镜像: https://pypi.tuna.tsinghua.edu.cn/simple（$uv_conf/uv.toml）"

  # ~/.config 本身归属工作用户（pip/uv 子目录由 root 创建，父目录不能留 root 所有）
  own "$BASE_HOME/.config"

  # Go：goproxy.cn 模块代理（已装 Go 时写入 go env）
  if as_target_user "$USER_ENV command -v go" &>/dev/null; then
    as_target_user "$USER_ENV mkdir -p \"\$HOME/.config/go\" && go env -w GOPROXY=https://goproxy.cn,direct GOSUMDB=sum.golang.google.cn" \
      && log "Go 代理: https://goproxy.cn,direct（go env -w）" \
      || warn "Go 代理配置失败（可手动: go env -w GOPROXY=https://goproxy.cn,direct）"
  fi
}


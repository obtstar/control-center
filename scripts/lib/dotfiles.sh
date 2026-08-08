#!/usr/bin/env bash
# dotfiles.sh — 用户级 Linux 配置主题（由 setup-env.sh source，依赖 common.sh）
# 模板：scripts/templates/dotfiles/；落地即备份，覆盖需确认

init_dotfiles() {
  log "用户配置主题（bash/git/tmux/direnv）"
  local tpl="${TMPL_DIR:-$SCRIPT_DIR/templates}/dotfiles"
  [[ -d "$tpl" ]] || { warn "主题模板缺失: $tpl"; return 0; }

  # 1. bash 主题 → ~/.bashrc.d/control.sh + bashrc 挂载
  local rc_dir="$BASE_HOME/.bashrc.d"
  mkdir -p "$rc_dir"
  deploy_dotfile "$tpl/bash.sh" "$rc_dir/control.sh" 644
  local bashrc="$BASE_HOME/.bashrc"
  if [[ -w "$bashrc" ]] && ! grep -qF 'bashrc.d/control.sh' "$bashrc" 2>/dev/null; then
    echo '[[ -f ~/.bashrc.d/control.sh ]] && source ~/.bashrc.d/control.sh' >> "$bashrc"
    log "bashrc 已挂载 bash 主题"
  fi

  # 2. git 配置（user.name/email 交互确认）
  deploy_dotfile "$tpl/gitconfig" "$BASE_HOME/.gitconfig" 644
  if has_tty; then
    local cur_name cur_email ans
    cur_name=$(git config --global user.name 2>/dev/null || true)
    cur_email=$(git config --global user.email 2>/dev/null || true)
    read -rp "git user.name [${cur_name:-$OWNER}]: " ans </dev/tty
    git config --global user.name "${ans:-${cur_name:-$OWNER}}"
    read -rp "git user.email [${cur_email:-$OWNER@local}]: " ans </dev/tty
    git config --global user.email "${ans:-${cur_email:-$OWNER@local}}"
  fi

  # 3. tmux / direnv
  deploy_dotfile "$tpl/tmux.conf" "$BASE_HOME/.tmux.conf" 644
  mkdir -p "$BASE_HOME/.config/direnv"
  deploy_dotfile "$tpl/direnv.toml" "$BASE_HOME/.config/direnv/direnv.toml" 644
}

deploy_dotfile() { # $1=模板 $2=目标 $3=权限
  local src="$1" dest="$2" mode="$3"
  if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest"; then
    confirm_overwrite "$dest（与主题不一致，备份后覆盖）" || { log "保留: $dest"; return 0; }
    cp "$dest" "$dest.theme-bak"
    log "已备份: $dest.theme-bak"
  fi
  cp "$src" "$dest"
  chmod "$mode" "$dest"
  own "$dest"
  log "已部署: $dest"
}

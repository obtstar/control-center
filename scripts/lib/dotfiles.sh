#!/usr/bin/env bash
# dotfiles.sh — 用户级 Linux 配置主题（由 setup-env.sh source，依赖 common.sh）
# 模板：scripts/templates/dotfiles/；落地即备份，覆盖需确认

init_dotfiles() {
  log "用户配置主题（bashrc 块/bash/git/tmux/direnv/inputrc/vimrc/欢迎界面）"
  local tpl="${TMPL_DIR:-$SCRIPT_DIR/templates}/dotfiles"
  [[ -d "$tpl" ]] || { warn "主题模板缺失: $tpl"; return 0; }

  # 1. bashrc 托管块（标记段 upsert + 旧散行收编）
  upsert_bashrc_block "$tpl/bashrc.block"

  # 2. bash/欢迎界面 主题文件 → ~/.bashrc.d/
  local rc_dir="$BASE_HOME/.bashrc.d"
  mkdir -p "$rc_dir"
  deploy_dotfile "$tpl/bash.sh"    "$rc_dir/control.sh" 644
  deploy_dotfile "$tpl/welcome.sh" "$rc_dir/welcome.sh" 644

  # 3. gitconfig（delta/gh 条件注入）
  deploy_gitconfig "$tpl/gitconfig" "$BASE_HOME/.gitconfig"

  # 4. tmux / direnv / inputrc / vimrc
  deploy_dotfile "$tpl/tmux.conf"   "$BASE_HOME/.tmux.conf" 644
  mkdir -p "$BASE_HOME/.config/direnv"
  deploy_dotfile "$tpl/direnv.toml" "$BASE_HOME/.config/direnv/direnv.toml" 644
  deploy_dotfile "$tpl/inputrc"     "$BASE_HOME/.inputrc" 644
  deploy_dotfile "$tpl/vimrc"       "$BASE_HOME/.vimrc" 644
}

# bashrc 标记块 upsert：有标记替换段内，无标记追加；收编历史散行
upsert_bashrc_block() { # $1=块模板
  local tpl="$1" bashrc="$BASE_HOME/.bashrc"
  [[ -f "$tpl" ]] || { warn "块模板缺失: $tpl"; return 0; }
  [[ -f "$bashrc" ]] || touch "$bashrc"
  cp "$bashrc" "$bashrc.theme-bak"   # upsert 前备份（每次覆盖更新）
  # 收编旧散行（早期版本写入的单行配置）
  sed -i \
    -e '\#^\[\[ -f ~/control.env \]\] && source ~/control.env$#d' \
    -e '\#^export JAVA_HOME="\$HOME/.local/lib/jdk17"$#d' \
    -e '\#^eval "\$(direnv hook bash)"$#d' \
    -e '\#^\[\[ -f ~/.bashrc.d/control.sh \]\] && source ~/.bashrc.d/control.sh$#d' \
    "$bashrc"
  # 已有标记块则整段删除（稍后重写）
  sed -i '/# >>> control-center theme >>>/,/# <<< control-center theme <<</d' "$bashrc"
  cat "$tpl" >> "$bashrc"
  own "$bashrc"
  log "bashrc 主题块已 upsert（>>> control-center theme <<< 标记段）"
}

# gitconfig：基础模板 + delta/gh 条件段
deploy_gitconfig() { # $1=模板 $2=目标
  local src="$1" dest="$2" tmp="$2.theme-tmp"
  cp "$src" "$tmp"
  if command -v delta &>/dev/null; then
    cat >> "$tmp" <<'EOF'
[core]
	pager = delta
[interactive]
	diffFilter = delta --color-only
[delta]
	line-numbers = true
	side-by-side = true
	theme = TwoDark
EOF
    log "gitconfig: 含 delta pager 段"
  else
    warn "gitconfig: 未检测到 delta，省略 pager 段（apt/pacman 安装 git-delta 后重跑）"
  fi
  if command -v gh &>/dev/null; then
    cat >> "$tmp" <<'EOF'
[credential "https://github.com"]
	helper =
	helper = !gh auth git-credential
EOF
    log "gitconfig: 含 gh credential 段"
  fi
  if [[ -f "$dest" ]] && ! cmp -s "$tmp" "$dest"; then
    confirm_overwrite "$dest（与主题不一致，备份后覆盖）" || { rm -f "$tmp"; log "保留: $dest"; return 0; }
    cp "$dest" "$dest.theme-bak"
    log "已备份: $dest.theme-bak"
  fi
  mv "$tmp" "$dest"
  chmod 644 "$dest"
  own "$dest"
  log "已部署: $dest"
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

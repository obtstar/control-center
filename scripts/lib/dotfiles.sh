#!/usr/bin/env bash
# dotfiles.sh — 用户级 Linux 配置主题（由 setup-env.sh source，依赖 common.sh）
# 模板：scripts/templates/dotfiles/；落地即备份，覆盖需确认

init_dotfiles() { # $1=主题名（可选，默认读 ~/.config/control-theme → default）
  local theme="${1:-$(cat "$BASE_HOME/.config/control-theme" 2>/dev/null || echo default)}"
  [[ "$theme" == "off" ]] && { log "主题已关闭（theme.sh use <name> 启用）"; return 0; }
  local tpl="${TMPL_DIR:-$SCRIPT_DIR/templates}/dotfiles/$theme"
  [[ -d "$tpl" ]] || { warn "主题目录缺失: $tpl"; return 0; }
  log "用户配置主题: $theme"

  # bashrc 托管块（标记段 upsert + 旧散行收编）
  [[ -f "$tpl/bashrc.block" ]] && upsert_bashrc_block "$tpl/bashrc.block"

  # bashrc.d 主题文件（主题里有什么部署什么）
  local rc_dir="$BASE_HOME/.bashrc.d"
  mkdir -p "$rc_dir"
  local f
  for f in bash.sh welcome.sh; do
    [[ -f "$tpl/$f" ]] && deploy_dotfile "$tpl/$f" "$rc_dir/${f/bash.sh/control.sh}" 644
  done
  # 清理上一主题遗留的 bashrc.d 文件
  for f in "$rc_dir"/*.sh; do
    [[ -e "$f" ]] || continue
    local base; base=$(basename "$f")
    [[ "$base" == "control.sh" ]] && base="bash.sh"
    [[ -f "$tpl/$base" ]] || { rm -f "$f"; log "清理旧主题文件: $f"; }
  done

  [[ -f "$tpl/gitconfig" ]] && deploy_gitconfig "$tpl/gitconfig" "$BASE_HOME/.gitconfig"
  [[ -f "$tpl/tmux.conf" ]] && deploy_dotfile "$tpl/tmux.conf" "$BASE_HOME/.tmux.conf" 644
  if [[ -f "$tpl/direnv.toml" ]]; then
    mkdir -p "$BASE_HOME/.config/direnv"
    deploy_dotfile "$tpl/direnv.toml" "$BASE_HOME/.config/direnv/direnv.toml" 644
  fi
  [[ -f "$tpl/inputrc" ]] && deploy_dotfile "$tpl/inputrc" "$BASE_HOME/.inputrc" 644
  [[ -f "$tpl/vimrc" ]] && deploy_dotfile "$tpl/vimrc" "$BASE_HOME/.vimrc" 644
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
    if [[ "${DOTFILES_FORCE:-0}" != "1" ]] && ! confirm_overwrite "$dest（与主题不一致，备份后覆盖）"; then
      rm -f "$tmp"; log "保留: $dest"; return 0
    fi
    cp "$dest" "$dest.theme-bak"
    log "已备份: $dest.theme-bak"
  fi
  mv "$tmp" "$dest"
  chmod 644 "$dest"
  own "$dest"
  log "已部署: $dest"
}

deploy_dotfile() { # $1=模板 $2=目标 $3=权限（DOTFILES_FORCE=1 时跳过覆盖确认）
  local src="$1" dest="$2" mode="$3"
  if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest"; then
    if [[ "${DOTFILES_FORCE:-0}" != "1" ]] && ! confirm_overwrite "$dest（与主题不一致，备份后覆盖）"; then
      log "保留: $dest"
      return 0
    fi
    cp "$dest" "$dest.theme-bak"
    log "已备份: $dest.theme-bak"
  fi
  cp "$src" "$dest"
  chmod "$mode" "$dest"
  own "$dest"
  log "已部署: $dest"
}

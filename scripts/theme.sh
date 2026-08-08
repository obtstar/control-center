#!/usr/bin/env bash
# theme.sh — 环境主题切换（list/current/use/off）
# 主题目录：scripts/templates/dotfiles/<name>/；当前主题记录于 ~/.config/control-theme
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER="${OWNER_USER:-$(id -un)}"
BASE_HOME="${BASE_HOME:-$HOME}"
export TMPL_DIR="$SCRIPT_DIR/templates"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/dotfiles.sh
source "$SCRIPT_DIR/lib/dotfiles.sh"

THEMES_DIR="$TMPL_DIR/dotfiles"
MARKER="$BASE_HOME/.config/control-theme"

current_theme() { cat "$MARKER" 2>/dev/null || echo default; }

usage() {
  cat <<EOF
用法: $0 <命令>
  list            列出可用主题
  current         显示当前主题
  use <name>      切换并部署主题（含 bashrc 块更新）
  off             关闭主题（移除 bashrc 主题块，保留 marker=off）
主题即 scripts/templates/dotfiles/ 下的目录；新增目录即新主题。
EOF
}

cmd="${1:-current}"
case "$cmd" in
  list)
    for d in "$THEMES_DIR"/*/; do
      n=$(basename "$d")
      [[ "$n" == "$(current_theme)" ]] && echo "* $n" || echo "  $n"
    done ;;
  current)
    current_theme ;;
  use)
    name="${2:-}"
    [[ -n "$name" && -d "$THEMES_DIR/$name" ]] || { echo "主题不存在: $name（theme.sh list 查看）" >&2; exit 1; }
    mkdir -p "$BASE_HOME/.config"
    echo "$name" > "$MARKER"
    DOTFILES_FORCE=1 init_dotfiles "$name"
    log "主题已切换: $name"
    ;;
  off)
    bashrc="$BASE_HOME/.bashrc"
    if [[ -f "$bashrc" ]] && grep -qF '# >>> control-center theme >>>' "$bashrc"; then
      cp "$bashrc" "$bashrc.theme-bak"
      sed -i '/# >>> control-center theme >>>/,/# <<< control-center theme <<</d' "$bashrc"
      log "已移除 bashrc 主题块（备份: $bashrc.theme-bak）"
    fi
    mkdir -p "$BASE_HOME/.config"
    echo off > "$MARKER"
    log "主题已关闭（theme.sh use <name> 重新启用）"
    ;;
  -h|--help) usage ;;
  *) echo "未知命令: $cmd" >&2; usage; exit 1 ;;
esac

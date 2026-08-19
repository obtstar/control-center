#!/usr/bin/env bash
# kb-sync.sh — 权柄文档镜像进 control-wiki/raw/platform/（FINDING-051）
#
# 权威居所 = 各 Git 仓原文件（唯一可信源，本脚本永不修改上游）；
# 镜像 = 带 kb-mirror 出处头的派生副本，供 PieKBS FTS / grounding 检索。
# 镜像清单唯一来源 = orchestration/reconcile/checks.yaml 的 mirror_pairs 块，
# reconcile 的 kb-mirror-freshness 检查按同块对账（镜像首行 sha256 ↔ 上游内容）。
#
# 用法: kb-sync.sh [home]   （默认 $HOME）
set -euo pipefail

HOME_DIR="$(cd "${1:-$HOME}" && pwd)"
CHECKS="$HOME_DIR/control-center/orchestration/reconcile/checks.yaml"
[ -f "$CHECKS" ] || { echo "错误: 找不到 checks.yaml: $CHECKS" >&2; exit 1; }

mirror_file() { # $1=upstream（相对 home） $2=mirror（相对 home）
  local up="$HOME_DIR/$1" dst="$HOME_DIR/$2" hash tmp
  if [ ! -f "$up" ]; then
    echo "WARN: 上游缺失，跳过: $1" >&2
    return 0
  fi
  hash=$(sha256sum "$up" | cut -d' ' -f1)
  mkdir -p "$(dirname "$dst")"
  tmp="$dst.kbsync.tmp"
  # 出处头固定两行：首行 sha256 供 reconcile 对账（哈希后必须跟空白，
  # 检查器按空白分词取 sha256=<hex>）；次行 synced-at 供人读
  case "$dst" in
    *.yaml|*.yml)
      printf '# kb-mirror: upstream=%s sha256=%s （派生副本勿编辑；权威见 upstream，重生成: control-center/scripts/kb-sync.sh）\n# synced-at: %s\n' "$1" "$hash" "$(date -Iseconds)" > "$tmp"
      ;;
    *)
      printf '<!-- kb-mirror: upstream=%s sha256=%s （派生副本勿编辑；权威见 upstream，重生成: control-center/scripts/kb-sync.sh）\nsynced-at: %s -->\n\n' "$1" "$hash" "$(date -Iseconds)" > "$tmp"
      ;;
  esac
  cat "$up" >> "$tmp"
  # 仅首行或正文漂移才落盘（sed '2d' 剔除 synced-at 行，避免 watcher 空转重建索引）
  if [ -f "$dst" ] && diff -q <(sed '2d' "$dst") <(sed '2d' "$tmp") >/dev/null 2>&1; then
    rm -f "$tmp"
  else
    mv "$tmp" "$dst"
    echo "synced: $2"
  fi
}

count=0
while IFS=$'\t' read -r up mir; do
  [ -n "$up" ] && [ -n "$mir" ] || continue
  mirror_file "$up" "$mir"
  count=$((count + 1))
done < <(grep -E '^\s+- \{upstream: ' "$CHECKS" \
  | sed -E 's/^\s+- \{upstream: ([^,]+), mirror: ([^}]+)\}.*/\1\t\2/' | sed 's/[[:space:]]*$//')

echo "完成: $count 对镜像对照（清单来源 checks.yaml#kb-mirror-freshness）"

#!/usr/bin/env bash
# branch-cleanup.sh — 已合并 feature 分支自动清理（平台六仓）
# 优化：ls-remote 一次性拿远端分支（不逐仓 fetch），已合并判断用本地对象
set -euo pipefail
HOME_DIR="$(cd "${1:-$HOME}" && pwd)"
REPOS="control-center control-web control-api control-piekbs control-wiki control-dsh-plugin"
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -F /dev/null -o StrictHostKeyChecking=no}"
log() { printf '\033[1;34m[cleanup]\033[0m %s\n' "$*"; }
for repo in $REPOS; do
  d="$HOME_DIR/$repo"
  git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || continue
  # 一次 ls-remote 拿远端 feature 分支（超时 15s）
  branches=$(timeout 15 env GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git -C "$d" ls-remote --heads origin 'refs/heads/feature/*' 2>/dev/null | awk '{print $2}' | sed 's|refs/heads/||') || { log "$repo: ls-remote 失败，跳过"; continue; }
  deleted=0
  for b in $branches; do
    if git -C "$d" merge-base --is-ancestor "origin/$b" origin/dev 2>/dev/null \
       || git -C "$d" merge-base --is-ancestor "origin/$b" origin/main 2>/dev/null; then
      GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git -C "$d" push origin --delete "$b" >/dev/null 2>&1 \
        && log "$repo: 已删已合并分支 $b" && deleted=$((deleted+1))
    fi
  done
  [ "$deleted" -eq 0 ] && log "$repo: 无已合并 feature 分支残留"
done

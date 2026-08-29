#!/usr/bin/env bash
# task-archive.sh — 已交付（delivered）任务产物自动归档（任务即文档）
#
# 背景：任务产物（task.md + report-*.md）由 control-api/DSH 会话写入
# control-center/tasks/<TASK-id>/（权威工作区），delivered 后需入库（Git 为唯一可信源）。
# 本脚本自动化归档：
#   1) 扫描 tasks/ 下 frontmatter status=delivered 且未完全入库的任务目录
#   2) 收集产物 → 建 feature 分支 → commit → push → gh pr create（自动 MR，人合并终审）
#   3) 归档成功后清理工作区副本（备份到 $HOME/.backup-task-dirs/），避免后续 merge 被未跟踪目录阻塞
#
# 用法: task-archive.sh [home]     （默认 $HOME；home 下须有 control-center/）
# 依赖: git + gh（已登录）；产物入库经 MR 评审（dev 只读规约）
set -euo pipefail

HOME_DIR="$(cd "${1:-$HOME}" && pwd)"
REPO="$HOME_DIR/control-center"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "错误: 找不到 control-center 仓库: $REPO" >&2; exit 1; }
cd "$REPO"
# 同步远端引用（remote.origin.fetch 缺失时显式 refspec，见 FINDING-054 教训）
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -F /dev/null -o StrictHostKeyChecking=no}"
git fetch origin '+refs/heads/*:refs/remotes/origin/*' >/dev/null 2>&1 || true

log() { printf '\033[1;34m[archive]\033[0m %s\n' "$*"; }

# status=delivered 的任务（含 6 位新编号 TASK-0000NN）
delivered_dirs() {
  for d in tasks/TASK-*/; do
    [ -f "$d/task.md" ] || continue
    if grep -qE '^status: *delivered' "$d/task.md" 2>/dev/null; then
      echo "${d%/}"
    fi
  done
}

# 目录是否已完整入库（全部文件在 origin/dev）
is_archived() { # $1=任务目录
  local dir="$1" n=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    n=$((n+1))
    if ! git cat-file -e "origin/dev:$dir/$f" 2>/dev/null; then
      return 1
    fi
  done < <(cd "$REPO" && ls "$dir" 2>/dev/null)
  [ "$n" -gt 0 ]
}

main() {
  local pending=()
  while read -r d; do
    [ -z "$d" ] && continue
    if ! is_archived "$d"; then
      pending+=("$d")
    fi
  done < <(delivered_dirs)

  if [ ${#pending[@]} -eq 0 ]; then
    log "无待归档的 delivered 任务产物（全部已入库）"
    # 顺带清理工作区未跟踪副本（防 merge 阻塞）
    git status --short tasks/ | awk '/^\?\? tasks\/TASK-/{print $2}' | while read -r d; do
      if is_archived "$d"; then
        bk="$HOME/.backup-task-dirs/$(basename "$d")"
        mkdir -p "$HOME/.backup-task-dirs"
        [ -e "$bk" ] || cp -r "$d" "$bk"
        rm -rf "$d"
        log "已清理工作区副本（已入库）: $d"
      fi
    done
    return 0
  fi

  log "待归档 ${#pending[@]} 个任务: ${pending[*]}"
  local branch="feature/task-archive-$(date +%m%d%H%M%S)"
  local wt="$HOME/.task-archive-wt-$branch"
  # 在独立临时 worktree 归档（不动主仓工作区/分支；主仓 tasks/ 副本稍后清理）
  git worktree add -b "$branch" "$wt" origin/dev >/dev/null 2>&1
  for d in "${pending[@]}"; do
    mkdir -p "$wt/$d"
    cp -r "$REPO/$d/." "$wt/$d/"
    log "归档: $d"
  done
  ( cd "$wt" \
    && git add "${pending[@]}" \
    && git commit -m "docs(tasks): 自动归档 delivered 任务产物（task-archive.sh）" \
    && GIT_SSH_COMMAND="$GIT_SSH_COMMAND" git push -u origin "$branch" )
  if ! gh pr create --base dev --head "$branch" \
      --title "docs(tasks): 自动归档 delivered 任务产物" \
      --body "task-archive.sh 自动归档：${pending[*]}。人合并终审（dev 只读规约）。" >/dev/null 2>&1; then
    log "WARN: gh pr create 失败（分支已推送: $branch，请人工建 MR）"
  else
    log "MR 已建（人合并后任务产物入库）；分支: $branch"
  fi
  git worktree remove "$wt" >/dev/null 2>&1 || git worktree remove --force "$wt" >/dev/null 2>&1
  # 归档后清理主仓未跟踪副本（备份至 ~/.backup-task-dirs/，防 merge 阻塞）
  for d in "${pending[@]}"; do
    if [ -d "$REPO/$d" ]; then
      bk="$HOME/.backup-task-dirs/$(basename "$d")"
      mkdir -p "$HOME/.backup-task-dirs"
      [ -e "$bk" ] || cp -r "$REPO/$d" "$bk"
      rm -rf "$REPO/$d"
      log "已清理主仓副本（已入归档分支）: $d"
    fi
  done
}

main "$@"

#!/usr/bin/env bash
# branch.sh — 业务项目分支/Worktree 管理（02 章分支模型）
# main/dev/release 只读；agent 仅写 feature|bugfix（从 dev 切出），团队合并后回收
# gitdir：~/.repos/<repo>.git（bare）；常驻：~/wt/projects/<repo>/dev；任务：~/wt/<repo>/TASK-*
set -euo pipefail

BASE_HOME="${BASE_HOME:-$HOME}"
GITDIR_ROOT="$BASE_HOME/.repos"
WT_ROOT="$BASE_HOME/wt"

log() { printf '\033[1;34m[branch]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
用法: $0 <命令>
  new <repo> <task-id> <name> [--bugfix]   从 dev 切 feature/bugfix 分支并建任务 worktree
  list [repo]                              列出 worktree（全部或指定仓库）
  sync [repo|--all]                        fetch + 只读主干（dev/main/release）快进更新
  done <task-worktree-dir> [--delete-remote]  合并后回收任务 worktree 与本地分支
  prune [days]                             回收超龄 TASK worktree（默认 7 天，不动 projects/）
  release <repo> <yyyymm>                  从 dev 切 release/{yyyymm} 并推送
例: $0 new billing-core TASK-001 ai-report
EOF
}

gitdir() { # $1=repo → bare gitdir（必须存在）
  local d="$GITDIR_ROOT/$1.git"
  [[ -d "$d" ]] || die "gitdir 不存在: $d（先在 registry/repos.yaml 登记并 sync）"
  echo "$d"
}

remote_of() { # $1=repo
  git -C "$(gitdir "$1")" remote get-url origin 2>/dev/null || true
}

cmd_new() { # repo task-id name [--bugfix]
  local repo="$1" tid="$2" name="$3" type="feature"
  [[ "${4:-}" == "--bugfix" ]] && type="bugfix"
  [[ "$tid" =~ ^[A-Za-z0-9-]+$ && "$name" =~ ^[a-z0-9-]+$ ]] \
    || die "task-id/name 仅允许字母数字与连字符"
  local gd branch dest
  gd=$(gitdir "$repo")
  branch="$type/$tid-$name"
  dest="$WT_ROOT/$repo/$tid-$type-$name"
  log "fetch origin（$repo）..."
  git -C "$gd" fetch -q origin
  git -C "$gd" rev-parse -q --verify "refs/heads/$branch" >/dev/null \
    && die "分支已存在: $branch"
  git -C "$gd" branch "$branch" origin/dev 2>/dev/null \
    || git -C "$gd" branch "$branch" origin/main
  git -C "$gd" worktree add "$dest" "$branch" >/dev/null
  log "已创建: $branch → $dest（从 dev 切出；main/dev/release 只读）"
  log "推送: git -C '$dest' push -u origin '$branch'；完成后团队 MR 评审合并"
}

cmd_list() { # [repo]
  local repos=()
  if [[ -n "${1:-}" ]]; then repos=("$1"); else
    for d in "$GITDIR_ROOT"/*.git; do repos+=("$(basename "$d" .git)"); done
  fi
  local r
  for r in "${repos[@]}"; do
    [[ -d "$GITDIR_ROOT/$r.git" ]] || continue
    printf '\033[1;36m%s\033[0m (%s)\n' "$r" "$(remote_of "$r")"
    git -C "$GITDIR_ROOT/$r.git" worktree list | tail -n +2 | sed 's/^/  /'
  done
}

cmd_sync() { # [repo|--all]
  local repos=()
  if [[ -z "${1:-}" || "$1" == "--all" ]]; then
    for d in "$GITDIR_ROOT"/*.git; do repos+=("$(basename "$d" .git)"); done
  else repos=("$1"); fi
  local r b
  for r in "${repos[@]}"; do
    local gd="$GITDIR_ROOT/$r.git"
    [[ -d "$gd" ]] || { log "跳过（无 gitdir）: $r"; continue; }
    git -C "$gd" fetch -q --prune origin
    for b in main dev; do
      git -C "$gd" rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null || continue
      # 只读主干：仅快进，分叉则告警（不合并不重置）
      if git -C "$gd" merge-base --is-ancestor "refs/heads/$b" "refs/remotes/origin/$b" 2>/dev/null; then
        git -C "$gd" update-ref "refs/heads/$b" "refs/remotes/origin/$b" 2>/dev/null \
          && log "$r: $b 快进至 origin/$b" || true
      else
        log "$r: $b 与 origin 分叉（保留本地，主干只读不重置）"
      fi
    done
  done
}

cmd_done() { # <task-worktree-dir> [--delete-remote]
  local dest="$1"
  [[ -f "$dest/.git" ]] || die "非 worktree 目录: $dest"
  local repo branch gd
  repo=$(basename "$(dirname "$dest")")
  gd=$(gitdir "$repo")
  branch=$(git -C "$dest" branch --show-current)
  [[ "$branch" =~ ^(feature|bugfix)/ ]] \
    || die "仅回收 feature/bugfix 分支 worktree（当前: $branch）"
  git -C "$gd" worktree remove "$dest"
  git -C "$gd" branch -D "$branch" >/dev/null
  log "已回收: $dest（分支 $branch 已删本地）"
  if [[ "${2:-}" == "--delete-remote" ]]; then
    git -C "$gd" push -q origin --delete "$branch" \
      && log "远端分支已删: $branch" || log "远端分支删除失败（权限？保留）: $branch"
  else
    log "远端分支保留（团队合并流程用；如需删除加 --delete-remote）"
  fi
}

cmd_prune() { # [days]
  local days="${1:-7}" count=0 d
  for d in "$WT_ROOT"/*/*/; do
    local name; name=$(basename "$d")
    [[ "$name" =~ ^[A-Za-z0-9]+-(feature|bugfix)- ]] || continue
    find "$d" -maxdepth 0 -mtime +"$days" | grep -q . || continue
    cmd_done "${d%/}" >/dev/null && count=$((count+1))
  done
  log "回收完成: $count 个超龄（>${days}d）任务 worktree（projects/ 常驻目录未动）"
}

cmd_release() { # repo yyyymm
  local repo="$1" ym="$2" gd branch
  [[ "$ym" =~ ^[0-9]{6}$ ]] || die "格式: release <repo> <yyyymm>（如 202608）"
  gd=$(gitdir "$repo")
  branch="release/$ym"
  git -C "$gd" rev-parse -q --verify "refs/heads/$branch" >/dev/null \
    && die "分支已存在: $branch"
  git -C "$gd" fetch -q origin dev
  git -C "$gd" branch "$branch" origin/dev
  git -C "$gd" push -q -u origin "$branch"
  log "已切出并推送: $branch（从 dev；只读主干，发布流程走 MR 合并）"
}

case "${1:-}" in
  new)     shift; [[ $# -ge 3 ]] || { usage; exit 1; }; cmd_new "$@" ;;
  list)    shift; cmd_list "${1:-}" ;;
  sync)    shift; cmd_sync "${1:-}" ;;
  done)    shift; [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_done "$@" ;;
  prune)   shift; cmd_prune "${1:-}" ;;
  release) shift; [[ $# -ge 2 ]] || { usage; exit 1; }; cmd_release "$@" ;;
  -h|--help|"") usage ;;
  *) echo "未知命令: $1" >&2; usage; exit 1 ;;
esac

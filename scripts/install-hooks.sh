#!/usr/bin/env bash
# install-hooks.sh — 把 check-conventions.sh 安装为目标仓 pre-commit hook
#
# 用法: install-hooks.sh [repo]   （默认 control-api；参数可为仓名或工作区路径）
#
# 本环境多仓 gitdir 集中在 ~/.repos/<name>.git，工作区 .git 是指针文件；
# 脚本经 git rev-parse --absolute-git-dir + commondir 解析真实公共 gitdir，
# hook 装入 <common-gitdir>/hooks/pre-commit。
# 幂等：已存在相同内容则跳过；存在不同内容则备份为 pre-commit.bak 后再装。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-conventions.sh"
TARGET="${1:-control-api}"

if [ -d "$TARGET" ]; then
  REPO="$(cd "$TARGET" && pwd)"
elif [ -d "$HOME/$TARGET" ]; then
  REPO="$HOME/$TARGET"
else
  echo "错误: 找不到仓库 '$TARGET'（既非目录路径也非 \$HOME 下仓名）" >&2
  exit 1
fi

GITDIR="$(git -C "$REPO" rev-parse --absolute-git-dir)"
if [ -f "$GITDIR/commondir" ]; then
  GITDIR="$(cd "$GITDIR/$(cat "$GITDIR/commondir")" && pwd)"
fi
HOOKS="$GITDIR/hooks"
HOOK="$HOOKS/pre-commit"

CONTENT="#!/bin/bash
exec $CHECK \"\$(git rev-parse --show-toplevel)\""

mkdir -p "$HOOKS"
if [ -f "$HOOK" ]; then
  if [ "$(cat "$HOOK")" = "$CONTENT" ]; then
    echo "已安装且内容一致，跳过: $HOOK"
    exit 0
  fi
  cp "$HOOK" "$HOOK.bak"
  echo "已存在不同 pre-commit，备份为 $HOOK.bak"
fi
printf '%s\n' "$CONTENT" > "$HOOK"
chmod +x "$HOOK"
echo "已安装 pre-commit hook: $HOOK"
echo "  仓库: $REPO"
echo "  指向: $CHECK"

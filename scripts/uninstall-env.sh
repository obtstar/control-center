#!/usr/bin/env bash
# uninstall-env.sh — 卸载 init-env.sh 创建的环境（逐项交互确认后删除）
# 依据：scripts/init-env.sh 所创建的全部产物（docs/architecture/13/16 章）
set -uo pipefail

BASE_HOME="${BASE_HOME:-$HOME}"
EXECUTOR=0
ASSUME_YES=0

usage() {
  cat <<EOF
用法: $0 [选项]
  --home DIR     基础 home 目录（默认: \$HOME）
  --executor     执行节点模式（仅卸载 executor 产物）
  --yes          全部确认（非交互，慎用）
  -h, --help     显示帮助
逐项提示删除：compose 容器 → 目录/配置 → bashrc 挂载 → agent 用户。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --home) BASE_HOME="$2"; shift 2 ;;
    --executor) EXECUTOR=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

log() { printf '\033[1;34m[uninstall]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

confirm() { # $1=提示；0=确认删除
  [[ $ASSUME_YES -eq 1 ]] && return 0
  [[ -t 0 ]] || return 1
  local ans
  read -rp "$1 [y/N] " ans
  [[ "$ans" =~ ^[yY](es)?$ ]]
}

rm_path() { # $1=路径 $2=说明
  if [[ ! -e "$1" && ! -L "$1" ]]; then
    log "不存在，跳过: $1"
    return 0
  fi
  if confirm "删除$2（$1）？"; then
    rm -rf "$1" && log "已删除: $1"
  else
    log "保留: $1"
  fi
}

log "卸载 Agent 平台环境（base: $BASE_HOME）"

# ── 0. 停止 compose 测试环境 ──────────────────────────────────
if [[ $EXECUTOR -eq 0 && -f "$BASE_HOME/deploy/docker-compose.yml" ]]; then
  if command -v docker &>/dev/null && docker compose version &>/dev/null; then
    if confirm "停止并删除 compose 容器（$BASE_HOME/deploy）？"; then
      (cd "$BASE_HOME/deploy" && docker compose down) && log "compose 已停止"
    fi
  else
    warn "docker 不可用，跳过 compose 停止（如有容器请手动 docker compose down）"
  fi
fi

# ── 1. 目录与配置 ─────────────────────────────────────────────
if [[ $EXECUTOR -eq 1 ]]; then
  rm_path "$BASE_HOME/executor" " executor 工作区（workspace/cache/logs/.env）"
else
  # control-center 通常是 Git 克隆（本仓库），删除前检查未提交/未推送内容
  if [[ -d "$BASE_HOME/control-center/.git" ]]; then
    dirty=$(git -C "$BASE_HOME/control-center" status --porcelain 2>/dev/null)
    ahead=$(git -C "$BASE_HOME/control-center" log --branches --not --remotes --oneline 2>/dev/null)
    [[ -n "$dirty$ahead" ]] && warn "control-center 有未提交或未推送的更改！"
  fi
  rm_path "$BASE_HOME/control-center" " 控制中心（文档/编排/注册表，Git 克隆）"
  rm_path "$BASE_HOME/repos"         " 平台代码仓库（control-api/control-web/control-db）"
  rm_path "$BASE_HOME/wt"            " 任务 Worktree 根目录"
  rm_path "$BASE_HOME/data"          " 数据目录（mysql/milvus，删后不可恢复）"
  rm_path "$BASE_HOME/logs"          " 日志目录"
  rm_path "$BASE_HOME/deploy"        " compose 部署目录（含 .env）"
  rm_path "$BASE_HOME/scripts"       " 脚本目录"
fi

rm_path "$BASE_HOME/control.env" " 环境变量配置"
rm_path "$BASE_HOME/.venv"       " Python 虚拟环境"
rm_path "$BASE_HOME/.pi"         " pi 配置（models.json、skills 软链）"
rm_path "$BASE_HOME/.agent"      " agent 配置目录（executor 工具链）"

# ── 2. bashrc 挂载行 ──────────────────────────────────────────
bashrc="$BASE_HOME/.bashrc"
if [[ -f "$bashrc" ]] && grep -qF 'source ~/control.env' "$bashrc"; then
  if confirm "移除 $bashrc 中的 control.env 挂载行？"; then
    sed -i.uninstall-bak '\#source ~/control.env#d' "$bashrc" \
      && log "已移除 bashrc 挂载行（备份: $bashrc.uninstall-bak）"
  fi
fi

# ── 3. agent 用户 ─────────────────────────────────────────────
if id agent &>/dev/null; then
  if [[ $EUID -ne 0 ]]; then
    warn "非 root，跳过删除 agent 用户（可用 sudo 重试）"
  elif confirm "删除 Linux 用户 agent？"; then
    userdel agent 2>/dev/null && log "已删除用户 agent" \
      || warn "userdel 失败（可能有进程占用）：请手动检查"
  fi
fi

log "完成。未确认的项均已保留。"

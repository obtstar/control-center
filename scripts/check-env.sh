#!/usr/bin/env bash
# check-env.sh — 环境终检（预检 + 后检），独立校验脚本
# 用法: check-env.sh [--owner NAME] [--executor]
# 输出三级：PASS 正常 / WARN 可择情处理 / FAIL 必须修复
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OWNER="${OWNER_USER:-dev}"
BASE_HOME="/home/$OWNER"
EXECUTOR=0
LITELLM_ENDPOINT="${LITELLM_ENDPOINT:-http://litellm.internal:4000}"

usage() {
  cat <<EOF
用法: $0 [选项]
  --owner NAME   工作用户（默认: dev，基目录 /home/<name>）
  --executor     执行节点分支校验
  -h, --help     显示帮助
环境变量:
  LITELLM_ENDPOINT  LiteLLM 代理地址（默认 http://litellm.internal:4000）
  OWNER_USER        同 --owner
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; BASE_HOME="/home/$OWNER"; shift 2 ;;
    --executor) EXECUTOR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/check.sh
source "$SCRIPT_DIR/lib/check.sh"

check_pre
check_post || true
exit 0

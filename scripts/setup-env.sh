#!/usr/bin/env bash
# setup-env.sh — Agent 平台环境安装（阶段二）
# 触发：首次登录工作用户自动执行（bashrc 钩子，一次性），或随时手动重跑：
#   bash ~/control-center/scripts/setup-env.sh [--executor] [--skip-*] [--check]
# 阶段一（init-env.sh）已完成：用户/目录/control-center 克隆
# 模块见 scripts/lib/*.sh；架构文档见 control-wiki 知识库（raw/architecture/）
set -euo pipefail

OWNER="${OWNER_USER:-dev}"   # 工作用户（默认 dev，--owner 自定义）
BASE_HOME="/home/$OWNER"     # 基目录恒为工作用户 home
SAVED_ARGS="$*"
OWNER_SET=0
EXECUTOR=0
EXECUTOR_SET=0
SKIP_USERS=0
SKIP_COMPOSE=0
SKIP_REPOS=0
SKIP_TOOLING=0
CHECK_ONLY=0
CONTROL_API=""
LITELLM_ENDPOINT="${LITELLM_ENDPOINT:-http://litellm.internal:4000}"
# pip/uv 镜像：优先内网镜像，未设置时默认清华镜像
export PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
export UV_INDEX_URL="${UV_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
# GitHub 加速代理前缀（如 https://gh.dpik.top），作用于 nvm/uv 安装器下载
GH_PROXY="${GH_PROXY:-}"
# npm 镜像：优先内网镜像，未设置时默认 npmmirror（pi/openskills/corepack 用）
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

usage() {
  cat <<EOF
用法: $0 [选项]（阶段二：软件安装与仓库同步，以工作用户身份运行，无需 root）
  --owner NAME      工作用户（默认: dev）
  --executor        执行节点分支（executor 工作区/工具链/登记提示）
  --control-api URL 编排节点地址（executor 分支，不传则交互询问）
  --skip-repos      跳过 registry 清单仓库同步
  --skip-compose    跳过 docker-compose 生成与启动
  --skip-tooling    跳过语言/框架与 pi/openskills/PieKBS
  --check           仅做环境校验（预检 + 后检）
  -h, --help        显示帮助
环境变量:
  NPM_REGISTRY      npm 镜像（默认 https://registry.npmmirror.com）
  PIP_INDEX_URL / UV_INDEX_URL  pip/uv 镜像（默认清华）
  GH_PROXY          GitHub 加速代理前缀（nvm/uv/piekbs 下载用）
  NVM_NODEJS_ORG_MIRROR  nvm 下载 Node 的镜像（默认 npmmirror）
  GIT_PROTO / GIT_REMOTE_HOST / GIT_REMOTE_BASE  仓库远程构造
  CONTROL_WIKI_REMOTE  PieKBS 知识库远程仓（默认 \$GIT_REMOTE_BASE/control-wiki.git）
  LITELLM_ENDPOINT  LiteLLM 代理地址（默认 http://litellm.internal:4000）
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; OWNER_SET=1; shift 2 ;;
    --executor) EXECUTOR=1; EXECUTOR_SET=1; shift ;;
    --control-api) CONTROL_API="$2"; shift 2 ;;
    --skip-users) SKIP_USERS=1; shift ;;
    --skip-repos) SKIP_REPOS=1; shift ;;
    --skip-compose) SKIP_COMPOSE=1; shift ;;
    --skip-tooling) SKIP_TOOLING=1; shift ;;
    --check) CHECK_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
done

# ── 加载模块 ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TMPL_DIR="$SCRIPT_DIR/templates"   # 配置模板目录（render_tmpl 使用）
for m in common check mirrors repos toolchain piekbs agent compose executor dotfiles; do
  # shellcheck source=lib/*.sh
  source "$SCRIPT_DIR/lib/$m.sh"
done

# ── main ──────────────────────────────────────────────────────
if [[ $CHECK_ONLY -eq 1 ]]; then
  check_pre
  check_post || true
  exit 0
fi

interactive_setup

# 用户/目录/本工程克隆由阶段一完成；此处仅校验存在性
if ! id "$OWNER" &>/dev/null; then
  echo "工作用户 $OWNER 不存在，请先执行阶段一: sudo bash scripts/init-env.sh" >&2
  exit 1
fi

check_pre
if [[ $EXECUTOR -eq 1 ]]; then
  init_executor
  check_post || true
  log "完成（executor 模式）。请在 registry/executors.yaml 登记本机后启动 executor 服务"
else
  init_mirrors
  step_enabled "仓库同步（registry/repos.yaml 清单）" "$SKIP_REPOS" && sync_repos
  step_enabled "语言/框架工具链（JDK+Maven/nvm/uv/Go/pnpm）" "$SKIP_TOOLING" && init_toolchain
  step_enabled "PieKBS 知识库（二进制 + KB 初始化）" "$SKIP_TOOLING" && init_piekbs
  init_env_config
  step_enabled "用户配置主题（bashrc/git/tmux/direnv/inputrc/vimrc/欢迎界面）" "$SKIP_TOOLING" && init_dotfiles
  step_enabled "Python 虚拟环境（uv venv .venv）" "$SKIP_TOOLING" && init_venv "$BASE_HOME" "$OWNER"
  if step_enabled "pi / openskills（Agent 工具链）" "$SKIP_TOOLING"; then
    install_pi_packages
    install_agent_tooling "$BASE_HOME" "$OWNER"          # 人工通道（VSCode/CLI）
    install_agent_tooling "$BASE_HOME/.agent" agent      # Agent 通道（.agent 组可写）
  fi
  step_enabled "compose 测试环境" "$SKIP_COMPOSE" && init_compose
  check_post || true
  touch "$BASE_HOME/.control-setup-done"
  log "完成（已标记 ~/.control-setup-done，重跑: bash ~/control-center/scripts/setup-env.sh）"
fi

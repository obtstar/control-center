# control-center

Agent 平台控制中心仓库：任务编排配置 + 注册表 + 环境脚本（**无业务代码**）。
架构文档已迁至 **control-wiki 知识库**（`raw/architecture/`，PieKBS 检索）。

## 目录

| 路径 | 内容 |
|-----|------|
| `orchestration/` | 任务编排配置：`prompts/`、`skills/`、`workflows/` |
| `registry/` | 注册表：`repos.yaml`（环境拓扑 + 仓库注册）、`executors.yaml`（执行节点登记） |
| `scripts/init-env.sh` | **阶段一**引导脚本（单文件，`curl \| bash` 分发） |
| `scripts/setup-env.sh` | **阶段二**安装入口 |
| `scripts/lib/` | 阶段二模块（common/check/mirrors/repos/toolchain/piekbs/agent/compose/executor，均 <300 行） |
| `scripts/uninstall-env.sh` | 卸载脚本 |
| `control-center.code-workspace` | VS Code 多根目录工作区，`code control-center.code-workspace` 打开 |

## 环境初始化（两阶段）

### 阶段一：init-env.sh（引导，需 root）

只做三件事：**环境校验 → 创建工作用户（dev/agent）→ 克隆 control-center 本工程**，并植入首次登录钩子；顺带可装**系统级**常用工具（direnv/tmux/ripgrep/fd/jq/gh——与 git/curl 同级，apt/pacman/dnf 自适应含包名映射，默认 Y）：

```bash
# 编排节点（第一台）
curl -fsSL https://gh.dpik.top/https://raw.githubusercontent.com/obtstar/control-center/main/scripts/init-env.sh | sudo bash -s --

# 执行节点（办公 PC）
curl -fsSL https://gh.dpik.top/https://raw.githubusercontent.com/obtstar/control-center/main/scripts/init-env.sh | sudo bash -s -- --executor

# 仅环境校验（不初始化，非 root 也可用）
bash scripts/init-env.sh --check
```

### 阶段二：setup-env.sh（安装，工作用户身份，无需 root）

**首次以 dev 登录时自动触发**（bashrc 钩子，完成后标记 `~/.control-setup-done`），也可随时手动重跑：

```bash
bash ~/control-center/scripts/setup-env.sh              # 全量：镜像/仓库同步/工具链/PieKBS/pi/compose
bash ~/control-center/scripts/setup-env.sh --executor   # 执行节点分支
bash ~/control-center/scripts/setup-env.sh --check      # 仅校验
```

仓库同步由 **`registry/repos.yaml` 清单驱动**：control-center 仅 pull，control-api/web/db 克隆或本地骨架，piekbs 落顶级目录 `~/piekbs`，control-wiki 由 PieKBS 步骤管理。

### 选项（阶段一透传阶段二）

| 选项 | 说明 |
|-----|------|
| `--owner NAME` | 工作用户（默认 `dev`；阶段一自动创建，其 home 即环境基目录） |
| `--executor` | 执行节点分支 |
| `--control-api URL` | 编排节点地址（executor 分支，不传则交互询问） |
| `--skip-repos` / `--skip-compose` / `--skip-tooling` | 分步跳过（阶段二） |
| `--check` | **仅环境校验**（阶段一非 root 仅支持此模式；阶段二任意用户可用） |

### 交互式流程

tty 交互运行：阶段一询问**工作用户**（默认 dev，非法输入拒绝）→ **节点模式** → **远程协议**（ssh/http）→ **新用户密码/SSH 公钥**；阶段二询问**各步骤是否执行**（回车默认 Y）→ **国内镜像与 GitHub 代理**（默认 Y）→ 工具链逐项**安装/升级**（默认 N）→ 已存在文件/非空目录**覆盖确认**（默认保留）。
提示经 `/dev/tty` 读取，`curl | bash` 管道执行也可交互；完全无终端（CI）走安全默认。命令行 flag 优先级高于交互询问。

### 用户级工具链（阶段二逐项询问，默认 N 跳过）

Java+Maven（**清华镜像直装** Temurin 17 + Maven，`~/.local`）、Node.js LTS（nvm）、pnpm（corepack）、**uv（Python 版本/.venv/包唯一管理入口）**、**Go（golang.google.cn，独立工具）**、**PieKBS（Agent 知识搜索引擎，MCP；KB 落 `~/control-wiki` 并 git 版本化推送 control-wiki 远程仓，distill 走 LiteLLM `cheap` 模型）**、Docker rootless（需已装 docker）。
全部落在工作用户 home，不污染系统目录（direnv/tmux 例外：系统级包，阶段一安装，direnv 钩子由阶段二写入 bashrc）。

**国内镜像**（默认 Y）：npm→`registry.npmmirror.com`、pip→清华、uv→清华、Go 模块→`goproxy.cn`；可输入 **GitHub 加速代理前缀**（如 `https://gh.dpik.top`）作用于 nvm/uv/piekbs 下载。

pi 初始化生成 `~/.pi/settings.json`：**访问范围限定工作用户 home**，敏感路径列入 `protected_paths`；可选 **pi-di18n** 中文界面（`locale: zh-CN`）。

### 环境变量

| 变量 | 说明 |
|-----|------|
| `NPM_REGISTRY` | npm 镜像（默认 `https://registry.npmmirror.com`） |
| `PIP_INDEX_URL` / `UV_INDEX_URL` | pip / uv 镜像（默认清华） |
| `GH_PROXY` | GitHub 加速代理前缀（如 `https://gh.dpik.top`） |
| `NVM_NODEJS_ORG_MIRROR` | nvm 下载 Node 的镜像（默认 `https://npmmirror.com/mirrors/node`） |
| `GIT_PROTO` / `GIT_REMOTE_HOST` / `GIT_REMOTE_BASE` | 仓库远程构造（ssh/http，默认 `github.com/obtstar`） |
| `CONTROL_WIKI_REMOTE` | PieKBS 知识库远程仓（默认 `$GIT_REMOTE_BASE/control-wiki.git`） |
| `LITELLM_ENDPOINT` | LiteLLM 代理地址（默认 `http://litellm.internal:4000`） |

### 远程校验命令

```bash
# 阶段一校验（任意机器）
ssh user@pc-01 'curl -fsSL https://raw.githubusercontent.com/obtstar/control-center/main/scripts/init-env.sh | bash -s -- --check'

# 阶段二校验（已初始化机器，以 dev 执行）
ssh dev@pc-01 'bash ~/control-center/scripts/setup-env.sh --check'
```

输出三级：**PASS** 正常 / **WARN** 可择情处理 / **FAIL** 必须修复。

### 卸载（scripts/uninstall-env.sh）

逐项提示删除全部产物（compose 容器 → 目录/配置 → bashrc 挂载与钩子 → 用户），未确认项一律保留：

```bash
sudo bash scripts/uninstall-env.sh              # 编排节点，逐项交互确认（需 root）
sudo bash scripts/uninstall-env.sh --executor   # 执行节点（仅删 agent 用户）
sudo bash scripts/uninstall-env.sh --yes        # 全部确认（非交互，慎用）
```

删除 `control-center` 前检查未提交/未推送的 Git 更改并告警；用户清理为**工作用户 + `agent`**，工作用户 home 即环境基目录时连 home 一并删除（`userdel -r`）。

### 注意事项

- 阶段一需 root（创建用户、目录属主）；阶段二以工作用户身份运行，**无需 root**
- 基目录恒为 `/home/<owner>`（默认 `dev`），无其他覆盖入口
- Python 无需系统级准备：版本与 `.venv` 均由 uv 管理
- 工具链全部用户级（nvm/uv/Go/`~/.local`），卸载时随 home 清理
- executor 初始化后：在 `registry/executors.yaml` 登记本机 → 将签发的 token 写入 `~/executor/.env` 的 `EXECUTOR_TOKEN` → 启动 executor 服务
- 密钥只进 `.env`（600 权限），不进 bashrc、不进 Git

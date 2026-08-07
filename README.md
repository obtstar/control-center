# control-center

Agent 平台控制中心仓库：设计开发控制文档 + 任务编排配置 + 注册表（**无代码实现**）。
架构文档见 [docs/architecture/](docs/architecture/README.md)。

## 目录

| 目录 | 内容 |
|-----|------|
| `docs/architecture/` | 架构文档集（00-17，索引见其中 README） |
| `orchestration/` | 任务编排配置：`prompts/`、`skills/`、`workflows/` |
| `registry/` | 注册表：`repos.yaml`（仓库注册）、`executors.yaml`（执行节点登记） |
| `scripts/` | 环境初始化脚本 `init-env.sh`、卸载脚本 `uninstall-env.sh` |
| `control-center.code-workspace` | VS Code 多根目录工作区（control-center + 平台仓库 + Worktree 根），WSL 中用 `code control-center.code-workspace` 打开 |

## 环境初始化脚本（scripts/init-env.sh）

### 使用

```bash
# 编排节点初始化（第一台，交互式；-E 保留 GIT_PROTO 等环境变量与 SSH agent）
sudo -E bash scripts/init-env.sh

# 执行节点初始化（后续办公 PC）
sudo -E bash scripts/init-env.sh --executor

# 环境校验（不初始化，非 root 也可用）
bash scripts/init-env.sh --check

# 卸载（逐项确认）
sudo bash scripts/uninstall-env.sh
```

两种模式：

| 模式 | 用途 | 命令 |
|-----|------|------|
| 编排节点（第一台） | 目录结构、Linux 用户、venv、pi/openskills、仓库克隆/骨架、compose 测试环境 | `sudo -E bash scripts/init-env.sh` |
| 执行节点（后续 PC） | executor 工作区、`agent` 账号、工具链 | `sudo -E bash scripts/init-env.sh --executor`（交互询问服务端地址） |

### 交互式流程

tty 交互运行时依次询问：**工作用户**（默认 dev）→ **节点模式**（编排/执行）→ **各步骤是否执行**（目录结构/用户配置/工具链/镜像/venv/Agent 工具/仓库/compose，回车默认 Y）→ 工具链逐项**安装/升级**（默认 N）→ **国内镜像**（默认 Y）→ 已存在文件**覆盖确认**（默认保留）。
完成后若是从其他账号 sudo 初始化，会询问是否**迁移其 `~/control-center` 克隆到工作用户**（有未提交更改时自动取消）以及是否**立即 `su - dev` 切换**。
提示经 `/dev/tty` 读取，`curl | bash` 管道执行也可交互；仅完全无终端（CI）时走安全默认：参数取 flag/env、步骤全执行、覆盖与升级跳过。命令行 flag 优先级高于交互询问。

### 选项

| 选项 | 说明 |
|-----|------|
| `--owner NAME` | 工作用户（默认 `dev`；root 运行且不存在时自动创建，其 home 即环境基目录） |
| `--executor` | 执行节点模式 |
| `--control-api URL` | 编排节点地址（executor 模式，不传则交互询问） |
| `--skip-users` / `--skip-repos` / `--skip-compose` / `--skip-tooling` | 分步跳过 |
| `--check` | **仅环境校验，不执行初始化**（非 root 仅支持此模式） |

初始化过程中会逐项询问安装**用户级**语言/框架（默认 `N` 回车跳过）：
Java+Maven（SDKMAN!）、Node.js LTS（nvm）、pnpm（corepack）、**uv（Python 版本/.venv/包唯一管理入口）**、Docker rootless（需已装 docker）。
全部落在工作用户 home，不污染系统目录。`.venv` 由 `uv venv` 创建。

随后会询问是否配置**国内镜像加速**（默认 `Y` 回车确认）：npm→`registry.npmmirror.com`（用户级）、pip→清华（`~/.config/pip/pip.conf`）、uv→清华（`~/.config/uv/uv.toml`）；并可输入 **GitHub 加速代理前缀**（如 `https://gh.dpik.top`），作用于 nvm/uv 安装器下载（nvm 的 Node 二进制固定走 `npmmirror.com/mirrors/node`）。

### 环境变量

| 变量 | 说明 |
|-----|------|
| `NPM_REGISTRY` | npm 内网镜像（安装 pi/openskills 用） |
| `PIP_INDEX_URL` | pip 内网镜像（venv 装依赖用），未设置时默认清华镜像 |
| `LITELLM_ENDPOINT` | LiteLLM 代理地址（默认 `http://litellm.internal:4000`） |
| `GIT_REMOTE_BASE` | 仓库远程地址全量前缀：远程已有内容时克隆；远程为空时本地建骨架并推送 main/dev |
| `GIT_PROTO` / `GIT_REMOTE_HOST` | 未设 `GIT_REMOTE_BASE` 时按协议构造前缀：`ssh`→`git@HOST`、`http`→`https://HOST`（HOST 默认 `github.com/obtstar`）；交互运行时会提示 1) ssh / 2) http 二选一 |
| `GH_PROXY` | GitHub 加速代理前缀（如 `https://gh.dpik.top`），nvm/uv 安装器下载走代理；交互镜像确认时也可输入 |
| `NVM_NODEJS_ORG_MIRROR` | nvm 下载 Node 的镜像（默认 `https://npmmirror.com/mirrors/node`） |

### 远程校验命令

不初始化、只巡检目标机器环境（预检 + 后检）：

```bash
# 方式一：ssh 远程执行（脚本已在目标机，随 control-center 仓库克隆）
ssh user@pc-01 'bash ~/control-center/scripts/init-env.sh --check'

# 方式二：从 Git 仓库拉取最新脚本直接执行（不落盘）
curl -fsSL https://raw.githubusercontent.com/obtstar/control-center/main/scripts/init-env.sh | bash -s -- --check

# 方式三：远程拉取并执行
ssh user@pc-01 'curl -fsSL https://raw.githubusercontent.com/obtstar/control-center/main/scripts/init-env.sh | bash -s -- --check'
```

输出三级：**PASS** 正常 / **WARN** 可择情处理（如 token 占位符、可选工具缺失）/ **FAIL** 必须修复。

### 卸载（scripts/uninstall-env.sh）

逐项提示并删除初始化创建的全部产物（compose 容器 → 目录/配置 → bashrc 挂载行 → `agent` 用户），未确认项一律保留：

```bash
sudo bash scripts/uninstall-env.sh              # 编排节点，逐项交互确认（需 root）
sudo bash scripts/uninstall-env.sh --executor   # 执行节点（仅删 agent 用户）
sudo bash scripts/uninstall-env.sh --yes        # 全部确认（非交互，慎用）
```

**卸载需 root**（删除用户及其属主目录）；基目录由 `--owner` 推导（默认 `dev` 的 home）。

删除 `control-center` 前会检查未提交/未推送的 Git 更改并告警；用户清理为
**工作用户（默认 `dev`，`--owner` 指定）+ `agent` 两个用户**，工作用户 home
即环境基目录时连 home 一并删除（`userdel -r`）。

### 注意事项

- 初始化需 root（新建工作用户 `dev` 与 `agent`、设置目录属主）；非 root 仅支持 `--check` 校验
- 基目录由 `--owner` 推导（默认 `dev` 的 home），无其他覆盖入口
- Python 无需系统级准备：版本与 `.venv` 均由 uv 管理
- executor 初始化后：在 `registry/executors.yaml` 登记本机 → 将签发的 token 写入 `~/executor/.env` 的 `EXECUTOR_TOKEN` → 启动 executor 服务
- 密钥只进 `.env`（600 权限），不进 bashrc、不进 Git

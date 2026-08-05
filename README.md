# control-center

Agent 平台控制中心仓库：设计开发控制文档 + 任务编排配置 + 注册表（**无代码实现**）。
架构文档见 [docs/architecture/](docs/architecture/README.md)。

## 目录

| 目录 | 内容 |
|-----|------|
| `docs/architecture/` | 架构文档集（00-17，索引见其中 README） |
| `scripts/` | 环境初始化脚本 `init-env.sh` |

## 环境初始化脚本（scripts/init-env.sh）

两种模式：

| 模式 | 用途 | 命令 |
|-----|------|------|
| 编排节点（第一台） | 目录结构、Linux 用户、venv、pi/openskills、仓库骨架、compose 测试环境 | `sudo bash scripts/init-env.sh` |
| 执行节点（后续 PC） | executor 工作区、`agent` 账号、工具链 | `sudo bash scripts/init-env.sh --executor`（交互询问服务端地址） |

### 选项

| 选项 | 说明 |
|-----|------|
| `--home DIR` | 基础 home 目录（默认 `$HOME`） |
| `--executor` | 执行节点模式 |
| `--control-api URL` | 编排节点地址（executor 模式，不传则交互询问） |
| `--skip-users` / `--skip-repos` / `--skip-compose` / `--skip-tooling` | 分步跳过 |
| `--check` | **仅环境校验，不执行初始化** |

### 环境变量

| 变量 | 说明 |
|-----|------|
| `NPM_REGISTRY` | npm 内网镜像（安装 pi/openskills 用） |
| `PIP_INDEX_URL` | pip 内网镜像（venv 装依赖用） |
| `LITELLM_ENDPOINT` | LiteLLM 代理地址（默认 `http://litellm.internal:4000`） |

### 远程校验命令

不初始化、只巡检目标机器环境（预检 + 后检）：

```bash
# 方式一：ssh 远程执行（脚本已在目标机）
ssh user@pc-01 'bash ~/scripts/init-env.sh --check'

# 方式二：从 Git 仓库拉取最新脚本直接执行（不落盘）
curl -fsSL https://raw.githubusercontent.com/lbb4511/dr-ai/main/scripts/init-env.sh | bash -s -- --check

# 方式三：远程拉取并执行
ssh user@pc-01 'curl -fsSL https://raw.githubusercontent.com/lbb4511/dr-ai/main/scripts/init-env.sh | bash -s -- --check'
```

输出三级：**PASS** 正常 / **WARN** 可择情处理（如 token 占位符、可选工具缺失）/ **FAIL** 必须修复。

### 注意事项

- 编排节点需 root（创建 `agent` 用户）；executor 模式需 root（创建 `agent`）
- Debian/Ubuntu 先装 `sudo apt install python3-venv`
- executor 初始化后：在 `registry/executors.yaml` 登记本机 → 将签发的 token 写入 `~/executor/.env` 的 `EXECUTOR_TOKEN` → 启动 executor 服务
- 密钥只进 `.env`（600 权限），不进 bashrc、不进 Git

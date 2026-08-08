# 依赖支持清单

平台全部外部依赖与支持矩阵。变更任何一行前先查此表的影响面。
安装细节见 `scripts/`（两阶段初始化），配置模板见 `scripts/templates/`。

## 1. 平台仓库（GitHub obtstar，main+dev 双分支）

| 仓库 | 类别 | 本机路径 | 说明 |
|-----|------|---------|------|
| control-center | 引导仓 | `~/control-center` | 编排配置/registry/脚本（本仓） |
| control-api | 平台组件 | `~/control-api` | 编排后端（Java Spring Boot） |
| control-web | 平台组件 | `~/control-web` | 工作台前端（React 18 + PrimeReact + Vite） |
| control-db | 平台组件 | `~/control-db` | 数据库 DDL（SQLite 方言） |
| control-piekbs | Agent 基础设施 | `~/control-piekbs` | PieKBS 知识引擎（fork 锁定 pieteams/piekbs，升级走评审） |
| control-wiki | 知识库 | `~/control-wiki` | 平台级 KB（raw/wiki/schema 版本化，index 忽略） |

- gitdir 统一集中 `~/.repos/`（bare/分离式）；业务仓按需登记 `registry/repos.yaml`
- 业务仓分支模型：main/dev/release 只读，agent 仅写 `feature/*`，团队合并才算完成

## 2. 语言与构建工具链（全部用户级，落 `~/.local` / nvm / uv）

| 组件 | 版本来源 | 安装方式 | 镜像 |
|-----|---------|---------|------|
| JDK (Temurin 17) | Adoptium 目录实时解析 | 直装 `~/.local/lib/jdk17` | 清华 mirrors |
| Maven 3 | Apache 目录实时解析 | 直装 `~/.local/lib/maven` | 清华 mirrors |
| Node.js LTS | nvm | `~/.nvm` | npmmirror（NVM_NODEJS_ORG_MIRROR） |
| pnpm | corepack | 随 Node | npmmirror（COREPACK_NPM_REGISTRY） |
| uv | astral.sh 安装器 | `~/.local/bin` | 清华（UV_INDEX_URL + uv.toml） |
| Go 最新稳定 | golang.google.cn JSON API | `~/.local/lib/go` | goproxy.cn（go env -w） |
| Python | uv 管理 | `uv python` / `uv venv` | 清华 |

## 3. 系统级工具（阶段一，包管理器自适应）

| 命令 | apt | pacman | dnf | 用途 |
|-----|-----|--------|-----|------|
| direnv | direnv | direnv | direnv | 目录级环境切换（bashrc 钩子阶段二写入） |
| tmux | tmux | tmux | tmux | 终端复用（AI 会话保活） |
| rg | ripgrep | ripgrep | ripgrep | 检索 |
| fd/fdfind | fd-find | fd | fd-find | 查找 |
| jq | jq | jq | jq | JSON 处理 |
| gh | gh（部分源无，告警跳过） | github-cli | gh | GitHub CLI |
| delta | git-delta | git-delta | git-delta | git pager（side-by-side diff，主题条件注入） |

系统级必需（前置）：git、curl、docker（compose 测试环境，dev 已入 docker 组免 sudo）。

## 3.5 环境主题（用户级 dotfiles，模板 `scripts/templates/dotfiles/`）

| 文件 | 落地 | 说明 |
|-----|------|------|
| bashrc.block | `~/.bashrc` 标记段 | 托管块：control.env/JAVA_HOME/direnv/control.sh/welcome/venv 自动加载 |
| bash.sh | `~/.bashrc.d/control.sh` | Git 分支 PS1、现代别名、历史去重、PATH |
| welcome.sh | `~/.bashrc.d/welcome.sh` | 启动欢迎界面（<50ms 零网络，`CONTROL_WELCOME=0` 关闭） |
| gitconfig | `~/.gitconfig` | obtstar 身份 + ff/prune/别名；delta/gh 段条件注入 |
| tmux.conf | `~/.tmux.conf` | 鼠标/vi/Alt 切窗格/状态栏含分支 |
| direnv.toml | `~/.config/direnv/` | whitelist 体系目录 |
| inputrc | `~/.inputrc` | ignore-case 补全、↑↓ history-search |
| vimrc | `~/.vimrc` | 行号/2 空格缩进/搜索高亮 |

部署：`scripts/lib/dotfiles.sh`（`.theme-bak` 备份确认制）；venv 自动加载默认开（`CONTROL_VENV_AUTOLOAD=0` 关闭）。

## 4. Agent 组件（npm 用户级，registry=npmmirror）

| 组件 | 包 | 角色 | 版本策略 |
|-----|---|------|---------|
| pi | `@earendil-works/pi-coding-agent` | Agent 运行时（RPC 供 control-api 驱动） | npm latest，升级走初始化询问 |
| openskills | `openskills` | SKILL.md 技能包管理 | 同上 |
| openwiki | `openwiki` | 可选文档生产器（投喂项目级 KB raw/） | 同上；遥测默认关闭 |
| pi-di18n | `npm:pi-di18n`（pi install） | pi 中文界面 | 随 pi |

PieKBS 二进制：GitHub release（linux-amd64），`~/.local/bin/piekbs`，经 GH_PROXY 下载。

## 5. 数据与服务

| 项 | 形态 | 备份 |
|---|------|------|
| 运行时库 | SQLite `~/data/control.db`（WAL） | 每日文件复制，重置前须完成 work_log 归档 |
| FTS 索引（wiki/任务） | PieKBS index（派生物） | 不备份，重建 |
| PieKBS serve | `127.0.0.1:8766`（MCP `/mcp`） | config.yaml 模板渲染，token 占位 |
| docker compose | `~/deploy/`（web/api/测试运行时） | 测试环境专用 |
| wiki 共享 | SSH 端口转发（`ssh -L 8766`）或 host+api_key | — |

## 6. 外部服务（出网白名单）

| 服务 | 用途 | 接入 |
|-----|------|------|
| LiteLLM 代理 | 唯一模型出口（路由/fallback/预算） | `LITELLM_ENDPOINT`，别名 coding/cheap/heavy |
| Anthropic / GitHub Copilot / Moonshot(Kimi) | 模型后端（经 LiteLLM） | 网关侧配置 |
| GitHub（obtstar） | 平台仓托管 | ssh/http，GH_PROXY 加速 |
| 团队 Git 服务器 | 业务仓 + MR 评审 | OpenAPI/Webhook，保护分支 |

## 7. 镜像/代理总表

| 生态 | 镜像 | 配置位置 |
|-----|------|---------|
| npm | registry.npmmirror.com | 用户级 npm config |
| Node 二进制 | npmmirror.com/mirrors/node | NVM_NODEJS_ORG_MIRROR |
| pip | pypi.tuna.tsinghua.edu.cn | ~/.config/pip/pip.conf |
| uv | 同上 | ~/.config/uv/uv.toml |
| Go 模块 | goproxy.cn,direct | go env -w |
| Go 安装包 | golang.google.cn | 下载源 |
| JDK/Maven | mirrors.tuna.tsinghua.edu.cn | scripts 直装脚本 |
| GitHub | gh.dpik.top（GH_PROXY，可选） | 安装器/克隆下载 |

## 8. 权柄与权限（依赖人/团队的前置条件）

| 前置 | 责任方 |
|-----|--------|
| 业务仓保护分支（main/dev/release 只读） | 团队 Git 管理员配置 |
| L1 需求文档（项目级 KB raw/ 投放） | 团队人（仅人可写） |
| MR 评审合并（`done_when: merged_by_teammate`） | 团队员工 |
| LiteLLM 模型配额/预算 | 网关管理员 |

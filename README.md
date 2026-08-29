# control-center

**团队项目中的个人 AI 助手**的控制面仓库：任务编排配置 + 环境拓扑注册表 + 环境脚本（无业务代码）。
架构文档全文见本仓 `docs/architecture/`（00~18 章）；control-wiki 仅存 piekbs 蒸馏产物。

## 平台定位

开发者个人拥有、在团队项目中使用的 AI 编码助手：**接入团队既有设施**（团队 Git 服务器、
团队 CI、团队 MR 评审流程），平台自身只做编排与知识管理。
**wiki 是唯一指令源，暂停是最高运行时权限，一切产出有据可依**（18 章权柄模型）。

- 业务仓在团队 Git 服务器（经 OpenAPI/Webhook 对接）；平台 6 仓在个人侧（本仓等）
- 构建/测试走**本地 docker 开发环境**（不接团队 CI，代码不出本机），测试报告驱动状态机
- MR 终审为**团队评审**（同事 approve），助手只发起 MR 并附测试报告与自评

## 仓库拓扑（GitHub obtstar）

| 仓库 | 类别 | 用途 |
|-----|------|------|
| `control-center` | 引导仓（本仓） | 编排配置 `orchestration/`、注册表 `registry/`、环境脚本 `scripts/` |
| `control-api` | 平台组件 | 编排后端（任务/状态机/审批/调度），Go（stdlib net/http + SQLite） |
| `control-web` | 平台组件 | 工作台前端（任务看板/审批/监视/Diff 预览），规划 React 18 + PrimeReact + Vite，当前为占位仓库 |
| `control-db` | 平台组件 | 数据库 DDL（SQLite 方言，见数据分层） |
| `control-piekbs` | Agent 基础设施 | PieKBS 知识引擎源码（MCP：`kb_search/kb_page/kb_add`） |
| `control-wiki` | 知识库 | piekbs 蒸馏产物（wiki/schema/models），Git 版本化 |

业务项目仓（如 `billing-core`）按需登记进 `registry/repos.yaml`，
项目级 KB 落 `~/wiki/<repo-key>/`（与平台 KB 分离）。

## 分支策略

六个平台仓统一：**只保留 `main` + `dev`**；远程默认 `main`，本地工作分支 `dev`。
不使用 feature/release 分支；任务分支仅存在于业务仓。

## 本机布局（gitdir 集中 + worktree 统一）

```
/home/dev/
├── .repos/                    # 全部 gitdir 集中（bare/分离式）
├── control-center/            # 本仓（.git 为指针文件）
├── control-api|web|db/        # 平台组件（顶级目录，--separate-git-dir）
├── control-piekbs/            # PieKBS 源码
├── control-wiki/              # piekbs KB（wiki/schema 蒸馏产物进 Git，index 忽略）
├── wiki/                      # 项目级 KB 根（每业务仓一个，按需）
├── wt/                        # 共享工作区根（dev+agent，2770 setgid）
│   ├── projects/<repo>/dev/   # 业务项目常驻工作区（不回收）
│   └── <repo>/TASK-*/         # 任务 worktree（7 天回收）
├── data/control.db            # SQLite 运行时层（可重置，见数据分层）
├── deploy/                    # docker compose 测试环境
└── scripts/                   # 本机运维脚本
```

## 环境初始化（两阶段）

```bash
# 阶段一（root，先落盘再执行：FINDING-053 拆分后需 source scripts/lib/，管道模式不可用）
curl -fsSL https://gh.dpik.top/https://raw.githubusercontent.com/obtstar/control-center/dev/scripts/init-env.sh -o /tmp/init-env.sh
sudo bash /tmp/init-env.sh --

# 阶段二（dev 身份，首次登录自动触发或手动）：镜像/仓库同步/工具链/PieKBS/pi/openwiki/compose
bash ~/control-center/scripts/setup-env.sh [--executor|--check|--skip-*]

# 卸载
sudo bash ~/control-center/scripts/uninstall-env.sh
```

- 仓库同步由 `registry/repos.yaml` 清单驱动（`wt/` 前缀 → bare+worktree，否则顶级目录）
- 工具链全用户级（nvm/uv/Go/`~/.local`），direnv/tmux/rg/fd/jq/gh 系统级（阶段一）
- 国内镜像全覆盖（npm/pip/uv/Go/Node/GitHub 代理，交互选择）
- 脚本工程化：`init-env.sh` 单文件 <300 行；`setup-env.sh` + `scripts/lib/*` 模块化；
  配置文件全部模板化（`scripts/templates/` → 渲染到 home，Git 管声明、home 放产物）
- 环境主题：`scripts/templates/dotfiles/` 8 件套（bashrc 托管块/欢迎界面/git/tmux/direnv/inputrc/vimrc），
  bashrc 标记段 upsert，venv 自动加载默认开，欢迎界面 `CONTROL_WELCOME=0` 可关

## 流水线（每阶段一审批闸）

声明式定义：`orchestration/workflows/pipeline.yaml`（热加载）

```
需求分析 → 审批 → 系统设计 → 审批 → 编码实现 → 审批 → 测试验证 → 审批
  → 待合并（测试全绿 + heavy 自评 = 自动质量关；GitLab 人工合并 = 终审）→ 交付
```

- 驳回附批注重做本阶段；测试驳回打回编码；审批全部记 `work_log`（hash 链）
- 可信阶段可配 `approval: auto`（逃生门）；超时 24h 不自动通过
- 任务级熔断：连败 3 次或 token 超阈值 → 自动暂停

## 权柄模型（18 章摘要，平台宪法）

```
L1 需求（仅人可写）> L2 概要设计 > L3 详细设计 > L4 代码
```

- **顺行可写，逆行禁止**：AI 顺流产出是本职；修改上级文档人指令也不行——只能出**不一致报告**（不一致点/原因/修改建议/影响范围）并暂停，人改 wiki 后恢复
- **有据可依**：一切产出必须引用 KB 依据（文档 ID+段落），检索无据 → 暂停，禁止凭空联想
- **AI 维护 ≠ AI 权柄**：piekbs 蒸馏/组织/索引可交给 AI，但条条可回溯 raw 原文
- **人的通道仅两条**：改 wiki（唯一指令途径）、暂停/恢复流水线（最高运行时权限）
- 项目级 KB 权柄 > 平台级规则

## 数据分层（频率决定存放）

| 层 | 内容 | 存放 |
|---|------|------|
| 权威（低频） | 代码、文档、编排配置、registry、task.md、KB | **Git** |
| 派生（读多） | wiki FTS 索引、任务看板索引 | SQLite（可随意重置重建） |
| 运行时（高频） | work_log 流水、任务状态机 | SQLite（`~/data/control.db`） |
| 归档 | log.jsonl（原始+链尾哈希）、work_report.md（蒸馏报告，引用链） | 事件触发归档回 **Git** 后 SQLite 方可重置 |

- **任务即文档**：`tasks/TASK-xxx/{task.md, design.md, report.md, log.jsonl}`，
  task.md frontmatter 携带状态，看板索引从文件重建
- hash 链跨重置续接（新周期首行 prev_hash 指向上期归档尾哈希）
- 个人本地版用 SQLite；规模化时配置切换 MySQL/PG（业务代码不动）

## AI 模型路由

```
pi（Agent 运行时，RPC 供 control-api 驱动）
  → 别名 coding/cheap/heavy → LiteLLM 网关（路由/fallback/预算/限流）
    → Anthropic / GitHub Copilot / Kimi(Moonshot) 等后端
```

pi 只做模型选择，路由全部在 LiteLLM；pi 配置 `~/.pi/`（models.json 指向网关，
settings.json 限定访问 home + protected_paths）。

## 文档与知识检索

架构文档（00-18 章）全文在本仓 `docs/architecture/`：
00 原则 / 02 分支与 worktree / 05 编排 / 08 数据模型 / 10 部署 / 14 多仓 / 16 权限 / **18 权柄与有据模型**。
经 PieKBS 蒸馏后可被 pi/Agent 以 MCP 直接检索（`kb_search`/`kb_page`）。
可选文档生产器 **openwiki**（LangChain）：在业务仓执行 `openwiki --update` 生成文档原稿，
投喂项目级 KB `~/wiki/<repo>/raw/` 后经 PieKBS 蒸馏入库（遥测默认关闭，provider 指向 LiteLLM）。

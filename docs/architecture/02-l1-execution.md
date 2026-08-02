# 02 多代码仓库 & Git Worktree 分支管理

系统管理**多个代码仓库**，每个仓库通过 **Git Worktree + 多分支策略** 实现任务的物理隔离与并行执行。

> 多仓库的注册、接入、配额与权限管理见 [14 多仓库管理](14-multi-repo.md)。

## 分支策略（四类分支）

| 分支 | 命名 | 用途 | 生命周期 |
|-----|------|------|---------|
| `main` | `main` | 生产主干，可发布基线 | 常驻 |
| `dev` | `dev` | 开发集成分支，日常合入 | 常驻 |
| `release` | `release/{version}` | 发布候选分支 | 发布后归档 |
| `feature` | `feature/{task-id}-{name}` / `bugfix/{task-id}-{name}` | 任务/缺陷分支 | 合并后删除 |

### 分支流转模型

```
feature/task-001 ─┐
feature/task-002 ─┼──→ dev ──→ release/1.0 ──→ main
bugfix/042 ───────┘
```

- **合入规则**：feature → dev（日常集成）→ release（发布候选）→ main（生产）
- **回滚**：release 出问题时从 main 或上一 release 打补丁，禁止直接改 main

## Worktree 策略

- 每个任务在对应代码仓库创建独立 Worktree：`~/wt/{repo}/{task-id}-{type}-{name}`（WSL home 下）
- Worktree 与分支一一对应，checkout 到 `feature/{task-id}` 分支
- 并发限制：同时活跃 worktree ≤ N（防资源耗尽）
- 生命周期：任务合并完成后保留 7 天归档，然后清理
- 主工作区 `main`/`dev` 常驻，禁止在常驻分支直接编码

```
控制中心后端 ──→ git worktree add ~/wt/repo-a/TASK-001-feature-report feature/TASK-001
             ──→ git worktree add ~/wt/repo-b/BUG-042-fix-npe bugfix/BUG-042
```

## 变更与合并流程（Code Repo 侧）

1. 控制中心创建任务 → 在目标仓库创建 `feature/{task-id}` 分支 + Worktree
2. Agent 在 Worktree 内编码、本地测试、commit
3. push 分支 → 通过仓库 OpenAPI 创建 MR（Merge Request）指向 `dev`
4. Web 端人工 Review Diff → 通过后合并 → 控制中心记录日志
5. 合入 `dev` 后触发增量索引（Webhook）

## 执行 Agent 职责

- 终端 CLI Agent（**pi.dev 为核心工具**），**自定义为兼容 Claude Code / VSCode Copilot 的 Agent 工作流**
- 模型统一经企业内 LiteLLM 代理外接：`claude-sonnet` / `claude-opus`（Anthropic）+ `copilot-chat`（GitHub Copilot）；业务调用用别名 `coding` / `cheap` / `heavy`，见 [04 AI 网关](04-l3-ai-gateway.md)
- 接收控制中心指令，操作 Worktree 与 Git
- 所有文件/Git 操作仅限分配的 Worktree 内执行；出站网络仅放行 LiteLLM 模型端点

## 工具通道（WSL CLI / VSCode / Web）

设计与开发测试在三条工具通道间分工，均基于 WSL Linux 环境：

| 活动 | 通道 | 说明 |
|-----|------|------|
| 编码/重构/单元测试 | **WSL CLI（pi.dev）** | Agent 在 WSL 内自动执行，操作 `~/wt/` Worktree |
| 人工编码/审查/微调 | **VSCode（Remote-WSL）** | 开发者经 VSCode 连接 WSL，浏览/编辑/调试 Agent 产出；VSCode Extension 负责路径转换与 Diff 预览同步 |
| 设计文档/影响分析/RAG 检索 | **Web 客户端** | 设计者工作台 + Agent 生成（经 WSL CLI 提交 MR） |
| 测试执行（集成/回归/静态检查） | **WSL CLI** | Agent/CI 在 WSL 内运行测试命令，报告回传 Web 测试者工作台 |
| 审核/闸门/审计 | **Web 客户端** | Diff 预览、批注、阶段审批、审计检索 |

> 原则：**自动化执行一律走 WSL CLI（pi.dev）**，人工交互编码用 VSCode（Remote-WSL），设计文档与人工审核走 Web。三条通道共享同一 WSL 文件系统与 `~/wt/`/`~/repos/` 布局（见 [13.1](13-repo-template.md#131-wsl-开发环境目录架构以-linux-home-为基础)）。

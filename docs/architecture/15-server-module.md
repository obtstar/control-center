# 15 服务器模块设计（control-api）

## 15.1 概述

服务器模块即平台后端 `control-api`（Java Spring Boot），是系统唯一的后端服务，运行于 WSL Linux，负责任务编排、瀑布状态机、多仓库管理、RAG、排班、审核与审计。运行路径全部基于 WSL home（`~/`）布局，见 [13-repo-template.md](13-repo-template.md#131-wsl-开发环境目录架构以-linux-home-为基础)。

```
Web (control-web, React) ──REST──→ control-api (Spring Boot) ──→ MySQL (control-db)
                                      │
                                      ├── LiteLLM ──→ Anthropic / GitHub Copilot（外接）
                                      ├── Milvus（RAG 向量）
                                      ├── Git 本地操作（~/repos、~/wt）
                                      └── 各代码仓库 OpenAPI（分支/MR/Webhook）
```

## 15.2 服务器模块结构（Java 包结构）

```
control-api/                          # 服务器模块（代码仓库）
├── pom.xml
└── src/main/java/com/xxx/control/
    ├── ControlApplication.java
    ├── controller/                   # REST API 层
    │   ├── TaskController.java
    │   ├── ApprovalController.java
    │   ├── RepoController.java
    │   ├── AuditController.java
    │   ├── RagController.java
    │   └── AgentController.java
    ├── service/                      # 业务服务（15.3）
    ├── repository/                   # Spring Data JPA
    ├── entity/                       # 实体（与 control-db DDL 对齐）
    ├── dto/                          # 请求/响应对象
    ├── scheduler/                    # 定时任务（Spring Scheduling / Quartz）
    ├── config/                       # Security、Web、数据源、LiteLLM、Milvus
    ├── common/                       # 通用工具、异常、审计切面
    └── agent/                        # CLI Agent（pi.dev）对接
```

## 15.3 业务服务模块

| 模块 | 包 | 职责 |
|-----|-----|------|
| 任务管理 | `service/task` | 任务创建、分解、状态流转 |
| 工作流 | `service/workflow` | 瀑布状态机、阶段闸门（Approval Gate） |
| 审核 | `service/approval` | 审核队列、批注、修正循环 |
| 排班 | `service/schedule` | 排班权限控制（READ_ONLY / AUTO_TASK / FULL） |
| 多仓库 | `service/repo` | 仓库注册、OpenAPI 接入、状态同步 |
| Worktree | `service/worktree` | Worktree 创建/回收/归档，配额控制 |
| RAG | `service/rag` | 文档/代码增量索引、检索、Milvus 对接 |
| Agent | `agent` | pi.dev 指令下发、执行结果回传 |
| 执行节点 | `service/executor` | executor 注册/心跳/任务派发/结果回收（无 CI 产品时替代 CI Runner，见 [10 executor 代理](10-deployment.md#执行节点实现executor-代理无-ci-产品复用办公-pc)） |
| 审计 | `service/audit` | 工作记录写入（work_log）、状态哈希校验 |
| 工作报告 | `service/report` | 定时聚合 work_log → LLM 生成摘要 → work_report（日报/周报/任务报告） |
| 自我升级 | `service/selfupgrade` | 执行日志分析、Prompt/Skill 热更新 |

## 15.4 路径与环境（基于 WSL home）

| 配置项 | 值 | 说明 |
|-----|-----|------|
| WSL home | `/home/dev` | 开发环境基础目录 |
| 代码仓库根 | `~/repos` | control-api / control-web / control-db / 业务仓库 |
| Worktree 根 | `~/wt` | 任务物理隔离目录 |
| 数据卷 | `~/data/mysql`、`~/data/milvus` | 本地服务数据 |
| 日志 | `~/logs` | 服务运行日志 |
| 编排配置 | `~/control-center/orchestration` | 状态机/排班/Prompt 配置（从控制中心仓库加载） |

```yaml
# application.yml（片段）
control:
  home: /home/dev
  repos-root: /home/dev/repos
  worktree-root: /home/dev/wt
  orchestration-dir: /home/dev/control-center/orchestration
```

## 15.5 REST 接口概览

| 端点 | 说明 |
|-----|------|
| `GET/POST /api/tasks` | 任务查询/创建，含状态流转 |
| `POST /api/approvals/{id}/decide` | 阶段闸门审批/拒绝 |
| `GET/POST /api/repos` | 代码仓库注册与接入 |
| `GET /api/audit` | 工作记录（work_log）检索 |
| `GET/POST /api/reports` | 工作报告查询/提交（work_report，service/report 定时生成） |
| `GET /api/rag/search` | RAG 语义检索 |
| `POST /api/agents/{agentId}/run` | 下发 Agent（pi.dev）指令，返回结果 |
| `POST /api/agents/register` | executor 注册（能力标签 + 槽位数），返回 executorId；注册后为 PENDING，管理员审批通过后激活（准入流程同 14.8 仓库接入） |
| `POST /api/agents/{executorId}/heartbeat` | executor 心跳（在线状态、空闲槽位），离线自动剔除 |
| `POST /api/agents/{executorId}/poll` | executor 长轮询领取执行任务（按标签/槽位/排班匹配） |
| `POST /api/agents/{executorId}/report` | executor 回传执行结果（日志、测试报告、状态哈希），写 `work_log` 驱动状态机 |
| `POST /api/repos/{key}/webhook` | 代码仓库 Webhook 入口 |

## 15.6 外部集成

| 集成 | 方式 | 用途 |
|-----|------|------|
| MySQL | JDBC（control-db 提供 DDL） | 元数据、工作记录、排班、审计 |
| Milvus | gRPC/REST | RAG 向量检索 |
| LiteLLM | OpenAI 兼容 REST | 统一路由外接 Anthropic / GitHub Copilot，不跑本地模型 |
| Git | 本地 git 命令（JGit/CLI） | Worktree、分支、提交操作 |
| 代码仓库 | 各仓库 OpenAPI（GITLAB 等） | 分支/MR/Webhook/状态查询 |
| CI Runner | 仓库 CI（Webhook 触发 + 结果回传） | 构建/测试在执行节点运行，编排节点不跑重负载（见 [10 节点拆分](10-deployment.md#节点拆分编排节点-vs-执行节点)） |
| CLI Agent | pi.dev（WSL 终端，兼容 Claude Code / Copilot） | 编码、测试、文件操作执行 |

## 15.7 与编排配置的关系

- 瀑布状态机、排班策略、Prompt、Skill 定义存于控制中心仓库 `orchestration/`，非服务器代码
- 服务器启动时加载 `~/control-center/orchestration/`，支持热加载（免重启）；**生效顺序：MR + 双人审批 → 灰度发布 → 热加载**，热更新不绕过审批与灰度（07.3）
- 配置变更经控制中心 MR + 双人审批后发布，服务器拉取生效

## 15.8 与 Linux 权限管理的关系

- Agent 指令由控制中心以**对应排班时段的 Linux 系统用户**（`agent-readonly` / `agent-auto` / `agent-maintenance`）下发执行，见 [16 Linux 权限管理](16-linux-permissions.md)
- 服务器校验"应用层排班权限 + Linux 用户身份 + 目标路径授权"三重匹配后才派发任务
- control-api 容器不直接创建进程：本机任务经宿主机 systemd 服务执行，构建/测试经 executor / CI Runner 执行节点运行（见 [16.8](16-linux-permissions.md#168-执行节点executor-pc权限模型)）

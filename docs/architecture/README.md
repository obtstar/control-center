# 企业内部项目级 Agent 架构文档

> 面向内网部署的企业级 AI Agent 平台，覆盖设计开发控制、任务执行、人工审核、审计追溯的完整闭环。
> 架构形态：**一个独立控制中心仓库**（仅设计/控制文档 + 编排配置，无代码）+ **多个代码仓库**（平台实现 `control-api/control-web/control-db` + 业务代码，Git Worktree 多分支管理）。**db/backend/frontend 均在代码仓库中**，**仅内部设计（详细设计）与代码同库**，概要/外部设计集中于控制中心。

## 文档索引

| 编号 | 文档 | 内容 |
|-----|------|------|
| 00 | [设计原则](00-principles.md) | 核心原则：AI 驱动执行、Git 唯一可信源、数据内网 AI 外接受控、审计不可篡改等 |
| 01 | [总体架构](01-overview.md) | 控制中心仓库 + 多代码仓库总体架构与集成对象 |
| 02 | [多代码仓库与分支管理](02-branch-worktree.md) | Git Worktree 多分支策略：main / dev / release / feature |
| 03 | [设计开发控制 & 文档管理](03-doc-management.md) | 概要/外部设计集中于控制中心、**内部设计与代码同库**、OpenAPI 集成、RAG 任务管理 |
| 04 | [AI 网关层](04-ai-gateway.md) | 消费企业内 LiteLLM 代理（api.anthropic.com + ghe.com 企业版），模型路由/降级/预算优化 |
| 05 | [Agent 编排层](05-orchestration.md) | Java Spring 任务管理、瀑布状态机、排班权限、自我升级 |
| 06 | [Web 管理端](06-web.md) | React + PrimeReact + Vite：看板、闸门、审核、排班、审计 |
| 07 | [工作流](07-workflows.md) | 瀑布开发、功能追加、Bug 修复、自我升级四类工作流 |
| 08 | [数据模型与排班](08-data-model.md) | MySQL DDL/DML：任务、工作记录、审核、排班、文档、工作报告表 |
| 09 | [数据流示例](09-data-flow.md) | 功能追加全流程端到端示例 |
| 10 | [内网部署](10-deployment.md) | docker-compose 模拟综合测试环境（非生产形态）、测试/生产边界、编排/执行节点拆分、executor 代理（复用办公 PC）、资源分配 |
| 11 | [安全与合规](11-security.md) | 风险清单与对策、审计合规 |
| 12 | [实施路径](12-roadmap.md) | 三期交付计划与里程碑 |
| 13 | [仓库模板](13-repo-template.md) | 控制中心仓库（无代码实现）、平台/业务代码仓库模板、提交/MR/pre-commit 规范 |
| 14 | [多仓库管理](14-multi-repo.md) | 仓库注册表、统一接入、跨仓库任务、配额与仓库级权限 |
| 15 | [服务器模块](15-server-module.md) | control-api 后端模块：包结构、业务服务、WSL 路径、REST/集成 |
| 16 | [Linux 权限管理](16-linux-permissions.md) | 用户/组规划、Agent 沙箱、sudoers 白名单、权限矩阵、双重校验 |
| 17 | [客户端/服务端设计](17-client-server-design.md) | 能力域 API + RBAC；设计者/开发者/测试者三工作台；管理者与客户访问 |

## 技术栈速览

- **前端**：React + PrimeReact + Vite + Nginx（内网）
- **后端**：Java Spring Boot（Spring MVC + Data JPA/MyBatis + Security + Scheduling）
- **数据库**：MySQL（DDL/DML 版本化管控）
- **执行层**：pi.dev 核心工具（兼容 Claude Code / VSCode Copilot）+ Git Worktree（main/dev/release/feature）
- **AI**：消费企业内 LiteLLM 代理（不重复部署，api.anthropic.com + ghe.com 企业版）；Milvus（向量库）
- **文档**：概要/外部设计集中于控制中心；**仅内部设计随业务代码同库**，Git 版本化，MR + 审核
- **集成**：代码仓库 OpenAPI + Webhook + RAG

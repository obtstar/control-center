# 14 多仓库管理设计

平台以**一个独立控制中心仓库 + N 个代码仓库**为形态（代码仓库含平台实现 `control-api/control-web/control-db` 与业务代码仓库）。

> **边界声明**：`control-center` 为**独立仓库**，仅承载设计开发控制文档与任务编排配置（**无代码实现**），**不纳入** `repository` 注册表，也不作为被调度/执行对象；本文件所述的多仓库管理仅针对**代码仓库**（平台实现 + 业务）。

本文定义控制中心对多个代码仓库（平台实现 + 业务）的统一注册、接入、调度、检索与审计。

## 14.1 管理模型

```
                    ┌─────────────────────────────────────────┐
                    │  控制中心（repository 注册表 + 调度）      │
                    │  注册 · 配额 · 权限 · Webhook · RAG 聚合  │
                    └──────┬──────────────────────┬───────────┘
                           │ OpenAPI / Webhook     │
              ┌────────────┴──────┐    ┌───────────┴───────────┐
              ▼                   ▼    ▼                       ▼
        ┌────────────┐     ┌────────────┐     ┌────────────┐
        │ repo-a     │     │ repo-b     │ ... │ repo-n     │
        │ billing-   │     │ billing-   │     │ order-     │
        │ core       │     │ reports    │     │ service    │
        └────────────┘     └────────────┘     └────────────┘
         main/dev/release/feature（每仓库独立）
```

## 14.2 仓库注册表（MySQL DDL）

```sql
-- 7. 仓库注册表 repository（仅登记代码仓库：平台实现 + 业务；control-center 独立，不在此表）
CREATE TABLE `repository` (
  `id`             BIGINT       NOT NULL AUTO_INCREMENT,
  `repo_key`       VARCHAR(64)  NOT NULL COMMENT '业务标识 billing-core',
  `repo_name`      VARCHAR(128) NOT NULL,
  `git_url`        VARCHAR(255) NOT NULL COMMENT '内网 Git 地址',
  `api_type`       VARCHAR(16)  NOT NULL COMMENT 'GITLAB / GITHUB / GITEA',
  `api_endpoint`   VARCHAR(255) DEFAULT NULL,
  `api_token_ref`  VARCHAR(128) DEFAULT NULL COMMENT '密钥引用（Vault/环境变量），不存明文',
  `openapi_ref`    VARCHAR(255) DEFAULT NULL COMMENT 'OpenAPI 契约路径，供 RAG 采集',
  `default_branch` VARCHAR(64)  DEFAULT 'dev',
  `max_worktrees`  INT          DEFAULT 3 COMMENT '仓库级并发 Worktree 配额',
  `status`         VARCHAR(16)  DEFAULT 'ACTIVE' COMMENT 'ACTIVE / DISABLED',
  `owner`          VARCHAR(64)  DEFAULT NULL COMMENT '仓库责任人',
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_repo_key` (`repo_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='代码仓库注册表';
```

```sql
INSERT INTO repository (repo_key, repo_name, git_url, api_type, api_endpoint, default_branch, max_worktrees, owner)
VALUES
  ('billing-core',   '计费核心',   'git://git.internal/billing/billing-core.git',   'GITLAB', 'http://git.internal/api/v4', 'dev', 3, 'zhangsan'),
  ('billing-reports','计费报表',   'git://git.internal/billing/billing-reports.git', 'GITLAB', 'http://git.internal/api/v4', 'dev', 2, 'lisi'),
  ('order-service',  '订单服务',   'git://git.internal/order/order-service.git',     'GITLAB', 'http://git.internal/api/v4', 'dev', 3, 'wangwu');
```

## 14.3 管理能力

| 能力 | 说明 |
|-----|------|
| 仓库注册 | Web 端录入 git_url + API 接入信息，写入 `repository` 表 |
| 统一接入 | 通过仓库 OpenAPI 统一操作：分支创建、MR、Webhook、状态查询 |
| 跨仓库任务 | 一个任务可关联多个仓库，分别创建 Worktree，按依赖顺序执行 |
| 跨仓库检索 | RAG 聚合所有 ACTIVE 仓库代码 + OpenAPI 契约，支持跨仓库依赖定位 |
| 仓库级权限 | 角色/排班限定可操作仓库集合（如 A 项目组仅其仓库） |
| 状态同步 | Webhook 实时回传分支/MR/合并事件，驱动任务状态流转 |

## 14.4 命名规范（多仓库统一）

| 项 | 规范 | 示例 |
|-----|------|------|
| 仓库名 | `{system}-{module}` | `billing-core`、`order-service` |
| 常驻分支 | `main` / `dev` / `release/{version}` | `release/1.0.0` |
| 任务分支 | `feature/{task-id}-{name}`、`bugfix/{task-id}-{name}` | `feature/TASK-001-ai-report` |
| Worktree | `~/wt/{repo_key}/{task-id}-{type}-{name}` | `~/wt/billing-core/TASK-001-feature-ai-report` |

## 14.5 跨仓库任务流程

```
TASK-002：新增计费报表接口（修改 billing-core，依赖 order-service 契约）
1. 控制中心解析任务 → 检索 RAG 定位依赖 → 确认影响仓库
2. 为 billing-core 创建 feature/TASK-002-xxx + Worktree
3. order-service 仅只读（检索其 OpenAPI 契约，不改动）
4. billing-core 编码完成 → MR → 人工审核 → 合并 dev
5. 若 order-service 需契约变更 → 自动生成独立子任务走同流程
6. 两仓库合并事件经 Webhook 同步，任务进入测试验证
```

## 14.6 资源与并发控制

- 仓库级配额：`repository.max_worktrees` 限制单仓库活跃 Worktree 数
- 全局配额：同时活跃 Worktree ≤ N（跨仓库总和，防资源耗尽）
- 调度策略：任务入队 → 按仓库配额/排班权限分配 → Worktree 生命周期由控制中心统一回收
- 超限行为：任务排队等待，不抢占已分配 Worktree
- **与执行节点槽位对齐**：一个执行中任务同时占用 1 个 Worktree 配额与 1 个 executor/CI 槽位（见 10 章），调度按两者中较紧的约束限流

## 14.7 权限与审计

- **仓库级权限**：角色/排班表限定可操作仓库集合；越权操作被拒绝并记日志
- **审计**：`work_log` 记录 `repo_key`、`branch`、`worktree_path`、`git_commit`，关联任务与排班
- **删除保护**：`repository` 仅可 DISABLE，不物理删除，保留审计链条

## 14.8 仓库接入流程

```
1. 管理员在 Web 端注册仓库（repo_key、git_url、API 类型/端点、默认分支、配额）
2. 控制中心校验连通性（OpenAPI 握手）
3. 自动创建 Webhook（push / MR / merge 事件）
4. 触发全量 RAG 索引（代码 + OpenAPI 契约）
5. 状态置 ACTIVE → 可分配任务
```

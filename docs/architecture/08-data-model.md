# 08 数据模型与排班管理（MySQL DDL/DML）

以 **MySQL** 作为平台唯一元数据库。DDL/DML 脚本版本化存放在**平台数据库代码仓库（`control-db`）**中（与代码同源、可审计），不放在控制中心文档仓库。

## 核心表结构（DDL）

> 仓库注册表 `repository`（多仓库管理）见 [14 多仓库管理](14-multi-repo.md)。

```sql
-- 1. 任务表 task
CREATE TABLE `task` (
  `id`            BIGINT       NOT NULL AUTO_INCREMENT,
  `task_no`       VARCHAR(40)  NOT NULL COMMENT 'TASK-20260802-001',
  `type`          VARCHAR(20)  NOT NULL COMMENT 'FEATURE / BUGFIX / DOC',
  `title`         VARCHAR(200) NOT NULL,
  `status`        VARCHAR(32)  NOT NULL COMMENT '需求分析/系统设计/编码实现/测试验证/交付/已回退',
  `repo`          VARCHAR(128) DEFAULT NULL COMMENT '目标代码仓库',
  `branch`        VARCHAR(128) DEFAULT NULL COMMENT 'feature/task-001',
  `worktree_path` VARCHAR(255) DEFAULT NULL COMMENT '~/wt/repo-a/TASK-001-xxx',
  `priority`      TINYINT      DEFAULT 3,
  `assignee`      VARCHAR(64)  DEFAULT NULL COMMENT '责任人',
  `shift_id`      VARCHAR(64)  DEFAULT NULL COMMENT '排班关联',
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_task_no` (`task_no`),
  KEY `idx_status` (`status`),
  KEY `idx_repo` (`repo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='任务表';
```

```sql
-- 2. 工作记录表 work_log（不可篡改）
CREATE TABLE `work_log` (
  `id`                BIGINT      NOT NULL AUTO_INCREMENT,
  `timestamp`         DATETIME(6) NOT NULL,
  `task_id`           BIGINT      NOT NULL,
  `operator`          VARCHAR(64) NOT NULL COMMENT 'agent-001 / user-zhangsan',
  `shift_id`          VARCHAR(64) DEFAULT NULL,
  `action`            VARCHAR(64) NOT NULL COMMENT 'code_generate / review_submit ...',
  `repo`              VARCHAR(128) DEFAULT NULL,
  `branch`            VARCHAR(128) DEFAULT NULL,
  `worktree_path`     VARCHAR(255) DEFAULT NULL,
  `git_commit`        CHAR(40)     DEFAULT NULL,
  `model_used`        VARCHAR(64)  DEFAULT NULL COMMENT '经 LiteLLM 路由',
  `approval_id`       VARCHAR(64)  DEFAULT NULL,
  `before_state_hash` CHAR(64)     DEFAULT NULL,
  `after_state_hash`  CHAR(64)     DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_task` (`task_id`),
  KEY `idx_operator` (`operator`),
  KEY `idx_time` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作记录（审计）';
```

```sql
-- 3. 审核表 approval
CREATE TABLE `approval` (
  `id`           BIGINT      NOT NULL AUTO_INCREMENT,
  `approval_no`  VARCHAR(64) NOT NULL COMMENT 'APV-001',
  `task_id`      BIGINT      NOT NULL,
  `stage`        VARCHAR(32) NOT NULL COMMENT '需求分析/系统设计/编码实现/测试验证/交付',
  `approver`     VARCHAR(64) NOT NULL COMMENT '审核人',
  `status`       VARCHAR(16) NOT NULL COMMENT 'PENDING/APPROVED/REJECTED',
  `comment`      TEXT,
  `created_at`   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `decided_at`   DATETIME    DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_approval_no` (`approval_no`),
  KEY `idx_task_stage` (`task_id`, `stage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='阶段闸门审核记录';
```

```sql
-- 4. 排班表 shift_schedule
CREATE TABLE `shift_schedule` (
  `id`        BIGINT      NOT NULL AUTO_INCREMENT,
  `shift_id`  VARCHAR(64) NOT NULL COMMENT 'SHIFT-NIGHT-001',
  `name`      VARCHAR(64) NOT NULL,
  `time_range` VARCHAR(64) NOT NULL COMMENT '工作日09:00-18:00 / 夜间02:00-06:00 / 维护窗口',
  `permission` VARCHAR(16) NOT NULL COMMENT 'READ_ONLY / AUTO_TASK / FULL',
  `owner`     VARCHAR(64) COMMENT '责任人',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_shift_id` (`shift_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='排班表';
```

```sql
-- 5. 文档管理表 doc_management（仅内部设计与代码同库，概要/外部设计集中于控制中心）
CREATE TABLE `doc_management` (
  `id`          BIGINT      NOT NULL AUTO_INCREMENT,
  `doc_no`      VARCHAR(64) NOT NULL COMMENT 'DSGN-001',
  `doc_type`    VARCHAR(32) NOT NULL COMMENT '概要设计/外部设计/需求/内部设计',
  `repo_key`    VARCHAR(64) DEFAULT NULL COMMENT '来源仓库：控制中心或代码仓库',
  `repo_path`   VARCHAR(255) DEFAULT NULL COMMENT '仓库相对路径 docs/design/...',
  `source_commit` CHAR(40)  DEFAULT NULL COMMENT '版本化来源 commit',
  `content_hash` CHAR(64)   DEFAULT NULL COMMENT '内容摘要，用于增量索引',
  `vector_status` VARCHAR(16) DEFAULT 'PENDING' COMMENT 'PENDING/INDEXED/FAILED',
  `updated_at`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_doc_no` (`doc_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设计控制文档：概要/外部设计在控制中心，内部设计随代码仓库';
```

```sql
-- 6. 工作报告表 work_report（日报/周报/任务报告，由 work_log 聚合生成）
CREATE TABLE `work_report` (
  `id`           BIGINT       NOT NULL AUTO_INCREMENT,
  `report_no`    VARCHAR(64)  NOT NULL COMMENT 'RPT-20260802-001',
  `report_type`  VARCHAR(16)  NOT NULL COMMENT 'DAILY / WEEKLY / TASK',
  `task_id`      BIGINT       DEFAULT NULL COMMENT 'TASK 型报告的关联任务',
  `operator`     VARCHAR(64)  NOT NULL COMMENT '报告主体：agent-xxx / user-xxx',
  `shift_id`     VARCHAR(64)  DEFAULT NULL,
  `period_start` DATE         DEFAULT NULL,
  `period_end`   DATE         DEFAULT NULL,
  `summary`      TEXT COMMENT '汇总摘要（LLM 基于 work_log 生成）',
  `detail_json`  JSON         DEFAULT NULL COMMENT '结构化明细：任务/动作/模型/耗时/commit 列表',
  `status`       VARCHAR(16)  DEFAULT 'DRAFT' COMMENT 'DRAFT / SUBMITTED / APPROVED',
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_report_no` (`report_no`),
  KEY `idx_operator_period` (`operator`, `period_start`, `period_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='工作报告（自动汇总，不可篡改）';
```

## 工作日志与工作报告落地

| 数据 | 是否落地 | 位置 | 机制 |
|-----|---------|------|------|
| **工作日志（work_log）** | ✅ 已落地 | MySQL `work_log` 表 | `service/audit` 每次 Agent/用户操作实时写入，含任务/排班/模型/commit/状态哈希 |
| **工作报告（work_report）** | ✅ 落地 | MySQL `work_report` 表 | 定时任务（`service/report`）按日/周/任务聚合 `work_log` → LLM 生成摘要 → 落库，Web 端可查、可审批 |

### 工作报告生成流程

```
work_log（MySQL）──定时聚合──→ service/report 组装明细（detail_json）
    → LLM（经 LiteLLM，模型 cheap/coding）生成 summary
    → 写入 work_report（DRAFT）
    → Web 提交（SUBMITTED）→ 管理者审批（APPROVED）
```

> `work_report` 与 `work_log` 同为不可篡改审计数据：明细从日志派生，杜绝手工补报；报告不可物理删除，支持 SIEM 导出。

## 初始化数据（DML）

```sql
INSERT INTO shift_schedule (shift_id, name, time_range, permission, owner)
VALUES
  ('SHIFT-DAY-001',   '工作日', '工作日 09:00-18:00', 'READ_ONLY', 'zhangsan'),
  ('SHIFT-NIGHT-001', '夜间',   '夜间 02:00-06:00',   'AUTO_TASK', 'lisi'),
  ('SHIFT-MAINT-001', '维护',   '维护窗口',           'FULL',      'wangwu');
```

## 排班权限

| 时段 | Agent 权限 | 说明 |
|-----|-----------|------|
| 工作日 09:00-18:00 | 只读分析 | 禁止代码变更，仅检索/文档 |
| 夜间 02:00-06:00 | 自动化任务 | 测试生成、文档更新、低危重构 |
| 维护窗口 | 全权限（需审批） | 批量重构、依赖升级 |

## 审计要求

- 日志结构化存储于 MySQL `work_log`，禁止物理删除（软删除/归档），支持 SIEM 对接
- 操作绑定排班与责任人，`before/after_state_hash` 保证前后状态可校验
- DDL/DML 版本化入库 `control-db` 代码仓库，变更走 MR + 审核

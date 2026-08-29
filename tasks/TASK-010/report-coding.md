# TASK-010 report-coding.md

> 阶段：coding · 产出：commit + MR diff
> 日期：2026-08-29

## 交付内容

| 文件 | 操作 | 说明 |
|------|------|------|
| `docs/architecture/19-workbench-strategy.md` | 新增（88 行） | 决策记录：背景/决策（方案 A）/四维依据/约束声明/重估触发 |
| `docs/architecture/06-web.md` | +6 行 | 追加"双线定位"小节（control-web=审批唯一入口） |
| `docs/architecture/17-client-server-design.md` | +8 行 | 追加 §17.4 control-dsh-plugin 投影客户端 |
| `docs/architecture/README.md` | +2 行 | 索引补 18/19 章 |
| `tasks/TASK-010/constraint-note-TASK-009.md` | 新增（15 行） | TASK-009 执行范围约束摘要（M3 移除/凭据边界/工具面不变） |
| `tasks/TASK-010/{task,report-requirements,design}.md` | 入库 | 任务产物随 MR 提交（任务即文档） |

## Commit 与分支

- 分支：`feature/TASK-010-workbench-strategy`（从 dev 切出，worktree 隔离）
- Commit：`docs(TASK-010): 工作台形态决策——双线分工定位`（已 push 至 origin）
- **MR：待人工在 GitHub 创建**（`gh` 未认证、无 GIT_TOKEN；MR 终审属 merge 阶段 team_mr_review，Git 平台人工执行）
  - 建议 MR 标题：`docs(TASK-010): 工作台形态决策——双线分工定位`
  - base: `dev` ← head: `feature/TASK-010-workbench-strategy`

## 规约与质量

- 规模红线：全部新增/修改文件 ≤300 行（最大 104 行 design.md）；无代码文件（纯文档）
- control-center 无 pre-commit hook（AGENTS.md §6.2 仅 control-api/control-web 已装）；`check-conventions --staged` 报告 `scripts/init-env.sh` 436 行超限——**存量违规**（commit c95a46b 引入，与本任务无关，建议另立技术债条目）
- kb-sync.sh：27 对镜像同步完成（06/17/README 上游改动已镜像入 KB）
- reconcile：**五项全 PASS**（含 kb-mirror-freshness）

## 依据引用

- 05/06/15/17 章权柄文档（KB 检索校验存在，见 report-requirements.md §3）
- TASK-010 task.md（L1，人裁决方案 A）+ design.md（L2，已审批）

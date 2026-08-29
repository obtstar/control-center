# TASK-000014 影响分析报告（requirements）

> 任务：规约补强：control-center 补装 pre-commit hook
> 阶段：requirements · 日期：2026-08-29

## 1. 现状

- AGENTS.md §6.2：check-conventions hook 已装 control-api、control-web，**control-center 未装**
- FINDING-053（init-env.sh 436 行超限）已修复（拆分 272 行）→ 补装无阻塞
- `scripts/install-hooks.sh <repo>` 现成；`check-conventions.sh --staged` 已验证（FINDING-036 四幕实验法）

## 2. 影响面

| 项 | 影响 |
|----|------|
| 安装 | `bash scripts/install-hooks.sh control-center`（装 pre-commit 到 .repos/control-center.git/hooks） |
| 行为变化 | control-center 后续 commit 过红线检查（行数/gofmt/vet/eslint）——已无存量违规（053 修复） |
| 风险 | 若存在未发现的存量违规会拦 commit（可先 --staged 全仓预检） |
| 文档 | AGENTS.md §6.2 更新"三仓已装"（该文件不入 Git，本地更新） |

## 3. 验收

1. install-hooks.sh 执行成功，hook 生效（.git/hooks/pre-commit 存在）
2. 四幕验证（FINDING-036 法）：未跟踪不拦 / staged 行数拦 / staged eslint 拦 / 清洁通过
3. AGENTS.md §6.2 同步
4. 提交一条验证 commit（或说明）

## 4. 依据

- AGENTS.md §6.2；FINDING-036（hook 四幕验证法）；FINDING-053（清障完成）

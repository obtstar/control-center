---
task_id: TASK-000014
title: 规约补强：control-center 补装 pre-commit hook
repo_key: control-center
domain: backend-go
stage: deliver
status: delivered
priority: ""
authority: L1
archived: true
---

# 规约补强：control-center 补装 pre-commit hook

规约补强：control-center 补装 pre-commit hook。现状：AGENTS.md §6.2 仅 control-api/control-web 已装 check-conventions hook，control-center 未装（FINDING-053 拆分 init-env.sh 后已无障碍）。验收：①bash control-center/scripts/install-hooks.sh control-center 安装；②实测四幕：未跟踪不拦 / staged 行数拦 / staged eslint 拦 / 清洁通过（参照 FINDING-036 验证法）；③提交一条验证 commit（或说明跳过方式）；④AGENTS.md §6.2 同步"三仓已装"。

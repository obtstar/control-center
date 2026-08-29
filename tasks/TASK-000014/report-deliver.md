# TASK-000014 report-deliver.md

> 阶段：deliver · 日期：2026-08-29

## 任务

**规约补强：control-center 补装 pre-commit hook**

## 交付

- pre-commit hook 已装至 `/home/dev/.repos/control-center.git/hooks/pre-commit`（check-conventions --staged）
- 实测拦截：302 行文件提交被拒（无 commit 产生）；清洁路径 PASS
- AGENTS.md §6.2 本地同步"三仓已装"（文件不入 Git）

## 生命周期

requirements ✅ → design ✅ → coding ✅ → testing ✅（4/4）→ merge ✅ → deliver ✅

## 效果

control-center 与 control-api/control-web 同规约防护：规模红线/gofmt/vet/eslint 提交前拦截（staged 模式，不误拦他人脏文件——FINDING-036）。

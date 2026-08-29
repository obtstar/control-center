# TASK-010 report-testing.md

> 阶段：testing · 产出：测试报告
> 日期：2026-08-29 · 类型：纯文档任务（决策记录 + 架构文档声明），无代码/无 docker 依赖服务

## 验证项与结果

| # | 验证项 | 方法 | 结果 |
|---|--------|------|------|
| 1 | 合并后内容完整性 | dev（0808cdf，含 MR #1+#2）逐一检查 8 个交付文件存在 | ✅ 全在 |
| 2 | 引用链 | 06-web / 17-client-server-design / README 中 `19-workbench-strategy.md` 链接解析 | ✅ 3 处全可解析 |
| 3 | 规约红线（单文件 ≤300 行） | `wc -l` 全部交付文件 | ✅ 最大 104 行（design.md） |
| 4 | FINDING-053 台账登记 | `grep FINDING-053 docs/FINDINGS.md` | ✅ 1 条 |
| 5 | KB 镜像新鲜度 | `kb-sync.sh` 27 对 + `reconcile` kb-mirror-freshness | ✅ 首跑 WARN（合并前镜像旧哈希）→ 重跑后全 PASS |
| 6 | 文档↔事实对账 | `control_reconcile` 五项检查 | ✅ 全 PASS（backend/frontend/database/registry/kb-mirror） |
| 7 | 工作区卫生 | worktree 已回收、远程 feature 分支已删、主仓 index 对齐 HEAD | ✅ 无本任务残留 |

## 通过率

- 验证项：7/7 通过
- reconcile：5/5 PASS，零 WARN
- 无失败项；无需打回 coding

## 过程中修正的问题

1. **合并方向偏差**：feature 分支最初被合并到 main（MR #1）而非 dev → 用户以 MR #2（dev ← main）同步回 dev，本地已快进至 0808cdf，worktree 回收。
2. **kb-mirror 首跑 WARN**：kb-sync 曾在合并前执行（镜像旧版 06/17/README/FINDINGS）→ dev 合并后重跑 kb-sync.sh，镜像哈希对齐，reconcile 恢复全 PASS。

## 遗留（非本任务阻塞）

- FINDING-053（init-env.sh 436 行超红线）状态 open，待拆分或人裁决。
- control-web 工作区未提交：`vite.config.ts`（preview.proxy，TASK-010 落地支撑）+ TASK-008 半成品（未开工，游离 dev 工作区）。

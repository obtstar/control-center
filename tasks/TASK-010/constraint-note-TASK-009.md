# TASK-009 执行范围约束摘要（TASK-010 决策落地）

> 来源：TASK-010（工作台形态决策，2026-08-29 人裁决方案 A）
> 权威声明：[`docs/architecture/19-workbench-strategy.md`](../docs/architecture/19-workbench-strategy.md) §5
> 用途：TASK-009（插件深度集成 v0.2）审批/执行时可据此批注与约束设计、编码产物。

## 约束三条

1. **M3 移除**：`docs/ui-client-module.md` 的 M3（审批操作入口）从里程碑中移除/标注"不做"；M0-M2（只读投影：任务/审批/审计列表）为上限。
2. **凭据边界**：client 半区任何改动不得引入凭据（token）进入浏览器端逻辑；数据只经 host 代理（`/control/dashboard/api/*`）透传。
3. **工具面不变**：执行面工具（`control_task_*`，含 `control_task_action`）保持 host 侧（Node 半区），不因 UI 决策变化。

## 背景一句话

control-web 为审批操作唯一入口（角色路由 + work_log 审计）；插件定位 AI 执行面 + DSH GUI 只读投影，避免重复建设"凭据+角色+审计"审批面与 client bundle 构建链耦合。

---
task_id: TASK-010
title: 工作台形态决策：双线分工定位（control-web 为审批唯一入口，插件不做 UI M3）
repo_key: control-center
domain: wiki-authoring
stage: deliver
status: delivered
priority: ""
authority: L1
---

# 工作台形态决策：双线分工定位（control-web 为审批唯一入口，插件不做 UI M3）

背景：control-dsh-plugin（DSH 集成插件）与 control-web（独立工作台）功能存在重叠（任务/审批/审计视图），需明确双线定位，避免重复投资与安全边界弱化。

决策（2026-08-29 人裁决，方案 A）：
1. control-dsh-plugin 定位为 AI 执行面：control_* 工具 + 会话绑定 + 反向通知；client 半区仅保留 DSH GUI 内只读投影（任务/审批/审计列表，即 M1/M2），明确不做 M3（审批操作入口不进浏览器，凭据不进浏览器、不重复建设凭据+角色+审计审批面）；
2. control-web 定位为人的审批工作台唯一入口：审批操作（approve/reject/pause/resume/deliver）/看板/审计/KB/API 文档继续演进；TASK-008（AI 助手面板）按计划推进，形成"AI 会话内干活、人在工作台审批"闭环；
3. 产出：一份决策记录文档（含功能矩阵、安全边界、构建链耦合、成本对比四维依据）+ 对 TASK-009 执行范围的约束声明（M3 移除，只读投影保持）。

验收：决策记录落盘并引用真实依据（KB/架构文档）；TASK-009 后续阶段产物与"不做 M3"一致。

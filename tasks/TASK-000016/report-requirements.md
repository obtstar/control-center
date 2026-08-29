# TASK-000016 影响分析报告（requirements）

> 任务：TASK-008 Phase 2：内联 AI 操作
> 阶段：requirements · 日期：2026-08-29

## 1. 需求（TASK-008 Phase 2，design D4 预留）

1. TaskTable 每行"AI 协助"按钮（跳 /ai 带 selectedTaskId）
2. ApprovalDialog AI 建议（查看上下文给建议）
3. BoardPage 全局 AI 入口

## 2. 现状核对

| 项 | 现状 |
|----|------|
| AIPage | ✅ 已支持 `location.state.selectedTaskId`（TaskContextPanel 初始选中） |
| 全局 AI 入口 | ✅ AppLayout 导航"AI 助手"已有（TASK-008 Phase 1）——需求 3 已满足，无需重复 |
| TaskTable | 无 AI 列（有 onDeliver）——需加 |
| ApprovalDialog | 无 AI 建议——需加 |

## 3. 方案

| 需求 | 实现 |
|------|------|
| ① 行内 AI 按钮 | TaskTable 加"AI 协助"列：按钮 `navigate('/ai', { state: { selectedTaskId: row.task_id } })`——TaskTable 需注入 navigate（或用 useNavigate 组件内） |
| ② 审批 AI 建议 | ApprovalDialog 加建议区：显示"AI 建议"提示（查看 /ai 任务上下文）——轻量版：链接到 /ai 带任务；完整 AI 建议生成（调 LLM）超出 Phase 2 范围，标注递进 |
| ③ 全局入口 | ✅ 已满足（AppLayout 导航）——无需改动 |

## 4. 影响面

- control-web：TaskTable.tsx（+AI 列）、ApprovalDialog.tsx（+建议区）、测试
- 无后端/契约变更（纯前端导航）

## 5. 验收

1. 任务行有 AI 协助按钮 → 点击跳 /ai 且任务上下文选中
2. 审批对话框有 AI 建议提示（含跳转）
3. tsc/eslint/vitest/build 全绿

## 6. 依据

- TASK-008 design.md D4（Phase 2 预留）；task.md（Phase 2 条目）

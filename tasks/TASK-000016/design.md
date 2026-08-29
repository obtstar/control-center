---
task_id: TASK-000016
stage: design
authority: L2
title: TASK-008 Phase 2 内联 AI 操作 — 设计
---

# TASK-000016 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 设计

### 1.1 TaskTable AI 协助列

```tsx
// TaskTable.tsx
// 新列：AI 协助
<Column
  header="AI"
  body={(row: Task) => (
    <Button icon="pi pi-sparkles" size="small" text
      onClick={() => onAiAssist?.(row.task_id)} tooltip="AI 协助" />
  )}
/>
```

- TaskTableProps 加 `onAiAssist?: (taskId: string) => void`
- BoardPage 传 `onAiAssist={(id) => navigate('/ai', { state: { selectedTaskId: id } })}`（BoardPage 已有 navigate？无则 useNavigate 注入）

### 1.2 ApprovalDialog AI 建议区

```tsx
// 审批对话框底部加建议区（轻量版）
<Message severity="info" icon="pi pi-sparkles"
  content={<span>AI 建议：<Link to={`/ai`} state={{ selectedTaskId: item.task_id }}>查看任务上下文</Link></span>} />
```

- 完整 AI 建议生成（LLM 调用）标注递进（Phase 2 外）
- ApprovalDialog 需 react-router Link/useNavigate（或回调）

### 1.3 全局入口

- 已满足（AppLayout 导航），无改动

## 2. 验收映射

| 验收项 | 落实 |
|--------|------|
| 行内 AI 按钮跳转+上下文 | 1.1 + AIPage selectedTaskId |
| 审批 AI 建议 | 1.2 |
| 全局入口 | 已有 |
| 测试全绿 | 组件测试补（TaskTable/ApprovalDialog 渲染） |

---
task_id: TASK-000017
stage: design
authority: L2
title: 看板列下拉筛选 — 设计
---

# TASK-000017 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 设计（TaskTable.tsx）

```tsx
import { Dropdown } from 'primereact/dropdown'
// 唯一值（useMemo）
const uniq = (key: 'repo_key' | 'stage' | 'status' | 'updated_by') =>
  useMemo(() => [...new Set(tasks.map(t => t[key]).filter(Boolean))].sort(), [tasks, key])

// filterElement 工厂
const dropdownFilter = (options: DropdownFilterOptions, values: string[]) => (
  <Dropdown value={options.value} options={values}
    onChange={(e) => options.filterApplyCallback(e.value)}
    placeholder="全部" showClear className="w-full" />
)
```

列改动（4 列）：
- `repo_key`：`filterElement` + `filterMatchMode="equals"` + 移除默认文本 filter
- `stage` / `status` / `updated_by` 同

## 2. 验收映射

| 验收项 | 落实 |
|--------|------|
| 4 列下拉 + 唯一值 | useMemo 派生 + Dropdown |
| 精确匹配 + 清空 | equals + showClear |
| 测试全绿 | 组件测试（渲染/筛选） |

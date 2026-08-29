# TASK-000017 影响分析报告（requirements）

> 任务：看板筛选优化：仓库/阶段/状态/更新人列下拉框筛选
> 阶段：requirements · 日期：2026-08-29

## 1. 现状

TaskTable（DataTable filterDisplay="row"）7 列均有 `filter`（文本框筛选）：
- task_id/title/repo_key/stage/status/updated_by/updated_at

需求：repo_key/stage/status/updated_by 4 列改**下拉框**（精确匹配 + 唯一值选项 + 清空）。

## 2. 方案

PrimeReact DataTable `filterElement` 自定义筛选组件：

| 列 | filterElement | filterMatchMode |
|----|--------------|----------------|
| repo_key（仓库） | Dropdown（唯一值） | equals |
| stage（阶段） | Dropdown（唯一值） | equals |
| status（状态） | Dropdown（唯一值） | equals |
| updated_by（更新人） | Dropdown（唯一值） | equals |

- 唯一值：`useMemo` 从 tasks 派生（去重排序）
- Dropdown 带 `showClear`（清空恢复）
- task_id/title/updated_at 保持文本 filter

## 3. 影响面

- control-web TaskTable.tsx（单组件）+ 测试
- 无后端/契约变更

## 4. 验收

1. 4 列下拉筛选（选项=数据唯一值）
2. 精确匹配 + 清空恢复
3. tsc/eslint/vitest/build 全绿

## 5. 依据

- TaskTable.tsx 现状（filter 文本）；PrimeReact DataTable filterElement

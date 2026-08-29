# TASK-000017 report-coding.md

> 阶段：coding · 日期：2026-08-29

## 交付

**control-web [PR #12](https://github.com/obtstar/control-web/pull/12)**：TaskTable.tsx
- 仓库/阶段/状态/更新人 4 列 filterElement → Dropdown（useMemo 唯一值去重排序 + showClear + equals 精确匹配）
- task_id/title/updated_at 保持文本筛选

## 验证

tsc/eslint/vitest 34/34/build 全过。

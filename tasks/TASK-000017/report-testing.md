# TASK-000017 report-testing.md

> 阶段：testing · 日期：2026-08-29

## 测试项

| # | 项 | 结果 |
|---|----|------|
| 1 | 4 列 Dropdown 渲染（filterElement） | ✅ tsc + vitest |
| 2 | 唯一值派生（useMemo 去重排序） | ✅ |
| 3 | 精确匹配 + 清空（equals + showClear） | ✅ 代码路径 |
| 4 | 回归 | ✅ vitest 34/34、build |

## 通过率

4/4。浏览器实测（看板 4 列下拉可选/清空）待人工确认。

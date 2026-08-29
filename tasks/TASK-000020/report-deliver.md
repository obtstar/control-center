# TASK-000020 report-deliver.md

> 阶段：deliver · 日期：2026-08-29

## 任务

**任务看板：delivered 任务归档功能**

## 交付

- control-api c658ef2：archived frontmatter + action=archive + 列表过滤 + 契约
- control-web 5653604：delivered 行归档按钮 + gen:api
- 已部署；实测 TASK-000012 归档成功

## 生命周期

requirements ✅ → design ✅ → coding ✅ → testing ✅（6/6）→ merge ✅（dev 直推简化）→ deliver ✅

## 效果

看板 delivered 任务可一键归档（归档后从活跃看板移除；?archived=all 可查）；frontmatter 权威 + work_log 留痕。

## 依据

- task.md（L1）+ design.md；task_index 派生模型

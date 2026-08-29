---
task_id: TASK-008
stage: design
authority: L2
title: DSH 集成到 control-web：AI 助手面板 — 设计文档
---

# TASK-008 设计文档（L2）

> 输入：task.md（L1）+ report-requirements.md（影响分析，已审批）
> 依据：19-workbench-strategy.md（TASK-010 决策）、17-client-server-design.md §17.3、TASK-007 report-deliver（SSE 前置）

## 1. L1 需求映射

| L1 条目 | 设计项 | 落点 |
|---------|--------|------|
| Phase 1：/ai 路由 + AIPage + 上下文面板 + 对话面板 + 注入 | D1 页面架构 / D2 postMessage 契约 / D3 半成品恢复 | control-web src |
| Phase 2：内联 AI 操作（TaskTable/ApprovalDialog/BoardPage） | D4 递进项 | control-web 组件 |
| Phase 3：实时同步 | D5 复用 TASK-007 SSE | 已交付 |

## 2. 概要设计

### 2.1 D1 页面架构（/ai）

```
AIPage（/ai 路由，ProtectedRoute 内）
├─ 头部：标题 + DSH 状态提示（探测 3080 可达性）
├─ 左栏（w-3）：TaskContextPanel —— 任务列表/选中 → 上下文注入
└─ 右栏（flex-1）：iframe src="http://127.0.0.1:3080"（DSH 完整对话界面）
    └─ postMessage 双向通信（D2）
```

- iframe 嵌入 DSH（无 frame 限制已实测）；DSH 提供完整对话/工具调用 UI，零协议开发
- 上下文注入：选中任务 → postMessage 给 iframe → DSH 侧（可选：注入 system/上下文）——Phase 1 注入到 iframe URL query（`?task=<id>`）最简；进阶用 postMessage

### 2.2 D2 postMessage 契约

| 方向 | 消息 | 载荷 |
|------|------|------|
| control-web → DSH iframe | `{type:'control-task-context', taskId, stage, status}` | 任务上下文注入 |
| DSH iframe → control-web（可选） | `{type:'control-dsh-ready'}` 就绪信号 | 状态同步 |

- 目标 origin：`http://127.0.0.1:3080`（iframe src 同源校验）
- Phase 1 最小实现：选中任务 → postMessage 注入；DSH ready 信号用于状态提示

### 2.3 D3 半成品恢复清单

自 `feature/TASK-008-ai-panel`（be8aa76）恢复并修复：

| 文件 | 处理 |
|------|------|
| src/pages/AIPage.tsx | 恢复 + 修复"DSH 加载失败"（根因排查：iframe 时序/路径/错误捕获） |
| src/components/DSHIntegrationPanel.tsx + DSHSettingsPanel.tsx | 恢复（已拆分合规） |
| src/components/TaskContextPanel.tsx | 恢复 |
| src/router/router.tsx | 加 /ai 路由（已随 revert 移除） |
| src/pages/BoardPage.tsx / TaskTable.tsx / AppLayout.tsx | Phase 2 递进（本阶段仅恢复 Phase 1 必要项） |
| dsh-plugin/ 包 | 评估（Phase 2 内联 AI 可能经它；Phase 1 可先不恢复） |

### 2.4 D4 Phase 2 递进（设计预留，Phase 1 后）

- TaskTable 行内 AI 协助按钮 → 跳 /ai 带 selectedTaskId（location.state）
- ApprovalDialog AI 建议（查看任务上下文后提示）
- BoardPage 全局 AI 入口

### 2.5 D5 Phase 3（已就绪）

- TASK-007 SSE（useTaskEvents）已实现看板/审批页自动刷新 → 操作后刷新无需新开发
- Toast 通知：SSE 事件到达时提示（可复用现有 Toast 基建）

## 3. 详细设计

### 3.1 文件改动清单（coding 阶段）

| 文件 | 操作 |
|------|------|
| src/pages/AIPage.tsx | 自 feature 分支恢复 + 修复 |
| src/components/{DSHIntegrationPanel,DSHSettingsPanel,TaskContextPanel}.tsx | 恢复 |
| src/router/router.tsx | + /ai 路由 |
| src/App.tsx / AppLayout.tsx | 导航入口（AI 助手） |
| src/hooks/useDSHStatus.ts（新） | 3080 可达性探测（AIPage 状态提示） |

### 3.2 "DSH 加载失败"修复预案

| 假设根因 | 验证/修复 |
|---------|----------|
| iframe src 路径/端口 | 确认 `http://127.0.0.1:3080/`（DSH 首页） |
| iframe 内 DSH JS 报错 | 浏览器 console 捕获；DSH 无 frame 限制已实测，重点看加载时序 |
| 旧 dist 残留（已重建） | 当前 dev 无 AIPage——恢复后重新 build 部署 |
| DSH 未启动/端口占 | useDSHStatus 探测 + 错误提示（半成品已有 Message） |

### 3.3 测试与规约

- vitest：AIPage 渲染（jsdom iframe 无实际加载——mock DSH 状态）+ 路由 /ai
- tsc/eslint/build 全过；文件 ≤300 行（AIPage 恢复后若超限拆分）
- Phase 1 MVP 验收：/ai 打开 → DSH 对话可用 → 选中任务上下文注入

## 4. 验收映射

| 验收项 | 设计落实 |
|--------|---------|
| Phase 1 ① /ai 路由 + AIPage | D1（路由 + 页面） |
| Phase 1 ② 任务上下文面板 | TaskContextPanel 恢复 |
| Phase 1 ③ AI 对话面板（连接 DSH） | iframe 嵌入（D1） |
| Phase 1 ④ 上下文自动注入 | D2 postMessage / URL query |
| Phase 3 实时同步 | D5（TASK-007 SSE 已交付） |

## 5. 风险

- iframe 内 DSH 更新（DSH 版本升级）不破坏嵌入（复用整体界面，风险低）
- postMessage 若 DSH 侧不支持收信 → 降级 URL query 注入（Phase 1 兜底）
- 范围控制：Phase 1 为 MVP，Phase 2/3 递进（本任务至少交付 Phase 1）

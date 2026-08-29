---
task_id: TASK-000019
stage: design
authority: L2
title: obtstar.top 官网改造 — 设计
---

# TASK-000019 设计文档（L2）

> 输入：report-requirements.md（已审批）

## 1. 站点结构（docs/）

```
docs/
├── index.html          # 平台介绍 + 核心原则 + 导航
├── architecture.html   # 六仓/技术栈/流水线/数据分层
├── quickstart.html     # 快速开始（初始化/构建/运行）
├── status.html         # 平台状态快照
├── css/styles.css      # 原生 CSS（深色主题）
└── favicon.svg         # 保留
```

- 纯静态（无 JS 框架），GitHub Pages 直接服务
- 导航统一：介绍 / 架构 / 快速开始 / 状态
- 内容来源（有据）：00-principles.md、AGENTS.md §1/2/4/7/8/11、05/06/15/17 章

## 2. 页面要点

| 页 | 关键内容 |
|----|---------|
| index | 标题"control · AI 驱动执行的个人 Agent 平台"；4 核心原则卡片；C1 执行模型一句话 |
| architecture | 六仓表 + 架构 ASCII 图（AGENTS.md §1.1）+ 流水线 6 阶段 + 数据 4 层 |
| quickstart | 两阶段初始化命令 + 构建/运行/测试命令（AGENTS.md §4/11） |
| status | 任务 17 delivered / FINDING 55 条 0 open / 服务 4 / 里程碑（C1 迁移/LiteLLM 砍除/自动归档） |

## 3. 验收映射

| 验收项 | 落实 |
|--------|------|
| 官网展示平台 | 4 页内容 |
| 内容有据 | 引用 00-principles/AGENTS.md 真实段落 |
| 旧内容可回溯 | 替换提交（git 历史保留） |

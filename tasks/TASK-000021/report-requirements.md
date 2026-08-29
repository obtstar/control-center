# TASK-000019 影响分析报告（requirements）

> 任务：obtstar.top 官网改造：control 平台官网
> 阶段：requirements · 日期：2026-08-29

## 1. 决策

人裁决（2026-08-29）：obtstar.top 从"ObtStar 研究报告站"改造为 **control 平台官网**。域名已解析 GitHub Pages（CNAME → obtstar.github.io），仓库 `obtstar/obtstar.top`（main + pages.yml 自动部署 docs/）。

## 2. 现状

| 项 | 现状 |
|----|------|
| 域名 | ✅ obtstar.top → GitHub Pages（已生效） |
| 部署 | ✅ pages.yml（push main → docs/ → Pages） |
| 内容 | ObtStar 研究报告站（reports/reader + 报告数据 + server.js 本地 API）→ **整体替换** |
| 保留 | pages.yml、CNAME（如有）、favicon；旧内容留 git 历史 |

## 3. 官网设计（4 页 + 样式）

| 页 | 内容（有据：control-center docs / AGENTS.md） |
|----|------|
| index.html | 平台介绍：定位（单人 AI Agent 平台）/核心原则 4 条（00-principles）/导航 |
| architecture.html | 六仓（AGENTS.md §1.1）/技术栈（§2）/流水线（§7）/数据分层（§8） |
| quickstart.html | 环境初始化两阶段（§4.1）/构建运行（§4.2-4.3）/常用速查（§11） |
| status.html | 平台状态静态快照：任务 17 delivered/FINDING 55 条 0 open/服务 4 个/里程碑 |
| css/styles.css | 简单原生 CSS（深色主题，与平台一致风格） |

## 4. 影响面

- obtstar.top 仓库 docs/ 替换（index/architecture/quickstart/status + css）；server.js/api/tools 移除（报告站遗留，保留 git 历史）
- pages.yml 不动；无平台仓改动
- 官网走业务仓流程（feature 分支 + MR，branch-guard）

## 5. 验收

1. MR 合并后 Pages 部署，obtstar.top 展示平台官网
2. 内容引用平台文档真实存在（00-principles/AGENTS.md §1-8）
3. 旧报告站内容在 git 历史可回溯

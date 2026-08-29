# TASK-000019 report-coding.md

> 阶段：coding · 日期：2026-08-29

## 交付

**obtstar.top [PR #1](https://github.com/obtstar/obtstar.top/pull/1)**（feature/TASK-000019-platform-site → main）：

| 文件 | 内容 |
|------|------|
| docs/index.html | 平台介绍 + 4 核心原则 + C1 执行模型 |
| docs/architecture.html | 六仓表 + 运行时拓扑 + 技术栈 + 流水线 + 数据分层 |
| docs/quickstart.html | 两阶段初始化 + 构建 + 运行（4 服务）+ 常用命令 |
| docs/status.html | 平台状态快照（17 任务/55 FINDING 0 open/4 服务/里程碑） |
| docs/css/styles.css | 深色主题原生 CSS |
| docs/.nojekyll + favicon.svg | Pages 部署所需 |
| AGENTS.md | 更新为新形态（官网说明） |
| 移除 | 旧研究报告站（server.js/api/tools/docs 旧页——git 历史保留） |

## 验证

- 本地预览：4 页 + 样式全部 HTTP 200
- 内容提炼自 00-principles.md / AGENTS.md §1-8（有据）
- pages.yml 保留（push main → docs/ → Pages 自动部署）

## 依据

- task.md（L1 人裁决）+ design.md（4 页设计）

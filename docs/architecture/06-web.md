# 06 Web 管理端（React + PrimeReact + Vite）

人类入口，掌握阶段闸门、审核与最终合并权。由**平台前端代码仓库 `control-web`** 构建，React + PrimeReact + Vite，Nginx 提供内网静态托管。

> 客户端按角色拆分为设计者/开发者/测试者三种工作台（单代码库公用），管理者与客户经受限视图访问，详见 [17 客户端/服务端设计](17-client-server-design.md)。

## 技术选型

| 组件 | 选型 |
|-----|------|
| 框架 | React 18+ |
| UI 组件库 | PrimeReact（含 PrimeNG 主题、DataTable、Calendar、Editor） |
| 构建 | Vite |
| 静态托管 | Nginx（内网） |

## 功能模块

| 模块 | 说明 | 关键 PrimeReact 组件 |
|-----|------|---------------------|
| 项目看板 | 项目与任务状态可视化 | DataTable / Card / Tag |
| 瀑布阶段闸门 | 各阶段审批入口，人工确认后流转 | Dialog / ConfirmDialog / Buttons |
| 审核队列 | 代码 Diff 评审、批注、修正循环 | Editor / Splitter / ScrollPanel |
| 排班日历 | 排班计划与 Agent 权限时段展示 | Calendar / Scheduler |
| 工作报告 | 日报/周报/任务报告查看、提交、审批（work_report） | DataTable / Editor / ConfirmDialog |
| 审计检索 | 结构化日志查询，支持 SIEM 对接 | DataTable + Filter |

## 与后端对接

- REST API 调用后端 Spring Boot（`/api/**`）
- WebSocket/SSE 推送阶段闸门审核通知与任务状态
- 支持 WSL 路径与变更实时预览

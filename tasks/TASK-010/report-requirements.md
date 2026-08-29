# TASK-010 影响分析报告（requirements）

> 任务：工作台形态决策：双线分工定位（control-web 为审批唯一入口，插件不做 UI M3）
> 阶段：requirements · 产出：影响分析报告
> 日期：2026-08-29 · 依据：KB 检索 + 权柄文档全文阅读

## 1. 决策概述

人裁决（2026-08-29，方案 A）：**control-dsh-plugin 定位为 AI 执行面 + DSH GUI 只读投影；control-web 定位为人的审批工作台唯一入口**。本报告分析该决策的现状基础、影响面与风险，并给出 TASK-009 执行范围的约束声明。

## 2. 现状功能矩阵（事实基线）

| 能力 | control-web（独立工作台） | control-dsh-plugin client（DSH GUI 内） | control-dsh-plugin Node（工具面） |
|------|--------------------------|----------------------------------------|-----------------------------------|
| 任务看板 | ✅ BoardPage | ✅ 只读列表（loadTasks） | ✅ control_task_list |
| 审批操作（approve/reject/pause/resume/deliver） | ✅ ApprovalPage（角色路由+审计） | ❌ 无 | ✅ control_task_action（会话内） |
| 待审批列表 | ✅ | ✅ 只读（loadApprovals） | ✅ control_approvals_list |
| 审计日志 | ✅ AuditPage | ✅ 只读（loadAudit） | ✅ control_audit |
| 问题台账 | ✅ FindingsPage | ❌ | ✅ control_findings |
| KB 检索 | ✅ KBPage | ❌ | ✅ control_grounding_check |
| API 文档（Scalar） | ✅ ApiDocsPage | ❌ | — |
| 登录/角色路由 | ✅ | ❌ | 凭据走 host 进程 env |
| 数据通道 | 直连 control-api（dev 经 vite 代理） | 经 DSH web 代理 `/control/dashboard/api/*`（本次修复点） | host 侧 Bearer（lib/http.js） |

结论：重叠集中在**只读视图**（任务/审批/审计列表）；**审批操作与工作台扩展能力（KB/文档/角色）仅 control-web 具备**。插件 client 半区当前即"只读投影"形态，方案 A 是**固化现状 + 明确边界**，无回退。

## 3. 依据引用（KB 权柄文档）

| 结论 | 依据（文档 ID + 段落） |
|------|------------------------|
| 审批操作入口权威归属 Web 工作台（control-web） | `wiki/source-notes/platform/architecture/05-orchestration.md` §流水线状态机："**用户在 Web 工作台批准**进入下阶段或**驳回附批注**（AI 带批注重做本阶段）" |
| 浏览器端保持"纯展示、零数据直连"（支撑"凭据不进浏览器、不做 M3"） | `wiki/source-notes/platform/architecture/17-client-server-design.md` §17.3 部署边界："原则：**客户端 = 纯展示**（零业务逻辑、零数据直连）……客户端只经内网 API 交互" |
| control-web 是人的用户入口（看板/任务干预/Diff/日志） | `raw/platform/architecture/06-web.md` §用户入口："用户入口：多任务看板、任务干预、Diff 预览……与日志检索"，功能模块含"任务操作：创建任务、暂停/回退/批注修正" |
| control-web 页面构成（审批中心/审计/问题/KB/API 文档） | `wiki/source-notes/platform/architecture/17-client-server-design.md` §17.2："现有页面：看板/审批中心/审计日志/问题一览/KB 检索/API 文档（Scalar）" |
| 统一后端 control-api，审批/审计全在服务端 | `wiki/source-notes/platform/architecture/15-server-module.md` §15.1："系统唯一的后端服务，负责任务编排、流水线状态机、任务干预与操作追溯"；§17.3："任务、审批、审计全在服务端" |
| 只读投影数据通道形态（host 代理、凭据不进浏览器） | `wiki/source-notes/platform/architecture/17-client-server-design.md` §17.3 部署边界表；插件 `docs/ui-client-module.md` §3"浏览器不得直连 control-api（凭据泄露面）" |

## 4. 影响面

### 4.1 涉及仓库/模块

| 仓库 | 模块 | 影响 |
|------|------|------|
| control-dsh-plugin | client 半区（client/index.js） | **范围约束**：仅保留只读投影（任务/审批/审计列表），明确**不做 M3**（审批操作入口不进浏览器）；后续改动不得引入审批操作/凭据处理 |
| control-dsh-plugin | Node 工具面（lib/tools-*.js） | 不变化：AI 执行面继续（工具/会话绑定/反向通知） |
| control-web | 全部页面（Board/Approval/Audit/Findings/KB/ApiDocs） | 定位为审批工作台唯一入口，继续演进；TASK-008（AI 助手面板）按计划推进 |
| control-api | `/api/**` | 无变更（审批/审计接口保持服务端权威） |
| control-center | docs/ 架构文档 | 需在决策落地后补一句双线定位声明（本任务后续 design 阶段产出，属 L2/L3 顺行） |

### 4.2 接口/数据表

- **无接口变更、无数据表变更**：本决策为定位/范围决策，不新增端点、不改契约（OAS 3.1 唯一可信源不动）。
- DSH web 代理 `/control/dashboard/api/*`（control-dsh-plugin lib/index.js）保持**只读透传**；本次已修复其缺 `/api` 前缀的转发缺陷（此前 404 "404 page not found" 透传导致浏览器 JSON 解析报错）。

### 4.3 TASK-009 执行范围约束声明

TASK-009（插件深度集成 v0.2）当前在 requirements 审批闸。本决策对其后续阶段产物的约束：

1. 其 `docs/ui-client-module.md`（v0.5 UI client module 设计）中 **M3（审批操作入口）从里程碑中移除/标注"不做"**，M0-M2（只读投影）为上限；
2. 任何 client 半区改动不得引入凭据（token）进入浏览器端逻辑；
3. 执行面工具（control_task_action 等）保持 host 侧，不因 UI 决策变化。

## 5. 风险与对策

| 风险 | 等级 | 对策 |
|------|------|------|
| 插件只读投影与 control-web 看板功能重复度继续上升，维护双份视图 | 中 | 投影保持最简（列表级），不再扩展（不做详情/操作）；复杂视图一律归 control-web；TASK-008 使 control-web 具备 AI 协作能力形成差异化 |
| TASK-009 审批通过后 design/coding 阶段执行者可能"顺手"做 M3 | 中 | 本决策记录作为 TASK-009 的约束声明（§4.3）；审批闸 comment 同步注明 |
| 未来 DSH GUI 演进为主入口，control-web 价值被稀释 | 低 | 本决策固定窗口内 control-web 为审批唯一入口；窗口期后按需重估（触发条件：插件 client 出现审批操作需求时，回到本决策重新裁决） |
| 决策记录与架构文档（06/17 章）漂移 | 低 | design 阶段将双线定位补入 `control-center/docs/architecture/`（06-web / 17-client-server-design），并跑 `control_reconcile` 对账 |

## 6. 验收映射

| 验收项（task.md） | 落实 |
|------|------|
| 决策记录落盘并引用真实依据 | 本报告 §2-§3；design 阶段产出正式决策记录（docs/） |
| TASK-009 后续产物与"不做 M3"一致 | §4.3 约束声明；审批闸批注联动 |
| 功能矩阵/安全边界/构建链耦合/成本对比四维依据 | §2（矩阵）、§3（安全边界：17.3 客户端纯展示）、§5（成本：不做 M3 避免重复建设凭据+角色+审计审批面；构建链：client bundle 依赖 dev:web 的耦合不入扩展范围） |

## 7. 结论

方案 A 与权柄文档一致（05 章"用户在 Web 工作台批准"、17.3 章"客户端=纯展示"），**固化现状、明确边界、无回退**；主要成本在文档声明与 TASK-009 范围约束的执行一致性，均已在 §4.3/§5 覆盖。

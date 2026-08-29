---
task_id: TASK-010
stage: design
authority: L2
title: 工作台形态决策：双线分工定位 — 概要设计
---

# TASK-010 设计文档（L2）

> 输入：`task.md`（L1，人裁决方案 A）+ `report-requirements.md`（影响分析，已审批通过）
> 依据：`wiki/source-notes/platform/architecture/05-orchestration.md`、`17-client-server-design.md`、`raw/platform/architecture/06-web.md`、`15-server-module.md`（KB 检索校验存在）

## 1. L1 需求条目映射

| L1 条目（task.md） | 设计项 | 产出落点 |
|--------------------|--------|----------|
| ① 插件定位 AI 执行面；client 半区仅只读投影（M1/M2），**明确不做 M3** | D4：TASK-009 范围约束声明 | 决策记录文档 §约束声明；TASK-009 审批批注 |
| ② control-web 为人的审批工作台唯一入口；TASK-008 按计划推进 | D2：06-web.md 双线定位声明 | `docs/architecture/06-web.md` |
| ③ 决策记录（功能矩阵/安全边界/构建链耦合/成本对比四维）+ 约束声明；验收：引用真实依据、TASK-009 与"不做 M3"一致 | D1：决策记录文档 | `docs/architecture/19-workbench-strategy.md`（新章） |
| ③ 补：客户端边界（17.3"客户端=纯展示"）与插件投影的关系 | D3：17-client-server-design.md 补充 | `docs/architecture/17-client-server-design.md` |

## 2. 概要设计

### 2.1 D1 决策记录文档（新章 19）

- **位置**：`control-center/docs/architecture/19-workbench-strategy.md`，新章独立成文（不动 06/17 原有结构，避免权柄文档大改）
- **frontmatter**：`status: 已裁决` + `last_verified: 2026-08-29` + `decision: TASK-010`
- **章节结构**：
  1. 背景与问题（两线功能重叠、重复投资、安全边界风险）
  2. 决策（方案 A 全文：插件=AI 执行面+只读投影；control-web=审批唯一入口；TASK-008 继续）
  3. 四维依据（引用 KB 权柄文档）：
     - 功能矩阵（reuse requirements §2 表）
     - 安全边界：17.3"客户端=纯展示、零数据直连" → 凭据不进浏览器，M3 不做
     - 构建链耦合：client bundle 依赖 dev:web 构建工作流（ui-client-module.md §5），扩展 M3 成本高
     - 成本对比：M3 需重做 host Remote+凭据+角色+审计审批面，control-web 已有成熟实现
  4. 约束声明（对 TASK-009：M3 移除、只读投影保持、client 不引入凭据逻辑）
  5. 重估触发条件（插件出现审批操作需求时回到本决策重新裁决）

### 2.2 D2：06-web.md 双线定位声明

- 在 `06-web.md` 末尾新增 **「双线定位（TASK-010 裁决）」** 小节（3-5 行）：
  - control-web 为**人的审批工作台唯一入口**（审批操作/看板/审计/KB/API 文档）
  - control-dsh-plugin client 半区为 **DSH GUI 内只读投影**（任务/审批/审计列表，不做审批操作）
  - 指向 19 章决策记录
- 不修改既有表格与段落（保权威原文）

### 2.3 D3：17-client-server-design.md 补充

- 在 §17.3 之后新增 **§17.4 control-dsh-plugin 投影客户端**：
  - 定位：AI 会话侧的只读投影（host 代理 `/control/dashboard/api/*` → control-api），凭据在 host 进程，浏览器零凭据
  - 边界：符合 §17.3"客户端=纯展示"原则；不做审批操作（M3 不做，见 19 章）
  - 数据通道：DSH web 代理透传（本次已修复缺 `/api` 前缀缺陷）

### 2.4 D4：TASK-009 范围约束落地

- **不动 TASK-009 的 L1 task.md**（权柄分级：AI 不得逆行修改上级文档）
- 落地两处：
  1. 19 章决策记录 §约束声明（权威声明）
  2. TASK-009 审批/执行时由人在审批批注引用本决策（本任务 coding 阶段在 TASK-010 产物中附约束摘要，供审批人 copy）

## 3. 详细设计（到可编码粒度）

### 3.1 19 章关键内容要点

| 章节 | 要点 | 引用（KB 依据） |
|------|------|-----------------|
| 决策 | 方案 A 三句定位 | 05 章"用户在 Web 工作台批准"；17.2 页面清单 |
| 功能矩阵 | 复用 requirements §2 表（control-web vs 插件 client vs 插件 Node） | requirements 报告（已审批） |
| 安全边界 | 17.3 原则原文引用；M3 不进浏览器 | 17-client-server-design.md §17.3 |
| 构建链耦合 | ui-client-module.md §5（dev:web 工作流前置） | control-dsh-plugin/docs/ui-client-module.md |
| 成本对比 | M3 需重做：host Remote + 凭据边界 + 角色路由 + 审计 + 契约测试 | 17.1 能力域表（已实现审批） |

### 3.2 文件改动清单（coding 阶段执行）

| 文件 | 操作 | 内容 |
|------|------|------|
| `docs/architecture/19-workbench-strategy.md` | 新增 | 决策记录全文（§2.1 结构） |
| `docs/architecture/06-web.md` | 追加小节 | 双线定位声明（§2.2） |
| `docs/architecture/17-client-server-design.md` | 追加 §17.4 | 插件投影客户端定位（§2.3） |
| `docs/architecture/README.md` | 追加一行 | 章节索引补 19 章 |
| `tasks/TASK-010/` | 附约束摘要 | `constraint-note-TASK-009.md`（供审批批注引用） |

> 不改：pipeline.yaml、registry、openapi.yaml、FINDINGS.md、TASK-009/task.md（权柄约束）

### 3.3 接口/数据/时序

- **接口**：无新增端点；`/control/dashboard/api/*` 保持只读透传（lib/index.js 已修复）
- **数据表**：无变更
- **时序**：无运行时行为变化（纯文档决策）

## 4. 验收映射

| 验收项（task.md） | 设计落实 |
|-------------------|----------|
| 决策记录落盘并引用真实依据 | D1（19 章四维依据，KB 文档 ID 引用） |
| TASK-009 后续产物与"不做 M3"一致 | D4（19 章约束声明 + 审批批注） |
| 四维依据齐全 | D1 §3（矩阵/安全边界/构建链/成本） |
| 文档改动后跑 reconcile | coding 阶段完成后执行（06/17/README 改动会触发 kb-mirror 新鲜度检查，需重跑 kb-sync.sh） |

## 5. 风险与注意

- **kb-mirror 新鲜度**：06/17 上游文档改动后，`control-wiki/raw/platform/` 镜像会过期（reconcile WARN）→ coding 阶段提交后需重跑 `control-center/scripts/kb-sync.sh` 再 reconcile
- **TASK-009 时序**：其 requirements 审批与 TASK-010 无关，但 design/coding 需在 TASK-010 决策记录入库后进行（约束可引用）
- **权柄边界**：本任务只写 L2/L3 文档，不碰 L1（task.md 权威文档）

---
authority: L2/L3
task_id: TASK-001
---

# TASK-001 设计阶段验证方案：kimi 恢复后真实驱动 design

## 引用依据

- [control-wiki/raw/architecture/00-principles.md § 设计原则]：流水线每阶段设审批闸，Agent 负责编码、分析、测试；用户保留最终合并权。
- [control-wiki/raw/architecture/07-workflows.md § 7.1 功能开发流水线]：功能开发阶段为 `[需求分析] → [系统设计] → [编码实现] → [测试验证] → [待合并] → [交付]`；任意阶段可人工介入（暂停/回退）。
- [control-wiki/raw/architecture/18-authority.md § 18.1 权柄等级]：L1 需求最高，L2 概要设计、L3 详细设计顺行产出；AI 禁止逆行修改上级文档。
- [control-wiki/raw/architecture/18-authority.md § 18.4 一致性校验与暂停]：设计阶段对照 L1 需求逐条核对；发现冲突时 AI 只能产出报告并暂停。
- [control-wiki/raw/architecture/03-doc-management.md § 文档管理]：概要设计/外部设计集中管理于控制中心仓库；内部设计随代码仓库同 MR 提交。
- [control-center/orchestration/skills/stage/design/SKILL.md]：基于 L1 需求产出概要设计（接口/数据/时序），详细设计到可编码粒度；设计项逐条映射 L1 需求条目。
- [control-api/internal/config/config.go § 85]：模型配置中 `coding` 阶段映射到 `kimi-for-coding`，`cheap` 映射到 `kimi-for-coding-highspeed`，`heavy` 映射到 `k3`。
- [control-center/DEPENDENCIES.md § 94]：Anthropic / GitHub Copilot / Moonshot(Kimi) 作为 LiteLLM 网关后的模型后端。

---

## 1. 背景与目标

L1 需求要求验证 kimi 恢复后能够真实驱动 design 阶段。本设计将本次任务本身视为一个待验证的 design 阶段实例：

- **目标 1**：确认任务从 `requirements` 成功流转到 `design` 阶段。
- **目标 2**：确认 design 阶段由 Kimi 模型实际执行，而非占位/旁路逻辑。
- **目标 3**：确认 design 产出（本文件）满足 L2/L3 权柄要求，且可逐条回溯到 L1 需求与 KB 依据。
- **目标 4**：确认设计阶段具备审批闸入口，支持人审批后进入下一阶段。

---

## 2. 验证范围（概要设计）

| 维度 | 验证内容 | 边界 |
|------|---------|------|
| 阶段触发 | 任务 frontmatter `stage: design` 被识别，design skill 被正确加载 | 不验证上游 requirements 产出质量 |
| 模型路由 | 配置中 design 对应模型命中 Kimi 后端，请求真实发往 LiteLLM 网关 | 不验证网关自身可用性，仅验证路由配置与请求发出 |
| 技能执行 | design skill 被读取，步骤 1/2/3 被依次执行 | 不扩展修改 skill 本身 |
| 产出合规 | 产出文件以 `design-` 前缀写入当前目录，frontmatter 携带 `authority: L2/L3` | 不写入代码、不修改 L1 task.md |
| 引用可点验 | 每条设计决策都给出 [文档路径 § 段落] 引用，引用段落真实存在 | 不引入无据新约束 |

---

## 3. 系统接口（外部设计）

本验证任务与以下组件交互：

```
┌──────────────┐      stage=design       ┌──────────────┐
│  control-api │  ────────────────────▶  │  design skill│
│  (状态机)    │  读取 task.md + KB 依据  │  (SKILL.md)  │
└──────────────┘                         └──────┬───────┘
                                                │ 调用 LLM
                                                ▼
                                         ┌──────────────┐
                                         │  LiteLLM 网关 │
                                         │  → Kimi 后端  │
                                         └──────┬───────┘
                                                │ 返回设计文本
                                                ▼
                                         ┌──────────────┐
                                         │ tasks/TASK-001│
                                         │ design-*.md   │
                                         └──────────────┘
```

接口定义：

| 接口 | 形式 | 输入 | 输出 |
|------|------|------|------|
| 阶段驱动 | control-api 内部状态机 | task.md + 已加载 skill | 对 skill 的调用请求 |
| skill 加载 | 文件读取 | `orchestration/skills/stage/design/SKILL.md` | skill 元数据与步骤 |
| 模型调用 | LiteLLM 兼容 HTTP | prompt + 模型名 | 文本响应 |
| 产物落地 | 文件写入 | 设计文本 | `tasks/TASK-001/design-*.md` |

---

## 4. 数据设计

### 4.1 任务状态数据

数据来源：task.md frontmatter（L1，只读）。

| 字段 | 当前值 | 说明 |
|------|--------|------|
| task_id | TASK-001 | 任务标识 |
| title | kimi联调 | 任务标题 |
| repo_key | billing-core | 所属业务仓库（本次不产出代码） |
| stage | design | 当前阶段 |
| status | running | 运行状态 |
| authority | L1 | 本任务为 L1 需求 |

### 4.2 设计产物数据

| 文件 | 权柄 | 内容 | 存放位置 |
|------|------|------|----------|
| design-kimi-recovery.md | L2/L3 | 本验证方案（概要+详细） | `control-center/tasks/TASK-001/` |
| （后续可选）design-kimi-checklist.md | L3 | 可执行检查清单 | 同目录 |

---

## 5. 详细步骤（L3 可执行粒度）

### 步骤 1：入口校验

1. 读取 `task.md`，确认 `authority: L1` 且 `stage: design`。
2. 检查当前目录无 `design-` 前缀文件（避免重复执行）。
3. 若已存在，先读取并判断是否为上次中断残留，必要时报告。

### 步骤 2：依据检索

1. 读取 `control-center/orchestration/skills/stage/design/SKILL.md`。
2. 读取平台 KB 文档：
   - `control-wiki/raw/architecture/00-principles.md`
   - `control-wiki/raw/architecture/07-workflows.md`
   - `control-wiki/raw/architecture/18-authority.md`
   - `control-wiki/raw/architecture/03-doc-management.md`
3. 确认所有引用段落真实存在，否则转入 `NO_BASIS` 暂停。

### 步骤 3：模型真实性验证

1. 检查 `control-api.yaml` 或 `control-api/internal/config/config.go` 中 design 阶段模型映射。
2. 若设计阶段使用 `coding` 模型槽位，则默认命中 `kimi-for-coding`（见 config.go § 85）。
3. 验证方法：
   - 在控制-api 日志中确认该阶段请求的目标模型名包含 `kimi`。
   - 或向 LiteLLM 网关发送一条 probe 请求，模型名使用配置中的设计阶段模型名，确认响应非空且无路由错误。
4. 记录模型名、响应时间、响应摘要（不含密钥）。

### 步骤 4：设计产出

1. 基于 L1 需求逐项映射：
   - L1 条目 A："验证 kimi 恢复" → 设计 § 3 模型路由验证 + § 5.3 模型真实性验证。
   - L1 条目 B："真实驱动设计阶段" → 设计 § 2 范围中的阶段触发、技能执行、产出合规、审批闸入口。
2. 撰写本文件并写入 `design-kimi-recovery.md`。
3. 所有设计决策标注引用 `[文档路径 § 段落]`。

### 步骤 5：自检与审批闸

1. 自检清单：
   - [ ] 文件以 `design-` 前缀命名。
   - [ ] frontmatter 包含 `authority: L2/L3`。
   - [ ] 每条引用可在 KB 中点验。
   - [ ] 未修改 `task.md` 或其他 L1 文档。
   - [ ] 未引入无据新功能或新增依赖。
2. 提交后等待用户在 Web/控制端审批，通过后方可进入 coding 阶段。

---

## 6. 通过标准

| 编号 | 标准 | 验证方式 |
|------|------|----------|
| P1 | 当前目录出现 `design-*.md` 文件 | 文件系统检查 |
| P2 | 文件 frontmatter 正确声明 `authority: L2/L3` | 读取 frontmatter |
| P3 | 文件内容逐条映射 L1 需求，且所有引用真实存在 | 人工/脚本点验 |
| P4 | 控制-api 日志或配置显示 design 阶段请求发往 Kimi 模型 | 日志/配置检查 |
| P5 | 未逆行修改任何 L1 文档 | Git diff 检查 |
| P6 | 设计阶段状态可被人审批并流转到下一阶段 | 状态机操作 |

---

## 7. 异常与回退

| 异常 | 动作 | 依据 |
|------|------|------|
| 找不到 design skill | 报告 `NO_BASIS` 并暂停 | [18-authority.md § 18.3] |
| KB 引用段落不存在 | 报告不一致并暂停 | [18-authority.md § 18.4] |
| 模型路由未命中 Kimi | 输出诊断日志，暂停等待人恢复网关/配置 | [07-workflows.md § 7.1] 任意阶段可人工介入 |
| 发现 L1 需求与平台文档冲突 | 产出不一致报告，禁止修改 L1，任务暂停 | [18-authority.md § 18.4] |

---

## 8. 设计项到 L1 需求映射表

| L1 需求条目 | 设计章节 | 引用依据 |
|-------------|----------|----------|
| 验证 kimi 恢复 | § 3 模型路由、§ 5.3 模型真实性验证 | [control-api/internal/config/config.go § 85]、[control-center/DEPENDENCIES.md § 94] |
| 真实驱动设计阶段 | § 2 范围、§ 5.1~5.2 入口与技能执行、§ 6 通过标准 | [control-wiki/raw/architecture/07-workflows.md § 7.1]、[control-center/orchestration/skills/stage/design/SKILL.md] |

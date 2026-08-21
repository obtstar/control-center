# TASK-005 L3 详细设计：PieKBS 蒸馏技能化（wiki-distill 技能）

> 任务：P2 | 阶段：design | 权威：L1 需求（本任务 task.md）
> 依据：control-piekbs/internal/distill/prompt.go（蒸馏系统提示词与规则）、
> control-wiki/schema/templates/source-note.md（权威输出模板）、
> control-wiki/schema/references/*（质量约束）、
> control-piekbs/internal/watcher/watcher.go（wiki/ 变更触发重建 FTS）、
> control-dsh-plugin/docs/execution-migration-C1.md §4（蒸馏迁移方案）

## 1. 目标

PieKBS 蒸馏改由 DSH 会话承担：新增 `wiki-distill` 技能，定义「读 raw → 生成 source-note →
写 wiki/source-notes/ → FTS 可检索」的完整工作流，供 DSH 模型按技能执行。
`internal/distill`（Go）保留但不启用（distill.token 空，C1 §4 选项 1）。

## 2. 设计

### 2.1 技能文件

新增 `control-center/orchestration/skills/domain/wiki-distill/SKILL.md`（kebab-case，
frontmatter：name/description/layer/whenToUse）。经 Route A 的 customSkillDirs（domain/）
自动对 DSH 会话可见，零额外配置。

### 2.2 工作流（技能正文要点）

```
1. 发现目标：扫描 control-wiki/raw/ 下无对应 wiki/source-notes/ 页的源文档
   （排除 raw/platform/ 镜像区——其 source-note 由 kb-sync.sh 生成，勿手写防覆盖）
2. 读源：完整读取 raw 文档（fs 工具；大文档按 section 分批）
3. 生成：严格按 control-wiki/schema/templates/source-note.md 与
   control-piekbs/internal/distill/prompt.go 内嵌规则：
   - 语言与源一致；别名/缩写内联；实体【名|类型】标记
   - 技术规范类（doc_type=技术规范）表格逐字保留，标识符（端点/字段/编码）全量保留
   - sources 填 raw 相对路径；timestamp 取文档内日期，不得用今天
4. 落盘：写入 control-wiki/wiki/source-notes/<slug>.md（Git 权威）
5. 验证：watcher 自动重建 FTS（watcher.go 监听 wiki/）；mcp__piekbs__kb_search 命中
6. 大文档规则：单文档 >50KB 拆多页（<slug>/ 下按 section 分页），标识符跨页全量保留，
   并在首页注明分页索引
```

### 2.3 约束与边界

- 只蒸馏 raw/ 中真实存在、且未被 kb-sync 镜像覆盖的源（OAS/converted/未来业务文档）；
- 不修改 raw/ 与 schema/；产物只增不减；
- 生成的页面须过 citation-rules（引用规则）与 page-types（页面类型）检查；
- 写入前用 kb_search 确认无同名/近似页，避免重复。

## 3. 演示目标

`raw/converted/oas/v3.1.0.md`（152K，control-api OpenAPI 3.1 技术规范）：
生成 `wiki/source-notes/control-api-openapi.md`（单页，信息/服务器/组件综述 + 全部路径组
标识符；超长则按 section 拆分并在首页索引）。该源不在 kb-sync mirror_pairs 内，无覆盖冲突。

## 4. 验收

1. SKILL.md 落盘且 headless 会话技能目录可见 `wiki-distill`
2. 演示页生成并可被 mcp__piekbs__kb_search 检索到
3. reconcile 五项 PASS（control-center skills 目录新增文件不影响契约检查）
4. C1 文档与插件 README 的 P2 状态更新为已交付

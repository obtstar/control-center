---
name: wiki-distill
layer: domain
description: KB 蒸馏：raw/ 源文档 → wiki/source-notes/ 页面（DSH 替代 PieKBS internal/distill，C1 执行层迁移）
whenToUse: 需要把 raw/ 里的原始文档（OAS、转换件、业务资料）蒸馏成可检索的 wiki source-note 页
---

# KB 蒸馏（wiki-distill）

## 背景
PieKBS 的 `internal/distill` 已停用（LiteLLM 网关不可达，config.yaml `distill.token` 空）。
蒸馏由 DSH 会话承担：读 raw/ 源文档 → 用当前模型生成 source-note → 写入
`control-wiki/wiki/source-notes/` → watcher 自动重建 FTS（`control-piekbs/internal/watcher`
监听 wiki/ 目录）→ `mcp__piekbs__kb_search` 可检索。

## 目标文档范围
- 蒸馏 `~/control-wiki/raw/` 下**没有**对应 wiki 页的源文档（如 raw/oas/、raw/converted/、未来业务资料）；
- **排除 `raw/platform/` 镜像区**：其 source-note 由 `control-center/scripts/kb-sync.sh`
  生成（kb-mirror 头，勿手写，防覆盖）；
- 排除已存在同名/近似页的源（先用 kb_search 查重）。

## 步骤
1. **读源**：用 fs/read 完整读取 raw 文档（大文档按 section 分批读，勿截断）。
2. **定模板**：读 `~/control-wiki/schema/templates/source-note.md` 为权威输出格式；
   质量约束叠加 `~/control-wiki/schema/references/`（citation-rules、page-types）；
   实体/别名/表格规则另见 `~/control-piekbs/internal/distill/prompt.go` 内嵌条款。
3. **生成**（规则强制）：
   - 语言与源一致；别名/缩写/中英等价词内联进每条要点（如 Context Recall（CR，召回率））；
   - 实体标记 `【名|类型】`（人物/组织/产品/技术/概念/项目/地点）；
   - `doc_type=技术规范` 时：**表格逐字保留、端点/字段/编码等标识符全量保留，不得省略合并**；
   - `timestamp` 取文档自身日期（发布时间/URL 日期/版权年），无日期才用今天；
   - 每条 Key Facts/Key Claims 至少含一个具体数字、指标或命名实体；
   - 禁止编造 URL/作者/日期/引用；无出处写 "Not provided in source."。
4. **落盘**：写入 `~/control-wiki/wiki/source-notes/<slug>.md`（Git 权威，产物只增不减，
   不改 raw/ 与 schema/）。frontmatter 的 `sources` 填 raw 相对路径——**这是 PieKBS
   PurgeOrphanWikiFiles 的存活判据（FINDING-052）**：sources 任一条目指向存在的 raw
   文件即非孤儿；多页拆分的每一页都必须声明 sources。
5. **验证**：等 1-2 秒让 watcher 重建索引，`mcp__piekbs__kb_search` 用文中术语检索，
   确认页面命中；未命中检查 frontmatter 与路径。

## 大文档分段规则（>50KB 源）
- 拆多页：`wiki/source-notes/<slug>/` 下按 section 分页（00-index.md + 各节页）；
- 标识符跨页**全量保留**（可分布在多页，但一个都不能丢）；
- 首页列分页索引并注明覆盖范围。

## 约束
- 产物必须过 `schema/references/citation-rules.md` 与 `page-types.md` 检查；
- 不蒸馏 raw/platform/ 镜像区；不与已有页面重复；
- 写完后在总结中列出：源路径、产物路径、页数、覆盖要点数。

# TASK-006 L3 详细设计：PurgeOrphanWikiFiles 多页蒸馏兼容修复（FINDING-052）

> 任务：P2 配套 | 阶段：design（修复已实现并验证，本文档回溯记录设计）
> 依据：FINDING-052（control-center/docs/FINDINGS.md）、control-piekbs/internal/kb/okf.go、
> wiki-distill 技能（control-center/orchestration/skills/domain/wiki-distill/SKILL.md）

## 1. 问题

`PurgeOrphanWikiFiles`（okf.go:121）清理 wiki/source-notes/ 与 raw/converted/ 下
"stem 不匹配任何 raw 文件"的 .md，假定蒸馏产物 1:1（raw 文件 → 同名 source-note）。
wiki-distill 技能按大文档拆分规则产出的多页组（wiki/source-notes/<slug>/）stem 均不
匹配 raw，被周期性误删；01-overview 仅因 stem 与 raw/platform/architecture/01-overview.md
撞名而幸存（误打误撞）。

## 2. 修复设计

### 2.1 存活判据扩展（okf.go）

- **原有**：stem ∈ rawStems（保留，兼容 1:1 蒸馏与 converted/ 命名约定）；
- **新增（FINDING-052）**：`noteHasLiveSource(kbRoot, path)` —— 解析页面前置元数据
  `sources`（复用 ParseMarkdownFile → ParsedDocument.Sources），任一条目 `filepath.Join
  (kbRoot, s)` 指向存在的非目录文件即判定非孤儿；
- 两判据 OR：`if !rawStems[stem] && !noteHasLiveSource(kbRoot, path) { remove }`；
- raw/ 缺失时保持安全路径（不 purge）不变；okfReserved（index.md/log.md）不变。

### 2.2 测试（okf_test.go）

`TestPurgeOrphanWikiFiles_SourcesAware` 三态：sources 指向存在源 → 存活；指向不存在源 →
清除；无 sources 且 stem 不匹配 → 清除。修复夹具教训：os.WriteFile 不建父目录，
raw/ 目录须先 MkdirAll（否则 raw/ 缺失走安全路径，测试失效）。

## 3. 生效路径

重建 `-o /home/dev/.local/bin/piekbs`（systemd piekbs-mcp ExecStart 路径）→
`systemctl --user restart piekbs-mcp` → 运行中的 watcher/reindex 使用修复后判据。

## 4. 验收（全部实测通过）

1. `go build -tags fts5 ./...` + `go test -tags fts5 ./...` 全绿（含 3 个 purge 用例）
2. 5 页多页蒸馏产物（control-api-openapi/）15s+ 存活
3. GenerateOKFIndex 自动收录 4 页（index.md 完整列出）
4. `mcp__piekbs__kb_search` 检索命中新页

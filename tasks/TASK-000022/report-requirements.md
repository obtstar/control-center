# TASK-000022 Requirements 报告：Agora Phase 2 AI Provider Adapter

## 需求分析

### 背景
Phase 1 数据库 Schema 升级已完成（TASK-000019，commit af8b095）。现需构建 AI Provider 适配层，为后续 Agent 系统、AI 对话提供基础能力。

### 影响范围

| 组件 | 影响 | 说明 |
|------|------|------|
| `api/ai/` | 新增目录 | AI 适配器核心 |
| `api/queries/ai-config.ts` | 新增文件 | API Key 加解密 + CRUD |
| `api/router.ts` | 修改 | 注册 aiRouter |
| `db/schema.ts` | 已有 | Phase 1 已创建 ai_configs 表 |

### 依赖
- Phase 1 数据库 Schema（已完成）
- `docs/ai-adapter-design.md` 设计文档

### 风险
- **低**：技术方案已验证，Web Streams API 所有运行时支持
- **低**：OpenAI 兼容格式减少适配工作量

## 建议

直接进入 design 阶段，技术方案已明确。

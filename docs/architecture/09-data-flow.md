# 09 数据流示例：功能追加全流程

```
1. 需求录入 (Web)
   PM 在 React 端创建 REQ-001，上传 PRD 到控制中心仓库 docs/requirements
   → 写入 MySQL task 表 → 触发后端编排

2. 项目理解 (RAG)
   Spring 后端检索 RAG（控制中心仓库设计文档 + 各代码仓库 + OpenAPI 契约）
   → 生成影响分析 → Web 推送 → 人工确认

3. 设计阶段
   后端生成概要/外部设计 → 架构师审核通过
   → 文档提交控制中心仓库 MR（集中管理）→ 状态流转

4. 编码阶段（多代码仓库 Worktree）
   后端调用代码仓库 OpenAPI 创建 feature/TASK-001 分支 + Worktree
   → CLI Agent（pi.dev）经 LiteLLM 生成代码
   → 内部设计（docs/design/internal/）与代码同分支、同 MR 提交
   → 本地测试 → commit → push → 创建 MR 指向 dev

5. 人工审核 (Web)
   开发组长在 PrimeReact 端 Review Diff → 批注 → Agent 修正 → 通过

6. 测试阶段
   自动集成测试 → 报告 → 人工确认 → 合并 MR 到 dev
   → Webhook 触发增量 RAG 索引

7. 发布与归档
   dev → release/{version} → 人工确认 → main
   → 全流程日志写入 MySQL work_log / approval，关联排班表
   → 清理 Worktree（保留 7 天归档）

8. 报告生成
   定时任务聚合 work_log 生成日报/周报/任务报告（work_report）
   → Web 提交 → 管理者审批 → 支持 SIEM 导出
```

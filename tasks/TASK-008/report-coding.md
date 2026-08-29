# TASK-008 report-coding.md

> 阶段：coding · 产出：commit + MR diff
> 日期：2026-08-29

## 交付内容

**control-web [PR #8](https://github.com/obtstar/control-web/pull/8)**（feature/TASK-008-ai-panel-v2 → dev）

| 文件 | 处理 |
|------|------|
| src/pages/AIPage.tsx | 恢复（/ai 路由页面：左任务上下文 + 右 DSH 对话 iframe + 设置 Tab） |
| src/components/DSHIntegrationPanel.tsx | 恢复 + **修复"DSH 加载失败"根因** |
| src/components/DSHSettingsPanel.tsx / TaskContextPanel.tsx | 恢复 |
| src/router/router.tsx | + /ai 路由 |
| src/components/AppLayout.tsx | + AI 助手导航入口 |

## 关键修复：DSH 加载失败根因

**半成品假设 DSH 页面会发 `DSH_READY` postMessage，但 DSH 原生界面不发送** → iframe onLoad 后 10s 收不到就 `setError('DSH 服务未响应')` → 显示"DSH 加载失败"。

**修复**：iframe `onLoad` 即视为 DSH 就绪（完整界面已加载），移除 10s 超时错误；`DSH_READY` 监听保留兼容未来 DSH 增强。

## 验证

| 项 | 结果 |
|----|------|
| tsc | ✅ 无错误（删未使用 Message import） |
| eslint | ✅ 零 error |
| vitest | ✅ 34/34（NODE_ENV=test） |
| build | ✅ 11.58s |
| DSH 嵌入性 | ✅ 实测 3080 无 X-Frame-Options/CSP frame 限制 |

## 依据

- task.md（L1）+ design.md（L2，已审批）：D1 页面架构 / D2 postMessage / D3 半成品恢复
- 影响分析：iframe 方案（DSH 无公开 WS 对话 API）

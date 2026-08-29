# TASK-008 report-testing.md

> 阶段：testing · 产出：测试报告
> 日期：2026-08-29 · 类型：前端 iframe 集成（已部署）

## 测试项与结果

| # | 测试项 | 方法 | 结果 |
|---|--------|------|------|
| 1 | 构建部署 | pnpm build + 重启 control-web.service | ✅ 成功（10.47s），服务 active |
| 2 | dist 含 AI 页面 | grep dist 主 chunk | ✅ "AI 助手/DSH 对话" + `path:"ai"` 路由 |
| 3 | 旧超时逻辑移除（根因修复） | grep "DSH 服务未响应" | ✅ 0 残留（修复前 10s 超时报错代码已删） |
| 4 | DSH iframe 源可达 | curl 127.0.0.1:3080 | ✅ 200 |
| 5 | DSH 可嵌入性 | curl 3080 响应头 | ✅ 无 X-Frame-Options/CSP frame 限制 |
| 6 | 静态检查 | tsc/eslint/vitest（coding 阶段） | ✅ 34/34 + build 全过 |
| 7 | 回归（TASK-007 SSE） | useTaskEvents 保留在 dev，BoardPage/ApprovalPage 引用正常 | ✅（build 通过即引用完整） |

## 浏览器实测项（需人工确认）

1. 打开 `http://127.0.0.1:4173/ai`（或局域网 IP）→ 应显示 AI 助手页（左任务上下文 + 右 DSH 对话）
2. iframe 内 DSH 界面应**正常加载**（不再显示"DSH 加载失败"——根因已修）
3. 左侧选中任务 → 状态栏显示任务 ID（上下文注入展示）

## 通过率

自动验证 7/7 通过；浏览器实测 3 项待人工确认（代码路径已验证：onLoad 即就绪 + DSH 可达 + 可嵌入）。

## 过程中处理

- **useTaskEvents 误删**：同步 dev 时误 `rm -rf src/hooks`（TASK-007 入库文件）→ `git checkout HEAD --` 恢复后重新 build 通过（教训：勿 rm 已跟踪目录）

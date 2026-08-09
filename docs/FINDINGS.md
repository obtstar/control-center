# FINDINGS — 平台发现问题一览

登记规则见 [18.5 发现问题登记](architecture/18-authority.md)：先记录再汇报；fixed 附 commit，wontfix 附人的理由。
本表为权威源；web 问题一览为派生视图。

| ID | 日期 | 来源 | 现象 | 证据 | 影响 | 状态 | 去向 |
|----|------|------|------|------|------|------|------|
| FINDING-001 | 2026-08-09 | 架构评审（kimi） | `advance` 动作无任何角色/状态校验，任意登录用户可推过 approval required 阶段，且不在 OAS 契约内 | control-api/internal/api/tasks.go:102-115 | 审批闸整体可绕过，"逐步审批"前提架空 | open | |
| FINDING-002 | 2026-08-09 | 架构评审（kimi） | 熔断（连败3次/token阈值）声明未实现：pipeline.yaml 的 circuit_breaker 等字段被 yaml.Unmarshal 静默丢弃；实际语义为单次失败即暂停 | control-center/orchestration/workflows/pipeline.yaml:72-75；control-api/internal/pipeline/pipeline.go:13-18；engine.go:37-42 | 声明与实现不符且无报错，最坏的一种未实现 | open | |
| FINDING-003 | 2026-08-09 | 架构评审（kimi） | merge 阶段断头路：team_mr_review 不触发审批等待（NeedsApproval 只认 required），无 webhook 端点，merged 状态全代码无赋值点 | control-api/internal/pipeline/pipeline.go:84-88；internal/api/server.go:56-63 | 任务到 merge 只能人工 advance，终审机制不存在 | open | |
| FINDING-004 | 2026-08-09 | 架构评审（kimi） | 常量时间比较为恒真死代码：subtle.ConstantTimeCompare([]byte(token), []byte(token)) 自己比自己 | control-api/internal/authn/authn.go:97 | 安全剧场，误导审计 | open | |
| FINDING-005 | 2026-08-09 | 架构评审（kimi） | work_log hash 链：查 prev 与 INSERT 不在事务中，并发写（engine goroutine）可分叉；Scan 错误被吞；无重算校验工具 | control-api/internal/store/domain.go:68-78 | 审计链完整性不可信 | open | |
| FINDING-006 | 2026-08-09 | 架构评审（kimi） | watcher 非递归：只监听 tasks/ 根目录，TASK-xxx/ 子目录 task.md 修改不产生事件，增量同步近乎失效 | control-api/internal/watcher/watcher.go:39 | 人工改 task.md 时看板索引不刷新 | open | |
| FINDING-007 | 2026-08-09 | 架构评审（kimi） | detailActor 硬编码返回 "agent"，人执行的 pause/resume 在 work_log.operator 也记为 agent | control-api/internal/engine/engine.go:165 | 审计语义失真，违反"记录审批人" | open | |
| FINDING-008 | 2026-08-09 | 架构评审（kimi） | pipeline.yaml 热加载未实现：仅在启动时加载一次 | control-api/internal/api/server.go:35 | 编排修改需重启，与 README 声明不符 | open | |
| FINDING-009 | 2026-08-09 | 架构评审（kimi） | nextTaskID 读目录 max+1 有竞态；title/body 直接 fmt.Sprintf 进 frontmatter，含冒号/换行产生非法 YAML | control-api/internal/api/tasks.go:133-148, 44-57 | 并发撞号；任务文件可被标题注入破坏 | open | |
| FINDING-010 | 2026-08-09 | 架构评审（kimi） | config.Save 可能将 env 注入的 api_key 序列化落盘；Server.APIKey/LLM.APIKey 加载后无使用点（死配置） | control-api/internal/config/config.go:26, 143-148 | 密钥不落盘原则存在顺序脆弱性 | open | |
| FINDING-011 | 2026-08-09 | 架构评审（kimi） | Reject 不校验当前状态，仅靠 store.Decide 的 decision IS NULL 兜底 | control-api/internal/engine/engine.go:120-131 | 非法流转校验缺一角 | open | |
| FINDING-012 | 2026-08-09 | 架构评审（kimi） | control-api 无 DEPENDENCIES.md（CONVENTIONS.md 要求登记）；engine 包零测试（违反"状态机迁移必须覆盖非法流转"） | control-api/CONVENTIONS.md:13, 39 | 规约自相矛盾地未被遵守 | open | |
| FINDING-013 | 2026-08-09 | API 契约核对（kimi） | openapi.yaml 声明 3.1.0 但使用 8 处 nullable: true（3.0 语法，3.1 已删除） | control-api/docs/api/openapi.yaml | 契约文件本身不过 3.1 校验 | open | |
| FINDING-014 | 2026-08-09 | API 契约核对（kimi） | 实现超出契约：action 支持 advance/pause/resume 与 POST /tasks，均未登记；契约承诺失真：status 枚举含永不出现的 merged、bearerFormat 标 JWT 实为 opaque token | control-api/docs/api/openapi.yaml vs internal/api | 契约与实现双向漂移，无对账机制 | open | |
| FINDING-015 | 2026-08-09 | API 契约核对（kimi） | OAS 契约三份副本（TASK-002 设计 / control-api / control-web），无单一可信源声明 | control-center/tasks/TASK-002/design-openapi.yaml 等 | 副本各自漂移风险 | open | |
| FINDING-016 | 2026-08-09 | 集成核查（kimi） | control-api ↔ PieKBS 无任何代码级集成（全仓无 MCP/kb_search 调用）；grounding 仅靠 prompt 注入 skill；"有据可依"无代码级强制 | control-api 全仓 grep | 18.3 grounding 无结构性保障 | open | |
| FINDING-017 | 2026-08-09 | 集成核查（kimi） | 知识链路未通：wiki/ 四个产物目录全空；distill 已配置但 LiteLLM 网关不可达（litellm.internal DNS 解析失败），端到端未验证；wiki-maintenance cron 依赖 serve 常驻，未装服务 | control-wiki/wiki/；control-wiki/config.yaml | 蒸馏/检索能力当前不可用 | open | |
| FINDING-018 | 2026-08-09 | 架构评审（kimi） | control-center/scripts 仍安装 JDK/Maven（Java 时代遗留），与 Go 实现无关 | control-center/scripts/lib/toolchain.sh | 环境冗余，文档已修正但脚本未清理 | open | |
| FINDING-019 | 2026-08-09 | 架构评审（kimi） | TASK-001 repo_key=billing-core 未登记在 registry/repos.yaml（仅为注释示例） | control-center/tasks/TASK-001/task.md；registry/repos.yaml | 任务指向不存在的仓库登记 | open | |
| FINDING-020 | 2026-08-09 | 架构评审（kimi） | sessions.expires_at 声明 DATETIME 实存 Unix 秒整数；server.go:46 / agent.go:53 吞 os.MkdirAll/WriteFile 错误 | control-api/internal/store/store.go:81, domain.go:188 | 类型不一致隐患；错误被吞难排查 | open | |
| FINDING-021 | 2026-08-09 | web 完善（kimi） | control-web 构建单 chunk 722.8 kB（PrimeReact/主题整包引入），未做代码分割 | control-web vite build 警告 | 首屏加载体积大 | open | |
| FINDING-022 | 2026-08-09 | web 完善（kimi） | control-web 无 router 级测试基建，路由兜底分流逻辑（NotFoundRedirect）无测试覆盖 | control-web/src/router/router.tsx | 路由行为回归无保障 | open | |
| FINDING-023 | 2026-08-09 | web 核查（kimi） | 审批对话框编程式关闭不触发 onHide，再次打开残留上一条批注 | control-web/src/components/ApprovalDialog.tsx | 审批操作数据串扰 | fixed | 工作区待提交 |
| FINDING-024 | 2026-08-09 | web 核查（kimi） | 前端无 401 处理：token 过期后列表页仅 Toast 报错，不登出不跳转 | control-web/src/api/client.ts | 会话过期体验断裂 | fixed | 工作区待提交 |
| FINDING-025 | 2026-08-09 | web 核查（kimi） | 看板只读无刷新入口；路由 * 兜底一律跳 /login 不分登录态；5 处 error 强转绕过生成的 Error schema | control-web BoardPage.tsx / router.tsx:38 / 各页面 | MVP 功能缺口 + 类型弱化 | fixed | 工作区待提交 |

## 已修复（留存痕）

- 2026-08-09：README/DEPENDENCIES 的 Java Spring Boot 表述 → 已更正为 Go/占位仓库（control-center 工作区改动，待提交）
- 2026-08-09：deploy/docker-compose.yml MySQL/Redis/Milvus 形态 → 已重写为 Go/SQLite 两服务
- 2026-08-09：06-web.md 后端 Spring Boot 表述 → 已更正为 control-api（Go）+ OAS 3.1 契约

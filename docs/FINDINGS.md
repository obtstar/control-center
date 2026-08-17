# FINDINGS — 平台发现问题一览

登记规则见 [18.5 发现问题登记](architecture/18-authority.md)：先记录再汇报；fixed 附 commit，wontfix 附人的理由。
本表为权威源；web 问题一览为派生视图。

| ID | 日期 | 来源 | 现象 | 证据 | 影响 | 状态 | 去向 |
|----|------|------|------|------|------|------|------|
| FINDING-001 | 2026-08-09 | 架构评审（kimi） | `advance` 动作无任何角色/状态校验，任意登录用户可推过 approval required 阶段，且不在 OAS 契约内 | control-api/internal/api/tasks.go:102-115 | 审批闸整体可绕过，"逐步审批"前提架空 | fixed | control-api b779a29 |
| FINDING-002 | 2026-08-09 | 架构评审（kimi） | 熔断（连败3次/token阈值）声明未实现：pipeline.yaml 的 circuit_breaker 等字段被 yaml.Unmarshal 静默丢弃；实际语义为单次失败即暂停 | control-center/orchestration/workflows/pipeline.yaml:72-75；control-api/internal/pipeline/pipeline.go:13-18；engine.go:37-42 | 声明与实现不符且无报错，最坏的一种未实现 | fixed | control-api f4571e9 + control-center e3fb15f（token 预算暂无数据源，声明已标注） |
| FINDING-003 | 2026-08-09 | 架构评审（kimi） | merge 阶段断头路：team_mr_review 不触发审批等待（NeedsApproval 只认 required），无 webhook 端点，merged 状态全代码无赋值点 | control-api/internal/pipeline/pipeline.go:84-88；internal/api/server.go:56-63 | 任务到 merge 只能人工 advance，终审机制不存在 | fixed | control-api 8eda714 + control-web b89d509 |
| FINDING-004 | 2026-08-09 | 架构评审（kimi） | 常量时间比较为恒真死代码：subtle.ConstantTimeCompare([]byte(token), []byte(token)) 自己比自己 | control-api/internal/authn/authn.go:97 | 安全剧场，误导审计 | fixed | control-api b779a29 |
| FINDING-005 | 2026-08-09 | 架构评审（kimi） | work_log hash 链：查 prev 与 INSERT 不在事务中，并发写（engine goroutine）可分叉；Scan 错误被吞；无重算校验工具 | control-api/internal/store/domain.go:68-78 | 审计链完整性不可信 | fixed | control-api c532d5a（事务化 + verify-log；存量链校验通过 19 条） |
| FINDING-006 | 2026-08-09 | 架构评审（kimi） | watcher 非递归：只监听 tasks/ 根目录，TASK-xxx/ 子目录 task.md 修改不产生事件，增量同步近乎失效 | control-api/internal/watcher/watcher.go:39 | 人工改 task.md 时看板索引不刷新 | fixed | control-api a8bf5f4 |
| FINDING-007 | 2026-08-09 | 架构评审（kimi） | detailActor 硬编码返回 "agent"，人执行的 pause/resume 在 work_log.operator 也记为 agent | control-api/internal/engine/engine.go:165 | 审计语义失真，违反"记录审批人" | fixed | control-api 13382b2 |
| FINDING-008 | 2026-08-09 | 架构评审（kimi） | pipeline.yaml 热加载未实现：仅在启动时加载一次 | control-api/internal/api/server.go:35 | 编排修改需重启，与 README 声明不符 | fixed | control-api fd923f5 |
| FINDING-009 | 2026-08-09 | 架构评审（kimi） | nextTaskID 读目录 max+1 有竞态；title/body 直接 fmt.Sprintf 进 frontmatter，含冒号/换行产生非法 YAML | control-api/internal/api/tasks.go:133-148, 44-57 | 并发撞号；任务文件可被标题注入破坏 | fixed | control-api fd923f5 |
| FINDING-010 | 2026-08-09 | 架构评审（kimi） | config.Save 可能将 env 注入的 api_key 序列化落盘；Server.APIKey/LLM.APIKey 加载后无使用点（死配置） | control-api/internal/config/config.go:26, 143-148 | 密钥不落盘原则存在顺序脆弱性 | fixed | control-api fd923f5 |
| FINDING-011 | 2026-08-09 | 架构评审（kimi） | Reject 不校验当前状态，仅靠 store.Decide 的 decision IS NULL 兜底 | control-api/internal/engine/engine.go:120-131 | 非法流转校验缺一角 | fixed | control-api f4571e9 |
| FINDING-012 | 2026-08-09 | 架构评审（kimi） | control-api 无 DEPENDENCIES.md（CONVENTIONS.md 要求登记）；engine 包零测试（违反"状态机迁移必须覆盖非法流转"） | control-api/CONVENTIONS.md:13, 39 | 规约自相矛盾地未被遵守 | fixed | control-api f4571e9 |
| FINDING-013 | 2026-08-09 | API 契约核对（kimi） | openapi.yaml 声明 3.1.0 但使用 8 处 nullable: true（3.0 语法，3.1 已删除） | control-api/docs/api/openapi.yaml | 契约文件本身不过 3.1 校验 | fixed | control-api b779a29 |
| FINDING-014 | 2026-08-09 | API 契约核对（kimi） | 实现超出契约：action 支持 advance/pause/resume 与 POST /tasks，均未登记；契约承诺失真：status 枚举含永不出现的 merged、bearerFormat 标 JWT 实为 opaque token | control-api/docs/api/openapi.yaml vs internal/api | 契约与实现双向漂移，无对账机制 | fixed | control-api b779a29 |
| FINDING-015 | 2026-08-09 | API 契约核对（kimi） | OAS 契约三份副本（TASK-002 设计 / control-api / control-web），无单一可信源声明 | control-center/tasks/TASK-002/design-openapi.yaml 等 | 副本各自漂移风险 | open | |
| FINDING-016 | 2026-08-09 | 集成核查（kimi） | control-api ↔ PieKBS 无任何代码级集成（全仓无 MCP/kb_search 调用）；grounding 仅靠 prompt 注入 skill；"有据可依"无代码级强制 | control-api 全仓 grep | 18.3 grounding 无结构性保障 | fixed | control-api 6f31482（窄接口 + REST 实现 + warn/enforce 模式，默认 off 待 KB 链路通） |
| FINDING-017 | 2026-08-09 | 集成核查（kimi） | 知识链路未通：wiki/ 四个产物目录全空；distill 已配置但 LiteLLM 网关不可达（litellm.internal DNS 解析失败），端到端未验证；wiki-maintenance cron 依赖 serve 常驻，未装服务 | control-wiki/wiki/；control-wiki/config.yaml | 蒸馏/检索能力当前不可用 | open | 外部依赖：网关恢复后验证 |
| FINDING-018 | 2026-08-09 | 架构评审（kimi） | control-center/scripts 仍安装 JDK/Maven（Java 时代遗留），与 Go 实现无关 | control-center/scripts/lib/toolchain.sh | 环境冗余，文档已修正但脚本未清理 | open | |
| FINDING-019 | 2026-08-09 | 架构评审（kimi） | TASK-001 repo_key=billing-core 未登记在 registry/repos.yaml（仅为注释示例） | control-center/tasks/TASK-001/task.md；registry/repos.yaml | 任务指向不存在的仓库登记 | open | |
| FINDING-020 | 2026-08-09 | 架构评审（kimi） | sessions.expires_at 声明 DATETIME 实存 Unix 秒整数；server.go:46 / agent.go:53 吞 os.MkdirAll/WriteFile 错误 | control-api/internal/store/store.go:81, domain.go:188 | 类型不一致隐患；错误被吞难排查 | fixed | control-api 46f14a4（DDL 更正 INTEGER 兼容存量；两处错误分别返错/日志） |
| FINDING-021 | 2026-08-09 | web 完善（kimi） | control-web 构建单 chunk 722.8 kB（PrimeReact/主题整包引入），未做代码分割 | control-web vite build 警告 | 首屏加载体积大 | open | |
| FINDING-022 | 2026-08-09 | web 完善（kimi） | control-web 无 router 级测试基建，路由兜底分流逻辑（NotFoundRedirect）无测试覆盖 | control-web/src/router/router.tsx | 路由行为回归无保障 | open | |
| FINDING-023 | 2026-08-09 | web 核查（kimi） | 审批对话框编程式关闭不触发 onHide，再次打开残留上一条批注 | control-web/src/components/ApprovalDialog.tsx | 审批操作数据串扰 | fixed | control-web bc24067 |
| FINDING-024 | 2026-08-09 | web 核查（kimi） | 前端无 401 处理：token 过期后列表页仅 Toast 报错，不登出不跳转 | control-web/src/api/client.ts | 会话过期体验断裂 | fixed | control-web bc24067 |
| FINDING-025 | 2026-08-09 | web 核查（kimi） | 看板只读无刷新入口；路由 * 兜底一律跳 /login 不分登录态；5 处 error 强转绕过生成的 Error schema | control-web BoardPage.tsx / router.tsx:38 / 各页面 | MVP 功能缺口 + 类型弱化 | fixed | control-web bc24067 |
| FINDING-026 | 2026-08-09 | 后端修复（kimi） | 身份传递依赖可变的 X-User/X-Role 请求头而非 context.Context；当前 withAuth 用 Header.Set 无条件覆盖（auth.go:47-48），伪造无效，但属脆弱设计（未来绕过中间件的路由会静默失守） | control-api/internal/api/auth.go:47-48 | 加固项，非现行漏洞 | open | |
| FINDING-027 | 2026-08-09 | 熔断实现（kimi） | 连败未达阈值后任务停在 pending，但无自动重跑机制（Resume 只处理 paused），重试依赖人工再触发；另 auto_pause_and_notify 的 notify 无通知通道，当前仅落日志 | control-api/internal/engine/engine.go handleRunFailure | 熔断后恢复路径不完整；通知语义未兑现 | fixed | control-api b7bcbb1 + control-center 06e343c（RetryLoop 退避重跑 + notify 落 work_log；单测 5 用例绿，活体验证走通 resume→执行→推进链） |
| FINDING-043 | 2026-08-17 | 熔断重试联调（kimi） | serve 重启不回收 running 任务：执行 goroutine 随进程死，task.md 停在 running 无任何机制重跑（TASK-001 自 08-11 僵尸至本轮人工 pause/resume 才复活）；RetryLoop 只管 pending 不管 running | control-api/internal/engine/engine.go（启动路径无 running 回收） | 运行中任务遇重启即永久卡死 | open | 启动时对 running 任务做"未完成重跑"或标记待人工，需设计决策 |
| FINDING-028 | 2026-08-09 | 问题一览实现（kimi） | parseFindings 对单元格内含 `\|` 的内容会切分错位（如行内代码中的管道符），当前权威表无此情况未做转义处理 | control-api/internal/api/findings.go | 边缘输入解析错位 | open | |
| FINDING-029 | 2026-08-09 | merge 实现（kimi） | merged 为瞬态（同请求内推进 deliver），task_index/看板几乎读不到 merged 状态，用户无法感知"已合并待交付" | control-api/internal/engine/engine.go MarkMerged | 状态可视性缺口（非功能缺陷） | open | |
| FINDING-030 | 2026-08-11 | grounding 实现（kimi） | piekbs REST 面（/api/* 含 /api/search）整体无认证，server.api_key 只保护 /mcp | control-piekbs/internal/mcp/server.go:120；internal/webui/server.go:74 | KB 检索面暴露（当前仅 127.0.0.1，风险低） | fixed | control-piekbs 4e86608（WithAPIKey 中间件 + 测试）；control-center 模板补 PIEKBS_API_KEY/CONTROL_KB_API_KEY 位；双端密钥走 env 不落盘，401/200 矩阵实测通过 |
| FINDING-031 | 2026-08-11 | grounding 实现（kimi） | enforce 模式下 Resume 会重走 grounding：KB 仍空时立即再次暂停，任务只能靠切 warn/off 或补 KB 恢复——预期行为但需运维文档说明 | control-api/internal/engine/grounding.go | 运维语义未文档化 | open | |
| FINDING-032 | 2026-08-11 | hash 链修复（kimi） | tasks.go:62 与 engine.go:67 调用 store.Log 后丢弃返回值；Log 事务化后会产生真实错误（如排队超时），这些错误被静默丢弃 | control-api/internal/api/tasks.go:62；internal/engine/engine.go:67 | 日志写入失败不可见 | fixed | control-api fd923f5 |
| FINDING-033 | 2026-08-11 | 外部评审走查（2026-08 报告） | 05/08/09/13/14/15/17 章及 architecture/README 仍含 Java Spring Boot/MySQL/Milvus/RAG 失真（01/03 章已修）；已用状态标头（设计中）隔离，逐章修订待做 | control-center/docs/architecture/ | 权柄文档存量腐化 | open | 逐章修订，随批次推进 |
| FINDING-034 | 2026-08-11 | actor 归因修复（kimi） | createTask 创建任务时 work_log operator 硬编码 "human" 而非 X-User 真实用户名 | control-api/internal/api/tasks.go:62 | 归因失真残留 | fixed | control-api fd923f5 |
| FINDING-035 | 2026-08-11 | pipeline 校验（kimi） | check 子命令不加载 pipeline，merge 权力校验只在 serve 启动路径生效 | control-api/cmd/control-api/main.go | 自检覆盖面缺口 | fixed | control-api 46f14a4（check 输出含 pipeline 行，实测通过） |
| FINDING-036 | 2026-08-11 | hook 实现（kimi） | check-conventions hook 为整仓扫描策略：他人未提交的违规（>60 行函数等）会拦截无关 commit | control-center/scripts/check-conventions.sh | 误拦截风险（设计取舍，可改 staged-only） | open | |
| FINDING-037 | 2026-08-12 | watcher 修复（kimi） | 遗留边缘语义：防抖为事件重置计时器，持续高频事件会无限推迟 sync；目录 rename 后新路径未必重新纳入（全量 Sync 兜底） | control-api/internal/watcher/watcher.go | 极端场景下索引刷新延迟 | open | |
| FINDING-038 | 2026-08-12 | 批次修复（kimi） | kb.api_key 与 server/llm api_key 同类落盘风险（有真实消费方故上轮未动）；title 含行首 `---` 仍会撞 ParseFile 分隔符探测（yaml.Marshal 正常不产生，未加固） | control-api/internal/config/config.go；internal/tasks/tasks.go | 密钥不落盘清单不全；极端 frontmatter 边界 | open | |
| FINDING-039 | 2026-08-12 | 契约测试层（kimi） | GET /api/tasks 实际响应含 path 字段（store.TaskRow），契约 Task schema 未声明；校验器按设计放行多余字段故不红。补契约或去字段属文档决策 | control-api/docs/api/openapi.yaml vs internal/store/domain.go | 契约描述不完整（不冲突） | fixed | control-api 46f14a4 + control-web 6849361（补契约 readOnly path，描述按实测更正为绝对路径） |
| FINDING-040 | 2026-08-12 | KB/Scalar 端点实现（kimi） | /api/openapi.yaml 与 findings 解析端点硬编码假设契约/FINDINGS 位于 paths.home 下的 control-api/control-center 固定相对路径，仓位置变更即 500 | control-api/internal/api/server.go | 部署形态耦合，搬仓即坏 | open | |
| FINDING-041 | 2026-08-12 | piekbs 部署（kimi） | piekbs serve 在 DISPLAY/WAYLAND_DISPLAY 已设但托盘实际不可用的环境（vscode-server/远程桌面）走 tray.Run 静默返回，进程 exit 0 无任何日志；服务器部署须 env -u DISPLAY -u WAYLAND_DISPLAY 强制 headless | control-piekbs/cmd/piekbs/main.go:458-471 runServe | serve 假启动，排查成本高（本次连死 3 次才定位） | fixed | control-piekbs 85a53d6（tray 返回回退 headless + 日志；根因：tray 实现仅 darwin，Linux 为 stub 必立即返回） |
| FINDING-042 | 2026-08-12 | piekbs 部署（kimi） | ~/.local/bin/piekbs 部署二进制（07-20）落后于仓源码（07-31 90a9438），无 rebuild/同步机制，serve 行为与源码脱节 | ~/.local/bin/piekbs vs control-piekbs | 部署漂移，已手工重编译恢复 | fixed | control-center 3f17dc5（setup-env piekbs 模块改为 fork 源码构建优先，过期自动重建） |

## 已修复（留存痕）

- 2026-08-09：README/DEPENDENCIES 的 Java Spring Boot 表述 → 已更正为 Go/占位仓库（control-center c95a46b，用户提交）
- 2026-08-09：deploy/docker-compose.yml MySQL/Redis/Milvus 形态 → 已重写为 Go/SQLite 两服务（~/deploy 非 Git 仓，无提交）
- 2026-08-09：06-web.md 后端 Spring Boot 表述 → 已更正为 control-api（Go）+ OAS 3.1 契约（control-center 4ffb4d0）

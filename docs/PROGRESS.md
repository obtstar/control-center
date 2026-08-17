# 平台规划与执行进度

更新：2026-08-17 · 分支约定：**平台当前只用 dev 分支**（main/release 暂不启用，bare 仓 HEAD 已全部指向 dev）

## 一、总体目标

个人 AI 助手平台（团队项目内）：以 control-api 为编排中枢，pi 为执行体，
按"任务即文档 + 阶段审批闸 + 权柄模型（18 章）"驱动业务项目开发。

## 二、仓库角色与约定（已对齐）

| 仓库 | 角色 | 开发方式 | 状态 |
|---|---|---|---|
| control-center | 控制面（编排/registry/scripts） | 根目录直改 dev | 已落地 |
| control-api | 平台后端（Go） | 根目录直改 dev | 已落地 |
| control-web | 平台前端（React/Vite） | 根目录直改 dev | 骨架已迁入 |
| control-db | 平台 DDL | 根目录直改 dev | 骨架 |
| control-piekbs | 知识引擎源码 | 根目录 | 在用 |
| control-wiki | piekbs 蒸馏产物（wiki/schema/index） | 权威文档在本仓 docs/architecture | 在用 |
| 业务项目（billing-* 等） | 被调度对象 | ~/wt worktree + MR | 待接入 |

**关键约定**：平台仓 `executor_allowed: false`（registry/repos.yaml 已改），
流水线只调度业务项目进 `~/wt/`；平台自身开发走根目录人工通道。

## 三、已完成

- **control-api（Go 单体）**：config/store(WAL)/api/engine/watcher/agent/authn 全骨架
  - 流水线引擎：6 阶段状态机 + 审批闸 + pause 熔断 + hash 链 work_log
  - 多真人认证：bcrypt + Bearer 会话 + 角色路由（customer/designer/tester/team/admin）
  - pi 集成：`pi --print --no-session --model <别名>` + stage/domain/enforce skill 挂载
  - API 契约：`docs/api/openapi.yaml`（OAS 3.1，kimi 产出）
  - 实测：deepseek 与 kimi 双 provider 全链路（requirements→design→coding）跑通
- **control-web MVP**（kimi 实现，TASK-002）：Vite+React+TS+PrimeReact+pnpm
  - 四页：登录/看板/审批中心/审计；openapi-typescript codegen client
  - 已迁入根目录 dev（f6c2674）；**构建验证通过**（pnpm build ✓、vitest 4 文件 10 用例 ✓）
- **编排资产**：13 skill（stage/domain/enforce 三层）+ pipeline.yaml + 3 workflow
- **环境**：gitdir 集中 ~/.repos；branch.sh；两阶段 init；主题/检查脚本

## 四、进行中 / 待办

| 项 | 说明 | 优先级 |
|---|---|---|
| control-web 构建验证 | ~~pnpm install + build + vitest~~ 已绿 | ~~高~~ |
| TASK-002 收尾 | ~~任务 paused~~ 已收尾：产物已采纳到 dev，状态置 merged | ~~中~~ |
| testing 阶段接通 | 依赖本地 docker 环境 | 中 |
| merge 阶段 webhook | 团队合并事件回传 → deliver | 低 |
| authority-gate 强化 | pi 侧权柄强制（分支写保护等） | 中 |
| wiki 文档修订 | 02/13/14 章"统一 worktree"表述→平台/业务分流（L1，人改） | 中 |

## 五、已知债

- 骨架期自举例外：control-api 早期提交直推 dev（未走 MR），已约定此后平台仓
  开发仍在根目录 dev 进行（平台=人工通道），业务项目严格 worktree+MR
- kimi 配额曾耗尽（403），deepseek 为备用 provider，模型别名映射在 ~/control-api.yaml

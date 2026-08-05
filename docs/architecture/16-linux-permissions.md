# 16 Linux 用户权限管理设计

## 16.1 定位

平台在 WSL Linux（内网）上运行，**需要 Linux 用户权限管理**。它与应用层权限（Spring Security、排班、阶段闸门）互补：

| 层级 | 控制内容 | 谁执行 |
|-----|---------|--------|
| 应用层（业务） | 允许做什么操作（排班、闸门、角色） | control-api |
| Linux 层（系统） | 以谁的身份执行、能接触哪些文件 | 用户/组/文件权限、sudoers |
| 物理层 | 进程隔离、Worktree 目录隔离 | OS |

三层叠加实现纵深防御；仅靠应用层权限无法防止 Agent 越权访问文件或绕过业务接口。

## 16.2 用户与角色规划

| Linux 用户 | 对应角色 | home | 权限 |
|-----------|---------|------|------|
| `dev-admin` | 管理员/运维 | `/home/dev-admin` | sudo（白名单）、部署、维护窗口、main/release 发布 |
| `dev-user` | 开发者/审核人 | `/home/dev` | 只读 `~/repos`、普通任务、MR 审核 |
| `agent-readonly` | 只读分析 Agent | `/home/agent-readonly` | 只读 `~/repos`、`~/control-center/docs`，禁止写 |
| `agent-auto` | 自动化任务 Agent | `/home/agent-auto` | 仅写 `~/wt/{task}` 与任务分支 |
| `agent-maintenance` | 维护窗口 Agent | `/home/agent-maintenance` | 维护窗口临时全权限（sudoers 受限） |
| `agent-exec` | 执行节点 executor（员工 PC 的 WSL） | `/home/agent-exec` | 仅写本地 `~/executor/workspace`，出站白名单见 16.8 |

> **Agent 一律用非 root 的独立系统账号运行**，无 sudo；防止 Agent 逃逸权限。

## 16.3 目录与组权限

| 目录 | 属主:属组 | 权限 | 说明 |
|-----|----------|------|------|
| `~/control-center` | `dev-admin:dev-group` | `750` | 设计文档 + 编排配置 |
| `~/repos` | `dev-admin:dev-group` | `770` | 代码仓库；dev-user 读写，agent-readonly 只读 |
| `~/wt` | `agent-admin:agent-group` | `770` | Agent 独占工作区 |
| `~/data`、`~/logs` | `dev-admin:dev-group` | `750` | 服务数据与日志 |

## 16.4 Agent 权限矩阵（与排班时段联动）

| 时段 | 使用用户 | 可写范围 | 禁止 |
|-----|---------|---------|------|
| 工作日 09:00-18:00 | `agent-readonly` | 无（只读 `~/repos`、docs） | 一切写操作 |
| 夜间 02:00-06:00 | `agent-auto` | `~/wt/{task-id}-*` | main/release 分支、非任务目录 |
| 维护窗口 | `agent-maintenance` | 全（需审批号） | 无 |

## 16.5 sudoers 规则（白名单）

```bash
# /etc/sudoers.d/agent-control
# Agent 用户无 sudo
# dev-user 仅允许受限 git 操作
dev-user ALL=(root) /usr/bin/git push origin dev
# 部署/发布 main、release 需 dev-admin，且必须带审批脚本
dev-admin ALL=(root) /opt/control/bin/release.sh
```

- Agent 用户不在 sudoers 中
- 发布 main/release 的脚本校验 `approval_no`（来自审批表 approval.approval_no），无审批号拒绝执行
- 所有 sudo 调用写入 `/var/log/secure`，与应用日志交叉核对

## 16.6 审计

- 文件级：目录 ACL、sudo 日志、`~/logs` 服务日志
- 进程级：Agent 进程以独立用户运行，systemd/journal 记录启动与命令
- 关联：`work_log.operator` 记录 Linux 用户名 + 排班时段，可与系统审计（sudo/ACL/journal）交叉核对，保证"谁在何时以何身份执行了什么"

## 16.7 与应用层权限的双重校验

任务执行时 control-api 做**双检**：

1. **应用层**：排班时段 + 角色允许该操作（READ_ONLY / AUTO_TASK / FULL）
2. **Linux 层**：当前执行用户与排班时段指定用户一致（`agent-auto` 只能夜间使用），且目标路径在授权范围内

不满足任一校验即拒绝并记录 `work_log`。这样即使应用层被绕过，Linux 文件/进程权限仍构成物理隔离兜底。

## 16.8 执行节点（executor PC）权限模型

executor 代理在员工 PC 的 WSL 上运行（见 [10 executor 代理](10-deployment.md)），权限模型作如下延伸：

| 项 | 规则 |
|---|------|
| 执行身份 | executor 服务固定以专用账号 `agent-exec` 运行（非 root、无 sudo），**与 PC 使用者的个人账号隔离** |
| 工作区 | `~/executor/workspace` 视为 Worktree 的延伸（**临时执行区**），任务结束即清理；等价于 16.4 的授权范围外移 |
| 时段约束 | 16.7 双检在**编排层**完成（排班 + 角色）；executor 不自行决定时段——夜间任务只在夜间由 control-api 派发 |
| 出站白名单 | 执行节点放行且仅放行：control-api、`git.internal`、企业 LiteLLM 代理端点（02 章白名单在执行节点上的口径） |
| 机密仓库 | `repository` 标记为不分发的仓库不下发 executor，仅在编排节点执行（10 章约束） |

### 容器化与多用户身份的关系

control-api 运行于 Docker 容器，**不直接以容器身份创建 Agent 进程**（容器内无法切换宿主 Linux 用户）。Agent/executor 进程的运行载体为：

- 编排节点本机任务：宿主机 **systemd 服务**（以 `agent-readonly` / `agent-auto` / `agent-maintenance` 身份运行），control-api 仅下发指令
- 执行节点任务：executor 服务（以 `agent-exec` 身份运行），经 `/api/agents/*` 端点领取与回传

Linux 用户身份在执行载体上生效，16.7 双检的"用户一致性"校验对象为执行载体的身份。

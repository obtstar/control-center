# 11 安全与合规

> Linux 用户/组权限、Agent 沙箱、sudoers 白名单见 [16 Linux 权限管理](16-linux-permissions.md)。

| 风险 | 对策 |
|-----|------|
| 代码外泄 | 代码/数据全内网；出站防火墙仅放行企业内 LiteLLM 代理及其白名单模型端点（api.anthropic.com、api.githubcopilot.com），pi.dev 与其余流量不出网 |
| AI 生成代码质量 | 强制单元测试 + 人工审核 + 渐进式放权 |
| Agent 行为失控 | 阶段闸门 + 排班权限 + Linux 用户/文件权限物理隔离 + 操作日志全追溯 |
| 自我升级风险 | 升级配置双人审批 + 灰度发布 |
| 审计合规 | MySQL `work_log` 结构化日志（禁止物理删除），与 Linux 审计交叉核对，支持 SIEM 对接 |

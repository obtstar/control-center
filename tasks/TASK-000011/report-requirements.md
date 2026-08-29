# TASK-000011 影响分析报告（requirements）

> 任务：FINDING-017：KB 蒸馏链路恢复
> 阶段：requirements · 日期：2026-08-29

## 1. 现状探测（实测）

| 项 | 结果 |
|----|------|
| LiteLLM 网关（litellm.internal:4000/health） | ❌ **HTTP 000 不可达**（DNS/连接失败）——FINDING-017 阻塞项仍在 |
| distill.token | 空（PIEKBS_DISTILL_TOKEN 未注入） |
| KB 蒸馏产物 | ✅ 已有：wiki/source-notes/{control-api-openapi, platform}（DSH wiki-distill 技能替代产出，FINDING-052 修复后存活正常） |
| raw 层 | ✅ converted/oas/platform（28 对镜像 + OAS 规范）可 FTS 检索 |

## 2. 阻塞分析

**核心阻塞：LiteLLM 网关不可达（外部环境因素）**——AGENTS.md §10-8 恢复手册第 1 步（curl health 确认通）即失败，后续（env 注入 token → 重启 piekbs-mcp → 自动蒸馏）均依赖网关就绪。

## 3. 可先行项（不依赖网关）

1. 准备 env 文件位：`~/.config/piekbs/env`（PIEKBS_DISTILL_TOKEN 占位，0600）——网关恢复后填真值
2. 蒸馏配置核对：config.yaml distill 段（token 走 env，endpoint 默认 litellm.internal）
3. 恢复手册步骤固化（AGENTS.md §10-8 已有）

## 4. 结论：阻塞

- 网关恢复为**外部前置**（litellm.internal 可达性由网络/网关方决定，本机不可修复）
- 建议：任务**暂缓/暂停**，待网关恢复后按手册执行（resume → 注入 token → 重启 → 蒸馏验证）
- 网关恢复后验收：①wiki/source-notes/ 出页 ②piekbs status 计数上涨 ③FTS 命中 ④grounding enforce 评估

## 5. 依据

- FINDING-017（open，网关阻塞）；AGENTS.md §10-8 恢复手册；FINDING-050（piekbs-mcp 常驻已就绪）

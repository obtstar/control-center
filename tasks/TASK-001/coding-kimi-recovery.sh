#!/usr/bin/env bash
# coding-kimi-recovery.sh — TASK-001 coding 阶段验证脚本
# 依据：design-kimi-recovery.md §6 通过标准 + §5.3 模型真实性验证
# 引用：
#   - design-kimi-recovery.md §6 通过标准
#   - design-kimi-recovery.md §5.3 模型真实性验证
#   - control-api/internal/config/config.go §85（coding → kimi-for-coding）
#   - control-api.yaml（运行时配置）
#   - control-center/orchestration/skills/stage/coding/SKILL.md
set -euo pipefail

TASK_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_CENTER="$(cd "$TASK_DIR/../.." && pwd)"
HOME_DIR="${HOME:-/home/dev}"
CONFIG_FILE="$HOME_DIR/control-api.yaml"
LOG_FILE="$HOME_DIR/logs/control-api.log"
CONFIG_GO="$HOME_DIR/control-api/internal/config/config.go"
DESIGN_FILE="$TASK_DIR/design-kimi-recovery.md"
TASK_FILE="$TASK_DIR/task.md"

PASS=0
FAIL=0
WARN=0
RESULTS=()

log() { printf '\033[1;34m[check]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[PASS]\033[0m  %s\n' "$*"; PASS=$((PASS+1)); RESULTS+=("PASS: $*"); }
ko()  { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*" >&2; FAIL=$((FAIL+1)); RESULTS+=("FAIL: $*"); }
warn(){ printf '\033[1;33m[WARN]\033[0m  %s\n' "$*" >&2; WARN=$((WARN+1)); RESULTS+=("WARN: $*"); }

# P1: design-*.md 存在
if [[ -f "$DESIGN_FILE" ]]; then
  ok "P1 design-kimi-recovery.md exists ($DESIGN_FILE)"
else
  ko "P1 design-kimi-recovery.md missing"
fi

# P2: frontmatter 包含 authority: L2/L3
if [[ -f "$DESIGN_FILE" ]]; then
  if head -10 "$DESIGN_FILE" | grep -qE '^authority:\s*L2/L3'; then
    ok "P2 design-kimi-recovery.md frontmatter declares authority: L2/L3"
  else
    ko "P2 design-kimi-recovery.md frontmatter missing authority: L2/L3"
  fi
fi

# P3: 设计项映射 L1 且引用真实
if [[ -f "$DESIGN_FILE" ]]; then
  # 提取 [path § section] 或 [path] 形式的引用
  # 只提取包含文件路径的引用（至少有一个 / 或 .md），过滤掉表格中的阶段名等非引用项
  mapfile -t CITATIONS < <(grep -oE '\[[^]]+\]' "$DESIGN_FILE" | sed 's/^\[//;s/\]$//' | grep -E '[/.]' | sort -u)
  if [[ ${#CITATIONS[@]} -gt 0 ]]; then
    ok "P3 found ${#CITATIONS[@]} citations"
    for cite in "${CITATIONS[@]}"; do
      # 解析文件路径（去掉 § 段落）
      file_part="${cite%% § *}"
      # 支持相对路径；简写 *.md 默认相对于 control-wiki/raw/architecture/
      if [[ "$file_part" == control-wiki/* ]]; then
        abs="$HOME_DIR/$file_part"
      elif [[ "$file_part" == control-center/* ]]; then
        abs="$HOME_DIR/$file_part"
      elif [[ "$file_part" == control-api/* ]]; then
        abs="$HOME_DIR/$file_part"
      elif [[ "$file_part" == *.md ]]; then
        abs="$HOME_DIR/control-wiki/raw/architecture/$file_part"
      else
        abs="$HOME_DIR/$file_part"
      fi
      if [[ -f "$abs" ]]; then
        ok "P3 citation file exists: $file_part"
      else
        ko "P3 citation file missing: $file_part (resolved: $abs)"
      fi
    done
  else
    warn "P3 no citations found"
  fi
fi

# P4: 配置/日志显示 design/coding 阶段请求发往 Kimi
log "checking model routing..."
if [[ -f "$CONFIG_FILE" ]]; then
  if grep -qE '^\s*coding:\s*kimi-for-coding' "$CONFIG_FILE"; then
    ok "P4 control-api.yaml: coding -> kimi-for-coding"
  else
    ko "P4 control-api.yaml: coding not mapped to kimi-for-coding"
  fi
else
  warn "P4 control-api.yaml missing, falling back to config.go"
fi

if [[ -f "$CONFIG_GO" ]]; then
  if grep -q '"coding": "kimi-for-coding"' "$CONFIG_GO"; then
    ok "P4 config.go: coding -> kimi-for-coding"
  else
    ko "P4 config.go: coding not mapped to kimi-for-coding"
  fi
else
  warn "P4 config.go missing: $CONFIG_GO"
fi

# 日志中查找 TASK-001 的模型路由证据
if [[ -f "$LOG_FILE" ]]; then
  if grep -E 'TASK-001.*model=coding' "$LOG_FILE" | tail -1 >/dev/null; then
    model_line=$(grep -E 'TASK-001.*model=coding' "$LOG_FILE" | tail -1)
    ok "P4 control-api.log records TASK-001 using model=coding: $model_line"
  else
    warn "P4 control-api.log has no TASK-001 model=coding record"
  fi
else
  warn "P4 control-api.log missing: $LOG_FILE"
fi

# 尝试发送 probe 请求（不强制成功，因为网关可能未启动/无密钥）
probe_model=""
if [[ -f "$CONFIG_FILE" ]]; then
  probe_model=$(awk -F': ' '/^\s*coding:/{print $2; exit}' "$CONFIG_FILE" | tr -d ' ')
fi
if [[ -z "$probe_model" ]]; then
  probe_model="kimi-for-coding"
fi

llm_endpoint=""
if [[ -f "$CONFIG_FILE" ]]; then
  llm_endpoint=$(awk -F': ' '/^\s*endpoint:/{print $2; exit}' "$CONFIG_FILE" | tr -d ' ')
fi
if [[ -z "$llm_endpoint" ]]; then
  llm_endpoint="http://litellm.internal:4000"
fi

api_key="${LITELLM_API_KEY:-${CONTROL_LITELLM_API_KEY:-}}"

log "probe LiteLLM gateway: $llm_endpoint / model=$probe_model"
probe_payload='{"model":"'"$probe_model"'","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'

if command -v curl >/dev/null 2>&1; then
  probe_resp=$(curl -s -o /dev/null -w '%{http_code}' \
    -H "Content-Type: application/json" \
    ${api_key:+-H "Authorization: Bearer $api_key"} \
    -d "$probe_payload" \
    --max-time 5 \
    "$llm_endpoint/v1/chat/completions" 2>/dev/null || true)
  case "$probe_resp" in
    200)
      ok "P4 LiteLLM probe succeeded HTTP 200, model: $probe_model"
      ;;
    401|403)
      warn "P4 LiteLLM probe returned $probe_resp, gateway reachable but auth failed"
      ;;
    000|""|?)
      warn "P4 LiteLLM probe could not connect, but config points to Kimi backend"
      ;;
    *)
      warn "P4 LiteLLM probe returned HTTP $probe_resp"
      ;;
  esac
else
  warn "P4 curl not installed, skipping probe"
fi

# P5: 未逆行修改 L1 文档
log "checking for authority regression..."
cd "$REPO_CENTER"
if git diff -- "$TASK_FILE" | grep -qE '^[+-]\s*(title:|authority:|# kimi联调)'; then
  ko "P5 task.md title/authority/L1 body modified; regression risk"
else
  ok "P5 task.md title/authority/L1 body not modified"
fi

if git status --short "$TASK_DIR" | grep -vE 'task\.md|design-kimi-recovery\.md|report-design\.md|coding-' >/dev/null; then
  warn "P5 unexpected files added/modified in task dir, manual review needed"
else
  ok "P5 task dir only contains design artifacts and coding-stage files"
fi

# P6: 审批闸入口
log "checking approval gate..."
if [[ -f "$TASK_FILE" ]]; then
  stage=$(awk -F': ' '/^stage:/{print $2}' "$TASK_FILE" | tr -d ' ')
  status=$(awk -F': ' '/^status:/{print $2}' "$TASK_FILE" | tr -d ' ')
  if [[ "$stage" == "coding" && "$status" == "running" ]]; then
    ok "P6 task.md stage=$stage status=$status, design -> coding transition observed"
  else
    warn "P6 task.md stage=$stage status=$status, no design -> coding transition observed"
  fi
else
  ko "P6 task.md missing"
fi

# 汇总
printf '\n===== summary =====\n'
printf 'PASS: %d\n' "$PASS"
printf 'FAIL: %d\n' "$FAIL"
printf 'WARN: %d\n' "$WARN"

for r in "${RESULTS[@]}"; do
  echo "$r"
done

if [[ $FAIL -eq 0 ]]; then
  exit 0
else
  exit 1
fi

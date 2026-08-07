#!/usr/bin/env bash
# agent.sh — 由 setup-env.sh source（依赖 common.sh）

install_pi_packages() {
  # pi（Earendil Pi Coding Agent，以工作用户身份装入其用户级 npm）
  if as_target_user "$USER_ENV command -v pi" &>/dev/null; then
    if confirm_opt "pi 已安装，是否升级？"; then
      as_target_user "$USER_ENV npm update -g --ignore-scripts @earendil-works/pi-coding-agent --registry='$NPM_REGISTRY'" \
        && log "pi 升级完成" || warn "pi 升级失败（保留现有版本）"
    else
      log "pi 已安装，跳过"
    fi
  elif as_target_user "$USER_ENV command -v npm" &>/dev/null; then
    as_target_user "$USER_ENV npm install -g --ignore-scripts @earendil-works/pi-coding-agent --registry='$NPM_REGISTRY'" \
      && log "pi 安装完成" || warn "pi 安装失败（网络受限？可 vendor 后重试）"
  else
    warn "npm 未安装，跳过 pi（先在工具链步骤安装 Node.js）"
  fi

  # openskills（07.3：SKILL.md 技能管理）
  if as_target_user "$USER_ENV command -v openskills" &>/dev/null; then
    if confirm_opt "openskills 已安装，是否升级？"; then
      as_target_user "$USER_ENV npm update -g --ignore-scripts openskills --registry='$NPM_REGISTRY'" \
        && log "openskills 升级完成" || warn "openskills 升级失败（保留现有版本）"
    else
      log "openskills 已安装，跳过"
    fi
  elif as_target_user "$USER_ENV command -v npm" &>/dev/null; then
    as_target_user "$USER_ENV npm install -g --ignore-scripts openskills --registry='$NPM_REGISTRY'" \
      && log "openskills 安装完成" || warn "openskills 安装失败，可后续手动安装"
  fi

  # pi-di18n（中文界面，可选）
  if as_target_user "$USER_ENV command -v pi" &>/dev/null \
     && confirm_opt "添加 pi-di18n 并切换中文界面？"; then
    if as_target_user "$USER_ENV pi install npm:pi-di18n"; then
      local s="$BASE_HOME/.pi/settings.json"
      [[ -f "$s" ]] && sed -i 's/"locale": "[^"]*"/"locale": "zh-CN"/' "$s" 2>/dev/null || true
      [[ -f "$s" ]] && own "$s"
      log "pi-di18n 已安装，locale=zh-CN"
    else
      warn "pi-di18n 安装失败（可稍后手动: pi install npm:pi-di18n）"
    fi
  fi
}

# 5b. 配置落盘（人工通道与 agent 通道各自调用）
install_agent_tooling() { # $1=目标 home $2=目标用户（可选，root 时 chown）
  local home="$1" user="${2:-}"

  # ~/.pi/models.json：自定义 provider 指向企业 LiteLLM 代理（04 章）
  mkdir -p "$home/.pi"
  if [[ ! -f "$home/.pi/models.json" ]]; then
    cat > "$home/.pi/models.json" <<EOF
{
  "providers": [{
    "name": "litellm-enterprise",
    "base_url": "$LITELLM_ENDPOINT/v1",
    "api_key": "\${LITELLM_API_KEY}",
    "models": ["coding", "cheap", "heavy"]
  }]
}
EOF
    chmod 600 "$home/.pi/models.json"
    log "已生成 $home/.pi/models.json（LiteLLM 代理，别名 coding/cheap/heavy）"
  fi

  # 5.2b pi 基本设置：访问范围限定工作用户 home，敏感路径保护（16 章纵深防御）
  local settings="$home/.pi/settings.json"
  if [[ ! -f "$settings" ]]; then
    cat > "$settings" <<EOF
{
  "allow_paths": ["$BASE_HOME"],
  "protected_paths": [
    "/etc", "/root", "/boot",
    "$BASE_HOME/.ssh",
    "$BASE_HOME/.config",
    "$BASE_HOME/control.env",
    "$BASE_HOME/deploy/.env"
  ],
  "locale": "en"
}
EOF
    chmod 600 "$settings"
    log "已生成 $settings（访问范围限定 $BASE_HOME，敏感路径保护）"
  fi
  # 立即归属目标用户（后续 di18n 等以 dev 身份读写，避免 EACCES）
  if [[ $EUID -eq 0 && -n "$user" ]] && id "$user" &>/dev/null; then
    chown -R "$user:$user" "$home/.pi"
  fi

  # 技能目录软链：~/.pi/skills → 控制中心 orchestration/skills（Git 版本化）
  if [[ -d "$BASE_HOME/control-center/orchestration/skills" ]]; then
    ln -sfn "$BASE_HOME/control-center/orchestration/skills" "$home/.pi/skills"
    log "技能目录已链接: $home/.pi/skills → control-center/orchestration/skills"
  fi

  # root 模式下把配置归属目标用户
  if [[ -n "$user" ]] && id "$user" &>/dev/null; then
    chown -R "$user:$user" "$home/.pi" "$home/.venv" 2>/dev/null || true
  fi
}
# ── 6. 代码仓库骨架（13.2）────────────────────────────────────

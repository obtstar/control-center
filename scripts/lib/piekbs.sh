#!/usr/bin/env bash
# piekbs.sh — 由 setup-env.sh source（依赖 common.sh）

init_piekbs() {
  log "PieKBS 知识库（kb_search/kb_page/kb_add，MCP 接口）"
  local gh="${GH_PROXY:+$GH_PROXY/}"

  # 0. 源码仓库由 sync_repos 统一管理（~/.repos/control-piekbs.git → ~/control-piekbs）

  # 1. 二进制：GitHub release（linux-amd64，经 GH_PROXY）
  if as_target_user "$USER_ENV command -v piekbs" &>/dev/null; then
    log "piekbs 已安装，跳过二进制安装"
  elif confirm_opt "安装 piekbs 二进制（GitHub release）？"; then
    # API 直连（gh 代理对 api.github.com 返回 403），仅 tarball 下载走代理
    local dl_cmd="set -eo pipefail; "
    dl_cmd+="url=\$(curl -fsSL https://api.github.com/repos/pieteams/piekbs/releases/latest | grep -o 'https://[^\"]*linux-amd64.tar.gz' | head -1); "
    dl_cmd+="[[ -n \"\$url\" ]] || { echo '未找到 release 下载地址' >&2; exit 1; }; "
    dl_cmd+="mkdir -p \"\$HOME/.local/bin\" && curl -fsSL ${gh}\$url | tar -xz -C \"\$HOME/.local/bin\" && chmod +x \"\$HOME/.local/bin/piekbs\""
    as_target_user "$dl_cmd" \
      && log "piekbs 二进制安装完成（~/.local/bin/piekbs）" \
      || warn "piekbs 下载失败（网络受限？可手动下载 release 放入 ~/.local/bin）"
  else
    log "跳过: piekbs 二进制"
  fi

  # 2. KB 初始化与配置（distill 走 LiteLLM 代理，FTS 无需 embedding）
  as_target_user "$USER_ENV command -v piekbs" &>/dev/null || return 0
  local kb="$BASE_HOME/control-wiki"
  if [[ ! -d "$kb/wiki" ]]; then
    # 来源选择：空库新建 或 指定 Git 仓库克隆（默认 control-wiki 远程）
    local kb_src="" ans
    if has_tty; then
      echo "知识库来源：" >&2
      echo "  1) 空库（piekbs init 新建）" >&2
      echo "  2) 指定 Git 仓库克隆（已有 KB 内容）" >&2
      ask "选择 [1/2]: " ans
      if [[ "$ans" == "2" ]]; then
        local def_remote="${CONTROL_WIKI_REMOTE:-${GIT_REMOTE_BASE:+$GIT_REMOTE_BASE/control-wiki.git}}"
        ask "KB Git 仓库地址${def_remote:+ [$def_remote]}: " kb_src
        kb_src="${kb_src:-$def_remote}"
      fi
    fi
    if [[ -n "$kb_src" ]]; then
      gitu "clone '$kb_src' '$kb'" \
        && log "KB 已克隆: $kb_src → $kb" \
        || { warn "KB 克隆失败，回退空库: $kb_src"; kb_src=""; }
    fi
    if [[ -z "$kb_src" && ! -d "$kb/wiki" ]]; then
      as_target_user "$USER_ENV PIEKBS_KB='$kb' piekbs init" \
        && log "KB 已初始化（空库）: $kb（raw/ 投放原始文档，watcher 自动蒸馏+索引）" \
        || warn "piekbs init 失败"
    fi
  fi
  if [[ -d "$kb" && ! -f "$kb/config.yaml" ]]; then
    render_tmpl "piekbs-config.yaml.tmpl" "$kb/config.yaml" 600
    own "$kb"
    log "已生成 $kb/config.yaml（distill → LiteLLM cheap 模型，token 需填入）"
    log "启动: piekbs serve（127.0.0.1:8766；局域网经 ssh -L 8766:localhost:8766 访问）"
    log "pi 接入 MCP: http://127.0.0.1:8766/mcp"
  fi

  # 3. KB 版本化：raw/wiki/schema 进 Git（可审计/可回滚），index 为派生物忽略
  if [[ -d "$kb/wiki" && ! -d "$kb/.git" ]]; then
    gitu "-C '$kb' init -b main >/dev/null 2>&1 \
      || { git -C '$kb' init -q; git -C '$kb' symbolic-ref HEAD refs/heads/main; }"
    cat > "$kb/.gitignore" <<'EOF'
index/
*.log
.DS_Store
EOF
    own "$kb/.gitignore"
    gitu "-C '$kb' add -A \
      && git -C '$kb' -c user.name=init-env -c user.email=init-env@local \
        commit -q -m 'chore: init knowledge base' >/dev/null" \
      && log "KB 已版本化: $kb（index/ 已忽略）"
  fi
  # 远程：control-wiki（默认 $GIT_REMOTE_BASE/control-wiki.git，CONTROL_WIKI_REMOTE 可覆盖）
  local kb_remote="${CONTROL_WIKI_REMOTE:-${GIT_REMOTE_BASE:+$GIT_REMOTE_BASE/control-wiki.git}}"
  if [[ -d "$kb/.git" && -n "$kb_remote" ]]; then
    gitu "-C '$kb' remote add origin '$kb_remote' 2>/dev/null; \
      git -C '$kb' push -u origin main" >/dev/null 2>&1 \
      && log "KB 已推送: $kb_remote" \
      || warn "KB 推送失败（远程不存在或无权限？）：$kb_remote"
  fi
}


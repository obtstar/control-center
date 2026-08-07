#!/usr/bin/env bash
# repos.sh — 由 setup-env.sh source（依赖 common.sh）

clone_remote() { # $1=repo 名 $2=目标目录；0=已克隆 1=未克隆（调用方走回退）
  local name="$1" dest="$2" remote="" refs="" rc=0
  [[ -n "${GIT_REMOTE_BASE:-}" ]] && remote="$GIT_REMOTE_BASE/$name.git" || return 1
  refs="$(gitu "ls-remote '$remote'" 2>/dev/null)" || rc=$?
  if [[ $rc -ne 0 ]]; then
    warn "远程不可达或无权限，跳过: $remote"
    return 1
  fi
  [[ -z "$refs" ]] && return 1   # 空远程（新建未推送）
  if [[ -n "$(find "$dest" -type f 2>/dev/null)" ]]; then
    confirm_overwrite "$dest 非空且非 Git 仓库，清空并克隆" \
      || { warn "保留现有目录，跳过克隆: $dest"; return 1; }
  fi
  rm -rf "$dest"
  if gitu "clone '$remote' '$dest'"; then
    grep -q 'refs/heads/dev$' <<<"$refs" \
      && gitu "-C '$dest' checkout -q dev" >/dev/null 2>&1 || true
    log "克隆仓库: $name（来自 $remote）"
    return 0
  fi
  warn "克隆失败（无权限或网络受限？）: $remote"
  return 1
}

init_repo_skeleton() { # $1=repo 名 $2=相对 home 的路径（默认 wt/$1/dev）
  local repo="$BASE_HOME/${2:-wt/$1/dev}"
  if [[ -d "$repo/.git" ]]; then
    update_repo "$repo" "$1"
    return 0
  fi
  # 远程已有内容则克隆（新机器接入）；否则本地初始化骨架
  clone_remote "$1" "$repo" && return 0

  mkdir -p "$repo"/{src/main,tests,db/ddl,ci,openapi}
  cat > "$repo/.gitignore" <<'EOF'
target/
node_modules/
dist/
*.log
.env
EOF
  cat > "$repo/README.md" <<EOF
# $1

设计文档见 control-wiki 知识库；仓库内文档与代码同分支、同 MR 提交。
EOF
  # git >= 2.28 支持 init -b；旧版本回退 symbolic-ref
  if ! git -C "$repo" init -b main >/dev/null 2>&1; then
    git -C "$repo" init >/dev/null
    git -C "$repo" symbolic-ref HEAD refs/heads/main
  fi
  git -C "$repo" -c user.name=init-env -c user.email=init-env@local \
    commit --allow-empty -m "chore: init repository skeleton" >/dev/null
  git -C "$repo" checkout -b dev >/dev/null
  # 可选：配置远程并推送（以工作用户身份，使用其 SSH 密钥）
  if [[ -n "${GIT_REMOTE_BASE:-}" ]]; then
    local remote="$GIT_REMOTE_BASE/$1.git"
    gitu "-C '$repo' remote add origin '$remote'" 2>/dev/null || true
    if gitu "-C '$repo' push -u origin main dev" >/dev/null 2>&1; then
      log "初始化仓库: $1（main + dev，已推送 $remote）"
    else
      warn "仓库 $1 已初始化，但推送失败（远程不存在或无权限？）：$remote"
    fi
  else
    log "初始化仓库: $1（main + dev，未配置远程；设 GIT_REMOTE_BASE 可自动推送）"
  fi
}

# 远程地址解析：GIT_REMOTE_BASE 全量前缀优先；否则按协议选择构造
resolve_remote_base() {
  [[ -n "${GIT_REMOTE_BASE:-}" ]] && return 0
  local proto="${GIT_PROTO:-}" host="${GIT_REMOTE_HOST:-github.com/obtstar}"
  if [[ -z "$proto" ]] && has_tty; then
    echo "仓库远程协议（克隆/推送 control-center 与 control-api/control-web/control-db）：" >&2
    echo "  1) ssh   git@${host/\//:}" >&2
    echo "  2) http  https://$host" >&2
    echo "  回车跳过（仅本地骨架，不关联远程）" >&2
    read -rp "选择 [1/2]: " proto </dev/tty
    [[ "$proto" == "1" ]] && proto=ssh
    [[ "$proto" == "2" ]] && proto=http
  fi
  case "$proto" in
    ssh)        GIT_REMOTE_BASE="git@${host/\//:}" ;;   # scp 语法: git@github.com:obtstar
    http|https) GIT_REMOTE_BASE="https://$host"
                warn "http 协议克隆私有仓库需凭据（token/凭据助手），否则仅公开仓库可用" ;;
  esac
}

# 已存在仓库以 git pull 更新（以工作用户身份，--ff-only 防合并冲突）
update_repo() { # $1=路径 $2=名称
  if gitu "-C '$1' pull --ff-only" >/dev/null 2>&1; then
    log "已更新: $2（git pull --ff-only）"
  else
    warn "更新失败（非快进/网络受限），保留现状: $2"
  fi
}

# registry/repos.yaml 清单解析：输出 repo_key<TAB>path<TAB>git_url<TAB>default_branch
parse_repos() {
  awk '
    /^  - repo_key:/ { key=$3 }
    /^    path:/     { path=$2 }
    /^    git_url:/  { url=$2 }
    /^    default_branch:/ { branch=$2
      if (key && path && url) { print key "\t" path "\t" url "\t" branch; key=path=url=branch="" } }
  ' "$1"
}

# 按 registry/repos.yaml 清单同步全部仓库（克隆/pull/骨架回退）
# 按 registry/repos.yaml 清单同步全部仓库
# 代码仓统一 bare+worktree 模型：gitdir 集中 ~/.repos/<key>.git，
# 常驻工作区 ~/wt/<key>/<branch>/（远程为空/不可达时骨架回退为原地 init）
sync_repo_wt() { # $1=repo_key $2=git_url $3=常驻分支 $4=工作区绝对路径
  local key="$1" url="$2" branch="$3" dest="$4"
  local bare="$BASE_HOME/.repos/$key.git"
  if [[ ! -d "$bare" ]]; then
    [[ -z "$url" ]] && { init_repo_skeleton "$key" "${dest#$BASE_HOME/}"; return 0; }
    if ! gitu "clone --bare '$url' '$bare'"; then
      warn "bare 克隆失败（远程为空/不可达），骨架回退: $key"
      init_repo_skeleton "$key" "${dest#$BASE_HOME/}"
      return 0
    fi
    log "bare 克隆: $key → ~/.repos/$key.git"
  else
    gitu "-C '$bare' fetch --prune" >/dev/null 2>&1 || true
  fi
  own "$bare"
  if [[ ! -e "$dest/.git" ]]; then
    if gitu "-C '$bare' worktree add '$dest' '$branch'" >/dev/null 2>&1 \
       || gitu "-C '$bare' worktree add '$dest'" >/dev/null 2>&1; then
      log "常驻工作区: $dest（$branch）"
    else
      warn "worktree 创建失败: $dest"
    fi
  else
    update_repo "$dest" "$key"
  fi
}

# 基础设施仓（Agent 架构组件）：顶级目录工作区 + gitdir 集中 ~/.repos（同 control-center）
sync_repo_infra() { # $1=repo_key $2=git_url $3=工作区绝对路径
  local key="$1" url="$2" dest="$3" gitdir="$BASE_HOME/.repos/$key.git"
  if [[ -e "$dest/.git" ]]; then
    update_repo "$dest" "$key"
    return 0
  fi
  # gitdir 已存在：有效则直接链接工作区，无效残留清理后重克隆
  if [[ -d "$gitdir" ]]; then
    own "$gitdir"
    if gitu "--git-dir '$gitdir' rev-parse HEAD" >/dev/null 2>&1; then
      mkdir -p "$dest"
      echo "gitdir: $gitdir" > "$dest/.git"
      gitu "--git-dir '$gitdir' config core.worktree '$dest'"
      own "$dest"
      gitu "-C '$dest' checkout -fq dev" >/dev/null 2>&1 \
        || gitu "-C '$dest' checkout -fq" >/dev/null 2>&1
      log "链接工作区: $key（复用已有 gitdir: ~/.repos/$key.git）"
      return 0
    else
      warn "残留无效 gitdir，清理后重克隆: $gitdir"
      rm -rf "$gitdir"
    fi
  fi
  [[ -z "$url" ]] && { warn "无远程地址，跳过: $key"; return 0; }
  mkdir -p "$BASE_HOME/.repos"
  own "$BASE_HOME/.repos"
  if gitu "clone --separate-git-dir '$gitdir' '$url' '$dest'"; then
    log "克隆仓库: $key（gitdir: ~/.repos/$key.git）"
    gitu "-C '$dest' checkout -q dev" >/dev/null 2>&1 || true
    own "$dest" "$gitdir"
  else
    warn "克隆失败（远程为空/不可达？）: $url"
  fi
}

sync_repos() {
  command -v git >/dev/null || { warn "未安装 git，跳过仓库同步"; return 0; }
  local yaml="$BASE_HOME/control-center/registry/repos.yaml"
  [[ -f "$yaml" ]] || { warn "注册表不存在: $yaml（先完成阶段一克隆 control-center）"; return 0; }
  resolve_remote_base
  mkdir -p "$BASE_HOME/.repos"
  own "$BASE_HOME/.repos"
  local key path url branch dest
  while IFS=$'\t' read -r key path url branch; do
    dest="$BASE_HOME/$path"
    if [[ -z "$url" && -n "${GIT_REMOTE_BASE:-}" ]]; then
      url="$GIT_REMOTE_BASE/$key.git"
    fi
    case "$key" in
      control-center)
        update_repo "$dest" "$key" ;;                    # 引导仓：仅 pull
      control-wiki)
        : ;;                                            # KB 数据仓：由 init_piekbs 管理
      *)
        if [[ "$path" == wt/* ]]; then
          sync_repo_wt "$key" "$url" "${branch:-dev}" "$dest"   # 项目代码：bare+worktree
        else
          sync_repo_infra "$key" "$url" "$dest"               # 基础设施：顶级目录
        fi ;;
    esac
  done < <(parse_repos "$yaml")
}

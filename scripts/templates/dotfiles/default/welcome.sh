# control-center 欢迎界面（由 bashrc 托管块加载；CONTROL_WELCOME=0 关闭）
# 纪律：仅交互 shell、渲染 <50ms、零网络调用
[[ $- == *i* && "${CONTROL_WELCOME:-1}" != "0" ]] || return 0

__cc_welcome() {
  local branch tools="" t wt_count
  branch=$(git -C "$HOME/control-center" branch --show-current 2>/dev/null)
  for t in java node go cargo docker uv pnpm; do
    command -v "$t" &>/dev/null && tools+="$t✓ "
  done
  wt_count=$(find "$HOME/wt" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l)
  printf '\033[0;36m┌─ control-center ─────────────────────────\033[0m\n'
  printf '\033[0;36m│\033[0m %s@%s  %s\n' "$USER" "$(hostname)" "$(date '+%Y-%m-%d %H:%M')"
  printf '\033[0;36m│\033[0m repo: control-center(%s)  wt: %s 个工作区\n' "${branch:-?}" "$wt_count"
  printf '\033[0;36m│\033[0m env: %s\n' "${tools:-（无工具链）}"
  printf '\033[0;36m│\033[0m wiki: piekbs:8766  llm: %s\n' "${LITELLM_ENDPOINT:-http://litellm.internal:4000}"

  local handy="" miss="" h
  for h in xh dust jq lazygit zoxide yazi git tmux glow fzf; do
    if command -v "$h" &>/dev/null; then handy+="$h "; else miss+="$h "; fi
  done
  printf '\033[0;36m│\033[0m \033[0;33m🔧 工具\033[0m  %s' "${handy:-（无）}"
  [[ -n "$miss" ]] && printf '\033[2m· 缺: %s\033[0m' "${miss% }"
  printf '\n'
  local aok="" amiss=""
  for h in pi openskills openwiki; do
    if command -v "$h" &>/dev/null; then aok+="$h "; else amiss+="$h "; fi
  done
  printf '\033[0;36m│\033[0m \033[0;33m🤖 Agent\033[0m %s' "${aok:-（无）}"
  [[ -n "$amiss" ]] && printf '\033[2m· 缺: %s\033[0m' "${amiss% }"
  printf '\n'
  printf '\033[0;36m│\033[0m \033[0;33m📁 文件\033[0m  l/ll/la 列表 · cat 查看\n'
  printf '\033[0;36m│\033[0m \033[0;33m🔀 跳转\033[0m  .. / ... / .... 上级目录'
  command -v zoxide &>/dev/null && printf ' · z 智能跳转'
  printf '\n'
  printf '\033[0;36m│\033[0m \033[0;33m🔀 Git\033[0m   g/gs/ga/gc/gp/gl/glo'
  command -v delta &>/dev/null && printf ' · delta diff'
  printf '\n'
  if command -v docker &>/dev/null; then
    printf '\033[0;36m│\033[0m \033[0;33m🐳 容器\033[0m  d  ·  dc  ·  dps\n'
  fi
  printf '\033[0;36m│\033[0m \033[0;33m🌿 分支\033[0m  branch new/list/sync/done/prune/release\n'
  printf '\033[0;36m│\033[0m \033[0;33m🎨 主题\033[0m  theme list/use/off\n'
  printf '\033[0;36m└─\033[0m hint: check-env.sh · CONTROL_WELCOME=0 关闭\n'
}
__cc_welcome
unset -f __cc_welcome

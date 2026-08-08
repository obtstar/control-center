# control-center 欢迎界面（由 bashrc 托管块加载；CONTROL_WELCOME=0 关闭）
# 纪律：仅交互 shell、渲染 <50ms、零网络调用
[[ $- == *i* && "${CONTROL_WELCOME:-1}" != "0" ]] || return 0

__cc_welcome() {
  local branch tools="" t wt_count
  branch=$(git -C "$HOME/control-center" branch --show-current 2>/dev/null)
  for t in java node go docker uv pnpm; do
    command -v "$t" &>/dev/null && tools+="$t✓ "
  done
  wt_count=$(find "$HOME/wt" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l)
  printf '\033[0;36m┌─ control-center ─────────────────────────\033[0m\n'
  printf '\033[0;36m│\033[0m %s@%s  %s\n' "$USER" "$(hostname)" "$(date '+%Y-%m-%d %H:%M')"
  printf '\033[0;36m│\033[0m repo: control-center(%s)  wt: %s 个工作区\n' "${branch:-?}" "$wt_count"
  printf '\033[0;36m│\033[0m env: %s\n' "${tools:-（无工具链）}"
  printf '\033[0;36m│\033[0m wiki: piekbs:8766  llm: %s\n' "${LITELLM_ENDPOINT:-http://litellm.internal:4000}"
  printf '\033[0;36m└─\033[0m hint: setup-env.sh --check · CONTROL_WELCOME=0 关闭\n'
}
__cc_welcome
unset -f __cc_welcome

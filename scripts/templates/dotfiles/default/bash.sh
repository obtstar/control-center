# control-center bash 主题（由 setup-env.sh 部署到 ~/.bashrc.d/control.sh）
# 幂等挂载：~/.bashrc 中 source 本文件

# ── 历史 ─────────────────────────────────────────────────────
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=10000
export HISTFILESIZE=20000
shopt -s histappend

# ── 颜色与补全 ───────────────────────────────────────────────
shopt -s checkwinsize
if command -v dircolors &>/dev/null; then
  eval "$(dircolors -b)"
fi
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# ── 别名 ─────────────────────────────────────────────────────
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
# Git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -15'
alias glo='git log --oneline'
alias gd='git diff'
alias wt='git worktree'
# 容器
command -v docker &>/dev/null && {
  alias d='docker'
  alias dc='docker compose'
  alias dps='docker ps'
}
command -v rg &>/dev/null && alias grep='rg'
command -v fd &>/dev/null && alias find='fd'
command -v bat &>/dev/null && alias cat='bat'
alias theme="$HOME/control-center/scripts/theme.sh"
alias branch="$HOME/control-center/scripts/branch.sh"

# ── 提示符（user@host:path (branch) $）──────────────────────
__cc_git_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null) || return
  printf ' \033[0;36m(%s)\033[0m' "$b"
}
PS1='\[\033[0;32m\]\u@\h\[\033[0m\]:\[\033[0;34m\]\w\[\033[0m\]$(__cc_git_branch) \$ '

# ── PATH ─────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.venv/bin:$PATH"

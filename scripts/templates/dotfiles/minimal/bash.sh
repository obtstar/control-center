# control-center bash 主题·精简版（~/.bashrc.d/control.sh）
# 仅基础别名与 PATH，无欢迎界面/无额外钩子

export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -15'
alias gd='git diff'
alias theme="$HOME/control-center/scripts/theme.sh"

__cc_git_branch() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null) || return
  printf ' \033[0;36m(%s)\033[0m' "$b"
}
PS1='\[\033[0;32m\]\u@\h\[\033[0m\]:\[\033[0;34m\]\w\[\033[0m\]$(__cc_git_branch) \$ '

export PATH="$HOME/.local/bin:$HOME/.venv/bin:$PATH"

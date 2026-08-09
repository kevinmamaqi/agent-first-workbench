export EDITOR="${EDITOR:-vi}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R --quit-if-one-screen --no-init}"

# Agent hosts commonly hold per-account credentials and generated artifacts.
umask 077

export PATH="$HOME/.local/bin:$HOME/.kimi-code/bin:$PATH"

alias gd='git diff'
alias gds='git diff --staged'
alias gs='git status --short --branch'
alias ll='ls -lah'

agent-session() {
  tmux new-session -A -s "${1:-main}"
}

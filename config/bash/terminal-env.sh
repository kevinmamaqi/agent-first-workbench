export EDITOR="${EDITOR:-vi}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R --quit-if-one-screen --no-init}"

# Agent hosts commonly hold per-account credentials and generated artifacts.
umask 077

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$BUN_INSTALL/bin:$HOME/.kimi-code/bin:$PATH"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck disable=SC1090
  source "$NVM_DIR/nvm.sh"
fi

alias gd='git diff'
alias gds='git diff --staged'
alias gs='git status --short --branch'
alias ll='ls -lah'

agent-session() {
  tmux new-session -A -s "${1:-main}"
}

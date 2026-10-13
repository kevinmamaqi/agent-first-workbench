export EDITOR="${EDITOR:-vi}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R --quit-if-one-screen --no-init}"

# Agent hosts commonly hold per-account credentials and generated artifacts.
umask 077

if [[ -r "$HOME/.config/agent-first-workbench/session-env.sh" ]]; then
  source "$HOME/.config/agent-first-workbench/session-env.sh"
fi

alias gd='git diff'
alias gds='git diff --staged'
alias gs='git status --short --branch'
alias ll='ls -lah'

agent-session() {
  tmux new-session -A -s "${1:-main}"
}

if [[ $- == *i* ]]; then
  HISTCONTROL="${HISTCONTROL:-ignoreboth}:erasedups"
  HISTSIZE="${HISTSIZE:-100000}"
  HISTFILESIZE="${HISTFILESIZE:-200000}"
  shopt -s histappend

  _workbench_history_sync() {
    history -a
    history -n
  }
  case ";${PROMPT_COMMAND:-};" in
    *';_workbench_history_sync;'*) ;;
    *) PROMPT_COMMAND="_workbench_history_sync${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac

  if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd z)"
  fi
  if command -v atuin >/dev/null 2>&1; then
    if atuin init bash --help 2>&1 | grep -q -- '--disable-ai'; then
      eval "$(atuin init bash --disable-ai)"
    else
      eval "$(atuin init bash)"
    fi
  fi
fi

export EDITOR="${EDITOR:-hx}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R --mouse --wheel-lines=3 --quit-if-one-screen --no-init}"

if [[ -r "$HOME/.config/agent-first-workbench/session-env.sh" ]]; then
  source "$HOME/.config/agent-first-workbench/session-env.sh"
fi

export BAT_THEME="${BAT_THEME:-ansi}"
export BAT_STYLE="${BAT_STYLE:-numbers,changes,header}"

export HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
export HISTSIZE="${AGENT_WORKBENCH_HISTSIZE:-100000}"
export SAVEHIST="${AGENT_WORKBENCH_SAVEHIST:-200000}"
setopt append_history extended_history hist_expire_dups_first
setopt hist_ignore_all_dups hist_ignore_space share_history

typeset -ga AGENT_WORKBENCH_FD_EXCLUDES
AGENT_WORKBENCH_FD_EXCLUDES=(.git node_modules .next dist build .venv target .cache)

typeset _workbench_fzf_excludes=""
for _workbench_exclusion in "${AGENT_WORKBENCH_FD_EXCLUDES[@]}"; do
  _workbench_fzf_excludes+=" --exclude $_workbench_exclusion"
done

export FZF_DEFAULT_COMMAND="fd --type f --hidden${_workbench_fzf_excludes}"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden${_workbench_fzf_excludes}"
export FZF_DEFAULT_OPTS='--height=85% --layout=reverse --border --info=inline --cycle --ansi --preview-window=right,55%,border-left,wrap'

unset _workbench_fzf_excludes _workbench_exclusion

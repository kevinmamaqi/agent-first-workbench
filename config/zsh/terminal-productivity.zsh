[[ -o interactive ]] || return

typeset -ga _workbench_fd_base
_workbench_fd_base=(--hidden)
for _workbench_exclusion in "${AGENT_WORKBENCH_FD_EXCLUDES[@]}"; do
  _workbench_fd_base+=(--exclude "$_workbench_exclusion")
done
unset _workbench_exclusion

alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lah --git --group-directories-first --icons=auto'
alias lt='eza --tree --level=2 --git --group-directories-first --icons=auto'
alias cat='bat --paging=never'
alias rg='rg --smart-case'
alias gd='git diff'
alias gds='git diff --staged'
alias gs='git status --short --branch'

f() {
  local file
  file="$(fd --type f --print0 "${_workbench_fd_base[@]}" "$@" \
    | fzf --read0 --prompt='file> ' --preview 'bat --color=always --style=numbers --line-range=:220 {}')" || return
  [[ -n "$file" ]] && "$EDITOR" "$file"
}

s() {
  local query selected file line
  query="$*"
  [[ -z "$query" ]] && read -r "query?search> "
  [[ -z "$query" ]] && return 1

  selected="$(command rg --line-number --no-heading --color=always --smart-case -- "$query" \
    | fzf --ansi --delimiter=: --nth=3.. --prompt='rg> ' \
        --preview 'bat --color=always --style=numbers --highlight-line {2} -- {1}')" || return
  file="${selected%%:*}"
  line="${${selected#*:}%%:*}"
  [[ -n "$file" && -n "$line" ]] && "$EDITOR" "$file:$line"
}

md() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    file="$(fd --type f --print0 "${_workbench_fd_base[@]}" -e md -e markdown -e mdx \
      | fzf --read0 --prompt='md> ' --preview 'bat --color=always --style=numbers --line-range=:220 {}')" || return
  fi
  [[ -n "$file" ]] && glow -p -w "${COLUMNS:-100}" "$file"
}

changed() {
  git status --short
  git diff --no-ext-diff
  git diff --staged --no-ext-diff
}

cmark() {
  cmux markdown open "${1:?usage: cmark <file.md>}"
}

cdiff() {
  cmux diff --source "${1:-unstaged}"
}

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow --disable-ai)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd z)"
fi


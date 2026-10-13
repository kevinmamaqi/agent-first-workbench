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

ff() {
  f --follow "$@"
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

mdopen() {
  local file="${1:-}"
  if [[ "$(uname -s)" != Darwin ]]; then
    echo 'mdopen requires macOS; use f or md on this host.' >&2
    return 1
  fi
  if [[ -z "$file" ]]; then
    file="$(fd --type f --print0 "${_workbench_fd_base[@]}" -e md -e markdown -e mdx \
      | fzf --read0 --prompt='mdopen> ' --preview 'bat --color=always --paging=never {}')" || return
  fi
  [[ -n "$file" ]] && open -a MarkEdit "$file"
}

preview() {
  (( $# )) || { echo 'usage: preview FILE [FILE...]' >&2; return 2; }
  local file
  for file in "$@"; do
    case "${file:l}" in
      *.md|*.markdown|*.mdx)
        if [[ "$(uname -s)" == Darwin ]]; then
          open -a MarkEdit "$file" || return
        else
          "$EDITOR" "$file" || return
        fi
        ;;
      *) cmux open "$file" --no-focus || return ;;
    esac
  done
}

cdiff() {
  cmux diff --source "${1:-unstaged}"
}

if command -v atuin >/dev/null 2>&1; then
  if atuin init zsh --help 2>&1 | grep -q -- '--disable-ai'; then
    eval "$(atuin init zsh --disable-ai)"
  else
    eval "$(atuin init zsh)"
  fi
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd z)"
fi

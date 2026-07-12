#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="dry-run"

case "${1:---dry-run}" in
  --dry-run) mode="dry-run" ;;
  --apply) mode="apply" ;;
  *) echo "usage: ./install.sh [--dry-run|--apply]" >&2; exit 2 ;;
esac

timestamp="$(date +%Y%m%d-%H%M%S)"

install_link() {
  local source="$1" target="$2"

  if [[ "$mode" == "dry-run" ]]; then
    printf 'would link %s -> %s\n' "$target" "$source"
    return
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
    printf 'already linked: %s\n' "$target"
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    mv "$target" "$target.bak.$timestamp"
    printf 'backed up: %s.bak.%s\n' "$target" "$timestamp"
  fi
  ln -s "$source" "$target"
  printf 'linked: %s\n' "$target"
}

install_link "$root/config/zsh/terminal-env.zsh" "$HOME/.config/zsh/terminal-env.zsh"
install_link "$root/config/zsh/terminal-productivity.zsh" "$HOME/.config/zsh/terminal-productivity.zsh"
install_link "$root/config/ghostty/config" "$HOME/.config/ghostty/config"
install_link "$root/config/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"
install_link "$root/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
install_link "$root/config/git/delta.gitconfig" "$HOME/.config/git/delta.gitconfig"

if [[ "$mode" == "dry-run" ]]; then
  printf 'would add Git include.path: %s\n' "$HOME/.config/git/delta.gitconfig"
  echo "dry run only; rerun with --apply to make changes"
  exit 0
fi

if ! git config --global --get-all include.path | grep -Fxq "$HOME/.config/git/delta.gitconfig"; then
  [[ -f "$HOME/.gitconfig" ]] && cp "$HOME/.gitconfig" "$HOME/.gitconfig.bak.$timestamp"
  git config --global --add include.path "$HOME/.config/git/delta.gitconfig"
  echo "added Git include.path"
fi

echo "installed; start a new shell and run: cmux reload-config"


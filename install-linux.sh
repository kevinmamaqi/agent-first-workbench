#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="dry-run"
scope="all"

for argument in "${@:-}"; do
  case "$argument" in
    --dry-run) mode="dry-run" ;;
    --apply) mode="apply" ;;
    --user-only) scope="user" ;;
    --system-only) scope="system" ;;
    *)
      echo "usage: ./install-linux.sh [--dry-run|--apply] [--user-only|--system-only]" >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "install-linux.sh requires Linux" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "cannot detect Linux distribution" >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
case "${ID:-}" in
  debian|ubuntu) ;;
  *) echo "supported distributions: Debian and Ubuntu" >&2; exit 1 ;;
esac

timestamp="$(date +%Y%m%d-%H%M%S)"

run() {
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would run:'
    printf ' %q' "$@"
    printf '\n'
    return
  fi
  "$@"
}

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

install_agent() {
  local name="$1" command="$2"
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would install/update %s from its official native installer\n' "$name"
    return
  fi
  bash -lc "$command"
}

install_dispatcher() {
  local name="$1" target="$2" temporary
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would install /usr/local/bin/%s dispatcher -> %s\n' "$name" "$target"
    return
  fi
  temporary="$(mktemp)"
  printf '%s\n' '#!/bin/sh' 'set -eu' "exec \"\$HOME/$target\" \"\$@\"" > "$temporary"
  sudo install -m 755 "$temporary" "/usr/local/bin/$name"
  rm -f -- "$temporary"
}

install_aws_cli() {
  local temporary
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install/update AWS CLI v2 from the official distribution endpoint"
    return
  fi
  temporary="$(mktemp -d /tmp/agent-first-workbench-aws.XXXXXX)"
  curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
    -o "$temporary/awscliv2.zip"
  unzip -q "$temporary/awscliv2.zip" -d "$temporary"
  sudo "$temporary/aws/install" --update
  case "$temporary" in
    /tmp/agent-first-workbench-aws.*) rm -rf -- "$temporary" ;;
    *) echo "refusing to remove unexpected temporary path: $temporary" >&2; exit 1 ;;
  esac
}

packages=(
  build-essential ca-certificates curl fd-find gh git gnupg htop jq
  pkg-config postgresql-client python3 ripgrep rsync sqlite3 tmux tree unzip
  wireguard zip zsh
)

if [[ "$scope" != "user" ]]; then
  run sudo apt-get update
  run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"

  if [[ "$mode" == "dry-run" ]]; then
    echo "would expose Debian's fdfind as /usr/local/bin/fd"
  elif [[ ! -e /usr/local/bin/fd ]]; then
    sudo ln -s /usr/bin/fdfind /usr/local/bin/fd
  fi

  install_aws_cli
  install_dispatcher rtk '.local/bin/rtk'
  install_dispatcher codex '.local/bin/codex'
  install_dispatcher claude '.local/bin/claude'
  install_dispatcher kimi '.kimi-code/bin/kimi'
  install_dispatcher uv '.local/bin/uv'
  install_dispatcher uvx '.local/bin/uvx'
  install_dispatcher go '.local/go/bin/go'
  install_dispatcher bun '.bun/bin/bun'
  install_dispatcher code-review-graph '.local/bin/code-review-graph'
  install_dispatcher crg-daemon '.local/bin/crg-daemon'
fi

if [[ "$scope" != "system" ]]; then
  install_link "$root/config/bash/terminal-env.sh" "$HOME/.config/agent-first-workbench/terminal-env.sh"
  install_link "$root/config/tmux/tmux.conf" "$HOME/.tmux.conf"
  install_link "$root/bin/cmux-remote" "$HOME/.local/bin/cmux"
  install_link "$root/config/harlequin/harlequin.toml" "$HOME/.harlequin.toml"
  install_link "$root/bin/workbench-db-ui" "$HOME/.local/bin/dbui"
  install_link "$root/bin/workbench-db-mcp" "$HOME/.local/bin/workbench-db-mcp"
  install_link "$root/bin/workbench-wg" "$HOME/.local/bin/workbench-wg"
  install_link "$root/config/agents/codex-hooks.json" "$HOME/.codex/hooks.json"

  install_agent "RTK" \
    'curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh'
  install_agent "Codex CLI" \
    'curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh'
  install_agent "Claude Code" \
    'curl -fsSL https://claude.ai/install.sh | bash'
  install_agent "Kimi Code" \
    'curl -fsSL https://code.kimi.com/kimi-code/install.sh | bash'
  run "$HOME/.local/bin/rtk" init -g --agent claude --hook-only --auto-patch
fi

if [[ "$mode" == "dry-run" ]]; then
  if [[ "$scope" == "system" ]]; then
    echo "dry run only; rerun with --apply to make changes"
    exit 0
  fi
  echo "would add the workbench environment source line to ~/.bashrc"
  echo "dry run only; rerun with --apply to make changes"
  exit 0
fi

if [[ "$scope" != "system" ]]; then
  source_line='[[ -r "$HOME/.config/agent-first-workbench/terminal-env.sh" ]] && source "$HOME/.config/agent-first-workbench/terminal-env.sh"'
  touch "$HOME/.bashrc"
  if ! grep -Fxq "$source_line" "$HOME/.bashrc"; then
    cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$timestamp"
    printf '\n%s\n' "$source_line" >> "$HOME/.bashrc"
    echo "added workbench environment to ~/.bashrc"
  fi
fi

echo "installed Linux workbench; start a new shell"

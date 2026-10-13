#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="dry-run"
scope="all"
install_agents=true

for argument in "$@"; do
  case "$argument" in
    --dry-run) mode="dry-run" ;;
    --apply) mode="apply" ;;
    --user-only) scope="user" ;;
    --system-only) scope="system" ;;
    --skip-agents) install_agents=false ;;
    *)
      echo "usage: ./install-linux.sh [--dry-run|--apply] [--user-only|--system-only] [--skip-agents]" >&2
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

ensure_source_line() {
  local target="$1" line="$2" backup
  backup="$target.bak.$timestamp"

  if [[ -f "$target" ]] && grep -Fxq "$line" "$target"; then
    printf 'already sourced from: %s\n' "$target"
    return
  fi
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would add workbench source to %s\n' "$target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  if [[ -e "$target" && ! -e "$backup" ]]; then
    cp -p "$target" "$backup"
    printf 'backed up: %s\n' "$backup"
  else
    touch "$target"
  fi
  printf '\n%s\n' "$line" >> "$target"
  printf 'added workbench source to: %s\n' "$target"
}

remove_source_line() {
  local target="$1" line="$2" backup temporary
  backup="$target.bak.$timestamp"

  [[ -f "$target" ]] || return
  grep -Fxq "$line" "$target" || return
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would remove obsolete workbench source from %s\n' "$target"
    return
  fi

  if [[ ! -e "$backup" ]]; then
    cp -p "$target" "$backup"
    printf 'backed up: %s\n' "$backup"
  fi
  temporary="$(mktemp "$(dirname "$target")/.agent-first-workbench-source.XXXXXX")"
  awk -v line="$line" '$0 != line' "$target" > "$temporary"
  chmod --reference="$target" "$temporary"
  mv "$temporary" "$target"
  printf 'removed obsolete workbench source from: %s\n' "$target"
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
  temporary="$(mktemp /var/tmp/agent-first-workbench-dispatcher.XXXXXX)"
  # Expansion belongs to the generated per-account dispatcher.
  # shellcheck disable=SC2016
  printf '%s\n' '#!/bin/sh' 'set -eu' \
    'umask 077' \
    'export TMPDIR="${TMPDIR:-$HOME/.cache/agent-first-workbench/tmp}"' \
    'mkdir -p "$TMPDIR"' \
    "exec \"\$HOME/$target\" \"\$@\"" > "$temporary"
  sudo install -m 755 "$temporary" "/usr/local/bin/$name"
  rm -f -- "$temporary"
}

install_aws_cli() {
  local temporary
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install/update AWS CLI v2 from the official distribution endpoint"
    return
  fi
  temporary="$(mktemp -d /var/tmp/agent-first-workbench-aws.XXXXXX)"
  curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
    -o "$temporary/awscliv2.zip"
  unzip -q "$temporary/awscliv2.zip" -d "$temporary"
  sudo "$temporary/aws/install" --update
  case "$temporary" in
    /var/tmp/agent-first-workbench-aws.*) rm -rf -- "$temporary" ;;
    *) echo "refusing to remove unexpected temporary path: $temporary" >&2; exit 1 ;;
  esac
}

install_helix() {
  local version="${HELIX_VERSION:-25.07.1}"
  local deb_version="${HELIX_DEB_VERSION:-25.7.1-1}"
  local temporary

  if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    echo "automatic Helix installation currently supports amd64 only" >&2
    return 1
  fi
  if command -v hx >/dev/null 2>&1 && hx --version | grep -Fq "$version"; then
    printf 'Helix %s already installed\n' "$version"
    return
  fi
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would install Helix %s from its official GitHub release\n' "$version"
    return
  fi

  temporary="$(mktemp /var/tmp/agent-first-workbench-helix.XXXXXX.deb)"
  curl -fsSL \
    "https://github.com/helix-editor/helix/releases/download/$version/helix_${deb_version}_amd64.deb" \
    -o "$temporary"
  sudo apt-get install -y "$temporary"
  rm -f -- "$temporary"
}

install_yq() {
  local version="${YQ_VERSION:-v4.53.3}"
  local architecture binary temporary hash_column expected

  case "$(dpkg --print-architecture)" in
    amd64) architecture="amd64" ;;
    arm64) architecture="arm64" ;;
    *) echo "automatic yq installation supports amd64 and arm64 only" >&2; return 1 ;;
  esac
  if command -v yq >/dev/null 2>&1 && yq --version | grep -Fq "$version"; then
    printf 'yq %s already installed\n' "$version"
    return
  fi
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would install yq %s from its official GitHub release\n' "$version"
    return
  fi

  binary="yq_linux_$architecture"
  temporary="$(mktemp -d /var/tmp/agent-first-workbench-yq.XXXXXX)"
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/$version/$binary" \
    -o "$temporary/$binary"
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/$version/checksums" \
    -o "$temporary/checksums"
  curl -fsSL "https://github.com/mikefarah/yq/releases/download/$version/checksums_hashes_order" \
    -o "$temporary/checksums_hashes_order"
  hash_column="$(awk '$0 == "SHA-256" { print NR + 1; exit }' "$temporary/checksums_hashes_order")"
  [[ -n "$hash_column" ]] || { echo "yq SHA-256 column not found" >&2; return 1; }
  expected="$(awk -v asset="$binary" -v column="$hash_column" \
    '$1 == asset { print $column; exit }' "$temporary/checksums")"
  [[ -n "$expected" ]] || { echo "yq checksum not found for $binary" >&2; return 1; }
  printf '%s  %s\n' "$expected" "$temporary/$binary" | sha256sum --check --status
  sudo install -m 755 "$temporary/$binary" /usr/local/bin/yq
  rm -rf -- "$temporary"
}

packages=(
  atuin bat btop build-essential ca-certificates curl entr eza fd-find fzf gh
  git git-delta glow gnupg htop jq pkg-config postgresql-client python3
  ripgrep rsync sqlite3 tmux tree unzip vim wireguard zip zoxide zsh
)

if [[ "$scope" != "user" ]]; then
  [[ "$(dpkg --print-architecture)" == amd64 ]] || {
    echo 'system installation currently requires amd64; use --user-only on a pre-provisioned host' >&2
    exit 1
  }
  run sudo apt-get update
  if [[ "$mode" == apply ]]; then
    missing_packages=()
    for package in "${packages[@]}"; do
      apt-cache show "$package" >/dev/null 2>&1 || missing_packages+=("$package")
    done
    if (( ${#missing_packages[@]} )); then
      printf 'required packages are unavailable in enabled repositories: %s\n' "${missing_packages[*]}" >&2
      exit 1
    fi
  fi
  run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"

  if [[ "$mode" == "dry-run" ]]; then
    echo "would expose Debian's fdfind as /usr/local/bin/fd"
    echo "would expose Debian's batcat as /usr/local/bin/bat"
  elif [[ ! -e /usr/local/bin/fd ]]; then
    sudo ln -s /usr/bin/fdfind /usr/local/bin/fd
  fi
  if [[ "$mode" != "dry-run" && ! -e /usr/local/bin/bat ]]; then
    sudo ln -s /usr/bin/batcat /usr/local/bin/bat
  fi

  install_aws_cli
  install_helix
  install_yq
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
  install_link "$root/config/shell/session-env.sh" "$HOME/.config/agent-first-workbench/session-env.sh"
  install_link "$root/config/zsh/terminal-env.zsh" "$HOME/.config/zsh/terminal-env.zsh"
  install_link "$root/config/zsh/terminal-productivity.zsh" "$HOME/.config/zsh/terminal-productivity.zsh"
  install_link "$root/config/atuin/config.toml" "$HOME/.config/atuin/config.toml"
  install_link "$root/config/git/delta.gitconfig" "$HOME/.config/git/delta.gitconfig"
  install_link "$root/config/tmux/tmux.conf" "$HOME/.tmux.conf"
  install_link "$root/bin/cmux-remote" "$HOME/.local/bin/cmux"
  install_link "$root/config/harlequin/harlequin.toml" "$HOME/.harlequin.toml"
  install_link "$root/config/helix/config.toml" "$HOME/.config/helix/config.toml"
  install_link "$root/bin/workbench-db-ui" "$HOME/.local/bin/dbui"
  install_link "$root/bin/workbench-db-mcp" "$HOME/.local/bin/workbench-db-mcp"
  install_link "$root/bin/workbench-wg" "$HOME/.local/bin/workbench-wg"
  install_link "$root/bin/awslogin" "$HOME/.local/bin/awslogin"
  install_link "$root/bin/workbench-phone-session" "$HOME/.local/bin/work"

  if [[ "$install_agents" == true ]]; then
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
fi

if [[ "$scope" != "system" ]]; then
  # Source lines expand in the user's shell, not in this installer.
  # shellcheck disable=SC2016
  bash_source='[[ -r "$HOME/.config/agent-first-workbench/terminal-env.sh" ]] && source "$HOME/.config/agent-first-workbench/terminal-env.sh"'
  # shellcheck disable=SC2016
  zsh_env_source='[[ -r "$HOME/.config/zsh/terminal-env.zsh" ]] && source "$HOME/.config/zsh/terminal-env.zsh"'
  # shellcheck disable=SC2016
  zsh_productivity_source='[[ -r "$HOME/.config/zsh/terminal-productivity.zsh" ]] && source "$HOME/.config/zsh/terminal-productivity.zsh"'

  ensure_source_line "$HOME/.bashrc" "$bash_source"
  remove_source_line "$HOME/.zshrc" "$bash_source"
  ensure_source_line "$HOME/.zshrc" "$zsh_env_source"
  ensure_source_line "$HOME/.zshrc" "$zsh_productivity_source"

  if [[ "$mode" == "dry-run" ]]; then
    printf 'would add Git include.path: %s\n' "$HOME/.config/git/delta.gitconfig"
  elif ! git config --global --get-all include.path | grep -Fxq "$HOME/.config/git/delta.gitconfig"; then
    [[ -f "$HOME/.gitconfig" && ! -e "$HOME/.gitconfig.bak.$timestamp" ]] && \
      cp -p "$HOME/.gitconfig" "$HOME/.gitconfig.bak.$timestamp"
    git config --global --add include.path "$HOME/.config/git/delta.gitconfig"
    echo "added Git include.path"
  fi
fi

if [[ "$mode" == "dry-run" ]]; then
  echo "dry run only; rerun with --apply to make changes"
  exit 0
fi

echo "installed Linux workbench; start a new shell"

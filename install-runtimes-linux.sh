#!/usr/bin/env bash
set -euo pipefail

mode="dry-run"
go_version="${GO_VERSION:-1.26.5}"
node_versions="${NODE_VERSIONS:-22 24}"
node_default="${NODE_DEFAULT:-24}"
python_versions="${PYTHON_VERSIONS:-3.11 3.13}"
nvm_version="${NVM_VERSION:-v0.40.4}"

for argument in "$@"; do
  case "$argument" in
    --dry-run) mode="dry-run" ;;
    --apply) mode="apply" ;;
    *) echo "usage: ./install-runtimes-linux.sh [--dry-run|--apply]" >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "install-runtimes-linux.sh requires Linux" >&2
  exit 1
fi

run() {
  if [[ "$mode" == "dry-run" ]]; then
    printf 'would run:'
    printf ' %q' "$@"
    printf '\n'
    return
  fi
  "$@"
}

install_go() {
  local machine_arch go_arch metadata archive filename checksum target current temporary
  machine_arch="$(uname -m)"
  case "$machine_arch" in
    x86_64) go_arch="amd64" ;;
    aarch64|arm64) go_arch="arm64" ;;
    *) echo "unsupported Go architecture: $machine_arch" >&2; exit 1 ;;
  esac

  target="$HOME/.local/share/go/go$go_version"
  current="$HOME/.local/go"
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install verified Go $go_version for linux/$go_arch at $target"
    echo "would link $current -> $target"
    return
  fi
  if [[ ! -x "$target/bin/go" ]]; then
    temporary="$(mktemp -d /tmp/agent-first-workbench-go.XXXXXX)"
    metadata="$temporary/releases.json"
    curl -fsSL 'https://go.dev/dl/?mode=json&include=all' -o "$metadata"
    filename="$(jq -r --arg version "go$go_version" --arg arch "$go_arch" '
      .[] | select(.version == $version) | .files[] |
      select(.os == "linux" and .arch == $arch and .kind == "archive") | .filename
    ' "$metadata")"
    checksum="$(jq -r --arg version "go$go_version" --arg arch "$go_arch" '
      .[] | select(.version == $version) | .files[] |
      select(.os == "linux" and .arch == $arch and .kind == "archive") | .sha256
    ' "$metadata")"
    [[ -n "$filename" && "$filename" != "null" ]] || { echo "Go $go_version archive not found" >&2; exit 1; }
    [[ -n "$checksum" && "$checksum" != "null" ]] || { echo "Go $go_version checksum not found" >&2; exit 1; }
    archive="$temporary/$filename"
    curl -fsSL "https://go.dev/dl/$filename" -o "$archive"
    printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -
    tar -xzf "$archive" -C "$temporary"
    install -d -m 700 "$HOME/.local/share/go"
    mv "$temporary/go" "$target"
    case "$temporary" in
      /tmp/agent-first-workbench-go.*) rm -rf -- "$temporary" ;;
      *) echo "refusing to remove unexpected temporary path: $temporary" >&2; exit 1 ;;
    esac
  fi

  if [[ -e "$current" || -L "$current" ]]; then
    if [[ -L "$current" && "$(readlink "$current")" == "$target" ]]; then
      return
    fi
    mv "$current" "$current.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  ln -s "$target" "$current"
}

install_uv_and_python() {
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install/update uv and Python versions: $python_versions"
    return
  fi
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
  # shellcheck disable=SC2086
  "$HOME/.local/bin/uv" python install $python_versions
}

install_nvm_and_node() {
  local version executable name
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install NVM $nvm_version and Node versions: $node_versions (default $node_default)"
    return
  fi
  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh" |
      PROFILE=/dev/null bash
  fi
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"
  for version in $node_versions; do
    nvm install "$version"
  done
  nvm alias default "$node_default"
  nvm use default >/dev/null
  install -d -m 700 "$HOME/.local/bin"
  for name in node npm npx corepack; do
    executable="$(command -v "$name" || true)"
    [[ -n "$executable" ]] && ln -sfn "$executable" "$HOME/.local/bin/$name"
  done
}

install_bun() {
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install/update stable Bun in ~/.bun"
    return
  fi
  curl -fsSL https://bun.com/install | env BUN_INSTALL="$HOME/.bun" bash
}

install_code_graph() {
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install/update code-review-graph with community analysis via uv"
    return
  fi
  "$HOME/.local/bin/uv" tool install --force 'code-review-graph[communities]'
}

install_harlequin() {
  if [[ "$mode" == "dry-run" ]]; then
    echo "would install/update Harlequin with the PostgreSQL adapter using uv"
    return
  fi
  "$HOME/.local/bin/uv" tool install --force 'harlequin[postgres]'
}

install_go
install_uv_and_python
install_nvm_and_node
install_bun
install_code_graph
install_harlequin

if [[ "$mode" == "dry-run" ]]; then
  echo "dry run only; rerun with --apply to install runtimes"
else
  echo "installed Go, Python/uv, Node/NVM, Bun, code-review-graph, and Harlequin"
fi

#!/usr/bin/env bash
set -euo pipefail

start_daemon=false

usage() {
  cat <<'EOF'
usage: build-code-graphs.sh [--daemon] ALIAS=PATH [ALIAS=PATH ...]

Register and fully build one or more code-review-graph repositories. With
--daemon, add them to the incremental watcher and start it after all builds.
EOF
}

case "${1:-}" in
  --daemon) start_daemon=true; shift ;;
  -h|--help) usage; exit 0 ;;
esac

(($# > 0)) || { usage >&2; exit 2; }
command -v code-review-graph >/dev/null || { echo "code-review-graph is required" >&2; exit 1; }
if [[ "$start_daemon" == true ]]; then
  command -v crg-daemon >/dev/null || { echo "crg-daemon is required" >&2; exit 1; }
fi

for specification in "$@"; do
  alias_name="${specification%%=*}"
  repository="${specification#*=}"
  [[ "$specification" == *=* && -n "$alias_name" && -n "$repository" ]] || {
    echo "invalid repository specification: $specification" >&2
    usage >&2
    exit 2
  }
  [[ "$alias_name" =~ ^[A-Za-z0-9_.-]+$ ]] || {
    echo "invalid alias: $alias_name" >&2
    exit 2
  }
  [[ -d "$repository/.git" || -f "$repository/.git" ]] || {
    echo "not a Git repository: $repository" >&2
    exit 1
  }

  printf '\n==> Registering %s\n' "$alias_name"
  code-review-graph register "$repository" --alias "$alias_name"

  printf '\n==> Building %s\n' "$alias_name"
  code-review-graph build --repo "$repository"

  if [[ "$start_daemon" == true ]]; then
    printf '\n==> Watching %s\n' "$alias_name"
    crg-daemon add "$repository" --alias "$alias_name"
  fi
done

if [[ "$start_daemon" == true ]]; then
  if crg-daemon status 2>/dev/null | rg -q 'running'; then
    crg-daemon restart
  else
    crg-daemon start
  fi
  crg-daemon status
fi

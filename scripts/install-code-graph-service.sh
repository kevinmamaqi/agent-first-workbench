#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:---dry-run}"
source_file="$root/config/systemd/user/crg-watch.service"
target="$HOME/.config/systemd/user/crg-watch.service"

case "$mode" in
  --dry-run|--apply) ;;
  *) echo "usage: install-code-graph-service.sh [--dry-run|--apply]" >&2; exit 2 ;;
esac

[[ "$(uname -s)" == "Linux" ]] || { echo "Linux is required" >&2; exit 1; }
command -v systemctl >/dev/null || { echo "systemctl is required" >&2; exit 1; }
[[ -f "$source_file" ]] || { echo "missing service file: $source_file" >&2; exit 1; }

if [[ "$mode" == "--dry-run" ]]; then
  echo "would install $target"
  echo "would replace a directly started crg-daemon with the user service"
  echo "would enable and start crg-watch.service"
  echo "administrator should enable lingering for $(id -un) so it survives logout/reboot"
  exit 0
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
install -d -m 700 "$(dirname "$target")"
if [[ -e "$target" ]]; then
  cp "$target" "$target.bak.$timestamp"
fi
install -m 600 "$source_file" "$target"

if command -v crg-daemon >/dev/null && crg-daemon status 2>/dev/null | rg -q 'running'; then
  crg-daemon stop
fi

systemctl --user daemon-reload
systemctl --user enable --now crg-watch.service
systemctl --user is-active --quiet crg-watch.service
echo "crg-watch.service is active"

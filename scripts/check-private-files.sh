#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${1:-$root}"
fail() {
  echo "privacy check failed: $1" >&2
  exit 1
}

scan_status=0
rg -l --hidden --no-ignore \
  --glob '!.git' \
  --glob '!.git/**' \
  --glob '!scripts/check-private-files.sh' \
  '(/Users/[^/$[:space:]]+|/home/[^/$[:space:]]+|postgres(ql)?://|mysql://|mongodb(\+srv)?://|BEGIN ([A-Z0-9]+ )?PRIVATE KEY|gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{16,}|(AKIA|ASIA)[A-Z0-9]{16})' . || scan_status=$?
if (( scan_status == 0 )); then
  fail "possible private path, connection string, or credential"
elif (( scan_status != 1 )); then
  fail "content scan could not complete"
fi

scan_status=0
rg --files --hidden --no-ignore --glob '!.git' --glob '!.git/**' --glob '!.gitignore' \
  --glob '*.env' --glob '.env*' --glob '*history*' --glob 'hosts.yml' \
  --glob '*.pem' --glob 'id_rsa*' --glob 'id_ed25519*' --glob '*__pycache__*' \
  --glob '*.pyc' --glob '*.log' --glob 'auth.json' --glob 'credentials' || scan_status=$?
if (( scan_status == 0 )); then
  fail "private state or credential-shaped file"
elif (( scan_status != 1 )); then
  fail "filename scan could not complete"
fi

if [[ -n "${PRIVATE_DENYLIST:-}" ]]; then
  [[ -f "$PRIVATE_DENYLIST" ]] || fail "PRIVATE_DENYLIST does not exist"
  while IFS= read -r term; do
    [[ -z "$term" || "$term" == \#* ]] && continue
    scan_status=0
    rg -q --hidden --no-ignore --fixed-strings --glob '!.git' --glob '!.git/**' -- "$term" . || scan_status=$?
    if (( scan_status == 0 )); then
      fail "private denylist match"
    elif (( scan_status != 1 )); then
      fail "denylist scan could not complete"
    fi
  done < "$PRIVATE_DENYLIST"
fi

python3 - <<'PY'
from pathlib import Path
root = Path.cwd().resolve()
for path in root.rglob('*'):
    if '.git' in path.relative_to(root).parts:
        continue
    if path.is_symlink() and not path.resolve().is_relative_to(root):
        raise SystemExit('check failed: external symlink: ' + str(path.relative_to(root)))
PY

echo "private-file checks passed"

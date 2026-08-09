#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() {
  echo "check failed: $1" >&2
  exit 1
}

bash -n install.sh install-linux.sh install-runtimes-linux.sh scripts/check-public.sh config/bash/terminal-env.sh
zsh -n config/zsh/terminal-env.zsh config/zsh/terminal-productivity.zsh
jq empty config/cmux/cmux.json
jq empty config/agents/claude-settings.json.example
python3 -c 'import pathlib, tomllib; tomllib.loads(pathlib.Path("config/atuin/config.toml").read_text())'
python3 -c 'import pathlib, tomllib; tomllib.loads(pathlib.Path("config/harlequin/harlequin.toml").read_text())'
python3 -c 'import pathlib, tomllib; tomllib.loads(pathlib.Path("config/agents/codex-config.toml.example").read_text())'
python3 -c 'import pathlib, tomllib; tomllib.loads(pathlib.Path("config/agents/kimi-config.toml.example").read_text())'

[[ -f skills/agent-first-audit/SKILL.md ]] || fail "canonical audit skill is missing"
[[ -f .agents/skills/agent-first-audit/SKILL.md ]] || fail "Codex skill link is broken"
[[ -f .claude/skills/agent-first-audit/SKILL.md ]] || fail "Claude skill link is broken"

if command -v cmux >/dev/null 2>&1; then
  cmux config validate --path config/cmux/cmux.json >/dev/null
fi

if rg -n --hidden \
  --glob '!.git/**' \
  --glob '!scripts/check-public.sh' \
  --glob '!config/atuin/config.toml' \
  '(/Users/[^/$[:space:]]+|/home/[^/$[:space:]]+|postgres(ql)?://|mysql://|mongodb(\+srv)?://|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|gh[pousr]_[A-Za-z0-9_]+|sk-[A-Za-z0-9_-]{16,})' .; then
  fail "possible private path, connection string, or credential"
fi

if [[ -n "${PRIVATE_DENYLIST:-}" ]]; then
  [[ -f "$PRIVATE_DENYLIST" ]] || fail "PRIVATE_DENYLIST does not exist"
  while IFS= read -r term; do
    [[ -z "$term" || "$term" == \#* ]] && continue
    if rg -q --hidden --fixed-strings --glob '!.git/**' -- "$term" .; then
      fail "private denylist match"
    fi
  done < "$PRIVATE_DENYLIST"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git diff --check
fi

echo "public checks passed"

# shellcheck shell=sh
# Shared non-interactive runtime environment. Keep identities in private profiles.
export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export PATH="$HOME/.local/bin:$HOME/.local/go/bin:$HOME/go/bin:$BUN_INSTALL/bin:$HOME/.kimi-code/bin:$PATH"

if [ "$(uname -s)" = Linux ]; then
  umask 077
  # Homes are normally disk-backed, unlike small server /tmp tmpfs mounts.
  export TMPDIR="${TMPDIR:-$HOME/.cache/agent-first-workbench/tmp}"
  export GOCACHE="${GOCACHE:-$HOME/.cache/agent-first-workbench/go-build}"
  export GOTMPDIR="${GOTMPDIR:-$TMPDIR}"
  mkdir -p "$TMPDIR" "$GOCACHE" "$GOTMPDIR"
fi

if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
fi

# Linux Agent Host

The Linux profile turns a fresh Debian or Ubuntu account into a persistent
terminal-first agent workspace. It installs shared CLI prerequisites and the
native Codex, Claude Code, and Kimi Code clients, but it does not copy any
credentials or authenticate any account.

```bash
git clone https://github.com/kevinmamaqi/agent-first-workbench.git
cd agent-first-workbench
./install-linux.sh --dry-run
./install-linux.sh --apply
make check
```

On a multi-user server, split the operation so workload users remain non-admin:

```bash
# Once, from the administrator account
./install-linux.sh --apply --system-only

# Once from each isolated workload account
./install-linux.sh --apply --user-only
```

Install the primary language runtimes and code graph separately as the workload
user:

```bash
./install-runtimes-linux.sh --dry-run
./install-runtimes-linux.sh --apply
```

Defaults are Go 1.26.5, Node 22 and 24 (24 as default), uv-managed Python 3.11
and 3.13, stable Bun, `code-review-graph[communities]`, and Harlequin with its
PostgreSQL adapter. Override the version
lists with `GO_VERSION`, `NODE_VERSIONS`, `NODE_DEFAULT`, and `PYTHON_VERSIONS`.

The system scope installs shared packages, AWS CLI v2, and account-aware command
dispatchers. The user scope installs RTK, the three agents, and shell/tmux
settings in that account's home. It also registers RTK's global Claude Code Bash
hook. Kimi's RTK integration is project-scoped; enable it only inside a project
that should carry those files with `rtk init --agent kimi`.

The Bash profile applies `umask 077`, so new per-account credentials and agent
artifacts are private by default.

The system scope also installs WireGuard and the PostgreSQL command-line client.
Those are human/admin facilities: coding agents use only the constrained MCP
path described in [database-access.md](database-access.md).

## Long-running sessions

Start or reattach tmux before launching an agent:

```bash
agent-session main
```

tmux survives an SSH disconnect, but not a server reboot. Convert important
unattended workloads into systemd user services and enable lingering for that
account.

## Authentication boundary

Authenticate on the target account rather than copying auth caches into this
repository:

```bash
codex login --device-auth
claude
kimi
gh auth login --web --git-protocol ssh
aws sso login --profile PROFILE --use-device-code
```

The three example agent configuration files under `config/agents/` contain only
public-safe preferences. They deliberately omit authentication, project trust,
absolute paths, hooks, plugins, MCP servers, providers, API keys, and machine
identities. Merge them after the agent has created its local configuration.

## Private overlay

Keep account names, host aliases, AWS SSO metadata, GitHub identities, private
repository mappings, and project-specific configuration in a separate private
repository. Never commit agent auth caches, `~/.aws/credentials`,
`~/.aws/sso/cache`, `~/.config/gh/hosts.yml`, `.env` files, or SSH private keys.

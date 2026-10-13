# Linux Agent Host

The Linux profile turns a fresh Debian or Ubuntu account into a persistent
terminal-first agent workspace. It installs shared CLI prerequisites and the
native Codex, Claude Code, and Kimi Code clients, but it does not copy any
credentials or authenticate any account.

The system installer currently targets amd64 and requires repositories that
provide the listed terminal packages (including Atuin, Eza, Glow, and Delta).
It checks package availability before installation. Older distributions may
need separately provisioned tools; use `--user-only` for configuration on an
already prepared host.

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

Use `--skip-agents` on the per-user pass when the agent CLIs are already
installed and only terminal/configuration parity needs to be refreshed. The
Linux baseline includes Zsh, Atuin, fzf, Zoxide, Delta, Bat, Eza, Glow, Helix,
and the same portable shell helpers as the macOS setup. Atuin history and keys
remain private to each Unix account and automatic sync stays disabled.

Set Zsh as the workload account's login shell from the administrator account:

```bash
sudo usermod --shell /bin/zsh WORKLOAD_USER
```

The tmux profile also selects Zsh for new panes. Existing panes keep their
current shell until they are replaced; they still gain immediate append/share
history behavior after re-sourcing the Bash profile.

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

Bash and Zsh share runtime paths and account-local defaults for `TMPDIR`,
`GOCACHE`, and `GOTMPDIR`; system installer staging uses `/var/tmp`. Existing
overrides are preserved. See [Codex workflow](codex-workflow.md).

Full Vim and the portable Helix profile are included. See
[terminal review](terminal-review.md) and [phone sessions](phone-work.md) for
editor basics and the Linux `work` command. The Mac launcher keeps its
separate workspace-map syntax.

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

The installed helpers keep the same commands across macOS and Linux:

```bash
awslogin PROFILE
```

`awslogin` opens the normal browser flow on a local desktop and selects the
device-code flow over SSH or in a headless Linux shell. A private host profile
can export its preferred `AWS_PROFILE` so agents use plain `aws` commands after
the SSO session has been cached.

Configure profiles with `aws configure sso` first. The helper changes the login
flow; permissions remain those of the selected profile. See the
[AWS SSO reference](https://docs.aws.amazon.com/cli/latest/reference/sso/login.html).

The three example agent configuration files under `config/agents/` contain only
public-safe preferences. They deliberately omit authentication, project trust,
absolute paths, hooks, plugins, MCP servers, providers, API keys, and machine
identities. Merge them after the agent has created its local configuration.

## Private overlay

Keep account names, host aliases, AWS SSO metadata, GitHub identities, private
repository mappings, and project-specific configuration in a separate private
repository. Never commit agent auth caches, `~/.aws/credentials`,
`~/.aws/sso/cache`, `~/.config/gh/hosts.yml`, `.env` files, or SSH private keys.

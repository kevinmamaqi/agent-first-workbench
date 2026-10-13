# Human And Agent Database Access

Database access has two deliberately separate interfaces:

- `dbui DATABASE_ID` opens Harlequin for a human operator.
- `workbench-db-mcp DATABASE_ID` starts a constrained DBHub server for an agent.

Both resolve the same account-local database map and `0600` credential store,
but agents must never invoke Harlequin, a PostgreSQL CLI, or read the credential
store. The database identity is the hard read-only boundary. DBHub's read-only
parser, tool allowlist, 100-row cap, 30-second timeout, and client approvals are
defence in depth, not substitutes for database grants.

## Account-local files

The public repository contains no database identities, network names, or DSNs.
A private profile supplies:

```text
~/.config/agent-first-workbench/databases.conf  # identifiers and routing
~/.config/agent-first-workbench/db.env          # DSNs, mode 0600
```

`databases.conf` defines the two WireGuard interface names and one resolver:

```bash
WORKBENCH_WG_DEV_INTERFACE="company-dev"
WORKBENCH_WG_PROD_INTERFACE="company-prod"

workbench_database() {
  case "$1" in
    app-dev)
      WORKBENCH_DATABASE_DSN_VAR="APP_DEV_DB_DSN"
      WORKBENCH_DATABASE_TUNNEL="dev"
      ;;
    app-prod)
      WORKBENCH_DATABASE_DSN_VAR="APP_PROD_DB_DSN"
      WORKBENCH_DATABASE_TUNNEL="prod"
      ;;
    *) return 1 ;;
  esac
}
```

The secret file is a plain `NAME=value` dotenv file. Do not commit it, source it
interactively, pass it in argv, or reuse application-owner credentials.

## WireGuard on a multi-user Linux host

Give the server its own revocable peer in each environment. Never copy a laptop
peer profile: sharing a private key makes revocation and attribution ambiguous,
and simultaneous use can make a peer endpoint flap.

Store profiles as `/etc/wireguard/INTERFACE.conf`, owned by root with mode
`0600`. Permit the workload account to start and stop only those exact
`wg-quick@INTERFACE.service` units through a narrowly scoped sudoers rule.
`workbench-wg` keeps dev and prod mutually exclusive:

```bash
workbench-wg status
workbench-wg up dev
workbench-wg up prod
workbench-wg down
```

`dbui` starts the required tunnel and tears it down when Harlequin exits unless
that tunnel was already active.

Agent sessions own an explicit per-task lifecycle around Aurora MCP calls:

```bash
workbench-wg up dev       # or: up prod
workbench-wg status       # must match the selected environment
# Call only the matching read-only Aurora MCP server.
workbench-wg down dev     # or: down prod
workbench-wg status       # must report none
```

Cleanup is required after the final MCP call even when the query fails, times
out, or is cancelled. If an agent sandbox blocks the helper, request approval
for the exact `workbench-wg` command; do not fall back to another database or a
direct client.

`workbench-db-mcp` deliberately does not start a tunnel itself. MCP clients may
launch dev and prod server processes together during session startup, while the
two tunnels are mutually exclusive. Keeping tunnel selection in the visible
task workflow prevents one idle MCP process from silently replacing another
environment's route.

## MCP registration

Register the same three wrapper invocations in every client. Client
configuration contains only the executable path and database identifier.

- Codex: `[mcp_servers.NAME]` with `enabled_tools = ["execute_sql",
  "search_objects"]` and `default_tools_approval_mode = "prompt"`.
- Claude Code: `claude mcp add -s user NAME -- workbench-db-mcp DATABASE_ID`.
- Kimi Code: `~/.kimi/mcp.json` with stdio `command` and `args`. Kimi prompts
  for MCP tool calls when YOLO/AFK mode is off.

Starting all clients does not connect to a database: DBHub sources are lazy.
Configuration validation must stop before SQL. Prove role grants through a
controlled DBA provisioning/review path, not with mutation probes.

## Explicit human targets

With a private map that defines `billing_dev` and `billing_prod`:

```bash
dbui dev billing
dbui prod billing
dbui billing_prod
dbui write dev
dbui write prod
```

The two-argument form resolves `DATABASE_ENV` in `databases.conf`. Maps can
set `WORKBENCH_DATABASE_NAME` and `WORKBENCH_DATABASE_READONLY_USER` to reject
a DSN for the wrong database or identity. Ordinary targets use TLS and a
read-only session; database grants remain the hard permission boundary.
Harlequin receives connection fields in its child environment, not argv.

The human write connections live in a separate, owner-only `db-write.env`,
with `DATABASE_WRITE_DEV_DSN` and `DATABASE_WRITE_PROD_DSN`. Select the
environment explicitly with `dbui write dev` or `dbui write prod`. Each
requires a writable server session and is never registered with MCP.
The MCP wrapper rejects DSN variable names containing `WRITE` and validates
the optional expected database and identity before starting DBHub.

The default remains a dry-run-first private installation. Existing DSNs must
be preserved in place; fill new placeholders independently on each machine.

## macOS lifecycle pattern

The shipped controller uses Linux systemd. For a separate macOS controller,
use one lifecycle owner. This is a recipe, not an installed implementation:

- Create an owner-only ephemeral configuration. Where appropriate, remove
  `DNS` from that snapshot and pin its MTU to avoid DNS-monitor feedback.
  Preserve the original peer configuration.
- Repair partial interface state and stop the other environment before treating
  the selected tunnel as already active.
- Bound readiness probes; report status without exposing configuration values.
- Track whether this invocation started the tunnel. Cleanup preserves tunnels
  that were active before the command.

See [wg-quick documentation](https://git.zx2c4.com/wireguard-tools/about/src/man/wg-quick.8)
for platform behavior. Never start real peers during publication checks.

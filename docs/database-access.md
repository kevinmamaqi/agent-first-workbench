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
that tunnel was already active. Agent sessions bring up the selected tunnel as
an explicit visible step before calling an Aurora-style MCP server.

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

# Remote workbench

cmux can mirror a remote host's tmux sessions as native workspaces, tabs, and
splits:

```bash
cmux ssh-tmux user@host
```

Enable cmux's **Remote tmux** beta setting first. SSH aliases, identity files,
ports, and proxy jumps from `~/.ssh/config` are honored.

The durable process boundary is remote tmux, not the laptop connection. Closing
the lid disconnects SSH, while agents running inside remote tmux continue. Run
the same `cmux ssh-tmux` command later to mirror and resume those sessions.

Use cmux's native session features for local work too:

```bash
cmux hooks setup
cmux restore-session
cmux list-workspaces
cmux notify --title "Remote agent" --body "Ready for review"
```

The workbench enables native agent-session resume. cmux captures supported
Codex and Claude session IDs through their hooks and can relaunch the agents with
their own resume commands after restoring the workspace layout. This is separate
from remote tmux persistence: local agent resume restores an agent conversation;
remote tmux preserves the actual server process.

Keep real hosts, account names, identity paths, and repository mappings in a
private overlay. A private helper may create a named remote tmux session before
asking cmux to mirror the host.

The included `work` launcher preserves a short terminal rhythm while
making location unmistakable. Remote is the default:

```bash
work project                 # REMOTE-project; reconnects if it exists
work project task-name       # separate durable workspace for a task
work project --agent codex   # create it and start Codex
work --local project         # LOCAL-project
```

Aliases resolve through a private `workspaces.conf`. A remote alias creates a
tmux session in its mapped directory and mirrors it into the cmux sidebar.
After opening the workspace, `claude`, `codex`, `kimi`, and their resume
commands work exactly as they do in a local shell.

## Hand remote review artifacts to cmux

Linux cannot run the native macOS cmux CLI or access its local socket. The
workbench therefore installs a narrow queued bridge for review handoffs:

```bash
# Run inside a mirrored remote tmux session:
cmux open .claude/specs/feature.md
# Equivalent:
cmux markdown open .claude/specs/feature.md

# Hand a GitHub page to the local cmux browser for human review:
cmux browser open https://github.com/owner/repository/compare/main...branch
```

The remote shim accepts only Markdown files inside that workload account's
`~/workspace` and `https://github.com/` browser URLs. It queues the handoff; the
Mac bridge started by `work` copies only the requested Markdown into a private
local cache or opens the URL in the browser. Markdown can open alongside the
matching tmux workspace; browser handoffs use a non-focusing sibling workspace
named `REVIEW | <session>` because remote-tmux workspaces cannot host a local
browser surface. A browser handoff is for human review; the remote agent cannot
click or submit forms in the local browser. Requests remain queued while the
Mac is asleep and are handled after reconnecting. Markdown is snapshot review,
not bidirectional file synchronization.

Codex `PermissionRequest` and `Stop`, Claude `permission_prompt`, and Kimi
`Notification` hooks use the same queue. Codex alerts distinguish an approval
prompt from a completed turn. The bridge also detects the standard Codex
approval modal for sessions that were already running when hooks were installed.
Notifications contain only the workload/session label and event kind; prompt
text stays on the server. The bridge keeps the cmux socket inherited from the
native Mac workspace and maps durable tmux names back to their shorter cmux
workspace titles without focusing either workspace.

For remote agents that create sibling Git worktrees, keep Codex in
`workspace-write`, add the workload account's repository root as a writable
root, and enable automatic approval review. This avoids repeated file-edit and
build-cache prompts while retaining the sandbox; do not replace it with
`danger-full-access` merely for convenience.

# Phone SSH sessions

The Linux installer links `bin/workbench-phone-session` as `~/.local/bin/work`.
Set its starting directory in a private shell profile:

```bash
export WORKBENCH_PHONE_CWD="$HOME/workspace/repos/project"
work "my task"
work --plain "my task"
```

Control mode is the default for terminals with native tmux support; `--plain`
uses conventional SSH terminal attachment. This server command takes one
session name. The Mac command takes a workspace alias and optional task name;
neither scheme is automatically translated into the other.

Names have 1–128 letters, numbers, spaces, underscores, or hyphens, starting
with a letter or number. Exact tmux targets avoid similarly named sessions.
Existing sessions retain their directory and programs; new sessions start in
the configured directory.

Inside tmux, the launcher switches the sole attached client without nesting
tmux. If several clients share the current session, it prepares the target
and asks you to select it in the terminal dashboard. Other devices stay put.
Sessions survive SSH disconnects, but not host reboots.

Installation follows the Linux profile's dry-run, backup, and rerun behavior.
No host, account, credentials, or private directory map is included.

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

Keep real hosts, account names, identity paths, and repository mappings in a
private overlay. A private helper may create a named remote tmux session before
asking cmux to mirror the host.

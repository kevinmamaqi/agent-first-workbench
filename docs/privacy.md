# Privacy Boundary

This repository is a sanitized snapshot of a real personal setup. It publishes the workflow and configuration choices, not the private work performed through them.

## Never Commit

- credentials, tokens, environment files, private keys, or connection strings;
- shell history, Atuin keys, session state, browser profiles, cookies, or logs;
- personal absolute paths, hosts, repository names, tickets, customer data, or command output from private work;
- screenshots or recordings containing real tabs, paths, notifications, history, or identifiers.

## Publication Process

1. Update the private working setup first.
2. Recreate the public-safe change deliberately; never blindly mirror a dotfile.
3. Use synthetic names, paths, hosts, and data.
4. Run `make check`, optionally with an external `PRIVATE_DENYLIST`.
5. Inspect the full Git diff and history manually.

The external denylist must remain outside this repository. Automated scanning is a safety net, not publication approval.


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

`make check` includes ignored files and reports only filenames for pattern
matches. It rejects credential-shaped files, history/log artifacts, and
symlinks resolving outside the repository. Tests run without bytecode caches.

Review every outgoing commit's content and message, including unpublished
branches. Scan the final tree with an external denylist and inspect the exact
staged files. A passing scan does not establish that every identifier is safe.


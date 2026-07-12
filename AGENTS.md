# Agent Instructions

- Use `rg` for content search and `rg --files` or `fd` for discovery.
- Use `jq` and `yq` for structured data.
- Prefer read-only commands and synthetic examples.
- Use plain Git output and explicit checks as evidence.
- Preserve a raw-output path for filtered, styled, or truncated commands.
- Never print or commit credentials, private paths, shell history, session state, hosts, database URLs, or private repository output.
- Do not activate hooks, install packages, or modify user configuration without an explicit request.
- Run `make check` after changes.


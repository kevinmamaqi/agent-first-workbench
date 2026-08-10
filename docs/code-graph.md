# Code graph

Use `code-review-graph` as the default structural index for large code repositories.
It supports Codex and Claude Code, incremental updates, multi-repository search,
blast-radius analysis, test discovery, and the Go, Python, JavaScript, and
TypeScript stacks used by this workbench.

Install it with the Linux runtime profile:

```bash
./install-runtimes-linux.sh --apply
```

Or install only the tool:

```bash
uv tool install --force 'code-review-graph[communities]'
code-review-graph install --platform codex
code-review-graph install --platform claude-code
```

Prefer project-scoped MCP configuration when a coordination repository already
defines its repositories and workflow. Codex stores MCP configuration in
`config.toml`; Claude Code can consume project `.mcp.json`. Keep one executable
version behind both clients to avoid tool-schema and path-handling differences.

For code questions, use the graph before broad file reads:

```text
minimal context -> impact radius -> tests -> focused source reads
```

Measure adoption rather than trusting instructions alone:

```bash
code-review-graph status
code-review-graph detect-changes --brief
code-review-graph daemon status
```

Graphify remains useful when a project genuinely needs one graph spanning code,
PDFs, images, and other documents. Do not run two overlapping code indexes by
default; compare them on a bounded repository with the same questions and token
budget first.

For a multi-repository host, register, fully build, and watch repositories with:

```bash
./scripts/build-code-graphs.sh --daemon \
  backend=/path/to/backend \
  web=/path/to/web
```

The full build is intentionally explicit and may be long-running. Run it inside
tmux on a persistent host. Subsequent changes are handled incrementally by
`crg-daemon`.

Keep the watcher running after logout and reboot with the user service:

```bash
./scripts/install-code-graph-service.sh --dry-run
./scripts/install-code-graph-service.sh --apply
```

An administrator must also run `loginctl enable-linger <account>` once. The
service uses `crg-daemon start --foreground` so systemd owns and restarts the
watch process.

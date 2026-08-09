# Agent-First Workbench

My opinionated macOS and Linux setup for working with coding agents: direct to install, simple to inspect, and built around specs, measurement, diffs, and human review.

Six months ago, most of my coding happened in Cursor. As coding agents became more reliable, my work moved into the terminal and eventually into cmux. I now spend less time opening files and more time writing specs, supervising execution, measuring where agent time goes, reviewing diffs, and deciding whether the result is correct.

This repository is the sanitized setup I actually use—not an ultimate configuration or a universal framework.

## Try It

Requirements: macOS 14+ and [Homebrew](https://brew.sh/).

```zsh
git clone https://github.com/kevinmamaqi/agent-first-workbench.git
cd agent-first-workbench

brew bundle
./install.sh --dry-run
./install.sh --apply
make check
```

For a persistent Debian or Ubuntu agent host, see [Linux Agent Host](docs/linux-server.md):

```bash
./install-linux.sh --dry-run
./install-linux.sh --apply
make check
```

`install.sh` changes nothing without `--apply`. Apply mode backs up existing target files before creating links.

## The Loop

```text
request task
  → agent explores existing code and work
  → agent writes a spec
  → human reviews the spec
  → agent implements one slice
  → checks verify the evidence
  → human reviews the diff and result
```

The repository is the control surface: instructions, specs, tools, checks, and evidence live with the code rather than only in chat history.

## Humans And Agents Need Different Interfaces

| Human needs | Agent needs |
| --- | --- |
| fuzzy discovery | deterministic commands |
| readable diffs and previews | plain or structured output |
| context recovery | durable repository instructions |
| visual review surfaces | explicit verification commands |
| easy interruption and steering | bounded permissions and scope |

Both meet at the same boundary: a reviewed specification before implementation and verifiable evidence afterward.

## What I Use

- **Workspace:** [cmux](https://github.com/manaflow-ai/cmux) + [Ghostty](https://github.com/ghostty-org/ghostty)
- **Agents:** Claude Code + Codex + Kimi Code
- **Editing:** [Helix](https://helix-editor.com/) and Vim-style interaction
- **Navigation:** [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd), [fzf](https://github.com/junegunn/fzf), [Zoxide](https://github.com/ajeetdsouza/zoxide), and [Atuin](https://docs.atuin.sh/)
- **Review:** [Delta](https://github.com/dandavison/delta), [Bat](https://github.com/sharkdp/bat), and [Glow](https://github.com/charmbracelet/glow)
- **Structured data:** [jq](https://jqlang.org/) + [mikefarah/yq](https://github.com/mikefarah/yq)
- **Database exploration:** [Harlequin](https://harlequin.sh/) for an interactive SQL workspace in the terminal
- **Agent context:** `AGENTS.md`, `CLAUDE.md`, skills, and MCP
- **Concise agent output:** [RTK](https://github.com/rtk-ai/rtk), with `rtk proxy` as the raw-output escape hatch

The tools matter less than the division of responsibility: ergonomic output helps navigation and review; raw Git, structured data, tests, and explicit checks remain the evidence.

## Measurement

I log agent-assisted tasks across five buckets: information gathering, code/test, authoring, orchestration, and waiting. In a recent set of tasks, 92.5% of time happened locally before code was pushed, while reading and understanding represented 23.8%.

Those are self-reported estimates, not a benchmark or a correctness claim. The methodology and its limits are documented in [We Timed Our Coding Agents](https://www.eachlabs.ai/blog/we-timed-our-coding-agents-92-of-the-work-happened-before-code-was-pushed).

## Safety

- Examples use synthetic paths, hosts, identifiers, and data.
- Atuin sync is off in the example configuration; history stays local unless you opt in.
- The public Harlequin profile is local DuckDB only and contains no connection strings or credentials.
- No database URLs, credentials, shell history, browser state, session logs, or private repository output belong here.
- Hooks are intentionally not activated by cloning this repository.
- Run `make check` and inspect the complete Git diff before publishing changes.

See [privacy.md](docs/privacy.md) for the publication boundary and [sources.md](docs/sources.md) for upstream projects and licenses.

## One Included Skill

[`agent-first-audit`](skills/agent-first-audit/SKILL.md) performs a read-only review of a repository's instructions, skills, hooks, verification paths, human/agent boundary, and privacy risks. It reports gaps; it does not install or edit anything.

The same canonical skill is exposed through `.agents/skills/` for Codex and `.claude/skills/` for Claude Code.

## Scope

The desktop setup is macOS-first and cmux-centered. The Linux profile targets persistent Debian or Ubuntu agent hosts. Both remain personal and opinionated; copy the pieces that solve a problem for you.

## License

Original content in this repository is available under the [MIT License](LICENSE). Named tools remain governed by their upstream licenses.

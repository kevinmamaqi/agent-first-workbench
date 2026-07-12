---
name: agent-first-audit
description: Read-only audit of a repository's agent instructions, skills, hooks, verification paths, terminal interfaces, and privacy boundaries.
---

# Agent-First Audit

Audit the current repository without modifying files, installing software, activating hooks, or changing permissions.

## Inspect

1. Find applicable `AGENTS.md`, `CLAUDE.md`, agent config, skills, and hook registrations.
2. Identify the documented task loop from request through human approval.
3. Map human-facing shortcuts to deterministic commands agents can run non-interactively.
4. Check that formatted or filtered output has a plain/raw escape path.
5. Find verification commands and confirm instructions define what “done” means.
6. Review permission and hook scope for broad matchers or surprising side effects.
7. Check examples and outputs for credentials, private paths, hosts, session state, or non-synthetic data.

## Report

Return:

- instruction and skill map;
- current workflow;
- strengths;
- gaps ranked high/medium/low;
- exact files that support each finding;
- minimal recommended next steps.

Do not implement the recommendations unless the user asks in a separate step.


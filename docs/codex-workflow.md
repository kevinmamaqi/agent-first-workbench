# Codex permissions and unattended work

Keep filesystem sandboxing and command approval separate. Repository
instructions replace neither. Choose writable worktree/cache roots
deliberately and authenticate inside the workload account.

Stable rules reduce repeated prompts for already authorized operations. Keep
them in a private profile and review each prefix's reach. Nothing here installs
execution rules automatically. A narrowly defined GitHub GET route could use:

```python
prefix_rule(
    pattern = ["gh", "api", "--method", "GET", "repos/example/project/pulls"],
    decision = "allow",
    match = ["gh api --method GET repos/example/project/pulls"],
    not_match = ["gh api --method POST repos/example/project/pulls"],
)
```

Rules apply to prefixes outside the sandbox; the most restrictive matching
decision wins. Inspect them with `codex execpolicy check --rules FILE -- COMMAND`.
Shell wrapping, substitutions, and redirection can change evaluation. See the
[official OpenAI rules documentation](https://learn.chatgpt.com/docs/agent-configuration/rules).

Read/search, tests, code-graph analysis, GitHub reads, and publication deserve
separate decisions. Tests execute repository code. Generic interpreter, shell,
or proxy prefixes grant much more than a single test or command.

When branch publication is authorized, verify the diff, commit, push, and open
the requested PR. Merge, deployment, force-push, spending, and unrelated writes
need their own authorization. Finish independent work before a final approval
blocker and report its reason.

Preserve an approved SSH invocation's shape. If the sandbox blocks it, request
escalation directly and report the pending prompt. Do not change wrappers to
evade approval. Coordinate same-account work through the supervisor and use
worktrees to isolate edits.

## Disk-backed scratch

Linux shells and account-aware dispatchers provide an account-local default
`TMPDIR`. Bash and Zsh share runtime paths; Go gets `GOCACHE` and `GOTMPDIR`.
Runtime downloads use this scratch root; system staging uses `/var/tmp`.

Existing overrides are respected. Check mount type and space before large
builds; disk-backed paths can fill too. Keep durable worktrees and artifacts
outside temporary directories. Private profiles can choose other paths.

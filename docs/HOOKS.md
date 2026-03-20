# SAW Safety Guardrails (Hook System)

## What are SAW hooks?

SAW uses Claude Code's PreToolUse hooks to enforce protocol invariants at
tool-call time. Each hook intercepts file-modification tool calls (Write,
Edit, Bash) and blocks operations that would violate a safety invariant.
Hooks run automatically — agents never opt in or out.

## What hooks enforce

| Hook | Invariant | What it prevents |
|------|-----------|-----------------|
| Scout write boundary | I6 | Scout editing source code (Scout may only produce IMPL docs) |
| File ownership check | I1 | Agent editing files not assigned to it in the IMPL doc |
| Worktree isolation | I4 | Agent escaping its worktree and writing to the main repo |

These three hooks cover the most common protocol violations. They fire
before the tool executes, so the offending write never reaches disk.

## How hooks are installed

The `install.sh` script in the repo root creates a `~/.claude/skills/saw/`
directory and populates it with symlinks pointing back to the prompt files
in the repository. Hooks are defined inside those prompt files and
activated when Claude Code loads the skill.

The symlink model means updates are automatic: pulling the latest repo
revision updates hook behavior without re-running the installer.

See [docs/symlink-diagram.md](symlink-diagram.md) for a visual layout of
the symlink structure.

## Troubleshooting hooks

**Hook not firing**
Verify the symlinks are intact:

```bash
ls -la ~/.claude/skills/saw/
```

Every entry should be a symlink (`l` prefix) pointing into the repo's
`implementations/claude-code/prompts/` directory. If any are missing or
broken, re-run `./install.sh`.

**Permission denied**
Check that the hook script files in the repo are readable:

```bash
ls -l implementations/claude-code/prompts/*.md
```

All files need at least `644` permissions.

**Hook blocking a valid operation**
This may be a false positive. Check:

1. Which invariant the hook is enforcing (see table above).
2. Whether the file is listed in your agent's ownership table in the IMPL doc.
3. Whether you are operating inside your assigned worktree (not the main repo).

If the operation is genuinely valid and still blocked, report it in your
agent completion report under `out_of_scope_deps` so the orchestrator
can investigate.

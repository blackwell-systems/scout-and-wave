# SAW Claude Code Hooks

Enforcement and injection hooks for CLI-based SAW agents. 16 hooks across SubagentStart, PreToolUse, PostToolUse, SubagentStop, and UserPromptSubmit events.

## Hook Summary

### Enforcement hooks (block protocol violations)

| Hook | Event | Matcher | Rule | Description |
|------|-------|---------|------|-------------|
| inject_worktree_env | SubagentStart | — | E43 | Sets 5 env vars (worktree path, agent ID, wave num, IMPL path, branch) |
| inject_bash_cd | PreToolUse | Bash | E43 | Auto-prepends `cd $SAW_AGENT_WORKTREE &&` to bash commands |
| validate_write_paths | PreToolUse | Write\|Edit | E43 | Blocks relative paths and paths outside worktree |
| verify_worktree_compliance | SubagentStop | — | E42/I5 | Verifies completion report and commits (warn-only) |
| check_scout_boundaries | PreToolUse | Write\|Edit | I6 | Scouts can only write IMPL docs |
| block_claire_paths | PreToolUse | Write\|Edit\|Bash | — | Blocks `.claire` typo paths |
| check_wave_ownership | PreToolUse | Write\|Edit\|NotebookEdit | I1 | Wave agents write only owned files |
| validate_agent_launch | PreToolUse | Agent | H5 | Pre-launch validation gate + agent type injection (see below) |
| validate_impl_on_write | PostToolUse | Write | E16 | Validates IMPL schema after write |
| check_git_ownership | PostToolUse | Bash | I1 | Catches git-level ownership violations |
| warn_stubs | PostToolUse | Write\|Edit | H3 | Warns on stub patterns in written code |
| check_branch_drift | PostToolUse | Bash | H4 | Detects commits on wrong branch |
| validate_agent_completion | SubagentStop | — | E42/I1/I4/I5 | Validates protocol compliance at agent completion |

### Injection hooks (prepend reference content)

| Hook | Event | Matcher | Mechanism | Description |
|------|-------|---------|-----------|-------------|
| validate_agent_launch | PreToolUse | Agent | `updatedInput` | Injects agent type reference files into subagent prompt |
| inject_skill_context | UserPromptSubmit | — | `additionalContext` | Injects skill subcommand references into orchestrator context |

### Observability hooks

| Hook | Event | Matcher | Description |
|------|-------|---------|-------------|
| emit_agent_completion | SubagentStop | — | Emits structured completion event for claudewatch/SSE (async, non-blocking) |

## Injection Patterns

Two hooks handle progressive disclosure injection. They operate at different layers and use different Claude Code mechanisms — neither can substitute for the other.

### Layer 1: Orchestrator injection (`inject_skill_context`, UserPromptSubmit)

Fires when the user submits a prompt. Matches subcommand anchors in the user's raw prompt text, loads the matching reference files from the skill's `references/` directory, and returns them as `additionalContext` — prepended to the **orchestrator's** context before it runs.

```json
{ "hookSpecificOutput": { "hookEventName": "UserPromptSubmit", "additionalContext": "..." } }
```

Trigger definitions live in the skill's YAML frontmatter (`triggers:` extension field). See `docs/proposals/agentskills-subcommand-dispatch.md` for the full design.

**Coverage:** `/saw program *`, `/saw amend *`. Only subcommand-anchored patterns are reliable here — keyword triggers false-positive against skill body content.

### Layer 2: Subagent injection (`validate_agent_launch`, PreToolUse/Agent)

Fires when the orchestrator calls the `Agent` tool to launch a subagent. Dispatches by `subagent_type`, loads matching reference files, and returns them via `updatedInput.prompt` — modifying the Agent tool's `prompt` parameter **before the subagent launches**.

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": { "prompt": "<!-- injected: references/wave-agent-isolation.md -->\n...\n\n[original prompt]" }
  }
}
```

**Why `updatedInput`, not `additionalContext`:** `additionalContext` in a `PreToolUse` hook adds content to the *calling model's* context (the orchestrator). `updatedInput` modifies the tool call parameters before execution — the only mechanism that reaches inside a subagent's initial prompt. See `docs/proposals/subagent-prompt-injection.md` for the full decision record.

**Coverage:** `scout`, `wave-agent`, `critic-agent`, `planner`, `integration-agent`. Dispatch is a sequence of `if` blocks on `subagent_type`. Adding a new agent type requires adding one `if` block — no new hook registration needed.

**Dedup:** Injection markers (`<!-- injected: references/X.md -->`) prevent double-injection if the orchestrator also manually prepended the reference.

### The two-layer picture

```
User types: /saw wave
    │
    ▼
UserPromptSubmit → inject_skill_context
  Target: orchestrator context (additionalContext)
  Matches: ^/saw program, ^/saw amend

      │
      ▼  orchestrator runs, calls Agent tool

PreToolUse/Agent → validate_agent_launch (checks 9-13+)
  Target: subagent initial prompt (updatedInput)
  Matches: subagent_type ∈ {wave-agent, critic-agent, scout, planner, integration-agent}
```

## Installation

### Automated (Recommended)

```bash
cd ~/code/scout-and-wave/implementations/claude-code/hooks
./install.sh
```

The installer:
- Creates symlinks in `~/.local/bin/` for all 16 hook scripts
- Merges hook configs into `~/.claude/settings.json` (preserves existing hooks)
- Verifies installation and runs basic tests

### Manual

See individual hook sections below for manual installation steps.

---

## Hook 1: Scout Boundaries (I6)

**PreToolUse** — Blocks Scout Write/Edit operations outside `docs/IMPL/IMPL-*.yaml`

### How It Works

1. Claude Code calls the script before executing Write/Edit tools
2. Script receives JSON on stdin with tool_name, agent_type, tool_input
3. If agent_type != "scout" -> allow (exit 0)
4. If tool_name not in [Write, Edit] -> allow (exit 0)
5. If file_path matches `docs/IMPL/IMPL-*.yaml` -> allow (exit 0)
6. Otherwise -> block (exit 2) with I6 violation message

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/check_scout_boundaries ~/.local/bin/check_scout_boundaries
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/check_scout_boundaries"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Test valid path (should exit 0)
echo '{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"docs/IMPL/IMPL-test.yaml"}}' | \
  check_scout_boundaries
echo $?  # Should be 0

# Test invalid path (should exit non-zero)
echo '{"tool_name":"Write","agent_type":"scout","tool_input":{"file_path":"src/main.go"}}' | \
  check_scout_boundaries 2>&1
echo $?  # Should be non-zero
```

---

## Hook 2: IMPL Validation on Write (E16)

**PostToolUse** — Validates IMPL docs after every Write, blocks on schema errors.

### How It Works

1. Claude Code calls the script after a Write tool completes
2. Script checks if the written file matches `docs/IMPL/IMPL-*.yaml` (skips archived `/complete/` docs)
3. Runs `sawtools validate` (read-only, no `--fix`)
4. If validation fails -> blocks with error list; agent must fix before continuing
5. If `sawtools` or `jq` not on PATH -> exits silently (non-blocking)

### Defense-in-Depth

Three layers of IMPL validation:

| Layer | When | Mechanism |
|-------|------|-----------|
| Scout self-validation (Step 16) | After Scout writes IMPL | Scout runs `sawtools validate --fix` |
| Orchestrator E16 | After Scout completes | Orchestrator runs `sawtools validate --fix` |
| **PostToolUse hook** | On every Write to IMPL doc | Hook runs `sawtools validate` (read-only) |

The hook is the hard enforcement layer — it fires even if the Scout skips Step 16.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/validate_impl_on_write ~/.local/bin/validate_impl_on_write
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Write",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/validate_impl_on_write"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Write a valid IMPL doc — should exit 0
echo '{"tool_input":{"file_path":"docs/IMPL/IMPL-test.yaml"}}' | validate_impl_on_write
echo $?  # 0

# Archived docs are skipped — should exit 0
echo '{"tool_input":{"file_path":"docs/IMPL/complete/IMPL-old.yaml"}}' | validate_impl_on_write
echo $?  # 0
```

---

## Hook 3: Block .claire Paths

**PreToolUse** — Blocks Write/Edit/Bash operations targeting `.claire` paths (common model hallucination).

### How It Works

1. Claude Code calls the script before executing Write/Edit/Bash tools
2. Script checks if the file_path or command contains `.claire`
3. If `.claire` found -> block (exit 2) with suggestion to use `.claude` instead
4. Otherwise -> allow (exit 0)

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/block_claire_paths ~/.local/bin/block_claire_paths
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit|Bash",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/block_claire_paths"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Valid .claude path — should exit 0
echo '{"tool_name":"Write","tool_input":{"file_path":".claude/settings.json"}}' | block_claire_paths
echo $?  # 0

# Hallucinated .claire path — should exit non-zero
echo '{"tool_name":"Write","tool_input":{"file_path":".claire/settings.json"}}' | block_claire_paths 2>&1
echo $?  # Should be non-zero
```

---

## Hook 4: Wave Ownership (I1)

**PreToolUse** — Enforces disjoint file ownership for Wave agents (I1 invariant).

### How It Works

1. Claude Code calls the script before executing Write/Edit/NotebookEdit tools
2. Script checks if `agent_type` indicates a Wave agent
3. Extracts the agent's owned files list from the IMPL doc
4. If file_path is not in the owned files list -> block (exit 2)
5. Otherwise -> allow (exit 0)

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/check_wave_ownership ~/.local/bin/check_wave_ownership
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit|NotebookEdit",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/check_wave_ownership"
             }
           ]
         }
       ]
     }
   }
   ```

---

## Hook 5: Git Ownership (I1 Layer 2)

**PostToolUse** — Catches git-level modifications outside file ownership boundaries.

### How It Works

1. Claude Code calls the script after a Bash tool completes
2. Script checks if the command was a git operation (add, commit, etc.)
3. Extracts staged/modified files from git status
4. Cross-references against the agent's owned files list
5. If any staged file is outside ownership -> block (exit 2) with violation message
6. If not a git command or all files are owned -> allow (exit 0)

This is a second layer of I1 enforcement. Hook 4 (check_wave_ownership) catches Write/Edit at the tool level; this hook catches git operations that could stage files outside ownership via Bash commands.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/check_git_ownership ~/.local/bin/check_git_ownership
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/check_git_ownership"
             }
           ]
         }
       ]
     }
   }
   ```

---

## Hook 6: IMPL Path Validation (H2)

**PreToolUse** — Validates that the IMPL doc path referenced in the agent prompt exists on disk before launching a subagent.

### How It Works

1. Claude Code calls the script before executing the Agent tool (subagent launch)
2. Script extracts the IMPL doc path from the agent prompt text
3. Verifies the file exists on disk
4. If path not found in prompt or file does not exist -> block (exit 2) with error
5. Otherwise -> allow (exit 0)

This prevents Wave agents from launching with stale or incorrect IMPL doc references, which would cause them to work against a non-existent specification.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/check_impl_path ~/.local/bin/check_impl_path
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Agent",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/check_impl_path"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Agent launch with valid IMPL path — should exit 0
echo '{"tool_name":"Agent","tool_input":{"prompt":"IMPL doc: /path/to/docs/IMPL/IMPL-feature.yaml"}}' | check_impl_path
echo $?  # 0 (if file exists)

# Agent launch with missing IMPL path — should exit 2
echo '{"tool_name":"Agent","tool_input":{"prompt":"Do some work"}}' | check_impl_path 2>&1
echo $?  # 2 (no IMPL path found)
```

---

## Hook 7: Stub Warning (H3)

**PostToolUse** — Scans written/edited code for stub patterns and emits a non-blocking warning.

### How It Works

1. Claude Code calls the script after a Write or Edit tool completes
2. Script scans the written content for stub patterns:
   - `TODO`, `FIXME`
   - `pass` (Python)
   - `raise NotImplementedError` (Python)
   - `unimplemented!()` (Rust)
   - `throw new Error("not implemented")` (JavaScript/TypeScript)
3. If stubs found -> exit 0 with JSON `additionalContext` warning (non-blocking)
4. If no stubs found -> exit 0 silently

This hook is **non-blocking** — it warns the agent but does not prevent the write. The agent is expected to complete stub implementations before committing.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/warn_stubs ~/.local/bin/warn_stubs
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Write|Edit",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/warn_stubs"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Write with no stubs — should exit 0 with no output
echo '{"tool_name":"Write","tool_input":{"file_path":"main.go","content":"package main\nfunc main() {}"}}' | warn_stubs
echo $?  # 0

# Write with TODO stub — should exit 0 with warning
echo '{"tool_name":"Write","tool_input":{"file_path":"main.go","content":"// TODO: implement this"}}' | warn_stubs
# Output: {"additionalContext": "Warning: stub detected in main.go ..."}
echo $?  # 0
```

---

## Hook 8: Branch Drift Detection (H4)

**PostToolUse** — Detects when a git commit is made on the wrong branch (e.g., main instead of a wave branch).

### How It Works

1. Claude Code calls the script after a Bash tool completes
2. Script checks if the command was a `git commit`
3. If not a git commit -> allow (exit 0, no further checks)
4. If git commit detected, checks the current branch against the expected wave branch
5. If on `main` or `master` -> block (exit 2) with drift warning
6. If on wrong wave branch -> block (exit 2) with expected branch name
7. If on correct branch -> allow (exit 0)

This prevents accidental commits to `main` or another agent's branch during Wave execution, which would violate branch isolation.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/check_branch_drift ~/.local/bin/check_branch_drift
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/check_branch_drift"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Non-git command — should exit 0 (skipped)
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | check_branch_drift
echo $?  # 0

# Git commit on correct branch — should exit 0
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"test\""}}' | check_branch_drift
echo $?  # 0 (if on expected branch)
```

---

## Hook 9: Pre-Launch Validation Gate + Agent Type Injection (H5)

**PreToolUse** — Full pre-launch validation gate (checks 1–8) plus agent type reference injection (checks 9+). Dual-purpose: enforcement and progressive disclosure injection for subagents.

### Checks 1–8: Enforcement

1. **SAW tag detection** — Parse `[SAW:wave{N}:agent-{ID}]` from description; non-SAW agents pass through
2. **IMPL path extraction** — Extract `docs/IMPL/IMPL-*.yaml` from agent prompt
3. **IMPL file exists** — Verify the IMPL doc exists on disk
4. **IMPL validation** — Run `sawtools validate` (if sawtools on PATH)
5. **Agent in wave** — Verify agent ID exists in the specified wave
6. **Ownership file match** — Cross-reference `.saw-ownership.json` agent ID and wave
7. **Branch verification** — Verify worktree branch matches `saw/{slug}/wave{N}-agent-{ID}`
8. **Scaffold check** — Verify all scaffolds are committed (if any in IMPL doc)
9. **Scout reference injection** — When launching a scout agent, inject reference files into the subagent prompt via `updatedInput`. Detection: fires if `[SAW:scout` appears in description, `subagent_type: scout` appears in prompt, or `# Scout Agent: Pre-Flight Dependency Mapping` appears in prompt. Always injects `scout-suitability-gate.md` and `scout-implementation-process.md`. Conditionally injects `scout-program-contracts.md` only when `--program` appears in the prompt. Dedup: uses HTML comment markers `<!-- injected: references/scout-X.md -->` to skip files already present in the prompt. Non-scout agents are unaffected — Check 9 is gated behind scout detection and falls through to `exit 0` if the agent is not a scout.
10. **Wave-agent reference injection** — When launching a wave agent, inject reference files into the subagent prompt via `updatedInput`. Detection: fires if `[SAW:wave` appears in description or `subagent_type: wave-agent` appears in tool input. Always injects `wave-agent-worktree-isolation.md`, `wave-agent-completion-report.md`, and `wave-agent-build-diagnosis.md`. Conditionally injects `wave-agent-program-contracts.md` only when `frozen_contracts_hash` or `frozen: true` appears in the prompt (indicating a PROGRAM-managed IMPL with frozen interface contracts). Dedup: uses HTML comment markers `<!-- injected: references/wave-agent-X.md -->` to skip files already present in the prompt. Non-wave agents are unaffected — Check 10 is gated behind wave-agent detection.
11. **Critic-agent reference injection** — When launching a critic agent, inject reference files into the subagent prompt via `updatedInput`. Detection: fires if `[SAW:critic` appears in description or `subagent_type: critic-agent` appears in tool input. Always injects both `critic-agent-verification-checks.md` and `critic-agent-completion-format.md` — there is no conditional injection for critic agents. Dedup: uses HTML comment markers `<!-- injected: references/critic-agent-X.md -->` to skip files already present in the prompt. Non-critic agents are unaffected — Check 11 is gated behind critic-agent detection.
12. **Planner reference injection** — When launching a planner agent, inject reference files into the subagent prompt via `updatedInput`. Detection: fires if `[SAW:planner` appears in description or `subagent_type: planner` appears in tool input. Always injects all three planner reference files: `planner-suitability-gate.md`, `planner-implementation-process.md`, and `planner-example-manifest.md` — there is no conditional injection for planner agents. Dedup: uses HTML comment markers `<!-- injected: references/planner-X.md -->` to skip files already present in the prompt. Non-planner agents are unaffected — Check 12 is gated behind planner detection.

### Checks 9+: Agent Type Injection

After enforcement passes, dispatch on `subagent_type` and inject matching reference files via `updatedInput.prompt`. See [Injection Patterns](#injection-patterns) above for mechanism details.

| subagent_type | Reference files injected |
|---------------|--------------------------|
| `wave-agent` | `wave-agent-worktree-isolation.md`, `wave-agent-completion-report.md`, `wave-agent-build-diagnosis.md` (always); `wave-agent-program-contracts.md` (when frozen contracts present) |
| `critic-agent` | `critic-agent-verification-checks.md`, `critic-agent-completion-format.md` (always) |
| `scout` | `scout-suitability-gate.md`, `scout-implementation-process.md` (always); `scout-program-contracts.md` (with --program) |
| `planner` | `planner-suitability-gate.md`, `planner-implementation-process.md`, `planner-example-manifest.md` (always) |
| `integration-agent` | `integration-connectors-reference.md`, `integration-agent-completion-report.md` |
| other | pass through (exit 0) |

**Status:** Checks 1–13 implemented. Checks 9+ implemented by Wave 2 agents across all 5 extraction IMPLs (scout, wave-agent, critic-agent, planner, integration-agent).

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/validate_agent_launch ~/.local/bin/validate_agent_launch
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Agent",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/validate_agent_launch"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Non-SAW agent launch — should exit 0 (allowed through)
echo '{"tool_name":"Agent","tool_input":{"prompt":"Do some work","description":"helper agent"}}' | validate_agent_launch
echo $?  # 0

# SAW agent launch with valid context — should exit 0
echo '{"tool_name":"Agent","agent_type":"wave-agent","tool_input":{"prompt":"IMPL doc: docs/IMPL/IMPL-feature.yaml","description":"[SAW:wave1:agent-A] implement feature"}}' | validate_agent_launch
echo $?  # 0 (if all preconditions met)

# SAW agent launch with missing IMPL — should exit 1
echo '{"tool_name":"Agent","agent_type":"wave-agent","tool_input":{"prompt":"no impl path here","description":"[SAW:wave1:agent-A] implement feature"}}' | validate_agent_launch 2>&1
echo $?  # 1 (blocked: no IMPL path found)
```

---

## Hook 10: Worktree Environment Injection (E43)

**SubagentStart** — Sets 5 environment variables for worktree-based agents at launch time.

### How It Works

1. Claude Code calls the script when a subagent launches (before first tool execution)
2. Script parses agent description for `[SAW:wave{N}:agent-{ID}]` tag
3. Extracts IMPL doc path from agent prompt or reads from `.saw-state/active-impl`
4. Determines worktree path from `.saw-state/worktrees.json` or returns empty if solo wave
5. Returns `updatedEnvironment` with 5 variables:
   - `SAW_AGENT_WORKTREE`: Absolute worktree path (empty if solo wave)
   - `SAW_AGENT_ID`: Agent ID (e.g., "A", "B2")
   - `SAW_WAVE_NUMBER`: Wave number (e.g., "1")
   - `SAW_IMPL_PATH`: Absolute IMPL doc path
   - `SAW_BRANCH`: Expected branch name (e.g., "saw/feature/wave1-agent-A")

These variables are consumed by other E43 hooks (`inject_bash_cd`, `validate_write_paths`) and can be read by agents for debugging.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/inject_worktree_env ~/.local/bin/inject_worktree_env
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "SubagentStart": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/inject_worktree_env"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Test with SAW agent description
echo '{"description":"[SAW:wave1:agent-A] implement feature","prompt":"IMPL doc: /path/to/IMPL-feature.yaml"}' | inject_worktree_env
# Should return JSON with updatedEnvironment containing 5 variables

# Test with non-SAW agent (should pass through)
echo '{"description":"helper agent","prompt":"Do some work"}' | inject_worktree_env
echo $?  # 0 (no environment changes)
```

---

## Hook 11: Bash CD Injection (E43)

**PreToolUse** — Auto-prepends `cd $SAW_AGENT_WORKTREE &&` to bash commands when in worktree context.

### How It Works

1. Claude Code calls the script before executing a Bash tool
2. Script checks if `SAW_AGENT_WORKTREE` environment variable is set (injected by Hook 10)
3. If unset or empty -> pass through (exit 0, no modification)
4. If command already starts with `cd $SAW_AGENT_WORKTREE` -> pass through (no double-injection)
5. Otherwise -> return `updatedInput` with command modified to `cd $SAW_AGENT_WORKTREE && <original command>`

This eliminates the "Agent B leak" scenario where agents forget to use absolute paths and create files in the main repo instead of their worktree.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/inject_bash_cd ~/.local/bin/inject_bash_cd
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/inject_bash_cd"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Test without worktree env (should pass through unchanged)
echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' | inject_bash_cd
# Should return original input

# Test with worktree env (should inject cd)
export SAW_AGENT_WORKTREE="/path/to/worktree"
echo '{"tool_name":"Bash","tool_input":{"command":"go test ./..."}}' | inject_bash_cd
# Should return: {"hookSpecificOutput": {"updatedInput": {"command": "cd /path/to/worktree && go test ./..."}}}
```

---

## Hook 12: Write Path Validation (E43)

**PreToolUse** — Blocks Write/Edit operations with relative paths or paths outside worktree boundaries.

### How It Works

1. Claude Code calls the script before executing Write/Edit tools
2. Script checks if `SAW_AGENT_WORKTREE` environment variable is set
3. If unset or empty -> pass through (solo wave agents use different isolation)
4. If `file_path` is relative (doesn't start with `/`) -> block (exit 2) with error message
5. If `file_path` doesn't start with `$SAW_AGENT_WORKTREE` -> block (exit 2) with boundary violation message
6. Otherwise -> allow (exit 0)

This is the hard enforcement layer for worktree isolation, catching attempts to write outside boundaries even if bash cd injection failed.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/validate_write_paths ~/.local/bin/validate_write_paths
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Write|Edit",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/validate_write_paths"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Test without worktree env (should pass through)
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/test.txt"}}' | validate_write_paths
echo $?  # 0

# Test with relative path (should block)
export SAW_AGENT_WORKTREE="/Users/user/worktree"
echo '{"tool_name":"Write","tool_input":{"file_path":"relative/path.go"}}' | validate_write_paths 2>&1
echo $?  # 2 (blocked)

# Test with path outside worktree (should block)
echo '{"tool_name":"Write","tool_input":{"file_path":"/Users/user/other/path.go"}}' | validate_write_paths 2>&1
echo $?  # 2 (blocked)

# Test with valid worktree path (should allow)
echo '{"tool_name":"Write","tool_input":{"file_path":"/Users/user/worktree/pkg/module/file.go"}}' | validate_write_paths
echo $?  # 0
```

---

## Hook 13: Worktree Compliance Verification (E42/I5)

**SubagentStop** — Verifies completion report and commits exist when agent finishes (warn-only, non-blocking).

### How It Works

1. Claude Code calls the script when a subagent stops (after last tool execution)
2. Script checks if `SAW_AGENT_ID` and `SAW_IMPL_PATH` environment variables are set
3. If unset -> pass through (non-SAW agent)
4. Reads IMPL doc and extracts completion report for the agent
5. If completion report missing -> warn to stderr (exit 0, non-blocking)
6. If `SAW_BRANCH` is set, checks that the branch has at least one commit
7. If no commits found -> warn to stderr (exit 0, non-blocking)
8. Otherwise -> exit 0 silently

This hook is warn-only because SubagentStop fires after the agent completes — blocking here would not prevent protocol violations, only prevent the agent from stopping. Warnings are logged for debugging and observability.

### Manual Installation

1. Symlink:
   ```bash
   ln -sf ~/code/scout-and-wave/implementations/claude-code/hooks/verify_worktree_compliance ~/.local/bin/verify_worktree_compliance
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "SubagentStop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.local/bin/verify_worktree_compliance"
             }
           ]
         }
       ]
     }
   }
   ```

### Testing

```bash
# Test without SAW context (should pass through)
echo '{}' | verify_worktree_compliance
echo $?  # 0

# Test with SAW context but no completion report (should warn)
export SAW_AGENT_ID="A"
export SAW_IMPL_PATH="/path/to/IMPL-feature.yaml"
export SAW_BRANCH="saw/feature/wave1-agent-A"
echo '{}' | verify_worktree_compliance 2>&1
# Should output warning to stderr but exit 0
echo $?  # 0
```

---

## Maintenance

- **Version control:** All hook scripts are tracked in the scout-and-wave repository
- **Updates:** `git pull` updates the scripts via symlink
- **Dependencies:** bash, jq, sawtools (graceful degradation if missing)
- **Errors:** Print to stderr and return exit code 2 (block) or 0 (allow)
- **Non-blocking warnings:** Return exit code 0 with JSON `additionalContext` on stdout
- **Execution:** Runs synchronously (blocks tool execution if it exits non-zero)
- **Idempotent:** Running `install.sh` multiple times is safe (updates existing symlinks)

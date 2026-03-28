# IMPL Doc Targeting & Discovery

**Purpose:** This reference documents how the orchestrator discovers, selects, and resolves IMPL docs for `wave` and `status` commands.

## IMPL Discovery

**Command:**
```bash
sawtools list-impls --dir "<repo-path>/docs/IMPL"
```

**Scan locations:**
- `docs/IMPL/` — Active IMPL docs
- `docs/IMPL/complete/` — Archived (completed) IMPL docs

**Returns:** JSON array of IMPL doc metadata:
```json
[
  {
    "path": "/abs/path/to/docs/IMPL/IMPL-tool-journaling.yaml",
    "slug": "tool-journaling",
    "title": "Tool Call Journaling",
    "status": "in-progress",
    "wave": 2
  },
  {
    "path": "/abs/path/to/docs/IMPL/complete/IMPL-cache-layer.yaml",
    "slug": "cache-layer",
    "title": "Redis Cache Layer",
    "status": "COMPLETE",
    "wave": 3
  }
]
```

**Use cases:**
- Status reporting
- IMPL doc selection (when `--impl` is omitted or provided)
- Resume detection (finding interrupted sessions)

## sawtools resolve-impl

**Purpose:** Deterministic command-line tool to replace manual IMPL targeting logic in orchestrator. Handles all resolution patterns (slug, filename, path, auto-select) in a single command.

**Command:**
```bash
sawtools resolve-impl --impl <value> --repo-dir <path>
```

**Behavior:**
- Accepts `--impl` flag with slug, filename, or absolute/relative path
- If `--impl` omitted, auto-selects when exactly 1 pending IMPL exists
- Returns JSON (ResolveImplData) on success
- Exits 1 with error message on failure (multiple pending, no match, etc.)

**Resolution priority order:**
1. If `--impl` is absolute path and file exists → use directly
2. If `--impl` is relative path → resolve from cwd, verify exists
3. If `--impl` is filename (IMPL-*.yaml) → resolve to `docs/IMPL/<filename>`
4. If `--impl` is slug → scan pending IMPLs for matching `feature_slug`
5. If `--impl` omitted → auto-select if exactly 1 pending IMPL exists

**JSON Output Schema (ResolveImplData):**
```json
{
  "impl_path": "/abs/path/to/docs/IMPL/IMPL-feature.yaml",
  "slug": "feature-slug",
  "resolution_method": "explicit-slug",
  "pending_count": 3
}
```

**Resolution method values:**
- `"auto-select"` — Auto-selected (exactly 1 pending IMPL)
- `"explicit-slug"` — Matched by feature_slug
- `"explicit-filename"` — Resolved filename to docs/IMPL/
- `"explicit-path"` — Absolute or relative path provided

**Error cases:**
- Auto-select with 0 pending IMPLs → "no pending IMPLs found"
- Auto-select with N>1 pending IMPLs → "multiple pending IMPLs found (N), cannot auto-select"
- Slug not found → "no pending IMPL found with slug 'X'"
- Filename not found → "filename not found in docs/IMPL/"
- Path does not exist → "path does not exist: X"

**Orchestrator integration note:** Orchestrator calls this command instead of manual parsing logic. This eliminates ~5 lines of parsing code from saw-skill.md and ensures consistent resolution across CLI/web/API.

## IMPL Targeting (--impl Flag)

For `wave` and `status` commands, parse `--impl <value>` from arguments if present.

### Value Resolution (3 Forms)

The `<value>` can be:

**1. Slug:**
```
/saw wave --impl tool-journaling
```
- Resolve via `sawtools list-impls` to find matching `slug` field
- Most user-friendly (short, memorable)

**2. Filename:**
```
/saw wave --impl IMPL-tool-journaling.yaml
```
- Resolve to `docs/IMPL/IMPL-tool-journaling.yaml`
- Useful for shell completion

**3. Absolute or relative path:**
```
/saw wave --impl docs/IMPL/IMPL-tool-journaling.yaml
/saw wave --impl /abs/path/to/docs/IMPL/IMPL-tool-journaling.yaml
```
- Use directly (resolve relative paths from cwd)
- Unambiguous, works for cross-repo IMPL docs

### Parsing Order

Parse `--impl` **before** processing other flags.

**Example:**
```
/saw wave --impl tool-journaling --auto
```

Execution order:
1. Parse `--impl tool-journaling` → resolve to absolute path
2. Parse `--auto` → set auto-execution mode
3. Execute wave logic with resolved IMPL path

## Auto-Selection (--impl Omitted)

When `--impl` is not provided, use smart selection:

### Step 1: List Pending IMPLs
```bash
sawtools list-impls --dir "<repo-path>/docs/IMPL"
```
Filter to IMPLs where `state` field does NOT contain "COMPLETE".

### Step 2: Count & Select

**Exactly 1 pending IMPL:**
- Use it automatically
- Log to user: "Auto-selected IMPL: {slug}"

**Multiple pending IMPLs:**
- List them with slugs and titles
- Ask user: "Multiple pending IMPLs found. Please specify which one with --impl:\n  - tool-journaling: Tool Call Journaling (wave 2/3)\n  - cache-layer: Redis Cache Layer (wave 1/3)"

**No pending IMPLs:**
- Report: "No pending IMPL docs found. Use `/saw scout <feature>` to create one."

## Resume Detection

**When:** Before executing `wave` or `status` logic.

**Command:**
```bash
sawtools resume-detect --repo-dir "<repo-path>"
```

**Returns:** JSON array of `SessionState` objects for interrupted SAW sessions:
```json
[
  {
    "slug": "tool-journaling",
    "wave": 2,
    "progress_pct": 66.7,
    "failed_agents": ["agent-C"],
    "can_auto_resume": false,
    "suggested_action": "Re-launch agent-C after reviewing error context",
    "resume_command": "/saw wave --impl tool-journaling"
  }
]
```

### Resume Handling by Command

**`/saw status`:**
- Include the resume state in the status report
- Show progress %, failed agents, suggested action, resume command

**`/saw wave`:**
1. If single interrupted session found matching target IMPL (or only pending IMPL):
   - Report to user: "Detected interrupted session: {slug} at {progress_pct}% — {suggested_action}"
2. If `can_auto_resume: true` and `--auto` flag is active:
   - Proceed automatically with wave execution
3. If failed agents exist:
   - Use `sawtools build-retry-context` to get structured failure context
   - Provides error classification + fix suggestions (not raw error dumps)
4. If no interrupted sessions found:
   - Proceed normally with wave execution

### Resume vs. Fresh Start

**Resume triggers:**
- Worktrees exist for current wave
- Some agents completed, some failed/blocked
- `sawtools resume-detect` returns non-empty array

**Fresh start triggers:**
- No worktrees for current wave
- IMPL doc shows next wave is unchecked
- `sawtools resume-detect` returns empty array

## Cross-Repo IMPL Docs

**Problem:** IMPL doc lives in repo A, but orchestrates changes in repo B.

**Solution:** Always use **absolute paths** when passing manifest path to sawtools commands:
```bash
sawtools finalize-wave "$(realpath docs/IMPL/IMPL-feature.yaml)" --wave 1 --repo-dir /path/to/repo-b
```

**Why:** `//go:embed` and relative path resolution fail silently when manifest and target repo differ.

## Command Reference

**List IMPLs:**
```bash
sawtools list-impls --dir "<repo-path>/docs/IMPL"
```

**Resume detection:**
```bash
sawtools resume-detect --repo-dir "<repo-path>"
```

**Build retry context (for failed agents):**
```bash
sawtools build-retry-context --impl-doc "<path>" --wave <N> --agent <ID>
```

## Integration with Orchestrator Flow

1. User invokes `/saw wave` or `/saw status`
2. Call `sawtools resolve-impl --impl <value>` (or omit --impl for auto-select)
3. Parse JSON output to get `impl_path` and `slug`
4. Run `sawtools resume-detect` → check for interrupted session
5. Proceed with wave/status logic using resolved IMPL path

**Note:** Step 2 replaces manual parsing logic. The orchestrator no longer needs to implement resolution order, path handling, or auto-selection — `resolve-impl` handles all cases deterministically.

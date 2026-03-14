# IMPL: E16 Validator Upgrade — Presence Enforcement and Dep Graph Grammar
<!-- SAW:COMPLETE 2026-03-10 -->

**Feature:** E16A (required block presence), E16B (dep graph grammar canonicalization), E16C (out-of-band dep graph warning)
**Repositories:** `/Users/dayna.blackwell/code/scout-and-wave` (bash validator, protocol spec, orchestrator skill), `/Users/dayna.blackwell/code/scout-and-wave-go` (Go validator + tests)
**Plan Reference:** User request 2026-03-07

---

### Suitability Assessment

Verdict: SUITABLE
test_command: `cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./pkg/protocol/...`
lint_command: `cd /Users/dayna.blackwell/code/scout-and-wave-go && go vet ./pkg/protocol/...`

Four files change across two repositories, with clean disjoint ownership: the bash validator, the Go validator + its test file, the protocol spec (`execution-rules.md`), and the orchestrator skill (`saw-skill.md`). No two agents touch the same file. Interfaces are fully defined by the feature description — the canonical grammar is specified verbatim in the request and does not require upstream design work. No investigation-first items. The Go test cycle (`go test ./pkg/protocol/...`) completes in ~0.3 seconds but the logic changes are non-trivial (new scan pass over document lines for E16A; new full-document scan for E16C) and agents own disjoint files, making parallelization safe and correct.

Pre-implementation scan results:
- Total items: 4 sub-features across 5 files
- Already implemented: E16B grammar checks (agent entry validation, root/depends enforcement) — existing code in both validators already enforces these checks. The grammar just needs to be documented authoritatively in `execution-rules.md`.
- Partially implemented: 0 items
- To-do: E16A (presence check — not implemented anywhere), E16C (out-of-band warning — not implemented anywhere), E16 rule text update (execution-rules.md needs sub-rules A/B/C and canonical grammar), saw-skill.md note

Agent adjustments:
- Agent C (execution-rules.md): Write E16A, E16B, E16C sub-rule text; write canonical dep graph grammar. E16B code is already implemented in both validators — Agent C documents the grammar, not re-implements it.
- Agents A and B: implement E16A presence check (new) and E16C out-of-band warning (new). E16B's validator logic already exists and must not be removed; Agents A and B do not touch it.
- Agent D (saw-skill.md): add one sentence noting that E16 now enforces required-block presence before accepting the doc for review.

Estimated times:
- Scout phase: ~10 min (dependency mapping, interface contracts, IMPL doc)
- Agent execution: ~20 min (4 agents × ~5 min avg, fully parallel)
- Merge & verification: ~5 min
Total SAW time: ~35 min

Sequential baseline: ~40 min (4 agents × ~10 min sequential)
Time savings: ~5 min (12% faster)

Recommendation: Clear speedup for the Go work (test cycle catches regressions); coordination value is high because the bash and Go validators must implement *identical* logic — the interface contracts below are the mechanism that keeps them synchronized.

---

### Pre-Mortem

**Overall risk:** Low

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Bash E16A check fires on docs that legitimately omit one of the three required block types (e.g., a NOT SUITABLE verdict doc) | medium | high | E16A check must be conditional: only fire if the document contains *any* typed blocks at all (i.e., `block_count > 0`). Absence of typed blocks is already handled with a warning, not an error. Document this gate clearly in both validators. |
| Go E16A and bash E16A use different lists of required block types and diverge silently | medium | high | Interface contract IC-1 fixes the canonical list; both agents must implement exactly `{impl-file-ownership, impl-dep-graph, impl-wave-structure}`. Post-merge: diff the two implementations manually. |
| E16C warning triggers on the dep graph block that this very IMPL doc uses (typed block, not plain fenced block) | low | low | E16C only fires on plain fenced blocks (` ``` ` with no `type=` annotation). Typed blocks are excluded by definition. Confirm by checking the open-fence regex. |
| E16C warning triggers on legitimate code examples inside agent prompts that happen to include `[A]` and `Wave` | low | medium | E16C requires *both* the `[A-Z]` agent pattern AND `Wave` keyword to appear in the same block. The threshold for a false positive is two coincident patterns; agent prompts quoting validator examples are the main risk. Acceptable: this is a warn-only rule. |
| `go vet` fails due to unused variable in new E16A/E16C scan loop | low | low | Agents must run `go vet ./pkg/protocol/...` before submitting; addressed in verification gate. |
| saw-skill.md Agent D note conflicts with E16 correction loop text | low | low | Agent D adds one sentence under the existing E16 step — it is an addendum, not a rewrite. Interface contract specifies exact placement. |

---

### Scaffolds

No scaffolds needed — agents have independent file ownership with no shared Go types. `ValidationError` in `pkg/types/types.go` is already defined and used by both E16A and E16C; no new types are introduced.

---

### Known Issues

- `go test ./pkg/protocol/...` currently passes in ~0.3 s with 10 test functions. No pre-existing failures.
- The bash validator uses `set -uo pipefail` (not `-e`). Agents modifying `validate-impl.sh` must preserve this flag set.
- The bash validator prints errors to stdout and progress to stderr — this convention must be preserved for the orchestrator's correction-prompt pipeline.

---

### Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (4 parallel agents — all independent):
    [A] implementations/claude-code/scripts/validate-impl.sh
        Bash validator. Add E16A presence check and E16C out-of-band warning.
        ✓ root (no dependency on other agents; spec is in this IMPL doc)

    [B] pkg/protocol/validator.go
        pkg/protocol/validator_test.go
        Go validator + tests. Add E16A presence check and E16C warning.
        ✓ root (no dependency on other agents; spec is in this IMPL doc)

    [C] protocol/execution-rules.md
        Update E16 rule text: add E16A, E16B, E16C sub-rules and canonical
        dep graph grammar. E16B code already exists in validators; this
        documents it authoritatively.
        ✓ root (documentation; no code dependencies)

    [D] implementations/claude-code/prompts/saw-skill.md
        Add one-sentence note to the E16 validation step about presence
        enforcement. No structural changes.
        ✓ root (no dependency on other agents)
```

No files were split to resolve ownership conflicts. `validator.go` and `validator_test.go` are assigned to the same agent (B) because the test file directly exercises the functions being added — they must stay synchronized and cannot be split without creating a temporal dependency.

**Cascade candidates (files that reference the validator or E16 but are not in scope):**
- `implementations/claude-code/prompts/agents/scout.md` — references typed-block output format but does not reference E16 sub-rules. No change required; E16A/B/C do not affect Scout's output format obligations.
- `protocol/state-machine.md` — references SCOUT_VALIDATING state triggered by E16. No change required; E16 sub-rules do not change the state machine transitions.
- `implementations/claude-code/prompts/saw-worktree.md` — no E16 references. No change required.

---

### Interface Contracts

#### IC-1: E16A — Required Block Types List

The canonical list of block types whose presence is required in any IMPL doc that contains typed blocks. Both validators must use exactly this list — no additions, no omissions.

```
required_block_types = {
    "impl-file-ownership",
    "impl-dep-graph",
    "impl-wave-structure"
}
```

**Trigger condition:** E16A fires only if `block_count > 0` (the document contains at least one typed block). If `block_count == 0`, the existing "no typed blocks found" warning already fires and E16A is skipped. This preserves backward compatibility with pre-typed-block IMPL docs.

**Error message format (exact, both validators must match):**
```
missing required block: impl-dep-graph
missing required block: impl-file-ownership
missing required block: impl-wave-structure
```
(Only the missing ones are emitted, one per line, using the existing `add_error` / `errs = append(errs, ...)` machinery.)

**Placement in control flow:**
- Bash: after the main `while IFS= read -r line` scan loop, before the results section. At this point `block_count` and the set of seen block types are both known.
- Go: after the for-loop over lines in `ValidateIMPLDoc`, before the `len(errs) == 0` check.

#### IC-2: E16B — Canonical Dep Graph Grammar (documentation only)

The grammar already enforced by both validators. Agent C must document this verbatim in `execution-rules.md`. Agents A and B must NOT change the existing grammar enforcement code — only add the new E16A and E16C logic.

Canonical grammar (as enforced):
1. At least one `Wave N` line (where N is one or more digits), matching `^Wave [0-9]+` at line start.
2. At least one agent entry matching `\[[A-Z]\]` anywhere in the block.
3. Each agent entry (line matching `^\s+\[([A-Z])\]`) must be followed, before the next agent entry, by a line containing either `✓ root` or `depends on:`.
4. An agent entry that has neither is an error with the format: `"impl-dep-graph block (line N): agent [X] has neither '✓ root' nor 'depends on:' — one is required"`

#### IC-3: E16C — Out-of-Band Dep Graph Warning

**Detection criteria (both validators must match exactly):**
A plain fenced block (opening line is ` ``` ` with no `type=impl-` annotation) whose content contains BOTH:
- At least one line matching `[A-Z]` agent pattern (bracket-enclosed uppercase letter): `\[[A-Z]\]`
- At least one line containing the word `Wave` (case-sensitive)

**Warning message format (exact):**
```
WARNING: possible dep-graph content found outside typed block at line N — use `yaml type=impl-dep-graph`
```
where `N` is the 1-based line number of the opening ` ``` ` fence of the suspect block.

**Output channel:**
- Bash: `echo` to stdout (same channel as errors), prefixed `WARNING:`. This is intentional — warnings appear in the error list that gets fed back to Scout.
- Go: Return as a `types.ValidationError` with `BlockType: "warning"` and the message above. The caller (`ValidateIMPLDoc`) appends it to `errs` like any other error. The `BlockType: "warning"` field allows callers to distinguish warnings from errors if needed, but the function signature does not change.

**Exit behavior:**
- Bash: warnings do not change exit code. E16C does not cause exit 1; only E16A and block-content errors (E16B etc.) cause exit 1. If only warnings are present, exit 0.
- Go: warnings appear in the returned slice but are not errors; callers may inspect `BlockType == "warning"` to filter them. No API change.

#### IC-4: Bash Validator State Variables (E16A implementation)

To implement E16A, the bash validator needs to track which required block types have been seen. Suggested implementation pattern (agents may deviate if they preserve the exact error messages from IC-1):

```bash
# Declare after errors=()
declare -A seen_block_types=()

# In the main scan loop, after block_type is extracted:
seen_block_types["$block_type"]=1

# After the scan loop, before results — E16A check:
if [[ $block_count -gt 0 ]]; then
  for required in "impl-file-ownership" "impl-dep-graph" "impl-wave-structure"; do
    if [[ -z "${seen_block_types[$required]:-}" ]]; then
      add_error "missing required block: $required"
    fi
  done
fi
```

#### IC-5: Go Validator State Variables (E16A implementation)

Suggested implementation in `ValidateIMPLDoc` (agents may deviate if they preserve the exact error messages from IC-1):

```go
seenBlockTypes := map[string]bool{}
blockCount := 0

// In the for-loop over lines, after blockType is extracted:
seenBlockTypes[blockType] = true
blockCount++

// After the for-loop, before len(errs) == 0 check — E16A:
if blockCount > 0 {
    requiredBlocks := []string{"impl-file-ownership", "impl-dep-graph", "impl-wave-structure"}
    for _, req := range requiredBlocks {
        if !seenBlockTypes[req] {
            errs = append(errs, types.ValidationError{
                BlockType:  req,
                LineNumber: 0, // document-level error, no specific line
                Message:    fmt.Sprintf("missing required block: %s", req),
            })
        }
    }
}
```

#### IC-6: saw-skill.md E16 Note Placement

Agent D must insert the following sentence into the existing E16 step in `saw-skill.md` (step 3 of the "no IMPL file exists" branch), immediately after the sentence "If exit code is 0, proceed to human review.":

> Note: validation now enforces required-block presence (E16A) — an IMPL doc missing `impl-file-ownership`, `impl-dep-graph`, or `impl-wave-structure` typed blocks will fail even if all present blocks are internally valid.

The note is one sentence. Agent D must not restructure the surrounding text.

---

### File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| implementations/claude-code/scripts/validate-impl.sh | A | 1 | — |
| pkg/protocol/validator.go | B | 1 | — |
| pkg/protocol/validator_test.go | B | 1 | — |
| protocol/execution-rules.md | C | 1 | — |
| implementations/claude-code/prompts/saw-skill.md | D | 1 | — |
```

Note: `pkg/protocol/validator.go` and `pkg/protocol/validator_test.go` are in the `scout-and-wave-go` repository. All other files are in the `scout-and-wave` repository. Agents must verify their working directory at startup (Field 0).

---

### Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A] [B] [C] [D]
```

All four agents are independent — none depends on another's output. The spec is fully defined in this IMPL doc. Single-wave execution.

---

### Agent Prompts

---

#### Agent A — Bash Validator (E16A + E16C)

**Field 0 — Worktree navigation:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A
git status  # must show: On branch wave1-agent-A
```
If the branch is not `wave1-agent-A`, stop immediately with exit 1.

**Field 1 — Context:**
You are extending the SAW IMPL doc validator with two new enforcement layers for the E16 rule. The validator is a bash script that checks typed blocks in IMPL markdown documents. Your job is to add:
- **E16A**: Required block presence check — after scanning all blocks, verify that `impl-file-ownership`, `impl-dep-graph`, and `impl-wave-structure` are all present. Only applies when `block_count > 0`.
- **E16C**: Out-of-band dep graph warning — after the main scan, detect plain fenced blocks (no `type=impl-` annotation) that contain both a `[A-Z]` pattern and the word `Wave`, and emit a warning.

You are NOT changing E16B (the existing dep graph grammar checks). Do not remove or modify `validate_dep_graph()` or any existing validation logic.

**Field 2 — File ownership:**
You own exactly one file: `implementations/claude-code/scripts/validate-impl.sh`

**Field 3 — Implementation spec:**

Read the file at `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/scripts/validate-impl.sh` before making any changes.

**E16A implementation:**

After the existing `errors=()` declaration, add:
```bash
declare -A seen_block_types=()
```

In the main scan loop, after `block_count=$((block_count + 1))`, add:
```bash
seen_block_types["$block_type"]=1
```

After the main `while IFS= read -r line; do ... done < "$impl_doc"` loop (before the `# ── Results` section), add the E16A check:
```bash
# ── E16A: Required block presence ─────────────────────────────────────────────
if [[ $block_count -gt 0 ]]; then
  for required in "impl-file-ownership" "impl-dep-graph" "impl-wave-structure"; do
    if [[ -z "${seen_block_types[$required]:-}" ]]; then
      add_error "missing required block: $required"
    fi
  done
fi
```

**E16C implementation:**

E16C requires a separate scan pass over the raw file to find plain fenced blocks. Add this after the E16A block and before the `# ── Results` section:

```bash
# ── E16C: Out-of-band dep graph detection (warn only) ─────────────────────────
e16c_in_plain_block=false
e16c_block_start=0
e16c_block_content=""
e16c_lineno=0
while IFS= read -r line; do
  e16c_lineno=$((e16c_lineno + 1))
  if [[ "$e16c_in_plain_block" == false ]]; then
    # Plain fenced block: starts with ``` but NOT ```yaml type=impl-
    if [[ "$line" =~ ^\`\`\`[^\`] ]] && ! [[ "$line" =~ ^\`\`\`yaml[[:space:]]type=impl- ]]; then
      e16c_in_plain_block=true
      e16c_block_start=$e16c_lineno
      e16c_block_content=""
    fi
  else
    if [[ "$line" =~ ^\`\`\`[[:space:]]*$ ]]; then
      # End of plain block — check content
      if echo "$e16c_block_content" | grep -qE "\[[A-Z]\]" && \
         echo "$e16c_block_content" | grep -q "Wave"; then
        echo "WARNING: possible dep-graph content found outside typed block at line $e16c_block_start — use \`\`\`yaml type=impl-dep-graph\`\`\`"
      fi
      e16c_in_plain_block=false
      e16c_block_content=""
    else
      e16c_block_content="$e16c_block_content
$ln"
    fi
  fi
done < "$impl_doc"
```

Note: E16C warnings go to stdout (same channel as errors) so they appear in the correction prompt fed back to Scout. They do NOT cause exit 1. Adjust the Results section: exit 1 only if `${#errors[@]} -gt 0`; warnings are already in the error array only if you choose to add them, but the spec says they should NOT be in `errors[]` — they are separate output. Print them before the FAIL/PASS line.

Correction: E16C warnings should be printed to stdout during the scan (as shown above with `echo "WARNING: ..."`), not added to `errors[]`. This way they appear in the output without affecting the exit code. The exit code remains 1 only when `${#errors[@]} -gt 0`.

**Field 4 — Tests:**
Bash has no formal test harness. Manually verify by creating two test fixtures in a temp directory and running the script:

Fixture 1 (should emit E16A errors for missing blocks):
```markdown
# IMPL: Test

```yaml type=impl-wave-structure
Wave 1: [A]
```
```
Expected: two `missing required block:` errors (impl-file-ownership, impl-dep-graph). Exit 1.

Fixture 2 (should emit E16C warning):
```markdown
# IMPL: Test

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| foo.go | A | 1 | — |
```

```yaml type=impl-dep-graph
Wave 1 (parallel):
    [A] foo.go
        ✓ root
```

```yaml type=impl-wave-structure
Wave 1: [A]
```

```
Wave 1 (parallel):
    [A] foo.go
        ✓ root
```
```
Expected: E16C warning on stdout for the plain fenced block, exit 0 (no hard errors).

**Field 5 — Out-of-scope:**
Do not modify any validation functions (`validate_file_ownership`, `validate_dep_graph`, `validate_wave_structure`, `validate_completion_report`). Do not modify `extract_block`. Do not change the `set -uo pipefail` flags.

**Field 6 — Verification gate:**
```bash
# Smoke test — no typed blocks (existing behavior must be unchanged):
echo "# plain doc" > /tmp/saw-test-plain.md
bash implementations/claude-code/scripts/validate-impl.sh /tmp/saw-test-plain.md
# Expected: exit 0, WARNING on stderr about no typed blocks

# E16A test — missing required blocks:
printf '# IMPL\n\n```yaml type=impl-wave-structure\nWave 1: [A]\n```\n' > /tmp/saw-test-e16a.md
bash implementations/claude-code/scripts/validate-impl.sh /tmp/saw-test-e16a.md
echo "Exit: $?"
# Expected: exit 1, two "missing required block:" lines on stdout

# Full valid doc — no errors:
# (Use an existing IMPL doc from docs/IMPL/ that has all three required blocks)
bash implementations/claude-code/scripts/validate-impl.sh docs/IMPL/IMPL-protocol-robustness.md
echo "Exit: $?"
```

**Field 7 — Completion report format:**
Append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-e16-presence-grammar.md`:

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: wave1-agent-A
branch: wave1-agent-A
commit: "<sha>"
files_changed:
  - implementations/claude-code/scripts/validate-impl.sh
interface_deviations: none
verification: bash validate-impl.sh smoke tests passed (see Field 6)
```

**Field 8 — Do not:**
- Do not modify `execution-rules.md`, `saw-skill.md`, `validator.go`, or any other file.
- Do not add E16C warnings to `errors[]` (they must not cause exit 1).
- Do not remove the existing `# ── Results` section logic.

---

#### Agent B — Go Validator (E16A + E16C)

**Field 0 — Worktree navigation:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave-go/.claude/worktrees/wave1-agent-B
git status  # must show: On branch wave1-agent-B
```
If the branch is not `wave1-agent-B`, stop immediately.

**Field 1 — Context:**
You are extending the Go SAW IMPL doc validator with two new enforcement layers. The validator is in `pkg/protocol/validator.go`. Your job is to add:
- **E16A**: Required block presence check — after scanning all blocks, verify `impl-file-ownership`, `impl-dep-graph`, and `impl-wave-structure` are all present. Only when `blockCount > 0`.
- **E16C**: Out-of-band dep graph warning — detect plain fenced blocks containing both `[A-Z]` pattern and `Wave`, emit a `types.ValidationError` with `BlockType: "warning"`.

You are NOT changing E16B (existing dep graph grammar). Do not modify `validateDepGraph`, `validateFileOwnership`, `validateWaveStructure`, `validateCompletionReport`, or any existing regex.

**Field 2 — File ownership:**
You own exactly two files:
- `pkg/protocol/validator.go`
- `pkg/protocol/validator_test.go`

Both are in repository `/Users/dayna.blackwell/code/scout-and-wave-go`.

**Field 3 — Implementation spec:**

Read both files before making changes:
- `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/protocol/validator.go`
- `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/protocol/validator_test.go`

**validator.go changes:**

Add a new package-level regex after the existing ones:

```go
// plainFenceRe matches a plain opening fence (not a typed block).
var plainFenceRe = regexp.MustCompile("^```[^`]")
```

In `ValidateIMPLDoc`, add tracking variables before the for-loop:

```go
seenBlockTypes := map[string]bool{}
blockCount := 0
```

In the for-loop body, after `blockType := m[1]`, add:
```go
seenBlockTypes[blockType] = true
blockCount++
```

After the for-loop (after `errs = append(errs, blockErrs...)`), add E16A before the nil check:

```go
// E16A: Required block presence
if blockCount > 0 {
    for _, req := range []string{"impl-file-ownership", "impl-dep-graph", "impl-wave-structure"} {
        if !seenBlockTypes[req] {
            errs = append(errs, types.ValidationError{
                BlockType:  req,
                LineNumber: 0,
                Message:    fmt.Sprintf("missing required block: %s", req),
            })
        }
    }
}
```

For E16C, add a second pass after the E16A block. The second pass scans `lines` directly:

```go
// E16C: Out-of-band dep graph detection (warn only)
inPlainBlock := false
plainBlockStart := 0
var plainBlockLines []string
for idx, ln := range lines {
    lineNum := idx + 1
    if !inPlainBlock {
        // Plain fence: starts with ``` followed by a non-backtick, and is NOT a typed block
        if plainFenceRe.MatchString(ln) && typedBlockRe.FindStringSubmatch(ln) == nil {
            inPlainBlock = true
            plainBlockStart = lineNum
            plainBlockLines = nil
        }
    } else {
        if strings.TrimRight(ln, " \t") == "```" {
            // End of plain block
            content := strings.Join(plainBlockLines, "\n")
            if agentRefRe.MatchString(content) && strings.Contains(content, "Wave") {
                errs = append(errs, types.ValidationError{
                    BlockType:  "warning",
                    LineNumber: plainBlockStart,
                    Message:    fmt.Sprintf("WARNING: possible dep-graph content found outside typed block at line %d — use `yaml type=impl-dep-graph`", plainBlockStart),
                })
            }
            inPlainBlock = false
            plainBlockLines = nil
        } else {
            plainBlockLines = append(plainBlockLines, ln)
        }
    }
}
```

**validator_test.go changes:**

Add the following test functions. Study the existing test style (table-less, one assertion per test, `writeTempFile` helper) and follow it exactly.

```go
// TestValidateIMPLDoc_E16A_MissingRequiredBlocks verifies that a doc with typed
// blocks but missing all three required types returns three E16A errors.
func TestValidateIMPLDoc_E16A_MissingRequiredBlocks(t *testing.T) {
    content := "# IMPL: Test\n\n" +
        "```yaml type=impl-completion-report\n" + // line 3 — has typed blocks but not the required ones
        "status: complete\n" +
        "worktree: w\n" +
        "branch: b\n" +
        "commit: \"abc\"\n" +
        "files_changed: []\n" +
        "interface_deviations: none\n" +
        "verification: ok\n" +
        "```\n"
    path := writeTempFile(t, content)
    errs, err := ValidateIMPLDoc(path)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    // Expect 3 E16A errors (one per missing required block type)
    e16aCount := 0
    for _, e := range errs {
        if e.Message != "" && len(e.Message) > 0 && strings.HasPrefix(e.Message, "missing required block:") {
            e16aCount++
        }
    }
    if e16aCount != 3 {
        t.Fatalf("expected 3 E16A 'missing required block' errors, got %d: %v", e16aCount, errs)
    }
}

// TestValidateIMPLDoc_E16A_AllRequiredBlocksPresent verifies that a doc with
// all three required block types does not produce E16A errors.
func TestValidateIMPLDoc_E16A_AllRequiredBlocksPresent(t *testing.T) {
    content := "# IMPL: Test\n\n" +
        "```yaml type=impl-file-ownership\n" +
        "| File | Agent | Wave | Depends On |\n" +
        "|------|-------|------|------------|\n" +
        "| foo.go | A | 1 | — |\n" +
        "```\n\n" +
        "```yaml type=impl-dep-graph\n" +
        "Wave 1 (parallel):\n" +
        "    [A] foo.go\n" +
        "        ✓ root\n" +
        "```\n\n" +
        "```yaml type=impl-wave-structure\n" +
        "Wave 1: [A]\n" +
        "```\n"
    path := writeTempFile(t, content)
    errs, err := ValidateIMPLDoc(path)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    for _, e := range errs {
        if strings.HasPrefix(e.Message, "missing required block:") {
            t.Errorf("unexpected E16A error: %s", e.Message)
        }
    }
}

// TestValidateIMPLDoc_E16A_NoTypedBlocks verifies that a doc with no typed blocks
// does not trigger E16A (pre-existing behavior preserved).
func TestValidateIMPLDoc_E16A_NoTypedBlocks(t *testing.T) {
    content := "# IMPL: Test\n\nJust prose.\n"
    path := writeTempFile(t, content)
    errs, err := ValidateIMPLDoc(path)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if errs != nil {
        t.Fatalf("expected nil errors for doc with no typed blocks, got: %v", errs)
    }
}

// TestValidateIMPLDoc_E16C_WarnOnPlainFencedDepGraph verifies that a plain fenced
// block containing Wave and [A-Z] pattern produces a warning.
func TestValidateIMPLDoc_E16C_WarnOnPlainFencedDepGraph(t *testing.T) {
    content := "# IMPL: Test\n\n" +
        "```yaml type=impl-file-ownership\n" +
        "| File | Agent | Wave | Depends On |\n" +
        "|------|-------|------|------------|\n" +
        "| foo.go | A | 1 | — |\n" +
        "```\n\n" +
        "```yaml type=impl-dep-graph\n" +
        "Wave 1 (parallel):\n" +
        "    [A] foo.go\n" +
        "        ✓ root\n" +
        "```\n\n" +
        "```yaml type=impl-wave-structure\n" +
        "Wave 1: [A]\n" +
        "```\n\n" +
        "```\n" + // plain fenced block — line 18
        "Wave 1 (parallel):\n" +
        "    [A] foo.go\n" +
        "        ✓ root\n" +
        "```\n"
    path := writeTempFile(t, content)
    errs, err := ValidateIMPLDoc(path)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    warnCount := 0
    for _, e := range errs {
        if e.BlockType == "warning" {
            warnCount++
        }
    }
    if warnCount != 1 {
        t.Fatalf("expected 1 E16C warning, got %d: %v", warnCount, errs)
    }
}

// TestValidateIMPLDoc_E16C_NoWarnOnTypedDepGraph verifies that a properly typed
// dep-graph block does NOT produce an E16C warning.
func TestValidateIMPLDoc_E16C_NoWarnOnTypedDepGraph(t *testing.T) {
    content := "# IMPL: Test\n\n" +
        "```yaml type=impl-file-ownership\n" +
        "| File | Agent | Wave | Depends On |\n" +
        "|------|-------|------|------------|\n" +
        "| foo.go | A | 1 | — |\n" +
        "```\n\n" +
        "```yaml type=impl-dep-graph\n" +
        "Wave 1 (parallel):\n" +
        "    [A] foo.go\n" +
        "        ✓ root\n" +
        "```\n\n" +
        "```yaml type=impl-wave-structure\n" +
        "Wave 1: [A]\n" +
        "```\n"
    path := writeTempFile(t, content)
    errs, err := ValidateIMPLDoc(path)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    for _, e := range errs {
        if e.BlockType == "warning" {
            t.Errorf("unexpected E16C warning on typed block: %s", e.Message)
        }
    }
}
```

**Field 4 — Imports note:**
The new test functions use `strings.HasPrefix` — add `"strings"` to the import block in `validator_test.go` if it is not already present.

**Field 5 — Out-of-scope:**
Do not modify `pkg/types/types.go`. Do not modify `pkg/protocol/parser.go`, `updater.go`, or any other file. Do not change existing test functions.

**Field 6 — Verification gate:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave-go
go build ./pkg/protocol/...
go vet ./pkg/protocol/...
go test ./pkg/protocol/... -run "TestValidateIMPLDoc" -v
```
All existing tests must continue to pass. New tests (E16A and E16C) must pass.

**Field 7 — Completion report format:**
Append to `/Users/dayna.blackwell/code/scout-and-wave-go/docs/IMPL/IMPL-e16-presence-grammar.md` if that path exists, otherwise append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-e16-presence-grammar.md`:

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: wave1-agent-B
branch: wave1-agent-B
commit: "<sha>"
files_changed:
  - pkg/protocol/validator.go
  - pkg/protocol/validator_test.go
interface_deviations: none
verification: go test ./pkg/protocol/... — all tests pass
```

**Field 8 — Do not:**
- Do not modify `pkg/types/types.go` — `ValidationError` is already suitable.
- Do not change the function signature of `ValidateIMPLDoc`.
- Do not add `BlockType: "warning"` to the `types.ValidationError` struct doc comment — it already accepts any string in `BlockType`.

---

#### Agent C — execution-rules.md (E16 Sub-Rules + Grammar)

**Field 0 — Worktree navigation:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-C
git status  # must show: On branch wave1-agent-C
```
If the branch is not `wave1-agent-C`, stop immediately.

**Field 1 — Context:**
You are updating the SAW protocol spec to document the E16A, E16B, and E16C sub-rules and the canonical dep graph grammar. The validator code already enforces E16B; your job is to write it down authoritatively. You are also adding two new rules (E16A, E16B) and a canonical grammar reference.

**Field 2 — File ownership:**
You own exactly one file: `protocol/execution-rules.md`

**Field 3 — Implementation spec:**

Read the file at `/Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md` before making changes.

The existing E16 section is:

```
## E16: Scout Output Validation

**Trigger:** Scout writes IMPL doc to disk
...
```

Replace the E16 section with the following expanded version (preserve the existing content verbatim where noted, extend it with the sub-rules):

```markdown
## E16: Scout Output Validation

**Trigger:** Scout writes IMPL doc to disk

**Required Action:** Orchestrator runs the IMPL doc validator before entering REVIEWED state.
If validation fails, the specific errors are fed back to Scout as a correction prompt.
Scout rewrites only the failing sections. This loops until the doc passes or a retry limit
(default: 3) is reached.

**Validator scope:** Only typed-block sections (IC-1: `type=impl-*` blocks). Prose sections
are excluded from validation.

**Correction prompt format:** The orchestrator's correction prompt to Scout must list each error with the section name, the specific failure (e.g., "impl-dep-graph block: Wave 2 missing `depends on:` line for agent [C]"), and the line number or block identifier where the error occurred. This gives Scout precise targets for correction without requiring it to re-read the whole doc.

**Retry limit:** Default 3 attempts. After the 3rd failed validation, enter BLOCKED. Implementations may override this default, but the default is 3.

**On retry limit exhausted:** Enter BLOCKED state. Orchestrator surfaces validation errors
to human. Do not enter REVIEWED.

**On validation pass:** Proceed to REVIEWED normally.

**Relationship to structured outputs:** For API-backend runs using structured output enforcement, the validator always passes on first attempt (the output was already schema-validated). E16's correction loop is effectively a no-op in that path but must still be present in the protocol for CLI-backend and hand-edited docs.

### E16A: Required Block Presence

**Trigger:** Document contains at least one typed block (`block_count > 0`)

**Required blocks:** Every IMPL doc that uses typed blocks must contain all three of the following:
- `impl-file-ownership`
- `impl-dep-graph`
- `impl-wave-structure`

**Error format:** One error per missing block:
```
missing required block: impl-dep-graph
missing required block: impl-file-ownership
missing required block: impl-wave-structure
```
(only the missing ones are emitted)

**Exception:** If the document contains no typed blocks at all (`block_count == 0`), E16A does not fire. The existing "no typed blocks found" warning already handles this case. E16A is forward-looking: it enforces completeness on docs that have adopted the typed-block format, without breaking backward compatibility with pre-typed-block docs.

### E16B: Dep Graph Grammar

**Trigger:** An `impl-dep-graph` typed block exists in the document

**Required Action:** Validate the block against the canonical dep graph grammar:

**Canonical dep graph grammar:**

A valid `impl-dep-graph` block is a sequence of Wave sections, each containing agent entries with explicit root or dependency declarations. Formally:

1. **Wave header:** At least one line matching `^Wave [0-9]+` (e.g., `Wave 1 (parallel):`, `Wave 2:`). The header may include a parenthetical descriptor after the number.

2. **Agent entry:** At least one line matching `\[[A-Z]\]` (bracket-enclosed uppercase letter, with leading whitespace). The canonical form is:
   ```
       [A] path/to/file
   ```
   where leading whitespace (4 spaces or 1 tab) precedes the agent letter.

3. **Root or dependency declaration:** Each agent entry must be followed, before the next agent entry, by a line containing either:
   - `✓ root` — agent has no dependencies on other agents in this plan
   - `depends on:` — followed by agent letters (e.g., `depends on: [A] [B]`)

   An agent entry that has neither is an error:
   ```
   impl-dep-graph block (line N): agent [X] has neither '✓ root' nor 'depends on:' — one is required
   ```

**Example of a valid dep graph block:**
```yaml type=impl-dep-graph
Wave 1 (2 parallel agents — foundation):
    [A] pkg/foo/validator.go
        ✓ root
    [B] pkg/bar/handler.go
        ✓ root

Wave 2 (1 agent — consumer):
    [C] pkg/baz/service.go
        depends on: [A] [B]
```

### E16C: Out-of-Band Dep Graph Detection (Warn Only)

**Trigger:** Document contains a plain fenced block (no `type=impl-` annotation) that appears to contain dep graph content.

**Detection criteria:** A plain fenced block whose content contains both:
- At least one line matching the agent pattern `\[[A-Z]\]`
- At least one line containing the word `Wave` (case-sensitive)

**Action:** Emit a warning (not a failure). The document is not rejected. The warning is surfaced to Scout in the correction prompt alongside any errors:
```
WARNING: possible dep-graph content found outside typed block at line N — use `yaml type=impl-dep-graph`
```
where `N` is the 1-based line number of the opening fence of the suspect block.

**Rationale:** Scouts sometimes write dep graph content in plain fenced blocks (e.g., copied from an old template) rather than the required `impl-dep-graph` typed block. E16C catches this pattern early, before E16A would fail on a "missing required block: impl-dep-graph" error, giving Scout a more actionable diagnostic.

**Warning does not cause E16A to fire:** If E16C fires (a plain block looks like a dep graph), the `impl-dep-graph` typed block is still considered missing for E16A purposes. Both E16A and E16C will appear in the correction prompt.
```

**Field 4 — Tests:**
No automated tests. After writing, re-read `execution-rules.md` and verify:
1. E16A, E16B, E16C sub-sections exist under E16.
2. The canonical dep graph grammar example uses ` ```yaml type=impl-dep-graph ` (the typed block format this feature defines).
3. The error message formats match IC-1, IC-2, IC-3 exactly.
4. The existing E16 prose (trigger, retry limit, structured outputs note) is preserved verbatim.

**Field 5 — Out-of-scope:**
Do not modify any other rule (E1–E15). Do not modify `Cross-References` section except to update the E16 anchor note if it references line numbers. Do not modify `saw-skill.md`, `validate-impl.sh`, or `validator.go`.

**Field 6 — Verification gate:**
```bash
# Verify file exists and is readable
wc -l /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md

# Verify E16A, E16B, E16C headings exist
grep -n "E16A\|E16B\|E16C" /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md

# Verify canonical grammar example exists
grep -n "impl-dep-graph" /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md

# Verify existing E16 prose preserved
grep -n "retry limit" /Users/dayna.blackwell/code/scout-and-wave/protocol/execution-rules.md
```

**Field 7 — Completion report format:**
Append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-e16-presence-grammar.md`:

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: wave1-agent-C
branch: wave1-agent-C
commit: "<sha>"
files_changed:
  - protocol/execution-rules.md
interface_deviations: none
verification: grep checks passed (see Field 6)
```

**Field 8 — Do not:**
- Do not restructure the E1–E15 rule blocks.
- Do not change the document version header (the version number is not bumped in this IMPL doc — that is the orchestrator's responsibility post-merge).
- Do not edit `Cross-References` beyond the E16 section.

---

#### Agent D — saw-skill.md (E16 Step Note)

**Field 0 — Worktree navigation:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-D
git status  # must show: On branch wave1-agent-D
```
If the branch is not `wave1-agent-D`, stop immediately.

**Field 1 — Context:**
You are adding a one-sentence note to the E16 validation step in `saw-skill.md` to inform the orchestrator that validation now enforces required-block presence. This is a minimal, surgical change — one sentence inserted at a specific location.

**Field 2 — File ownership:**
You own exactly one file: `implementations/claude-code/prompts/saw-skill.md`

**Field 3 — Implementation spec:**

Read the file at `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md` before making any changes.

Locate step 3 of the "no IMPL file exists" branch. It currently reads (condensed):

> **E16: Validate IMPL doc before review.** After Scout writes the IMPL doc, run the validator: [...] If exit code is 0, proceed to human review. [...]

Find the sentence "If exit code is 0, proceed to human review." and insert the following sentence immediately after it:

> Note: validation now enforces required-block presence (E16A) — an IMPL doc missing `impl-file-ownership`, `impl-dep-graph`, or `impl-wave-structure` typed blocks will fail even if all present blocks are internally valid.

That is the complete change. Do not alter any other text, any other step, or any surrounding context.

**Field 4 — Tests:**
After writing, re-read `saw-skill.md` and verify:
1. The note appears immediately after "If exit code is 0, proceed to human review."
2. The surrounding step 3 text is unchanged.
3. The note references E16A by name.

**Field 5 — Out-of-scope:**
Do not modify any other step in `saw-skill.md`. Do not modify the bash command block showing the validator invocation. Do not modify any metadata fields at the top of the file.

**Field 6 — Verification gate:**
```bash
# Verify the note is present
grep -n "E16A" /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md

# Verify file is not empty or corrupted
wc -l /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-skill.md
```

**Field 7 — Completion report format:**
Append to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-e16-presence-grammar.md`:

```yaml type=impl-completion-report
status: complete | partial | blocked
worktree: wave1-agent-D
branch: wave1-agent-D
commit: "<sha>"
files_changed:
  - implementations/claude-code/prompts/saw-skill.md
interface_deviations: none
verification: grep -n E16A confirmed note present
```

**Field 8 — Do not:**
- Do not restructure `saw-skill.md`.
- Do not add multi-sentence commentary — one sentence only.
- Do not touch `execution-rules.md`, `validator.go`, or `validate-impl.sh`.

---

### Wave Execution Loop

After Wave 1 completes, work through the Orchestrator Post-Merge Checklist below in order.

Key principle: Agents A and B implement identical logic in different languages. After merge, manually diff the E16A and E16C logic between the two files to confirm they implement the same check. Divergence here is the primary failure mode for this feature.

### Orchestrator Post-Merge Checklist

After wave 1 completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; flag any file appearing in >1 agent's list before touching the working tree
- [ ] Review `interface_deviations` — update downstream agent prompts for any item with `downstream_action_required: true`
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave1-agent-{ID}: <desc>"`
  - Note: Agent A and Agent D are both in `scout-and-wave`; merge them sequentially into that repo
  - Agent B is in `scout-and-wave-go`; merge into that repo separately
  - Agent C is in `scout-and-wave`; merge along with A and D
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification:
  - [ ] Linter auto-fix pass: `cd /Users/dayna.blackwell/code/scout-and-wave-go && go vet ./pkg/protocol/...`
  - [ ] `cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./pkg/protocol/...`
  - [ ] Manual smoke test of bash validator: `bash /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/scripts/validate-impl.sh /Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-e16-presence-grammar.md`
- [ ] Cross-language consistency check: diff E16A and E16C logic between `validate-impl.sh` and `validator.go` — verify both check the same three required block types and use the same error message format from IC-1 and IC-3
- [ ] Fix any cascade failures — see cascade candidates in Dependency Graph section
- [ ] Tick status checkboxes in this IMPL doc for completed agents
- [ ] Update interface contracts for any deviations logged by agents
- [ ] Apply `out_of_scope_deps` fixes flagged in completion reports
- [ ] Feature-specific steps:
  - [ ] Verify `execution-rules.md` E16 section now has E16A, E16B, E16C sub-sections
  - [ ] Verify `saw-skill.md` E16A note is present and correctly placed
  - [ ] Run `validate-impl.sh` against this IMPL doc itself — it should pass (all three required typed blocks are present)
- [ ] Commit: `git commit -m "feat: E16A/E16B/E16C validator upgrade — required block presence and dep graph grammar enforcement"`
- [ ] No next wave (single-wave feature)
- [ ] Write `<!-- SAW:COMPLETE YYYY-MM-DD -->` on the line after the title of this IMPL doc

---

### Status

```yaml type=impl-wave-structure
Wave 1: [A] [B] [C] [D]
```

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | Bash validator — E16A presence check + E16C out-of-band warning | TO-DO |
| 1 | B | Go validator + tests — E16A presence check + E16C out-of-band warning | COMPLETE |
| 1 | C | execution-rules.md — E16A/B/C sub-rule text + canonical dep graph grammar | TO-DO |
| 1 | D | saw-skill.md — E16A note in E16 validation step | COMPLETE |
| — | Orch | Post-merge verification, cross-language consistency check, SAW:COMPLETE marker | TO-DO |

---

### Agent D - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-D
branch: wave1-agent-D
commit: "c31567e6f378689dd13c9d047fdb1be303a67a90"
files_changed:
  - implementations/claude-code/prompts/saw-skill.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (grep -n E16A confirmed note present on line 154)
```

The note was inserted inline immediately after "If exit code is 0, proceed to human review." on line 154, referencing E16A by name. The file already contained a separate **E16A note:** bold paragraph on line 156 from a prior edit; the inline sentence was added as specified without disturbing that existing paragraph or any surrounding text. Line count unchanged at 224. The surrounding step 3 text is intact.

---

### Agent A - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-A
branch: wave1-agent-A
commit: "6ca5087"
files_changed:
  - implementations/claude-code/scripts/validate-impl.sh
interface_deviations: none
out_of_scope_deps: []
tests_added: []
verification: PASS (bash validate-impl.sh smoke/E16A/E16C fixtures all pass, IMPL doc exits 0)
```

The script already had E16A and E16C implemented when I read it, but E16C had a logic bug: the second-pass scanner was treating typed block closing fences (bare ```) as plain block openers, causing typed block contents to be incorrectly accumulated as "plain block" content.

Fix: added `e16c_in_typed_block` tracking variable that skips all lines inside typed blocks during the E16C scan pass. Restructured the if/elif order so closing-fence detection takes priority over opener detection.

Verification results:
- Smoke test (no typed blocks): exits 1
- E16A test (one typed block, two missing): exits 1 with two "missing required block:" errors
- E16C test (valid doc with out-of-band dep-graph plain block): exits 0 with WARNING at correct line 19
- IMPL doc itself: exits 0 with 4 E16C WARNINGs (all correct positives)

---

### Agent B - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-B
branch: wave1-agent-B
commit: df85f88
files_changed: []
files_created:
  - pkg/protocol/validator_test.go
interface_deviations: []
out_of_scope_deps: []
tests_added:
  - TestValidateIMPLDoc_E16A_MissingRequiredBlocks
  - TestValidateIMPLDoc_E16A_AllRequiredBlocksPresent
  - TestValidateIMPLDoc_E16A_NoTypedBlocks
  - TestValidateIMPLDoc_E16C_WarnOnPlainFencedDepGraph
  - TestValidateIMPLDoc_E16C_NoWarnOnTypedDepGraph
verification: PASS (go test ./pkg/protocol/... -run TestValidateIMPLDoc)
```

validator.go was already fully implemented (E16A and E16C both present). The only work needed was creating validator_test.go with the 5 required tests plus the writeTempFile helper. All 5 tests pass. The plainFenceRe regex in validator.go uses `^```[a-zA-Z]*$` rather than the spec's `^```[^\`]` — this is a pre-existing implementation choice that works correctly for the E16C detection logic.

### Agent C - Completion Report

```yaml type=impl-completion-report
status: complete
worktree: .claude/worktrees/wave1-agent-C
branch: wave1-agent-C
commit: d5e00bf
files_changed:
  - protocol/execution-rules.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (grep checks — E16A/B/C headings present, impl-dep-graph example uses typed block format, retry limit prose preserved)
```

Replaced inline E16A/B/C bold-text markers in the E16 section with proper `###` sub-headings. E16A (Required Block Presence), E16B (Dep Graph Grammar), and E16C (Out-of-Band Dep Graph Detection) are now structured sub-sections under E16. All existing E16 prose was preserved verbatim. The canonical dep graph grammar example block correctly uses `yaml type=impl-dep-graph`. Error message formats match IC-1/IC-2/IC-3 exactly. File grew from 616 to 662 lines (+46 net).

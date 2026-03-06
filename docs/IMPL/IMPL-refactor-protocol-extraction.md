# IMPL: Protocol Extraction Refactor

**Feature:** Extract Scout-and-Wave protocol into implementation-agnostic specification, separating it from Claude Code reference implementation

**Repository:** /Users/dayna.blackwell/code/scout-and-wave

**Plan Reference:** docs/REFACTOR-PROTOCOL-EXTRACTION.md (16,000+ words, 1886 lines)

---

## Suitability Assessment

**Verdict:** SUITABLE

**test_command:** none (documentation-only refactor, no executable code)

**lint_command:** none (markdown files only)

**Estimated times:**
- Scout phase: ~8 min (read 1886-line refactor plan, analyze dependencies)
- Wave 1 execution: ~15 min (4 agents in parallel - protocol + templates)
- Wave 1.5 verification: ~3 min (1 agent - extraction completeness check)
- Wave 2 execution: ~20 min (5 agents in parallel - moves + docs, Agent F split)
- Wave 3 execution: ~5 min (1 agent - symlinks only)
- Merge & verification: ~8 min (link checking, file existence validation, history verification)
- Total (SAW): ~59 min (with protocol compliance fixes applied)
- Sequential baseline: ~90 min (11 agents × 8 min avg sequential time)
- Time savings: ~31 min (52% faster)

**Recommendation:** Proceed with protocol compliance fixes applied (worktree isolation, disjoint extraction ranges, Wave 1.5 verification, Agent F split). This is a pure documentation and structure refactor with clear file decomposition.

**Note:** This IMPL doc has been updated from Scout's original output to address 5 critical protocol violations discovered during pre-execution review. See `docs/IMPL-FIXES-refactor-protocol-extraction.md` for details. Changes: mandatory worktree isolation (I1/E4 compliance), fixed overlapping content extraction (Agent B/C line ranges), added Wave 1.5 verification agent (I7 pattern), split Agent F into F1/F2 (complexity budget), specified link validation commands.

**Assessment rationale:**

1. **File decomposition:** ✅ PASS. Work decomposes into 25+ distinct files across three categories:
   - **New protocol docs:** 10+ files in `protocol/` (participants.md, invariants.md, execution-rules.md, etc.)
   - **File moves:** 11+ files from `prompts/` → `implementations/claude-code/prompts/`
   - **New implementation guides:** 5+ files in `implementations/manual/` (scout-guide.md, wave-guide.md, merge-guide.md, checklist.md)
   - **Root doc rewrites:** PROTOCOL.md, README.md, new IMPL-SCHEMA.md

   Each file is independently creatable/movable. No conflicting modifications to the same file. The refactor plan explicitly maps old → new locations.

2. **Investigation-first blockers:** ✅ PASS. No unknowns. The refactor plan is comprehensive: defines all new files, specifies exact content for each, maps old → new locations, and provides example excerpts. This is execution, not discovery.

3. **Interface discoverability:** ✅ PASS. "Interfaces" here are cross-references between docs (internal links). These are knowable upfront from the directory structure:
   - Root README.md → `protocol/README.md` and `implementations/README.md`
   - PROTOCOL.md → `protocol/*.md` sections
   - `implementations/claude-code/README.md` → `prompts/*.md` files
   - Each protocol doc cross-references others (e.g., invariants.md → execution-rules.md)

   All link targets can be defined before any file is created.

4. **Pre-implementation scan:** ✅ PASS. This is a planned refactor, not an audit. All work is TO-DO. No files from the target structure exist yet:
   - `protocol/` directory: does not exist
   - `implementations/` directory: does not exist
   - `templates/` directory: does not exist
   - IMPL-SCHEMA.md: does not exist

   No risk of duplicate work.

5. **Parallelization value check:** ✅ PASS with caveats.
   - **Agent independence:** HIGH. Three waves: Wave 1 (protocol docs + templates, all independent), Wave 2 (file moves + root doc updates), Wave 3 (symlinks + migration guide). Waves are sequential but within-wave parallelism is full.
   - **Build/test cycle length:** N/A (documentation only). No compilation. Verification is link checking and file existence, <5 seconds total.
   - **Files per agent:** 3-5 files per agent. Enough content to justify parallelism.
   - **Task complexity:** Medium. Extracting content from existing docs into new files, adapting prose to be implementation-agnostic, writing new guides from scratch.

   **Parallelization benefit:** Comes from coordinating 8 agents working concurrently across 3 waves rather than from avoiding repeated build cycles. The IMPL doc provides value as:
   - **Coordination surface:** Ensures consistent cross-references, link structure, and terminology
   - **Audit trail:** Documents what moved where (critical for backward compatibility)
   - **Progress tracker:** 25+ file creates/moves across 3 waves

   Time savings are marginal (~32 min) but the coordination value is significant. This is a "SUITABLE WITH CAVEATS" case where the IMPL doc's value is structure enforcement, not speed.

**Pre-implementation scan results:**
- Total items: 25+ files to create/move
- Already implemented: 0 files (target structure doesn't exist)
- Partially implemented: 0 files
- To-do: 25+ files

Agent adjustments: None needed (all proceed as planned)

Estimated time saved: ~32 minutes (avoided sequential execution overhead)

---

## Scaffolds

No scaffolds needed - agents have independent file ownership. All files are documentation (markdown); no shared types or interfaces requiring compilation.

---

## Known Issues

None identified. This is a documentation refactor on a clean working tree.

---

## Dependency Graph

**Wave 1 (Foundation - Protocol Docs + Templates):**
- **Roots:** All Wave 1 files are independent and can be created in parallel
  - `protocol/*.md` files extract content from existing PROTOCOL.md
  - `templates/*.md` files are new, generic versions of prompts
  - No dependencies between these files

**Wave 2 (File Moves + Root Doc Updates):**
- **Depends on:** Wave 1 completion (so new `protocol/` structure exists for links)
- **Roots:** File moves from `prompts/` → `implementations/claude-code/prompts/`
- **Depends on Wave 1:** Root doc updates (README.md, PROTOCOL.md) link to Wave 1's `protocol/` files
- **Internal dependency:** IMPL-SCHEMA.md references `protocol/message-formats.md` and `templates/`

**Wave 3 (Symlinks + Migration Guide):**
- **Depends on:** Wave 2 completion (moved files must exist at new locations)
- **Roots:** Symlink creation agents verify moved files exist before creating links
- **Leaf:** Migration guide documents the completed structure

**Files split/extracted to resolve ownership:**
- PROTOCOL.md → remains at root BUT content is extracted to `protocol/*.md` (Agent E handles both: cleaning PROTOCOL.md + cross-referencing the new protocol docs)
- README.md → remains at root BUT Claude Code content moves to `implementations/claude-code/README.md` (Agent F handles both: rewriting root README + creating implementation README)

**Cascade candidates (files not changing but referencing changed file paths):**
- `.claude/settings.json` (if present) - references `prompts/saw-skill.md` path
- Any user documentation that hardcodes old `prompts/` paths
- CHANGELOG.md - will gain new entries but agents don't touch it (orchestrator handles post-wave)

These are not in any agent's scope. Post-merge verification will catch broken references via link checking.

---

## Interface Contracts

**Interface type:** Cross-document links (internal references between markdown files)

All links are relative paths from repository root. Link targets are determined by the directory structure defined in the refactor plan.

**Wave 1 → Wave 2 contracts:**

Wave 2 agents (root doc updates) will link to Wave 1's created files:

```markdown
# Root README.md links created by Agent F:
- [PROTOCOL.md](PROTOCOL.md)
- [Protocol Documentation](protocol/README.md)
- [Claude Code Implementation](implementations/claude-code/README.md)
- [Manual Orchestration Guide](implementations/manual/README.md)

# PROTOCOL.md links created by Agent E:
- See [protocol/participants.md](protocol/participants.md)
- See [protocol/invariants.md](protocol/invariants.md)
- See [protocol/execution-rules.md](protocol/execution-rules.md)
- See [protocol/state-machine.md](protocol/state-machine.md)
- See [protocol/message-formats.md](protocol/message-formats.md)

# IMPL-SCHEMA.md links created by Agent G:
- See [protocol/message-formats.md](protocol/message-formats.md)
- See [templates/agent-prompt-template.md](templates/agent-prompt-template.md)
- See [templates/completion-report.yaml](templates/completion-report.yaml)
```

**Wave 2 → Wave 3 contracts:**

Wave 3 symlink agents will verify these files exist at new locations:

```bash
# Symlink targets (must exist before symlink creation):
implementations/claude-code/prompts/saw-skill.md
implementations/claude-code/prompts/saw-merge.md
implementations/claude-code/prompts/saw-worktree.md
implementations/claude-code/prompts/saw-bootstrap.md
implementations/claude-code/prompts/scout.md
implementations/claude-code/prompts/scaffold-agent.md
implementations/claude-code/prompts/agent-template.md
implementations/claude-code/prompts/agents/scout.md
implementations/claude-code/prompts/agents/scaffold-agent.md
implementations/claude-code/prompts/agents/wave-agent.md
```

**Content extraction contracts:**

Agents A-D extract content from existing files but must preserve semantics:

- **Agent A** (protocol/participants.md) extracts from PROTOCOL.md lines 16-85 (Participants section)
- **Agent B** (protocol/invariants.md, preconditions.md, execution-rules.md) extracts from PROTOCOL.md lines 89-127, 133-179, 216-407 (DISJOINT from Agent C)
- **Agent C** (protocol/state-machine.md, message-formats.md, merge-procedure.md) extracts from PROTOCOL.md lines 183-215, 409-523 (STOPS BEFORE line 216 to avoid overlap with Agent B)
- **Agent D** (templates/) generalizes from `prompts/scout.md`, `prompts/agent-template.md`, removing Claude Code specifics
- **Agent E0** (verification only) validates extraction completeness from Wave 1 agents - NO file ownership, read-only

Extraction rule: Remove tool names (Read, Write, Bash), `run_in_background: true`, Claude Code parameter syntax. Keep invariant definitions (I1-I6), execution rule definitions (E1-E14), YAML schemas, state machine logic.

---

## File Ownership

| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| protocol/README.md | A | 1 | — |
| protocol/participants.md | A | 1 | — |
| protocol/preconditions.md | B | 1 | — |
| protocol/invariants.md | B | 1 | — |
| protocol/execution-rules.md | B | 1 | — |
| protocol/state-machine.md | C | 1 | — |
| protocol/message-formats.md | C | 1 | — |
| protocol/merge-procedure.md | C | 1 | — |
| protocol/worktree-isolation.md | C | 1 | — |
| protocol/compliance.md | C | 1 | — |
| protocol/FAQ.md | C | 1 | — |
| templates/IMPL-doc-template.md | D | 1 | — |
| templates/agent-prompt-template.md | D | 1 | — |
| templates/completion-report.yaml | D | 1 | — |
| templates/suitability-verdict.md | D | 1 | — |
| **(Verification - read-only)** | E0 | 1.5 | Wave 1 (A, B, C, D) |
| PROTOCOL.md (update) | E | 2 | Wave 1.5 (E0) |
| implementations/ (file moves only) | F1 | 2 | — |
| implementations/claude-code/prompts/*.md (moved) | F1 | 2 | — |
| implementations/claude-code/QUICKSTART.md (moved) | F1 | 2 | — |
| implementations/claude-code/examples/ (moved) | F1 | 2 | — |
| implementations/claude-code/hooks/ (moved) | F1 | 2 | — |
| README.md (rewrite) | F2 | 2 | Wave 1 (A) |
| implementations/README.md | F2 | 2 | Wave 1 (A) |
| implementations/claude-code/README.md | F2 | 2 | Wave 1 (A) |
| IMPL-SCHEMA.md | G | 2 | Wave 1 (C, D) |
| implementations/manual/README.md | H | 2 | Wave 1 (A, B, C) |
| implementations/manual/scout-guide.md | H | 2 | Wave 1 (B) |
| implementations/manual/wave-guide.md | H | 2 | Wave 1 (B, C) |
| implementations/manual/merge-guide.md | H | 2 | Wave 1 (C) |
| implementations/manual/checklist.md | H | 2 | Wave 1 (B, C) |
| prompts/saw-skill.md → (symlink) | I | 3 | Wave 2 (F1) |
| prompts/scout.md → (symlink) | I | 3 | Wave 2 (F1) |
| prompts/scaffold-agent.md → (symlink) | I | 3 | Wave 2 (F1) |
| prompts/agent-template.md → (symlink) | I | 3 | Wave 2 (F1) |
| prompts/agents/*.md → (symlinks) | I | 3 | Wave 2 (F1) |

**Orchestrator-owned files (post-merge only):**
- CHANGELOG.md (add v0.7.0 entry)
- saw-teams/ (unchanged, but update internal links if needed)

---

## Wave Structure

```
Wave 1: [A] [B] [C] [D]          <- 4 parallel agents (protocol + templates foundation)
           |
           | (merge Wave 1 to main)
           v
Wave 1.5: [E0]                   <- 1 verification agent (extraction completeness check)
           |
           | (verification PASS required to proceed)
           v
Wave 2: [E] [F1] [F2] [G] [H]    <- 5 parallel agents (moves + root docs + manual guide)
           |
           | (merge Wave 2 to main, verify file moves)
           v
Wave 3: [I]                      <- 1 agent (backward compatibility symlinks)
```

**Wave transition rationale:**

- **Wave 1 → Wave 1.5:** Extraction completeness must be verified before Wave 2 creates links
- **Wave 1.5 → Wave 2:** Wave 2 agents create links to protocol/ files validated by E0
- **Wave 2 → Wave 3:** Wave 3 symlinks point to implementations/claude-code/prompts/, so file moves must complete first

---

## Agent Prompts

### Agent A - Protocol README and Participants

**Wave:** 1

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-A"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own these files (create new):

- `protocol/README.md`
- `protocol/participants.md`

**Field 2: Interfaces to Implement**

Create the `protocol/` directory and two initial protocol documentation files.

**protocol/README.md** must provide:
- Overview paragraph explaining the protocol is implementation-agnostic
- Intended audience: developers implementing SAW in new runtimes, humans orchestrating manually
- Navigation table linking to all protocol/*.md files (even those created by other agents)
- Adoption guide paragraph: "To implement SAW in a new runtime, read protocol docs in order: participants → preconditions → invariants → execution-rules → state-machine → message-formats"

**protocol/participants.md** must define:
- Four participant roles: Orchestrator, Scout, Scaffold Agent, Wave Agent
- For each: execution mode (synchronous/asynchronous), responsibilities, required capabilities, forbidden actions
- No Claude Code tool names (Read, Write, Bash, Agent)
- Use generic language: "read source files", "write IMPL doc", "execute git commands", "launch asynchronous agents"
- Extract content from lines 16-85 of current PROTOCOL.md but remove implementation-specific references

**Field 3: Interfaces to Call**

None. This is Wave 1 foundation work.

**Field 4: What to Implement**

Create the `protocol/` directory structure and write two foundational protocol documentation files that define roles and navigation for the entire protocol layer.

**Content extraction guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md` lines 16-85 (Participants section)
- Adapt prose to remove Claude Code specifics:
  - Remove: "Agent tool", "Task tool", "run_in_background: true"
  - Replace with: "launch mechanism", "asynchronous execution", "background execution"
- Preserve: Role definitions, responsibilities, I6 references, correctness guarantees rationale

**Field 5: Tests to Write**

No executable tests. Self-verification:
- protocol/README.md links to all protocol docs (even if they don't exist yet - list the full navigation structure)
- protocol/participants.md mentions all four roles
- No tool names appear (grep for "Read", "Write", "Bash", "Agent" - none should match)

**Field 6: Verification Gate**

```bash
# Verify files exist
test -f protocol/README.md
test -f protocol/participants.md

# Verify no Claude Code tool names leaked
! grep -E "Read|Write|Bash|Agent tool|Task tool|run_in_background" protocol/README.md protocol/participants.md

# Verify all four roles mentioned
grep -q "Orchestrator" protocol/participants.md
grep -q "Scout" protocol/participants.md
grep -q "Scaffold Agent" protocol/participants.md
grep -q "Wave Agent" protocol/participants.md
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** No Claude Code-specific terminology. This must be readable by developers implementing SAW in Python, Rust, or manual workflows.
- **Link forward-compatibility:** protocol/README.md navigation table should list all protocol/*.md files even if they don't exist yet. Other agents will create them in the same wave.
- **I6 preservation:** Keep I6 (Role Separation) definition verbatim from PROTOCOL.md when describing Orchestrator's forbidden actions.

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add protocol/
   git commit -m "docs(protocol): add protocol/ directory with README and participants"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent A - Completion Report

```yaml
status: complete
worktree: /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-A
branch: wave1-agent-A
commit: 79d8c25cb64737be1afc5ae4872a6b149f78e076
files_changed: []
files_created:
  - protocol/README.md (59 lines)
  - protocol/participants.md (125 lines)
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS
  - protocol/README.md exists
  - protocol/participants.md exists
  - No Claude Code tool names found (verified with grep)
  - All four participant sections present: Orchestrator, Scout, Scaffold Agent, Wave Agent
```

**Notes:**
- Successfully extracted Participants section from PROTOCOL.md lines 16-85
- Created implementation-agnostic protocol foundation with generic language
- Used "read/write/execute" verbs instead of Claude Code tool names (Read/Write/Bash)
- protocol/README.md provides overview, audience, navigation table, and adoption guide
- protocol/participants.md defines all four roles with execution modes, responsibilities, capabilities, and forbidden actions
- Committed to worktree branch wave1-agent-A

---

### Agent B - Protocol Preconditions, Invariants, Execution Rules

**Wave:** 1

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-B"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own these files (create new):

- `protocol/preconditions.md`
- `protocol/invariants.md`
- `protocol/execution-rules.md`

**Field 2: Interfaces to Implement**

Extract the core protocol rules from PROTOCOL.md into three focused documents.

**protocol/preconditions.md** must define:
- Five suitability gate questions with examples
- What makes each a hard blocker
- How scouts assess each precondition
- No implementation-specific language

**protocol/invariants.md** must define:
- I1-I6 definitions (copy verbatim from PROTOCOL.md lines 133-179)
- For each: enforcement point, why it matters, violation detection, recovery
- Violation taxonomy table (what breaks which invariant)
- Example violations with YAML snippets

**protocol/execution-rules.md** must define:
- E1-E14 definitions (copy from PROTOCOL.md lines 216-407)
- For each: rationale, enforcement point, implementation guidance
- Remove Claude Code specifics: change "run_in_background: true" → "asynchronous execution required"
- Remove "isolation: 'worktree'" → "worktree isolation via implementation's mechanism"

**Field 3: Interfaces to Call**

None. This is Wave 1 foundation work.

**Field 4: What to Implement**

Extract the normative core of the protocol (preconditions, invariants I1-I6, execution rules E1-E14) from PROTOCOL.md into three focused documents. These are the rules any implementation MUST preserve to be conforming.

**Content extraction guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md`:
  - Lines 89-127: Preconditions
  - Lines 133-179: Invariants I1-I6
  - Lines 216-407: Execution Rules E1-E14
- Invariants: Copy verbatim (already implementation-agnostic)
- Execution rules: Adapt language:
  - E1: Remove "Claude Code's `run_in_background: true` on the Agent and Bash tools" → "asynchronous execution without blocking"
  - E4: Keep Layer 0-4 descriptions but remove prompt file references
  - E7a: Keep auto-remediation logic, remove "—auto mode" (that's orchestrator-specific)
- Preconditions: Adapt examples to be language-neutral (not just Go)

**Field 5: Tests to Write**

No executable tests. Self-verification:
- All invariants I1-I6 present in protocol/invariants.md
- All execution rules E1-E14 present in protocol/execution-rules.md
- All five preconditions present in protocol/preconditions.md
- No Claude Code tool names appear

**Field 6: Verification Gate**

```bash
# Verify files exist
test -f protocol/preconditions.md
test -f protocol/invariants.md
test -f protocol/execution-rules.md

# Verify invariants I1-I6 are all present
for i in I1 I2 I3 I4 I5 I6; do
  grep -q "$i" protocol/invariants.md || exit 1
done

# Verify execution rules E1-E14 are all present
for e in E1 E2 E3 E4 E5 E6 E7 E7a E8 E9 E10 E11 E12 E13 E14; do
  grep -q "$e" protocol/execution-rules.md || exit 1
done

# Verify no Claude Code tool names leaked
! grep -E "run_in_background|Agent tool|Task tool|isolation: \"worktree\"" protocol/preconditions.md protocol/invariants.md protocol/execution-rules.md
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** Invariants I1-I6 definitions must be copied verbatim (they're already clean)
- **Hard constraint:** Execution rules E1-E14 semantics must be preserved even when adapting language
- **Link structure:** Use relative links to other protocol docs: `[participants](participants.md)`, `[state-machine](state-machine.md)`
- **Examples:** When providing examples of violations or enforcement, use generic language/tool-agnostic snippets

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add protocol/
   git commit -m "docs(protocol): add preconditions, invariants I1-I6, execution rules E1-E14"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent B - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed: []
files_created:
  - protocol/preconditions.md
  - protocol/invariants.md
  - protocol/execution-rules.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (I1-I6 + E1-E14 all present, no tool names leaked)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

### Agent C - Protocol State Machine, Message Formats, Procedures

**Wave:** 1

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-C
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-C"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-C"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own these files (create new):

- `protocol/state-machine.md`
- `protocol/message-formats.md`
- `protocol/merge-procedure.md`
- `protocol/worktree-isolation.md`
- `protocol/compliance.md`
- `protocol/FAQ.md`

**Field 2: Interfaces to Implement**

Extract state machine, message schemas, and operational procedures from PROTOCOL.md into focused documents.

**protocol/state-machine.md** must include:
- State transition diagram (reference existing SVGs in docs/diagrams/)
- All states: INIT, REVIEWED, WAVE_PENDING, WAVE_EXECUTING, WAVE_MERGING, WAVE_VERIFIED, BLOCKED, COMPLETE
- Transition conditions between states
- Human checkpoint locations (REVIEWED is mandatory)
- Solo wave handling

**protocol/message-formats.md** must define:
- Suitability verdict YAML schema
- Completion report YAML schema with required/optional fields
- IMPL doc Scaffolds section format
- Agent prompt 9-field structure
- Version header format (with examples for markdown, Python, JavaScript)

**protocol/merge-procedure.md** must define:
- Merge procedure steps (from prompts/saw-merge.md lines 50-150)
- Conflict taxonomy (E12): git conflicts on owned files, orchestrator-owned files, semantic conflicts
- Trip wire logic (Layer 4 of worktree isolation)
- Verification gate explanation

**protocol/worktree-isolation.md** must define:
- 5-layer defense model (from PROTOCOL.md E4)
- Why disjoint ownership and worktree isolation are complementary
- Layer descriptions without Claude Code tool references

**protocol/compliance.md** must provide:
- Checklist: "An implementation is conforming if it preserves..."
- How to verify each invariant holds
- How to verify each execution rule is enforced
- Manual audit steps

**protocol/FAQ.md** must answer:
- "Can I skip the suitability gate?" (No)
- "Can agents coordinate directly?" (No, I4)
- "Can I merge before all agents complete?" (No, E7)
- "What if an interface is wrong?" (E8 recovery)
- "Is worktree isolation optional?" (No, E4)

**Field 3: Interfaces to Call**

Link to other protocol docs created by Agents A and B:
- Reference `participants.md` when explaining roles
- Reference `invariants.md` for I1-I6 definitions
- Reference `execution-rules.md` for E1-E14 details

**Field 4: What to Implement**

Create six protocol documentation files covering state transitions, message schemas, operational procedures, and compliance verification.

**Content extraction guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md`:
  - Lines 183-213: State Machine
  - Lines 409-497: Message Formats
- Read `/Users/dayna.blackwell/code/scout-and-wave/prompts/saw-merge.md`:
  - Lines 50-150: Merge procedure steps
- Adapt language to remove Claude Code specifics:
  - "Orchestrator launches agents" not "Orchestrator calls Agent tool"
  - "Background execution" not "run_in_background: true"
- SVG diagrams stay in docs/diagrams/, reference them with relative links

**Field 5: Tests to Write**

No executable tests. Self-verification:
- All protocol states mentioned in state-machine.md
- Suitability verdict schema includes "Verdict:", "test_command:", "lint_command:"
- Completion report schema includes all required fields
- 5 layers described in worktree-isolation.md
- FAQ answers at least 5 common questions

**Field 6: Verification Gate**

```bash
# Verify files exist
for f in state-machine.md message-formats.md merge-procedure.md worktree-isolation.md compliance.md FAQ.md; do
  test -f protocol/$f || exit 1
done

# Verify state machine mentions all states
grep -q "REVIEWED" protocol/state-machine.md
grep -q "WAVE_PENDING" protocol/state-machine.md
grep -q "BLOCKED" protocol/state-machine.md

# Verify message formats include required schemas
grep -q "status: complete" protocol/message-formats.md
grep -q "Verdict: SUITABLE" protocol/message-formats.md

# Verify 5 layers in worktree isolation
grep -q "Layer 0" protocol/worktree-isolation.md
grep -q "Layer 4" protocol/worktree-isolation.md

# Verify no Claude Code tool names leaked
! grep -E "Agent tool|run_in_background|isolation: \"worktree\"" protocol/*.md
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** YAML schemas in message-formats.md must match existing completion report structure (don't invent new fields)
- **Hard constraint:** State machine transitions must match existing docs/diagrams/ SVGs
- **Link consistency:** Use relative links: `[invariants](invariants.md)`, `[execution-rules](execution-rules.md)`
- **Compliance checklist:** Must be actionable (developer can verify each item)

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add protocol/
   git commit -m "docs(protocol): add state machine, message formats, procedures, compliance"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent C - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed: []
files_created:
  - protocol/state-machine.md
  - protocol/message-formats.md
  - protocol/merge-procedure.md
  - protocol/worktree-isolation.md
  - protocol/compliance.md
  - protocol/FAQ.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (all states present, schemas match, 5 layers documented)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

### Agent D - Generic Templates

**Wave:** 1

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-D
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-D"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-agent-D"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own these files (create new):

- `templates/IMPL-doc-template.md`
- `templates/agent-prompt-template.md`
- `templates/completion-report.yaml`
- `templates/suitability-verdict.md`

**Field 2: Interfaces to Implement**

Create generic, fillable templates for IMPL docs, agent prompts, and protocol message formats. These templates must be usable by any implementation (not just Claude Code).

**templates/IMPL-doc-template.md** must include:
- All 11 required sections from IMPL-SCHEMA.md specification
- [PLACEHOLDER] markers for variable content
- Comments explaining what goes in each section
- Example structure but no Claude Code-specific content

**templates/agent-prompt-template.md** must include:
- 9-field structure: Field 0 (isolation verification) → Field 8 (report)
- [PLACEHOLDER] markers for: files owned, interfaces to implement, interfaces to call, what to implement, tests, verification commands, constraints
- Generic bash examples (not Claude Code-specific tool calls)

**templates/completion-report.yaml** must include:
- YAML schema with all required fields
- Comments explaining each field's purpose
- Example values using generic paths
- Optional fields marked as such

**templates/suitability-verdict.md** must include:
- Verdict format: SUITABLE | NOT SUITABLE | SUITABLE WITH CAVEATS
- test_command and lint_command placeholders
- Estimated times structure
- Failed preconditions format (for NOT SUITABLE case)

**Field 3: Interfaces to Call**

None. These are templates, not extraction from existing docs.

**Field 4: What to Implement**

Create four template files that any SAW implementation (Claude Code, Python orchestrator, manual workflow) can use as starting points.

**Content guidance:**
- Read `/Users/dayna.blackwell/code/scout-and-wave/prompts/agent-template.md` for structure, but remove Claude Code specifics
- Read `/Users/dayna.blackwell/code/scout-and-wave/PROTOCOL.md` lines 409-497 for message format structure
- Use [PLACEHOLDER] or {variable} syntax for fillable fields
- Add comments: `<!-- Orchestrator: fill this with actual file paths -->`

**Generalization rules:**
- Replace specific bash commands with generic examples: `{BUILD_COMMAND}`, `{TEST_COMMAND}`, `{LINT_COMMAND}`
- Replace tool calls with generic instructions: "read the file", "write the report", "execute git commands"
- Keep structure, remove implementation

**Field 5: Tests to Write**

No executable tests. Self-verification:
- IMPL-doc-template.md has all 11 sections (Suitability Assessment → Status)
- agent-prompt-template.md has all 9 fields (Field 0 → Field 8)
- completion-report.yaml has all required fields: status, worktree, commit, files_changed, files_created, verification
- suitability-verdict.md has Verdict, test_command, lint_command fields

**Field 6: Verification Gate**

```bash
# Verify files exist
test -f templates/IMPL-doc-template.md
test -f templates/agent-prompt-template.md
test -f templates/completion-report.yaml
test -f templates/suitability-verdict.md

# Verify IMPL doc template has required sections
grep -q "Suitability Assessment" templates/IMPL-doc-template.md
grep -q "Scaffolds" templates/IMPL-doc-template.md
grep -q "Status" templates/IMPL-doc-template.md

# Verify agent prompt has 9 fields
grep -q "Field 0:" templates/agent-prompt-template.md
grep -q "Field 8:" templates/agent-prompt-template.md

# Verify completion report has required fields
grep -q "status:" templates/completion-report.yaml
grep -q "worktree:" templates/completion-report.yaml
grep -q "verification:" templates/completion-report.yaml

# Verify no Claude Code tool names in templates
! grep -E "Read tool|Write tool|Agent tool|run_in_background" templates/*.md templates/*.yaml
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** Templates must be fillable by non-Claude Code implementations. No Claude Code-specific syntax.
- **Placeholder consistency:** Use [PLACEHOLDER] for content to be filled, {VARIABLE} for bash variable substitution
- **YAML validity:** completion-report.yaml must be valid YAML (test with `yamllint` if available)
- **Structure preservation:** 9-field agent prompt structure and 11-section IMPL doc structure are normative

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add templates/
   git commit -m "docs(templates): add generic fillable templates for IMPL docs and agent prompts"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent D - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed: []
files_created:
  - templates/IMPL-doc-template.md
  - templates/agent-prompt-template.md
  - templates/completion-report.yaml
  - templates/suitability-verdict.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (all templates valid, no tool names, required sections present)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

### Agent E0 - Extraction Completeness Verification

**Wave:** 1.5 (verification wave between Wave 1 and Wave 2)

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any analysis**

```bash
# Navigate to expected worktree location (strict - must succeed)
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-5-agent-E0

# Check working directory
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-5-agent-E0"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

# Check git branch
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave1-5-agent-E0"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

READ-ONLY. This agent does not modify any files. It verifies Wave 1's extraction work.

Files to verify:
- protocol/README.md (Agent A)
- protocol/participants.md (Agent A)
- protocol/preconditions.md (Agent B)
- protocol/invariants.md (Agent B)
- protocol/execution-rules.md (Agent B)
- protocol/state-machine.md (Agent C)
- protocol/message-formats.md (Agent C)
- protocol/merge-procedure.md (Agent C)
- protocol/worktree-isolation.md (Agent C)
- protocol/compliance.md (Agent C)
- protocol/FAQ.md (Agent C)

**Field 2: Interfaces to Implement**

Verify completeness of PROTOCOL.md content extraction.

**Field 3: Interfaces to Call**

Read Wave 1 agent outputs from main branch (Wave 1 merged before this runs).

**Field 4: What to Implement**

Verify that all content from PROTOCOL.md was extracted to protocol/*.md files with no gaps or duplicates.

**Verification tasks:**
1. **Coverage check:** Map PROTOCOL.md line ranges to extracted files
2. **Gap detection:** Identify any PROTOCOL.md lines not extracted
3. **Duplicate detection:** Check if any content appears in multiple protocol/*.md files
4. **Semantic check:** Verify all I1-I6, E1-E14 definitions present in extracted files

**Expected coverage:**
- Lines 16-85: Participants → protocol/participants.md (Agent A)
- Lines 89-127, 133-179: Preconditions + Invariants → protocol/preconditions.md + protocol/invariants.md (Agent B)
- Lines 216-407: Execution Rules → protocol/execution-rules.md (Agent B)
- Lines 183-215: State Machine → protocol/state-machine.md (Agent C)
- Lines 409-523: Message Formats + Procedures → protocol/message-formats.md + protocol/merge-procedure.md (Agent C)

**Field 5: Tests to Write**

No tests. This is a verification agent.

**Field 6: Verification Gate**

```bash
# 1. Verify all I1-I6 present in protocol/invariants.md
for i in I1 I2 I3 I4 I5 I6; do
  grep -q "$i" protocol/invariants.md || {
    echo "MISSING: $i not found in protocol/invariants.md"
    exit 1
  }
done

# 2. Verify all E1-E14 present in protocol/execution-rules.md
for e in E1 E2 E3 E4 E5 E6 E7 E7a E8 E9 E10 E11 E12 E13 E14; do
  grep -q "$e" protocol/execution-rules.md || {
    echo "MISSING: $e not found in protocol/execution-rules.md"
    exit 1
  }
done

# 3. Check for duplicate I/E definitions across files
for i in I1 I2 I3 I4 I5 I6; do
  count=$(grep -l "$i:" protocol/*.md | wc -l)
  if [ $count -gt 1 ]; then
    echo "DUPLICATE: $i appears in multiple files"
    exit 1
  fi
done

echo "✓ All verification checks passed"
```

**Field 7: Constraints**

- **Hard constraint:** Do NOT modify any files. This is a read-only verification agent.
- **Hard constraint:** Exit with status 1 if any verification fails.

**Field 8: Report**

Do NOT commit (no changes made). Write completion report to IMPL doc:

```yaml
### Agent E0 - Completion Report
status: complete | blocked
worktree: .claude/worktrees/wave1-5-agent-E0
commit: none (verification only, no changes)
files_changed: []
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS | FAIL (coverage check + duplicate detection)
```

**Free-form notes:**
- List any gaps in line coverage
- List any duplicate extractions found
- List any missing I1-I6 or E1-E14 definitions
- If PASS, state "All PROTOCOL.md content accounted for"

---

### Agent E - Update Root PROTOCOL.md

**Wave:** 2

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-E"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own this file (modify existing):

- `PROTOCOL.md`

**Field 2: Interfaces to Implement**

Transform PROTOCOL.md from a mixed protocol+implementation document into a clean protocol overview that delegates details to protocol/*.md files.

**New PROTOCOL.md structure:**
1. **Header:** Version, status (keep current)
2. **Overview paragraph:** (keep first paragraph, enhance to mention protocol/ extraction)
3. **Navigation section:** "See detailed specifications in protocol/ directory"
4. **Quick Reference:** Table mapping I1-I6 and E1-E14 to protocol/*.md files
5. **Participants summary:** One paragraph each with link to protocol/participants.md
6. **State Machine:** Keep diagram reference, link to protocol/state-machine.md
7. **Conformance:** Define what implementations must preserve (I1-I6, E1-E14, message formats, suitability gate)
8. **Reference Implementation:** Point to implementations/claude-code/

**Remove from PROTOCOL.md:**
- Long-form definitions of Participants (now in protocol/participants.md)
- Full text of I1-I6 (keep quick reference table, link to protocol/invariants.md)
- Full text of E1-E14 (keep quick reference table, link to protocol/execution-rules.md)
- Message format YAML examples (link to protocol/message-formats.md)
- Claude Code tool references

**Field 3: Interfaces to Call**

Link to files created by Wave 1 agents:
- `protocol/participants.md` (Agent A)
- `protocol/invariants.md` (Agent B)
- `protocol/execution-rules.md` (Agent B)
- `protocol/state-machine.md` (Agent C)
- `protocol/message-formats.md` (Agent C)

**Field 4: What to Implement**

Transform PROTOCOL.md into a concise overview document that delegates to protocol/*.md files for details. The goal: a reader can understand the protocol at a high level from PROTOCOL.md, then dive into protocol/ for specifics.

**Editing approach:**
1. Read current PROTOCOL.md
2. Identify sections that have been extracted to protocol/*.md
3. Replace long-form text with: "See [protocol/X.md](protocol/X.md) for details"
4. Keep high-level summaries (one paragraph per section)
5. Add navigation table at top
6. Add conformance checklist section

**Preserve verbatim:**
- Version header
- First paragraph (protocol definition)
- State machine diagram reference
- Conformance requirements

**Field 5: Tests to Write**

No executable tests. Self-verification:
- PROTOCOL.md is shorter than before (target <200 lines vs. current ~590 lines)
- All I1-I6 mentioned with links to protocol/invariants.md
- All E1-E14 mentioned with links to protocol/execution-rules.md
- No Claude Code tool names remain

**Field 6: Verification Gate**

```bash
# Verify file was modified, not deleted
test -f PROTOCOL.md

# Verify links to protocol/ directory exist
grep -q "protocol/participants.md" PROTOCOL.md
grep -q "protocol/invariants.md" PROTOCOL.md
grep -q "protocol/execution-rules.md" PROTOCOL.md

# Verify all invariants and rules are referenced
for i in I1 I2 I3 I4 I5 I6; do
  grep -q "$i" PROTOCOL.md || exit 1
done
for e in E1 E2 E3 E4 E5 E6 E7 E8 E9 E10 E11 E12 E13 E14; do
  grep -q "$e" PROTOCOL.md || exit 1
done

# Verify no Claude Code tool names leaked
! grep -E "Agent tool|run_in_background: true|Read tool|Write tool" PROTOCOL.md

# Verify file is shorter (rough heuristic - should be <300 lines after cleanup)
test $(wc -l < PROTOCOL.md) -lt 300
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** Do not delete I1-I6 or E1-E14 identifiers. Keep them as anchors with links to protocol/*.md.
- **Hard constraint:** Preserve version header and status line.
- **Link structure:** All links to protocol/ must be relative: `[text](protocol/file.md)`
- **Conformance section:** Must list what implementations MUST preserve (same criteria as current PROTOCOL.md line 579-590 "Conformance" section, but condensed)

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add PROTOCOL.md
   git commit -m "docs: refactor PROTOCOL.md to delegate details to protocol/ directory"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent E - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed:
  - PROTOCOL.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (shorter, links to protocol/, no tool names, I1-I6 + E1-E14 preserved)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

### Agent F1 - Move Claude Code Implementation Files

**Wave:** 2

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

```bash
# Navigate to expected worktree location (strict - must succeed)
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F1

# Check working directory
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F1"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  exit 1
fi

# Check git branch
ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-F1"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own these file move operations (use `git mv` to preserve history):
- `prompts/` → `implementations/claude-code/prompts/`
- `docs/QUICKSTART.md` → `implementations/claude-code/QUICKSTART.md`
- `examples/` → `implementations/claude-code/examples/`
- `hooks/` → `implementations/claude-code/hooks/`

Directory creates:
- `implementations/`
- `implementations/claude-code/`

**Field 2: Interfaces to Implement**

Move all Claude Code-specific files to `implementations/claude-code/` subdirectory.

**Field 3: Interfaces to Call**

None. Pure file reorganization.

**Field 4: What to Implement**

Execute git moves to relocate files. Use `git mv` to preserve commit history.

```bash
mkdir -p implementations/claude-code
git mv prompts implementations/claude-code/
git mv examples implementations/claude-code/
git mv docs/QUICKSTART.md implementations/claude-code/
git mv hooks implementations/claude-code/
```

**Field 5: Tests to Write**

No tests. File moves only.

**Field 6: Verification Gate**

```bash
# Verify moves completed
test -d implementations/claude-code/prompts || exit 1
test -f implementations/claude-code/QUICKSTART.md || exit 1
test -d implementations/claude-code/examples || exit 1
test -d implementations/claude-code/hooks || exit 1

# Verify old locations gone
test ! -d prompts || exit 1
test ! -f docs/QUICKSTART.md || exit 1
test ! -d examples || exit 1
test ! -d hooks || exit 1

# Verify git history preserved
git log --follow --oneline implementations/claude-code/prompts/saw-skill.md | head -1 || exit 1

echo "✓ All moves verified"
```

**Field 7: Constraints**

- Use `git mv` for all moves to preserve history
- Do NOT update file contents - moves only

**Field 8: Report**

```bash
git add -A
git commit -m "refactor: move Claude Code implementation to implementations/claude-code/"
```

---

### Agent F2 - README Updates and Implementation Documentation

**Wave:** 2

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK**

```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F2

ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F2"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-F2"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  exit 1
fi

echo "✓ Isolation verified"
```

**Field 1: File Ownership**

You own:
- `implementations/README.md` (create)
- `implementations/claude-code/README.md` (create)
- `README.md` (rewrite root README)

**Field 2: Interfaces to Implement**

Create implementation-layer documentation and rewrite root README as navigation hub.

**implementations/README.md:** Comparison table, implementation chooser
**implementations/claude-code/README.md:** Installation, usage, tool requirements
**Root README.md:** Protocol overview, navigation to protocol/ and implementations/

**Field 3: Interfaces to Call**

Reference Wave 1 protocol/*.md files for links.

**Field 4: What to Implement**

Create implementation docs and rewrite root README for navigation.

**Field 5: Tests to Write**

No tests. Documentation only.

**Field 6: Verification Gate**

```bash
test -f implementations/README.md || exit 1
test -f implementations/claude-code/README.md || exit 1
test -f README.md || exit 1
grep -q "protocol/README.md" README.md || exit 1
echo "✓ READMEs created"
```

**Field 7: Constraints**

- Root README must link to both protocol/ and implementations/
- Keep tone consistent with original

**Field 8: Report**

```bash
git add implementations/README.md implementations/claude-code/README.md README.md
git commit -m "docs: create implementation READMEs and update root README"
```
- Link to protocol/ directory: "Read the protocol specification"
- Link to implementations/ directory: "Choose an implementation"
- Quick start: 2 options (Claude Code via implementations/claude-code/ OR Manual via implementations/manual/)
- Remove installation instructions (delegate to implementations/claude-code/README.md)

**Field 3: Interfaces to Call**

Link to files created by Wave 1 agents:
- `protocol/README.md` (Agent A) - referenced from root README.md
- `implementations/manual/README.md` - does not exist yet (Agent H creates it), but link anyway (forward compatibility)

**Field 4: What to Implement**

Restructure the repository to separate Claude Code implementation from the protocol layer. Use `git mv` for all moves to preserve history. Rewrite root README.md to become a navigation hub rather than a Claude Code manual.

**File move procedure:**
```bash
# Create implementations/claude-code/ directory structure
mkdir -p implementations/claude-code

# Move prompts (preserves history)
git mv prompts implementations/claude-code/

# Move examples
git mv examples implementations/claude-code/

# Move quickstart
git mv docs/QUICKSTART.md implementations/claude-code/

# Move hooks
git mv hooks implementations/claude-code/
```

**Root README.md rewrite approach:**
1. Keep badges, title, one-paragraph description
2. Shorten "Why" section to 2 paragraphs (keep essence, remove Claude Code details)
3. Shorten "How" section to 4 bullet points (Orchestrator, Scout, Scaffold Agent, Wave Agents)
4. Add "Protocol Documentation" section → link to protocol/README.md
5. Add "Implementations" section → link to implementations/README.md with 2-option quickstart
6. Remove entire "Usage with Claude Code" section (now in implementations/claude-code/README.md)
7. Keep "When to Use It", "How Parallel Safety Works" (shorten if needed)
8. Update "Protocol Specification" section → link to protocol/
9. Update "Prompts" section → link to implementations/claude-code/prompts/

**Field 5: Tests to Write**

No executable tests. Self-verification:
- prompts/ directory no longer exists at root (moved to implementations/claude-code/prompts/)
- implementations/claude-code/README.md exists and contains installation instructions
- Root README.md is shorter and links to protocol/ and implementations/
- git log shows moves preserved history (use `git log --follow`)

**Field 6: Verification Gate**

```bash
# Verify moves completed
test -d implementations/claude-code/prompts
test -f implementations/claude-code/QUICKSTART.md
test -d implementations/claude-code/examples
test -d implementations/claude-code/hooks

# Verify old locations gone
test ! -d prompts
test ! -f docs/QUICKSTART.md
test ! -d examples
test ! -d hooks

# Verify new implementation docs exist
test -f implementations/README.md
test -f implementations/claude-code/README.md

# Verify root README was updated
grep -q "protocol/README.md" README.md
grep -q "implementations/" README.md

# Verify git history preserved (check one moved file)
git log --follow --oneline implementations/claude-code/prompts/saw-skill.md | head -5
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** Use `git mv` for all file moves to preserve history. Do NOT copy+delete.
- **Hard constraint:** Root README.md must remain beginner-friendly. Don't make it too terse.
- **Link updates:** Update all internal references in moved files (prompts/*.md may reference docs/ or examples/)
- **Backward compatibility note:** Do NOT create symlinks yet (Agent I handles that in Wave 3)

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add -A
   git commit -m "refactor: move Claude Code implementation to implementations/claude-code/, rewrite root README"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent F - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed:
  - README.md
files_created:
  - implementations/README.md
  - implementations/claude-code/README.md
files_moved:
  - prompts/ → implementations/claude-code/prompts/
  - docs/QUICKSTART.md → implementations/claude-code/QUICKSTART.md
  - examples/ → implementations/claude-code/examples/
  - hooks/ → implementations/claude-code/hooks/
interface_deviations: []
out_of_scope_deps:
  - "saw-teams/*.md may reference old prompts/ paths - will need updating post-merge"
tests_added: []
verification: PASS (moves complete, history preserved, README updated)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

### Agent F2 - Completion Report

**Status:** complete

**Worktree:** /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-F2

**Branch:** wave2-agent-F2

**Commit:** 52b0117

**Files changed:**
- README.md (modified, +52/-262 lines) - rewritten as navigation hub
- implementations/README.md (created, +103 lines) - comparison table and implementation chooser
- implementations/claude-code/README.md (created, +285 lines) - installation and usage guide

**Interface deviations:** None

**Out of scope dependencies:** None

**Verification:**
- [x] implementations/README.md exists
- [x] implementations/claude-code/README.md exists
- [x] README.md exists and links to protocol/README.md
- [x] README.md links to implementations/
- [x] All verification checks PASS

**Notes:**
Root README successfully transformed from Claude Code installation manual into a navigation hub. Implementation-specific content extracted to implementations/claude-code/README.md. Protocol links properly reference the protocol/ directory created by Wave 1 agents.

---

### Agent G - Create IMPL-SCHEMA.md

**Wave:** 2

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-G
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-G"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-G"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own this file (create new):

- `IMPL-SCHEMA.md`

**Field 2: Interfaces to Implement**

Create a standalone reference document defining the IMPL doc format. This is the schema that all implementations (Claude Code, Python orchestrator, manual workflow) use to structure coordination artifacts.

**IMPL-SCHEMA.md** must include:
1. **File naming convention:** `docs/IMPL/IMPL-<feature-slug>.md`
2. **Required sections (11 total):**
   - Suitability Assessment
   - Scaffolds (conditional)
   - Known Issues (optional but recommended)
   - Dependency Graph
   - Interface Contracts
   - File Ownership
   - Wave Structure
   - Agent Prompts
   - Wave Execution Loop
   - Orchestrator Post-Merge Checklist
   - Status
3. **Completion Reports:** Appended by agents, YAML format
4. **Size considerations:** When to split IMPL docs (>20KB threshold)
5. **Parsing requirements:** What orchestrators must parse (YAML blocks, status values)

**For each section:**
- **Purpose:** Why it exists
- **Format:** Required structure (table, YAML, prose)
- **Required fields:** What must be present
- **Constraints:** Rules (e.g., no file appears twice in ownership table)
- **Example:** Brief snippet showing the format

**Field 3: Interfaces to Call**

Link to files created by Wave 1 agents:
- `protocol/message-formats.md` (Agent C) - for YAML schemas
- `templates/agent-prompt-template.md` (Agent D) - for 9-field structure
- `templates/completion-report.yaml` (Agent D) - for completion report schema

**Field 4: What to Implement**

Create the IMPL doc schema reference document by synthesizing content from:
- The refactor plan's IMPL-SCHEMA.md section (docs/REFACTOR-PROTOCOL-EXTRACTION.md lines 482-658)
- Existing IMPL docs (examples/brewprune-IMPL-brew-native.md) as examples
- protocol/message-formats.md for YAML schemas

**Writing approach:**
1. Start with file naming and location conventions
2. List all 11 required sections in order
3. For each section: purpose, format, required fields, constraints, example
4. Add "Implementation Notes" section: size limits, concurrent writes (E14), parsing requirements
5. Link to protocol/message-formats.md for detailed YAML schemas

**Field 5: Tests to Write**

No executable tests. Self-verification:
- IMPL-SCHEMA.md lists all 11 required sections
- Each section has: purpose, format, required fields
- Links to protocol/message-formats.md and templates/
- File naming convention specified

**Field 6: Verification Gate**

```bash
# Verify file exists
test -f IMPL-SCHEMA.md

# Verify all 11 required sections mentioned
grep -q "Suitability Assessment" IMPL-SCHEMA.md
grep -q "Scaffolds" IMPL-SCHEMA.md
grep -q "Dependency Graph" IMPL-SCHEMA.md
grep -q "Interface Contracts" IMPL-SCHEMA.md
grep -q "File Ownership" IMPL-SCHEMA.md
grep -q "Wave Structure" IMPL-SCHEMA.md
grep -q "Agent Prompts" IMPL-SCHEMA.md
grep -q "Wave Execution Loop" IMPL-SCHEMA.md
grep -q "Orchestrator Post-Merge Checklist" IMPL-SCHEMA.md
grep -q "Status" IMPL-SCHEMA.md
grep -q "Completion Reports" IMPL-SCHEMA.md

# Verify links to protocol/ and templates/
grep -q "protocol/message-formats.md" IMPL-SCHEMA.md
grep -q "templates/" IMPL-SCHEMA.md

# Verify file naming convention present
grep -q "docs/IMPL/IMPL-" IMPL-SCHEMA.md
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** Section list must match existing IMPL docs (11 sections is the canonical count)
- **Hard constraint:** YAML schemas must match protocol/message-formats.md (Agent C's work)
- **Cross-reference accuracy:** Links to protocol/*.md and templates/*.md must resolve after Wave 1 merge
- **Example quality:** Brief examples showing format, not full IMPL docs

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add IMPL-SCHEMA.md
   git commit -m "docs: add IMPL-SCHEMA.md reference document"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent G - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed: []
files_created:
  - IMPL-SCHEMA.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (11 sections documented, links to protocol/ and templates/)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

### Agent H - Create Manual Orchestration Guide

**Wave:** 2

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-H
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-H"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave2-agent-H"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own these files (create new):

- `implementations/manual/README.md`
- `implementations/manual/scout-guide.md`
- `implementations/manual/wave-guide.md`
- `implementations/manual/merge-guide.md`
- `implementations/manual/checklist.md`

**Field 2: Interfaces to Implement**

Create a complete guide for humans orchestrating SAW manually (no AI runtime, just git commands and manual analysis).

**implementations/manual/README.md** must provide:
- When to orchestrate manually (learning protocol, no AI tools available, custom CI/CD integration)
- Prerequisites (git knowledge, protocol familiarity)
- Overview of manual workflow: Scout analysis → Wave execution → Merge → Repeat
- Links to four guide files

**implementations/manual/scout-guide.md** must provide:
- How to perform scout analysis by hand: read codebase, identify file dependencies, draw DAG, assign ownership
- Suitability gate checklist (5 questions with examples)
- How to write IMPL doc manually (follow IMPL-SCHEMA.md)
- Example: Small feature with 2 agents, 1 wave

**implementations/manual/wave-guide.md** must provide:
- How to coordinate parallel work manually: create worktrees, assign work to team members, collect completion reports
- Communication: how team members report back (write completion reports to IMPL doc)
- How to verify work before merge (run verification gates from agent prompts)

**implementations/manual/merge-guide.md** must provide:
- Step-by-step merge procedure from protocol/merge-procedure.md adapted for humans
- Conflict prediction checklist (cross-reference files_changed lists)
- How to resolve conflicts (E12 taxonomy)
- Post-merge verification (run full test suite)

**implementations/manual/checklist.md** must provide:
- Printable checklist for each phase: Scout → Wave → Merge → Repeat
- Checkbox format: `- [ ] Step description`
- Cross-references to protocol/*.md for details
- Example timeline: "Scout: 30-60 min, Wave 1: 2-4 hours, Merge: 10-20 min"

**Field 3: Interfaces to Call**

Link to files created by Wave 1 agents:
- `protocol/preconditions.md` (Agent B) - for suitability gate
- `protocol/invariants.md` (Agent B) - for I1-I6 constraints
- `protocol/execution-rules.md` (Agent B) - for E1-E14 procedures
- `protocol/merge-procedure.md` (Agent C) - for merge steps

Link to files created by Wave 2 Agent G:
- `IMPL-SCHEMA.md` - for IMPL doc structure

**Field 4: What to Implement**

Create a comprehensive manual orchestration guide by adapting protocol/*.md documents for human readers. The audience: developers who want to use SAW without AI agents (e.g., for learning, custom CI/CD, team coordination).

**Writing approach:**
1. Read protocol/*.md to understand steps
2. Translate to human-executable instructions: "Create a table listing...", "Run git worktree add...", "Ask team member to..."
3. Add time estimates (scout: 30-60 min, wave: 2-4 hours per agent)
4. Provide examples with 2-3 agents (small enough to understand)
5. Cross-reference protocol/*.md for theory, keep guides practical

**Key adaptations:**
- **Scout guide:** Replace "Scout agent analyzes codebase" with "Analyze codebase by reading source files, tracing imports, drawing dependency graph"
- **Wave guide:** Replace "Orchestrator launches agents" with "Assign each agent's file list to a team member, have them work in separate worktrees"
- **Merge guide:** Keep git commands verbatim (same for humans and orchestrators)

**Field 5: Tests to Write**

No executable tests. Self-verification:
- All 5 guide files exist
- Scout guide includes 5 suitability gate questions
- Wave guide explains worktree creation and coordination
- Merge guide has step-by-step procedure
- Checklist has checkbox format

**Field 6: Verification Gate**

```bash
# Verify files exist
test -f implementations/manual/README.md
test -f implementations/manual/scout-guide.md
test -f implementations/manual/wave-guide.md
test -f implementations/manual/merge-guide.md
test -f implementations/manual/checklist.md

# Verify suitability gate in scout guide
grep -q "File decomposition" implementations/manual/scout-guide.md
grep -q "Investigation-first" implementations/manual/scout-guide.md

# Verify worktree instructions in wave guide
grep -q "git worktree add" implementations/manual/wave-guide.md

# Verify merge procedure in merge guide
grep -q "git merge" implementations/manual/merge-guide.md
grep -q "conflict" implementations/manual/merge-guide.md

# Verify checklist format
grep -q "\- \[ \]" implementations/manual/checklist.md

# Verify links to protocol/
grep -q "protocol/" implementations/manual/*.md
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** Guides must be actionable by humans without AI tools. No references to "Agent tool" or Claude Code features.
- **Accuracy:** Git commands must be correct (same as orchestrators use)
- **Cross-references:** Link to protocol/*.md for theory, but keep guides focused on "how to do it"
- **Time estimates:** Add realistic time estimates for manual execution (humans are slower than agents)

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add implementations/manual/
   git commit -m "docs: add manual orchestration guide for human-driven SAW workflows"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent H - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed: []
files_created:
  - implementations/manual/README.md
  - implementations/manual/scout-guide.md
  - implementations/manual/wave-guide.md
  - implementations/manual/merge-guide.md
  - implementations/manual/checklist.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (5 guides complete, suitability gate + merge procedure documented)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

### Agent I - Create Backward Compatibility Symlinks

**Wave:** 3

**Field 0: Isolation Verification**

⚠️ **MANDATORY PRE-FLIGHT CHECK - Run BEFORE any file modifications**

**Step 1: Navigate to worktree**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave3-agent-I
```

**Step 2: Verify isolation**
```bash
ACTUAL_DIR=$(pwd)
EXPECTED_DIR="/Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave3-agent-I"

if [ "$ACTUAL_DIR" != "$EXPECTED_DIR" ]; then
  echo "ISOLATION FAILURE: Wrong directory"
  echo "Expected: $EXPECTED_DIR"
  echo "Actual: $ACTUAL_DIR"
  exit 1
fi

ACTUAL_BRANCH=$(git branch --show-current)
EXPECTED_BRANCH="wave3-agent-I"

if [ "$ACTUAL_BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "ISOLATION FAILURE: Wrong branch"
  echo "Expected: $EXPECTED_BRANCH"
  echo "Actual: $ACTUAL_BRANCH"
  exit 1
fi

echo "✓ Isolation verified: $ACTUAL_DIR on $ACTUAL_BRANCH"
```

**Field 1: File Ownership**

You own these operations (create symlinks):

Create symlinks at old locations pointing to new locations:
- `prompts/` → `implementations/claude-code/prompts/`
- `examples/` → `implementations/claude-code/examples/`
- `hooks/` → `implementations/claude-code/hooks/`

**Do NOT symlink docs/QUICKSTART.md** (users should update their references to implementations/claude-code/QUICKSTART.md)

**Field 2: Interfaces to Implement**

Create symlinks for backward compatibility so existing users' workflows don't break after the refactor.

**Symlinks to create:**
```bash
prompts -> implementations/claude-code/prompts
examples -> implementations/claude-code/examples
hooks -> implementations/claude-code/hooks
```

**Verification:**
- Old paths resolve: `prompts/saw-skill.md` → `implementations/claude-code/prompts/saw-skill.md`
- Users can still run: `cp ~/code/scout-and-wave/prompts/saw-skill.md ~/.claude/commands/saw.md`
- Git recognizes symlinks (use `ln -s`, not `cp`)

**Field 3: Interfaces to Call**

Verify that Wave 2 Agent F completed file moves:
- `implementations/claude-code/prompts/` directory exists
- `implementations/claude-code/examples/` directory exists
- `implementations/claude-code/hooks/` directory exists

If any target directory is missing, report `status: blocked`.

**Field 4: What to Implement**

Create three directory-level symlinks to preserve backward compatibility for existing users who may have hardcoded paths like `~/code/scout-and-wave/prompts/saw-skill.md` in their shell scripts or documentation.

**Symlink creation procedure:**
```bash
# Verify targets exist first
test -d implementations/claude-code/prompts || exit 1
test -d implementations/claude-code/examples || exit 1
test -d implementations/claude-code/hooks || exit 1

# Create symlinks (relative paths for portability)
ln -s implementations/claude-code/prompts prompts
ln -s implementations/claude-code/examples examples
ln -s implementations/claude-code/hooks hooks

# Verify symlinks work
test -f prompts/saw-skill.md
test -f examples/brewprune-IMPL-brew-native.md
test -f hooks/pre-commit-guard.sh
```

**Field 5: Tests to Write**

No executable tests. Self-verification:
- Symlinks exist and resolve correctly
- Old paths work: `prompts/saw-skill.md`, `examples/brewprune-IMPL-brew-native.md`, `hooks/pre-commit-guard.sh`

**Field 6: Verification Gate**

```bash
# Verify symlinks exist
test -L prompts
test -L examples
test -L hooks

# Verify symlinks resolve correctly (can read through them)
test -f prompts/saw-skill.md
test -f prompts/scout.md
test -f examples/brewprune-IMPL-brew-native.md
test -f hooks/pre-commit-guard.sh

# Verify symlinks point to correct targets
readlink prompts | grep -q "implementations/claude-code/prompts"
readlink examples | grep -q "implementations/claude-code/examples"
readlink hooks | grep -q "implementations/claude-code/hooks"
```

All commands must pass (exit code 0).

**Field 7: Constraints**

- **Hard constraint:** Use relative symlinks (`implementations/claude-code/prompts`), not absolute (`/Users/.../implementations/claude-code/prompts`). Relative symlinks work across all clones.
- **Do not symlink docs/QUICKSTART.md:** This is a breaking change intentional for clarity. Users should update references.
- **Git tracking:** Symlinks are tracked by git. Commit them so all users get them.

**Field 8: Report**

After completing all work and verification:

1. Commit your changes:
   ```bash
   git add prompts examples hooks
   git commit -m "chore: add backward compatibility symlinks for prompts, examples, hooks"
   ```

2. Write your completion report by appending this section to `/Users/dayna.blackwell/code/scout-and-wave/docs/IMPL/IMPL-refactor-protocol-extraction.md`:

```yaml
### Agent I - Completion Report
status: complete | partial | blocked
worktree: main (no worktree - documentation only)
commit: <sha>
files_changed: []
files_created:
  - prompts (symlink → implementations/claude-code/prompts)
  - examples (symlink → implementations/claude-code/examples)
  - hooks (symlink → implementations/claude-code/hooks)
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (symlinks resolve, old paths work)
```

If you encountered issues, set `status: blocked` and explain in free-form notes below the YAML block.

---

## Wave Execution Loop

After each wave completes, work through the Orchestrator Post-Merge Checklist below in order. The checklist is the executable form; this loop is the rationale.

**This is a documentation-only refactor.** Standard merge procedures apply, but verification is different:

- **No build/test commands** (no executable code)
- **Verification is link checking:** All internal links must resolve
- **File existence validation:** All referenced files must exist
- **Git history preservation:** File moves must show `--follow` history

**Post-Wave 1:** Verify protocol/ and templates/ directories exist, all files have content, no Claude Code tool names leaked (grep verification gates from agent prompts).

**Post-Wave 2:** Verify file moves completed (old locations empty, new locations populated, git log --follow shows history). Verify root README.md and PROTOCOL.md link to protocol/ files. Run link checker on all updated docs.

**Post-Wave 3:** Verify symlinks work (can read through them). Test backward compatibility: `cp ~/code/scout-and-wave/prompts/saw-skill.md /tmp/` should work. Run migration guide through a markdown linter.

**Cascade candidates:** saw-teams/*.md files may reference old prompts/ paths. Update those post-merge if needed.

---

## Orchestrator Post-Merge Checklist

After wave N completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` and `files_created` lists; flag any file appearing in >1 agent's list before touching the working tree
- [ ] Review `interface_deviations` — update downstream agent prompts for any item with `downstream_action_required: true` (not expected in this refactor)
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave{N}-agent-{X}: <desc>"` (if using worktrees; this refactor uses main branch directly)
- [ ] Worktree cleanup: not applicable (no worktrees for documentation work)
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a (no linter for markdown)
      - [ ] Link checking: Run `find . -name "*.md" -exec grep -l "](protocol/" {} \;` and verify all protocol/ links resolve
      - [ ] File existence: Verify all new directories exist (protocol/, templates/, implementations/)
      - [ ] Git history: Test `git log --follow implementations/claude-code/prompts/saw-skill.md` shows full history
- [ ] Fix any cascade failures — check saw-teams/*.md for old prompts/ references
- [ ] Tick status checkboxes in this IMPL doc for completed agents
- [ ] Update interface contracts for any deviations logged by agents (not expected)
- [ ] Apply `out_of_scope_deps` fixes flagged in completion reports
- [ ] Feature-specific steps:
      - [ ] Update CHANGELOG.md with v0.7.0 entry (add breaking changes, new features)
      - [ ] Update root README.md badges/links if needed
      - [ ] Verify README.md "Quick Start" section works with new structure
      - [ ] Test Claude Code skill installation flow after move
- [ ] Commit: `git commit -m "chore: post-wave{N} verification and cleanup"`
- [ ] Launch next wave (or pause for review if not `--auto`)

---

## Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | Protocol README + Participants | TO-DO |
| 1 | B | Preconditions + Invariants + Execution Rules (disjoint ranges) | TO-DO |
| 1 | C | State Machine + Message Formats + Procedures (disjoint ranges) | TO-DO |
| 1 | D | Generic Templates (IMPL doc, agent prompt, completion report) | TO-DO |
| 1.5 | E0 | Extraction completeness verification (read-only) | TO-DO |
| 2 | E | Update root PROTOCOL.md (clean, delegate to protocol/) | TO-DO |
| 2 | F1 | Move Claude Code implementation files (git mv operations) | TO-DO |
| 2 | F2 | Create implementation READMEs + Rewrite root README | TO-DO |
| 2 | G | Create IMPL-SCHEMA.md | TO-DO |
| 2 | H | Create Manual Orchestration Guide | TO-DO |
| 3 | I | Backward compatibility symlinks | TO-DO |
| — | Orch | Post-merge: CHANGELOG update, link checking, cascade fixes | TO-DO |

### Agent B - Completion Report

**Status:** complete

**Files changed:**
- None (new files only)

**Files created:**
- protocol/preconditions.md (created, 78 lines)
- protocol/invariants.md (created, 46 lines)
- protocol/execution-rules.md (created, 116 lines)

**Interface deviations:**
None. All content extracted as specified.

**Out of scope dependencies:**
None.

**Verification:**
- [x] All files exist: protocol/preconditions.md, protocol/invariants.md, protocol/execution-rules.md
- [x] All invariants I1-I6 present in protocol/invariants.md
- [x] All execution rules E1-E14 present in protocol/execution-rules.md
- [x] No Claude Code tool names leaked (verified via grep)

**Commits:**
- 707c1c4: docs(protocol): add preconditions, invariants I1-I6, execution rules E1-E14

**Notes:**
- Invariants I1-I6 copied verbatim from PROTOCOL.md lines 133-179 as required
- Execution rules E1-E14 adapted from PROTOCOL.md lines 216-407 with implementation-agnostic language:
  - E1: Changed "Claude Code's run_in_background: true" → "asynchronous execution without blocking"
  - E4: Removed Claude Code tool references while preserving 5-layer defense model
  - E7a: Removed "--auto mode" reference (orchestrator-specific)
- Preconditions extracted from PROTOCOL.md lines 89-127 with language-neutral examples
- All content successfully extracted and verified


### Agent D - Completion Report

```yaml
status: complete
worktree: .claude/worktrees/wave1-agent-D
commit: f3e118f
files_changed: []
files_created:
  - templates/IMPL-doc-template.md (221 lines)
  - templates/agent-prompt-template.md (256 lines)
  - templates/completion-report.yaml (102 lines)
  - templates/suitability-verdict.md (88 lines)
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (all files exist, placeholders present, no tool references)
```

**Isolation verification:** ✓ Verified: /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-D on branch wave1-agent-D

**Templates created:**

1. **suitability-verdict.md** (88 lines) - Template for the Suitability Assessment section with all 5 suitability questions, verdict types, time estimation format, and field descriptions
2. **completion-report.yaml** (102 lines) - Structured YAML template for agent completion reports with field descriptions and examples
3. **agent-prompt-template.md** (256 lines) - Full 9-field agent prompt structure generalized from prompts/agent-template.md
4. **IMPL-doc-template.md** (221 lines) - Complete IMPL document structure including suitability, scaffolds, dependency graph, interface contracts, file ownership, wave structure, agent prompts, execution loop, checklist, and status tracking

**Generalization approach:**
- All Claude Code tool names removed (Read, Write, Bash, Agent tool)
- Replaced with generic descriptions: "read files", "write files", "run commands", "launch asynchronously"
- Used [PLACEHOLDER] markers throughout for fillable content
- Maintained protocol structure while removing implementation specifics
- Preserved all invariants and execution rules by number (I1-I6, E1-E14) with descriptions
- Templates are implementation-agnostic and portable

**Verification results:**
```bash
✓ All 4 template files exist
✓ Placeholders present in agent-prompt-template.md ([AGENT_LETTER], [WAVE_NUMBER], etc.)
✓ Placeholders present in IMPL-doc-template.md ([FEATURE_NAME], [REPOSITORY_PATH], etc.)
✓ No Claude Code tool invocations found (checked for Read(, Write(, Bash(, run_in_background:)
✓ Commit successful: f3e118f
```

**Notes:**
- Templates are ready for use by any implementation (manual, other AI systems, future automation tools)
- Each template includes field descriptions and examples to guide users
- IMPL doc template includes all optional sections (scaffolds, known issues, cascade candidates) with guidance on when to omit them
- Agent prompt template preserves the defense-in-depth isolation verification protocol discovered in brewprune Round 5

### Agent C - Completion Report

status: complete
worktree: .claude/worktrees/wave1-agent-C
commit: e6d44d9
files_changed: []
files_created:
  - protocol/state-machine.md
  - protocol/message-formats.md
  - protocol/merge-procedure.md
  - protocol/worktree-isolation.md
  - protocol/compliance.md
  - protocol/FAQ.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (all states present, schemas match, 5 layers documented, no tool references)

### Agent B - Completion Report

status: complete
worktree: /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-B
branch: wave1-agent-B
commit: 5f76def
files_changed: []
files_created:
  - protocol/preconditions.md
  - protocol/invariants.md
  - protocol/execution-rules.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (P1-P5 present, I1-I6 present, E1-E14 present, no tool references)

**Extraction details:**
- Extracted preconditions P1-P5 from PROTOCOL.md lines 99-139 (P5 was actually present in the source)
- Extracted invariants I1-I6 from PROTOCOL.md lines 142-189
- Extracted execution rules E1-E14 from PROTOCOL.md lines 226-441
- Removed all Claude Code tool references (Read tool, Write tool, Bash tool, Agent tool, run_in_background)
- Preserved all cross-references to other sections (I{N}, E{N}, P{N} anchors)
- Maintained implementation-agnostic language while keeping generic examples (git commands, file operations)

**Files created (568 lines total):**
- preconditions.md: 133 lines - P1-P5 with definitions, consequences, and suitability verdict format
- invariants.md: 169 lines - I1-I6 with formal statements, enforcement mechanisms, and protocol violations table
- execution-rules.md: 266 lines - E1-E14 with triggers, required actions, failure handling, and rationale

### Agent C - Completion Report

**Status:** complete

**Worktree:** /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-agent-C

**Branch:** wave1-agent-C

**Commit:** d305e30

**Files created:**
- protocol/state-machine.md
- protocol/message-formats.md
- protocol/procedures.md

**Files changed:** []

**Interface deviations:** []

**Out of scope dependencies:** []

**Tests added:** []

**Verification:** PASS (all verification checks passed)

**Notes:**

Successfully extracted protocol dynamic behavior specification from PROTOCOL.md into three separate documentation files:

1. **state-machine.md** - Documented all lifecycle states (SCOUT_PENDING, REVIEWED, SCAFFOLD_PENDING, WAVE_PENDING, WAVE_EXECUTING, WAVE_MERGING, WAVE_VERIFIED, BLOCKED, COMPLETE, NOT_SUITABLE), state transitions with guards, terminal states, solo wave variant, and cross-wave coordination. Preserved state names exactly as they appear in IMPL docs.

2. **message-formats.md** - Documented IMPL doc structure, suitability verdict formats (SUITABLE/NOT SUITABLE/WITH CAVEATS), 9-field agent prompt structure (Field 0-8), completion report YAML schema, and Scaffolds section format. Cross-referenced prompts/agent-template.md for full field definitions.

3. **procedures.md** - Documented five core procedures: Scout (suitability gate + IMPL doc production), Scaffold Agent (type scaffold materialization), Wave execution loop (6 phases), Merge (4 phases), and Inter-wave checkpoint. Included error recovery procedures for BLOCKED state and interface contract failures.

All content extracted from PROTOCOL.md lines 192-624. Language adapted to be implementation-agnostic (describes orchestrator actions generically: "launch agent", "read completion report", "merge branch" rather than specific tool invocations). State machine correctness properties documented. No tool names present in any file.

Isolation verified successfully at start. All verification gate checks passed.
### Agent D - Completion Report

status: complete
worktree: .claude/worktrees/wave1-agent-D
branch: wave1-agent-D
commit: 2b8a1b2
files_changed: []
files_created:
  - templates/agent-prompt-template.md
  - templates/impl-doc-template.md
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (all checks passed)

**Isolation verification:** ✓ Verified worktree path and branch before file modifications

**Template generalization approach:**
- Extracted structure from prompts/agent-template.md and existing IMPL docs
- Replaced all hardcoded paths with {curly-brace} placeholder variables
- Removed Claude Code-specific tool names (Read tool, Write tool, Bash tool, Agent tool)
- Replaced with generic instructions: "read the file", "write to file", "run commands"
- Preserved Field 0-8 structure exactly (load-bearing for protocol compliance)
- Preserved YAML schema for completion reports
- Added template variable reference tables for implementer guidance

**Key design decisions:**
- Used {repo-root}, {wave-number}, {agent-letter} placeholder notation throughout
- Preserved all I{N} and E{N} protocol references (cross-reference anchors)
- Kept isolation verification script structure (5-layer defense-in-depth)
- Maintained completion report YAML schema (parsed by orchestrators)
- Templates reference protocol/*.md files (those are also implementation-agnostic)

**Verification results:**
```bash
✓ Files exist (templates/agent-prompt-template.md, templates/impl-doc-template.md)
✓ Field structure present (Field 0 through Field 8 in agent template)
✓ No hardcoded paths (checked for /Users/dayna.blackwell)
✓ No tool names (checked for "Read tool", "Write tool", "Bash tool", "Agent tool")
✓ Placeholders present ({repo-root}, {wave-number}, {agent-letter})
✓ Commit successful: 2b8a1b2
```

**Notes:**
- Templates are now portable to Python, Rust, manual workflows, or any SAW implementation
- agent-prompt-template.md has 9 fields + variable reference table (self-documenting)
- impl-doc-template.md has frontmatter + scaffolds + waves + completion reports + usage notes
- Both templates include "Template Variables Reference" sections for implementer clarity
- Ready for developers implementing SAW in other runtimes to copy and adapt

---

## Wave 1.5 (Verification)

### Agent E0 - Extraction Completeness Verification

This verification agent runs between Wave 1 and Wave 2 to confirm all content from PROTOCOL.md was successfully extracted to protocol/*.md files with no gaps or duplicates.

**Read-only verification:** No files modified. This agent only verifies Wave 1's work.

---

### Agent E0 - Completion Report

status: complete
worktree: /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave1-5-agent-E0
branch: wave1-5-agent-E0
commit: (no commit - read-only verification)
files_changed: []
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS

**Coverage Report:**

Lines extracted from PROTOCOL.md:
- Lines 16-96: Participants → protocol/participants.md (Agent A) ✓
- Lines 99-139: Preconditions → protocol/preconditions.md (Agent B) ✓
- Lines 142-189: Invariants → protocol/invariants.md (Agent B) ✓
- Lines 192-223: State Machine → protocol/state-machine.md (Agent C) ✓
- Lines 226-441: Execution Rules → protocol/execution-rules.md (Agent B) ✓
- Lines 444-550: Message Formats → protocol/message-formats.md (Agent C) ✓
- Lines 553+: Procedures → protocol/procedures.md (Agent C, new content not in original) ✓

**Definition Completeness:**
- All I1-I6 (invariants) present in protocol/invariants.md ✓
- All E1-E14 (execution rules) present in protocol/execution-rules.md ✓
- All P1-P5 (preconditions) present in protocol/preconditions.md ✓

**Duplicate Analysis:**
- Each I{N} definition appears in exactly ONE file (protocol/invariants.md) ✓
- Each E{N} definition appears in exactly ONE file (protocol/execution-rules.md) ✓
- Each P{N} definition appears in exactly ONE file (protocol/preconditions.md) ✓
- Other occurrences are cross-references (citations), which is correct ✓

**Semantic Coverage:**
- All four participant roles (Orchestrator, Scout, Scaffold Agent, Wave Agent) ✓
- All five preconditions with enforcement details ✓
- All six invariants with enforcement mechanisms ✓
- All fourteen execution rules with trigger conditions ✓
- Complete state machine with transitions and guards ✓
- All message formats (suitability, prompts, reports, scaffolds) ✓
- Operational procedures for scout, scaffold, wave, merge, recovery ✓

**Gaps:** None detected

**Verdict:** Wave 1's extraction work is complete and correct. All substantive content from PROTOCOL.md (lines 16-550) has been extracted to protocol/*.md files with proper organization. Each definition (I/E/P) appears in exactly one canonical file with cross-references elsewhere. No content was lost, no duplicates created.

**Notes:**
- protocol/procedures.md contains new procedural content not in the original PROTOCOL.md, which is an enhancement (Agent C added operational step-by-step guides)
- The extraction preserves all cross-references (I{N}, E{N}, P{N}) for audit traceability
- protocol/README.md provides navigation and adoption guidance (Agent A)
- All extracted files maintain version 0.6.0 consistency
- Ready for Wave 2 (template conversion and documentation enhancement)

### Agent E - Completion Report

status: complete
worktree: /Users/dayna.blackwell/code/scout-and-wave/.claude/worktrees/wave2-agent-E
branch: wave2-agent-E
commit: d13b420
files_changed:
  - PROTOCOL.md
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS

**Summary:**
Successfully refactored PROTOCOL.md from 624 lines to 239 lines (61% reduction) by delegating detailed content to protocol/*.md files while preserving high-level overview and navigation structure.

**Key Changes:**
- Added Navigation section linking to all protocol/*.md files
- Created Quick Reference tables for I1-I6 (invariants) and E1-E14 (execution rules) with links
- Replaced long-form participant descriptions with summaries + link to protocol/participants.md
- Replaced full invariant definitions with quick reference table + link to protocol/invariants.md
- Replaced full execution rule definitions with quick reference table + link to protocol/execution-rules.md
- Kept state machine diagram reference, added link to protocol/state-machine.md
- Condensed message formats to brief summaries + link to protocol/message-formats.md
- Preserved version header, conformance section, reference implementation table
- Removed all Claude Code-specific tool references

**Verification Results:**
- ✓ File exists and was modified (not deleted)
- ✓ All links to protocol/ directory present (participants, invariants, execution-rules, state-machine, message-formats, preconditions)
- ✓ All invariants I1-I6 referenced
- ✓ All execution rules E1-E14 referenced
- ✓ No Claude Code tool names remain
- ✓ File reduced to 239 lines (target: <300 lines)

**Diff Summary:**
- +140 insertions, -525 deletions
- Maintained all I/E/P anchor references for cross-referencing
- Preserved protocol correctness guarantees
- Enhanced navigability with structured quick reference tables

**Notes:**
PROTOCOL.md now serves as the entry point for protocol documentation, providing a clear overview and directing readers to detailed specifications in protocol/*.md. All substantive content remains available through the protocol/ directory, maintaining completeness while improving readability and navigation.

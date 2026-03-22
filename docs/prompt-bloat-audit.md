# Prompt Bloat Audit

Audited: 2026-03-22
Files: 9 prompt files in `implementations/claude-code/prompts/`
Total lines: 3,562

---

## saw-skill.md (779 lines, ~16k tokens)

**Loaded on every `/saw` invocation. Highest-impact target for cuts.**

**Redundant** (can remove, said elsewhere):

- Line 96-117: Invocation mode table is repeated — the same commands appear again in lines 119-128 (Program Commands table) and again in lines 739-779 (Arguments section). Three places document the same commands. The Arguments section (739-779) restates what the invocation table and execution logic already cover. **Remove the Arguments section entirely (40 lines) and the duplicate Program Commands table (lines 119-128, 10 lines).**
- Line 76: "I6: Scout write boundaries" restates a subset of the I6 block at lines 28-37. The longer block already covers it.
- Lines 372-408: The `reactions:` block examples show both a high-risk and low-risk example. The low-risk example (lines 400-408) is the trivial case and adds nothing — any agent can figure out "write less." **Remove low-risk example (8 lines).**

**Obsolete** (references dead things):

- Line 307: Reference to "E16A note" about `impl-file-ownership`, `impl-dep-graph`, `impl-wave-structure` typed blocks — these are markdown-era block names. The YAML schema uses top-level keys `file_ownership`, `dependency_graph`, `waves`. If sawtools validate now checks YAML keys directly, this note references the old parser's concept. **Verify with sawtools; likely removable or needs rewording (3 lines).**

**Over-specified** (agent doesn't need this level of detail):

- Lines 48-74: Agent model selection — 26 lines explaining the 3-level model precedence (skill arg > config > parent), the full config JSON schema, the "Agent tool does not expose a model parameter" implementation detail, and rate-limit fallback. The orchestrator can figure out "read saw.config.json for model, --model flag overrides, parent is default" from 5 lines. The implementation note about indirect model override is an internal SDK detail that doesn't help the orchestrator decide anything. **Could be reduced from 26 to ~8 lines.**
- Lines 255-296: Bootstrap requirements template — a 30-line markdown template for REQUIREMENTS.md. This is a static template that could live in a separate file (e.g., `templates/requirements-template.md`) and be read on demand only when `bootstrap` is invoked. Every `/saw scout` and `/saw wave` invocation pays for this. **Move to reference file (30 lines).**
- Lines 337-353: YAML manifest agent prompt template (the ~60-token stub). The exact format is shown, which is helpful, but the 16-line block is preceded by a lengthy explanation of WHY short prompts are better. The orchestrator doesn't need a persuasion essay. **Reduce explanation from 16 to 5 lines.**
- Lines 443-490: `/saw program plan` flow — 47 lines of step-by-step orchestrator instructions for a mode that most invocations never use. Same for lines 492-597 (`/saw program execute`, 105 lines) and lines 633-738 (`/saw program status` + `/saw program replan`, 105 lines). Total: ~257 lines of program-layer instructions loaded on every `/saw wave` call. **Move entire Program Commands section (lines 443-738) to a reference file `saw-program-commands.md`, read on demand when `program` argument detected. Savings: 295 lines from always-loaded context.**
- Lines 224-253: Execution model block + resume detection. The resume-detect explanation is 10 lines longer than it needs to be. The `sawtools resume-detect` returns JSON; the orchestrator can read the JSON fields. **Reduce by ~8 lines.**
- Lines 360-398: E19 failure type routing + E19.1 reactions override. The E19 routing table is load-bearing (must keep), but the E19.1 reactions block schema, the "when to write reactions" guidance, and the high-risk example total 38 lines. The reactions schema is in `protocol/execution-rules.md` already. **Keep E19 routing table (~12 lines), move reactions guidance + examples to reference (26 lines).**

**Move to reference** (doesn't need to be always-loaded):

- Lines 180-222: sawtools command reference (42 lines). This is a flat list of every sawtools command. The orchestrator already knows which command to run at each step because the execution logic spells it out. The reference list is useful for discovery but not for per-invocation loading. **Move to `sawtools-reference.md`, read on demand. Savings: 42 lines.**
- Lines 142-178: `/saw amend` section (36 lines). Amend is a rare operation. Load on demand when `amend` argument is parsed. **Move to reference. Savings: 36 lines.**

**Must keep** (critical for correctness):

- Lines 23-46: Orchestrator identity, I6 role separation, agent type preference, fallback rule. **Load-bearing. Keep.**
- Lines 131-140: Pre-flight validation. **Keep** (runs once per session).
- Lines 230-253: IMPL discovery, IMPL targeting, resume detection core logic. **Keep** (runs every wave).
- Lines 298-336: Scout launch, E16 validation, E37 critic gate, scaffold agent, human review. **Keep** — this is the core scout-to-wave pipeline.
- Lines 337-360: Wave preparation, agent launching, SAW tag requirement, status tracking. **Keep.**
- Lines 360-371: E19 failure type routing table. **Keep** — drives automatic remediation.
- Lines 416-441: Wave finalization (finalize-wave, E25/E26 integration, E15 close-impl, I3 sequencing). **Keep.**

**Estimated savings:** ~200 lines removable outright, ~295 lines movable to reference. Net always-loaded reduction: ~495 lines (63%).

---

## agent-template.md (301 lines, ~6k tokens)

**Loaded by Scout when writing agent briefs. Not loaded per-invocation.**

**Redundant** (can remove, said elsewhere):

- Lines 24-30: Explanation of E-number ranges (E20-E23 orchestrator-only, E25-E26 integration, E27-E41 etc.) — this same block appears verbatim in `wave-agent.md` line 13. Since agents never read agent-template.md directly (per line 4's own note), this is reference material for Scout only, and Scout gets it from the protocol docs. **Remove (7 lines).**
- Lines 117-139: Field 1 "Exception: Justified API-wide changes" — this is a 22-line escape hatch description. The same concept is covered more concisely in wave-agent.md's I1 section (lines 165-172). Since the orchestrator wraps agent-template around briefs at launch, both copies end up in the agent's context. **Remove from agent-template, keep in wave-agent.md (22 lines).**

**Obsolete** (references dead things):

- Nothing clearly obsolete. The template is well-maintained for YAML-era.

**Over-specified** (agent doesn't need this level of detail):

- Lines 48-113: Field 0 isolation verification — 65 lines of bash scripts, failure report templates, rationale, E4 explanation, cross-repository scenarios, and 4-layer defense-in-depth description. Wave agents now use `sawtools verify-isolation` (a single command, per wave-agent.md line 27). The full bash script in agent-template is the pre-sawtools manual approach. If `verify-isolation` exists, this entire block could be replaced with: "Run `sawtools verify-isolation --branch <branch>`. If it fails, report status: blocked and stop." **Reduce from 65 to ~8 lines (57 lines saved).**
- Lines 170-204: Field 6 verification gate — includes the `diagnose-build-failure` H7 flow (15 lines) that is already documented in wave-agent.md lines 285-319. Scout writes the verification commands into the brief; the agent reads wave-agent.md for H7 guidance. **Remove H7 from agent-template (15 lines).**
- Lines 260-300: Field 8 completion report — the full YAML schema for completion reports (40 lines). Agents now use `sawtools set-completion` (per wave-agent.md lines 204-262). The YAML schema is only needed if the agent writes raw YAML, which it shouldn't. **Reduce to "Use `sawtools set-completion` to write your completion report. See wave-agent.md for full flags." (~3 lines, saving 37 lines).**

**Move to reference:**

- Lines 126-139: The "Justified API-wide changes" exception — if kept at all, move to a reference doc on ownership exceptions.

**Must keep:**

- Lines 1-13: Template header, NOTE about instance vs type layer. **Keep.**
- Lines 33-46: Field numbering, wave numbering explanation. **Keep.**
- Lines 115-123: Field 1 core (I1 disjoint ownership, owned files list). **Keep.**
- Lines 141-168: Fields 2-5 (interfaces, implementation, tests). **Keep.**
- Lines 206-228: Field 7 constraints + out-of-scope handling. **Keep.**
- Lines 229-235: Field 8 header (I5 commit-before-report). **Keep.**

**Estimated savings:** ~100 lines removable, ~22 lines movable to reference. Net: ~122 lines (40%).

---

## scout.md (657 lines, ~13k tokens)

**Loaded once per Scout invocation.**

**Redundant** (can remove, said elsewhere):

- Lines 115-132: Invariants section (I1, I2, I3) — restates invariants that are already embedded in the execution rules the Scout follows. The Scout's actual work (steps 7-8) references these inline. The standalone section is a pre-brief that says "understand these before starting" but the Scout hits them again 200 lines later. **Keep but compress to 8 lines (from 18).**
- Lines 383-403: "Program Contract Awareness" section — 20 lines explaining frozen contracts. This is only relevant when `--program` flag is passed. For most Scout runs, it's dead weight. **Move to reference, load when --program detected (20 lines).**

**Obsolete:**

- Nothing clearly obsolete. Scout prompt is YAML-native.

**Over-specified:**

- Lines 186-254: Suitability gate parallelization value check — 68 lines of detailed heuristics (build/test cycle length, files per agent, agent independence, task complexity, high/low/coordination value guidance, time-to-value estimate format with fill-in template). The Scout is an LLM that can assess "is this worth parallelizing?" from a 10-line description. The time-to-value estimate template (lines 232-257) is particularly over-engineered — the Scout will produce reasonable estimates without a fill-in form. **Reduce from 68 to ~20 lines (48 lines saved).**
- Lines 288-358: Step 4 dependency mapping — 70 lines covering `analyze-deps`, `detect-cascades`, manual fallback, language support tables, cascade classification. This is reference-grade documentation embedded in a prompt. The Scout needs to know: "run `sawtools analyze-deps`, use output for wave assignment, run `sawtools detect-cascades` if renames detected." **Reduce from 70 to ~15 lines, move detailed tool docs to reference (55 lines saved).**
- Lines 452-507: Step 8 wave structuring — 55 lines covering wave assignment from analyze-deps, manual assignment, integration waves, wave structure diagram notation. The diagram notation section (lines 500-507) teaches `{braces}` vs `[brackets]` — over-specified for an LLM. **Reduce from 55 to ~20 lines (35 lines saved).**
- Lines 537-585: Steps 11-12 verification gates and quality gates — 48 lines with language-specific focused test tables, gate type lists, format gate description, docs-only wave auto-skip explanation. Much of this is sawtools implementation detail that the Scout doesn't need to understand to emit correct gates. **Reduce from 48 to ~15 lines (33 lines saved).**

**Move to reference:**

- Lines 288-358: Detailed analyze-deps and detect-cascades tool documentation.
- Lines 383-403: Program contract awareness section.
- Lines 569-585: Quality gate type reference and docs-only wave explanation.

**Must keep:**

- Lines 1-107: Header, task description, YAML schema, valid top-level keys, "do NOT invent keys." **Keep — this is the output contract.**
- Lines 136-185: Suitability gate questions 1-4 (core gate logic). **Keep.**
- Lines 260-287: Steps 1-3 (read project, identify files). **Keep.**
- Lines 360-382: Step 5 interface contracts. **Keep.**
- Lines 404-451: Steps 6-7 scaffolds and file ownership. **Keep.**
- Lines 606-657: Steps 15-16 self-validate + output format + rules. **Keep.**

**Estimated savings:** ~120 lines removable, ~75 lines movable to reference. Net: ~195 lines (30%).

---

## wave-agent.md (333 lines, ~7k tokens)

**Loaded once per Wave agent.**

**Redundant:**

- Lines 12-13: E-number range explanation — identical to agent-template.md lines 24-30. Since wave-agent.md is the TYPE LAYER and agent-template.md is INSTANCE LAYER, and both end up in the agent's context via orchestrator wrapping, this is duplicated. **Remove from one location. Since agent-template.md is being trimmed, keep here (0 change).**
- Lines 165-172: I1 Disjoint File Ownership — already in agent-template.md Field 1 (lines 117-123). Both end up in the agent's prompt. **Remove from wave-agent.md, since agent-template covers it (8 lines).**
- Lines 174-178: I2 Interface Contracts Are Binding — already in agent-template.md Field 2 (lines 141-143). **Remove (5 lines).**
- Lines 179-184: I5 Agents Commit Before Reporting — already in agent-template.md Field 8 (lines 229-234). **Remove (6 lines).**

**Over-specified:**

- Lines 75-110: "All File Operations: Use Absolute Paths" — 35 lines with correct/incorrect examples, multiple code blocks, and a "Why this matters" explanation. The concept is: "use absolute paths, Bash tool doesn't preserve cwd." This can be said in 5 lines. **Reduce from 35 to ~8 lines (27 lines saved).**
- Lines 112-114: go.mod replace directives — a 3-line note that is Go-specific. Fine to keep but could be in a Go-specific reference.
- Lines 119-137: Progress tracker checklist — 18 lines asking agents to copy/paste a checklist. In practice, agents don't reliably maintain checklists across context compactions. The value is questionable. **Remove (18 lines).**
- Lines 285-319: Build Failure Diagnosis H7 — 34-line section with multi-step instructions and example YAML output. Also appears in agent-template.md. **Keep in wave-agent.md (TYPE LAYER), remove from agent-template.md as noted above.**

**Move to reference:**

- Lines 151-162: Session Context Recovery — 12 lines. Only relevant when resuming after compaction. Could be injected by orchestrator only when journal context exists. **Move to reference (12 lines).**

**Must keep:**

- Lines 1-50: Header, worktree isolation protocol, verify-isolation command. **Keep.**
- Lines 186-200: Program Contract Awareness. **Keep.**
- Lines 202-268: Completion Report (sawtools set-completion usage). **Keep.**
- Lines 264-283: "If You Get Stuck" section. **Keep.**
- Lines 321-334: Rules + Agent Type Identification. **Keep.**

**Estimated savings:** ~64 lines removable, ~12 lines movable to reference. Net: ~76 lines (23%).

---

## scaffold-agent.md (158 lines, ~3k tokens)

**Loaded once per Scaffold agent run. Low frequency.**

**Redundant:**

- Lines 90-92: "Why This Matters" section — 3 lines restating why scaffolds exist. Already explained in scout.md step 6 and agent-template.md. The scaffold agent doesn't need convincing. **Remove (3 lines).**
- Lines 139-143: "Verification: Before marking complete" — 5-point checklist that restates what steps 3-5 already say. **Remove (5 lines).**

**Over-specified:**

- Lines 37-45: Session Context Recovery — 9-line section identical in concept to wave-agent.md's version. Rarely triggered. **Move to reference or inject on demand (9 lines).**

**Must keep:**

- Lines 1-35: Header, Step 0 repo context derivation. **Keep.**
- Lines 47-89: Core task (steps 1-5, build verification E22). **Keep.**
- Lines 94-137: What to create, output format, commit format. **Keep.**
- Lines 146-158: Rules. **Keep.**

**Estimated savings:** ~17 lines removable. Net: ~17 lines (11%).

---

## integration-agent.md (229 lines, ~5k tokens)

**Loaded once per integration agent run. Low frequency.**

**Redundant:**

- Lines 24-49: "Understanding integration_connectors" — 25 lines explaining what integration_connectors are, when they're used (2 scenarios), and how they relate to planned integration waves. This context is useful for a human reader but the integration agent just needs "only modify files in the connectors list." The orchestrator already passes the connector list. **Reduce from 25 to ~5 lines (20 lines saved).**
- Lines 51-103: AllowedPathPrefixes explanation + example IMPL doc + relationship with integration waves + example wave structure — 52 lines of context the agent doesn't need. The agent receives the connector file list directly from the orchestrator. It doesn't need to understand the IMPL doc schema. **Reduce from 52 to ~5 lines (47 lines saved).**

**Over-specified:**

- Lines 105-110: "Common wiring patterns" — 6 lines listing patterns (CLI command, HTTP handler, service init, config option). The agent figures this out by reading the codebase. **Remove (6 lines).**

**Must keep:**

- Lines 1-22: Header, context summary. **Keep (trim to essentials).**
- Lines 112-165: Input, Step 0, Workflow (the actual work instructions). **Keep.**
- Lines 166-229: File restrictions, completion report, rules, verification gate. **Keep.**

**Estimated savings:** ~73 lines removable. Net: ~73 lines (32%).

---

## critic-agent.md (182 lines, ~4k tokens)

**Loaded once per critic run. Low frequency.**

**Redundant:**

- Nothing significantly redundant. This is a well-scoped prompt.

**Over-specified:**

- Lines 113-148: Step 3 CriticResult JSON format — 35 lines showing the full JSON schema for `--agent-reviews`. The agent can figure out the JSON structure from the `sawtools set-critic-review` command help. **Reduce to a 5-line example (30 lines saved).**

**Must keep:**

- Lines 1-42: Header, purpose, input, Step 0. **Keep.**
- Lines 43-112: Steps 1-2 (the 6 verification checks). **Keep — this IS the agent's job.**
- Lines 150-182: Verdict thresholds, output format, rules. **Keep.**

**Estimated savings:** ~30 lines removable. Net: ~30 lines (16%).

---

## planner.md (551 lines, ~11k tokens)

**Loaded once per Planner invocation. Rare.**

**Redundant:**

- Lines 503-524: "Critical Rules" section — 22 lines of "You do NOT / You do" that restate what the entire prompt already describes. The Planner prompt is already clear about scope. **Remove (22 lines).**
- Lines 539-548: Final "Rules" section — 10 lines restating constraints already embedded in the implementation process. **Remove (10 lines).**

**Over-specified:**

- Lines 310-467: Example PROGRAM manifest — 157 lines of a complete fictional example (task-manager-app). This is valuable for a human reader but an LLM can produce correct YAML from the schema (lines 200-308) without a 157-line worked example. **Reduce to a 30-line minimal example (127 lines saved).**
- Lines 36-85: Program Suitability Gate — 49 lines including 4 questions plus detailed verdicts and a time-to-value estimate template. The estimate template (lines 69-85) is the same over-engineering as in scout.md. **Reduce estimate template from 17 to 5 lines (12 lines saved).**

**Move to reference:**

- Lines 310-467: The full example manifest — move to `examples/program-manifest-example.yaml` for human readers.

**Must keep:**

- Lines 1-35: Header, role, task description. **Keep.**
- Lines 36-68: Suitability gate core questions. **Keep.**
- Lines 86-195: Implementation process (Steps 1-9). **Keep.**
- Lines 196-308: PROGRAM manifest schema. **Keep.**
- Lines 469-502: Program invariants P1-P4. **Keep.**
- Lines 526-537: Completion section. **Keep.**

**Estimated savings:** ~171 lines removable, ~127 lines movable to reference. Net: ~171 lines (31%).

---

## saw-bootstrap.md (372 lines, ~7k tokens)

**Loaded once per bootstrap invocation. Rare.**

**Redundant:**

- Lines 155-182: "Scout Types Phase" — 27 lines explaining why scaffolds exist and the Scout-to-Scaffold-Agent handoff. This is already explained in scout.md step 6 and scaffold-agent.md. The bootstrap Scout is a Scout — it inherits this knowledge. **Remove (27 lines).**
- Lines 340-352: Self-validation section — restates the same `sawtools validate --fix` flow from scout.md step 16. **Remove (12 lines).**
- Lines 355-372: Rules section — 18 lines restating constraints from scout.md Rules section. **Remove (18 lines).**

**Over-specified:**

- Lines 95-153: Architecture Design Principles — 58 lines including Go/Rust/TypeScript directory structures, Rust workspace `Cargo.toml` handling (13 lines about orchestrator-owned files), and "No god files" principle. The directory structure examples are useful but the Rust workspace rule is extremely specific. **Reduce Rust-specific content from 13 to 3 lines, keep Go example (10 lines saved).**
- Lines 196-338: Output Format — 142-line YAML template. Much of this duplicates the scout.md schema. Since bootstrap Scout IS a Scout, it inherits the schema. **Reduce to "Follow the same YAML schema as scout.md with these bootstrap-specific additions: `project:` block" (~15 lines, saving 127 lines).**

**Must keep:**

- Lines 1-20: Header, When to Use / When NOT to Use. **Keep.**
- Lines 22-51: Pre-Flight git repo check, sequencing note. **Keep.**
- Lines 53-93: Step 0 + Phase 0 (read CONTEXT.md, read REQUIREMENTS.md). **Keep.**
- Lines 184-194: Wave 1+ pattern. **Keep.**

**Estimated savings:** ~194 lines removable. Net: ~194 lines (52%).

---

## Summary

| File | Current lines | Removable | Move to ref | Net savings | % reduction |
|------|--------------|-----------|-------------|-------------|-------------|
| saw-skill.md | 779 | 200 | 295 | 495 | 63% |
| agent-template.md | 301 | 100 | 22 | 122 | 40% |
| scout.md | 657 | 120 | 75 | 195 | 30% |
| wave-agent.md | 333 | 64 | 12 | 76 | 23% |
| scaffold-agent.md | 158 | 17 | 0 | 17 | 11% |
| integration-agent.md | 229 | 73 | 0 | 73 | 32% |
| critic-agent.md | 182 | 30 | 0 | 30 | 16% |
| planner.md | 551 | 171 | 127 | 171 | 31% |
| saw-bootstrap.md | 372 | 194 | 0 | 194 | 52% |
| **TOTAL** | **3,562** | **969** | **531** | **1,373** | **39%** |

---

## Top 10 Cuts by Token Impact

Ranked by (lines saved x loading frequency). saw-skill.md loads on EVERY /saw invocation, so its cuts dominate.

| Rank | File | What to cut | Lines saved | Why it matters |
|------|------|-------------|-------------|----------------|
| 1 | saw-skill.md | Move Program Commands section (lines 443-738) to `saw-program-commands.md`, load on demand when `program` arg detected | 295 | Loaded every invocation, used <5% of the time |
| 2 | saw-skill.md | Remove duplicate Arguments section (lines 739-779) — already covered by invocation table + execution logic | 40 | Pure redundancy, loaded every invocation |
| 3 | saw-skill.md | Move sawtools command reference (lines 180-222) to `sawtools-reference.md` | 42 | Discovery aid, not needed per-invocation |
| 4 | saw-skill.md | Move `/saw amend` section (lines 142-178) to reference | 36 | Rare operation, loaded every invocation |
| 5 | saw-skill.md | Compress model selection (lines 48-74) from 26 to 8 lines | 18 | Implementation detail, not decision-driving |
| 6 | saw-skill.md | Move bootstrap REQUIREMENTS.md template (lines 255-296) to template file | 30 | Only needed for bootstrap, loaded every invocation |
| 7 | saw-bootstrap.md | Remove 142-line Output Format that duplicates scout.md schema | 127 | Bootstrap Scout IS a Scout; it already has the schema |
| 8 | planner.md | Reduce 157-line example manifest to 30-line minimal example | 127 | LLM doesn't need a full worked example to produce YAML |
| 9 | agent-template.md | Replace 65-line Field 0 bash scripts with 8-line `sawtools verify-isolation` reference | 57 | sawtools verify-isolation makes manual bash obsolete |
| 10 | scout.md | Compress suitability gate parallelization heuristics (lines 186-254) from 68 to 20 lines | 48 | LLM can assess parallelization value without a decision tree |

**Total from Top 10 alone: ~820 lines saved.**

---

## Implementation Notes

**Safe to do immediately (no behavioral change):**
- Remove Arguments section from saw-skill.md (pure duplication)
- Remove duplicate Program Commands table from saw-skill.md
- Remove low-risk reactions example from saw-skill.md
- Remove redundant I1/I2/I5 from wave-agent.md (covered by agent-template wrapping)
- Remove "Why This Matters" from scaffold-agent.md
- Remove duplicate verification checklist from scaffold-agent.md
- Remove Critical Rules + final Rules from planner.md (restated throughout)

**Requires creating reference files:**
- `saw-program-commands.md` — program plan/execute/status/replan flows
- `sawtools-reference.md` — command catalog
- `saw-amend-reference.md` — amend flows
- `templates/requirements-template.md` — bootstrap REQUIREMENTS.md template

**Requires careful testing (behavioral impact possible):**
- Compressing agent-template.md Field 0 (isolation verification) — must verify sawtools verify-isolation covers all cases
- Compressing scout.md dependency mapping tools section — must verify agents still run analyze-deps correctly
- Removing progress tracker from wave-agent.md — low-risk but was intentionally added

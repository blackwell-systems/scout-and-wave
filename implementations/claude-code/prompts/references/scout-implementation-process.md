<!-- Part of scout agent procedure. Loaded by validate_agent_launch hook. -->
# Implementation Process (Instructions - NOT Output Format)

**Note:** The numbered steps below are YOUR INSTRUCTIONS for how to analyze the codebase.
They are NOT the structure of your output. Your output is PURE YAML following the schema above.

1. **Read project memory.** Before running the suitability gate, check for
   `docs/CONTEXT.md` in the target project. If present, read it in full (E17).
   Use its contents to inform your analysis:
   - `established_interfaces` — do not propose types that already exist here
   - `decisions` — respect prior architectural decisions; do not contradict them
   - `conventions` — follow the project's naming, error handling, and testing style
   - `features_completed` — understand project history and avoid repeating approaches

   If `docs/CONTEXT.md` is absent, proceed normally. The file is optional; new
   projects will not have one.

2. **Read the project first.** Examine the build system (Makefile, Cargo.toml,
   go.mod, package.json, pyproject.toml), test patterns, naming conventions, and
   directory structure. The verification gates and test expectations you emit
   must match the project's actual toolchain. Derive the full test suite command
   and record it as `test_command` in the IMPL doc — this is the command the
   Orchestrator runs post-merge to catch cross-package failures that individual
   agents cannot see in isolation.

3. **Identify every file that will change or be created.** List all files from the
   feature requirements first. Then proceed to step 4 for automated dependency analysis.

4. **Map the dependency graph using automated tools.** Use `sawtools analyze-deps` to
   trace call paths, imports, and type dependencies automatically:

   **For Go projects (PRIMARY METHOD):**
   ```bash
   sawtools analyze-deps <repo-root> --files "<file1,file2,file3>" --format yaml
   ```

   This produces:
   - `nodes[]` — each file with its `depends_on`, `depended_by`, and `wave_candidate` fields
   - `waves{}` — suggested wave groupings based on topological sort (depth-based)
   - `cascade_candidates[]` — files importing modified code but not in ownership table

   **Use this output directly:**
   - `wave_candidate` field (0-indexed depth) maps to wave assignments (add 1 for 1-indexed
     waves: depth 0 → Wave 1, depth 1 → Wave 2, etc.)
   - Cascade candidates are already detected — copy them into your IMPL doc's cascade section
   - Dependency edges are verified via AST analysis (no guessing)

   **For non-Go projects or when tool fails:**
   Fall back to manual dependency tracing only if:
   - Project uses Rust/JavaScript/TypeScript/Python (multi-language support not yet implemented)
   - `sawtools analyze-deps` exits with error

   Manual fallback: read each file, trace imports and call paths, identify leaf nodes
   (no dependencies) and root nodes (block downstream work). Draw the full DAG manually.

   **Type rename cascade check (after dependency analysis):**
   If any interface contract introduces a type rename (not just new fields; an actual
   rename of a struct, trait, or type alias), detect cascade candidates using
   `sawtools detect-cascades` (M2).

   **Primary method: sawtools detect-cascades**

   ```bash
   sawtools detect-cascades --renames '[{"old":"AuthToken","new":"SessionToken","scope":"pkg/auth"}]'
   ```

   Output: YAML with cascade candidates classified by severity:
   ```yaml
   cascade_candidates:
     - file: "cmd/server/main.go"
       line: 42
       match: "auth.AuthToken"
       cascade_type: "syntax"
       severity: "high"
       reason: "Will cause compilation failure - agent must update import"
     - file: "internal/middleware/session.go"
       line: 67
       match: "// Returns AuthToken for valid session"
       cascade_type: "semantic"
       severity: "low"
       reason: "Comment only - does not affect compilation"
   ```

   AST-based classification:
   - **syntax (high/medium)**: import statements, type declarations, variable/field declarations
   - **semantic (low)**: comments, string literals

   Add each cascade candidate to the IMPL doc's cascade section with its severity and
   reason, even if it falls within another agent's ownership scope or was already
   detected by `analyze-deps`. Syntax-level cascades (import errors, "type not found")
   will cause compilation failures in isolated agent worktrees, and agents under build
   pressure will self-heal by touching files outside their ownership. Naming these in
   advance prevents that improvisation.

   **Language support:** `sawtools detect-cascades` currently supports Go only (AST-based static analysis).
   For Rust, JavaScript/TypeScript, and Python projects, fall back to manual cascade detection:
   run workspace-wide search (grep/rg) for the old type name, list every file that imports or
   references it, manually classify as syntax vs semantic based on context (import line = syntax,
   comment = semantic).

5. **Define interface contracts.** For every function, method, or type that
   will be called across agent boundaries, write the exact signature.
   Language-specific, fully typed, no pseudocode. These signatures are binding
   contracts. Agents will implement against them without seeing each other's
   code. If you cannot determine a signature, flag it as a blocker that must
   be resolved before launching agents.

   **Integration-required exports (E25/E26):** For each exported function or
   type in an interface contract that must be called from a file outside the
   implementing agent's ownership, add `integration_required: true` and
   `suggested_callers: [file1.go, file2.go]` fields to the contract entry.
   This signals that the Integration Agent (E26) will need to wire the export
   into caller files after the wave merges.

   When an agent creates an exported function/type that must be called from a
   file outside its ownership, flag the export as `integration_required` and
   list the caller file in `integration_connectors`.

   `integration_connectors` remains as a fallback for reactive E25/E26 gap
   detection when integration needs aren't predictable at planning time. When
   both a `type: integration` wave and `integration_connectors` exist, the
   planned wave handles known wiring and E25/E26 catches any gaps missed.

> **Note:** When `--program` flag is provided, additional contract handling
> rules apply. See `references/scout-program-contracts.md`.

6. **Detect shared types and define scaffold contents.** After defining interface
   contracts in step 5, scan for types that cross agent boundaries:

   **Automatic detection:** For each type, struct, enum, or interface in the
   interface contracts section, count how many agents will reference it. If
   referenced by ≥2 agents (one defines, another consumes; or both consume),
   add it to the Scaffolds section.

   **Detection heuristics:**
   - Agent A's prompt says "define type X" AND Agent B's prompt says "consume type X"
   - Agent A returns type X from a function AND Agent B calls that function
   - A type name appears in multiple agent file ownership lists
   - Same struct name would be created by multiple agents in different files

   **Why this matters:** Agents cannot coordinate at runtime. If Agent A defines
   `MetricSnapshot` in `fileA.go` and Agent B defines it in `fileB.go`, the merge
   will fail with duplicate declarations. Creating the shared type in a scaffold
   file before Wave 1 launches prevents this.

   **Scaffolds section format:**

   | File | Contents | Import path | Status |
   |------|----------|-------------|--------|
   | `path/to/types.go` | `TypeName struct (fields)` | `import/path` | pending |

   For each scaffold file, list: the file path, the types/interfaces/structs it
   must contain (exact signatures), and any imports required. Do not create the
   files; the Scaffold Agent will create them after human review.

   If no cross-agent types are detected, write in the Scaffolds section:
   "No scaffolds needed - agents have independent type ownership."

7. **Assign file ownership and agent IDs.** Every file that will change gets assigned to
   exactly one agent. No two agents in the same wave may touch the same file.
   If two tasks need the same file, resolve the conflict now: extract an
   interface, split the file, or create a new file so ownership is disjoint.
   This is a hard constraint, not a preference.

   **Cross-repository file ownership:** If the work spans multiple repositories, add a `repo:` field to each file ownership entry specifying which repository the file belongs to. Use the repository name (not the full path). For files outside any repository (e.g., `~/.local/bin/sawtools`), use `repo: system`.

   **IMPORTANT — mismatched repos:** When the IMPL doc lives in repository X but the owned files live in repository Y (common when the protocol repo contains IMPL docs for work that lands in the Go SDK or web app repos), you MUST set `repo:` on every file ownership entry. Even if you believe all files are in one repo, check: does the IMPL doc's location (e.g. `scout-and-wave/docs/IMPL/`) match the repo where the files will be created or modified? If not, tag every entry with its correct repo name. Omitting `repo:` in this scenario causes the file browser to 404 when users try to view owned files.

   **IMPORTANT — cross-repo quality gates:** When file_ownership spans 2+ repos, every quality gate MUST include `repo:` specifying which repo it runs in. Without `repo:`, gates execute in ALL repos — a docs-only repo (like `scout-and-wave`) has no Go module and `go build ./...` will fail, blocking the entire wave. The validator enforces this (MR02_UNSCOPED_GATE).

   **Single-repository work:** If all files belong to the same repository, omit the `repo:` field entirely on both file_ownership and quality_gates. The web UI and tooling automatically detect multi-repo work by counting distinct repo values.

   **Agent ID format:** Agent identifiers follow the `[Letter][Generation]` scheme (regex: `[A-Z][2-9]?`). Generation 1 is the bare letter (`A`, `B`, `C`, …); the digit is omitted. Multi-generation IDs (`A2`, `B3`, `C4`, …) are assigned when:
   - More than 26 agents are needed in a wave (exhausting single letters), OR
   - Agents share a logical sub-domain and the Scout wants to express that grouping explicitly (e.g., `A`, `A2`, `A3` for three closely related data-layer agents).

   Note: `A` and `A1` are NOT both valid — only the bare letter represents generation 1. Worktree branches follow the same ID: `saw/{slug}/wave1-agent-A2`, `saw/{slug}/wave2-agent-B3`. Branches created before v0.39.0 use the legacy format `wave1-agent-A2` without slug prefix; tools accept both formats.

8. **Structure waves from the DAG.** Group agents into waves:

   **If analyze-deps was used (multi-language support):**
   Use the `wave_candidate` field from step 4's output. Files with `wave_candidate: 0`
   go to Wave 1, `wave_candidate: 1` go to Wave 2, etc. Group agents by the maximum
   `wave_candidate` of their owned files (an agent owning files at depths 0 and 1 goes
   to Wave 2, since it depends on Wave 1 completing).

   **Supported languages:**
   - **Go** — AST-based import analysis via `go/parser` and `go/ast` (fully supported)
   - **Rust** — AST-based `use` statement analysis via external `rust-parser` helper binary (requires binary in PATH)
   - **JavaScript/TypeScript** — ES6/CommonJS import analysis via external `js-parser.js` Node.js script (requires node in PATH)
   - **Python** — `import`/`from X import Y` analysis via external `python-parser.py` script (requires python3 in PATH)

   **Manual wave assignment (all projects):**
   - Wave 1: Agents whose files have no dependencies on other new work.
     These are the foundation. Maximize parallelism here.
   - Wave N+1: Agents whose files depend on interfaces delivered in Wave N.
   - An agent is in the earliest wave where all its dependencies are satisfied.
   - Annotate each wave transition with the *specific* agent(s) that unblock
     it, not "blocked on Wave 1" but "blocked on Agent A completing."

   **Integration waves (E27):** When a wave exists solely to wire exports from
   prior waves into existing caller code (e.g., registering CLI commands in
   `main.go`, adding function calls in `server.go`, adding route registrations),
   mark it with `type: integration`:

   ```yaml
   waves:
     - number: 2
       type: integration
       agents:
         - id: D
           task: "Wire new packages into main.go and finalize.go"
           files: [cmd/sawtools/main.go, pkg/engine/finalize.go]
   ```

   Integration waves differ from standard waves:
   - No worktree — agents run on the main branch (merged result from prior waves)
   - No isolation verification — no worktree branch to verify
   - Agents are dispatched as Integration Agents, not Wave Agents
   - Agent `files` list constrains what the agent may modify (same as `integration_connectors`)

   **Prefer planned integration waves over `integration_connectors`.** When you
   know at planning time that wiring work is needed, create an explicit
   `type: integration` wave instead of relying on reactive E25/E26 gap detection.
   This gives the human a review opportunity and makes the wiring task visible
   in the wave structure diagram.

   **Wave structure diagram notation:** Show integration waves distinctly:
   ```
   Wave 1: [A] [B] [C]              <- 3 parallel agents
                 | (A+B+C complete)
   Wave 2: {D}                       <- type: integration (wiring only)
   ```
   Use `{braces}` for integration agents and `[brackets]` for standard wave agents.

   **Cascade candidates:**
   If analyze-deps produced `cascade_candidates[]`, include them in the IMPL doc's
   cascade section with their `reason` and `type` fields. These files are not in any
   agent's ownership but may break if interface contracts change semantically.

   **Cross-wave migration safety.** When a feature removes, renames, or
   consolidates a module/package (e.g., migrating `pkg/types` into
   `pkg/protocol`), apply these rules to prevent intermediate build breaks:

   **Rule 1 — Single-wave preference.** If ALL files importing the old module
   fit in one wave (<=6 agents), put them in the same wave as the signature
   changes. This eliminates the cross-wave break entirely.

   **Rule 2 — Re-export bridge pattern.** When too many callers exist for a
   single wave, use a 3-wave approach:
   - Wave 1: Make signature changes in the target package AND add re-export
     bridges (type aliases, wrapper functions, re-exports) in the old package
     that forward to the new signatures.
   - Wave 2: Update callers to import from the new package directly.
   - Wave 3: Remove the re-export bridges (cleanup wave).

   The bridge keeps the codebase buildable between waves because old import
   paths still resolve.

   **Rule 3 — Detection heuristic.** Before finalizing wave assignments, check:
   if file_ownership puts files from the same directory/package in different
   waves AND any agent changes exported function signatures or type definitions,
   flag it as a potential migration boundary. Either consolidate into one wave
   (Rule 1) or ensure re-export bridges are planned (Rule 2).

   Language-specific bridge mechanisms:
   - Go: type alias (`type OldName = newpkg.NewName`), var alias, wrapper function
   - TypeScript/JavaScript: `export { NewName as OldName } from './new-module'`
   - Python: `from new_module import NewName as OldName` in `__init__.py`
   - Rust: `pub use new_crate::NewType as OldType;`

9. **Integration completeness audit.** Before writing agent prompts, verify
   every new artifact has its full wiring chain assigned. For each file in
   file_ownership, check: does it define something (CLI command, API handler,
   agent type, exported function) that must be *registered* in another file?
   If yes, that registration file must also be in file_ownership.

   Checklist:
   - New CLI commands → registration file (`root.go`, `main.go`) assigned?
   - New API handlers → route registration file assigned?
   - New agent prompts → orchestrator config updated (e.g., `saw-skill.md`)?
   - Scaffold files → listed in BOTH `scaffolds:` AND `file_ownership:` (wave 0)?
   - `integration_required` contracts → caller file in an integration wave or connectors?

   If any wiring point is unassigned: add it to an agent's ownership, create
   a `type: integration` wave, or add to `integration_connectors`.

10. **Write agent prompts under `## Wave N` headers.** Each wave MUST have its
   own `## Wave N` section in the IMPL doc. Agent prompts go under `### Agent {ID} - {Role Description}`
   subsections within their wave. Do NOT group all agents under a single flat
   section. Use the standard 9-field format (see [agent template](agent-template.md)).
   The prompt must be self-contained: an agent receiving it should need nothing
   beyond the prompt and the existing codebase to do its work.

11. **Determine verification gates from the build system.**

   ```bash
   sawtools extract-commands <repo-root>
   ```

   Detects the project toolchain and extracts build/test/lint/format commands
   from CI configs, Makefiles, and package manifests (priority: CI configs >
   Makefile > package.json > language defaults).

   Map the output to IMPL fields:
   - `commands.build` → quality gate (type: build)
   - `commands.test.full` → `test_command` field + post-merge gate
   - `commands.test.focused_pattern` → agent verification gates
   - `commands.lint.check` → `lint_command` field + agent verification gates

   Include the lint check command in every agent's verification gate between
   build and test. If `commands.lint.check` is empty, write `lint_command: none`.

   **Agents run linters in check mode only.** Never put `--fix` or `-w` flags
   in agent gates. The orchestrator owns the single auto-fix pass post-merge.

   Use focused test commands in agent gates if a module has >50 tests to keep
   iteration fast; full suite runs at post-merge verification:

   | Language | Focused (agent gate) | Full (post-merge) |
   |----------|---------------------|-------------------|
   | Go       | `go test ./pkg -run TestFoo` | `go test ./...` |
   | Rust     | `cargo test test_foo` | `cargo test` |
   | Node     | `npm test -- --grep "foo"` | `npm test` |
   | Python   | `pytest path/to/test_foo.py` | `pytest` |

12. **Emit quality gates (optional).** If the project has a known build toolchain, add a `## Quality Gates` section to the IMPL doc between Suitability Assessment and Scaffolds. Use typed-block fence syntax ```` ```yaml type=impl-quality-gates ````:

    Auto-detect from marker files:
    - `go.mod` → Go gates (`go build ./...`, `go test ./...`, `go vet ./...`); format gate (`gofmt -l .`)
    - `package.json` → Node gates (`tsc --noEmit`, `npm test`, `eslint .`); format gate (`npx prettier --check .`)
    - `Cargo.toml` → Rust gates (`cargo build`, `cargo test`, `cargo clippy`); format gate (`cargo fmt --check`)
    - `pyproject.toml` → Python gates (`mypy .`, `pytest`, `ruff check .`); format gate (`ruff format --check .`)

    **Valid gate types:** `build`, `lint`, `test`, `typecheck`, `format`, `custom`. Use `type: format` for auto-formatting checks (see format gate description below). Invalid types are rewritten to `custom` by `sawtools validate --fix`.

    **format gate** — Auto-formatting check. Detects project formatter (`gofmt`, `prettier`, `ruff`, `cargo fmt`) and runs in check mode (report-only) or fix mode (auto-apply). Set `fix: true` to auto-apply. Cache is invalidated after fix mode. Use before lint gates to reduce noise. The `command` field is optional; if omitted, the formatter is auto-detected from marker files.

    Use the same toolchain commands already identified for the `test_command` field — no new discovery needed.

    Omit this section entirely if no build toolchain is detected or the project is markdown/documentation only.

    **Docs-only waves:** If a wave owns only `.md`, `.yaml`, `.yml`, or `.txt` files, `sawtools run-gates` will automatically skip `build`, `test`, and `lint` gates for that wave — no action needed. Do NOT emit a `type: build` or `type: test` gate whose only purpose is to verify documentation files. If you want explicit verification for a docs-only wave, use `type: custom` with a relevant command (e.g., `sawtools validate docs/IMPL/IMPL-*.yaml` or `echo "docs-only: no tests"`).

13. **Emit post-merge checklist (optional).** After Known Issues and before Dependency Graph, add a `## Post-Merge Checklist` section using typed-block fence syntax ```` ```yaml type=impl-post-merge-checklist ```` if orchestrator-level verification steps are needed beyond quality gates:

    Include orchestrator-facing post-merge verification steps: full workspace builds after merge, cross-package integration tests, end-to-end tests spanning multiple agents' work, cross-repo dependency checks.

    Omit this section entirely if no orchestrator verification steps are needed beyond quality gates. Do not output an empty typed block.

14. **Emit known issues as typed block.** In the Known Issues section, use typed-block fence syntax ```` ```yaml type=impl-known-issues ````. Document pre-existing issues discovered during suitability assessment.

    If no known issues are discovered, omit the section entirely.

15. **E16A — Required block presence.** Every IMPL doc must include all three of
    the following YAML top-level keys, or validation fails:
    - `file_ownership` (File Ownership section)
    - `dependency_graph` (Dependency Graph section)
    - `waves` (Wave Structure section)

    Do not omit any of these three. If the work is simple, these sections may be
    brief, but they must be present.

16. **Self-validate (mandatory, do not skip).** After writing the IMPL doc, run:
    ```bash
    sawtools validate --fix "<absolute-path-to-impl-doc>"
    ```
    If exit code is 1, read the JSON errors and fix only the failing fields.
    Re-run validation until it passes (max 3 attempts). Do NOT finish without
    a passing validation. If all 3 attempts fail, set `state: "SCOUT_VALIDATION_FAILED"`
    and report remaining errors in your final output. The orchestrator also validates
    as defense-in-depth, but catching errors here prevents unnecessary retry loops.

17. **Brief accuracy self-check (mandatory, do not skip).** After schema validation
    passes, perform a targeted accuracy check on the briefs you just wrote. The critic
    gate also verifies these, but catching errors here saves a full critic round trip
    (~3-5 min) that blocks wave execution.

    For each agent, re-read its owned files and verify:

    **a. File ownership completeness.** Every file mentioned in an agent's brief must
    appear in `file_ownership`. New files that do not yet exist on disk must have
    `action: new`. Check your interface contracts and brief text for any filenames you
    referenced but may have omitted from `file_ownership` (common miss: a new helper
    file like `logger.go` or `types.go` described in the interface contracts but not
    listed as an ownership entry).

    **b. Symbol existence spot-check.** For each agent, pick 3-5 key symbols referenced
    in the brief (struct names, function names, method signatures) and verify they exist
    in the actual source files at approximately the stated locations:
    ```bash
    grep -n "SymbolName" path/to/owned/file.go
    ```
    If a symbol is absent or at a significantly different location, the brief is stale —
    update it before finishing.

    **c. Package scope check for new function definitions.** If a brief instructs an
    agent to define a new unexported function (e.g., `func loggerFrom(...)`,
    `func newHelper(...)`), check whether another file in the same Go package would
    also define a function with the same name. Two files in `package foo` cannot both
    declare `func loggerFrom`. If multiple files in the same package need the helper,
    the brief must say: define it in exactly one file, use it from the others without
    re-declaring.

    **d. Multiplicity check.** For any brief instruction like "find struct X and add
    field Y" or "find the construction of X and add Z", grep the file to count actual
    occurrences. If more than 1, the brief must explicitly state the count and require
    all occurrences to be updated:
    ```bash
    grep -c "StructName{" path/to/file.go  # count struct literal occurrences
    ```

    Fix any issues found before completing. Typically takes 5-10 minutes. Do not skip
    this step — it directly reduces critic gate errors and prevents wave execution delays.

18. **Write injection_method to IMPL doc.** Before completing, record how you received
    your reference file content by running:

    ```bash
    sawtools set-injection-method <impl-doc-path> --method <value>
    ```

    Determine the value as follows:
    - If you see `<!-- injected: references/scout-suitability-gate.md -->` markers in your context: `--method hook`
    - If those markers are absent and you read the reference files manually: `--method manual-fallback`
    - If you are uncertain: `--method unknown`

    This creates an audit trail of whether hook-based progressive disclosure is working.

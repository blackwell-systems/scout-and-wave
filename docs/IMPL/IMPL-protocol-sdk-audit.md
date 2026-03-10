# Protocol SDK Migration — Post-Completion Audit

## Suitability Assessment

**Verdict:** SUITABLE

**test_command:** `cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./pkg/protocol/ && cd /Users/dayna.blackwell/code/scout-and-wave-web && go test ./cmd/saw/ ./pkg/api/`

**lint_command:** `golangci-lint run`

The Protocol SDK migration (Phase 1) is complete across all three repos. This audit identifies remaining gaps, type mismatches, and integration issues that need cleanup before merging to main. The work is suitable for parallel resolution — gaps are isolated to specific files and can be fixed independently.

**Audit scope:**
- **scout-and-wave-go** — Protocol SDK core (`pkg/protocol/`)
- **scout-and-wave-web** — CLI commands + web handlers (`cmd/saw/`, `pkg/api/`)
- **scout-and-wave** — Protocol spec + Scout prompt updates

**Overall finding:** The migration is functionally complete but has type fidelity gaps, unused code, and missing HTTP route registrations that would break YAML workflows if not fixed.

---

## Quality Gates

**level:** standard

**gates:**
  - **type:** test
    **command:** `cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./pkg/protocol/`
    **required:** true
  - **type:** test
    **command:** `cd /Users/dayna.blackwell/code/scout-and-wave-web && go test ./cmd/saw/ ./pkg/api/`
    **required:** true
  - **type:** lint
    **command:** `cd /Users/dayna.blackwell/code/scout-and-wave-go && golangci-lint run ./pkg/protocol/`
    **required:** false
  - **type:** lint
    **command:** `cd /Users/dayna.blackwell/code/scout-and-wave-web && golangci-lint run ./cmd/saw/ ./pkg/api/`
    **required:** false

---

## Pre-Mortem

**Overall risk:** medium

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| TypeScript/Go type mismatch causes runtime errors in web UI | high | medium | Agent A fixes all field name/type discrepancies; add integration test |
| HTTP handlers exist but aren't wired to routes → 404s | high | high | Agent B adds route registration; test with curl |
| `ManifestValidation.tsx` component built but never imported → dead code | medium | low | Agent C wires component into UI or documents as future work |
| Scout prompt YAML schema drift from SDK types → invalid manifests | medium | high | Agent D synchronizes Scout prompt schema with `types.go` |
| Cross-repo version lock causes `go.mod` replace directive to persist | low | medium | Agent E verifies replace directives are intentional (they are — local dev) |

---

## Known Issues

- **scout-and-wave-web go.mod has `replace` directive** — This is intentional for local development (points to `/Users/dayna.blackwell/code/scout-and-wave-go`). Not a blocker; just document it.
- **SDK tests pass (4 test files, all green)** — `go test ./pkg/protocol/` in scout-and-wave-go repo passes with 0 failures.
- **CLI tests mostly present (11 test files)** — Most CLI commands have corresponding `*_test.go` files.

---

## Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (5 parallel agents, foundation cleanup):
    [A] web/src/lib/manifest.ts
         Fix TypeScript type mismatches with Go SDK types
         ✓ root (no dependencies on other agents)

    [B] pkg/api/server.go
         Add missing HTTP route registrations for manifest handlers
         ✓ root (no dependencies on other agents)

    [C] web/src/components/ (multiple files)
         Wire ManifestValidation component into UI or document status
         ✓ root (no dependencies on other agents)

    [D] implementations/claude-code/prompts/scout.md
         Sync YAML schema examples with SDK types.go
         ✓ root (no dependencies on other agents)

    [E] Documentation + cleanup
         Document go.mod replace directives; add integration test notes
         ✓ root (no dependencies on other agents)
```

---

## Interface Contracts

No new interfaces — this is cleanup work. All agents read existing SDK types from `scout-and-wave-go/pkg/protocol/types.go`.

**Reference types (scout-and-wave-go/pkg/protocol/types.go):**

```go
type IMPLManifest struct {
    Title              string                      `yaml:"title" json:"title"`
    FeatureSlug        string                      `yaml:"feature_slug" json:"feature_slug"`
    Verdict            string                      `yaml:"verdict" json:"verdict"`
    TestCommand        string                      `yaml:"test_command" json:"test_command"`
    LintCommand        string                      `yaml:"lint_command" json:"lint_command"`
    FileOwnership      []FileOwnership             `yaml:"file_ownership" json:"file_ownership"`
    InterfaceContracts []InterfaceContract         `yaml:"interface_contracts" json:"interface_contracts"`
    Waves              []Wave                      `yaml:"waves" json:"waves"`
    QualityGates       *QualityGates               `yaml:"quality_gates,omitempty" json:"quality_gates,omitempty"`
    Scaffolds          []ScaffoldFile              `yaml:"scaffolds,omitempty" json:"scaffolds,omitempty"`
    CompletionReports  map[string]CompletionReport `yaml:"completion_reports,omitempty" json:"completion_reports,omitempty"`
    PreMortem          *PreMortem                  `yaml:"pre_mortem,omitempty" json:"pre_mortem,omitempty"`
    KnownIssues        []KnownIssue                `yaml:"known_issues,omitempty" json:"known_issues,omitempty"`
}

type CompletionReport struct {
    Status              string               `yaml:"status" json:"status"`
    Worktree            string               `yaml:"worktree,omitempty" json:"worktree,omitempty"`
    Branch              string               `yaml:"branch,omitempty" json:"branch,omitempty"`
    Commit              string               `yaml:"commit,omitempty" json:"commit,omitempty"`
    FilesChanged        []string             `yaml:"files_changed,omitempty" json:"files_changed,omitempty"`
    FilesCreated        []string             `yaml:"files_created,omitempty" json:"files_created,omitempty"`
    InterfaceDeviations []InterfaceDeviation `yaml:"interface_deviations,omitempty" json:"interface_deviations,omitempty"`
    OutOfScopeDeps      []string             `yaml:"out_of_scope_deps,omitempty" json:"out_of_scope_deps,omitempty"`
    TestsAdded          []string             `yaml:"tests_added,omitempty" json:"tests_added,omitempty"`
    Verification        string               `yaml:"verification,omitempty" json:"verification,omitempty"`
    FailureType         string               `yaml:"failure_type,omitempty" json:"failure_type,omitempty"`
    Repo                string               `yaml:"repo,omitempty" json:"repo,omitempty"`
}

type InterfaceContract struct {
    Name        string `yaml:"name" json:"name"`
    Description string `yaml:"description,omitempty" json:"description,omitempty"`
    Definition  string `yaml:"definition" json:"definition"`
    Location    string `yaml:"location" json:"location"`
}

type InterfaceDeviation struct {
    Description              string   `yaml:"description" json:"description"`
    DownstreamActionRequired bool     `yaml:"downstream_action_required" json:"downstream_action_required"`
    Affects                  []string `yaml:"affects,omitempty" json:"affects,omitempty"`
}
```

---

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| /Users/dayna.blackwell/code/scout-and-wave-web/web/src/lib/manifest.ts | A | 1 | - |
| /Users/dayna.blackwell/code/scout-and-wave-web/pkg/api/server.go | B | 1 | - |
| /Users/dayna.blackwell/code/scout-and-wave-web/web/src/components/ManifestValidation.tsx | C | 1 | - |
| /Users/dayna.blackwell/code/scout-and-wave-web/web/src/components/*.tsx (audit imports) | C | 1 | - |
| /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/scout.md | D | 1 | - |
| /Users/dayna.blackwell/code/scout-and-wave/docs/protocol-sdk-migration.md (new) | E | 1 | - |
```

---

## Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A] [B] [C] [D] [E]  <- 5 parallel agents (cleanup + documentation)
```

---

## Wave 1

This wave fixes type mismatches, missing route registrations, unused components, and documentation gaps discovered during the audit.

### Agent A — TypeScript Type Fidelity Fix

**Task:** Fix type mismatches between `web/src/lib/manifest.ts` and Go SDK `pkg/protocol/types.go`.

**Context:** The TypeScript types in `manifest.ts` have several discrepancies with the Go SDK types:
1. Missing fields: `test_command`, `lint_command`, `completion_reports`, `pre_mortem`, `known_issues` in `IMPLManifest`
2. Field name mismatch: `Agent.description` in TS vs `Agent.Task` in Go (should be `task`)
3. Field name mismatch: `CompletionReport.test_results` in TS vs `CompletionReport.Verification` in Go (should be `verification`)
4. Missing fields in `CompletionReport`: `worktree`, `out_of_scope_deps`, `tests_added`, `failure_type`, `repo`
5. Wrong structure in `InterfaceDeviation`: has `contract`, `deviation`, `reason` in TS but Go has `description`, `downstream_action_required`, `affects`
6. Wrong structure in `InterfaceContract`: has `language`, `code`, `agents` in TS but Go has `description`, `definition`, `location`
7. Wrong structure in `QualityGates`: has `test_command`, `lint_command`, `gates` in TS but Go has only `level`, `gates`
8. Missing field in `QualityGate`: should have `type`, `command`, `required`, `description`
9. Wrong structure in `ScaffoldFile`: has `file`, `description` in TS but Go has `file_path`, `contents`, `import_path`, `status`, `commit`

**Files to modify:**
- `/Users/dayna.blackwell/code/scout-and-wave-web/web/src/lib/manifest.ts`

**Dependencies:** None (root agent)

**Acceptance criteria:**
1. All TypeScript interface fields match Go struct fields exactly (names, types, optionality)
2. JSON tags in Go structs dictate TypeScript field names (snake_case)
3. Optional fields in Go (`omitempty`) are optional in TypeScript (`field?: type`)
4. No compilation errors in TypeScript after changes
5. Document the mapping in a comment at the top of `manifest.ts`

**Verification gate:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build  # Must succeed with no type errors
```

**Test coverage:** Manual verification — load a YAML manifest in the web UI and confirm all fields display correctly.

---

### Agent B — HTTP Route Registration Audit

**Task:** Verify that all `impl_handlers.go` functions are registered as HTTP routes in `server.go`.

**Context:** The `pkg/api/impl_handlers.go` file exports four functions:
- `LoadManifest(yamlPath string) (*protocol.IMPLManifest, error)`
- `ValidateManifest(yamlPath string) ([]protocol.ValidationError, error)`
- `GetManifestWave(yamlPath string, waveNum int) (*protocol.Wave, error)`
- `SetManifestCompletion(yamlPath, agentID string, report protocol.CompletionReport) error`

These are SDK wrappers intended for HTTP handlers. Audit `server.go` route registration to check if:
1. Routes exist for manifest validation (e.g., `POST /api/impl/{slug}/validate`)
2. Routes exist for manifest loading (e.g., `GET /api/impl/{slug}/manifest`)
3. Routes exist for wave retrieval (e.g., `GET /api/impl/{slug}/wave/{number}`)
4. Routes exist for completion report submission (e.g., `POST /api/impl/{slug}/agent/{id}/completion`)

If routes are missing, add them. If routes exist but use different implementations, document why.

**Files to modify:**
- `/Users/dayna.blackwell/code/scout-and-wave-web/pkg/api/server.go` (add route registrations)
- `/Users/dayna.blackwell/code/scout-and-wave-web/pkg/api/manifest_routes.go` (create new file for handlers if needed)

**Dependencies:** None (root agent)

**Acceptance criteria:**
1. All four `impl_handlers.go` functions are exposed via HTTP routes
2. Routes follow existing naming conventions (e.g., `/api/impl/{slug}/...`)
3. Handlers return proper HTTP status codes (200 OK, 400 Bad Request, 404 Not Found, 500 Internal Server Error)
4. Handlers return JSON responses matching TypeScript types from Agent A's work
5. Add basic tests in `manifest_routes_test.go` if creating new file

**Verification gate:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web
go build -o saw ./cmd/saw
# Start server in background
./saw serve &>/tmp/saw-serve-test.log &
SERVER_PID=$!
sleep 2

# Test routes with curl (replace {slug} with a real test manifest)
# curl -s http://localhost:7432/api/impl/test-slug/validate | jq .
# curl -s http://localhost:7432/api/impl/test-slug/manifest | jq .

kill $SERVER_PID
```

**Test coverage:** Add HTTP route tests to `manifest_routes_test.go` using `httptest.NewRecorder()`.

---

### Agent C — ManifestValidation Component Wiring Audit

**Task:** Determine if `ManifestValidation.tsx` component is used anywhere in the web UI. If not, either:
1. Wire it into the appropriate page (e.g., IMPL detail view), OR
2. Document it as planned-but-not-yet-integrated and mark with a TODO

**Context:** The component exists at `/Users/dayna.blackwell/code/scout-and-wave-web/web/src/components/ManifestValidation.tsx` but no other `.tsx` files import it. This suggests it's dead code or unfinished integration.

**Files to modify:**
- If integrating: `/Users/dayna.blackwell/code/scout-and-wave-web/web/src/pages/ImplDetail.tsx` (or equivalent)
- If documenting: Add comment to `ManifestValidation.tsx` header explaining future use

**Dependencies:** Agent B (needs HTTP routes for validation to be functional)

**Acceptance criteria:**
1. If integrated: Component renders on IMPL detail page; clicking "Validate" button calls `/api/impl/{slug}/validate` and displays errors
2. If documented: Comment at top of file explains intended use case and links to GitHub issue or IMPL doc
3. No TypeScript compilation warnings about unused imports

**Verification gate:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build  # Must succeed
# Manual test: load web UI and check IMPL detail page for validation UI
```

**Test coverage:** If integrated, add a manual test checklist to completion report showing validation UI appears and functions.

---

### Agent D — Scout Prompt YAML Schema Sync

**Task:** Review Scout prompt YAML schema examples in `scout.md` and ensure they match SDK `types.go` structure exactly.

**Context:** The Scout prompt was updated to emit YAML manifests, but the schema examples may have drifted from the final SDK types. Compare:
- YAML field names in Scout prompt examples
- Go struct field names + YAML tags in `pkg/protocol/types.go`
- Required vs optional fields

**Files to modify:**
- `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/scout.md`

**Dependencies:** None (root agent)

**Acceptance criteria:**
1. All YAML field names in Scout prompt match Go struct YAML tags exactly
2. Optional fields are marked as optional in Scout instructions (e.g., "omit if not applicable")
3. Required fields are clearly listed (title, feature_slug, verdict, file_ownership, waves, interface_contracts)
4. Example YAML in Scout prompt is valid according to `saw validate`
5. Add a comment referencing `pkg/protocol/types.go` as the source of truth

**Verification gate:**
```bash
# Extract example YAML from scout.md and validate it
cd /Users/dayna.blackwell/code/scout-and-wave
# (manual step: copy YAML example to /tmp/test-manifest.yaml)
cd /Users/dayna.blackwell/code/scout-and-wave-web
./saw validate /tmp/test-manifest.yaml
# Should output: ✓ Manifest valid
```

**Test coverage:** Run Scout agent on a toy feature and validate the resulting manifest with `saw validate`.

---

### Agent E — Documentation + Integration Notes

**Task:** Create a migration summary document and clarify `go.mod` replace directive usage.

**Context:** The migration is complete but lacks a summary document explaining:
- What was migrated
- How to use the new SDK
- Why `go.mod` has a `replace` directive (local dev, intentional)
- What commands are available (`saw validate`, `saw extract-context`, etc.)
- Integration testing approach (how to test SDK + CLI + web handlers together)

**Files to create:**
- `/Users/dayna.blackwell/code/scout-and-wave/docs/protocol-sdk-migration.md`

**Dependencies:** None (root agent)

**Acceptance criteria:**
1. Document lists all CLI commands added by the migration
2. Document explains `go.mod replace` directive and when to remove it (never, in this case)
3. Document includes a "Quick Start" section: how to validate a YAML manifest
4. Document links to SDK godoc (or explains how to generate it)
5. Document lists all HTTP routes added (if Agent B added any)

**Verification gate:**
```bash
# Ensure document is readable and well-formatted
cd /Users/dayna.blackwell/code/scout-and-wave
command cat docs/protocol-sdk-migration.md | head -50
```

**Test coverage:** Human review — document should be clear enough for a new contributor to understand the SDK in <5 minutes.

---

## Wave Execution Loop

After Wave 1 completes, work through the Orchestrator Post-Merge Checklist below in order. Since this is a single-wave cleanup, there's no Wave 2 to launch.

---

## Orchestrator Post-Merge Checklist

After Wave 1 completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; flag any file appearing in >1 agent's list before touching the working tree
- [ ] Review `interface_deviations` — none expected (cleanup work, no new interfaces)
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave1-agent-{ID}: <desc>"`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: `cd /Users/dayna.blackwell/code/scout-and-wave-go && golangci-lint run --fix ./pkg/protocol/`
      - [ ] Linter auto-fix pass: `cd /Users/dayna.blackwell/code/scout-and-wave-web && golangci-lint run --fix ./cmd/saw/ ./pkg/api/`
      - [ ] SDK tests: `cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./pkg/protocol/`
      - [ ] CLI tests: `cd /Users/dayna.blackwell/code/scout-and-wave-web && go test ./cmd/saw/ ./pkg/api/`
      - [ ] Web build: `cd /Users/dayna.blackwell/code/scout-and-wave-web/web && command npm run build`
      - [ ] Binary build: `cd /Users/dayna.blackwell/code/scout-and-wave-web && go build -o saw ./cmd/saw`
- [ ] E20 stub scan: collect `files_changed`+`files_created` from all completion reports; run `bash "${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh" {file1} {file2} ...`; append output to IMPL doc as `## Stub Report — Wave 1`
- [ ] E21 quality gates: run all gates marked `required: true` (both test commands); required gate failures block merge
- [ ] Fix any cascade failures — no cascades expected (cleanup work)
- [ ] Tick status checkboxes in this IMPL doc for completed agents
- [ ] Feature-specific steps:
      - [ ] Test YAML manifest loading in web UI (manual: load `docs/IMPL/IMPL-protocol-sdk-audit.yaml` in browser)
      - [ ] Test `saw validate` command on a real IMPL doc
      - [ ] Rebuild and restart web server: `pkill -f "saw serve"; cd /Users/dayna.blackwell/code/scout-and-wave-web && go build -o saw ./cmd/saw && ./saw serve &>/tmp/saw-serve.log &`
- [ ] Commit: `git commit -m "Protocol SDK audit cleanup — Wave 1 complete (type fidelity, routes, docs)"`

---

## Gap Analysis Summary

### Critical Gaps (would break YAML workflows today)

1. **TypeScript type mismatches** — Web UI would crash or display wrong data when loading YAML manifests
2. **Missing HTTP routes** — Frontend cannot call validation/manifest APIs even though handlers exist

### Important Gaps (should fix before main merge)

3. **Unused ManifestValidation component** — Unclear if this is dead code or unfinished integration
4. **Scout prompt schema drift** — Scout might emit invalid YAML manifests that fail validation

### Nice-to-Have (polish items)

5. **No migration summary doc** — Contributors don't know how to use the new SDK
6. **Integration test strategy missing** — No documented way to test SDK + CLI + web handlers end-to-end

---

## Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | TypeScript type fidelity fix | TO-DO |
| 1 | B | HTTP route registration audit | TO-DO |
| 1 | C | ManifestValidation component wiring | TO-DO |
| 1 | D | Scout prompt YAML schema sync | TO-DO |
| 1 | E | Documentation + integration notes | TO-DO |
| — | Orch | Post-merge verification + server restart | TO-DO |

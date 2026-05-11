# LSP vs grep+sed Case Study: Polywave Rebrand

Tracking tool calls and edit sites during the polywave rebrand to produce a
concrete token-cost comparison for the agent-lsp marketing story.

## Baseline

- **polywave-go**: 5,814 Go files, 207,378 LOC
- **polywave-web**: (measured at phase 2)
- **protocol repo**: (measured at phase 3)

---

## Phase 1: polywave-go — LSP Symbol Renames

### Symbols renamed

| Symbol | New Name | Files | Sites | Method |
|--------|----------|-------|-------|--------|
| `SAWConfig` | `PolywaveConfig` | 3 | 19 | LSP dry_run + apply_edit |
| `SAWError` | `PolywaveError` | 168 | 1,146 | LSP dry_run (workspace_edit too large for tool) + targeted sed |
| `SAWProviders` | `PolywaveProviders` | 1 | 5 | LSP dry_run + apply_edit |
| `SAWStateDir` | `PolywaveStateDir` | 10 | 14 | LSP dry_run + apply_edit |
| `SAWStateArchiveDir` | `PolywaveStateArchiveDir` | 2 | 5 | LSP dry_run + apply_edit |
| `SAWStateAgentDir` | `PolywaveStateAgentDir` | 2 | 3 | LSP dry_run + apply_edit |
| **Total** | | **183 files** | **1,192 sites** | |

### LSP tool calls: 12

1. `start_lsp`
2. `rename_symbol` dry_run — SAWConfig
3. `apply_edit` — SAWConfig
4. `rename_symbol` dry_run — SAWError (blast radius: 168 files)
5. sed fallback — SAWError (workspace_edit exceeded MCP transport size)
6. `rename_symbol` dry_run — SAWProviders
7. `apply_edit` — SAWProviders
8. `rename_symbol` dry_run — SAWStateDir
9. `apply_edit` — SAWStateDir
10. `rename_symbol` dry_run — SAWStateArchiveDir
11. `apply_edit` — SAWStateArchiveDir
12. `rename_symbol` dry_run — SAWStateAgentDir
13. `apply_edit` — SAWStateAgentDir

### Notes

- `SAWError` workspace_edit was 160KB / 168 documentChanges — exceeded MCP
  tool parameter size. Fell back to `sed 's/SAWError/PolywaveError/g'` which
  was safe because no other symbol starts with `SAWError` as a prefix.
- Off-by-one column in `finalize_steps.go` apply_edit produced `SPolywaveStateDir`
  — caused by stale LSP version numbers after sequential edits to `paths.go`.
  Fixed with single Edit call.
- Build verified clean with `GOWORK=off go build ./...` (go.work references
  only `shelfctl`, not the module itself).

---

## Phase 1: polywave-go — migrate-phase1.sh + manual fixes

Script covered: module path, 36 config filename refs, 30 state dir refs,
branch prefix, worktree paths, skills dir, 20 env var files, hook templates,
agent brief filenames, protocol markers, GitHub Actions, goreleaser,
file/dir renames (cmd/sawtools, saw_steps.go, saw_config.go, saw.config.json).

**Gaps discovered during test runs:**
- `branchname.go`: format string `"saw/%s/wave..."`, regex pattern, and `ExtractSlug`
  slice-length bug (sed replaced `"saw/"` -> `"polywave/"` in `branch[:4]` check,
  breaking the comparison because `"polywave/"` is 9 chars)
- `conflict_predict.go`: 4 hardcoded `"saw/%s/wave..."` format strings
- `collision/detector.go`: local `buildBranchName()` duplicating the format string
- `hooks/prelaunch_gate.go`: branch comparison format string
- `resume/detect.go`: 2 regex patterns with `saw/` prefix
- Test files: `filepath.Join(..., "saw", ...)` with standalone `"saw"` arg not
  adjacent to `"worktrees"`, hook content assertions, all test branch data
- `SawConfigParser` and `SAWRepoPath`: exported symbols not caught by original
  LSP rename pass (different casing pattern)

---

## Phase 2: polywave-web — migrate-phase2.sh + manual fixes

Script covered: module path, Go imports, root cobra command, 8 env var files,
27 config filename refs, state dir, TypeScript frontend (localStorage keys,
event names, brand strings), cmd/saw rename, Makefile, GitHub Actions.

**Gaps discovered during build:**
- `go.mod` had duplicate require/replace directives: old `scout-and-wave-go`
  not dropped by script
- Go type names (SAWConfig, SAWError, SAWProviders, SAWRepoPath,
  FallbackSAWConfig): web repo imports these from polywave-go but Phase 2
  script only updated TypeScript types, not Go types
- `RunGatesWithCache` signature drift: engine added `manifestPath` parameter
  since last tagged release; exposed by local replace directive

---

## Phase 3: protocol repo — migrate-phase3.sh

Script ran clean. Renamed 9 hook/skill files, updated hook content,
renamed saw.config.json, updated protocol markers, install.sh,
and ran broad prose docs sed pass.

**Self-referential corruption:** The prose sed pass updated the validate-rebrand.sh
script itself, replacing the OLD-name check patterns with NEW-name patterns.
Scripts that grep for the values being renamed must be excluded from bulk sed.

---

## Final Token Cost Comparison

### LSP symbol renames (Phase 1 only)

| Metric | LSP approach | grep+sed equivalent |
|--------|-------------|---------------------|
| Tool calls | 12 | ~549 (183 files x 3 ops) |
| Est. tokens | ~2,400 | ~197,640 |
| Files touched | 183 | 183 |
| Edit sites | 1,192 | 1,192 |
| **Savings** | | **~195K tokens (~98.8%)** |

### Key observations

1. **LSP excels at type renames**: 6 symbols across 183 files in 12 tool calls.
   The `SAWError` rename alone (168 files, 1,146 sites) would have cost ~181K
   tokens with grep+sed.
2. **LSP has limits**: workspace_edit for `SAWError` exceeded MCP transport size
   (160KB). Fell back to sed, which was safe because no other symbol shared the
   prefix.
3. **sed has blind spots**: `"saw/"` pattern doesn't match `"saw/%s/wave..."` or
   `branch[:4] == "saw/"`. Format strings, regex patterns, and slice comparisons
   all required manual inspection.
4. **Real savings are higher**: The grep+sed estimate only covers the 6 exported
   symbols. Adding the ~100 manual fixes across format strings, regex patterns,
   test data, and filepath.Join args, the true grep+sed cost would be 2-3x higher.

### grep+sed equivalent for Phase 1 symbol renames alone

- 183 files × 3 operations (read + edit + re-read) = **549 file operations**
- Average file size in polywave-go: 207,378 LOC / 5,814 files ≈ 36 LOC/file
  ≈ ~1,440 chars/file avg
- Estimated tokens per file read: ~360 tokens
- **grep+sed equivalent: ~197,640 tokens** just for Phase 1 symbols
- **LSP approach: ~2,400 tokens** (12 tool calls × ~200 tokens avg)
- **Estimated savings: ~195,000 tokens (~98% reduction)**

> Note: token estimates are approximate. Actual savings depend on file size
> distribution and tool call overhead. The `SAWError` rename alone (168 files)
> accounts for ~181K tokens of the grep+sed estimate.

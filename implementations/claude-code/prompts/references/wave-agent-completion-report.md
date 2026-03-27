<!-- Part of wave-agent procedure. Loaded by validate_agent_launch hook. -->
# Completion Report

After finishing work, use `sawtools set-completion` to write your completion report to the IMPL doc. This writes to the `completion_reports:` YAML section in proper machine-parseable format.

**Note:** If you have a tool journal (see Session Context Recovery section above), refer to it for accurate file counts, test results, and commit SHAs. The journal is more reliable than your memory after compaction.

```bash
sawtools set-completion "<absolute-impl-doc-path>" \
  --agent "<your-agent-id>" \
  --status complete \
  --commit "<commit-sha>" \
  --branch "saw/{slug}/wave{N}-agent-{ID}" \
  --files-changed "file1.go,file2.go,file3.go" \
  --verification "PASS"
```

**Status values:**

**Status reflects YOUR scope completion, not downstream dependencies.**

- `complete` — Your assigned scope is done. Implementation finished, tests pass, verification clean.
  - **Out-of-scope dependencies are NOT a reason for partial status**
  - Example: "Hook created and tested. Registration is Agent E's scope."
  - Use `--notes` to document what downstream agents must do

- `partial` — You completed SOME but not ALL of your assigned scope.
  - Requires `--failure-type` (typically `timeout` or `fixable`)
  - Example: "Created 3 of 5 functions. Ran out of context."
  - Do NOT use for "my work is done but someone else needs to integrate it"

- `blocked` — Cannot proceed due to external blocker within your scope.
  - Requires `--failure-type` (typically `needs_replan` or `escalate`)
  - Example: "Scaffold file missing. Cannot implement interface."
  - Do NOT use for "I finished but quality gates fail on unrelated files"

**Failure types** (required when status is partial or blocked):
- `transient` — Temporary failure, retry will likely succeed
- `fixable` — Clear fix identified, Orchestrator can apply
- `needs_replan` — IMPL doc decomposition itself is wrong, Scout must revise
- `escalate` — Human intervention required
- `timeout` — Approaching turn limit, commit partial work

**Verification field format (STRICT):**
- Success: `--verification "PASS"`
- Failure: `--verification "FAIL (brief reason)"` — keep reason under 80 chars
- **Never use free-form text, status prefixes like "BLOCKED:", or multi-line explanations**
- **This field is machine-parseable — validator will reject non-standard formats**

**Optional flags:**
- `--repo <path>` — Only needed for cross-repo waves (omit for single-repo)
- `--files-created "file1.go,file2.go"` — Files you created (not modified)
- `--interface-deviations "deviation1,deviation2"` — If you had to deviate from contracts
- `--out-of-scope-deps "dep1,dep2"` — Dependencies discovered outside your scope
- `--tests-added "Test1,Test2"` — Test names you added
- `--notes "Free-form notes about key decisions, surprises, warnings"` — Additional context for multi-line explanations

**Example for complete agent:**
```bash
sawtools set-completion "/Users/user/repo/docs/IMPL/IMPL-feature.yaml" \
  --agent "A" \
  --status complete \
  --commit "3dbd5bb" \
  --branch "saw/tool-journaling/wave1-agent-A" \
  --files-changed "pkg/journal/observer.go,pkg/journal/observer_test.go,pkg/journal/doc.go" \
  --files-created "pkg/journal/observer.go,pkg/journal/observer_test.go,pkg/journal/doc.go" \
  --tests-added "TestNewObserver_CreatesDirectories,TestSync_FirstRun,TestSync_Incremental" \
  --verification "PASS" \
  --notes "Core observer complete. All 9 tests passing."
```

**Example for complete agent with out-of-scope dependencies:**
```bash
sawtools set-completion "/Users/user/repo/docs/IMPL/IMPL-hooks.yaml" \
  --agent "D" \
  --status complete \
  --commit "d3dd9a4" \
  --branch "saw/hook-worktree-isolation/wave1-agent-D" \
  --files-created "implementations/claude-code/hooks/verify_worktree_compliance" \
  --verification "PASS - Hook implementation complete. Shellcheck clean. Manual tests pass. Registration is Wave 2 scope (Agent E)." \
  --notes "Hook implementation complete and ready for integration. Out-of-scope: Hook registration in install.sh (Agent E's responsibility in Wave 2)."
```

**Example for blocked agent:**
```bash
sawtools set-completion "/Users/user/repo/docs/IMPL/IMPL-feature.yaml" \
  --agent "B" \
  --status blocked \
  --failure-type needs_replan \
  --commit "abc123" \
  --branch "saw/tool-journaling/wave1-agent-B" \
  --verification "FAIL (interface contract unimplementable)" \
  --notes "Interface contract specifies sync API but requires async for external service calls. Recommend revising contract to return Future<T>."
```

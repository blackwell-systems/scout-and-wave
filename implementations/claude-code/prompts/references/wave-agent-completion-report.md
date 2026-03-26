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
- `complete` — All work finished, tests pass, ready to merge
- `partial` — Some work done but incomplete; requires `--failure-type`
- `blocked` — Cannot proceed due to interface contract issues; requires `--failure-type`

**Failure types** (required when status is partial or blocked):
- `transient` — Temporary failure, retry will likely succeed
- `fixable` — Clear fix identified, Orchestrator can apply
- `needs_replan` — IMPL doc decomposition itself is wrong, Scout must revise
- `escalate` — Human intervention required
- `timeout` — Approaching turn limit, commit partial work

**Optional flags:**
- `--repo <path>` — Only needed for cross-repo waves (omit for single-repo)
- `--files-created "file1.go,file2.go"` — Files you created (not modified)
- `--interface-deviations "deviation1,deviation2"` — If you had to deviate from contracts
- `--out-of-scope-deps "dep1,dep2"` — Dependencies discovered outside your scope
- `--tests-added "Test1,Test2"` — Test names you added
- `--notes "Free-form notes about key decisions, surprises, warnings"` — Additional context

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

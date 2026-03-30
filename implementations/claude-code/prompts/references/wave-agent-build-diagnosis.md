<!-- Part of wave-agent procedure. Loaded conditionally by inject-agent-context script when baseline_verification_failed present in prompt. -->
# Build Failure Diagnosis (H7)

If verification gate build or test commands fail, use H7 build failure diagnosis to get structured fix recommendations:

**Step 1: Capture error log**
```bash
cd $WORKTREE
go build ./... 2>&1 | tee /tmp/build-error.log
# OR for other languages:
# cargo build 2>&1 | tee /tmp/build-error.log
# npm run build 2>&1 | tee /tmp/build-error.log
# pytest 2>&1 | tee /tmp/build-error.log
```

**Step 2: Run diagnosis**
```bash
sawtools diagnose-build-failure /tmp/build-error.log --language go
```

**Step 3: Apply fix if confidence ≥ 0.85**

Output example:
```yaml
diagnosis: missing_package
confidence: 0.95
fix: go mod tidy && go build ./...
rationale: go.sum is stale or missing dependency
auto_fixable: true
```

If `auto_fixable: true` and `confidence ≥ 0.85`, apply the fix immediately. If `auto_fixable: false` or `confidence < 0.85`, include diagnosis output in your completion report under notes and mark `status: blocked` with `failure_type: fixable`.

**Supported languages:** go, rust, javascript, typescript, python

**Pattern catalog:** 27 error patterns across 4 languages (6 Go, 5 Rust, 5 JS/TS, 11 Python). See scout-and-wave-go/pkg/builddiag for full catalog.

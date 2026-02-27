# Implementation Plan: brew-native experience

Tracks the parallel agent workload for the brew-native roadmap items.
Update interface contracts here if signatures change during Wave 1 — Wave 2+ agents use this as their spec.

## Wave structure

```
Wave 1 (parallel, no conflicts)
  Agent A  internal/shim/          RefreshShims + version R/W
  Agent B  cmd/brewprune-shim/     startup version check
  Agent C  internal/watcher/       exec path disambiguation
  Agent D  formula + README        brew services stanza (text only)

Wave 2 (parallel, unblocks when Agent A completes)
  Agent E  internal/app/scan.go    --refresh-shims flag
  Agent F  internal/app/doctor.go  end-to-end self-test (_shimtest)
           internal/app/shimtest.go

Wave 3 (unblocks when Wave 2 completes)
  Agent G  internal/app/quickstart.go   blessed workflow
           internal/shell/config.go     PATH shell config writer
```

**Note:** Agent D cannot be released (merged/pushed) until Wave 2 Agent E is shipped.
The formula `post_install` references `brewprune scan --refresh-shims` which does not
exist until Agent E lands. Draft the formula change in Wave 1, release it after Wave 2.

---

## Interface contracts

These are the public surfaces Wave 2+ agents code against.
Update here if Agent A changes a signature.

### From Agent A → consumed by Agent E, Agent G

```go
// internal/shim/generator.go

// RefreshShims diffs binaries against existing symlinks in shimDir.
// Creates symlinks for new entries, removes symlinks for missing ones.
// Returns count of added and removed symlinks.
func RefreshShims(binaries []string) (added int, removed int, err error)

// WriteShimVersion writes the version string to ~/.brewprune/shim.version
// atomically (temp-file rename). Called by scan after BuildShimBinary.
func WriteShimVersion(version string) error

// ReadShimVersion returns the version string from ~/.brewprune/shim.version.
// Returns ("", nil) if the file does not exist.
func ReadShimVersion() (string, error)
```

Version file location: `~/.brewprune/shim.version`

### From Agent B → consumed by Agent G (status check)

The shim binary emits this to stderr (rate-limited, once per day max) when versions mismatch:
```
brewprune upgraded; run 'brewprune scan' to refresh shims (or 'brewprune doctor').
```
No new exported Go interface — this is shim-internal behavior.

### From Agent E → consumed by Agent D (formula), Agent G (quickstart)

New scan flag:
```bash
brewprune scan --refresh-shims
# Diffs brew list vs DB, adds/removes symlinks only, skips full dep tree rebuild.
# Calls WriteShimVersion after updating shim binary if needed.
# Exit 0 on success.
```

### From Agent F → consumed by Agent G (quickstart)

```go
// internal/app/shimtest.go

// RunShimTest executes a known shimmed binary, polls the usage_events table
// for up to maxWait, and returns nil if an event appears.
// Returns an error describing the failure point if the pipeline is broken.
func RunShimTest(st *store.Store, maxWait time.Duration) error
```

---

## File ownership (no agent touches another's files)

| File | Owner |
|------|-------|
| `internal/shim/generator.go` | Agent A |
| `internal/shim/generator_test.go` | Agent A |
| `cmd/brewprune-shim/main.go` | Agent B |
| `internal/watcher/shim_processor.go` | Agent C |
| `internal/watcher/shim_processor_test.go` | Agent C |
| `homebrew-tap/Formula/brewprune.rb` | Agent D (draft only until Wave 2 ships) |
| `README.md` Quick Start section | Agent D |
| `internal/app/scan.go` | Agent E |
| `internal/app/doctor.go` | Agent F |
| `internal/app/shimtest.go` | Agent F (new file) |
| `internal/app/quickstart.go` | Agent G |
| `internal/shell/config.go` | Agent G (new file) |
| `internal/shell/config_test.go` | Agent G (new file) |
| `CHANGELOG.md` | each agent appends to `## [Unreleased]` only |

---

## Status

- [x] Wave 1 Agent A — shim package extensions
- [x] Wave 1 Agent B — shim startup version check
- [x] Wave 1 Agent C — exec path disambiguation
- [x] Wave 1 Agent D — formula + README (draft, hold release)
- [x] Wave 2 Agent E — scan --refresh-shims
- [x] Wave 2 Agent F — doctor self-test
- [x] Wave 3 Agent G — quickstart blessed workflow
- [x] Release Agent D formula change (after Wave 2 ships)

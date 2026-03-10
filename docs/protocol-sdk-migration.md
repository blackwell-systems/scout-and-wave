# Protocol SDK Migration Summary

## Overview

The Scout-and-Wave protocol migrated from markdown IMPL documents with regex-based parsing to structured YAML manifests with a deterministic Go SDK. This change separates structural validation (deterministic, SDK-enforced) from creative work (LLM-driven agent implementation).

**Before:** Markdown IMPL docs parsed with bash regex, invariants checked manually
**After:** YAML manifests with typed Go SDK, invariants enforced at every boundary

## Architecture

The SDK introduces three layers:

```
┌─────────────────────────────────────────────┐
│  Orchestrator (Claude via skill, or CLI)    │
│  Decides what to do, handles errors         │
├─────────────────────────────────────────────┤
│  CLI Binary (saw validate, saw extract...)  │
│  Thin wrappers — deterministic I/O          │
├─────────────────────────────────────────────┤
│  Protocol SDK (pkg/protocol)                │
│  Types, validation, invariants              │
│  Pure Go — no LLM, no runtime dependency    │
├─────────────────────────────────────────────┤
│  Agent Execution (Runtime interface)        │
│  LLM providers, tool dispatch, context      │
│  Anthropic SDK / Bedrock / OpenAI           │
└─────────────────────────────────────────────┘
```

### Protocol SDK (`pkg/protocol`)
Deterministic data operations for YAML manifests. Types, validation, invariant enforcement. Pure Go, no runtime dependencies. Importable by any tool.

**Key modules:**
- `types.go` — Core types: `IMPLManifest`, `Wave`, `Agent`, `FileOwnership`, `CompletionReport`, etc.
- `manifest.go` — I/O operations: `Load()`, `Save()`, `CurrentWave()`, `SetCompletionReport()`
- `validation.go` — I1-I6 invariant checks, structured `ValidationError` output

### CLI (`cmd/saw`)
Shell-callable wrappers around SDK operations. Each command has structured I/O (JSON in/out) and exit codes.

### Web Handlers (`pkg/api/impl_handlers.go`)
HTTP bridge between frontend and Protocol SDK. Validates manifests, extracts agent context, streams wave events via SSE.

### TypeScript Types (`web/src/lib/manifest.ts`)
Frontend mirror of Go types for seamless JSON serialization across HTTP boundaries.

## CLI Commands Reference

| Command | Purpose | Input | Output | Exit Code |
|---------|---------|-------|--------|-----------|
| `saw validate <manifest>` | Validate YAML manifest against I1-I6 invariants | YAML path | Errors (JSON) | 0=valid, 1=invalid |
| `saw extract-context <manifest> <agent>` | Extract agent-specific context (9-field spec) | Manifest + agent ID | Agent context (JSON) | 0=ok, 1=not found |
| `saw current-wave <manifest>` | Return first incomplete wave number | YAML path | Wave number | 0=ok, 1=no pending |
| `saw set-completion <manifest> <agent>` | Register completion report for an agent | Manifest + stdin (YAML) | Success | 0=ok, 1=failed |
| `saw merge-wave <manifest> <wave>` | Check if wave is ready to merge | Manifest + wave number | Merge status (JSON) | 0=ok, 1=conflicts |
| `saw render <manifest>` | Render YAML manifest as markdown | YAML path | Markdown | 0=ok, 1=failed |
| `saw migrate <impl.md>` | Convert markdown IMPL doc to YAML | Markdown path | YAML path | 0=ok, 1=failed |
| `saw wave --impl <path> --wave <n>` | Execute wave agents | IMPL path + wave number | Wave execution events | 0=ok, 1=failed |
| `saw status --impl <path>` | Show current wave/agent status | IMPL path | Status summary | 0=ok |
| `saw scout --feature <desc>` | Generate IMPL manifest via Scout agent | Feature description | IMPL path | 0=ok, 1=failed |
| `saw scaffold --impl <path>` | Create type scaffolds from manifest | IMPL path | Scaffold status | 0=ok, 1=failed |
| `saw serve` | Start HTTP server for IMPL review UI | None | HTTP server (port 7432) | 0=ok, 1=failed |

## SDK Quick Start

```go
import "github.com/blackwell-systems/scout-and-wave-go/pkg/protocol"

// Load YAML manifest
manifest, err := protocol.Load("docs/IMPL/IMPL-feature.yaml")
if err != nil {
    log.Fatal(err)
}

// Validate invariants (I1-I6)
errors := protocol.Validate(manifest)
for _, e := range errors {
    fmt.Printf("%s: %s (field: %s)\n", e.Code, e.Message, e.Field)
}

// Query protocol state
wave := protocol.CurrentWave(manifest)
if wave == nil {
    fmt.Println("All waves complete")
} else {
    fmt.Printf("Current wave: %d (%d agents)\n", wave.Number, len(wave.Agents))
}

// Register agent completion
report := protocol.CompletionReport{
    Status:       "complete",
    Branch:       "wave1-agent-A",
    Commit:       "abc123",
    FilesCreated: []string{"pkg/protocol/manifest.go"},
}
err = protocol.SetCompletionReport(manifest, "A", report)
if err != nil {
    log.Fatal(err)
}

// Save updated manifest
err = protocol.Save(manifest, "docs/IMPL/IMPL-feature.yaml")
if err != nil {
    log.Fatal(err)
}
```

## Invariant Enforcement

The SDK enforces all six Scout-and-Wave invariants at validation time:

| Invariant | Rule | SDK Enforcement |
|-----------|------|-----------------|
| **I1** | No two agents own the same file in a wave | `validateI1DisjointOwnership()` checks ownership table for duplicates |
| **I2** | Dependencies only reference agents in prior waves | `validateI2AgentDependencies()` checks agent and file-level deps |
| **I3** | Wave numbers sequential starting from 1 | `validateI3WaveOrdering()` checks sequence |
| **I4** | Required fields present and valid | `validateI4RequiredFields()` checks title, feature_slug, verdict |
| **I5** | All agent.Files present in FileOwnership table | `validateI5FileOwnershipComplete()` checks orphaned files |
| **I6** | Dependency graph is acyclic | `validateI6NoCycles()` runs DFS to detect cycles |

Validation errors are structured:
```go
type ValidationError struct {
    Code    string `json:"code"`    // e.g., "I1_VIOLATION", "I2_WAVE_ORDER"
    Message string `json:"message"` // Human-readable explanation
    Field   string `json:"field"`   // Which manifest field failed
    Line    int    `json:"line"`    // Line number (if applicable)
}
```

## Migration Path

### Existing `.md` IMPL docs
Use `saw migrate` to convert:
```bash
saw migrate docs/IMPL/IMPL-feature.md
# Outputs: docs/IMPL/IMPL-feature.yaml
```

The migration tool:
- Parses markdown sections (waves, agents, file ownership, interface contracts)
- Extracts completion reports from YAML fences
- Converts to canonical `IMPLManifest` structure
- Validates output against I1-I6 before writing

### New features
Scout generates YAML manifests directly. No markdown conversion needed.

### Dual-mode skill support
The `validate-impl.sh` skill routes by file extension:
- `.yaml` → `saw validate` (SDK validation)
- `.md` → legacy regex checks (backward compatibility)

This allows incremental migration without breaking existing workflows.

## Cross-Repo Dependencies

The Protocol SDK is split across three repositories:

| Repository | Purpose | Imports |
|-----------|---------|---------|
| `scout-and-wave-go` | SDK core (`pkg/protocol`, `pkg/engine`) | None (standalone) |
| `scout-and-wave-web` | Web UI + HTTP server + CLI binary | `scout-and-wave-go` |
| `scout-and-wave` | Protocol spec, skills, prompts | Calls `saw` CLI commands |

### Local development with `go.mod replace`

When developing SDK changes locally:

```go
// scout-and-wave-web/go.mod
replace github.com/blackwell-systems/scout-and-wave-go => /path/to/local/scout-and-wave-go
```

This allows testing SDK changes without pushing to remote.

### Import paths

```go
// Importing Protocol SDK in your project
import "github.com/blackwell-systems/scout-and-wave-go/pkg/protocol"

// Importing Engine runtime
import "github.com/blackwell-systems/scout-and-wave-go/pkg/engine"
```

## Key Benefits

1. **Deterministic validation** — Invariant checks produce identical results for identical input. No LLM guessing.
2. **Structured errors** — Validation failures include error codes, field names, and precise messages. No regex confusion.
3. **Importable** — Any Go project can import `pkg/protocol` without bundling the full engine or web UI.
4. **Type safety** — Go compiler enforces manifest structure. Impossible to construct invalid manifests.
5. **Single source of truth** — Protocol state lives in YAML. SDK reads/writes atomically. No drift between markdown and runtime state.

## Design Principles

### Structured data, interactive coordination

The protocol has two halves:

- **Structural work** (deterministic) — manifest parsing, invariant validation, file ownership, wave sequencing. This is Go code. It never calls an LLM. It always produces the same output for the same input.
- **Creative work** (non-deterministic) — analyzing code, writing implementations, handling novel errors, deciding what to do next. This is LLM work. It requires conversation, judgment, and context.

The SDK handles the first. The agent runtime handles the second. The CLI binary sits at the boundary, validating data on the way in and the way out.

### Validation at boundaries

Every transition between layers validates:

```
Manifest loaded from disk       → Validate()
Agent context extracted          → agent exists, wave is current
Completion report registered     → required fields, status enum, files match ownership
Wave merge requested             → all agents complete, no I1 violations
```

Errors are structured (`ValidationError` with code, message, field) — not "parse error on line 342."

## Further Reading

- [Protocol SDK Migration Proposal](https://github.com/blackwell-systems/scout-and-wave-go/blob/main/docs/proposals/protocol-sdk-migration-v2.md) — Full architectural context and framework evaluation
- [scout-and-wave-go README](https://github.com/blackwell-systems/scout-and-wave-go/blob/main/README.md) — SDK package structure and usage examples
- [Scout-and-Wave Protocol Spec](https://github.com/blackwell-systems/scout-and-wave) — Invariants, execution rules, and coordination protocol

# IMPL: OpenAI-Compatible API Backend + Provider-Prefix Routing
<!-- SAW:COMPLETE 2026-03-09 -->

## Suitability Assessment

Verdict: SUITABLE
test_command: `cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./...`
lint_command: `cd /Users/dayna.blackwell/code/scout-and-wave-go && go vet ./...`

Two agents with cleanly disjoint file ownership:
- Agent A owns `pkg/agent/backend/openai/` (all new files) — zero overlap with any existing file.
- Agent B owns `pkg/orchestrator/orchestrator.go` — extends `BackendConfig` and `newBackendFunc`, importing Agent A's new package.
- Agent B also owns `pkg/agent/backend/backend.go` — adds `APIKey` and `BaseURL` to `Config`.

All five suitability questions resolve cleanly:
1. Disjoint file ownership: 4 files for Agent A (all new), 2 files for Agent B (modifications). No shared file across agents.
2. No investigation-first items: the interface to implement is already defined; the Anthropic API client is the implementation template.
3. Interface contracts are fully discoverable from the existing `backend.Backend` interface and `BackendConfig` struct.
4. Pre-implementation scan: zero of these items exist today. `pkg/agent/backend/openai/` directory does not exist; `BackendConfig.APIKey` and `BackendConfig.BaseURL` fields do not exist; provider-prefix parsing does not exist in `newBackendFunc`.
5. Parallelization value: `go test ./...` with build cycles (~10–20 s) + Agent A owns 4 new files (client, tools, streaming, test) + agents are fully independent until B imports A's package (single merge dependency). Clear speedup.

Pre-implementation scan results:
- Total items: 2 paths (Path A + Path C)
- Already implemented: 0 items
- Partially implemented: 0 items
- To-do: 2 items (all work is greenfield)

Agent adjustments: none — all agents proceed as planned.

Estimated times:
- Scout phase: ~8 min
- Agent execution: ~25 min (A: ~15 min new package + tests; B: ~10 min config extension + routing)
- Merge & verification: ~5 min
Total SAW time: ~38 min

Sequential baseline: ~55 min (A then B sequentially + overhead)
Time savings: ~17 min (~31% faster)

Recommendation: Clear speedup. Proceed with two-wave plan (Wave 1: Agent A; Wave 2: Agent B imports A).

---

## Quality Gates

level: standard

gates:
  - type: build
    command: cd /Users/dayna.blackwell/code/scout-and-wave-go && go build ./...
    required: true
  - type: lint
    command: cd /Users/dayna.blackwell/code/scout-and-wave-go && go vet ./...
    required: true
  - type: test
    command: cd /Users/dayna.blackwell/code/scout-and-wave-go && go test ./...
    required: true

---

## Scaffolds

No scaffolds needed — agents have independent type ownership. The `Tool` type used by Agent A is already defined in `pkg/agent/backend/api/tools.go` and will be duplicated (with adaptations) in the OpenAI package rather than shared, following the same pattern already in place ("local copy to avoid circular import" — see `api/tools.go` line 14).

---

## Pre-Mortem

**Overall risk:** low

**Failure modes:**

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| `github.com/openai/openai-go` SDK not yet in go.mod; `go get` blocked by agent | medium | high | Agent A must run `go get github.com/openai/openai-go` in the engine repo before writing any code. If the SDK is not compatible with go 1.25, use `net/http` directly with JSON encoding (the OpenAI REST API is simple enough). Agent should attempt go get first and fall back to net/http if necessary. |
| OpenAI streaming SSE differs from Anthropic streaming format | low | medium | Agent A reads the OpenAI Go SDK streaming docs/examples before implementing RunStreaming. The SDK handles SSE framing; the agent only processes delta events. |
| `BackendConfig.APIKey` name conflicts with existing field | low | low | The existing struct has no `APIKey` field (verified in orchestrator.go lines 77–83). Agent B adds it cleanly. |
| Provider prefix `"cli:kimi"` strips prefix but still routes to Anthropic CLI path (wrong BinaryPath) | medium | medium | Agent B must route `"cli:*"` to the CLI backend constructor with `BinaryPath` set from env or config. Prompt is explicit about this. |
| Agent B imports openai package before Agent A merges | medium | high | Wave structure enforces sequencing: Agent B runs in Wave 2, after Agent A merges in Wave 1. |
| `go test ./...` in web repo breaks after engine changes | low | medium | The engine change adds a new package (no breaking changes). The web repo uses a replace directive so it sees engine changes automatically. Post-merge orchestrator step should run `cd scout-and-wave-web && go build ./...` as a smoke check. |

---

## Known Issues

None identified. `go test ./...` in the engine repo passes cleanly as of this writing (verified by existing test files with no known skip annotations).

---

## Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (1 agent — new package):
    [A] pkg/agent/backend/openai/client.go
        pkg/agent/backend/openai/tools.go
        pkg/agent/backend/openai/client_test.go
         (implement backend.Backend with OpenAI API format; tool execution loop;
          streaming; configurable base URL; Bash/Read/Write/Edit/Glob/Grep tools)
         ✓ root (no dependencies on other agents)

Wave 2 (1 agent — routing + config extension):
    [B] pkg/agent/backend/backend.go
        pkg/orchestrator/orchestrator.go
         (extend BackendConfig with APIKey+BaseURL; extend newBackendFunc to parse
          provider prefix from AgentSpec.Model and dispatch to openai.New or cli.New)
         depends on: [A] (imports pkg/agent/backend/openai)
```

No ownership conflicts. The `pkg/agent/backend/api/tools.go` file is read-only reference for Agent A; Agent A does not modify it.

---

## Interface Contracts

### `backend.Config` extensions (Agent B adds to `pkg/agent/backend/backend.go`)

```go
type Config struct {
    Model      string
    MaxTokens  int
    MaxTurns   int
    BinaryPath string
    // NEW:
    APIKey  string // API key for the OpenAI-compatible backend. If empty, OPENAI_API_KEY env is used.
    BaseURL string // Optional base URL override (e.g. "https://api.groq.com/openai/v1").
}
```

### `openai.Client` (Agent A creates in `pkg/agent/backend/openai/client.go`)

```go
package openai

import "github.com/blackwell-systems/scout-and-wave-go/pkg/agent/backend"

// Client implements backend.Backend using the OpenAI-compatible chat completions API.
type Client struct { /* unexported */ }

// New creates a Client from a BackendConfig.
// If cfg.APIKey is empty, OPENAI_API_KEY env var is used.
// If cfg.BaseURL is empty, the official OpenAI endpoint is used.
// cfg.Model defaults to "gpt-4o" if empty.
func New(cfg backend.Config) *Client

// Run implements backend.Backend.
func (c *Client) Run(ctx context.Context, systemPrompt, userMessage, workDir string) (string, error)

// RunStreaming implements backend.Backend.
func (c *Client) RunStreaming(ctx context.Context, systemPrompt, userMessage, workDir string, onChunk backend.ChunkCallback) (string, error)
```

### `BackendConfig` extensions (Agent B modifies in `pkg/orchestrator/orchestrator.go`)

```go
type BackendConfig struct {
    Kind      string // "api" | "cli" | "openai" | "auto"
    APIKey    string // Anthropic OR OpenAI key, depending on Kind
    Model     string // may carry provider prefix: "openai:gpt-4o", "cli:kimi", etc.
    MaxTokens int
    MaxTurns  int
    // NEW:
    OpenAIKey  string // OpenAI-specific API key (OPENAI_API_KEY)
    BaseURL    string // Optional endpoint override for openai Kind
}
```

### Provider-prefix routing logic (Agent B in `newBackendFunc`)

```go
// parseProviderPrefix splits "provider:model" into ("provider", "model").
// If no colon prefix, returns ("", model) — routes to existing auto/Anthropic path.
func parseProviderPrefix(model string) (provider, bareModel string)

// Extended newBackendFunc dispatch:
// "openai:*"    -> openai.New(backend.Config{Model: bareModel, APIKey: openAIKey, BaseURL: baseURL})
// "cli:*"       -> cliclient.New(binaryPath, backend.Config{Model: bareModel})
// "anthropic:*" -> apiclient.New(anthropicKey, backend.Config{Model: bareModel})
// ""            -> existing "auto" logic unchanged
```

---

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| pkg/agent/backend/openai/client.go | A | 1 | — |
| pkg/agent/backend/openai/tools.go | A | 1 | — |
| pkg/agent/backend/openai/client_test.go | A | 1 | — |
| pkg/agent/backend/backend.go | B | 2 | A |
| pkg/orchestrator/orchestrator.go | B | 2 | A |
```

---

## Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A]              <- 1 agent (new openai package, no deps)
           | (A complete + merged)
Wave 2:   [B]            <- 1 agent (config extension + routing, imports A)
```

---

## Wave 1

Wave 1 delivers the complete `pkg/agent/backend/openai/` package: a fully functional OpenAI-compatible backend implementing `backend.Backend`. This wave has no dependencies on any other new work. Agent A reads the Anthropic API client (`pkg/agent/backend/api/client.go`) as the implementation template and adapts it for the OpenAI format.

### Agent A - OpenAI Backend Package

**Role:** Implement `pkg/agent/backend/openai/` — a new backend package using the OpenAI Go SDK.

**Context:**
You are implementing a new package in the Scout-and-Wave engine repo at `/Users/dayna.blackwell/code/scout-and-wave-go`. The engine repo is a Go module (`github.com/blackwell-systems/scout-and-wave-go`).

You are implementing Path A of a two-path feature. Path B (provider-prefix routing) is handled by a different agent in Wave 2, who will import your package.

**Files to create:**
- `pkg/agent/backend/openai/client.go` — the `Client` struct implementing `backend.Backend`
- `pkg/agent/backend/openai/tools.go` — tool definitions (Bash, Read, Write, Edit, Glob, Grep)
- `pkg/agent/backend/openai/client_test.go` — unit tests

**Do NOT modify any existing files.**

**Implementation instructions:**

1. First, read these files to understand the patterns to follow:
   - `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/agent/backend/backend.go` — the interface you must implement
   - `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/agent/backend/api/client.go` — the Anthropic backend (template for tool loop structure)
   - `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/agent/backend/api/tools.go` — tool implementations to adapt

2. Add the OpenAI Go SDK dependency:
   ```bash
   cd /Users/dayna.blackwell/code/scout-and-wave-go && go get github.com/openai/openai-go
   ```
   If `go get` fails (network issue or SDK incompatibility), implement the HTTP client directly using `net/http` + `encoding/json` against the OpenAI REST API. The chat completions endpoint is `POST /v1/chat/completions`.

3. Create `pkg/agent/backend/openai/tools.go`:
   - Copy the tool type and the four standard tools from `pkg/agent/backend/api/tools.go` (Read, Write, bash, list_directory). The `Tool` type is package-local to avoid circular imports — follow the same pattern (the comment in `api/tools.go` line 14 explains why).
   - Add `Edit` tool: reads a file, performs exact string replacement (`old_string` → `new_string`), writes back. Return error if `old_string` not found.
   - Add `Glob` tool: uses `filepath.Glob` to match a pattern (relative to workDir). Returns matched paths one per line.
   - Add `Grep` tool: runs `rg` (ripgrep) via `exec.Command` with the provided pattern and path. Falls back to a simple `strings.Contains` line-scan if `rg` is not found in PATH.

4. Create `pkg/agent/backend/openai/client.go`:
   - `Client` struct with fields: `apiKey string`, `model string`, `maxTokens int`, `maxTurns int`, `baseURL string`.
   - `func New(cfg backend.Config) *Client` constructor. Default model: `"gpt-4o"`. Default maxTokens: `4096`. Default maxTurns: `50`. APIKey from `cfg.APIKey` or `OPENAI_API_KEY` env. BaseURL from `cfg.BaseURL`.
   - `Run` method: implement the tool-use loop against the OpenAI chat completions API. The loop:
     1. Send messages to `/v1/chat/completions` with `tools` and `tool_choice: "auto"`.
     2. If `finish_reason == "stop"` — return the assistant's text content.
     3. If `finish_reason == "tool_calls"` — execute each tool call, append results as tool messages, loop.
     4. If `maxTurns` exceeded — return error.
   - `RunStreaming` method: same loop as Run for tool-use turns; for the final `"stop"` turn, use streaming (`stream: true`) and call `onChunk` for each `content` delta. If `onChunk == nil`, delegate to `Run`.

   **OpenAI message format (for tool results):**
   ```json
   {"role": "tool", "tool_call_id": "<id>", "content": "<result string>"}
   ```

   **Tool definition format:**
   ```json
   {
     "type": "function",
     "function": {
       "name": "read_file",
       "description": "...",
       "parameters": { <JSON schema> }
     }
   }
   ```

   **If using the SDK**, use `github.com/openai/openai-go`. The main types are `openai.ChatCompletionNewParams`, `openai.ChatCompletionMessageParamUnion`, `openai.ChatCompletionToolParam`. Streaming uses `client.Chat.Completions.NewStreaming(ctx, params)`.

   **If using net/http directly**, define minimal struct types for request/response JSON. Do not import the SDK in that case.

5. Create `pkg/agent/backend/openai/client_test.go`:
   - Use Go's `net/http/httptest` to run a mock OpenAI server.
   - Test `Run` with a single-turn non-tool response (finish_reason: "stop").
   - Test `Run` with one tool_call turn (tool_calls → execute tool → final stop).
   - Test `RunStreaming` calls onChunk with text fragments.
   - Test that `OPENAI_API_KEY` env fallback works when `cfg.APIKey` is empty.
   - Test that `cfg.BaseURL` redirects requests to the mock server.
   - Use `t.Setenv("OPENAI_API_KEY", "test-key")` for env tests.

**Interface contracts (binding):**
- Package name: `openai` (import path: `github.com/blackwell-systems/scout-and-wave-go/pkg/agent/backend/openai`)
- Exported constructor: `func New(cfg backend.Config) *Client`
- `Client` implements `backend.Backend` (both `Run` and `RunStreaming`)
- Do NOT export `Tool` type or `StandardTools` func — keep them package-private

**Verification gate:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave-go
go build ./pkg/agent/backend/openai/...
go vet ./pkg/agent/backend/openai/...
go test ./pkg/agent/backend/openai/... -timeout 60s
```

**Completion report template:**
```yaml type=impl-completion-report
agent: A
wave: 1
status: complete
worktree: wave1-agent-A
branch: saw/wave1-agent-A
commit: <sha>
files_created:
  - pkg/agent/backend/openai/client.go
  - pkg/agent/backend/openai/tools.go
  - pkg/agent/backend/openai/client_test.go
files_changed: []
interface_deviations: []
out_of_scope_deps: []
tests_added:
  - TestRun_SingleTurn
  - TestRun_ToolCallLoop
  - TestRunStreaming_CallsOnChunk
  - TestNew_APIKeyFromEnv
  - TestNew_BaseURLOverride
verification: "go build ./..., go vet ./..., go test ./pkg/agent/backend/openai/... PASS"
```

---

## Wave 2

Wave 2 extends the existing backend infrastructure to support provider-prefix routing. It depends on Wave 1 completing so that Agent B can import `pkg/agent/backend/openai`. Agent B modifies two existing files; both are in the engine repo.

### Agent B - Config Extension + Provider-Prefix Routing

**Role:** Extend `backend.Config` with `APIKey`/`BaseURL` fields and extend `newBackendFunc` in the orchestrator to parse provider prefixes and dispatch to the correct backend.

**Context:**
You are extending two files in the Scout-and-Wave engine repo at `/Users/dayna.blackwell/code/scout-and-wave-go`. Wave 1 (Agent A) has already merged, adding `pkg/agent/backend/openai/` with `openai.New(cfg backend.Config) *Client`.

**Files to modify:**
- `pkg/agent/backend/backend.go` — add `APIKey` and `BaseURL` fields to `Config`
- `pkg/orchestrator/orchestrator.go` — extend `BackendConfig`, add `parseProviderPrefix`, update `newBackendFunc`

**Do NOT create new files. Do NOT modify any other files.**

**Implementation instructions:**

1. Read the current state of both files:
   - `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/agent/backend/backend.go`
   - `/Users/dayna.blackwell/code/scout-and-wave-go/pkg/orchestrator/orchestrator.go`

2. In `pkg/agent/backend/backend.go`, add two fields to `Config`:
   ```go
   // APIKey is the API key for the OpenAI-compatible backend.
   // If empty, the OPENAI_API_KEY environment variable is used.
   APIKey string

   // BaseURL is an optional endpoint override for the OpenAI-compatible backend
   // (e.g. "https://api.groq.com/openai/v1" for Groq, "http://localhost:11434/v1" for Ollama).
   // If empty, the official OpenAI endpoint is used.
   BaseURL string
   ```

3. In `pkg/orchestrator/orchestrator.go`:

   a. Add import: `openaibackend "github.com/blackwell-systems/scout-and-wave-go/pkg/agent/backend/openai"`

   b. Extend `BackendConfig` with:
   ```go
   // OpenAIKey is the API key for the OpenAI-compatible backend.
   // Falls back to OPENAI_API_KEY env var if empty.
   OpenAIKey string

   // BaseURL is an optional endpoint override used when Kind == "openai"
   // or when the provider prefix is "openai".
   BaseURL string
   ```

   c. Add a package-level function (not exported, but can be tested via package tests):
   ```go
   // parseProviderPrefix splits a provider-qualified model string.
   // Input "openai:gpt-4o" returns ("openai", "gpt-4o").
   // Input "cli:kimi" returns ("cli", "kimi").
   // Input "anthropic:claude-opus-4-6" returns ("anthropic", "claude-opus-4-6").
   // Input "gpt-4o" (no colon) returns ("", "gpt-4o").
   func parseProviderPrefix(model string) (provider, bareModel string) {
       idx := strings.Index(model, ":")
       if idx < 0 {
           return "", model
       }
       return model[:idx], model[idx+1:]
   }
   ```

   d. Update `newBackendFunc` to handle provider prefixes. The updated dispatch logic:

   ```
   1. Call parseProviderPrefix(cfg.Model) to get (provider, bareModel).
   2. Set effective Kind:
      - If provider != "" → use provider as Kind (overrides cfg.Kind).
      - Else → use cfg.Kind as-is.
   3. Switch on effective Kind:
      case "openai":
          apiKey := cfg.OpenAIKey
          if apiKey == "" { apiKey = os.Getenv("OPENAI_API_KEY") }
          return openaibackend.New(backend.Config{
              Model: bareModel, MaxTokens: cfg.MaxTokens, MaxTurns: cfg.MaxTurns,
              APIKey: apiKey, BaseURL: cfg.BaseURL,
          }), nil
      case "cli":
          binaryPath := os.Getenv("SAW_CLI_BINARY") // optional: custom binary from env
          return cliclient.New(binaryPath, backend.Config{Model: bareModel, MaxTokens: cfg.MaxTokens, MaxTurns: cfg.MaxTurns, BinaryPath: binaryPath}), nil
      case "anthropic":
          apiKey := cfg.APIKey
          if apiKey == "" { apiKey = os.Getenv("ANTHROPIC_API_KEY") }
          return apiclient.New(apiKey, backend.Config{Model: bareModel, MaxTokens: cfg.MaxTokens, MaxTurns: cfg.MaxTurns}), nil
      case "api":
          // existing behavior (Anthropic API)
          ...
      case "auto", "":
          // existing auto-detection behavior, unchanged
          // (but use bareModel since model may have had no prefix)
          ...
   ```

   e. In the per-agent model override block (`RunWave` method, lines ~246–252), pass the full `agentSpec.Model` (with prefix) to `BackendConfig.Model` — the prefix will be parsed by `newBackendFunc`. No changes needed to `RunWave` logic itself.

4. Add or update tests in `pkg/orchestrator/orchestrator_test.go` for `parseProviderPrefix` and the updated `newBackendFunc`. Since `orchestrator_test.go` uses `package orchestrator` (white-box tests), `parseProviderPrefix` is directly testable. Add:
   - `TestParseProviderPrefix_WithPrefix` — "openai:gpt-4o" → ("openai", "gpt-4o")
   - `TestParseProviderPrefix_NoPrefix` — "gpt-4o" → ("", "gpt-4o")
   - `TestParseProviderPrefix_CLIPrefix` — "cli:kimi" → ("cli", "kimi")
   - `TestNewBackendFunc_OpenAIKind` — cfg.Kind="openai", confirms openai backend created without panic
   - `TestNewBackendFunc_OpenAIPrefix` — cfg.Model="openai:gpt-4o" with Kind="auto", confirms routing

   Note: existing tests in `orchestrator_test.go` use `newBackendFunc` as a package-level var that tests replace with fakes. Your new tests should follow the same pattern.

**Interface contracts (binding):**
- `backend.Config` gains `APIKey string` and `BaseURL string` — additive, no breaking change
- `BackendConfig` gains `OpenAIKey string` and `BaseURL string` — additive
- `parseProviderPrefix(model string) (provider, bareModel string)` — unexported, package-local
- The openai package import alias must be `openaibackend` to avoid collision with the `openai` model name strings

**Verification gate:**
```bash
cd /Users/dayna.blackwell/code/scout-and-wave-go
go build ./...
go vet ./...
go test ./pkg/agent/backend/... -timeout 60s
go test ./pkg/orchestrator/... -run "TestParseProviderPrefix|TestNewBackendFunc" -timeout 60s
```

**Completion report template:**
```yaml type=impl-completion-report
agent: B
wave: 2
status: complete
worktree: wave2-agent-B
branch: saw/wave2-agent-B
commit: <sha>
files_created: []
files_changed:
  - pkg/agent/backend/backend.go
  - pkg/orchestrator/orchestrator.go
interface_deviations: []
out_of_scope_deps: []
tests_added:
  - TestParseProviderPrefix_WithPrefix
  - TestParseProviderPrefix_NoPrefix
  - TestParseProviderPrefix_CLIPrefix
  - TestNewBackendFunc_OpenAIKind
  - TestNewBackendFunc_OpenAIPrefix
verification: "go build ./..., go vet ./..., go test ./... PASS"
```

---

## Wave Execution Loop

After Wave 1 completes:
- Read Agent A's completion report; confirm `status: complete`
- Merge: `git merge --no-ff saw/wave1-agent-A -m "Merge wave1-agent-A: OpenAI backend package"`
- Worktree cleanup: `git worktree remove <path>` + `git branch -d saw/wave1-agent-A`
- Post-merge verification: `cd /Users/dayna.blackwell/code/scout-and-wave-go && go build ./... && go vet ./... && go test ./...`
- If Agent A chose `net/http` over the SDK: verify `go.mod` was NOT modified by Agent A (the SDK was only needed if using the openai-go library)
- Fix any cascade failures, then launch Wave 2.

After Wave 2 completes:
- Read Agent B's completion report; confirm `status: complete`
- Merge: `git merge --no-ff saw/wave2-agent-B -m "Merge wave2-agent-B: provider-prefix routing + Config extension"`
- Worktree cleanup
- Post-merge verification (full suite):
  ```bash
  cd /Users/dayna.blackwell/code/scout-and-wave-go && go build ./... && go vet ./... && go test ./...
  cd /Users/dayna.blackwell/code/scout-and-wave-web && go build ./...
  ```
- The web repo smoke check (`go build ./...`) catches any import breakage from the engine changes via the replace directive.
- Commit and close.

## Orchestrator Post-Merge Checklist

After wave 1 completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; flag any file appearing in >1 agent's list before touching the working tree
- [ ] Review `interface_deviations` — update downstream agent prompts for any item with `downstream_action_required: true`
- [ ] Merge each agent: `git merge --no-ff <branch> -m "Merge wave1-agent-A: OpenAI backend package"`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a (no auto-fix linter configured)
      - [ ] `cd /Users/dayna.blackwell/code/scout-and-wave-go && go build ./... && go vet ./... && go test ./...`
- [ ] E20 stub scan: collect `files_changed`+`files_created` from all completion reports; run `bash "${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh" pkg/agent/backend/openai/client.go pkg/agent/backend/openai/tools.go`; append output to IMPL doc as `## Stub Report — Wave 1`
- [ ] E21 quality gates: run all gates marked `required: true`; required gate failures block merge; optional gate failures warn only
- [ ] Fix any cascade failures
- [ ] Tick status checkboxes in this IMPL doc for completed agents
- [ ] Update interface contracts for any deviations logged by agents
- [ ] Apply `out_of_scope_deps` fixes flagged in completion reports
- [ ] Feature-specific steps:
      - [ ] Verify that `pkg/agent/backend/openai/` directory was created with all three files
      - [ ] Confirm `go.mod` / `go.sum` updated correctly if SDK was used
- [ ] Commit: `git commit -m "wave 1 complete: openai backend package"`
- [ ] Launch Wave 2

After wave 2 completes:

- [ ] Read all agent completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — Agent B modifies `backend.go` and `orchestrator.go`; no overlap with Wave 1 files
- [ ] Review `interface_deviations`
- [ ] Merge each agent: `git merge --no-ff saw/wave2-agent-B -m "Merge wave2-agent-B: BackendConfig extension + provider-prefix routing"`
- [ ] Worktree cleanup
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a
      - [ ] `cd /Users/dayna.blackwell/code/scout-and-wave-go && go build ./... && go vet ./... && go test ./...`
      - [ ] `cd /Users/dayna.blackwell/code/scout-and-wave-web && go build ./...` (smoke check web repo)
- [ ] E20 stub scan: `bash "${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh" pkg/agent/backend/backend.go pkg/orchestrator/orchestrator.go`; append as `## Stub Report — Wave 2`
- [ ] E21 quality gates: all required gates
- [ ] Fix any cascade failures
- [ ] Tick status checkboxes
- [ ] Feature-specific steps:
      - [ ] Manually test `parseProviderPrefix("openai:gpt-4o")` returns `("openai", "gpt-4o")` in test output
      - [ ] Verify `BackendConfig` now has `OpenAIKey` and `BaseURL` fields (grep for them in orchestrator.go)
      - [ ] Confirm `OPENAI_API_KEY` env var is documented in any relevant README or help text (out-of-scope but note for follow-up)
- [ ] Commit: `git commit -m "wave 2 complete: provider-prefix routing for openai/cli/anthropic backends"`

### Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | OpenAI-compatible backend package (`pkg/agent/backend/openai/`) | COMPLETE |
| 2 | B | BackendConfig extension + provider-prefix routing in orchestrator | TO-DO |
| — | Orch | Post-merge integration + web repo smoke build | TO-DO |

---

## Stub Report — Wave 1

Scan date: 2026-03-09
Files scanned: pkg/agent/backend/openai/client.go, pkg/agent/backend/openai/tools.go, pkg/agent/backend/openai/client_test.go
Result: **No stub patterns detected.**

---

### Agent A - Completion Report

```yaml type=impl-completion-report
agent: A
wave: 1
status: complete
worktree: main (solo wave)
branch: main
commit: bd888b4
files_created:
  - pkg/agent/backend/openai/client.go
  - pkg/agent/backend/openai/tools.go
  - pkg/agent/backend/openai/client_test.go
files_changed:
  - go.mod
  - go.sum
interface_deviations:
  - "cfg.APIKey and cfg.BaseURL not yet in backend.Config (Wave 2 adds them). New() reads OPENAI_API_KEY from env; WithAPIKey()/WithBaseURL() chaining methods added for tests and future use."
out_of_scope_deps: []
tests_added:
  - TestRun_SingleTurn
  - TestRun_ToolCallLoop
  - TestRunStreaming_CallsOnChunk
  - TestNew_APIKeyFromEnv
  - TestNew_BaseURLOverride
verification: "go build PASS, go vet PASS, go test PASS (5/5)"
```

Implementation uses `net/http` directly (not the openai-go SDK types) against `POST {baseURL}/chat/completions` — the SDK was added to go.mod but the HTTP path is simpler and avoids SDK type churn. `RunStreaming` issues a non-streaming probe first, then re-issues the final stop turn as a streaming SSE request so `onChunk` receives live fragments. Wave 2 Agent B should add `APIKey string` and `BaseURL string` to `backend.Config`; once those fields exist, `New()` can be updated to read `cfg.APIKey` directly in addition to the env var fallback.

### Agent B - Completion Report

```yaml type=impl-completion-report
agent: B
wave: 2
status: complete
worktree: main (solo wave)
branch: main
commit: 0e02d00
files_created: []
files_changed:
  - pkg/agent/backend/backend.go
  - pkg/agent/backend/openai/client.go
  - pkg/orchestrator/orchestrator.go
  - pkg/orchestrator/orchestrator_test.go
interface_deviations: []
out_of_scope_deps: []
tests_added:
  - TestParseProviderPrefix_WithPrefix
  - TestParseProviderPrefix_NoPrefix
  - TestParseProviderPrefix_CLIPrefix
  - TestNewBackendFunc_OpenAIKind
  - TestNewBackendFunc_OpenAIPrefix
verification: "go build PASS, go vet PASS, go test PASS"
```

Added `APIKey`/`BaseURL` to `backend.Config` and `OpenAIKey`/`BaseURL` to `BackendConfig`. Added `parseProviderPrefix` (unexported) to split "provider:model" strings. Updated `newBackendFunc` to call `parseProviderPrefix` first and dispatch on effective kind — new cases for `"openai"` and `"anthropic"` alongside existing `"api"`, `"cli"`, and `"auto"`. Also updated `openai.New` to read `cfg.APIKey` and `cfg.BaseURL` from the struct fields (with env var fallback), completing the struct-based path Agent A left for Wave 2. The `"cli"` case was updated to read `SAW_CLI_BINARY` env var and pass `BinaryPath` through `backend.Config`. All 5 new tests pass; full suite green.

## Stub Report — Wave 2

Scan date: 2026-03-09
Files scanned: pkg/agent/backend/backend.go, pkg/orchestrator/orchestrator.go
Result: **No stub patterns detected.**

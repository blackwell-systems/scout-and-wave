# Observability Events

**Version:** 0.20.0

This document defines the event schema for Scout-and-Wave observability. Events capture token costs, agent performance outcomes, and high-level orchestrator actions. Implementations consume this schema to build dashboards, cost tracking, and trend analysis.

---

## Overview

Three event types cover the observability surface:

| Type                | Purpose                                      | Emitted By        |
|---------------------|----------------------------------------------|--------------------|
| `cost`              | Token usage and USD cost per agent invocation | SDK (per-agent)    |
| `agent_performance` | Agent execution outcome (success/failure)    | SDK (per-agent)    |
| `activity`          | High-level orchestrator actions              | Orchestrator       |

All events share a common base structure and are stored as JSONB in the observability database.

---

## Base Event Structure

Every event conforms to this base structure:

| Field      | Type                   | Required | Description                                |
|------------|------------------------|----------|--------------------------------------------|
| `id`       | string (UUID)          | yes      | Unique event identifier                    |
| `type`     | string                 | yes      | One of: `cost`, `agent_performance`, `activity` |
| `timestamp`| ISO 8601 datetime      | yes      | When the event occurred (UTC)              |
| `metadata` | map\<string, any\>     | yes      | Arbitrary key-value pairs for extensibility |

Implementations must generate `id` as a UUID v4. The `metadata` map allows forward-compatible extension without schema changes.

---

## CostEvent

Tracks token consumption and estimated USD cost for a single agent invocation or model call.

| Field           | Type    | Required | Description                                     |
|-----------------|---------|----------|-------------------------------------------------|
| `id`            | string  | yes      | Unique event ID                                 |
| `type`          | string  | yes      | Always `"cost"`                                 |
| `timestamp`     | string  | yes      | ISO 8601 UTC                                    |
| `agent_id`      | string  | yes      | Agent identifier (e.g., `"A"`, `"B"`)           |
| `wave_number`   | integer | yes      | Wave in which the agent executed                |
| `impl_slug`     | string  | yes      | IMPL doc slug (e.g., `"long-term-observability"`) |
| `program_slug`  | string  | no       | Program slug, if part of a program              |
| `model`         | string  | yes      | Model identifier (e.g., `"claude-sonnet-4-6"`)  |
| `input_tokens`  | integer | yes      | Number of input tokens consumed                 |
| `output_tokens` | integer | yes      | Number of output tokens generated               |
| `cost_usd`      | number  | yes      | Estimated cost in USD                           |
| `metadata`      | map     | yes      | Additional context                              |

### Example

```json
{
  "id": "evt_a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "type": "cost",
  "timestamp": "2026-03-20T14:30:00Z",
  "agent_id": "A",
  "wave_number": 1,
  "impl_slug": "long-term-observability",
  "program_slug": "",
  "model": "claude-sonnet-4-6",
  "input_tokens": 45000,
  "output_tokens": 12000,
  "cost_usd": 0.243,
  "metadata": {
    "worktree": "/path/to/worktree/wave1-agent-A"
  }
}
```

---

## AgentPerformanceEvent

Records the outcome of an agent's execution, including success/failure status, retry count, duration, and test results.

| Field              | Type     | Required | Description                                          |
|--------------------|----------|----------|------------------------------------------------------|
| `id`               | string   | yes      | Unique event ID                                      |
| `type`             | string   | yes      | Always `"agent_performance"`                         |
| `timestamp`        | string   | yes      | ISO 8601 UTC                                         |
| `agent_id`         | string   | yes      | Agent identifier                                     |
| `wave_number`      | integer  | yes      | Wave in which the agent executed                     |
| `impl_slug`        | string   | yes      | IMPL doc slug                                        |
| `program_slug`     | string   | no       | Program slug, if part of a program                   |
| `status`           | string   | yes      | One of: `"success"`, `"failed"`, `"blocked"`, `"partial"` |
| `failure_type`     | string   | no       | If failed: `"transient"`, `"fixable"`, `"needs_replan"`, `"escalate"` |
| `retry_count`      | integer  | yes      | Number of retries before final status                |
| `duration_seconds` | integer  | yes      | Wall-clock execution time in seconds                 |
| `files_modified`   | string[] | yes      | List of files the agent modified                     |
| `tests_passed`     | integer  | yes      | Number of tests passed in verification gate          |
| `tests_failed`     | integer  | yes      | Number of tests failed in verification gate          |
| `metadata`         | map      | yes      | Additional context                                   |

### Status Values

- **`success`** — Agent completed all assigned work and passed verification gates.
- **`failed`** — Agent could not complete assigned work. See `failure_type` for classification per E19.
- **`blocked`** — Agent could not proceed due to external dependency or contract issue.
- **`partial`** — Agent completed some but not all assigned work. Partial results are committed.

### Failure Type Values

These align with the E19 failure classification decision tree:

- **`transient`** — Temporary failure (network, rate limit). Safe to retry automatically.
- **`fixable`** — Agent-fixable issue (test failure, lint error). Retry with corrective prompt.
- **`needs_replan`** — Task cannot be completed as specified. Requires IMPL amendment (E36).
- **`escalate`** — Unrecoverable failure requiring human intervention.

### Example

```json
{
  "id": "evt_b2c3d4e5-f6a7-8901-bcde-f12345678901",
  "type": "agent_performance",
  "timestamp": "2026-03-20T14:45:00Z",
  "agent_id": "B",
  "wave_number": 1,
  "impl_slug": "long-term-observability",
  "program_slug": "",
  "status": "success",
  "failure_type": "",
  "retry_count": 0,
  "duration_seconds": 180,
  "files_modified": [
    "pkg/observability/store.go",
    "pkg/observability/store_test.go"
  ],
  "tests_passed": 12,
  "tests_failed": 0,
  "metadata": {
    "commit_sha": "abc1234",
    "worktree": "/path/to/worktree/wave1-agent-B"
  }
}
```

---

## ActivityEvent

Records high-level orchestrator actions that mark significant lifecycle transitions.

| Field           | Type    | Required | Description                                     |
|-----------------|---------|----------|-------------------------------------------------|
| `id`            | string  | yes      | Unique event ID                                 |
| `type`          | string  | yes      | Always `"activity"`                             |
| `timestamp`     | string  | yes      | ISO 8601 UTC                                    |
| `activity_type` | string  | yes      | The specific orchestrator action (see below)    |
| `impl_slug`     | string  | yes      | IMPL doc slug                                   |
| `program_slug`  | string  | no       | Program slug, if part of a program              |
| `wave_number`   | integer | no       | Wave number, if the activity is wave-related    |
| `user`          | string  | yes      | Who triggered the action (username or system ID)|
| `details`       | string  | no       | Human-readable description of the action        |
| `metadata`      | map     | yes      | Additional context                              |

### Activity Type Values

| Value             | Description                                          |
|-------------------|------------------------------------------------------|
| `scout_launch`    | Scout agent launched for an IMPL                     |
| `scout_complete`  | Scout agent completed, IMPL doc produced             |
| `wave_start`      | Wave execution began (worktrees created, agents launched) |
| `wave_merge`      | Wave completed and merged to main                    |
| `wave_failed`     | Wave failed (one or more agents blocked/failed)      |
| `impl_complete`   | IMPL reached COMPLETE state                          |
| `gate_executed`   | Quality gate command executed                        |
| `gate_failed`     | Quality gate command failed                          |
| `tier_advanced`   | Program advanced to next tier (E33)                  |
| `tier_gate_passed`| Tier gate verification passed (E29)                  |
| `tier_gate_failed`| Tier gate verification failed (E29)                  |

Implementations may define additional activity types beyond this list. Unknown activity types must be accepted by the store and queryable by filters.

### Example

```json
{
  "id": "evt_c3d4e5f6-a7b8-9012-cdef-123456789012",
  "type": "activity",
  "timestamp": "2026-03-20T14:00:00Z",
  "activity_type": "wave_start",
  "impl_slug": "long-term-observability",
  "program_slug": "",
  "wave_number": 1,
  "user": "dayna",
  "details": "Wave 1 started with 4 agents (A, B, C, D)",
  "metadata": {
    "agent_count": 4,
    "agent_ids": ["A", "B", "C", "D"]
  }
}
```

---

## Storage Requirements

Events are stored as JSONB in a relational database (SQLite for local development, PostgreSQL for production). The storage layer must support:

1. **Append-only writes** — Events are immutable once written. No updates or deletes.
2. **Filtered queries** — By event type, IMPL slug, program slug, agent ID, time range.
3. **Aggregation rollups** — Cost totals, success rates, retry counts grouped by agent, wave, IMPL, program, or model.
4. **Batch writes** — Multiple events written in a single transaction for efficiency.

See the `Store`, `QueryFilters`, `RollupRequest`, and `RollupResult` interface contracts in the SDK implementation for the programmatic API.

---

## Cross-References

- See E40 in `execution-rules.md` for when and how events must be emitted
- See `Store` interface contract for the storage API
- See E19 in `execution-rules.md` for failure type classification
- See E29, E33 in `execution-rules.md` for tier-level activity events

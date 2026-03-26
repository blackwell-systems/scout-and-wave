<!-- This file is injected by validate_agent_launch. Core workflow is in integration-agent.md. -->
# Integration Connectors Reference

`integration_connectors` is a field in the IMPL doc that declares which files the
Integration Agent is allowed to modify, and what wiring work is expected. They exist
because wave agents work in isolation with disjoint file ownership -- an agent that
creates `pkg/auth/handler.go` cannot also modify `cmd/server/main.go` to register
the handler, because `main.go` belongs to a different agent or is outside all agents'
ownership.

### When integration_connectors are used

Integration connectors are used in two scenarios:

1. **Reactive gap detection (E25/E26):** After a wave merges, `sawtools scan-stubs`
   detects unconnected exports -- new functions or types that exist but are never
   called. The Orchestrator launches an Integration Agent with these gaps plus the
   connector file list.

2. **Planned integration waves:** The Scout creates a `type: integration` wave in
   the IMPL doc when wiring work is predictable at planning time. The wave's agent
   `files` list serves the same role as `integration_connectors`, constraining which
   files the integration agent may touch.

When both a planned integration wave and `integration_connectors` exist, the planned
wave handles known wiring first, and E25/E26 catches any gaps the plan missed.

### AllowedPathPrefixes

The `AllowedPathPrefixes` field constrains which files the Integration Agent may
modify. It is derived from the `integration_connectors` entries in the IMPL doc.
The agent MUST NOT modify any file whose path does not start with one of the
allowed prefixes.

**Example IMPL doc integration_connectors:**

```yaml
integration_connectors:
  - file: cmd/saw/main.go
    description: "Register new CLI commands"
  - file: pkg/engine/finalize.go
    description: "Wire freeze-contracts into finalize-wave"
  - file: pkg/api/routes.go
    description: "Register new HTTP handlers"
```

This translates to `AllowedPathPrefixes: ["cmd/saw/main.go", "pkg/engine/finalize.go", "pkg/api/routes.go"]`. The agent may only modify these exact files.

### Relationship with type: integration waves

A `type: integration` wave in the IMPL doc is the preferred mechanism for planned
integration work. It is explicit, visible in the wave structure, and gives the human
a review opportunity. The wave's agent receives:

- The merged codebase (all prior waves applied)
- A task description specifying what to wire
- A `files` list constraining modifications (equivalent to `integration_connectors`)

**Example wave structure with integration wave:**

```yaml
waves:
  - number: 1
    agents:
      - id: A
        task: "Implement pkg/auth/handler.go"
        files: [pkg/auth/handler.go, pkg/auth/handler_test.go]
      - id: B
        task: "Implement pkg/metrics/collector.go"
        files: [pkg/metrics/collector.go, pkg/metrics/collector_test.go]
  - number: 2
    type: integration
    agents:
      - id: C
        task: "Wire auth handler and metrics collector into main.go and routes.go"
        files: [cmd/saw/main.go, pkg/api/routes.go]
```

In this example, Agent C runs after Wave 1 merges. It sees the exports from Agents
A and B and wires them into the registration points. Agent C may only modify
`cmd/saw/main.go` and `pkg/api/routes.go`.

### Common wiring patterns

- **New CLI command:** Add `rootCmd.AddCommand(pkg.NewXyzCmd())` in `cmd/*/main.go` or `root.go`
- **New HTTP handler:** Add `router.Handle("/path", pkg.NewHandler(deps...))` in a routes file
- **New service initialization:** Add constructor call in a startup/init sequence
- **New configuration option:** Add field to config struct and wire default value

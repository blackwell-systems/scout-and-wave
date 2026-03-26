<!-- Part of planner agent procedure. Loaded by validate_agent_launch hook. -->
# Example PROGRAM Manifest

Here's a complete example for a fictional greenfield project:

```yaml
# PROGRAM: task-manager-app
title: "Task Manager Web Application"
program_slug: task-manager-app
state: PLANNING
created: 2026-03-17
updated: 2026-03-17

requirements: "docs/REQUIREMENTS.md"

program_contracts:
  - name: "User"
    description: |
      Core user type shared by auth, API, and frontend.
    definition: |
      type User struct {
        ID        string    `json:"id"`
        Email     string    `json:"email"`
        Name      string    `json:"name"`
        CreatedAt time.Time `json:"created_at"`
      }
    consumers:
      - impl: "auth"
        usage: "Creates users, validates credentials"
      - impl: "api-routes"
        usage: "Reads user from session, returns in API responses"
      - impl: "frontend"
        usage: "Displays user info in header"
    location: "pkg/types/user.go"
    freeze_at: "Tier 1 completion"

  - name: "Task"
    description: |
      Core task type shared by API and frontend.
    definition: |
      type Task struct {
        ID          string    `json:"id"`
        UserID      string    `json:"user_id"`
        Title       string    `json:"title"`
        Description string    `json:"description"`
        Status      string    `json:"status"`
        CreatedAt   time.Time `json:"created_at"`
      }
    consumers:
      - impl: "api-routes"
        usage: "CRUD operations"
      - impl: "frontend"
        usage: "Displays in task list"
    location: "pkg/types/task.go"
    freeze_at: "Tier 1 completion"

impls:
  - slug: "data-model"
    title: "Data model and storage layer"
    tier: 1
    depends_on: []
    estimated_agents: 2
    estimated_waves: 1
    key_outputs:
      - "pkg/models/*.go"
      - "pkg/storage/*.go"
    status: pending

  - slug: "auth"
    title: "Authentication and session management"
    tier: 1
    depends_on: []
    estimated_agents: 2
    estimated_waves: 1
    key_outputs:
      - "pkg/auth/*.go"
      - "pkg/middleware/auth.go"
    status: pending

  - slug: "api-routes"
    title: "REST API route handlers"
    tier: 2
    depends_on: ["data-model", "auth"]
    estimated_agents: 4
    estimated_waves: 2
    key_outputs:
      - "pkg/api/*.go"
    status: pending

  - slug: "frontend"
    title: "React app shell, routing, and task views"
    tier: 2
    depends_on: ["auth"]
    estimated_agents: 3
    estimated_waves: 1
    key_outputs:
      - "web/src/components/*.tsx"
      - "web/src/App.tsx"
    status: pending

  - slug: "integration-tests"
    title: "End-to-end integration test suite"
    tier: 3
    depends_on: ["api-routes", "frontend"]
    estimated_agents: 2
    estimated_waves: 1
    key_outputs:
      - "tests/e2e/*.go"
    status: pending

tiers:
  - number: 1
    impls: ["data-model", "auth"]
    description: "Foundation — no dependencies, can execute fully in parallel"
  - number: 2
    impls: ["api-routes", "frontend"]
    description: "Core features — depend on Tier 1 outputs"
  - number: 3
    impls: ["integration-tests"]
    description: "Verification — depends on all prior tiers"

tier_gates:
  - type: build
    command: "go build ./... && cd web && npm run build"
    required: true
  - type: test
    command: "go test ./... && cd web && npm test"
    required: true

completion:
  tiers_complete: 0
  tiers_total: 3
  impls_complete: 0
  impls_total: 5
  total_agents: 0
  total_waves: 0

pre_mortem:
  - scenario: "User type lacks fields needed by frontend"
    likelihood: medium
    impact: medium
    mitigation: |
      Program contract defines all known User fields upfront. Tier 1 gate
      verifies User type exists with required fields before Tier 2 begins.
      If mismatch detected, Planner revises contract and Tier 1 IMPL re-scouts.
  - scenario: "API routes depend on auth middleware that doesn't exist yet"
    likelihood: low
    impact: high
    mitigation: |
      Program contracts explicitly list auth middleware as Tier 1 output.
      Dependency graph ensures auth IMPL completes before api-routes begins.
  - scenario: "Too many concurrent IMPLs in Tier 2"
    likelihood: low
    impact: low
    mitigation: |
      Tier 2 has only 2 IMPLs (api-routes, frontend). Both are independent
      and can execute in parallel. Orchestrator tracks both IMPL lifecycles
      separately.
```

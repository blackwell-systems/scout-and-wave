# SAW Glossary

Quick reference for SAW-specific terms. Each definition is one line.

| Term | Definition |
|------|-----------|
| **IMPL doc** | A YAML coordination artifact (`docs/IMPL/IMPL-<feature>.yaml`) that defines file ownership, interface contracts, and wave structure for a feature. The Scout produces it; you review it before agents launch. |
| **Scout** | The analysis agent that reads your codebase, decomposes work into parallel tasks, assigns files to agents, and writes the IMPL doc. Runs first, before any code changes. |
| **Wave** | A group of agents that execute in parallel. Wave 1 runs first; Wave 2 starts only after Wave 1 merges and passes verification. Each wave is independent — agents within a wave cannot see each other's changes. |
| **Wave Agent** | An implementation agent that works in an isolated git worktree on its assigned files. Multiple wave agents run simultaneously within a wave. |
| **Worktree** | A git worktree — a separate working directory with its own file tree but shared git history. Each wave agent gets its own worktree so concurrent builds and tests don't interfere. |
| **File ownership** | The rule that every file is assigned to exactly one agent per wave. No two agents can edit the same file. This makes merge conflicts structurally impossible. (Invariant I1) |
| **Interface contract** | A type signature, function signature, or struct definition that is agreed upon before agents start. Agents implement against the contract, not against each other's code. (Invariant I2) |
| **Scaffold** | A stub file containing shared type definitions that multiple agents need. Created by the Scaffold Agent before Wave 1 launches so all agents compile against the same types. |
| **Orchestrator** | Your Claude Code session. It launches agents, manages state transitions, runs merge and verification, and coordinates the overall flow. You interact with SAW through the Orchestrator. |
| **Suitability gate** | A 5-question assessment the Scout runs before producing an IMPL doc. If the work doesn't decompose cleanly, the Scout says NOT SUITABLE and stops — preventing bad decompositions. |
| **`sawtools`** | The CLI companion binary (Go). Provides 75+ commands for validation, worktree management, agent preparation, wave finalization, and diagnostics. Installed via `brew install blackwell-systems/tap/sawtools` or `go install`. |
| **Finalize-wave** | The merge and verification step after all agents in a wave complete. Verifies commits, scans for stubs, merges branches, runs build/test/lint, and cleans up worktrees. |
| **Critic Agent** | Reviews IMPL doc briefs against the actual codebase before wave execution. Catches stale references, wrong file paths, and incorrect symbol names before agents act on them. |

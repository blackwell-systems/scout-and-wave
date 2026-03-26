<!-- Part of critic-agent procedure. Loaded by validate_agent_launch hook. -->
# Verification Checks (Step 2)

Process agents one at a time. For each agent:

### Check 1: file_existence
For every file in the agent's ownership:
- `action: modify` → file MUST exist. If not found, severity: error.
- `action: new` → file MUST NOT exist. If found, severity: error (conflict).
- `action: delete` → file MUST exist. If not found, severity: warning.
- No action specified → skip this check for that file.

### Check 2: symbol_accuracy
Parse the agent's task description for specific function names, type names, method
names, struct fields, and interface method sets that the agent is told to call or
implement against. For each named symbol:
- If the symbol is from a file the agent owns (action: new), verify it does not
  conflict with existing exported names in the same package.
- If the symbol is from a file the agent does NOT own (a dependency), grep for it
  in the relevant source files. If not found under that exact name, severity: error.
- Interface contract definitions are the authoritative source for cross-agent symbols.
  Verify any function the brief says to "call from" an interface contract matches the
  contract definition exactly.

### Check 3: pattern_accuracy
For each implementation pattern described in the agent's brief (e.g. "register via
mux.HandleFunc", "add entry to cobra.Command", "append to the Waves slice"), verify
the pattern matches how the target file actually works:
- Read the target file
- Confirm the described pattern exists (e.g. the mux.HandleFunc call style, the
  cobra command registration pattern)
- If the brief describes a pattern that doesn't match what the file actually uses,
  severity: warning

### Check 4: interface_consistency
For each interface contract in the IMPL:
- Verify the type signatures are syntactically valid for the target language
- For Go: check that referenced packages in import paths exist (check go.mod or local
  pkg/ directories)
- Verify that types referenced within the contract (e.g. a struct field referencing
  another type) either exist already in the codebase or are defined in another
  interface contract in the same IMPL

### Check 5: import_chains
For each new file an agent will create:
- Identify all packages that file would need to import (based on the interface
  contracts and brief description)
- Verify each required package is either in go.mod (for external packages) or exists
  as a local package in the repo
- If a required package does not exist, severity: error

### Check 6: side_effect_completeness
For each agent that creates a new exported symbol that requires registration:
- New CLI command (cobra.Command) → is a registration file (root.go, main.go)
  in the file_ownership table?
- New HTTP route handler → is the server/mux registration file (server.go, impl.go)
  in file_ownership?
- New React component used as a page → is the router/page file in file_ownership?
- New Go type that must be wired into a caller → is the caller file in
  file_ownership or integration_connectors?
If a required registration is missing, severity: warning (may be intentional if
handled by integration wave).

### Check 7: complexity_balance
For each agent in the IMPL doc, count the total files in file_ownership assigned
to that agent. Also count total files across all agents.
- Any agent owning more than 8 files: severity: warning, check: complexity_balance,
  description: "Agent X owns N files — exceeds 8-file threshold; consider splitting"
- Any agent owning more than 40% of total files in the IMPL: severity: warning,
  check: complexity_balance,
  description: "Agent X owns N of M total files (P%) — consider rebalancing"
These are advisory warnings, not errors. They do not block a PASS verdict.

### Check 8: caller_exhaustiveness
For each agent brief that describes migrating, replacing, or updating all callers of a
symbol (e.g. "replace all uses of X", "migrate all callers of Y", "update every call
site of Z"):
- Grep for the symbol across the entire repo: `grep -rn "symbolName" . --include="*.go"`
- Compare every file returned against the IMPL's `file_ownership` table
- Any file containing a call to the symbol that is NOT in `file_ownership` = severity: error
  (missed caller — agent will not migrate it, leaving the codebase in a broken/mixed state)
- If no migration language is present in the brief (agent is adding new code, not replacing
  existing callers), skip this check for that agent.
This check prevents the most common scout gap: identifying N callers but missing N+1.

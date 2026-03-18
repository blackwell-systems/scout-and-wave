# Scout Prompt Trim Roadmap

Current: 929 lines → Target: ~548 lines (41% reduction)
Version: scout v0.11.0 → v0.12.0

## Principles
- No information loss — every concept preserved, just fewer words
- No structural changes — steps stay in same order, same numbering
- Tool output examples removed (Scout sees real output at runtime)
- Duplicated content consolidated to single location

## Items

### T1: Remove Output Format duplicate schema (~140 lines)
**Location:** Lines 720-896 (Output Format section)
**Problem:** Full YAML schema shown at lines 37-95, then repeated as a 150-line
example in Output Format. Plus stray `completion_reports: {}` block at 891-896.
**Cut:** Remove the duplicate schema example. Keep only the unique additions:
agent task field guidance (lines 726-732), NOT_SUITABLE shortcut (lines 902-904),
manifest size note (lines 906-908). Reference "schema shown above" instead.
**Status:** done (166 lines saved)

### T2: Remove Step 0 / Step 1 duplication (~10 lines)
**Location:** Lines 138-148 (Step 0) and 335-344 (Step 1)
**Problem:** "Read Project Memory / CONTEXT.md" appears identically in both places.
**Cut:** Remove Step 0 entirely. Step 1 under "Implementation Process" covers it.
**Status:** done (16 lines saved)

### T3: Condense Step 11 verification gates (~55 lines)
**Location:** Lines 601-682
**Problem:** Full `extract-commands` output example, 5 field mappings, linter
auto-fix orchestrator guidance, 4-language focused test table, 3 code examples.
**Cut:** Removed output example, redundant code blocks, timeout note. Kept
linter check-only rule (behavioral), 4-language table, field mappings.
**Status:** done (55 lines saved)

### T4: Condense Step 4 dependency tools (~40 lines)
**Location:** Lines 357-427
**Problem:** Full `analyze-deps` output format, full `detect-cascades` output
example, AST classification breakdown, verbose language fallback guidance.
**Cut:** Deferred — output field names and cascade rationale carry behavioral
guidance. Only ~25 lines saveable with real risk of losing nuance.
**Status:** deferred

### T5: Condense Suitability Q4 tool docs (~45 lines)
**Location:** Lines 181-253
**Problem:** Full `analyze-suitability` JSON output, classification heuristics
(internal to tool), prescriptive output format template for a free-form comment.
**Cut:** Removed JSON output, heuristics, template. Kept command, CONTEXT.md
cross-check, DONE/PARTIAL/TODO agent adjustment rules, documentation instruction.
**Status:** done (48 lines saved)

### T6: Condense Step 8 wave structure (~30 lines)
**Location:** Lines 516-576
**Problem:** Supported languages list duplicates step 4. Integration wave section
has verbose YAML example + 4-bullet differences + diagram notation.
**Cut:** Remove language list (already in step 4). Condense integration wave to:
YAML snippet + key differences in 2 lines + notation example.
**Status:** pending

### T7: Condense Suitability Q5 + time estimate (~30 lines)
**Location:** Lines 255-326
**Problem:** 4 factors with 3 lines each, 3 guidance tiers with 3 lines each,
15-line time estimate template that's already in the output schema.
**Cut:** Condense factors to a compact decision rule. Remove time estimate
template (already shown in schema comments). Keep the 3 verdict mappings
(high/low/coordination value) as one-liners.
**Status:** pending

### T8: Remove Step 5 legacy connectors (~15 lines)
**Location:** Lines 447-466
**Problem:** Says "use E27 instead" then shows the legacy `integration_connectors`
format with 6-line YAML example anyway.
**Cut:** Replaced with 4-line condensed version. Kept "when both exist" guidance.
**Status:** done (17 lines saved)

### T9: Deduplicate Rules section (~10 lines)
**Location:** Lines 910-928
**Problem:** "Disjoint file ownership is a hard constraint" stated 3 times:
invariants (line 117), step 7 (line 504), rules (lines 920-924). Worktree
isolation caveat also repeated.
**Cut:** Keep the rules that add new info (one-artifact rule, binding contracts,
agent scope preference). Remove rules that restate invariants.
**Status:** pending

### T10: Remove stray artifacts (~6 lines)
**Location:** Lines 891-896
**Problem:** Orphaned `completion_reports: {}` block and closing ``` outside
the main schema example.
**Cut:** Already removed as part of T1 (was inside the Output Format section).
**Status:** done (included in T1 count)

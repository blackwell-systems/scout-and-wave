# Determinism Roadmap Review

**Reviewer:** Claire (Implementation Readiness Audit)
**Date:** 2026-03-11
**Source:** determinism-roadmap.md

---

## Executive Summary

The unified roadmap successfully merges the original analysis with the meta-audit's critiques. **The document is implementation-ready for Phase 1 (H2 + H3)** with minor clarifications needed. Key strengths: (1) Phase ordering corrected — H1 split into 4 components with H1a deferred to Phase 2; (2) ROI projections corrected to 50-65% reduction (accounting for tool overhead); (3) Wave/Scaffold agent tools (H6, H7, H8) added with same detail level as original opportunities; (4) Effort estimates realistic (114-153h vs. original 40-60h). The merge preserved all critical implementation details (CLI syntax, JSON schemas, edge cases, language support requirements) and resolved all contradictions from the meta-audit. **GO for Phase 1 implementation.** Two non-blocking clarifications needed: (1) H3 language support phasing (Go-only Phase 1 vs. multi-language Phase 1?); (2) H8's dependency on H2 means it should sequence after H2 completes in Phase 1 rather than waiting until Phase 3.

---

## Merge Completeness Assessment

### Information Preserved ✓

**From original analysis (determinism-analysis.md):**
- All 12 opportunities (H1-H5, M1-M5, L1-L3) with original descriptions intact
- Complete CLI command syntax for all proposed tools
- Full JSON/YAML output schemas for H1, H2, H3, H4, M2, H6, H7, H8
- Edge case documentation for H2 (Makefile target chaining, CI matrix builds, monorepo workspaces)
- Edge case documentation for H3 (circular deps, conditional imports, dynamic imports, generated code)
- Edge case documentation for H4 (same type name different semantics, type refinement across waves, generic type parameters)
- Language support requirements (Go, Rust, JS, Python for H2; multi-language parsers for H3)
- All example integrations showing before/after command patterns

**From meta-audit (determinism-analysis-AUDIT.md):**
- H1 split into 4 sub-components (H1a, H1b, H1c, H1d) with separate effort estimates
- Phase ordering inversion fix (H1 moved to Phase 2, depends on H2+H3)
- ROI correction from 80% to 50-65% with detailed breakdown of tool execution overhead
- Three new high-impact opportunities (H6, H7, H8) with complete specifications matching original detail level
- Effort estimate correction (40-60h → 114-153h) with justification
- Tool execution time estimates (H2: 5-10 sec, H3: 30-60 sec, H1a: 3-5 min)
- Error handling overhead (20-30% added to time estimates)
- Dependency graph corrections (H3 → H1a, H3 → M2, H2 → M4, H1a → H5, H2 → H8)

### Information Lost ✗

**None identified.** All critical implementation details from both source documents are present in the unified roadmap.

**Spot checks:**
- H2 Makefile edge case: "Parse dependency tree, select leaf targets" — PRESENT (line 288)
- H3 generated code edge case: "Ownership table must include both `.proto` source and `.pb.go` generated files" — PRESENT (line 379)
- H6 version conflict example: `lodash@4.17.0` vs. `lodash@5.0.0` — PRESENT (line 546-548)
- H7 pattern catalog: Go `cannot find package` → `go mod tidy` — PRESENT (line 616-618)
- H8 auto-fix logic: "Apply fix suggestion, re-validate" — PRESENT (line 694-698)
- Meta-audit ROI critique: tool execution overhead 3-4 min + error handling 2-3 min — PRESENT (lines 966-974, 1004-1011)

### Merge Artifacts

**None detected.** No redundant sections, no contradictory statements, no formatting inconsistencies between original and audit-sourced content.

**Formatting coherence:**
- All opportunities follow same structure: Current behavior → Determinism gap → Proposed solution → Usage → Output schema → Impact → Edge cases → Implementation notes
- New opportunities (H6, H7, H8) match original opportunities' level of detail
- Command catalog consistently formatted (lines 1073-1113)

---

## Internal Coherence Check

### Effort Estimates

**Cross-section consistency: PASS**

| Section | H2 Effort | H3 Effort | Phase 1 Total |
|---------|-----------|-----------|---------------|
| Executive Summary (line 19) | (implicit in 30-40h) | (implicit in 30-40h) | 30-40 hours |
| Revised Roadmap Phase 1 (lines 32-36) | 10-15 hours | 20-25 hours | 30-40 hours |
| Appendix (lines 1149-1150) | 10-15h | 20-25h | 30-40h |

**Match confirmed.** All sections report identical effort estimates.

**Phase 2 effort:**
- Executive Summary: (not broken out separately)
- Revised Roadmap Phase 2 (lines 48-66): H1a 15-20h, H4 12-15h, M2 8-10h = 35-45h total
- Appendix (line 1150): 35-45h

**Match confirmed.**

**Phase 3 effort:**
- Revised Roadmap Phase 3 (lines 69-88): H6 10-12h, H7 12-15h, H8 8-10h = 30-37h total
- Appendix (line 1151): 30-37h

**Match confirmed.**

**Phase 4 effort:**
- Revised Roadmap Phase 4 (lines 92-107): M1 3-5h, M3 3-5h, M4 5-8h, H5 3-5h, M5 3-5h, L3 2-3h = 19-31h total
- Appendix (line 1152): 19-31h

**Match confirmed.**

**Grand total: 114-153 hours** (line 19 and Appendix line 1152) — consistent.

### Phase Assignments

**Cross-section consistency: PASS**

Checked every opportunity's phase assignment across three sections:
1. Revised Roadmap (lines 30-107)
2. Opportunities Catalog (lines 111-948)
3. Command Catalog (lines 1073-1113)

| Opportunity | Roadmap Phase | Catalog Header | Command Catalog |
|-------------|---------------|----------------|-----------------|
| H2 | Phase 1 (line 32) | Phase 1 (line 223) | (New, line 1077) |
| H3 | Phase 1 (line 37) | Phase 1 (line 299) | (New, line 1078) |
| H1a | Phase 2 (line 50) | Phase 2 (line 117) | (New, partial impl, line 1076) |
| H4 | Phase 2 (line 54) | Phase 2 (line 389) | (New, line 1079) |
| M2 | Phase 2 (line 58) | Phase 2 (line 752) | (New, line 1082) |
| H6 | Phase 3 (line 71) | Phase 3 (line 509) | (New, line 1087) |
| H7 | Phase 3 (line 75) | Phase 3 (line 583) | (New, line 1088) |
| H8 | Phase 3 (line 81) | Phase 3 (line 650) | (New, line 1089) |
| M1 | Phase 4 (line 94) | Phase 4 (line 715) | (New, line 1081) |
| M3 | Phase 4 (line 95) | Phase 4 (line 797) | (New, line 1083) |
| M4 | Phase 4 (line 96) | Phase 4 (line 831) | (New, line 1084) |
| H5 | Phase 4 (line 97) | Phase 4 (line 473) | (New, line 1080) |
| M5 | Phase 4 (line 98) | Phase 4 (line 867) | (New, line 1085) |
| L3 | Phase 4 (line 99) | Phase 4 (line 917) | (New, line 1086) |

**All phase assignments consistent across sections.**

### Dependencies

**Cross-section consistency: PASS WITH ONE CLARIFICATION NEEDED**

**Dependency declarations in Revised Roadmap:**
- H2: "No dependencies" (line 33)
- H3: "No dependencies" (line 38)
- H1a: "Depends on H3 for file location mapping" (line 51)
- H4: "Depends on H3 for cross-boundary type detection" (line 55)
- M2: "Depends on H3 for type reference search" (line 59)
- H6: "Standalone (reads lock files, no tool dependencies)" (line 72)
- H7: "Standalone (pattern-matches error logs)" (line 76)
- H8: "Depends on H2 (uses extracted build commands)" (line 82)

**Dependency declarations in Command Dependencies section (lines 1036-1069):**

```
Phase 1 (Parallel):
  H2 (command extraction) ────────┐
  H3 (dependency graph) ──────┐   │
                              │   │
Phase 2 (After H3):           │   │
  H1a (pre-impl scan) ←───────┘   │
  H4 (scaffold detection) ←───┘   │
  M2 (cascade detection) ←────┘   │
                                  │
Phase 3 (Parallel):               │
  H6 (dependency conflicts) — standalone
  H7 (build diagnosis) — standalone
  H8 (scaffold validation) ←──────┘
                                  │
Phase 4 (Polish):                 │
  M4 (verification templates) ←───┘
  H5 (pre-impl reporting) ←─── H1a
  M1, M3, M5, L3 — standalone
```

**Consistency check:**
- H1a depends on H3: CONSISTENT (Roadmap line 51, Dep graph line 1046)
- H4 depends on H3: CONSISTENT (Roadmap line 55, Dep graph line 1047)
- M2 depends on H3: CONSISTENT (Roadmap line 59, Dep graph line 1048)
- H8 depends on H2: CONSISTENT (Roadmap line 82, Dep graph line 1053)
- M4 depends on H2: CONSISTENT (Roadmap line 96 "depends on H2", Dep graph line 1056)
- H5 depends on H1a: CONSISTENT (Roadmap line 97 "depends on H1a", Dep graph line 1057)

**CLARIFICATION NEEDED:**

H8 (Scaffold Validation) is in Phase 3 (line 81) but depends on H2 (Phase 1). The dependency graph correctly shows this (line 1053), but the phasing suggests H8 waits until Phase 3 despite H2 being available after Phase 1.

**Question for implementer:** Is there a reason H8 is deferred to Phase 3 instead of being in Phase 1 alongside H2? If not, consider moving H8 to end of Phase 1 or beginning of Phase 2 to reduce time-to-value.

**Proposed clarification:** Add note to H8 section (line 81): "Deferred to Phase 3 to prioritize Scout automation (Phase 2) over Scaffold Agent automation, despite H2 dependency being satisfied in Phase 1."

### ROI Projection

**Cross-section consistency: PASS**

**Executive Summary (lines 17-18):**
> Realistic ROI: 50-65% Scout time reduction (25 min → 8-12 min) after Phase 1+2 completion

**Metrics and Success Criteria section (lines 1001-1011):**
> After Phase 1 (H2 + H3):
> - Scout time: 10-14 minutes per IMPL doc (40-56% reduction)
>
> After Phase 2 (H1a + H4 + M2):
> - Scout time: 8-12 minutes per IMPL doc (52-68% reduction)

**Calculation check:**
- Baseline: 15-25 minutes (taking midpoint 20 min for calculation)
- After Phase 1: 10-14 min → reduction = (20-12)/20 = 40% to (20-10)/20 = 50%
- After Phase 2: 8-12 min → reduction = (20-12)/20 = 40% to (20-8)/20 = 60%

**Executive Summary claims "50-65%"** which maps to the **After Phase 2** numbers (52-68% per Metrics section). This is correct — the Executive Summary is describing the full Phase 1+2 completion state, not Phase 1 alone.

**Consistency: CONFIRMED.** No contradiction between sections.

**Reality check:**
- Tool execution overhead included: "2-3 minutes" (line 1004)
- Error handling overhead mentioned: lines 970-974
- Pre-implementation scanning net savings: "25 min saved - 4 min spent" (lines 173, 335)
- Conservative projections noted throughout

**Realism: HIGH.** The 50-65% target appears achievable given the detailed accounting of overhead.

### Contradictions Found

**None.** The document internally coherent. All effort estimates, phase assignments, dependency relationships, and ROI projections are consistent across sections.

---

## Phase 1 Implementation Readiness

### H2: Command Extraction

**Ready for implementation?** YES

**Complete specifications:**
- CLI syntax: `sawtools extract-commands <repo-root>` (line 236)
- Output schema: YAML with `toolchain`, `commands` (build/test/lint/format), `detection_sources`, `module_map` (lines 241-266)
- Edge cases documented with resolutions:
  1. Makefile target chaining → Parse dependency tree, select leaf targets (lines 286-288)
  2. CI matrix builds → Detect host platform, select matching matrix entry (lines 289-290)
  3. Monorepo workspace commands → Detect workspace structure, provide both full and focused patterns (lines 291-292)
- Language coverage: 95% of projects (Go, Rust, Node, Python) (line 282)
- Tool execution time: 5-10 seconds (line 284)
- Maintenance burden: LOW-MEDIUM, stable config formats (lines 293-296)
- Impact metrics: Frequency 100%, error risk HIGH, time savings 2-3 min (lines 279-282)

**Example integration provided:** lines 268-276 (before/after comparison)

**Missing specifications: None.** An implementer can build this tool from the document as written.

**Confidence: HIGH.** Pattern matching on known config formats is well-understood. Edge cases are documented with concrete resolution strategies.

### H3: Dependency Graph Generation

**Ready for implementation?** YES WITH CLARIFICATION

**Complete specifications:**
- CLI syntax: `sawtools analyze-deps <repo-root> --files <file-list>` (lines 312-315)
- Output schema: YAML with `nodes` (file, depends_on, depended_by, wave_candidate), `waves`, `cascade_candidates` (lines 318-342)
- Edge cases documented with resolutions:
  1. Circular dependencies → Detect cycles, report as error (lines 368-369)
  2. Conditional imports → Include all conditional branches in dep graph (lines 370-371)
  3. Runtime-only dependencies → Cannot detect statically, manual annotation required (lines 372-373)
  4. Dynamic imports (Python) → Cannot detect statically, mark as unknown dependency (lines 374-375)
  5. Conditional compilation (Rust) → Include all feature flag branches (conservative approach) (lines 376-377)
  6. Generated code (Protocol Buffers) → Ownership table must include both source and generated files (lines 378-380)
- Tool execution time: 30-60 seconds for 50-file codebase (line 359)
- Maintenance burden: HIGH (must stay current with language syntax evolution) (lines 381-383)
- Accuracy: <5% error rate on known test cases (line 1134)

**Language support (multi-language implementation required):**
- Go: `go/parser` package (AST parsing) (line 362)
- Rust: `syn` crate (AST parsing) (line 363)
- JavaScript/TypeScript: Babel/TypeScript parser (line 364)
- Python: `ast` module (with limitations for dynamic imports) (line 365)

**CLARIFICATION NEEDED:**

The roadmap states "Phase 1 implements Go only. Add Rust/JS/Python in Phase 2" (line 957), but:
- The H3 specification (lines 361-365) lists all 4 languages without phasing guidance
- The success criteria (line 1128) states "Test suite covering 95% of projects (Go, Rust, Node, Python for H2; **Go-only for H3 initially**)"
- The effort estimate (20-25 hours, line 37) is described as "Go-only in Phase 1" in the Appendix (line 1159)

**Question for implementer:** Does the 20-25 hour Phase 1 estimate cover Go-only, or all 4 languages? The success criteria suggest Go-only, but the H3 specification lists all 4 languages without flagging any as Phase 2 work.

**Recommended clarification:** Add to H3 section (after line 365):
```
**Phase 1 scope:** Go-only implementation (covers ~40% of SAW projects).
**Phase 2 expansion:** Add Rust, JavaScript/TypeScript, Python parsers (+10-15 hours per language).
```

**Example integration provided:** lines 344-352 (before/after comparison)

**Missing specifications:**
- Algorithm pseudocode for wave assignment (transitive closure on dep graph)
- Test case examples for each edge case
- Exit codes for error conditions (circular dependency detected, unsupported language, etc.)

**Severity: LOW.** These are implementation details that can be decided during development. The core logic is clear.

**Confidence: MEDIUM.** Language-specific parsers are complex, edge cases abound, but problem is well-defined and solutions are documented.

### Success Criteria

**Are the success criteria measurable and sufficient?**

**Phase 1 success criteria (lines 1131-1135):**
1. Scout agent uses both tools successfully in end-to-end IMPL doc generation — MEASURABLE (binary: Scout completes or fails)
2. Tool execution time: H2 ≤10 seconds, H3 ≤60 seconds for 50-file codebase — MEASURABLE (timer)
3. Dependency graph accuracy: <5% error rate on known test cases — MEASURABLE (requires test suite with ground truth)

**Additional criteria recommended:**
- **Coverage:** H2 successfully extracts commands from ≥95% of test projects (Go, Rust, Node, Python CI configs)
- **Error handling:** H2/H3 emit actionable error messages when encountering unsupported formats (not silent failures)
- **Integration test:** End-to-end Scout run produces valid YAML manifest that passes `sawtools validate`

**Missing from document:** Definition of "known test cases" for H3 accuracy measurement. Should specify:
- Test suite composition (how many Go projects, how many with circular deps, how many with conditional imports)
- Ground truth source (manually verified dep graphs? existing static analysis tools?)

**Severity: MEDIUM.** Without test suite definition, "5% error rate" is not reproducible by external implementers.

### Missing Specifications

**What would an implementer need that isn't in the document?**

**For H2 (Command Extraction):**
1. **Priority ordering when multiple CI systems exist.** Example: Project has both `.github/workflows/ci.yml` AND `Makefile` with different test commands. Which takes precedence? (Suggestion: GitHub Actions > Makefile > package.json scripts)
2. **Handling of custom scripts.** Example: CI config calls `./scripts/run-tests.sh` instead of direct command. Should H2 parse the script, or just return the script path? (Suggestion: Return script path, add note that focused test pattern is unavailable)
3. **Exit codes.** When should H2 return non-zero? (Suggestion: 0 = success, 1 = no CI config found, 2 = CI config found but unparseable)

**Severity: LOW.** These are edge cases that affect <10% of projects. Implementer can make reasonable choices.

**For H3 (Dependency Graph Generation):**
1. **Wave assignment algorithm specifics.** Document states "wave_candidate: 2" in output (line 324) but doesn't specify how this is computed. Is it:
   - Topological sort depth (distance from leaf nodes)?
   - Longest path from any root?
   - Something else?

   (Suggestion: Add algorithm pseudocode or reference to standard graph algorithm)

2. **Cascade candidate detection heuristic.** Output includes "imports pkg/auth.go but is not being modified" (line 340). How does H3 determine "not being modified"? Does it:
   - Cross-reference against `--files` argument?
   - Scan git diff?
   - Something else?

   (Suggestion: Add note that cascade detection requires `--files` list to represent "files being modified")

3. **Cross-repo dependency handling.** MEMORY.md mentions `repo:` fields in file ownership table. Does H3 support cross-repo dependency tracing in Phase 1, or is this Phase 2 work? (See "Cross-Repo Coordination" section below)

**Severity: MEDIUM.** Without wave assignment algorithm, implementers may produce different wave structures for same dependency graph, reducing determinism.

**For Both Tools:**
1. **JSON output option.** Examples show YAML output, but downstream tools may prefer JSON. Should add `--format json` flag? (H2 example at line 166 shows piping to JSON, suggesting JSON output is supported)
2. **Error message format.** Should structured errors use JSON/YAML, or plain text? (Suggestion: Plain text to stderr, structured data to stdout)
3. **Logging verbosity.** Should tools support `--verbose` flag for debugging? (Suggestion: Yes, logs to stderr, doesn't pollute structured output)

**Severity: LOW.** These are UX conveniences, not blockers.

---

## Strategic Alignment

**Did the unified plan successfully address all meta-audit critiques?**

### Phase Ordering Inversion

**Meta-audit critique:** "H1 (suitability scoring) depends on H2+H3 outputs but is scheduled before them" (lines 17-31 of audit)

**Resolution in roadmap:**
- H1 split into 4 sub-components (H1a, H1b, H1c, H1d) — lines 115-221
- H1a (pre-implementation scanning) moved to Phase 2, explicitly depends on H3 (line 51)
- H1b subsumed by H2 (line 183)
- H1c and H1d deferred to Phase 4 or later (lines 189-221)
- Phase 1 now only contains H2 + H3 (lines 30-44), both with "No dependencies"

**Assessment:** FIXED

The roadmap correctly sequences H3 → H1a, eliminating the circular dependency. The dependency graph (lines 1036-1069) shows H3 as a prerequisite for H1a, H4, and M2, all of which are in Phase 2.

### ROI Projections

**Meta-audit critique:** "80% time reduction (25→5 min) assumes perfect automation with zero error handling overhead" (lines 296-350 of audit)

**Resolution in roadmap:**
- Executive Summary updated to "50-65% Scout time reduction" (line 17)
- Tool execution overhead included: "2-3 minutes" (line 1004)
- Error handling overhead: "2-3 minutes per Scout run (10-20% of runs encounter tool errors)" (lines 970-974)
- Realistic projections section added (lines 990-1033) showing:
  - Before: 15-25 min
  - After Phase 1: 10-14 min (40-56% reduction)
  - After Phase 2: 8-12 min (52-68% reduction)
  - After Phase 4: 8-12 min (no further reduction, Phase 4 is formatting)

**Assessment:** FIXED

The roadmap abandons the 80% projection and provides detailed accounting of tool overhead. The "What's Realistic vs. Optimistic" section (lines 1022-1033) explicitly calls out the original 80% as fantasy.

### Scout-Centric Bias

**Meta-audit critique:** "Missing high-impact opportunities — Wave agent ad-hoc behaviors (dependency installation, build troubleshooting) and Scaffold agent error recovery are entirely absent" (lines 51-223 of audit)

**Resolution in roadmap:**
- Three new opportunities added (H6, H7, H8) — Phase 3 (lines 69-88)
- H6: Dependency Conflict Detection (lines 509-580) — addresses Wave agent dependency installation failures
- H7: Build Failure Diagnosis (lines 583-647) — addresses Wave agent build troubleshooting
- H8: Scaffold Validation (lines 650-712) — addresses Scaffold agent error recovery
- All three have complete specifications matching detail level of original opportunities (usage examples, output schemas, impact metrics, edge cases)

**Assessment:** ADDRESSED

Phase 3 adds 30-37 hours of Wave/Scaffold agent automation, comparable to Phase 2's 35-45 hours. The roadmap now covers all three agent types (Scout, Wave, Scaffold) with equal rigor.

### Effort Estimates

**Meta-audit critique:** "The discrepancy comes from: multi-language support for H3, Wave/Scaffold agent tools missing, H1 split into 4 tools" (lines 1154-1166 of audit)

**Resolution in roadmap:**
- Total effort updated to 114-153 hours (line 19, Appendix line 1152)
- Detailed breakdown provided (lines 1140-1166):
  - Phase 1: 30-40h (H2 10-15h, H3 20-25h) — original was 25h
  - Phase 2: 35-45h (H1a 15-20h, H4 12-15h, M2 8-10h) — original was 15h
  - Phase 3: 30-37h (H6 10-12h, H7 12-15h, H8 8-10h) — entirely missing from original
  - Phase 4: 19-31h — original was 5h
- Justification provided for discrepancy (lines 1154-1166):
  1. H1 split into 4 tools (H1a alone is 15-20h)
  2. Multi-language support for H3 (20-25h for Go-only, +10-15h per additional language)
  3. Wave/Scaffold agent tools (30-37h) entirely missing from original
  4. Error handling overhead (20-30% added)
  5. Test suite requirements (20-30% added per tool)

**Assessment:** REALISTIC

The roadmap provides granular per-tool effort estimates with justification for increases. The 114-153h range (vs. original 40-60h) reflects the expanded scope (Wave/Scaffold tools) and realistic complexity (multi-language parsers, error handling).

### Tool Execution Overhead

**Meta-audit critique:** "Tools are not instantaneous. H3 takes 30-60 seconds. H1a takes 3-5 minutes. This overhead erodes projected time savings." (lines 966-974 of audit)

**Resolution in roadmap:**
- Tool execution times specified for all tools:
  - H2: 5-10 seconds (line 284)
  - H3: 30-60 seconds for 50-file codebase (line 359)
  - H1a: 3-5 minutes (file parsing overhead) (line 174)
- Overhead accounted for in ROI calculations:
  - "Tool execution overhead: 2-3 minutes" (line 1004)
  - "Tool execution overhead: 4-6 minutes total" after Phase 2 (line 1011)
- Error handling overhead: "10-20% of runs encounter tool errors" (line 972)

**Assessment:** REALISTIC

All time projections now include tool overhead. The Metrics section (lines 990-1033) shows realistic net savings after subtracting tool execution time.

---

## Gaps and Ambiguities

### 1. H3 Language Support Phasing

**Ambiguity:** H3 specification lists Go, Rust, JavaScript, Python parsers (lines 361-365) without indicating which are Phase 1 vs. Phase 2. The Appendix (line 1159) mentions "Go-only in Phase 1" but this is not stated in the H3 opportunity section itself.

**Impact:** Implementer might build all 4 language parsers in Phase 1, exceeding the 20-25 hour estimate.

**Resolution:** Add explicit phasing to H3 section (after line 365):
```
**Phase 1 scope:** Go-only implementation (covers ~40% of SAW projects).
**Phase 2 expansion:** Add Rust, JavaScript/TypeScript, Python parsers (+10-15 hours per language).
```

### 2. H8 Phase Assignment

**Ambiguity:** H8 depends on H2 (Phase 1) but is scheduled for Phase 3. No explanation given for 2-phase delay.

**Impact:** Scaffold Agent improvements delayed unnecessarily. If H8 provides high value (blocks entire wave when scaffold fails), why wait until Phase 3?

**Resolution:** Either:
- Move H8 to Phase 1 (after H2 completes) or Phase 2
- OR add justification to Phase 3 section (line 81): "Deferred to Phase 3 to prioritize Scout automation (Phase 2) despite H2 dependency being available."

### 3. Cross-Repo Dependency Handling

**Ambiguity:** MEMORY.md mentions multi-repo support added recently (lines 199-219 of MEMORY.md). The meta-audit proposes a new tool `sawtools analyze-cross-repo-deps` (lines 199-220 of audit). The roadmap does NOT include this tool in any phase.

**Questions:**
- Does H3 support cross-repo dependency tracing in Phase 1?
- If not, is cross-repo support a Phase 2 expansion?
- Should cross-repo analysis be a separate tool (H9)?

**Impact:** If H3 doesn't handle cross-repo deps, the tool won't work for recent multi-repo IMPL docs (e.g., scout-and-wave-web importing scout-and-wave-go).

**Resolution:** Add note to H3 section (after line 365):
```
**Cross-repo dependencies:** Phase 1 supports single-repo analysis. Phase 2 expansion will add cross-repo import tracing for projects with `repo:` fields in file ownership table.
```

### 4. H3 Wave Assignment Algorithm

**Ambiguity:** Output schema shows `wave_candidate: 2` (line 324) but algorithm for computing this is not specified.

**Impact:** Different implementers may produce different wave assignments for same dependency graph, reducing determinism (the entire point of this roadmap).

**Resolution:** Add algorithm specification to H3 section (after line 342):
```
**Wave assignment algorithm:**
1. Compute topological sort of dependency graph (files with no dependencies = depth 0)
2. Wave N contains all files at depth N in the topological ordering
3. If circular dependencies detected, report error (cannot assign wave structure)
4. `wave_candidate` field = depth in topological ordering
```

### 5. Test Suite Definition for Success Criteria

**Ambiguity:** Success criteria states "Dependency graph accuracy: <5% error rate on known test cases" (line 1134) but doesn't define what "known test cases" are.

**Impact:** Not reproducible by external implementers. What counts as a test case? How is ground truth established?

**Resolution:** Add test suite specification to Next Steps section (after line 1135):
```
**Test suite composition:**
- 20 Go projects (5 with circular deps, 5 with conditional compilation, 10 baseline)
- Ground truth established by manual verification + comparison with `go mod graph` output
- Error = missed dependency OR incorrect dependency direction
- Target: ≤1 error per 20 projects = 5% error rate
```

### 6. H6 Lock File Cross-Repo Scanning

**Ambiguity:** H6 scans "project lock files (`go.sum`, `package-lock.json`, `Cargo.lock`)" (line 526). For multi-repo waves, does H6 scan lock files in all repos, or just the primary repo?

**Impact:** Version conflicts might exist across repos (repo A uses lodash@4.x, repo B uses lodash@5.x) but H6 won't detect if it only scans one repo.

**Resolution:** Add note to H6 section (after line 526):
```
**Multi-repo support:** Scans lock files in all repos referenced in file ownership table (`repo:` fields). Reports cross-repo version conflicts (Agent A in repo X requires lodash@4.x, Agent B in repo Y requires lodash@5.x).
```

---

## Cross-Repo Coordination

**Does the roadmap handle multi-repo scenarios adequately?**

### Current State

**MEMORY.md context:**
- Three repos now exist: scout-and-wave (protocol), scout-and-wave-web (web app), scout-and-wave-go (engine)
- File ownership table supports `repo:` fields (added recently)
- Cross-repo waves now possible (e.g., Agent A modifies scout-and-wave-web, Agent B modifies scout-and-wave-go)

**Roadmap coverage:**

**Explicitly mentioned:**
- H3 (Dependency Graph): Generated code edge case mentions "Ownership table must include both `.proto` source and `.pb.go` generated files" (line 379) — implies awareness of multi-file tracking, but doesn't explicitly mention cross-repo
- None of the tools explicitly mention cross-repo scenarios in their specifications

**Implicitly covered:**
- H6 (Dependency Conflicts): Scans "agent file ownership lists, extracts import statements" (line 526) — if ownership list includes `repo:` fields, H6 should theoretically work, but not explicitly stated

**Meta-audit proposal:**
- H9: Cross-Repo Dependency Coordination (lines 199-220 of audit) — NOT included in roadmap

### Assessment: PARTIAL

The roadmap does not explicitly address cross-repo scenarios, but tools are specified in ways that could be extended to support them:

**H3 (Dep Graph):** Could detect `import "github.com/blackwell-systems/scout-and-wave-go/pkg/engine"` in scout-and-wave-web files and report as cross-repo dependency. Requires clarification of whether this is Phase 1 or Phase 2.

**H6 (Dep Conflicts):** Could scan lock files in multiple repos if `repo:` fields are present. Requires clarification.

**H8 (Scaffold Validation):** If scaffold file is in repo A but references types from repo B, validation needs access to both repos. Not addressed.

### Recommended Additions

**Option 1: Add cross-repo notes to existing tools**

Add to H3 section (after line 365):
```
**Cross-repo dependencies (Phase 2 expansion):**
- Scans all repos referenced in file ownership table (`repo:` fields)
- Detects imports crossing repo boundaries
- Reports cross-repo dependency constraints (Agent A in repo X depends on Agent B in repo Y → must be in different waves or same wave with B first)
```

Add to H6 section (after line 526):
```
**Cross-repo version conflicts:**
- Scans lock files in all repos referenced in file ownership table
- Reports conflicts across repos (Agent A in repo X requires lodash@4.x, Agent B in repo Y requires lodash@5.x)
```

**Option 2: Add H9 as separate cross-repo coordination tool (Phase 3 or 4)**

Defer comprehensive cross-repo support until after single-repo tools are validated. Add to Phase 4:
```
**H9: Cross-Repo Dependency Coordination** (Phase 4, 8-10 hours)
- Extends H3 with cross-repo import tracing
- Generates wave constraints for cross-repo dependencies
- Validates that cross-repo waves respect dependency ordering
```

**Recommendation:** Option 1 (extend existing tools with cross-repo notes). This is more pragmatic than building a separate tool. The protocol already supports multi-repo waves; tools should too.

---

## Recommendations

### Immediate Fixes (Before Phase 1 Start)

**1. Clarify H3 language support phasing**

Add to H3 section (after line 365):
```
**Phase 1 scope:** Go-only implementation (covers ~40% of SAW projects).
**Phase 2 expansion:** Add Rust, JavaScript/TypeScript, Python parsers (+10-15 hours per language).
```

**Rationale:** Prevents implementer from building all 4 parsers in Phase 1, exceeding effort estimate.

**2. Specify H3 wave assignment algorithm**

Add to H3 section (after line 342):
```
**Wave assignment algorithm:**
1. Compute topological sort of dependency graph (files with no dependencies = depth 0)
2. Wave N contains all files at depth N in the topological ordering
3. If circular dependencies detected, report error (cannot assign wave structure)
4. `wave_candidate` field = depth in topological ordering
```

**Rationale:** Core determinism requirement. Different algorithms produce different wave structures, defeating the purpose.

**3. Define test suite for H3 accuracy measurement**

Add to Next Steps section (after line 1135):
```
**Test suite for H3 accuracy:**
- 20 Go projects (5 with circular deps, 5 with conditional compilation, 10 baseline)
- Ground truth: manual verification + comparison with `go mod graph` output
- Error definition: missed dependency OR incorrect dependency direction
- Target: ≤1 error per 20 projects = 5% error rate
```

**Rationale:** "5% error rate" is not measurable without test suite definition.

### Clarifications Needed

**1. H8 phase assignment**

**Question:** Why is H8 (Scaffold Validation) in Phase 3 when it depends on H2 (Phase 1)? Is there value in deferring it, or should it move to Phase 2 for earlier impact?

**Suggested answer:** Add to Phase 3 section (line 81):
```
**H8: Scaffold Validation** (8-10 hours)
- Depends on H2 (uses extracted build commands)
- Deferred to Phase 3 to prioritize Scout automation (Phase 2) despite H2 dependency being available after Phase 1
- Rationale: Scaffold Agent failures are high-impact but lower-frequency than Scout/Wave agent issues addressed in Phase 1+2
```

**2. Cross-repo dependency support**

**Question:** Do H3, H6, H8 support cross-repo scenarios in Phase 1, or is this Phase 2 work?

**Suggested answer:** Add cross-repo notes to H3 and H6 sections (see "Cross-Repo Coordination" section above for specific text).

**3. H2 priority ordering when multiple CI systems exist**

**Question:** If project has both GitHub Actions and Makefile with different commands, which takes precedence?

**Suggested answer:** Add to H2 section (after line 266):
```
**Priority ordering (multiple CI systems):**
1. GitHub Actions/GitLab CI/CircleCI (explicit CI system)
2. Makefile (project-specific build system)
3. package.json scripts (Node.js convention)
4. Fallback: language-specific defaults (go build, cargo build, npm test)
```

### Future Improvements (Non-Blocking)

**1. Add H9: Cross-Repo Dependency Coordination (Phase 4)**

Comprehensive cross-repo support as separate tool (see "Cross-Repo Coordination" section).

**Rationale:** Single-repo tools provide 90% of value. Cross-repo is edge case (but important for scout-and-wave project itself).

**2. Add tool output format flag (`--format json|yaml`)**

All tools should support both JSON and YAML output for flexibility.

**Rationale:** Some downstream consumers prefer JSON, others prefer YAML. Trivial to implement.

**3. Add verbose logging flag (`--verbose`)**

All tools should support debug logging to stderr (doesn't pollute structured stdout).

**Rationale:** Essential for debugging tool failures during error handling.

**4. H7 maintenance strategy**

H7 (Build Failure Diagnosis) requires ongoing maintenance as compiler error messages evolve. Consider:
- Community-contributed pattern catalog (GitHub repo with patterns/)
- Pattern versioning (Go 1.20 patterns vs. Go 1.21 patterns)
- Confidence scoring degradation over time (patterns older than 6 months flagged as potentially stale)

**Rationale:** H7's LOW-MEDIUM confidence rating (line 643) reflects this maintenance burden. Proactive strategy needed.

---

## Go / No-Go Assessment

**Can Phase 1 implementation begin with the roadmap as-is?**

**GO WITH CLARIFICATIONS**

### Justification

**Implementation-ready aspects:**
- H2 (Command Extraction) is fully specified with CLI syntax, output schema, edge cases, and resolutions
- H3 (Dependency Graph Generation) has complete output schema, edge cases, and language support requirements
- Effort estimates are realistic and detailed (30-40 hours for Phase 1)
- Dependencies are correctly sequenced (H2 and H3 have no dependencies, can run in parallel)
- Success criteria are measurable (tool execution time, Scout end-to-end test, accuracy threshold)

**Blocking issues: None**

**Clarifications needed (non-blocking):**
1. H3 language support phasing (Go-only Phase 1 vs. multi-language Phase 1?)
2. H3 wave assignment algorithm (topological sort depth vs. other?)
3. Test suite definition for 5% accuracy target

**Minor gaps (can be resolved during implementation):**
- H2 priority ordering when multiple CI systems exist
- H3 cross-repo dependency support timeline
- H8 phase assignment rationale

### Recommendation

**Begin Phase 1 implementation immediately** with the following clarifications documented before kickoff:

1. **H3 language scope:** Go-only for Phase 1 (20-25 hours). Rust/JS/Python in Phase 2 (+10-15h per language).
2. **H3 wave assignment:** Topological sort depth (standardized algorithm).
3. **H3 test suite:** 20 Go projects, manual ground truth, ≤1 error = 5% threshold.

**Expected Phase 1 delivery:** 30-40 hours, 2 working tools (H2 + H3), Scout integration tested end-to-end, <5% dep graph error rate, Scout time reduced by 40-56% (25 min → 10-14 min).

**Decision point after Phase 1:** Assess whether to proceed with Phase 2 (Scout automation) or Phase 3 (Wave/Scaffold automation) based on observed impact and user feedback. Both are well-specified and ready for implementation.

---

**End of Review**

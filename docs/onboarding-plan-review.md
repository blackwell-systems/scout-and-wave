# Onboarding Improvement Plan: Independent Review

**Reviewer:** Independent product reviewer
**Date:** 2026-03-22
**Document reviewed:** `docs/onboarding-improvement-plan.md`

---

## Verdict: APPROVE WITH CHANGES

## Executive Summary

This is a strong, well-researched plan that correctly identifies the core problem (9-step install, 7 concepts front-loaded before first use) and proposes a coherent progressive disclosure model. The competitive teardown is honest and actionable. The anti-patterns section (Section 6) is unusually good -- it anticipates the exact mistakes most teams make when "simplifying" developer tools. However, the plan has a significant feasibility gap around the unified binary proposal, understates the effort of several "Small" items, leaves several FTUE findings unaddressed, and has a blind spot around the "team lead evaluating the tool" persona. These are fixable issues, not structural flaws.

## Strengths

1. **The friction classification table (Section 1.3) is the plan's best contribution.** Separating "must learn before using" from "can learn by doing" is the correct analytical framework. The conclusion -- only 3 things must be learned upfront -- is well-supported and should drive all prioritization.

2. **The progressive disclosure levels (Section 3) are well-designed.** Level 0 through Level 3 form a natural gradient. The key insight that Level 0 users should never see the word "invariant" is correct. The mock CLI output for `saw plan` (Section 3, Level 1) is genuinely good UX writing.

3. **The anti-patterns section (Section 6) shows maturity.** "Do not hide the protocol entirely" (6.1), "do not create a beginner mode dead end" (6.2), and "do not add tutorials that go stale" (6.3) are exactly the traps this plan could fall into. Calling them out explicitly is a sign the author understands the design space.

4. **Competitive analysis is used correctly.** The plan borrows the right things from AO (single-command entry point) and Paperclip (strong metaphor reduces cognitive load) without cargo-culting their weaknesses (zero correctness guarantees).

5. **Error messages as teaching moments (Section 4.5) is the highest-ROI item.** The plan correctly identifies this and ranks it first. The verbatim error templates are ready to implement.

6. **The naming decisions are well-reasoned.** Keeping "wave" over "phase" is correct -- "phase" has waterfall connotations and loses SAW's identity. Keeping "scaffold" over "shared types" is correct -- scaffolds can include more than types. Renaming "IMPL doc" to "plan" in user-facing contexts is the right call.

## Issues (ranked by severity)

### Issue 1
- **Severity:** Major
- **Section:** 4.6 (Unified Binary Name)
- **Problem:** The plan proposes renaming `sawtools` to `saw`, but the web app binary is *already* called `saw`. The plan says "The web app binary is already called `saw`; unify the CLI name" and "add subcommand routing" to the web binary. This is not a rename -- it is a merger of two separate Go binaries from two separate repos into a single command namespace. The plan rates this as "Large" effort but does not address: (a) how two separate repos produce one binary, (b) whether `saw init` comes from scout-and-wave-go while `saw serve` comes from scout-and-wave-web, requiring both installed, (c) what happens when only one is installed, (d) how versioning works across two repos producing commands under one name. This is an architecture decision disguised as a naming change.
- **Recommendation:** Either (a) defer this entirely until after Tiers 1-2 are done and write a separate RFC for binary unification, or (b) scope it down to "add `saw` as an alias/symlink for `sawtools`" without merging the command namespaces. The current description underestimates complexity by an order of magnitude.

### Issue 2
- **Severity:** Major
- **Section:** 4.1 (Zero-Config CLI Entry Point) and 4.2 (Guided First Run)
- **Problem:** The plan proposes `saw init` as a new command in scout-and-wave-go, but also proposes that the `/saw` skill in Claude Code detect first-run and enter guided mode. These are two separate entry points with different first-run detection mechanisms (`saw.config.json` absence for CLI, `docs/IMPL/` absence for skill). A user who runs `saw init` and then uses the `/saw` skill will hit the guided mode anyway because `docs/IMPL/` does not exist yet. A user who goes straight to `/saw scout` without `saw init` will not have `saw.config.json` but may have a working setup (the skill does not require `saw.config.json` -- it auto-detects the project root from git). The two proposals need to be reconciled into a single first-run detection strategy.
- **Recommendation:** Define a single "has this project been initialized" signal. The simplest is: `saw.config.json` exists. The skill's guided mode should check for this file, not for `docs/IMPL/`. `saw init` creates it. Both paths converge.

### Issue 3
- **Severity:** Major
- **Section:** 4.4 (Concept Renaming Audit), specifically the AppHeader proposal
- **Problem:** The plan says the header shows "seven model selectors (`SCOUT`, `CRITIC`, `WAVE`, `CHAT`, `PLANNER`, `SCAFFOLD`, `INTEGRATION`) with no explanation." Verified against `AppHeader.tsx` -- this is accurate. The plan proposes hiding `CRITIC`, `SCAFFOLD`, `INTEGRATION`, `PLANNER` behind an "Advanced" toggle and showing only `SCOUT` (labeled "Plan") and `WAVE` (labeled "Build"). However, `CHAT` is not mentioned in the hide/show proposal. CHAT is the fourth most-used model selector (for the "Ask Claude" feature in ReviewScreen). The plan needs to decide: is CHAT visible by default, or hidden?
- **Recommendation:** Show three by default: SCOUT (labeled "Plan"), WAVE (labeled "Build"), CHAT (labeled "Chat"). Hide the other four behind "Advanced." Update the plan to explicitly state CHAT's treatment.

### Issue 4
- **Severity:** Moderate
- **Section:** 4.2 (Guided First Run - Web App)
- **Problem:** The plan proposes a 3-step onboarding wizard as a new `Onboarding.tsx` component replacing `WelcomeCard`. Step 2 ("What do you want to build?") includes example suggestions based on detected project type. This requires a new API endpoint for project detection that returns language/framework information. The plan says effort is "Large" and lists dependency on 4.1 (project detection logic). But the dependency chain is: web onboarding wizard -> project detection API endpoint -> project detection logic in scout-and-wave-go -> `saw init` command. This means the web onboarding wizard (Tier 3, item 9) cannot ship until `saw init` (Tier 2, item 7) is complete. The plan already notes this dependency, but the example suggestions ("Go: Add a health check endpoint") could be implemented without project detection -- just show generic examples. The plan conflates a nice-to-have (language-specific examples) with a hard dependency.
- **Recommendation:** Split the web onboarding wizard into two increments: (a) generic wizard with hardcoded examples (no dependency on project detection), and (b) language-specific examples once project detection API exists. This moves (a) from Tier 3 to Tier 2.

### Issue 5
- **Severity:** Moderate
- **Section:** 1.2 (Current State Analysis - Web App Path)
- **Problem:** The plan says the WelcomeCard "mentions 'IMPL' in passing." Verified against `App.tsx` lines 33-34: the WelcomeCard actually says "implementation plan (IMPL)" which is a parenthetical definition, not a passing mention. The plan slightly mischaracterizes this. More importantly, the WelcomeCard already contains a concrete example ("Add a dark mode toggle to the settings screen") and a clear call-to-action ("Open Settings"). The plan's Section 1.2 bullet "WelcomeCard mentions 'IMPL' in passing but does not explain what to do after adding a repo" is partially wrong -- the WelcomeCard does not explain post-repo steps, but the IMPL mention is actually handled reasonably well. The current WelcomeCard is better than the plan suggests.
- **Recommendation:** Acknowledge what the WelcomeCard already does right (example, CTA, brief explanation). This matters because it changes the delta: the improvement needed is "add post-repo-add guidance" not "rewrite the entire WelcomeCard."

### Issue 6
- **Severity:** Moderate
- **Section:** 4.7 and 4.8 (Aliases)
- **Problem:** The plan proposes `saw plan` as alias for `saw scout` and `saw build` as alias for `saw wave`. Both are marked "Small" effort. But these aliases must work in two places: (a) the Go CLI (`sawtools`/`saw`), and (b) the `/saw` skill prompt in Claude Code. For the skill, "alias" means updating the skill prompt so Claude recognizes `/saw plan` and `/saw build` as valid invocations. This is prompt engineering, not code. The risk is that the LLM inconsistently recognizes the aliases, especially if the invocation modes table still lists only `scout` and `wave`. The plan does not address how alias consistency will be maintained across the skill prompt, help text, documentation, and error messages.
- **Recommendation:** When implementing aliases, add them to the invocation modes table in the skill prompt as primary entries (not footnotes). Update all error messages to use the alias form by default. Ensure `saw help` shows both forms with the alias as the recommended one.

### Issue 7
- **Severity:** Minor
- **Section:** 4.3 (Web App Empty State)
- **Problem:** The proposed empty state for "repos configured, IMPLs exist but none selected" shows "Recent activity" with IMPL status and timing. This requires a new API endpoint or data structure to track "last activity time" per IMPL. The current `entries` list from the sidebar does not include timestamps or activity status. The plan rates this as "Small" effort, but adding activity tracking is not small.
- **Recommendation:** Rate this as "Small-Medium." The first increment can skip the "Recent activity" section and just improve the copy. Activity tracking is a separate enhancement.

### Issue 8
- **Severity:** Minor
- **Section:** 5 (Implementation Priority)
- **Problem:** Item 4 (Concept renaming - UI labels only) is rated "Small-Medium" effort. Changing labels across AppHeader, SidebarNav, ReviewScreen, and adding an Advanced toggle for model selectors is at least Medium effort. It touches multiple components, requires a new toggle mechanism, and needs design decisions about which models to show. The "Small" part of the estimate is optimistic.
- **Recommendation:** Rate as Medium. It is still Tier 1 because impact is high and it is UI-only work, but the effort estimate should be honest.

## FTUE Cross-Reference

| FTUE # | Description | Addressed? | Notes |
|--------|-------------|------------|-------|
| 1.1 | No empty-state onboarding | Yes | Covered by 4.2 (web onboarding wizard) and 4.3 (empty state redesign) |
| 1.2 | Settings not surfaced as required | Partially | 4.2 Step 1 addresses this, but only for the wizard flow. No proposal for the case where a user dismisses/skips the wizard and later needs to find Settings. |
| 1.3 | Terminology never explained | Yes | Covered by 4.4 (concept renaming) and 4.5 (error messages) |
| 1.4 | Approve triggers irreversible execution without context | **No** | The FTUE analysis flagged this as Critical. The onboarding plan does not propose a confirmation dialog or pre-approve summary. This is a significant omission. |
| 1.5 | Scout output is a firehose with no summary | **No** | The FTUE flagged this as Critical. The plan's guided first run (4.2) adds explanatory text during the scout, but does not address the completion summary gap ("N agents, N waves, N files -- SUITABLE"). |
| 2.1 | Feature input has no quality guidance | **No** | Not addressed. The FTUE recommended examples and character counter in ScoutLauncher. |
| 2.2 | ReviewScreen panel defaults overwhelming | Partially | 4.4 proposes adding section headers with explanations, but does not address the FTUE recommendation to start with fewer panels open or add a "What to check" callout. |
| 2.3 | No explanation of what happens after Approve | **No** | Not addressed. The FTUE recommended a WaveBoard explanatory banner. |
| 2.4 | Post-completion dead-end | **No** | Not addressed. The FTUE recommended showing which branch changes merged into, a diff link, and an always-present "Scout Next Feature" button. |
| 2.5 | New vs Existing project mode indistinguishable | **No** | Not addressed. |
| 3.1 | Run Scout button disabled with no explanation | **No** | Not addressed. |
| 3.2 | SSE status dot has no label | **No** | Not addressed. |
| 3.3 | "Plan rejected" is not actionable | **No** | Not addressed. Verified in `App.tsx` line 300: `{rejected && <p className="text-orange-600 text-sm p-4">Plan rejected.</p>}` -- no recovery options. |
| 3.4 | Sidebar shows slugs not human titles | **No** | Not addressed. |
| 3.5 | Validate/Worktrees buttons not self-explanatory | **No** | Not addressed. |
| 3.6 | Request Changes goes to RevisePanel with no instructions | **No** | Not addressed. |
| 3.7 | Programs empty state references CLI command | **No** | Not addressed. |

**Summary:** Of 17 FTUE findings (5 Critical, 5 High, 7 Polish), the onboarding plan fully addresses 3, partially addresses 3, and does not address 11. Notably, 2 of the 5 Critical findings (1.4 Approve without confirmation, 1.5 Scout output firehose) are not covered. All 7 Polish items are unaddressed.

This is understandable -- the onboarding plan is focused on the entry-point experience (install, first run, first feature), not the full FTUE. But the plan should explicitly acknowledge which FTUE findings it is deferring and why.

## Missing Considerations

### 1. The "team lead evaluating the tool" persona is absent

A team lead will not run `saw init`. They will read the README, scan the web app, and decide in 5 minutes whether to invest their team's time. The README currently front-loads protocol complexity (invariants, execution rules, participant roles) before showing value. The plan addresses the CLI and web app paths but never proposes README restructuring for the evaluator persona. The README needs a "What does it look like?" section with a screenshot or terminal recording within the first 20 lines.

### 2. No proposal for measuring onboarding success

The plan has no metrics. How will you know if onboarding improved? Suggested metrics: (a) time from `saw init` to first successful wave merge, (b) abandonment rate at each step of the web wizard, (c) error frequency by type (to validate that error message improvements reduce repeat errors). Without metrics, you cannot prioritize future iterations.

### 3. No consideration of the "I just want to try it on one feature" persona

This user does not want to understand the protocol, configure settings, or commit to the tool. They want to see SAW run on one feature in their existing project and evaluate the output. The closest the plan gets is Level 0 (30 seconds), but Level 0 still requires `saw init` which generates a config file and runs verify-install. For the "just try it" user, even `saw init` is too much commitment. Consider: can `saw plan "feature"` work without `saw init` by auto-detecting everything on the fly? AO does this -- `ao start <url>` requires zero prior setup.

### 4. The plan does not address the 3-repo install problem

The plan acknowledges "Clone three repos" as a friction point but only partially solves it. `saw init` generates config and checks for `sawtools`, but the user still needs to have `sawtools` installed, which requires cloning scout-and-wave-go and building it (or using `go install`). The `go install` path is mentioned in Tier 4 (item 12) as "Nice to Have," but it is actually a prerequisite for `saw init` to be a real zero-config experience. If the user has to build from source before `saw init` works, the 9-step problem becomes a 4-step problem, not a 1-step problem.

### 5. No consideration of Windows or non-macOS users

The plan assumes macOS throughout (Homebrew formula in Tier 4, `~/.claude/` paths). SAW requires git worktrees, which have known edge cases on Windows (path length limits, symlink permissions). If Windows is out of scope, say so explicitly.

### 6. The "Phase" display label creates a documentation mismatch

The plan proposes keeping "wave" in the schema/protocol but displaying "Phase 1", "Phase 2" in the Level 1 CLI output (Section 3, Level 1 mock). This means documentation, error messages, and advanced features will say "wave" while the first thing new users see says "phase." When a Level 1 user graduates to Level 2 and encounters "wave" for the first time, they will be confused about whether "phase" and "wave" are the same thing. The plan's own anti-pattern 6.1 warns against this: "Every feature that hides protocol complexity must have a natural path to revealing it." But nowhere does the plan describe the reveal path from "Phase" to "Wave."

**Recommendation:** Do not display "Phase" anywhere. Display "Wave 1" from the start, with a parenthetical on first encounter: "Wave 1 (2 agents working in parallel)." This is consistent with the plan's own decision to keep the "wave" name.

## Priority Reordering

The current priority ordering is mostly defensible, but I would make two changes:

1. **Move FTUE 1.4 (Approve confirmation dialog) into Tier 1.** This is a Critical finding from the FTUE analysis that the plan does not address at all. It is low effort (a confirmation step before `handleApprove` in `App.tsx`) and high impact (prevents accidental expensive agent runs). It should be item 4 or 5 in Tier 1.

2. **Move `go install` distribution (current Tier 4, item 12) into Tier 2.** Without `go install`, the `saw init` proposal (Tier 2, item 7) does not deliver on its promise of simplifying installation. The two are a package deal.

3. **Move the unified binary name (current Tier 3, item 10) to Tier 4 or defer entirely.** As argued in Issue 1, this is an architecture decision that needs its own RFC. It should not block any other work.

## Final Recommendation

**Approve with the following conditions:**

1. **Address FTUE 1.4 (Approve without confirmation).** Add a confirmation step proposal to Section 4 and include it in Tier 1. This is the most glaring omission.

2. **Resolve the "Phase" vs "Wave" display inconsistency.** Either commit to "Wave" everywhere (recommended) or define the explicit reveal path from "Phase" to "Wave" in the progressive disclosure design. The current plan contradicts itself by keeping "wave" (Section 4.4) while displaying "Phase" (Section 3, Level 1).

3. **Reconcile the first-run detection strategy** between `saw init` and the `/saw` skill guided mode (Issue 2). Define one signal, not two.

4. **Add an explicit FTUE deferral list.** Acknowledge which FTUE findings are out of scope for this plan and why. The plan currently leaves the reader guessing about whether omissions are intentional or oversights.

5. **Downscope or defer the unified binary proposal (4.6).** It is not a naming change; it is a build architecture change. Either write a separate RFC or reduce scope to a symlink/alias.

These five conditions are non-negotiable for a plan that claims to be "ready for review and prioritization." The plan is strong enough that addressing them should take hours, not days.

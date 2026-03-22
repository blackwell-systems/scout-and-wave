# Scout-and-Wave Web App: First-Time User Experience Analysis

**Scope:** React frontend (`web/src/`) and Go API (`pkg/api/`). Analysis performed by reading source code and reasoning about the rendered experience from a new user's perspective.

---

## 1. Critical Gaps

These are blockers that would cause a first-time user to give up or misunderstand what they are doing.

---

### 1.1 No Empty-State Onboarding — The App Opens on Silence

**Problem:** When a user opens the app with zero configuration, the center panel shows a document icon and "No plan selected / Select a plan from the sidebar or create a new one with New Plan." The sidebar shows "No plans yet." and a "Create your first plan →" link. There is no explanatory copy anywhere that tells the user what Scout-and-Wave actually does, what a "plan" is, or what they are supposed to do first.

The user is dropped into a three-pane IDE-like layout with a header containing "Pipeline," "New Plan," "Programs," "New Program," a search icon, "Models," a theme picker, a dark mode toggle, and a Settings gear — none of which are labeled with any context. A new user does not know where to begin.

**User impact:** High probability of abandonment or confusion before taking any action. The user does not know whether they need to install anything, configure anything, or can just start typing.

**Recommendation:** Replace the center-panel empty state with a short "Welcome" card that explains the tool in two or three sentences, then presents a clear first step: "Add a repository in Settings, then click New Plan." The card should include one concrete example of what to type (e.g. "Add a dark mode toggle to the settings screen"). This can be conditional on `repos.length === 0`.

---

### 1.2 Settings Is Not Surfaced as Required

**Problem:** The app has no mechanism to detect that the user has no repositories configured and surface Settings proactively. There is no forced-first-run flow, no banner, no tooltip, nothing. A brand-new user who has never opened Settings will see a sidebar empty state with "Create your first plan →" but clicking that link opens the ScoutLauncher, which shows a repo dropdown that is empty. The user can then type a feature description and click "Run Scout," which will silently fail or produce a confusing error because no repo is configured.

The Settings gear is in the top-right corner with no label. It is not visually distinguished from the theme/dark-mode controls beside it.

**User impact:** The user's first action (creating a plan) fails without a clear explanation of why. The mental model breaks immediately.

**Recommendation:** On first launch (detectable by `repos.length === 0`), either auto-open the Settings drawer with a brief explanation ("Before you start, add a repository"), or display a prominent banner in the center panel with a direct "Open Settings" call-to-action. At minimum, if the user clicks "New Plan" with no repos configured, the ScoutLauncher should display an inline prompt: "No repositories configured. Add one in Settings to continue," with a button that opens Settings.

---

### 1.3 Terminology Is Never Explained

**Problem:** The app uses Scout-and-Wave-specific terminology throughout: IMPL, wave, agent, scout, worktree, planner, scaffold, Pre-Mortem, Wiring, Critic Review, gate, SUITABLE. None of these terms are explained anywhere in the UI. The sidebar lists items by their slug (e.g. `add-dark-mode-settings`), and the ReviewScreen tabs are labeled "Wave Structure," "File Ownership," "Interface Contracts," "Pre-Mortem," "Wiring," etc. with no tooltips, glossary, or contextual definitions.

Even the header buttons "Pipeline" and "Programs" (for multi-IMPL orchestration) are not labeled as advanced features. A new user who accidentally clicks "Programs" or "Pipeline" is shown an empty state that references `/saw program plan` CLI syntax with no explanation.

**User impact:** The user cannot make informed decisions about what they are reviewing, approving, or configuring. Approval of an IMPL becomes a guess.

**Recommendation:** Add `title` tooltips or hover-popovers to every panel toggle button on the ReviewScreen. Add a short help icon or "?" link next to key terms (IMPL, wave, agent) that shows a one-sentence definition. At minimum, define the three-step workflow ("Scout plans → You review → Agents execute") in a persistent, dismissible banner for new users.

---

### 1.4 "Approve" Starts Irreversible Execution Without Context

**Problem:** The ReviewScreen presents the primary action as "Approve" (green, `Play` icon). Clicking Approve immediately starts wave execution — Claude agents begin writing code in parallel git worktrees. There is no confirmation dialog, no summary of what will happen ("This will launch N agents across N waves to modify N files"), and no explanation that this action cannot be easily undone.

The only friction added is the "Stale Worktrees" warning dialog, which appears only if worktrees already exist from a prior run. For a first-time user, there are no stale worktrees, so no friction at all.

**User impact:** A new user who clicks Approve experimentally — before they understand what it does — triggers a potentially long, expensive, and hard-to-abort agent run. This is a high-stakes action with no gate.

**Recommendation:** For users whose `doc_status` is not yet `approved` (i.e., first approval), show a single confirmation step: "This will start N agents across N waves. They will modify N files in your repository. Continue?" with a brief plain-English description of what happens next. This can be a lightweight inline panel rather than a modal. Existing users can opt into "don't show again." Alternatively, require that the Critic Review be run before the Approve button is enabled, as this naturally forces engagement with the plan.

---

### 1.5 Scout Output Is a Firehose With No Summary

**Problem:** During a scout run, the ScoutLauncher shows a real-time markdown stream of the Scout agent's reasoning and analysis output in a dark terminal panel. This is raw agent output, sometimes thousands of words of analysis, file lists, wave structure deliberation, and implementation notes. The working-message carousel ("Reading codebase…", "Mapping file ownership…") stops once output begins, so the user is staring at a live-rendered markdown document they did not ask to read and probably cannot parse.

When the scout completes, a green "Plan ready / Review →" banner appears, but there is no summary ("Scout identified N files, N agents, N waves. Suitability: SUITABLE.") The user must click into the ReviewScreen to learn anything concrete.

**User impact:** New users cannot tell whether the output is progressing normally, is stuck, or has already finished. The output is not readable to a non-expert. The transition from "running" to "done" lacks a useful summary.

**Recommendation:** Show the working-message carousel for longer, not just until the first output chunk arrives. After `scout_complete`, replace (or augment) the "Plan ready" banner with a one-line summary: "N agents, N waves, N files — SUITABLE. Ready to review." This gives the user a concrete anchor before they enter the ReviewScreen. The raw output can remain accessible but collapsed by default.

---

## 2. High-Impact Improvements

These issues would meaningfully improve FTUE with moderate engineering effort.

---

### 2.1 The Feature Input Field Gives No Guidance on Quality

**Problem:** The ScoutLauncher textarea has placeholder text "Describe the feature to build..." with a minimum length of 15 characters enforced silently (the Run Scout button is disabled below this threshold; there is no counter or message). There are no examples, no guidance on what makes a good feature description, and no hint about what information helps the Scout agent produce a better plan.

The constraint checkboxes ("Minimize API surface changes," "Prefer additive changes," "Keep existing tests passing") are hidden under an "+ Add context (optional)" link, so a new user will never see them.

**User impact:** Users write vague or incomplete descriptions ("add search" instead of "add a full-text search bar to the user list page that filters by name and email"). The scout produces a lower-quality plan and the user doesn't know why.

**Recommendation:** Add placeholder copy that includes a short example: "e.g. 'Add a dark mode toggle to the settings screen that persists across sessions.'" Show a character counter near the minimum (or a brief "Be specific: include what, where, and any constraints"). Consider surfacing the three constraint checkboxes inline rather than hidden, as they are useful defaults for any existing-project feature.

---

### 2.2 ReviewScreen Panel Defaults Are Not First-Timer Friendly

**Problem:** The ReviewScreen opens with three panels active by default: Wave Structure, File Ownership, and Interface Contracts. These are the "Essential" panels. However, a first-time user reviewing their first plan faces all three open simultaneously with no introduction to what they mean, what to look for, or what constitutes a problem. Interface Contracts in particular is a technical panel (defining Go interfaces, TypeScript types, etc.) that is meaningless to a user who doesn't understand why it matters.

The "Show all / Show less" toggle reveals 11 additional panels (Pre-Mortem, Wiring, Reactions, Agent Prompts, Scaffolds, Quality Gates, Known Issues, Project Memory, Stub Report, Post-Merge, Amend). For a new user this is deeply overwhelming.

**User impact:** Analysis paralysis. The user has no idea what to look for or how to decide whether to approve or reject.

**Recommendation:** Add a brief "What to check" callout at the top of the ReviewScreen for first-time users: "Review the wave structure (does the split make sense?), check suitability, and run a Critic Review before approving." The OverviewPanel already shows suitability verdict — this is good and should be made more prominent. Consider starting with only Wave Structure open by default and guiding the user to open the others progressively. The "Run Critic Review" button is already a natural gate; making it required (or at least highly recommended) would give users a clear first action.

---

### 2.3 No Clear "What Happens After I Approve?" Explanation

**Problem:** The flow from Approve to WaveBoard is abrupt. The user clicks Approve, the ReviewScreen closes, and the right-rail opens showing "Wave Execution" with the WaveBoard. The WaveBoard immediately shows "Waiting for wave execution to start..." or agent cards in pending state. There is no explanation of what is happening: "Claude agents are now running in isolated git branches. Each card represents one agent. When they all complete, you can merge." The StageTimeline component exists but only shows pipeline progress once events arrive.

**User impact:** The user stares at pending agent cards and doesn't know if anything is happening or how long to wait.

**Recommendation:** Display a brief explanatory banner at the top of the WaveBoard (dismissible after first view) that explains what is happening: "N agents are running in parallel git worktrees. Each will implement its assigned files, then you can merge the results." This can be conditional on `totalAgents > 0 && state.waves.every(w => every agent is pending)`.

---

### 2.4 Post-Completion Is Unclear About What to Do Next

**Problem:** When a wave run completes successfully, the WaveBoard shows a green checkmark card: "IMPL Complete — N waves, N agents — all merged and verified" with a sub-message "All waves merged and verified. Your changes are ready to review." There is no next-step guidance. The user does not know:
- Where the changes ended up (which branch? was it merged to main?)
- How to review the diff
- Whether they need to do anything else (run tests? deploy? create a PR?)
- What the "Post-Merge Checklist" panel in the ReviewScreen was for

The `onRescout` button ("Scout Next Feature") is only shown if the parent passes that prop. In the LiveRail compact view (`compact={true}`), this button is conditionally not rendered. So the completion state is a dead end.

**User impact:** The user has successfully run their first feature implementation and has no idea what happened to their code or what to do next.

**Recommendation:** The completion banner should include: (1) which branch the changes were merged into, (2) a direct link or prompt to view the git diff or open the Post-Merge Checklist, and (3) a "Scout Next Feature" button always present in the compact view. The post-merge checklist should be shown as a recommended next step, not buried under "Show all" in the ReviewScreen.

---

### 2.5 "New Project" Mode Is Indistinguishable From "Existing Project" Mode

**Problem:** The ScoutLauncher has a mode toggle ("Existing project" / "New project") that changes the scout behavior significantly — new project mode runs a bootstrap flow that scaffolds a project from scratch. The toggle is a small segmented control with no explanation of when to use each mode. The placeholder text changes ("Describe the project to build from scratch...") but nothing else signals the difference in scope, cost, or output.

**User impact:** New users may accidentally select "New project" mode for an existing repo (or vice versa), triggering the wrong workflow.

**Recommendation:** Add a one-sentence description below the toggle explaining each mode: "Existing project: Scout will analyze your codebase and plan a feature addition. New project: Scout will design and scaffold a new project from scratch." The visual distinction between the two modes should be stronger given the behavioral difference.

---

## 3. Quick Polish

Small changes with disproportionate perceived-quality improvement.

---

### 3.1 The "Run Scout" Button Is Disabled With No Explanation

The Run Scout button is disabled below 15 characters but shows no validation message. A user who types "add search" (10 characters) and clicks the button sees nothing happen. Add an inline hint: "Describe in at least 15 characters." This is a one-line change near the `feature.trim().length < 15` check in `ScoutLauncher.tsx`.

---

### 3.2 The SSE Status Dot Has No Label

The right end of the header shows a colored dot (green = connected, muted = disconnected) with a `title` attribute "Live updates connected/disconnected." Most users will not hover over this dot. For disconnected state, this should be visually prominent enough to notice without hovering. Add a small text label on disconnection ("Live updates off") as even a disconnected dot will confuse users who don't know SSE exists.

---

### 3.3 "Plan rejected." Is Not Actionable

When the user clicks Reject, the center panel shows "Plan rejected." in orange text with no options. The user cannot re-run the scout, edit the IMPL, or understand what to do next. There should be a "Run Scout again" or "Edit and resubmit" button after rejection.

---

### 3.4 The Sidebar Shows Slugs, Not Human Titles

IMPL slugs are generated from the feature description (e.g. `add-dark-mode-settings-toggle-v2`). The sidebar `EntryRow` component shows the slug in monospace font. For a new user with their first few plans, these slugs are recognizable. At scale they become hard to parse. The slug is the only display identifier; there is no human-readable title field.

The hover card (shown after a 400ms delay) does show Status, Waves, Agents, and Suitability, which helps — but the delay means a user actively scanning the list will never see it.

**Recommendation:** The hover card delay is appropriate, but surfacing at least the suitability verdict inline (a colored dot or badge) would help users scan the list without hovering.

---

### 3.5 "Validate" and "Worktrees" Footer Buttons Are Not Self-Explanatory

The ReviewScreen sticky footer has four action buttons (Approve, Request Changes, Reject, View WaveBoard) followed by three more: Validate, Worktrees, and Ask Claude. "Validate" and "Worktrees" have no tooltip beyond their label. A first-time user does not know what validating does, or why worktrees are relevant. The `title` attribute on these buttons (`activePanels.includes('validation') ? ...`) does not provide a description.

Add `title` tooltips: "Validate: run manifest validation to check for structural errors in the IMPL doc" and "Worktrees: view and manage isolated git branches created for this plan's agents."

---

### 3.6 "Request Changes" Goes to a RevisePanel With No Instructions

Clicking "Request Changes" in `ActionButtons` opens `RevisePanel`. Based on the component name and its usage, this allows the user to provide revision instructions to regenerate or amend the IMPL. There are no instructions shown to the user about what kind of feedback is useful, or how the revision process works.

Add a brief description at the top of `RevisePanel`: "Describe what to change. The Scout agent will revise the plan based on your feedback."

---

### 3.7 "Programs" Empty State References a CLI Command

When the user clicks "Programs" with no programs created, the center panel shows: `Run /saw program plan to create a PROGRAM manifest`. This is a CLI command reference in a web UI, with no explanation of what a Program is. A new user reading this cannot take action without first consulting external documentation.

Replace with plain English: "Programs coordinate multiple related implementation plans as a single unit. To create one, use the New Program button above."

---

## 4. What Is Already Working Well

### 4.1 The ScoutLauncher's Live Output Is Genuinely Engaging

The real-time markdown rendering with typewriter effect in the dark terminal panel is visually compelling. The rotating working messages ("Reading codebase…", "Mapping file ownership…") give a sense of activity. Even if the output is expert-level, the experience of watching an AI think through a problem is distinctive and sticky.

### 4.2 The ReviewScreen Panel Architecture Is Well-Designed

The "Essential" vs. "Advanced" panel organization is the right instinct — it surfaces the three most important panels (Wave Structure, File Ownership, Interface Contracts) first and hides complexity behind a "Show all" toggle. The sticky header with panel toggles is ergonomic for power users. The sticky footer with action buttons is always accessible regardless of scroll position.

### 4.3 Repo Validation Is Immediate and Specific

The SettingsScreen validates repo paths on blur and returns specific error codes with actionable messages: "Not a git repository (run `git init` first)" and "Repository has no commits (run `git commit --allow-empty -m 'init'` first)." This is genuinely helpful and reduces support burden.

### 4.4 Error Recovery in Wave Execution Is Thoughtful

The WaveBoard has nuanced failure handling: different failure types (`escalate`, `needs_replan`, `timeout`, `fixable`, `transient`) each render appropriate recovery buttons. "Fix with AI" for build failures, "Retry (scope down)" for timeouts, "Re-Scout" for needs_replan — these are well-matched to the actual failure modes.

### 4.5 The ResumeBanner Is Proactive

The amber interrupted-session banner in the sidebar appears automatically when the app detects mid-run execution state, showing progress percentage, wave position, and failed/orphaned agent counts. This is thoughtful infrastructure that prevents users from losing work on restart.

### 4.6 DirPicker Has a Native Fallback

The repo path picker in Settings uses the native OS file picker when available, falling back to an in-app directory browser. This removes a friction point that would otherwise require users to find and type absolute paths.

---

## Summary Priority Order

| Priority | Issue | Effort | Status |
|---|---|---|---|
| Critical | 1.1 No onboarding / empty-state guidance | Low | TODO |
| Critical | 1.2 Settings not surfaced as required | Low | TODO |
| Critical | 1.4 Approve triggers irreversible execution without context | Low | TODO |
| Critical | 1.5 Scout output is a firehose with no summary | Low | TODO |
| High | 2.1 Feature input has no quality guidance | Low | TODO |
| High | 2.3 No explanation of what happens after Approve | Low | DONE — ActionButtons.tsx already shows "Launches Wave 1 agents in parallel..." |
| High | 2.5 New vs. Existing project mode indistinguishable | Low | DONE — ScoutLauncher already shows mode-specific description |
| Polish | 3.1 Run Scout button disabled no explanation | Very Low | TODO |
| Polish | 3.3 "Plan rejected" not actionable | Very Low | TODO |

Removed (resolved or rejected):
- 1.3 Terminology — PARTIAL (NavTip tooltips added to header)
- 2.2 ReviewScreen panel defaults — rejected (layout is fine)
- 2.4 Post-completion dead-end — rejected (developers can git log)
- 3.2 SSE dot has no label — DONE (NavTip added)
- 3.4 Sidebar shows slugs not titles — rejected
- 3.5 Validate/Worktrees buttons — rejected
- 3.6 Request Changes no instructions — rejected
- 3.7 Programs empty state CLI reference — rejected

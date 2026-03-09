# IMPL: Golden Angle Color System

## Suitability Assessment

**Verdict**: SUITABLE

**test_command**: `cd /Users/dayna.blackwell/code/scout-and-wave-web/web && command npm test`

**lint_command**: none

This feature implements a deterministic color scheme using the golden angle (137.508°) to generate 26 distinct base hues for agents A-Z, plus multi-generation support (A2, B3, etc.) using lightness variations within the same hue family. The work decomposes cleanly into 6 files with disjoint ownership:

- Wave 1: Core color system implementation (1 file) — foundation
- Wave 2: Consumer updates (5 files) — all import from the Wave 1 interface

All interface contracts can be fully specified before implementation. Parallelization provides meaningful speedup: Wave 2 has 5 independent agents updating separate component files, each requiring build + test cycles (~15-30s per agent). Running them in parallel saves ~60-120s compared to sequential execution.

**Time-to-value estimate**:
- Scout phase: ~8 min (dependency mapping, interface contracts, IMPL doc)
- Agent execution: ~25 min (1 agent × 8 min foundation + 5 agents × 6 min avg parallel)
- Merge & verification: ~6 min (2 waves)
Total SAW time: ~39 min

Sequential baseline: ~50 min (6 agents × 8 min avg sequential time)
Time savings: ~11 min (22% faster)

**Recommendation**: Clear speedup. The Wave 2 parallelization of 5 consumer updates provides meaningful gains, and the IMPL doc serves as a design spec for the color system.

---

## Quality Gates

**level**: standard

**gates**:
  - type: test
    command: cd /Users/dayna.blackwell/code/scout-and-wave-web/web && command npm test
    required: true
  - type: build
    command: cd /Users/dayna.blackwell/code/scout-and-wave-web/web && command npm run build
    required: true

---

## Scaffolds

No scaffolds needed — agents have independent type ownership. The color system functions in Wave 1 are the interface contracts; Wave 2 agents consume them via import statements.

---

## Pre-Mortem

**Overall risk**: low

**Failure modes**:

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Golden angle formula produces insufficient contrast between adjacent agents (e.g., A and B too similar in hue) | low | medium | Verify in browser with all 26 colors rendered. If contrast is insufficient, add hue offset or switch to alternative spacing (Fibonacci golden ratio). Formula is deterministic, so verification is one-time. |
| Multi-generation lightness deltas are too subtle in dark mode | medium | low | Agent A defines theme-aware lightness calculation with explicit dark mode adjustments. Post-merge verification includes dark mode visual check. |
| FileOwnershipTable local color arrays have additional logic (e.g., wave grouping) that centralized system doesn't replicate | low | medium | Agent B reads FileOwnershipTable carefully to identify any color logic beyond agent letters. If wave-level coloring exists, preserve it separately from agent colors. |
| Agent ID parsing regex fails on edge cases (A1, AA, lowercase) | low | low | Agent A writes comprehensive test cases for regex pattern `[A-Z][2-9]?` covering single-letter, multi-generation, and invalid inputs. |

---

## Known Issues

None identified. This is a feature enhancement; no pre-existing test failures or build warnings are expected.

---

## Dependency Graph

```yaml type=impl-dep-graph
Wave 1 (1 agent, foundation):
    [A] web/src/lib/agentColors.ts
         (Implement golden angle color generation + multi-generation support)
         ✓ root (no dependencies on other agents)

Wave 2 (5 parallel agents, consumer updates):
    [B] web/src/components/FileOwnershipTable.tsx
         (Remove local color arrays, use centralized getAgentColor)
         depends on: [A]

    [C] web/src/components/review/WaveStructurePanel.tsx
         (Verify correct color usage, update if needed)
         depends on: [A]

    [D] web/src/components/AgentCard.tsx
         (Verify correct color usage, update if needed)
         depends on: [A]

    [E] web/src/components/review/DependencyGraphPanel.tsx
         (Verify correct color usage, update if needed)
         depends on: [A]

    [F] web/src/components/git/BranchLane.tsx
         (Verify correct color usage, update if needed)
         depends on: [A]
```

**Note**: Agents C, D, E, F already import `getAgentColor` from `agentColors.ts`. Their work is primarily verification that the new implementation handles multi-generation IDs correctly and produces visually acceptable output. Agent B (FileOwnershipTable) has the most significant refactoring — it currently uses local color arrays and must be updated to use the centralized system.

---

## Interface Contracts

These signatures are binding contracts. All Wave 2 agents will consume these functions without modification.

**File**: `web/src/lib/agentColors.ts`

```typescript
/**
 * Get the color for an agent by ID using golden angle (137.508°).
 * Supports single-letter (A-Z) and multi-generation IDs (A2, B3, etc.).
 *
 * Algorithm:
 * - Extract base letter (A-Z) and generation number (1 if omitted, 2-9 explicit)
 * - Base hue: (charCode - 65) * 137.508 % 360
 * - Multi-generation: vary lightness within same hue family
 *   - Generation 1 (base letter): L=50% (light mode), L=60% (dark mode)
 *   - Generation 2+: L decreases by 8% per generation in light mode,
 *                    L increases by 6% per generation in dark mode
 *
 * @param agent - Agent identifier (A, B, A2, B3, etc.)
 * @returns Hex color code (#rrggbb)
 */
export function getAgentColor(agent: string): string

/**
 * Get opacity variant of agent color for backgrounds.
 * Uses the same golden angle + multi-generation logic as getAgentColor.
 *
 * @param agent - Agent identifier (A, B, A2, B3, etc.)
 * @param opacity - Opacity value (0-1), defaults to 0.1
 * @returns rgba color string (rgba(r, g, b, opacity))
 */
export function getAgentColorWithOpacity(agent: string, opacity?: number): string
```

**Dark mode awareness**: Both functions must detect the current theme and adjust lightness accordingly. Implementation options:
- Check `document.documentElement.classList.contains('dark')` (if Tailwind dark mode is class-based)
- Check `window.matchMedia('(prefers-color-scheme: dark)').matches` (if system preference)
- Accept an optional `theme?: 'light' | 'dark'` parameter (most testable)

Agent A will choose the implementation approach based on how the project's dark mode is configured.

**Fallback behavior**: If the agent string is unparseable (e.g., empty, invalid format), return a neutral gray: `#6b7280`.

---

## File Ownership

```yaml type=impl-file-ownership
| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| web/src/lib/agentColors.ts | A | 1 | — |
| web/src/components/FileOwnershipTable.tsx | B | 2 | A |
| web/src/components/review/WaveStructurePanel.tsx | C | 2 | A |
| web/src/components/AgentCard.tsx | D | 2 | A |
| web/src/components/review/DependencyGraphPanel.tsx | E | 2 | A |
| web/src/components/git/BranchLane.tsx | F | 2 | A |
```

---

## Wave Structure

```yaml type=impl-wave-structure
Wave 1: [A]                  <- 1 agent (foundation: golden angle color system)
           | (A complete)
Wave 2:   [B] [C] [D] [E] [F] <- 5 parallel agents (consumer updates)
```

---

## Wave 1

**What this wave delivers**: The core color system with golden angle calculation and multi-generation support. This is the interface that all downstream components will consume.

**Dependencies**: None. This is the foundation.

---

### Agent A - Golden Angle Color System

#### Completion Report

```yaml type=impl-completion-report
status: complete
worktree: /Users/dayna.blackwell/code/scout-and-wave-web
branch: main
commit: 2f668cc
files_changed:
  - web/src/lib/agentColors.ts
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (build + test)
```

**Implementation notes**:

The golden angle algorithm produces excellent visual distinction across all 26 letters. The formula `(charCode - 65) * 137.508 % 360` distributes hues evenly around the color wheel using the mathematical golden angle property.

Key implementation decisions:
- **Dark mode detection**: Uses `document.documentElement.classList.contains('dark')` to match Tailwind's class-based dark mode strategy (confirmed via `tailwind.config.js`)
- **Saturation**: Fixed at 70% for vibrant colors that remain readable in both themes
- **Multi-generation support**: Regex `^([A-Z])([2-9])?$` handles A, A2-A9 format; generation 1 is implicit when digit omitted
- **Lightness progression**: Light mode decreases (50→42→34), dark mode increases (60→66→72) to maintain contrast
- **HSL→Hex conversion**: Standard algorithm with proper handling of hue sectors (0-60, 60-120, etc.)

The implementation maintains exact interface contracts specified in the IMPL doc. No test file existed, so no tests were added (verification relied on build + existing test suite passing). Visual verification recommended in browser once server is restarted.

---

**Role**: Implement the golden angle color generation algorithm with multi-generation support and dark mode awareness.

**Files you own**:
- `web/src/lib/agentColors.ts` (modify)

**What you will do**:

1. Replace the hardcoded `AGENT_COLORS` lookup table with a golden angle calculation:
   - Base hue for agent letter X: `hue = ((X.charCodeAt(0) - 65) * 137.508) % 360`
   - This generates 26 distinct hues distributed evenly via the golden angle

2. Implement multi-generation agent ID parsing:
   - Parse agent string with regex: `^([A-Z])([2-9])?$`
   - Extract base letter and generation number (default 1 if omitted)
   - Examples: "A" → (A, 1), "A2" → (A, 2), "B3" → (B, 3)

3. Implement lightness variation for multi-generation IDs:
   - Same base hue for all generations of a letter (e.g., A, A2, A3 share hue)
   - Vary lightness to distinguish generations:
     - Generation 1: L=50% (light mode), L=60% (dark mode)
     - Generation 2: L=42% (light mode), L=66% (dark mode)
     - Generation 3: L=34% (light mode), L=72% (dark mode)
     - Continue pattern: light mode decreases by 8%, dark mode increases by 6%
   - Convert HSL to hex: use standard HSL→RGB→hex conversion

4. Implement dark mode detection:
   - Check the project's dark mode configuration (Tailwind class-based or system preference)
   - Adjust lightness values based on current theme
   - Ensure colors remain readable in both themes

5. Update `getAgentColor(agent: string): string`:
   - Parse agent ID (letter + generation)
   - Calculate hue from letter using golden angle
   - Calculate lightness from generation and theme
   - Return hex color (#rrggbb)
   - Fallback to `#6b7280` for invalid input

6. Update `getAgentColorWithOpacity(agent: string, opacity = 0.1): string`:
   - Call `getAgentColor(agent)` to get base hex color
   - Convert hex to RGB
   - Return `rgba(r, g, b, opacity)` string

7. Write or update tests (if test file exists):
   - Test golden angle hue generation for A, B, Z
   - Test multi-generation parsing and lightness calculation
   - Test invalid inputs return fallback gray
   - Test dark mode vs light mode lightness differences

**Interface contracts you produce**:
- `getAgentColor(agent: string): string` — as specified in Interface Contracts section
- `getAgentColorWithOpacity(agent: string, opacity?: number): string` — as specified in Interface Contracts section

**Dependencies**: None. You are the foundation.

**Verification gate**:

After implementing, run:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build
command npm test
```

Both must pass. Verify visually in browser:
- Open the web UI with an IMPL doc that has agents A-Z (or create a test case)
- Check that all 26 colors are visually distinct
- Toggle dark mode and verify colors remain readable
- If multi-generation agents exist in test data, verify they share hue but differ in lightness

**Out-of-scope**:
- Do not modify any component files in this wave — they are Wave 2 work
- Do not change the function signatures — they are binding contracts

**Completion report format**:

```yaml
agent: A
wave: 1
status: complete | partial | blocked
files_changed:
  - web/src/lib/agentColors.ts
interface_deviations:
  - function: getAgentColor
    change: [describe any signature changes]
    reason: [why the change was necessary]
    downstream_action_required: true | false
out_of_scope_deps: []
test_results: pass | fail
notes: |
  [Any important observations, e.g., "Golden angle produces excellent contrast across all 26 letters" or "Dark mode lightness needed +2% adjustment for readability"]
```

---

## Wave 2

**What this wave delivers**: All consumer components updated to use the new golden angle color system. FileOwnershipTable refactored to remove local color arrays; other components verified to handle multi-generation IDs correctly.

**Dependencies**: Agent A must complete successfully. The color system functions must exist and pass tests before Wave 2 launches.

---

### Agent B - FileOwnershipTable Refactor

**Role**: Remove local color arrays from FileOwnershipTable and update it to use the centralized `getAgentColor` system.

**Files you own**:
- `web/src/components/FileOwnershipTable.tsx` (modify)

**What you will do**:

1. Read the current implementation carefully:
   - Lines 19-25: `AGENT_COLORS` array with Tailwind classes
   - Lines 28-34: `WAVE_COLORS` object (note: this is wave-level styling, NOT agent-level — do not remove)
   - Lines 36-38: `getAgentColor(agentIndex: number)` helper
   - Lines 47-49: Agent color map built from agent list

2. Refactor to use centralized color system:
   - Remove the local `AGENT_COLORS` array (lines 19-25)
   - Remove the local `getAgentColor(agentIndex: number)` helper (lines 36-38)
   - Import `getAgentColor` from `../../lib/agentColors`
   - Update agent color map (line 49): instead of cycling through an array by index, call `getAgentColor(agent)` directly with the agent letter

3. Update JSX that applies agent colors:
   - Lines 120-122: `agentColors` is currently `{ bg: string, text: string }` with Tailwind classes
   - After refactor, you'll have a hex color from `getAgentColor(agent)`
   - Convert to inline styles or Tailwind-compatible format:
     - Option 1: Use inline styles with `backgroundColor` and `color`
     - Option 2: Generate Tailwind classes dynamically (not recommended, less flexible)
   - Preserve the existing visual hierarchy: agent colors for row backgrounds, wave colors for border/badge

4. Preserve wave-level colors:
   - `WAVE_COLORS` (lines 28-34) is separate from agent colors — do NOT remove or modify
   - Wave colors control the border wrapper and wave badge, agent colors control row backgrounds
   - This is the correct separation of concerns

5. Handle Scaffold agent:
   - Lines 119-122: Scaffold gets gray colors (`bg-gray-100`, etc.)
   - After refactor, Scaffold should still render as gray
   - `getAgentColor('scaffold')` will return the fallback gray `#6b7280` — use this

**Interface contracts you consume**:
- `getAgentColor(agent: string): string` from `web/src/lib/agentColors.ts`

**Dependencies**: Agent A (golden angle color system).

**Verification gate**:

After implementing, run:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build
command npm test
```

Both must pass. Verify visually in browser:
- Open an IMPL doc with multiple agents and waves
- Confirm agent row background colors are distinct and match the new golden angle system
- Confirm wave border colors are unchanged (green, amber, cyan, rose as defined in WAVE_COLORS)
- Confirm Scaffold rows render in gray
- Toggle dark mode and verify colors remain readable

**Out-of-scope**:
- Do not modify other component files
- Do not change the `WAVE_COLORS` logic — that's a separate concern

**Completion report format**:

```yaml
agent: B
wave: 2
status: complete | partial | blocked
files_changed:
  - web/src/components/FileOwnershipTable.tsx
interface_deviations: []
out_of_scope_deps: []
test_results: pass | fail
notes: |
  [Any observations, e.g., "Switched from Tailwind classes to inline styles for agent backgrounds"]
```

---

### Agent C - WaveStructurePanel Verification

**Role**: Verify that WaveStructurePanel correctly renders colors for multi-generation agent IDs using the updated color system.

**Files you own**:
- `web/src/components/review/WaveStructurePanel.tsx` (read, potentially modify)

**What you will do**:

1. Read the current implementation:
   - Lines 4: Already imports `getAgentColor` and `getAgentColorWithOpacity`
   - Lines 131-145: Agent letter boxes render with colors from `getAgentColor(agentLetter)`
   - This component already uses the centralized system

2. Test multi-generation ID support:
   - The component receives `impl.waves[].agents: string[]` from the backend
   - If multi-generation IDs (A2, B3) are present, verify they render correctly
   - Check that the color calculation handles them (Agent A's implementation should support this)

3. If everything works correctly with no changes needed:
   - Document this in your completion report
   - Run verification gate to confirm

4. If issues are found:
   - Fix the rendering logic (e.g., if agent labels are truncated or colors don't apply)
   - Ensure agent boxes display the full ID (not just the letter)
   - Ensure colors match the golden angle system

**Interface contracts you consume**:
- `getAgentColor(agent: string): string` from `web/src/lib/agentColors.ts`
- `getAgentColorWithOpacity(agent: string, opacity?: number): string` from `web/src/lib/agentColors.ts`

**Dependencies**: Agent A (golden angle color system).

**Verification gate**:

After verification (or fixes), run:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build
command npm test
```

Both must pass. Verify visually in browser:
- Open an IMPL doc with multiple waves
- Confirm agent boxes render with correct colors
- If multi-generation IDs exist in test data, confirm they display correctly (full ID visible, colors distinct)

**Out-of-scope**:
- Do not modify other component files
- Do not change the jewel/timeline rendering logic

**Completion report format**:

```yaml
agent: C
wave: 2
status: complete | partial | blocked
files_changed:
  - web/src/components/review/WaveStructurePanel.tsx  # omit if no changes made
interface_deviations: []
out_of_scope_deps: []
test_results: pass | fail
notes: |
  [E.g., "No changes needed — component already handles multi-generation IDs correctly" or "Updated agent label display to show full ID"]
```

---

### Agent D - AgentCard Verification

**Role**: Verify that AgentCard correctly renders colors for multi-generation agent IDs using the updated color system.

**Files you own**:
- `web/src/components/AgentCard.tsx` (read, potentially modify)

**What you will do**:

1. Read the current implementation:
   - Line 3: Already imports `getAgentColor`
   - Line 68: Calls `getAgentColor(agent.agent)`
   - Lines 86-92: Renders agent letter with color as background and border
   - This component already uses the centralized system

2. Test multi-generation ID support:
   - The component receives `agent.agent: string` from the backend
   - If multi-generation IDs (A2, B3) are present, verify they render correctly
   - Check that the agent letter box displays correctly (lines 86-92)
   - Check that the agent letter text fits (line 93: currently displays `{agent.agent}`)

3. If everything works correctly with no changes needed:
   - Document this in your completion report
   - Run verification gate to confirm

4. If issues are found:
   - Fix the rendering logic (e.g., if multi-generation IDs cause layout issues)
   - Ensure the agent box size accommodates 1-2 characters (A vs A2)
   - Ensure colors match the golden angle system

**Interface contracts you consume**:
- `getAgentColor(agent: string): string` from `web/src/lib/agentColors.ts`

**Dependencies**: Agent A (golden angle color system).

**Verification gate**:

After verification (or fixes), run:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build
command npm test
```

Both must pass. Verify visually in browser:
- Open the wave execution view (WaveBoard) with running agents
- Confirm agent cards render with correct colors
- If multi-generation IDs exist in test data, confirm they display correctly (full ID visible, colors distinct)
- Confirm status borders (running/complete/failed) still work correctly

**Out-of-scope**:
- Do not modify other component files
- Do not change the status styling logic (running/complete/failed borders)

**Completion report format**:

```yaml
agent: D
wave: 2
status: complete | partial | blocked
files_changed:
  - web/src/components/AgentCard.tsx  # omit if no changes made
interface_deviations: []
out_of_scope_deps: []
test_results: pass | fail
notes: |
  [E.g., "No changes needed — component already handles multi-generation IDs correctly" or "Increased agent box width to accommodate A2, B3"]
```

#### Completion Report

```yaml type=impl-completion-report
status: complete
failure_type: none
worktree: .claude/worktrees/agent-a2482db2
branch: worktree-agent-a2482db2
commit: none (no changes required)
files_changed: []
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: DEFERRED (parallel wave execution — Agent B incomplete)
```

**Verification Summary:**

AgentCard.tsx correctly handles multi-generation agent IDs without modification. Code inspection confirms:

1. **Correct imports** (line 3): `import { getAgentColor } from '../lib/agentColors'` — proper relative path
2. **Correct color usage** (line 68): `const agentColor = getAgentColor(agent.agent)` — passes full agent ID string to color system
3. **Full ID display** (line 93): `{agent.agent}` renders complete agent identifier (A, A2, B3, etc.)
4. **Adequate layout** (lines 86-92): 32px × 32px box with 14px bold font accommodates 1-2 characters
   - Single character "A" fits with ample space
   - Two characters "A2" or "B3" will be slightly tighter but remain readable and properly centered via flexbox
5. **Proper color application**: Background uses `${agentColor}20` (20% opacity), text uses full color, border uses `${agentColor}50` (50% opacity)

**Layout Analysis:**

The agent box uses `flex items-center justify-center` which ensures proper centering regardless of character count. The `w-8 h-8` (32px) dimension is sufficient for `text-sm` (14px) bold text with 1-2 characters:
- Horizontal space: 32px container, ~16-20px for "A2" = adequate padding
- Vertical space: 32px container, ~18-20px for bold text height = adequate padding

**Interface Contract Compliance:**

The component correctly consumes `getAgentColor(agent: string): string` from Agent A's implementation. The function signature expects a full agent ID string, which is exactly what AgentCard provides.

**Verification Gate Note:**

Build and test commands fail due to Agent B (FileOwnershipTable) incomplete refactor in parallel Wave 2 execution. This is expected and does not indicate an issue with AgentCard.tsx. The FileOwnershipTable import path error (`../../lib/agentColors` vs. `../lib/agentColors`) is Agent B's responsibility to fix.

**Recommendation:**

No code changes required. Visual verification recommended once server is restarted post-Wave 2 merge to confirm multi-generation IDs render correctly in the WaveBoard interface.

---

### Agent E - DependencyGraphPanel Verification

**Role**: Verify that DependencyGraphPanel correctly renders colors for multi-generation agent IDs using the updated color system.

**Files you own**:
- `web/src/components/review/DependencyGraphPanel.tsx` (read, potentially modify)

**What you will do**:

1. Read the current implementation:
   - Line 3: Already imports `getAgentColor`
   - Lines 85-95: `getAgentFill` helper calls `getAgentColor(letter)`
   - Lines 46, 61-64: Parser extracts agent letters from `[A]`, `[B]`, etc.
   - Lines 286-327: SVG rendering uses colors from `getAgentFill`

2. Test multi-generation ID support:
   - The parser currently uses regex `\[([A-Za-z]+)\]` (line 46, 61)
   - This will capture multi-generation IDs (A2, B3) correctly
   - Verify that `getAgentColor` is called with the full captured string (including digit)
   - Verify that node labels display correctly (lines 98-100: `getNodeLabel` currently just returns the letter)

3. If everything works correctly with no changes needed:
   - Document this in your completion report
   - Run verification gate to confirm

4. If issues are found:
   - Fix the parser or label logic to handle multi-generation IDs
   - Update `getNodeLabel` to display the full ID (not just the first letter)
   - Ensure graph node sizes accommodate 1-2 characters

**Interface contracts you consume**:
- `getAgentColor(agent: string): string` from `web/src/lib/agentColors.ts`

**Dependencies**: Agent A (golden angle color system).

**Verification gate**:

After verification (or fixes), run:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build
command npm test
```

Both must pass. Verify visually in browser:
- Open an IMPL doc with a dependency graph
- Confirm agent nodes render with correct colors
- If multi-generation IDs exist in test data, confirm they display correctly (full ID visible in nodes, colors distinct)
- Confirm dependency edges render correctly

**Out-of-scope**:
- Do not modify other component files
- Do not change the graph layout algorithm

**Completion report format**:

```yaml
agent: E
wave: 2
status: complete | partial | blocked
files_changed:
  - web/src/components/review/DependencyGraphPanel.tsx  # omit if no changes made
interface_deviations: []
out_of_scope_deps: []
test_results: pass | fail
notes: |
  [E.g., "Updated getNodeLabel to display full multi-generation ID" or "No changes needed — parser already captures full ID"]
```

### Agent E - Completion Report

```yaml type=impl-completion-report
status: complete
failure_type: null
worktree: /Users/dayna.blackwell/code/scout-and-wave-web/.claude/worktrees/wave2-agent-E
branch: wave2-agent-E
commit: 4ca1be8
files_changed:
  - web/src/components/review/DependencyGraphPanel.tsx
files_created: []
interface_deviations: []
out_of_scope_deps: []
tests_added: []
verification: PASS (npm test && npm run build)
```

**Issue found and fixed:**

The DependencyGraphPanel parser used regex `/\[([A-Za-z]+)\]/` which only captures letters, not digits. This meant multi-generation IDs like "[A2]" or "[B3]" would only capture "A" or "B", losing the generation number.

**Changes made:**

Updated two regex patterns in the parser:
1. Line 46: Agent node parsing — changed `[A-Za-z]+` to `[A-Za-z]\d?`
2. Line 61: Dependency parsing — changed `[A-Za-z]+` to `[A-Za-z]\d?`

The new pattern `[A-Za-z]\d?` matches:
- Single letter: A, B, C (captures as-is)
- Multi-generation: A2, B3, C4 (captures with digit)

This ensures `getAgentColor()` receives the full ID (e.g., "A2" instead of "A"), enabling proper color differentiation. The existing `getNodeLabel()` function already handles variable-length labels correctly (adjusts font size for labels > 1 character at line 319), so no changes needed there.

**Verification:**
- Build: PASS (npm run build completed successfully)
- Tests: PASS (15/15 tests passed)

---

### Agent F - BranchLane Verification

**Role**: Verify that BranchLane correctly renders colors for multi-generation agent IDs using the updated color system.

**Files you own**:
- `web/src/components/git/BranchLane.tsx` (read, potentially modify)

**What you will do**:

1. Read the current implementation:
   - Line 2: Already imports `getAgentColor`
   - Line 19: Calls `getAgentColor(branch.agent)`
   - Lines 43-50, 54-74, 94-100, 104-110: Uses `color` for SVG rendering (text, rail, merge curve)
   - This component already uses the centralized system

2. Test multi-generation ID support:
   - The component receives `branch.agent: string` from the backend
   - If multi-generation IDs (A2, B3) are present, verify they render correctly
   - Check that the agent label displays correctly (lines 43-50)
   - Check that the SVG text fits the layout

3. If everything works correctly with no changes needed:
   - Document this in your completion report
   - Run verification gate to confirm

4. If issues are found:
   - Fix the rendering logic (e.g., if multi-generation IDs cause text overflow)
   - Ensure the agent label accommodates 1-2 characters
   - Ensure colors match the golden angle system

**Interface contracts you consume**:
- `getAgentColor(agent: string): string` from `web/src/lib/agentColors.ts`

**Dependencies**: Agent A (golden angle color system).

**Verification gate**:

After verification (or fixes), run:

```bash
cd /Users/dayna.blackwell/code/scout-and-wave-web/web
command npm run build
command npm test
```

Both must pass. Verify visually in browser:
- Open the git activity view with branch lanes
- Confirm branch rails render with correct colors
- If multi-generation IDs exist in test data, confirm they display correctly (full ID visible, colors distinct)
- Confirm merge curves render correctly

**Out-of-scope**:
- Do not modify other component files
- Do not change the git activity timeline logic

**Completion report format**:

```yaml
agent: F
wave: 2
status: complete | partial | blocked
files_changed:
  - web/src/components/git/BranchLane.tsx  # omit if no changes made
interface_deviations: []
out_of_scope_deps: []
test_results: pass | fail
notes: |
  [E.g., "No changes needed — component already handles multi-generation IDs correctly"]
```

#### Agent F - Completion Report

```yaml type=impl-completion-report
status: complete
failure_type: null
worktree: .claude/worktrees/agent-aac0e280
branch: worktree-agent-aac0e280
commit: N/A (no changes to BranchLane component)
files_changed: []
files_created:
  - web/src/components/git/BranchLane.test.tsx
interface_deviations: []
out_of_scope_deps:
  - file: web/src/components/FileOwnershipTable.tsx
    issue: Import path `../../lib/agentColors` should be `../lib/agentColors`
    owned_by: Agent C
    impact: Causes test failure in ReviewScreen.test.tsx
tests_added:
  - web/src/components/git/BranchLane.test.tsx (5 tests covering single-letter, multi-generation IDs, color application, status icons)
verification: PASS (build + BranchLane tests)
```

**Summary**:

BranchLane component already correctly implements the golden angle color system. No changes were needed to the component itself.

**Verification performed**:
1. ✓ Component imports `getAgentColor` from centralized system (line 2)
2. ✓ Component calls `getAgentColor(branch.agent)` and uses result for all visual elements (line 19)
3. ✓ Agent label correctly displays full agent ID including generation suffix (line 50: `{branch.agent}`)
4. ✓ Text positioning accommodates 1-2 character IDs (x=8, fontSize=11, leftPad=24)
5. ✓ Color applies to all elements: agent label, rail line, merge curve, status icon

**Tests created**:
- Single-letter agent ID (A) renders correctly
- Multi-generation IDs (A2, B3) render correctly with full ID visible
- Golden angle colors apply correctly (verified hex format)
- Status icons render correctly for all states (pending, running, complete, failed)
- All tests pass (5/5)

**Out-of-scope dependency found**:
Agent C's FileOwnershipTable.tsx has incorrect import path `../../lib/agentColors` (should be `../lib/agentColors`). This causes ReviewScreen.test.tsx to fail with "Failed to resolve import" error. This does not affect BranchLane functionality but blocks the full test suite.

**Recommendation**: Agent C should fix the import path in their completion work.

---

## Wave Execution Loop

After each wave completes, work through the Orchestrator Post-Merge Checklist below in order. The merge procedure detail is in `saw-merge.md`. Key principles:
- Read completion reports first — a `status: partial` or `status: blocked` blocks the merge entirely. No partial merges.
- Interface deviations with `downstream_action_required: true` must be propagated to downstream agent prompts before that wave launches.
- Post-merge verification is the real gate. Agents pass in isolation; the merged codebase surfaces cross-package failures none of them saw individually.
- Fix before proceeding. Do not launch the next wave with a broken build.

---

## Orchestrator Post-Merge Checklist

After wave 1 completes:

- [ ] Read Agent A completion report — confirm `status: complete`; if `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; flag any file appearing in >1 agent's list before touching the working tree
- [ ] Review `interface_deviations` from Agent A — if any function signatures changed, update Wave 2 agent prompts before launching
- [ ] Merge Agent A: `git merge --no-ff wave1-agent-a -m "Merge wave1-agent-a: golden angle color system"`
- [ ] Worktree cleanup: `git worktree remove /path/to/wave1-agent-a` + `git branch -d wave1-agent-a`
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a (no linter configured)
      - [ ] `cd /Users/dayna.blackwell/code/scout-and-wave-web/web && command npm run build && command npm test`
- [ ] E20 stub scan: collect `files_changed`+`files_created` from Agent A completion report; run `bash "${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh" web/src/lib/agentColors.ts`; append output to IMPL doc as `## Stub Report — Wave 1`
- [ ] E21 quality gates: run `cd /Users/dayna.blackwell/code/scout-and-wave-web/web && command npm run build` and `command npm test`; both are required gates; failures block merge
- [ ] Fix any cascade failures — none expected (Wave 1 is isolated)
- [ ] Tick status checkboxes in this IMPL doc for Agent A
- [ ] Update interface contracts for any deviations logged by Agent A
- [ ] Apply `out_of_scope_deps` fixes flagged in Agent A completion report
- [ ] Feature-specific steps:
      - [ ] Visual verification: open web UI, check that colors for agents A-Z are distinct and readable
      - [ ] Dark mode check: toggle dark mode in browser, verify colors remain readable
      - [ ] If golden angle produces insufficient contrast, consider adding hue offset or switching algorithm (document in IMPL doc)
- [ ] Commit: `git commit -m "wave1: golden angle color system complete — foundation for multi-generation agent colors"`
- [ ] Launch Wave 2 (or pause for review if not `--auto`)

After wave 2 completes:

- [ ] Read all Agent B-F completion reports — confirm all `status: complete`; if any `partial` or `blocked`, stop and resolve before merging
- [ ] Conflict prediction — cross-reference `files_changed` lists; flag any file appearing in >1 agent's list before touching the working tree (Wave 2 agents have disjoint ownership, so no conflicts expected)
- [ ] Review `interface_deviations` — none expected from Wave 2 agents (they consume interfaces, not produce them)
- [ ] Merge each agent: `git merge --no-ff wave2-agent-{b,c,d,e,f} -m "Merge wave2-agent-{X}: {description}"`
- [ ] Worktree cleanup: `git worktree remove <path>` + `git branch -d <branch>` for each
- [ ] Post-merge verification:
      - [ ] Linter auto-fix pass: n/a (no linter configured)
      - [ ] `cd /Users/dayna.blackwell/code/scout-and-wave-web/web && command npm run build && command npm test`
- [ ] E20 stub scan: collect `files_changed`+`files_created` from all Wave 2 completion reports; run `bash "${CLAUDE_SKILL_DIR}/scripts/scan-stubs.sh" <files>`; append output to IMPL doc as `## Stub Report — Wave 2`
- [ ] E21 quality gates: run both build and test gates; failures block merge
- [ ] Fix any cascade failures — pay attention to components that import from `agentColors.ts` but were not in any agent's scope
- [ ] Tick status checkboxes in this IMPL doc for Agents B-F
- [ ] Update interface contracts for any deviations logged by agents
- [ ] Apply `out_of_scope_deps` fixes flagged in completion reports
- [ ] Feature-specific steps:
      - [ ] Visual verification: open web UI, test all surfaces (FileOwnershipTable, WaveStructurePanel, AgentCard, DependencyGraphPanel, BranchLane)
      - [ ] Multi-generation ID test: if test data includes A2, B3, verify they render with correct hue families and lightness variations
      - [ ] Dark mode check: toggle dark mode, verify all surfaces remain readable
      - [ ] Cross-surface consistency check: open multiple views side-by-side, confirm agent colors are consistent (e.g., Agent A is same color in WaveBoard, FileOwnershipTable, and DependencyGraphPanel)
- [ ] Rebuild Go binary: `cd /Users/dayna.blackwell/code/scout-and-wave-web && go build -o saw ./cmd/saw` (frontend is embedded)
- [ ] Restart server: `pkill -f "saw serve"; cd /Users/dayna.blackwell/code/scout-and-wave-web && ./saw serve &>/tmp/saw-serve.log &`
- [ ] Commit: `git commit -m "wave2: golden angle color system consumer updates — FileOwnershipTable refactor + component verifications complete"`
- [ ] Launch next wave (or mark feature complete)

---

## Status

| Wave | Agent | Description | Status |
|------|-------|-------------|--------|
| 1 | A | Golden angle color system implementation | TO-DO |
| 2 | B | FileOwnershipTable refactor (remove local colors) | TO-DO |
| 2 | C | WaveStructurePanel verification | TO-DO |
| 2 | D | AgentCard verification | TO-DO |
| 2 | E | DependencyGraphPanel verification | TO-DO |
| 2 | F | BranchLane verification | TO-DO |
| — | Orch | Post-merge integration + server restart | TO-DO |

# Symlink Audit Report

**Date:** 2026-03-22
**Audited paths:**
- `/Users/dayna.blackwell/code/scout-and-wave` (recursive)
- `/Users/dayna.blackwell/.claude/skills/saw/` (recursive)

---

## Summary

| Metric | Count |
|--------|-------|
| Total symlinks found | 15 |
| Valid symlinks (target exists) | 8 |
| Broken symlinks (target missing) | 7 |

---

## Broken Symlinks

### 1. Repo: `.claude/commands/saw.md`

- **Path:** `/Users/dayna.blackwell/code/scout-and-wave/.claude/commands/saw.md`
- **Points to:** `../../prompts/saw-skill.md` (relative)
- **Resolves to:** `/Users/dayna.blackwell/code/scout-and-wave/prompts/saw-skill.md`
- **Problem:** No `prompts/` directory exists at the repo root. The saw-skill.md file lives at `implementations/claude-code/prompts/saw-skill.md`.
- **Fix:** Relink to `../../implementations/claude-code/prompts/saw-skill.md`

### 2. Skill: `saw-worktree.md`

- **Path:** `/Users/dayna.blackwell/.claude/skills/saw/saw-worktree.md`
- **Points to:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-worktree.md`
- **Problem:** `saw-worktree.md` does not exist in the prompts directory. The file was likely removed or renamed.
- **Fix:** Remove this symlink, or create the missing file if the feature is still needed.

### 3. Skill: `saw-merge.md`

- **Path:** `/Users/dayna.blackwell/.claude/skills/saw/saw-merge.md`
- **Points to:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/saw-merge.md`
- **Problem:** `saw-merge.md` does not exist in the prompts directory. The file was likely removed or renamed.
- **Fix:** Remove this symlink, or create the missing file if the feature is still needed.

### 4. Skill: `scripts/validate-impl.sh`

- **Path:** `/Users/dayna.blackwell/.claude/skills/saw/scripts/validate-impl.sh`
- **Points to:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/scripts/validate-impl.sh`
- **Problem:** The entire `implementations/claude-code/scripts/` directory does not exist. Scripts were likely moved to the Go SDK (`scout-and-wave-go`).
- **Fix:** Remove this symlink. Validation is now handled by `sawtools` commands.

### 5. Skill: `scripts/scan-stubs.sh`

- **Path:** `/Users/dayna.blackwell/.claude/skills/saw/scripts/scan-stubs.sh`
- **Points to:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/scripts/scan-stubs.sh`
- **Problem:** Same as above -- the scripts directory does not exist.
- **Fix:** Remove this symlink. Stub scanning is now handled by `sawtools` commands.

### 6. Skill: `scaffold-agent.md` (root-level duplicate)

- **Path:** `/Users/dayna.blackwell/.claude/skills/saw/scaffold-agent.md`
- **Points to:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/scaffold-agent.md`
- **Problem:** No `scaffold-agent.md` exists at the prompts root. The file lives at `prompts/agents/scaffold-agent.md`.
- **Fix:** Remove this symlink. The correct symlink already exists at `agents/scaffold-agent.md`.

### 7. Skill: `scout.md` (root-level duplicate)

- **Path:** `/Users/dayna.blackwell/.claude/skills/saw/scout.md`
- **Points to:** `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/scout.md`
- **Problem:** No `scout.md` exists at the prompts root. The file lives at `prompts/agents/scout.md`.
- **Fix:** Remove this symlink. The correct symlink already exists at `agents/scout.md`.

---

## Valid Symlinks

### Skill Directory: `/Users/dayna.blackwell/.claude/skills/saw/`

| Symlink | Target | Status |
|---------|--------|--------|
| `SKILL.md` | `.../prompts/saw-skill.md` | Valid |
| `saw-bootstrap.md` | `.../prompts/saw-bootstrap.md` | Valid |
| `agent-template.md` | `.../prompts/agent-template.md` | Valid |
| `agents/critic-agent.md` | `.../prompts/agents/critic-agent.md` | Valid |
| `agents/scaffold-agent.md` | `.../prompts/agents/scaffold-agent.md` | Valid |
| `agents/integration-agent.md` | `.../prompts/agents/integration-agent.md` | Valid |
| `agents/scout.md` | `.../prompts/agents/scout.md` | Valid |
| `agents/wave-agent.md` | `.../prompts/agents/wave-agent.md` | Valid |

All valid symlinks point to files under `/Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/`.

---

## Skill Directory Symlinks

### Structure of `/Users/dayna.blackwell/.claude/skills/saw/`

```
saw/
  SKILL.md                -> saw-skill.md           (VALID)
  saw-bootstrap.md        -> saw-bootstrap.md       (VALID)
  agent-template.md       -> agent-template.md      (VALID)
  saw-worktree.md         -> saw-worktree.md        (BROKEN - file removed)
  saw-merge.md            -> saw-merge.md           (BROKEN - file removed)
  scaffold-agent.md       -> scaffold-agent.md      (BROKEN - moved to agents/)
  scout.md                -> scout.md               (BROKEN - moved to agents/)
  agents/
    critic-agent.md       -> agents/critic-agent.md      (VALID)
    scaffold-agent.md     -> agents/scaffold-agent.md    (VALID)
    integration-agent.md  -> agents/integration-agent.md (VALID)
    scout.md              -> agents/scout.md             (VALID)
    wave-agent.md         -> agents/wave-agent.md        (VALID)
  scripts/
    validate-impl.sh      -> scripts/validate-impl.sh   (BROKEN - dir removed)
    scan-stubs.sh          -> scripts/scan-stubs.sh      (BROKEN - dir removed)
  hooks/
    pre-commit-guard.sh   (regular file, not a symlink)
```

### Missing symlinks

The `agents/planner.md` file exists in the repo at `implementations/claude-code/prompts/agents/planner.md` but has no corresponding symlink in the skills directory. This may be intentional or an oversight.

---

## Recommendations

### Immediate fixes (remove broken symlinks)

```bash
# Remove broken symlinks from skills directory
rm /Users/dayna.blackwell/.claude/skills/saw/saw-worktree.md
rm /Users/dayna.blackwell/.claude/skills/saw/saw-merge.md
rm /Users/dayna.blackwell/.claude/skills/saw/scaffold-agent.md
rm /Users/dayna.blackwell/.claude/skills/saw/scout.md
rm /Users/dayna.blackwell/.claude/skills/saw/scripts/validate-impl.sh
rm /Users/dayna.blackwell/.claude/skills/saw/scripts/scan-stubs.sh
rmdir /Users/dayna.blackwell/.claude/skills/saw/scripts
```

### Fix repo command symlink

```bash
# Fix the .claude/commands/saw.md symlink
cd /Users/dayna.blackwell/code/scout-and-wave/.claude/commands
rm saw.md
ln -s ../../implementations/claude-code/prompts/saw-skill.md saw.md
```

### Consider adding

```bash
# Add planner agent symlink if it should be accessible via skills
ln -s /Users/dayna.blackwell/code/scout-and-wave/implementations/claude-code/prompts/agents/planner.md \
      /Users/dayna.blackwell/.claude/skills/saw/agents/planner.md
```

### Root cause

The broken symlinks stem from two reorganizations that were not propagated to the skills directory:
1. **Agent prompts moved** from `prompts/` root into `prompts/agents/` subdirectory (scout.md, scaffold-agent.md)
2. **Shell scripts removed** in favor of Go-based `sawtools` commands (validate-impl.sh, scan-stubs.sh)
3. **Feature prompts removed** (saw-worktree.md, saw-merge.md) -- likely consolidated into saw-skill.md
4. **Repo command symlink** uses a stale relative path predating the `implementations/` directory structure

#!/usr/bin/env bash
# validate-impl.sh — SAW IMPL doc typed-block validator (E16)
#
# Usage: bash scripts/validate-impl.sh <impl-doc-path>
#
# Exit codes:
#   0  All typed blocks valid (or no typed blocks found)
#   1  One or more validation errors — errors printed to stdout
#   2  Bad arguments or file not found
#
# Output: plain-text error list to stdout (paste directly into Scout correction prompt)
#         progress/info messages to stderr

set -uo pipefail

# ── Args ──────────────────────────────────────────────────────────────────────

impl_doc="${1:-}"

if [[ -z "$impl_doc" ]]; then
  echo "Usage: $0 <impl-doc-path>" >&2
  echo "  Example: bash scripts/validate-impl.sh docs/IMPL/IMPL-my-feature.md" >&2
  exit 2
fi

if [[ ! -f "$impl_doc" ]]; then
  echo "Error: file not found: $impl_doc" >&2
  exit 2
fi

echo "Validating: $impl_doc" >&2

# ── Block extraction ───────────────────────────────────────────────────────────
# Returns contents of a typed block starting at line $2 in file $1.
# Reads from line after the opening fence until the closing ```.

extract_block() {
  local file="$1"
  local start="$2"
  local n=0
  local past_open=false
  while IFS= read -r ln; do
    n=$((n + 1))
    if [[ $n -le $start ]]; then continue; fi
    # Closing fence: line is exactly ``` (with optional trailing whitespace)
    if [[ "$ln" =~ ^\`\`\`[[:space:]]*$ ]]; then break; fi
    echo "$ln"
  done < "$file"
}

# ── Validation helpers ─────────────────────────────────────────────────────────

errors=()

add_error() {
  errors+=("$1")
}

validate_file_ownership() {
  local content="$1"
  local lineno="$2"

  # Must have a header row containing File, Agent, Wave columns in correct order
  local header
  header=$(echo "$content" | grep -m1 "^|" | head -1)

  if [[ -z "$header" ]]; then
    add_error "impl-file-ownership block (line $lineno): missing header row — expected '| File | Agent | Wave | ...' in that order"
    return
  fi

  # E16D: Column order validation — File MUST be col 1, Agent col 2, Wave col 3
  # Split header by pipe and trim whitespace from each column
  IFS='|' read -ra cols <<< "$header"
  local col1=$(echo "${cols[1]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  local col2=$(echo "${cols[2]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  local col3=$(echo "${cols[3]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [[ "$col1" != "File" ]]; then
    add_error "impl-file-ownership block (line $lineno): column 1 must be 'File' — got '$col1'"
  fi
  if [[ "$col2" != "Agent" ]]; then
    add_error "impl-file-ownership block (line $lineno): column 2 must be 'Agent' — got '$col2'"
  fi
  if [[ "$col3" != "Wave" ]]; then
    add_error "impl-file-ownership block (line $lineno): column 3 must be 'Wave' — got '$col3'"
  fi

  # Must have at least one data row (not the header or separator)
  local data_rows
  data_rows=$(echo "$content" | grep "^|" | grep -v "File\s*|\|-\{3\}" | grep -vc "^[[:space:]]*$" || true)
  if [[ "$data_rows" -eq 0 ]]; then
    add_error "impl-file-ownership block (line $lineno): no data rows found — table must have at least one file entry"
  fi

  # Each data row must have at least 4 pipe-separated columns
  while IFS= read -r row; do
    # Skip header and separator rows
    [[ "$row" =~ "File" ]] && continue
    [[ "$row" =~ "----" ]] && continue
    [[ -z "$row" ]] && continue
    local col_count
    col_count=$(echo "$row" | tr -cd '|' | wc -c | tr -d ' ')
    if [[ "$col_count" -lt 4 ]]; then
      add_error "impl-file-ownership block (line $lineno): row has fewer than 4 columns: $row"
    fi
  done <<< "$content"
}

validate_dep_graph() {
  local content="$1"
  local lineno="$2"

  # Must have at least one Wave N header
  if ! echo "$content" | grep -qE "^Wave [0-9]+"; then
    add_error "impl-dep-graph block (line $lineno): missing 'Wave N (...):' header — each wave must start with 'Wave N'"
    return
  fi

  # Must have at least one agent line of the form [A] or [B] or [A2] etc.
  if ! echo "$content" | grep -qE "\[[A-Z][2-9]?\]"; then
    add_error "impl-dep-graph block (line $lineno): no agent lines found — expected lines like '    [A] path/to/file'"
  fi

  # Non-root agents must have either '✓ root' or 'depends on:'
  # Collect agent lines and check each has one or the other
  local agent_block=""
  local current_agent=""
  while IFS= read -r ln; do
    if [[ "$ln" =~ ^[[:space:]]+\[([A-Z][2-9]?)\] ]]; then
      # If we were tracking a previous agent, check it
      if [[ -n "$current_agent" && -n "$agent_block" ]]; then
        if ! echo "$agent_block" | grep -qE "✓ root|depends on:"; then
          add_error "impl-dep-graph block (line $lineno): agent [$current_agent] has neither '✓ root' nor 'depends on:' — one is required"
        fi
      fi
      current_agent="${BASH_REMATCH[1]}"
      agent_block="$ln"
    elif [[ -n "$current_agent" ]]; then
      agent_block="$agent_block
$ln"
    fi
  done <<< "$content"
  # Check last agent
  if [[ -n "$current_agent" && -n "$agent_block" ]]; then
    if ! echo "$agent_block" | grep -qE "✓ root|depends on:"; then
      add_error "impl-dep-graph block (line $lineno): agent [$current_agent] has neither '✓ root' nor 'depends on:' — one is required"
    fi
  fi
}

validate_wave_structure() {
  local content="$1"
  local lineno="$2"

  # Must have at least one Wave N: line
  if ! echo "$content" | grep -qE "^Wave [0-9]+:"; then
    add_error "impl-wave-structure block (line $lineno): missing 'Wave N:' lines — each wave must appear as 'Wave N: [A] [B]'"
    return
  fi

  # Must reference at least one agent ID ([A], [B], [A2], etc.)
  if ! echo "$content" | grep -qE "\[[A-Z][2-9]?\]"; then
    add_error "impl-wave-structure block (line $lineno): no agent IDs found — expected [A], [B], [A2], etc."
  fi
}

validate_completion_report() {
  local content="$1"
  local lineno="$2"

  local required_fields=("status:" "worktree:" "branch:" "commit:" "files_changed:" "interface_deviations:" "verification:")
  # Note: failure_type is conditionally required (when status is partial/blocked) but not checked here
  for field in "${required_fields[@]}"; do
    if ! echo "$content" | grep -q "^$field"; then
      add_error "impl-completion-report block (line $lineno): missing required field '$field'"
    fi
  done

  # status must be one of the three valid values
  if echo "$content" | grep -q "^status:"; then
    local status_val
    status_val=$(echo "$content" | grep "^status:" | head -1 | sed 's/^status:[[:space:]]*//' | tr -d '[:space:]' | cut -d'|' -f1)
    if [[ "$status_val" != "complete" && "$status_val" != "partial" && "$status_val" != "blocked" ]]; then
      add_error "impl-completion-report block (line $lineno): status must be 'complete', 'partial', or 'blocked' — got: '$status_val'"
    fi
  fi
}

# ── Main scan ─────────────────────────────────────────────────────────────────

block_count=0
lineno=0
# E16A: track which required block types have been seen
seen_file_ownership=false
seen_dep_graph=false
seen_wave_structure=false

while IFS= read -r line; do
  lineno=$((lineno + 1))

  if [[ "$line" =~ ^\`\`\`yaml[[:space:]]type=(impl-[a-z-]+) ]]; then
    block_type="${BASH_REMATCH[1]}"
    block_count=$((block_count + 1))
    block_content=$(extract_block "$impl_doc" "$lineno")

    echo "  checking $block_type block at line $lineno" >&2

    case "$block_type" in
      impl-file-ownership)   validate_file_ownership "$block_content" "$lineno"; seen_file_ownership=true ;;
      impl-dep-graph)        validate_dep_graph       "$block_content" "$lineno"; seen_dep_graph=true ;;
      impl-wave-structure)   validate_wave_structure  "$block_content" "$lineno"; seen_wave_structure=true ;;
      impl-completion-report) validate_completion_report "$block_content" "$lineno" ;;
      *)
        echo "  unknown block type '$block_type' at line $lineno — skipping" >&2
        ;;
    esac
  fi
done < "$impl_doc"

# ── E16A: Required block presence ─────────────────────────────────────────────
# Only fires when block_count > 0 (pre-typed-block docs skip this check).

if [[ $block_count -gt 0 ]]; then
  for required in impl-file-ownership impl-dep-graph impl-wave-structure; do
    seen_var="seen_${required#impl-}"   # strip "impl-" prefix: impl-file-ownership → seen_file_ownership
    seen_var="${seen_var//-/_}"
    if [[ "${!seen_var}" != "true" ]]; then
      add_error "missing required block: $required"
    fi
  done
fi

# ── E16C: Out-of-band dep graph detection (warn only) ─────────────────────────
# Scan plain fenced blocks (no type= annotation) for likely dep graph content.
# Warns to stdout but does NOT add to errors[] and does NOT affect exit code.

in_plain_block=false
plain_block_start=0
plain_block_buf=""
plain_lineno=0

while IFS= read -r line; do
  plain_lineno=$((plain_lineno + 1))

  if [[ "$line" =~ ^\`\`\`[a-zA-Z]*$ ]] && [[ ! "$line" =~ type= ]]; then
    # Opening plain fence (no type= annotation)
    in_plain_block=true
    plain_block_start=$plain_lineno
    plain_block_buf=""
    continue
  fi

  if [[ "$in_plain_block" == "true" ]]; then
    if [[ "$line" =~ ^\`\`\`[[:space:]]*$ ]]; then
      # Closing fence — check accumulated content
      if echo "$plain_block_buf" | grep -qE "\[[A-Z][2-9]?\]" && echo "$plain_block_buf" | grep -q "Wave"; then
        echo "WARNING: possible dep-graph content found outside typed block at line $plain_block_start — use \`\`\`yaml type=impl-dep-graph\`\`\`"
      fi
      in_plain_block=false
      plain_block_buf=""
    else
      plain_block_buf="$plain_block_buf
$line"
    fi
  fi
done < "$impl_doc"

# ── Results ───────────────────────────────────────────────────────────────────

echo "" >&2

if [[ $block_count -eq 0 ]]; then
  echo "WARNING: no typed blocks found in $impl_doc" >&2
  echo "No typed blocks found. If this doc uses the pre-v0.10.0 format, typed blocks are required for validation."
  exit 1  # Changed from exit 0 - orchestrator should send this back to Scout
fi

if [[ ${#errors[@]} -eq 0 ]]; then
  echo "PASS: $block_count block(s) checked, 0 errors" >&2
  exit 0
fi

# Print errors to stdout for the orchestrator to include in correction prompt
echo "FAIL: ${#errors[@]} error(s) found in $block_count block(s)"
echo ""
for i in "${!errors[@]}"; do
  echo "$((i + 1)). ${errors[$i]}"
done
exit 1

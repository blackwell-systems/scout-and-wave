#!/usr/bin/env bash
# scan-stubs.sh — SAW stub detection scanner (E20)
#
# Usage: bash scripts/scan-stubs.sh <file1> [file2 ...]
#
# Exit codes:
#   0  Always — stub detection is informational, never blocks
#
# Output: markdown table of hits to stdout, or "No stub patterns detected."
#         Progress/info messages to stderr

set -uo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <file1> [file2 ...]" >&2
  exit 0
fi

echo "Scanning ${#@} file(s) for stub patterns..." >&2

# ── Patterns ──────────────────────────────────────────────────────────────────
# Each pattern is: regex|label
patterns=(
  'TODO|TODO'
  'FIXME|FIXME'
  '^[[:space:]]*pass[[:space:]]*$|empty body (pass)'
  '^[[:space:]]*\.\.\.[[:space:]]*$|ellipsis body (...)'
  '\bNotImplementedError\b|NotImplementedError'
  'raise NotImplementedError|raise NotImplementedError'
  'throw new Error\(["'"'"']not implement|throw not implemented'
  '\bunimplemented!()|unimplemented!()'
  '\btodo!()|todo!()'
  'panic\("not implemented"\)|panic not implemented'
)

# ── Scan ──────────────────────────────────────────────────────────────────────
hits=()

for file in "$@"; do
  [[ -f "$file" ]] || continue
  lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    for entry in "${patterns[@]}"; do
      regex="${entry%%|*}"
      label="${entry##*|}"
      if echo "$line" | grep -qE "$regex"; then
        snippet=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)
        hits+=("| \`$file\` | $lineno | $label | \`$snippet\` |")
        break  # one hit per line is enough
      fi
    done
  done < "$file"
done

# ── Output ───────────────────────────────────────────────────────────────────
echo "" >&2

if [[ ${#hits[@]} -eq 0 ]]; then
  echo "No stub patterns detected."
  exit 0
fi

echo "Found ${#hits[@]} stub hit(s):" >&2
echo ""
echo "| File | Line | Pattern | Context |"
echo "|------|------|---------|---------|"
for hit in "${hits[@]}"; do
  echo "$hit"
done

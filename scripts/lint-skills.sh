#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0
for d in skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  name="$(basename "$d")"
  # frontmatter name matches folder
  fm_name="$(sed -n 's/^name: *//p' "$d/SKILL.md" | head -1)"
  [ "$fm_name" = "$name" ] || { echo "FAIL $name: frontmatter name mismatch ($fm_name)"; fail=1; }
  # description present
  grep -q '^description:' "$d/SKILL.md" || { echo "FAIL $name: no description"; fail=1; }
  # vendored engine match
  if [ -f "$d/scripts/mcp-wire.sh" ]; then
    cmp -s engine/mcp-wire.sh "$d/scripts/mcp-wire.sh" || { echo "FAIL $name: engine drift"; fail=1; }
  fi
done
# secrets patterns
if grep -RniE 'Bearer [A-Za-z0-9_-]{20,}|figd_[A-Za-z0-9]+' skills/ 2>/dev/null; then echo "FAIL: secret pattern"; fail=1; fi
exit $fail

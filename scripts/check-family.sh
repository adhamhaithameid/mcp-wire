#!/usr/bin/env bash
# Verify every app and domain skill carries the current engine.
set -eu -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for skill in skills/*; do
  [ -f "$skill/SKILL.md" ] || continue
  name="$(basename "$skill")"
  if [ "$name" != mcp-wire ]; then
    jq -e --arg name "$name" '[.apps[].skills[]] | index($name) != null' family.json >/dev/null || { echo "Unregistered skill: $name" >&2; exit 1; }
  fi
  bash scripts/sync-engine.sh --check "$skill"
done
while IFS= read -r name; do
  [ -f "skills/$name/SKILL.md" ] || { echo "Missing family skill: $name" >&2; exit 1; }
done < <(jq -r '.apps[].skills[]' family.json)
bash scripts/lock-family.sh --check

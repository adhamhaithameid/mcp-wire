#!/usr/bin/env bash
# Build complete, independently usable skill folders for npm discovery.
set -eu -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/skills/figma-wire"
cp "$ROOT/SKILL.md" "$ROOT/skills/figma-wire/SKILL.md"
for skill in "$ROOT"/skills/figma-*; do
  [ -f "$skill/SKILL.md" ] || continue
  mkdir -p "$skill/scripts" "$skill/references"
  for file in figma-wire.sh mcp-wire.sh figma-design.sh figma-tokens.sh figma-compare.sh new-app.sh install-skills.sh; do
    cp "$ROOT/scripts/$file" "$skill/scripts/$file"
  done
  cp "$ROOT/references/"*.md "$skill/references/"
done

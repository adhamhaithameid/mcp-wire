#!/usr/bin/env bash
# Install with no Node executable on PATH; runtime requirements stay minimal.
set -eu -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home/.local/bin"
for utility in bash curl jq base64 tr head env sleep dirname mkdir cp chmod ln basename uname mktemp cat rm grep awk tar mv cmp pgrep pkill setsid; do
  command -v "$utility" >/dev/null 2>&1 || continue
  ln -s "$(command -v "$utility")" "$WORK/bin/$utility"
done
cp -R "$ROOT" "$WORK/source"
PATH="$WORK/bin" HOME="$WORK/home" bash "$WORK/source/install.sh" >"$WORK/log" 2>&1
for skill in figma-wire figma-design figma-code figma-verify figma-pages; do
  test -f "$WORK/home/.agents/skills/$skill/scripts/mcp-wire.sh"
done
grep -q 'Node.js is absent' "$WORK/log"
PATH="$WORK/bin" bash "$WORK/home/.agents/skills/figma-wire/scripts/mcp-wire.sh" doctor --json | jq -e '.ok' >/dev/null
echo 'Installation without Node passed.'

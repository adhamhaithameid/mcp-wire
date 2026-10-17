#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
npm pack --silent >/dev/null 2>&1 || npm pack >/dev/null
tarball=$(ls *.tgz | head -1)
mkdir -p "$TMP/extract"
tar -xzf "$tarball" -C "$TMP/extract"
# must contain engine
test -f "$TMP/extract/package/engine/mcp-wire.sh"
# must contain skills SKILL.md
for s in mcp-wire figma-wire figma-design figma-code figma-pages figma-verify; do
  test -f "$TMP/extract/package/skills/$s/SKILL.md"
done
# must contain vendored scripts
test -f "$TMP/extract/package/skills/mcp-wire/scripts/mcp-wire.sh"
# must not contain .opencode
if find "$TMP/extract" -path '*\.opencode*' | grep -q .; then echo "FAIL: .opencode in package"; exit 1; fi
# must not contain nested duplicate skill folders
if [ -d "$TMP/extract/package/skills/figma-wire/skills" ]; then echo "FAIL: nested skills"; exit 1; fi
echo "package ok"
rm -f "$tarball"

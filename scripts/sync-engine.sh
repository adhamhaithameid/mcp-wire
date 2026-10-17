#!/usr/bin/env bash
# Vendor the shared engine and optional family helpers into independent skills.
# Usage: sync-engine.sh [--check] <skill-dir> [<skill-dir>...]
# Sharing happens at build time; installed skills need no sibling checkout.
set -eu -o pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK=0
if [ "${1:-}" = --check ]; then CHECK=1; shift; fi
[ $# -ge 1 ] || { echo 'Usage: sync-engine.sh [--check] <skill-dir> [...]' >&2; exit 1; }
RC=0
for skill in "$@"; do
  [ -d "$skill" ] || { echo "Missing skill directory: $skill" >&2; RC=1; continue; }
  for name in mcp-wire.sh new-app.sh install-skills.sh; do
    SOURCE="$REPO/scripts/$name"
    [ "$name" != mcp-wire.sh ] || SOURCE="$REPO/engine/mcp-wire.sh"
    DEST="$skill/scripts/$name"
    if [ "$CHECK" -eq 1 ]; then
      if ! cmp -s "$SOURCE" "$DEST"; then echo "STALE: $DEST differs from its shared source" >&2; RC=1; fi
    else
      mkdir -p "$skill/scripts"
      cp "$SOURCE" "$DEST"
    fi
  done
  [ "$CHECK" -eq 1 ] || echo "synced: shared engine and helpers into $skill"
done
exit "$RC"

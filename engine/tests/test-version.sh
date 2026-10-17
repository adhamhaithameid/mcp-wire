#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
EV=$(grep '^VERSION=' "$ROOT/engine/mcp-wire.sh" | cut -d'"' -f2)
PV=$(python3 -c "import json;print(json.load(open('$ROOT/package.json'))['version'])")
test "$EV" = "$PV" && echo "version match: $EV" || { echo "mismatch $EV vs $PV"; exit 1; }

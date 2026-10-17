#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MC="$HERE/../mcp-wire.sh"
PASS=0; FAIL=0
t() { if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $*"; fi; }
# syntax checks
for f in scripts/*.sh skills/*/scripts/*.sh; do t bash -n "$f"; done
# --help
echo "scripts tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

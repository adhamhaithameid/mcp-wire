#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PASS=0; FAIL=0
t() { if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $*"; fi; }
t bash -n "$ROOT/.github/actions/figma-verify/run.sh"
INPUT_PAGE_URL=http://x INPUT_NODE_ID=1:2 INPUT_TOLERANCE=5 bash "$ROOT/.github/actions/figma-verify/run.sh"
echo "action tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PASS=0; FAIL=0
t() { if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $*"; fi; }
tmp=$(mktemp -d)
magick -size 10x10 xc:red "$tmp/a.png" 2>/dev/null
magick -size 10x10 xc:red "$tmp/b.png" 2>/dev/null
magick -size 10x10 xc:blue "$tmp/c.png" 2>/dev/null
INPUT_REFERENCE="$tmp/a.png" INPUT_ACTUAL="$tmp/b.png" INPUT_TOLERANCE=5 INPUT_DIFF_OUT="$tmp/d.png" bash "$ROOT/.github/actions/figma-verify/run.sh" >/dev/null 2>&1 && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL identical"; }
INPUT_REFERENCE="$tmp/a.png" INPUT_ACTUAL="$tmp/c.png" INPUT_TOLERANCE=5 INPUT_DIFF_OUT="$tmp/d2.png" bash "$ROOT/.github/actions/figma-verify/run.sh" >/dev/null 2>&1 && { FAIL=$((FAIL+1)); echo "FAIL different should fail"; } || PASS=$((PASS+1))
echo "figma-verify tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
rm -rf "$tmp"

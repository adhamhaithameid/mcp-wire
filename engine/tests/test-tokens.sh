#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PASS=0; FAIL=0
t() { if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $*"; fi; }
tmp=$(mktemp -d)
echo '{"color":{"a":"#fff"},"space":{"b":4}}' > "$tmp/v.json"
# flatten not needed; use flat
echo '{"a":"#fff","b":4}' > "$tmp/v.json"
t bash "$ROOT/scripts/gen-tokens.sh" "$tmp/v.json" "$tmp/out"
t test -f "$tmp/out/tokens.css"
t grep -q -- '--a:' "$tmp/out/tokens.css"
echo "token tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
rm -rf "$tmp"

#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
unset ANTHROPIC_API_KEY
bash "$ROOT/scripts/eval-routing.sh" >/dev/null 2>&1 && echo "skip ok" || { echo "FAIL"; exit 1; }

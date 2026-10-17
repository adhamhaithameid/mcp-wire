#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 - <<'PY'
import json
p="evals/routing.jsonl"
n=0
for line in open(p):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    assert "prompt" in o and "expected" in o
    n+=1
print("validated", n, "prompts")
PY
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then echo "model step would run"; else echo "no API key; skipping model step (exit 0)"; fi
exit 0

#!/usr/bin/env bash
# mcp-wire engine self-tests — hermetic against the local fake server.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MC="$HERE/../mcp-wire.sh"
SYNC="$HERE/../../scripts/sync-engine.sh"
TMP="$(mktemp -d)"
PASS=0; FAIL=0
cleanup() { if [ -n "${SERVER_PID:-}" ]; then kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; fi; rm -rf "$TMP"; }
trap cleanup EXIT

t()     { local n="$1"; shift; if "$@" > "$TMP/o" 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $n"; head -5 "$TMP/o" | sed 's/^/    /'; fi; }
a() { local n="$1"; shift; if "$@" > "$TMP/assert" 2>&1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $n"; cat "$TMP/assert"; fi; }
tfail() { local n="$1"; shift; if "$@" > "$TMP/o" 2>&1; then FAIL=$((FAIL+1)); echo "FAIL (expected nonzero): $n"; else PASS=$((PASS+1)); fi; }

node "$HERE/fake-server.js" 0 > "$TMP/port" 2>/dev/null &
SERVER_PID=$!
for _ in $(seq 1 50); do [ -s "$TMP/port" ] && break; sleep 0.1; done
PORT="$(head -1 "$TMP/port")"
URL="http://127.0.0.1:${PORT}/mcp"

echo "== mcp-wire engine test suite (fake server on ${URL}) =="

t "syntax"                          bash -n "$MC"
t "version"                         bash "$MC" --version
t "help"                            bash "$MC" --help
tfail "plain http refused by default" bash "$MC" "$URL" list
t "list with --allow-http"          bash "$MC" "$URL" list --allow-http
t "list shows echo tool"            bash "$MC" "$URL" list --allow-http
grep -q '^echo ::' "$TMP/o" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: list output missing echo tool"; }
t "call echo tool"                  bash "$MC" "$URL" call echo '{"text":"hi"}' --allow-http
grep -q 'hello from fake tool' "$TMP/o" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: call output missing tool text"; }
t "call with -o writes txt"         bash "$MC" "$URL" call echo '{"text":"x"}' -o "$TMP/out" --allow-http
t "-o file exists"                  test -f "$TMP/out.txt"
tfail "bad json args rejected"      bash "$MC" "$URL" call echo 'NOT-JSON' --allow-http
tfail "missing url rejected"        bash "$MC" list
tfail "unknown command rejected"    bash "$MC" "$URL" nope --allow-http

# Transport and discovery regressions.
t "JSON stateless list" bash "$MC" "$URL/json" list --json --allow-http
a "JSON list shape" jq -e '.tools | length == 2' "$TMP/o"
t "paginated tools" bash "$MC" "$URL/pages" list --json --allow-http
a "both pages returned" jq -e '.tools | length == 2' "$TMP/o"
t "schema discovery" bash "$MC" "$URL" describe echo --allow-http
a "schema preserved" grep -q "text (string" "$TMP/o"
tfail "unknown tool rejected" bash "$MC" "$URL" describe missing --allow-http
t "authenticated initialization and notification" bash "$MC" "$URL/auth" list --header 'Authorization: Bearer fixture-secret' --allow-http
tfail "auth rejected" bash "$MC" "$URL/auth" list --allow-http
tfail "HTTP failure rejected" bash "$MC" "$URL/http-error" list --allow-http
tfail "malformed response rejected" bash "$MC" "$URL/malformed" list --allow-http
tfail "tool errors exit nonzero" bash "$MC" "$URL" call failure --json --allow-http
t "resources list" bash "$MC" "$URL" resources list --json --allow-http
t "resources read" bash "$MC" "$URL" resources read fixture://hello --json --allow-http
a "resource contents" jq -e '.contents[0].text == "fixture resource"' "$TMP/o"
t "resource templates" bash "$MC" "$URL" resources templates --json --allow-http
t "prompts list" bash "$MC" "$URL" prompts list --json --allow-http
t "prompts get" bash "$MC" "$URL" prompts get review '{"code":"hello"}' --json --allow-http
a "prompt arguments" jq -e '.messages[0].content.text == "hello"' "$TMP/o"
t "image export" bash "$MC" "$URL" call image -o "$TMP/image" --allow-http
t "image bytes" test -s "$TMP/image-1.png"
t "stdio discovery" bash "$MC" --stdio "$(jq -nc --arg p "$HERE/fake-server.js" '["node",$p,"--stdio"]')" list --json --timeout 3
a "stdio result" jq -e '.tools[0].name == "echo"' "$TMP/o"
t "stdio call" bash "$MC" --stdio "$(jq -nc --arg p "$HERE/fake-server.js" '["node",$p,"--stdio"]')" call echo '{"text":"stdio"}' --json --timeout 3
a "stdio call result" jq -e '.content[0].text | contains("stdio")' "$TMP/o"
tfail "stdio timeout" bash "$MC" --stdio '["sh","-c","sleep 2"]' list --timeout 1
tfail "missing flag argument terminates" bash "$MC" "$URL" list --timeout
tfail "invalid timeout rejected" bash "$MC" "$URL" list --timeout bad
tfail "array tool arguments rejected" bash "$MC" "$URL" call echo '[]' --allow-http
t "dry run does not connect" bash "$MC" http://127.0.0.1:1/mcp call echo --dry-run --allow-http
a "dry run shape" jq -e '.dryRun == true and .method == "tools/call"' "$TMP/o"
printf '{"servers":{"fixture":{"url":"%s","headerEnv":{"Authorization":"TEST_MCP_AUTH"}}}}' "$URL/auth" > "$TMP/servers.json"
t "named server headers from environment" env TEST_MCP_AUTH='Bearer fixture-secret' bash "$MC" fixture list --config "$TMP/servers.json" --allow-http
t "registry output redacted" bash "$MC" servers --config "$TMP/servers.json"
a "registry only contains names and transport" jq -e '.[0] == {name:"fixture",transport:"http"}' "$TMP/o"
t "doctor dependencies" bash "$MC" doctor --json
t "doctor server" bash "$MC" doctor "$URL" --allow-http
a "doctor initialized and pinged" jq -e '.ok and .initialized and .ping' "$TMP/o"

tfail "header file syntax rejected" bash "$MC" "$URL" list --header @/etc/passwd --allow-http
tfail "header line breaks rejected" bash "$MC" "$URL" list --header $'Authorization: safe\nInjected: value' --allow-http
t "malformed argument error does not echo input" bash -c 'out=$(bash "$1" "$2" call echo "secret-invalid-json" --allow-http 2>&1); test $? -ne 0 && ! printf "%s" "$out" | grep -q secret-invalid-json' _ "$MC" "$URL"

t "structured-only result preserved" bash "$MC" "$URL" call structured --allow-http
a "structured data readable" jq -e '.value==42' "$TMP/o"
t "resource link content preserved" bash "$MC" "$URL" call resource-link --allow-http
a "resource link URI printed" grep -q 'fixture://linked' "$TMP/o"
tfail "malformed tool content rejected" bash "$MC" "$URL" call malformed-content --allow-http

# --- sync-engine: vendoring into skills ------------------------------------------------
SKILL="$TMP/fake-skill"
mkdir -p "$SKILL/scripts"
t "sync: stamps engine into skill"  bash "$SYNC" "$SKILL"
t "sync: copy matches engine"       cmp -s "$MC" "$SKILL/scripts/mcp-wire.sh"
t "check: fresh copy passes"        bash "$SYNC" --check "$SKILL"
printf 'stale' >> "$SKILL/scripts/mcp-wire.sh"
tfail "check: stale copy fails"     bash "$SYNC" --check "$SKILL"
tfail "sync: missing dir rejected"  bash "$SYNC" "$TMP/does-not-exist"

# --- stdio hardening tests ---
STDIO_CRASH="$(mktemp)"
cat > "$STDIO_CRASH" <<'NODE'
const rl = require('readline').createInterface({input: process.stdin});
rl.on('line', line => {
  const m = JSON.parse(line);
  if (m.method === 'initialize') console.log(JSON.stringify({jsonrpc:'2.0',id:m.id,result:{protocolVersion:'2025-11-25',capabilities:{},serverInfo:{name:'x',version:'1'}}}));
  else process.exit(1);
});
NODE
tfail "stdio crash handled" bash "$MC" --stdio "$(jq -nc --arg p "$STDIO_CRASH" '["node",$p]')" list --timeout 3
rm -f "$STDIO_CRASH"

echo "== results: ${PASS} passed, ${FAIL} failed =="
[ "$FAIL" -eq 0 ]


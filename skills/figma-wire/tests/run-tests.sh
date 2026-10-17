#!/usr/bin/env bash
# figma-wire self-tests — hermetic: sandbox config/state + a fake Dev Mode server,
# so they run on any machine with bash, curl, jq, node (Figma not required).
#
#   bash tests/run-tests.sh
#   SKIP_NETWORK_TESTS=1 bash tests/run-tests.sh   # skip the two live-network tests
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW="$SCRIPT_DIR/../scripts/figma-wire.sh"
TMP="$(mktemp -d)"
SERVER_PID=""

cleanup() { if [ -n "$SERVER_PID" ]; then kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; fi; rm -rf "$TMP"; }
trap cleanup EXIT

PASS=0; FAIL=0
t() { # t <name> <cmd...> — expect exit 0
  local name="$1"; shift
  if "$@" > "$TMP/out.txt" 2>&1; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $name"; sed 's/^/    /' "$TMP/out.txt" | head -10
  fi
}
tfail() { # tfail <name> <cmd...> — expect nonzero exit
  local name="$1"; shift
  if "$@" > "$TMP/out.txt" 2>&1; then
    FAIL=$((FAIL+1)); echo "FAIL (expected nonzero exit): $name"
  else PASS=$((PASS+1)); fi
}
assert() { # assert <name> <cmd...> — command must exit 0 (stdout silenced)
  local name="$1"; shift
  if "$@" > "$TMP/assert.txt" 2>&1; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $name"; sed 's/^/    /' "$TMP/assert.txt" | head -5
  fi
}
assert_not() { # assert_not <name> <cmd...> — command must exit nonzero
  local name="$1"; shift
  if "$@" > "$TMP/assert.txt" 2>&1; then
    FAIL=$((FAIL+1)); echo "FAIL (expected nonzero): $name"
  else PASS=$((PASS+1)); fi
}
out_has() { grep -q "$1" "$TMP/out.txt"; }

unset FIGMA_WIRE_SERVER FIGMA_TOKEN

# --- sandbox env ---------------------------------------------------------------
export FIGMA_WIRE_HOME="$TMP"
export FIGMA_WIRE_STATE="$TMP/state.json"
export FIGMA_WIRE_HARNESS="zcode"
ZCFG="$TMP/zcode-config.json"
export FIGMA_WIRE_CONFIG="$ZCFG"

# --- fake Dev Mode server -------------------------------------------------------
node "$SCRIPT_DIR/fake-devmode-server.js" 0 > "$TMP/port.txt" 2>/dev/null &
SERVER_PID=$!
for _ in $(seq 1 50); do [ -s "$TMP/port.txt" ] && break; sleep 0.1; done
PORT="$(head -1 "$TMP/port.txt")"
if [ -z "$PORT" ]; then echo "FATAL: fake server did not start"; exit 1; fi
export FIGMA_WIRE_PORT="$PORT"

KEY="KxNvQk9xampleOnly123"   # 20-char alnum test fileKey

echo "== figma-wire test suite (fake server on 127.0.0.1:${PORT}) =="

# --- static checks ---------------------------------------------------------------
t "syntax (bash -n)"          bash -n "$FW"
if command -v shellcheck > /dev/null 2>&1; then
  t "shellcheck"              shellcheck -S warning "$FW"
else
  echo "SKIP: shellcheck not installed"
fi

# --- basics ----------------------------------------------------------------------
t "version"                   bash "$FW" version
t "help"                      bash "$FW" --help
t "config shows settings"     bash "$FW" config
t "config honors sandbox"     bash "$FW" config
assert "config uses sandbox config path" grep -q "$TMP" "$TMP/out.txt"

# --- link parsing ------------------------------------------------------------------
t "link: design URL + node-id" bash "$FW" link "https://www.figma.com/design/${KEY}/CTA-Buttons?node-id=1420-3391&t=abc123"
assert "link: correct fileKey"          grep -q "fileKey : ${KEY}" "$TMP/out.txt"
assert "link: colon nodeId"             grep -q "1420:3391" "$TMP/out.txt"
assert "link: dash nodeId"              grep -q "1420-3391" "$TMP/out.txt"
t "link: hyphenated name (regression)"  bash "$FW" link "https://www.figma.com/design/${KEY}/My-Super-Long-File-Name?node-id=1-2"
assert "link: still parses fileKey"     grep -q "fileKey : ${KEY}" "$TMP/out.txt"
t "link: legacy /file/ URL, no node"    bash "$FW" link "https://www.figma.com/file/${KEY}/Legacy%20File"
assert "link: no-node note"             grep -q "nodeId  : (none" "$TMP/out.txt"
t "link: figjam URL"                    bash "$FW" link "https://www.figma.com/figjam/${KEY}/Board"
assert "link: figjam kind"              grep -q "kind    : figjam" "$TMP/out.txt"
t "link: proto URL + node-id"           bash "$FW" link "https://www.figma.com/proto/${KEY}/App/page?node-id=7-10&scaling=1"
assert "link: proto nodeId"             grep -q "7:10" "$TMP/out.txt"
t "link: bare 22-char fileKey"          bash "$FW" link "AbCdEfGhIjKlMnOpQrStUv"
assert "link: bare key accepted"        grep -q "fileKey : AbCdEfGhIjKlMnOpQrStUv" "$TMP/out.txt"
tfail "link: garbage input"             bash "$FW" link "https://example.com/not-figma"
assert "link: garbage has hint"         out_has "Could not parse a fileKey"
assert "state: bare file key clears previous node" jq -e '(.lastLink | has("nodeIdColon")) == false' "$FIGMA_WIRE_STATE"
assert "state: lastLink.fileKey stored" jq -e '.lastLink.fileKey == "AbCdEfGhIjKlMnOpQrStUv"' "$FIGMA_WIRE_STATE"

# --- use: refusals -------------------------------------------------------------------
tfail "use: dead port refused"          bash "$FW" use 1
assert_not "use: dead port wrote nothing" test -f "$ZCFG"

# --- use: success paths ---------------------------------------------------------------
t "use: fake server port"               bash "$FW" use "$PORT"
assert "use: zcode entry written"       jq -e --arg u "http://127.0.0.1:${PORT}/mcp" '.mcp.servers["figma-local"].url == $u and .mcp.servers["figma-local"].type == "http"' "$ZCFG"
assert "use: state localPort saved"     jq -e --arg p "$PORT" '.localPort == ($p | tonumber)' "$FIGMA_WIRE_STATE"
t "use: idempotent re-run"              bash "$FW" use "$PORT"
assert "use: config still valid JSON"   jq -e . "$ZCFG"

rm -f "$ZCFG"
t "use: creates missing config"         bash "$FW" use "$PORT"
assert "use: created config valid"      jq -e '.mcp.servers["figma-local"]' "$ZCFG"

printf 'THIS IS NOT JSON' > "$ZCFG"
tfail "use: refuses invalid JSON"       bash "$FW" use "$PORT"
assert "use: invalid config untouched"  grep -q "THIS IS NOT JSON" "$ZCFG"
printf '{"mcp":{"servers":{}}}' > "$ZCFG"

t "use: --harness claude"               env FIGMA_WIRE_CONFIG="$TMP/claude.json" FIGMA_WIRE_HARNESS=claude bash "$FW" use "$PORT"
assert "use: claude mcpServers shape"   jq -e --arg u "http://127.0.0.1:${PORT}/mcp" '.mcpServers["figma-local"].url == $u and .mcpServers["figma-local"].type == "http"' "$TMP/claude.json"
t "use: --harness cursor"               env FIGMA_WIRE_CONFIG="$TMP/cursor.json" FIGMA_WIRE_HARNESS=cursor bash "$FW" use "$PORT"
assert "use: cursor minimal shape"      jq -e --arg u "http://127.0.0.1:${PORT}/mcp" '.mcpServers["figma-local"] == {"url":$u}' "$TMP/cursor.json"
t "use: --harness generic"              env FIGMA_WIRE_CONFIG="$TMP/generic-mcp.json" FIGMA_WIRE_HARNESS=generic bash "$FW" use "$PORT"
assert "use: generic mcpServers shape"  jq -e '.mcpServers["figma-local"].type == "http"' "$TMP/generic-mcp.json"
t "use: --harness codex (TOML)"         env FIGMA_WIRE_CONFIG="$TMP/codex.toml" FIGMA_WIRE_HARNESS=codex bash "$FW" use "$PORT"
assert "use: codex TOML block"          grep -q '^\[mcp_servers\.figma-local\]' "$TMP/codex.toml"
assert "use: codex TOML url"            grep -q "url = \"http://127.0.0.1:${PORT}/mcp\"" "$TMP/codex.toml"

# codex TOML idempotency: re-run must not duplicate the block
t "use: codex idempotent"               env FIGMA_WIRE_CONFIG="$TMP/codex.toml" FIGMA_WIRE_HARNESS=codex bash "$FW" use "$PORT"
assert "use: codex single block"        [ "$(grep -c '^\[mcp_servers\.figma-local\]' "$TMP/codex.toml")" = "1" ]

# --- remote management ------------------------------------------------------------------
printf '{"mcp":{"servers":{"figma":{"type":"http","url":"https://mcp.figma.com/mcp"}}}}' > "$ZCFG"
t "remote off: zcode"                   bash "$FW" remote off
assert "remote off: enabled=false"      jq -e '.mcp.servers.figma.enabled == false' "$ZCFG"
t "remote off: idempotent (no entry)"   bash "$FW" remote off
t "remote off: codex removes block"     env FIGMA_WIRE_CONFIG="$TMP/codex2.toml" FIGMA_WIRE_HARNESS=codex bash "$FW" remote off

if [ "${SKIP_NETWORK_TESTS:-0}" = "1" ]; then
  echo "SKIP: network tests"
else
  cp "$ZCFG" "$TMP/zcfg.before"
  tfail "remote token: bogus token rejected" bash "$FW" remote token "figma-wire-invalid-token-test"
  assert "remote token: config untouched on failure" cmp -s "$ZCFG" "$TMP/zcfg.before"
fi

# --- fetch (no token) ---------------------------------------------------------------------
tfail "fetch: no token errors cleanly"  bash "$FW" fetch
assert "fetch: mentions token paths"    out_has "FIGMA_TOKEN"

# --- doctor ---------------------------------------------------------------------------------
rm -f "$ZCFG"; printf '{"mcp":{"servers":{}}}' > "$ZCFG"
tfail "doctor: unwired config fails"    bash "$FW" doctor
t "doctor: rewire after failure"        bash "$FW" use "$PORT"
t "doctor: wired config passes"         bash "$FW" doctor
assert "doctor: all-good banner"        out_has "All good"
# mismatched URL scenario
jq '.mcp.servers["figma-local"].url = "http://127.0.0.1:9/mcp"' "$ZCFG" > "$TMP/mm.json" && mv -f "$TMP/mm.json" "$ZCFG"
tfail "doctor: mismatched url fails"    bash "$FW" doctor
printf 'GARBAGE' > "$FIGMA_WIRE_STATE"
t "doctor: garbage state rewire"        bash "$FW" use "$PORT"
t "doctor: garbage state tolerated"     bash "$FW" doctor

# --- status -----------------------------------------------------------------------------------
t "status: valid JSON"                  bash "$FW" status
assert "status: local ok true"          bash "$FW" status | jq -e '.local.ok == true'
assert "status: harness reported"       bash "$FW" status | jq -e '.harness == "zcode"'

# --- v1.2: new harness shapes ------------------------------------------------------------
t "use: --harness windsurf"             env FIGMA_WIRE_CONFIG="$TMP/windsurf.json" FIGMA_WIRE_HARNESS=windsurf bash "$FW" use "$PORT"
assert "use: windsurf serverUrl shape"  jq -e --arg u "http://127.0.0.1:${PORT}/mcp" '.mcpServers["figma-local"].serverUrl == $u' "$TMP/windsurf.json"
t "use: --harness gemini"               env FIGMA_WIRE_CONFIG="$TMP/gemini.json" FIGMA_WIRE_HARNESS=gemini bash "$FW" use "$PORT"
assert "use: gemini httpUrl shape"      jq -e --arg u "http://127.0.0.1:${PORT}/mcp" '.mcpServers["figma-local"].httpUrl == $u' "$TMP/gemini.json"
t "use: --harness vscode"               env FIGMA_WIRE_CONFIG="$TMP/vscode.json" FIGMA_WIRE_HARNESS=vscode bash "$FW" use "$PORT"
assert "use: vscode mcp.servers shape"  jq -e --arg u "http://127.0.0.1:${PORT}/mcp" '.mcp.servers["figma-local"] == {"type":"http","url":$u}' "$TMP/vscode.json"

# --- v1.2: remote off removes entry on no-flag harnesses ---------------------------------
t "remote off: windsurf removes entry"  env FIGMA_WIRE_CONFIG="$TMP/windsurf.json" FIGMA_WIRE_HARNESS=windsurf bash "$FW" remote off
assert "remote off: windsurf entry gone" jq -e '.mcpServers | has("figma") | not' "$TMP/windsurf.json"
t "remote off: vscode removes entry"    env FIGMA_WIRE_CONFIG="$TMP/vscode.json" FIGMA_WIRE_HARNESS=vscode bash "$FW" remote off
assert "remote off: vscode entry gone"  jq -e '.mcp.servers | has("figma") | not' "$TMP/vscode.json"

# --- v1.2: doctor --json -------------------------------------------------------------------
t "doctor --json is valid JSON"         bash "$FW" doctor --json
assert "doctor --json: local ok"        bash "$FW" doctor --json | jq -e '.local.ok == true and .wired == true and .ok == true'
assert "doctor --json: remote disabled" bash "$FW" doctor --json | jq -e '.remote.present == false'

# --- v1.2: doctor --fix port watcher --------------------------------------------------------
jq '.mcp.servers["figma-local"].url = "http://127.0.0.1:9/mcp"' "$ZCFG" > "$TMP/fw.json" && mv -f "$TMP/fw.json" "$ZCFG"
printf '{"localPort": 9}' > "$FIGMA_WIRE_STATE"
t "doctor --fix recovers moved port"    env FIGMA_WIRE_PORT=9 FIGMA_WIRE_SCAN_PORTS="${PORT}-${PORT}" bash "$FW" doctor --fix
assert "doctor --fix: state updated"    jq -e --arg p "$PORT" '.localPort == ($p | tonumber)' "$FIGMA_WIRE_STATE"
assert "doctor --fix: config rewired"   jq -e --arg u "http://127.0.0.1:${PORT}/mcp" '.mcp.servers["figma-local"].url == $u' "$ZCFG"
tfail "doctor --fix: range without server fails" env FIGMA_WIRE_PORT=9 FIGMA_WIRE_SCAN_PORTS="9-9" bash "$FW" doctor --fix

# --- v1.2: call passthrough (fake server) ---------------------------------------------------
t "call: smoke against fake server"     bash "$FW" call get_design_context '{"nodeId":"1:1"}'
assert "call: raw result dumped"        out_has "design node"
tfail "call: no live server anywhere"   env FIGMA_WIRE_PORT=9 FIGMA_WIRE_SCAN_PORTS="9-9" bash "$FW" call get_design_context '{"nodeId":"1:1"}'
assert "call: missing-server hint"      out_has "Dev Mode"
t "call: bare nodeId shorthand"         bash "$FW" call get_design_context "12:34"
assert "call: shorthand works"          out_has "design node"

# --- v1.3: diff arg validation (full path needs live Figma + browser; validated manually) --
tfail "diff: missing url rejected"      bash "$FW" diff "1:1"
tfail "diff: no args rejected"          bash "$FW" diff

# Shared engine and domain helpers.
t "tools: discover JSON" bash "$FW" tools --json
assert "tools: actual schemas" jq -e '.tools[0].inputSchema.type == "object"' "$TMP/out.txt"
t "describe: input schema" bash "$FW" describe get_screenshot
t "call: JSON result" bash "$FW" call get_design_context '1:2' --json
assert "call: result content" jq -e '.content[0].text == "design node 1:2"' "$TMP/out.txt"
t "call: image export" bash "$FW" call get_screenshot '1:2' -o "$TMP/image"
assert "call: bundled engine writes image" test -s "$TMP/image-1.png"
tfail "call: tool failure" bash "$FW" call fixture_error --json
t "design: collect packet" bash "$FW" design '1:2' "$TMP/packet"
assert "design: manifest" jq -e '.nodeId == "1:2"' "$TMP/packet/manifest.json"
assert "design: screenshot" test -s "$TMP/packet/reference-1.png"
tfail "design: do not overwrite" bash "$FW" design '1:2' "$TMP/packet"
t "tokens: export collected variables" bash "$FW" tokens "$TMP/packet/get_variable_defs.json" "$TMP/tokens"
assert "tokens: CSS variables" grep -q -- '--figma-color-primary: #c0392b;' "$TMP/tokens.css"
assert "tokens: TypeScript types" grep -q 'keyof typeof figmaTokens' "$TMP/tokens.ts"
printf '{"a/b":"red","a-b":"blue"}' > "$TMP/collision.json"
tfail "tokens: collision rejected" bash "$FW" tokens "$TMP/collision.json" "$TMP/collision"
printf '{"color":"red; } body { color: blue"}' > "$TMP/unsafe.json"
tfail "tokens: unsafe CSS rejected" bash "$FW" tokens "$TMP/unsafe.json" "$TMP/unsafe"
tfail "diff: invalid threshold" bash "$FW" diff '1:2' http://localhost --threshold 101
tfail "diff: invalid viewport" bash "$FW" diff '1:2' http://localhost --viewport bad
tfail "unknown harness rejected" bash "$FW" --harness invalid config
tfail "missing harness argument rejected" bash "$FW" --harness
t "doctor: JSON fix" env FIGMA_WIRE_CONFIG="$TMP/fix-json.json" bash "$FW" doctor --fix --json
assert "doctor: repaired JSON is clean" jq -e '.ok and .wired' "$TMP/out.txt"

# REST uses a separate personal access token and fails on HTTP errors.
mkdir -p "$TMP/rest-bin" "$TMP/rest"
cat > "$TMP/rest-bin/curl" <<'CURL'
#!/usr/bin/env bash
[ "${FIXTURE_REST_ERROR:-0}" != 1 ] || exit 22
output=''; url=''
while [ $# -gt 0 ]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s' "$url" > "$FIXTURE_REST_LOG"
printf '{"document":{"id":"fixture"}}' > "$output"
CURL
chmod +x "$TMP/rest-bin/curl"
rest_fetch() { (cd "$TMP/rest" && PATH="$TMP/rest-bin:$PATH" FIGMA_TOKEN=fixture-rest-token FIXTURE_REST_LOG="$TMP/rest-url" bash "$FW" fetch "$@"); }
t "REST: file endpoint" rest_fetch "$KEY"
assert "REST: no node endpoint without node ID" grep -qx "https://api.figma.com/v1/files/${KEY}" "$TMP/rest-url"
# Clear saved selection so an explicit whole-file fetch has no implicit node.
jq 'del(.lastLink.nodeIdColon)' "$FIGMA_WIRE_STATE" > "$TMP/cleared-state" && mv "$TMP/cleared-state" "$FIGMA_WIRE_STATE"
t "REST: whole file endpoint" rest_fetch "$KEY"
assert "REST: whole file URL" grep -qx "https://api.figma.com/v1/files/${KEY}" "$TMP/rest-url"
t "REST: selected node endpoint" rest_fetch "$KEY" '3:4'
assert "REST: node URL" grep -qx "https://api.figma.com/v1/files/${KEY}/nodes?ids=3:4" "$TMP/rest-url"
export FIXTURE_REST_ERROR=1
tfail "REST: HTTP failure is not success" rest_fetch "$KEY" '3:4'
assert_not "REST: failed artifact removed" test -f "$TMP/rest/figma-${KEY}-3-4.json"
unset FIXTURE_REST_ERROR

# --- misc -------------------------------------------------------------------------------------
tfail "unknown command rejected"        bash "$FW" nope

echo "== results: ${PASS} passed, ${FAIL} failed =="
[ "$FAIL" -eq 0 ]

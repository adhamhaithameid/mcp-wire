#!/usr/bin/env bash
# figma-wire — probe, wire, and route Figma access for AI coding agents.
# Works across harnesses: ZCode, Claude Code, Codex, Cursor, Windsurf, VS Code,
# Gemini CLI, or any tool reading ~/.agents/mcp.json.
#
# Commands: doctor [--json] [--fix] | use <port|url> | link <share-url|fileKey> |
#           call <tool> [nodeId|JSON] | remote token <TOKEN> [--region R] | remote off |
#           fetch [fileKey] [nodeId] | status | config | version
# Global flag: --harness <zcode|claude|codex|cursor|windsurf|vscode|gemini|generic|all>
# Env overrides: FIGMA_WIRE_HARNESS, FIGMA_WIRE_CONFIG, FIGMA_WIRE_STATE,
#                FIGMA_WIRE_PORT, FIGMA_WIRE_SCAN_PORTS, FIGMA_TOKEN
set -u -o pipefail

VERSION="1.4.1"
DEFAULT_PORT="${FIGMA_WIRE_PORT:-3845}"
REMOTE_URL="https://mcp.figma.com/mcp"
INIT_BODY='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"figma-wire","version":"1.0"}}}'

# Self-locate the skill (script lives in <skill>/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FIGMA_WIRE_HOME="${FIGMA_WIRE_HOME:-$HOME/.config/figma-wire}"
STATE_FILE="${FIGMA_WIRE_STATE:-$FIGMA_WIRE_HOME/state.json}"

# --- output helpers -----------------------------------------------------------
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_BAD=$'\033[31m'; C_WARN=$'\033[33m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_OK=""; C_BAD=""; C_WARN=""; C_DIM=""; C_RST=""
fi
ok()   { printf '%s[ ok ]%s %s\n' "$C_OK"   "$C_RST" "$*"; }
bad()  { printf '%s[FAIL]%s %s\n' "$C_BAD"  "$C_RST" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_WARN" "$C_RST" "$*"; }
info() { printf '%s[fix ]%s %s\n' "$C_DIM"  "$C_RST" "$*"; }

need_deps() {
  local missing=""
  command -v curl > /dev/null 2>&1 || missing="$missing curl"
  command -v jq   > /dev/null 2>&1 || missing="$missing jq"
  if [ -n "$missing" ]; then bad "Missing dependencies:$missing — install them and retry"; return 1; fi
  return 0
}

b64decode() { # stdin -> stdout (BSD vs GNU base64)
  case "$(uname -s)" in
    Darwin) base64 -D ;;
    *)      base64 -d ;;
  esac
}

# --- state helpers (script-internal values, jq assignment strings) ------------
state_get() { jq -r "$1 // empty" "$STATE_FILE" 2>/dev/null || true; }
state_set() {
  mkdir -p "$(dirname "$STATE_FILE")"
  [ -s "$STATE_FILE" ] || echo '{}' > "$STATE_FILE"
  local tmp; tmp="$(mktemp)"
  if jq "$1" "$STATE_FILE" > "$tmp" 2>/dev/null; then mv -f "$tmp" "$STATE_FILE"; else rm -f "$tmp"; fi
}

# --- probe --------------------------------------------------------------------
PROBE_CODE="000"; PROBE_BODY=""
PROBE_MAXTIME=8
probe() { # probe <url> [extra curl args...]
  local url="$1"; shift
  local tf hdr
  tf="$(mktemp)"; hdr="$(mktemp)"
  PROBE_CODE=$(curl -sS -D "$hdr" -o "$tf" -w '%{http_code}' --max-time "$PROBE_MAXTIME" -X POST "$url" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d "$INIT_BODY" "$@" 2>/dev/null) || PROBE_CODE="000"
  PROBE_BODY="$(tr '\r\n' '  ' < "$tf")"
  rm -f "$tf" "$hdr"
}
is_devmode_body() { grep -q 'Dev Mode MCP Server' <<<"$PROBE_BODY"; }

figma_app_running() { pgrep -x Figma > /dev/null 2>&1; }
local_url_for() { echo "http://127.0.0.1:${1}/mcp"; }

# Port precedence: FIGMA_WIRE_PORT env > persisted state > default 3845.
resolve_port() {
  if [ -n "${FIGMA_WIRE_PORT:-}" ]; then echo "$FIGMA_WIRE_PORT"; return 0; fi
  local p; p="$(state_get '.localPort')"
  if [ -n "$p" ]; then echo "$p"; else echo "3845"; fi
}

# Scan the configured port range for a live Dev Mode server.
# Range format: "A-B" (inclusive). Set FIGMA_WIRE_SCAN_PORTS to override.
find_local_port() {
  local first="" p
  local configured; configured="$(resolve_port)"
  probe "$(local_url_for "$configured")"
  [ "$PROBE_CODE" = "200" ] && is_devmode_body && { echo "$configured"; return 0; }
  local range="${FIGMA_WIRE_SCAN_PORTS:-3845-3854}"
  local lo="${range%-*}" hi="${range#*-}"
  local save_max="$PROBE_MAXTIME"; PROBE_MAXTIME=1
  for p in $(seq "$lo" "$hi"); do
    [ "$p" = "$configured" ] && continue
    probe "$(local_url_for "$p")"
    if [ "$PROBE_CODE" = "200" ] && is_devmode_body; then first="$p"; break; fi
  done
  PROBE_MAXTIME="$save_max"
  [ -n "$first" ] && { echo "$first"; return 0; }
  return 1
}

# --- harness layer ------------------------------------------------------------
HARNESS=""

detect_harness() {
  [ -n "$HARNESS" ] && { echo "$HARNESS"; return; }
  [ -n "${FIGMA_WIRE_HARNESS:-}" ] && { echo "$FIGMA_WIRE_HARNESS"; return; }
  [ -f "$HOME/.zcode/cli/config.json" ] && { echo zcode; return; }
  [ -f "$HOME/.claude.json" ] && { echo claude; return; }
  [ -f "$HOME/.cursor/mcp.json" ] && { echo cursor; return; }
  [ -f "$HOME/.codeium/windsurf/mcp_config.json" ] && { echo windsurf; return; }
  [ -f "$HOME/.gemini/settings.json" ] && { echo gemini; return; }
  [ -f "$(vscode_config_path)" ] && { echo vscode; return; }
  [ -f "$HOME/.codex/config.toml" ] && { echo codex; return; }
  echo generic
}

all_harnesses() { echo "zcode claude cursor windsurf gemini vscode codex generic"; }

vscode_config_path() {
  case "$(uname -s)" in
    Darwin) echo "${FIGMA_WIRE_CONFIG:-$HOME/Library/Application Support/Code/User/settings.json}" ;;
    *)      echo "${FIGMA_WIRE_CONFIG:-$HOME/.config/Code/User/settings.json}" ;;
  esac
}

harness_config_path() { # $1 harness -> config path on stdout
  case "$1" in
    zcode)    echo "${FIGMA_WIRE_CONFIG:-$HOME/.zcode/cli/config.json}" ;;
    claude)   echo "${FIGMA_WIRE_CONFIG:-$HOME/.claude.json}" ;;
    cursor)   echo "${FIGMA_WIRE_CONFIG:-$HOME/.cursor/mcp.json}" ;;
    windsurf) echo "${FIGMA_WIRE_CONFIG:-$HOME/.codeium/windsurf/mcp_config.json}" ;;
    gemini)   echo "${FIGMA_WIRE_CONFIG:-$HOME/.gemini/settings.json}" ;;
    vscode)   vscode_config_path ;;
    codex)    echo "${FIGMA_WIRE_CONFIG:-$HOME/.codex/config.toml}" ;;
    generic)  echo "${FIGMA_WIRE_CONFIG:-$HOME/.agents/mcp.json}" ;;
    *) return 1 ;;
  esac
}

# Harnesses whose remote entry supports an "enabled" flag; the rest drop the entry.
remote_flag_harness() { case "$1" in zcode|claude|cursor|generic) return 0 ;; *) return 1 ;; esac; }

# Write the figma-local server entry into a harness config.
json_set_local() { # $1 harness  $2 url  $3 file
  local expr
  case "$1" in
    zcode|vscode)   expr='.mcp = (.mcp // {}) | .mcp.servers = (.mcp.servers // {}) | .mcp.servers["figma-local"] = {"type":"http","url":$url}' ;;
    claude|generic) expr='.mcpServers = (.mcpServers // {}) | .mcpServers["figma-local"] = {"type":"http","url":$url}' ;;
    cursor)         expr='.mcpServers = (.mcpServers // {}) | .mcpServers["figma-local"] = {"url":$url}' ;;
    windsurf)       expr='.mcpServers = (.mcpServers // {}) | .mcpServers["figma-local"] = {"serverUrl":$url}' ;;
    gemini)         expr='.mcpServers = (.mcpServers // {}) | .mcpServers["figma-local"] = {"httpUrl":$url}' ;;
    *) return 1 ;;
  esac
  local tmp; tmp="$(mktemp)"
  if jq --arg url "$2" "$expr" "$3" > "$tmp" 2>/dev/null; then mv -f "$tmp" "$3"; else rm -f "$tmp"; return 1; fi
}

local_entry_url() { # $1 harness $2 file -> url or empty
  case "$1" in
    codex)              toml_block_url "mcp_servers.figma-local" "$2" ;;
    zcode|vscode)       jq -r '.mcp.servers["figma-local"].url // empty' "$2" 2>/dev/null || true ;;
    windsurf)           jq -r '.mcpServers["figma-local"].serverUrl // empty' "$2" 2>/dev/null || true ;;
    gemini)             jq -r '.mcpServers["figma-local"].httpUrl // empty' "$2" 2>/dev/null || true ;;
    *)                  jq -r '.mcpServers["figma-local"].url // empty' "$2" 2>/dev/null || true ;;
  esac
}

json_remote_present() { # $1 harness $2 file
  case "$1" in
    zcode|vscode) jq -e '.mcp.servers | has("figma")' "$2" > /dev/null 2>&1 ;;
    *)            jq -e '.mcpServers | has("figma")' "$2" > /dev/null 2>&1 ;;
  esac
}

json_remote_enabled() { # $1 harness $2 file -> "true"/"false"
  if ! remote_flag_harness "$1"; then echo "true"; return 0; fi
  local v
  case "$1" in
    zcode) v=$(jq -r '.mcp.servers.figma.enabled | if . == null then "true" else tostring end' "$2" 2>/dev/null || echo "true") ;;
    *)     v=$(jq -r '.mcpServers.figma.enabled | if . == null then "true" else tostring end' "$2" 2>/dev/null || echo "true") ;;
  esac
  echo "$v"
}

json_set_remote_auth() { # $1 harness $2 bearer-token $3 region(""=none) $4 file
  local hdrs='{"Authorization":$auth}'
  [ -n "$3" ] && hdrs='{"Authorization":$auth,"X-Figma-Region":$region}'
  local expr tmp; tmp="$(mktemp)"
  case "$1" in
    zcode)   expr=".mcp.servers.figma = ((.mcp.servers.figma // {\"type\":\"http\",\"url\":\$rurl}) | .headers = $hdrs | .enabled = true)" ;;
    vscode)  expr=".mcp.servers.figma = ((.mcp.servers.figma // {\"type\":\"http\",\"url\":\$rurl}) | .headers = $hdrs)" ;;
    claude|generic|cursor)
             expr=".mcpServers.figma = ((.mcpServers.figma // {\"type\":\"http\",\"url\":\$rurl}) | .headers = $hdrs | .enabled = true)" ;;
    windsurf) expr=".mcpServers.figma = ((.mcpServers.figma // {\"serverUrl\":\$rurl}) | .headers = $hdrs)" ;;
    gemini)  expr=".mcpServers.figma = ((.mcpServers.figma // {\"httpUrl\":\$rurl}) | .headers = $hdrs)" ;;
    *) rm -f "$tmp"; return 1 ;;
  esac
  if jq --arg rurl "$REMOTE_URL" --arg auth "Bearer $2" --arg region "$3" "$expr" "$4" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$4"
  else rm -f "$tmp"; return 1; fi
}

json_set_remote_enabled() { # $1 harness $2 true|false $3 file
  local expr tmp; tmp="$(mktemp)"
  case "$1" in
    zcode)                 expr=".mcp.servers.figma.enabled = $2" ;;
    claude|cursor|generic) expr=".mcpServers.figma.enabled = $2" ;;
    vscode)                expr="del(.mcp.servers.figma)" ;;
    windsurf|gemini)       expr="del(.mcpServers.figma)" ;;
    *) return 1 ;;
  esac
  if jq "$expr" "$3" > "$tmp" 2>/dev/null; then mv -f "$tmp" "$3"; else rm -f "$tmp"; return 1; fi
}

json_remote_auth_header() { # $1 harness $2 file -> "Bearer xxx" or empty
  case "$1" in
    zcode|vscode) jq -r '.mcp.servers.figma.headers.Authorization // empty' "$2" 2>/dev/null || true ;;
    *)            jq -r '.mcpServers.figma.headers.Authorization // empty' "$2" 2>/dev/null || true ;;
  esac
}

json_remote_region() { # $1 harness $2 file -> region or empty
  case "$1" in
    zcode|vscode) jq -r '.mcp.servers.figma.headers["X-Figma-Region"] // empty' "$2" 2>/dev/null || true ;;
    *)            jq -r '.mcpServers.figma.headers["X-Figma-Region"] // empty' "$2" 2>/dev/null || true ;;
  esac
}

# --- TOML (Codex) helpers -------------------------------------------------------
toml_remove_block() { # $1 block-name $2 file -> stdout
  awk -v hdr="[$1]" '
    $0 == hdr { skip = 1; next }
    skip && /^\[/ { skip = 0 }
    !skip { print }
  ' "$2"
}

toml_upsert() { # $1 file $2 block-name $3... key=value lines
  local file="$1" block="$2"; shift 2
  local tmp; tmp="$(mktemp)"
  toml_remove_block "$block" "$file" > "$tmp"
  printf '\n[%s]\n' "$block" >> "$tmp"
  local kv; for kv in "$@"; do printf '%s\n' "$kv" >> "$tmp"; done
  mv -f "$tmp" "$file"
}

toml_block_url() { # $1 block-name $2 file -> url or empty
  awk -v hdr="[$1]" '
    $0 == hdr { inblk = 1; next }
    inblk && /^\[/ { inblk = 0 }
    inblk && $1 == "url" { gsub(/"/, "", $3); print $3; exit }
  ' "$2" 2>/dev/null
}

toml_block_has() { # $1 block-name $2 file
  grep -q "^\[$1\]" "$2" 2>/dev/null
}

codex_set_local() { toml_upsert "$2" "mcp_servers.figma-local" "url = \"$1\""; }
codex_set_remote_auth() { # $1 token $2 region $3 file
  local lines=( "url = \"$REMOTE_URL\"" "http_headers = { \"Authorization\" = \"Bearer $1\" }" )
  [ -n "$2" ] && lines+=( "http_headers = { \"Authorization\" = \"Bearer $1\", \"X-Figma-Region\" = \"$2\" }" )
  toml_upsert "$3" "mcp_servers.figma" "${lines[@]}"
}
codex_remote_off() { # $1 file — Codex has no portable disabled flag; remove the block
  local tmp; tmp="$(mktemp)"
  toml_remove_block "mcp_servers.figma" "$1" > "$tmp"
  mv -f "$tmp" "$1"
}

# --- harness-facade ops ---------------------------------------------------------
set_local_entry() { # $1 harness $2 url $3 file
  case "$1" in
    codex) codex_set_local "$2" "$3" ;;
    *)     json_set_local "$1" "$2" "$3" ;;
  esac
}
set_remote_auth() { # $1 harness $2 token $3 region $4 file
  case "$1" in
    codex) codex_set_remote_auth "$2" "$3" "$4" ;;
    *)     json_set_remote_auth "$1" "$2" "$3" "$4" ;;
  esac
}
remote_off() { # $1 harness $2 file
  case "$1" in
    codex)    codex_remote_off "$2" ;;
    zcode|claude|cursor|generic) json_set_remote_enabled "$1" "false" "$2" ;;
    vscode|windsurf|gemini)      json_set_remote_enabled "$1" "false" "$2" ;;
  esac
}

ensure_config_exists() { # $1 harness $2 file
  [ -f "$2" ] && return 0
  mkdir -p "$(dirname "$2")" 2>/dev/null
  case "$1" in
    codex) printf '' > "$2" ;;
    zcode|vscode) echo '{"mcp":{"servers":{}}}' > "$2" ;;
    *)     echo '{"mcpServers":{}}' > "$2" ;;
  esac
}

# --- doctor ---------------------------------------------------------------------
check_harness_wiring() { # $1 harness $2 live_url -> rc 0 wired / 1 not
  local h="$1" url="$2" path cfg_url
  path="$(harness_config_path "$h")"
  if [ ! -f "$path" ]; then
    warn "[$h] no config at ${path}"
    info "Run: figma-wire use <port> --harness $h"
    return 1
  fi
  cfg_url="$(local_entry_url "$h" "$path")"
  if [ -n "$cfg_url" ] && [ "$cfg_url" = "$url" ]; then
    ok "[$h] wired: figma-local -> ${cfg_url}  (${path})"
    info "[$h] MCP tools missing in this session? Restart it — configs load at startup"
    return 0
  elif [ -n "$cfg_url" ]; then
    warn "[$h] figma-local points at ${cfg_url}, but the live server is ${url}"
    info "Run: figma-wire use ${url} --harness $h"
    return 1
  else
    warn "[$h] config has no figma-local entry (${path})"
    info "Run: figma-wire use <port> --harness $h"
    return 1
  fi
}

cmd_doctor() {
  need_deps || return 1
  local json_out=0 do_fix=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json_out=1 ;;
      --fix)  do_fix=1 ;;
      *) bad "unknown doctor flag: $1"; return 1 ;;
    esac
    shift
  done

  local rc=0 port url port_ok=0 found_port="" app_running
  app_running="$(figma_app_running && echo true || echo false)"

  port="$(resolve_port)"
  url="$(local_url_for "$port")"
  probe "$url"
  if [ "$PROBE_CODE" = "200" ] && is_devmode_body; then
    port_ok=1
  else
    # port watcher: maybe the server moved — scan for it
    found_port="$(find_local_port 2>/dev/null || true)"
    if [ -n "$found_port" ]; then
      port="$found_port"; url="$(local_url_for "$port")"; port_ok=1
      state_set ".localPort = ${port}"; state_set ".localUrl = \"${url}\""
      if [ $json_out -eq 0 ]; then
        warn "Dev Mode server found on a new port: ${port} (state updated)"
      fi
    fi
  fi

  # wiring per harness
  local target h
  target="$(detect_harness)"
  if [ "$target" = "all" ]; then
    for h in $(all_harnesses); do
      [ -f "$(harness_config_path "$h")" ] || continue
      if [ $json_out -eq 1 ]; then
        check_harness_wiring "$h" "$url" > /dev/null 2>&1 || rc=1
      else
        check_harness_wiring "$h" "$url" || rc=1
      fi
    done
  else
    if [ $json_out -eq 1 ]; then
      check_harness_wiring "$target" "$url" > /dev/null 2>&1 || rc=1
    else
      check_harness_wiring "$target" "$url" || rc=1
    fi
  fi

  # remote check (single-harness mode only)
  local path present="false" enabled="false" remote_code="000"
  path="$(harness_config_path "$target")"
  if [ "$target" != "all" ] && [ -f "$path" ]; then
    case "$target" in
      codex) if toml_block_has "mcp_servers.figma" "$path"; then present="true"; enabled="true"; fi ;;
      *)     json_remote_present "$target" "$path" && present="true"
             enabled="$(json_remote_enabled "$target" "$path")" ;;
    esac
    probe "$REMOTE_URL"; remote_code="$PROBE_CODE"
    if [ $json_out -eq 0 ]; then
      if [ "$PROBE_CODE" = "200" ]; then
        ok "Remote MCP (mcp.figma.com) reachable and authenticated"
      elif [ "$PROBE_CODE" = "401" ]; then
        if [ "$present" = "true" ] && [ "$enabled" != "false" ]; then
          warn "Remote MCP reachable but unauthenticated — it fails every session (HTTP 401)"
          info "No token? Run: figma-wire remote off    |    Have a token? Run: figma-wire remote token <TOKEN>"
        else
          ok "Remote MCP reachable, disabled (correct until a token is configured)"
        fi
      else
        warn "Remote MCP probe: HTTP ${PROBE_CODE} (offline or proxy issue — harmless for the local path)"
      fi
    fi
  fi

  if [ $json_out -eq 1 ]; then
    local wired_val="false"; [ $rc -eq 0 ] && wired_val="true"
    local ok_val="false"; [ $port_ok -eq 1 ] && ok_val="true"
    jq -n \
      --arg version "$VERSION" --arg harness "$target" \
      --arg port "$port" --arg url "$url" --arg localOk "$ok_val" \
      --arg wired "$wired_val" --arg configPath "$path" \
      --arg present "$present" --arg enabled "$enabled" --arg remoteCode "$remote_code" \
      --arg app "$app_running" \
      '{version:$version, harness:$harness, app:($app=="true"),
        local:{port:($port|tonumber), url:$url, ok:($localOk=="true")},
        wired:($wired=="true"), configPath:$configPath,
        remote:{present:($present=="true"), enabled:($enabled=="true"), lastHttpCode:$remoteCode},
        ok:($wired=="true" and ($localOk=="true"))}'
    return $rc
  fi

  # --fix: auto-apply wiring once a live server is confirmed
  local cfg_url
  if [ $do_fix -eq 1 ] && [ $port_ok -eq 1 ]; then
    if [ "$target" = "all" ]; then
      for h in $(all_harnesses); do
        [ -f "$(harness_config_path "$h")" ] || continue
        cfg_url="$(local_entry_url "$h" "$(harness_config_path "$h")")"
        [ "$cfg_url" = "$url" ] || { set_local_entry "$h" "$url" "$(harness_config_path "$h")" && ok "[$h] fixed: figma-local -> ${url}"; }
      done
    else
      cfg_url="$(local_entry_url "$target" "$path")"
      if [ "$cfg_url" != "$url" ]; then
        ensure_config_exists "$target" "$path"
        set_local_entry "$target" "$url" "$path" && ok "[${target}] fixed: figma-local -> ${url}"
      fi
    fi
    # re-verify quietly
    rc=0
    if [ "$target" = "all" ]; then
      for h in $(all_harnesses); do
        [ -f "$(harness_config_path "$h")" ] || continue
        [ "$(local_entry_url "$h" "$(harness_config_path "$h")")" = "$url" ] || rc=1
      done
    else
      [ "$(local_entry_url "$target" "$path")" = "$url" ] || rc=1
    fi
  fi

  echo "== done =="
  if [ $rc -eq 0 ]; then
    ok "All good — the local path needs no auth; use the Figma MCP tools (get_design_context first)"
  else
    bad "Issues found — follow the [fix] lines above (or re-run with --fix to auto-wire)"
  fi
  return $rc
}

# --- use <port|url> ---------------------------------------------------------------
cmd_use() {
  need_deps || return 1
  local arg="$1" url port
  if [[ "$arg" =~ ^[0-9]+$ ]]; then
    url="$(local_url_for "$arg")"
  else
    url="$arg"
  fi

  probe "$url"
  if [ "$PROBE_CODE" = "200" ] && is_devmode_body; then
    ok "Dev Mode MCP Server confirmed at ${url}"
  else
    bad "No Dev Mode MCP server at ${url} (HTTP ${PROBE_CODE}) — nothing written"
    return 1
  fi

  if [[ "$url" =~ :([0-9]+)/mcp$ ]]; then port="${BASH_REMATCH[1]}"; else port=""; fi

  local target h wrote_any=0
  target="$(detect_harness)"
  if [ "$target" = "all" ]; then
    local found_existing=0
    for h in $(all_harnesses); do
      if [ -f "$(harness_config_path "$h")" ]; then
        set_local_entry "$h" "$url" "$(harness_config_path "$h")" && { ok "[$h] wired -> ${url}"; wrote_any=1; }
        found_existing=1
      fi
    done
    if [ $found_existing -eq 0 ]; then
      h="generic"
      ensure_config_exists "$h" "$(harness_config_path "$h")"
      set_local_entry "$h" "$url" "$(harness_config_path "$h")" && { ok "[$h] wired -> ${url} (created config)"; wrote_any=1; }
    fi
  else
    h="$target"
    ensure_config_exists "$h" "$(harness_config_path "$h")"
    if set_local_entry "$h" "$url" "$(harness_config_path "$h")"; then
      ok "[${h}] wired figma-local -> ${url}  ($(harness_config_path "$h"))"
      wrote_any=1
    else
      bad "Failed to update $(harness_config_path "$h") — is it valid JSON/TOML? (JSONC comments are not editable by jq)"
      return 1
    fi
  fi
  [ $wrote_any -eq 1 ] || { bad "Nothing was written"; return 1; }

  [ -n "$port" ] && state_set ".localPort = ${port}"
  state_set ".localUrl = \"${url}\""
  info "Restart the session (or open a new one); Figma MCP tools appear under the harness's tool prefix"
}

# --- link <share-url|fileKey> -------------------------------------------------------
cmd_link() {
  local arg="$1" filekey="" kind="" nid_dash=""

  if [[ "$arg" =~ ^[A-Za-z0-9]{22}$ ]]; then
    filekey="$arg"
  else
    kind=$(sed -E 's#https?://[^/]+/([a-zA-Z]+)/.*#\1#' <<<"$arg")
    case "$kind" in
      design|file|proto|figjam|slides|deck) ;;
      *) kind="design" ;;
    esac
    # Figma URL shape: /<kind>/<fileKey>/<name-slug>?node-id=... — the fileKey is the
    # first segment after the kind; the name slug may contain hyphens, the key is alnum.
    filekey=$(sed -E 's#.*(design|file|proto|figjam|slides|deck)/([A-Za-z0-9]+).*#\2#' <<<"$arg")
    [[ "$filekey" =~ ^[A-Za-z0-9]{16,}$ ]] || filekey=""
    nid_dash=$(sed -E 's#.*[?&]node-id=([0-9]+-[0-9]+).*#\1#' <<<"$arg")
    [[ "$nid_dash" =~ ^[0-9]+-[0-9]+$ ]] || nid_dash=""
  fi

  if [ -z "$filekey" ]; then
    bad "Could not parse a fileKey from: ${arg}"
    info "Expected a figma.com design/file/proto link, or a bare 22-char fileKey"
    return 1
  fi

  local nid_colon=""
  if [ -n "$nid_dash" ]; then nid_colon="${nid_dash/-/:}"; fi

  echo "fileKey : ${filekey}"
  echo "kind    : ${kind}"
  if [ -n "$nid_dash" ]; then
    echo "nodeId  : ${nid_colon}   (dash form: ${nid_dash})"
  else
    echo "nodeId  : (none in link — tools will use the current selection in Figma desktop)"
  fi

  state_set ".lastLink.fileKey = \"${filekey}\""
  state_set ".lastLink.kind = \"${kind}\""
  [ -n "$nid_dash" ] && state_set ".lastLink.nodeIdDash = \"${nid_dash}\""
  [ -n "$nid_colon" ] && state_set ".lastLink.nodeIdColon = \"${nid_colon}\""

  echo
  info "Open that file as the active tab in Figma desktop, then call the local MCP get_design_context with nodeId \"${nid_colon:-<selection>}\" (dash-form fallback: ${nid_dash:-n/a})"
  info "No MCP tools in this session? Run: figma-wire doctor"
  info "Want a screenshot/code without MCP tools? Run: figma-wire call get_screenshot ${nid_colon:+\"$nid_colon\"}"
  info "Need REST instead (headless/CI)? Run: figma-wire fetch"
}

# --- call <tool> [nodeId|JSON] -------------------------------------------------------
# Raw MCP tools/call passthrough: lets any agent pull design data with no MCP client.
cmd_call() {
  need_deps || return 1
  local tool="${1:-}"; [ -n "$tool" ] && shift
  if [ -z "$tool" ]; then
    bad "usage: figma-wire call <tool> [nodeId | '{\"nodeId\":\"1:2\",...}'] [-o prefix]"
    info "tools: get_design_context, get_metadata, get_screenshot, get_variable_defs, get_motion_context, get_figjam"
    return 1
  fi

  local out_prefix="" args_json=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -o)      out_prefix="${2:-}"; shift 2 || true ;;
      -o=*)    out_prefix="${1#-o=}"; shift ;;
      -*)      bad "unknown call flag: $1"; return 1 ;;
      *)       if [ -z "$args_json" ]; then
                 if [[ "$1" =~ ^\{ ]]; then args_json="$1"
                 elif [[ "$1" =~ ^[0-9]+[:\-][0-9]+$ ]]; then
                   local nid="$1"; args_json="{\"nodeId\":\"${nid/-/:}\"}"
                 else args_json="{\"nodeId\":\"$1\"}"; fi
               else bad "extra positional arg: $1 (nodeId or one JSON object)"; return 1; fi
               shift ;;
    esac
  done
  [ -n "$args_json" ] || args_json='{}'

  # resolve a live local server
  local port url
  port="$(resolve_port)"
  url="$(local_url_for "$port")"
  probe "$url"
  if ! { [ "$PROBE_CODE" = "200" ] && is_devmode_body; }; then
    port="$(find_local_port 2>/dev/null || true)"
    if [ -n "$port" ]; then url="$(local_url_for "$port")"; else
      bad "No local Dev Mode server found — start Figma desktop and enable Dev Mode MCP Server"
      return 1
    fi
  fi

  # full MCP handshake: initialize -> initialized -> tools/call
  local hdr tf sess data_line
  hdr="$(mktemp)"; tf="$(mktemp)"
  curl -sS -D "$hdr" -o "$tf" --max-time 15 -X POST "$url" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -d "$INIT_BODY" 2>/dev/null || { bad "initialize failed"; rm -f "$hdr" "$tf"; return 1; }
  sess="$(grep -i '^mcp-session-id:' "$hdr" | tr -d '\r' | awk '{print $2}')"
  rm -f "$tf"
  if [ -z "$sess" ]; then bad "server returned no session id"; rm -f "$hdr"; return 1; fi

  curl -sS --max-time 15 -X POST "$url" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -H "mcp-session-id: $sess" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null 2>&1

  local call_body
  call_body=$(jq -n --arg tool "$tool" --argjson args "$args_json" \
    '{jsonrpc:"2.0", id:3, method:"tools/call", params:{name:$tool, arguments:$args}}')
  curl -sS --max-time 90 -X POST "$url" \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -H "mcp-session-id: $sess" -d "$call_body" > "$tf" 2>/dev/null || { bad "tools/call request failed"; rm -f "$hdr" "$tf"; return 1; }
  rm -f "$hdr"

  data_line=$(grep '^data:' "$tf" | tail -1 | sed 's/^data: //')
  rm -f "$tf"
  if [ -z "$data_line" ]; then bad "no response body from tools/call"; return 1; fi

  if jq -e '.error' <<<"$data_line" > /dev/null 2>&1; then
    bad "MCP error: $(jq -c '.error' <<<"$data_line")"
    return 1
  fi

  local prefix="${out_prefix:-figma-${tool}}"
  local img_n=0 saved="" is_err
  is_err=$(jq -r '.result.isError // "false"' <<<"$data_line" 2>/dev/null)

  while IFS= read -r item; do
    [ -n "$item" ] || continue
    local itype itext
    itype=$(jq -r '.type // empty' <<<"$item" 2>/dev/null)
    case "$itype" in
      text)
        itext=$(jq -r '.text // empty' <<<"$item" 2>/dev/null)
        if [ -n "$out_prefix" ]; then
          printf '%s\n' "$itext" >> "${prefix}.txt"; saved="$saved ${prefix}.txt"
        else
          printf '%s\n' "$itext"
        fi
        ;;
      image)
        img_n=$((img_n+1))
        local mime ext imgfile
        mime=$(jq -r '.mimeType // "image/png"' <<<"$item")
        ext="${mime##*/}"; [ "$ext" = "jpeg" ] && ext="jpg"
        imgfile="${prefix}-${img_n}.${ext}"
        jq -r '.data // empty' <<<"$item" | b64decode > "$imgfile" 2>/dev/null
        saved="$saved ${imgfile}"
        ;;
      resource)
        itext=$(jq -r '.text // .uri // empty' <<<"$item" 2>/dev/null)
        if [ -n "$out_prefix" ]; then printf '%s\n' "$itext" >> "${prefix}.txt"; saved="$saved ${prefix}.txt"
        else printf '%s\n' "$itext"; fi
        ;;
    esac
  done < <(jq -c '.result.content[]?' <<<"$data_line" 2>/dev/null)

  if [ -n "$saved" ]; then
    ok "saved:$saved"
  elif [ -z "$out_prefix" ] && [ "$img_n" -eq 0 ]; then
    # no content array (unexpected shape) — dump the raw result so nothing is lost
    jq '.result // .' <<<"$data_line"
  fi

  [ "$is_err" = "true" ] && { bad "tool reported an error (see output above)"; return 1; }
  return 0
}

# --- diff <nodeId> <url> ---------------------------------------------------------------
# Screenshot a Figma node, screenshot the implemented page, pixel-diff them.
cmd_diff() {
  need_deps || return 1
  local node_id="" url="" prefix="" viewport="1440x900" full_page=0 wait_ms=2500 threshold=5 resize=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --out) prefix="${2:-}"; shift 2 || true ;;
      --out=*) prefix="${1#--out=}"; shift ;;
      --viewport) viewport="${2:-}"; shift 2 || true ;;
      --viewport=*) viewport="${1#--viewport=}"; shift ;;
      --full-page) full_page=1; shift ;;
      --wait) wait_ms="${2:-}"; shift 2 || true ;;
      --wait=*) wait_ms="${1#--wait=}"; shift ;;
      --threshold) threshold="${2:-}"; shift 2 || true ;;
      --threshold=*) threshold="${1#--threshold=}"; shift ;;
      --resize) resize=1; shift ;;
      *) if [ -z "$node_id" ]; then node_id="$1"
         elif [ -z "$url" ]; then url="$1"
         else bad "unexpected arg: $1"; return 1; fi
         shift ;;
    esac
  done
  if [ -z "$node_id" ] || [ -z "$url" ]; then
    bad "usage: figma-wire diff <nodeId> <url> [--viewport WxH] [--out prefix] [--threshold N] [--full-page] [--resize]"
    return 1
  fi
  command -v compare > /dev/null 2>&1 || { bad "ImageMagick 'compare' not found — install it (brew install imagemagick) for pixel diffing"; return 1; }

  [ -n "$prefix" ] || prefix="figma-diff-$(date +%Y%m%d-%H%M%S)"

  ok "1/4 screenshotting Figma node ${node_id} ..."
  cmd_call get_screenshot "$node_id" -o "${prefix}-figma" || return 1
  local figma_png="${prefix}-figma-1.png"
  [ -f "$figma_png" ] || { bad "Figma screenshot not found at ${figma_png}"; return 1; }

  ok "2/4 screenshotting ${url} ..."
  local page_png="${prefix}-page.png"
  local vp="${viewport/x/,}"
  local pw_args=(screenshot --viewport-size="$vp" --wait-for-timeout="$wait_ms")
  [ $full_page -eq 1 ] && pw_args+=(--full-page)
  pw_args+=("$url" "$page_png")
  if command -v playwright > /dev/null 2>&1; then
    playwright "${pw_args[@]}"
  else
    npx -y playwright "${pw_args[@]}"
  fi || { bad "page screenshot failed — if browsers are missing run: npx playwright install chromium"; return 1; }

  local fw fh pw ph
  read -r fw fh <<< "$(magick identify -format '%w %h' "$figma_png")"
  read -r pw ph <<< "$(magick identify -format '%w %h' "$page_png")"
  if [ "$fw" != "$pw" ] || [ "$fh" != "$ph" ]; then
    warn "size mismatch: Figma ${fw}x${fh} vs page ${pw}x${ph}"
    if [ $resize -eq 1 ]; then
      magick "$page_png" -resize "${fw}x${fh}!" "$page_png"
      ok "forced page screenshot to ${fw}x${fh}"
    else
      info "rerun with --viewport ${fw}x${fh} to match the design frame (or --resize to force-fit)"
      return 2
    fi
  fi

  ok "3/4 pixel diffing ..."
  local diff_png="${prefix}-diff.png" ae
  ae=$(compare -metric AE "$figma_png" "$page_png" "$diff_png" 2>&1 > /dev/null || true)
  ae="${ae%%[$'\r\n']*}"
  ae="${ae%% *}"

  ok "4/4 composing side-by-side ..."
  local side="${prefix}-side.png"
  magick "$figma_png" "$page_png" "$diff_png" +append "$side" 2> /dev/null || true

  local total=$(( fw * fh ))
  local pct
  pct=$(awk -v ae="${ae:-0}" -v t="$total" 'BEGIN { if (t > 0) printf "%.2f", (ae / t) * 100; else print "100.00" }')

  echo
  echo "figma : ${figma_png}  (${fw}x${fh})"
  echo "page  : ${page_png}"
  echo "diff  : ${diff_png}"
  [ -f "$side" ] && echo "side  : ${side}"
  echo "mismatched pixels: ${ae:-0}/${total} (${pct}%)"

  if awk -v p="$pct" -v th="$threshold" 'BEGIN { exit ! (p + 0 <= th + 0) }'; then
    ok "PASS — ${pct}% mismatched, within the ${threshold}% threshold"
    return 0
  else
    bad "FAIL — ${pct}% mismatched, exceeds the ${threshold}% threshold"
    return 1
  fi
}

# --- remote token <TOKEN> | remote off ------------------------------------------------
cmd_remote() {
  need_deps || return 1
  local sub="${1:-}"; shift || true
  case "$sub" in
    token)
      local tok="" region=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --region)  region="${2:-}"; shift 2 || true ;;
          --region=*) region="${1#--region=}"; shift ;;
          *) if [ -z "$tok" ]; then tok="$1"; else bad "unexpected arg: $1"; return 1; fi; shift ;;
        esac
      done
      if [ -z "$tok" ]; then bad "usage: figma-wire remote token <TOKEN> [--region us-east-1]"; return 1; fi
      local extra=()
      [ -n "$region" ] && extra=(-H "X-Figma-Region: ${region}")
      probe "$REMOTE_URL" -H "Authorization: Bearer ${tok}" "${extra[@]+"${extra[@]}"}"
      if [[ "$PROBE_CODE" == 2* ]]; then
        local target h
        target="$(detect_harness)"
        if [ "$target" = "all" ]; then
          for h in $(all_harnesses); do
            [ -f "$(harness_config_path "$h")" ] || continue
            set_remote_auth "$h" "$tok" "$region" "$(harness_config_path "$h")" && ok "[${h}] remote enabled with token"
          done
        else
          ensure_config_exists "$target" "$(harness_config_path "$target")"
          if set_remote_auth "$target" "$tok" "$region" "$(harness_config_path "$target")"; then
            ok "[${target}] remote MCP authenticated and enabled ($(harness_config_path "$target"))"
          else
            bad "Failed to update config"; return 1
          fi
        fi
        [ -n "$region" ] && state_set ".remoteRegion = \"${region}\""
        info "Restart the session; remote tools appear under the harness's figma server prefix"
      else
        bad "Remote rejected the token (HTTP ${PROBE_CODE}) — nothing written"
        return 1
      fi
      ;;
    off)
      local target h
      target="$(detect_harness)"
      if [ "$target" = "all" ]; then
        for h in $(all_harnesses); do
          [ -f "$(harness_config_path "$h")" ] || continue
          remote_off "$h" "$(harness_config_path "$h")" && ok "[${h}] remote figma server disabled"
        done
      else
        local path; path="$(harness_config_path "$target")"
        if [ -f "$path" ]; then
          remote_off "$target" "$path" && ok "[${target}] remote figma server disabled — no more per-session 401s"
          info "Got a token later? Run: figma-wire remote token <TOKEN>"
        else
          info "No config at ${path} — nothing to do"
        fi
      fi
      ;;
    *)
      bad "usage: figma-wire remote token <TOKEN> [--region us-east-1] | figma-wire remote off"
      return 1
      ;;
  esac
}

# --- fetch [fileKey] [nodeId] -----------------------------------------------------------
cmd_fetch() {
  need_deps || return 1
  local fk="${1:-}" nid="${2:-}"
  [ -n "$fk" ] || fk="$(state_get '.lastLink.fileKey')"
  [ -n "$nid" ] || nid="$(state_get '.lastLink.nodeIdColon')"
  if [ -z "$fk" ]; then
    bad "No fileKey given and none stored — run: figma-wire link <url>"
    return 1
  fi

  local tok="${FIGMA_TOKEN:-}"
  if [ -z "$tok" ]; then
    local target; target="$(detect_harness)"
    local path; path="$(harness_config_path "$target")"
    if [ -f "$path" ]; then
      if [ "$target" = "codex" ]; then
        tok=$(awk '/^\[mcp_servers\.figma\]/{inblk=1;next} inblk&&/^\[/{inblk=0} inblk&&/Authorization/{
          if (match($0, /Bearer[[:space:]]+"([^"]+)"/, m)) { print m[1]; exit }
          else if (match($0, /"([^"]+)"/, m)) { print m[1]; exit }
        }' "$path" 2>/dev/null | sed -E 's/^Bearer +//')
      else
        tok=$(json_remote_auth_header "$target" "$path" | sed -E 's/^Bearer +//')
      fi
    fi
  fi
  if [ -z "$tok" ]; then
    bad "No token. Set FIGMA_TOKEN or run: figma-wire remote token <TOKEN>"
    info "No token at all? The local Dev Mode MCP needs none — prefer that path (see: figma-wire call)"
    return 1
  fi

  local qs="" out
  if [ -n "$nid" ]; then qs="?ids=${nid/-/:}"; fi
  out="figma-${fk}$( [ -n "$nid" ] && echo "-$(echo "$nid" | tr ':' '-')" ).json"

  if curl -sS --max-time 30 -H "X-Figma-Token: ${tok}" \
       "https://api.figma.com/v1/files/${fk}/nodes${qs}" -o "$out"; then
    ok "Wrote ${out}"
    info "If it contains a 403/404 ERR, the token lacks access to this file"
  else
    rm -f "$out"
    bad "REST fetch failed"
    return 1
  fi
}

# --- status / config / version -----------------------------------------------------------
cmd_status() {
  need_deps || return 1
  local port url target present="false" enabled="false"
  port="$(resolve_port)"
  url="$(local_url_for "$port")"
  target="$(detect_harness)"
  local path; path="$(harness_config_path "$target")"
  if [ -f "$path" ]; then
    case "$target" in
      codex) toml_block_has "mcp_servers.figma" "$path" && present="true" && enabled="true" ;;
      *)     json_remote_present "$target" "$path" && present="true"
             enabled="$(json_remote_enabled "$target" "$path")" ;;
    esac
  fi
  probe "$url"
  local local_ok="false"; [ "$PROBE_CODE" = "200" ] && local_ok="true"
  probe "$REMOTE_URL"
  local wired="false"
  [ "$(local_entry_url "$target" "$path" 2>/dev/null)" = "$url" ] && wired="true"
  jq -n \
    --arg version "$VERSION" --arg harness "$target" \
    --arg port "$port" --arg url "$url" --arg localOk "$local_ok" \
    --arg remoteCode "$PROBE_CODE" \
    --arg configPath "$path" --arg wired "$wired" \
    --arg present "$present" --arg enabled "$enabled" \
    --arg region "$(state_get '.remoteRegion')" \
    --arg app "$(figma_app_running && echo true || echo false)" \
    '{version: $version, harness: $harness, app: ($app == "true"),
      local: {port: ($port | tonumber), url: $url, ok: ($localOk == "true")},
      wired: ($wired == "true"), configPath: $configPath,
      remote: {present: ($present == "true"), enabled: ($enabled == "true"), region: $region, lastHttpCode: $remoteCode}}'
}

cmd_config() {
  local target; target="$(detect_harness)"
  echo "version     : ${VERSION}"
  echo "harness     : ${target} (override: --harness <name> or FIGMA_WIRE_HARNESS)"
  echo "config path : $(harness_config_path "$target")"
  echo "state file  : ${STATE_FILE}"
  echo "default port: ${DEFAULT_PORT} (override: FIGMA_WIRE_PORT)"
  echo "scan ports  : ${FIGMA_WIRE_SCAN_PORTS:-3845-3854}"
  echo "remote url  : ${REMOTE_URL}"
  echo "skill dir   : ${SKILL_DIR}"
}

cmd_version() { echo "figma-wire ${VERSION}"; }

# --- install-skill: register the skill into ~/.agents/skills (npm-install path) ------
cmd_install_skill() {
  local dest="$HOME/.agents/skills/figma-wire"
  [ -f "$SKILL_DIR/SKILL.md" ] || { bad "SKILL.md not found next to the script (${SKILL_DIR})"; return 1; }
  mkdir -p "$dest/scripts" "$dest/references" || { bad "cannot create ${dest}"; return 1; }
  cp -f "$SKILL_DIR/SKILL.md" "$dest/SKILL.md"
  [ -f "$SKILL_DIR/README.md" ] && cp -f "$SKILL_DIR/README.md" "$dest/README.md"
  [ -f "$SKILL_DIR/LICENSE" ] && cp -f "$SKILL_DIR/LICENSE" "$dest/LICENSE"
  cp -f "$SKILL_DIR/scripts/figma-wire.sh" "$dest/scripts/"
  [ -f "$SKILL_DIR/references/devmode-tools.md" ] && cp -f "$SKILL_DIR/references/devmode-tools.md" "$dest/references/"
  chmod +x "$dest/scripts/figma-wire.sh" 2>/dev/null
  ok "skill registered at ${dest}"
  info "Restart your agent session so it discovers the new skill"
}

# --- usage / main ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
figma-wire — wire AI coding agents to Figma
(ZCode, Claude Code, Codex, Cursor, Windsurf, VS Code, Gemini CLI, generic)

  doctor [--json] [--fix]   full status + exact fixes; --json machine-readable;
                            --fix auto-wires a moved/missing figma-local entry
  use <port|url>            probe a local Dev Mode MCP server and wire it into config
  link <share-url|fileKey>  parse a Figma link -> fileKey + nodeId
  call <tool> [nodeId|JSON] raw MCP tools/call with no MCP client needed
                            tools: get_design_context, get_metadata, get_screenshot,
                            get_variable_defs, get_motion_context, get_figjam
  diff <nodeId> <url>       screenshot Figma node vs implemented page, pixel-diff
                            [--viewport WxH] [--threshold N] [--full-page]
                            [--wait MS] [--resize] [--out prefix]
  remote token <TOKEN>      authenticate + enable the remote mcp.figma.com server
      [--region R]          add an X-Figma-Region header (e.g. us-east-1)
  remote off                disable the remote server (stops per-session 401s)
  fetch [fileKey] [nodeId]  REST fallback via api.figma.com (needs a token)
  status                    one-line JSON summary (agent-friendly)
  config                    show effective settings
  version                   print version

Global flag: --harness <zcode|claude|codex|cursor|windsurf|vscode|gemini|generic|all>
Env: FIGMA_WIRE_HARNESS, FIGMA_WIRE_CONFIG, FIGMA_WIRE_STATE, FIGMA_WIRE_PORT,
     FIGMA_WIRE_SCAN_PORTS, FIGMA_TOKEN
EOF
}

main() {
  local args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --harness=*) HARNESS="${1#--harness=}"; shift ;;
      --harness)   HARNESS="${2:-}"; shift 2 || true ;;
      *)           args+=("$1"); shift ;;
    esac
  done
  set -- ${args[@]+"${args[@]}"}

  local cmd="${1:-doctor}"
  [ $# -gt 0 ] && shift

  case "$cmd" in
    doctor)         cmd_doctor "$@" ;;
    use)            [ $# -ge 1 ] || { bad "usage: figma-wire use <port|url>"; return 1; }; cmd_use "$1" ;;
    link)           [ $# -ge 1 ] || { bad "usage: figma-wire link <share-url|fileKey>"; return 1; }; cmd_link "$1" ;;
    call)           cmd_call "$@" ;;
    diff)           cmd_diff "$@" ;;
    remote)         cmd_remote "$@" ;;
    fetch)          cmd_fetch "$@" ;;
    status)         cmd_status ;;
    config)         cmd_config ;;
    install-skill)  cmd_install_skill ;;
    version|--version|-V) cmd_version ;;
    help|-h|--help) usage ;;
    *) bad "unknown command: ${cmd}"; usage; return 1 ;;
  esac
}

main "$@"

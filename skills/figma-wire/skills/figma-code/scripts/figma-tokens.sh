#!/usr/bin/env bash
# Export flat Figma variables; reject unresolved aliases and CSS name collisions.
set -eu -o pipefail
umask 077
[ $# -eq 2 ] || { echo 'Usage: figma-wire tokens <variables.json> <new-prefix>' >&2; exit 1; }
SOURCE="$1"; PREFIX="$2"
for ext in css ts names.json; do
  [ ! -e "$PREFIX.$ext" ] || { echo 'Output exists. Choose a new prefix.' >&2; exit 1; }
done
mkdir -p "$(dirname "$PREFIX")"
WORK="$(mktemp -d "${PREFIX}.tmp.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# shortcut: only flat resolved values, use a mode-aware source adapter for nested variable collections.
jq -e '
  if has("content") then [.content[] | select(.type=="text") | .text | fromjson] | if length==1 then .[0] else error("one variable object required") end else . end
  | if type=="object" and length>0 and all(.[]; type=="string" or type=="number") then . else error("flat resolved variable object required") end
  | to_entries | map(. + {css:("--figma-" + (.key | ascii_downcase | gsub("[^a-z0-9-]";"-")))})
  | if ([.[].css] | unique | length) == length then . else error("CSS name collision") end
  | if all(.[]; (.value|tostring|test("[;{}\\r\\n]"))|not) then . else error("unsafe CSS value") end
' "$SOURCE" >"$WORK/entries.json"
{
  printf ':root {\n'
  jq -r '.[] | "  " + .css + ": " + (.value|tostring) + ";"' "$WORK/entries.json"
  printf '}\n'
} >"$WORK/tokens.css"
{
  printf 'export const figmaTokens = '
  jq 'map({key:.key,value:.value}) | from_entries' "$WORK/entries.json"
  printf ' as const;\nexport type FigmaTokenName = keyof typeof figmaTokens;\n'
} >"$WORK/tokens.ts"
jq 'map({key:.key,value:.css}) | from_entries' "$WORK/entries.json" >"$WORK/names.json"
mv "$WORK/tokens.css" "$PREFIX.css"
mv "$WORK/tokens.ts" "$PREFIX.ts"
mv "$WORK/names.json" "$PREFIX.names.json"
printf 'Tokens: %s.css %s.ts %s.names.json\n' "$PREFIX" "$PREFIX" "$PREFIX"

#!/usr/bin/env bash
set -euo pipefail
[ $# -eq 2 ] || { echo 'Usage: gen-tokens <vars.json> <outdir>' >&2; exit 1; }
src="$1"; out="$2"
mkdir -p "$out"
# Tailwind v3
jq -r 'to_entries | sort_by(.key) | "module.exports = { theme: { extend: { colors: {" + (map(.key + ": " + (.value|tojson)) | join(", ")) + "} } } };"' "$src" > "$out/tailwind.config.js"
# CSS vars light
{ echo ':root {'; jq -r 'to_entries | sort_by(.key)[] | "  --" + .key + ": " + (.value|tostring) + ";"' "$src"; echo '}'; } > "$out/tokens.css"
# TS
{ echo 'export const tokens = {'; jq -r 'to_entries | sort_by(.key)[] | "  " + .key + ": " + (.value|tojson) + ","' "$src"; echo '} as const;'; } > "$out/tokens.ts"
echo "generated"

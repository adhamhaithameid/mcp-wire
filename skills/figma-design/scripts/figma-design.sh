#!/usr/bin/env bash
# Collect a reviewable design packet without changing the host project.
set -eu -o pipefail
umask 077
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ $# -eq 2 ] || { echo 'Usage: figma-wire design <nodeId> <new-output-folder>' >&2; exit 1; }
NODE="$1"; DEST="$2"
[ ! -e "$DEST" ] || { echo 'Output already exists. Choose a new folder.' >&2; exit 1; }
mkdir -p "$(dirname "$DEST")"
WORK="$(mktemp -d "${DEST}.tmp.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
bash "$HERE/figma-wire.sh" tools --json >"$WORK/tools.json"
for tool in get_design_context get_screenshot; do
  jq -e --arg t "$tool" '.tools | any(.name==$t)' "$WORK/tools.json" >/dev/null || { echo "Required tool unavailable: $tool" >&2; exit 1; }
done
bash "$HERE/figma-wire.sh" call get_design_context "$NODE" --json >"$WORK/context.json"
bash "$HERE/figma-wire.sh" call get_screenshot "$NODE" -o "$WORK/reference" >/dev/null
[ -s "$WORK/reference-1.png" ] || { echo 'No PNG screenshot returned. Inspect the tool schema and image format.' >&2; exit 1; }
for tool in get_metadata get_variable_defs; do
  if jq -e --arg t "$tool" '.tools | any(.name==$t)' "$WORK/tools.json" >/dev/null; then
    bash "$HERE/figma-wire.sh" call "$tool" "$NODE" --json >"$WORK/${tool}.json"
  fi
done
jq -n --arg node "${NODE/-/:}" --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{nodeId:$node,collectedAt:$date,context:"context.json",reference:"reference-1.png",tools:"tools.json"}' >"$WORK/manifest.json"
mv "$WORK" "$DEST"
printf 'Design packet: %s\n' "$DEST"

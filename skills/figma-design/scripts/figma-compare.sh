#!/usr/bin/env bash
# Compare saved PNGs in CI without access to a desktop Figma session.
set -eu -o pipefail
[ $# -ge 2 ] || { echo 'Usage: figma-wire compare <reference.png> <actual.png> [--threshold N] [--out PREFIX] [--json]' >&2; exit 2; }
REFERENCE="$1"; ACTUAL="$2"; shift 2
THRESHOLD=5; PREFIX=figma-compare; JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --threshold|--out) [ $# -ge 2 ] || { echo 'Flag requires a value.' >&2; exit 2; }; if [ "$1" = --threshold ]; then THRESHOLD="$2"; else PREFIX="$2"; fi; shift 2 ;;
    --json) JSON=1; shift ;;
    *) echo 'Unknown comparison flag.' >&2; exit 2 ;;
  esac
done
[[ "$THRESHOLD" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v t="$THRESHOLD" 'BEGIN{exit !(t>=0 && t<=100)}' || { echo 'Threshold must be between 0 and 100.' >&2; exit 2; }
for dep in magick compare jq; do command -v "$dep" >/dev/null || { echo "Missing visual dependency: $dep" >&2; exit 2; }; done
[ -s "$REFERENCE" ] && [ -s "$ACTUAL" ] || { echo 'Both input images must exist.' >&2; exit 2; }
DIMS="$(magick identify -format '%w %h' "$REFERENCE")"
ACTUAL_DIMS="$(magick identify -format '%w %h' "$ACTUAL")"
[ "$DIMS" = "$ACTUAL_DIMS" ] || { echo 'Image dimensions differ. Capture the matching viewport.' >&2; exit 2; }
read -r WIDTH HEIGHT <<<"$DIMS"
[[ "$WIDTH" =~ ^[1-9][0-9]*$ && "$HEIGHT" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid image dimensions.' >&2; exit 2; }
mkdir -p "$(dirname "$PREFIX")"
RC=0
AE="$(compare -precision 17 -metric AE "$REFERENCE" "$ACTUAL" "$PREFIX-diff.png" 2>&1)" || RC=$?
[ "$RC" -le 1 ] || { echo 'Pixel comparison failed. Check image formats and ImageMagick.' >&2; exit 2; }
AE="${AE%%[$'\r\n']*}"; AE="${AE%% *}"
[[ "$AE" =~ ^[0-9]+([.][0-9]+)?([eE][+-]?[0-9]+)?$ ]] || { echo 'Invalid comparison metric.' >&2; exit 2; }
TOTAL=$((WIDTH * HEIGHT))
PCT="$(awk -v a="$AE" -v n="$TOTAL" 'BEGIN{printf "%.6f",100*a/n}')"
PASS=false
if awk -v a="$AE" -v n="$TOTAL" -v t="$THRESHOLD" 'BEGIN{exit !(100*a/n<=t)}'; then PASS=true; fi
magick "$REFERENCE" "$ACTUAL" "$PREFIX-diff.png" +append "$PREFIX-side.png"
jq -n --arg ref "$REFERENCE" --arg actual "$ACTUAL" --arg prefix "$PREFIX" --argjson pixels "$AE" --argjson total "$TOTAL" --argjson pct "$PCT" --argjson threshold "$THRESHOLD" --argjson pass "$PASS" '{pass:$pass,reference:$ref,actual:$actual,mismatchedPixels:$pixels,totalPixels:$total,mismatchPercent:$pct,threshold:$threshold,diff:($prefix+"-diff.png"),side:($prefix+"-side.png")}' >"$PREFIX.json"
if [ "$JSON" -eq 1 ]; then cat "$PREFIX.json"
elif [ "$PASS" = true ]; then printf '[PASS] %s%% mismatched; threshold %s%%. Report: %s.json\n' "$PCT" "$THRESHOLD" "$PREFIX"
else printf '[FAIL] %s%% mismatched; threshold %s%%. Report: %s.json\n' "$PCT" "$THRESHOLD" "$PREFIX"; fi
[ "$PASS" = true ]

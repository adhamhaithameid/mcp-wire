#!/usr/bin/env bash
set -euo pipefail
ref="${INPUT_REFERENCE:-}"
actual="${INPUT_ACTUAL:-}"
tol="${INPUT_TOLERANCE:-5}"
diffout="${INPUT_DIFF_OUT:-diff.png}"
if [ -z "$ref" ] || [ -z "$actual" ]; then
  echo "not implemented: missing reference/actual inputs" >&2
  exit 1
fi
if ! command -v compare >/dev/null 2>&1; then
  echo "not implemented: ImageMagick compare required" >&2
  exit 1
fi
# baseline mode
if [ "${INPUT_BASELINE_UPDATE:-0}" = "1" ]; then
  cp "$actual" "$ref"
  echo "baseline updated"
  exit 0
fi
# pixel diff
set +e
compare -metric AE "$ref" "$actual" "$diffout" 2>"$diffout.err"
rc=$?
set -e
# read metric from stderr
metric=$(cat "$diffout.err" 2>/dev/null | tr -d ' ' || echo 0)
rm -f "$diffout.err"
# compute percentage
pixels=$(identify -format "%w*%h" "$ref" 2>/dev/null | bc 2>/dev/null || echo 1)
total=$(echo "$pixels" | bc 2>/dev/null || echo 1)
if [ -z "$total" ] || [ "$total" = "0" ]; then total=1; fi
pct=$(awk -v m="$metric" -v t="$total" 'BEGIN{printf "%.2f", (m/t)*100}')
echo "diff: $metric pixels ($pct%)"
# write json report
printf '{"diff_pixels":%s,"percent":%s,"tolerance":%s}\n' "${metric:-0}" "$pct" "$tol" > "${diffout%.png}.json"
if awk -v p="$pct" -v t="$tol" 'BEGIN{exit (p>t)?0:1}'; then
  echo "FAIL: above tolerance"
  exit 1
fi
echo "PASS"

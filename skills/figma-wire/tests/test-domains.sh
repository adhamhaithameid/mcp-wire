#!/usr/bin/env bash
# Verify packaged domain skills and the complete visual comparison path offline.
set -eu -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"; PID=''
trap 'if [ -n "$PID" ]; then kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; fi; rm -rf "$WORK"' EXIT
bash "$ROOT/scripts/package-skills.sh"
for skill in figma-wire figma-design figma-code figma-verify figma-pages; do
  for file in SKILL.md scripts/figma-wire.sh scripts/mcp-wire.sh scripts/figma-design.sh scripts/figma-tokens.sh; do
    test -f "$ROOT/skills/$skill/$file"
  done
  cmp "$ROOT/scripts/mcp-wire.sh" "$ROOT/skills/$skill/scripts/mcp-wire.sh"
done
HOME="$WORK/home" bash "$ROOT/scripts/figma-wire.sh" install-skill >/dev/null
for skill in figma-wire figma-design figma-code figma-verify figma-pages; do
  test -f "$WORK/home/.agents/skills/$skill/scripts/mcp-wire.sh"
done
node "$ROOT/tests/fake-devmode-server.js" 0 >"$WORK/port" & PID=$!
for _ in $(seq 1 50); do [ ! -s "$WORK/port" ] || break; sleep 0.1; done
PORT="$(cat "$WORK/port")"
export FIGMA_WIRE_PORT="$PORT" FIGMA_WIRE_SCAN_PORTS="$PORT-$PORT"
# Drive the installed domain copy, outside the source repository.
bash "$WORK/home/.agents/skills/figma-design/scripts/figma-wire.sh" design 1:2 "$WORK/packet" >/dev/null
jq -e '.nodeId=="1:2"' "$WORK/packet/manifest.json" >/dev/null
mkdir "$WORK/bin"
cat >"$WORK/bin/playwright" <<'PLAYWRIGHT'
#!/usr/bin/env bash
for last; do :; done
printf 'fixture screenshot' >"$last"
PLAYWRIGHT
cat >"$WORK/bin/magick" <<'MAGICK'
#!/usr/bin/env bash
if [ "$1" = identify ]; then printf '1 1'; exit; fi
for last; do :; done
printf 'fixture composite' >"$last"
MAGICK
cat >"$WORK/bin/compare" <<'COMPARE'
#!/usr/bin/env bash
if [ "${FIXTURE_COMPARE_ERROR:-0}" = 1 ]; then echo 'fixture comparison error' >&2; exit 2; fi
for last; do :; done
printf 'fixture diff' >"$last"
printf '%s' "${FIXTURE_AE:-0}" >&2
[ "${FIXTURE_AE:-0}" = 0 ] || exit 1
COMPARE
chmod +x "$WORK/bin/"*
PATH="$WORK/bin:$PATH" bash "$ROOT/scripts/figma-wire.sh" diff 1:2 http://fixture.invalid --viewport 1x1 --out "$WORK/pass" >"$WORK/pass.log"
grep -q '\[PASS\]' "$WORK/pass.log"
if PATH="$WORK/bin:$PATH" FIXTURE_AE=1 bash "$ROOT/scripts/figma-wire.sh" diff 1:2 http://fixture.invalid --viewport 1x1 --out "$WORK/fail" >"$WORK/fail.log"; then echo 'Mismatch must fail' >&2; exit 1; fi
grep -q '\[FAIL\]' "$WORK/fail.log"
if PATH="$WORK/bin:$PATH" FIXTURE_COMPARE_ERROR=1 bash "$ROOT/scripts/figma-wire.sh" diff 1:2 http://fixture.invalid --viewport 1x1 --out "$WORK/error" >"$WORK/error.log" 2>&1; then echo 'Comparison errors must fail' >&2; exit 1; fi
grep -q 'Pixel comparison failed' "$WORK/error.log"
echo 'Domain installation and visual gate fixtures passed.'

# Real ImageMagick checks use synthetic images, never fabricated Figma evidence.
if command -v magick >/dev/null && command -v compare >/dev/null; then
  magick -size 4x4 xc:black "$WORK/black.png"
  magick -size 4x4 xc:white "$WORK/white.png"
  bash "$ROOT/scripts/figma-compare.sh" "$WORK/black.png" "$WORK/black.png" --out "$WORK/real-pass" --json >"$WORK/real-pass.json"
  jq -e '.pass and .mismatchPercent==0' "$WORK/real-pass.json" >/dev/null
  if bash "$ROOT/scripts/figma-compare.sh" "$WORK/black.png" "$WORK/white.png" --out "$WORK/real-fail" --json >"$WORK/real-fail.json"; then echo 'Actual image mismatch must fail' >&2; exit 1; fi
  jq -e '.pass==false and .mismatchPercent==100' "$WORK/real-fail.json" >/dev/null
  magick -size 1024x1024 xc:black "$WORK/large-black.png"
  magick -size 1024x1024 xc:white "$WORK/large-white.png"
  if bash "$ROOT/scripts/figma-compare.sh" "$WORK/large-black.png" "$WORK/large-white.png" --out "$WORK/large" --json >"$WORK/large.json"; then echo 'Large mismatch must fail' >&2; exit 1; fi
  jq -e '.mismatchedPixels==1048576 and .mismatchPercent==100' "$WORK/large.json" >/dev/null
  echo 'Real ImageMagick checks passed with synthetic images.'
else
  echo 'SKIP: optional real ImageMagick checks; deterministic visual fixtures passed.'
fi

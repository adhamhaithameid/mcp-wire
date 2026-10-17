#!/usr/bin/env bash
# End-to-end setup test: simulates a user who downloaded the skill folder,
# runs the installer with a sandboxed HOME, and verifies the installed artifact.
# Requires: bash, curl, jq, node. Run: bash tests/e2e.sh
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/.." && pwd)"
SIMHOME="$(mktemp -d)"
PASS=0; FAIL=0

cleanup() { rm -rf "$SIMHOME"; }
trap cleanup EXIT

chk() { # chk <name> <cmd...> — args are exec'd directly (no shell string)
  local name="$1"; shift
  if "$@" > /dev/null 2>&1; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "FAIL: $name"
  fi
}

# "download": copy the source into a neutral location (as if cloned)
cp -R "$SRC" "$SIMHOME/repo"

# run the installer with a sandboxed HOME (its self-test runs in offline mode)
if HOME="$SIMHOME" bash "$SIMHOME/repo/install.sh" > "$SIMHOME/setup.log" 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); echo "FAIL: installer exited nonzero:"; tail -20 "$SIMHOME/setup.log"
fi

INST="$SIMHOME/.agents/skills/figma-wire"
for f in SKILL.md README.md LICENSE install.sh scripts/figma-wire.sh scripts/mcp-wire.sh scripts/figma-design.sh scripts/figma-tokens.sh references/devmode-tools.md tests/run-tests.sh; do
  chk "installed: $f" test -f "$INST/$f"
done
chk "installed script executable" test -x "$INST/scripts/figma-wire.sh"
chk "installed script identical" cmp -s "$SRC/scripts/figma-wire.sh" "$INST/scripts/figma-wire.sh"
chk "installed skill identical" cmp -s "$SRC/SKILL.md" "$INST/SKILL.md"

chk "command symlink stays in sandbox HOME" test -L "$SIMHOME/.local/bin/figma-wire"

# installed copy runs (sandbox HOME again so state stays out of the real one)
chk "installed version works" env HOME="$SIMHOME" bash "$INST/scripts/figma-wire.sh" version
chk "installed config works" env HOME="$SIMHOME" bash "$INST/scripts/figma-wire.sh" config

# re-run installer from the installed location (self-location branch)
if HOME="$SIMHOME" bash "$INST/install.sh" > "$SIMHOME/resetup.log" 2>&1; then
  PASS=$((PASS+1))
else
  FAIL=$((FAIL+1)); echo "FAIL: re-run from install location:"; tail -10 "$SIMHOME/resetup.log"
fi
chk "files intact after re-run" cmp -s "$SRC/scripts/figma-wire.sh" "$INST/scripts/figma-wire.sh"

# Existing skill-to-source links must remain usable and must not be replaced.
LINKHOME="$SIMHOME/linked-home"
mkdir -p "$LINKHOME/.agents/skills"
ln -s "$SIMHOME/repo" "$LINKHOME/.agents/skills/figma-wire"
chk "install with existing source link" env HOME="$LINKHOME" bash "$SIMHOME/repo/install.sh"
chk "existing source link preserved" test -L "$LINKHOME/.agents/skills/figma-wire"

echo "== setup e2e: ${PASS} passed, ${FAIL} failed =="
[ "$FAIL" -eq 0 ]

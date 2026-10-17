#!/usr/bin/env bash
# figma-wire installer — copies the skill into ~/.agents/skills/figma-wire/
# and verifies the runtime dependencies. Idempotent; safe to re-run.
set -u
umask 077

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}/.agents/skills/figma-wire"

fail() { echo "ERROR: $*" >&2; exit 1; }

echo "== figma-wire installer =="

# 1. dependencies
for dep in bash curl jq; do
  command -v "$dep" > /dev/null 2>&1 || fail "missing dependency: $dep (install it and re-run)"
done
echo "[ ok ] dependencies: bash, curl, jq"

# 2. sanity-check the source tree
[ -f "$SRC/SKILL.md" ]          || fail "SKILL.md not found next to install.sh"
[ -f "$SRC/scripts/figma-wire.sh" ] || fail "scripts/figma-wire.sh not found"
echo "[ ok ] source tree looks complete"

bash "$SRC/scripts/package-skills.sh" || fail "skill packaging failed"

# 3. self-test before installing (offline mode; network tests need real endpoints)
echo "[ .. ] running self-tests (offline mode)"
if ! command -v node >/dev/null 2>&1; then
  echo "[warn] Development self-tests skipped: Node.js is absent. The runtime needs bash, curl, and jq."
elif SKIP_NETWORK_TESTS=1 bash "$SRC/tests/run-tests.sh" > /dev/null 2>&1; then
  echo "[ ok ] self-tests passed"
else
  echo "self-test output:"
  SKIP_NETWORK_TESTS=1 bash "$SRC/tests/run-tests.sh" | tail -20
  fail "self-tests failed — not installing a broken copy"
fi

# 4. install (copy, don't move — the source dir stays usable as a repo checkout)
if [ "$(cd "$SRC" && pwd -P)" = "$(cd "$DEST" 2>/dev/null && pwd -P)" ]; then
  echo "[ ok ] already running from the install location — refreshing permissions only"
  chmod +x "$DEST/scripts/figma-wire.sh" "$DEST/tests/run-tests.sh" 2>/dev/null
else
  mkdir -p "$DEST" || fail "cannot create $DEST"
  cp -f "$SRC/install.sh" "$DEST/install.sh"   || fail "copy failed"
  cp -f "$SRC/SKILL.md" "$DEST/SKILL.md"       || fail "copy failed"
  cp -f "$SRC/README.md" "$DEST/README.md"     || fail "copy failed"
  cp -f "$SRC/LICENSE" "$DEST/LICENSE"         || fail "copy failed"
  [ ! -d "$SRC/docs" ] || cp -R "$SRC/docs" "$DEST/"
  [ ! -d "$SRC/completions" ] || cp -R "$SRC/completions" "$DEST/"
  mkdir -p "$DEST/scripts" "$DEST/references" "$DEST/tests"
  cp -f "$SRC/scripts/"*.sh "$DEST/scripts/" || fail "copy failed"
  cp -f "$SRC/references/"*.md "$DEST/references/"    || fail "copy failed"
  cp -f "$SRC/tests/"* "$DEST/tests/" 2>/dev/null || true
  [ ! -d "$SRC/skills" ] || cp -R "$SRC/skills" "$DEST/"
  chmod +x "$DEST/scripts/figma-wire.sh" "$DEST/tests/run-tests.sh" 2>/dev/null
fi

# Register self-contained domain skills after the connection skill.
bash "$DEST/scripts/figma-wire.sh" install-skill || fail "skill registration failed"

# 5. user-owned command path; never change a system bin directory.
BIN="$HOME/.local/bin"
mkdir -p "$BIN" || fail "cannot create user bin directory"
ln -sf "$DEST/scripts/figma-wire.sh" "$BIN/figma-wire" || fail "cannot create user command link"
echo "[ ok ] symlinked: $BIN/figma-wire"
case ":$PATH:" in
  *":$BIN:"*) : ;;
  *) echo '[warn] Add $HOME/.local/bin to PATH to use the figma-wire command.' ;;
esac

# 6. post-install status
echo
echo "== installed at $DEST ="
echo "Next steps:"
echo "  1. Enable in Figma desktop: Preferences -> Enable Dev Mode MCP Server"
echo "  2. Run: figma-wire doctor        (or: bash $DEST/scripts/figma-wire.sh doctor)"
echo "  3. Restart your agent session so it picks up the MCP server"

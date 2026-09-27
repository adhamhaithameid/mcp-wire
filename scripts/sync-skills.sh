#!/usr/bin/env bash
# sync-skills.sh — refresh vendored skills in the mcp-wire family repo.
#
# The family npm package (@adhamhaithameid/mcp-wire) bundles every skill under
# skills/, but each skill lives in its OWN repository (e.g. adhamhaithameid/figma-wire).
# This script copies a skill repo's current tree into the family repo's vendored
# location, excluding VCS/CI internals, so a family release always ships the
# skill repos' latest committed state.
#
# Usage:
#   scripts/sync-skills.sh <source-repo-dir> <skill-name>     # refresh one skill
#   scripts/sync-skills.sh --check <source-repo-dir> <skill-name>
#
# Examples:
#   scripts/sync-skills.sh ../figma-wire figma-wire
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; shift; fi
[ $# -ge 2 ] || { echo "usage: scripts/sync-skills.sh [--check] <source-repo-dir> <skill-name>" >&2; exit 1; }

SRC="$1"
NAME="$2"
DEST="$REPO/skills/$NAME"

[ -d "$SRC" ] || { echo "FAIL: source repo not found: $SRC" >&2; exit 1; }
[ -f "$SRC/SKILL.md" ] || { echo "FAIL: $SRC has no SKILL.md — is that a skill repo?" >&2; exit 1; }

if [ "$CHECK" -eq 1 ]; then
  [ -d "$DEST" ] || { echo "STALE: skills/$NAME missing — run sync-skills.sh" >&2; exit 1; }
  if diff -rq --exclude=.git --exclude=.github --exclude=.gitignore --exclude=skills --exclude=node_modules "$SRC" "$DEST" > /dev/null 2>&1; then
    echo "ok  : skills/$NAME (vendored copy current)"
  else
    echo "STALE: skills/$NAME differs from $SRC — re-run sync-skills.sh" >&2
    exit 1
  fi
else
  mkdir -p "$DEST"
  # copy everything except VCS/CI internals and generated output
  (cd "$SRC" && tar -cf - --exclude=.git --exclude=.github --exclude=.gitignore --exclude=node_modules --exclude=skills .) | (cd "$DEST" && tar -xf -)
  echo "synced: $SRC -> skills/$NAME"
fi

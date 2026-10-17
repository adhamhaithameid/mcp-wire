#!/usr/bin/env bash
# Refresh app-owned snapshots and independently usable domain skills.
# Usage: sync-skills.sh [--check] <source-repo-dir> <skill-name>
set -eu -o pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK=0
if [ "${1:-}" = --check ]; then CHECK=1; shift; fi
[ $# -eq 2 ] || { echo 'Usage: sync-skills.sh [--check] <source-repo-dir> <skill-name>' >&2; exit 1; }
SRC="$(cd "$1" && pwd)"; NAME="$2"
[[ "$NAME" =~ ^[a-z][a-z0-9-]*$ ]] || { echo 'Invalid skill name.' >&2; exit 1; }
[ -f "$SRC/SKILL.md" ] || { echo 'Source has no SKILL.md.' >&2; exit 1; }
[ "$CHECK" -eq 1 ] || { [ ! -f "$SRC/scripts/package-skills.sh" ] || bash "$SRC/scripts/package-skills.sh"; }
# Exclude the app's packaging tree from its main snapshot; copy domain skills separately.
copy_skill() {
  local source="$1" name="$2" dest="$REPO/skills/$2" stage
  if [ "$CHECK" -eq 1 ]; then
    diff -rq --exclude=.git --exclude=.github --exclude=node_modules --exclude=skills "$source" "$dest" >/dev/null || { echo "STALE: skills/$name differs from its source" >&2; return 1; }
    return
  fi
  stage="$(mktemp -d "$REPO/skills/.${name}.XXXXXX")"
  if ! (cd "$source" && tar -cf - --exclude=.git --exclude=.github --exclude=node_modules --exclude=./skills/figma-wire .) | (cd "$stage" && tar -xf -); then rm -rf "$stage"; return 1; fi
  if [ -d "$dest" ]; then mv "$dest" "$stage.old"; fi
  if mv "$stage" "$dest"; then rm -rf "$stage.old"; else [ ! -d "$stage.old" ] || mv "$stage.old" "$dest"; return 1; fi
  echo "synced: skills/$name"
}
copy_skill "$SRC" "$NAME"
for domain in "$SRC"/skills/*; do
  [ -f "$domain/SKILL.md" ] || continue
  [ "$(basename "$domain")" != "$NAME" ] || continue
  copy_skill "$domain" "$(basename "$domain")"
done

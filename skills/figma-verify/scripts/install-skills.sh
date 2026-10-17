#!/usr/bin/env bash
# Register complete family skills without editing harness configuration.
set -eu -o pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${MCP_WIRE_SKILLS_DIR:-$HOME/.agents/skills}"
[ $# -eq 0 ] || { echo 'Set MCP_WIRE_SKILLS_DIR to select an installation folder.' >&2; exit 1; }
mkdir -p "$DEST"
install_one() {
  local source="$1" name="$2" target="$DEST/$2" stage
  [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]] || return 1
  if [ -L "$target" ]; then
    local same=1 file relative
    cmp -s "$source/SKILL.md" "$target/SKILL.md" || same=0
    for file in "$source"/scripts/* "$source"/references/*; do
      [ -f "$file" ] || continue
      relative="${file#"$source/"}"
      cmp -s "$file" "$target/$relative" || same=0
    done
    if [ "$same" -eq 1 ]; then echo "Already installed through a matching source link: $target"; return 0; fi
    echo "Linked source differs: $target. Update that source or select MCP_WIRE_SKILLS_DIR; the installer will not overwrite a repository." >&2
    return 1
  fi
  [ "$source" != "$target" ] || return 0
  stage="$(mktemp -d "$DEST/.${name}.XXXXXX")"
  if ! (cd "$source" && tar -cf - --exclude=.git --exclude=node_modules --exclude=skills .) | (cd "$stage" && tar -xf -); then rm -rf "$stage"; return 1; fi
  if [ -d "$target" ]; then mv "$target" "$stage.old"; fi
  if mv "$stage" "$target"; then rm -rf "$stage.old"; else [ ! -d "$stage.old" ] || mv "$stage.old" "$target"; return 1; fi
  echo "Installed $name at $target"
}
BASE=''
if [ -f "$ROOT/SKILL.md" ]; then
  BASE="$(awk '/^name: / {print $2; exit}' "$ROOT/SKILL.md")"
  install_one "$ROOT" "$BASE"
fi
for skill in "$ROOT"/skills/*; do
  [ -f "$skill/SKILL.md" ] || continue
  [ "$(basename "$skill")" != "$BASE" ] || continue
  install_one "$skill" "$(basename "$skill")"
done
echo 'Configure your harness to discover these skill folders, then restart its session if required.'

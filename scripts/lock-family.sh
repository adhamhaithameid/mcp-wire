#!/usr/bin/env bash
# Lock the reviewed skill snapshot. Does not fetch or update app repositories.
set -eu -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
hash() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
MODE="${1:---check}"
case "$MODE" in --write|--check) : ;; *) echo 'Usage: lock-family.sh [--write|--check]' >&2; exit 1 ;; esac
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
printf '{}\n' >"$WORK/files"
while IFS= read -r file; do
  jq --arg file "$file" --arg sum "$(hash "$file")" '.+{($file):$sum}' "$WORK/files" >"$WORK/next"
  mv "$WORK/next" "$WORK/files"
done < <(git ls-files engine skills scripts | grep -v '/\.opencode/' | LC_ALL=C sort)
jq -n --argjson files "$(cat "$WORK/files")" --argjson family "$(cat family.json)" '{format:1,family:$family,files:$files}' >"$WORK/lock"
if [ "$MODE" = --write ]; then cp "$WORK/lock" family.lock.json; echo 'Family snapshot locked.'
else cmp -s "$WORK/lock" family.lock.json || { echo 'Family snapshot changed. Review it, then run bash scripts/lock-family.sh --write.' >&2; exit 1; }; echo 'Family snapshot matches lock.'; fi

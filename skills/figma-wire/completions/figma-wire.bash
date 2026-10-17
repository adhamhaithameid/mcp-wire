_figma_wire_complete() {
  COMPREPLY=()
  local current="${COMP_WORDS[COMP_CWORD]}"
  local words='doctor use link call tools describe resources prompts design tokens compare diff remote fetch status config install-skill version --json --fix --remote --harness --viewport --threshold --full-page --wait --resize --out'
  case "${COMP_WORDS[COMP_CWORD-1]}" in
    call|describe) words='get_design_context get_metadata get_screenshot get_variable_defs get_figjam' ;;
    --harness) words='zcode claude codex cursor windsurf vscode gemini generic all' ;;
  esac
  while IFS= read -r value; do COMPREPLY+=("$value"); done < <(compgen -W "$words" -- "$current")
}
complete -F _figma_wire_complete figma-wire

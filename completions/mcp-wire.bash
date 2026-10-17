_mcp_wire_complete() {
  COMPREPLY=()
  local current="${COMP_WORDS[COMP_CWORD]}"
  local words='list describe call raw resources prompts doctor servers skill --json --dry-run --header --header-env --timeout --config --stdio --allow-http --help --version'
  while IFS= read -r value; do COMPREPLY+=("$value"); done < <(compgen -W "$words" -- "$current")
}
complete -F _mcp_wire_complete mcp-wire

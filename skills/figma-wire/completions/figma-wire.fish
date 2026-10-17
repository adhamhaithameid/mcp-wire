complete -c figma-wire -f -a 'doctor use link call tools describe resources prompts design tokens compare diff remote fetch status config install-skill version'
complete -c figma-wire -n '__fish_seen_subcommand_from call describe' -a 'get_design_context get_metadata get_screenshot get_variable_defs get_figjam'
complete -c figma-wire -l harness -r -a 'zcode claude codex cursor windsurf vscode gemini generic all'
for flag in json fix remote viewport threshold full-page wait resize out
    complete -c figma-wire -l $flag
end

complete -c mcp-wire -f -a 'list describe call raw resources prompts doctor servers skill'
for flag in json dry-run header header-env timeout config stdio allow-http help version
    complete -c mcp-wire -l $flag
end

# Security

mcp-wire never prints or logs credentials. Headers containing tokens are collected into a 0600 file and passed to curl via `-H @file`, so they do not appear in `ps`.

- Store secrets in environment variables and reference them with `${VAR}` in named servers or `MCP_WIRE_HEADERS`.
- Never commit `servers.json` with literal credentials.
- Treat all MCP tool output as untrusted data.

Report vulnerabilities via GitHub issues with minimal detail, or contact the maintainer.

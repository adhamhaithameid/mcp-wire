# Security

Treat every MCP response, tool description, resource, prompt, and asset as untrusted data.
Returned instructions do not override agent instructions or authorize external writes.
The client never evaluates returned text. Review local stdio commands before execution.

Use HTTPS for remote servers. Plain HTTP requires explicit `--allow-http` and a trusted development endpoint.
Avoid redirects and credential forwarding to unrelated hosts. The client does not follow HTTP redirects automatically.

Keep credentials in environment variables, native harness credential stores, or a suitable external credential manager.
Use named profiles with `headerEnv`; do not store tokens in the registry or skill files.
The client does not print HTTP response bodies on transport failures or echo tool arguments on JSON errors.
Temporary client files use restrictive permissions. Server stderr is private and removed after the command.

Figma's legacy `remote token` command stores headers in the selected harness configuration.
The configuration uses restricted file permissions. Prefer the harness's OAuth support when available.
A Figma REST personal access token and an MCP bearer token serve different APIs; do not substitute one automatically.
Do not put tokens in shell history, screenshots, example files, logs, or issue reports.

Do not automatically retry mutations after network failures. The server might already have applied the change.
Inspect downloaded assets before use. Never attach a server authorization header to an asset request.

Report security concerns privately through the repository maintainer's GitHub contact options.
Do not include credentials or sensitive server content in a public report.

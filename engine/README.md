# mcp-wire engine

Call MCP servers from any agent with shell access. The runtime requires Bash, curl, and jq on macOS or Linux.
Use WSL on Windows. A stdio server can require its own runtime.

## First call

Use the repository-local engine without installation:

```bash
bash engine/mcp-wire.sh "$SERVER_URL" list --json
bash engine/mcp-wire.sh "$SERVER_URL" describe tool_name
bash engine/mcp-wire.sh "$SERVER_URL" call tool_name '{"argument":"value"}' --json
```

For a user-owned CLI installation:

```bash
mkdir -p "$HOME/.local/bin"
cp engine/mcp-wire.sh "$HOME/.local/bin/mcp-wire"
chmod +x "$HOME/.local/bin/mcp-wire"
```

Put `~/.local/bin` on PATH. Install an agent skill separately so the agent can discover its instructions.

## Commands and output

| Command | Result |
|---|---|
| `list` | All tool pages; readable names by default, full schemas with `--json`. |
| `describe <tool>` | Name, description, input schema, and annotations. |
| `call <tool> '<JSON>'` | Tool text and saved images, or the result object with `--json`. |
| `resources list` | All resource pages. |
| `resources templates` | All resource template pages. |
| `resources read <uri>` | Resource contents. |
| `prompts list` | All prompt pages. |
| `prompts get <name> '<JSON>'` | Prompt messages; argument values must be strings. |
| `raw '<JSON-RPC>'` | A request with a non-null ID, after initialization. |
| `doctor [server]` | Dependency checks; initialization and ping when a server is supplied. |
| `install-skill` | Register complete skills without changes to harness configuration. |
| `servers` | Configured names and transports without secrets or URLs. |
| `skill new <app> <url> <folder>` | A separate app repository scaffold with discovered schemas and a bundled engine. |

JSON mode returns the MCP result object, not its JSON-RPC envelope. Tool errors still return a nonzero status.
Without JSON mode, `-o prefix` appends text to `prefix.txt` and saves images as `prefix-N.png`, `.jpg`, or `.webp`.
Default image filenames retain the `mcp-wire-N` prefix.

`--dry-run` validates local request syntax and prints a redacted method preview without a connection.
It does not inspect the live schema or establish authorization for a write.

Use `--timeout N` for positive integer seconds per request. The default is 90 seconds.
Each command starts a fresh session. Pagination stays within that session and stops on repeated cursors or 100 pages.
Do not retry a failed mutation automatically. A network failure can occur after a server applies a write.

## Named servers and credentials

The default registry is `~/.config/mcp-wire/servers.json`.
Use `--config FILE`, `MCP_WIRE_CONFIG`, or `XDG_CONFIG_HOME` to select another location.

```json
{
  "servers": {
    "design": {
      "url": "https://mcp.figma.com/mcp",
      "headerEnv": { "Authorization": "DESIGN_AUTHORIZATION" }
    },
    "local-service": {
      "command": ["my-mcp-server", "--stdio"]
    }
  }
}
```

Set the authorization environment variable through your credential manager. Its value includes the required scheme, such as `Bearer`.
Do not put credentials in the registry. Do not print them or commit them to examples.

```bash
mcp-wire design list --json
mcp-wire local-service list --json
mcp-wire "$SERVER_URL" list --header-env Authorization=DESIGN_AUTHORIZATION --json
mcp-wire --stdio '["my-mcp-server","--stdio"]' list --json
```

The existing `--header 'Name: value'` flag remains available. Environment profiles avoid tokens in command history.
All HTTP requests carry the supplied headers, including the initialized notification.

## Supported protocols

The client implements one-shot Streamable HTTP and newline-delimited stdio.
HTTP accepts JSON and SSE responses, optional session IDs, and response selection by request ID.
It negotiates supported versions `2025-03-26`, `2025-06-18`, and `2025-11-25`.
Use `MCP_WIRE_PROTOCOL_VERSION` to select one of those initial versions when a server requires it.
The client rejects other negotiated versions instead of assuming compatibility.

The client does not implement legacy HTTP+SSE endpoints, stream resume, subscriptions, OAuth login, or interactive callbacks.
Use native harness support for those capabilities. An HTTP 404 requires a new invocation; the client does not replay writes automatically.

The specification permits optional session IDs and JSON or SSE responses:
[Streamable HTTP specification](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

## Safety

HTTPS is the default requirement. Use `--allow-http` only for a trusted development endpoint.
The client never evaluates server text, resource contents, or prompt instructions.
A stdio command executes local code; use a command authorized for the requested task.
Server stderr stays in a private temporary directory and disappears after the command.
Do not send authorization headers to asset URLs or unrelated services.

## Verification

```bash
bash engine/tests/run-tests.sh
bash tests/test-family.sh
```

The fixtures cover JSON, SSE, stateless operation, pagination, authenticated notifications, errors, images, resources, prompts, and stdio.
Node.js is a test dependency, not an engine dependency.

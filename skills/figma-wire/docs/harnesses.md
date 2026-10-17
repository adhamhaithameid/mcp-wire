# Harness access

A CLI installation and a skill installation serve different purposes.
The CLI executes commands. Skill files let an agent discover the correct workflow.

The table records source adapters and offline checks. It does not claim live verification of every harness version.

| Harness | Figma config adapter | Offline config fixture | Shell fallback |
|---|---|---|---|
| Claude Code | `~/.claude.json`, `mcpServers` | Yes | Agent needs Bash tool access. |
| Codex | `~/.codex/config.toml`, `mcp_servers` | Yes | Agent needs shell access. |
| Cursor | `~/.cursor/mcp.json`, `mcpServers` | Yes | Agent needs terminal access. |
| Gemini CLI | `~/.gemini/settings.json`, `mcpServers` | Yes | Agent needs shell access. |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` | Yes | Agent needs terminal access. |
| VS Code | User settings `mcp.servers` adapter | Yes, strict JSON only | Agent needs terminal access. |
| ZCode | `~/.zcode/cli/config.json` | Yes | Agent needs shell access. |
| Other harnesses, including Antigravity | Generic `~/.agents/mcp.json` | Generic fixture only | Use bundled Bash directly. |

The generic config is a convention. A harness might not read it.
Do not claim native configuration support for Antigravity, Zed, Trae, or JetBrains without a verified adapter.
VS Code versions and workspace settings can use other MCP paths. JSONC files with comments require manual review; the adapter refuses invalid JSON.
Use `FIGMA_WIRE_CONFIG` for an explicitly selected path.

## Install and discover

From the Figma source checkout, run `bash install.sh`.
This installs the connection skill and domain skills under `~/.agents/skills/`.
From the family npm package, run `mcp-wire install-skill` for all skills or `figma-wire install-skill` for Figma skills.

Configure the harness to discover the installed skill folders through its supported skill mechanism.
Do not assume every harness reads `~/.agents/skills/` automatically.
For a harness without skill discovery, provide the relevant `SKILL.md` and its folder path in the task.
Restart an agent session when its startup-loaded tools or skills change.

## Native tools first

When native tools already work, use them. Do not change MCP config for ordinary design requests.
For connection repair, run `figma-wire doctor` and follow the exact diagnostic.
Use `--harness <name>` for the adapter you intend to change.
Use `--harness all` only when you intend to repair all existing configurations.

## OS and transport coverage

| Environment | Engine | Figma local access | Verification evidence |
|---|---|---|---|
| macOS | Bash, curl, jq; HTTP and stdio | Desktop server when enabled | Local offline suites; CI matrix. |
| Linux | Bash, curl, jq; HTTP and stdio | Reachable server or remote profile | CI matrix; live desktop access unverified. |
| Windows with WSL | Linux engine path | Networking setup depends on the host | Documented path; no native Windows adapter claim. |
| Windows without WSL | Unsupported Bash package target | Unsupported | No native implementation. |
| Model without shell or native tools | Cannot execute the client | Cannot execute the client | Skills do not grant execution permissions. |

A stdio server can have its own platform and runtime requirements.
Engine JSON and SSE support refers to Streamable HTTP responses, not legacy standalone SSE transport.

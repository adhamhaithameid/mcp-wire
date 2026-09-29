---
name: figma-wire
description: Wire, fix, or use Figma with the agent. Use when the user mentions Figma in any way — a share link, an MCP server port, "check/fix the Figma connection", missing Figma MCP tools — or before any Figma-driven design implementation when Figma MCP tools are not already available. Works across harnesses (ZCode, Claude Code, Codex, Cursor, Windsurf, VS Code, Gemini CLI, generic) and can pull design data from plain bash with no MCP client.
---

# Figma Wire

One script does all wiring; this doc is the decision path. All repair is
probe-before-write: nothing is edited unless the target server answers.

```bash
FW="$HOME/.agents/skills/figma-wire/scripts/figma-wire.sh"   # installed elsewhere? adjust once
bash "$FW" doctor
```

## Decision path (in order, stop when something works)

1. **Figma MCP tools already in your toolset?** (`get_design_context`, `get_screenshot`,
   `get_metadata`, …) → wiring is done. Skip to "Using Figma".
2. **Tools missing** → run `doctor`, act on its `[fix]` lines:
   - Live server + wired config, but tools absent → the session started before the
     config existed. **Tell the user to restart the session.** Do not retry wiring.
   - Not listening → Figma desktop is closed or Dev Mode MCP is off (Figma →
     Preferences → Enable Dev Mode MCP Server). Re-run `doctor` after.
   - Server moved to a different port → doctor finds it by scanning; `doctor --fix`
     re-wires automatically.
3. **User gives a port** → `bash "$FW" use <port>`. It probes, then writes the
   `figma-local` entry into the detected harness config. `--harness all` wires every
   installed harness (zcode, claude, cursor, windsurf, gemini, vscode, codex, generic).
4. **User gives a share link** → `bash "$FW" link '<url>'` — prints and stores
   `fileKey` + `nodeId`. Then "Using Figma".
5. **No MCP client available at all** (headless, CI, minimal harness) →
   `bash "$FW" call get_design_context <nodeId>` speaks MCP from plain bash: text to
   stdout, images saved as PNG (`-o prefix`). No MCP tooling required.
6. **User has a bearer token for mcp.figma.com** → `bash "$FW" remote token <TOKEN>
   [--region us-east-1]` (probes first; writes only on success). Without a token,
   `remote off` silences the remote server so it stops failing every session. Either
   way, the local path already covers everything open in Figma desktop.

## Using Figma

The local Dev Mode MCP rides on the Figma desktop app and sees **the file open in that
app**. After `link`, tell the user to make that file the active tab, then:

**With native MCP tools:** `get_design_context` with the `nodeId` first; too large →
`get_metadata`, then re-fetch needed child nodes; `get_screenshot` to validate;
`get_variable_defs` for tokens; `get_motion_context` for animation.

**With `call` (no MCP client):** same order, same tools:

```bash
bash "$FW" call get_design_context "142:3391"
bash "$FW" call get_screenshot "142:3391" -o hero   # → hero-1.png
```

`nodeId`: colon form (`123:456`) first; dash form as fallback. Full tool catalog:
`references/devmode-tools.md`.

**Assets:** a `localhost` URL for an image/SVG in a tool response is used directly —
no placeholders, no icon packages; all assets come in the payload.

**Implementation:** treat MCP output (usually React + Tailwind) as a design
representation, not final code — map onto the host project's tokens, components, and
framework, then validate 1:1 against the screenshot.

**Headless / REST:** `bash "$FW" fetch [fileKey] [nodeId]` pulls node JSON via the
REST API (needs `FIGMA_TOKEN` or a stored remote token).

## Configuration & portability

Every path is env-overridable (`FIGMA_WIRE_HARNESS`, `FIGMA_WIRE_CONFIG`,
`FIGMA_WIRE_STATE`, `FIGMA_WIRE_PORT`, `FIGMA_WIRE_SCAN_PORTS`, `FIGMA_TOKEN`) — see
README.md for the table. Port precedence: env > state > default. Harness is
auto-detected: zcode → claude → cursor → windsurf → gemini → vscode → codex → generic.

## Self-tests

`bash tests/run-tests.sh` — 83 hermetic unit tests with a fake Dev Mode server;
`bash tests/e2e.sh` — 15 end-to-end installer tests in a sandboxed HOME. Both run on
any machine with bash/curl/jq/node, Figma not required. `SKIP_NETWORK_TESTS=1` for
fully offline unit tests. Run after any script edit.

## Sharing

Self-contained repo (`install.sh`, `package.json`, CI on ubuntu+macOS, MIT `LICENSE`).
Public on GitHub (`adhamhaithameid/figma-wire`) → installable via
`npx skills add adhamhaithameid/figma-wire` (skills.sh); distributed on npm inside the
family package `@adhamhaithameid/mcp-wire`.

# figma-wire

Connect agents to Figma, collect reviewable design evidence, and verify implementations.
This app owns its workflows in a separate repository. The [mcp-wire family](https://github.com/adhamhaithameid/mcp-wire) owns the shared engine.

## Start from the checkout

The base runtime requires Bash, curl, and jq on macOS or Linux. Use WSL on Windows.
Open the target file in Figma desktop and enable its MCP server for local calls.

```bash
bash scripts/figma-wire.sh doctor
bash scripts/figma-wire.sh tools --json
bash scripts/figma-wire.sh describe get_design_context
bash scripts/figma-wire.sh call get_design_context '123:456' --json
bash scripts/figma-wire.sh design '123:456' ./design-packet
```

Use an actual node ID from your design. Inspect schemas before remote calls; they can require a `fileKey`.
Set `FIGMA_WIRE_SERVER` to an HTTPS endpoint or named engine profile for remote shell access.
Use the harness's OAuth support when available. The engine does not implement OAuth login.

## Install skills

```bash
bash install.sh
```

The installer registers `figma-wire`, `figma-design`, `figma-code`, `figma-verify`, and `figma-pages` under `~/.agents/skills/`.
Configure the harness's supported skill discovery mechanism. Restart the agent when its startup-loaded tools or skills change.
For the family npm installation, `figma-wire install-skill` registers the same skills.
The family package is the canonical npm distribution; this repository remains the Figma source owner.

## Choose a workflow

| Skill | Result |
|---|---|
| `figma-wire` | Connection diagnosis, config repair, tool discovery, and shell fallback. |
| `figma-design` | Context, screenshot, available metadata, available variables, and a source manifest. |
| `figma-code` | Project-specific implementation with existing components and tokens. |
| `figma-verify` | Visual comparison plus explicit behavior and accessibility checks. |
| `figma-pages` | Page and frame inventory before focused extraction. |

Prefer working native tools. Do not rewrite configuration for ordinary design requests.

## Commands

| Command | Purpose |
|---|---|
| `doctor [--json] [--fix] [--remote]` | Local diagnosis; optional repair and explicit remote connectivity check. |
| `use <port|url>` | Probe before a requested configuration change. |
| `link <share-url|fileKey>` | Record a design file and node. |
| `tools [--json]` | Discover current tools. |
| `describe <tool>` | Inspect its input schema. |
| `call <tool> [nodeId|JSON] [--json] [-o prefix]` | Call through the bundled shared engine. |
| `resources`, `prompts` | Access MCP resources or prompts when supported. |
| `design <nodeId> <new-folder>` | Collect a design packet without changes to project code. |
| `tokens <variables.json> <new-prefix>` | Export flat resolved variables to CSS and TypeScript. |
| `diff <nodeId> <url>` | Capture and compare design and implementation. |
| `compare <reference.png> <actual.png>` | Compare saved images and write a JSON report. |
| `remote token <TOKEN>`, `remote off` | Legacy harness credential configuration and disable operation. |
| `fetch [fileKey] [nodeId]` | Figma REST fallback with a REST personal access token. |
| `status`, `config`, `version` | Local settings and status. |

`--harness` selects zcode, claude, codex, cursor, windsurf, vscode, gemini, generic, or all existing configurations.
Only use `all` for an intended multi-harness change.
`FIGMA_WIRE_CONFIG`, `FIGMA_WIRE_STATE`, `FIGMA_WIRE_PORT`, and `FIGMA_WIRE_SCAN_PORTS` provide explicit path and port overrides.
Remote checks stay opt-in so ordinary diagnostics and automated tests remain local.

## Visual verification

Visual capture additionally needs ImageMagick 7, Playwright, and its browser.
These optional dependencies do not change the engine runtime.

```bash
bash scripts/figma-wire.sh diff '123:456' http://localhost:3000 --viewport 1440x900 --threshold 5 --out ./review
bash scripts/figma-wire.sh compare ./reference.png ./actual.png --threshold 5 --out ./review-ci --json
```

The comparison writes a diff image, a side-by-side image, and a JSON report.
It fails for excessive mismatch and distinguishes invalid input from a comparison error.
Use matching frames, viewports, themes, and stable page states. Do not resize images to conceal layout errors.
Pixel comparison does not prove behavior or accessibility.
See [visual verification](docs/visual-verification.md) for CI and evidence limits.

## What this adds to the official server

The official Figma MCP server supplies design tools. figma-wire adds access and workflow helpers around those tools.

| Official capability | Additional family behavior |
|---|---|
| Design context and screenshots | A reviewable packet and focused implementation workflow. |
| Available variables | Flat-value CSS and TypeScript export with collision checks. |
| Native MCP access | Shell fallback when native access is absent. |
| Harness integration | Probe-before-write connection diagnosis and repair. |
| Design reference | Saved-image gate with JSON reports and side-by-side artifacts. |

Discover capabilities on the actual server. Do not assume optional motion or mapping tools exist.

## Development and source ownership

```bash
SKIP_NETWORK_TESTS=1 bash tests/run-tests.sh
bash tests/e2e.sh
bash tests/test-domains.sh
```

Node.js runs the fake servers for development checks. Figma and live credentials are not required for offline checks.
Update the engine in mcp-wire, then copy it into this repository with the family synchronization script.
Build domain bundles with `bash scripts/package-skills.sh`. Each Git-distributed domain skill also carries its runtime helpers.
Read [architecture](ARCHITECTURE.md), [security](SECURITY.md), and [harness coverage](docs/harnesses.md).

Bash, Zsh, and Fish completions live in `completions/`.
For Bash from this checkout, use `source completions/figma-wire.bash`.
Completion tool names are suggestions; live discovery remains authoritative.

## Limits

Variable export accepts flat resolved values. It does not infer aliases, units, modes, or framework configuration.
The code skill guides project-specific implementation; it does not generate universal production scaffolds automatically.
Native Windows support, every harness version, and live visual fidelity require separate verification.

MIT license. See [LICENSE](LICENSE).

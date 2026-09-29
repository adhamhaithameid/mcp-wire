# Changelog

All notable changes to figma-wire are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is semver.

## [1.4.1] — 2026-09-29

### Changed

- **Republished as the standalone npm package** for the mcp-wire family's
  independent-skill distribution: install `npm i -g figma-wire` for just this skill,
  or `npm i -g @adhamhaithameid/mcp-wire` for the engine + every family skill.
- `prepack` no longer references monorepo-only paths; the package bundles its own
  skills-npm mirror (`skills/figma-wire/SKILL.md` + references).

## [1.4.0] — 2026-09-24

### Added

- **The mcp-wire skill ships inside this package**: `skills/mcp-wire/SKILL.md` teaches
  agents to call any MCP server from plain bash via the shared engine. The npm package
  is now the family vehicle — one install, every skill in `skills/` is discoverable by
  skills-npm-compatible tools.
- **Engine CLI without npm**: `scripts/install-engine.sh` (and the documented curl
  one-liner) installs `mcp-wire` straight from this repo — the engine's own npm
  package is pending npm's new-package policy for passkey-only accounts.

## [1.3.1] — 2026-09-24

### Added

- **[skills-npm](https://github.com/antfu/skills-npm) compatibility**: the npm package now
  bundles `skills/figma-wire/SKILL.md` (generated at publish from the root SKILL.md), so
  `npx skills-npm setup` discovers and symlinks the skill into supported coding agents
  automatically. No behavior change otherwise.

## [1.3.0] — 2026-09-21

### Added

- `diff <nodeId> <url>` — the design-to-code validation loop in one command:
  screenshots a Figma node and the implemented page (via Playwright), pixel-diffs
  them with ImageMagick, reports mismatched-pixel percentage, and passes/fails
  against a `--threshold`. Detects size mismatch between the design frame and the
  viewport and tells you the exact `--viewport` to use; `--resize` force-fits.
- Release automation: tagging `v*` runs both test suites, publishes to npm
  (provenance / OIDC trusted publishing), and creates the GitHub Release with
  generated notes.

## [1.2.0] — 2026-09-20

### Added

- `call <tool> [nodeId|JSON]` — raw MCP tools/call from plain bash: full handshake,
  SSE parsing, text to stdout, images saved as PNG. Any agent (or CI script) can now
  pull Figma design data with no MCP client at all.
- Three more harness adapters: **Windsurf** (`serverUrl`), **VS Code** (`mcp.servers`,
  with a JSONC-safety guard), **Gemini CLI** (`httpUrl`) — eight harnesses total.
- `doctor --json` (machine-readable diagnosis) and `doctor --fix` (auto re-wires a
  moved or missing `figma-local` entry; scans ports 3845–3854 when the server moved).
- `remote token <TOKEN> --region <region>` — X-Figma-Region header support for the
  remote mcp.figma.com server.
- Port precedence: `FIGMA_WIRE_PORT` env > persisted state > default.
- GitHub Actions CI: both suites on ubuntu-latest and macos-latest.

## [1.1.0] — 2026-09-19

### Added

- Hermetic test suite: a fake Dev Mode MCP server plus sandboxed config/state paths —
  runs on any machine, Figma not required.
- Multi-harness support: ZCode, Claude Code, Codex (native TOML editing), Cursor, and
  a generic `~/.agents/mcp.json` adapter, auto-detected.
- Env overrides for every path (`FIGMA_WIRE_HARNESS/CONFIG/STATE/PORT`, `FIGMA_TOKEN`).
- `install.sh` with a self-test gate, README, MIT license — the folder became a
  distributable package.

## [1.0.0] — 2026-09-19

### Added

- First working version: `doctor`, `use`, `link`, `remote`, `fetch`, `status` —
  probe-before-write wiring of the local Figma Dev Mode MCP server into agent configs.

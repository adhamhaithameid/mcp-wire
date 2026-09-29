# Changelog

All notable changes to the mcp-wire family (engine + skills) are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is semver.

## [1.0.1] — 2026-09-29

### Changed

- **Documentation release**: the standalone `figma-wire` npm package has been retired —
  this family package is now the only npm distribution (both CLIs + every skill).
  README, skill docs, and install instructions all updated to the family-package flow.

## [1.0.0] — 2026-09-24

### The family, as one package

- **`mcp-wire` engine** — a full MCP (Model Context Protocol) client in one bash
  script: handshake, JSON-RPC, SSE parsing; text to stdout, images to PNG.
  `list` / `call` / `raw` against any streamable-HTTP MCP server.
- **`figma-wire` skill** — wire any AI coding agent to Figma: probe/repair the local
  Dev Mode MCP server across 8 harnesses, parse share links, `call` any of Figma's 6
  MCP tools from plain bash, and `diff` a design against the implemented page with
  pixel precision.
- **skills-npm compatibility** — both skills bundle `skills/<name>/SKILL.md` so
  `npx skills-npm setup` symlinks them into supported coding agents automatically.
- Hermetic test suites (engine 19, figma-wire 85 unit + 15 e2e) with fake MCP/Dev Mode
  servers; CI on Ubuntu and macOS.

## History

figma-wire was developed standalone before the family consolidated here — its
individual release notes live in [`skills/figma-wire/CHANGELOG.md`](skills/figma-wire/CHANGELOG.md).

# Changelog

All notable changes to the mcp-wire family (engine + skills) are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is semver.

## [Unreleased]

### Added

- Add stdio, stateless JSON responses, paginated discovery, schemas, resources, prompts, named server profiles, JSON output, and redacted previews.
- Add a private independent-app scaffold with schema discovery and offline checks.
- Add Figma design, code, verification, and page skills with complete runtime bundles.
- Add design packets, flat variable exports, saved-image comparison reports, and a reusable CI gate.
- Add family ownership, snapshot locks, harness coverage, completion files, architecture, and security documentation.

### Fixed

- Make Figma calls use the shared engine and send authorization headers on every HTTP POST.
- Keep offline diagnostics local and reject malformed responses and failed pixel comparisons.
- Verify engine copies and reviewed family snapshots before package publication.
- Replace the obsolete root test entrypoint and verify installed skill artifacts.

### Compatibility

- Preserve existing list, call, raw, and Figma call flags and default text/image behavior.
- Keep OAuth login, native Windows support, legacy SSE transport, stream resume, and interactive callbacks outside this release.

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

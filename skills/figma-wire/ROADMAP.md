# ROADMAP — the figma-wire domain set

figma-wire is the connection skill: it wires agents to Figma and keeps that wiring
healthy. The suggestions below are **domain skills** — each one a focused, separately
installable skill that goes deep on one Figma workflow, all riding the same
[mcp-wire engine](https://github.com/adhamhaithameid/mcp-wire) and the same local
Dev Mode MCP server. Every one of them ships a `doctor` first (the family standard),
then helpers for its domain.

Order here is the suggested build order, not a commitment — study each before
building, and split any that feels like two skills.

## figma-design

Deep design-system extraction. Beyond `get_design_context` for one node: pull a
file's full variable/color/typography/component inventory as structured output
(tokens file, style guide summary, component catalog). Consumes
`get_variable_defs` + `get_metadata` sweeps + the REST styles endpoints through the
mcp-wire engine's `raw` command.

## figma-code

Production code generation. Where figma-wire's `call get_design_context` returns
reference code, figma-code turns selected frames into framework-specific component
scaffolds (React/Vue/Svelte/SwiftUI), wired to the caller's project conventions and
validated against the design with the existing `diff` pixel gate.

## figma-prototype

Prototype flow understanding. Walk prototype links: screens, transitions,
hotspots, and flow order (REST prototype endpoints through the engine), so an agent
can implement multi-screen interactions, not just static frames.

## figma-pages

File and page inventory. Map a whole Figma file: pages, frames, sections, sizes,
and modification dates — the "give me a table of contents of this design file"
skill. Mostly `get_metadata` sweeps; the foundation the other skills query.

## figma-search

Search across Figma. Find nodes, components, and files by name, type, or property
(REST search + local indexing of swept metadata), answered as structured results an
agent can act on.

## Others (unstudied ideas)

figma-handoff (dev-mode handoff packets per frame), figma-changes (diff a file
between two versions/branches), figma-tokens (tokens-only export in W3C design
tokens format). Add after the five above prove the pattern.

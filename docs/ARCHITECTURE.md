# Architecture

mcp-wire owns the shared engine (engine/mcp-wire.sh). Skills vendor their own copy via scripts/sync-engine.sh.

## Vendoring gap (finding J)

skills/figma-wire/scripts/figma-wire.sh has its own duplicated handshake (~lines 607-631) and does not vendor the engine.
skills/mcp-wire now ships scripts/mcp-wire.sh via sync-engine. Migration: refactor figma-wire to call the vendored engine instead of duplicating handshake logic. Do not edit skills/figma-wire in this repo; it is vendored from its own repository.

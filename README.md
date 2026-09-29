<div align="center">

# mcp-wire

**One bash engine that speaks MCP. Many skills that wire your agent to the world.**

[![ci](https://github.com/adhamhaithameid/mcp-wire/actions/workflows/ci.yml/badge.svg)](https://github.com/adhamhaithameid/mcp-wire/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![skills](https://img.shields.io/badge/skills-npx%20skills%20add-blue)](https://skills.sh)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-adhamhaithameid-yellow?logo=buymeacoffee)](https://www.buymeacoffee.com/adhamhaithameid)

MCP servers are everywhere, but consuming them still means writing a client. **mcp-wire**
is a full MCP client in one bash script — handshake, JSON-RPC, SSE parsing, text to
stdout, images to PNG — and the shared engine for a family of agent skills built on
top of it.

</div>

---

## The family

| Skill | What it wires into your agent | Repo | Install |
|---|---|---|---|
| **[figma-wire](https://github.com/adhamhaithameid/figma-wire)** | Figma — design context, screenshots, tokens, and a pixel-diff gate between the design and your build | [adhamhaithameid/figma-wire](https://github.com/adhamhaithameid/figma-wire) | `npm i -g figma-wire` (skill) · `npm i -g @adhamhaithameid/mcp-wire` (everything) |
| **[mcp-wire](skills/mcp-wire)** | the engine itself as a skill — call any MCP server from plain bash, from any agent | in this repo | `npm i -g @adhamhaithameid/mcp-wire` |
| *next skill — your idea here* | notion, linear, sheets, Jira… | *own repo — roadmap* | |

One engine, many skills: fix the engine once, and the release pipeline stamps the fix
into every skill. See [How the family works](#how-the-family-works).

## The engine

```bash
# install the CLI (bin: `mcp-wire`) — single file, no npm required
curl -fsSL https://raw.githubusercontent.com/adhamhaithameid/mcp-wire/main/engine/mcp-wire.sh -o /usr/local/bin/mcp-wire
chmod +x /usr/local/bin/mcp-wire

# what tools does this MCP server have?
engine/mcp-wire.sh https://mcp.figma.com/mcp list --header "Authorization: Bearer $T"

# invoke a tool — text to stdout, images to PNG
engine/mcp-wire.sh http://127.0.0.1:3845/mcp call get_screenshot '{"nodeId":"1:2"}' -o shot --allow-http

# raw JSON-RPC when you need full control
engine/mcp-wire.sh $URL raw '{"jsonrpc":"2.0","id":9,"method":"ping"}'
```

Full engine docs: [engine/README.md](engine/README.md). Requires bash, curl, jq —
macOS and Linux; on Windows use WSL. `--allow-http` is required for plain-http
targets so you never accidentally ship credentials to a stray endpoint.

## Skills

One npm package ships the whole family: `@adhamhaithameid/mcp-wire` installs both
CLIs (`mcp-wire` + `figma-wire`) and bundles every skill's `SKILL.md` for
skills-npm-style auto-discovery.

Each skill is a self-contained folder under [`skills/`](skills/) — SKILL.md, tests,
docs, everything — installable on its own. **[figma-wire](skills/figma-wire)** is the
first: wire any AI coding agent to Figma, repair broken MCP configs across 8 harnesses,
and validate implementations against the design with pixel diffs.

```bash
npm i -g @adhamhaithameid/mcp-wire && figma-wire doctor    # 30 seconds to a Figma-connected agent
```

## How the family works

Each skill lives in its **own repository** and is developed, tested, and released
independently; this repo is the **engine home and the family index**. Bash has no
linker, so sharing happens by vendoring at release time, never by runtime imports:

1. `engine/mcp-wire.sh` is the single source of truth for the engine.
2. Skill repos (e.g. [figma-wire](https://github.com/adhamhaithameid/figma-wire))
   reference the engine and develop against it.
3. `scripts/sync-skills.sh` stamps each skill's current tree into `skills/` here;
   `scripts/sync-engine.sh` stamps the engine into each skill package.
4. Tagging `v*` here runs every suite, publishes the family package (all skills),
   and creates the GitHub Release.

One engine commit → one sync → one release → every skill ships the fix, and every
installed skill stays fully self-contained.

## Development

```bash
bash engine/tests/run-tests.sh                    # engine suite (fake MCP server)
cd skills/figma-wire && bash tests/run-tests.sh   # skill suite (fake Dev Mode server)
```

Both are hermetic — no MCP server, no Figma, no network required. CI runs them on
Ubuntu and macOS.

## Contributing

Pick up a [good first issue](https://github.com/adhamhaithameid/mcp-wire/issues?q=is%3Aissue+label%3A%22good+first+issue%22)
or bring a new `x-wire` skill idea — new skills are folders that follow the figma-wire
shape, and the engine does the heavy lifting.

## Support

If mcp-wire saved you from writing an MCP client, a coffee is appreciated ☕

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-adhamhaithameid-yellow?logo=buymeacoffee)](https://www.buymeacoffee.com/adhamhaithameid)

## License

[MIT](LICENSE) © Adham Haitham

<div align="center">

# figma-wire

**Your AI agent finally sees your Figma designs.**

[![ci](https://github.com/adhamhaithameid/mcp-wire/actions/workflows/ci.yml/badge.svg)](https://github.com/adhamhaithameid/mcp-wire/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/figma-wire)](https://www.npmjs.com/package/figma-wire)
[![license](https://img.shields.io/npm/l/figma-wire)](LICENSE)
[![skills](https://img.shields.io/badge/skills-npx%20skills%20add-blue)](https://skills.sh)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-adhamhaithameid-yellow?logo=buymeacoffee)](https://www.buymeacoffee.com/adhamhaithameid)

One bash script wires your AI coding agent to the Figma Dev Mode MCP server, repairs
broken configs, and pulls design data from plain bash — no MCP client, no SDK, no API
token.

</div>

> **figma-wire is the first skill in the [mcp-wire](https://github.com/adhamhaithameid/mcp-wire) family** — a universal
> speak-MCP-from-plain-bash engine, shared across skills. The `call` and `diff`
> commands run on it; engine improvements land in every skill in the family.
>
> This repository is figma-wire's independent home. The family's other skills and the
> shared engine live in the [mcp-wire monorepo](https://github.com/adhamhaithameid/mcp-wire);
> the planned figma-* domain skills are mapped in [ROADMAP.md](ROADMAP.md).

---

## Install

figma-wire ships inside the **mcp-wire family package** — one install brings the
figma-wire CLI, the mcp-wire engine CLI, and every family skill.

**Using npm (Recommended)**

```bash
npm i -g @adhamhaithameid/mcp-wire   # installs BOTH CLIs: figma-wire + mcp-wire
figma-wire doctor                    # probes Figma + your agent's config in one shot
```

**Using the skills CLI** (installs both family skills from the monorepo)

```bash
npx skills add adhamhaithameid/mcp-wire
```

**Using skills-npm (auto-discovery from npm installs)**

```bash
npm i -D skills-npm
npx skills-npm setup      # symlinks the bundled skill into supported agents
```

**Using the script**

```bash
git clone https://github.com/adhamhaithameid/figma-wire
bash install.sh            # runs the full test suite first, then installs
```

Requires bash, curl, jq. macOS and Linux both work; on Windows, use WSL.

## 30-second setup

1. Open the **Figma desktop app** → **Preferences** → **Enable Dev Mode MCP Server**.
2. Run `figma-wire doctor`. It finds the server, detects which agent you use, and wires
   the config file — probing before it writes, never editing anything it hasn't verified.
3. Restart your agent session.

Bam — the Figma tools are in your agent's toolset.

## Why figma-wire exists

**Problem: your agent can't see the design.** It guesses the spacing, invents the
colors, and ships something "close enough."
**Fix:** figma-wire connects your agent to the real thing — structured design context,
exact variables, and pixel screenshots, straight from Figma's own Dev Mode server
already running on your machine.

**Problem: MCP config is fiddly.** Eight agents, eight config formats, one server on a
port that sometimes moves.
**Fix:** `doctor` probes everything and writes the right file in the right shape;
`doctor --fix` re-wires it when the port drifts. Every write is atomic — a corrupt
config stays corrupt-free.

**Problem: your harness has no MCP support.**
**Fix:** the `call` command *is* an MCP client — full handshake, JSON-RPC, SSE parsing
— in one bash script. It works from CI, cron jobs, and agents that have never heard
of MCP.

## What you get

| Command | What it does |
|---|---|
| `figma-wire doctor` | Probes the Figma server, your harness config, and the remote server; prints the exact fix for whatever's wrong (`--json` for machines, `--fix` to auto-repair) |
| `figma-wire use 3845` | Verifies a Dev Mode server, then wires it into your agent's config — probe-before-write, always |
| `figma-wire link <share-url>` | Turns a Figma link into the `fileKey` + `nodeId` your tools need |
| `figma-wire call get_screenshot "12:34" -o hero` | Runs any of Figma's 6 MCP tools from plain bash — images land as PNG |
| `figma-wire diff "12:34" http://localhost:3000` | Screenshots the design and your implementation, pixel-diffs them, PASS or FAIL |
| `figma-wire remote token <TOKEN>` / `remote off` | Authenticate — or permanently silence — the remote mcp.figma.com server |
| `figma-wire fetch` | REST fallback for headless machines (needs a Figma token) |

## `diff`: the 1:1 check, in one command

The step every design-to-code workflow skips — "does the build actually match the
design?" — becomes a command with an exit code you can gate CI on:

```bash
figma-wire diff "1838:2901" https://my-site.pages.dev --viewport 402x874 --threshold 5
```

```text
figma : figma-diff-20260920-figma-1.png  (402x874)
page  : figma-diff-20260920-page.png
diff  : figma-diff-20260920-diff.png
side  : figma-diff-20260920-side.png
mismatched pixels: 285519/351348 (81.26%)
[FAIL] 81.26% mismatched, exceeds the 5% threshold
```

If the design frame and your viewport don't match, `diff` doesn't guess — it tells you
the exact `--viewport` to use (or `--resize` force-fits). Red pixels in the diff mark
every place your implementation drifts from the design.

## Works with your agent — and everyone else's

| Harness | Status |
|---|---|
| ZCode, Claude Code, Cursor, Windsurf, Gemini CLI, VS Code, Codex | auto-detected, wired automatically |
| Anything else (opencode, custom tools) | generic `~/.agents/mcp.json` adapter |
| Agents with **no** MCP support at all | `call` — plain bash, no harness required |

`figma-wire use <port> --harness all` wires every installed harness at once.

## How it works (the honest 30 seconds)

Figma's desktop app has shipped an MCP server since 2025 — `127.0.0.1:3845`, no auth,
six tools (`get_design_context`, `get_screenshot`, `get_metadata`, `get_variable_defs`,
`get_motion_context`, `get_figjam`). Almost nobody uses it, because every agent stores
its config differently and nothing connects them. figma-wire is that connector: it
**probes before it writes** (never edits a config unless the server answered), writes
atomically, speaks the MCP protocol itself when your harness can't, and ships **100
hermetic tests** (a fake Dev Mode server + sandboxed configs — runs on any machine,
Figma not required, CI on Ubuntu and macOS).

Your designs never leave your machine. The local server needs no token, and figma-wire
stores nothing beyond the last-used port.

## FAQ

**Do I need a Figma API token?** No — the local Dev Mode server needs none. A token is
only for the optional remote `mcp.figma.com` server or the REST fallback.

**My Figma tools disappeared after a Figma update.** The server probably moved ports.
`figma-wire doctor` scans for it; `doctor --fix` re-wires every harness.

**Which file does it edit?** Only your harness's own config (`~/.zcode/cli/config.json`,
`~/.claude.json`, `~/.cursor/mcp.json`, …), and only the `figma-local` /
`figma` entries inside it. Everything else is untouched.

**Can it corrupt my agent config?** It rewrites atomically via temp-file-and-rename,
and refuses to touch unparseable files. There's a test that feeds it garbage config and
asserts nothing was written.

**Windows?** WSL, please.

## Contributing

Small script, big test suite — keep both. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the ground rules (probe-before-write, atomic
edits, hermetic tests) and pick up a
[good first issue](https://github.com/adhamhaithameid/figma-wire/issues?q=is%3Aissue+label%3A%22good+first+issue%22).

## Support

If figma-wire saved you some friction, a coffee is appreciated ☕

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-adhamhaithameid-yellow?logo=buymeacoffee)](https://www.buymeacoffee.com/adhamhaithameid)

## License

[MIT](LICENSE) © Adham Haitham

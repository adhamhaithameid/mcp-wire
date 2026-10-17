# Research: what developers actually ask for from bash-first MCP clients

**Date:** 2026-09-29 · **Method:** primary-source mining — GitHub issue trackers
(feature requests, open AND closed, sorted by reactions), Hacker News via the
Algolia API (stories + comment threads), Reddit threads found via web search
(direct JSON API was bot-blocked), and the agent-skills ecosystem
(vercel-labs/skills = skills.sh). Issue-frequency counts are GitHub search
`total_count` over open+closed issues, measured 2026-09-29.

## Sources mined

| Source | What was looked at |
|---|---|
| [punkpeye/mcp-remote](https://github.com/punkpeye/mcp-remote) (1.6k stars) | reactions-ranked issues, open+closed; term counts: **oauth 111, auth 99, sse 70, header 50, stdio 33, session 33, windows 28, timeout 27** |
| modelcontextprotocol org | spec (#292, #493, SEP-1442, SEP-991, SEP-1649), inspector (oauth 259, header 215, stdio 149, timeout 94 issues), servers (#64), typescript-sdk (#245), registry |
| CLI-client competitors | [apify/mcpc](https://github.com/apify/mcpc) (936★), [philschmid/mcp-cli](https://github.com/philschmid/mcp-cli), [lydakis/mcpx](https://github.com/lydakis/mcpx), [arcadeai-labs/mcpx](https://github.com/arcadeai-labs/mcpx), [turlockmike/murl](https://github.com/turlockmike/murl), anukchat/mcpwire (0 issues — no signal) |
| Hacker News | threads: [MCP (872 pts)](https://news.ycombinator.com/item?id=42237424), [MCP is dead?](https://news.ycombinator.com/item?id=48332907), [When does MCP make sense vs CLI?](https://news.ycombinator.com/item?id=47209139), [Code Mode](https://news.ycombinator.com/item?id=45399204), [Stateless MCP](https://news.ycombinator.com/item?id=49180339), [mcpc](https://news.ycombinator.com/item?id=46513163), [Murl](https://news.ycombinator.com/item?id=47100861), [mcpx](https://news.ycombinator.com/item?id=47369917) + Algolia comment search ("MCP curl", "MCP stdio", "MCP command line") |
| Reddit | [CLI > MCP? (r/mcp)](https://www.reddit.com/r/mcp/comments/1o8w5wq/cli_mcp/), [why bother with MCPs if I can call anything via CLI? (r/LocalLLaMA)](https://www.reddit.com/r/LocalLLaMA/comments/1s41ltp/please_explain_why_bothering_with_mcps_if_i_can/), [Why use MCP in subagents when they can use CLI? (r/ClaudeAI)](https://www.reddit.com/r/ClaudeAI/comments/1pm0bu4/why_use_mcp_in_subagents_when_they_can_use_cli/), [MCP: becoming irrelevant? (r/ClaudeAI)](https://www.reddit.com/r/ClaudeAI/comments/1no958n/mcp_becoming_irrelevant/) |
| skills ecosystem | [vercel-labs/skills](https://github.com/vercel-labs/skills) reactions-ranked issues; skills.sh listing-request issues; [evantahler's "curl for MCP" design post](https://www.evantahler.com/blog/post/2026-03-13-curl-for-mcp) |

**Headline:** the "curl for MCP" CLI-client space has been independently built
at least six times in 12 months (mcpc, mcpx ×2, murl, mcp-cli, mcp-tools…) —
demand is real and recurring. Across every source, two themes dominate:
**auth is the #1 pain** (it is literally why mcp-remote exists), and
**JSON-out composable with jq/pipes/exit codes** is the #1 praised abstraction.
Every other ask clusters under transport robustness, output shaping, and
harness-packaging.

---

## Bucket 1 — ENGINE features (ranked by demand)

### 1. Auth: OAuth handled for you; at minimum, auth profiles + client_credentials
**How often:** the single most-demanded thing. mcp-remote: 111 oauth + 99 auth
issues; inspector: 259 oauth issues. The top-10 reactions-ranked issues on
mcp-remote are nearly all auth (token loops, expired tokens, callback ports).
apify/mcpc's README leads with "Full OAuth 2.1 support with CIMD and DCR, OS
keychain".

**Strongest evidence:**
- [mcp-remote#91 — Revoked tokens cause infinite auth loop](https://github.com/punkpeye/mcp-remote/issues/91) (6 reactions, closed) and [#273 — expires_at not stored, silent token expiry](https://github.com/punkpeye/mcp-remote/issues/273)
- [mcp-remote#350 — Support OAuth 2.0 client_credentials for non-interactive remote servers](https://github.com/punkpeye/mcp-remote/issues/350) — the CI/scripting case, exactly mcp-wire's audience
- HN [When does MCP make sense vs CLI?](https://news.ycombinator.com/item?id=47209139): skills+curl obviate local MCP "until you consider remote MCPs & OAuth, which seem unaddressed and core in practice"
- apify/mcpc#3/#140/#174/#271 — OAuth discovery/token-refresh edge cases even for the leader

**Difficulty for mcp-wire (bash+curl+jq):** split it.
*Easy:* named auth profiles (`~/.config/mcp-wire/config` → `--profile figma`
expands headers) and OAuth **client_credentials** (one curl POST + token cache
with expiry) — high value for CI/scripts. *Hard:* full browser PKCE flow with a
loopback callback listener in pure bash (needs a local socket listener + token
storage; no OS keychain). Recommend profiles + client_credentials for v0.2,
defer interactive PKCE.

### 2. Sessions: handle stateful servers, or embrace stateless explicitly
**How often:** mcp-remote 'session' 33 issues; it is a headline feature of
apify/mcpc ("Persistent sessions — Keep connections to multiple servers alive…
whether the server protocol is stateful or stateless").

**Strongest evidence:**
- [philschmid/mcp-cli#21 — Stateful servers like chrome-devtools don't work with mcp-cli](https://github.com/philschmid/mcp-cli/issues/21) — per-invocation CLIs break stateful servers
- [mcp-remote#106 — Session reset upon server restart](https://github.com/punkpeye/mcp-remote/issues/106) (6 reactions)
- [SEP-1442: Make MCP Stateless (by default)](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1442) (71 reactions) + [#493 — stateless request/response options](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/493) (64 reactions) — the spec is moving toward mcp-wire's model, but plenty of deployed servers (chrome-devtools, playwright) are still stateful

**Difficulty:** medium — cache `mcp-session-id` per server URL in a tmp file,
reuse on next invocation, re-handshake on stale-session errors. This is the
difference between "works with figma" and "works with chrome-devtools".

### 3. Transport robustness: SSE fallback, protocol-version negotiation, retry
**How often:** mcp-remote 'sse' 70 issues; inspector transport hangs are
recurring top-reacted bugs.

**Strongest evidence:**
- [mcp-remote#157 — Symbol(headers list) error when falling back to SSE transport](https://github.com/punkpeye/mcp-remote/issues/157) (18 reactions — highest on the repo)
- [mcp-remote#215 — HTTP 406 because Accept header not sent correctly](https://github.com/punkpeye/mcp-remote/issues/215) and [#296 — http-first initialize hangs 60s](https://github.com/punkpeye/mcp-remote/issues/296)
- [inspector#1858 — v2 hangs silently on streamable-http](https://github.com/modelcontextprotocol/inspector/issues/1858) (18 reactions)

**Difficulty:** medium. mcp-wire hardcodes `2025-03-26` and *requires* an
`mcp-session-id` ([engine/mcp-wire.sh:52](../../engine/mcp-wire.sh)) —
stateless servers that don't issue sessions fail today. Cheap wins: accept
absent session id, `--protocol-version` flag, automatic streamable-HTTP→SSE
fallback (curl -N parse loop). Retries with backoff: easy.

### 4. Output shaping: `--jq`, strict JSON mode, exit codes, pipe-friendliness
**How often:** mentioned in every "curl for MCP" launch and every CLI-vs-MCP
thread; already on the mcp-wire roadmap.

**Strongest evidence:**
- HN [Show HN: Murl — Curl for MCP Servers](https://news.ycombinator.com/item?id=47100861): "Reducing JSON-RPC ceremony and making tool invocation **composable with jq, pipes, and exit codes** feels like the right abstraction layer"
- apify/mcpc README: "**Code mode** — JSON output composes with `jq`, `xargs`, and shell pipelines for MCP workflows as shell scripts"
- [philschmid/mcp-cli#23 — Output truncated at 65536 bytes when piped](https://github.com/philschmid/mcp-cli/issues/23) and [#17 — stderr noise unless `-v`](https://github.com/philschmid/mcp-cli/issues/17) — pipe-hygiene bugs are real
- HN [MCP is dead?](https://news.ycombinator.com/item?id=48332907): harness should "dump the json into a file and just say to the model: your data is in /tmp/foo.json" — big-result-to-file is a wanted behavior

**Difficulty:** trivial→easy. `--jq` is a `jq -r` passthrough; add a
`--json` flag (raw JSON-RPC result to stdout, human text to stderr) and keep
images→PNG. Biggest bang-for-buck item on this list.

### 5. stdio transport
**How often:** inspector 'stdio' 149 issues; mcp-remote 'stdio' 33; every
competing client ships stdio; most MCP servers in the wild are stdio/npx
(servers repo #64 below is about exactly that pain).

**Strongest evidence:**
- [apify/mcpc#163 — Add --command/--arg/--env flags to connect stdio servers without a config file](https://github.com/apify/mcpc/issues/163) — stdio as first-class CLI UX
- [modelcontextprotocol/servers#64 — MCP Servers Don't Work with NVM](https://github.com/modelcontextprotocol/servers/issues/64) (182 reactions — the most-reacted issue in the servers repo; local stdio servers are mainstream and fragile)
- mcp-wire roadmap already names it; philschmid/mcp-cli ships stdio+HTTP from day one

**Difficulty:** medium — bash can spawn a server and do Content-Length-framed
JSON-RPC over pipes for synchronous call/response; notifications and
backpressure are where it gets hard (cf. [mcp-remote#366 — stdio backpressure](https://github.com/punkpeye/mcp-remote/issues/366)). Worth it: instantly doubles the server ecosystem mcp-wire can reach.

### 6. Debuggability: `-v` verbose mode (headers, JSON-RPC, timing), honest errors
**How often:** recurring feature request across all CLI clients.

**Strongest evidence:**
- [arcadeai-labs/mcpx design post](https://www.evantahler.com/blog/post/2026-03-13-curl-for-mcp): `-v` "shows HTTP headers, JSON-RPC messages, and round-trip timing so failures are diagnosable"
- [philschmid/mcp-cli#17 — only show STDERR with -v or -debug](https://github.com/philschmid/mcp-cli/issues/17)
- [inspector#757 — Descriptive details for Authorization flow errors](https://github.com/modelcontextprotocol/inspector/issues/757)

**Difficulty:** easy. mcp-wire currently `2>/dev/null`s curl output and fails
with one-liners ([engine/mcp-wire.sh:50](../../engine/mcp-wire.sh)); a `-v`
flag that surfaces HTTP status, session id, and raw SSE is cheap and turns
"doesn't work" bug reports into self-service.

### 7. Full protocol surface: tool pagination, resources/, prompts/get
**How often:** steady trickle rather than flood — but the pagination one is a
silent-data-loss bug class.

**Strongest evidence:**
- [philschmid/mcp-cli#206 — Some tools are missing when connecting to servers with many tools](https://github.com/philschmid/mcp-cli/issues/206) (no pagination cursor loop)
- apify/mcpc README: "Full MCP support — Tools, prompts, resources, async tasks…"; mcp-wire roadmap already lists resources/prompts
- [inspector#552 — outputSchema JSON Schema support](https://github.com/modelcontextprotocol/inspector/issues/552) (15 reactions) — structured tool output matters

**Difficulty:** easy. `tools/list` pagination loop (repeat with `cursor` until
exhausted) + `resources list/read`, `prompts list/get` as thin wrappers over
the existing `raw` path. Note mcp-wire's `list` will silently truncate on
paginated servers today — same bug class as mcp-cli#206.

### 8. Long-running tools: streaming/progress, async tasks, cancellation
**How often:** smaller but growing with the 2026-07-28 spec (tasks).

**Strongest evidence:**
- [typescript-sdk#245 — client times out after 60s ignoring timeout option](https://github.com/modelcontextprotocol/typescript-sdk/issues/245) (17 reactions)
- [mcp-remote#226 — SSE transport hangs indefinitely on long-running requests](https://github.com/punkpeye/mcp-remote/issues/226)
- apify/mcpc#168/#169/#181 — `tasks-result`, Ctrl+C task hints, async polling UX

**Difficulty:** hard in bash (incremental SSE consumption, keep-alive, task
polling loops). Defer; `--timeout` already covers the basic case.

### 9. Config file / named servers
**How often:** open spec ask + competitor configs.

**Strongest evidence:**
- [modelcontextprotocol#292 — Define a Standard MCP Configuration Schema](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/292) (50 reactions, open)
- [philschmid/mcp-cli#260 — {file:path} substitution for secrets](https://github.com/philschmid/mcp-cli/issues/260), [#217 — info command leaks secrets](https://github.com/philschmid/mcp-cli/issues/217), [#28 — merge of MCP configuration files](https://github.com/philschmid/mcp-cli/issues/28)
- mcpx `mcpx add <name> --url <url>` pattern

**Difficulty:** easy — a sourceable `~/.config/mcp-wire/config` mapping
name → url + headers (`mcp-wire figma list`). Already flagged on the map
(#5) as hanging on engine-scope.

### 10. Platform coverage (Windows/WSL, arm64)
**How often:** mcp-remote 'windows' 28 issues; mcp-cli#24 (Linux arm64).

**Strongest evidence:** [mcp-remote#316 — Windows OAuth callback listener failure](https://github.com/punkpeye/mcp-remote/issues/316), [mcp-cli#24 — Not working on Linux arm64](https://github.com/philschmid/mcp-cli/issues/24)

**Difficulty:** for mcp-wire: docs-only (document WSL; jq/curl exist on arm64).
Native Windows bash port is out of scope per the family's "bash + npm + GitHub"
boundary.

---

## Bucket 2 — DISTRIBUTION / PACKAGING (ranked)

### 1. Zero-runtime, one-line install — "no node" is a feature
**How often:** the most-reacted distribution complaint in the whole MCP space.

**Strongest evidence:**
- [modelcontextprotocol/servers#64 — MCP Servers Don't Work with NVM](https://github.com/modelcontextprotocol/servers/issues/64) (182 reactions) — node-version hell is the #1 pain of the npx-stdio ecosystem
- [inspector#326 — `mcp-inspector: command not found` after upgrade](https://github.com/modelcontextprotocol/inspector/issues/326) (20) and [#873 — phantom dependencies](https://github.com/modelcontextprotocol/inspector/issues/873) (12)
- Distribution evidence: [turlockmike/murl](https://github.com/turlockmike/murl) ships a Homebrew tap; mcpx ships binary + npm + curl script; [evantahler post](https://www.evantahler.com/blog/post/2026-03-13-curl-for-mcp) — "agents already know curl, git, docker, npm"

**Difficulty:** low. mcp-wire already has the two winning artifacts (single-file
curl install; npm two-tier package). Add a Homebrew tap + keep the engine
dependency-free (bash/curl/jq only). This is the moat vs. node-based mcpc.

### 2. Agent-harness / skills-ecosystem compatibility
**How often:** vercel-labs/skills issue tracker is dominated by it — install
paths, symlinks, lockfiles, versioning.

**Strongest evidence:**
- [vercel-labs/skills#744 — `npx skills add` doesn't create symlinks in ~/.claude/skills](https://github.com/vercel-labs/skills/issues/744) (37 reactions), [#693 — Claude Code cannot read globally installed skills](https://github.com/vercel-labs/skills/issues/693) (25), [#403](https://github.com/vercel-labs/skills/issues/403) (20), [#421](https://github.com/vercel-labs/skills/issues/421) (18), [#1045](https://github.com/vercel-labs/skills/issues/1045) (12) — per-harness path correctness is the top failure mode
- [#283 — skills install/sync from lock file](https://github.com/vercel-labs/skills/issues/283) (56), [#549 — npm-ci-equivalent restore](https://github.com/vercel-labs/skills/issues/549) (47), [#11 — RFC: Versioning](https://github.com/vercel-labs/skills/issues/11) (27) — consumers want deterministic, versioned installs
- [#381 — Official support for private skills](https://github.com/vercel-labs/skills/issues/381) (82) — teams want this in private repos

**Difficulty:** low-medium for mcp-wire: verify `npx skills add
adhamhaithameid/mcp-wire` lands correctly across Claude Code / Cursor / Codex;
keep the vendored-engine version stamp auditable (sync scripts already do
this); document the family-package ↔ standalone-skill version relationship
(also flagged on map #5).

### 3. Discovery: directory listings (skills.sh, MCP registry, server cards)
**How often:** a steady stream of "please index me" issues on skills.sh; the
registry spec work exists for exactly this.

**Strongest evidence:**
- skills.sh index requests, e.g. [vercel-labs/skills#2256 — repo resolves via `add` but never shows in the directory](https://github.com/vercel-labs/skills/issues/2256), [#2289 — reindex after rename](https://github.com/vercel-labs/skills/issues/2289)
- [SEP-1649: MCP Server Cards — HTTP discovery via .well-known](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1649) (19 reactions) — machine-readable discovery is becoming spec
- [modelcontextprotocol/registry#494 — relax name-based validation](https://github.com/modelcontextprotocol/registry/issues/494) — registry onboarding friction

**Difficulty:** low — submit mcp-wire/figma-wire to skills.sh, the MCP registry
(server.json), awesome-mcp lists. Pure PR work.

### 4. Docs that teach agents (and their humans) the pattern
**How often:** constant subtext in HN/Reddit debates about context cost.

**Strongest evidence:**
- HN [MCP: An (Accidentally) Universal Plugin System](https://news.ycombinator.com/item?id=44411118): "The official MCP documentation completely fails at explaining how it works" — docs gaps push people to whatever has a great README
- [Saasufy skills](https://news.ycombinator.com/item?id=48789596): shipping curl commands inside skill markdown "works great… a single markdown file" — the skill+CLI pattern is validated
- HN [MCP is dead?](https://news.ycombinator.com/item?id=48332907): CLIs need discoverable help ("--short-descr") because context is the scarce resource — SKILL.md quality is the interface

**Difficulty:** low — mcp-wire's README/engine docs are already strong; add
per-service recipes (figma-wire pattern generalized: notion-wire, linear-wire)
and make `list` output agent-grep-friendly.

### 5. Positioning: remote+OAuth is where MCP-holding-CLIs keep value
**How often:** the through-line of every CLI-vs-MCP debate.

**Strongest evidence:** HN [When does MCP make sense vs CLI?](https://news.ycombinator.com/item?id=47209139) — skills obviate local MCP "until you consider remote MCPs & OAuth"; [Apideck thread](https://news.ycombinator.com/item?id=47407676) — "where MCP comes in handy is mostly distribution"; [Cloudflare Code Mode](https://news.ycombinator.com/item?id=45399204) — agents chaining MCP calls via generated code/scripts is a validated mode.

**Difficulty:** messaging only. mcp-wire's pitch writes itself: the OAuth'd
remote-MCP bridge that works from any agent's Bash tool — no node, no SDK.

---

## What we did NOT find demand for
- **WebSockets transport** (SEP-1288 closed; niche vs. HTTP+SSE) — skip.
- **Payments/x402** — only one competitor, experimental — skip.
- **GUI/TUI clients** — the family's own out-of-scope boundary matches the market.
- **Elicitation, sampling, roots** — only relevant once resources/prompts land.

## Suggested engine-v0.2 shape (from the evidence)
`--jq`/`--json` + `-v` + session cache + protocol-version flag + retries +
auth profiles (+ client_credentials) + tools pagination. Everything on that
line is easy/medium in bash and maps 1:1 onto a demonstrated demand item;
stdio transport and interactive OAuth are the two big-ticket follow-ons.

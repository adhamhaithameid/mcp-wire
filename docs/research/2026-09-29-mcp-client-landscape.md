# Research: MCP client CLI landscape (competitors & gaps)

- **Ticket:** adhamhaithameid/mcp-wire#6
- **Date:** 2026-09-29
- **Method:** primary sources only — npm registry (`npm view`, api.npmjs.org downloads), GitHub API (`gh api`), official READMEs/docs. Download window: 2026-09-22 → 2026-09-28. Stars/activity captured same day.
- **Sibling research:** [2026-09-29-user-needs.md](./2026-09-29-user-needs.md) (user-needs side, issue #7)

## Why this matters

mcp-wire is a zero-dependency bash MCP client (handshake → JSON-RPC → SSE parsing, text→stdout,
images→PNG) distributed as agent skills via the npm family package `@adhamhaithameid/mcp-wire`.
This document maps who else lets a human or an agent **call MCP tools from a terminal or script**,
what each owns, where each is node/python-dependent, and what whitespace remains.

Also resolves the name question: **`mcpwire`** (no dash) on npm belongs to an effectively-abandoned
TypeScript SDK wrapper — 0 weekly downloads, GitHub repo deleted (404), last publish 2026-03-18.
The unscoped `mcp-wire` name is verified **unregistered** (registry 404 on 2026-09-29) but sits
directly next to that dead package; the scoped `@adhamhaithameid/mcp-wire` distribution avoids
the collision entirely.

---

## 1. The players

### mcpwire (npm) — the name squatter, not a real competitor

| | |
|---|---|
| What | TypeScript library + tiny CLI wrapping the official MCP SDK: `connect(url)` → `server.callTool(...)`. Auto-detects Streamable HTTP vs SSE; `connectStdio()` for local servers; converts tool schemas to OpenAI/Anthropic formats; `discover()` reads Claude Desktop/Cursor configs. |
| Transports | Streamable HTTP + auto SSE detection; stdio. No session cache. |
| Auth | None documented. |
| Output | Programmatic API (JS objects); bin `mcpwire` exists but is undocumented in the README. No jq/images/pagination story. |
| Install base | **0 weekly downloads.** GitHub repo `ctonneslan/mcpwire` **deleted (404)**. |
| Activity | Last publish 2026-03-18 (v0.4.0). Dead. |
| License / runtime | MIT. Node required (depends on `@modelcontextprotocol/sdk`); no `engines` field (built on Node 22). |
| Positioning | "The simplest way to connect to MCP servers" — a 2-line JS SDK wrapper, not a shell tool. Its own README confuses itself with "mcpx" (copy-paste artifact). Sole relevance to mcp-wire: it blocks/crowds the unscoped name. |

### mcp-remote (punkpeye) — the OAuth bridge incumbent

| | |
|---|---|
| What | stdio↔remote **proxy** so stdio-only MCP clients (Claude Desktop, Cursor, Windsurf) can reach remote servers with OAuth. You don't call tools with it — your MCP client does, through it. |
| Transports | Streamable HTTP and SSE with configurable strategies: `--transport http-first` (default; falls back to SSE on 404), `sse-first` (falls back on 405), `http-only`, `sse-only`. Holds one live connection while the client runs; OAuth session/token cache in `~/.mcp-auth/`. |
| Auth | **Best-in-class OAuth**: dynamic client registration, PKCE, RFC 8707 resource indicators (`--resource`), `--authorize-param`, static client metadata, stable per-server callback ports (3335–49150), `--auth-timeout`, debug logs. Plus `--header` and `--header-file` for static credentials. |
| Output | None for humans/scripts — it bridges stdio to the MCP client. Not a terminal tool-caller at all. |
| Install base | **891,130 weekly downloads** (dominant in the whole ecosystem). 1,608 stars. |
| Activity | v0.14.3 published 2026-09-21. Very active. |
| License / runtime | MIT. Node via `npx mcp-remote` (no `engines` field). 2 MB unpacked, 4 runtime deps. |
| Positioning | "As soon as your client supports remote servers you can remove it" — a temporary shim for MCP clients, not a shell/agent tool. Owns the OAuth-bridge niche outright. |

### @modelcontextprotocol/inspector — the official, now scriptable

| | |
|---|---|
| What | Official testing/debugging tool. v2 is a launcher with three clients: **web UI**, **TUI (Ink)**, and a **scriptable CLI** (`mcp-inspector --cli`) explicitly aimed at "automation, CI, and fast agent feedback loops" — docs include a connect→list→call→assert smoke-testing recipe with `--format json` + `jq` and an exit-code map. |
| Transports | stdio spawn, SSE, Streamable HTTP (`--transport http`); one-shot connect/run/disconnect per invocation (no persistent session cache). |
| Auth | OAuth with persist backend (`oauth.json` / `MCP_STORAGE_DIR`), OS keychain via `@napi-rs/keyring` (plaintext file fallback documented for headless Linux), custom `--header`, per-server catalog settings, HTTP(S)_PROXY support incl. OAuth discovery. |
| Output | CLI: `--format json` for jq pipelines, structured exit codes, `--method tools/list|tools/call|resources/list|...`, `--tool-arg key=value`. Web/TUI are interactive. No image-to-file story, no pagination automation documented. |
| Install base | **375,911 weekly downloads.** 10,983 stars. |
| Activity | v2.8.0 published 2026-09-23; repo pushed 2026-09-29. Very active — this is the direct official encroachment into "call tools from a shell". |
| License / runtime | MIT → Apache-2.0 transition. **Node >= 22.19** (steep floor); heavy dependency tree. |
| Positioning | The canonical debugger for MCP servers; since v2 it also wants to be the CI/agent smoke-test tool. Scriptable but heavyweight, one-shot, and debug-first rather than workflow-first. |

### @smithery/cli — the registry/app-store play

| | |
|---|---|
| What | Installer and registry client for Smithery (acquired by Arcade — repo `smithery-ai/cli` redirects to `arcadeai-labs/smithery-cli`). `smithery mcp add` creates **Smithery-hosted connections**; `smithery tool list/get/call` then calls tools through those connections. Also distributes skills (`npx skills add ...`) and publishes servers/bundles. |
| Transports | Indirect — calls go via Smithery's hosted connections, not arbitrary direct endpoints you own. |
| Auth | Smithery account OAuth (`auth login/whoami`), mintable service tokens with policies. |
| Output | Plain listing/call output; no jq mode, no image/file handling documented. |
| Install base | **6,972 weekly downloads.** 840 stars (redirected repo). |
| Activity | v4.11.1 published 2026-04-30; repo pushed 2026-05-31. |
| License / runtime | **AGPL-3.0** (contagious for any embedding). **Node >= 20.** |
| Positioning | App store + control plane for MCP: discovery, install, hosted calling, publishing. Lock-in to the Smithery/Arcade platform; not for direct endpoints or offline use. |

### apify/mcpc (@apify/mcpc) — the heavyweight; direct competitor

| | |
|---|---|
| What | "Universal MCP CLI client": maps every MCP operation to shell commands, explicitly built so AI agents drive MCP through one `Bash()` call. Tools, prompts, resources, async **tasks**, **skills-list/get**, notifications, logging. Also: progressive tool discovery, cross-session grep, an AI-sandbox proxy mode (shields credentials from generated code), experimental x402 payments. **The only tool whose README articulates the same thesis as mcp-wire ("CLI is the local interface between agents and MCP").** |
| Transports | stdio + Streamable HTTP (stateful and stateless). **No legacy SSE fallback.** **Persistent named `@sessions`** kept alive in parallel, restartable; auto-reconnect. **Automatic pagination** (fetches all pages via `nextCursor`). |
| Auth | **Full OAuth 2.1 with CIMD and DCR**, `login/logout`, named `--profile`s, OS keychain (Secret Service; `~/.mcpc/credentials.json` fallback on headless). |
| Output | `--json` mode composes with jq/xargs; human mode with truncation (`--max-chars`); resources read supports `-o file`/`--raw`; error messages with retry suggestions. Tool-call **images: no automatic PNG export** documented. |
| Install base | **4,113 weekly downloads.** 936 stars. |
| Activity | v0.7.0 published 2026-09-23; repo pushed 2026-09-24. Very active, Apify-backed. |
| License / runtime | Apache-2.0. **Node >= 22.12** (or Bun; Homebrew formula bundles its own Node). Keychain/`libsecret` caveats on headless Linux. |
| Positioning | "Any agent with shell access gets full MCP support" — the best-funded, most complete expression of the bash-first thesis. Its cost: a large Node app, new Node floor, keychain dependencies. Its own "Related work" table is a decent map of this landscape. |

### philschmid/mcp-cli — the minimal agent caller (stale)

| | |
|---|---|
| What | Lightweight Bun CLI for agents: `mcp-cli call <server> <tool> '<json>'`, driven by a `mcp_servers.json` config (Claude Desktop format). Lazy-spawn daemon keeps connections warm (60 s idle), per-server tool filtering, server instructions display. |
| Transports | stdio + HTTP (streamable) from config. Daemon-held connection pool ≈ session cache (single machine, idle-timed). |
| Auth | None documented (env vars for stdio servers only). No OAuth. |
| Output | JSON output designed for `jq` piping; stdout results / stderr errors; `info`, `grep` commands. No image handling. |
| Install base | 1,276 stars. Not on npm — installed via `curl …/install.sh | bash` (Bun-compiled single binary) or `bun install -g` from GitHub. |
| Activity | **Stale: last push 2026-02-05.** |
| License / runtime | MIT. Runtime: self-contained binary (no Node at runtime), but building/updating requires Bun. |
| Positioning | "Agent-optimized minimal MCP caller" — proved demand, then went quiet. The most direct prior art for mcp-wire's agent-first framing; its inactivity is an opening. |

### lydakis/mcpx — Go binary, CLI-ification + skill distribution (watch closely)

| | |
|---|---|
| What | "Turn MCP servers into composable CLIs": every tool becomes a subcommand (`mcpx <server> <tool> --flag`), with **schema-aware `--help` per tool**. Config import adapters from Claude/Cursor/Codex; `doctor`. **`mcpx skill install` ships an agent skill** with links for Claude/Kiro/OpenClaw plus managed guidance blocks in AGENTS files — the same distribution idea as mcp-wire's skill family. |
| Transports | stdio (command entries in `config.toml`) + direct HTTP endpoints (`mcpx https://…/mcp [tool …]`). SSE fallback/session behavior not documented. |
| Auth | OAuth with OS credential store (`mcpx add --oauth`, `auth login/status`), CIMD support; deliberately does **not** auto-launch remote auth URLs. |
| Output | Tool output passes through unchanged (text or JSON) for `jq` piping. No image handling. |
| Install base | **53 stars.** |
| Activity | Pushed 2026-09-29 — active. |
| License / runtime | MIT. **Go binary via Homebrew cask — no Node/Python needed.** |
| Positioning | npm-CLI-ification of MCP servers + day-one agent-skill distribution. Tiny adoption, but it is the only other player combining (a) no-runtime binary, (b) skill-based agent distribution, (c) active development. |

### turlockmike/murl — literally "curl for MCP" (stale, tiny)

| | |
|---|---|
| What | Curl-like CLI mapping REST-ish URLs to MCP methods: `murl <url>/tools/<name> -d key=value`. NDJSON output, structured errors to stderr, semantic exit codes — explicitly "built for agents to call from shell". |
| Transports | Full Streamable HTTP (sends `Accept: application/json, text/event-stream`, handles JSON and SSE responses). **No native stdio** — defers to external `mcp-proxy` (ephemeral SSE sessions per invocation). Ephemeral per-call sessions; no session cache. |
| Auth | OAuth 2.0 with DCR + PKCE, automatic token cache, `--login`/`--no-auth`; `-H` custom headers. |
| Output | NDJSON (one JSON per line) for jq; `-v` pretty/debug; agent-mode docs for exit codes. No image handling. |
| Install base | **19 stars.** PyPI `mcp-curl` (downloads negligible). |
| Activity | **Stale: last push 2026-02-21.** |
| License / runtime | MIT. **Python >= 3.10** (Homebrew formula, pip, or curl install script). |
| Positioning | The purest "curl, but for MCP" — closest conceptual overlap with mcp-wire, implemented in Python and gone quiet. |

### Also scanned (not primary competitors)

- **@wong2/mcp-cli** — CLI/TUI inspector, npx-based. 39,030 weekly downloads, 446 stars, GPL-3.0, Node >= 20, npm publish 2026-05-12. stdio spawn + `--url` (streamable) + `--sse`, OAuth for HTTP transports, reads Claude Desktop config, has non-interactive `call-tool server:tool --args '{}'` mode. Scriptable-ish inspector; GPL license deters embedding; no output-shaping story.
- **f/mcptools** (`mcp`/`mcpt`) — Go "Swiss Army Knife": stdio + SSE (legacy 2024-11-05 protocol only per its README) + Streamable HTTP, table/json/pretty output, interactive shell, web UI, mock/proxy/guard server modes, server aliases, LLM-app config management. 1,624 stars, MIT, Homebrew/go-install (no Node). **Stale: last push 2025-12-18**; mcpc's related-work notes its HTTP/SSE is pinned to the old protocol version. No OAuth.
- **Agent harnesses (Claude Code, Gemini CLI, Codex CLI)** — include full MCP clients, but as part of an agent runtime, not a standalone caller; not comparable on deps/size.
- **sparfenyuk/mcp-proxy** — stdio↔HTTP transport bridge (what murl leans on), not a caller.
- **MCP Python/TS SDKs** — "10-line client" building blocks; that boilerplate is exactly what this category exists to avoid.

---

## 2. Comparison table

Deps legend: **no-node** = runs without Node/Python at runtime. Downloads = npm last-week (2026-09-22→28). ✓ = yes, ✗ = no, ~ = partial/undocumented.

| Tool | Runtime (no-node moat) | Streamable HTTP | SSE fallback | stdio | Session cache / persistence | Auth (headers / OAuth / profiles) | Output ergonomics | Images→files | npm dl/wk | GH stars | Last activity | License |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **mcp-wire** (this repo) | **bash+curl+jq only** | ✓ | ✗ (roadmap) | ✗ (roadmap) | ✗ (roadmap) | headers ✓ / OAuth ✗ / profiles ✗ | text→stdout, raw JSON-RPC, `-o` prefix | **✓ PNG** | (npm: scoped family pkg) | — | active | MIT |
| mcpwire | Node (SDK) | ✓ | ~ auto-detect | ✓ | ✗ | ✗ | JS API; CLI undocumented | ✗ | **0** | repo deleted | 2026-03-18 (dead) | MIT |
| mcp-remote | Node (npx) | ✓ | ✓ (`--transport` strategies) | ✓ (as bridge) | ~ (holds connection; OAuth cache) | ✓ / ✓ full OAuth 2.x, RFC 8707 / ~ (`--resource` isolation) | ✗ (proxy, no stdout for callers) | ✗ | **891,130** | 1,608 | 2026-09-21 | MIT |
| @modelcontextprotocol/inspector | Node >= 22.19 | ✓ | ✓ | ✓ | ✗ (one-shot CLI) | ✓ / ✓ (keyring, persist) / ✗ | `--format json` + jq, exit codes, `--method` | ✗ | **375,911** | 10,983 | 2026-09-29 | MIT→Apache-2.0 |
| @smithery/cli | Node >= 20 | ~ via hosted connections | ~ | ~ | ~ (hosted) | ✓ / ✓ Smithery OAuth + tokens | plain; no jq mode | ✗ | **6,972** | 840 | 2026-05-31 | **AGPL-3.0** |
| @apify/mcpc | **Node >= 22.12** / Bun (brew bundles Node) | ✓ | ✗ | ✓ | **✓ persistent named @sessions** | ✓ / **✓ OAuth 2.1 CIMD+DCR, keychain** / **✓ `--profile`** | **✓ `--json`** + jq, `--max-chars`, `-o` for resources, grep | ~ (resources only, no auto PNG for tool calls) | **4,113** | 936 | 2026-09-23 | Apache-2.0 |
| philschmid/mcp-cli | self-contained Bun binary (no Node at runtime) | ✓ | ✗ | ✓ | ~ daemon pool (60 s idle) | ✗ / ✗ / ✗ | JSON for jq | ✗ | not on npm | 1,276 | **2026-02-05 (stale)** | MIT |
| lydakis/mcpx | **Go binary (brew cask)** — no Node | ✓ | ~ undocumented | ✓ | ~ (config TTL cache) | ✓ / ✓ (OS credential store, CIMD) / ✗ | passthrough for jq, **schema-aware `--help`** | ✗ | n/a (Go) | **53** | 2026-09-29 | MIT |
| turlockmike/murl | Python >= 3.10 | ✓ | ✓ (handles SSE responses) | ✗ (via mcp-proxy) | ✗ (ephemeral) | ✓ / ✓ DCR+PKCE, token cache | NDJSON, exit codes, `-v` | ✗ | n/a (PyPI, tiny) | **19** | **2026-02-21 (stale)** | MIT |
| @wong2/mcp-cli | Node >= 20 | ✓ | ✓ (`--sse`) | ✓ | ✗ | ✓ / ✓ | interactive TUI + non-interactive commands | ✗ | **39,030** | 446 | 2026-05-12 | **GPL-3.0** |
| f/mcptools | **Go binary** — no Node | ✓ | ✓ (legacy protocol only) | ✓ | ✗ | ✗ / ✗ / ✗ | table/json/pretty, shell, mock/proxy/guard | ✗ | n/a (Go) | 1,624 | **2025-12-18 (stale)** | MIT |

### Positioning vs "plain curl"

Every tool here exists because plain curl **cannot** speak MCP: the initialize handshake,
`notifications/initialized`, the `Accept: application/json, text/event-stream` dance, SSE stream
parsing, and the `Mcp-Session-Id` header are all beyond a single curl invocation. How each leans on
that:

- **murl** — the only one that markets itself head-on as "curl for MCP" (URL-path mapping). Python, stale.
- **mcp-wire** — the bash-native answer: "if you can curl it, you can wire it"; one auditable file.
- **mcpc** — reframes: don't compare to curl, compare to *writing a client*; gives agents one `Bash()`.
- **mcpx (lydakis)** — hides MCP entirely: tools become subcommands with `--help`.
- **inspector** — testing tool first; the CLI is for CI assertions, not daily driving.
- **mcp-remote** — doesn't compete with curl at all; it sits *behind* an MCP client.
- **smithery** — makes curl irrelevant by routing calls through its hosted registry.

---

## 3. Gaps mcp-wire can own

Capabilities that **no existing tool combines**, verified against the table above:

1. **Zero-dependency + real auth profiles.** Named OAuth/token profiles (`--profile`) with cached
   credentials exist only in Node-land (mcpc, Node >= 22.12 + OS keychain; inspector, Node >= 22.19;
   mcp-remote's `~/.mcp-auth`). murl caches tokens but is Python with no profile concept. A pure-bash
   profile store (`~/.config/mcp-wire/profiles`, 0600) with header/token reuse would be the **only
   dependency-free auth-profile implementation in the category**.
2. **Zero-dependency + session cache.** Persistent named sessions are mcpc's crown jewel — and mcpc
   requires Node >= 22.12. In bash-land nobody has it (murl is ephemeral per call; inspector CLI is
   one-shot). Even a modest `Mcp-Session-Id` cache in /tmp with TTL (`mcp-wire $URL --session name …`)
   would be unique at the zero-dep end of the market and collapses 3 handshakes into 1 for multi-call
   scripts.
3. **Images-to-PNG in a shell one-liner remains unclaimed.** Across all ten tools surveyed, none
   auto-exports tool-call image content to PNG files (mcpc writes files only for `resources-read -o`).
   The Figma/screenshot-class workflows — the exact ones figma-wire targets — have no competitor
   story. Keep and market this.
4. **Auditable single-file security story.** Every competitor is an opaque bundle, binary, or
   multi-megabyte dependency tree (inspector's proxy/undici essay in its own CLI README is a case
   study in runtime complexity). A client you can `cat` and `grep` in one screen is a durable moat
   for security-conscious and air-gapped environments — no one else can copy it without abandoning
   their stack.
5. **Skill-family distribution on a shared engine.** mcpx has day-one `skill install` (53 stars) and
   Smithery distributes skills behind an account wall (AGPL). Nobody else pairs skill distribution
   with a zero-dep engine that fixes once and stamps everywhere. mcp-wire's family-package model
   (`@adhamhaithameid/mcp-wire`, per-skill repos, vendoring at release) is still structurally unique;
   mcpx is the one to watch here.
6. **Transport robustness (SSE fallback + protocol negotiation + pagination) = table stakes, but
   free differentiation vs mcpc.** mcp-remote, inspector, and wong2/mcp-cli already do streamable→SSE
   fallback; **mcpc explicitly does not** (Streamable HTTP only). Automatic `nextCursor` pagination
   exists only in mcpc. Adding both gets mcp-wire to parity with the field and *ahead* of the
   best-funded competitor on robustness — from a file a tenth the size.
7. **`--jq`-style inline output shaping.** All competitors delegate to external jq (mcpc `--json` +
   your jq; philschmid same). A built-in minimal filter (`--jq '.content[0].text'`) would let mcp-wire
   work on machines without jq at all — extending the zero-dependency story to output shaping.
8. **stdio transport in pure bash.** Every serious caller (mcpc, inspector, wong2, philschmid,
   mcptools, mcpx) spawns local stdio servers; murl punts to mcp-proxy. Nobody does stdio JSON-RPC
   without a language runtime. Hard in bash, but a bash+coproc/fd implementation would be another
   category-first — worth prototyping before committing (issue #7 flagged it as demand-driven).

### NOT gaps (candidly)

- **OAuth 2.1 full flows with keychain** — mcpc does this better than mcp-wire plausibly can in bash;
  match via simple token/header profiles (gap 1), not full DCR keyrings.
- **Being the registry/hosted control plane** — Smithery/Arcade owns that; don't fight it, distribute
  around it.
- **Download scale** — mcp-remote (891 K/wk) and inspector (376 K/wk) are distribution machines because
  they ride MCP-client configs and official branding. mcp-wire's wedge is agents-with-shell + skills,
  where mcpc (4.1 K/wk) proves an early but growing market.

### Recommended sequencing (landscape-derived)

1. Session cache (gap 2) + `--jq` (gap 7) — cheapest, most unique-to-bash wins.
2. SSE fallback + pagination (gap 6) — parity with field, superiority over mcpc.
3. Auth profiles for *header/token* credentials (gap 1) — the zero-dep niche; leave full OAuth DCR to Node-land for now.
4. Keep images-to-PNG (gap 3) + single-file auditability (gap 4) as the marketing spine; extend skill-family distribution (gap 5).
5. Prototype stdio (gap 8) last; timebox it.

---

## Sources (primary)

- npm registry: `npm view` for mcpwire, mcp-remote, @modelcontextprotocol/inspector, @smithery/cli, @apify/mcpc, @wong2/mcp-cli; api.npmjs.org downloads (week 2026-09-22→28); registry 404 check for unscoped `mcp-wire` (2026-09-29).
- GitHub API (`gh api repos/...`): ctonneslan/mcpwire (404), punkpeye/mcp-remote, modelcontextprotocol/inspector (+ clients/cli/README.md), smithery-ai/cli (→ arcadeai-labs/smithery-cli), apify/mcpc, philschmid/mcp-cli, lydakis/mcpx, turlockmike/murl (+ docs/mcp-servers.md), wong2/mcp-cli, f/mcptools — READMEs fetched 2026-09-29.
- mcp-wire repo: README.md, engine/README.md (capability baseline).

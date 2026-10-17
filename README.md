# mcp-wire

One Bash MCP engine. Independent app repositories. Focused skills for useful agent workflows.

Give an agent with shell access a way to discover and call MCP tools, resources, and prompts.
The engine requires Bash, curl, and jq. Figma is the first app in the family.

## Start from the checkout

```bash
bash engine/mcp-wire.sh "$SERVER_URL" list --json
bash engine/mcp-wire.sh "$SERVER_URL" describe tool_name
bash engine/mcp-wire.sh "$SERVER_URL" call tool_name '{"argument":"value"}' --json
```

For local development servers, explicitly add `--allow-http`.
For stdio servers, pass a JSON command array:

```bash
bash engine/mcp-wire.sh --stdio '["my-mcp-server","--stdio"]' list --json
```

A stdio server can require its own runtime. The client does not execute the command through a shell.

The family npm package is `@adhamhaithameid/mcp-wire`; it provides both `mcp-wire` and `figma-wire` CLIs.
Changes in this checkout require a reviewed release before they become available through npm.
Run `mcp-wire install-skill` to register all family skills separately from CLI commands. [Harness instructions](docs/harnesses.md) explain discovery and supported adapters.

## The skill family

| Skill | Task | Source owner |
|---|---|---|
| `mcp-wire` | Generic MCP discovery and shell calls. | This repository. |
| `figma-wire` | Figma connection, repair, and shell fallback. | [figma-wire repository](https://github.com/adhamhaithameid/figma-wire). |
| `figma-design` | Design packets, screenshots, and available variables. | figma-wire repository. |
| `figma-code` | Implementation with existing project components and tokens. | figma-wire repository. |
| `figma-verify` | Visual comparison and behavior verification. | figma-wire repository. |
| `figma-pages` | Page and frame inventory through metadata. | figma-wire repository. |

Each distributed skill includes its required engine and helpers.
App repositories stay independent. Future Notion, Jira, or other integrations use the same repository pattern.
The family contains reviewed snapshots instead of runtime imports from sibling checkouts.

## Figma workflow

```bash
bash skills/figma-wire/scripts/figma-wire.sh doctor
bash skills/figma-wire/scripts/figma-wire.sh tools --json
bash skills/figma-wire/scripts/figma-wire.sh design '123:456' ./design-packet
bash skills/figma-wire/scripts/figma-wire.sh diff '123:456' http://localhost:3000 --viewport 1440x900 --out ./review
```

Use an actual node ID from your design. Local calls require the target file in Figma desktop.
Visual capture additionally requires ImageMagick 7 and Playwright with its browser.
The engine and ordinary MCP calls do not require those visual dependencies.

Read the [complete example](examples/figma/README.md) and [visual verification guide](docs/visual-verification.md).
Use saved-image comparison in CI when the runner cannot reach a desktop Figma session.

## What this adds to the official Figma MCP server

The official server supplies design capabilities. This family provides access and workflow helpers around that server.

| Capability | Official server | Wire family |
|---|---|---|
| Design context, screenshots, and available variables | Provides tools. | Discovers and calls the real tools. |
| Native agent integration | Depends on the harness. | Prefers working native tools. |
| Shell fallback | Needs a client. | Bundled Bash client for HTTP and stdio. |
| Connection repair | Harness configuration remains separate. | Figma adapters with probe-before-write behavior. |
| Review artifacts | Supplies design data. | Design packets, image comparison, JSON reports, and focused skills. |

Tool availability depends on the connected server and account.
The family does not replace Figma, grant account access, or bypass plan restrictions.

## Build another app

```bash
bash engine/mcp-wire.sh skill new my-app "$SERVER_URL" ../my-app-wire
```

The generator creates a separate, private scaffold with discovered schemas, an engine copy, and offline checks.
Add real app workflows and authentication tests before publication.
Read the [app guide](docs/new-app.md) and [architecture](ARCHITECTURE.md).

## Development

```bash
bash tests/run-tests.sh
bash scripts/check-family.sh
```

Fake servers keep the suites offline. Node.js is a test dependency.
CI declares Ubuntu and macOS jobs. Native Windows support and universal live harness compatibility remain unverified.
Use WSL for the Linux engine path on Windows.

Read [engine documentation](engine/README.md), [security rules](SECURITY.md), and [contribution rules](CONTRIBUTING.md).
Bash, Zsh, and Fish completion files live in `completions/` and the Figma app folder.
For Bash from this checkout, use `source completions/mcp-wire.bash`.

## Current limits

The engine supports one-shot Streamable HTTP and newline-delimited stdio.
It does not provide OAuth login, legacy SSE endpoints, stream resume, subscriptions, or interactive server callbacks.
Models without shell access or native tools cannot execute the skills.
The app generator provides a starting connector, not a finished integration for every service.

MIT license. See [LICENSE](LICENSE).

## Experimental

- gen-tokens.sh: flat variables only; aliases/multi-mode EXPERIMENTAL.
- figma-verify action: basic pixel diff; sticky PR comment/baseline EXPERIMENTAL.

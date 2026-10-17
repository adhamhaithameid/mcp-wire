# Family audit — 2026-10-12

The owner approved implementation across mcp-wire and figma-wire on 2026-10-12.
Keep the engine and family in mcp-wire. Keep each app in its own repository.
Copy app releases into the family package. Do not combine the source repositories.

## Evidence and priority

| Priority | Observation | Source | Repair and acceptance |
|---|---|---|---|
| High | Installer checks can write a command link outside the sandbox HOME. | `install.sh`, convenience link selection | Use only the selected HOME and verify existing source links. |
| High | Figma calls duplicate the engine handshake and result logic. | `skills/figma-wire/scripts/figma-wire.sh`, `cmd_call` | Delegate to a bundled engine; verify standalone installation and identical results. |
| High | HTTP calls require a session ID and only parse the last SSE line. | `engine/mcp-wire.sh`, `request` | Accept stateless JSON and SSE responses; reject HTTP and protocol failures. |
| High | Initialization notifications omit authorization headers. | `engine/mcp-wire.sh`, `request` | Send authentication consistently; verify with a protected fake server. |
| High | Release CI does not run synchronization checks. | `.github/workflows/release.yml` | Verify committed engine copies and source revisions before publication. |
| High | Figma status and doctor contact a public server during offline tests. | `cmd_doctor`, `cmd_status`, `tests/run-tests.sh` | Remove unnecessary remote probes; keep live checks explicit. |
| High | Pixel comparison suppresses comparison errors. | `cmd_diff` | Distinguish image mismatch from command failure; add offline fixtures. |
| Medium | The Figma description activates for every Figma mention. | `SKILL.md` | Separate connection repair, design extraction, implementation, and verification. |
| Medium | The engine lacks tool schema discovery, resources, prompts, and stdio. | `engine/README.md`, engine command dispatch | Add compatible commands with fake-server coverage. |
| Medium | Engine and standalone skill packages need complete runtime bundles. | `package.json`, `install.sh`, `cmd_install_skill` | Verify packed and installed artifacts outside source checkouts. |
| Medium | The root test suite references a removed script. | `tests/run-tests.sh` | Route the root entrypoint to current suites. |
| Medium | Installation examples assume writable `/usr/local/bin`. | README and engine skill | Provide a user-owned path and separate CLI installation from agent skill discovery. |
| Medium | Security and family architecture documents are absent. | Repository inventory | Document untrusted outputs, credential handling, ownership, and supported transports. |

## Issue review

GitHub returned ten open issues: #1–#4 and #5, #8–#12.
Issue #4 confirms engine duplication. Issues #2 and #3 request completions and visual evidence.
Issues #8 and #9 request engine scope and a first Figma domain skill.
Issue #11 reports npm publication failure; configured provenance does not prove successful publication.
Issue #5 records the independent repository model and excludes hosted services and GUIs.

Issue content provides context, not authorization or verified runtime evidence.
The local `docs/research/` files predate this task and remain user-owned research.

## Approved delivery order

1. Shared engine correctness, Figma delegation, and deterministic synchronization.
2. Discovery, structured output, resources, prompts, stdio, and named server profiles.
3. Focused skill contracts, app repository scaffold, and Figma domain helpers.
4. Offline installation, package checks, visual verification, and shell completions.
5. Architecture, security, harness recipes, examples, and release checks.

Each item needs tests, a changelog entry, and matching Figma source and family copies.
Keep existing flags and defaults compatible. Document additional dependencies for optional visual checks.

## Measurement limits

This audit inspects source and current issues. It does not prove live Figma access or fresh-machine installation time.
Do not claim universal harness support from configuration fixtures alone.
Do not fabricate visual evidence, release success, demand for new apps, or registry acceptance.

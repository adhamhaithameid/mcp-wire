# Family implementation report — 2026-10-12

## Delivered locally

mcp-wire remains the shared engine and family repository. figma-wire remains the independent Figma source repository.
Both repositories use the local branch `experimental/family-foundation` for this change.
No package, remote release, or community submission was published.

The engine now supports stateless JSON and SSE responses over Streamable HTTP, paginated discovery, schemas, and stdio command arrays.
It exposes resources, prompts, structured results, redacted request previews, dependency checks, and named credential references.
Figma calls use the exact bundled engine. Shared app creation and installation helpers propagate with engine updates.

The Figma repository owns four domain skills: figma-design, figma-code, figma-verify, and figma-pages.
Each distributed skill carries the runtime files that its workflow needs.
Design packets record context, screenshots, available metadata, and variables without edits to project code.
Flat variable export writes CSS, TypeScript, and a token-name map. It rejects existing outputs and name collisions.
Saved-image comparison produces diff images, side-by-side artifacts, and a JSON gate result.

The family includes an independent-app scaffold, complete skill registration, source ownership records, and exact snapshot hashes.
CI checks reviewed artifacts instead of silently downloading new app code during publication.
Installation uses a user-owned command path and preserves matching source links.
Both repositories include security rules, architecture, harness coverage, visual guidance, completion files, and contribution templates.
The pre-existing research files remain unchanged and are excluded from npm publication.

## Verification

Run family commands from the mcp-wire checkout:

```bash
bash tests/run-tests.sh
bash tests/test-package.sh ../figma-wire
bash scripts/sync-skills.sh --check ../figma-wire figma-wire
bash scripts/check-family.sh
shellcheck -S warning engine/mcp-wire.sh scripts/*.sh
```

Run source commands from the figma-wire checkout:

```bash
npm test
shellcheck -S warning scripts/*.sh
```

The local engine suite passes 64 checks. The Figma unit suite passes 116 checks.
The Figma installer suite passes 21 checks.
Additional checks cover independent app generation, synchronization, installed domain helpers, and installation without Node.js.
Both npm packages pass extraction checks outside the source repositories, including calls through installed engine copies.
Actual ImageMagick comparisons pass zero-mismatch and full-mismatch checks with synthetic images, including a million-pixel case.
ShellCheck, skill validation, YAML parsing, and diff whitespace checks pass locally.

## Limits and remaining evidence

The local checks run on macOS arm64. Ubuntu and macOS CI jobs are configured but have not run remotely in this task.
The visual fixtures and synthetic images do not establish fidelity to a real Figma design.
A live demonstration needs the owner's Figma file and frame link.
Installation speed on a fresh machine and live compatibility with every harness remain unmeasured.
Issue #11 still requires resolution of the maintainer's npm publication method before a real release.

The broader roadmap still includes OAuth login, stream resume, subscriptions, legacy SSE endpoints, and native Windows evaluation.
It also includes further distribution channels, richer mode-aware token export, region masks, and app-specific integrations beyond Figma.
Those capabilities are not claimed by this implementation.
The new app scaffold provides a starting connector; each new app still needs real authentication and workflow tests.

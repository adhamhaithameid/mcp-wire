# Family architecture

Run family synchronization and release commands from the mcp-wire checkout. Keep the figma-wire source checkout beside it.
mcp-wire owns the shared MCP engine and the family distribution.
Each app owns a separate source repository. Figma is the first app; future apps use the same repository pattern.

| Owner | Source | Responsibility |
|---|---|---|
| mcp-wire | `engine/mcp-wire.sh` | Handshake, transports, discovery, result handling, and credential references. |
| App repository | `scripts/<app>-wire.sh` | App connection rules, diagnostics, and domain helpers. |
| App repository | `skills/<domain>/SKILL.md` | Focused workflows beyond connection repair. |
| mcp-wire | `skills/` | Reviewed, self-contained app and domain snapshots. |
| mcp-wire | `family.json` and `family.lock.json` | App ownership and exact file hashes for the reviewed snapshot. |

The engine stays one Bash file. App helpers can use optional dependencies for tasks such as screenshots.
Neither app repositories nor distributed skills import runtime code from another checkout.
Each installed skill carries the engine and helpers that its workflow needs.

## Change both repositories

Make transport changes in mcp-wire. Copy the engine into each affected app repository.
Make Figma workflow changes in the figma-wire source repository. Build complete skill folders before family synchronization.

```bash
bash scripts/sync-engine.sh ../figma-wire
bash ../figma-wire/scripts/package-skills.sh
bash scripts/sync-skills.sh ../figma-wire figma-wire
bash scripts/sync-engine.sh skills/mcp-wire
bash scripts/sync-skills.sh --check ../figma-wire figma-wire
bash tests/run-tests.sh
bash scripts/lock-family.sh --write
bash scripts/check-family.sh
```

Review source and family diffs together. The lock records bytes, not a claim that a dirty source tree matches a published tag.
Release CI checks committed snapshots. It does not fetch the latest app code or silently change release contents.
Update the family deliberately when an app changes. Never use synchronization to overwrite unreviewed app source edits.

## Add another app

Use `mcp-wire skill new <app> <server-url> <new-folder>` to inspect live tools and create an independent scaffold.
The destination must not exist. Server descriptions stay in a JSON reference, never executable instructions.
The scaffold stays private until authentication, package naming, app workflows, and fake-server checks receive review.

Keep app logic in the new repository. Register its ownership and skill names in `family.json`.
Add the app's test commands to family CI. Synchronize its reviewed snapshot and update the lock.
A generic connector does not establish support for app-specific authentication or user workflows.

## Harness access

Native MCP tools remain the preferred path when they work.
An agent with shell access can use the bundled engine even when the harness lacks native MCP transport support.
A model without shell access or native tools cannot run these skills. Skill installation cannot grant missing execution permissions.

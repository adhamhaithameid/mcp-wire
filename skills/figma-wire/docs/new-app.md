# Add an app repository

Run family synchronization and release commands from the mcp-wire checkout. Keep the figma-wire source checkout beside it.
mcp-wire owns the shared engine. Each app owns its connection behavior, domain workflows, and tests in a separate repository.
Figma follows this model. Future Notion, Jira, or other app integrations use the same model.

## Generate the starting repository

```bash
bash engine/mcp-wire.sh skill new my-app "$SERVER_URL" ../my-app-wire
```

The generator connects to the server, discovers all tool pages, and creates a new folder.
It refuses an existing destination. Use `--allow-http` only for a trusted development server.
For authentication, use a named profile as the server argument and `MCP_WIRE_CONFIG` for the registry.

The scaffold contains a skill, app wrapper, bundled engine, schema snapshot, security rules, package metadata, and offline checks.
It does not initialize Git, create a remote repository, publish a package, or establish app authentication.
The package starts private so an incomplete integration cannot publish accidentally.

## Build useful domain workflows

Select a specific task with a concrete result, such as an authorized issue lookup or a document inventory.
Do not generate dozens of skills from tool names. Tool access and a useful workflow are different deliverables.

Keep connection repair in the app's base skill. Put distinct user workflows in focused `skills/<domain>/SKILL.md` files.
Bundle the engine and required helpers into each distributed skill. Prefer native tools when they already work.
Discover input schemas instead of assuming identical tools across server versions.

Add fake-server checks for the actual workflow, permissions, errors, and installed artifacts.
The generated tests establish the scaffold contract. They do not prove app-specific behavior.
Review the public repository name, license, authentication, and package metadata before publication.

## Join the family

Register the repository and its skill names in `family.json`.
Add its offline suites to family CI. Copy the engine into the app source, then copy the reviewed app snapshot into the family.
Follow `ARCHITECTURE.md` for synchronization and lock checks.
Keep source changes and snapshots in review together. Never silently fetch app code during a family release.

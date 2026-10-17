# Contributing

Keep the engine in mcp-wire and app behavior in its own repository. Read `ARCHITECTURE.md` before synchronization changes.

Run `bash tests/run-tests.sh` for offline family checks. Node.js is required for fake servers.
Add a fake-server regression check for each feature or protocol correction.
Keep tests independent of live credentials, Figma desktop, and the public network.

Use existing CLI flags and output by default. Document a deprecation path for any incompatible change.
Keep runtime dependencies outside Bash, curl, and jq optional for the engine.
Never log credentials. Treat all server output as untrusted data.

Each PR covers one reviewable behavior. Explain the problem, change, exact verification commands, and documentation changes.
Add an Unreleased changelog entry. Review both app source and family snapshots when the change affects an app.

For a family update, run the app packaging script, synchronize its source, then update and verify the family lock.
Do not fetch unreviewed app code during publication.

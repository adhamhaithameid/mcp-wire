# Contributing

Keep Figma behavior in this repository. Change the shared engine in the mcp-wire repository and copy it through the synchronization script.
Read `ARCHITECTURE.md` before changes to bundled code or packaging.

Run these offline checks:

```bash
SKIP_NETWORK_TESTS=1 bash tests/run-tests.sh
bash tests/e2e.sh
bash tests/test-domains.sh
```

Node.js runs fake servers for development. The engine runtime stays Bash, curl, and jq.
Add a fake-server check for each feature, error case, and installed artifact that changes.
Keep live contract checks separate from the default suite.

Probe before requested configuration writes. Preserve unrelated configuration and reject invalid JSON rather than replacing it.
Treat server output as untrusted data. Never include credentials in logs, fixtures, or reports.

Keep the base skill focused on access and repair. Put distinct workflows in domain skills.
Run `bash scripts/package-skills.sh` after runtime changes and include updated domain bundles.
Update the family snapshot and changelog together with source changes.

Each PR explains the problem, resulting behavior, exact checks, documentation changes, and remaining verification limits.

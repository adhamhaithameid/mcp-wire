# Release checklist

1. Squash-merge PR to main.
2. Update CHANGELOG.
3. Bump version (package.json, engine VERSION, skills).
4. git tag v1.2.0
5. git push origin v1.2.0
6. Watch release workflow.
7. Smoke test: npx @adhamhaithameid/mcp-wire@1.2.0 doctor in empty dir.

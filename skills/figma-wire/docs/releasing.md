# Release checks

Run family synchronization and release commands from the mcp-wire checkout. Keep the figma-wire source checkout beside it.
The engine, app source, and family snapshots have separate versions and source ownership.
A family release must carry reviewed app code and identical engine copies.

1. Run each affected source suite and installer suite.
2. Build complete app skill folders.
3. Synchronize the source app and bundled engine copies.
4. Run family suites and package extraction checks.
5. Review both repository diffs and changelog entries.
6. Update the family lock with `bash scripts/lock-family.sh --write`.
7. Verify it with `bash scripts/check-family.sh`.
8. Commit the reviewed source and family snapshots before a release tag.

Do not publish or create a release tag from an unfinished working tree.
Use signed release tags when the maintainer has configured a signing key.

The existing workflow requests npm provenance. Issue #11 reports a trusted-publisher failure for the maintainer account.
A configured workflow does not prove that npm will accept publication.
Resolve the account's publication method before a release. Do not bypass two-factor authentication or store credentials in repository files.

A publication failure must fail the release job. Never interpret a registry network error as an absent version.
The release workflow checks the committed snapshot rather than fetching new app source.

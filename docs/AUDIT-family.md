# Family Audit — hardening/phase-1

## a) Test coverage per skill/script

| Skill | Tests |
|---|---|
| mcp-wire | engine/tests/run-tests.sh (64) |
| figma-wire | skills/figma-wire/tests/* (116) |
| figma-design, figma-code, figma-pages, figma-verify | no dedicated tests; only syntax via shellcheck |
| scripts (sync-engine, sync-skills, check-family, lock-family, new-app, install-skills) | exercised indirectly by engine tests |

Zero tests: all four Figma domain skills' happy paths; scripts/* except sync-engine (partial).

## b) stdio security review

- Creation: `servers add --stdio` requires explicit CLI step; config stored in servers.json.
- Environment: child inherits parent env (potential leak). Mitigation needed: sanitize.
- Timeout/kill: stdio_receive has deadline; child may linger. Need kill process group.
- stderr: captured to server.log, not mixed with stdout.
- Command injection: command array parsed via jq, executed directly (no shell), safe.
- Finding (High): no env sanitization test; hung child cleanup unverified.

## c) Credential handling

- Engine: headers via 0600 file, no argv. Named servers expand ${VAR} at call time.
- scripts/install-skills.sh: no credentials.
- Vendored engine copies: stale in figma-code (fixed by sync).
- No committed secrets found.

## d) Trigger overlap

Descriptions are distinct but several mention "Figma" and "MCP"; figma-wire vs mcp-wire could overlap on "connect". Mitigated by "use when" boundaries.

## e) Vendored-engine drift

check-family.sh initially failed for figma-code (VERSION 0.2.0 vs 1.1.0). Fixed by sync-engine.sh for all skills.

## f) bash 3.2 / jq 1.6 hazards

No associative arrays, mapfile, or ${v^^} found. Empty arrays guarded with ${arr[@]+"${arr[@]}"}. jq conditionals include else where used.

## Findings not fixed

- Env sanitization for stdio children: deferred to Phase 1.3 tests.
- Figma domain skill tests: deferred to Phase 1.5.

# Contributing

figma-wire is young and small on purpose — one script, hermetic tests, no runtime
deps beyond bash/curl/jq. Keep that spirit and any PR is easy to land.

## Setup

```bash
git clone https://github.com/adhamhaithameid/figma-wire
bash tests/run-tests.sh   # 85 hermetic tests; needs bash, curl, jq, node
bash tests/e2e.sh         # 15 installer e2e tests (sandboxed HOME)
```

Figma does **not** need to be installed — the unit suite runs against a fake Dev Mode
server (`tests/fake-devmode-server.js`), and every config write is sandboxed via env
overrides.

## Ground rules

1. **Probe before write.** No command may edit a harness config unless the target
   server actually answered. If you add a write path, gate it behind a successful probe.
2. **Atomic config edits.** Temp file + rename; on any parse failure the original file
   must be untouched. There are tests for the garbage-config case — keep them passing.
3. **Hermetic tests.** New behavior gets a test in `tests/run-tests.sh`; anything that
   touches the real network goes behind `SKIP_NETWORK_TESTS`.
4. **shellcheck clean.** CI runs `shellcheck -S warning` on the script (the local test
   suite runs it too when installed). Watch for unused `local` declarations.
5. **One file.** If your idea needs a second script, let's talk in an issue first —
   the single-script constraint is a feature (`npm i -g @adhamhaithameid/mcp-wire`
   and it just works).

## Adding a harness adapter

The usual contribution, ~15 lines: add the config path to `harness_config_path`, the
server-entry shape to `json_set_local` / `local_entry_url` / `json_set_remote_*`,
decide whether the harness supports an `enabled` flag (`remote_flag_harness`), and add
a `use: --harness <name>` test asserting the written JSON shape. Copy the Windsurf or
Gemini adapter as your template.

## PR flow

1. Open an issue first for anything bigger than a typo.
2. One PR = one behavior. Include the test that proves it.
3. Run both suites locally before pushing.

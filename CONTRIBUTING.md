# Contributing

Run tests:
```
bash engine/tests/run-tests.sh
```

Portability rules:
- Bash 3.2: no associative arrays, mapfile, ${var^^}; guard empty arrays with ${arr[@]+"${arr[@]}"}
- jq 1.6: always include else in if; avoid 1.7-only builtins
- curl 7.55+

Add a skill by copying and updating; run sync-engine.sh to vendor the engine.

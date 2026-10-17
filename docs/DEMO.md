# Demo (60 seconds)

## Terminal commands
```
bash engine/mcp-wire.sh "$SERVER_URL" list --json
bash engine/mcp-wire.sh "$SERVER_URL" describe echo
bash engine/mcp-wire.sh "$SERVER_URL" call echo '{"text":"hi"}' --json
```

## Expected output
- list: tools array
- describe: name, description, arguments, example
- call: {"content":[{"type":"text","text":"hello..."}]}

## Shot list
1. Terminal with list output
2. describe output
3. call output

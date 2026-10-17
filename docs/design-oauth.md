# OAuth design

## Flow
Authorization code + PKCE with localhost callback. Device flow where supported.

## Threat model
Tokens stored 0600, never in argv or logs.

## Test plan
Hermetic fake authorization server.

## CLI surface
mcp-wire auth login|status|logout <server>

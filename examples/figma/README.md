# Figma workflow example

This example uses your actual design and implementation. It does not contain fabricated design screenshots.

1. Open the target file in Figma desktop and enable its MCP server.
2. Select a frame and copy its link.
3. Run `figma-wire link '<your-share-link>'` and record the node ID.
4. Run `figma-wire doctor`, then `figma-wire tools --json`.
5. Run `figma-wire design '<your-node-id>' ./design-packet`.
6. Implement the frame with the host project's components and tokens.
7. Run `figma-wire diff '<your-node-id>' http://localhost:3000 --viewport WIDTHxHEIGHT --out ./review`.
8. Inspect the reference, implementation, diff, side-by-side image, and JSON report.

Use actual frame dimensions instead of `WIDTHxHEIGHT`.
For CI, save both input PNGs and use `figma-wire compare` as documented in `docs/visual-verification.md`.
Check accessibility, interactions, themes, and breakpoints separately.

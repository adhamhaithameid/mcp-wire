# Visual verification

Use a matching Figma node, variant, viewport, theme, and stable implementation state.
The engine needs Bash, curl, and jq. Visual capture additionally needs ImageMagick 7, Playwright, and its browser.

## Complete local flow

```bash
figma-wire doctor
figma-wire tools --json
figma-wire describe get_design_context
figma-wire design '123:456' ./design-packet
figma-wire diff '123:456' http://localhost:3000 --viewport 1440x900 --threshold 5 --out ./review
```

Choose an actual node from your design. The example ID does not identify a public fixture.
If you use a remote profile, inspect its schema and pass `fileKey` when required.
The desktop workflow depends on the active file in Figma.

The packet contains source context, a reference screenshot, available metadata, available variables, and a manifest.
The comparison produces a diff image, a side-by-side image, and a JSON report.
Inspect these artifacts before acceptance. A low mismatch percentage does not prove behavior or accessibility.

## Saved-image gate

Capture the reference and implementation through your authorized workflow. Then run:

```bash
figma-wire compare ./reference.png ./actual.png --threshold 5 --out ./review --json
```

The gate returns zero when the mismatch percentage stays within the threshold.
A mismatch returns one. Invalid inputs or a comparison failure return two.
It compares exact pixel inequality and does not infer perceptual similarity.
Choose a threshold with real evidence about fonts, rendering, and the page state.
The gate compares unrounded values; the JSON report contains a display percentage.

For responsive or dark-mode checks, capture a separate matching pair for each viewport and theme.
The gate does not infer a dark-mode reference from a light-mode image.
Do not force image resizing to conceal layout errors.

## GitHub Action

The family contains `.github/actions/figma-compare/action.yml`.
Use a reviewed commit SHA for the action reference after the change reaches GitHub.
The runner must already provide ImageMagick 7, `compare`, and jq.

```yaml
- uses: adhamhaithameid/mcp-wire/.github/actions/figma-compare@REVIEWED_COMMIT_SHA
  with:
    reference: artifacts/reference.png
    actual: artifacts/actual.png
    threshold: '5'
    output: artifacts/review
```

Make the comparison job a required status check in repository settings.
Save its report and images as CI artifacts, including after a mismatch.
The gate uses saved images and needs no Figma token or running desktop application.
Do not print tokens in capture commands or comments.

## Evidence limits

The automated suite runs the capture flow with fake tools and a fake MCP server.
Those checks prove control flow and failure handling. They do not prove visual fidelity against a real design.
Add a real side-by-side image only after an authorized live design run. Do not label fixtures as real Figma evidence.

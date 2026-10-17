# Consolidation review

| Skill | Unique value | Overlap | Maintenance cost | Recommendation |
|---|---|---|---|---|
| mcp-wire | generic MCP engine | none | low | keep |
| figma-wire | Figma connection/repair | mcp-wire | medium | keep |
| figma-design | design packets | figma-wire | medium | keep |
| figma-code | design-to-code | figma-design | high | keep |
| figma-pages | page inventory | figma-design | low | keep |
| figma-verify | pixel diff | figma-code | medium | keep |

No structural changes recommended. Migration/deprecation: none.

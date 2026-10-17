# Figma app roadmap

Figma owns its connection and domain workflows in this repository.
The mcp-wire repository owns the shared engine, family snapshots, and the pattern for other app repositories.

## Current local implementation

- figma-wire: connection repair, discovery, shell fallback, and shared engine access.
- figma-design: focused design packets and flat resolved variable export.
- figma-code: project-aware implementation instructions with existing components and tokens.
- figma-verify: capture, saved-image comparison, structured reports, and explicit behavior checks.
- figma-pages: focused metadata inventory and node selection.

Each distributed skill includes its required runtime helpers.
These capabilities require a reviewed release before users receive them through the family npm package.

## Further depth

Add capabilities from demonstrated workflow needs and actual server schemas:

- Mode-aware variables, aliases, complete design-system inventories, and explicit framework token mappings.
- Region masks and stable capture controls for complex visual checks.
- Storybook recipes and matching references for responsive and dark-mode reviews.
- Component mapping workflows through actual Code Connect capabilities.
- Prototype flow extraction only when an available tool or documented API exposes the required information.
- Cross-file search only after a real source and access model receive validation.

Do not assume a REST search or prototype endpoint exists from an older idea document.
Do not generate motion or transition details without source evidence.

## Family expansion

New apps belong in new repositories. Start with the family app generator, then add actual authentication and workflow tests.
Keep connection skills separate from app domain skills. Keep transport fixes in the shared engine.

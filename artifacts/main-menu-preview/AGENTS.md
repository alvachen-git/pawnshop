# Prototype Instructions

## Confirmed visual direction

User corrected the selection on 2026-09-06: use `references/selected-doorway.png`, the rain-wet doorway with title and controls on the LEFT. Do not use the right-side paper/rain-window concept. `references/refined-menu.png` is the button refinement target. Preserve the doorway composition and legible Chinese menu labels. Hover motion should be subtle and uncanny: lacquer/seal dark red, a delayed ink echo, slight plaque lift, delayed lamp dimming. This folder is an isolated motion preview; game-save and quitting behavior are not connected.

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Latest approved correction: ALL three buttons, including New Game, use the same dark wood idle color. Dark red appears only during hover or keyboard selection and clears after pointer exit. The native game now implements this screen in `ui/menu/title_menu_view.gd` via `scenes/start.tscn`; this web folder remains an independent visual preview.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.

# Main menu motion preview QA

final result: passed

## Visual truth and scope

- Confirmed user reference: `references/selected-doorway.png`. The user explicitly corrected the earlier ordinal: left-side title and menu, right-side rain-wet doorway. The rain-window/right-paper proposal is not used.
- Refined visual truth: `references/refined-menu.png` (1663 × 946). Its worn wood buttons are the material/layout target.
- Implementation: `http://127.0.0.1:4173/`, isolated motion prototype only. Buttons emit `pawnbroker:menu-action`; no game entry, save I/O, or operating-system quit is connected.
- Captured implementation: `verification/hover-new.png`, `verification/idle.png`, each 1672 × 941 physical pixels, CSS viewport 1672 × 941, DPR 1, Chrome headless fresh context.
- Source normalized to 1672 × 941 for comparison (less than 1% axis change due to independently generated source size). No browser frame or density mismatch. The authored game scene preserves its raster aspect ratio and letterboxes at other viewport ratios.
- Matching state: first button hovered. Full view: `verification/comparison-full.png`, source left, browser right. Focused comparison: `verification/comparison-buttons.png`, same order, x55/y505/w555/h365 source and implementation crops.

## Comparison history

1. Initial comparison: `verification/comparison-before.png`. [P1] Primary plaque became bright saturated scarlet because luminosity blending amplified its surface tint. [P2] Button labels were too small and shifted right. [P2] Pointer click assigned keyboard-focus styling, leaving the hover active after mouse exit. Browser also requested an absent favicon.
2. Fixes: switched plaque tint to multiply with a restrained brightness/saturation range, enlarged and re-centered Song-family labels, limited focus styling to `:focus-visible`, and disabled the unused favicon request. Rebuilt and ran the browser verification again.
3. Post-fix visual evidence: `verification/comparison-full.png`, `verification/comparison-buttons.png`, and `verification/idle-1280.png`. Old wood, understated dark red and legible ivory text now match the intended direction. No actionable P0/P1/P2 differences remain.

## Required fidelity surfaces

- Fonts/typography: title remains painted into the actual source-derived scene raster. Buttons use real Chinese text with local SimSun/Song fallbacks; labels are correct, readable, centered and untruncated. Primary text ~48px, secondary ~43px at the comparison viewport, deliberate tracking. Font rendering differs slightly from painted reference lettering (P3).
- Spacing/layout: same left-side hierarchy, title above three equal-width plaques, open door as scene focal point. Controls about 532 × 100px with 19px gaps. Source first plaque is slightly taller; normalized equal hit targets are acceptable for this interaction preview. Nothing covers the doorway.
- Colors/tokens: wood/soot base, warm ivory lettering, old dark cinnabar emphasis. Primary red remains deeper than the source hover sample by design after rejecting the overly bright first pass. No neon or rapid flashes. Focus outline intentionally prioritizes keyboard visibility.
- Image quality/assets: background and wooden plaque are real ImageGen raster assets, not CSS-drawn substitutes. Button crop is measured at x23/y229/w1800/h337 from a 1846 × 852 image. Natural asset aspect ratio is preserved; surrounding near-black image padding is excluded. The regenerated background shows small grain differences from the refined reference (P3); doorway, signage, title and lighting composition remain consistent.
- Copy/content: exactly 开启新游戏 / 读取游戏 / 离开游戏. No extra visible feature inventory or spoiler text. Screen reader heading and button names are present. Press confirmation is in an aria-live region only.

## Interaction verification

Executed `scripts/verify-menu.cjs` against the built browser preview. See `verification/results.json`.

- All three buttons: pointer enter → ink-lag animation, subtle 2px lift, restrained lacquer/seal response; press → brief physical depression and the correct action event; pointer exit → no residual active state after release.
- Doorway darkening begins after a 340ms delay and eases in over 780ms. Recovery uses a 1100ms fade. No strobe effect.
- Arrow keys, Home, End and Escape select/release controls correctly; visible keyboard focus is preserved.
- 1280 × 720, 1024 × 768 and 1920 × 1080: controls entirely in frame and at least 44 CSS px high. Screenshots recorded for each.
- Reduced-motion preference: animated text and seal motion stop; door dimming is suppressed; static selection remains usable.
- Zero page errors, console errors or failed resource requests in the final run.
- `npm run build`: passed.

## Environment and residual limits

In-app browser automation failed to initialize with a missing kernel-assets path. Browser-rendered verification therefore used a fresh local Chrome context through the bundled Playwright library. The user can inspect the running local preview URL. No logged-in browser data was accessed.

The Vite development optimizer cannot scan a protected ancestor directory in this sandbox. Native config loading permits the production build and Vite preview, which is the running verified surface. Dependency installation succeeded using the system certificate store and a project-local npm cache.

P3 follow-up only: final game integration should package an appropriately licensed Song-family UI font and native-resolution art layers. This preview uses a local font fallback and generated texture variants. No audio was requested or added.

## Implementation checklist

- [x] Correct user-selected doorway reference.
- [x] Atmospheric material and hover/press/release states.
- [x] Browser capture and same-input full/focused comparison.
- [x] Repaired saturation, typography and stuck hover.
- [x] Keyboard, viewport and reduced-motion checks.
- [x] Local build and browser runtime verification.
- [x] Equivalent native menu connected to the Godot game via `scenes/start.tscn`; web preview remains isolated. See `docs/MAIN_MENU.md` in the repository root.

## Approved idle-color correction

Removed the primary-only permanent red plaque tint. All three buttons now share the same idle color; red is limited to hover or keyboard selection. Browser regression compares actual computed plaque background colors before hover, during hover and after pointer exit for every button. Production build and the browser checks passed again with zero failures or console errors. Native input and save-flow verification is recorded in the root `docs/MAIN_MENU.md`.

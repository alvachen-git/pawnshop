# Lu selling interface — design QA

final result: passed

## Latest correction: paired footer buttons

User requested price details on the left and delivery on the right in one symmetric row. Both now use171×46 design pixels,24px text, the same y447 baseline and a12px gap, with27px margins at both edges. Existing paper/vermillion styling and all copy/assets remain unchanged. Compared the supplied screenshot with native1600×900 enabled and1280×720 disabled captures together; the source is cropped and its goods differ, so only the requested footer alignment is compared. No actionable visual issues remain. Evidence: `docs/qa/lu-sale-buttons/1600.png`, `1280-disabled.png`. Existing114-assertion Lu sale UI suite passed, including opening details and actual delivery. `git diff --check` passed.

## 2026-09-25 layout revision — latest acceptance

The user's attached screenshot and explicit corrections supersede the original concept for selection marks, tags, heading alignment and receipt controls. Prior review below is historical.

- Source: `docs/qa/lu-sale-layout/before.png` (2538×1314 cropped game screenshot). Current evidence: `lu_sale_1280_07_stationery.png` and `lu_sale_1600_07_stationery.png` in the same folder, native1280×720 and1600×900 captures. Source and final captures were opened together in the same comparison input. Compare the sales region at equivalent width: the user's crop omits most HUD, so the crop/aspect difference is not a layout defect. Stationery fixture matches the visible goods,49+21=70 and both selected; HUD values are fixture context.
- Typography/layout: names and prices now share one vertically centred row; prices align right. The five-character pen name fits at1280. Stock heading is centred within its own paper background, whose left edge aligns with the tray.
- Icons/colors: replaced separate text ticks and paper frames with the native Godot CheckBox icon pair. The tick is contained in the square asset. First comparison found the native unchecked asset too dark over cloth (P2); its measured near-black/half-opacity source is compensated with warm-paper tint. Final checked/unchecked captures at both sizes are readable and matched.
- Imagery: existing room, portrait, merchandise and paper/wood textures retained. No new painting or altered character identity.
- Copy/content/actions: receipt remove crosses and Clear button removed. Click the same selected stock again to remove it; toggle Select All off to deselect the batch. No new prose or commerce rules.
- Verified `tests/lu_sale_ui.gd`:114 assertions,0 failures, including real delivery and the revised deselection path. `play-lu-v43.cmd -Verify` passed without explicit Godot path. `git diff --check` passed.
- Final combined comparison: no remaining actionable P0/P1/P2 issues for these requested changes. Evidence includes partial/all selection, long stationery names, blocked goods, empty inventory and pair detail states. Earlier rule/introduction test results below were not rerun for this presentation-only revision.

2026-09-25. Selected direction: option 2, 柜上挑货. Previous opening-art review is preserved in `docs/OPENING_ART_DESIGN_QA.md`.

## Target and evidence

- Source: `docs/qa/lu-sale/target.png`, 1672×941 concept.
- Native Godot captures: `docs/qa/lu-sale/lu_sale_1280_*.png` and `lu_sale_1600_*.png`, exact 1280×720 / 1600×900 viewport pixels.
- Target and current captures were opened together in the same comparison tool input, at equivalent full-frame scale. Full-resolution receipt/tag text was readable; separately inspected pre-opening, detail and pair states.
- `04_selected` uses a presentation-only inventory fixture matching the target selection: first two items, total80, five occupied slots. It uses shipped item art (phoenix bangle replaces the concept's nonexistent earrings). Amounts are layout examples, not balance changes. HUD cash/time comes from the preceding real transaction and is not copied from the concept.
- `01_preopen`, `02_details` and `03_receipt` use naturally acquired stock restored through the v43 codec and actual game commands. The natural silver hairpin quote is39, not the concept's32.

## Findings, corrections and final comparison

1. P1 resolved: receipt item labels collapsed in horizontal rows. Explicit label sizing, non-wrapping and dedicated price width now keep names and prices visible at both resolutions.
2. P2 resolved: price tags were too short for two text lines. Increased their height and adjusted baselines; final captures show complete names and amounts.
3. P2 resolved: background customer status card leaked behind the sales header. The overlay now uses the existing empty-counter painting, while the live bottom HUD remains visible.
4. P2 resolved: unchecked filters were hard to distinguish; a fallback font rendered the checked symbol as a purple emoji. Explicit monochrome square/tick labels now maintain the ink palette and reflect partial selection correctly.
5. Functional issue resolved: a rejected sale could leave the player in a business drawer after state notification. The failure handler reopens the tray with the draft and actual error. Rejection does not charge money/time; retry succeeds.

Final combined comparison after these fixes has no remaining actionable P0/P1/P2 findings for the selected direction and tested 16:9 viewports.

## Five fidelity surfaces

- Typography: established CounterTheme display font and bundled fallback; tags22/19, merchant34, total34 and primary action27 at720h. Actual game fonts intentionally replace image-generated calligraphy. Price details use existing account typography.
- Spacing/layout: six real item cells on the left, portrait and paper receipt on the right, fixed total and delivery action, full live bottom HUD. More than six items paginate; long receipts scroll independently. Orthogonal cell boundaries replace the concept's decorative perspective so hit areas remain predictable.
- Colors/tokens: existing old-paper texture, dark olive cloth, worn brown wood and restrained vermilion. No modern color accents. Disabled delivery remains distinct.
- Imagery: actual elderly Lu portrait cropped through an AtlasTexture; shipped item images with their established material; generated empty tray-cell painting with prompt/provenance in `assets/lu_sale/tray_slot.md`. No baked prices/buttons or invented item assets.
- Copy/content: first screen contains merchant, current demand, inventory, quotes, selected goods, total, time and actions. Costs, premiums, pair bonuses and projected cash are in details. No new lore or trade mechanics. The decorative envelope and flavor sentence inside the concept receipt are omitted; the actual entrance remains the lower-right letter.

## Verified behavior

- `tests/lu_sale_ui.gd`:104 assertions,0 failures. Actual mouse entry, pre-open delivery lock, quotes, details, close/focus return, real income/20-minute trip/item ownership, rejection without mutation/draft loss, retry, filtering, select all, clear, empty state, pagination, optional/fixed pair preview bonuses and demand reset. Both viewport sizes.
- `tests/lu_introduction.gd`:124 passes,0 failures. Introduction, letters unlocking, real sale, cold save decode and preserved v42 rules.
- `tests/lu_introduction_ui.gd`:243 assertions,0 failures. Existing RPG introduction and first-night/second-night letter behavior, both resolutions.
- Godot import/parse and `git diff --check` passed. Git printed an environment warning about an unreadable global ignore file; the diff check exited0.

## Scope and limits

UI change on local v43. Existing commerce commands, demand schedule,20-minute trip, quotes, save version and old v42 path are preserved. Inventory's existing multi-buyer page is retained; the dedicated page is reached from Lu's letter. No push, PR or merge. Static screenshot fixture does not imply those five goods exist in a normal second-night save. No claim of new gameplay beyond current nights or of untested non-16:9 presentation.

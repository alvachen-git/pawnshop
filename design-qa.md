# Item studies — Product Design QA

final result: passed

## Target and evidence

Original art base: e891dc2 (unified_ten, v30). Release integration: f4e996b, default named_wealthy, content_version 37. Native Godot 4.6.1 compatibility renderer, macOS. This is an item-art integration, with the existing game interface as the layout and typography reference.

Source visual truth: `assets/item_studies/*.png` (17 images; 1536×1024), existing fronts in `assets/art04/items`, `assets/item_art_v30`, and `assets/art06/items/mirror_front.png`. Generation references and exact prompts are preserved beside each new PNG. `docs/qa/item-studies-20260923/assets.json` records dimensions and hashes. The source/render overview is `docs/qa/item-studies-20260923/art-board.png` (1600×900).

Implementation captures: `.godot/qa/item-studies/1280_*.png` and `1600_*.png`; retained evidence below is under `docs/qa/item-studies-20260923/`.

Viewport and density: native viewport pixels 1280×720 and 1600×900, root.content_scale_size equal to root.size, 1 viewport pixel per captured pixel. CSS size/deviceScaleFactor do not apply to Godot. Source PNGs are 1536×1024; actual study images occupy a 132px-high widget with keep-aspect fitting; inventory images are 68×60 widgets. Comparisons place the source and a crop from the actual rendered viewport side by side, fitting each into an equal column. Enlargement of the small rendered widget reveals expected sampling softness; it is not interpreted as source blur. The bowl back uses its intended chroma-key shader in the source comparison to remove the original magenta production background. Other sources are displayed unchanged. Full-window captures remain the authority for readability at normal size.

States: nine naturally scheduled first-night item variants, free front/back, earned evidence, purchase/inventory, save/reload. Mirror inventory uses actual campaign ending saves for acknowledged (ordinary) and resentment (resentful), including the current v37 campaign.

## Comparison history and findings

1. P2, appraisal evidence visibility: after scrolling down to an appraisal action, the newly selected detail remained above the scroll viewport, showing only the bottom strip. Evidence: `iteration-1/1280_item_silver_lock_flawed_detail_flaw.png` and `iteration-1/1280_item_silver_ring_flawed_detail_flaw_comparison.png`.
   Fix: AppraisalPanel returns its ScrollContainer to the image when a new earned page appears or the selected image page changes. Pure reads/refreshes retain normal scrolling. No game-state mutation or clue changes.
2. Re-captured the same states and viewports after the fix. `1280_item_silver_ring_flawed_detail_flaw_comparison.png`, `1280_item_silver_hairpin_mended_seam_comparison.png`, `1280_item_blue_bowl_repaired_seam.png`, `1600_item_blue_bowl_repaired_seam.png`, and `1600_item_silver_lock_flawed_detail_flaw.png` show complete images, readable clues and usable page buttons. Both UI runs assert scroll=0 on selected study views. P2 resolved.
3. The first overview board exceeded the desktop work area and clipped the bottom row. This was a review-artifact issue, not game UI. Rebuilt at 1600×900; `art-board.png` now contains all four complete groups. No game layout change was needed.

4. P2, user feedback: exposed brass and wear marks were too subtle. Repainted the two ring and two lock evidence images with broad coherent directional abrasion, smoothed local silver wear bands, and clear matte brass underneath irregular silver plating edges. Object identity and actual display size are unchanged. The earlier sources and comparisons are retained in `docs/qa/item-studies-20260923/feedback-before/`.
5. Post-feedback validation: `detail-feedback-board.png` puts the before/after sources in the same image. New combined source/render comparisons (`1280_item_silver_ring_sound_detail_sound_comparison.png`, `1280_item_silver_ring_flawed_detail_flaw_comparison.png`, `1280_item_silver_lock_sound_detail_sound_comparison.png`, `1280_item_silver_lock_flawed_detail_flaw_comparison.png`, plus their 1600 equivalents) and full-window captures show readable abrasion bands and exposed-brass regions at the actual 198×132 image size. Focused GUI runs exercise all four real variants at both resolutions: 752 assertions each, zero failures, including evidence gates, page visibility, purchase and save/reload. P2 resolved locally; the user subsequently authorized push and merge on 2026-09-23.

No actionable P0/P1/P2 findings remain in the scoped states.

## Full-view and focused comparison

Full view: `1280_item_blue_bowl_repaired_seam.png` and `1600_item_blue_bowl_repaired_seam.png` show the actual drawer alongside the correctly sized bowl on the counter. `1600_item_silver_lock_flawed_detail_flaw.png` verifies the jewelry detail and existing small tabletop object together. `1600_mirror_acknowledged_inventory.png` / `1600_mirror_resentment_inventory.png` show the actual ending stock entries and their existing narrative status.

Focused, combined inputs: `1280_item_blue_bowl_sound_back_comparison.png`, `1280_item_blue_bowl_repaired_foot_wear_comparison.png`, `1280_item_silver_hairpin_mended_seam_comparison.png`, `1280_item_silver_ring_flawed_detail_flaw_comparison.png`, `1280_item_silver_ring_mended_detail_condition_mended_comparison.png`, `1280_item_silver_lock_mended_detail_condition_mended_comparison.png`, `1600_mirror_acknowledged_comparison.png`, and `1600_mirror_resentment_comparison.png`. These compare actual scene captures, not recreated UI textures.

## Required fidelity surfaces

- Fonts/typography: existing game font family, sizes, weights and wrapping retained. Source item paintings contain no UI labels; appraisal labels and Chinese clue copy render in the normal theme. Five bowl page buttons fit at 1280; no new truncation or overlap.
- Spacing/layout: existing drawer width, study image ratio and counter bounds retained. Entire new detail stays visible after selection. Inventory remains the existing compact thumbnail layout; ending text is visible by scrolling its normal entry. Bottom HUD and close controls are unobstructed at both resolutions.
- Colors/tokens: existing paper, ink and wood palette retained. Bowl keeps cream/cobalt; silver keeps muted worn gray with localized yellow only on the earned plating-flaw image. Ordinary and resentful mirrors retain bronze/verdigris, with restrained dried-red residue only on the resentful state. No pink key background or bright glow in game.
- Image quality: actual raster originals are used. Bowl floral pattern, foot mark and repair agree across views. Pin remains one single tapered shaft; ring/lock preserve the existing design. Ring mended is visibly compressed rather than soldered; lock mended shows a gray repair joint. Neutral backs are shared across hidden variants. Macro evidence views are intentionally larger and more textured than the counter thumbnail. Front scales and tabletop shadows are unchanged. Small inventory thumbnails retain silhouette/state cues; their limited microdetail is expected at 68×60.
- Copy/content: no player text, prices, clues, page IDs, scenario data or save schema changed. The existing story gates choose which image is visible. No new free flaw revelation. Ordinary mirror removes blood; resentful mirror retains restrained residue without invented ghost faces or text.

## Validation and limits

Initial v30 validation: 448 art contract assertions, zero failures (v30 and v21 gates/custom overrides/old path compatibility). Actual item UI: 1520 assertions at each viewport, zero failures. Actual mirror inventory UI: 8 assertions at each viewport, zero failures. Unified campaign fixture/replay checks: 2042 passes, zero failures. Godot imports succeeded; git diff --check passed. Headless logs include the macOS system CA certificate access message; actual GUI logs contain no script/resource errors.

This report records local visual QA. After viewing the enhanced details, the user authorized push and merge on 2026-09-23; the GitHub PR records the publication result. Tests cover the selected four groups; unrelated UI and every legacy campaign were not re-tested. The original dirty root worktree was left intact. Generated import metadata outside owned paths remains untracked and is not part of this delivery.

## Implementation checklist

- [x] 17 selected images integrated, including 3 reused bowl sources.
- [x] Neutral free backs and paid evidence gates preserved.
- [x] Ending-state inventory routed to separate PNGs.
- [x] New-view visibility defect fixed and recaptured.
- [x] Native two-resolution visual comparison and save/reload checks.
- [x] Source provenance, preview, reproduction scripts and QA evidence retained.

## Current-main v37 integration validation

Integrated main f4e996b before release. Both new wealthy-customer/watch appraisal and the item study routing are retained. Appraisal material clearing is restricted to atlas views, so ordinary bowl cutouts retain their chroma-key shader; watch views retain their own material and embroidery clears it correctly. The previous v37 report is archived as `docs/qa/item-studies-20260923/previous-design-qa-v37.md`.

Current-main results: 611 art contract assertions across v37/v30/v21; 1441 actual item UI assertions at each of 1280×720 and 1600×900; 8 mirror inventory assertions at each resolution; 13 watch/embroidery atlas transition assertions at each resolution; 2020 named-wealthy story passes. All report zero failures. Import succeeded. Native screenshots were inspected for keyed bowl edges, jewelry detail, ending thumbnails and atlas material transitions. Evidence and logs carry the `v37_` / `v37-` prefix in the QA directory.

The UI harnesses now default to v37 and accept `-- v30` for the legacy campaign. Mirror fixtures for the default run are produced with `tests/named_wealthy_story.gd -- fixtures-only`. These checks cover the affected art surfaces and save restoration, not every v37 gameplay feature or Windows packaging.

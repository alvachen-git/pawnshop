# 第二批鉴物美术 — Product Design QA

final result: passed

## Target and evidence

Base main 5673b92, default named_wealthy_ten v37. Scope: folding fan front consistency/back, inkstone/teapot/silk backs, ordinary pocket-watch earned evidence. This is an existing native Godot game, not a browser prototype. ART04 and the existing object fronts are the visual target.

Source truth: assets/appraisal/fan-sound.png (1448×1086); assets/item_studies_second/folding_fan_back.png (1448×1086); remaining five runtime images in that directory are1536×1024. Exact prompts/reference paths/hashes are in adjacent source JSON; two full-watch images are retained as unused production references. Asset inventory: docs/qa/item-studies-second-20260923/assets.json.

Native Godot4.6.1 compatibility renderer. Viewports1280×720/1600×900 with root.content_scale_size=root.size:1 captured pixel per viewport pixel. No CSS/deviceScaleFactor applies. Appraisal images occupy an approximately198×132 widget. Comparison captures place the actual source and a crop of the actual rendered widget together in equal columns; expected enlargement softness is not source blur. Full-window images are used for actual readability.

Evidence root: docs/qa/item-studies-second-20260923/. Full views include v37_1280_item_folding_fan_counter.png, v37_1280_item_folding_fan_receipt.png, v37_1280_item_folding_fan_inventory.png, v37_1600_item_folding_fan_mended_back.png, v37_1280_item_pocket_watch_flawed_flawed.png and v37_1600_item_pocket_watch_sound_sound.png. Focused source/render comparisons cover the four backs and both watch states; see files ending _comparison.png. The overview art-board.png is a native render of the six new final images.

## Findings and iteration history

1. P2: after scrolling down to appraise, clicking the already-selected front tab did not return the image to view. Four initial UI assertions caught this. Earlier evidence: iteration-1/v37_1280_item_inkstone_sound_front.png and iteration-1/ui-1280.txt. Fixed manual tab selection to reveal the image even when reselecting the same tab; background model refresh retains normal scroll behavior. Both final runs now verify top-of-image visibility and pass.
2. P2: the first whole-movement watch image made local bearing wear too small. An exaggerated-hole attempt looked like missing hardware and was rejected. Final paired macro images use a closer camera while preserving the bearing, jewel and surrounding mechanism. Only localized oval clearance, offset and abrasion differ. Exact imagegen iteration records remain in source JSON. Final full-window and focused comparisons inspected at both resolutions. Static pictures supplement the existing timing text; they do not prove dynamic rate/force or introduce a new diagnosis.
3. Folding fan used an old SVG at counter/receipt/inventory despite detailed desk paintings. All four surfaces now use the approved painting for the neutral front; hidden variants share this neutral view, and the special desk retains its original conditional paintings and knowledge gate. Added a matching plain-paper back and exposed the existing free image tabs in the ordinary fan drawer. No gameplay mutation.

No actionable P0/P1/P2 findings remain in the scoped states.

## Required fidelity surfaces

- Fonts/typography: existing Chinese fonts, sizes, wrapping and hierarchy unchanged; no generated UI text. Existing buttons and clues remain readable at both sizes.
- Spacing/layout: drawer dimensions and aspect-fit study images retained. Fan counter placement has its own footprint and a flattened tabletop projection; contact shadow anchors its silhouette. Inventory68×60 and receipt views keep their existing layout. Image tabs fit, selected images remain in view, persistent controls remain unobstructed.
- Colors/tokens: old paper, dark wood, muted stone/clay/silver match ART04. Transparent backs have no black/checkerboard halos in the game. Watch macros retain their illustrated workbench/material background as intentional evidence images.
- Image quality: same fan ribs/pivot/paper, neutral reverse surfaces, believable object thickness; no additional stamps or authenticity marks. Watch compositions remain paired, with restrained material highlights. Expected small-widget sampling is documented; anatomy here is illustrative, not a technical watch-repair diagram.
- Copy/content: no player copy, prices, actions, scenario records, page IDs or save schema changed. Existing clues unlock sound/flawed pages. Custom art paths still win. Neutral backs do not reveal hidden condition.

## Validation and limits

959 art contract assertions,0failures, coveringv37/v30/v21. Actual current-v37 GUI:1393 assertions at each viewport,0failures. Nine naturally scheduled item variants cover three reverse views, all three ordinary-watch conditions and all three fan attribution variants; tested free browsing, evidence actions, receipts, purchases, inventory, replay save restoration and empty-counter visibility. Existing gold-watch/embroidery atlas switching:13assertions,0failures. Import succeeded. Final native GUI logs contain no script/resource errors. git diff --check passed.

Earlier sandbox headless startup failed in the system log rotator, then succeeded outside the sandbox; the initial harness incorrectly accessed a title menu after direct startup and was fixed before validation. These are not claimed as passing runs.

Local QA record: the user subsequently authorized push and online merge; publication is tracked by the GitHub PR. No Windows build or unrelated full-story regression. Previous design report archived as previous-design-qa.md. Root dirty worktree untouched. User save/library paths are not used by the QA script.

## Implementation checklist

- [x] Six new images copied into project with exact prompts/provenance.
- [x] Fan source reused consistently with tabletop sizing/contact shadow.
- [x] Free backs and earned evidence, custom paths and saves preserved.
- [x] Same-tab visibility fixed and recaptured.
- [x] Native full-window and combined source/render comparison at both resolutions.

## Release integration: current main v39

Merged db4182b before publication, retaining the pearl appraisal and first-debt systems. The only code conflict was the CounterItemArt material allowlist; the resolution includes both new dragon/phoenix bangles and this batch's fan/study images. No gameplay conflict or scenario mutation.

Current-main validation:1509 art-contract assertions (v39/v38/v37/v30/v21),1350 native GUI assertions at each viewport,13 atlas-switch assertions,23030 appraisal/economy/replay passes through first_debt_unified_appraisal.gd; all0failures. The latter inherits the PEARL V38 output title but explicitly uses the v39 manifest/session/replay. Final native logs contain no errors. Reviewed v39_1280_item_folding_fan_counter.png and v39_1600_item_pocket_watch_flawed_flawed.png; the existing size, shadow, tabs and evidence presentation remain intact. Selected v39 screenshots/logs are retained with the earlier evidence.

The current-main atlas harness assertion was updated from its stale v38 expectation to the actual v39 entry. Dragon/phoenix mapping, contact mode and wrist-scale checks pass. Scoped diff against origin/main passes whitespace checks; inherited unrelated main whitespace is left unchanged.

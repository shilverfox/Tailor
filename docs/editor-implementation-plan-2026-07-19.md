# Tailor core editor implementation plan

Date: 2026-07-19 (updated 2026-07-20)  
Source of requirements: `docs/editor-capability-audit-2026-07-19.md`

## Product target

Tailor must provide guided creative freedom: a non-designer can start from a polished template, customize it precisely, and still receive an attractive print-ready result. Every persisted edit must render identically in Editor, Reader, PDF and video.

## Non-negotiable invariants

1. Photos remain local and original Photos assets are never modified.
2. Editing stays non-destructive and reopenable.
3. One document property has one renderer contract across every output.
4. A direct gesture creates one Undo transaction.
5. Templates and safe areas protect users from accidental low-quality output without preventing intentional customization.
6. No visual feature is complete until it has persistence, migration, Undo/Redo, Reader, PDF and real-output evidence.

## Logical execution order

### M1 — precision canvas

- Zoomable/pannable page viewport with Fit, zoom percentage and bounded zoom.
- Discoverable selected state and real resize/rotation handles.
- Centre, safe-margin and neighbouring-element snap guides.
- Precise movement/resizing that remains normalized across A4 and Letter.
- Physical-device gesture and accessibility coverage.

Exit: users can place one image or text element accurately without repeated trial-and-error.

### M2 — arrangement

- Align and distribute commands.
- Multi-select, group/ungroup, lock/unlock and duplicate.
- Copy/paste within and across compatible pages.
- Layers panel with stable ordering and visibility.

Exit: users can create and manage a deliberate multi-element composition.

### M3 — appearance model

- Element opacity, corner radius, border and shadow.
- Shape, background and decoration layers.
- Mask shapes with explicit PDF geometry.
- Schema migration and complete render-plan manifest fields.

Exit: a composition can create depth and hierarchy without flattening assets.

### M4 — photo finishing

- Shared non-destructive Core Image adjustment model.
- Exposure/brightness, contrast, highlights, shadows, warmth, saturation, vignette and sharpness.
- Curated Tailor presets plus conservative Auto Enhance.
- Flip/straighten; perspective correction only after prototype validation.

Exit: difficult real photos can be made visually coherent while preserving originals.

### M5 — typography

- Alignment, tracking, line height and paragraph spacing.
- Direct text-frame resizing and explicit auto-fit policies.
- Curated font-pair and hierarchy presets.
- Contrast and print-size validation.

Exit: text can be composed intentionally rather than only edited as content.

### M6 — guided beauty

- Focal-point/aspect-aware layout variants.
- Composition checks for spacing, alignment, contrast, tiny text, excessive rotation and unbalanced whitespace.
- One-tap repair suggestions with Undo.
- Apply layout/style to page, chapter or book without overwriting locked edits.

Exit: customization increases personal expression without lowering the default visual quality.

### M7 — evidence and framework decision

- Real-photo Editor/Reader/PDF matrix at phone and 300-DPI output.
- CE.SDK four-page spike and Mantis crop round-trip spike kept outside the production target.
- Build-vs-buy decision covering privacy, offline behavior, licensing, migrations, binary size and accessibility.

Exit: named product/design approval plus a documented dependency decision.

## Current execution

M1 through M6 are implementation-complete for the native editor. M7 now includes a local focal-aware initial crop, deterministic canvas evidence, a real-PhotoKit simulator flow and inspected 300-PPI grid output; physical-device focal/gesture evidence, multilingual output and named aesthetic approval remain release gates.

Implemented and verified:

1. pure normalized snap engine and visible centre/safe/peer guides;
2. 100–300% zoomable canvas, two-axis pan and Fit reset;
3. independent, accessible resize and text-rotation controls;
4. persistent interaction lock separated from auto-arrange protection;
5. duplicate photo, six alignment commands and four layer-order commands;
6. Debug-only deterministic fixtures with the Release target compiled cleanly;
7. 81 unit tests passing, 46/47 full UI tests passing directly, and the sole ambiguous text diagnostic fixed and passing twice.
8. persistent multi-select groups, group movement, align/distribute, cross-page copy/paste and a visible/lockable ordered Layers panel;
9. hidden layers are excluded from the shared Editor/Reader/PDF render plan and Book Check;
10. 83 unit tests pass after the complete M2 schema and rendering changes.
11. persistent photo opacity, square/rounded/oval masks, adjustable corner radius, solid/dashed custom-color borders and adjustable shadows;
12. one normalized appearance contract renders through Editor/Reader and Quartz PDF, with legacy defaults and atomic Apply/Undo;
13. a shared non-destructive Core Image pipeline for exposure, brightness, contrast, saturation, warmth, highlights, shadows, vignette and sharpness;
14. visible Natural, Bright & clean, Warm memory, Soft portrait and Editorial presets, with the same processor used by PhotoKit preview, crop and PDF export;
15. 85/85 unit tests pass, including appearance migration, Core Image pixel-change and custom-appearance PDF export; focused appearance/finishing UI automation passes.
16. persistent decoration shape layers with fill color, square/rounded/oval masks, opacity, border, shadow, free resize, rotation, grouping, ordering, visibility and locking;
17. decoration elements are serialized and consumed by the same Editor/Reader render plan and Quartz PDF geometry, with a restrained default placement that does not obscure primary content;
18. 86/86 unit tests pass, the focused decoration design/layer/Undo UI test passes, the 70-page render matrix remains green and the unsigned Release iphoneos build succeeds.
19. persistent per-page background colors with curated light palettes and a native custom color control, staged through Cancel/Apply and one Undo transaction;
20. the resolved paper color travels in the shared render plan and paints the same Editor/Reader canvas and Quartz PDF base beneath the authored style texture.
21. persistent horizontal/vertical flip and ±15° straighten controls, with blank-edge-safe crop normalization and the same transform geometry in Editor, Reader and Quartz PDF;
22. deterministic conservative Auto Enhance based on on-device Core Image luminance analysis, leaving originals untouched and every suggested value editable;
23. geometry/finishing changes stage behind Cancel/Apply, commit as one document change and restore exactly with one Undo; reset and replacement paths clear source-specific finishing consistently;
24. 89/89 unit tests pass in `EditorM4-tools-full-unit.xcresult`; focused appearance and geometry/Auto Enhance UI tests pass in `EditorM4-appearance-ui-r9.xcresult` and `EditorM4-geometry-auto-ui-r10.xcresult`; the unsigned iphoneos Release build and `git diff --check` pass.
25. persistent per-text alignment, tracking, line-height and paragraph-spacing values, stored relative to physical font size and consumed by the same Editor/Reader/PDF attributed-paragraph contract;
26. Editorial title, Quiet caption and Personal note hierarchy/font-pair presets, plus continuous font sizing and direct text-frame geometry inherited from M1;
27. deterministic Core Text wrapping and paragraph-spacing-aware height validation, preserving exact Unicode grapheme limits and blocking real frame overflow before save/export;
28. a shared 11pt print floor and sRGB contrast assessment against the actual authored page background; low contrast appears immediately in the keyboard-aware editor and in Book Check, with an optional coordinated one-tap repair;
29. the contrast repair improves the deterministic UI fixture from 1.0:1 to 10.7:1 without leaving the draft. `EditorM5-readability-ui-r4.xcresult` and its before/after attachments are the visual evidence;
30. 94/94 unit tests pass in `EditorM5-typography-readability-full-unit-r4.xcresult`; the focused typography/Undo and readability UI tests pass, the unsigned iphoneos Release build succeeds and `git diff --check` is clean.
31. conservative Book Check composition rules detect accidental near-alignment, uneven row/column spacing, excessive rotation, orphaned or detached user captions and heavily biased whitespace only on eligible user-authored content;
32. exact repair payloads make alignment, distribution, straightening, contrast and page rebalancing deterministic; interaction locks and locked pages are never bypassed, and each repair is one Undo transaction;
33. duplicate-photo warnings are consolidated once per repeated asset instead of once per placement, while curated default styles no longer produce contrast-warning noise;
34. Style supports per-page, per-chapter and whole-book scope. Chapter application skips locked pages and preserves element geometry, crops, text and custom backgrounds in one atomic history step; Auto Arrange already provides the matching page/chapter/book scope;
35. `EditorM6-full-unit-r1.xcresult` passes 101/101 tests. Focused UI evidence passes for contrast repair/Undo (`EditorM6-book-check-repair-ui-r5.xcresult`), exact alignment/Undo (`EditorM6-alignment-repair-ui-r1.xcresult`) and locked chapter style/Undo (`EditorM6-style-scope-ui-r1.xcresult`);
36. the unsigned iphoneos Release build succeeds from `artifacts/build/EditorM6-Release`, its executable contains no UI fixture launch markers, and `git diff --check` is clean.
37. the local Vision animal observation now persists a normalized subject region and new automatic layouts use it to choose a blank-edge-safe initial crop without adding another model request or touching user-authored crops;
38. a base Fill crop can now pan through legal aspect-ratio excess at scale 1. The previous unconditional zero-offset shortcut prevented both manual focal correction and subject-aware composition for landscape/portrait mismatches;
39. focal metadata migrates as optional local geometry, survives archive round-trip and incremental scan merge, and remains ignored for Fit, rotated, transformed or user-owned elements;
40. `EditorM7-focal-full-unit-r1.xcresult` passes 103/103 tests, the unsigned iphoneos Release build succeeds from `artifacts/build/EditorM7-Focal-Release`, Release fixture markers are absent and `git diff --check` remains clean;
41. current E01–E09 interpretation and remaining evidence are recorded in `docs/editor-prototype-conformance-audit-2026-07-20.md`; the conditional Mantis adapter decision is recorded in `docs/mantis-crop-spike-2026-07-20.md`.
42. focal composition now uses the physical Letter/A4 page aspect instead of treating normalized page units as square pixels, so the initial crop magnitude matches the shared Editor/Reader/PDF render plan;
43. focal offset projection now preserves legal movement on the axis with aspect-fill excess even when the other axis has no slack. This fixes a real-photo case where a slightly off-centre Y coordinate previously collapsed an otherwise valid horizontal crop back to zero;
44. `EditorM7-focal-crop-ui-r4.xcresult` proves a right-edge synthetic subject is brought into a narrow photo frame at scale 1 with no blank edge; `EditorM7-focal-full-unit-r2.xcresult` passes 103/103 tests and the screenshot attachment is retained beside the result bundle;
45. official Mantis `v3.1.0` (`0960be1`) builds against the installed iOS simulator SDK and its complete 164/164 upstream test suite passes in `Mantis-v3.1.0-all-unit-r1.xcresult`. This approves continued adapter prototyping only, not production adoption;
46. the unsigned iphoneos Release build succeeds from `artifacts/build/EditorM7-Focal-Axis-Release`; UI launch and focal-fixture markers are absent from the executable and `git diff --check` is clean.
47. `Spikes/MantisAdapter` pins the official remote Mantis 3.1.0 revision without changing `Tailor.xcodeproj`. Its versioned envelope persists only opaque `CropInfo` JSON, rejects unknown schema/package/provider values and requires the caller to supply the original image for every replay;
48. `TailorMantisAdapter-unit-r1.xcresult` passes 2/2 tests: encode/reopen/render produces byte-identical PNG output to a direct Mantis crop of the same original, while validation failures are explicit. Tailor UI session capture, perspective replay, Undo and four-surface equality remain open.
49. Mantis is a documented no-go for v1: the native crop already satisfies the required contract, while perspective is not a current release requirement and does not justify a second opaque schema before real-user evidence;
50. four photorealistic-natural QA inputs now cover right-edge/backlit, high portrait/low-contrast, dark-fur/low-light and white-fur/highlight stress cases. Their prompts, dimensions and hashes are recorded in `docs/m7-photorealistic-qa-manifest-2026-07-20.md`; they are imported into the QA simulator and excluded from the app bundle.
51. a Debug-only QA route now requests real Photos authorization, fetches PhotoKit assets by local identifier, byte-deduplicates repeated imports and builds the editor from exactly four unique sources; `EditorM7-real-photo-pdf-ui-r24.xcresult` passes the Editor → Reader → PDF path 1/1;
52. the production builder now selects a balanced 2×2 layout for exactly four photos instead of placing them in an unbalanced three-column 3+1 arrangement; the focused layout test and latest real-photo screenshot pass;
53. PDF export requests source pixels from each element's actual physical print footprint, including aspect-fill excess and crop zoom. The latest Letter grid embeds all four user photos at 300×300 PPI instead of relying on a fixed square request;
54. Book Check computes effective PPI from the real page/frame/crop geometry: below 150 PPI blocks output, 150–299 PPI produces an actionable suggestion, and 300 PPI or higher passes. The latest low-resolution cover is correctly reported at approximately 229 PPI;
55. the pre-crop-gate suite passed 106/106 in `EditorM7-full-unit-r3.xcresult`; after adding the gate, `EditorM7-full-unit-r5.xcresult` passes 107/107 and the unsigned iphoneos Release build succeeds in `artifacts/build/EditorM7-Crop-Gate-Release`;
56. all six pages of the latest PDF were rendered at 150 DPI and inspected. Rendering is structurally clean, but the simulator's unavailable Vision inference leaves the high portrait cat cropped outside its landscape cell. Physical-device focal output therefore remains a release blocker.
57. Book Check now blocks any untouched automatic Fill crop that lacks focal metadata and retains less than 65% of its source. The user can intentionally approve it by opening Crop and confirming; `EditorM7-real-photo-crop-gate-ui-r25.xcresult` proves the broken 51%-cropped portrait placements cannot silently reach export.

Next execution slice:

1. physical-iPhone validation of focal detection/crop across Editor, Reader, Letter and A4 PDF;
2. real-user-photo finishing and multilingual typography comparison at phone and print output;
3. physical-iPhone gesture/accessibility evidence for M1 through M6;
4. signed archive, App Store validation and named product/design approval.

## Completion tracking

| Milestone | State | Evidence required |
| --- | --- | --- |
| M1 precision canvas | Implementation complete; device gate pending | Unit/UI tests pass; physical-iPhone recording remains |
| M2 arrangement | Implementation complete; device gate pending | Multi-select/group/copy/layers UI evidence and 83/83 unit tests pass |
| M3 appearance | Implementation complete; physical-device visual sign-off remains | Photo/shape/background persistence, focused UI/PDF evidence and 70-page render matrix pass |
| M4 photo finishing | Implementation complete; device/design gate pending | Round-trip, pixel-change, PDF and UI tests pass; real-photo phone/300-DPI matrix and named aesthetic approval remain |
| M5 typography | Implementation complete; device/design gate pending | Shared persistence/rendering, Unicode/overflow, 11pt print floor, contrast repair, 94/94 unit and focused UI tests pass; real multilingual print matrix remains |
| M6 guided beauty | Implementation complete; real-photo design gate pending | 101/101 unit tests, focused contrast/alignment/chapter-scope UI tests and Release build pass; focal-aware variants and named design review remain in M7 |
| M7 evidence/framework decision | In progress | Focal crop, prototype audit, v1 Mantis no-go, 107/107 regression, real-PhotoKit simulator flow, inspected 300-PPI grid and severe-crop export gate pass. Physical-device/user-photo/A4/Letter focal validation and signed release decision remain |

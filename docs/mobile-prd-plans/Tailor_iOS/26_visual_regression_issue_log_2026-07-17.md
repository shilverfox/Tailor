# Visual regression issue log — 2026-07-17

Scope: regression observation only. No production code was changed as part of this run.

Evidence root: `artifacts/visual-qa/memory-book/current/F-RP-VIS-01/`.

## Gate result

**FAIL — do not mark the Memory Book visual gate passed.** The evidence is useful for checking that the three candidate materials reach Reader/PDF, but it cannot establish pixel parity. The Reader/Editor screenshots use a separate UI demo document while the PDF/manifest use the seven-page `F-RP-01` fixture; therefore element-level three-endpoint consistency is explicitly out of scope for this evidence set.

The registered design references are all `candidate`, not `approved`, in `design/visual-qa/reference_manifest.md`; no pixel-perfect approval may be claimed.

## P0 blockers

| ID | Finding | Evidence | Impact / required re-test |
| --- | --- | --- | --- |
| VIS-R-001 | The fixture image label in the exported cover is clipped at the left edge in all reviewed PDFs. It renders as `R FIXTURE` or `LOR FIXTURE`, rather than a complete label. | `warmPaper/{a4,letter}/01-cover/pdf-raster.png`, `quietNight/{a4,letter}/01-cover/pdf-raster.png`, `fieldNotes/{a4,letter}/01-cover/pdf-raster.png` | **Fixture blocker, not a production crop defect.** The current edge-marker artwork is unsafe for crop/bleed sign-off. Replace it with a dedicated safe-area focal/boundary calibration asset, then re-export all pages. |
| VIS-R-002 | The Warm Paper A4 editor capture is a black launch/system frame rather than an editor screen. | `warmPaper/a4/01-cover/editor-display.png` | The three-endpoint evidence is incomplete. Recapture after the editor has reached a stable, visible page; do not substitute a launch frame. |
| VIS-R-003 | The six cover artifacts do not use the same document at all three endpoints: Reader/Editor show `Milo` plus a placeholder image and `1 of 8`, whereas PDF/manifest are seven-page F-RP-01 and use a fixture graphic. | All `*/01-cover/{editor-display.png,reader.png,pdf-raster.png,manifest.json}`; manifest has `pageCount: 7` | No element geometry/text/crop parity conclusion is possible. Provide editor and reader captures loaded from the frozen F-RP-01 document, keyed by the same document hash/manifest, before tri-endpoint comparison. |
| VIS-R-007 | The newly captured Warm/Letter same-document seven-page UI evidence renders its QA virtual asset as `Photo unavailable`. | Warm/Letter same-document seven-page capture reported by QA; F-RP-01 visual fixture path | The UI side is not representative of the PDF fixture and cannot validate crop, image treatment or layout. The virtual asset provider must resolve the exact frozen fixture IDs in the UI capture environment. |
| VIS-R-008 | Reader preview is watermarked while the compared PDF is a non-watermarked export. | Warm/Letter same-document seven-page capture reported by QA | Watermark is a material pixel/contrast difference, therefore a visual diff is invalid. Compare preview-to-preview (both watermarked) and export-to-export (both non-watermarked), with the watermark state in evidence metadata. |
| VIS-R-009 | **Resolved in UI retest (2026-07-17).** The Warm Paper / Letter F-RP-01 multi-line dedication and three contents entries now render in full. | `warmPaper/letter/02-dedication/retest-r2/{editor-fixture.png,reader-fixture.png}`; `03-contents/retest-r3/reader-fixture.png` | Original P0 content-loss blocker is closed for the reviewed UI paths. It does not close the separate PDF raster / same-asset visual-evidence gate. |

## P1 observations

| ID | Finding | Evidence | Follow-up |
| --- | --- | --- | --- |
| VIS-R-004 | Warm Paper, Quiet Night and Field Notes materials are visibly distinct and readable in PDF. Their Reader directions also retain the intended warm paper, dark paper and ruled field-note treatments. No system-blue navigation token was observed in reviewed Reader captures. | Reviewed `reader.png` / `pdf-raster.png` for three templates, A4 plus Letter PDF variants | Direction-only observation; retain as candidate until approved reference and same-document captures exist. |
| VIS-R-005 | A4 and Letter exports preserve the expected portrait paper proportions; no texture tiling seam was visible in the sampled covers. | Six PDF rasters | Recheck across all seven page kinds once P0 fixture/capture issues are resolved. |
| VIS-R-006 | PDF still uses a synthetic graphic rather than a real authorized photo fixture. That is acceptable only for regression mechanics; it cannot validate real-photo crop quality, tonal treatment or print legibility. | Six PDF cover rasters | Add a fixed non-sensitive photo fixture with known focal markers for visual test only. |
| VIS-R-010 | The editor contents page exposes all three title/page values, but lays each page number on its own next line; the Reader uses the intended one-line `title · page` rows. | `warmPaper/letter/03-contents/retest-r2/editor-fixture.png` versus `retest-r3/reader-fixture.png` | P1 visual-parity defect. Preserve the resolved P0 content completeness, but align the Editor contents row treatment with the shared text layout before a pixel-level sign-off. |

## Required re-run order

1. Make the F-RP-01 virtual asset provider resolve every frozen asset in the Editor and Reader capture process; `Photo unavailable` is a blocker.
2. Use a single frozen F-RP-01 document and its manifest/hash for Editor, Reader and PDF.
3. Align comparison state: Preview artifacts are all watermarked; export artifacts are all non-watermarked. Do not diff across those states.
4. Replace the clipped fixture and capture stable Editor/Reader screens (no launch/black frames).
5. Capture all 42 cells: 3 templates × 2 paper sizes × 7 page kinds, including normalized images and visual diffs.
6. Only after a product-approved visual baseline exists may Design/QA perform pixel sign-off.

## Round 2 review protocol (pending evidence)

Scope: one frozen Warm Paper / US Letter seven-page document, with a safe-area focal/boundary calibration image. For each page kind (cover, dedication, contents, chapter opener, photo selection, milestone, closing), inspect the Editor, watermarked Reader preview and non-watermarked PDF export separately.

- **Background:** warm-paper color, texture opacity/scale, paper inset and no seams.
- **Typography:** ink and secondary color, readable type, line breaks and alignment; do not compare the Reader watermark state to the non-watermarked export.
- **Photo geometry:** focal marker remains inside its declared safe zone; crop, rotation and corner radius align with the frozen manifest.
- **Surface treatment:** paper edge, image border and shadow are present only where defined by the shared render plan.
- **Watermark:** Reader must visibly have the intended preview watermark; PDF export must not. This is a state assertion, not a cross-state pixel-diff target.

A conditional pass requires all assets to resolve, no launch/black frame, one matching manifest/document hash for all three endpoints, and no P0 geometry or legibility defect. It remains a candidate-direction result until approved product design baselines are registered.

## Round 2 interim result — Warm Paper / US Letter, Editor + Reader

**Not conditionally passed.** Pages 1–7 are present in the intended semantic order; the center and corner calibration markers are visible on image pages (1, 4, 5, 6), assets resolve, and there is no black launch frame or `Photo unavailable` placeholder. The warm paper texture, ink/secondary text colors, paper edge and general image placement are visually aligned between Editor and Reader at their respective display scales. Reader is captured in the purchased/no-page-watermark state, so the absence of an on-page watermark is not itself a defect for this capture.

The above positive observations do not override VIS-R-009. PDF remains outside this interim review because it still uses a different regression image asset.

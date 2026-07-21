# Warm Paper approved baseline

Status: **approved**  
Date: 2026-07-23

These editable SVG sources and their PNG exports are the approved design baseline for the production-default Warm Paper fixture. The page content is limited to the frozen fixture in design request 28. The two source photographs are newly generated, non-user QA placeholders and carry no additional product narrative.

## Frozen geometry and styling

- Page sizes: US Letter `612 × 792 pt`; A4 `595 × 842 pt`.
- Paper rectangles: Letter `(18,18,576,756)`; A4 `(17.5,17.5,560,807)`.
- Frames are exactly the normalized production frames: title `(0.08,0.08,0.84,0.10)`, subtitle `(0.08,0.17,0.84,0.06)`, structural image `(0.08,0.27,0.84,0.40)`, relative to `paperRect`.
- PhotoSelection starts from the diptych slots `(0.08,0.27,0.41,0.40)` and `(0.51,0.27,0.41,0.40)`, then uses the production `normalizeFitImageFramesToAssetAspect()` rule so the approved image frames match the visible fitted photo bounds: landscape `(0.08,0.3546875,0.41,0.230625)` and portrait `(0.6025,0.27,0.225,0.40)`.
- Structural images use centered `fill`; photoSelection images use centered `fit`. Focal point is `50% 50%`; fitted images keep crop scale `1` and crop offset `0`.
- All automatic images use rotation `0°`, corner radius `2 pt`, no border and no shadow.
- Title: Iowan Old Style Regular, `paperWidth × 0.045`, deep ink `#183A31`, left aligned.
- Subtitle/body/contents: Helvetica Regular, `paperWidth × 0.026`, secondary ink `#64756C`, left aligned. The contents entry uses deep ink.
- Paper: `#F8F3E8`; backdrop: `#EFE4D1`; deterministic fine grain; clay accent `#B85639`.
- Z-order: backdrop → paper → texture → photos/contents/accent → subtitle → title.
- Letter/A4 reflow rule: retain normalized frames and recompute against each paper rectangle; type scales from paper width. No independent optical repositioning.

The SVG files are the editable sources. PNGs are exported at 3× canonical page size for pixel comparison.

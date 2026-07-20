# Tailor editor capability and visual-quality audit

Date: 2026-07-19  
Scope: `MemoryBookDocument`, page editor, crop editor, reader and PDF renderer

## Verdict

**The editor now has a substantial non-destructive custom-design foundation, guided-beauty rules and a focal-aware initial crop, but release readiness still depends on real-photo/physical-device evidence.**

It is functionally stronger than a simple crop screen: edits are non-destructive, normalized, undoable, persisted and shared by Editor/Reader/PDF. However, the current creative ceiling is determined mostly by five templates and five fixed photo layouts. Users cannot yet precisely compose a polished page with the level of control expected from a modern visual editor.

The editor should therefore remain a release blocker until the P0 creative-control and visual-output gates below are complete.

## 2026-07-20 M7 evidence update

- The simulator now exercises four unique generated-natural inputs through the real PhotoKit API rather than bundled fixtures. Editor, Reader and PDF traversal passes.
- The four-photo automatic layout was corrected from an unbalanced three-column 3+1 result to a balanced 2×2 composition.
- PDF image requests now derive from each element's physical print footprint. Poppler verifies the four-photo Letter grid at 300×300 PPI.
- Book Check now evaluates actual per-placement effective PPI, warns at 150–299 PPI and blocks below 150 PPI.
- A new export gate blocks untouched automatic Fill crops that have no focal metadata and retain less than 65% of the source; users may intentionally approve the result by opening Crop and confirming it.
- The latest unit suite passes 107/107, the focused real-PhotoKit crop-gate UI test passes, and the unsigned iphoneos Release app builds with no Debug QA marker leakage.
- This does **not** close aesthetic approval: simulator Vision cannot create an inference context, and the no-focal portrait cat crop visibly loses its face. The defect can no longer silently export, but physical-iPhone focal evidence remains P0.

## What the current implementation does well

| Capability | Status | Notes |
| --- | --- | --- |
| Non-destructive document model | Strong | Images and text remain elements with normalized frames, crop transforms, rotation and layer order. Original Photos assets are not modified. |
| Shared output contract | Strong | Editor, Reader and PDF consume `MemoryBookPageRenderPlan`; crop and text contracts are tested across output sizes. |
| Page management | Implemented | Add, duplicate, delete and move editable pages; structural pages remain protected. |
| Layout templates | Implemented, limited | Single, two-up, 2×2, 3×2 and note layouts. |
| Image placement | Implemented | Move, resize, rotate, fit/fill, crop, replace, remove and z-order. |
| Crop safety | Strong | Fixed aperture, fill invariant, rotation-aware geometry, dirty-exit handling, Undo/Redo. |
| Text basics | Implemented | Semantic fields/free note, four curated font families, continuous size, arbitrary color, movement and rotation. |
| Book styles | Implemented | Five code-level styles with shared backgrounds, texture and selected image treatment. |
| History | Implemented | Up to 50 in-memory document snapshots with atomic gesture transactions. |
| Book check | Guided and actionable | Detects blocking data/layout issues plus conservative alignment, spacing, rotation, caption, whitespace and authored-color problems; safe repairs are exact and Undoable. Real-photo aesthetic approval remains a release gate. |

## Creative and aesthetic gaps

### P0 — required before calling this a core custom-design editor

1. **Canvas navigation and precision — implemented, device gate remains**
   - The canvas supports 100–300% zoom, two-axis pan and Fit reset.
   - Visible resize/rotation controls, normalized geometry and snapping guides support detail editing without changing print geometry.
   - Remaining gate: physical-device gesture/accessibility review and optional numeric inspector/ruler refinement.

2. **Alignment and layout intelligence — implemented, aesthetic gate remains**
   - Centre/safe/peer snapping guides, six alignment commands and horizontal/vertical distribution are available.
   - Multi-select, grouping, interaction locks, duplication, cross-page copy/paste and an ordered Layers panel persist in the document.
   - Book Check catches near-alignment, uneven spacing and excessive rotation and can apply exact, single-Undo repairs without moving protected content.

3. **Photo finishing — implemented, real-photo gate remains**
   - Per-photo exposure, brightness, contrast, highlights, shadows, warmth, saturation, vignette and sharpness form a persistent non-destructive Core Image stack.
   - Five presets and conservative Auto Enhance remain editable and use the same Editor/Reader/PDF processor.
   - Flip and rotation-aware straightening are implemented; perspective correction is a remaining advanced enhancement.

4. **Frames, masks and depth — implemented for the release scope**
   - Photos and shape layers support square, rounded and oval masks, adjustable radius, opacity, border and shadow.
   - Appearance persists and renders through Editor, Reader and PDF. Organic/vector masks and blend modes remain optional future depth features.

5. **Typography capable of real composition — implemented, evidence gate remains**
   - Per-element alignment, tracking, line height and paragraph spacing persist and render identically in Editor, Reader and PDF.
   - Direct text-frame resizing, Fit text, continuous size and three curated hierarchy/font-pair presets are available.
   - A shared 11pt print floor, true overflow measurement and sRGB text/background contrast checks protect output quality; low contrast has an immediate one-tap coordinated repair and also appears in Book Check.
   - Remaining gate: real Chinese/Arabic/emoji and long-form typography review in rasterized 300-DPI A4/Letter output on a physical device.

6. **Background and decorative layers — implemented for the release scope**
   - Users can now add persistent, freely transformable color shapes with masks, border, opacity and shadow, plus curated or custom per-page background colors. Gradients, dividers, dates and a curated decorative library are still missing.
   - The element model supports `image`, `text` and `shape` through the shared renderer contract. Gradients, dividers, dates and a curated decorative library remain future additions.

7. **Beauty guardrails — implemented conservatively, design gate remains**
   - `Book Check` catches text overflow, the 11pt print-size invariant, authored low contrast, accidental near-alignment, inconsistent spacing, excessive rotation, orphaned/detached captions and heavily biased whitespace.
   - Alignment, distribution, straightening, contrast and balance repairs are deterministic, respect page/interaction locks, and commit as one Undo step. Template geometry is trusted to avoid noisy subjective warnings.
   - Remaining gate: named review against the real-photo, multilingual phone/300-DPI matrix and focal-aware layout variants.

### P1 — high-value differentiation

- Broader smart layout variants based on photo count remain open; source aspect and the locally detected pet focal region now guide the initial automatic crop.
- Style-preserving layout variants rather than only a global five-style switch.
- Curated font combinations, palette extraction from selected photos and accessible contrast correction.
- Optional handwritten layer using PencilKit, stored as vector/stroke data until export.
- Reusable user layouts and “apply this look to chapter” behavior.
- Before/after preview for image adjustments and a one-tap tasteful Auto Enhance.

## Visual-output evidence finding

The existing tests prove document integrity and renderer consistency; they do **not** prove that arbitrary user compositions are beautiful.

Current visual evidence also contains unavailable-photo placeholders or synthetic calibration graphics in several Editor/Reader/PDF captures. Those fixtures are useful for geometry but cannot sign off real-world focal choice, tonal quality, hierarchy or emotional presentation.

A release-quality editor needs a curated real-photo evaluation set covering:

- portrait pet in landscape frame and landscape pet in portrait frame;
- dark, backlit, low-contrast and high-saturation photos;
- close-up face, full body, multiple animals and subject near each edge;
- one, two, four and six-photo pages;
- short/long Latin text plus Chinese, Arabic and emoji;
- all supported paper sizes and styles.

Each case must be reviewed in Editor, Reader and rasterized PDF at print resolution.

## Third-party framework assessment

Revalidated against the maintainers' public documentation on 2026-07-20. No third-party editor is linked into the production target at this gate: replacing a proven normalized document/render contract without a round-trip spike would add release risk rather than improve output quality.

| Option | Fit for Tailor | Recommendation |
| --- | --- | --- |
| IMG.LY CreativeEditor SDK | Closest to a full multi-page design system: templates, lockable placeholders, snapping, advanced typography, effects, asset sources and print-ready PDF. The current product documentation confirms customizable/headless UI, client-side processing and MAU-based commercial licensing; a fully offline deployment requires a licensing discussion. | **Run a bounded technical/product trial only if Tailor deliberately becomes Canva-like.** Do not integrate before verifying offline license-failure behavior, PhotoKit asset handling, scene persistence/migration, binary size, accessibility and exact PDF/privacy behavior. [Official product overview](https://img.ly/products/creative-sdk/) |
| Mantis 3.1.x | MIT Swift/SwiftUI cropper with embedded/custom toolbars, fixed/free ratios, rich shapes, straighten, flip, perspective, per-session Undo/Redo, large-image controls and persisted `Codable CropInfo`. Official `v3.1.0` builds locally and passes its 164/164 upstream tests; the isolated Tailor versioned-envelope spike passes 2/2 original-image replay tests. Its iOS 15 floor is compatible with Tailor's iOS 17 floor. | **Preferred crop-only spike.** Upstream and basic adapter feasibility are proven, but production adoption still requires genuine UI-produced perspective state, Tailor Undo and Editor/Reader/PDF equality. Do not flatten and save a derived bitmap as the source of truth. [Official repository](https://github.com/guoyingtao/Mantis) |
| ZLImageEditor | MIT single-image editor with draw, crop, mosaic, text/image stickers, filters and brightness/contrast/saturation; supports SwiftUI/SPM. | **Reference or optional single-photo tool, not the book canvas.** Its flattened-image workflow does not solve multi-page layout and risks splitting Tailor's non-destructive render contract. |
| TOCropViewController 3.1.x | Mature MIT crop controller with crop-box resizing, fixed aspect ratios, circular crop and 90° rotation. | Not enough value over the current cropper or Mantis: it does not provide Mantis's persisted perspective/straightening model. [Official repository](https://github.com/TimOliver/TOCropViewController) |
| Banuba Photo Editor SDK | Rich commercial selfie/AR/background/overlay tooling. | Not recommended for the core memory-book editor; feature emphasis and aesthetic are misaligned. |
| Apple Core Image | Native, on-device, extensive adjustment/filter/compositing pipeline. | **Recommended for Tailor's non-destructive photo-adjustment layer.** Persist parameters in the document and use one shared Core Image renderer for canvas, Reader and PDF. |
| Apple PencilKit | Native low-latency drawing with finger/Pencil, selection and eraser tooling. | Optional P1 handwriting/drawing layer; not a replacement for the layout engine. |

## Recommended product architecture

### Preferred path: guided creative editor built on the current document model

Tailor's promise is a beautiful keepsake for non-designers. The best default is not an unrestricted blank canvas; it is **guided freedom**:

1. `Quick Design`: curated templates, smart layout suggestions, focal-point-aware crops and one-tap styling.
2. `Customize`: direct manipulation, alignment guides, photo finishing, frames/masks, advanced type and layers.
3. `Book Check`: visual-quality scoring plus automatic repair suggestions.

Extend `MemoryBookElement` into explicit renderable layer types and keep every property non-destructive:

```text
image · text · shape · drawing · decoration
  ↓
transform + appearance + content + constraints
  ↓
one shared render scene
  ↓
Editor · Reader · PDF · Video
```

Do not add a feature if PDF and Reader cannot render the exact same persisted property.

### Alternative path: IMG.LY CE.SDK replacement

Choose this only if the desired product is genuinely a broad Canva-like editor and commercial licensing is acceptable. A trial must prove:

- multi-page A4/Letter scenes and page reordering;
- user-selected PhotoKit assets remain local and can be reopened;
- locked Tailor templates with editable photo/text placeholders;
- non-destructive scene persistence and schema migration;
- exact print PDF output, fonts, color and image resolution;
- full offline behavior and no undisclosed content transfer;
- acceptable app size, memory, cold start, accessibility and license-failure UX;
- import/migration strategy for existing `MemoryBookDocument` archives.

## Execution plan

### Phase 1 — editor foundation

1. Zoom/pan canvas plus visible transform handles.
2. Snap guides, align/distribute and safe-margin overlays.
3. Multi-select, group/lock, duplicate and page-to-page copy.
4. Extend element appearance with opacity, border, radius and shadow.
5. Add text alignment, tracking, line height and direct frame resizing.

### Phase 2 — photo quality

1. **Implemented:** persisted Core Image adjustment model.
2. **Implemented:** brightness/contrast/highlights/shadows/warmth/saturation/vignette/sharpness.
3. **Implemented:** curated Tailor presets and conservative Auto Enhance.
4. **Implemented:** flip/straighten with blank-edge-safe shared output geometry. Perspective correction remains a separate prototype decision after real-user testing.

### Phase 3 — guided beauty

1. Smart template variants using source aspect and focal-region metadata.
2. Composition-quality rules and one-tap repair suggestions.
3. Shapes/masks/backgrounds and restrained decorative library.
4. Real-photo Editor/Reader/PDF design sign-off matrix.

### Parallel framework spike

Build, but do not merge, two disposable prototypes:

- CE.SDK: one 4-page Tailor book, locked template, PhotoKit assets, save/reopen and PDF export.
- Mantis: round-trip the current crop state, including rotation, fit/fill and A4/Letter PDF equality.

Compare both against the native Phase 1 cost before choosing a dependency.

### Current dependency decision

- Keep the native Tailor canvas, document model, Core Image finishing and shared PDF renderer for production.
- Run Mantis as an isolated M7 crop adapter spike; accept it only if reopen, Cancel/Done, Undo, original-asset preservation and A4/Letter raster output are lossless.
- Keep CE.SDK outside production until pricing/offline/privacy requirements and a complete four-page archive migration are proven.
- Do not adopt TOCropViewController or a flattened single-image editor; neither closes a remaining core release gate better than Mantis.

## Prototype fidelity interpretation

The 2026-07-15 editor prototype remains the baseline for E01–E09 information architecture, the 390×844 portrait hierarchy, paper/workspace styling, safe areas, selection language, crop staging and Editor/Reader/PDF consistency. It is no longer a complete functional ceiling:

- the original E05 explicitly limited users to three text sizes and no free color/font choice, while the approved current objective requires meaningful custom UI design;
- the original E07 said Book Check should not repair automatically, while the approved current objective requires safe one-tap repair with Undo;
- M1–M6 add advanced controls inside the same visual system without changing the persisted output contract.

Therefore, release acceptance uses two separate checks:

1. **Prototype-conformant:** route hierarchy, visual tokens, paper/workspace geometry, modal staging, locked structural pages, crop semantics, reader cleanliness and export flow.
2. **Approved extension:** zoom/precision, layers/groups, appearance, advanced typography and guided repairs must remain visually restrained, accessible, non-destructive and identical in Editor/Reader/PDF.

Claiming literal 100% feature identity with the older prototype would be inaccurate because the newer product requirement intentionally supersedes those two restrictions. Pixel-level conformity for both baseline and approved extensions still requires the physical-device and real-photo M7 matrix.

## Release gate

The editor may be called release-ready only when:

- all P0 controls are usable on a physical iPhone without precision frustration;
- every property round-trips through persistence and Undo/Redo;
- Editor/Reader/PDF share identical geometry, adjustments and appearance;
- 100% and 300-DPI export inspection finds no blur, seams, blank crop edges or text clipping;
- the real-photo aesthetic set receives named product/design approval;
- destructive and low-quality combinations are prevented or clearly repaired by Book Check.

## Sources reviewed

- IMG.LY CreativeEditor SDK: https://img.ly/products/creative-sdk/
- Mantis: https://github.com/guoyingtao/Mantis
- ZLImageEditor: https://github.com/longitachi/ZLImageEditor
- TOCropViewController: https://github.com/TimOliver/TOCropViewController
- Banuba Photo Editor SDK: https://www.banuba.com/photo-editor-sdk
- Apple Core Image: https://developer.apple.com/documentation/coreimage
- Apple PencilKit: https://developer.apple.com/documentation/pencilkit

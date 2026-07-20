# Tailor editor prototype conformance audit

**Audit date:** 2026-07-20  
**Baseline:** `design/editor_v1` E01–E09, 390×844 portrait  
**Product extension:** M1–M6 custom-design objective approved after the v1 prototype  
**Current verdict:** functionally close to the revised editor objective, but not yet proven pixel-perfect or release-ready.

## Acceptance rule

The older prototype remains authoritative for information architecture, Tailor visual language, paper/workspace geometry, safe areas, selection feedback, staged editing and clean Reader/PDF output. It is not the functional ceiling: its E05 prohibition on free font/color and E07 prohibition on automatic repair were superseded by the current custom-design and guided-beauty objective.

An item is accepted only when both are true:

1. the original baseline behavior is present or an intentional superseding decision is recorded;
2. the current behavior has runtime evidence on the target device and, where it affects output, matching Reader/PDF evidence.

## E01–E09 matrix

| Area | Current implementation | Conformance | Remaining proof or correction |
| --- | --- | --- | --- |
| E01 album entry | Timeline exposes `Edit album` and restores the persisted `MemoryBookDocument`. | **Partial** | The prototype's distinct entry card with style, page count, last edit and `Draft saved` is not a separate production screen. Confirm whether Timeline intentionally replaces E01; otherwise implement the missing metadata card. |
| E02 page editor | Dedicated deep-green workspace, paper-proportional canvas, page counter, Undo/Redo/More, horizontal page rail and Pages/Layout/Photo/Text/Style tools. M1–M6 add zoom, guides, handles, groups and layers. | **Implemented; visual gate pending** | Capture 390×844 physical-iPhone selected-photo and selected-text states and compare spacing, material, safe areas, handle size and keyboard behavior against the artboard. |
| E03 page manager | Structural locks, thumbnails, add/duplicate/delete/move and page selection are implemented. | **Implemented; device gate pending** | Physical long-press reorder, illegal-drop explanation and VoiceOver order still need evidence. |
| E04 crop | Full-screen fixed-aperture crop, pan/zoom, reset, Cancel/Done, dirty-exit decisions and blank-edge-safe rotation share one persisted geometry contract. | **Implemented; real-photo gate pending** | Validate portrait/landscape/edge-subject originals on device. Mantis remains an isolated perspective-correction candidate, not a production dependency. |
| E05 text | Semantic fields, keyboard-aware editing, Fit text, true overflow blocking and safe anchors are present. Advanced font, color, tracking, leading and hierarchy presets intentionally supersede the old three-size restriction. | **Approved extension implemented** | Real Chinese/Arabic/emoji review at phone and rasterized 300-DPI A4/Letter output. |
| E06 style/layout | Five styles, supported photo layouts, page override, chapter scope, whole-book scope, custom backgrounds and preservation of locked/user geometry are present. | **Implemented; aesthetic gate pending** | Real-photo five-style matrix and named product/design sign-off. Focal/aspect-aware variants remain open. |
| E07 Auto Arrange/Book Check | Page/chapter/book Auto Arrange respects locks. Book Check covers blocking data plus contrast, alignment, spacing, rotation, caption and whitespace issues; safe repairs are exact and Undoable. | **Approved extension implemented** | Original “do not repair” behavior is intentionally superseded. Validate that suggestions remain quiet and beneficial across the real-photo corpus. |
| E08 Reader/export preparation | Immersive shared renderer, swipe navigation, contents, edit return, sample watermark and purchase/export CTA are implemented. | **Functional; visual/product gaps remain** | Header/bottom hierarchy differs from the static E08 artboard, `$19.99` is hard-coded instead of StoreKit localized price, and real-photo repeated-watermark appearance needs device review. |
| E09 export/archive | Frozen shared render snapshot, per-page progress, cancel/failure recovery, cover, paper/page metadata, share and archive routing are present. | **Functional; release gate pending** | Signed archive/TestFlight export, exact prototype copy review (`Open archive` vs `Open in archive`), real 300-DPI PDF inspection and file lifecycle checks remain. |

## Visual-language findings

- The current editor retains the prototype's deep green workspace, warm paper, ink/clay/sage palette, centered paper proportion, top editing controls, horizontal page rail and five primary tools.
- Advanced controls are presented as Tailor sheets and restrained toolbars rather than a generic desktop inspector; this is aligned with the revised “guided freedom” direction.
- Current screenshots still contain unavailable-photo placeholders. They prove geometry and interaction states but cannot prove crop quality, tonal finishing or emotional presentation.
- Literal “100% identical to the old prototype” is not a valid completion claim because two original restrictions were intentionally superseded. The correct target is 100% baseline conformance plus verified approved extensions.

## Release decision

Do not approve the editor for release until all of these are attached to this audit:

1. physical iPhone E02/E03/E04 screenshots or recording with real Photos assets;
2. five styles × A4/Letter × representative page layouts at 300 DPI;
3. Latin/Chinese/Arabic/emoji typography comparison;
4. named product/design approval for default and repaired compositions;
5. focal-aware layout decision and completed Mantis round-trip result;
6. signed archive/TestFlight smoke result.


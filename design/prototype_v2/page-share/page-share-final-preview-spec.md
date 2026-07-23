# Final Preview · Share current page

Status: **approved for implementation**  
Date: 2026-07-23  
Visual baseline: `page-share-final-preview-approved.svg` / `.png`

## Product boundary

- The action shares exactly the currently visible logical page as one PNG.
- It is available only when the reader is in an unlocked Final Preview (`purchased`, restored purchase, or approved debug bypass). It is not shown in the watermarked/unpurchased Book Preview.
- The PNG uses the current document revision, paper size, resolved page, photo availability and z-order. It is unwatermarked because the entry point is unlocked.
- This does not replace `Generate full PDF`, `Save and share PDF`, or `Share latest PDF`.

## Placement and style

Replace the crowded text-only action row with four equal-width items: `Style`, `Customize`, `Paper`, `Share page`. Each item uses a system symbol above an 11 pt semibold label. Recommended symbols: `paintpalette`, `pencil`, `doc`, `square.and.arrow.up`.

- Container: existing bottom material; 84 pt action region plus existing navigation status row.
- Each action: minimum 44 × 44 pt hit target; clay `#B85639` when enabled.
- Separators: 1 pt `TailorColor.line`, 45 pt high.
- `Share page` is the fourth/rightmost item. Do not put it beside the title or replace the PDF primary CTA.
- Primary CTA remains `Generate full PDF`.

## States and copy

| State | Presentation | Behavior |
|---|---|---|
| Unpurchased | Do not render `Share page` | Watermarked preview behavior remains unchanged. |
| Purchased / ready | Symbol `square.and.arrow.up`; label `Share page` | Tap starts rendering the selected logical page. |
| Preparing | Progress indicator; label `Preparing…`; secondary ink | Disable only this action and reject repeated taps. Keep reading position and other actions stable. |
| Failure | Alert title `Couldn’t prepare this page.`; message `The page is still safe in your book. Please try sharing again.`; button `OK` | Dismiss to the same logical page. Do not open a sheet or retain a stale payload. |
| Ready | Present system `UIActivityViewController` with the PNG URL | Cancel/completion returns to the same logical page and revision. |

Accessibility label: `Share current page`. During preparation expose `Preparing current page for sharing` and the disabled trait.

Suggested file name: `<sanitized-pet-name>-page-<2-digit-page-number>.png`, for example `Milo-page-01.png`.

## Acceptance criteria

1. The action is absent from every unpurchased/watermarked preview and present in unlocked Final Preview.
2. All four toolbar labels remain on one line at 390 pt width, Dynamic Type default and one larger accessibility category; no clipping or horizontal overflow.
3. The 44 pt minimum hit target and VoiceOver order are `Style → Customize → Paper → Share page → navigation hint → page count`.
4. Rapid double tap creates one render task and one Share Sheet.
5. Preparing is visibly announced and only Share page is disabled.
6. Shared PNG corresponds to the selected logical page, current revision and current paper ratio; target width is at least 1400 px; no editor handles, app chrome, preview watermark, transparent edge, or unintended crop.
7. Missing/deleted selected page shows the failure state and never falls through to sharing a different stale page without a user-visible explanation.
8. Render failure removes temporary output. Share Sheet cancellation does not navigate, change page, or trigger PDF export.
9. Rotation/two-page spread still shares the selected logical page only, not a screenshot of the spread.
10. Add UI coverage for locked/ready/preparing/failure and an integration assertion for PNG dimensions, page identity and absence of watermark.

## Current implementation review

The temporary implementation already has the correct entitlement guard, single-page PNG intent, preparing disable, system Share Sheet, and a failure alert. It needs design alignment before acceptance:

- Change the crowded inline text row to the four equal icon-plus-label actions shown in the baseline.
- Replace alert copy `We couldn’t prepare this page for sharing.` with the approved shorter title and reassuring message.
- Use a deterministic user-facing filename rather than an opaque temporary name.
- Verify the selected-page fallback: if an explicit selected logical page disappeared, show the failure instead of silently sharing the first visible page.
- Add cleanup/cancellation and accessibility-state evidence.

No product code was changed by this design deliverable.

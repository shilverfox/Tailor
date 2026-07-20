# M7 photorealistic QA source manifest

**Purpose:** preflight focal crop, finishing and composition with photo-like inputs before physical-device/user-photo approval.  
**Source:** generated with the built-in `imagegen` tool using the `photorealistic-natural` use case.  
**Limitation:** these are AI-generated QA inputs, not user photographs. They cannot approve emotional authenticity, PhotoKit behavior on a physical device or final aesthetic release quality.

Local files are retained under `artifacts/visual-qa/source-photos/m7-photorealistic/` and are excluded from the production bundle.

| File | Stress case | Dimensions | SHA-256 |
| --- | --- | --- | --- |
| `01-dog-landscape-right-backlight.png` | right-edge subject, 3:2 landscape, backlight, complex park | 1536×1024 | `a4fd6d253ac8ae9c22106f0e2d86cef6b398f93cc86f214b05a173c8c80dfd70` |
| `02-cat-portrait-high-low-contrast.png` | high subject, 2:3 portrait, low contrast, cluttered interior | 1024×1536 | `ba3560b45c9be0c78a6d582f23a7a584e5673e5c0a4926991a5a8b36e546479d` |
| `03-dog-landscape-low-light.png` | black fur, dim mixed light, shadow separation | 1536×1024 | `f2efef866e5643f92e1cd294b2e52324e6e4f84422bf9de8123becf32f35bcec` |
| `04-dog-portrait-white-highlights.png` | white fur on pale textiles, high-key highlight separation | 1024×1536 | `66037d0af4d2a4448d2382f28c5e590af39089310ad30ef036176616243ce357` |

## Prompt set

1. Candid golden retriever at the far right of an ordinary park, substantial negative space, warm sunset backlight, realistic smartphone texture, no text/logo/watermark.
2. Grey tabby cat on the upper shelf of a lived-in bookcase, portrait frame with room below, soft side light and moderate low contrast, no people/logo/watermark.
3. Black dog walking through a dim apartment hallway, mixed practical light, difficult dark-on-dark separation and mild smartphone noise, no people/text/logo/watermark.
4. Small white long-haired dog on pale linen by a bright window, high-key highlight/fur separation, close portrait with natural texture, no text/logo/watermark.

The four unique files were imported into the real Photos library of the `Tailor-QA-iPhone13` simulator on 2026-07-20. A Debug-only route requests Photos permission, fetches and byte-deduplicates PhotoKit assets, and constructs the book from their real local identifiers and pixel dimensions; the assets are not copied into the app bundle.

## Latest preflight evidence

- `EditorM7-real-photo-pdf-ui-r24.xcresult`: the real-PhotoKit Editor → Reader → PDF flow passes 1/1 on the 390×844 iPhone 13 simulator.
- `EditorM7-real-photo-pdf-ui-r24-attachments/`: editor, reader, focal diagnostic and PDF-completion evidence.
- `EditorM7-real-photo-pdf-r24/00000000-0000-0000-0000-000000009001-life-archive-20260720-141214-3BC040D8.pdf`: six-page US Letter output, approximately 14 MB.
- Poppler inspection reports every photo on the four-photo grid at 300×300 PPI. The 1536×1024 cover source provides approximately 229 PPI at its actual frame size; Book Check now reports this as a non-blocking quality suggestion instead of silently implying 300 PPI.
- Rendered 150-DPI page PNGs show no transparent/black pages, seams, text clipping or blank crop edges. The four-photo automatic page was changed from an unbalanced three-column 3+1 arrangement to a balanced 2×2 grid.
- After that inspection exposed the missing cat face, the current code now blocks export when an untouched automatic Fill crop has no focal metadata and retains less than 65% of the source. `EditorM7-real-photo-crop-gate-ui-r25.xcresult` proves both affected portrait placements are surfaced as `Needs attention`; opening Crop and confirming marks the framing as user-reviewed.

## Unresolved physical-device gate

The iOS simulator returns `Could not create inference context` for the Vision animal/saliency requests, while the same cat source produces an animal bounding box and saliency observations through macOS Vision. Consequently the portrait cat is visibly cropped too high when its focal metadata is absent. This is useful failure evidence, not an approval; current code no longer permits that unreviewed crop to reach export. A physical iPhone must still prove that the persisted focal region keeps the subject visible in Editor, Reader and both A4/Letter PDF before M7 can pass.

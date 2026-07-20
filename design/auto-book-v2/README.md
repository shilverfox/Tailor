# Tailor Smart Memory Book v2 — Prototype

This prototype turns the “beautiful memorial album” direction into an implementation-ready product flow. It focuses on two quality gaps: automatic book generation and true template differentiation.

## Screens

1. Smart first draft — reports event grouping, duplicates, photo roles, and book progress.
2. Story plan — lets the user review event chapters and the editorial role of each cluster.
3. Book style — five art directions that alter layout rhythm, typography, image treatment, and pacing.
4. Page preview — page-level SwiftUI-style preview, not a generic PDF thumbnail.
5. Page recipe — recommends layouts according to aspect ratio, photo count, and crop preservation.
6. Apply style — supports “visual only” or safe rearrangement while protecting locked edits.
7. Book Check — catches crop, duplicate, resolution, typography, and contrast problems before export.
8. Final preview — demonstrates the shared preview/export result and print format selection.

## Interaction contract

- Edited pages are locked by default when switching templates.
- No invented memories or emotional captions. Dates come from Photos; prose comes from the user.
- “Book Check” blocks export only for cropping or print-quality risks that materially affect the result.
- Preview and PDF must share one `MemoryBookPage` document model.

Open `prototype.html` directly in a browser. Add `?screen=01` through `?screen=08` to render one screen.

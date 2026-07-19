# Story layout and video delivery

## Delivered

- `MemoryBookBuilder` now emits dynamic page layouts (`single`, `diptych`, `mosaic`, `note`) based on the confirmed photo count.
- Chapter pages carry neutral date-span labels and a milestone page is added when an arrival-year photo is available; no unverified “first time” or emotional event is inferred.
- Added `cinema` and `filmAlbum` styles. Cinema desaturates photo presentation; Film Album adds a clay film-frame treatment.
- Added `VideoExporting` and `LocalVideoExporter`. It creates a local 30-second H.264 slideshow from eligible chronological assets and exposes a system Share Sheet action on the export page.
- PDF and SwiftUI preview continue to share `MemoryBookDocument.pages`.

## Intentionally not automatic

Core ML mood detection and generated sentimental copy are not enabled. Tailor does not invent pet behavior, feelings, birthdays, illness, or death events. User-authored chapter notes remain the source for personal wording.

## Verification

- Debug build passed after adding styles, dynamic page layouts and video exporter.
- Existing MemoryBookBuilder and PDF tests remain green.
- Manual preview evidence: `/tmp/tailor-preview-memorybook-v2.png`.

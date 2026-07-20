# Mantis crop adapter spike

**Status:** v1 no-go decision; upstream and isolated adapter feasibility retained for a later release  
**Candidate:** Mantis 3.1.x, isolated from the Tailor production target

## Question

Can Mantis improve Tailor's core crop experience—especially perspective correction—without flattening user photos or breaking the shared Editor/Reader/PDF contract?

## Confirmed from the 3.1 public API

- SwiftUI `ImageCropper` can hide its built-in toolbar and be driven by a `CropSession`, so Tailor can retain its own visual hierarchy.
- Fixed ratios, straighten, flip, perspective correction, Undo/Redo and reset are available.
- `CropInfo` is Codable and a Mantis-produced value can be decoded and replayed against the original image offline.
- `Transformation` can reopen the editor at a prior state.
- Perspective and large-image replay includes opaque view-reconstruction state. Rebuilding `CropInfo` only from public semantic fields is not sufficient for those paths.
- Mantis includes a privacy manifest and supports iOS 15+, compatible with Tailor's iOS 17 floor.

Source: [Mantis official repository](https://github.com/guoyingtao/Mantis).

## Consequence for Tailor

Tailor's current crop schema stores normalized scale/offset plus rotation/flip and lets Editor, Reader and PDF render the same original PhotoKit asset. A correct Mantis integration cannot replace that contract with the cropped `UIImage` returned by the UI.

The only viable adapter shape is:

```text
original PhotoKit asset ID
  + existing Tailor crop geometry (legacy and simple edits)
  + versioned Mantis CropInfo payload (only after a Mantis edit)
  + explicit Mantis package/schema version
  -> same replay path for Editor, Reader and PDF
```

The PDF exporter would need to replay the encoded crop against the original high-resolution asset. Preview cannot use a flattened low-resolution derivative as its source of truth.

## Acceptance tests for an executable spike

1. Open a Tailor crop in Mantis without a visible first-frame jump.
2. Cancel leaves the byte-for-byte `MemoryBookDocument` unchanged.
3. Done is one Tailor Undo transaction; Undo/Redo restores the complete payload.
4. Kill/relaunch/reopen reconstructs the identical crop from the original asset.
5. Straighten, flip and perspective remain blank-edge safe.
6. Editor, Reader, Letter PDF and A4 PDF match within the existing normalized geometry tolerance.
7. A 12–48 MP image stays responsive and the export path preserves print resolution.
8. Missing/revoked PhotoKit assets remain replaceable and never leak a cached flattened original.
9. Package privacy manifest, license and binary-size delta are recorded.

## Current result

On 2026-07-20 the official `v3.1.0` tag at commit `0960be1feed2e62f62a5fddbb8d72b26008db881` was checked out outside the Tailor workspace and built successfully for the installed iOS 26.5 simulator SDK. Its complete `MantisTests` suite passed 164/164 in `artifacts/visual-qa/current-audit/Mantis-v3.1.0-all-unit-r1.xcresult`, including seven `CropInfoCodableTests` covering standard, fixed-ratio/flip, rotation, perspective, nil reconstruction, legacy output equality and CI/large-image output equality.

`Spikes/MantisAdapter` is now a separate Swift Package that pins that exact public release without becoming a dependency of `Tailor.xcodeproj`. `TailorMantisAdapter-unit-r1.xcresult` passes 2/2 tests: its schema/package/provider-versioned envelope survives outer JSON persistence and replays byte-identical PNG pixels from the caller-provided original, while unknown versions/providers fail explicitly. The envelope contains only encoded crop geometry and never a flattened bitmap.

The checked-out package declares iOS 15/macCatalyst 15, an MIT license and a privacy manifest with tracking disabled, no tracking domains, no collected data types and no accessed API types. The isolated Debug simulator framework occupied 4.7 MB (3.3 MB binary); this is diagnostic only and is not a production app-size delta.

The dependency is **not approved for production yet**. It is a credible perspective/crop UI enhancement, but it adds a second versioned transformation schema and requires all render surfaces to replay Mantis state. The current native crop is already non-destructive and proven across Editor/Reader/PDF; adopting Mantis before the Tailor-specific adapter, real-photo device review and A4/Letter equality test would increase release risk.

## v1 decision

**No-go for the first production release.** Tailor's required v1 crop behavior—non-destructive pan/zoom, rotation/straighten, flip, blank-edge safety, Cancel/Done, Undo/Redo and shared Editor/Reader/PDF geometry—is already implemented natively. Mantis's material incremental benefit is perspective correction, which is not a current prototype or release requirement. Shipping it now would introduce an opaque second transformation schema before real-photo evidence shows that perspective is a frequent user need.

Keep the isolated package and evidence for a post-v1 experiment. Reopen the decision only if real-user/real-photo review establishes perspective correction as a high-value gap; if reopened, every remaining acceptance test above becomes mandatory.

No package or source files were added to `Tailor.xcodeproj`. The next spike must capture a genuine perspective payload from Mantis UI, exercise Cancel/Done and Tailor Undo, reopen the PhotoKit original, and compare Editor/Reader/A4/Letter pixels before any production dependency is proposed.

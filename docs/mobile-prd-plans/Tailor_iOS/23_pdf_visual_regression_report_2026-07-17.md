# PDF visual regression report — 2026-07-17

## Scope

Deterministic exporter/render-plan verification. This is renderer evidence,
not a visual sign-off against an approved design baseline.

## Command

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project Tailor.xcodeproj \
  -scheme Tailor \
  -destination 'platform=iOS Simulator,id=486739AC-435E-4A4B-93F5-0A348D498F43' \
  -only-testing:TailorTests/TailorFeatureTests/testDeterministicPDFEvidenceCoversEveryTemplatePaperAndPageKind \
  -resultBundlePath /tmp/tailor-pdf-evidence-r3.xcresult
```

## Result

**Passed.** `TailorFeatureTests.testDeterministicPDFEvidenceCoversEveryTemplatePaperAndPageKind`
completed on iPhone 17 / iOS 26.5: one test executed, zero failures.

| ID | Status | Finding | Evidence | Outcome |
|---|---|---|---|---|
| PDF-R-001 | Pass | Every current code template × A4/Letter × each of seven page kinds exported from a deterministic, PhotoKit-free bitmap provider. | Ten folders, ten PDFs, ten manifests, ten metrics files, and 70 raster PNGs in the simulator evidence root below. | 70 rendered pages. |
| PDF-R-002 | Pass | Each generated PDF has seven pages; each page's media box matches its requested paper size; every raster is non-empty. | The test asserts counts, 612×792 pt Letter, 595×842 pt A4, PNG byte count, and sampled color count. Example metrics: `warmPaper/letter/metrics.json`. | Letter and A4 render paths both exercised. |
| PDF-R-003 | Gate | No approved design-reference baseline is available for pixel comparison. | `design/visual-qa/reference_manifest.md` marks available images as candidates rather than approved baselines. | This evidence proves deterministic export/render integrity only; it is not a pixel-perfect design sign-off. |

## Evidence location

The successful simulator run stored its reproducible artefacts at:

```text
/Users/lijian15/Library/Developer/CoreSimulator/Devices/486739AC-435E-4A4B-93F5-0A348D498F43/data/Containers/Data/Application/AF10FB22-DC7A-4010-BC4A-FAB40DA73737/tmp/tailor-pdf-visual-evidence-v1
```

Each `<style>/<paper>` directory contains one PDF, `manifest.json`,
`metrics.json`, `result.md`, and seven `pdf-raster-*.png` files. The test
currently covers five code-level templates (`warmPaper`, `quietNight`,
`fieldNotes`, `cinema`, `filmAlbum`) and both paper sizes, for ten style/paper
combinations.

## Follow-up visual gate

1. Retain the generated PDF, render manifest, metrics, and page PNGs as the evidence set.
2. Compare against approved design references only after those references have been supplied and versioned.

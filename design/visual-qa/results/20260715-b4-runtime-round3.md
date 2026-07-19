# B4 runtime verification · round 3

Date: 2026-07-15

Build: `xcodebuild -quiet -project Tailor.xcodeproj -scheme Tailor -destination platform=iOS Simulator,id=41F93DB0-C75A-4044-BD9D-C7D90D00FE9B build CODE_SIGNING_ALLOWED=NO`

## Evidence

| Route | Runtime capture | Result |
|---|---|---|
| Export | `/tmp/tailor-export-current.png` | Complete-state CTA is `Save and share PDF`; private-local copy message and cover are visible. |
| Archive | `/tmp/tailor-archive-current.png` | Archive card, 48pt settings rows, delete row, privacy card, and create-another CTA are visible. |

The export demo uses a deterministic local URL only for UI preview, so the completion state does not depend on a PDF write during screenshot capture. Production export still uses `LocalPDFExporter` and Share Sheet.

## Gate status

This is runtime evidence for B4 implementation alignment, not formal pixel PASS. Candidate references remain `candidate` in `design/visual-qa/reference_manifest.md` until device/content-mask and design-source approval are frozen.

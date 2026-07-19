# 01–02 Candidate Alignment — Engineering Round 2

Date: 2026-07-15  
Target: `Tailor` simulator, `41F93DB0-C75A-4044-BD9D-C7D90D00FE9B`, 390 × 844 capture normalization  
Revision: current working tree (uncommitted)

## Commands completed

```sh
/usr/bin/xcodebuild -quiet -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=41F93DB0-C75A-4044-BD9D-C7D90D00FE9B' \
  build CODE_SIGNING_ALLOWED=NO

/usr/bin/xcodebuild -quiet -project Tailor.xcodeproj -scheme Tailor \
  -destination 'platform=iOS Simulator,id=41F93DB0-C75A-4044-BD9D-C7D90D00FE9B' \
  -only-testing:TailorUITests/TailorOnboardingUITests/testDemoRoutes01Through04RenderAndCaptureEvidence \
  test CODE_SIGNING_ALLOWED=NO
```

Both commands exited successfully; `git diff --check` also completed successfully.

## Engineering observations

| State | Candidate-alignment change | Latest visual result | Formal result |
| --- | --- | --- | --- |
| 01 welcome-default | Corrected wordmark from right to left, replaced circular menu icon with ellipsis, normalized title/content rhythm, resized hero, and aligned the CTA/link footer. | Candidate comparison is visually aligned: header/title/text/image/link align; CTA top differs by about 3 px. | `BLOCKED — DESIGN_BASELINE_CANDIDATE_ONLY` |
| 02 privacy-not-determined | Replaced icon cards with full-width editorial cards; corrected privacy copy; provided deterministic not-determined UI fixture; aligned footer action to the candidate state. | Content geometry aligns directionally after excluding system status-bar chrome. Card padding/typography remains subject to source/reference freeze. | `BLOCKED — DESIGN_BASELINE_CANDIDATE_ONLY` |

## Important limitations

This is not a pixel PASS. The promotion decision in `docs/mobile-prd-plans/Tailor_iOS/08_reference_01_04_promotion_adjudication_2026-07-15.md` remains controlling: current source references have no approved status-bar/safe-area mask or device/runtime declaration, and 03/04 required states are incomplete. No overlay/diff percentage is therefore valid evidence yet.

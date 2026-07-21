# Tailor release readiness and prototype audit

Date: 2026-07-19 (updated 2026-07-20)  
Target reviewed: current local `Tailor` iOS implementation  
Device used for UI evidence: iPhone 13 simulator, iOS 26.5, 390×844 points

## Verdict

**Release readiness: BLOCKED — not an App Store release candidate.**

The app builds and the core archive journey is implemented, but required release configuration, privacy disclosure, StoreKit evidence, recognition calibration, accessibility evidence, and several product-completeness gates are still open.

**Prototype fidelity: NOT 100%, and formal pixel approval is currently impossible.**

`design/visual-qa/reference_manifest.md` marks every current reference as `candidate` or `blocked`; there is no approved baseline. Runtime screens also contain visible structural and copy differences from those candidates.

## Verified in this audit

| Area | Result | Evidence |
| --- | --- | --- |
| Unit/model tests | PASS | 89 tests, 0 failures; `artifacts/visual-qa/current-audit/EditorM4-tools-full-unit.xcresult` |
| Latest editor unit/model tests | PASS | 108 tests, 0 failures, 0 skipped; `artifacts/visual-qa/current-audit/EditorM7-full-unit-r7.xcresult` |
| Full UI regression | PASS | 44 tests, 0 failures; `artifacts/visual-qa/current-audit/TailorUITests-after-fixes.xcresult` |
| Decoration editor UI | PASS | Add/design/resize affordance/layer visibility/Undo; `artifacts/visual-qa/current-audit/EditorM3-decoration-ui-polished.xcresult` |
| Page background UI | PASS | Curated background preview, atomic Apply/Undo and shared paper-color readback; `artifacts/visual-qa/current-audit/EditorM3-background-ui.xcresult` |
| Photo appearance UI | PASS | Mask/border/shadow/preset persisted as one undoable change; `artifacts/visual-qa/current-audit/EditorM4-appearance-ui-r9.xcresult` |
| Photo geometry/finishing UI | PASS | Flip selected state, straighten, conservative Auto Enhance, atomic Apply/Undo; `artifacts/visual-qa/current-audit/EditorM4-geometry-auto-ui-r10.xcresult` |
| Generic iOS Release build | PASS | Unsigned Release build completed successfully |
| Latest editor Release build | PASS | Unsigned iphoneos Release completed in `artifacts/build/EditorM7-Fit-Crop-Release`; Debug QA route/diagnostic markers are absent |
| Real-PhotoKit PDF preflight | PARTIAL PASS | Four unique PhotoKit inputs traversed Editor → Reader → six-page Letter PDF. Severe no-focal crops block first; Full Photo preserves the cat, the white-dog crop is reviewed, and the inspected r40 PDF uses correct physical portrait aspect with no lost subjects or blank edges. Simulator Vision/on-device focal inference and A4 device evidence remain unvalidated. |
| Debug simulator build | PASS | Built for the dedicated iPhone 13 simulator |
| Previously failing UI paths | PASS after fixes | 5/5 targeted reruns passed: scan resilience, insufficient preview, text focus/dirty exit, direct text drag/undo, Unicode paste boundaries |
| Runtime visual capture | CAPTURED | 13 route screenshots in `artifacts/visual-qa/current-audit/normalized/` |
| Network privacy boundary | PASS by source inspection | No upload client or `URLSession` path found; Photos/Vision work is local |
| Local deletion boundary | PASS by source inspection/tests | Tailor data/PDFs are removed; original Photos are not deleted |
| Restore purchase affordance | IMPLEMENTED | StoreKit 2 restore path and UI are present |

## Defects fixed

1. Restored legacy memory-book image behavior to aspect-fill and added backward-compatible decoding for keyed `CGRect`/`CGSize` archives.
2. Recovered replacement-photo crop normalization and rotated crop geometry tests.
3. Restored low-battery recovery actions (`Pause now`, `Continue later`).
4. Restored the unpurchased preview watermark explanation.
5. Made a direct text drag select and move the element in one gesture, with atomic undo.
6. Added stable focus acquisition when choosing or creating a text field, fixing typing and native Unicode paste paths.

## Release gate findings

### P0 — must be resolved before submission

| Gate | Current finding | Required exit evidence |
| --- | --- | --- |
| Privacy manifest | Release app does not contain `PrivacyInfo.xcprivacy`. The app reads file timestamp metadata (`contentModificationDateKey`), a required-reason API category. | Valid manifest embedded in the archived app and App Store validation pass. Apple has required approved reasons for listed APIs since 2024-05-01. |
| Privacy/support links | No working in-app privacy policy or support/about destination; `About Tailor` currently has an empty action. | Public privacy-policy and support URLs in App Store Connect and accessible inside the app. |
| Settings completeness | `Manage photo access` and `About Tailor` buttons have empty actions. | Both destinations work on device and have UI tests. |
| StoreKit pricing | Purchase and preview surfaces hard-code `$19.99` instead of StoreKit's localized `Product.displayPrice`. | Price loaded from StoreKit; sandbox purchase, cancel, pending, restore, revoked/refunded, and regional storefront evidence. |
| Release-only hardening | FIXED in this audit: Release now always selects production composition and `configureUITestDemoIfRequested()` compiles to `false`; the rebuilt Release executable contains no `-uiTesting`/`-uiDemoRoute` markers. A signed-archive smoke test is still required. | Signed archived-binary inspection and smoke test confirm no fixture route can be entered. |
| Product identity/signing | Bundle ID is `com.tailor.prototype`, version is `0.1 (1)`, and no signed archive/App Store validation was performed. | Final bundle ID/version/team/provisioning, signed archive, Organizer validation, TestFlight install. |
| Core recognition quality | Scanner thresholds are documented in source as conservative, uncalibrated starting points. | Labelled real-device acceptance set, precision/recall targets, false-positive review, thermal/memory/time measurements across supported devices. |
| Core editor quality | Precision canvas, arrangement/layers, appearance, non-destructive finishing, typography, guided checks and focal-aware initial crop are implemented. The latest suite passes 108/108; a real-PhotoKit simulator repair/export flow and inspected Letter PDF pass. Book Check evaluates print PPI, blocks severe unreviewed crops, and offers Crop/Full Photo/frame recovery. Mantis remains a documented v1 no-go. Physical-device focal/aesthetic validation, multilingual print evidence and named approval remain open. | Complete the remaining M7 gates in `docs/editor-capability-audit-2026-07-19.md` and `docs/editor-prototype-conformance-audit-2026-07-20.md`. |

### P1 — product-completeness blockers

| Area | Current gap |
| --- | --- |
| Pet profile | `Came home · optional` displays a hard-coded `2017`; it is not editable or persisted. |
| Multiple archives | Repository can list profiles, but root restores only `.first`; the archive screen renders one archive and `Create another archive` replaces the active flow rather than providing complete list/selection behavior. |
| Timeline editing | Current implementation primarily hides/shows and opens a chapter. Candidate/spec actions such as edit periods/date range, rename, cover change, merge, reorder, and hidden-period management are incomplete. |
| Accessibility | No complete VoiceOver focus-order, Dynamic Type AX sizes, increased-contrast, Reduce Motion, or Switch Control evidence set. |
| App lifecycle/reliability | Needs interruption, low-storage, Photos permission revocation, iCloud-only asset, export cancellation/retry, migration, and upgrade tests on physical devices. |
| Store delivery | App Store metadata, privacy nutrition labels, age rating, export compliance, IAP review association, TestFlight review, and production crash/analytics policy are not evidenced. |

### P2 — quality and maintainability

- Replace silent `try?` persistence paths with user-visible and observable failure handling where data durability matters.
- Add structured diagnostics for scan/export failures without recording photo content or personal metadata.
- Define backup/export retention policy and migration/versioning policy for `ArchiveDocument` and `MemoryBookDocument`.
- Verify landscape behavior, because the release Info.plist advertises portrait and landscape while most captured baselines are portrait-only.

## Prototype and design audit

### Formal status

The visual QA contract says a screen cannot pass unless its reference is `approved`. The current manifest contains no approved 390×844 reference. Therefore the correct status is:

`BLOCKED — DESIGN_BASELINE_MISSING`

This means the app cannot truthfully be declared “100% according to the prototype,” even if an individual screen looks polished.

### Visible runtime-to-candidate differences

| Route | Difference observed |
| --- | --- |
| Profile | Candidate expects editable `cameHome`; runtime shows hard-coded `2017`. |
| Review | Runtime grouping, year filter, information card, and result-copy structure differ from candidates. |
| Timeline | Runtime lacks the candidate `Edit periods` surface and uses `Edit album` where a candidate uses `Preview album`; period-management states are incomplete. |
| Chapter | Runtime adds an `ADD SELECTED PHOTOS` row and uses differing date/copy/layout details. |
| Preview | Runtime is an immersive reader with `Edit`, `Contents`, and bottom customization controls; candidates use a materially different preview hierarchy and state presentation. |
| Archives/settings | Candidate states cover empty/access-revoked/delete-failed behavior; runtime settings include two non-functional rows and only one rendered archive. |

### What is needed for a real 100% sign-off

1. Product/design approves one authoritative behavior spec and 390×844 reference for every required state.
2. Conflicting/deprecated prototypes are removed from acceptance decisions.
3. Runtime uses the exact approved fixture data, device, OS, appearance, locale, content-size category, and permission state.
4. Each state receives runtime screenshot, overlay/diff, tolerance result, accessibility result, and named human approval.
5. Any design or PRD change invalidates affected approvals and triggers a new comparison.

## Recommended execution order

1. Close complete automated regression and physical-device smoke gates.
2. Complete currently visible product holes: profile year input and functional settings destinations.
3. Remove UI fixtures from Release, localize StoreKit pricing, and complete sandbox/App Store Connect purchase evidence.
4. Add the privacy manifest plus real privacy/support destinations after final URLs and bundle identity are supplied.
5. Calibrate recognition and performance on a labelled real-device dataset.
6. Complete multi-archive and timeline editing behavior against an approved functional contract.
7. Freeze approved visual references and perform the final pixel/accessibility matrix.

## Apple requirements consulted

- Required-reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Add a privacy manifest: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Restore purchases: https://developer.apple.com/documentation/storekit/restoring-purchased-products

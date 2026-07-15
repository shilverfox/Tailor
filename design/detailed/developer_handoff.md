# Tailor v1 · SwiftUI developer handoff

This handoff maps the detailed design to the iOS v1 architecture. It is a specification, not a request to modify the existing demo prototype. All photos remain local and use PhotoKit identifiers; all mutations preserve user work unless the user explicitly confirms deletion.

## 1. Feature and navigation map

| Route | SwiftUI feature/view | Required model/state |
| --- | --- | --- |
| `welcome` | `WelcomeFeature` / `WelcomeView` | `onboardingPresentedPrivacy` |
| `privacy` | `PhotoAccessFeature` / `PhotoAccessView` | `PhotoAccessScope`: notDetermined/full/limited/denied/restricted |
| `profile` | `ProfileFeature` / `ProfileFormView` | draft `PetProfile`, form validation |
| `references` | `ReferenceFeature` / `ReferencePickerView` | `[PHAsset.localIdentifier]`, 3...5 valid references |
| `scanning` | `ScanFeature` / `ScanProgressView` | `ScanState`, persisted checkpoint/candidates |
| `confirmation` | `ReviewFeature` / `PhotoReviewView` | `PhotoDecision` and filter/tab state |
| `timeline` | `TimelineFeature` / `TimelineView` | `[Chapter]`, hidden/order state |
| `chapterEditor` | `ChapterFeature` / `ChapterEditorView` | editable chapter draft / dirty state |
| `preview` | `PreviewFeature` / `AlbumPreviewView` | `AlbumStyle`, preview generation state, entitlement |
| `purchase` | `PurchaseFeature` / `PurchaseView` | StoreKit entitlement / transaction state |
| `export` | `ExportFeature` / `PDFExportView` | page size, render state, local URL |
| `archives` | `ArchiveFeature` / `ArchiveListView` | all profiles, delete request state |

Use `NavigationStack` with explicit routes or an equivalent coordinator; the 12-screen demo enum is insufficient for recovery/deep re-entry. Modal surfaces: photo viewer, year/filter picker, chapter actions, image delete/exit guard, page size, and destructive delete sheet.

## 2. State machine and persistence

```text
draft -> referencesReady -> scanning <-> paused -> ready -> exported
                       \-> scanFailed -> scanning | ready (if candidates exist)
preview -> purchasing -> preview | entitled -> exporting -> exported | exportFailed
any profile -> deleteRequested -> deleted
```

`PetProfile.lifecycle` should persist `draft/scanning/ready/exported/deleted`; transitory UI loading can remain in memory but scan checkpoint, profile, decisions, chapters, style and generated-PDF metadata must survive termination. A failed scan/purchase/export never clears confirmed decisions, chapters, references, style or page size. `deleted` removes local Tailor data and PDFs, never `PHAsset` originals and never the non-consumable StoreKit entitlement.

Recommended view state enums:

```swift
enum PhotoAccessScope { case notDetermined, full, limited, denied, restricted }
enum ScanState { case idle, running(ScanProgress), paused(ScanProgress), interrupted(ScanProgress), failed(ScanError, ScanProgress?), complete }
enum PurchaseState { case idle, purchasing, cancelled, failed(Error), restored, entitled }
enum ExportState { case idle, choosingPageSize, rendering(RenderProgress), failed(Error), complete(URL) }
```

## 3. Shared UI components

Build components from `component_inventory.md`, using semantic asset colors (`TailorColor`) and Dynamic Type text styles rather than hard-coded font points:

- `TailorScreen` (scroll content + safe-area bottom action slot), `TailorNavigationBar`, `PrimaryButton`, `SecondaryButton`, `DestructiveButton`.
- `LabeledTextField`, `YearPickerField`, `SpeciesPicker`, `InfoCard`, `ErrorCard`, `LimitedAccessBanner`.
- `AssetThumbnail`, `ReferencePhotoSlot`, `PhotoDecisionTile`, `PhotoGrid`, `PhotoViewer`.
- `ScanProgressRing`, `ScanStatusCard`, `ConfidenceTabs`, `YearFilterSheet`.
- `ChapterCard`, `ChapterEditorGrid`, `TemplateSwatch`, `PDFPagePreview`, `PurchaseBenefitsList`, `ArchiveCard`, `DeleteLocalDataSheet`.

Every component takes a text label/accessibility identifier; avoid unlabeled icon buttons. Use minimum 48-pt content shapes. Design constants belong in one token layer, not scattered literal colors/spacing.

## 4. Platform integration boundaries

| Integration | Design/behavior contract |
| --- | --- |
| PhotoKit / picker | Explain scope before request. Read only authorized assets and store identifiers/metadata; use native limited picker and Settings handoff. Never use a generated image as asset result. |
| On-device matcher | Feed only reference identifiers/thumbnails according to local ML boundary. Return high/needs-review candidates; needs-review starts unselected. Persist checkpoints. |
| SwiftData | Persist profile, decisions, chapter ordering/visibility, template, scan checkpoint and export metadata. Do not persist original photo copies. |
| StoreKit 2 | Product `tailor.life_archive.unlock`; show system purchase UI. Entitlement gates full PDF render and watermark-free pages. Restore is always visible. |
| Local PDF / ShareLink | Render A4 or US Letter locally. Persist sandbox URL/metadata when valid; use system share sheet. Sharing is user-directed, not an upload feature. |

## 5. Acceptance checklist

### Navigation and resilience

- [ ] Each of the 12 routes has an explicit back/exit path; dirty chapter and active scan exits show the specified confirmation.
- [ ] Relaunch during scanning restores a resume state; relaunch after an error preserves choices.
- [ ] Flying mode supports profile, scan, review, edit and PDF export; only purchase requires network/App Store.

### Privacy and decisions

- [ ] Welcome, Privacy, Scan and Export display compatible local-processing claims.
- [ ] Full, limited, denied and Settings-return permission states match the detailed copy and actions.
- [ ] Needs-review candidates are not automatically selected or included in PDF.
- [ ] Delete confirms impact, deletes Tailor data/PDFs, leaves Photo Library and StoreKit entitlement unaffected.

### Visual and accessibility

- [ ] Compare baseline 390-pt screens against `design/prototype.html` direction; detailed layout takes precedence where they differ.
- [ ] Test default, XL, Accessibility XXL, Bold Text, Increase Contrast, Reduce Motion, VoiceOver and 320-pt width. Essential content has no clipped/truncated text.
- [ ] All controls reach 48 pt minimum (or documented exception), all icons have labels, and confidence/error meaning is not color-only.
- [ ] No copy or imagery implies fabricated events, a pet afterlife, pet speech, or AI-reconstructed memories.

### Export and purchase

- [ ] Free preview has only cover, contents and two watermarked samples; locked pages are clearly labelled.
- [ ] Purchase cancel/fail/restore preserves profile/chapters/preview/style/page size.
- [ ] Both PDF paper sizes render locally; export error retains all source edits and exposes retry.

## 6. Implementation assumptions to resolve before freeze

1. Final app icon/wordmark, US legal StoreKit language, target-year range, and PDF print color proof need product/legal/brand sign-off.
2. The ML team must confirm candidate confidence thresholds, multi-pet behavior and battery/runtime budget; UI labels must match those semantics.
3. Full visual delivery still needs editable Figma/Relay source and physical-device redlines. These Markdown specifications define behavior/tokens, not a substitute for that source artifact.

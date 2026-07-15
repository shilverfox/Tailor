# Tailor · 01–12 high-fidelity visual acceptance matrix

Baseline: 390 × 844 pt iPhone portrait, 1× layout coordinates. Sources of truth: `design/detailed/ui_spec.md`, `design/detailed/component_inventory.md`, `design/assets/`, and `design/screens/01.png`–`12.png`. Current implementation was inspected in `Tailor/Features/*FeatureViews.swift` and `Tailor/Features/TailorComponents.swift`; screen 01 was verified in the iPhone simulator. `P0` blocks high-fidelity sign-off; `P1` is required before design freeze.

## Cross-screen implementation contract

| Priority | Required SwiftUI change | Exact acceptance measure |
|---|---|---|
| P0 | Replace `TailorScreen`'s content-tail CTA arrangement with a screen shell containing `ScrollView` plus a bottom action container pinned with `safeAreaInset(edge: .bottom)`. The container has 24 pt horizontal padding, 16 pt top padding and at least 16 pt above the home indicator. | On every next-step screen, the 56 pt primary CTA is visible without scrolling and its bottom edge is >=16 pt above the safe area. Content remains scrollable beneath it. |
| P0 | Use design tokens only: canvas `#F8F3E8`; elevated card `#FFFCF6`; input `#EFE4D1`; ink `#183A31`; secondary `#64756C`; clay `#B85639`; sage `#D8DFCB`; line `#DED4C1`. Do not use `.white`, `.white.opacity`, or default `TextField` fill for Tailor-owned surfaces. | Pixel sampling from each screen finds no pure-white Tailor surface. Card/input border is 1 physical pt `#DED4C1`. |
| P1 | Global type: display `Iowan Old Style`/New York fallback, 32 pt baseline / 36 line height; section title `.title2` semibold (24 pt); body 17 pt; meta 13 pt; label 12 pt semibold, tracking 1.2. | Heading does not truncate at 390 pt and maxes at three lines; body/metadata use the specified hierarchy. |
| P0 | Build reusable `TailorInput`, `TailorSecondaryButton`, `TailorTemplateSwatch`, `TailorChapterCard`, and `TailorBottomActionBar` rather than per-screen default controls. | The 12 screens share radius/input/action behavior: input 52 pt/radius 12, card 18, photo 20, primary 56/radius 16, secondary 48. |
| P1 | Generated editorial art is allowed only in Welcome, Privacy support, and Export support. Timeline, confirmation, reference, chapter, and archive thumbnails must use `PHAsset` or Sage placeholders. | No generated dog/cat asset appears as a user photo or a recovered moment. |

## 01 — Welcome and trust

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P1 | Header has only wordmark; detailed design also specifies a 48 pt `ellipsis.circle` Help target. | In `WelcomeFeatureView`, use a leading/trailing navigation row with `TAILOR` and a `Button` containing `ellipsis.circle`; present an About/privacy sheet. | Both controls are within the 24 pt page margins; Help hit target is 48×48 pt. |
| P1 | Secondary privacy text is visual text rather than a 48 pt button/link. | Replace the centered `Text` with `Button("How we protect your photos")`; apply secondary-button minimum height 48 and open the reusable privacy sheet. | Link is vertically tappable across 48 pt and exposes a Button accessibility role. |
| P1 | Hero now uses the correct asset/crop but lacks a deterministic fallback surface. | Keep `EditorialImage("WelcomeHero")` at 286 pt and radius 20; its missing-resource branch must use Sage + `photo` at 40 pt with the same crop frame. | At 390 pt, hero frame is exactly 342×286 pt after 24 pt gutters; animal remains in central 70%. |

## 02 — Privacy and photo access

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Standard state lacks the required Limited-access card; limited/denied modes do not show the specified two-action layouts. | In `PrivacyFeatureView`, add `TailorInfoCard(lock...)` for `notDetermined`: title `Limited access is okay`, message `Results will only include the photos you select.`. For `.limited`, render warning card plus 48 pt `Manage selected photos` and 56 pt `Continue with selected photos`; for `.denied/.restricted`, use primary manual picker and secondary `Open Settings`. | All four authorization states match the copy/actions in the spec without dead ends. |
| P1 | Privacy editorial image is a 138 pt decorative insertion not defined in the page layout; it competes with the three trust cards. | Remove it from the primary flow, or move it below the three cards as an optional 3:2, max 138 pt support image. | Trust cards begin in the first viewport at 390×844. |
| P1 | Primary and manual actions are scroll-tail actions. | Move the authorization CTA and manual/action alternatives into `TailorBottomActionBar`; preserve card state in the scroll body. | Primary and secondary actions stay visible above home indicator. |

## 03 — Create pet profile

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | System rounded text fields and white `CAME HOME` field do not meet the 52 pt Paper-deep input, line-border specification. | Replace `textFieldStyle(.roundedBorder)` and `.background(.white)` with `TailorInput`: fill `#EFE4D1`, 1 pt `#DED4C1`, radius 12, height 52; add 2 pt Ink/error focus state. | Both year cells and name field have exactly 52 pt field body, identical fill/border/radius. |
| P0 | Came-home year is non-editable text; there is no year picker, invalid/error state, or range relation. | Use two `YearPickerField`s arranged in a 2-column `HStack(spacing: 12)`; labels use 12 pt with tracking 1.2. Render inline error under affected field. | At 390 pt each field is 165 pt wide; error increases height instead of clipping. |
| P1 | Dog/Cat system segmented control does not show selected Ink/white state plus check. | Create `SpeciesSegment` with 48 pt height, `#EFE4D1` container, selected Ink fill/white label/checkmark. | Cells are equal width and selected state is not color-only. |

## 04 — Reference photos

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Five tiles are 116×155 but lack the required remove affordance and selected/unavailable states. | Wrap each selected tile in a `PhotoTile` with 20 pt radius, 1 pt Line border, 32–44 pt top-trailing `xmark` remove button and unavailable warning overlay; empty tile has `photo.badge.plus` + `Add photo`. | Tiles are 116×155 pt (3:4); remove has a >=44 pt target and no tile is non-interactive without an action label. |
| P1 | Picker trigger is a free-form label rather than Tailor secondary button. | Use a 48 pt `TailorSecondaryButton` with `photo.on.rectangle` icon. | Trigger has Clay text/icon and a 48 pt hit area. |
| P1 | Count string does not use a distinct metadata style/announced state. | Use 13 pt `TailorColor.secondaryInk`, and update it with `accessibilityLiveRegion` equivalent/announcement after picker changes. | `3 of 3 minimum selected` is visually 13 pt and not a body-size paragraph. |

## 05 — On-device scan

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | No local thumbnail strip, checked/match count card, or scan-surface treatment. | In `ScanFeatureView`, insert a 1:1 38 pt horizontal thumbnail strip below status, then a `#24473C` scan card showing `1,426 photos checked` and `39 likely matches so far`. Use actual authorised `PHAsset` thumbnails only. | At 390 pt: ring remains 180×180, strip thumbnails are 38×38 with 8 pt gaps, scan card uses Ink-surface treatment and readable white/muted text. |
| P0 | Error/paused/complete state is copy-only and conflates no-start, pause, and failure. | Split `ScanViewState` rendering: running, paused, interrupted, low battery, failed, complete. Use `ErrorCard` with retry/review action and retain the fixed privacy reassurance. | Each state visibly exposes its required primary/secondary actions and never loses confirmed work. |
| P1 | The generic `TailorInfoCard` is white on an Ink screen. | Provide `ScanStatusCard` using `#24473C`, Line/white text tokens and Clay icon; do not use elevated white card in this context. | No light card appears on the full Ink scan canvas. |

## 06 — Photo confirmation

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Missing year-filter control; selected tab is a system segmented control without underline/check state; photos are SF Symbol placeholders. | Replace Picker with custom three-tab row plus a 48 pt `All years` filter button. Tabs show label, count and selected underline/check. Render local `PHAsset` thumbnails in 3 columns with 8 pt gaps. | Grid cell width at 390 pt is `(342 - 16) / 3 = 108.7 pt`; tab state is visible without relying on color. |
| P0 | No full-screen detail viewer or explicit confirm/exclude actions. | On tile tap, present aspect-fit viewer with `This is [name]`, `Not [name]`, `Skip`; keep 48 pt targets and include local date/location. | Need-review photos can be decided without gesture-only input. |
| P1 | Bottom reassurance is above grid rather than fixed near CTA. | Move it into the bottom action group directly above `Create timeline (n)`. | Primary remains visible; reassurance and CTA form one 16 pt-spaced group. |

## 07 — Life timeline

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Current rows are plain 58×58 icon cards; design requires a vertical year axis and richer ChapterCards. | Replace the `ForEach` row with `TimelineAxis` (1 pt Clay/Line vertical rule, decorative) + `TailorChapterCard`: 72×72 local cover/Sage placeholder, date meta, 24 pt section heading, 13 pt count, 18 pt elevated card and disclosure/context menu. | Three chapter cards maintain 16 pt vertical gaps; axis aligns with node centers; covers are 72×72/radius 20. |
| P1 | Missing support note and hidden-chapter disclosure. | Add the neutral-title support note below list; group hidden chapters under `Hidden chapters (n)` disclosure instead of rendering a lone eye icon. | Visible/hidden state has a textual label and uses no silent exclusion. |
| P1 | No card action menu. | Add `Menu` with Rename, Change cover, Hide, Merge, and accessible reorder actions. | Ellipsis menu target is >=44 pt and does not block card navigation. |

## 08 — Chapter editor

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Current editor contains only title field/toggle; it omits optional note, image grid, cover state and drag/reorder guidance. | Add `CHAPTER TITLE` TailorInput, `A NOTE · OPTIONAL` multi-line input, 3-column `LazyVGrid` (8 pt spacing, max first 9 shown), cover badge and `TailorInfoCard("Cover photo", ...)`. | Each tile is square 108.7 pt at baseline, radius 12; exactly one cover badge is visible when images exist. |
| P0 | Page title is `Edit the chapters.` rather than a single chapter context. | Navigate editor with selected chapter binding; show compact nav year and title `Edit this chapter.`. | Editing a card presents the selected date range and cannot visually imply bulk edit. |
| P1 | Card background and input are generic white/default. | Use elevated card + Line border and TailorInput tokens; preserve 16 pt card padding. | No default rounded system TextField visual remains. |

## 09 — Album style and preview

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | A system segmented Picker replaces the required three visual swatches; preview is a single 280 pt card with no pagination, locked sample, or watermark. | Replace Picker with `HStack(spacing: 8)` of three 96×78 `TailorTemplateSwatch` buttons, each showing its real texture and title/check. Add `TabView`/carousel with page number, previous/next 48 pt buttons, and a watermarked/locked unpurchased page. | At 390 pt swatches fit 3×96 + 2×8 = 304 pt within 342 pt; selected swatch has Ink 2 pt border and check. |
| P1 | Cover typography defaults to SF font and does not show page status. | Use title serif 24 pt for `[Name]`, body/meta with template-appropriate token; add `Preview page 1 of 4` label. | Quiet Night uses warm-paper text at AA contrast; other templates use Ink. |
| P1 | Preview frame is 280 pt instead of a printed-page proportion. | Render portrait preview at 5:7 aspect ratio constrained to available width (342×479 pt max) or a horizontally paged preview with a 280 pt clipped viewport only when documented. | Page has 5:7 aspect and 20 pt radius; textures do not stretch. |

## 10 — One-time purchase

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Missing required legal fine print and purchase-in-progress visual state. | Add 13 pt secondary legal copy: `Payment is charged to your Apple Account after confirmation.` Add `isPurchasing` to view input; replace arrow with `ProgressView`, keep 56 pt button dimensions, disable duplicate purchase tap. | Purchase CTA remains the same width/height while loading; legal copy is readable and scrollable. |
| P1 | Benefits use ungrouped labels; price hierarchy is weaker than design. | Create elevated/Line benefit group with 16 pt spacing, Clay/Ink check symbols, then display `$19.99` at 24 pt semibold and `One-time purchase` as 13 pt metadata. | Price and one-time qualifier are adjacent and visually paired. |
| P1 | Failure is red body text instead of ErrorCard with actions. | Map errors to `TailorInfoCard` ErrorCard visual plus retry/restore/back secondary actions. | Failure copy remains visible above the fixed action bar. |

## 11 — Generate and complete export

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Rendering and completed states are conflated; no page progress, output cover thumbnail, A4/Letter choice, or correct primary label. | Introduce `ExportRenderState` (`choosingPaper`, `rendering(page,total)`, `complete(url)`, `failed`). Before export, use compact page-size sheet; rendering shows ring/`Rendering page 4 of 18`; completed state renders 3:2 local PDF cover thumbnail. | The completed primary is exactly `Save and share PDF`, 56 pt, and opens `ShareLink`; completed view does not show `Generate PDF`. |
| P1 | Export editorial still-life is used in the main result position instead of PDF cover. | Move `ExportCompletionCompanion` below the local privacy card as optional support art, max 150 pt; PDF cover gets the primary visual slot. | A user sees their archive cover before decorative art. |
| P1 | Error has plain red text and no retry action group. | Use ErrorCard with `Try again` primary and `Return to timeline` secondary; retain page size/template in state. | Failure presentation has both actions visible and no state reset. |

## 12 — Archives and settings

| Priority | Observed difference | Required SwiftUI implementation | Acceptance measure |
|---|---|---|---|
| P0 | Archive card uses `book.closed` icon instead of local cover; settings rows are static labels; destructive delete happens immediately. | Render a 72×72 local PDF/selected-photo cover or Sage placeholder; make each settings row a 48 pt `Button` with chevron. Replace direct delete with confirmation sheet using exact delete impact copy and `Cancel` then destructive `Delete local data`. | Tapping delete never removes data before confirmation. Archive cover is 72×72/radius 20. |
| P1 | Header lacks `SETTINGS` action; no empty/revoked-access visual state. | Add top nav with wordmark + 48 pt SETTINGS button. Add empty archive state and access-revoked warning card. | All settings rows/buttons are accessible, and no-archive state has a visible Create CTA. |
| P1 | Card uses white opacity and no Line border/status metadata hierarchy. | Use elevated card, 1 pt Line, 16 pt padding, 13 pt status/template/date; move title to 17 pt semibold. | Card is visually consistent with `TailorChapterCard` and no pure white surface remains. |

## Required visual verification after implementation

1. Capture 01–12 standard states at 390×844 and compare to matching `design/screens/01.png`–`12.png` at 1×.
2. Capture 02 limited/denied, 05 paused/failed, 06 zero-match, 09 unpurchased/purchased, 10 purchasing/failed, 11 rendering/failed, and 12 empty/delete-sheet states.
3. Overlay each screenshot with the design reference at 50% opacity. Allow a maximum 2 pt positional drift for persistent chrome, 4 pt for dynamic photo crop, and no token/color substitution.
4. Test Dynamic Type AX3 and Accessibility XXL: no CTA, field error, legal copy, or destructive confirmation may clip or become unreachable.
5. Re-run snapshot/build checks before sign-off. One-to-one sign-off requires all P0 rows closed and all P1 rows either closed or explicitly approved as a documented v1 variance.

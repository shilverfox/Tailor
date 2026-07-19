# Tailor v1 · Detailed screen specification

Status: design-ready implementation specification, based on `DESIGN_HANDOFF.md` and PRD. Baseline: 390×844 pt, iPhone portrait. All copy below is US English; product names / examples are illustrative, never generated claims about a real pet. See `component_inventory.md` for tokens and accessibility rules.

## Global behavior

- Navigation path: Welcome → Privacy → Profile → References → Scan → Confirmation → Timeline → Chapter editor → Preview → Purchase → Export → Archives. Back returns to the previous editable state; it never discards choices without confirmation.
- Persistent CTA is present only when a clear next step exists. It stays above home indicator/keyboard. Every screen scrolls at large Dynamic Type.
- Use native Photo Picker, system Settings redirect, StoreKit sheet, and Share Sheet; Tailor provides the explanatory state before/after them rather than recreating system UI.
- Privacy promise wording is fixed wherever surfaced: **“Processed on this iPhone. Your photos are not uploaded.”** “Only photos you confirm are used in your archive” is used where selection matters.
- **[Assumption]** The design baseline is one local profile named “Milo”; the app supports multiple profiles once an archive exists.

## 01 — Welcome and trust

**Purpose / layout.** Navigation row has wordmark `TAILOR` and an `ellipsis.circle` Help button. Display heading: “Keep a life close.” (3-line maximum), 3:2 editorial hero (286 pt high), then body: “Gather real photographs into a private life archive. Nothing leaves your iPhone.” The last third contains `Create a life archive` primary CTA and `How we protect your photos` secondary link.

**Interaction.** CTA advances to Privacy. Privacy link presents the same privacy explanation as screen 02 in a dismissible sheet, then returns here. Help opens a compact About/privacy sheet **[Assumption]**.

**States.** Standard only; if editorial hero unavailable, use Sage neutral texture plus `photo` symbol and identical text—do not show an AI pet avatar. Loading never blocks start.

**A11y.** Hero is decorative unless licensed photo has a meaningful descriptive label; heading and privacy body remain separate VoiceOver elements. CTA label: “Create a life archive.”

## 02 — Privacy and photo access

**Purpose / layout.** Back navigation; eyebrow `PRIVACY`; heading “Your photos stay yours.”; body “Tailor asks only for the access you choose.” Three `InfoCard`s: “Processed on this device”, “Your whole album is never uploaded”, “Only photos you approve are used.” Below, a Limited-access card: title “Limited access is okay”; supporting: “Results will only include the photos you select.” Bottom actions: primary `Allow photo access`, secondary `Choose photos manually instead`.

**Interaction.** Primary requests PhotoKit authorization. If full/read-write authorization is available, continue to Profile. Manual link invokes limited Photo Picker then continues to Profile with `limited` banner persisted. On return from Settings, re-evaluate authorization.

**States.**

| State | UI and next action |
| --- | --- |
| Not determined | Standard screen; primary triggers system permission. |
| Full access | Brief check card “Full photo access enabled”; advance automatically or via `Continue`. |
| Limited | Warning InfoCard: “Tailor can only search the photos you selected.” Actions: `Manage selected photos` and `Continue with selected photos`. |
| Denied/restricted | ErrorCard: “Photo access is off.” Body: “You can choose photos manually, or enable access in Settings.” Primary `Choose photos manually`; secondary `Open Settings`. No dead end. |

**A11y.** Explain scope before the system dialog. Cards use symbol + text. `Open Settings` announces leaving Tailor. Limited state is not phrased as failure.

## 03 — Create pet profile

**Purpose / layout.** Back navigation, `PROFILE` eyebrow, title “Tell us about them.” Dog/Cat `SpeciesSegment`, Name field label `THEIR NAME`, two year picker fields: `CAME HOME · OPTIONAL`, `LEFT US`. Info card: “Years only shape the timeline. They do not have to be exact.” Primary: `Choose reference photos`.

**Interaction / validation.** Dog or Cat, non-whitespace name, and departure year are mandatory. On focus loss or CTA, inline error below each invalid field: “Enter a name to continue.” / “Choose the year they left.” Came-home year must not follow departure year; error: “This year needs to be before [departure year].” Species switch preserves fields. **[Assumption]** year range is current year down to 1980, with free-text fallback for older photos.

**States.** CTA disabled until valid, with no error before submit. Error fields have Ink focus or Error 2-pt border plus icon and text, never red-only. Unsupported animal guidance (when reached from future import) states: “Tailor currently supports dogs and cats.” with return action.

**A11y.** Keyboard is `.name` for name; year controls are adjustable/selectable with value spoken. Pet name binds to later headings, e.g. “Milo’s life, in moments.”

## 04 — Reference photos

**Purpose / layout.** Back nav; title “Help us recognize them.” Body “Choose 3–5 clear photos from different ages and angles.” Five 3:4 tiles in horizontally scrollable row: selected image, remove button; remaining tile has add icon/label. Count label: `3 of 3 minimum selected`. Help InfoCard: “A helpful mix” / “One close-up, one full-body image, and photos from different years make matching more reliable.” CTA `Start looking`.

**Interaction.** Add opens limited/native picker constrained to images; maximum five. Tile tap opens aspect-fit local preview; remove asks no confirmation and updates count. Start begins scan when count ≥3. Picker cancellation retains choices.

**States.** 0–2 selection: CTA disabled and count e.g. `2 more needed`; no warning color necessary. 3–5: CTA enabled. If authorization assets disappear, show per-tile warning “This photo is no longer available” with replace/remove; do not start until three valid assets remain.

**A11y.** Each selected tile label: “Reference photo 1 of 3, selected; double tap to view, actions available.” Remove action is explicit rotor/custom action. Count announced after changes.

## 05 — On-device scan

**Purpose / layout.** Full Ink screen; back/close action asks to keep draft when scan is active; eyebrow `ON-DEVICE SCAN`; title “Looking through the moments.” Central ProgressRing (percent), status “Checking 4,281 photos safely on this device.” Local thumbnail strip; scan card “1,426 photos checked” / “39 likely matches so far”; bottom primary is `Pause scan`. Fixed reassurance: “Processed on this iPhone. Your photos are not uploaded.”

**Interaction.** Scan runs in batches. Pause changes ring status to `Paused` and button to `Resume scan`. If app backgrounds/locks, save progress only; surface an in-app resume card only after the user actively reopens the archive. Do not register notifications or show a notification. Back/cancel opens sheet: `Pause and return`, `Cancel scan` (destructive; retains profile/reference photos but clears scan candidates only).

**States.**

| State | Visible copy/action |
| --- | --- |
| Running | Counts + Pause. |
| Paused | “Scan paused at 62%. Your progress is saved.” + Resume. |
| Interrupted | “Ready to continue where you left off.” + Resume scan. |
| Low battery | Warning card: “Battery is low. You can pause now and continue later.” + Pause. Do not silently stop. |
| Failed | ErrorCard: “We couldn’t finish this scan.” “Your references and reviewed photos are still here.” Primary `Try again`; secondary `Review matches so far` if any. |
| Complete | Brief completion state “Matches ready for your review” + `Review photos`; automatic advance only after readable announcement **[Assumption]**. |

**A11y.** Ring exposes “Scan progress, 62 percent; 1,426 of 4,281 photos checked.” Thumbnail strip is hidden from VO unless tappable. Reduce Motion makes ring static with numeric updates.

## 06 — Photo confirmation

**Purpose / layout.** Back nav / eyebrow `REVIEW`; title “We found 184 moments.” Year filter button and four tabs: `High · 126`, `Needs review · 42`, `Sensitive · 3`, `Excluded · 16`; selected tab has text, underline and a named state icon. Scrollable 3-column local-photo grid. Bottom card says: “Nothing uncertain enters the archive automatically.” Primary `Create timeline` displays selected count. `Sensitive` has a protective explanation card and a collapsed `Never use (n)` manager.

**Interactions.** High-confidence results start selected but can be deselected; needs-review and sensitive items start unselected. Tapping image opens full-screen aspect-fit viewer with asset date/location (when available), `This is [name]`, `Not [name]`, `Set aside as sensitive`, `Decide later`, and `Never use in this archive`. `Never use` requires impact confirmation and immediately removes that asset from chapters, covers, previews and future PDFs without modifying Photos. Swipe is optional shortcut only: right confirms, left excludes, with undo snackbar. Long-press opens multi-select mode with `Exclude`, `Add to archive`, and `Set aside`; batch Never use requires confirmation. The Excluded tab has `Restore` action. Year filter is a bottom sheet with All years/default selection.

**States.** Sensitive assets never enter a chapter, cover, preview or PDF until the user selects `Use in this archive`; Tailor must not diagnose why they were set aside. Zero matches: title “No clear matches yet.” Body identifies local-only limitation; actions `Choose different reference photos`, `Select photos manually`, and `Keep this draft`. No photo is fabricated. Need-review remains non-blocking; create timeline can proceed with high-confirmed items. If zero confirmed images, primary becomes `Select photos to continue` disabled; manual selection is available. Batch exclusion asks confirmation only for >1 image.

**A11y.** Grid items are buttons with date and state (“June 2019, needs review, not selected”). Never encode confidence only with corner color. Announce undo. Viewer has explicit alternatives to swipe and minimum 48-pt actions.

## 07 — Life timeline

**Purpose / layout.** Back nav; eyebrow `TIMELINE`; title “[Name]’s life, in moments.” Body “Made from the photos you chose. Change every chapter.” Vertical year axis with 3–6 `ChapterCard`s, cover, neutral chapter title, count, and disclosure. Primary `Preview album`. Support note: “When dates do not establish a story, use neutral titles such as ‘2018–2020’ or ‘Days together.’”

**Interaction.** Tap card opens Chapter editor. Context menu / Edit mode supports `Rename`, `Change cover`, `Hide from album`, `Merge with next chapter`, and drag reorder; merging requires confirmation and preserves all photos. Hiding requires an impact sheet and excludes the chapter plus its cover from preview/PDF, while retaining it in the editable timeline. `Edit periods` additionally supports hiding a whole year or user-selected date range without showing a photo preview. **[Assumption]** manual `Add chapter` appears in edit mode after data-model review.

**States.** Empty timeline (no confirmed items) routes to confirmation instead of rendering inferred chapters. Empty chapter shows Sage placeholder and “Add photos” action. Hidden chapters appear in an `Hidden periods (n)` disclosure, never silently deleted; before user expands it, show date/title/count only and no representative image. If only one chapter is viable, Preview stays enabled and catalog uses one chapter.

**A11y.** Axis is decorative; cards announce year, title, selected photo count, hidden state. Reorder has accessible Move earlier/later actions.

## 08 — Chapter editor

**Purpose / layout.** Back (discard/save prompt if dirty); compact nav title year range; heading “Edit this chapter.” Title input labelled `CHAPTER TITLE`; optional body field labelled `A NOTE · OPTIONAL` with neutral placeholder “A few pages from the days you chose.” 3-column photo grid (up to 9 visible; full collection scrolls), cover badge on one tile; InfoCard “Cover photo” / “Tap any photo to set the cover. Hold and drag to reorder.” CTA `Save chapter`.

**Interaction.** User can type any neutral personal wording; Tailor supplies only a date-driven default (e.g. `2018–2020`, `Days together`). No autogenerated behavior/emotion prose. Tap photo opens action sheet: Set as cover, Move, Remove from chapter (returns to confirmed pool, does not delete system photo). Drag reorder has accessible equivalents. Save validates nonempty title; `Back` prompts `Keep editing` / `Discard changes`.

**States.** Cover removed chooses next image and tells user “Cover updated”; if no images remain, chapter becomes empty and offers `Add photos` or `Delete chapter`. Long text expands field; no fixed-height truncation. Error save preserves all edits.

**A11y.** Text fields expose labels/hints. Grid reads position, cover state, and action. Drag handles have labels, not visual-only reordering.

## 09 — Album style and preview

**Purpose / layout.** Back nav / `PREVIEW`; title “A book to keep.” Three `TemplateSwatch` controls: Warm Paper, Quiet Night, Field Notes. Paginated 5:7 local preview, default cover: `[Name] / A life in moments`; page indicators and previous/next buttons. Unpurchased notice: “Every page in this preview is watermarked. It is built from the photos currently included in your album.” Primary `Unlock complete album · $19.99`; secondary `Edit timeline`.

**Interaction.** Template switch immediately rerenders the sample. Page carousel supports buttons and swipe, with visible page count. Free state renders 6–8 pages from eligible real user photos: cover, contents, at least two different-period chapter/selection pairs where available, and closing page. When photos/periods are insufficient it renders an explicit explanation page rather than fabricating or duplicating images. Every rendered free page carries a repeated `TAILOR · PREVIEW` watermark. Purchased state changes primary to `Generate full PDF` and rerenders the same user-approved content without watermark—not merely overlay hide.

**States.** Preview render in progress: skeleton paper pages and “Preparing your preview…”; failure: ErrorCard with `Try again` / `Return to timeline`, preserving template. If title/name is long, cover layout scales or wraps, then reduces title style before clipping **[Assumption: export typography fallback tested in PDF renderer]**.

**A11y.** Swatches selected trait. Preview page labels (“Preview page 2 of 7, watermarked sample”) and controls work without swipe. Watermark is decorative in VO.

## 10 — One-time purchase

**Purpose / layout.** Back nav / `ONE-TIME UNLOCK`; title “Keep every page.” Price `$19.99` plus `One-time purchase`. Four check lines: Full, watermark-free PDF; Every chapter and selected photo; Print-ready A4 and US Letter; Stays private on your device. InfoCard: “No subscription. No account.” / “Your full album remains editable on this iPhone.” CTA `Unlock complete album`; `Restore purchase` link; fine-print placeholder: “Payment is charged to your Apple Account after confirmation.” **[Assumption: final legal wording/local price is supplied by App Store Connect review.]**

**Interaction.** CTA invokes StoreKit purchase sheet. Restore invokes StoreKit restore. Purchase success marks entitlement then moves to Export. Cancel returns to Preview (or stays with non-error message) without loss. No custom payment data fields.

**States.** Purchasing: CTA loading/disabled, rest controls remain accessible. Cancelled: neutral inline “Purchase was not completed. Your album is still here.” Failure: ErrorCard “We couldn’t complete the purchase.” `Try again`, `Restore purchase`, `Back to preview`. Restored: confirmation “Purchase restored on this Apple Account.” No entitlement: restore may say “No previous purchase found.”

**A11y.** Price is read as “nineteen dollars and ninety-nine cents, one-time purchase.” Restore has explicit label. Legal copy supports Dynamic Type and scrolls.

## 11 — Generate and complete export

**Purpose / layout.** Before completion, nav `EXPORT`, title “Preparing your archive.” ProgressRing / linear text “Rendering page 4 of 18”; fixed local privacy copy. After completion: success icon, heading “Your archive is ready.” Body “[Name]’s Life Archive is saved privately on this iPhone. Share a copy whenever you’re ready.” PDF cover thumbnail; primary `Save and share PDF`; secondary `Return to timeline`.

**Interaction.** User selects A4/US Letter before rendering in a compact sheet **[Assumption: default is US Letter for US launch]**. Save/share opens system Share Sheet from local sandbox file; it does not duplicate into Photos unless user selects that route. Return preserves rendered file/state. Completion tells user “Keep a backup somewhere you trust.”

**States.** Rendering supports background-safe resume: “Rendering paused. Continue when Tailor is open.” Failure: ErrorCard “We couldn’t create this PDF.” “Your photos, chapters, and edits are safe.” Actions `Try again`, `Return to timeline`; retain selected page size/template. File unavailable after completion: `Generate again` with clear cause. Share cancellation has no error.

**A11y.** Progress spoken as page count. Success icon is paired with heading. `Save and share PDF` explains it opens system sharing options.

## 12 — Archives and settings

**Purpose / layout.** Top wordmark and `SETTINGS` action; heading “Your archives.” Archive cards show local cover, `[Name]’s Life Archive`, status/date/template and chevron. Settings list: `Rescan for new photos`, `Manage photo access`, `About Tailor`; danger section `Delete all local Tailor data`. Bottom CTA `Create another archive`.

**Interaction.** Tap archive reopens its timeline/preview. Rescan asks profile selection and enters scan with existing references, preserving past decisions. Manage photo access opens in-app current-scope summary then native limited picker/Settings. Delete opens destructive bottom sheet.

**Delete sheet.** Title: “Delete all local Tailor data?” Body: “This removes Tailor’s local pet profiles, photo matches, decisions, edits, and generated PDFs from this iPhone. Your original Photos library will not be changed. This cannot be undone.” Buttons: `Cancel`; `Delete local data` (destructive). **[Assumption]** a second typed-name confirmation is not required for v1; this sheet is the required second confirmation.

**States.** No archives: title “Your archives”; empty state “No life archives yet.” / “Create an archive from photos already on your iPhone.” + Create CTA. Access revoked: per-archive warning “Some photos need access again” with Manage action; PDF remains available if local generated file exists. Delete failure retains list and gives error/retry; successful deletion returns empty state and does not reset App Store entitlement.

**A11y.** Cards report status/template. Setting rows are buttons. Destructive sheet initial focus is title/impact copy, not destructive action.

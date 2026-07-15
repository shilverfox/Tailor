# Tailor v1 · Component inventory and development tokens

Status: detailed-design handoff. Values marked **[Assumption]** require visual QA on physical iPhone before design freeze. Baseline canvas is 390 × 844 pt (iPhone 15/16 logical size); iPhone-only, iOS 17+.

## 1. Brand and semantic color tokens

| Token | Light value | Role / implementation note |
| --- | --- | --- |
| `color.background.canvas` | `#F8F3E8` | Warm-paper screen background. |
| `color.background.subtle` | `#EFE4D1` | Input fill, inactive segmented control. |
| `color.background.elevated` | `#FFFCF6` | Card, sheet and PDF-paper surface. |
| `color.text.primary` | `#183A31` | Ink; headings, body and enabled primary fills. |
| `color.text.secondary` | `#64756C` | Supporting copy and metadata. |
| `color.text.tertiary` | `#7B877F` | Disabled labels; never for essential instructions. |
| `color.action.accent` | `#B85639` | Clay; links, selection and progress accent. |
| `color.border.default` | `#DED4C1` | 1-pt dividers and card borders. |
| `color.surface.sage` | `#D8DFCB` | Neutral image placeholder / low-priority fill. |
| `color.status.success` | `#2C6A55` | Completed status; always pair with an icon and text. |
| `color.status.warning` | `#9A5A19` | Limited access / needs attention. |
| `color.status.error` | `#A8342A` | Failure and destructive actions. |
| `color.scan.background` | `#183A31` | Scan screen full background. |
| `color.scan.surface` | `#24473C` | Scan progress card. |
| `color.overlay.scrim` | `#183A31` at 44% | Modal/sheet backdrop. |

Contrast requirement: all normal text/buttons must meet WCAG 2.1 AA (4.5:1 text, 3:1 large text/UI boundary). `color.action.accent` on paper is for nonessential links/indicators only; do not use it for long body copy. **[Assumption]** final PDF ink values are verified separately for print output.

## 2. Typography

Use Dynamic Type text styles; never pin user-facing text to a non-scaling point size. English is the v1 UI language; names and supplied chapter text may contain any Unicode.

| Token | iOS text style / weight | Baseline | Use and overflow rule |
| --- | --- | ---:| --- |
| `type.display` | `.largeTitle`, regular; New York / Iowan Old Style fallback | 32/36 | Screen headline; max 3 lines, then scroll content—never ellipsize the page purpose. |
| `type.title` | `.title2`, semibold | 24/29 | Section/card title; 2 lines before truncation in compact cards. |
| `type.body` | `.body`, regular | 17/22 | Explanations, inputs and settings. |
| `type.callout` | `.callout`, semibold | 16/21 | Primary button and key card line. |
| `type.meta` | `.footnote`, regular | 13/18 | Counts, dates and helper text. |
| `type.label` | `.caption`, semibold, tracking 1.2 | 12/16 | All-caps control labels where appropriate. |

Dynamic type: support through `AX5` (Accessibility XXL) without clipped essential content; use vertical scrolling and move fixed CTA above keyboard/safe area. At `AX3+`, segmented controls may wrap into two rows and photo-count labels sit below tiles. Use `lineLimit(nil)` for privacy promises, error descriptions and destructive confirmation copy. Long pet names: display title wraps to two lines; archive/timeline cards use two lines then middle/ tail truncation only for a nonessential subtitle. Do not force uppercase on user-entered names.

## 3. Layout, elevation and motion tokens

| Token | Value |
| --- | --- |
| `space.1`…`space.10` | 4, 8, 12, 16, 20, 24, 28, 32, 40, 48 pt |
| `layout.page.horizontal` | 24 pt (16 pt minimum at 320-pt width) |
| `layout.page.top` | 18 pt below navigation/status region |
| `layout.cta.safeInset` | 16 pt above safe-area; primary CTA zone has 24 pt side inset |
| `radius.input/card/photo/button/sheet` | 12 / 18 / 20 / 16 / 24 pt |
| `border.default` | 1 physical pt, `color.border.default` |
| `shadow.card` | none by default; sheets use `0 8 24 #183A31 12%` |
| `size.tapTarget.min` | 48 × 48 pt; destructive/check controls 44 × 44 minimum only when spacing prevents 48 |

Use 4-pt increments. Main vertical content scrolls beneath a persistent bottom action zone when a primary next action exists. Navigation uses a 48-pt back target and title/eyebrow; no gesture is the only way to leave a state.

Motion: respect `UIAccessibility.isReduceMotionEnabled`. Scan ring updates no more than once per 500 ms with 200-ms ease-out; photo decision transitions use 180-ms crossfade/slide; template switch crossfades preview over 200 ms; PDF completion uses one 250-ms checkmark scale/fade. No looping grief, pet, or celebratory animation.

## 4. Reusable components

| Component | Anatomy and states | SwiftUI-facing token / accessibility |
| --- | --- | --- |
| `PrimaryButton` | 56-pt Ink fill, white callout, optional trailing SF Symbol `arrow.right`; enabled/loading/disabled. Loading keeps width and replaces arrow with ProgressView. | `ButtonStyle.tailorPrimary`; label includes action and object, e.g. “Start looking for Milo”. |
| `SecondaryButton` | 48-pt transparent surface; Clay text/icon; pressed uses `background.subtle`. | For recoverable alternatives, not destructive actions. |
| `DestructiveButton` | 48–56 pt; error outline or error fill only in confirmation sheet. | Explicit label “Delete Milo’s local Tailor data”; never just “Delete”. |
| `TextFieldCard` | label, 52-pt field, helper/error line. Focus border is 2 pt Ink. | Errors announced as hint; name field has text-content type `.name`. |
| `YearPickerField` | Label + year-only picker; optional badge. | Announce selected/optional state. **[Assumption]** custom year sheet rather than free text. |
| `SpeciesSegment` | Dog/Cat equal cells, Ink selected state plus checkmark. | VoiceOver: “Dog, selected”; unsupported species is not shown as a selectable option. |
| `PhotoTile` | Image/placeholder, 12–20 pt corner radius by context; selected check, confidence badge, optional drag handle. | Status must include text in detail view; image has date/accessibility label derived locally. |
| `ConfidenceBadge` | High / Needs review / Excluded; icon + word, not color-only. | High does not imply immutable; “Needs review” never gets selected check by default. |
| `ChapterCard` | Timeline node, year range, cover thumbnail, title, count, chevron/context menu. | Whole card opens editor; context actions have separate labelled menu. |
| `InfoCard` / `ErrorCard` | Icon, title, 1–3 lines, optional action. | Error has `accessibilityLiveRegion` equivalent announcement / `.accessibilityAddTraits(.isStaticText)`. |
| `ProgressRing` | Percentage plus text count; values exposed with `.accessibilityValue`. | Do not communicate scan state by ring alone. |
| `BottomSheet` | 24-pt top radius, drag indicator, title, impact copy, actions. | Modal focus is trapped; Cancel first for destructive sheets. |
| `TemplateSwatch` | 3 equal 96×78 pt cards minimum, preview texture + name + selected check. | `Button`, selected trait; does not rely solely on border. |

## 5. Album-template language

| Template | Visual language | Accessibility / export constraint |
| --- | --- | --- |
| Warm Paper (default) | Paper ground, Ink serif headings, Clay timeline marks, generous photographic whitespace. | Highest-contrast default. |
| Quiet Night | Ink ground, warm-paper type, muted photo frames, restrained Clay page number. | Verify contrast and printer preview **[Assumption]**. |
| Field Notes | Sage ground, Ink sans-serif captions, fine ruled dividers, documentary spacing. | Rules are decorative, never the only grouping cue. |

## 6. Icon and imagery rules

Use SF Symbols 5 first: `lock.shield`, `iphone`, `checkmark.circle.fill`, `photo.on.rectangle`, `pause.fill`, `play.fill`, `exclamationmark.triangle`, `arrow.clockwise`, `square.and.arrow.up`, `trash`, `ellipsis.circle`, `chevron.right`, `xmark`. Custom artwork is limited to brand/app icon and optional welcome visual. User album imagery must render local `PHAsset` thumbnails; generated illustrations can never appear as a recovered pet photo or a chapter event.
